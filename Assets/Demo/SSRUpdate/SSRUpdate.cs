using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class SSRUpdate : MonoBehaviour
{
    enum ViewMode { Original, Normal, Reflection, CalcCount, MipMap, Diffuse, Speclar, Occlusion, Smmothness }
    [SerializeField] Shader shader;
    [SerializeField] ViewMode viewMode;
    [SerializeField] [Range(0, 5)] int maxLOD = 3;
    [SerializeField] [Range(0, 100)] int maxLoop = 100;
    [SerializeField] [Range(0, 100)] float maxRayLength = 3;
    [SerializeField] [Range(0.0001f, 0.1f)] float baseRaise = 0.00001f;
    [SerializeField] [Range(0.001f, 0.1f)] float thickness = 0.01f;
    [SerializeField] [Range(0.01f, 0.1f)] float rayLengthCoeff = 0.01f;

	Material mat;
    RenderTexture dpt;
    Camera cam;

	void OnEnable()
    {
        mat = new Material(shader);
        dpt = new RenderTexture(Screen.width, Screen.height, 24);
        dpt.useMipMap = true;
        dpt.autoGenerateMips = true;
        dpt.enableRandomWrite = true;
        dpt.filterMode = FilterMode.Bilinear;
        dpt.Create();
        cam = GetComponent<Camera>();
	}

    void OnDisable()
    {
        Destroy(mat);
        dpt.Release();
    }

    void Update()
    {
        var resolution = new Vector2Int(cam.pixelWidth, cam.pixelHeight);

        if(dpt != null && (dpt.width != resolution.x || dpt.height != resolution.y)) dpt.Release();

        if(dpt == null || !dpt.IsCreated())
        {
            dpt = new RenderTexture(Screen.width, Screen.height, 24);
            dpt.useMipMap = true;
            dpt.autoGenerateMips = true;
            dpt.enableRandomWrite = true;
            dpt.filterMode = FilterMode.Bilinear;
            dpt.Create();
        }
    }

    void OnRenderImage(RenderTexture src, RenderTexture dst)
    {
        Graphics.Blit(src, dpt, mat, 0);

        // world <-> screen matrix
        var view = cam.worldToCameraMatrix;
        var proj = GL.GetGPUProjectionMatrix(cam.projectionMatrix, false);
        var viewProj = proj * view;
        mat.SetMatrix("_ViewProj", viewProj);
        mat.SetMatrix("_InvViewProj", viewProj.inverse);


        mat.SetFloat("_BaseRaise", baseRaise);
        mat.SetFloat("_Thickness", thickness);
        mat.SetFloat("_RayLenCoeff", rayLengthCoeff);


        mat.SetFloat("_MaxRayLength", maxRayLength);
        mat.SetInt("_ViewMode", (int) viewMode);
        mat.SetInt("_MaxLOD", maxLOD);
        mat.SetInt("_MaxLoop", maxLoop);

        mat.SetTexture("_CameraDepthMipmap", dpt);

        Graphics.Blit(src, dst, mat, 1);
    }
}
