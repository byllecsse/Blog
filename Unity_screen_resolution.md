[Back](index.md)

# 画质控制

移动平台要求在有限的机型上，做出更快更流畅的游戏，现在手机的屏幕越做越大，对于GPU来说，需要计算的像素变多了，所以可以手动地限制画面分辨率，使其不按照最大屏幕分辨率去计算渲染。

Unity提供了Screen.SetResoution来修改输出的画面分辨率，这将会在一定程度上减少渲染开销。

``` csharp
Screen.SetResolution(width, height, true); // 设置分辨率，第三个参数是fullscreen

QualitySettings.shadows = ShadowQuality.Disable; // 关闭全局阴影

QualitySettings.SetQualityLevel(index, true); // 画面质量，第二个参数为开启抗锯齿

QualitySettings.vSyncCount = count; // 垂直同步
```


A resolution switch does not happen immediately; it will actually happen when the current frame is finished.
``` csharp
using UnityEngine;

public class ExampleScript : MonoBehaviour
{
    void Start()
    {
        // Switch to 640 x 480 fullscreen at 60 hz
        Screen.SetResolution(640, 480, true, 60);
    
        // Switch to 800 x 600 windowed
        Screen.SetResolution(800, 600, false);
    }
}
```