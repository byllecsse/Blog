# 优化Unity启动速度

## Multithreaded rendering

> 你可以在3.5之后的版本PlayerSettings-Other Settings-Rendering中开启。  

 这个特性最早出现在Unity3.5版本中，对于多核的平台开启后可以提升渲染速度，尤其是大场景渲染速度的提升，不过对编程角度说，可以操作的空间不大，Unity整体是单线程运行，这只不过是Unity提供的封装好的非单线程的渲染方式，对主线程和工作线程，即代码运行没有效果。  

从实现上看，Unity调用了OpenGL开启另一个渲染线程，并行处理任务，举个例子：两幅图AB执行渲染任务，线性处理是先渲染A，完成后再渲染B，并行处理则是同时渲染A和B，时间上只用了线性处理的一半。  
- plugin在渲染中调用GL.IssuePluginEvent
- 提供void UnityRenderEvent(int eventID)回调


## GL

它是底层的图像渲染库，可以用来操作矩阵变换，调用OpenGL渲染指令和做底层的图形渲染任务，绝大部分情况下，Graphics.DrawMesh或CommandBuffer会比实时模型绘制更加高效。实时的GL绘制函数是无论当前材质如何都立刻执行，材质会控制最终的渲染效果（混合，纹理，等）。GL的绘制非常快，几乎是立刻执行，那以为着当你调用Update()，绘制的物体会在相机画面渲染前立刻渲染。  
