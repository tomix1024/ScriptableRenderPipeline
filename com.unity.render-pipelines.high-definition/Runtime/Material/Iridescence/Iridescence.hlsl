//-----------------------------------------------------------------------------
// Includes
//-----------------------------------------------------------------------------

// SurfaceData is define in Iridescence.cs which generate Iridescence.cs.hlsl
#include "Packages/com.unity.render-pipelines.high-definition/Runtime/Material/Iridescence/Iridescence.cs.hlsl"
#include "Packages/com.unity.render-pipelines.high-definition/Runtime/Material/SubsurfaceScattering/SubsurfaceScattering.hlsl"
#include "Packages/com.unity.render-pipelines.high-definition/Runtime/Material/NormalBuffer.hlsl"

//-----------------------------------------------------------------------------
// Configuration
//-----------------------------------------------------------------------------

// Choose between Lambert diffuse and Disney diffuse (enable only one of them)
// #define USE_DIFFUSE_LAMBERT_BRDF

//#ifndef IRIDESCENCE_REFERENCE_VDOTH_MEAN_VAR
//#define LIT_USE_GGX_ENERGY_COMPENSATION
//#endif // IRIDESCENCE_REFERENCE_VDOTH_MEAN_VAR

// Enable reference mode for IBL and area lights
// Both reference define below can be define only if LightLoop is present, else we get a compile error
#ifdef HAS_LIGHTLOOP
// #define IRIDESCENCE_DISPLAY_REFERENCE_AREA
#if defined(IRIDESCENCE_DISPLAY_REFERENCE_IBL_16)
#define IRIDESCENCE_DISPLAY_REFERENCE_IBL 16
#elif defined(IRIDESCENCE_DISPLAY_REFERENCE_IBL_256)
#define IRIDESCENCE_DISPLAY_REFERENCE_IBL 256
#elif defined(IRIDESCENCE_DISPLAY_REFERENCE_IBL_2048)
#define IRIDESCENCE_DISPLAY_REFERENCE_IBL 2048
#elif defined(IRIDESCENCE_DISPLAY_REFERENCE_IBL_16K)
#define IRIDESCENCE_DISPLAY_REFERENCE_IBL 16*1024
#endif
#endif

#ifndef SKIP_RASTERIZED_SHADOWS
#define RASTERIZED_AREA_LIGHT_SHADOWS 1
#else
#define RASTERIZED_AREA_LIGHT_SHADOWS 0
#endif

#include "Packages/com.unity.render-pipelines.high-definition/Runtime/Material/LTCAreaLight/LTCAreaLight.hlsl"
#include "Packages/com.unity.render-pipelines.high-definition/Runtime/Material/PreIntegratedFGD/PreIntegratedFGD.hlsl"
#include "Packages/com.unity.render-pipelines.high-definition/Runtime/Material/PreIntegratedVdotH/PreIntegratedVdotH.hlsl"
#include "Packages/com.unity.render-pipelines.high-definition/Runtime/Material/PreIntegratedVdotL/PreIntegratedVdotL.hlsl"
#include "Packages/com.unity.render-pipelines.high-definition/Runtime/Material/PreIntegratedLightDir/PreIntegratedLightDir.hlsl"
#include "Packages/com.unity.render-pipelines.high-definition/Runtime/Material/PreIntegratedIblR/PreIntegratedIblR.hlsl"
#include "Packages/com.unity.render-pipelines.high-definition/Runtime/Material/Iridescence/IridescenceBSDF.hlsl"

//-----------------------------------------------------------------------------
// Definition
//-----------------------------------------------------------------------------

#define SUPPORTS_RAYTRACED_AREA_SHADOWS (SHADEROPTIONS_RAYTRACING && (SHADERPASS == SHADERPASS_DEFERRED_LIGHTING))

// Lighting architecture and material are suppose to be decoupled files.
// However as we use material classification it is hard to be fully separated
// the dependecy is define in this include where there is shared define for material and lighting in case of deferred material.
// If a user do a lighting architecture without material classification, this can be remove
#include "Packages/com.unity.render-pipelines.high-definition/Runtime/Lighting/LightLoop/LightLoop.cs.hlsl"

// Currently disable SSR until critical editor fix is available
#undef LIGHTFEATUREFLAGS_SSREFLECTION
#define LIGHTFEATUREFLAGS_SSREFLECTION 0

//-----------------------------------------------------------------------------
// Helper functions/variable specific to this material
//-----------------------------------------------------------------------------

// This function return diffuse color or an equivalent color (in case of metal). Alpha channel is 0 is dieletric or 1 if metal, or in between value if it is in between
// This is use for MatCapView and reflection probe pass
// replace is 0.0 if we want diffuse color or 1.0 if we want default color
float4 GetDiffuseOrDefaultColor(BSDFData bsdfData, float replace)
{
    // We do not produce a diffuse color.
    return float4(bsdfData.diffuseColor, 1);
}

float3 GetNormalForShadowBias(BSDFData bsdfData)
{
    return bsdfData.normalWS;
}

float GetAmbientOcclusionForMicroShadowing(BSDFData bsdfData)
{
    return bsdfData.ambientOcclusion;
}

