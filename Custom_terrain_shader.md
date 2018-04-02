
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