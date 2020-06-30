package loader;

/**
 * Формат данных.
 */
@:enum abstract DataFormat(String) to String
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
     * JavaScript Объект, полученный в результате разбора JSON строки.
     */
    var JSON = "json";
}