[back](index.md)

# 深入理解C#(第三版)-Lambda表达式 学习笔记

Lambda表达式是C# 3提供的一种用来创建委托实例的方式，它可以看作是C# 2匿名方法的一种演变，相比于匿名方法，Lambda表达式更加简单、通俗。

.NET 3.5的_System_命名空间中，有五个泛型_Func_的委托类型：
- TResult Func<TResult>()
- TResult Func<T,TResult>(T arg)
- TResult Func<T1,T2,TResult>(T1 arg1, T2 arg2)
- TResult Func<T1,T2,T3,TResult>(T1 arg1, T2 arg2, T3 arg3)
- TResult Func<T1,T2,T3,T4,TResult>(T1 arg1, T2 arg2, T3 arg3, T4 arg4)

比方说：Func<string, double, int>的委托形式是
public delegate int SomeDelegate(string arg1, double arg2)

*用匿名方法来创建委托实例*
``` csharp
Func<string, int> returnLength;
returnLength = delegate(string text)
{
	return text.Length;
}

Console.WriteLine(returnLength("Hello"));
```

Lambda表达式在设置按钮监听的时候也非常简洁
``` csharp
Button button = new Button{Test = "Click me"};
button.Click += (src, e) => Log("Click", src, e);
button.KeyPress += (src, e) => Log("KeyPress", src, e);
```
使用Lambda表达式将事件名称和事件参数传给记录事件细节的Log方法，我们对属性描述符使用了反射技术，从而展示了传递EventArgs实例的细节。
