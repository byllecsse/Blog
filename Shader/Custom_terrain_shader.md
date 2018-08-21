
# 自定义地形shader

翻译自：
https://alastaira.wordpress.com/2013/12/07/custom-unity-terrain-material-shaders/


（省略第一段）
Unity内建的shader似乎只有一个，仅仅支持漫反射纹理，如果你在网络上搜索“自定义Unity地形shader”，会找到大量重复的建议，要么不支持，要么是地形建模程序，或者一个同样名称，所谓的创建新的地形shader，其实内部隐藏的地形shader：“Hidden/TerrainEngine/Splatmap/LightmapFirstPass”，代码很不直观。

很多旧时的描述已经过了时效并且不准确了，但仍然被搜索引擎置顶，看起来很难找到最新的信息，所以我将我自定义地形shader的经历记录下来放在blog上，版本Unity 4.2.


### Normal-Mapped/Specular Terrain

从Unity 4.0开始，创建 bump-mapped/specular terrain就已经可供应合适的shader，下面就展示这些步骤：

1. 创建新的材质并且应用_Nature/Terrain/Bumped Specular shader_，这个shader没有提供纹理属性，下一步会展示如何在这个材质上使用纹理。  
![Image](https://alastaira.files.wordpress.com/2013/12/image_thumb1.png?w=340&h=295)


2. 选中地形，在inspector面板中，点击画刷，编辑这个地形。  
![Image](https://alastaira.files.wordpress.com/2013/12/image_thumb2.png?w=325&h=372) 

添加一个主纹理和与之对应的法线贴图。  
![Image](https://alastaira.files.wordpress.com/2013/12/image_thumb3.png?w=220&h=343)

用图示的各种画刷，在地形上绘制。


3. 根据上面的步骤信息，我要对地形应用一个法线贴图的材质，点击最右边的设置按钮，拖拽材质到这个material 栏，完成之后，地形就变得有凹凸感了。

![Image](https://alastaira.files.wordpress.com/2013/12/image_thumb5.png?w=644&h=395)



### 自定义地形shader

创建一个bumped/specular贴图是非常简单的，因为Unity已经提供了这个shader，你只需要制定一个材质用它来代替默认的漫反射地形shader. 创建一个自定义地形shader比起bumped/specular 会略有些复杂，先看下地形shader内建的结构体会有些帮助，Unity在它的网站上有提供内置shader的源码下载。

第一个需要了解的是shader的属性面板，包含各种纹理和uv信息的设定，下列代码中的属性被标记为[HideInInspector]，表示这些参数会自动地经地形引擎输入，不走Unity Inspector面板，Inspector面板不会显示这些参数。下列代码中第一个_Control纹理输入一个纯红色的数据，这是表示第0层的纹理数据（引擎默认是从 _Splat0 纹理开始着色）

``` 
// Splat Map Control Texture
[HideInInspector] _Control ("Control (RGBA)", 2D) = "red" {}
 
// Textures
[HideInInspector] _Splat3 ("Layer 3 (A)", 2D) = "white" {}
[HideInInspector] _Splat2 ("Layer 2 (B)", 2D) = "white" {}
[HideInInspector] _Splat1 ("Layer 1 (G)", 2D) = "white" {}
[HideInInspector] _Splat0 ("Layer 0 (R)", 2D) = "white" {}
 
// Normal Maps
[HideInInspector] _Normal3 ("Normal 3 (A)", 2D) = "bump" {}
[HideInInspector] _Normal2 ("Normal 2 (B)", 2D) = "bump" {}
[HideInInspector] _Normal1 ("Normal 1 (G)", 2D) = "bump" {}
[HideInInspector] _Normal0 ("Normal 0 (R)", 2D) = "bump" {}
```

shader的主体代码有一套标准的格式，融合四个纹理的RGBA通道采样数据，并设置到设置到材质的反照率输出中。

```
fixed3 col;
col  = splat_control.r * tex2D (_Splat0, IN.uv_Splat0).rgb;
col += splat_control.g * tex2D (_Splat1, IN.uv_Splat1).rgb;
col += splat_control.b * tex2D (_Splat2, IN.uv_Splat2).rgb;
col += splat_control.a * tex2D (_Splat3, IN.uv_Splat3).rgb;
o.Albedo = col;
```

最后需要关心的是在shader的地步：包含了两个额外shader的依赖：
```
Dependency "AddPassShader" = "MyShaders/Terrain/Editor/AddPass"
Dependency "BaseMapShader" = "MyShaders/Terrain/Editor/BaseMap"
```



### AddPassShader

检查AddPassShader的代码，你会找到它与表面着色器(surface shader)的FirstPassShader相同，下列列举了两个shader之间的微妙差异：

- FirstPassShader 的渲染队列**"Queue" = "Geometry - 100"**，而AddPassShader则要晚一些渲染"Queue" = "Geometry - 99"
- AddPassShader指定了**"IgnoreProjector" = "True"**
- AddPassShader是个相加通道的shader，使用**decal:add**参数遵循表面shader的参数指令。

除此之外，他们之间有很多相似处，从经验和一些以往的证据来看，这么做有很大部分的逻辑考虑，这两个shader的不同之处都可以被解释通：FirstPass shader（地形使用的唯一材质）仅有4个纹理插槽，如果使用了多于4个纹理，则AddPassShader就会被地形引擎所调用，每个增加的处理链接到地形后，它的输出会相加融合到第一个通道。

也就是说，如果你的地形使用了不超过4张纹理绘制表面，是使用FirstPassShader，否则引擎会替换使用AddPassShader。



### BaseMapShader

FirstPassShader和AddPassShader控制地形的通道并且将纹理融合进shader内，造成的问题是比较消耗GPU，同时对老旧显卡的支持也不好，为了补偿这个缺陷，Unity融合所有地形的纹理（基于shader控制的纹理），导入进单个的融合基础纹理（这个做法类似光照贴图lightmap），分别率由地形inspector面板中的“基础纹理分别率”限定，这个基础纹理作为参数输入到shader，可以被用作老旧显卡不支持FirstPassShader混合纹理的回溯版本。任何地形用到了比Base Map Dist更多的功能，这个单纹理就会用BaseMapShader渲染。

接收基础纹理的参数名为 _MainTex，对应一个 _Color参数，两个参数会被FirstPassShader自动设置。


## Toon Outlined Terrain

