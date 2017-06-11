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

> MVP变换：这个十分重要，以至于我要另起一行来讲这个东西。  
> 模型（Model）、观察（View）和投影（Projection）矩阵