Shader "HDRenderPipeline/Iridescence2DRect"
{
    Properties
    {
        [Toggle(IRIDESCENCE_USE_PREFILTERED_VDOTH)]_IridescenceVdotH("Prefiltered VdotH", Float) = 0
        [Toggle(IRIDESCENCE_USE_PREFILTERED_VDOTL)]_IridescenceVdotL("Prefiltered VdotL", Float) = 0

        _IridescenceThickness("Iridescence Thickness (µm)", Range(0.0, 3.0)) = 1.0
        _IridescenceEta2("Iridescence Eta 2", Range(1.0, 5.0)) = 1.21
        _IridescenceEta3("Iridescence Eta 3", Range(1.0, 5.0)) = 2.0
        _IridescenceKappa3("Iridescence Kappa 3", Range(0.0, 5.0)) = 0.0

        [Toggle(IRIDESCENCE_USE_PHASE_SHIFT)]_IridescenceUsePhaseShift("Use Phase Shift", Float) = 1

        [Toggle(IRIDESCENCE_DISPLAY_REFERENCE_IBL_16)]_IridescenceDisplayReferenceIBL16("16 Sample Ref. IBL", Float) = 0
        [Toggle(IRIDESCENCE_DISPLAY_REFERENCE_IBL_256)]_IridescenceDisplayReferenceIBL256("256 Sample Ref. IBL", Float) = 0
        [Toggle(IRIDESCENCE_DISPLAY_REFERENCE_IBL_2048)]_IridescenceDisplayReferenceIBL2048("2048 Sample Ref. IBL", Float) = 0
        [Toggle(IRIDESCENCE_DISPLAY_REFERENCE_IBL_16K)]_IridescenceDisplayReferenceIBL16k("16k Sample Ref. IBL", Float) = 0


        // BlendMode
        [HideInInspector] _Surface("__surface", Float) = 0.0
        [HideInInspector] _Blend("__blend", Float) = 0.0
        [HideInInspector] _AlphaClip("__clip", Float) = 0.0
        [HideInInspector] _SrcBlend("Src", Float) = 1.0
        [HideInInspector] _DstBlend("Dst", Float) = 0.0
        [HideInInspector] _ZWrite("ZWrite", Float) = 1.0
        [HideInInspector] _Cull("__cull", Float) = 2.0
    }
    SubShader
    {
        Tags{ "RenderPipeline" = "HDRenderPipeline" }
        Pass
        {
            Cull   Off
            ZTest  Always
            ZWrite Off
            Blend  Off

            HLSLPROGRAM
            #pragma target 4.5
            #pragma only_renderers d3d11 ps4 xboxone vulkan metal switch

            #pragma vertex Vert
            #pragma fragment Frag

            #pragma shader_feature _ IRIDESCENCE_USE_PREFILTERED_VDOTH
            #pragma shader_feature _ IRIDESCENCE_USE_PREFILTERED_VDOTL
            #pragma shader_feature _ IRIDESCENCE_USE_PHASE_SHIFT

            #pragma shader_feature _ IRIDESCENCE_DISPLAY_REFERENCE_IBL_16 IRIDESCENCE_DISPLAY_REFERENCE_IBL_256 IRIDESCENCE_DISPLAY_REFERENCE_IBL_2048 IRIDESCENCE_DISPLAY_REFERENCE_IBL_16K

            #if defined(IRIDESCENCE_DISPLAY_REFERENCE_IBL_16)
            #define IRIDESCENCE_DISPLAY_REFERENCE_IBL 16
            #elif defined(IRIDESCENCE_DISPLAY_REFERENCE_IBL_256)
            #define IRIDESCENCE_DISPLAY_REFERENCE_IBL 256
            #elif defined(IRIDESCENCE_DISPLAY_REFERENCE_IBL_2048)
            #define IRIDESCENCE_DISPLAY_REFERENCE_IBL 2048
            #elif defined(IRIDESCENCE_DISPLAY_REFERENCE_IBL_16K)
            #define IRIDESCENCE_DISPLAY_REFERENCE_IBL 16*1024
            #endif


            #define UNITY_MATERIAL_IRIDESCENCE // Need to be define before including Material.hlsl

            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/ImageBasedLighting.hlsl"
            #include "Packages/com.unity.render-pipelines.high-definition/Runtime/ShaderLibrary/ShaderVariables.hlsl"
            #include "Packages/com.unity.render-pipelines.high-definition/Runtime/Material/PreIntegratedFGD/PreIntegratedFGD.hlsl"
            #include "Packages/com.unity.render-pipelines.high-definition/Runtime/Material/PreIntegratedVdotH/PreIntegratedVdotH.hlsl"
            #include "Packages/com.unity.render-pipelines.high-definition/Runtime/Material/PreIntegratedVdotL/PreIntegratedVdotL.hlsl"
            #include "Packages/com.unity.render-pipelines.high-definition/Runtime/Material/PreIntegratedIblR/PreIntegratedIblR.hlsl"


            // Uniform values here!

            float _IridescenceThickness;
            float _IridescenceEta2;
            float _IridescenceEta3;
            float _IridescenceKappa3;





            struct ShadingData
            {
                float3 viewDirWS;
                float3 normalWS;
                // float3 L; // ?

                float perceptualRoughness;

                // Iridescence parameters
                float iridescenceThickness;
                float iridescenceEta2;
                float iridescenceEta3;
                float iridescenceKappa3;
            };

            float3 EvalIridescentShadingReference(ShadingData data, uint sampleCount)
            {
                float3x3 localToWorld;

                // We do not have a tangent frame unless we use anisotropic GGX.
                localToWorld = GetLocalFrame(data.normalWS);

                float roughness = PerceptualRoughnessToRoughness(data.perceptualRoughness);

                float  NdotV = ClampNdotV(dot(data.normalWS, data.viewDirWS));
                float3 acc   = float3(0.0, 0.0, 0.0);

                /*
                float accVdotH0 = 0.0;
                float accVdotH1 = 0.0;
                float accVdotH2 = 0.0;
                float accVdotH3 = 0.0;

                float accVdotL0 = 0.0;
                float accVdotL1 = 0.0;
                float accVdotL2 = 0.0;
                float accVdotL3 = 0.0;

                // Integrate VdotH moments
                for (uint i = 0; i < sampleCount; ++i)
                {
                    float2 u = Hammersley2d(i, sampleCount);

                    float VdotH;
                    float NdotL;
                    float3 L;
                    float weightOverPdf;

                    // GGX BRDF
                    ImportanceSampleGGX(u, V, localToWorld, bsdfData.roughness, NdotV, L, VdotH, NdotL, weightOverPdf);

                    if (NdotL > 0.0)
                    {
                        float val = float4(1,1,1,1); // SampleEnv

                        float accVdotH_weight = weightOverPdf * val;
                        accVdotH0 += accVdotH_weight;
                        accVdotH1 += accVdotH_weight * VdotH;
                        accVdotH2 += accVdotH_weight * VdotH*VdotH;
                        accVdotH3 += accVdotH_weight * VdotH*VdotH*VdotH;

                        float VdotL = dot(V, L);
                        accVdotL0 += accVdotH_weight;
                        accVdotL1 += accVdotH_weight * VdotL;
                        accVdotL2 += accVdotH_weight * VdotL*VdotL;
                        accVdotL3 += accVdotH_weight * VdotL*VdotL*VdotL;
                    }
                }

                float VdotH_mean = accVdotH1 / accVdotH0;
                float VdotH_var = accVdotH2 / accVdotH0 - Sq(VdotH_mean);

                float VdotL_mean = accVdotL1 / accVdotL0;
                float VdotL_var = accVdotL2 / accVdotL0 - Sq(VdotL_mean);
                */

                // Compute color
                for (uint i = 0; i < sampleCount; ++i)
                {
                    float2 u = Hammersley2d(i, sampleCount);

                    float VdotH;
                    float NdotL;
                    float3 L;
                    float weightOverPdf;

                    // GGX BRDF
                    ImportanceSampleGGX(u, data.viewDirWS, localToWorld, roughness, NdotV, L, VdotH, NdotL, weightOverPdf);

                    if (NdotL > 0.0)
                    {
                        // Fresnel component is apply here as describe in ImportanceSampleGGX function
                        float thickness = data.iridescenceThickness;
                        float eta1 = 1.0; // Default is air
                        float eta2 = data.iridescenceEta2;
                        float3 eta3 = data.iridescenceEta3;
                        float3 kappa3 = data.iridescenceKappa3;

                        float OPD, OPDSigma;
                        EvalOpticalPathDifference(eta1, VdotH, 0, eta2, thickness, OPD, OPDSigma);
                        float3 F = EvalIridescenceCorrectOPD(eta1, VdotH, 0, eta2, eta3, kappa3, OPD, OPDSigma);

                        float3 FweightOverPdf = F * weightOverPdf;

                        float4 val = float4(1,1,1,1); // SampleEnv
                        acc += FweightOverPdf * val.rgb;
                    }
                }

                float3 result = acc / sampleCount;
                return result;
            }




            float3 EvalIridescentShading(ShadingData data)
            {
                float NdotV = ClampNdotV(dot(data.normalWS, data.viewDirWS));

                // Prepare IBL parameters
                float3 iblR = reflect(-data.viewDirWS, data.normalWS);
                float  iblRoughness;
                float  iblPerceptualRoughness;
                GetPreIntegratedIblR(NdotV, data.perceptualRoughness, data.normalWS, iblR, iblR, iblRoughness);
                iblPerceptualRoughness = RoughnessToPerceptualRoughness(iblRoughness);

                float VdotH_mean = NdotV;
                float VdotH_var = 0;
                float VdotL_mean = 2 * NdotV - 1;
                float VdotL_var = 0;

            #if defined(IRIDESCENCE_USE_PREFILTERED_VDOTL)

                float4 VdotL_moments;
                GetPreIntegratedVdotLGGX(NdotV, data.perceptualRoughness, VdotL_moments);

                VdotL_mean = VdotL_moments.y;
                VdotL_var = max(0, VdotL_moments.z - Sq(VdotL_mean));

                // Override VdotH mean and variance from VdotL distribution
                VdotH_mean = sqrt(0.5 * (1 + VdotL_mean));
                VdotH_var = (1.0/8.0) / (1.0 + VdotL_mean) * VdotL_var;

            #elif defined(IRIDESCENCE_USE_PREFILTERED_VDOTH)

                float4 VdotH_moments;
                GetPreIntegratedVdotHGGX(NdotV, data.perceptualRoughness, VdotH_moments);

                VdotH_mean = VdotH_moments.y;
                VdotH_var = max(0, VdotH_moments.z - VdotH_mean * VdotH_mean);

                // Override VdotL mean and variance from VdotH distribution
                VdotL_mean = 2*Sq(VdotH_mean) - 1;
                VdotL_var = 16*Sq(VdotH_mean) * VdotH_var;

            #endif // IRIDESCENCE_USE_PREFILTERED_VDOTL


                // Evaluate iridescence
                float thickness = data.iridescenceThickness;
                float eta1 = 1.0; // Default is air
                float eta2 = data.iridescenceEta2;
                float3 eta3 = data.iridescenceEta3;
                float3 kappa3 = data.iridescenceKappa3;

                float OPD, OPDSigma;
            #ifdef IRIDESCENCE_USE_PREFILTERED_VDOTL
                EvalOpticalPathDifferenceVdotL(eta1, VdotL_mean, VdotL_var, eta2, thickness, OPD, OPDSigma);
            #else
                EvalOpticalPathDifference(eta1, VdotH_mean, VdotH_var, eta2, thickness, OPD, OPDSigma);
            #endif // IRIDESCENCE_USE_PREFILTERED_VDOTL

                float3 iridescenceF = EvalIridescenceCorrectOPD(eta1, VdotH_mean, VdotH_var, eta2, eta3, kappa3, OPD, OPDSigma);



                float specularReflectivity, diffuseFGD;
                float3 specularFGD;
                GetPreIntegratedFGDGGXAndDisneyDiffuse(NdotV, data.perceptualRoughness, float3(1,1,1), specularFGD, diffuseFGD, specularReflectivity);

                return iridescenceF * specularFGD; // * envLD
            }



            struct Attributes
            {
                uint vertexID : SV_VertexID;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 texCoord   : TEXCOORD0;
            };

            Varyings Vert(Attributes input)
            {
                Varyings output;

                output.positionCS = GetFullScreenTriangleVertexPosition(input.vertexID);
                output.texCoord   = GetFullScreenTriangleTexCoord(input.vertexID);

                return output;
            }

            float4 Frag(Varyings input) : SV_Target
            {
                ShadingData shadingData;

                float theta = input.texCoord.x * HALF_PI;
                float sinTheta, cosTheta;
                sincos(theta, sinTheta, cosTheta);
                shadingData.viewDirWS = float3(sinTheta, 0, cosTheta);
                shadingData.normalWS = float3(0,0,1);

                shadingData.perceptualRoughness = input.texCoord.y;
                shadingData.iridescenceThickness = _IridescenceThickness;
                shadingData.iridescenceEta2 = _IridescenceEta2;
                shadingData.iridescenceEta3 = _IridescenceEta3;
                shadingData.iridescenceKappa3 = _IridescenceKappa3;

            #ifdef IRIDESCENCE_DISPLAY_REFERENCE_IBL
                return float4(EvalIridescentShadingReference(shadingData, IRIDESCENCE_DISPLAY_REFERENCE_IBL), 1);
            #else
                return float4(EvalIridescentShading(shadingData), 1);
            #endif // IRIDESCENCE_DISPLAY_REFERENCE_IBL
            }
            ENDHLSL
        }
    }
}
