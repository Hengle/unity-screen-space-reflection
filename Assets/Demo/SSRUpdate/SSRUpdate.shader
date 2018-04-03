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
        #define PI 3.14159265359

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

		float _Roughness;
		float _FresnelReflectance;

        float4 _BlurParams;
        #define _BlurOffset _BlurParams.xy
        #define _BlurNum (int)(_BlurParams.z)

        sampler2D _ReflectionTexture;
        float4 _ReflectionTexture_TexelSize;
        sampler2D _PreAccumulationTexture;
        sampler2D _AccumulationTexture;

        sampler2D _CameraGBufferTexture0; // rgb: diffuse,  a: occlusion
        sampler2D _CameraGBufferTexture1; // rgb: specular, a: smoothness
        sampler2D _CameraGBufferTexture2; // rgb: normal,   a: unused
        sampler2D _CameraGBufferTexture3; // rgb: emission, a: unused
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

        //
        // V : view vector
        // L : light vector
        // H : half vector
        //
		float D_GGX(float3 H, float3 N)
        {
			float NdotH = saturate(dot(H, N));
			float roughness = saturate(_Roughness);
		    float alpha = roughness * roughness;
		    float alpha2 = alpha * alpha;
			float t = ((NdotH * NdotH) * (alpha2 - 1.0) + 1.0);
			return alpha2 / (PI * t * t);
		}

		float Flesnel(float3 V, float3 H)
        {
			float VdotH = saturate(dot(V, H));
		    float F0 = saturate(_FresnelReflectance);
		    float F = pow(1.0 - VdotH, 5.0);
		    F *= (1.0 - F0);
		    F += F0;
			return F;
		}

		float G_CookTorrance(float3 L, float3 V, float3 H, float3 N) {
			float NdotH = saturate(dot(N, H));
			float NdotL = saturate(dot(N, L));
			float NdotV = saturate(dot(N, V));
			float VdotH = saturate(dot(V, H));

		    float NH2 = 2.0 * NdotH;
		    float g1 = (NH2 * NdotV) / VdotH;
		    float g2 = (NH2 * NdotL) / VdotH;
		    float G = min(1.0, min(g1, g2));
			return G;
		}

        float SchlickFresnel(float u, float f0, float f90)
        {
          return f0 + (f90-f0)*pow(1.0-u,5.0);
        }


        float DisneyDiffuse(float albedo, float3 N, float3 L, float3 V, float roughness)
        {
          float3 H = normalize(L+V);
          float dotLH = saturate(dot(L,H));
          float dotNL = saturate(dot(N,L));
          float dotNV = saturate(dot(N,V));
          float Fd90 = 0.5 + 2.0 * dotLH * dotLH * roughness;
          float FL = SchlickFresnel(1.0, Fd90, dotNL);
          float FV = SchlickFresnel(1.0, Fd90, dotNV);
          return (albedo*FL*FV)/PI;
        }

		float rand(float2 co)
		{
			return frac(sin(dot(co.xy, float2(12.9898, 78.233))) * 43758.5453);
		}

		float3 randomInSphere(float3 pos, float l) {
			float x = rand(pos.xy) * 2 - 1.0;
			float y = rand(pos.yz) * 2 - 1.0;
			float z = rand(pos.zx) * 2 - 1.0;
			float r = sqrt(x * x + y * y + z * z);

			x /= r;
			y /= r;
			z /= r;

			return float3(x, y, z) * l;
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

        v2f vert_fullscreen(appdata v)
        {
            v2f o;
            o.vertex = v.vertex;
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
            float4 col = tex2D(_MainTex, uv);
            float4 refcol = tex2D(_MainTex, uv);
            float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, uv);
            float smooth = tex2D(_CameraGBufferTexture1, uv).w;
            if (depth <= 0.0) return tex2D(_MainTex, uv);

            float2 screenpos = 2.0 * uv - 1.0;
            float4 pos = mul(_InvViewProj, float4(screenpos, depth, 1.0));
            pos /= pos.w;

            float3 cam = normalize(pos - _WorldSpaceCameraPos);
            float3 nor = tex2D(_CameraGBufferTexture2, uv) * 2.0 - 1.0; // roughness が大きくなるほどこれの振れ幅が大きくなる
			float3 norRough = normalize(nor + randomInSphere(nor.zyx, 0.01));
            float3 ref = reflect(cam, nor);
            float3 hlf = normalize(cam + ref);
			float3 refRough = reflect(cam, norRough);

            int lod = 0;
            float currlen = 0;
            int calcTimes = 0;
            float3 ray = pos;

            [loop]
            for (int n = 1; n <= _MaxLoop; n++) 
            {
                float3 step = ref * _RayLenCoeff * (lod + 1);
                
                ray += step * (1 + rand(uv + _Time.x) * 0.5);

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
                            refcol = tex2D(_MainTex, rayUV);
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
                if(currlen > _MaxRayLength) break;
                calcTimes = n;
            }

            float a = pow(min(1.0, 100.0 / length(ray)), 2.0);
            col = col * (1-a) * (1 - smooth) + refcol * a * smooth;

            if (_ViewMode == 1) col = float4((norRough.xyz), 1);
            if (_ViewMode == 2) col = float4((ref.xyz), 1);
            if (_ViewMode == 3) col = float4(1, 1, 1, 1) * calcTimes / _MaxLoop;
			if (_ViewMode == 4) col = float4(1, 1, 1, 1) * tex2Dlod(_CameraDepthMipmap, float4(uv, 0, _MaxLOD));

            if (_ViewMode == 5) col = float4(tex2D(_CameraGBufferTexture0, uv).xyz, 1);
            if (_ViewMode == 6) col = float4(tex2D(_CameraGBufferTexture1, uv).xyz, 1);
            if (_ViewMode == 7) col = float4(0, tex2D(_CameraGBufferTexture0, uv).w, 0, 1);
            if (_ViewMode == 8) col = float4(0, tex2D(_CameraGBufferTexture1, uv).w, 0, 1);
            if (_ViewMode == 9) col = float4(tex2D(_CameraGBufferTexture3, uv).xyz, 1);


            return col;
        }

        float4 blur(v2f i) : SV_Target
        {
            float2 uv = i.screen.xy / i.screen.w;
            float2 size = _ReflectionTexture_TexelSize;
        
            float4 col = 0.0;
            for (int n = -_BlurNum; n <= _BlurNum; ++n) {
                col += tex2D(_ReflectionTexture, uv + _BlurOffset * size * n);
            }
            return col / (_BlurNum * 2 + 1);
        }

        float4 accumulation(v2f i) : SV_Target
        {
            float2 uv = i.screen.xy / i.screen.w;
            float4 base = tex2D(_PreAccumulationTexture, uv);
            float4 reflection = tex2D(_ReflectionTexture, uv);
            float blend = 0.2;
            return lerp(base, reflection, blend);
        }
        
        float4 composition(v2f i) : SV_Target
        {
            float2 uv = i.screen.xy / i.screen.w;
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
