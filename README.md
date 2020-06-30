# Haxe HTTP/S Клиент для браузера и NodeJS

Описание
------------------------------

HaxeLoader - Это маленькая библиотека для выполнения HTTP/S запросов из среды браузера или NodeJS в едином стиле.
Этот интерфейс описывает общий API для выполнения запросов из любой среды и предоставляет реализацию этого интерфейса для каждой из этих сред.

Дизайн этой библиотеки схож с дизайном Flash URLLoader.

Как использовать
------------------------------

```
// Запрос в NodeJS:
var loader:Loader = new LoaderNodeJS();
loader.load(new Request("https://google.com"));
loader.onComplete = function(loader){ trace(loader.error); trace(loader.data); };

// Запрос в браузере:
var loader:Loader = new LoaderBrowser();
loader.load(new Request("https://google.com"));
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