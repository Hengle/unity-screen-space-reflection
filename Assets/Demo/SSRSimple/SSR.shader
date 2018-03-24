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

		float4 _BlurParams;
        #define _BlurOffset _BlurParams.xy
        #define _BlurNum (int)(_BlurParams.z)

		sampler2D _MainTex;

		sampler2D _CameraGBufferTexture0; // rgb: diffuse,  a: occlusion
        sampler2D _CameraGBufferTexture1; // rgb: specular, a: smoothness
        sampler2D _CameraGBufferTexture2; // rgb: normal,   a: unused
        sampler2D _CameraGBufferTexture3; // rgb: emission, a: unused
        sampler2D _CameraDepthTexture;

		sampler2D _PreAccumulationTexture;
		sampler2D _ReflectionTexture;
		sampler2D _AccumulationTexture;
		float4x4 _InvViewProj;
		float4x4 _ViewProj;
		float4 _ReflectionTexture_TexelSize;

		float noise(float2 seed)
        {
            return frac(sin(dot(seed.xy, float2(12.9898, 78.233))) * 43758.5453);
        }

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

		v2f vert_fullscreen(appdata v)
        {
            v2f o;
            o.vertex = v.vertex;
            o.screenPos = ComputeScreenPos(o.vertex);
            return o;
        }
		
		float4 reflection(v2f i) : SV_Target
        {
            float2 uv = i.screenPos.xy / i.screenPos.w;
            float4 col = tex2D(_MainTex, uv);

			//return tex2D(_CameraGBufferTexture0, uv);
			//return tex2D(_CameraGBufferTexture1, uv);
			//return tex2D(_CameraGBufferTexture2, uv);
			//return tex2D(_CameraGBufferTexture3, uv);

            float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, uv);
            if (depth <= 0.0) return col;
        
            float2 spos = 2.0 * uv - 1.0;
            float4 pos = mul(_InvViewProj, float4(spos, depth, 1.0));
            pos = pos / pos.w;


			float3 camDir = normalize(pos - _WorldSpaceCameraPos);
            float3 normal = tex2D(_CameraGBufferTexture2, uv) * 2.0 - 1.0;
            float3 refDir = reflect(camDir, normal);

			int maxRayNum = 50;
			float maxLength = 2.0;
			float  maxThickness = 0.3 / maxRayNum;
            float3 step = 2.0 / maxRayNum * refDir;

            for (int n = 1; n <= maxRayNum; ++n) {
                float3 ray = (n + noise(uv + _Time.x) * 0.5) * step;
                float3 rayPos = pos + ray;
                float4 vpPos = mul(_ViewProj, float4(rayPos, 1.0));
                float2 rayUv = vpPos.xy / vpPos.w * 0.5 + 0.5;

				if (max(abs(rayUv.x - 0.5), abs(rayUv.y - 0.5)) > 0.5) break;

                float rayDepth = ComputeDepth(vpPos);
                float gbufferDepth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, rayUv);
                if (rayDepth - gbufferDepth < 0 && rayDepth - gbufferDepth > - maxThickness) {
				    float sign = -1.0;
                    for (int m = 1; m <= 4; ++m) {
                        rayPos += sign * pow(0.5, m) * step;
                        vpPos = mul(_ViewProj, float4(rayPos, 1.0));
                        rayUv = vpPos.xy / vpPos.w * 0.5 + 0.5;
                        rayDepth = ComputeDepth(vpPos);
                        gbufferDepth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, rayUv);
                        sign = rayDepth - gbufferDepth < 0 ? -1 : 1;
                    }
                    float a = 0.2 * pow(min(1.0, (maxLength / 2) / length(ray)), 2.0);
                    col = col * (1 - a) + tex2D(_MainTex, rayUv) * a;
                    break;
                }
            }
			return col;
        }

		float4 blur(v2f i) : SV_Target
        {
            float2 uv = i.screenPos.xy / i.screenPos.w;
            float2 size = _ReflectionTexture_TexelSize;
        
            float4 col = 0.0;
            for (int n = -_BlurNum; n <= _BlurNum; ++n) {
                col += tex2D(_ReflectionTexture, uv + _BlurOffset * size * n);
            }
            return col / (_BlurNum * 2 + 1);
        }

		float4 accumulation(v2f i) : SV_Target
        {
            float2 uv = i.screenPos.xy / i.screenPos.w;
            float4 base = tex2D(_PreAccumulationTexture, uv);
            float4 reflection = tex2D(_ReflectionTexture, uv);
            float blend = 0.2;
            return lerp(base, reflection, blend);
        }
        
        float4 composition(v2f i) : SV_Target
        {
            float2 uv = i.screenPos.xy / i.screenPos.w;
            float4 base = tex2D(_MainTex, uv);
            float4 reflection = tex2D(_AccumulationTexture, uv);
            float a = reflection.a;
            return lerp(base, reflection, a);
        }

		ENDCG
				
		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment reflection
			ENDCG
		}
		Pass 
        {
            CGPROGRAM
            #pragma vertex vert_fullscreen
            #pragma fragment blur
            ENDCG
        }
		Pass
		{
		    CGPROGRAM
			#pragma vertex vert_fullscreen
			#pragma fragment accumulation
			ENDCG
		}
		Pass
		{
		    CGPROGRAM
			#pragma vertex vert
			#pragma fragment composition
			ENDCG
		}
	}
}
