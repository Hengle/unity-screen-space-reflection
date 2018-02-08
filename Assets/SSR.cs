using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[RequireComponent(typeof(Camera))]
[ExecuteInEditMode]

public class SSR : MonoBehaviour
{

    [SerializeField] Shader shader;
    Material m;

    [ImageEffectOpaque]

    private void OnRenderImage(RenderTexture s, RenderTexture d)
    {
        if (m == null) m = new Material(shader);

        var camera = GetComponent<Camera>();
        var view = camera.worldToCameraMatrix;
        var proj = GL.GetGPUProjectionMatrix(camera.projectionMatrix, false);
        var viewProj = proj * view;
        m.SetMatrix("_ViewProj", viewProj);
        m.SetMatrix("_InvViewProj", viewProj.inverse);

        Graphics.Blit(s, d, m, 0);
    }
}
