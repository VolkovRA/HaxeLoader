package loader.nodejs;

import js.Syntax;
import js.lib.Error;
import js.node.Buffer;
import js.node.Http;
import js.node.Https;
import js.node.http.ClientRequest;
import js.node.http.IncomingMessage;
import js.node.url.URL;
import haxe.DynamicAccess;
import loader.DataFormat;
import loader.Global;
import loader.Header;
import loader.Loader;
import loader.Method;
import loader.Request;

/**
 * Реализация загрузчика для NodeJS.
 * Поддерживаются http и https запросы.
 */
class LoaderNodeJS implements Loader
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
    public var onComplete:Loader->Void          = null;
    public var onResponse:Loader->Void          = null;
    public var onProgress:Loader->Void          = null;

    // Приват:
    private var headers:Array<Header>           = null;
    private var buffer:Array<Buffer>            = null;
    private var cr:ClientRequest                = null;
    private var msg:IncomingMessage             = null;
    private var req:Request                     = null;

    /**
     * Создать загрузчик.
     */
    public function new() {
    }
    
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
            headers         = null;
        }

        // Должен быть указан объект запроса:
        if (request == null) {
            error = new Error("Параметры запроса Request - не должны быть null");
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

        // Разное:
        var url     = new URL(req.url);
        var isHttps = url.protocol == "https:";
        var port    = Utils.parseInt(url.port, 10);

        // Заголовки:
        var sendHeaders:DynamicAccess<String> = new DynamicAccess();
        if (req.headers != null) {
            for (header in req.headers)
                sendHeaders[header.name.toLowerCase()] = header.value.toLowerCase();
        }

        // Опций запроса:
        var options:HttpsRequestOptions = {
            protocol:   url.protocol,
            hostname:   url.hostname,
            method:     untyped req.method,
            headers:    sendHeaders,
            path:       url.pathname,
            family:     4,
            port:       port>0?port:(isHttps?443:80)
        }

        // Параметры для GET запроса:
        if (req.method == Method.GET && req.data != null)
            options.path += "?" + Utils.encodeURI(req.data);

        // Создаём запрос:
        if (isHttps)
            cr = Https.request(options, onRequestComplete);
        else
            cr = Http.request(options, onRequestComplete);

        // События:
        cr.addListener("error", onRequestError);
        cr.addListener("close", onRequestClose);

        // Отправляем:
        if (req.method == Method.POST && req.data != null)
            cr.end(req.data);
        else
            cr.end();
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
        if (Utils.eq(buffer, null))
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
            if (Utils.eq(dataFormat, DataFormat.BINARY)) {
                data = Buffer.concat(buffer);
            }
            else if (Utils.eq(dataFormat, DataFormat.JSON)) {
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
                return Utils.parseInt(header.value, 10);
        }
        
        return 0;
    }

    @:keep
    public function toString():String {
        return "[LoaderNodeJS status=" + status + " bytesLoaded=" + bytesLoaded + " bytesTotal=" + bytesTotal + "]";
    }
}