#include "Packages/com.unity.render-pipelines.high-definition/Runtime/Lighting/LightDefinition.cs.hlsl"
#include "Packages/com.unity.render-pipelines.high-definition/Runtime/Lighting/Reflection/VolumeProjection.hlsl"

// This function is use to help with debugging and must be implemented by any lit material
// Implementer must take into account what are the current override component and
// adjust SurfaceData properties accordingdly
void ApplyDebugToSurfaceData(float3x3 tangentToWorld, inout SurfaceData surfaceData)
{
#ifdef DEBUG_DISPLAY
    // Override value if requested by user
    // this can be use also in case of debug lighting mode like diffuse only
    bool overrideAlbedo = _DebugLightingAlbedo.x != 0.0;
    bool overrideSmoothness = _DebugLightingSmoothness.x != 0.0;
    bool overrideNormal = _DebugLightingNormal.x != 0.0;

    if (overrideSmoothness)
    {
        float overrideSmoothnessValue = _DebugLightingSmoothness.y;
        surfaceData.perceptualSmoothness = overrideSmoothnessValue;
    }

    if (overrideNormal)
    {
        surfaceData.normalWS = tangentToWorld[2];
    }
#endif
}

// This function is similar to ApplyDebugToSurfaceData but for BSDFData
void ApplyDebugToBSDFData(inout BSDFData bsdfData)
{
#ifdef DEBUG_DISPLAY
    // Override value if requested by user
    // this can be use also in case of debug lighting mode like specular only
    bool overrideSpecularColor = _DebugLightingSpecularColor.x != 0.0;

    if (overrideSpecularColor)
    {
        float3 overrideSpecularColor = _DebugLightingSpecularColor.yzw;
        bsdfData.fresnel0 = overrideSpecularColor;
    }
#endif
}

NormalData ConvertSurfaceDataToNormalData(SurfaceData surfaceData)
{
    NormalData normalData;

    // Note: We can't handle clear coat material here, we have only one slot to store smoothness
    // and the buffer is the GBuffer1.
    normalData.normalWS = surfaceData.normalWS;
    normalData.perceptualRoughness = PerceptualSmoothnessToPerceptualRoughness(surfaceData.perceptualSmoothness);

    return normalData;
}

void UpdateSurfaceDataFromNormalData(uint2 positionSS, inout BSDFData bsdfData)
{
    NormalData normalData;

    DecodeFromNormalBuffer(positionSS, normalData);

    bsdfData.normalWS = normalData.normalWS;
    bsdfData.perceptualRoughness = normalData.perceptualRoughness;
}

//-----------------------------------------------------------------------------
// conversion function for forward
//-----------------------------------------------------------------------------

BSDFData ConvertSurfaceDataToBSDFData(uint2 positionSS, SurfaceData surfaceData)
{
    BSDFData bsdfData;
    ZERO_INITIALIZE(BSDFData, bsdfData);

    // Standard material
    bsdfData.normalWS            = surfaceData.normalWS;
    bsdfData.perceptualRoughness = PerceptualSmoothnessToPerceptualRoughness(surfaceData.perceptualSmoothness);
    bsdfData.roughness           = PerceptualRoughnessToRoughness(bsdfData.perceptualRoughness);
    bsdfData.fresnel0            = surfaceData.fresnel0;

    // Iridescence
    bsdfData.iridescenceThickness = surfaceData.iridescenceThickness;
    bsdfData.iridescenceThicknessSphereModel = surfaceData.iridescenceThicknessSphereModel;
    bsdfData.iridescenceEta2      = surfaceData.iridescenceEta2;
    bsdfData.iridescenceEta3      = surfaceData.iridescenceEta3;
    bsdfData.iridescenceKappa3    = surfaceData.iridescenceKappa3;

    ApplyDebugToBSDFData(bsdfData);

    return bsdfData;
}

//-----------------------------------------------------------------------------
// Debug method (use to display values)
//-----------------------------------------------------------------------------

void GetSurfaceDataDebug(uint paramId, SurfaceData surfaceData, inout float3 result, inout bool needLinearToSRGB)
{
    GetGeneratedSurfaceDataDebug(paramId, surfaceData, result, needLinearToSRGB);

    // Overide debug value output to be more readable
    switch (paramId)
    {
    case DEBUGVIEW_IRIDESCENCE_SURFACEDATA_NORMAL_VIEW_SPACE:
        // Convert to view space
        result = TransformWorldToViewDir(surfaceData.normalWS) * 0.5 + 0.5;
        break;
    }
}

void GetBSDFDataDebug(uint paramId, BSDFData bsdfData, inout float3 result, inout bool needLinearToSRGB)
{
    GetGeneratedBSDFDataDebug(paramId, bsdfData, result, needLinearToSRGB);

    // Overide debug value output to be more readable
    switch (paramId)
    {
    case DEBUGVIEW_IRIDESCENCE_BSDFDATA_NORMAL_VIEW_SPACE:
        // Convert to view space
        result = TransformWorldToViewDir(bsdfData.normalWS) * 0.5 + 0.5;
        break;
    }
}

void GetPBRValidatorDebug(SurfaceData surfaceData, inout float3 result)
{
    result = surfaceData.fresnel0; // Whatever
}

//-----------------------------------------------------------------------------
// PreLightData
//-----------------------------------------------------------------------------

