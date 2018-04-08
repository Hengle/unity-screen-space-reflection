using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class GaussianBlur : MonoBehaviour
{
    Material mat;
    RenderTexture rt;
    [SerializeField] Shader shader;
    [SerializeField] int blurNum = 3;

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
        for (int i = 0; i < blurNum; i++)
        {
            Graphics.Blit(src, mat, 0);
            Graphics.Blit(src, mat, 1);
        }
        Graphics.Blit(src, dst);
    }
}
