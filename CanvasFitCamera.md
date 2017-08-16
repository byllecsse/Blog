
# Canvas 自适应屏幕宽高

``` csharp
using UnityEngine;
using System.Collections;

[ExecuteInEditMode]
public class FitCamera : MonoBehaviour
{
    public float ZPosition = 22f;

    void Start()
    {
        if (Application.isEditor && !Application.isPlaying)
        {
            fitCamera();
        }
        GetComponent<Canvas>().worldCamera = Camera.main;
    }

    void Update()
    {
        if (Application.isEditor && !Application.isPlaying)
        {
            fitCamera();
        }
    }

    void fitCamera()
    {
        RectTransform rectTransform = this.GetComponent<RectTransform>();
        rectTransform.sizeDelta = new Vector2(1920, 1080);
        Camera SuperDCamera = Camera.main;

        float pos = ZPosition;
        transform.position = SuperDCamera.transform.position + SuperDCamera.transform.forward * pos;
        float h = Mathf.Tan(SuperDCamera.fieldOfView * Mathf.Deg2Rad * 0.5f) * pos * 2f;

        float scaleY = h / rectTransform.rect.height;
        float scaleX = (h * SuperDCamera.aspect) / rectTransform.rect.width;
        transform.localScale = new Vector3(scaleX, scaleY, scaleY);
    }

}

```