// Precomputed lighting data to send to the various lighting functions
struct PreLightData
{
    float NdotV;                     // Could be negative due to normal mapping, use ClampNdotV()

    // GGX
    float partLambdaV;
    float energyCompensation;

    // IBL
    float3 iblR;                     // Reflected specular direction, used for IBL in EvaluateBSDF_Env()
    float  iblPerceptualRoughness;

    // NOTE: Does not depend on microfacet orientation! always roughness = 0
    float3 iblT;                     // Transmitted specular direction, used for IBL in EvaluateBSDF_Env()

    float3 specularFGD;              // Store preintegrated BSDF for both specular and diffuse
    float  diffuseFGD;
    float3 transmissiveFGD;          // FGD for transmission through film
    float3 rayFGD[SPHERE_MODEL_BOUNCES];

    // Area lights (17 VGPRs)
    // TODO: 'orthoBasisViewNormal' is just a rotation around the normal and should thus be just 1x VGPR.
    float3x3 orthoBasisViewNormal;   // Right-handed view-dependent orthogonal basis around the normal (6x VGPRs)
    float3x3 ltcTransformDiffuse;    // Inverse transformation for Lambertian or Disney Diffuse        (4x VGPRs)
    float3x3 ltcTransformSpecular;   // Inverse transformation for GGX                                 (4x VGPRs)
};

//
// ClampRoughness helper specific to this material
//
void ClampRoughness(inout PreLightData preLightData, inout BSDFData bsdfData, float minRoughness)
{
    bsdfData.roughness    = max(minRoughness, bsdfData.roughness);
}

