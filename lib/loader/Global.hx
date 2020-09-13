package loader;

import haxe.extern.EitherType;
import haxe.extern.Rest;
#if nodejs
import js.node.Timers.Timeout;
#end

/**
 * Глобальная область видимости.  
 * Класс представляет глобальное пространство видимости на целевой платформе:
 * - Объект `global` - в NodeJS.
 * - Объект `window` - в браузере.
 * 
 * Содержит различные публичные API этих целевых платформ. Haxe не поддерживает
 * глобальные функций, поэтому, все обращения должны происходить через класс.
 */
#if nodejs
@:native("global")
#else
@:native("window")
#end
extern class Global
{
    
    /**
     * Запланировать **регулярный** вызов функции с заданной периодичностью.
     * @param callback Функция для вызова по истечении таймера.
     * @param delay Количество миллисекунд ожидания до вызова callback.
     * @param args Необязательные аргументы для передачи в callback.
     * @return Возвращает идентификатор для использования в `clearInterval()`.
     * @see Документация: https://www.w3schools.com/jsref/met_win_setinterval.asp
     * @see Документация: https://nodejs.org/api/timers.html#timers_setinterval_callback_delay_args
     */
    #if nodejs
    static public function setInterval(callback:Dynamic, delay:Int, args:Rest<Dynamic>):Timeout;
    #else
    static public function setInterval(callback:Dynamic, delay:Int, args:Rest<Dynamic>):Int;
    #end

    /**
     * Отменить запланированный ранее регулярный вызов функции.
     * @param timeout Значение, возвращаемое функцией: `setInterval()`.
     * @see Документация: https://www.w3schools.com/jsref/met_win_clearinterval.asp
     * @see Документация: https://nodejs.org/api/timers.html#timers_clearinterval_timeout
     */
    #if nodejs
    static public function clearInterval(timeout:Timeout):Timeout;
    #else
    static public function clearInterval(timeout:Int):Int;
    #end
}

/**
 * Описание внешнего интерфейса JSON, доступного в JS рантайме.
 * Содержит методы для удобной работы с JSON.
 * 
 * @see https://developer.mozilla.org/ru/docs/Web/JavaScript/Reference/Global_Objects/JSON
 */
@:native("JSON")
extern class JSON 
{
    /**
     * Прочитать JSON.  
     * Разбирает строку JSON, возможно с преобразованием получаемого
     * значения и его свойств и возвращает разобранное значение.
     * Выбрасывает исключение SyntaxError, если разбираемая строка
     * не является правильным JSON.
     * @param text      Разбираемая строка JSON.
     *                  Смотрите документацию по объекту JSON для описания синтаксиса JSON.
     * @param reviver   Если параметр является функцией, определяет
     *                  преобразование полученного в процессе разбора значения,
     *                  прежде, чем оно будет возвращено вызывающей стороне.
     * @return Возвращает объект `Object`, соответствующий переданной строке JSON text.
     */
    static public function parse(text:String, ?reviver:Dynamic->Dynamic->String):Dynamic;

    /**
     * Записать JSON.  
     * Возвращает строку JSON, соответствующую указанному значению,
     * возможно с включением только определённых свойств или с заменой
     * значений свойств определяемым пользователем способом.
     * 
     * @param   value       JavaScript Объект.
     * @param   replacer    Если является функцией, преобразует значения
     *                      и свойства по ходу их преобразования в строку.
     *                      Если является массивом, определяет набор свойств,
     *                      включаемых в объект в окончательной строке.
     * @param   spac        Используется для управления форматированием отступов
     *                      в конечной строке. Если он числовой, каждый последующий
     *                      уровень вложенности будет дополнен отступом из пробелов,
     *                      количество которых соответствует уровню (вплоть до
     *                      десятого уровня). Если он строковый, каждый последующий
     *                      уровень вложенности будет предваряться этой строкой (или
     *                      её первыми десятью символами).
     * @return Возвращает строку в формате JSON.
     */
    static public function stringify(value:Dynamic, ?replacer:EitherType<Dynamic->Dynamic->String,Array<String>>, ?space:EitherType<String,Int>):String;
}