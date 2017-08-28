[back](index.md)

# 根据ID获得外部的Texture

大多数时候Unity运行在其他平台，可以借用其他平台的力量，辅助自己，比如说这一篇说要说的，利用Android线程下载图片，用OpenGL的方式获取图片的TextureId，Unity提供了一个根据此TextureId创建Texture的方法：  
Texture2D.CreateExternalTexture(int width, int height, TextureFormat format, bool mipmap, bool linear, IntPtr nativeTex)  
这样我们可以充分借助平台优势，减轻Unity线程的网络下载压力。

###### 在Android平台上获取TextureId

``` java
private DisplayImageOptions displayImageOptions = 
(new DisplayImageOptions.Builder().cacheOnDisk(true).cacheInMemory(true)).build();

public Bitmap getBitmap(String url) {
	// ImageLoader是封装好的图片加载类，com.nostra13.universalimageloader.core
    ImageLoader imageLoader = ImageLoader.getInstance();
    Bitmap bitmap = imageLoader.loadImageSync(url, displayImageOptions);

    if (bitmap != null) {
        Matrix flip = new Matrix();
        flip.postScale(1f, -1f);	// 用矩阵将图片上下/左右转换
        Bitmap bmp = Bitmap.createBitmap(bitmap, 0, 0, 
        	bitmap.getWidth(), bitmap.getHeight(), flip, true);
        return bmp;
    }
    return null;
}
public int getTextureId(Bitmap bitmap) {
    if (bitmap == null)
        return 0;
    int[] newTexId = new int[1];
    // 创建纹理
    GLES20.glGenTextures(1, newTexId, 0);
    int textureId = newTexId[0];

    if (newTexId[0] != 0) {
    	// 将新建的纹理和编号绑定
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, textureId);
        // 设置纹理的参数
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR);
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR);
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_S, GLES20.GL_CLAMP_TO_EDGE);
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_T, GLES20.GL_CLAMP_TO_EDGE);
        // 把图片数据拷贝到纹理中
        GLUtils.texImage2D(GLES20.GL_TEXTURE_2D, 0, GLES20.GL_RGBA, bitmap, 0);
        bitmap.recycle();
    }
    return textureId;
}
```

只要给出图片url，可以加载图片，获取TextureId，就差Unity调用了，本次图片加载的情景是横向的列表，每屏显示3~5张图片，左右滑动加载新item，并填充相应的图片，所以说是Unity为主导的代码执行。  

在fillData中获取item的数据类，根据info.imageUrl请求图片，在LoadTexture中，开启一个Loom线程，调用Android接口传值imageUrl获得bitmap后，再根据bitmap调用Android接口，拿到TextureId后，切回主线程创建TextureId对应的Texture.  

``` csharp
public void LoadTexture(string imageUrl, CreateNativeTexture textureHandler) {
	Loom.RunAsync(() => {
		int textureID = -1;
		int width = 0, height = 0;
		// 附加当前线程到一个Java(Dalvik)虚拟机
		AndroidJNI.AttachCurrentThread();
		AndroidJavaObject bitmap = null;

		try
		{
			bitmap = getBitmap(imageUrl); // 调用Android getBitmap()
            width = bitmap.Call<int>("getWidth");
            height = bitmap.Call<int>("getHeight");
        }
        catch (Exception e) {

			Debug.Log("LoadTexture Exception: " + e);
		}
		finally {
			// 从一个Java（Dalvik）虚拟机，分类当前线程
			AndroidJNI.DetachCurrentThread();
		}

		if(bitmap != null) {
			Loom.QueueOnMainThread(() => {

				textureID = GetTextureId(bitmap);
				// 使用回调函数执行，对当前的代码执行进行一个等待操作
                textureHandler(width, height, textureID);
			});
		}
	});
}

// ImageView负责图片显示的类
InterfaceManager.Instance.LoadTexture(mUrl, (int width, int height, int textureId) => 
{
    Texture2D texture = Texture2D.CreateExternalTexture(width, height, 
    	TextureFormat.RGBA32, false, false, (IntPtr)textureId);
    SetTexture(texture);
});		

```