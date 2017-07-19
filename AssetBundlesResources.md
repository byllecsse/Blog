[Back](index.md)

# AssetBundles and Resources

今天在找AssetBundle.LoadFromMemoryAsync的使用时，发现了一篇不错的文章，记录一下：[文章地址](http://www.dongcoder.com/detail-191677.html)


### AssetBundle基础

#### 3.1 概览
AssetBundles系统提供一种手段把一个或多个Asset文件归档并能够被unity索引。目的就是分发能这些能够兼容unity序列化系统的数据，是安装后用来更新非代码内容的主要工具。使得能够减少安装包的尺寸和运行时内存压力。以及根据终端设备可选加载优化内容称为可行。  

理解AssetBundle工作流程是构建成功的Unity移动设备项目的关键。


#### 3.2 什么是AssetBundle

一个AssetBundle包含两个部分：头部和数据部分。  

头部是在构建AssetBundle时unity生成的。存放AssetBundle的信息，比如AssetBundle标记，AssetBundle是否压缩和一分清单。清单是有Object的名字作为索引的查找表。每个查找项提供一个给定名字的Object在数据段位置的字节索引。数据段包含所有Assets的序列化后的原始数据。如果数据段是压缩的。LZMA是整个数据段进行压缩的。即先把所有的Assets序列化，然后把整个字节流进行压缩。  

unity5.3之前，AssetBundle内部不能单个Object压缩。如果是使用5.3之前的版本，如果要读取一个或者多个Obect，Unity就要解压整个AssetBundle。一般来说unity会缓存未压缩的版本来提高以后的加载效率。  

5.3加入了LZ4压缩选型。用LZ4选项构造的AssetBundle会以单个Object为单位进行压缩。是的加载单个Object不用解压整个AssetBundle。  


#### 3.3 AssetBundle管理器  

Unity开发了一个AssetBundle的开源参考实现，可以从[这里](https://bitbucket.org/Unity-Technologies/assetbundledemo)下载.


#### 3.4 加载AssetBundle

在Unity5里面，AssetBundle可以通过4个API加载AssetBundle。这四个api会随着以下两个情况行为有所不同

AssetBundle是LZMA压缩还是LZ4压缩或者是未压缩的
加载AssetBundle的平台
这四个Api分别是 AssetBundle.LoadFromMemoryAsync、 LoadFromFile、

LoadFromCacheOrDownLoad 和UnityWebRequest的DownloadHandlerAssetBundle。

#### 3.4.1 LoadFromMemoryAsync

Unity建议不要用这个API。在5.3.2之前这个API名字叫CreateFromMemory。名字不一样但是功能一样。

这个方法从托管字节数组里面加载AssetBundle。他总是先将托管字节数组拷贝成本体字节数组。如果是LZMA压缩的，拷贝的时候就进行了解压。如果没压缩在原样拷贝。

这个api至少需要两倍的AssetBundle的尺寸内存。从AssetBundle里面加载的Asset会在内存里面拷贝3次：一次托管字节数组，一次本地内存拷贝还有一次就是Asset自身子啊GPU或者系统内存占用。

#### 3.4.2 LoadFromFile

5.2之前叫CreateFromFile，名字不一样，但是功能是一样的。

如果是加载一个未压缩的AssetBundle，这api十分高效。如果是未压缩或者LZ4压缩，api行为如下：

移动设备上API只加载头信息。只要在Load一个Object才会去加载特定的对象。不会浪费别的内存。

在编辑器里面会加载整个AssetBundle进内存。

注意在安卓设备上，如果版本是5.3或者更老的版本，从StreamAssts目录加载会失败。因为这些内容在一个压缩的jar包里面。5.4后面修复了这个bug。

#### 3.4.3 LoadFromCacheOrDownLoad

如果是从远程服务器上加载资源这是一个有用的api。如果是从本地文件系统加载可以用file://URL形式。如果内容已经存在本地缓存。这个api就和LoadFromFile一样。

如果没有缓存，就会从源处读取内容，如果是压缩的，他会用一个工作线程解压然后写进缓存。一旦缓存，则是未压缩的AssetBundle。

#### 3.4.4 AssetBundleDownLoadHandler

5.3后为移动平台引进的api。比WWW更具弹性。允许开发者指定如果处理下载的数据以便消除不必要的内存消耗。

#### 3.4.5 建议

一般来说，尽量使用LoadFromFile API。他更有效速度更快。如果需要从远程下载资源，5.3或更新的版本建议用UnityWebRequest，老的版本用WWW。

#### 3.5 从AssetBundle加载Asset

可以用三个不同的api从AssetBundle加载Object：LoadAsset、LoadAllAsset和LoadAssetWithSubAsset。这些api都有异步版本。同步api会比异步要快至少1帧。在5.1或者更老的版本可以这么说。因为在这些版本中一帧至多只加载一个Object。这意味着加载多个Object的异步api版本会比相应的同步版本慢很多。5.2之后修复了这个问题。可以再一帧里面加载多个Object，加载多少要视设置的时间片。

当要加载多个不相关的Object时应该用LoadAllAssets。但是也只有在加载大部分或者全部时才使用。相比另外两个API，LoadALL版本会稍微快一些。但是如果AssetBundle里面资源很多，而要加载的不超过三分之二。建议重新分割AssetBundle为多个更小的AssetBundle，然后调用LoadAll版本。

加载细节：  

加载不是在主线程上面运行的。其中数据读取是在工作线程上执行的。5.3之前加载对象是顺序执行，而且某些部分职能在主线程上面执行。当工作线程读完数据。他就会暂停执行让主线程进行整合集成(integration),直到主线程整合完毕才继续工作。5.3之后，对象加载可以并行。多个对象可以再工作线程上面反序列化，处理和整合。当对象完成加载。Awake回调会执行，然后在下一帧就可用了。

#### 3.5.2 AssetBundle依赖

Unity5 的AssetBundle系统。AssetBundle的依赖关系是可以通过两个不同的api自动跟踪的。在编辑器里面，依赖关系可以通过assetdatabase api来查询。AssetBundle的分配和依赖可以通过AssetImporter API来访问和改变。运行时可以通过ScriptableObject的子类的 AssetBundleManifest API来访问。

如果一个AssetBundle的object引用到一个或者多个另外一个AssetBundle的Object，我们就称为AssetBundle依赖。就像第一部分描述的，AssetBundle可以作为其内部包含的object的本地ID和GUID的数据源。

因为Object只有在实例ID首次被引用时才加载。而且AssetBundle被加载的时候，才会被赋予一个正确的实例ID。因此AssetBundle加载的顺序是无关的。重要的是要先于加载一个对象之前先加载它所依赖的AssetBundle们。Unity不会自动加载所有的依赖AssetBundle，这是开发者的责任。

比如一个材质A引用一个贴图B。A打包进AssetBundle1，B打包进AssetBundle2.在这个用例中，AssetBundle2必须先与从AssetBundle1中加载材质A之前加载。但这并不要AssetBundle2比AssetBundle1先加载。

Unity不会再AssetBundle1加载的时候自动加载AssetBundle2.这必须手工通过脚本加载。而且加载AssetBundle1和2的api是无关的。无论是通过哪种api加载都可以。

#### 3.5.3 AssetBundle清单

当通过buildpipeline生成AssetBundle时候，unity会生成一个依赖关系信息到一个单独的AssetBundle里面。放在所有的AssetBundles存放的共同父目录里面。他的里面存放了一个 AssetBundleManifest类型。它提供了一个GetAllAseetBundles API来查询所有的AssetBundle。 GetAllDependencies返回所有的依赖。包括一个依赖的依赖，以及依赖的依赖的依赖等等。GetDirectDependencies只返回直接依赖。

#### 3.5.4 建议

建议只加载所需要的对象。特别是移动平台上，因为他们本地存储读取速度非常慢，而且加载和卸载Object会触发垃圾回收。
