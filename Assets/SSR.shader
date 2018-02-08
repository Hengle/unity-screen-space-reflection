Shader "Unlit/SSR"
{
	Properties
	{
		_MainTex ("Base (RGB)", 2D) = "" {}
	}
	SubShader
	{
		Blend Off
        ZTest Always
        ZWrite Off
        Cull Off

        CGINCLUDE

		#include "UnityCG.cginc"

		float4 _Params1;
        #define _RaytraceMaxLength        _Params1.x
        #define _RaytraceMaxThickness     _Params1.y
        #define _ReflectionEnhancer       _Params1.z
        #define _AccumulationBlendRatio   _Params1.w

		sampler2D _MainTex;
		sampler2D _CameraDepthTexture;
		sampler2D _CameraGBufferTexture2;
		float4x4 _InvViewProj;
		float4x4 _ViewProj;

		float ComputeDepth(float4 clippos)
        {
        #if defined(SHADER_TARGET_GLSL) || defined(SHADER_API_GLES) || defined(SHADER_API_GLES3)
            return (clippos.z / clippos.w) * 0.5 + 0.5;
        #else
            return clippos.z / clippos.w;
        #endif
        }

		struct appdata
    	{
    		float4 vertex : POSITION;
    		float2 uv : TEXCOORD0;
    	};

		struct v2f
		{
			float4 vertex : SV_POSITION;
			float4 screenPos : TEXCOORD0;
		};

		v2f vert (appdata v)
		{
			v2f o;
			o.vertex = UnityObjectToClipPos(v.vertex);
			o.screenPos = ComputeScreenPos(o.vertex);
			return o;
		}
		
		float4 frag(v2f i) : SV_Target
        {
            float2 uv = i.screenPos.xy / i.screenPos.w;
            float4 col = tex2D(_MainTex, uv);
        
            float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, uv);
            if (depth >= 1.0) return col;
        
            float2 spos = 2.0 * uv - 1.0;
            float4 pos = mul(_InvViewProj, float4(spos, depth, 1.0));
            pos = pos / pos.w;


			float3 camDir = normalize(pos - _WorldSpaceCameraPos);
            float3 normal = tex2D(_CameraGBufferTexture2, uv) * 2.0 - 1.0;
            float3 refDir = normalize(camDir - 2.0 * dot(camDir, normal) * normal);


			int maxRayNum = 100;
            float maxLength = _RaytraceMaxLength;
            float3 step = maxLength / maxRayNum * refDir;
            float maxThickness = _RaytraceMaxThickness / maxRayNum;
            
            for (int n = 1; n <= maxRayNum; ++n) {
                float3 rayPos = pos + step * n;
                float4 vpPos = mul(_ViewProj, float4(rayPos, 1.0));
                float2 rayUv = vpPos.xy / vpPos.w * 0.5 + 0.5;
                float rayDepth = ComputeDepth(vpPos);
                float gbufferDepth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, rayUv);
                if (rayDepth - gbufferDepth > 0) {
                    col += tex2D(_MainTex, rayUv) * 0.2;
                    break;
                }
            }

			//return tex2D(_CameraGBufferTexture2, uv);
			//return pos;
            //return float4(refDir, 1.0);
			return col;
        }
		ENDCG
				
		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			ENDCG
		}
	}
}
