[Back](index.md)
# 表面着色器

和顶点着色器(Vertex shader)和片段着色器(Fragment shader)不同，表面着色器(Surface shader)不是一个标准渲染管线的必须过程，因为用顶点和片段着色器计算光照比较复杂麻烦，涉及到的代码也比较多，因此unity替我们封装了光照部分的计算，包括不同照明、点光源、平行光、光照贴图、不同的阴影，通过表面着色器我们不用关注底层的光照计算，不用管每个顶点、片段的光照值，相当于一段封装好的函数，直接拿来使用，使用方式也十分简单，你只需要了解ShaderLab的语法和使用规则，代码结构、输入输出和之前的着色器保持一致，也就是说没有什么学习成本，还帮我们省了不少事。  

先来看下正常的管线执行流程，在Unity视图中放置一个模型，要通过几步来实现一个最终的游戏显示效果：  
1. 输入值是网格(Mesh)，是不存在任何画面图像的，仅是顶点之间连线的模型结构轮廓。
2. 经Shader读取顶点信息，简单计算顶点光照后，交由片段着色器进行细分光照处理。
3. 交给GPU继续处理，接下来的光栅化阶段都是不可干预的。

![渲染管线](http://game.ceeger.com/forum/attachment/thumb/1305/thread/2_3106_7d01f3c9ec55e5d.png)


先来看个简单的着色器：
```
Shader "Example/Diffuse Simple" {
	SubShader {
		Tags {"RenderType" = "Opaque"}

		CGPROGRAM
		#pragma surface sur Lambert
		struct Input {
			float4 color : COLOR;
		};
		void surf(Input IN, inout SurfaceOutput o) {
			o.Albedo = 1;
		}
		ENDCG
	}
	Fallback "Diffuse"
}
```
保存后unity会立刻编译这段shader，程序新建一个着色器，在Inspector面板的shader中出现一个"Example/Diffuse Simple"的路径，是刚刚保存的shader名称，反斜杠‘/’会在shader下拉菜单中创建一个子菜单，标识层级。  

#### SubShader
每个Unity shader都会包含至少一个SubShader，当渲染面片时，unity会自己判定该用哪一个子着色器，通常会使用排列在第一位的，并且GPU可支持的subshader.  

> 格式：Subshader { [Tags] [CommonState] Passdef [Passdef ...] }  

Tags{}定义使用的渲染通道，设置通道状态。当Unity选定了subshader，就会以当前subshader中定义的每一个通道方式渲染物体，每个渲染的物体都是个昂贵的操作，所以尽可能少地定义通道，除非一些图形效果必须使用多个通道。  

通道类型包括:  
 - regular Pass
 - Use Pass
 - Grab Pass


##### SubShader Tags
subshader用标签的方式告知着色器怎么渲染、何时渲染。

> 格式：Tags { "TagName1" = "Value1" "TagName2" = "Value2" }

 Tags使用的基础key-value形式，定义渲染顺序和其他参数。  

**渲染顺序 - Queue tag**
这个tag可以定义物体的渲染顺序，先渲染的通常会被后渲染的遮盖，比如背景、远处的场景，属于最先渲染的范畴，近处的建筑、房屋、室内场景，会遮盖之前渲染的画面（不会全部遮盖，只是按照物体透视关系，遮盖一小块），而粒子、半透明玻璃又在此之后渲染，所以这些渲染顺序可以成为渲染队列，所以采用"Queue"队列一词来命名这个属性。 

分别是如下几个前置渲染队列：
* Background 最早的渲染，常用于天空盒和背景的渲染；
* Geometry (默认项) 适用于绝大多数非透明物体；
* AlphaTest 透明度测试，它是Geometry的分支，用于在纯色物体渲染后的透明度测试；
* Transparent 它在Geometry和AlphaTest之后渲染，也就是更加靠近相机的渲染，任何透明度融合的渲染都不会写入深度缓冲，比如玻璃杯和粒子效果。由于他的特性，必须在非透明物体渲染之后，再加一层渲染。
* Overlay 是最后渲染的队列，覆盖所有之前的渲染，例如镜头耀斑。

我常用的是Transparent，用于半透明渲染，普通的非透明不包含Alpha通道的物体，不需要特别指明Queue。  
而RenderType标签，常用内置有"Opaque/Transparent/TransparentCutout/Background/Overlay"，很明显当前的shader只是想显示纯白色，用"Opaque"就好。  


#pragma surface surf Lambert
这句话的含义是使用表面着色器，surf函数使用的Lambert, Lambert是Unity内置的光照模型，还包括其他内置光照模型如BlinnPhong高光反射光照模型，可以在Lighting.cginc中找到，让我们来编写一个简单的Lambert光照模型：
```
half4 LightingSimpleLambert(SurfaceOutput s, half3 lightDir, half atten)
{
	half NdotL = dot(s.Normal, lightDir);
	half4 c;
	c.rgb = s.Albedo * _LightColor0.rgb * (NdotL * atten);
	c.a = s.Alpha;
	return c;
}
```
#pragma surface 指令告诉着色器将使用哪个光照模型来计算，默认是使用Lighting.cginc里的Lambert光照模型，但现在我们要用自定义的光照模型，格式：Lighting<Name>，有三种格式的光照模型函数。
> half4 LightingName(SurfaceOutput s, half3 lightDir, half atten) {}
> 不需要视角方向的前向着色
> half4 LightingName(SurfaceOutput s, half3 lightDir, half3 viewDir, half atten) {}
> 需要视角方向的前向着色
> half4 LightingName_PrePass(SurfaceOutput s, half4 light) {}
> 用于需要延迟着色

s.normal是顶点平面的法线方向，与光线方向的点积结果是所成的夹角越小，值越大，表面可以接受的入射光也越多，这是漫反射的基础计算公式，如果是一个球体计算光照，则是靠近中心点的位置越亮，边缘位置越暗。lightDir则是光照函数提供的参数，atten是衰减系数，是光线的衰减常量。
SurfaceOutput 封装了Albedo物体表面的纹理颜色（反照率）、法线、自发光等信息，为了完成漫反射计算，要将Unity和SurfaceOutput结构体提供的数据做乘法运算，_LightColor0.rgb是光源颜色（来自Unity），再与漫反射与atten相乘，结果作为颜色值。

```
struct SurfaceOutput {
	fixed3 Albedo;
	fixed3 Normal;
	fixed3 Emission;
	half Specular;
	fixed Gloss;
	fixed Alpha;
};
```

Value公司在原版《半条命》游戏中为了防止摸个物体背光面丢失形状并且显得太过平面化，而将NdotL的区间改变为0.5~1，这个光照模型没有任何的物理原理，仅是一种视觉增强。
```
half4 LightingHalfLambert (SurfaceOutput s, half3 lightDir, half atten)
{
	half NdotL = dot(s.Normal, lightDir);
	half diff = NdotL * 0.5 + 0.5;
	half4 c;
	c.rgb = s.Albedo * _LightColor0.rgb * (diff * atten);
	c.a = s.Alpha;
	return c;
}
```
HalfLambert的原理是把漫反射光照值的范围分成两半，然后加上0.5
![HalfLambert](http://a1.qpic.cn/psb?/V12VFSh93PPcnw/Fg5Y3vwTb.HSrB1a9q1jhK5v9ve9Du6PZwDW.jPHzus!/b/dBgBAAAAAAAA&ek=1&kp=1&pt=0&bo=egEyAQAAAAADF3o!&tm=1496584800&sce=60-2-2&rf=viewer_4)