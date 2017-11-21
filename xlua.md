[Back](index.md)

# XLua的使用

看到XLua有个优势是hotfix，可以用C#写全部的逻辑，出了问题就用lua代码替换掉，等下一次版本迭代在换回正确的C#代码，毕竟C#的效率比lua高得多，原理是通过特性标记然后在IL逻辑层判断修改逻辑。

对于lua的编译环境，xlua和ulua的思路差不多，都是有个全局的lua管理类，这里只说xlua，LuaEnv *TODO*。  
最简单的C#调用lua方式是：这句代码调用lua的print()函数，打印'hello world'。
``` csharp
private LuaEnv _luaState; // lua状态机，全局唯一
luaenv.DoString("print('hello world')")
```

#### C#访问lua

获取lua的全局变量
``` csharp
// LuaEnv.cs
public LuaTable Global
{
    get
    {
        return _G;
    }
}

luaenv.Global.Get<int>("a")
luaenv.Global.Get<string>("b")
luaenv.Global.Get<bool>("c")
```


LuaTable则继承LuaBase，LuaTable的构造里什么都没做，LuaBase的构造则是保存Lua的int引用，以及LuaEnv的实例
``` csharp
// LuaBase.cs
public LuaBase(int reference, LuaEnv luaenv)
{
    luaReference = reference;
    luaEnv = luaenv;
}

```


Get是void类型函数，通过第二个参数out将值返回到上一层，Get的两个参数TKey, TValue都支持泛型，在搜索的时候，找到这么一句：  
It is convention to use T for generic types (comparable with "templates" in C++ etc)  
T原本是C++的模板，到了C#里除了T，比如List<T>，微软给C#扩充了T的使用：
- 如果有多个泛型，可以加以区分，例如：TKey, TValue
- 如果是函数的参数，或者用于委托调用，可以: Func<T1, T2, TResult>
``` csharp
public void Get<TKey, TValue>(TKey key, out TValue value)
```

LuaEnv.cs的internal ObjectTranslator translator;干啥的？暂时不清楚



#### 特性标签
形如[LuaCallCSharp]这种特性标签，让Lua可以访问C#的自定义类，添加上特性标签后，程序在启动时会自动查找具有特性标记的类，然后收集入lua栈，使得可以用Lua访问自定义的C#类和方法。

本段代码改编截取自[这](http://gad.qq.com/article/detail/28172)
``` csharp
[LuaCallCSharp]
public class ClassA
{
    public static void HelloWorld()
    {
        Debug.Log("Hello Aladdin_XLua, I am static model function");
    }

    public void HelloWorld2()
    {
        Debug.Log("Hello Aladdin_XLua, I am model function");
    }
    public string HelloWorld3()
    {
        Debug.Log("Hello Aladdin_XLua, 我是具有返回值的CS方法:" + s);
        return "你好，我获得了lua，我是C#";
    }
}

using XLua;
public class ClassB : MonoBehaviour
{
    LuaEnv luaenv = new LuaEnv();
    void Start()
    {
        luaenv.DoString(@"
            -- Lua访问特性标记的对象方法

            local luaC2 = CS.ClassA
            local luaO2 = luaC2

            luaC2:HelloWorld()
            luaO2:HelloWorld2()
            luaO2:HelloWorld3()
        ");
    }
}
```

对于命名空间内的类引用，其实就是CS.namespace.className，多了个引用层级，用法和直接CS.className一样。

``` csharp
namespace NameSpace
{
    public class ClassC
    {
        public void SayHello()
        {
            Debug.Log("Hello nameSpace");
        }
    }
}
```
在Lua中调用上面的方法，则是：
``` lua
local luaMethod = CS.NameSpace.ClassC
local luaObj = luaMethod()
luaObj:SayHello()
```


#### 绑定函数
xlua支持把一个lua函数绑定到C# delegate。
这段代码把lua的math.max绑定到C#的max变量后，就和一个C#函数调用差不多，而且*执行了XLua/GenerateCode*后，调用max(32, 12)是*不产生C# gc alloc！*

``` csharp
[XLua.CSharpCallLua]
public delegate double LuaMax(double a, double b);

var max = luaenv.Global.GetInPath<LuaMax>("math.max");
Debug.Log("max:" + max(32, 12));
```


#### 打补丁
Hoxfix是xlua一手好牌，可以用lua函数替换掉C#的构造函数、函数、属性、事件。lua实现都是函数，比如属性对于一个getter函数和一个setter函数，事件对应一个add函数和一个remove函数。

[xlua使用指南](https://github.com/Tencent/xLua/blob/master/Assets/XLua/Doc/hotfix.md)

``` csharp
public class ClassD<T> {}

// 对ClassD打补丁
luaenv.DoString(@"
    xlua.hotfix(CS['ClassD'1[System.int]'], {
        -- 构造函数
        ['.ctor'] = function(obj, a)
            print('ClassD<int>', obj, a)
        end;    -- 这里理论有没有分号都可以
        Func1 = function(obj)
            print('ClassD<ing>.Func1', obj)
        end;
        Func2 = function(obj)
            print('ClassD<int>.Func2', obj)
            return 1234
        end
    })
");
```
里面用xlua可识别的格式填充了代码，同理也是可以替换掉原先的代码，只走lua的实现。