package loader;

/**
 * Формат данных.  
 * Используется для указания типа принимаемых
 * данных от удалённого сервера.
 */
@:dce
enum abstract DataFormat(String) to String from String
{
    /**
     * Текстовые данные.
     */
    var TEXT = "text";

    /**
     * Необработанные, двоичные данные.
     */
    var BINARY = "binary";

    /**
     * JavaScript Объект, полученный в
     * результате разбора JSON строки.
     */
    var JSON = "json";
}