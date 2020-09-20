package loader.parser;

import js.Syntax;

#if nodejs
import js.node.Buffer;
#end

/**
 * Парсер данных для MIME типа: `application/x-www-form-urlencoded`  
 * Полезен для отправки запросов с произвольным набором значений.
 * 
 * Этот парсер упаковывает переданный объект JavaScript в набор пар:
 * *ключ=значение* и с использованием URI кодировки. Вложенные объекты
 * не поддерживаются. Значениями свойств объекта должны быть простые типы
 * или двоичные данные.
 * 
 * Разница между `application/x-www-form-urlencoded` и `multipart/form-data`:
 * 1. `application/x-www-form-urlencoded` при кодировании **двоичных** данных
 *    использует 3 байта на 1 исходный. Байты преобразуются в URI из 3
 *    символов ASCII на байт. `multipart/form-data` отправляет байты *как есть*.
 * 2. `multipart/form-data` Позволяет указать MIME тип отдельно для каждого
 *    отправляемого значения. Это может быть полезно для двоичных данных.
 * 3. `multipart/form-data` Имеет дополнительные накладные расходы на объём
 *    тела сообщения для указания разделителей и т.п.
 * 
 * *Из спецификации:  
 * Тип содержимого application/x-www-form-urlencoded неэффективен для
 * отправки больших объемов двоичных данных или текста, содержащего символы,
 * отличные от ASCII. Тип содержимого multipart/form-data следует
 * использовать для отправки форм, содержащих файлы, данные, отличные от
 * ASCII и двоичные данные.  
 * https://www.w3.org/TR/html401/interact/forms.html*
 * 
 * Пример использования:
 * ```
 * var req = new Request();
 * req.method = Method.POST;
 * req.data = XWWWForm.write({ id:1, name:"Galya принеси мне пива!", admin:true, bytes:Buffer.allocUnsafe(10) });
 * ```
 * 
 * Пример кодирования отдельных значений:
 * ```
 * trace(XWWWForm.encode(null)); // 
 * trace(XWWWForm.encode(1)); // 1
 * trace(XWWWForm.encode(true)); // true
 * trace(XWWWForm.encode("a=?b")); // a%3D%3Fb
 * trace(XWWWForm.encode("\"-_.!~*' ()")); // %22-_.%21~%2a%27+%28%29
 * trace(XWWWForm.encode("Hello world!")); // Hello+world%21
 * trace(XWWWForm.encode("\n+Привет дивный мир!")); // %0A%2B%D0%9F%D1%80%D0%B8%D0...
 * trace(XWWWForm.encode(Buffer.from(" \r\nHello world!"))); // %20%0D%0A%48%65%6C...
 * trace(XWWWForm.encode(Buffer.allocUnsafe(20))); // %00%00%00%00%00%00%00%00%31...
 * ```
 * 
 * Статический класс.
 */
@:dce
class XWWWForm
{
    /**
     * Записать данные в формате: `application/x-www-form-urlencoded`  
     * Принимает на вход простой JavaScript объект и формирует строку
     * с данными свойств этого объекта: *ключ1=значение1&ключ2=значение2* и т.д.  
     * Многоуровневая вложенность не поддерживается.
     * @param params Упаковываемые значения.
     * @return Строка с данными в формате URI.
     */
    static public function write(params:Dynamic):String {
        if (params == null)
            return "";

        var key:Dynamic = null;
        var parts = new Array<String>();
        Syntax.code('for ({0} in {1}) {', key, params);
            parts.push(encode(key) + "=" + encode(params[key]));
        Syntax.code('}');
        return parts.join("&");
    }

    /**
     * Получить значение заголовка для: `Request.contentType`  
     * Это просто синтаксический сахар для удобства и чтобы ничего не забыть.  
     * Функция встраивается в точку вызова для ускорения работы.
     * @return Значение заголовка для свойства: `Request.contentType`
     */
    inline static public function getContentType():String {
        return 'application/x-www-form-urlencoded';
    }

    /**
     * Кодирование данных для их отправки с помощью: `application/x-www-form-urlencoded`  
     * Эта функция преобразует переданные данные в безопасную строку
     * согласно спецификации.  
     * Может поддерживать упаковку двоичных данных.
     * @param value Кодируемое значение.
     * @return Закодированное значение.
     * @see https://www.w3.org/TR/html401/interact/forms.html
     */
    static public function encode(value:Dynamic):String {
        var str = "";
        if (value == null)
            return str;

        #if nodejs
        // Двоичные данные кодируем без модификаций, чтоб проще было
        // потом их читать:
        if (Buffer.isBuffer(value)) {
            var i = 0;
            var len = value.length;
            while (i < len) {
                var byte = value[i++];
                if (byte < 0x10)
                    str += "%0" + untyped byte.toString(16).toUpperCase();
                else
                    str += "%" + untyped byte.toString(16).toUpperCase();
            }
            return str;
        }
        #end

        // Простые типы данных
        // Приводим к строке и кодируем в соответствии с форматом:
        str = Syntax.code('encodeURIComponent({0} + "")', value);
        
        // Замена пробела на +
        str = Syntax.code('{0}.replace(/%20/g, "+")', str); 

        // Строгое соблюдение RFC 3986, который резервирует: !'()*
        str = Syntax.code("{0}.replace(/[!'()*]/g, function(c){ return '%' + c.charCodeAt(0).toString(16); })", str);

        return str;
    }
}