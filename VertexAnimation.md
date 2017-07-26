[返回](index.md)

# 顶点动画

使用定点着色器，我们可以最大限度地控制模型，创造出如海洋的波浪，挥舞的旗帜或者使用顶点颜色进行着色等，用程序的计算模拟重复性或者随机性的动画，但这种改变仅限于顶点的大面积浮动，对于角色模型的行为动画，还是需要动画师绑定。

顶点函数在每个顶点上都会被发送到GPU执行一次，它的任务是从3D Local space物体上得到顶点，并且将它以正确的位置渲染到2D屏幕，可以修改顶点的一些元素，像是顶点位置、顶点颜色和UV坐标。

### 顶点移动

平面波浪，这是一个x轴的波浪，实现也比较简单，不断的矩阵运算，改变定点x的位置，只改变x的位置，这个4x4的矩阵只有(0, 0)的值是非1的，其他y/z/w保持不变，(1,1)/(2,2)/(3,3)值为1.你要说为何是矩阵运算而不是向量相加减, appdata_base的vertex是float4类型的呀，有的地方给出了答案：用矩阵乘以一个向量是用一组精确的规则定义的，这样做是为了以一组特定的方式来改变向量的值。

![平面波浪](https://picabstract-preview-ftn.weiyun.com:8443/ftn_pic_abs_v2/b98e3a9b77dd98e8c9d3033278afe4de92e3c9948bd5619b6d8dbd907f2bce7b3264d6cead4fdd88b76ea14bf6856ac9?pictype=scale&from=30113&version=2.0.0.2&uin=287874300&fname=991f03b2-12d8-4364-aa28-d6691e18616f.jpg&size=1024)

```
v2f vert(appdata v)
{
	v2f o;
	float4x4 m = {
		float4(sin(v.vertex.z + _Time.y) / 8 + 0.5, 0, 0, 0),
		float4(0, 1, 0, 0);
		float4(0, 0, 1, 0);
		float4(0, 0, 0, 1);
	};
	v.vertex = mul(m, v.vertex);
	o.vertex = mul(UNITY_MVP_MATRIX, v.vertex);
	o.uv = TRANSFORM_TEX(v.uv, _MainTex);
	return o;
}

#### 各种水波

![横行](https://picabstract-preview-ftn.weiyun.com:8443/ftn_pic_abs_v2/1e28c39bfd5905ce54f9f1413fa0c8276fb1238d8876380338f31900ecc3618d1e601f63cc88196b14d5139895a24406?pictype=scale&from=30113&version=2.0.0.2&uin=287874300&fname=0d30268c-c8f1-4ec7-9db6-528f20409172.jpg&size=1024)

y轴上的水波浪实现，按照sin或者cos的值变化改变顶点y，获得一个在x轴方向上移动的波纹.

```
struct v2f
{
    float4 color : COLOR;
    float4 vertex : SV_POSITION;
};
v2f vert (appdata v)
{
    v2f o;
    v.vertex.y = 0.5 * sin(v.vertex.x + _Time.y); // A* sin(B * x + c)分别是振幅/频率/偏移
    o.vertex = UnityObjectToClipPos(v.vertex);
    float r = v.vertex.y;
    o.color = float4(r, r, r, 1);
    return o;
}
float4 frag (v2f i):COLOR
{
    // sample the texture
    return i.color;
}
```

![圆形](https://picabstract-preview-ftn.weiyun.com:8443/ftn_pic_abs_v2/29c8aef631af5fad6a4ca19d3508cb023889eb25f2557b20e5d278e28a2a75739edf93a422a4d932f30c0619b4b542a4?pictype=scale&from=30113&version=2.0.0.2&uin=287874300&fname=11e11c4d-0daf-4fe5-8801-11441090a5f1.jpg&size=1024)

或者是使用原点到顶点xz的长度作为变化参数，得到一个这样的从外向内的圆圈图形变换
```
//要想圆圈从圆心出发，将lenght(v.vertex.xz)取负数即可
v.vertex.y = 0.5 * sin(length(v.vertex.xz) * 2 + _Time.y);
```

![斜行]()


### 顶点旋转

在顶点函数中，顶点的位置可以任意通过矩阵变换得到，矩阵的变换就运用到了之间课程的数学知识，变换后的顶点位置再做一次MVP变换，得到摄像机所见的图像，下图这个“风车”会正向逆向交替转动。

![顶点动画“风车”](https://picabstract-preview-ftn.weiyun.com:8443/ftn_pic_abs_v2/6c9b9e83a7b9be2e1eb5f6e10fe8ae5a8f8455fcddd1ca563667e18a0afb17ddee92f2d59094c28ae405f2b65b44f88f?pictype=scale&from=30113&version=2.0.0.2&uin=287874300&fname=e2865540-9e40-485a-834d-afdd0303e526.jpg&size=1024)

所有顶点都围绕y轴旋转了angle度，angle是离中心点越远角度越大，然后要让这个角度不断随着时间变换，unity shader提供了_SinTime，这个随着时间变化的正弦值，注意这个正弦值是fixed4，它的x/y/z/w的值都不相同。这个顶点的变换涉及到矩阵乘法计算空间中的围绕轴旋转，下列代码中是围绕y轴的顶点选择变换。  

```
v2f vert(appdata_base i)
{
	v2f o;
	fixed angle = length(i.vertex) * _sinTime.w;
	fixed4 m = {
		fixed4(cos(angle), 0, sin(angle), 0),
		fixed4(0, 1, 0, 0),
		fixed4(-sin(angle), 0, cos(angle), 0),
		fixed4(0, 0, 0, 1)
	};

	m = mul(UNITY_MATRIX_MVP, m);
	o.vertex = mul(m, i.vertex);
}
```

1. 绕x轴旋转
	1		0		0		0
	0	  	cos		sin 	0
	0	    -sin 	cos 	0
	0		0		0		1
2. 绕y轴旋转
	cos		0		-sin 	0
	0		1		0		0
	sin 	0		cos		0
	0		0		0		1
3. 绕z轴旋转
	cos		sin 	0 		0
	-sin 	cos		0		0
	0		0		1		0
	0		0		0		1

这些矩阵可以由二维推到而来，详细请看[这](http://www.cnblogs.com/graphics/archive/2012/08/08/2609005.html)

[这里](http://www.opengl-tutorial.org/cn/beginners-tutorials/tutorial-3-matrices/)介绍了坐标空间和MVP变换。