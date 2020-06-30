package loader;

import js.Syntax;

/**
 * Вспомогательные утилиты.
 */
class Utils
{
    /**
     * Строговое равенство. (`===`).
     * 
     * Возможность использовать в Haxe чуть более быстрое сравнение JavaScript без авто-приведения типов.
     * Генерирует оптимальный JS код и встраивается в точку вызова.
     * 
     * @param v1 Значение 1.
     * @param v2 Значение 2.
     * @return Результат сравнения.
     */
    static public inline function eq(v1:Dynamic, v2:Dynamic):Bool {
        return Syntax.code('({0} === {1})', v1, v2);
    }

    /**
     * Закодировать URL адрес безопасными символами.
     * 
     * Функция представляет собою нативный вызов JS: `encodeURI()`.
     * 
     * @param v Небезопасный URL Адрес.
     * @return Безопасный URL Адрес.
     * @see encodeURI() https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/encodeURI
     */
    static public inline function encodeURI(v:String):String {
       return Syntax.code('encodeURI({0})', v); 
    }
    
    /**
     * Раскодировать URL адрес, закодированный ранее при помощи: `encodeURI()`.
     * 
     * Функция представляет собою нативный вызов JS: `decodeURI()`.
     * 
     * @param v Закодированный URL Адрес.
     * @return Раскодированный URL Адрес.
     * @see decodeURI() https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/decodeURI
     */
    static public inline function decodeURI(v:String):String {
        return Syntax.code('decodeURI({0})', v); 
    }
}