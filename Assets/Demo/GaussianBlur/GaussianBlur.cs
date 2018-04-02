using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class GaussianBlur : MonoBehaviour {

    Material mat;
    RenderTexture rt;
    [SerializeField] Shader shader;

    void OnEnable()
    {
        mat = new Material(shader);
    }

    void OnDisable()
    {
        Destroy(mat);
    }

    void OnRenderImage(RenderTexture src, RenderTexture dst)
    {
        Graphics.Blit(src, mat, 0);
        Graphics.Blit(src, dst, mat, 1);
    }
}