PreLightData GetPreLightData(float3 V, PositionInputs posInput, inout BSDFData bsdfData)
{
    PreLightData preLightData;
    ZERO_INITIALIZE(PreLightData, preLightData);

    float3 N = bsdfData.normalWS;
    preLightData.NdotV = dot(N, V);
    preLightData.iblPerceptualRoughness = bsdfData.perceptualRoughness;

    float clampedNdotV = ClampNdotV(preLightData.NdotV);

    // We modify the bsdfData.fresnel0 here for iridescence
    // if (HasFlag(bsdfData.materialFeatures, MATERIALFEATUREFLAGS_LIT_IRIDESCENCE))
    // ....

    // Handle IBL + area light + multiscattering.
    // Note: use the not modified by anisotropy iblPerceptualRoughness here.


    float3 iblN = N;
    preLightData.iblR = reflect(-V, iblN);
    preLightData.iblT = -V; // That's it


    // Modify iblR and iblPerceptualRoughness
    float3 tempIblR;
    float  tempIblRoughness;
    GetPreIntegratedIblR(clampedNdotV, preLightData.iblPerceptualRoughness, bsdfData.normalWS, preLightData.iblR, tempIblR, tempIblRoughness);
    preLightData.iblR = lerp(preLightData.iblR, tempIblR, _IBLUsePreIntegratedIblR);
    preLightData.iblPerceptualRoughness = lerp(preLightData.iblPerceptualRoughness, RoughnessToPerceptualRoughness(tempIblRoughness), _IBLUsePreIntegratedIblRoughness);


    float3 iridescenceFGD;
    float3 iridescenceTransmissiveFGD;
    {
        float4 VdotH_moments;
        GetPreIntegratedVdotHGGX(clampedNdotV, bsdfData.perceptualRoughness, VdotH_moments);

        float VdotH_mean = VdotH_moments.y;
        float VdotH_var = max(0, VdotH_moments.z - VdotH_mean * VdotH_mean);

        float3 lightDirMean;
        float3x3 lightDirCovar;
        GetPreIntegratedLightDirFromSky(preLightData.iblR, preLightData.iblPerceptualRoughness, lightDirMean, lightDirCovar);
        float VdotL_mean = max(-1, min(1, dot(V, lightDirMean)));
        float VdotL_var = max(0, dot(V, mul(lightDirCovar, V)));
        VdotL_var = _IridescenceUseVarVdotH ? VdotL_var : 0;

        if (_IridescenceUseVdotL)
        {
            // Override VdotH mean and variance from VdotL distribution
            VdotH_mean = sqrt(0.5 * (1 + VdotL_mean));
            VdotH_var = 0.25 / (1.0 + VdotL_mean) * VdotL_var;
        }


        float viewAngle = _IridescenceUseMeanVdotH ? VdotH_mean : clampedNdotV; // NOTE: THIS IS NOT GENERALLY THE CASE!
        float viewAngleVar = _IridescenceUseVarVdotH ? VdotH_var : 0;
        float thickness = bsdfData.iridescenceThickness;
        float eta1 = 1.0; // Default is air
        float eta2 = bsdfData.iridescenceEta2;
        float3 eta3 = bsdfData.iridescenceEta3;
        float3 kappa3 = bsdfData.iridescenceKappa3;

        // iridescenceFGD = EvalIridescenceCorrect(eta1, viewAngle, viewAngleVar, eta2, thickness, eta3, kappa3);
        float OPD, OPDSigma;

        if (_IridescenceUseVdotL)
            EvalOpticalPathDifferenceVdotL(eta1, VdotL_mean, VdotL_var, eta2, thickness, OPD, OPDSigma);
        else
            EvalOpticalPathDifference(eta1, viewAngle, viewAngleVar, eta2, thickness, OPD, OPDSigma);

        iridescenceFGD = EvalIridescenceCorrectOPD(eta1, viewAngle, viewAngleVar, eta2, eta3, kappa3, OPD, OPDSigma, _IridescenceUsePhaseShift);
        iridescenceTransmissiveFGD = EvalIridescenceTransmissionCorrectOPD(eta1, viewAngle, viewAngleVar, eta2, eta3, kappa3, OPD, OPDSigma, _IridescenceUsePhaseShift);

    #ifdef IRIDESCENCE_TRANSPARENT_SPHERE
        // IridescenceFGD for different light paths with multiple reflection/transmission...
        // From now on assume eta3 = 1!
        eta3 = 1.0;
        kappa3 = 0.0;
        thickness = 1; // OPD is known to be linear in thickness, want to compute for many thicknesses at once, don't have vectorized implementation...

        EvalOpticalPathDifference(eta1, viewAngle, 0, eta2, thickness, OPD, OPDSigma);
        float rayOPD[SPHERE_MODEL_BOUNCES];
        for (int i = 0; i < SPHERE_MODEL_BOUNCES; ++i)
        {
            rayOPD[i] = OPD * bsdfData.iridescenceThicknessSphereModel[i];
        }

    #ifdef IRIDESCENCE_DISPLAY_SPECTRAL

        // LIMITED MODEL BUT SPECTRAL!
        //iridescenceFGD = EvalIridescenceSpectral(eta1, viewAngle, eta2, OPD);
        EvalIridescenceSpectralSphereModel(eta1, viewAngle, eta2, rayOPD, preLightData.rayFGD, _IridescenceSpectralThinFilmBounces, _IridescenceSpectralIntermediateRGB);

    #else

        EvalIridescenceSphereModel(eta1, viewAngle, eta2, eta3, kappa3, rayOPD, preLightData.rayFGD, _IridescenceSpectralIntermediateRGB);

    #endif // IRIDESCENCE_SPECTRAL

        // TODO SPHERE_MODEL_BOUNCES

        preLightData.rayFGD[0] *= _RayMask1[0];
        preLightData.rayFGD[1] *= _RayMask1[1];
        preLightData.rayFGD[2] *= _RayMask1[2];
        preLightData.rayFGD[3] *= _RayMask1[3];

        preLightData.rayFGD[4] *= _RayMask2[0];
        preLightData.rayFGD[5] *= _RayMask2[1];
        preLightData.rayFGD[6] *= _RayMask2[2];
        preLightData.rayFGD[7] *= _RayMask2[3];

    #endif // IRIDESCENCE_TRANSPARENT_SPHERE
    }

    float specularReflectivity;
    GetPreIntegratedFGDGGXAndDisneyDiffuse(clampedNdotV, bsdfData.perceptualRoughness, bsdfData.fresnel0, preLightData.specularFGD, preLightData.diffuseFGD, specularReflectivity);
    preLightData.specularFGD *= iridescenceFGD;
    preLightData.transmissiveFGD = iridescenceTransmissiveFGD;

#ifdef USE_DIFFUSE_LAMBERT_BRDF
    preLightData.diffuseFGD = 1.0;
#endif

#ifdef LIT_USE_GGX_ENERGY_COMPENSATION
    // Ref: Practical multiple scattering compensation for microfacet models.
    // We only apply the formulation for metals.
    // For dielectrics, the change of reflectance is negligible.
    // We deem the intensity difference of a couple of percent for high values of roughness
    // to not be worth the cost of another precomputed table.
    // Note: this formulation bakes the BSDF non-symmetric!
    preLightData.energyCompensation = 1.0 / specularReflectivity - 1.0;
#else
    preLightData.energyCompensation = 0.0;
#endif // LIT_USE_GGX_ENERGY_COMPENSATION

    preLightData.partLambdaV = GetSmithJointGGXPartLambdaV(clampedNdotV, bsdfData.roughness);


    // Area light
    // UVs for sampling the LUTs
    float theta = FastACosPos(clampedNdotV); // For Area light - UVs for sampling the LUTs
    float2 uv = Remap01ToHalfTexelCoord(float2(bsdfData.perceptualRoughness, theta * INV_HALF_PI), LTC_LUT_SIZE);

    // Note we load the matrix transpose (avoid to have to transpose it in shader)
#ifdef USE_DIFFUSE_LAMBERT_BRDF
    preLightData.ltcTransformDiffuse = k_identity3x3;
#else
    // Get the inverse LTC matrix for Disney Diffuse
    preLightData.ltcTransformDiffuse      = 0.0;
    preLightData.ltcTransformDiffuse._m22 = 1.0;
    preLightData.ltcTransformDiffuse._m00_m02_m11_m20 = SAMPLE_TEXTURE2D_ARRAY_LOD(_LtcData, s_linear_clamp_sampler, uv, LTC_DISNEY_DIFFUSE_MATRIX_INDEX, 0);
#endif

    // Get the inverse LTC matrix for GGX
    // Note we load the matrix transpose (avoid to have to transpose it in shader)
    preLightData.ltcTransformSpecular      = 0.0;
    preLightData.ltcTransformSpecular._m22 = 1.0;
    preLightData.ltcTransformSpecular._m00_m02_m11_m20 = SAMPLE_TEXTURE2D_ARRAY_LOD(_LtcData, s_linear_clamp_sampler, uv, LTC_GGX_MATRIX_INDEX, 0);

    // Construct a right-handed view-dependent orthogonal basis around the normal
    preLightData.orthoBasisViewNormal = GetOrthoBasisViewNormal(V, N, preLightData.NdotV);

    return preLightData;
}

