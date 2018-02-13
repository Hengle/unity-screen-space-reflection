using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[RequireComponent(typeof(Camera))]
[ExecuteInEditMode]

public class SSR : MonoBehaviour
{
    Mesh screenQuad;
    RenderTexture[] rts = new RenderTexture[2];
    [SerializeField] Shader shader;
    Material m;

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
        if (screenQuad == null) screenQuad = CreateQuad();

        UpdateAccumulationTexture();

        if (m == null) m = new Material(shader);

        var camera = GetComponent<Camera>();
        var view = camera.worldToCameraMatrix;
        var proj = GL.GetGPUProjectionMatrix(camera.projectionMatrix, false);
        var viewProj = proj * view;
        m.SetMatrix("_ViewProj", viewProj);
        m.SetMatrix("_InvViewProj", viewProj.inverse);

        var reflectionTexture = RenderTexture.GetTemporary(
             camera.pixelWidth,
             camera.pixelHeight,
             0,
             RenderTextureFormat.ARGB32);

        reflectionTexture.filterMode = FilterMode.Bilinear;

        Graphics.Blit(s, reflectionTexture, m, 0);
        m.SetTexture("_ReflectionTexture", reflectionTexture);

        m.SetTexture("_PreAccumulationTexture", rts[1]);
        Graphics.SetRenderTarget(rts[0]);
        m.SetPass(1);
        Graphics.DrawMeshNow(screenQuad, Matrix4x4.identity);

        m.SetTexture("_AccumulationTexture", rts[0]);
        Graphics.SetRenderTarget(d);
        Graphics.Blit(s, d, m, 2);

        RenderTexture.ReleaseTemporary(reflectionTexture);

        var tmp = rts[1];
        rts[1] = rts[0];
        rts[0] = tmp;
    }
}
