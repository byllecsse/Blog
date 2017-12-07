[Back](index.md)

# Lua handler

将Lua对象及其方法包装成一个匿名函数，比如：
self.container.refreshCallback = handler(self, self.UpdateItem)

其实不大懂，已经有匿名方法的使用，完全可以将方法作为参数传递给下层级调用，都不需要C#中委托的实现，非常简单的就传递了方法，lua 方法的本质是table，table的传递就和变量一样，为何还会有handler.

handler的源码：
``` lua
function handler(obj, method)
    return function(...)
        return method(obj, ...)
    end
end
```

发现handler通过接收两个参数：obj, method，创建了一个匿名函数并且将其返回，调用匿名函数所传入的参数，将其也传入method方法中，作为obj后面使用的参数。


**举个例子**
``` lua
local cls = {}
cls._m = "close"

function cls:onClose()
    print(self._m)
end

handler(cls, cls.onClose)()
```
结果为：close

来解释下~通过handler将cls作为cls.onClose的第一个参数传入，执行返回的匿名函数等价于cls.onClose(cls)，由于传入的参数就是本身，所以handler(cls, cls.onClose)()本身就相当于cls:onClose()，最后的打印时close


**稍微复杂点的用法**
``` lua
handler("hello", handler(cls, cls.onClose))("world")
```
先将这行代码转换一下handler("hello, cls:onClose())("world");
http://forum.cocos.com/t/lua-handler/21885

