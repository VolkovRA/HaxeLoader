package loader;

import loader.Global;

/**
 * Балансировщик нагрузки.
 * 
 * Используется для ограничения количества отправляемых запросов
 * в единицу времени. Запросы встают в очередь и отправляются позже,
 * если их количество начинает превышать заданные лимиты. Один
 * балансировщик соответствует одному узлу.
 * 
 * Способ применения:
 * 1. Создать экземпляр `Balancer`, настроить необходимый лимит запросов.
 * 2. Назначить созданный экземпляр `Balancer` каждому загрузчику `Loader`
 *    **до** вызова метода `load()`.
 */
class Balancer
{
    /**
     * Интервал обновлений для запуска запросов. (mc)
     */
    static private inline var INTERVAL_UPDATE:Int = 100;

    // Приват
    private var loaders:Array<Loader> = new Array();
    private var interval:Dynamic = null;
    private var time:Float = 0;

    /**
     * Создать балансировщик.
     */
    public function new() {
    }

    /**
     * Ограничение частоты запросов. (Request per second)
     * - Это значение не может быть меньше `0`.
     * - Если задано `0` - запросы никогда не будут отправлены.
     * 
     * По умолчанию: `1` (Один запрос в секунду)
     */
    public var rps(default, set):Float = 1;
    function set_rps(value:Float):Float {
        if (value > 0) {
            if (Utils.eq(value, rps))
                return value;

            rps = value;

            if (Utils.eq(interval, null) && length > 0)
                interval = Global.setInterval(onUpdate, INTERVAL_UPDATE, this);
        }
        else {
            if (Utils.eq(rps, 0))
                return value;

            rps = 0;

            if (Utils.noeq(interval, null)) {
                Global.clearInterval(interval);
                interval = null;
            }
        }

        return value;
    }

    /**
     * Количество запросов в очереди. (Штук)
     * 
     * По умолчанию: `0`
     */
    public var length(default, null):Int = 0;

    /**
     * Обновление.
     * 
     * Метод сделан статическим, что бы хакс не использовал `bind()`,
     * который нужен для привязки контенкста `this`. Так будет работать
     * быстрее.
     * 
     * @param b Обновляемый балансировщик.
     */
    static private function onUpdate(b:Balancer):Void {

        // Обновление
        // Выключаем обновление, если загрузчиков больше нет:
        if (Utils.eq(b.length, 0)) {
            if (Utils.noeq(b.interval, null)) {
                Global.clearInterval(b.interval);
                b.interval = null;
            }
            return;
        }

        // Метод гарантированно не вызовется, если rps <= 0:
        var t = 1000 / b.rps;         // Время на 1 запрос. (mc)
        var ct = Utils.stamp();     // Текущее время. (mc)
        var dt = ct - b.time;         // Реально прошедшее время с момента последнего запроса. (mc)

        // Времени прошло слишком мало даже для выполнения 1 запроса:
        if (dt < t)
            return;

        // Максимально прошедшее время для 1 тика: (Чтоб не было скачка запросов)
        var mt = Math.max(t + INTERVAL_UPDATE, INTERVAL_UPDATE * 2);
        var num = 0; // <-- Количество отправляемых запросов
        if (dt > mt) {
            // Скачок прошедшего времени:
            num = Math.floor(mt / t);
            if (num > b.length)
                num = b.length;
            
            b.time = ct; // <-- Приближённое уравнение с пропуском промежутка в скачке
        }
        else {
            // Нет скачка прошедшего времени:
            num = Math.floor(dt / t);
            if (num > b.length)
                num = b.length;
            
            b.time += num * t; // <-- Точное уравнение, ни секунды пропущено
        }

        // Чистим очередь от null и сортируем её:
        var len = b.loaders.length;
        var i = 0;
        var j = 0;
        while (i < len) {
            if (Utils.eq(b.loaders[i], null)) {
                i ++;
                continue;
            }

            b.loaders[j] = b.loaders[i];
            i ++;
            j ++;
        }
        if (Utils.noeq(i,j))
            b.loaders.resize(j);
        b.loaders.sort(compare);

        // Забираем из списка отправляемые элементы: (При отправке список может измениться!)
        var arr:Array<Loader> = Utils.createArray(num);
        i = num;
        while (i-- > 0) {
            arr[i] = b.loaders[i];
            b.loaders[i] = null; // <-- Удалится на следующей иттерации
        }
        b.length -= num;

        // Безопасно инициируем запросы:
        while (num-- > 0) {
            if (Utils.eq(arr[num].state, LoaderState.PENDING) && Utils.eq(arr[num].balancer, b))
                arr[num].loadStart();
        }
    }

