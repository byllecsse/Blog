[返回](index.md)

# OpenGL ES绘制三角形

本文代码来自[这里](http://wiki.jikexueyuan.com/project/opengl-es-guide/triangle.html)，学习记录，并且添加代码注释。

定义6个顶点，使用三种不同模式在绘制三角形：
```java
float vertexArray[] = {
	 -0.8f, -0.4f * 1.732f, 0.0f,
	 0.0f, -0.4f * 1.732f, 0.0f,
	 -0.4f, 0.4f * 1.732f, 0.0f,
	 0.0f, -0.0f * 1.732f, 0.0f,
	 0.8f, -0.0f * 1.732f, 0.0f,
	 0.4f, 0.4f * 1.732f, 0.0f,
};
```

**ByteBuffer.allocateDirect()**
在Java中我们要对数据进行更加底层的操作时，通常是操作数据的字节(byte)，ByteBuffer提供了两种静态实例方法：

```java
public static ByteBuffer allocate(int capacity)  ;
public static ByteBuffer allocateDirect(int capacity)  ;
```

提供两种方式的原因是：这和Java的内存使用机制有关。
1. allocate产生的内存开销是在JVM中；
2. allocateDirect产生的内存开销是在JVM之外的，也就是系统级的内存分配。

当Java程序接收到外部传来的数据时，首先是被系统内存所获取，然后在由系统内存复制拷贝到JVM内存中供Java程序使用。所以在第二种分配方式中，可以省去复制这一步操作，效率上会有所提高。但是系统级内存的分配比起JVM内存的分配要耗时得多，所以并不是任何时候allocateDirect的操作效率都是最高的。



```java
public void DrawScene(GL10 gl) {
	 super.DrawScene(gl);

	 // 在系统内存中开辟顶点数组相当的内存空间
	 ByteBuffer vbb = ByteBuffer.allocateDirect(vertexArray.length * 4);
	 // 设置byteBuffer的字节序
	 vbb.order(ByteOrder.nativeOrder());

	 // 获取FloatBuffer缓冲视图，可用来直接写入float
	 FloatBuffer vertex = vbb.asFloatBuffer();
	 // 将给定的float写入给定的buffer内存位置
	 vertex.put(vertexArray);
	 vertex.position(0);

	 // 初始化单位矩阵
	 gl.glLoadIdentity();
	 // 坐标平移变换
	 gl.glTranslatef(0, 0, -4);
	 gl.glEnableClientState(GL10.GL_VERTEX_ARRAY);
	 // 为后面的Opengl绘图准备顶点数据
	 gl.glVertexPointer(3, GL10.GL_FLOAT, 0, vertex);

	 index++;
	 index%=10;
	 switch(index) {
		 case 0:
		 case 1:
		 case 2:
			 gl.glColor4f(1.0f, 0.0f, 0.0f, 1.0f);
			 gl.glDrawArrays(GL10.GL_TRIANGLES, 0, 6);
		 break;

		 case 3:
		 case 4:
		 case 5:
			 gl.glColor4f(0.0f, 1.0f, 0.0f, 1.0f);
			 gl.glDrawArrays(GL10.GL_TRIANGLE_STRIP, 0, 6);
		 break;

		 case 6:
		 case 7:
		 case 8:
		 case 9:
			 gl.glColor4f(0.0f, 0.0f, 1.0f, 1.0f);
			 gl.glDrawArrays(GL10.GL_TRIANGLE_FAN, 0, 6);
		 break;
	 }
	 gl.glDisableClientState(GL10.GL_VERTEX_ARRAY);
}  
```
这里 index 的目的是为了延迟一下显示（更好的做法是使用固定时间间隔）。前面说过 GLSurfaceView 的渲染模式有两种，一种是连续不断的更新屏幕，另一种为 on-demand ，只有在调用 requestRender() 在更新屏幕。 缺省为 RENDERMODE_CONTINUOUSLY 持续刷新屏幕。  

OpenGLDemos 使用的是缺省的 RENDERMODE_CONTINUOUSLY 持续刷新屏幕 ，因此 Activity 的 drawScene 会不断的执行。本例中屏幕上顺序以红，绿，蓝色显示 TRIANGLES， TRIANGLE_STRIP,TRIANGLE_FAN。

![运行截图](http://wiki.jikexueyuan.com/project/opengl-es-guide/images/58.png)


**glVertexPointer (int size, int type, int stride, Buffer pointer)**
- 第一个参数表示坐标的维数，可以是2或者3，如果是2，则坐标为（x,y），z轴默认为0；如果是3，则坐标为(x,y,z);
-  第二个参数可以是GL10.GL_FIXED或者GL10.GL_FLOAT，如果是GL10.GL_FIXED，则第四个参数为IntBuffer类   型，如果为GL10.GL_FLOAT，则第四个参数为FloatBuffer类型;
- 第三个参数表示步长.


**glDrawArrays (int mode, int first, int count)**
第一个参数有三种类型GL10.GL_TRIANGLES、GL10.GL_TRIANGLE_FAN、GL10.GL_TRIANGLE_STRIP.
| GL_TRIANGLES：每三个顶之间绘制三角形，之间不连接
| GL_TRIANGLE_FAN：以V0V1V2,V0V2V3,V0V3V4，……的形式绘制三角形
| GL_TRIANGLE_STRIP：顺序在每三个顶点之间均绘制三角形。这个方法可以保证从相同的方向上所有以三角形均被绘制。以V0V1V2,V1V2V3,V2V3V4……的形式绘制三角形，每三个相邻点。