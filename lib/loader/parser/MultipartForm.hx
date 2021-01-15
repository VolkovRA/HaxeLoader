package loader.parser;

import js.lib.Error;
import tools.NativeJS;

#if nodejs
import js.node.Buffer;
#end

/**
 * Парсер данных для MIME типа: `multipart/form-data`  
 * Полезен для отправки запросов с произвольным набором значений.
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
 * // Данные формы:
 * var bnd = MultipartForm.getBoundary();
 * var form:Array<FormItem> = [
 *      { name:"id", data:1, contentType:"text/plain" },
 *      { name:"message", data:"Привет!", filename:"Кукушка на сене.txt" },
 * ];
 * 
 * // Параметры запроса:
 * var req = new Request();
 * req.method = Method.POST;
 * req.contentType = MultipartForm.getContentType(bnd);
 * req.data = MultipartForm.write(form, bnd);
 * ```
 * 
 * Статический класс.
 */
@:dce
class MultipartForm
{
    /**
     * Записать данные формы в формате: `multipart/form-data`.
     * @param items Список отправляемых данных.
     * @param boundary Используемый разделитель. См.: `getBoundary()`
     * @return Двоичные данные для отправки.
     * @throws Error Разделитель не должен быть `null` или пустой строкой.
     */
    static public function write(items:Array<FormItem>, boundary:String):Dynamic {
        if (boundary == null)
            throw new Error("Boundary cannot be null");
        if (boundary == "")
            throw new Error("Boundary cannot be empty string");

        #if nodejs
        // NodeJS:
        var len:Int = items==null?0:items.length;
        var arr:Array<Buffer> = NativeJS.array(len);
        var i:Int = 0;
        while (i < len) {
            var item = items[i];
            if (item == null) {
                i ++;
                continue;
            }

            arr[i++] = Buffer.concat([
                Buffer.from(
                    '\r\n--' + boundary +
                    '\r\nContent-Disposition: form-data; name="' + item.name + '"' + (item.filename==null?'':('; filename="' + item.filename + '"')) +
                    (item.contentType==null?'':('\r\nContent-Type: ' + item.contentType)) +
                    '\r\n\r\n'
                ),
                Buffer.isBuffer(item.data)?item.data:Buffer.from(NativeJS.str(item.data)),
            ]);
        }
        if (arr.length != 0)
            arr.push(Buffer.from('\r\n--' + boundary + "--"));
        return Buffer.concat(arr);
        #else
        return null;
        #end
    }

    /**
     * Таблица символов, используемых при генерации *boundary*.
     */
    static public var boundaryChars(default, null) = [
        '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f',
        'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v',
        'w', 'x', 'y', 'z', 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L',
        'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z'
    ];

    /**
     * Получить новый разделитель тела сообщений. (boundary)  
     * Это используется для отправки составных сущностей, форм, которые
     * могут содержать не только текстовые, но и бинарные данные.
     * @return Новенький, случайный boundary!
     * @see Документация: https://developer.mozilla.org/ru/docs/Web/HTTP/%D0%97%D0%B0%D0%B3%D0%BE%D0%BB%D0%BE%D0%B2%D0%BA%D0%B8/Content-Type
     */
    static public function getBoundary():String {
        var len:Int = Math.floor(Math.random() * 15 + 15);
        var len2:Int = boundaryChars.length;
        var arr:Array<String> = NativeJS.array(len);
        var i = 0;
        while (i < len)
            arr[i++] = boundaryChars[Math.floor(Math.random() * len2)];
        return "-------" + arr.join("");
    }

    /**
     * Получить значение заголовка для: `Request.contentType`  
     * Это просто синтаксический сахар для удобства и чтобы ничего не забыть.  
     * Функция встраивается в точку вызова для ускорения работы.
     * @param boundary Используемый разделитель.
     * @return Значение заголовка для свойства: `Request.contentType`
     */
    inline static public function getContentType(boundary:String):String {
        return 'multipart/form-data; boundary="' + boundary + '"';
    }
}

/**
 * Данные на форме.  
 * Объект описывает один атрибут с данными и их типом для отправки
 * в запросе `multipart/form-data`.  
 */
typedef FormItem =
{
    /**
     * Отправляемые данные.  
     * Это должен быть простой тип данных или двоичный, специфичный
     * для текущего окружения. (Buffer в NodeJS)
     */
    var data:Dynamic;

    /**
     * Имя поля на форме.
     */
    var name:String;

    /**
     * Имя файла.  
     * Актуально при отправке двоичных данных, например.
     */
    @:optional var filename:String;

    /**
     * MIME Тип содержимого.  
     * Позволяет задать заголовок `Content-Type` для этого поля.  
     * По умолчанию: `null` (Заголовок не указывается)
     */
    @:optional var contentType:String;
}