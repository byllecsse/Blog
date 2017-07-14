[返回](index.md)

# 降低Draw Call（一）

CPU准备数据并通知GPU渲染的过程就是一次DrawCall,如果这个过程出现的次数太多，就会影响CPU的执行效率，就会出现卡顿。当然，影响CPU的不仅仅只有DrawCall,还有物理组件、GC（垃圾对象太多，造成GC负担，影响CPU的执行效率）、代码质量。  

每在屏幕上绘制一个物体，Unity必须想绘图API（无论OpenGL或者Direct3D)发起一次Draw Call，Draw Call是非常昂贵的，CPU封装好数据发往GPU这个操作很耗时，所以我们要尽可能将物体封装为一次DrawCall，减少数据发送的次数，以减轻这部分的开销，另外永远不用担心GPU无法处理封装的数据，无论模型多复杂，这对于GPU来说，就是一次顶点/片元的计算，当然GPU的性能也会受顶点数量，纹理大小的限制，这些称之为GPU带宽。  


## Unity Batching

Unity使用多种技术来解决这个问题：
- 静态Batching: 把静态（勾选了static)的物体合并成一个大meshes;
- 动态Batching: 对于足够小的meshes，在CPU上变换他们的顶点，将一些相似的组合到一起。这是运行时的，不受我们控制，是Unity自动进行的Batching操作。  

不管是静态Batching还是动态Batching，都有它的缺点，静态Batching会导致内存和存储的开销，动态Batching会导致CPU开销，所以要根据项目实际情况合理选择。


## Shared Material（共享材质）

只有使用了相同材质的物体才能被动态合并，并且这些材质的属性，比如_Color必须相同。如果有两个使用了同样材质但是texture不同的话，可以合并这些texture到一个大texture中，这个过程叫做texture atlasing，如果需要在脚本中访问共享材质，应该使用Renderer.sharedMaterial, 使用Renderer.material会创建一个当前材质的副本，并且不会和相同属性的副本合并，之前我遇到过一次6个颜色的立方体，使用同一个材质，但是在代码中Renderer.material设置了颜色，不停地创建这几个颜色的立法体，最终导致DrawCall上升到500多！  

相同材质的相同属性，即使他们的材质不同，也经常被合并到一起，只要材质的数值在shadow pass是相同的，当渲染阴影投射时，也可以使用动态合并。举个例子，许多箱可以使用具有不同的texture的材质，但对于阴影投射渲染 texture是不相关 - 在这种情况下，他们可以被batched到在一起。  


## Dynamic Batching（动态批处理）

Unity可以自动将非static物体合并到相同的DrawCall中，如果具有相同材质，并且满足其他标准，动态Batching会自动完成，不需要你做额外事情。动态Batching物体的每个顶点会有某些开销，所有batching只适用于顶点数目小于900的mesh, 假如这个mesh的shader使用了顶点位置，法线和单独UV，那么可以batch的顶点数目降到了300，如果使用了顶点位置，法线，UV0,UV1和正切，就只能batch180个顶点了。  
| 这个限制的数量将来有可能改变。

**其他限制**
1. 如果物体包含镜像变换，就不会被batch，例如：object A scale = +1, object B scale = -1，就不能batch.
2. 使用不同材质的实例，即使他们实质上是相同的，也会导致两个物体不能batch（阴影投射除外）。
3. 具有光照贴图的对象有额外的渲染参数：光照索引和偏移/缩放的光照，所以动态lightmapped的对象应只想完全相同的光照贴图位置后，在进行batch.
4. 多通道的shader将不会被batching，几乎所有的Unity shader都支持前置渲染几个灯光，有效的为他们做更多的通道。“额外的逐像素的灯光”的draw call 将不会被batched。
5. 传统的延迟渲染（逐通道光照）通道禁用了动态batching，因为它必须绘制两次。


## Static Batching（静态批处理）

静态batching运行引擎减少draw call，这使用与任何大小的几何对象，并且限制没有动态batching多，大部分情况下更好更高效，但是会占用更多内存。  

为了使静态batching有更好的效益，需要我们明确指定游戏中某些物体是静态的，而且不会移动，旋转或者缩放，unity提供了一个简单的选项，在inspector面板中勾选上static，就可以一步标记为静态啦~  

![static](http://upload-images.jianshu.io/upload_images/2550093-8f383fc8769ec88d.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)  

使用静态batching需要额外的内存来存储合并后的几何信息，如果几个物体在静态batching前共享同一个几何图元，那么这个几何图元将会为每个物体复制一份，无论在Editor中还是runtime中都是如此。这不是一个好方法 - 有时候为了保持更小的内存占用量，你必须牺牲渲染性能为了避免一些物体的静态batching。例如，在一个稠密的森林中，标记树木为static会产生严重的内存影响。  

unity内部静态batch的原理是变换这些静态物体到世界空间，为他们建立一个很大的顶点+索引缓冲区，然后所有标记为static的物体都被放到一个batch里，一系列“廉价”的drawcall就这样完成了，这期间几乎没有状态转换，所以，这并没有省 3D API Draw call。  



| 目前只有mesh renderer可以被batch, 像skinned mesh, cloth, trail renderer和其他类型的渲染组件是不能被batch的。

半透明shader为了做透明度的工作，需要物体从后往前的顺序渲染，靠近摄像机的物体要层叠在远离相机的物体上。Unity会先对物体进行排序，然后试着batch他们，蛋由于这个顺序是严格限制的，这就意味这相比于不透明物体，会很少有batch。

更多的是需要物体在建模层面合并网格，减少gameobject的产生，合并贴图，减少贴图片数，这比在unity中做大量操作更加有效。