//-----------------------------------------------------------------------------
// bake lighting function
//-----------------------------------------------------------------------------

// This define allow to say that we implement a ModifyBakedDiffuseLighting function to be call in PostInitBuiltinData
#define MODIFY_BAKED_DIFFUSE_LIGHTING

// This function allow to modify the content of (back) baked diffuse lighting when we gather builtinData
// This is use to apply lighting model specific code, like pre-integration, transmission etc...
// It is up to the lighting model implementer to chose if the modification are apply here or in PostEvaluateBSDF
void ModifyBakedDiffuseLighting(float3 V, PositionInputs posInput, SurfaceData surfaceData, inout BuiltinData builtinData)
{
    // In case of deferred, all lighting model operation are done before storage in GBuffer, as we store emissive with bakeDiffuseLighting

    // To get the data we need to do the whole process - compiler should optimize everything
    BSDFData bsdfData = ConvertSurfaceDataToBSDFData(posInput.positionSS, surfaceData);
    PreLightData preLightData = GetPreLightData(V, posInput, bsdfData);

    // Premultiply (back) bake diffuse lighting information with DisneyDiffuse pre-integration
    builtinData.bakeDiffuseLighting *= preLightData.diffuseFGD * GetDiffuseOrDefaultColor(bsdfData, _ReplaceDiffuseForIndirect).rgb;
}

//-----------------------------------------------------------------------------
// light transport functions
//-----------------------------------------------------------------------------

LightTransportData GetLightTransportData(SurfaceData surfaceData, BuiltinData builtinData, BSDFData bsdfData)
{
    LightTransportData lightTransportData;

    // diffuseColor for lightmapping should basically be diffuse color.
    // But rough metals (black diffuse) still scatter quite a lot of light around, so
    // we want to take some of that into account too.

    float roughness = PerceptualRoughnessToRoughness(bsdfData.perceptualRoughness);
    lightTransportData.diffuseColor = bsdfData.diffuseColor + bsdfData.fresnel0 * roughness * 0.5;
    lightTransportData.emissiveColor = builtinData.emissiveColor;

    return lightTransportData;
}

//-----------------------------------------------------------------------------
// LightLoop related function (Only include if required)
// HAS_LIGHTLOOP is define in Lighting.hlsl
//-----------------------------------------------------------------------------

#ifdef HAS_LIGHTLOOP

//-----------------------------------------------------------------------------
// BSDF share between directional light, punctual light and area light (reference)
//-----------------------------------------------------------------------------

bool IsNonZeroBSDF(float3 V, float3 L, PreLightData preLightData, BSDFData bsdfData)
{
    float NdotL = dot(bsdfData.normalWS, L);

    return NdotL > 0.0;
}

CBSDF EvaluateBSDF(float3 V, float3 L, PreLightData preLightData, BSDFData bsdfData)
{
    CBSDF cbsdf;
    ZERO_INITIALIZE(CBSDF, cbsdf);

    float3 N = bsdfData.normalWS;

    float NdotV = preLightData.NdotV;
    float NdotL = dot(N, L);
    float clampedNdotV = ClampNdotV(NdotV);
    float clampedNdotL = saturate(NdotL);
    float flippedNdotL = ComputeWrappedDiffuseLighting(-NdotL, TRANSMISSION_WRAP_LIGHT);

    float LdotV, NdotH, LdotH, invLenLV;
    GetBSDFAngle(V, L, NdotL, NdotV, LdotV, NdotH, LdotH, invLenLV);

    float3 F = F_Schlick(bsdfData.fresnel0, LdotH);
    // Remark: Fresnel must be use with LdotH angle. But Fresnel for iridescence is expensive to compute at each light.
    // Instead we use the incorrect angle NdotV as an approximation for LdotH for Fresnel evaluation.
    // The Fresnel with iridescence and NDotV angle is precomputed ahead and here we jsut reuse the result.
    // Thus why we shouldn't apply a second time Fresnel on the value if iridescence is enabled.
    /// if (HasFlag(bsdfData.materialFeatures, MATERIALFEATUREFLAGS_LIT_IRIDESCENCE))
    {
        float viewAngle = LdotH;
        float thickness = bsdfData.iridescenceThickness;
        float eta1 = 1.0; // Default is air
        float eta2 = bsdfData.iridescenceEta2;
        float3 eta3 = bsdfData.iridescenceEta3;
        float3 kappa3 = bsdfData.iridescenceKappa3;

        F = EvalIridescenceCorrect(eta1, viewAngle, 0, eta2, thickness, eta3, kappa3, 0, 0);
    }

    float DV = DV_SmithJointGGX(NdotH, abs(NdotL), clampedNdotV, bsdfData.roughness, preLightData.partLambdaV);

    float3 specTerm = F * DV;

#ifdef USE_DIFFUSE_LAMBERT_BRDF
    float  diffTerm = Lambert();
#else
    // A note on subsurface scattering: [SSS-NOTE-TRSM]
    // The correct way to handle SSS is to transmit light inside the surface, perform SSS,
    // and then transmit it outside towards the viewer.
    // Transmit(X) = F_Transm_Schlick(F0, F90, NdotX), where F0 = 0, F90 = 1.
    // Therefore, the diffuse BSDF should be decomposed as follows:
    // f_d = A / Pi * F_Transm_Schlick(0, 1, NdotL) * F_Transm_Schlick(0, 1, NdotV) + f_d_reflection,
    // with F_Transm_Schlick(0, 1, NdotV) applied after the SSS pass.
    // The alternative (artistic) formulation of Disney is to set F90 = 0.5:
    // f_d = A / Pi * F_Transm_Schlick(0, 0.5, NdotL) * F_Transm_Schlick(0, 0.5, NdotV) + f_retro_reflection.
    // That way, darkening at grading angles is reduced to 0.5.
    // In practice, applying F_Transm_Schlick(F0, F90, NdotV) after the SSS pass is expensive,
    // as it forces us to read the normal buffer at the end of the SSS pass.
    // Separating f_retro_reflection also has a small cost (mostly due to energy compensation
    // for multi-bounce GGX), and the visual difference is negligible.
    // Therefore, we choose not to separate diffuse lighting into reflected and transmitted.
    float diffTerm = DisneyDiffuse(NdotV, NdotL, LdotV, bsdfData.perceptualRoughness);
#endif

    // The compiler should optimize these. Can revisit later if necessary.
    cbsdf.diffR = diffTerm * clampedNdotL;
    cbsdf.diffT = diffTerm * flippedNdotL;

    // Probably worth branching here for perf reasons.
    // This branch will be optimized away if there's no transmission.
    if (NdotL > 0)
    {
        cbsdf.specR = specTerm * clampedNdotL;
    }

    // We don't multiply by 'bsdfData.diffuseColor' here. It's done only once in PostEvaluateBSDF().
    return cbsdf;
}

