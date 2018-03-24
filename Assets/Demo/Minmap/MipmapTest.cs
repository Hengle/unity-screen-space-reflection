using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class MipmapTest : MonoBehaviour
{
    Material mat;
    RenderTexture rt;
    [SerializeField] Shader shader;
    [SerializeField] int lod;

	void OnEnable ()
    {
        mat = new Material(shader);
        rt = new RenderTexture(Screen.width, Screen.height, 24);
        rt.useMipMap = true;

	}

     void OnDisable()
    {
        Destroy(mat);
        rt.Release();
    }

    void OnRenderImage(RenderTexture src, RenderTexture dst)
    {
        mat.SetInt("_LOD", lod);
        Graphics.Blit(src, rt, mat);
        Graphics.Blit(rt, dst, mat);
    }
}
