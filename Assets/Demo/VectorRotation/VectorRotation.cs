using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class VectorRotation : MonoBehaviour
{

    Material mat;
    [SerializeField] Shader shader;
    [SerializeField] Color color;
    [SerializeField] Vector4 seed;

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
        mat.SetColor("_Color", color);
        mat.SetVector("_Seed", seed);
        Graphics.Blit(src, dst, mat);
    }
}
