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

		int _ViewMode;
        int _MaxLOD;
		int _MaxLoop;
        float _MaxRayLength;
        float _Thickness;
        float _RayLenCoeff;

        float _BaseRaise;
        float4x4 _InvViewProj;
        float4x4 _ViewProj;

        sampler2D _MainTex;
        float4 _MainTex_ST;

        sampler2D _CameraGBufferTexture2;
        sampler2D _CameraDepthTexture;
        sampler2D _CameraDepthMipmap;

		//
		// utility functions 
		//

        float ComputeDepth(float4 clippos)
        {
            #if defined(SHADER_TARGET_GLSL) || defined(SHADER_API_GLES) || defined(SHADER_API_GLES3)
            return (clippos.z / clippos.w) * 0.5 + 0.5;
            #else
            return clippos.z / clippos.w;
            #endif
        }

		float HaltonSequence(float x)
		{
			float y = 0;
			float h = 0.5f;
			while (x > 0)
			{
				float digit = x % 2;
				x = (x - digit) * h;
				y = y + digit * h;
				h *= 0.5f;
			}
			return y;
		}

		float SchlickFresnel(float u, float f0, float f90)
		{
			return f0 + (f90 - f0)*pow(1.0 - u, 5.0);
		}

		float DisneyDiffuse(float albedo, vec3 N, vec3 L, vec3 V, float roughness)
		{
			vec3 H = normalize(L + V);
			float dotLH = saturate(dot(L, H));
			float dotNL = saturate(dot(N, L));
			float dotNV = saturate(dot(N, V));
			float Fd90 = 0.5 + 2.0 * dotLH * dotLH * roughness;
			float FL = SchlickFresnel(1.0, Fd90, dotNL);
			float FV = SchlickFresnel(1.0, Fd90, dotNV);
			return (albedo*FL*FV) / PI;
		}

		//
		// end utility functions
		//

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

            int lod = 0;
            float currlen = 0;
			int calcTimes = 0;
			float3 ray = pos;

			[loop]
            for (int n = 1; n <= _MaxLoop; n++) 
            {
				float test = HaltonSequence(n);

                float3 step = refDir * _RayLenCoeff * (lod + 1);
                
				ray += step;

                float4 rayScreen  = mul(_ViewProj, float4(ray, 1.0));
                float2 rayUV      = rayScreen.xy / rayScreen.w * 0.5 + 0.5;
                float  rayDepth   = ComputeDepth(rayScreen);
                float  worldDepth = (lod == 0)? SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, rayUV) : tex2Dlod(_CameraDepthMipmap, float4(rayUV, 0, lod)) + _BaseRaise * lod; 

                if (max(abs(rayUV.x - 0.5), abs(rayUV.y - 0.5)) > 0.5) break;


                if(rayDepth < worldDepth)
                {
                    if(lod == 0)
                    {
                        if (rayDepth + _Thickness > worldDepth)
						{
						    float sign = -1.0;
							for(int m = 1; m <=8; ++m)
							{
							    ray += sign * pow(0.5, m) * step;
								rayScreen = mul(_ViewProj, float4(ray, 1.0));
							    rayUV = rayScreen.xy / rayScreen.w * 0.5 + 0.5;
                                rayDepth = ComputeDepth(rayScreen);
								worldDepth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, rayUV);
								sign = (rayDepth < worldDepth)? -1 : 1; 

							}
						    col = tex2D(_MainTex, rayUV);
						}
                        break;
                    }
                    else
                    {
					    ray -= step;
                        lod--;
                    }
                }
                else if(n <= _MaxLOD)
                {
                    lod++;
                }

                currlen += abs(step);
                if(currlen > _MaxRayLength) 
				{
				    break;
				}

				calcTimes = n;
            }

			if (_ViewMode == 1) col = float4(1, 1, 1, 1) * calcTimes / _MaxLoop * 0.5;
			if (_ViewMode == 2) col = float4(1, 1, 1, 1) * tex2Dlod(_CameraDepthMipmap, float4(uv, 0, _MaxLOD));

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
