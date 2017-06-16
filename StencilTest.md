# Stencil Test

模板测试stencil test是3d渲染管线中介于透明测试alpha test和深度测试depth test之间的测试，目的是根据条件来比较设置的参考值referenceValue和模板缓冲区stencil buff中对应的值stencilBuffValue的大小，如果条件满足就让片段fragment（候选的像素）进入下一测试，即深度测试，条件不满足就过滤掉片段，不把对应材质的片段输出到屏幕。  
它是个长度为8位的buffer，主要用于筛选pixel用，stencil buffer其实是zBuffer其中的一部分，stencil的测试与深度测试也是紧密连接，因为要用到深度测试的结果。  

语法如下：
```
Stencil
{
    Ref referenceValue 	//参考值
    ReadMask  readMask  //读取掩码，取值范围也是0-255的整数，默认值为255，二进制位11111111，即读取的时候不对referenceValue和stencilBufferValue产生效果，读取的还是原始值.

    WriteMask writeMask  //输出掩码，当写入模板缓冲时进行掩码操作（按位与【&】），writeMask取值范围是0-255的整数，默认值也是255，即当修改stencilBufferValue值时，写入的仍然是原始值.

    Comp comparisonFunction  //条件，关键字有，Greater（>），GEqual（>=），Less（<），LEqual（<=），Equal（=），NotEqual（!=），Always（总是满足），Never（总是不满足）  

    Pass stencilOperation  	//条件满足后的处理
    Fail stencilOperation  	//条件不满足后的处理
    ZFail stencilOperation  //深度测试失败后的处理
}
```

## Stencil Operation

Keep 	| 保留当前缓冲中的内容，即stencilBufferValue不变。
Zero 	| 将0写入缓冲，即stencilBufferValue值变为0。
Replace | 将参考值写入缓冲，即将referenceValue赋值给stencilBufferValue。
IncrSat	| stencilBufferValue加1，如果stencilBufferValue超过255了，那么保留为255，即不大于255。
DecrSat 	| stencilBufferValue减1，如果stencilBufferValue超过为0，那么保留为0，即不小于0。
Invert 		| 将当前模板缓冲值（stencilBufferValue）按位取反.
IncrWrap 	| 当前缓冲的值加1，如果缓冲值超过255了，那么变成0，（然后继续自增）。
DecrWrap 	| 当前缓冲的值减1，如果缓冲值已经为0，那么变成255，（然后继续自减）。

以上内容来自[这里](http://www.hiwrz.com/2016/07/09/unity/246/)


### 示例1：
```
Stencil
{
	Ref 2			// -1
	Comp always		// -2
	Pass replace	// -3
	ZFail decrWrap 	// -4
}
```
1. 参考值为2，stencilBuffer值默认为0
2. stencil的比较函数永远通过
3. pass的处理是替换，用参考值2替换buffer的值
4. ZFail的处理是深度测试失败，则溢出型减1


### 示例2：
项目需要实现一个下图所示效果，海报图片挪到tab上会截断显示。
[!demo stencil](http://a2.qpic.cn/psb?/V12VFSh93PPcnw/AWmTkmQL2g8zFUVo37ak0wdNFHBQjuYAApYOALIDV.s!/b/dNAAAAAAAAAA&bo=xQJnAQAAAAADB4M!&rf=viewer_4)

海报图片和遮罩的放置位置：
1. 是最前的一张海报，当前的焦点海报
2. 是左右的两张海报，海报都在遮罩位置的前面（离相机较近）
3. 是遮罩的位置，在所有海报的后面
[!demo stencil 1](http://a2.qpic.cn/psb?/V12VFSh93PPcnw/BN8534M9s8piPAwDZ54tqlJzmT8STWXL*EqIRhPo0sk!/b/dNAAAAAAAAAA&bo=ugEwAQAAAAADB6g!&rf=viewer_4)

这个遮罩的作用是，显示在遮罩中的海报，遮罩本身输出的RGB颜色值为0，就是不输出颜色，关闭深度写入，模板测试永远为通过，将当前pixel buffer中的0值替换为Ref定义的1.
```
Pass
{
	ColorMask 0
	ZWrite Off
	Stencil{
		Ref 1
		Comp always
		Pass replace
	}
	//...
}

```

然后在海报图片的shader，比较Ref 1和buffer中的值，由于之前mask已经把屏幕除了tab以外区域的buffer中的值替换为了1，所以只有图中显示了海报的地方才通过stencil测试，Pass默认是keep，将当前的pixel写入缓冲区，而tab区域的stencil测试失败，不写入像素。
```
Pass
{
	Blend SrcAlpha OneMinusSrcAlpha
	Stencil{
		Ref 1
		Comp equal
	}
	//...
}
```

完整代码：
- [海报shader](StencilPosterShader.md)
- [遮罩shader](StencilTabMaskShader.md)