    static private function compare(x:Loader, y:Loader):Int {
        if (x.priority > y.priority)
            return -1;
        if (x.priority < y.priority)
            return 1;
        
        return 0;
    }

    /**
     * Выполнить все запросы в очереди.
     * 
     * Вызов этого метода приводит к мгновенной отправке всех запросов,
     * находящихся в данный момент в очереди.
     * 
     * Очередь запросов очищается.
     */
    public function flush():Void {
        var i = 0;
        var arr = loaders;
        var len = arr.length;

        loaders = new Array(); // <-- Список может измениться из-за вызова колбеков
        time = Utils.stamp();
        length = 0;

        // Обновления не нужны:
        if (Utils.noeq(interval, null)) {
            Global.clearInterval(interval);
            interval = null;
        }

        // Безопасно инициируем запросы:
        while (i < len) {
            var l = arr[i++];
            if (Utils.noeq(l, null) && Utils.eq(l.state, LoaderState.PENDING) && Utils.eq(l.balancer, this))
                l.loadStart();
        }
    }

    /**
     * Очистить балансировщик.
     * - У загрузчиков в очереди вызывается метод: `Loader.close()`. (Состояние: `LoaderState.PENDING`)
     * - Уже выполняемые и завершённые запросы - игнорируются.
     * - Очередь запросов очищается.
     */
    public function clear():Void {
        var i = 0;
        var arr = loaders;
        var len = arr.length;
        
        loaders = new Array(); // <-- Список может измениться из-за вызова колбеков
        length = 0;

        // Обновления не нужны:
        if (Utils.noeq(interval, null)) {
            Global.clearInterval(interval);
            interval = null;
        }

        // Безопасно закрываем очередь:
        while (i < len) {
            var l = arr[i++];
            if (Utils.eq(l, null) || Utils.noeq(l.state, LoaderState.PENDING))
                continue;

            l.close();
        }
    }

    /**
     * Добавить загрузчик в очередь на отправку.
     * 
     * Регистрирует переданный загрузчик в очереди и инициирует
     * в будущем его загрузку. Этот метод не выполняет никаких
     * проверок и просто добавляет переданный экземпляр в очередь.
     * 
     * - Этот метод должен вызываться только один раз, иначе будут
     *   дубли в очереди.
     * - Не забудьте удалить загрузчик из очереди, если его загрузку
     *   отменит пользователь вызовом метода: `Loader.close()`.
     * 
     * @param loader Загрузчик.
     */
    @:allow(loader.Loader)
    private function add(loader:Loader):Void {
        length ++;
        loaders.push(loader);
        
        if (Utils.eq(interval, null) && rps > 0)
            interval = Global.setInterval(onUpdate, INTERVAL_UPDATE, this);
    }

    /**
     * Удалить загрузчик из очереди на отправку.
     * 
     * Удаляет из очереди первый найденный экземпляр.
     * Этот метод не выполняет никаких дополнительных действий.
     * 
     * @param loader Загрузчик.
     */
    @:allow(loader.Loader)
    private function remove(loader:Loader):Void {
        var i = 0;
        var len = loaders.length;
        while (i < len) {
            if (Utils.eq(loaders[i], loader)) {
                length --;
                loaders[i] = null; // <-- Список перестроится при следующем обновлении.
                return;
            }

            i ++;
        }
    }

    /**
     * Получить строковое представление балансера.
     * @return Возвращает строковое представление объекта.
     */
    @:keep
    public function toString():String {
        return "[Balancer length=" + length + " rps=" + rps + "]";
    }
}