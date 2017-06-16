[返回](StencilTest.md)

# 遮罩shader

```
Shader "Custom/StencilNever" {

	SubShader{
		Tags{ "Queue" = "Transparent-100" "RenderType" = "Transparent" "IgnoreProjector" = "True" }
		Pass
		{
			ColorMask 0
			ZWrite Off
			Stencil{
				Ref 1
				Comp always
				Pass replace
			}

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#include "UnityCG.cginc"

			struct appdata {
				float4 vertex : POSITION;
			};

			struct v2f {
				float4 pos : SV_POSITION;
			};

			v2f vert(appdata v) {
				v2f o;
				o.pos = mul(UNITY_MATRIX_MVP, v.vertex);
				return o;
			}

			half4 frag(v2f i) : SV_Target{
				return fixed4(0, 0, 0, 0);
			}
			ENDCG
		}
	}
}


```