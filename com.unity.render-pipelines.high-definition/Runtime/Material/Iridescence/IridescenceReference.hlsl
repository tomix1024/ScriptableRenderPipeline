float _ReferenceUseBetterIblR;
float _ReferenceUseCorrectOPD;
float _ReferenceUseCorrectCoeffs;
float _ReferenceUseMeanVdotH;
float _ReferenceUseVdotHWeightWithLight;

float _MeanScale;
float _MeanOffset;
float _DevScale;
float _DevOffset;

// Ref: Moving Frostbite to PBR (Appendix A)
float3 IntegrateSpecularGGXIBLRef(LightLoopContext lightLoopContext,
                                  float3 V, PreLightData preLightData, EnvLightData lightData, BSDFData bsdfData,
                                  uint sampleCount = 2048)
{
    float3x3 localToWorld;

    // We do not have a tangent frame unless we use anisotropic GGX.
    localToWorld = GetLocalFrame(bsdfData.normalWS);

    float  NdotV = ClampNdotV(dot(bsdfData.normalWS, V));
    float3 acc   = float3(0.0, 0.0, 0.0);
    float3 accWithoutF = float3(0.0, 0.0, 0.0);
    float accVdotH0 = 0.0;
    float accVdotH1 = 0.0;
    float accVdotH2 = 0.0;
    float accVdotH3 = 0.0;

    float3 R = preLightData.iblR;

    {
        float3 Rnew = GetSpecularDominantDir(bsdfData.normalWS, R, preLightData.iblPerceptualRoughness, ClampNdotV(preLightData.NdotV));
        // When we are rough, we tend to see outward shifting of the reflection when at the boundary of the projection volume
        // Also it appear like more sharp. To avoid these artifact and at the same time get better match to reference we lerp to original unmodified reflection.
        // Formula is empirical.
        float roughness = PerceptualRoughnessToRoughness(preLightData.iblPerceptualRoughness);
        Rnew = lerp(Rnew, preLightData.iblR, saturate(smoothstep(0, 1, roughness * roughness)));

        R = lerp(R, Rnew, _ReferenceUseBetterIblR);
    }

    float3 RH = normalize(V + R);
    float VdotRH = ClampNdotV(dot(V, RH));


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
            // Fresnel component is apply here as describe in ImportanceSampleGGX function
            float viewAngle = VdotH;
            float thickness = bsdfData.iridescenceThickness;
            float eta1 = 1.0; // Default is air
            float eta2 = bsdfData.iridescenceEta2;
            float3 eta3 = bsdfData.iridescenceEta3;
            float3 kappa3 = bsdfData.iridescenceKappa3;

            float viewAngleOPD = lerp(VdotRH, VdotH, _ReferenceUseCorrectOPD);
            float viewAngleCoeffs = lerp(VdotRH, VdotH, _ReferenceUseCorrectCoeffs);

            // float3 F = EvalIridescenceCorrect(eta1, viewAngle, eta2, thickness, eta3, kappa3);
            float OPD, phi;
            EvalOpticalPathDifference(eta1, viewAngleOPD, eta2, thickness, OPD, phi);
            float3 F = EvalIridescenceCorrectOPD(eta1, viewAngleCoeffs, eta2, eta3, kappa3, OPD, phi);

            float3 FweightOverPdf = F * weightOverPdf;

            float4 val = SampleEnv(lightLoopContext, lightData.envIndex, L, 0);

            float accVdotH_weight = weightOverPdf * lerp(1, dot(val.rgb, float3(0.2126, 0.7152, 0.0722)), _ReferenceUseVdotHWeightWithLight);
            accVdotH0 += accVdotH_weight;
            accVdotH1 += accVdotH_weight * VdotH;
            accVdotH2 += accVdotH_weight * VdotH*VdotH;
            accVdotH3 += accVdotH_weight * VdotH*VdotH*VdotH;

            acc += FweightOverPdf * val.rgb;
            accWithoutF += weightOverPdf * val.rgb;
        }
    }

    float3 result = acc / sampleCount;

    float VdotH_mean = accVdotH1 / accVdotH0;
    float VdotH_var = accVdotH2 / accVdotH0 - VdotH_mean * VdotH_mean;

#ifdef IRIDESCENCE_REFERENCE_VDOTH_MEAN_VAR
    return SRGBToLinear(float3(VdotH_mean*_MeanScale + _MeanOffset, sqrt(VdotH_var)*_DevScale + _DevOffset, 0));
#endif // IRIDESCENCE_REFERENCE_VDOTH_MEAN_VAR

    {
        // Fresnel component is apply here as describe in ImportanceSampleGGX function
        float viewAngle = VdotH_mean;
        float thickness = bsdfData.iridescenceThickness;
        float eta1 = 1.0; // Default is air
        float eta2 = bsdfData.iridescenceEta2;
        float3 eta3 = bsdfData.iridescenceEta3;
        float3 kappa3 = bsdfData.iridescenceKappa3;

        // float3 F = EvalIridescenceCorrect(eta1, viewAngle, eta2, thickness, eta3, kappa3);
        float OPD, phi;
        EvalOpticalPathDifference(eta1, viewAngle, eta2, thickness, OPD, phi);
        float3 F = EvalIridescenceCorrectOPD(eta1, viewAngle, eta2, eta3, kappa3, OPD, phi);

        result = lerp(result, F * accWithoutF / sampleCount, _ReferenceUseMeanVdotH);
    }

    return result;
}
