package;

import loader.Balancer;
import loader.ILoader;
import loader.Request;

/**
 * Пример использования.
 */
class Main
{
    private var lr:ILoader;

    /**
     * Точка входа.
     */
    public static function main() {
        var balancer = new Balancer();
        balancer.rps = 1;

        var url:String = "https://google.com";
        var len:Int = 10;

        // Тест NodeJS:
        #if nodejs
        var i = len;
        while (i-- > 0) {
            var lr:ILoader = new loader.nodejs.LoaderNodeJS();
            lr.balancer = balancer;
            //lr.priority = len;
            lr.onComplete = function(lr){ trace(balancer.length, lr.error, lr.data); };
            lr.load(new Request(url));
        }
        #end

        // Тест XmlHttpRequest:
        #if xhr
        var i = len;
        while (i-- > 0) {
            var lr:ILoader = new loader.xhr.LoaderXHR();
            lr.balancer = balancer;
            //lr.priority = len;
            lr.onComplete = function(lr){ trace(balancer.length, lr.error, lr.data); };
            lr.load(new Request(url));
        }
        #end

        // Тест JSONP:
        #if jsonp
        var i = len;
        while (i-- > 0) {
            var req = new Request("https://api.vk.com/method/friends.get"); // VK Отдаёт JSONP
            //var req = new Request("https://asdasasdad3d.com/method/friends.get"); // Запрос с ошибкой
            req.data = "user_id=33092628&v=5.120&access_token=9025954fb55fdb4be0ac6028a2cd9e5944e0fc7e5e44b4ae1dc46307d243336b08d0c9030f9fc7cbfc913";

            var lr:ILoader = new loader.jsonp.LoaderJSONP();
            lr.balancer = balancer;
            //lr.priority = len;
            lr.onComplete = function(lr){ trace(balancer.length, lr.error, lr.data); };
            lr.load(req);
        }
        #end
    }
}