using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class MipmapTest : MonoBehaviour
{
    Material mat;
    RenderTexture rt;
    [SerializeField] Shader shader;

	void OnEnable ()
    {
        mat = new Material(shader);
        rt = new RenderTexture(1200, 800, 0, RenderTextureFormat.ARGB32);
        rt.useMipMap = true;

	}

     void OnDisable()
    {
        Destroy(mat);
        rt.Release();
    }

    void OnRenderImage(RenderTexture src, RenderTexture dst)
    {
        Graphics.Blit(src, rt, mat);
        Graphics.Blit(rt, dst, mat);
    }
}
