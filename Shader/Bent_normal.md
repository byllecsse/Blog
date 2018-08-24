
# Bent Normal

中文译名貌似叫：环境法线

![Bent Normal示意图](http://hi.csdn.net/attachment/201202/19/4491947_1329650854zqXO.png)

Bent Normal的采样示意图（从图中可以看出，Bent Normal(黄色)与原始Normal(蓝色)相比，其在考虑周围几何体元分布的情况下向右侧做了修整）

那有个问题是，肉眼很容易判断的几何控件，如何在机器上快速的将蓝色原始法线向右偏移变成黄色Bent Normal？
两种方式:
1. 传统离线采样
2. 很流行的基于Screen Space方法

## 传统离线采样 

和传统离线Ambient Occlusion(环境光遮蔽)计算方法一样，在场景表面的每个点做采样，离线的意思大概是说如此大量的计算不适合实时进行，只能在前期烘培时候做，采样后计算蒙特卡罗积分，即可统计得到场景遮挡情况下的Bent Normal.

蒙特卡罗积分公式没有积分符号$\int$，但它被称为积分公式是因为它是**对理想积分的近似**，不是精确的积分求解，这个近似值结果是**采样(Sampling)**，对一个连续函数的采样方法是：在该函数定义域中随机挑选N个值，求出对应的N个$f(X_{i})$


蒙特卡罗积分公式：
$$F^{N} = \frac {1}{N}\sum _{i=1}^{N}\frac {f(X_{i})}{ pdf(X_{i}) }$$


pdf用http://www.scratchapixel.com/ 的一个例子来说明
![pdf例子](https://www.qiujiawei.com/images/2016.8/1.png)


## 基于Screen Space

该方法优点是快，缺点是不大精确，但为了在游戏中得到实时的AO计算，很多基于屏幕控件的SSAO算法被提出。

说到AO，其实和全局照明(Global Illumination, GI)有一定关系，GI是所有表面之间相互左右的光照现象，光线的反射、折射、遮挡，例如：渗色(Color Bleeding)、焦散(Caustics)和阴影，大多数情况下，GI表示渗色和逼真的环境光照(Ambient Lighting). 直接照明即光线直接来自光源，现在的硬件已经很容易实时计算，但GI需要手机场景中每个面的邻近面信息，复杂度容易失控，在小型设备上根本做不到实时，所以对应出了一些GI近似模拟方案：将一些光线不容易照射到的角落、缝隙等，进行光线计算的遮蔽、屏蔽，这个环境光线屏蔽称为AO。

AO一直以来是在每个采样点上计算它被其他几何体遮挡的程度，进而得到在统一光照强度下，场景中软阴影效果的图形算法，但这些都是离线渲染，知道CryTek在游戏中运用了Screen Space Ambient Occlusion(SSAO)之后，它通过后处理渲染的一些常用信息，比如深度Depth、位置Position,将传统的基于3D空间的AO计算转换到完全基于2D屏幕空间的操作。

**Shadow Map**阴影实现，从光源的视角渲染整个场景，实际相机渲染物体，将物体从世界坐标转换到光源视角下，与深度纹理对比数据获得阴影信息，根据阴影信息渲染场景和阴影。采集Shadow Map纹理的基础是获取深度纹理，深度纹理其实也是一种Image Effect，它是Post Effect的一种方式，可以通过Camera GameObject上挂带有OnImageRender的脚步实现。要获取深度，相机需设置DepthTextureMode参数，可设置为DepthTextureMode.Depth或者DepthTextureMode.DepthNormals，配合unity shaderLab中提供的参数_CameraDepthTexture 或者_CameraDepthNormalsTexture来获取。

深度纹理并非是深度缓冲中的数据，而是通过特定Pass获得。

对于自身带有ShadowCaster Pass或者FallBack包含的，并且Render Queue小于等于2500的渲染对象才会出现在深度纹理中，在Shader中提前定义纹理_CameraDepthTexture，Unity提供了UNITY_SAMPLE_DEPTH \ SAMPLE_DEPTH_TEXTURE不同平台的解决方案。

``` c
Pass
{
    CGPROGRAM
    #pragma vertex vert
    #pragma fragment frag
    #include "UnityCG.cginc"
    // 提前定义的深度纹理
    uniform sampler2D_float _CameraDepthTexture;

    struct uinput
    {
        float4 pos : POSITION;
    };
    struct uoutput
    {
        float4 pos : SV_POSITION;
    };
    uoutput vert(uinput i)
    {
        uoutput o;
        o.pos = mul(UNITY_MATRIX_MVP, i.pos);
        return o;
    }
    fixed4 frag(uoutput o)     :COLOR
    {
        float depth = UNITY_SAMPLE_DEPTH(tex2D(_CameraDepthTexture, o.uv));
        depth = Linear01Depth(depth) * 10.0f;
        return fixed4(depth, depth, depth, 1);
    }
    ENDCG
}
```

## Unreal Engine对Bent normal的解释
Unreal推荐使用Bent Normals，使用Bent Normal的材质可以改善光线反射和阴影的响应，可以显著减少一些光线计算，在Ambient Occlusion中改善漫反射间接照明，使其更接近Global Illumination的光照结果。Unreal Engine已经提供了BentNormal的shader节点以供使用，对于Unity来说，则要自己动手。

### 参考：
https://blog.csdn.net/BugRunner/article/details/7272902
https://www.qiujiawei.com/monte-carlo/
https://blog.csdn.net/BugRunner/article/details/7101419
http://www.cnblogs.com/zsb517/p/6655546.html
https://docs.unrealengine.com/en-us/Engine/Rendering/LightingAndShadows/BentNormalMaps