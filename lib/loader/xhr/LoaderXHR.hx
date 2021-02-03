package loader.xhr;

import haxe.DynamicAccess;
import js.Browser;
import js.html.ProgressEvent;
import js.html.XMLHttpRequest;
import js.html.XMLHttpRequestResponseType;
import js.lib.Error;
import loader.parser.XWWWForm;
import tools.NativeJS;

/**
 * Реализация загрузчика на основе
 * браузерного: `XmlHttpRequest`
 * @see https://developer.mozilla.org/en-US/docs/Web/API/XMLHttpRequest
 */
@:dce
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
    private var xhr:XMLHttpRequest = null;
    private var req:Request = null;

    /**
     * Создать новый экземпляр.
     */
    public function new() {
    }

    public function load(request:Request):Void {

        // Объект в изначальное состояние:
        if (state != LoaderState.READY) {
            close();

            status      = 0;
            bytesTotal  = 0;
            bytesLoaded = 0;
            data        = null;
            error       = null;
        }

        // Параметры запроса:
        if (request == null) {
            error = new Error("Не передан объект с параметрами запроса");
            state = LoaderState.COMPLETE;
            if (onComplete != null)
                onComplete(this);
            return;
        }
        req = request;

        // Балансировщик:
        if (balancer == null) {
            loadStart();
        }
        else {
            state = LoaderState.PENDING;
            balancer.add(this);
        }
    }

    private function loadStart():Void {
        state = LoaderState.LOAD;

        xhr                    = Browser.createXMLHttpRequest();
        xhr.timeout            = req.timeout>0?req.timeout:30000;
        xhr.onreadystatechange = onXhrReadyStateChange;
        xhr.onabort            = onXhrAbort;
        xhr.ontimeout          = onXhrTimeout;
        xhr.onerror            = onXhrError;
        xhr.onprogress         = onXhrProgress;
        xhr.onloadend          = onXhrLoadEnd;
        xhr.responseType       = getResponseType(dataFormat);
        xhr.open(req.method==null?Method.GET:req.method, req.url+getQueryParams(req.query));

        // Тело:
        var headers:DynamicAccess<String> = {};
        var body:Dynamic = null;
        if (req.body != null) {
            if (isBin(req.body)) {
                body = req.body;
                headers["content-type"] = "application/octet-stream";
            }
            else if (NativeJS.isObj(req.body)) {
                body = XWWWForm.write(req.body);
                headers["content-type"] = "application/x-www-form-urlencoded";
            }
            else {
                body = NativeJS.str(req.body);
                headers["content-type"] = "text/plain";
            }
        }

        // Заголовки пользователя:
        if(req.headers != null) {
            var i = 0;
            var l = req.headers.length;
            while (i < l) {
                var h = req.headers[i++];
                if (h.name == null || h.name == "" || h.value == null)
                    continue;
                headers[h.name.toLowerCase()] = h.value;
            }
        }
        for (k => v in headers)
            xhr.setRequestHeader(k, v);

        // Улетел:
        xhr.send(body);
    }

    /**
     * Проверка данных на двоичность.  
     * Возвращает: `true`, если указанные данные
     * являются двоичными.
     * @param data Проверяемые данные.
     * @return Двоичная природа данных.
     */
    static private function isBin(data:Dynamic):Bool {
        if (NativeJS.is(data, js.html.Blob)) return true;
        if (NativeJS.is(data, js.lib.ArrayBuffer)) return true;
        if (NativeJS.is(data, js.lib.DataView)) return true;
        if (NativeJS.is(data, js.lib.Float32Array)) return true;
        if (NativeJS.is(data, js.lib.Float64Array)) return true;
        if (NativeJS.is(data, js.lib.Int16Array)) return true;
        if (NativeJS.is(data, js.lib.Int32Array)) return true;
        if (NativeJS.is(data, js.lib.Int8Array)) return true;
        if (NativeJS.is(data, js.lib.Uint8Array)) return true;
        if (NativeJS.is(data, js.lib.Uint16Array)) return true;
        if (NativeJS.is(data, js.lib.Uint32Array)) return true;
        if (NativeJS.is(data, js.lib.Uint8ClampedArray)) return true;
        return false;
    }

    /**
     * Получить параметры запроса.  
     * Возвращает строку, готовую для вставки в URL.
     * @param params Параметры запроса.
     * @return Упакованный вид.
     */
    static private function getQueryParams(params:Dynamic):String {
        if (params == null)
            return "";

        var s = "";
        if (NativeJS.isObj(params))
            s = XWWWForm.write(params);
        else
            s = NativeJS.str(params);

        return s==""?s:("?"+s);
    }

    /**
     * Получить тип загружаемых данных.  
     * Функция внутреннего маппинга между API.
     * @param format Заявленный формат.
     * @return Формат в API XHR.
     */
    static private function getResponseType(format:DataFormat):XMLHttpRequestResponseType {
        if (format == DataFormat.BINARY)
            return XMLHttpRequestResponseType.ARRAYBUFFER;
        if (format == DataFormat.JSON)
            return XMLHttpRequestResponseType.JSON;
        return XMLHttpRequestResponseType.TEXT;
    }

    function set_balancer(value:Balancer):Balancer {
        if (value == balancer)
            return value;
        close();
        balancer = value;
        return value;
    }

    public function close():Void {
        if (state == LoaderState.COMPLETE)
            return;
        if (state == LoaderState.PENDING && balancer != null)
            balancer.remove(this);
        if (xhr != null) {
            xhr.onreadystatechange = null;
            xhr.onabort            = null;
            xhr.ontimeout          = null;
            xhr.onerror            = null;
            xhr.onprogress         = null;
            xhr.onloadend          = null;

            try {
                // Тихо потушили:
                xhr.abort();
            }
            catch (err:Error) {
            }
            xhr = null;
        }
        state = LoaderState.COMPLETE;
        req   = null;
    }

    public function purge():Void {
        close();

        status      = 0;
        bytesTotal  = 0;
        bytesLoaded = 0;
        priority    = 0;
        state       = LoaderState.READY;
        dataFormat  = DataFormat.TEXT;
        balancer    = null;
        data        = null;
        error       = null;
        onComplete  = null;
        onResponse  = null;
        onProgress  = null;
    }

    public function getHeaders():Array<Header> {
        if (xhr == null)
            return [];

        var str = xhr.getAllResponseHeaders();
        if (str == null)
            return [];

        var arr = str.split("\r\n");
        if (arr.length == 0)
            return [];

        var res = new Array<Header>();
        for (item in arr) {
            var arr2 = item.split(": ");
            if (arr2.length >= 2)
                res.push({ name:arr2[0].toLowerCase(), value:arr2[1] });
        }
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
        var c = state==LoaderState.LOAD;
        error = new Error("Запрос был отменён: " + req.url);

        close();
        if (c && onComplete != null)
            onComplete(this);
    }

    private function onXhrTimeout():Void {
        var c = state==LoaderState.LOAD;
        error = new Error("Таймаут выполнения запроса: " + req.url);

        close();
        if (c && onComplete != null)
            onComplete(this);
    }

    private function onXhrError(e:ProgressEvent):Void {
        var c = state==LoaderState.LOAD;
        error = new Error("Ошибка выполнения запроса: " + req.url);

        close();
        if (c && onComplete != null)
            onComplete(this);
    }

    private function onXhrProgress(e:ProgressEvent):Void {
        bytesLoaded = e.loaded;
        bytesTotal  = e.total;

        if (onProgress != null)
            onProgress(this);
    }

    private function onXhrLoadEnd():Void {
        var c = state==LoaderState.LOAD;
        data = xhr.response;
        if (status >= 400)
            error = new Error(xhr.responseURL + " вернул статус: " + status);

        close();
        if (c && onComplete != null)
            onComplete(this);
    }
}