//-----------------------------------------------------------------------------
// Surface shading (all light types) below
//-----------------------------------------------------------------------------

#include "Packages/com.unity.render-pipelines.high-definition/Runtime/Lighting/LightEvaluation.hlsl"
#include "Packages/com.unity.render-pipelines.high-definition/Runtime/Material/MaterialEvaluation.hlsl"
#include "Packages/com.unity.render-pipelines.high-definition/Runtime/Lighting/SurfaceShading.hlsl"

//-----------------------------------------------------------------------------
// EvaluateBSDF_Directional
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
// EvaluateBSDF_Directional
//-----------------------------------------------------------------------------

DirectLighting EvaluateBSDF_Directional(LightLoopContext lightLoopContext,
                                        float3 V, PositionInputs posInput,
                                        PreLightData preLightData, DirectionalLightData lightData,
                                        BSDFData bsdfData, BuiltinData builtinData)
{
    return ShadeSurface_Directional(lightLoopContext, posInput, builtinData, preLightData, lightData, bsdfData, V);
}

//-----------------------------------------------------------------------------
// EvaluateBSDF_Punctual (supports spot, point and projector lights)
//-----------------------------------------------------------------------------

DirectLighting EvaluateBSDF_Punctual(LightLoopContext lightLoopContext,
                                     float3 V, PositionInputs posInput,
                                     PreLightData preLightData, LightData lightData,
                                     BSDFData bsdfData, BuiltinData builtinData)
{
    return ShadeSurface_Punctual(lightLoopContext, posInput, builtinData, preLightData, lightData, bsdfData, V);
}

#include "IridescenceReference.hlsl"

//-----------------------------------------------------------------------------
// EvaluateBSDF_Line - Approximation with Linearly Transformed Cosines
//-----------------------------------------------------------------------------

DirectLighting EvaluateBSDF_Line(   LightLoopContext lightLoopContext,
                                    float3 V, PositionInputs posInput,
                                     PreLightData preLightData, LightData lightData,
                                     BSDFData bsdfData, BuiltinData builtinData)
{
    DirectLighting lighting;
    ZERO_INITIALIZE(DirectLighting, lighting);

    // TODO

    return lighting;
}

//-----------------------------------------------------------------------------
// EvaluateBSDF_Rect - Approximation with Linearly Transformed Cosines
//-----------------------------------------------------------------------------

// #define ELLIPSOIDAL_ATTENUATION

DirectLighting EvaluateBSDF_Rect(   LightLoopContext lightLoopContext,
                                    float3 V, PositionInputs posInput,
                                    PreLightData preLightData, LightData lightData,
                                    BSDFData bsdfData, BuiltinData builtinData)
{
    DirectLighting lighting;
    ZERO_INITIALIZE(DirectLighting, lighting);

    // TODO

    return lighting;
}

DirectLighting EvaluateBSDF_Area(LightLoopContext lightLoopContext,
    float3 V, PositionInputs posInput,
    PreLightData preLightData, LightData lightData,
    BSDFData bsdfData, BuiltinData builtinData)
{
    if (lightData.lightType == GPULIGHTTYPE_TUBE)
    {
        return EvaluateBSDF_Line(lightLoopContext, V, posInput, preLightData, lightData, bsdfData, builtinData);
    }
    else
    {
        return EvaluateBSDF_Rect(lightLoopContext, V, posInput, preLightData, lightData, bsdfData, builtinData);
    }
}

