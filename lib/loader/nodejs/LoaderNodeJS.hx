package loader.nodejs;

import js.node.url.URL;
import js.lib.Error;
import js.node.Buffer;
import js.node.Http;
import js.node.Https;
import js.node.http.ClientRequest;
import js.node.http.IncomingMessage;
import haxe.DynamicAccess;
import loader.Method;
import loader.Header;
import loader.DataFormat;
import loader.Loader;
import loader.Request;

/**
 * Реализация загрузчика для NodeJS.
 * Поддерживаются http и https запросы.
 */
class LoaderNodeJS implements Loader
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

    private var headers:Array<Header>;
    private var buffer:Array<Buffer>;
    private var cr:ClientRequest;
    private var msg:IncomingMessage;

    /**
     * Создать загрузчик.
     */
    public function new() {
        bytesLoaded = 0;
        bytesTotal  = 0;
        status      = 0;
        dataFormat  = DataFormat.TEXT;
        data        = null;
        error       = null;
        onComplete  = null;
        onResponse  = null;
        onProgress  = null;
    }
    
    public function load(request:Request):Void {

        // Удаляем предыдущий запрос:
        if (cr != null) {
            cr.removeListener("error", onRequestError);
            cr.removeListener("close", onRequestClose);
            cr.abort();
        }
        if (msg != null) {
            msg.removeListener("data", onRequestData);
        }

        // Сброс:
        bytesLoaded = 0;
        bytesTotal  = 0;
        status      = 0;
        data        = null;
        error       = null;
        cr          = null;
        msg         = null;
        buffer      = null;
        headers     = null;

        // Должен быть указан объект запроса:
        if (request == null) {
            error = new Error("Параметры запроса Request - не должны быть null");
            if (onComplete != null)
                onComplete(this);
            return;
        }

        // Разное:
        var url = new URL(request.url);
        var isHttps = url.protocol == "https:";

        // Заголовки:
        var sendHeaders:DynamicAccess<String> = new DynamicAccess();
        if (request.headers != null) {
            for (header in request.headers)
                sendHeaders[header.name.toLowerCase()] = header.value.toLowerCase();
        }

        // Опций запроса:
        var options:HttpsRequestOptions = {
            protocol: url.protocol,
            hostname: url.hostname,
            method: untyped request.method,
            headers: sendHeaders,
            path: url.pathname,
            family: 4,
            port: Std.parseInt(url.port)>0?Std.parseInt(url.port):(isHttps?443:80)
        }

        // Параметры для GET запроса:
        if (request.method == Method.GET && request.data != null)
            options.path += "?" + Utils.encodeURI(request.data);

        // Создаём запрос:
        if (isHttps)
            cr = Https.request(options, onRequestComplete);
        else
            cr = Http.request(options, onRequestComplete);

        // События:
        cr.addListener("error", onRequestError);
        cr.addListener("close", onRequestClose);

        // Отправляем:
        if (request.method == Method.POST && request.data != null)
            cr.end(request.data);
        else
            cr.end();
    }

    public function close():Void {
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
    }

    public function getHeaders():Array<Header> {
        return headers;
    }

    // ЛИСТЕНЕРЫ
    private function onRequestComplete(m:IncomingMessage):Void { // Установка соединения
        var obj:DynamicAccess<Dynamic> = m.headers;
        if (obj != null) {
            headers = new Array<Header>();

            for (item in obj.keys()) {
                var value:Dynamic = obj[item];
                if (Std.is(value, Array))
                    headers.push({name:item, value:getHeaderArrayValue(value)});
                else
                    headers.push({name:item, value:Std.string(value)});
            }
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
            if (dataFormat == DataFormat.TEXT)
                data = Buffer.concat(buffer).toString();
            else if (dataFormat == DataFormat.BINARY)
                data = Buffer.concat(buffer);
            else
                error = new Error("Unknown dataFormat: " + this.dataFormat);

            buffer = null;
        }

        if (onComplete != null)
            onComplete(this);
    }

    /**
     * Получение размера тела сообщения.
     */
    private function getContentLength():UInt {
        if (headers == null)
            return 0;
        
        for (header in headers) {
            if (header.name == "content-length") // Апи нода возвращает заголовки в lowerCase.
                return Std.parseInt(header.value);
        }
        
        return 0;
    }

    /**
     * Получить значение заголовка из массива.
     */
    private function getHeaderArrayValue(array:Array<String>):String {
        if (array == null)
            return "";
        
        var str:String = "";
        for (item in array)
            str += item + "; ";
        
        if (str.length == 0)
            return "";
        else
            return str.substring(0, str.length - 2);
    }
}