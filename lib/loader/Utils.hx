package loader;

import js.Syntax;

/**
 * Вспомогательные утилиты.
 */
@:dce
class Utils
{
    /**
     * Таблица символов, используемых при генерации *boundary*.
     */
    static private var boundaryChars = [
        '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f',
        'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v',
        'w', 'x', 'y', 'z', 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L',
        'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z'
    ];

    /**
     * Получить новый разделитель тела для HTTP сообщений. (boundary)  
     * Это используется для отправки составных сущностей, форм, которые
     * могут содержать не только текстовые, но и бинарные данные.
     * @return Новенький, случайный boundary!
     * @see Документация: https://developer.mozilla.org/ru/docs/Web/HTTP/%D0%97%D0%B0%D0%B3%D0%BE%D0%BB%D0%BE%D0%B2%D0%BA%D0%B8/Content-Type
     */
    static public function createBoundary():String {
        var len:Int = Math.floor(Math.random() * 15 + 15);
        var len2:Int = boundaryChars.length;
        var arr:Array<String> = createArray(len);
        var i = 0;
        while (i < len)
            arr[i++] = boundaryChars[Math.floor(Math.random() * len2)];

        return "---------------" + arr.join("");
    }

    /**
     * Строговое равенство. (`===`).  
     * Возможность использовать в Haxe чуть более быстрое сравнение JavaScript без авто-приведения типов.
     * Генерирует оптимальный JS код и встраивается в точку вызова.
     * @param v1 Значение 1.
     * @param v2 Значение 2.
     * @return Результат сравнения.
     */
    static public inline function eq(v1:Dynamic, v2:Dynamic):Bool {
        return Syntax.code('({0} === {1})', v1, v2);
    }

    /**
     * Строговое неравенство. (`!==`).  
     * Возможность использовать в Haxe чуть более быстрое сравнение JavaScript без авто-приведения типов.
     * Генерирует оптимальный JS код и встраивается в точку вызова.
     * @param v1 Значение 1.
     * @param v2 Значение 2.
     * @return Результат сравнения.
     */
    static public inline function noeq(v1:Dynamic, v2:Dynamic):Bool {
        return Syntax.code('({0} !== {1})', v1, v2);
    }

    /**
     * Закодировать URL адрес безопасными символами.  
     * Функция представляет собою нативный вызов JS: `encodeURI()`.
     * @param v Небезопасный URL Адрес.
     * @return Безопасный URL Адрес.
     * @see encodeURI() https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/encodeURI
     */
    static public inline function encodeURI(v:String):String {
       return Syntax.code('encodeURI({0})', v); 
    }
    
    /**
     * Приведение к: `String`   
     * Нативное JavaScript приведение любого значения к строке.
     * @param v Значение.
     * @return Строка.
     */
    static public inline function str(v:Dynamic):String {
        return Syntax.code("({0} + '')", v);
    }

    /**
     * Раскодировать URL адрес, закодированный ранее при помощи: `encodeURI()`  
     * Функция представляет собою нативный вызов JS: `decodeURI()`
     * @param v Закодированный URL Адрес.
     * @return Раскодированный URL Адрес.
     * @see decodeURI() https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/decodeURI
     */
    static public inline function decodeURI(v:String):String {
        return Syntax.code('decodeURI({0})', v); 
    }

    /**
     * Получить время, прошедшее с момента запуска приложения. (mc)
     * @see https://developer.mozilla.org/en-US/docs/Web/API/Performance/now
     */
    public static inline function stamp():Float {
        return Syntax.code('Date.now()');
    }

    /**
     * Нативная JavaScript реализация: `parseInt()`  
     * Функция принимает строку в качестве аргумента и возвращает целое число в
     * соответствии с указанным основанием системы счисления.
     * @param v     Значение, которое необходимо проинтерпретировать. Если значение параметра
     *              не принадлежит строковому типу, оно преобразуется в него (с помощью абстрактной операции ToString).
     *              Пробелы в начале строки не учитываются.
     * @param base  Целое число в диапазоне между `2` и `36`, представляющее собой основание системы
     *              счисления числовой строки string, описанной выше. В основном пользователи используют
     *              десятичную систему счисления и указывают `10`. Всегда указывайте этот параметр,
     *              чтобы исключить ошибки считывания и гарантировать корректность исполнения и предсказуемость
     *              результата. Когда основание системы счисления не указано, разные реализации могут
     *              возвращать разные результаты.
     * @return      Целое число, полученное парсингом (разбором и интерпретацией) переданной строки.
     *              Если первый символ не получилось сконвертировать в число, то возвращается `NaN`. 
     */
    public static inline function parseInt(v:Dynamic, base:Int):Int {
        return Syntax.code('parseInt({0}, {1})', v, base);
    }
    
    /**
     * Создать обычный JavaScript массив заданной длины.  
     * По сути, является аналогом для использования конструктора: `new Vector(length)`  
     * Полезно для разового выделения памяти нужной длины.
     * @param length Длина массива.
     * @return Новый массив заданной длины.
     */
    public static inline function createArray(length:Int):Dynamic {
        return Syntax.code('new Array({0})', length);
    }

    /**
     * Удалить свойство.  
     * Генерирует JS код: `delete obj.property`.
     * @param property Удаляемое свойство.
     */
    public static inline function delete(property:Dynamic):Void {
        Syntax.code("delete {0}", property);
    }

    /**
     * Проверка значения на тип: `String`  
     * Возвращает `true`, если переданное значение является JavaScript строкою.
     * @param v Проверяемое значение.
     * @return Возвращает `true`, если переданное значение является JavaScript строкою.
     */
    public static inline function isString(v:Dynamic):Bool {
        return Syntax.code('(typeof {0} === "string")', v);
    }

    /**
     * Проверка значения на тип: `Object`  
     * Возвращает `true`, если переданное значение является JavaScript объектом или `null`.
     * @param v Проверяемое значение.
     * @return Возвращает `true`, если переданное значение является JavaScript объектом или `null`.
     */
    public static inline function isObject(v:Dynamic):Bool {
        return Syntax.code('(typeof {0} === "object")', v);
    }
}