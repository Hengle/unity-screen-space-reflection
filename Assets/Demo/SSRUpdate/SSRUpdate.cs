using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class SSRUpdate : MonoBehaviour
{
    [SerializeField] Shader shader;
    [SerializeField] [Range(0, 6)] int maxLOD = 3;
    [SerializeField] [Range(0, 10)] float maxRayLength = 3;
    [SerializeField] [Range(0.0001f, 0.1f)] float baseRaise = 0.00001f;
    [SerializeField] [Range(0.01f, 0.5f)] float thickness = 0.01f;
    [SerializeField] [Range(0.01f, 0.1f)] float rayLengthCoeff = 0.01f;

	Material mat;
    RenderTexture dpt;
    Camera cam;

	void OnEnable()
    {
        mat = new Material(shader);
        dpt = new RenderTexture(Screen.width, Screen.height, 24);
        dpt.useMipMap = true;

        cam = GetComponent<Camera>();
	}

    void OnDisable()
    {
        Destroy(mat);
        dpt.Release();
    }

    void OnRenderImage(RenderTexture src, RenderTexture dst)
    {
        Graphics.Blit(src, dpt, mat, 0);


        var view = cam.worldToCameraMatrix;
        var proj = GL.GetGPUProjectionMatrix(cam.projectionMatrix, false);
        var viewProj = proj * view;

        mat.SetFloat("_BaseRaise", baseRaise);
		mat.SetFloat("_Thickness", thickness);
        mat.SetFloat("_RayLenCoeff", rayLengthCoeff);
        mat.SetMatrix("_ViewProj", viewProj);
        mat.SetMatrix("_InvViewProj", viewProj.inverse);

        mat.SetFloat("_MaxRayLength", maxRayLength);
        mat.SetInt("_MaxLOD", maxLOD);

        mat.SetTexture("_CameraDepthMipmap", dpt);

        Graphics.Blit(src, dst, mat, 1);
    }
}
