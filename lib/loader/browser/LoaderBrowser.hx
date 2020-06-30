package loader.browser;

import js.Browser;
import js.lib.Error;
import js.html.ProgressEvent;
import js.html.XMLHttpRequest;
import js.html.XMLHttpRequestResponseType;
import loader.Loader;
import loader.Request;
import loader.Header;
import loader.DataFormat;
import loader.Method;

/**
 * Реализация загрузчика для браузера.
 * Поддерживаются http и https запросы.
 */
class LoaderBrowser implements Loader
{
    public var bytesLoaded(default, null):Int;
    public var bytesTotal(default, null):Int;
    public var data(default, null):Dynamic;
    public var status(default, null):Int;
    public var dataFormat:DataFormat;
    public var error:Error;
    public var onComplete:Loader->Void;
    public var onResponse:Loader->Void;
    public var onProgress:Loader->Void;

    private var xhr:XMLHttpRequest;

    /**
     * Создать загрузчик.
     */
    public function new() {
        bytesLoaded     = 0;
        bytesTotal      = 0;
        status          = 0;
        dataFormat      = DataFormat.TEXT;
        data            = null;
        error           = null;
        onComplete      = null;
        onResponse      = null;
        onProgress      = null;
        xhr             = null;
    }

    // ПАБЛИК
    public function load(request:Request):Void {
        
        // Удаляем предыдущий объект: (Если есть)
        removeXHR();

        // Сброс:
        bytesLoaded     = 0;
        bytesTotal      = 0;
        status          = 0;
        data            = null;
        error           = null;
        xhr             = Browser.createXMLHttpRequest();

        // Должен быть указан объект запроса:
        if (request == null) {
            error = new Error("Параметры запроса Request - не должны быть null");
            if (onComplete != null)
                onComplete(this);
            return;
        }

        // Тип запроса:
        if (Utils.eq(request.method, Method.GET)) {
            if (request.data == null)
                xhr.open(Method.GET, Utils.encodeURI(request.url), true);
            else
                xhr.open(Method.GET, Utils.encodeURI(request.url + "?" + request.data), true);
        }
        else if (Utils.eq(request.method, Method.POST)) {
            xhr.open(Method.POST, Utils.encodeURI(request.url), true);
        }
        else {
            error = new Error("Неподдерживаемый тип HTTP запроса=" + request.method);
            if (onComplete != null)
                onComplete(this);
            return;
        }

        // Заголовки:
        if (request.headers != null) {
            for (header in request.headers)
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
            error = new Error("Неподдерживаемый тип загружаемых данных=" + dataFormat);
            removeXHR();
            if (onComplete != null)
                onComplete(this);
            return;
        }

        // Настройка:
        xhr.timeout             = request.timeout;
        xhr.onreadystatechange  = onXhrReadyStateChange;
        xhr.onabort             = onXhrAbort;
        xhr.ontimeout           = onXhrTimeout;
        xhr.onerror             = onXhrError;
        xhr.onprogress          = onXhrProgress;
        xhr.onloadend           = onXhrLoadEnd;

        // Запрос: Если метод запроса GET или HEAD, то аргументы игнорируются и тело запроса устанавливается в null. (Справка)
        xhr.send(request.data);
    }

    public function close():Void {
        removeXHR();
    }

    public function getHeaders():Array<Header> {
        if (xhr == null)
            return null;

        var str = xhr.getAllResponseHeaders();
        if (str == null)
            return null;

        var arr = str.split("\r\n");
        if (arr.length == 0)
            return null;

        var res = new Array<Header>();
        for (item in arr) {
            var arr2 = item.split(": ");
            if (arr2.length >= 2)
                res.push({name:arr2[0], value:arr2[1] });
        }

        if (res.length == 0)
            return null;

        return res;
    }

    /**
     * Удалить объект **XMLHTTPRequest**.
     * Прерывает активную загрузку, если такая выполняется.
     */
    private function removeXHR():Void {
        if (xhr != null) {
            xhr.onreadystatechange = null;
            xhr.onabort = null;
            xhr.ontimeout = null;
            xhr.onerror = null;
            xhr.onprogress = null;
            xhr.onloadend = null;
            
            try {
                xhr.abort();
            }
            catch (err:Error) {
            }

            xhr = null;
        }
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
        error = new Error("Запрос отменён");
    }

    private function onXhrTimeout():Void {
        error = new Error("Таймаут выполнения запроса");
    }

    private function onXhrError(e:ProgressEvent):Void {
        error = new Error("Ошибка выполнения запроса");
    }

    private function onXhrProgress(e:ProgressEvent):Void {
        bytesLoaded = e.loaded;
        bytesTotal = e.total;
        if (onProgress != null)
            onProgress(this);
    }

    private function onXhrLoadEnd():Void {
        data = xhr.response;
        if (status >= 400)
            error = new Error(xhr.responseURL + " replied " + status);
        if (onComplete != null)
            onComplete(this);
    }
}