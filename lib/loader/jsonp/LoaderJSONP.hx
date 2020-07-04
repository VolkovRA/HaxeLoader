package loader.jsonp;

import js.Browser;
import js.lib.Error;
import js.html.Event;
import js.html.ScriptElement;
import loader.DataFormat;
import loader.ILoader;
import loader.LoaderState;
import loader.Header;
import loader.Method;
import loader.Request;

/**
 * Реализация загрузчика на основе протокола: `JSONP`.
 * - Работает только в браузере.
 * - Раздел `<head>` в DOM должен быть загружен для добавления в него тегов `<script>`.
 * - Поддерживаются только `GET` запросы.
 * - Заголовки никакие не поддерживаются.
 * - Колбек прогресса загрузки не поддерживается.
 * - Статус ответа сервера не поддерживается.
 * - Позволяет выполнить кроссдоменный запрос.
 * 
 * @see https://ru.wikipedia.org/wiki/JSONP
 */
class LoaderJSONP implements ILoader
{
    static private var loaders:Dynamic<LoaderJSONP> = {};
    static private var autoID:Int = 0;

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
    private var id:Int                          = ++autoID;
    private var tag:ScriptElement               = null;
    private var req:Request                     = null;

    /**
     * Создать загрузчик.
     */
    public function new() {
        if (untyped Browser.window.activeLoadingJSONP == null)
            untyped Browser.window.activeLoadingJSONP = loaders;
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

        // Раздел head должен быть загружен!
        if (Browser.document.head == null) {
            close();
            error = new Error("The <head> tag of current DOM page is not loaded");
            if (onComplete != null)
                onComplete(this);

            return;
        }
        
        // Объект запроса:
        tag = Browser.document.createScriptElement();
        tag.addEventListener("load", onLoad);
        tag.addEventListener("error", onError);

        // Тип запроса:
        if (Utils.eq(req.method, Method.GET)) {
            tag.src = Utils.encodeURI(req.url + "?" + Utils.str(req.data) + "&callback=activeLoadingJSONP[" + id + "].onData");
        }
        else {
            close();
            error = new Error("Unsupported request method of JSONP loader: " + req.method);
            if (onComplete != null)
                onComplete(this);

            return;
        }

        // Запрос:
        req = null;
        untyped loaders[id] = this;
        Browser.document.head.appendChild(tag);
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

        if (Utils.noeq(tag, null)) {
            tag.removeEventListener("load", onLoad);
            tag.removeEventListener("error", onError);

            if (tag.parentNode == Browser.document.head)
                Browser.document.head.removeChild(tag);

            Utils.delete(untyped loaders[id]);
            tag.src = null;
            tag = null;
        }

        state = LoaderState.COMPLETE;
        req = null;
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
        return null;
    }

    @:keep
    public function toString():String {
        return "[LoaderJSONP complete=" + (Utils.eq(state,LoaderState.COMPLETE)?"true":"false") + "]";
    }

    // ЛИСТЕНЕРЫ
    /**
     * Колбек получения данных.
     * 
     * Вызывается неявно до вызова `onLoad`, если ответ валидный JSONP.
     * Не вызывается, если сервер не поддерживает JSONP или в JavaScript
     * коде ответа была ошибка.
     * 
     * Пример валидного JSONP ответа:
     * ```
     * activeLoadingJSONP[1].onData({
     *      "response": {
     *          "count": 2,
     *          "items": [
     *              1475915,
     *              1954780
     *          ]
     *      }
     * });
     * ```
     * 
     * @param data Данные с удалённого сервера.
     */
    @:keep
    private function onData(data:Dynamic):Void {
        this.data = data;
    }

    private function onError(e:Event):Void {
        close();

        error = new Error("Loading error");

        if (onComplete != null)
            onComplete(this);
    }

    private function onLoad(e:Event):Void {
        close();

        if (onComplete != null)
            onComplete(this);
    }
}