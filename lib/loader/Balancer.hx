package loader;

import tools.NativeJS;

/**
 * Балансировщик нагрузки. 🚦  
 * Ограничивает отправку запросов до заданного лимита.
 * 
 * Способ применения:
 * 1. Создать экземпляр: `Balancer`, настроить
 *    необходимый лимит запросов.
 * 2. Назначить созданный экземпляр: `Balancer` каждому
 *    загрузчику: `ILoader` **до** вызова их метода:
 *    `load()`
 * 
 * Пример:
 * ```
 * var b = new Balancer(5); // 5 Запросов в секунду
 * 
 * var l1:ILoader; // Какой-то новый загрузчик 1
 * l1.balancer = b;
 * 
 * var l2:ILoader; // Какой-то новый загрузчик 2
 * l2.balancer = b;
 * 
 * // Запросы будут выполнены с соблюдением очереди и частоты запросов
 * l1.load();
 * l2.load();
 * ```
 */
@:dce 
class Balancer
{
    /**
     * Интервал обновлений для запуска запросов. *(mc)*  
     * Используется для периодического опроса
     * балансировщика на предмет запуска новых запросов
     * из его очереди.
     */
    inline static private var INTERVAL_TIME:Int = 100;

    // Приват
    private var arr:Array<ILoader> = [];
    private var id:Dynamic = null;
    private var time:Float = 0;

    /**
     * Создать балансировщик.
     * @param rps Ограничение частоты запросов. *(Штук в секунду)*
     */
    public function new(?rps:Float) {
        if (rps != null)
            this.rps = rps;
    }

    /**
     * Ограничение частоты запросов. *(Штук в секунду)*  
     * - Это значение не может быть меньше: `0`
     * - Если задано: `0` - запросы никогда не будут
     *   отправлены.
     * 
     * По умолчанию: `1` *(Один запрос в секунду)*
     */
    public var rps(default, set):Float = 1;
    function set_rps(value:Float):Float {
        if (value > 0) {
            if (value == rps)
                return value;
            rps = value;
            if (len > 0 && id == null)
                id = untyped setInterval(onUpdate, INTERVAL_TIME);
        }
        else {
            if (rps == 0)
                return value;
            rps = 0;
            if (id != null) {
                untyped clearInterval(id);
                id = null;
            }
        }
        return value;
    }

    /**
     * Количество запросов в очереди.  
     * По умолчанию: `0`
     */
    public var len(get, never):Int;
    inline function get_len():Int {
        return arr.length;
    }

    /**
     * Обновление.  
     * Используется для запуска загрузки из
     * очереди.
     */
    private function onUpdate():Void {

        // Обновление
        // Выключаем обновление, если загрузчиков больше нет:
        if (len == 0) {
            if (id != null) {
                untyped clearInterval(id);
                id = null;
            }
            return;
        }

        // Метод гарантированно не вызовется, если rps <= 0:
        var t = 1000/rps;        // Время на 1 запрос. (mc)
        var ct = NativeJS.now(); // Текущее время. (mc)
        var dt = ct-time;        // Реально прошедшее время с момента последнего запроса. (mc)

        // Времени прошло слишком мало даже для выполнения 1 запроса:
        if (dt < t)
            return;

        // Максимально прошедшее время для 1 тика: (Чтоб не было скачка запросов)
        var mt = Math.max(t+INTERVAL_TIME, INTERVAL_TIME*2);
        var num = 0; // <-- Количество отправляемых запросов
        if (dt > mt) {
            // Скачок прошедшего времени:
            num = Math.floor(mt/t);
            if (num > len)
                num = len;
            time = ct; // <-- Приближённое уравнение с пропуском промежутка в скачке
        }
        else {
            // Нет скачка прошедшего времени:
            num = Math.floor(dt/t);
            if (num > len)
                num = len;
            time += num*t; // <-- Точное уравнение, ни секунды пропущено
        }

        // Чистим очередь от null и сортируем её:
        var i = 0;
        var j = 0;
        var l = len;
        while (i < l) {
            if (arr[i] == null) {
                i ++;
                continue;
            }
            arr[j++] = arr[i++];
        }
        if (i != j)
            arr.resize(j);
        arr.sort(compare);

        // Забираем из списка отправляемые элементы:
        // (При отправке список может измениться!)
        var a:Array<ILoader> = NativeJS.array(num);
        i = num;
        while (i-- > 0) {
            a[i] = arr[i];
            arr[i] = null; // <-- Удалится на следующей иттерации
        }

        // Безопасно инициируем запросы:
        while (num-- > 0) {
            if (arr[num].state == LoaderState.PENDING && arr[num].balancer == this)
                arr[num].loadStart();
        }
    }

