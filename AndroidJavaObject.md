[Back](index.md)
# Unity调用Android接口

## AndroidJavaObject
Unity提供了这么一个java.lang.Object的泛型实例，可以通过它从android获取object类型的数据，比如ArrayList、自定义类。

先来看一段代码：
```csharp
    AndroidModelInfo androidInfo;
    public AndroidModelInfo getAndroidModelInfo(string id, int ffrom) {
        if(androidInfo == null) {
            androidInfo = new AndroidModelInfo();
        }

        // 首先判断是否是android环境。
        // activity是另外一个AndroidJavaObject activity = javaclass.GetStatic<AndroidJavaObject>("Instance"); 具体情况下面继续说。
        // activityshi调用getAndroidModelInfo这个非静态方法，这个方法从unity传递id和ffrom参数。
        if (isAndroid) {
            AndroidJavaObject androidObject = activity.Call<AndroidJavaObject>("getAndroidModelInfo", id, ffrom);
            androidInfo.updateData(androidObject);
        }        

        return androidInfo;
    }


	// ...


    public void updateData(AndroidJavaObject obj) {
        try
        {
            mBase               = obj;

            // 这个AndroidJavaObject是一个自定义类，函数的输入输出都要两端保持一致
            // Get可以获取对象中非静态的字段值，int/string/bool都是可以直接获取的变量值，在java中string确实是引用类型，蛋表现出值类型的特性

            mId                 = mBase.Get<int>("mId");
            mTitle              = mBase.Get<string>("mTitle");
            mAuthorId           = mBase.Get<int>("mAuthorId");
            mAuthorName         = mBase.Get<string>("mAuthorName");
            mDescription        = mBase.Get<string>("mDescription");
            tags                = mBase.Get<string>("tags");
            filePath            = mBase.Get<string>("filePath");
            hasSaved            = mBase.Get<bool>("hasSaved");
            IsOnlyOneOfList     = mBase.Get<int>("IsOnlyOneOfList");
            ffrom               = mBase.Get<int>("ffrom");

            // genres 在该对象中是ArrayList<GenresInfo>，所以是用Get<AndroidJavaObject>读取
            genres = new List<GenresInfo>();
            AndroidJavaObject genresList = mBase.Get<AndroidJavaObject>("genres");
            if (genresList != null)
            {
                // 读取长度
               int len = genresList.Call<int>("size");

               AndroidJavaObject aGenresInfo;
               GenresInfo g;
               for (int i = 0; i < len; i++)
               {
                    // 循环读取每个GenresInfo的对象
                   aGenresInfo = genresList.Call<AndroidJavaObject>("get", i);

                   if (aGenresInfo != null)
                   {
                       g = new GenresInfo();
                       g.title = aGenresInfo.Get<string>("title");
                   }
               }
            }
        }
        catch(Exception e)
        {
            Debug.Log("AndroidModelInfo updateData error : " + e.ToString());
        }
    }

```


来详细介绍上面代码中的activity由来。
## AndroidJavaClass
Unity提供一个创建java.lang.Class的泛型实例，可以调用android的任意类。在我的代码中，我创建的是UnityActivity，路径是package + 类名，用javaClass直接获取我在UnityAcitivity写好的Instance静态实例。

``` java
if (isAndroid)
{
    AndroidJavaClass javaclass = new AndroidJavaClass("com.example.name.UnityActivity");
    activity = javaclass.GetStatic<AndroidJavaObject>("Instance");
}
```