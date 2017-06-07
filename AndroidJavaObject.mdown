```csharp
    AndroidModelInfo androidInfo;
    public AndroidModelInfo getAndroidModelInfo(string id, int ffrom) {
        if(androidInfo == null) {
            androidInfo = new AndroidModelInfo();
        }

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

            genres = new List<GenresInfo>();
            AndroidJavaObject genresList = mBase.Get<AndroidJavaObject>("genres");
            if (genresList != null)
            {
               int len = genresList.Call<int>("size");

               AndroidJavaObject aGenresInfo;
               GenresInfo g;
               for (int i = 0; i < len; i++)
               {
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