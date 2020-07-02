package;

import loader.Balancer;
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
        var balancer = new Balancer();
        balancer.rps = 1;

        var url:String = "http://google.com";
        var len:Int = 10;

        #if nodejs
        // Тест в NodeJS:
        while (len-- > 0) {
            var loader:Loader = new LoaderNodeJS();
            loader.balancer = balancer;
            //loader.priority = len;
            loader.onComplete = function(loader){ trace(balancer.length, loader.error, loader.data); };
            loader.load(new Request(url));
        }
        #else
        // Тест в браузере:
        while (len-- > 0) {
            var loader:Loader = new LoaderBrowser();
            loader.balancer = balancer;
            //loader.priority = len;
            loader.onComplete = function(loader){ trace(balancer.length, loader.error, loader.data); };
            loader.load(new Request(url));
        }
        #end
    }
}