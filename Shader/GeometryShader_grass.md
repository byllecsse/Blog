
# 几何着色器(Geometry Shader)
用于在物体表面生成多个顶点，构建三角形，来达到突起的毛发或者草地效果，比如球体用geometry shader可以渲染一个"针刺突起”的球，刺是由geometry shader生成，球体建模则只是个普通光滑的球，本节实例就以草地渲染为例，讲述下geometry shader在渲染这种大规模顶点物件的优势之处。

![草地图片](http://uwa-ducument-img.oss-cn-beijing.aliyuncs.com/Blog/HeaderImage/3538.png)

## geometry shader的基础特性
我需要定义这个geometry shader方法的名称:
``` c
#pragma geometry geo
```

geo()我应该在顶点着色器之后执行，并且在片元着色器之前，顶点着色器中只能简单的处理顶点信息，不要将顶点坐标转换成屏幕坐标或者投影坐标，**在geometry shader中将顶点从模型空间转换为相机齐次坐标的裁剪空间**，然后将顶点信息封装传入片元着色器，片元进行像素渲染，输出到屏幕。

对于封装的geometryOutput结构体，其字段定义和顶点、片元的字段定义一样，都是SV_POSITION等语义去知名字段的含义与作用。
``` c
struct geometryOutput
{
	float4 pos : SV_POSITION;
    float2 uv : TEXCOORD0;
    fixed color : COLOR;
};
```

geometry shader方法
``` c
[maxvertexcount(3)]
void geo(triangle float4 IN[3] : SV_POSITION, inout TriangleStream<geometryOutput> triStream)
{
}
```
maxvertexcount指示可能来自此几何着色器的最大顶点数，包括您在此阶段创建的新顶点或已删除的顶点，对于本例中的草地风吹动的弯曲效果，是将草分为三段共7个顶点，maxvertexcount支持公式，比如你这样写**[maxvertexcount(BLADE_SEGMENTS * 2 + 1)]* 是可以的。

geo()此方法接受v2g类型的输入，将其视为三角形（因为我们知道模型由三角形基元组成），并将其命名为输入，其[]运算符将允许访问三角形的三个顶点。

像图示这样重用顶点构建三角形，Triangle stip连接三角形，共享顶点
![geo内构建三角形](https://roystan.net/media/tutorials/grass/grass-construction.gif)

这不仅可以提高内存效率，还可以轻松快速地在代码中构建三角形序列。 如果我们希望有多个三角形条带，我们可以在TriangleStream上调用RestartStrip函数。就目前来看unity geometry shader已经实现了三角形带，我无只需要确定好顶点的加入顺序，从草平面渲染的结果看，由于是双面渲染，我无论将顶点按照顺时针或者逆时针添加，对结果的影响不大。

TriangleStream有点棘手。 请注意，此函数的返回类型为void，因此我们需要另一种方法将修改后的数据传递给下一个阶段。 inout关键字提供该功能：因为我们在三角形基础上进行处理，所以我们需要一个结构来输出它们; 因此我们需要这个流对象.

使用左手坐标系顺序添加顶点到TriangleStream中，TriangleStream会自动构建平面，在每个三角形的顶点添加完成时，调用trisstream.RestartStrip()，通知着色器我将进行下一轮三角形顶点的添加。

参考：
UnityObjectToClipPos() https://docs.unity3d.com/Manual/SL-BuiltinFunctions.html

Geometry shader基础概念 https://jayjingyuliu.wordpress.com/2018/01/24/unity3d-intro-to-geometry-shader/

草地实现 https://roystan.net/articles/grass-shader.html
草地Github https://github.com/IronWarrior/UnityGrassGeometryShader

关于Triangle stip的解释 https://en.wikipedia.org/wiki/Triangle_strip

有趣的实现：
https://github.com/keijiro/StandardGeometryShader