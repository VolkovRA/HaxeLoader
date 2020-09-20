package loader;

/**
 * HTTP Заголовок.  
 * Этот объект описывает одиночный заголовок, используемый
 * в клиент-серверных HTTP/S запросах. Содержит имя и значение.
 */
typedef Header =
{
    /**
     * Имя заголовка HTTP-запроса.  
     * Пример: `Content-Type` или `SOAPAction`.
     */
    var name:String;

    /**
     * Значение, связанное со свойством: `name`  
     * Пример: `text/plain`.
     */
    var value:String;
}