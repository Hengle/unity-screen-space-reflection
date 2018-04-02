Shader "Unlit/VectorRotation"
{
	Properties
	{
		_MainTex("Texture", 2D) = "white" {}
	}
		SubShader
	{
		Tags { "RenderType" = "Opaque" }

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#include "UnityCG.cginc"
			#define PI 3.14159265359

			float4 _Color;
	        float4 _Seed;

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				float4 vertex : SV_POSITION;
			};

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

			sampler2D _MainTex;
			float4 _MainTex_ST;

			v2f vert(appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				return o;
			}

			float4 frag(v2f i) : SV_Target
			{
				float3 rand = normalize(randomInSphere(_Color.xyz, 1.0));
				return float4(rand.xyz, 1);
			}
			ENDCG
		}
	}
}
