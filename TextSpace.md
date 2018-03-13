[Back](index.md)
# TextSpace Unity修改字间距

在项目中生成美术字，每个美术字两端的留白较多，导致使用起来字间距比效果图宽，理论上是需要美术重新导出美术字的，但是否存在程序化的方式处理，会简单许多，这是源代码的[网址](http://blog.csdn.net/qq_26999509/article/details/51902551)

TA的思路是修改顶点坐标, Unity text的实现方式就是正方形文字mesh的排列。
![Unity text的截图](http://img.blog.csdn.net/20160713233614704)

``` csharp
[AddComponentMenu("UI/Effects/TextSpacing")]
public class TextSpacing : BaseMeshEffect 
```

TextSpacing继承自BaseMeshEffect,BaseMeshEffect是UnityEngine.UI提供的类，用来修改生成mesh的。

看下Unity Scripting API提供的示例：
``` csharp
using UnityEngine;
using UnityEngine.UI;

public class PositionAsUV1 : BaseMeshEffect
{
    protected PositionAsUV1()
    {}

    public override void ModifyMesh(Mesh mesh)
    {
        if (!IsActive())
            return;

        var verts = mesh.vertices.ToList();
        var uvs = ListPool<Vector2>.Get();

        for (int i = 0; i < verts.Count; i++)
        {
            var vert = verts[i];
            uvs.Add(new Vector2(verts[i].x, verts[i].y));
            verts[i] = vert;
        }
        mesh.SetUVs(1, uvs);
        ListPool<Vector2>.Release(uvs);
    }
}
```

ModifyMesh的传入参数mesh，通过这个函数可以直接获取到mesh的各类信息，比如vertex uv信息等。
这段代码便利这个mesh的顶点，创建一个缓存池保存顶点，设置为mesh的uv后，释放缓存池。


TA的代码里用的VertexHelper，这同样也是UnityEngine.UI提供的东西
``` csharp
public override void ModifyMesh(VertexHelper vh)
    {}
```
VertexHelper作为一个顶点辅助类（从命名上也说明了这一点），它的作用是使构建msh变得简便。

``` csharp
using UnityEngine;
using UnityEngine.UI;

public class ExampleClass : MonoBehaviour
{
    Mesh m;

    void Start()
    {
        Color32 color32 = Color.red;
        using (var vh = new VertexHelper())
        {
            vh.AddVert(new Vector3(0, 0), color32, new Vector2(0f, 0f));
            vh.AddVert(new Vector3(0, 100), color32, new Vector2(0f, 1f));
            vh.AddVert(new Vector3(100, 100), color32, new Vector2(1f, 1f));
            vh.AddVert(new Vector3(100, 0), color32, new Vector2(1f, 0f));

            vh.AddTriangle(0, 1, 2);
            vh.AddTriangle(2, 3, 0);
            vh.FillMesh(m);
        }
    }
}
```

在Unity wiki 上也有一段用普通方式创建mesh的[代码](http://wiki.unity3d.com/index.php?title=Triangulator)
``` csharp
// 使用普通方式则要定义一个顶点数组
Vector2[] vertices2D = new Vector2[] {
            new Vector2(0,0),
            new Vector2(0,50),
            new Vector2(50,50),
            new Vector2(50,100),
            new Vector2(0,100),
            new Vector2(0,150),
            new Vector2(150,150),
            new Vector2(150,100),
            new Vector2(100,100),
            new Vector2(100,50),
            new Vector2(150,50),
            new Vector2(150,0),
        };
```




> VectexHelper有可能是继承Mesh的，查文档里只发现了public void ModifyMesh(Mesh mesh);一种参数？




### 上代码

``` csharp
List<UIVertex> vertexs = new List<UIVertex>();
vh.GetUIVertexStream(vertexs);  // Create a stream of UI vertex (in triangles) from the stream.
int indexCount = vh.currentIndexCount;
UIVertex vt;
for (int i = 6; i < indexCount; i++)
{
    //第一个字不用改变位置
    vt = vertexs[i];
    vt.position += new Vector3(_textSpacing * (i / 6), 0, 0);
    vertexs[i] = vt;
    //以下注意点与索引的对应关系
    if (i % 6 <= 2)
    {
        vh.SetUIVertex(vt, (i / 6) * 4 + i % 6);
    }
    if (i % 6 == 4)
    {
        vh.SetUIVertex(vt, (i / 6) * 4 + i % 6 - 1);
    }
}
```

UIVertex是一个在UnityEngine里的结构体，用于Canvas管理其顶点，存储顶点该有的全部信息：color, normal, position, tangent, uv0, uv1, uv2, uv3(支持4个mesh)。
vh.GetUIVertexStream(vertexs)是传入参数后又out了？因为在这行后，vertexs就已经存在对应的顶点值。

每个字对应6个序列，for循环从6开始，是从第二个字符启，每个顶点都挪一定的位置，对应字符的挪位会乘以该字符所在的索引位置，比如第一位不挪位置，第二位挪1个单位的位置，第三位挪2个单位的位置。

通常一个quad由4个顶点6个序列构成，比如0-1-2-3号顶点，那么这个quad构成的triangle数组就是
{0,2,1,1,3,2}
构建quad面向相机的顺序。
![A quad made with two triangles.](http://catlikecoding.com/unity/tutorials/procedural-grid/03-quad.png)