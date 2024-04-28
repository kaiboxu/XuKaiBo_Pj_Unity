Shader "Toon"
{
	Properties
	{
		_BaseMap ("Base Map", 2D) = "white" {}
		_SSSMap("SSS Map", 2D) = "black" {}
		_ILMMap("ILM Map",2D) = "gray" {}
		_DetailMap("Detail Map",2D) = "white" {}
		_ToonThesHold("ToonThesHold",Range(0,1)) = 0.5
		_ToonHardness("ToonHardness",Float) = 20.0
		_SpecColor("Spec Color",Color) = (1,1,1,1)
		_SpecSize("Spec Size",Range(0,1)) = 0.1
		_RimLightDir("RimLight Dir",Vector) = (1,0,-1,0)
		_RimLightColor("RimLight Color",Color) = (1,1,1,1)
		_OutlineWidth("Outline Width",Float) = 7.0
		_OutlineZbias("Outline Zbias",Float) = -10
		_OutlineColor("Outline Color",Color) = (1,1,1,1)
	}
	SubShader
	{
		Pass
		{
			Tags { "LightMode" = "UniversalForward" }
			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
			#pragma multi_compile_fragment _ _SHADOWS_SOFT
			#pragma multi_compile _ _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
			//#pragma multi_compile_fwdbase
			//#include "UnityCG.cginc"
			//#include "AutoLight.cginc"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

			struct Attritubes
			{
				float4 positionOS : POSITION;
				float2 texcoord0 : TEXCOORD0;
				float2 texcoord1 : TEXCOORD1;
				float3 normalOS : NORMAL;
				float4 color : COLOR;
			};

			struct Varyings
			{
				float4 positionCS : SV_POSITION;
				float4 uv : TEXCOORD0;
				float3 positionWS : TEXCOORD1;
				float3 normalWS : TEXCOORD2;
				float4 vertexColor : TEXCOORD3;
				float4 shadowCoord : TEXCOORD4;
			};

			TEXTURE2D(_BaseMap);	SAMPLER(sampler_BaseMap);
			TEXTURE2D(_SSSMap);		SAMPLER(sampler_SSSMap);
			TEXTURE2D(_ILMMap);		SAMPLER(sampler_ILMMap);
			TEXTURE2D(_DetailMap);	SAMPLER(sampler_DetailMap);

			CBUFFER_START(UnityPerMaterial)
			float _ToonThesHold;
			float _ToonHardness;
			float4 _SpecColor;
			float _SpecSize;
			float4 _RimLightDir;
			float4 _RimLightColor;
			CBUFFER_END
			
			Varyings vert (Attritubes input)
			{
				Varyings output = (Varyings)0;
				VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
				output.positionCS = vertexInput.positionCS;
				output.positionWS = vertexInput.positionWS;
				//output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
				//output.positionWS = TransformObjectToWorld(input.positionOS.xyz);
				output.normalWS = TransformObjectToWorldNormal(input.normalOS);
				output.uv = float4(input.texcoord0,input.texcoord1);
				output.vertexColor = input.color;
				output.shadowCoord = GetShadowCoord(vertexInput);

				return output;
			}
			
			half4 frag (Varyings input) : SV_Target
			{
				half2 uv1 = input.uv.xy;
				half2 uv2 = input.uv.zw;
				//向量
				float3 normalDir = normalize(input.normalWS);
				//float3 lightDir = normalize(_MainLightPosition.xyz);
				float3 viewDir = normalize(_WorldSpaceCameraPos - input.positionWS);
				//Base贴图
				half4 base_map = SAMPLE_TEXTURE2D(_BaseMap,sampler_BaseMap,uv1);
				half3 base_color = base_map.rgb; // 亮部的颜色
				half base_mask = base_map.a; //用来区分皮肤和非皮肤区域
				//SSS贴图
				half4 sss_map = SAMPLE_TEXTURE2D(_SSSMap,sampler_SSSMap, uv1);
				half3 sss_color = sss_map.rgb; //暗部的颜色
				half sss_alpha = sss_map.a; //边缘光的强度控制
				//ILM贴图
				half4 ilm_map = SAMPLE_TEXTURE2D(_ILMMap,sampler_ILMMap, uv1);
				float spec_intensity = ilm_map.r; //控制高光强度
				float diffuse_control = ilm_map.g * 2.0 - 1.0; //控制光照的偏移
				float spec_size = ilm_map.b; //控制高光形状大小
				float inner_line = ilm_map.a; //内描线
				//顶点色
				float ao = input.vertexColor.r;
				Light mainLight = GetMainLight(input.shadowCoord,input.positionWS,float4(1.0,1.0,1.0,1.0));
				float3 lightDir = mainLight.direction;
				float shadow = mainLight.shadowAttenuation;
				//float shadow = MainLightRealtimeShadow(input.shadowCoord);
				float atten = lerp(1 , shadow, input.vertexColor.g);
			
				//漫反射
				half NdotL = dot(normalDir, lightDir);
				half half_lambert = (NdotL + 1.0) * 0.5;
				half labmbert_term = half_lambert * ao * atten + diffuse_control;
				half toon_diffuse = saturate((labmbert_term - _ToonThesHold) * _ToonHardness);
				//多光源
				#ifdef _ADDITIONAL_LIGHTS
					uint pixelLightCount = GetAdditionalLightsCount();
					for(uint lightIndex = 0; lightIndex < pixelLightCount; ++lightIndex)
					{
						Light light = GetAdditionalLight(lightIndex,input.positionWS,float4(1.0,1.0,1.0,1.0));
						half NdotL_add = dot(normalDir, light.direction);
						half half_lambert_add = (NdotL_add + 1.0) * 0.5;
						float atten_add = lerp(1 , light.shadowAttenuation * light.distanceAttenuation , input.vertexColor.g);
						half labmbert_term_add = half_lambert_add * ao * atten_add + diffuse_control;
						toon_diffuse += saturate((labmbert_term_add * light.color - _ToonThesHold) * _ToonHardness);
					}
				#endif

				half3 final_diffuse = lerp(sss_color, base_color,toon_diffuse);
				//高光
				float NdotV = (dot(normalDir, viewDir) + 1.0) * 0.5;
				float spec_term = NdotV * ao + diffuse_control;
				spec_term = half_lambert * 0.9 + spec_term * 0.1;
				half toon_spec = saturate((spec_term - (1.0 - spec_size * _SpecSize)) * 500);
				half3 spec_color = (_SpecColor.rgb + base_color) * 0.5;
				half3 final_spec = toon_spec * spec_color * spec_intensity;
				//描线
				half3 inner_line_color = lerp(base_color * 0.2,float3(1.0,1.0,1.0),inner_line);
				half3 detail_color = SAMPLE_TEXTURE2D(_DetailMap,sampler_DetailMap, uv2);//第二套UV Detail细节图
				detail_color = lerp(base_color * 0.2, float3(1.0, 1.0, 1.0), detail_color);
				half3 final_line = inner_line_color * inner_line_color * detail_color;
				//补光、边缘
				float3 lightDir_rim = normalize(mul((float3x3)unity_MatrixInvV,_RimLightDir.xyz));
				half NdotL_rim = (dot(normalDir, lightDir_rim)+ 1.0) * 0.5;
				half rimlight_term = NdotL_rim + diffuse_control;
				half toon_rim = saturate((rimlight_term - _ToonThesHold) * 20);
				half3 rim_color = (_RimLightColor.rgb + base_color) * 0.5 * sss_alpha;
				half3 final_rimlight = toon_rim * rim_color * base_mask * toon_diffuse * _RimLightColor.a;
				
				half3 final_color = (final_diffuse + final_spec + final_rimlight) * final_line;
				final_color = sqrt(max(exp2(log2(max(final_color, 0.0)) * 2.2), 0.0));
				return float4(final_color,1.0);
			}
			ENDHLSL
		}
		Pass
		{
			Cull Front
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#include "UnityCG.cginc"
			#include "AutoLight.cginc"


			struct appdata
			{
				float4 vertex : POSITION;
				float2 texcoord0 : TEXCOORD0;
				float3 normal : NORMAL;
				float4 color : COLOR;
			};

			struct v2f
			{
				float4 pos : SV_POSITION;
				float2 uv : TEXCOORD0;
				float4 vertex_color : TEXCOORD3;
			};

			sampler2D _BaseMap;
			sampler2D _SSSMap;
			sampler2D _ILMMap;
			float _OutlineWidth;
			float _OutlineZbias;
			float4 _OutlineColor;
			
			v2f vert (appdata v)
			{
				v2f o;
				float3 pos_view = UnityObjectToViewPos(v.vertex);
				float3 normal_world = UnityObjectToWorldNormal(v.normal);
				float3 outline_dir = normalize(mul((float3x3)UNITY_MATRIX_V, normal_world));
				outline_dir.z = _OutlineZbias * (1.0 - v.color.b);
				pos_view += outline_dir * _OutlineWidth * 0.001 * v.color.a;
				o.pos = mul(UNITY_MATRIX_P, float4(pos_view, 1.0));
				o.uv = v.texcoord0;
				o.vertex_color = v.color;
				return o;
			}
			
			half4 frag (v2f i) : SV_Target
			{
				float3 basecolor = tex2D(_BaseMap, i.uv.xy).xyz;
				half maxComponent = max(max(basecolor.r, basecolor.g), basecolor.b) - 0.004;
				half3 saturatedColor = step(maxComponent.rrr, basecolor) * basecolor;
				saturatedColor = lerp(basecolor.rgb, saturatedColor, 0.6);
				half3 outlineColor = 0.8 * saturatedColor * basecolor * _OutlineColor.xyz;
				return float4(outlineColor, 1.0);
			}
			ENDCG
		}
		Pass
        {
            Name "ShadowCaster"
            Tags{"LightMode" = "ShadowCaster"}

            ZWrite On
            ZTest LEqual
            ColorMask 0
            Cull[_Cull]

            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local_fragment _ALPHATEST_ON
            #pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma multi_compile _ DOTS_INSTANCING_ON

            // -------------------------------------
            // Universal Pipeline keywords

            // This is used during shadow map generation to differentiate between directional and punctual light shadows, as they use different formulas to apply Normal Bias
            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW

            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment

            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/ShadowCasterPass.hlsl"
            ENDHLSL
        }
		Pass
        {
            Name "DepthOnly"
            Tags{"LightMode" = "DepthOnly"}

            ZWrite On
            ColorMask 0
            Cull[_Cull]

            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local_fragment _ALPHATEST_ON
            #pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma multi_compile _ DOTS_INSTANCING_ON

            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/DepthOnlyPass.hlsl"
            ENDHLSL
        }
	}
}
