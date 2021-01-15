# Haxe HTTP/S клиент

Зачем это надо
------------------------------

Позволяет выполнять запросы в едином стиле, независимо от Вашей среды исполнения. Позволяет в некоторых случаях (В браузере), выбирать реализацию для выполнения запроса: [XMLHttpRequest](https://developer.mozilla.org/ru/docs/Web/API/XMLHttpRequest), [JSONP](https://en.wikipedia.org/wiki/JSONP), [fetchAPI](https://developer.mozilla.org/ru/docs/Web/API/Fetch_API) *(Пока не реализован)*.

Библиотека унифицирует API интерфейс для выполнения HTTP/S запросов и предлагает его реализацию для каждой конкретной платформы и протокола. Вы можете ипсользовать единый интерфейс независимо от среды исполнения. 

Дизайн этого API схож с [URLLoader](https://help.adobe.com/ru_RU/FlashPlatform/reference/actionscript/3/flash/net/URLLoader.html). Возможно, вам это знакомо.

Как использовать
------------------------------

```
// Запрос в NodeJS:
var loader:Loader = new LoaderNodeJS();
loader.load({ url:"https://google.com" });
loader.onComplete = function(loader){ trace(loader.error); trace(loader.data); };

// Запрос в браузере:
var loader:Loader = new LoaderBrowser();
loader.load({ url:"https://google.com" });
loader.onComplete = function(loader){ trace(loader.error); trace(loader.data); };
```

Добавление библиотеки
------------------------------

1. Установите haxelib себе на локальную машину, чтобы вы могли использовать библиотеки Haxe.
2. Установите loader себе на локальную машину, глобально, используя cmd:
```
haxelib git loader https://github.com/VolkovRA/HaxeLoader master
```
Синтаксис команды:
```
haxelib git [project-name] [git-clone-path] [branch]
haxelib git minject https://github.com/massiveinteractive/minject.git         # Use HTTP git path.
haxelib git minject git@github.com:massiveinteractive/minject.git             # Use SSH git path.
haxelib git minject git@github.com:massiveinteractive/minject.git v2          # Checkout branch or tag `v2`.
```
3. Добавьте библиотеку loader в ваш Haxe проект.

Дополнительная информация:
 * [Документация Haxelib](https://lib.haxe.org/documentation/using-haxelib/ "Using Haxelib")
 * [Документация компилятора Haxe](https://haxe.org/manual/compiler-usage-hxml.html "Configure compile.hxml")