//-----------------------------------------------------------------------------
// EvaluateBSDF_SSLighting for screen space lighting
// ----------------------------------------------------------------------------

IndirectLighting EvaluateBSDF_ScreenSpaceReflection(PositionInputs posInput,
                                                    PreLightData   preLightData,
                                                    BSDFData       bsdfData,
                                                    inout float    reflectionHierarchyWeight)
{
    IndirectLighting lighting;
    ZERO_INITIALIZE(IndirectLighting, lighting);

    // TODO

    return lighting;
}

IndirectLighting EvaluateBSDF_ScreenspaceRefraction(LightLoopContext lightLoopContext,
                                                    float3 V, PositionInputs posInput,
                                                    PreLightData preLightData, BSDFData bsdfData,
                                                    EnvLightData envLightData,
                                                    inout float hierarchyWeight)
{
    IndirectLighting lighting;
    ZERO_INITIALIZE(IndirectLighting, lighting);

    float mipLevel = 0;
    float weight = 1;
    float2 samplingPositionNDC = posInput.positionNDC;

    float3 preLD = SAMPLE_TEXTURE2D_X_LOD(
        _ColorPyramidTexture,
        s_trilinear_clamp_sampler,
        samplingPositionNDC * _ColorPyramidScale.xy,
        mipLevel
    ).rgb;

    UpdateLightingHierarchyWeights(hierarchyWeight, weight); // Shouldn't be needed, but safer in case we decide to change hierarchy priority

#ifdef IRIDESCENCE_TRANSPARENT_SPHERE
    float3 T = preLightData.rayFGD[1]; // 0th ray is reflection (R), 1st ray is 2x transmission (TT), 2nd ray is (TRT)
#else
    float3 T = preLightData.transmissiveFGD;
#endif // IRIDESCENCE_TRANSPARENT_SPHERE

    // -------------------------------
    // Assign color
    // -------------------------------
    lighting.specularTransmitted = T * preLD.rgb * weight;

    return lighting;
}

//-----------------------------------------------------------------------------
// EvaluateBSDF_Env
// ----------------------------------------------------------------------------

// _preIntegratedFGD and _CubemapLD are unique for each BRDF
IndirectLighting EvaluateBSDF_Env(  LightLoopContext lightLoopContext,
                                    float3 V, PositionInputs posInput,
                                    PreLightData preLightData, EnvLightData lightData, BSDFData bsdfData,
                                    int influenceShapeType, int GPUImageBasedLightingType,
                                    inout float hierarchyWeight)
{
    IndirectLighting lighting;
    ZERO_INITIALIZE(IndirectLighting, lighting);
    if (GPUImageBasedLightingType == GPUIMAGEBASEDLIGHTINGTYPE_REFRACTION)
        return lighting;

    float3 envLighting;
    float3 positionWS = posInput.positionWS;
    float weight = 1.0;

#ifdef IRIDESCENCE_DISPLAY_REFERENCE_IBL

    envLighting = IntegrateSpecularGGXIBLRef(lightLoopContext, V, preLightData, lightData, bsdfData, IRIDESCENCE_DISPLAY_REFERENCE_IBL);

    // TODO: Do refraction reference (is it even possible ?)
    // TODO: handle clear coat


//    #ifdef USE_DIFFUSE_LAMBERT_BRDF
//    envLighting += IntegrateLambertIBLRef(lightData, V, bsdfData);
//    #else
//    envLighting += IntegrateDisneyDiffuseIBLRef(lightLoopContext, V, preLightData, lightData, bsdfData);
//    #endif

#elif defined(IRIDESCENCE_TRANSPARENT_SPHERE)

    // Assume we have eta1=eta3 = 1
    // Assume geometry is a perfect sphere
    // Assume surface is smooth!

    float iblMipLevel = 0;

    envLighting = float3(0,0,0);

    float3 Vi = V;
    float3 Li = reflect(-V, bsdfData.normalWS);

    for (int i = 0; i < SPHERE_MODEL_BOUNCES; ++i)
    {
        // Do transmission in EvaluateBSDF_SSLighting()
        if (i != 1)
        {
            float4 preLD = SampleEnv(lightLoopContext, lightData.envIndex, Li, iblMipLevel);
            envLighting += preLightData.rayFGD[i] * preLD.rgb;
        }

        float3 Vinext = -reflect(-Li, Vi);
        float3 Linext = -Vi;
        Vi = Vinext;
        Li = Linext;
    }

#else

    float3 R = preLightData.iblR;

    {
        // TODO implement iblR here!
        if (!IsEnvIndexTexture2D(lightData.envIndex)) // ENVCACHETYPE_CUBEMAP
        {
            float3 Rnew = GetSpecularDominantDir(bsdfData.normalWS, R, preLightData.iblPerceptualRoughness, ClampNdotV(preLightData.NdotV));
            // When we are rough, we tend to see outward shifting of the reflection when at the boundary of the projection volume
            // Also it appear like more sharp. To avoid these artifact and at the same time get better match to reference we lerp to original unmodified reflection.
            // Formula is empirical.
            float roughness = PerceptualRoughnessToRoughness(preLightData.iblPerceptualRoughness);
            Rnew = lerp(Rnew, preLightData.iblR, saturate(smoothstep(0, 1, roughness * roughness)));
            R = lerp(Rnew, R, _IBLUsePreIntegratedIblR);
        }
    }

    // Note: using influenceShapeType and projectionShapeType instead of (lightData|proxyData).shapeType allow to make compiler optimization in case the type is know (like for sky)
    EvaluateLight_EnvIntersection(positionWS, bsdfData.normalWS, lightData, influenceShapeType, R, weight);

    float3 F = preLightData.specularFGD;

    float iblMipLevel;
    // TODO: We need to match the PerceptualRoughnessToMipmapLevel formula for planar, so we don't do this test (which is specific to our current lightloop)
    // Specific case for Texture2Ds, their convolution is a gaussian one and not a GGX one - So we use another roughness mip mapping.
#if !defined(SHADER_API_METAL)
    if (IsEnvIndexTexture2D(lightData.envIndex))
    {
        // Empirical remapping
        iblMipLevel = PlanarPerceptualRoughnessToMipmapLevel(preLightData.iblPerceptualRoughness, _ColorPyramidScale.z);
    }
    else
#endif
    {
        iblMipLevel = PerceptualRoughnessToMipmapLevel(preLightData.iblPerceptualRoughness);
    }

    float4 preLD = SampleEnv(lightLoopContext, lightData.envIndex, R, iblMipLevel);
    weight *= preLD.a; // Used by planar reflection to discard pixel

    if (GPUImageBasedLightingType == GPUIMAGEBASEDLIGHTINGTYPE_REFLECTION)
    {
        envLighting = F * preLD.rgb;
    }

#endif // IRIDESCENCE_DISPLAY_REFERENCE_IBL


    UpdateLightingHierarchyWeights(hierarchyWeight, weight);
    envLighting *= weight * lightData.multiplier;

    if (GPUImageBasedLightingType == GPUIMAGEBASEDLIGHTINGTYPE_REFLECTION)
        lighting.specularReflected = envLighting;

    return lighting;
}

