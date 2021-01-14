package loader.xhr;

import js.Browser;
import js.lib.Error;
import js.html.ProgressEvent;
import js.html.XMLHttpRequest;
import js.html.XMLHttpRequestResponseType;
import loader.DataFormat;
import loader.ILoader;
import loader.LoaderState;
import loader.Header;
import loader.Method;
import loader.Request;

/**
 * Реализация загрузчика на основе браузерного: `XmlHttpRequest`.
 * @see https://developer.mozilla.org/en-US/docs/Web/API/XMLHttpRequest
 */
class LoaderXHR implements ILoader
{
    public var status(default, null):Int        = 0;
    public var bytesTotal(default, null):Int    = 0;
    public var bytesLoaded(default, null):Int   = 0;
    public var priority:Int                     = 0;
    public var state(default, null):LoaderState = LoaderState.READY;
    public var dataFormat:DataFormat            = DataFormat.TEXT;
    public var balancer(default, set):Balancer  = null;
    public var data(default, null):Dynamic      = null;
    public var error:Error                      = null;
    public var onComplete:ILoader->Void         = null;
    public var onResponse:ILoader->Void         = null;
    public var onProgress:ILoader->Void         = null;
    public var userData:Dynamic                 = null;

    // Приват:
    private var xhr:XMLHttpRequest              = null;
    private var req:Request                     = null;

    /**
     * Создать загрузчик.
     */
    public function new() {
    }

    // ПАБЛИК
    public function load(request:Request):Void {

        // Новый запрос
        // Объект в изначальное состояние: (Без изменения настроек)
        if (Utils.noeq(state, LoaderState.READY)) {
            close();

            status          = 0;
            bytesTotal      = 0;
            bytesLoaded     = 0;
            //state         = LoaderState.READY; // <-- Не имеет эффекта
            data            = null;
            error           = null;
        }

        // Должен быть указан объект запроса:
        if (request == null) {
            error = new Error("The Request parameters cannot be null");
            state = LoaderState.COMPLETE;
            if (onComplete != null)
                onComplete(this);

            return;
        }
        
        // Отложенный вызов:
        req = request;
        if (balancer == null) {
            loadStart();
        }
        else {
            state = LoaderState.PENDING;
            balancer.add(this); //<-- Балансер сам вызовет: Loader.loadStart()
        }
    }

    private function loadStart():Void {
        state   = LoaderState.LOAD;
        xhr     = Browser.createXMLHttpRequest();
        
        // Тип запроса:
        if (Utils.eq(req.method, Method.GET)) {
            if (req.data == null)
                xhr.open(Method.GET, Utils.encodeURI(req.url), true);
            else
                xhr.open(Method.GET, Utils.encodeURI(req.url + "?" + Utils.str(req.data)), true);
        }
        else if (Utils.eq(req.method, Method.POST)) {
            xhr.open(Method.POST, Utils.encodeURI(req.url), true);
        }
        else {
            close();
            error = new Error("Unsupported request method of XHR loader: " + req.method);
            if (onComplete != null)
                onComplete(this);

            return;
        }

        // Заголовки:
        if (req.headers != null) {
            for (header in req.headers)
                xhr.setRequestHeader(header.name, header.value);
        }

        // Формат данных:
        if (Utils.eq(dataFormat, DataFormat.TEXT))
            xhr.responseType = XMLHttpRequestResponseType.TEXT;
        else if (Utils.eq(dataFormat, DataFormat.BINARY))
            xhr.responseType = XMLHttpRequestResponseType.ARRAYBUFFER;
        else if (Utils.eq(dataFormat, DataFormat.JSON))
            xhr.responseType = XMLHttpRequestResponseType.JSON;
        else {
            close();
            error = new Error("Unsupported dataFormat: " + dataFormat);
            if (onComplete != null)
                onComplete(this);

            return;
        }

        // Настройка:
        xhr.timeout             = req.timeout;
        xhr.onreadystatechange  = onXhrReadyStateChange;
        xhr.onabort             = onXhrAbort;
        xhr.ontimeout           = onXhrTimeout;
        xhr.onerror             = onXhrError;
        xhr.onprogress          = onXhrProgress;
        xhr.onloadend           = onXhrLoadEnd;

        // Запрос: Если метод запроса GET или HEAD, то аргументы игнорируются и тело запроса устанавливается в null. (Справка)
        xhr.send(req.data);
        req = null;
    }

    function set_balancer(value:Balancer):Balancer {
        if (Utils.eq(value, balancer))
            return value;
        
        close();
        balancer = value;
        return value;
    }

    public function close():Void {
        if (Utils.eq(state, LoaderState.COMPLETE))
            return;
        if (Utils.eq(state, LoaderState.PENDING) && balancer != null)
            balancer.remove(this);
        if (Utils.noeq(xhr, null)) {
            xhr.onreadystatechange  = null;
            xhr.onabort             = null;
            xhr.ontimeout           = null;
            xhr.onerror             = null;
            xhr.onprogress          = null;
            xhr.onloadend           = null;
            
            try {
                xhr.abort(); // <-- Тихо потушили
            }
            catch (err:Error) {
            }
            
            xhr = null;
        }

        state   = LoaderState.COMPLETE;
        req     = null;
    }

    public function purge():Void {
        close();

        status          = 0;
        bytesTotal      = 0;
        bytesLoaded     = 0;
        priority        = 0;
        state           = LoaderState.READY;
        dataFormat      = DataFormat.TEXT;
        balancer        = null;
        data            = null;
        error           = null;
        onComplete      = null;
        onResponse      = null;
        onProgress      = null;
    }

    public function getHeaders():Array<Header> {
        if (Utils.eq(xhr, null))
            return null;

        var str = xhr.getAllResponseHeaders();
        if (str == null)
            return null;

        var arr = str.split("\r\n");
        if (Utils.eq(arr.length, 0))
            return null;

        var res = new Array<Header>();
        for (item in arr) {
            var arr2 = item.split(": ");
            if (arr2.length >= 2)
                res.push({ name:arr2[0], value:arr2[1] });
        }

        if (Utils.eq(res.length, 0))
            return null;

        return res;
    }

    // ЛИСТЕНЕРЫ
    private function onXhrReadyStateChange():Void {
        if (xhr.status > 0 && status == 0) {
            status = xhr.status;
            if (onResponse != null)
                onResponse(this);
        }
    }

    private function onXhrAbort():Void {
        var c = Utils.eq(state, LoaderState.LOAD);
        error = new Error("Request has been canceled");

        close();
        if (c && onComplete != null)
            onComplete(this);
    }

    private function onXhrTimeout():Void {
        var c = Utils.eq(state, LoaderState.LOAD);
        error = new Error("Request is timeout");

        close();
        if (c && onComplete != null)
            onComplete(this);
    }

    private function onXhrError(e:ProgressEvent):Void {
        var c = Utils.eq(state, LoaderState.LOAD);
        error = new Error("Request error");

        close();
        if (c && onComplete != null)
            onComplete(this);
    }

    private function onXhrProgress(e:ProgressEvent):Void {
        bytesLoaded     = e.loaded;
        bytesTotal      = e.total;

        if (onProgress != null)
            onProgress(this);
    }

    private function onXhrLoadEnd():Void {
        var c = Utils.eq(state, LoaderState.LOAD);
        data = xhr.response;
        if (status >= 400)
            error = new Error(xhr.responseURL + " replied " + status);

        close();
        if (c && onComplete != null)
            onComplete(this);
    }
}