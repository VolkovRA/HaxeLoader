package;

import loader.Method;
import loader.ILoader;
import loader.Request;
import loader.xhr.LoaderXHR;

/**
 * Тест XHR загрузчика.
 */
class TestXHR
{
    /**
     * Точка входа.
     */
    static public function main() {
        trace("TestXHR");

        var req1:Request = {};
        req1.url = "https://google.com/";
        req1.method = Method.POST;
        req1.query = { id:1, name:"Вася", family:"Crossider" };
        req1.body = { id:1, name:"Вася", family:"Crossider" };

        var l1:ILoader = new LoaderXHR();
        l1.onComplete = function(l){ trace(l.error, l.data); };
        l1.load(req1);
    }
}