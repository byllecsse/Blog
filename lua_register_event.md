[Back](index.md)

# lua class自动注册控件

lua中凡事都是table，既然是table就可以遍历查找，本文记录的自动注册也是基于这种思想。
然后lua的type()用于区分boolean, number, string, function，不过lua是弱类型的，不能区分int, float, double，所有的数值类型统称为number。

类型中还有个神奇的userdata, lua对此的解释是：
Our first concern is how to represent array values in Lua. Lua provides a basic type specifically for this: userdata. A userdatum offers a *raw memory* area with no predefined operations in Lua.


``` lua
print(type(2))      --> number
print(type(1+5))    --> number
print(type("hello"))        --> string
print(type('world'))        --> string
print(type(print))          --> function
print(type(type))           --> function

func = print("hello world")
print(type(func))           --> function

print(type(nil))        --> nil
print(type(type(X)))    --> string
```

使用这种特性，我可以找出这个类（同时也是表）中的所有元素，用type() = function区分出函数，再定义一定的规则，比如OnEvent_ClickButton，就可以实现在其他类中对这些函数的调用，作用和注册事件是一个方式。

这段代码用迭代器遍历整个类，控制条件找出带下划线且不以下划线开头的函数，判断函数的event类型，比如OnClick, OnDoubleClick, OnLongClick, OnValueChange，将函数用一个表保存，以事件方式使用。

``` lua
-- 注册控件的事件，这个只在界面创建的时候会调用
function Window:_RegisterUIEvent(cls)
    -- 遍历类中定义的函数
    for c,v in pairs(cls) do
        if type(v) == 'function' and string.find(c, '_') and not string.startswith(c, '_') then
            local event = string.sub(c, 1, string.find(c, '_') - 1)
            local ctrl = string.sub(c, string.find(c, '_') + 1, #c)
            if event == 'OnClick' or event =='OnDoubleClick' or event =='OnLongClick' or event == 'OnValueChanged' then
                if self[event] ~= nil then
                    self[event](self, ctrl, self, self[c]) -- here
                end
            end
        end
    end

    -- 注册基类的函数
    local super = cls.super
    if super and super.__cname and super.__cname ~= 'Window' then
        self:_RegisterUIEvent(super)
    end
end

-- 注册事件 在ui中实现对应函数则自动注册相应事件，函数的形式是  OnXXX_CtrlName
-- 如果是事件的话，要以OnEvent_开头，如果是控件的话，是什么事件就以对应的注册函数开头，例如按钮点击就是OnClick_
function Window:_RegisterEvent(cls)
    -- 遍历类中定义的函数
    for c,v in pairs(cls) do
        if type(v) == 'function' and string.find(c, '_') and not string.startswith(c, '_') then
            local event = string.sub(c, 1, string.find(c, '_') - 1)
            local ctrl = string.sub(c, string.find(c, '_') + 1, #c)
            if event == 'OnEvent' then
                if self[event] ~= nil then
                    self[event](self, ctrl, self, self[c])
                end
            end
        end
    end

    -- 注册基类的函数
    local super = cls.super
    if super and super.__cname and super.__cname ~= 'Window' then
        self:_RegisterEvent(super)
    end
end
```


### userdata
这玩意[lua.org](https://www.lua.org/pil/28.1.html)倒是讲了很多，不过看不懂，以后补充吧。

``` lua
if paramType == 'userdata' then
    local go
    if GetType(visibleOrName) == 'UnityEngine.GameObject' then
        go = visibleOrName
    else
        go = visibleOrName.gameObject
    end
end
```