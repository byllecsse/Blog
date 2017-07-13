[返回](index.md)

# 造成Profiler "Overhead"的因素

![overhead](https://picabstract-preview-ftn.weiyun.com:8443/ftn_pic_abs_v2/9523b74c92508099cfd00af3410ac88e666e2c0484f87268c55d0314af1e1a8208b28463ff9fc9c3cad865cc12cf9704?pictype=scale&from=30113&version=2.0.0.2&uin=287874300&fname=overhead_profiler.png&size=1024)  


Overhead通常是由于vsync（垂直同步）造成的，特别是IOS平台上不能关闭vsync，Profiler可能还包含分析开销，不过占比不大，不用过分关注，如果你的项目同时还有GPU瓶颈，就可能会体现在"overhead"这一项上，但是更多的时候，会显示为Camera.Present.  

- 在Profiler里，Overhead = 一帧的总时长 - 所有实际的测量值的耗时。
- 它通常与场景的内部处理相关，越是复杂的场景，overhead的耗时就越多。
- 它也是一个垂直同步的耗时表现，可以在Application.targetFrameRate中修改时间间隔。
- 频繁调用overhead可能导致内存警告，当IOS抛出内存异常时会增加app overhead，因此IOS游戏经常超过内存使用警告线时，会导致大量的耗能尖峰。


复杂场景的性能开销并不是因为object的数量大，而是一般性的处理开销较多，如果有大量的物体，计算起来比小数目的物体需要更多的时间，不过最重要的还是不同的引擎子系统任务在每个object上面的处理时间，这些任务时间不能在profiler中得到很好的体现，就会添加进overhead的时间统计里。将不明确的时间统计进overhead里是有好处的，它是为提供一个完整，准确的帧耗时服务的。  

Profiler的层次结构显示了最有可能消耗资源的进程，但是仍旧有很多隐藏任务我们无法得知，为了找出场景中最复杂，最耗时，最可以优化的部分，你要移除或者改变场景的某些部分，一步步尝试，最终找出最影响性能的模块，我指的是某些大量频繁出现的物体或者子系统，比如：3D or 2D physics, navmesh, sprites, lighting, scripts and plugins, rendering, GUI, audio or video, particles。  


## 用常规优化手段检查你的项目；
- CPU和GPU的使用率会决定你的FPS；
- 影响CPU的因素：Physics, Game code, Skinning(when not done in GPU), Particles, Raycasting(flares);
- 影响GPU的因素: Fillrate(带宽填充率), Shaders, Drawcalls, Image Effects;
- Garbage Collection 要尽量少的触发垃圾回收;
- 去掉所有代码中的的空事件回调(OnGUI, LateUpdate, Update)；
- 增大fixedTimeStep(Physics timestep)，减少FixedUpdate的调用次数；
- 在Time Manager里设置最大的Timestep，控制物理模拟的调用在合理范围内；
- 所有静止的物体勾选static，如果要移动(scale, position, disable/enable)，将他们设置为Kinematic;
- 去掉所有不使用的AnimationClips curves；
- 使用正确的QualitySettings去适配不同的硬件设备，减少反锯齿Anti Aliasing，减少阴影距离，调整最大的LOD值；
- 使用未压缩的AudioClips会占用较少的CPU资源，较小的audio clips就不需要压缩了；
- 如果你要在每一帧都使用Fine or Contains，请使用HashSet而不是List，HashSet本身就是设计用来快速查找的；
- 缓存结果引用以避免不需要的查找开销；
- 避免多个相机同时渲染，两个相机会使场景的渲染开销加一倍，即使你设置了不同的相机层级(layer)；
- 使用粒子系统渲染sprites and billboard(e.g gass);
- 如果需要频繁地修改网格信息，请在网格上调用MarkDynamic()，让Unity来优化这些频繁的改动；
- 减少内存的创建以减少GC的调用次数；
- 使用对象池来保存需要大量频繁创建的对象，这样比频繁创建销毁他们要快得多，而且频繁调用会增加内存开销，mono内存一旦创建就不会还给系统；
- 尽量不要使用meshCollider，对meshCollider的缩放会卡住主线程；
- AwakeFromLoad会非常耗时，不要使用。


其实并非是Overhead本身消耗了CPU，而是其他没有被Profiler明确给出的明细耗时，优化Overhead其实是去优化其他项，它由非常多的其他原因造成，所以还是去仔细阅读改进代码，减少渲染或者其他子系统的计算占用。


[翻译自这里](http://answers.unity3d.com/questions/482381/what-are-causes-of-overhead-in-profiler.html)
