Shader "Hidden/HDRenderPipeline/ComputeWSdotL"
{
    SubShader
    {
        Tags{ "RenderPipeline" = "HDRenderPipeline" }
        Pass
        {
            Cull   Off
            ZTest  Off
            ZWrite Off
            Blend  Off

            HLSLPROGRAM
            #pragma target 4.5
            #pragma only_renderers d3d11 ps4 xboxone vulkan metal switch

            #pragma vertex Vert
            #pragma fragment Frag

            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
            #include "Packages/com.unity.render-pipelines.high-definition/Runtime/ShaderLibrary/ShaderVariables.hlsl"

            TEXTURECUBE(_MainTex);

            float4x4 _PixelCoordToViewDirWS; // Actually just 3x3, but Unity can only set 4x4

            int _OutputIndex; // This is a workaround for not fully supported MRT...

            struct Attributes
            {
                uint vertexID : SV_VertexID;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
            };

            Varyings Vert(Attributes input)
            {
                Varyings output;
                output.positionCS = GetFullScreenTriangleVertexPosition(input.vertexID);
                return output;
            }

            float4 Frag(Varyings input) : SV_Target0
                /*out float4 output0 : SV_Target0,
                out float4 output1 : SV_Target1,
                out float4 output2 : SV_Target2)*/
            {
                // Points towards the camera
                float3 dirWS = -normalize(mul(float3(input.positionCS.xy, 1.0), (float3x3)_PixelCoordToViewDirWS));
                // Reverse it to point into the scene

                real3 val = SAMPLE_TEXTURECUBE_LOD(_MainTex, s_linear_clamp_sampler, dirWS, 0).rgb;

                float weight = dot(val, real3(0.2126, 0.7152, 0.0722));

                float3 X_Y_Z = dirWS * weight;
                float3 X2_Y2_Z2 = dirWS * X_Y_Z;
                float3 XY_YZ_ZX = dirWS.yzx * X_Y_Z;

                switch (_OutputIndex)
                {
                    case 0:
                        return float4(X_Y_Z, weight);
                    case 1:
                        return float4(X2_Y2_Z2, weight);
                    case 2:
                        return float4(XY_YZ_ZX, weight);
                    default:
                        return float4(1,0,1,1);
                }

                // output0 = float4(1,0,1,1); // float4(X_Y_Z, weight);
                // output1 = float4(1,0,1,1); // float4(X2_Y2_Z2, weight);
                // output2 = float4(1,0,1,1); // float4(XY_YZ_ZX, weight);
            }
            ENDHLSL
        }
    }
}
