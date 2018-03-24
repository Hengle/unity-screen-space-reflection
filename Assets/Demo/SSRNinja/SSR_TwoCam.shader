Shader "Unlit/SSR_TwoCam"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
		_SubTex ("Texture", 2D) = "white" {}
		_SubTexDepth ("Texture" 2D) = "white" {}
	}
	SubShader
	{
		Blend Off
        ZTest Always
        ZWrite Off
        Cull Off

		CGINCLUDE

		#include "UnityCG.cginc"

		ENDCG

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment reflection
			ENDCG
		}
	}
}
