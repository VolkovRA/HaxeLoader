package;

import loader.Loader;
import loader.Request;
#if nodejs
import loader.nodejs.LoaderNodeJS;
#else
import loader.browser.LoaderBrowser;
#end

/**
 * Пример использования.
 */
class Main
{
    private var loader:Loader;

    /**
     * Точка входа.
     */
    public static function main() {
        #if nodejs
        // Тест в NodeJS:
        var loader:Loader = new LoaderNodeJS();
        loader.load(new Request("https://google.com"));
        loader.onComplete = function(loader){ trace(loader.error); trace(loader.data); };
        #else
        // Тест в браузере:
        var loader:Loader = new LoaderBrowser();
        loader.load(new Request("https://127.0.0.1:8080/time"));
        loader.onComplete = function(loader){ trace(loader.error); trace(loader.data); };
        #end
    }
}