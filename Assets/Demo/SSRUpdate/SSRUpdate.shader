Shader "Unlit/SSRUpdate"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
	}
	SubShader
	{
        Blend Off
        ZTest Always
        ZWrite Off
        Cull Off

        CGINCLUDE

        #include "UnityCG.cginc"

        int _MaxLOD;
        float _MaxRayLength;
        float _Thickness;
        float _RayLenCoeff;

        float _BaseRaise;
        float4x4 _InvViewProj;
        float4x4 _ViewProj;

        sampler2D _MainTex;
        float4 _MainTex_ST;

        sampler2D _CameraGBufferTexture2; // normal texture
        sampler2D _CameraDepthTexture;
        sampler2D _CameraDepthMipmap;

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
            float4 screen : TEXCOORD0;
        };
        
        v2f vert (appdata v)
        {
            v2f o;
            o.vertex = UnityObjectToClipPos(v.vertex);
            o.screen = ComputeScreenPos(o.vertex);
            return o;
        }
        
        float4 outDepthTexture (v2f i) : SV_Target
        {
            return tex2D(_CameraDepthTexture, i.screen);
        }

        float4 reflection (v2f i) : SV_Target
        {
            float2 uv = i.screen.xy / i.screen.w;
            float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, uv);
            float4 col = tex2D(_MainTex, uv);
            if (depth <= 0.0) return tex2D(_MainTex, uv);

            float2 screenpos = 2.0 * uv - 1.0;
            float4 pos = mul(_InvViewProj, float4(screenpos, depth, 1.0));
            pos /= pos.w;

            float3 camDir = normalize(pos - _WorldSpaceCameraPos);
            float3 normal = tex2D(_CameraGBufferTexture2, uv) * 2.0 - 1.0;
            float3 refDir = reflect(camDir, normal);

            int lod = _MaxLOD;
            float currlen = 0;

            for (int n = 1; n <= 20; ++n) 
            {
                float3 step       = refDir * _RayLenCoeff * (lod + 1);
                float3 ray        = pos + n * step;                                        // head of ray
                float4 rayScreen  = mul(_ViewProj, float4(ray, 1.0));                      // screen
                float2 rayUV      = rayScreen.xy / rayScreen.w * 0.5 + 0.5;                // 0 ~ 1
                float  rayDepth   = ComputeDepth(rayScreen);
                float  worldDepth = (lod == 0)? SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, rayUV) : tex2Dlod(_CameraDepthMipmap, float4(rayUV, 0, lod)).x + _BaseRaise * lod; 

                // ignore when out of screen
                if (max(abs(rayUV.x - 0.5), abs(rayUV.y - 0.5)) > 0.5) break;

                //col = float4(rayDepth * 5, 0, 0, 1.0);
                //col = float4(worldDepth * 5, 0, 0, 1.0);

                if(rayDepth < worldDepth)
                {
                    if(lod == 0)
                    {
                        if (rayDepth + _Thickness > worldDepth) col = tex2D(_MainTex, rayUV);
                        break;
                    }
                    else
                    {
                        lod--;
                    }
                }


                // when it comes max length, break
                currlen += step;
                if(currlen > _MaxRayLength)
                {
                    break;
                };
            }
            return col;
        }

        ENDCG

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment outDepthTexture
			ENDCG
		}

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment reflection
            ENDCG
        }
	}
}
