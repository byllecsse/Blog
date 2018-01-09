
[Back](index.md)

# Unity Standard Asset - ProtectCameraFromWallClip

玩塞尔达荒野之息的时候，对它的相机跟随主角中间被障碍遮挡的做法感觉很新鲜，可能是自己玩游戏略少，今天偶然发现Unity Standard Asset中有提供防止相机视野穿插的一个代码，原来这功能引擎已经提供了，感叹见世面太窄。

简单介绍下这个相机方式：第三人称视角摄像机位置和主角位置有一定的距离，如果主角与摄像机中间存在障碍物，会导致主角的画面被遮挡，或者相机穿透障碍物，这个方式确保相机与主角的直线距离不会有任何障碍物，相机会动态移动并始终在所有障碍物的前面，无论如何都会看到主角。

大致的实现方案：设定一个相机离主角的最近距离与最远距离，每帧检查相机与玩家的射线之间有多少个障碍物，存在1个或多个障碍物时，将相机的位置设置在距离玩家最近的障碍物之前，同时将相机移动到一个更好的位置。


## 解析这段代码

### 变量

``` csharp
public float clipMoveTime = 0.05f;           
public float returnTime = 0.4f;              
public float sphereCastRadius = 0.1f;        
public bool visualiseInEditor;               
public float closestDistance = 0.5f;         
public bool protecting { get; private set; } 
public string dontClipTag = "Player";        

private Transform m_Cam;                 
private Transform m_Pivot;               
private float m_OriginalDist;            
private float m_MoveVelocity;            
private float m_CurrentDist;             
private Ray m_Ray = new Ray();           
private RaycastHit[] m_Hits;             
private RayHitComparer m_RayHitComparer; 

```

**clipMoveTime**为发生遮挡后的相机移动时间，这个时间比较短，相机视角/位置的切换几乎是一瞬间，较快的过渡不会使相机切换非常突兀。