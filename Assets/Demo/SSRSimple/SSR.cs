using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[RequireComponent(typeof(Camera))]
[ExecuteInEditMode]

public class SSR : MonoBehaviour
{
    enum Pass { reflection, blur, accumulation, composition }

    Mesh quad;
    [SerializeField] RenderTexture[] rts = new RenderTexture[2];
    [SerializeField] Shader shader;
    Material m;

    [Header("Blur")]
    [SerializeField]
    Vector2 blurOffset = new Vector2(1f, 1f);
    [SerializeField] uint blurNum = 3;

    [SerializeField] float resolution = 0.5f;
    int Width { get { return (int)(GetComponent<Camera>().pixelWidth * resolution); } }
    int Height { get { return (int)(GetComponent<Camera>().pixelHeight * resolution); } }

    Mesh CreateQuad()
    {
        Mesh mesh = new Mesh();
        mesh.name = "Quad";
        mesh.vertices = new Vector3[4]
        {
            new Vector3(1f, 1f, 0f),
            new Vector3(-1f, 1f, 0f),
            new Vector3(-1f,-1f, 0f),
            new Vector3(1f, -1f, 0f),
        };
        mesh.triangles = new int[6] {
            0, 1, 2,
            2, 3, 0
        };
        return mesh;
    }

    void ReleaseAccumulationTexture()
    {
        for (int i = 0; i < 2; ++i)
        {
            if (rts[i] != null)
            {
                rts[i].Release();
                rts[i] = null;
            }
        }
    }

    void UpdateAccumulationTexture()
    {
        var camera = GetComponent<Camera>();

        for (int i = 0; i < 2; ++i)
        {
            var resolution = new Vector2(camera.pixelWidth, camera.pixelHeight);
            if (rts[i] != null && (
                rts[i].width != (int)resolution.x ||
                rts[i].height != (int)resolution.y
            ))
            {
                ReleaseAccumulationTexture();
            }

            if (rts[i] == null || !rts[i].IsCreated())
            {
                rts[i] = new RenderTexture((int)resolution.x, (int)resolution.y, 0, RenderTextureFormat.ARGB32);
                rts[i].filterMode = FilterMode.Bilinear;
                rts[i].useMipMap = false;
                rts[i].autoGenerateMips = false;
                rts[i].enableRandomWrite = true;
                rts[i].Create();
                Graphics.SetRenderTarget(rts[i]);
                GL.Clear(false, true, new Color(0, 0, 0, 0));
            }
        }
    }

    [ImageEffectOpaque]

    private void OnRenderImage(RenderTexture s, RenderTexture d)
    {
        if (quad == null) quad = CreateQuad();
        if (m == null) m = new Material(shader);

        UpdateAccumulationTexture();


        var camera = GetComponent<Camera>();
        var view = camera.worldToCameraMatrix;
        var proj = GL.GetGPUProjectionMatrix(camera.projectionMatrix, false);
        var viewProj = proj * view;
        m.SetMatrix("_ViewProj", viewProj);
        m.SetMatrix("_InvViewProj", viewProj.inverse);

        RenderTexture reflectionTexture = RenderTexture.GetTemporary(Width, Height, 0,RenderTextureFormat.ARGB32);
        RenderTexture xBlurTexture = RenderTexture.GetTemporary(Width, Height, 0, RenderTextureFormat.ARGB32);
        RenderTexture yBlurTexture = RenderTexture.GetTemporary(Width, Height, 0, RenderTextureFormat.ARGB32);
        reflectionTexture.filterMode = FilterMode.Bilinear;
        xBlurTexture.filterMode = FilterMode.Bilinear;
        yBlurTexture.filterMode = FilterMode.Bilinear;

        Graphics.Blit(s, reflectionTexture, m, (int)Pass.reflection);
        m.SetTexture("_ReflectionTexture", reflectionTexture);

        if (blurNum > 0)
        {
            Graphics.SetRenderTarget(xBlurTexture);
            m.SetVector("_BlurParams", new Vector4(blurOffset.x, 0f, blurNum, 0));
            m.SetPass((int)Pass.blur);
            Graphics.DrawMeshNow(quad, Matrix4x4.identity);
            m.SetTexture("_ReflectionTexture", xBlurTexture);

            Graphics.SetRenderTarget(yBlurTexture);
            m.SetVector("_BlurParams", new Vector4(0f, blurOffset.y, blurNum, 0));
            m.SetPass((int)Pass.blur);
            Graphics.DrawMeshNow(quad, Matrix4x4.identity);
            m.SetTexture("_ReflectionTexture", yBlurTexture);
        }

        m.SetTexture("_PreAccumulationTexture", rts[1]);
        Graphics.SetRenderTarget(rts[0]);
        m.SetPass((int)Pass.accumulation);
        Graphics.DrawMeshNow(quad, Matrix4x4.identity);

        m.SetTexture("_AccumulationTexture", rts[0]);
        Graphics.SetRenderTarget(d);
        Graphics.Blit(s, d, m, (int)Pass.composition);

        RenderTexture.ReleaseTemporary(reflectionTexture);
        RenderTexture.ReleaseTemporary(xBlurTexture);
        RenderTexture.ReleaseTemporary(yBlurTexture);

        RenderTexture tmp = rts[1];
        rts[1] = rts[0];
        rts[0] = tmp;
    }
}