    /**
     * Сортировка по приоритету.
     * @param x Загручзик 1.
     * @param y Загручзик 2.
     * @return Порядок в отсортированном массиве.
     */
    static private function compare(x:ILoader, y:ILoader):Int {
        if (x.priority > y.priority)
            return -1;
        if (x.priority < y.priority)
            return 1;
        return 0;
    }

    /**
     * Выполнить все запросы в очереди.  
     * Вызов этого метода приводит к мгновенной отправке всех запросов,
     * находящихся в данный момент в очереди.  
     * Очередь запросов очищается.
     */
    public function flush():Void {
        var i = 0;
        var l = len;
        var a = arr;

        arr = []; // <-- Список может измениться из-за вызова колбеков
        time = NativeJS.now();

        // Обновления не нужны:
        if (id != null) {
            untyped clearInterval(id);
            id = null;
        }

        // Безопасно инициируем запросы:
        while (i < l) {
            var l = a[i++];
            if (l != null && l.state == LoaderState.PENDING && l.balancer == this)
                l.loadStart();
        }
    }

    /**
     * Очистить балансировщик.
     * - У всех загрузчиков в очереди вызывается метод:
     *   `Loader.close()`.
     * - Уже выполняемые и завершённые запросы игнорируются.
     * - Очередь запросов очищается.
     */
    public function clear():Void {
        var i = 0;
        var l = len;
        var a = arr;

        arr = new Array(); // <-- Список может измениться из-за вызова колбеков

        // Обновления не нужны:
        if (id != null) {
            untyped clearInterval(id);
            id = null;
        }

        // Безопасно закрываем очередь:
        while (i < l) {
            var l = a[i++];
            if (l == null || l.state != LoaderState.PENDING)
                continue;
            l.close();
        }
    }

    /**
     * Добавить загрузчик в очередь на отправку.  
     * Регистрирует переданный загрузчик в очереди и
     * инициирует в будущем его загрузку. Этот метод
     * не выполняет никаких проверок и просто добавляет
     * переданный экземпляр в очередь.
     * - Этот метод должен вызываться только один раз, иначе будут
     *   дубли в очереди.
     * - Не забудьте удалить загрузчик из очереди, если его загрузку
     *   отменит пользователь вызовом метода: `Loader.close()`
     * @param loader Загрузчик.
     */
    @:allow(loader.ILoader)
    private function add(loader:ILoader):Void {
        arr.push(loader);
        if (rps > 0 && id == null)
            id = untyped setInterval(onUpdate, INTERVAL_TIME);
    }

    /**
     * Удалить загрузчик из очереди.  
     * Удаляет из очереди первый найденный экземпляр.
     * Этот метод не выполняет никаких дополнительных
     * действий.
     * @param loader Загрузчик.
     */
    @:allow(loader.ILoader)
    private function remove(loader:ILoader):Void {
        var i = len;
        while (i-- != 0) {
            if (arr[i] == loader) {
                arr[i] = null; // <-- Список перестроится при следующем обновлении
                return;
            }
        }
    }
}