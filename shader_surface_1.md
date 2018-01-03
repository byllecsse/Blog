[返回](index.md)

# surface shader(表面着色器)

和vertex shader(顶点着色器)和fragment shader(片段着色器)不同，surface shader(表面着色器)不是一个标准渲染管线的必须过程，因为用vertex shader和fragment shader计算光照比较复杂麻烦，涉及到的代码也比较多，因此unity替我们封装了光照部分的计算，包括不同照明、点光源、平行光、光照贴图、不同的阴影，通过表面着色器我们不用关注底层的光照计算，不用管每个顶点、片段的光照值，相当于一段封装好的函数，直接拿来使用，使用方式也十分简单，你只需要了解ShaderLab的语法和使用规则，代码结构、输入输出和之前的着色器保持一致，也就是说没有什么学习成本，还帮我们省了不少事。  

但是surface shader并不是着色代码的最终形态，它只是个代码框架，unity在编译时，仍然会编译成vertex shader去执行，surface shader真正的用处是简化了关照的处理，它在Lighting.cginc中提供了各种常用的关照，例如：Lambert, BlinnPhong，在surf()函数中使用UnityCG.cginc提供的计算函数，将光照信息应用到纹理，输出到material.

先来看下正常的管线执行流程，在Unity视图中放置一个模型，要通过几步来实现一个最终的游戏显示效果：  
1. 输入值是网格(Mesh)，是不存在任何画面图像的，仅是顶点之间连线的模型结构轮廓。
2. 经Shader读取顶点信息，简单计算顶点光照后，交由片段着色器进行细分光照处理。
3. 交给GPU继续处理，接下来的光栅化阶段都是不可干预的。


![渲染流程图](http://game.ceeger.com/forum/attachment/thumb/1305/thread/2_3106_7d01f3c9ec55e5d.png)


先来看个简单的着色器：
使用lambert光照模型，只对物体进行白色光照的输出。
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
每个Unity shader都会包含至少一个SubShader，当渲染面片时，unity会自己判定该用哪一个子着色器，通常会使用排列在第一位的，并且GPU可支持的subshader. 如果第一位subshader不兼容当前硬件，则会依次向下选择一个可支持的subshader，如果全部的subshader不可用，最低的**Fallback**就发挥作用了，fallback最后说。

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
```
// 不需要视角方向的前向着色
half4 LightingName(SurfaceOutput s, half3 lightDir, half atten) {}
// 需要视角方向的前向着色
half4 LightingName(SurfaceOutput s, half3 lightDir, half3 viewDir, half atten) {}
// 用于需要延迟着色
half4 LightingName_PrePass(SurfaceOutput s, half4 light) {}
```

s.normal是顶点平面的法线方向，与光线方向的点积结果是所成的夹角越小，值越大，表面可以接受的入射光也越多，这是漫反射的基础计算公式，如果是一个球体计算光照，则是靠近中心点的位置越亮，边缘位置越暗。lightDir则是光照函数提供的参数，atten是衰减系数，是光线的衰减常量。
SurfaceOutput 封装了Albedo物体表面的纹理颜色（反照率）、法线、自发光等信息，为了完成漫反射计算，要将Unity和SurfaceOutput结构体提供的数据做乘法运算，_LightColor0.rgb是光源颜色（来自Unity），再与漫反射与atten相乘，结果作为颜色值。


这是标准着色器的输出格式，这些输出信息，可以自定义选择需要那些内容，或者也可以使用Unity提供的一些输出结构体，在UnityCG.cginc中有定义。
```
// 常见的output结构体
struct SurfaceOutput {
	fixed3 Albedo;		// 反照率，用于贴图和main color的颜色
	fixed3 Normal;		// 法线信息
	fixed3 Emission;	// 自发光
	half Specular;		// 反射/高光
	fixed Gloss;		// 光泽度，模拟金属表面高光
	fixed Alpha;		// 透明度
};
```

Value公司在原版《半条命》游戏中为了防止摸个物体背光面丢失形状并且显得太过平面化，而将NdotL的区间改变为0.5~1，这个光照模型没有任何的物理原理，仅是一种视觉增强。

除了使用Lighting.cginc中提供的光照模型，我们还可以自定义光照，下面代码Lighting__()的格式，是Unity shader可识别的自定义光照函数，它的输出是float4/half4/fixed4，具体哪个看机器性能与实现精度，关照函数提供光线方向、视角方向、衰减的输入参数，在函数内计算output\lightDir\viewDir，在这里可以编写自己任何需要实现的光照效果，这是可编程管线的好处。

```
half4 LightingHalfLambert (SurfaceOutput s, half3 lightDir, half atten)
{
	half NdotL = dot(s.Normal, lightDir);
	half diff = NdotL * 0.5 + 0.5;
	half4 c;
	c.rgb = s.Albedo * _LightColor0.rgb * (diff * atten); // _LightColor0.rgb是第一盏灯的颜色rgb值
	c.a = s.Alpha;
	return c;
}
```
HalfLambert的原理是把漫反射光照值的范围分成两半，然后加上0.5，改变的光照输出的值域，达到一个整体明亮又低饱和度的效果。  

![HalfLambert光照曲线示意图](https://picabstract-preview-ftn.weiyun.com:8443/ftn_pic_abs_v2/46e43bbdad3b259e0e64bd703c63929b1d9ffb3faa963797a104ee760c3ed2db7153e89febb41d71f60d9248365cb3aa?pictype=scale&from=30113&version=2.0.0.2&uin=287874300&fname=half_lambert.png&size=1024)


input输入_MainTex纹理的uv，tex2D则对这个纹理采样，读取出rgb值输出到材质。这是基础的漫反射带贴图shader.
```
void surf (Input IN, inout SurfaceOutput o) {
	o.Albedo = tex2D (_MainTex, IN.uv_MainTex).rgb;
}
```


#### fallback
他表示所有的subShader不可用时，尝试使用另一个shader，fallback是防止subShader一个都不可用的情况下，这个shader不至于没有崩掉或者没有渲染可用。

```
Shader "example" {
	// properties and subshaders here...
	Fallback "otherexample"
}
```