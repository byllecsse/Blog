
[Back](index.md)

# Unity Cinemachine

今天研究了下Cinemachine这个插件，Unity 2017.1.1之后的版本已经可以支持这个插件了，我用的Unity版本是2017.3.1p3。

![插件的下载地址](https://assetstore.unity.com/packages/essentials/cinemachine-79898)

这个插件是一个制作动画电影，多种时间线相机显示的工具，在动画电影的制作过程中，生成无数个相机用来渲染相应路径的动画，理论上有n个动画镜头，就有n+1个相机（包含n个分镜头相机和一个Main Camera）。电影的制作方式和Adobe Premiere的时间线式的很相似，有多个轴可以处理多个物体的同时动画或者音效。

该插件很适合做小型动画电影或者游戏内剧情动画，它本身没有过多的动画片段过渡，镜头切换和追踪的方式也比较简单，仅提供了follow和look at两种方式。



### 插件结构
[目录结构](Images/cinemachine_struct.png)


### 开始制作
导入Cinemachine插件后，Unity会在工具栏增加'Cinemachine'，里面包含添加各类相机的一系列操作，在'Window->Timeline'会打开时间线窗口
[Timeline窗口](Images/cinemachine_timeline.png)
