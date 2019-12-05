
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
            float4 val = SampleEnv(lightLoopContext, lightData.envIndex, L, 0);

            float accVdotH_weight = weightOverPdf * lerp(1, dot(val.rgb, float3(0.2126, 0.7152, 0.0722)), _ReferenceUseVdotHWeightWithLight);
            accVdotH0 += accVdotH_weight;
            accVdotH1 += accVdotH_weight * VdotH;
            accVdotH2 += accVdotH_weight * VdotH*VdotH;
            accVdotH3 += accVdotH_weight * VdotH*VdotH*VdotH;

            float VdotL = dot(V,L);
            accVdotL0 += accVdotH_weight;
            accVdotL1 += accVdotH_weight * VdotL;
            accVdotL2 += accVdotH_weight * VdotL*VdotL;
            accVdotL3 += accVdotH_weight * VdotL*VdotL*VdotL;
        }
    }

    float VdotH_mean = accVdotH1 / accVdotH0;
    float VdotH_var = accVdotH2 / accVdotH0 - VdotH_mean * VdotH_mean;

    float VdotL_mean = accVdotL1 / accVdotL0;
    float VdotL_var = accVdotL2 / accVdotL0 - VdotL_mean * VdotL_mean;

    // HoL = 2**-0.5 * ( 1 + LoV )**0.5
    // float surfaceVdotH_mean = sqrt( 0.5*(1 + VdotL_mean) );
    // float surfaceVdotH_var = 1.0/8.0 * VdotL_var / (1 + VdotL_mean);

    // VdotH_mean = VdotH_mean, surfaceVdotH_mean, _ReferenceUseVdotL);
    // VdotH_var = VdotH_var, surfaceVdotH_var, _ReferenceUseVdotL);

#ifdef IRIDESCENCE_REFERENCE_VDOTH_MEAN_VAR
    return SRGBToLinear(float3(VdotH_mean*_ReferenceDebugMeanScale + _ReferenceDebugMeanOffset, sqrt(VdotH_var)*_ReferenceDebugDevScale + _ReferenceDebugDevOffset, 0));
#endif // IRIDESCENCE_REFERENCE_VDOTH_MEAN_VAR

    // Lerp between ideal reflection (assume N=H) and real mean/variance
    float preVdotH = lerp(NdotV, VdotH_mean, _ReferenceUseMeanVdotH);
    float preVdotHVar = lerp(0, VdotH_var, _ReferenceUseVarVdotH);

    // Lerp between ideal reflection (assume N=H) and real mean/variance
    float preVdotL = lerp(2*Sq(NdotV)-1, VdotL_mean, _ReferenceUseMeanVdotH);
    float preVdotLVar = lerp(0, VdotL_var, _ReferenceUseVarVdotH);


    if (_IridescenceUseVdotL)
    {
        // Override VdotH mean and variance from VdotL distribution
        preVdotH = sqrt(0.5 * (1 + preVdotL));
        preVdotHVar = 0.25 / (1.0 + preVdotL) * preVdotLVar;
    }


    // Compute color
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
            float VdotL = dot(V, L);

            // Fresnel component is apply here as describe in ImportanceSampleGGX function
            float thickness = bsdfData.iridescenceThickness;
            float eta1 = 1.0; // Default is air
            float eta2 = bsdfData.iridescenceEta2;
            float3 eta3 = bsdfData.iridescenceEta3;
            float3 kappa3 = bsdfData.iridescenceKappa3;


            float VdotLOPD = lerp(preVdotL, VdotL, _ReferenceUseCorrectOPD);
            float VdotHOPD = lerp(preVdotH, VdotH, _ReferenceUseCorrectOPD);
            float VdotHCoeffs = lerp(preVdotH, VdotH, _ReferenceUseCorrectCoeffs);

            float VdotLOPDVar = lerp(preVdotLVar, 0, _ReferenceUseCorrectOPD);
            float VdotHOPDVar = lerp(preVdotHVar, 0, _ReferenceUseCorrectOPD);
            float VdotHCoeffsVar = lerp(preVdotHVar, 0, _ReferenceUseCorrectCoeffs);


            // float3 F = EvalIridescenceCorrect(eta1, viewAngle, eta2, thickness, eta3, kappa3);
            float OPD, OPDSigma;

            if (_IridescenceUseVdotL)
                EvalOpticalPathDifferenceVdotL(eta1, VdotLOPD, VdotLOPDVar, eta2, thickness, OPD, OPDSigma);
            else
                EvalOpticalPathDifference(eta1, VdotHOPD, VdotHOPDVar, eta2, thickness, OPD, OPDSigma);

            float3 F = EvalIridescenceCorrectOPD(eta1, VdotHCoeffs, VdotHCoeffsVar, eta2, eta3, kappa3, OPD, OPDSigma, _IridescenceUsePhaseShift);

            float3 FweightOverPdf = F * weightOverPdf;

            float4 val = SampleEnv(lightLoopContext, lightData.envIndex, L, 0);
            acc += FweightOverPdf * val.rgb;
            accWithoutF += weightOverPdf * val.rgb;
        }
    }

    float3 result = acc / sampleCount;
    return result;
}