//-----------------------------------------------------------------------------
// PostEvaluateBSDF
// ----------------------------------------------------------------------------

void PostEvaluateBSDF(  LightLoopContext lightLoopContext,
                        float3 V, PositionInputs posInput,
                        PreLightData preLightData, BSDFData bsdfData, BuiltinData builtinData, AggregateLighting lighting,
                        out float3 diffuseLighting, out float3 specularLighting)
{
    AmbientOcclusionFactor aoFactor;
    // Use GTAOMultiBounce approximation for ambient occlusion (allow to get a tint from the baseColor)
#if 0
    GetScreenSpaceAmbientOcclusion(posInput.positionSS, preLightData.NdotV, bsdfData.perceptualRoughness, bsdfData.ambientOcclusion, bsdfData.specularOcclusion, aoFactor);
#else
    GetScreenSpaceAmbientOcclusionMultibounce(posInput.positionSS, preLightData.NdotV, bsdfData.perceptualRoughness, bsdfData.ambientOcclusion, bsdfData.specularOcclusion, bsdfData.diffuseColor, bsdfData.fresnel0, aoFactor);
#endif
    // TODO this breaks things in this shader
    // ApplyAmbientOcclusionFactor(aoFactor, builtinData, lighting);

    // Subsurface scattering mode
    float3 modifiedDiffuseColor = bsdfData.diffuseColor; //GetModifiedDiffuseColorForSSS(bsdfData);

    // Apply the albedo to the direct diffuse lighting (only once). The indirect (baked)
    // diffuse lighting has already multiply the albedo in ModifyBakedDiffuseLighting().
    // Note: In deferred bakeDiffuseLighting also contain emissive and in this case emissiveColor is 0
    diffuseLighting = modifiedDiffuseColor * lighting.direct.diffuse + builtinData.bakeDiffuseLighting + builtinData.emissiveColor;

    // If refraction is enable we use the transmittanceMask to lerp between current diffuse lighting and refraction value
    // Physically speaking, transmittanceMask should be 1, but for artistic reasons, we let the value vary
    //
    // Note we also transfer the refracted light (lighting.indirect.specularTransmitted) into diffuseLighting
    // since we know it won't be further processed: it is called at the end of the LightLoop(), but doing this
    // enables opacity to affect it (in ApplyBlendMode()) while the rest of specularLighting escapes it.

    specularLighting = lighting.direct.specular + lighting.indirect.specularReflected;
#ifdef IRIDESCENCE_ENABLE_TRANSMISSION
    specularLighting += lighting.indirect.specularTransmitted;
#endif // IRIDESCENCE_ENABLE_TRANSMISSION
    // Rescale the GGX to account for the multiple scattering.
    specularLighting *= 1.0 + bsdfData.fresnel0 * preLightData.energyCompensation;

#ifdef DEBUG_DISPLAY
    PostEvaluateBSDFDebugDisplay(aoFactor, builtinData, lighting, bsdfData.diffuseColor, diffuseLighting, specularLighting);
#endif
}

#endif // #ifdef HAS_LIGHTLOOP
