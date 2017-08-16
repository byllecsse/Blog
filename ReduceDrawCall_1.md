[返回](index.md)

# 降低Draw Call（一）

Unity（或者说基本所有图形引擎）生成一帧画面的处理过程大致可以这样简化描述：引擎首先经过简单的可见性测试，确定摄像机可以看到的物体，然后把这些物体的顶点（包括本地位置、法线、UV等），索引（顶点如何组成三角形），变换（就是物体的位置、旋转、缩放、以及摄像机位置等），相关光源，纹理，渲染方式（由材质/Shader决定）等数据准备好，然后通知图形API——或者就简单地看作是通知GPU——开始绘制，GPU基于这些数据，经过一系列运算，在屏幕上画出成千上万的三角形，最终构成一幅图像。  

CPU准备数据并通知GPU渲染的过程就是一次DrawCall,如果这个过程出现的次数太多，就会影响CPU的执行效率，就会出现卡顿。当然，影响CPU的不仅仅只有DrawCall,还有物理组件、GC（垃圾对象太多，造成GC负担，影响CPU的执行效率）、代码质量。  

每在屏幕上绘制一个物体，Unity必须想绘图API（无论OpenGL或者Direct3D)发起一次Draw Call，Draw Call是非常昂贵的，CPU封装好数据发往GPU这个操作很耗时，所以我们要尽可能将物体封装为一次DrawCall，减少数据发送的次数，以减轻这部分的开销，另外永远不用担心GPU无法处理封装的数据，无论模型多复杂，这对于GPU来说，就是一次顶点/片元的计算，当然GPU的性能也会受顶点数量，纹理大小的限制，这些称之为GPU带宽。  


###### 为什么draw call是“昂贵的”  

stackoverflow上有个被引用了多次的回答，[地址](https://stackoverflow.com/questions/4853856/why-are-draw-calls-expensive)  
draw call本质是GPU渲染一系列顶点，处理像素着色、融合、插值，把它们合并成三角形再映射到屏幕的命令。
其实这种“昂贵”主要是性能差异导致的，GPU处理顶点和像素的速度非常快，他的硬件结构里有大量并行处理器件，可以十分高效地并行处理这些顶点，draw call如果包含一个模型，那么GPU可以一次性处理这个模型的所有顶点的变换计算，在片段着色器阶段，所有顶点构成的三角形的每一个像素又可以经过大量图元计算器件，快速计算出来。  

由于每个像素点都要计算颜色，像素点的数量远比顶点数量多得多，因此GPU中图元计算的器件比顶点计算器件要多得多。

这就造就了GPU变换和渲染三角形远比提交这些顶点的速度快，用原话说是“much faster than you can submit them”，如果大量提交数量不多的顶点，会造成CPU瓶颈，GPU被闲置，CPU的draw call提交速度不能匹配GPU的渲染速度。这就是把更多顶点封装在较少的draw call中的主要目的。  

draw call还有实际的性能消耗，它需要设置一堆的状态（比如选择要使用的顶点，选择要使用的shader），在CPU和GPU两端都要同步状态改变，更新大量的注册信息。如果draw call的提交内容很少，这些状态变换的会占用大部分的draw call性能，就非常不值得了。  

### Unity Batching

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


> 目前只有mesh renderer可以被batch, 像skinned mesh, cloth, trail renderer和其他类型的渲染组件是不能被batch的。

半透明shader为了做透明度的工作，需要物体从后往前的顺序渲染，靠近摄像机的物体要层叠在远离相机的物体上。Unity会先对物体进行排序，然后试着batch他们，蛋由于这个顺序是严格限制的，这就意味这相比于不透明物体，会很少有batch。

更多的是需要物体在建模层面**合并网格**，减少gameobject的产生，合并贴图，减少贴图片数，这比在unity中做大量操作更加有效。



## Combine Mesh

还有一种更加快捷高效的，由unity提供的合并网格方法Mesh.CombineMeshes，可以极大程度上的减少模型返工，在unity端，由开发人员进行简单的网格合并，有助于性能提升。这种网格合并方式是将其他若干个Mesh合并到当前的Mesh，这个方法提供了四个传入参数：

> public void CombineMeshes(CombineInstance[] combine, bool mergeSubMeshes = true, 
> 							bool useMatrices = true, bool hasLightmapData = false);
> combine 			要合并的Meshes
> mergeSubMeshes 	Meshes是否要合并一个单独子Mesh, 这样就可以共享material
> useMatrices		定义是否应该使用或忽略CombineInstance数组中提供的转换
> hasLightmapData 	设置mesh是否公用lightmap texture

```csharp
using UnityEngine;
using System.Collections;

[RequireComponent(typeof(MeshFilter))]
[RequireComponent(typeof(MeshRenderer))]
public class ExampleClass : MonoBehaviour {
    void Start() {
        MeshFilter[] meshFilters = GetComponentsInChildren<MeshFilter>();
        CombineInstance[] combine = new CombineInstance[meshFilters.Length];
        int i = 0;
        while (i < meshFilters.Length) {
            combine[i].mesh = meshFilters[i].sharedMesh;
            combine[i].transform = meshFilters[i].transform.localToWorldMatrix;
            meshFilters[i].gameObject.active = false;
            i++;
        }
        transform.GetComponent<MeshFilter>().mesh = new Mesh();
        transform.GetComponent<MeshFilter>().mesh.CombineMeshes(combine);
        transform.gameObject.active = true;
    }
}
```
![合并结果](https://picabstract-preview-ftn.weiyun.com:8443/ftn_pic_abs_v2/cc05f0fddf92d9ad5997ed879e6b15370d0b25bb4eb496247c2a580bb21ea7b121fe509abc294ffa9b7e656acc8bd46d?pictype=scale&from=30113&version=2.0.0.2&uin=287874300&fname=combineMesh.png&size=1024)  
这个帅！combine完后，就可以直接把子物体关掉了，因为子物体的meshes都已经合并到父物体上，如图原本11个batches的瞬间降到了3个，但为什么它要占两个batches。注：从5.x开始，draw call改名为了batches.



### 调优工具

Snapdragon Profiler
高通出品，提供三大主要系统通过USB联调Android设备，分析CPU, GPU, DSP, memory, power, thermal and network data，可以很方便地找出性能瓶颈。  

Mali Graphics Debugger
提供跟踪OpenGL ES, Vulkan和OpenCL API调用，可以很容易地分析每帧的draw call情况。


