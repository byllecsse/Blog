[Back](index.md)

# Lua学习笔记

刚换工作不久，2017/9/25，由于项目需要使用lua做热更新，开始系统性学习lua。

[xlua的一篇文章](http://www.infoq.com/cn/news/2017/01/C-NET-Lua-Unity3D)

lua先不说语法规则，在编写上就有和c#很不相同的地方，也是几次搞混
1. 句尾分号可写可不写，一般都是不写的
2. if不需要跟()，后面的{}用then end代替，比如
    if n == 1 then
    end
3. for是默认从1开始，lua里的数组，没有明确指定下标，都默认从1开始，所以for便利时候，也是写成for i=1, #array do end（=两边不能空格）
4. 为了省略self，函数一般是“类名:函数名”

###### 类型
lua不需要区分类型，有些类型c# var，但连var也不需要，直接一个变量名摆在那里直接赋值，这种是全局变量，确保变量名全局唯一就好，否则它会修改原有的变量，如果申明某个全局变量就使用了，lua也不会报错（要视情况，如未申明变量.name就会报错），所以未赋值，或者没定义的变量它的值都是nil


###### for循环
lua包括多种形式的for循环格式，以及使用for实现的迭代器
对于数组的循环，像是array = {1,2,3,4,5,6}，可以使用
1. for v in array do <body> end    
2. for i=1, #array do <body> end
其实1某种程度上是个迭代器，v是数组元素的内容，lua不关心数据类型，它是在动态解析时分配的，有些类似c#的foreach，2则省略了递增值，本来for循环有3个参数，最后面是递增值，不过lua做了点处理，如果没有显示指定，就默认每次递增1.

而table不能使用上述的格式遍历，它是个key-value形式，可以使用支持key-value的迭代器
1. for k, v in pairs(array) do <body> end
2. for _, v in pairs(array) do <body> end 下划线本质上是个占位符，我不需要key但用下划线来占位
3. for i, v in ipairs(array) do <body end 无状态迭代器

###### 迭代器
可以说这是lua中最重要的一个概念，凡是以table, 或者dictionary的数据结构，都可以用他来“解析”。它能够用来遍历标准模板库容器中的部分或全部元素，每个迭代器对象代表容器中的确定的地址
在Lua中迭代器是一种支持指针类型的结构，它可以遍历集合的每一个元素。

array = {11, 22, 33, 44, 55, 66, 77, 88}
```
-- for循环
for i=1, #array do
    print(array[i])
end

-- 迭代器，它将把索引下标和数组值一起打印
for k, v in pairs(array) do
    print(k, v)
end

-- 如果不需要索引下标
for _, v in pairs(array) do
    print(v)
end
```

创建自己的迭代器
```
array = {"lua", "tutorial}

function elementIterator(collection)
    local index = 0
    local count = #collection

    -- 闭包
    return function()
        index = index + 1 -- lua没有自增
        if index <= count
        then
            return collection[index]
        end
    end
end

for element in elementIterator(array)
do
    print(element)
end
```

###### pairs和ipairs的区别
- pairs迭代table，可以遍历表中所有的key，可以返回nil
- ipairs迭代数组，不能返回nil，如果遇到nil则退出

```
local tab= { 
[1] = "a", 
[3] = "b", 
[4] = "c" 
} 
for i,v in pairs(tab) do        -- 输出 "a" ,"b", "c"  ,
    print( tab[i] ) 
end 

for i,v in ipairs(tab) do    -- 输出 "a" ,k=2时断开 
    print( tab[i] ) 
end
```