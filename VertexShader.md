# 顶点着色器

在Unity中，顶点着色器(Vertex Shader)总是和片段着色器(Fragment Shader)一起，先由顶点着色器计算完顶点的光照后，再输入到片段着色器插值化单位像素的光照结果，经片段着色器处理后的表面信息会更加平滑，阴影渐变的更加柔和。


顶点着色器的结构
```
Pass {
    // ... the usual pass state setup ...

    CGPROGRAM
    // compilation directives for this snippet, e.g.:
    #pragma vertex vert
    #pragma fragment frag

    // the Cg/HLSL code itself

    ENDCG
    // ... the rest of pass setup ...
}
```
ShaderLab着色器使用Cg/HLSL语言编写的，在内层的CGPROGRAM中，外层套的是Unity可识别的特定格式代码，可以在Unity Inspector面板显示shader的参数。  


这是一个简单的顶点着色器，用颜色展示法线信息。
```
Shader "Tutorial/Display Normals" {
    SubShader {
        Pass {

            CGPROGRAM

            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            struct v2f {
                float4 pos : SV_POSITION;
                fixed3 color : COLOR0;
            };

            v2f vert (appdata_base v)
            {
                v2f o;
                o.pos = mul (UNITY_MATRIX_MVP, v.vertex);
                o.color = v.normal * 0.5 + 0.5;
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                return fixed4 (i.color, 1);
            }
            ENDCG

        }
    }
}

```
如果你把这个shader的材质球赋值给一个模型，会看到这样的效果
![normal效果图](https://docs.unity3d.com/uploads/SL/ExampleWorldSpaceNormals.png)

大致解释下这个shader做了些什么，在开头的#pragma定义了vertex的函数vert和fragment的函数frag，将UnityCG.cginc包含进来，因为引用到了内置的appdata_base，这是一个内置的结构体，包含了光照、内发光、法线等基础信息，定义一个vert输出结构体v2f，包含顶点和颜色信息，当然这个颜色信息是对于顶点数据来说的，接着就要实现vert和frag函数，mul()是Cg/HLSL提供的矩阵相乘函数，和dot一样，我们了解它的原理和结果就好了，怎么运算是另一篇比较偏数学的文章去详细铺开，这里不做过多解析，回到mul()里的两个参数，v.vertex是appdata_base提供的顶点，UNITY_MATRIX_MVP矩阵是实现MVP变换的重点。  
在MVP变换后，vertex shader得到了世界坐标系的顶点颜色信息，将其传入frag，SV_Target是吧用户的输入颜色存储到一个渲染目标中，这里将输入到默认的帧缓冲中，前面我们定义color是fixed3，因此要构建一个fixed4的颜色变量，第四个参数是alpha，完全不透明输入1.



## Shader语义
在HLSL着色器程序中，输入输出变量都包含一定的含义，这是标准HLSL着色器语言的要求。

### Vertex shader 输入变量语义
#pragma定义顶点函数的全部输入变量都必须包含语义，这样的好处是我们可以很容易理解输入输出了哪些东西，并且知道他们在函数中做了什么事情，Mesh网格数据的顶点位置、法线、uv坐标都可以一一对应。

来看一个使用顶点位置和纹理坐标的简单着色器程序，它使用纹理的像素值作为颜色的输出：
```
Shader "Unlit/Show UVs"
{
    SubShader
    {
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            struct v2f {
                float2 uv : TEXCOORD0;
                float4 pos : SV_POSITION;
            };

            v2f vert (
                float4 vertex : POSITION, // vertex position input
                float2 uv : TEXCOORD0 // first texture coordinate input
                )
            {
                v2f o;
                o.pos = UnityObjectToClipPos(vertex);
                o.uv = uv;
                return o;
            }
            
            fixed4 frag (v2f i) : SV_Target
            {
                return fixed4(i.uv, 0, 0);
            }
            ENDCG
        }
    }
}
```
为了避免一个个输入参数，上面的程序定义了一个结构体，来封装输入参数，Unity也提供了很多的内置输入结构体，可以在UnityCG.cginc找到。

### Fragment shader 输出变量语义
大多数情况下Fragment shader都输出颜色，同时赋予SV_Target语义。上个实例中的frag函数的返回值是fixed4，这是一个低精度的RGBA颜色值，作为一个唯一返回值，SV_Target的语义是该函数本身。
https://docs.unity3d.com/Manual/SL-ShaderSemantics.html


## MVP变换

模型（Model）、视图（View）和投影（Projection）矩阵
- 模型变换：用于操纵模型和其中的特定对象，这里的模型指的是点的笛卡尔坐标，变换将对象移动到需要的位置，然后对他们进行旋转和缩放，但这些变换要遵从变换顺序，模型的变换不遵从乘法结合律，不同的变换顺序将会得到不同的结果。
- 视图变换：将模型位置变换到参考坐标系，即世界空间，它和模型变换的顺序是可以交换的。
- 投影变换：投影变换将在模型视图变换之后应用到顶点上，这种投影定义了视景体并创建了裁剪平面。投影变换有两种:正投影和透视投影。
    * 正投影(orthographic projection)，所有多边形都是按同样相对大小来在屏幕上绘制的。线和多边形使用平行线来直接映射到2D屏幕上。适合蓝图、文本等二维图形。
    ![正投影](http://img.blog.csdn.net/20141003001728734)

    * 透视投影(perspective projection)，通过非平行线来把图形映射到2D屏幕上，有透视缩短的特点，更加贴近现实。
    ![透视投影](http://img.blog.csdn.net/20141003002328209)