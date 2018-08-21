
[Back](index.md)

# Unity Standard Asset - ProtectCameraFromWallClip

玩塞尔达荒野之息的时候，对它的相机跟随主角中间被障碍遮挡的做法感觉很新鲜，可能是自己玩游戏略少，今天偶然发现Unity Standard Asset中有提供防止相机视野穿插的一个代码，原来这功能引擎已经提供了，感叹见世面太窄。

简单介绍下这个相机方式：第三人称视角摄像机位置和主角位置有一定的距离，如果主角与摄像机中间存在障碍物，会导致主角的画面被遮挡，或者相机穿透障碍物，这个方式确保相机与主角的直线距离不会有任何障碍物，相机会动态移动并始终在所有障碍物的前面，无论如何都会看到主角。

大致的实现方案：设定一个相机离主角的最近距离与最远距离，每帧检查相机与玩家的射线之间有多少个障碍物，存在1个或多个障碍物时，将相机的位置设置在距离玩家最近的障碍物之前，同时将相机移动到一个更好的位置。


## 对代码分析

#### 准备

初始化了一些过渡动画需要用到的参数，类似于碰撞墙体或者障碍物的闪避时间，相机与主角之间没有障碍物的相机归位时间，相机的围绕主角半径。
``` csharp
public float clipMoveTime = 0.05f;             
public float returnTime = 0.4f;                
public float sphereCastRadius = 0.1f;          
public bool visualiseInEditor;                 
public float closestDistance = 0.5f;           
public bool protecting { get; private set; }   
public string dontClipTag = "Player";          
```

检测相机与主角之前有无障碍物，有多少个障碍物，通过相机向主角发送射线，射线检测碰撞和穿透，raycastHit甚至能返回个穿透障碍的列表，可以得知最前的障碍物，障碍物距离主角的距离排序。
``` csharp
private Ray m_Ray = new Ray();            
private RaycastHit[] m_Hits;              
private RayHitComparer m_RayHitComparer;  
```

RayHitComparer 不是UnityEngine提供的类，而是这段demo代码封装的一个raycastHit比较方法，继承自IComparer，System.Collections的接口。
重写compare()方法，比较了两个RaycastHit的距离
``` csharp
public class RayHitComparer : IComparer
{
    public int Compare(object x, object y)
    {
        return ((RaycastHit) x).distance.CompareTo(((RaycastHit) y).distance);
    }
}
```


#### 主要代码

所有的障碍物检测以及规避障碍，防止相机渲染穿透都在LateUpdate()里执行，从MonoBehaviour生命周期来看，LateUpdate()是每帧逻辑代码的时间上最后一个更新函数，同时也在画面渲染函数之前执行。

LateUpdate中的执行顺序：
1. 相机forward方向发射射线，碰撞检测；
2. Physics.OverlapSphere，获取半径内所有的Collider;
3. 如果半径内存在碰撞体（障碍），则防穿透准备；
4. 获取相机到主角的碰撞列表，找到最近的物体；
5. 启动动画。



Physics.OverlapSphere(center, radius)，选定一个半径范围，获取在这个范围内所有的Collider。  
所以cols是射线起始点sphereCastRadius范围内的所有collider。  

如果cols数组中存在非触发/非空/非不需裁剪的障碍物，则将initialIntersect=true，准备避免画面穿透。

``` csharp
// initial check to see if start of spherecast intersects anything
var cols = Physics.OverlapSphere(m_Ray.origin, sphereCastRadius);

bool initialIntersect = false;
bool hitSomething = false;

// loop through all the collisions to check if something we care about
for (int i = 0; i < cols.Length; i++)
{
    if ((!cols[i].isTrigger) &&
        !(cols[i].attachedRigidbody != null && cols[i].attachedRigidbody.CompareTag(dontClipTag)))
    {
        initialIntersect = true;
        break;
    }
}

```


如果已经存在检测到障碍物的射线，Physics.RaycastAll会获取到这条射线想一定距离里穿透的所有物体；
否则Physics.SphereCastAll获取射线一定半径内的碰撞体。

``` csharp
// if there is a collision
if (initialIntersect)
{
    m_Ray.origin += m_Pivot.forward*sphereCastRadius;

    // do a raycast and gather all the intersections
    m_Hits = Physics.RaycastAll(m_Ray, m_OriginalDist - sphereCastRadius);
}
else
{
    // if there was no collision do a sphere cast to see if there were any other collisions
    m_Hits = Physics.SphereCastAll(m_Ray, sphereCastRadius, m_OriginalDist + sphereCastRadius);
}

```



对所有的射线碰撞体依照距离进行一次排序，找到里角色最近的障碍物，这是相机的移动目的点，不过不着急动画过渡，先设置并保存状态；
转换成标定点的local space, 相机在Pivot的下一层级，所以相机的坐标是相对于pivot的进行动画移动.

![标定点位置图片](Images/ProtectCamera_pivot_position.png)

使用Mathf.SmoothDamp可以在给定时间内，将当前输入值变更为目标targetDist，如果当前位置已经超出目标位置，则过渡的时间变为retureTime.
``` csharp
// hit something so move the camera to a better position
protecting = hitSomething;
m_CurrentDist = Mathf.SmoothDamp(m_CurrentDist, targetDist, ref m_MoveVelocity,
                               m_CurrentDist > targetDist ? clipMoveTime : returnTime);
m_CurrentDist = Mathf.Clamp(m_CurrentDist, closestDistance, m_OriginalDist);
m_Cam.localPosition = -Vector3.forward*m_CurrentDist;

```



#### 总结

在相机与主角之间的射线方向上存在挂载了Collider的障碍物，用Rhysics.RaycastAll()找出所有的障碍，移动相机到障碍的最前面；  
如果主角和相机之间没有障碍，则用Physics.RaycastAll()在相机中心范围内，找到一条没有障碍物的方向，将相机移动过去，预防画面穿透。