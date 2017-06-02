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
