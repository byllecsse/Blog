
# 

在Awake()里进行GameManager的单例的实例化操作，先判断单例对象是否存在，再判断是否存在其他单例对象，比如场景中存在两个挂载了GameManager脚本的GameObject对象，在场景start的时候，两个GameManager会进行两次Awake()操作，实例化两个“单例”对象，所以就要判断下该单例对象是否存在，存在则替换或者销毁掉这个对象。

这个小游戏每个关卡是重新加载场景的，场景重新加载时会销毁场景中已存在的所有内容，但GameManager由于它的特殊性，是进行整个游戏管理的类，不能随着场景变换而销毁重建，所以Unity提供了一个DontDestroyOnLoad(gameObject)方法，满足场景重新加载时，某些脚本不重置的需求


Leave feedback
public static void DontDestroyOnLoad(Object target);
Makes the object target not be destroyed automatically when loading a new scene.


Awake()函数在Start()之前被调用，它在这个prefab创建初期就被执行，prefab可以从Resources中创建，也可以是直接放在场景中运行，但前提是GameObject必须是激活状态，否则Awake()会等到激活的时候才被调用执行，也就是你什么时候勾选上GameObject这个active，Awake()什么时候调用。


像是一些List<>或者GetComponent<>就可以写在Awake()中。
还有一些GameObject.Find()，Find(objName)会在整个场景中已objName这个字符串查找出匹配名称的GameObject，比如objName = "LevelImage"，那就在场景中查找"LevelImage"的GameObject，查找路径是场景中全部的节点包括子节点，类似在无序的树形结构中查找，如果是根节点的效率还会高些，叶节点的效率就非常低了，所以这个操作尽量少用，尤其不能在Update等帧循环中用for等循环调用，那个CPU开销非常惊人。


[RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
允许初始化一个运行时的类方法,含有[RuntimeInitializeOnLoadMethod]的方法会在游戏开始运行之后调用，它的调用顺序在Awake之后。Unity提供了两个调用类型：AfterSceneLoad & BeforeSceneLoad。

``` csharp
static public void CallbackInitialization()
{
    //register the callback to be called everytime the scene is loaded
    SceneManager.sceneLoaded += OnSceneLoaded;
}

//This is called each time a scene is loaded.
static private void OnSceneLoaded(Scene arg0, LoadSceneMode arg1)
{
    instance.level++;
    instance.InitGame();
}

```


Unity提供了SceneManager（我记得是5.x版本提供的新场景管理），SceneManager提供了一个事件sceneLoaded用于执行场景加载时注册的消息/监听，这样做的好处是在场景加载时可以执行一大堆的函数，而且委托调用也利于解耦。

public static event UnityAction<Scene, LoadSceneMode> sceneLoaded;
UnityAction是个泛型委托，支持两个泛型变量传入，没有返回。
public delegate void UnityAction<T0, T1>(T0 arg0, T1 arg1);


不过这里就有个疑问：InitGame()在Awake()里调用一次，在OnSceneLoad()处，每次场景加载又调用了一次，我猜测Awake()是场景运行时，由于GameObject是active的，所以这时候调用了一次，之后的每次场景重新加载调用的是onSceneLoaded(), Awake()由于只在物体激活状态下调用一次，像是用了DontDestroyOnLoad()在场景重建时不会销毁重新生成的就不会再有Awake()的调用，接下来关卡等级就通过SceneManager提供的方式来完成。


在InitGame()的末尾SetupScene()处理了地图边界和随机物品：
1. 首先是地面的处理，x=-1到x < columns + 1 比实际地图区域两边都增加一条外边界，判断最外面的边界生成外墙图片。
2. 计算随机物品的位置，用了个随机数，再遍历下区域网格，满足条件的就从gridPositions数组中剔除掉
3. 敌人移动是用协程做的，协程其实是用的每帧循环中的空闲时间执行，和多线程那套没关系，相当于Unity自己弄了个假的异步处理。不过有个不理解的是，敌人的移动写在Update()里，真的有必要在这种每帧调用的函数里开起协程吗，协程的开起本身也比较消耗CPU。



关于主角和敌人的移动，在这个例子中定义了个抽象类，继承自MonoBehaviour，因此在这个函数中可以使用MonoBehaviour生命周期中的函数，Start()被定义成了受保护的虚函数protected virtual，这个类把Player和Enemy类的公共部分抽取出来，设定为Player、Enemy的基类，可以看下它这里移动的实现：

它在移动的时候发射一条射线检测移动方向上是否存在碰撞的物体，不过在检测完碰撞后将boxCollider打开？估计是为了防止图片重叠，开启2d的碰撞盒检测，相当是用了两种防止防止碰撞，然后用协程来处理移动的缓动，协程里包括yield
``` csharp
//Move returns true if it is able to move and false if not. 
//Move takes parameters for x direction, y direction and a RaycastHit2D to heck collision.
protected bool Move (int xDir, int yDir, out RaycastHit2D hit)
{
	//Store start position to move from, based on objects current transform position.
	Vector2 start = transform.position;
	
	// Calculate end position based on the direction parameters passed in when calling Move.
	Vector2 end = start + new Vector2 (xDir, yDir);
	
	//Disable the boxCollider so that linecast doesn't hit this object's own collider.
	boxCollider.enabled = false;
	
	//Cast a line from start point to end point checking collision on blockingLayer.
	hit = Physics2D.Linecast (start, end, blockingLayer);
	
	//Re-enable boxCollider after linecast
	boxCollider.enabled = true;
	
	//Check if anything was hit
	if(hit.transform == null)
	{
		//If nothing was hit, start SmoothMovement co-routine passing in the Vector2 end as destination
		StartCoroutine (SmoothMovement (end));
		
		//Return true to say that Move was successful
		return true;
	}
	
	//If something was hit, return false, Move was unsuccesful.
	return false;
}

```