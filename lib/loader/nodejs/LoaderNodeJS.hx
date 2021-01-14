package loader.nodejs;

import haxe.DynamicAccess;
import js.Syntax;
import js.lib.Error;
import js.node.Buffer;
import js.node.Http;
import js.node.Https;
import js.node.http.ClientRequest;
import js.node.http.IncomingMessage;
import js.node.url.URL;
import loader.DataFormat;
import loader.Global;
import loader.Header;
import loader.ILoader;
import loader.Method;
import loader.Request;
import loader.parser.XWWWForm;
import tools.NativeJS;

/**
 * Реализация загрузчика для NodeJS.
 * @see https://nodejs.org/api/http.html#http_http_request_url_options_callback
 */
class LoaderNodeJS implements ILoader
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
    private var headers:Array<Header>           = null;
    private var buffer:Array<Buffer>            = null;
    private var cr:ClientRequest                = null;
    private var msg:IncomingMessage             = null;
    private var req:Request                     = null;

    /**
     * Создать загрузчик.
     */
    public function new () {
    }
    
    public function load(request:Request):Void {

        // Новый запрос
        // Объект в изначальное состояние: (Без изменения настроек)
        if (state != LoaderState.READY) {
            close();

            status          = 0;
            bytesTotal      = 0;
            bytesLoaded     = 0;
            //state         = LoaderState.READY; // <-- Не имеет эффекта
            data            = null;
            error           = null;
            headers         = null;
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
        state = LoaderState.LOAD;

        // Разное:
        var url = new URL(req.url);
        var isHttps = url.protocol == "https:";
        var port = NativeJS.parseInt(url.port); // Может быть NaN!

        // Заголовки:
        var headers:DynamicAccess<String> = new DynamicAccess();
        if (req.headers != null) {
            var i = 0;
            while (i < req.headers.length) {
                var header = req.headers[i++];
                headers[header.name.toLowerCase()] = header.value.toLowerCase();
            }
        }

        // Отправляемые данные:
        var isGet = req.method == Method.GET;
        var isBodyModified = false;
        var body:Dynamic = null;
        if (req.data != null) {
            if (req.contentType == null || req.contentType.indexOf("application/x-www-form-urlencoded") != -1) {
                if (NativeJS.isStr(req.data)) {
                    isBodyModified = false;
                    body = null;
                }
                else if (Buffer.isBuffer(req.data)) {
                    isBodyModified = true;
                    body = XWWWForm.encode(req.data);
                }
                else if (NativeJS.isObj(req.data)) {
                    isBodyModified = true;
                    body = XWWWForm.write(req.data);
                }
                else {
                    isBodyModified = true;
                    body = XWWWForm.encode(NativeJS.str(req.data));
                }

                headers["content-type"] = "application/x-www-form-urlencoded";
                headers["content-length"] = NativeJS.str(Buffer.byteLength(isBodyModified?body:req.data));
            }
            else {
                if (NativeJS.isStr(req.data)) {
                    isBodyModified = false;
                    body = null;
                }
                else if (Buffer.isBuffer(req.data)) {
                    isBodyModified = false;
                    body = null;
                }
                else {
                    isBodyModified = true;
                    body = NativeJS.str(req.data);
                }

                headers["content-type"] = req.contentType;
                headers["content-length"] = NativeJS.str(Buffer.byteLength(isBodyModified?body:req.data));
            }
        }

        // Опций запроса:
        var options:HttpsRequestOptions = {
            protocol:   url.protocol,
            hostname:   url.hostname,
            method:     untyped req.method,
            headers:    headers,
            path:       url.search==""?url.pathname:(url.pathname+url.search),
            family:     4,
            port:       port>0?port:(isHttps?443:80),
        }

        // Параметры для GET запроса:
        if (isGet && req.data != null) {
            if (isBodyModified)
                options.path += (options.path.indexOf('?')==-1?("?"+body):("&"+body));
            else
                options.path += (options.path.indexOf('?')==-1?("?"+req.data):("&"+req.data));
        }

        // Создаём запрос:
        if (isHttps)
            cr = Https.request(options, onRequestComplete);
        else
            cr = Http.request(options, onRequestComplete);

        // События:
        cr.addListener("error", onRequestError);
        cr.addListener("close", onRequestClose);

        // Отправляем:
        if (req.data == null || isGet)
            cr.end();
        else
            cr.end(isBodyModified?body:req.data);
        req = null;
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
        if (cr != null) {
            cr.removeListener("error", onRequestError);
            cr.removeListener("close", onRequestClose);
            cr.addListener("error", function(){} ); // <-- hung up error
            cr.abort();
            cr = null;
        }
        if (msg != null) {
            msg.removeListener("data", onRequestData);
            msg = null;
        }

        state   = LoaderState.COMPLETE;
        req     = null;
        buffer  = null;
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
        return headers;
    }

    // ЛИСТЕНЕРЫ
    private function onRequestComplete(m:IncomingMessage):Void { // Установка соединения
        var obj:DynamicAccess<Dynamic> = m.headers;
        if (obj != null) {
            headers = new Array<Header>();

            // Заголовки:
            var key:String = null;
            Syntax.code("for ({0} in {1}) {", key, obj); // for in
                var value:Dynamic = obj[key];
                if (Syntax.code('{0} instanceof Array', value))
                    headers.push({ name:key, value:value.join("; ") });
                else
                    headers.push({ name:key, value:value });
            Syntax.code("}"); // for end
        }
        
        status = m.statusCode;
        bytesTotal = getContentLength();
        msg = m;
        msg.addListener("data", onRequestData);
    }

    private function onRequestData(data:Buffer):Void { // Получение данных
        if (buffer == null)
            buffer = new Array();

        buffer.push(data);
        bytesLoaded += data.length;

        if (onProgress != null)
            onProgress(this);
    }

    private function onRequestError(err:Error):Void { // Ошибка запроса
        error = err;
    }

    private function onRequestClose():Void { // Завершение сеанса
        if (buffer != null) {
            if (dataFormat == DataFormat.BINARY) {
                data = Buffer.concat(buffer);
            }
            else if (dataFormat == DataFormat.JSON) {
                try {
                    data = Global.JSON.parse(Buffer.concat(buffer).toString());
                }
                catch(err:Dynamic) {
                    error = err;
                }
            }
            else {
                data = Buffer.concat(buffer).toString();
            }
        }

        close();

        if (onComplete != null)
            onComplete(this);
    }

    /**
     * Получение размера тела сообщения.
     */
    private function getContentLength():Int {
        if (headers == null)
            return 0;
        
        for (header in headers) {
            if (header.name == "content-length") // API Ноды возвращает заголовки в lowerCase.
                return NativeJS.parseInt(header.value);
        }
        
        return 0;
    }
}