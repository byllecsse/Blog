
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

蒙特卡罗积分公式没有积分符号∫，但它被称为积分公式是因为它是**对理想积分的近似**，不是精确的积分求解，这个近似值结果是**采样(Sampling)**，对一个连续函数的采样方法是：在该函数定义域中随机挑选N个值，求出对应的N个

$$x=\frac{-b\pm\sqrt{b^2-4ac}}{2a}$$
\\(x=\frac{-b\pm\sqrt{b^2-4ac}}{2a}\\)
\\(f(X_{i})\\)


## 基于Screen Space


参考：
https://blog.csdn.net/BugRunner/article/details/7272902