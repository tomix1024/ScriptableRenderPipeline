#include "PreIntegratedVdotL.cs.hlsl"

TEXTURECUBE(_PreIntegratedWSdotL_X1_GGX);
TEXTURECUBE(_PreIntegratedWSdotL_X2_GGX);
TEXTURECUBE(_PreIntegratedWSdotL_XY_GGX);

// For image based lighting, a part of the BSDF is pre-integrated.
// This is done both for specular GGX height-correlated and DisneyDiffuse
// reflectivity is  Integral{(BSDF_GGX / F) - use for multiscattering
void GetPreIntegratedVdotLGGX(float3 V, float3 iblR, float iblPerceptualRoughness, out float VdotL_mean, out float VdotL_var)
{
    V = normalize(V);
    float iblMipLevel = PerceptualRoughnessToMipmapLevel(iblPerceptualRoughness);

    float3 weightRGB = SAMPLE_TEXTURECUBE_LOD(_SkyTexture,  s_trilinear_clamp_sampler, iblR, iblMipLevel).rgb;
    float weight = dot(weightRGB, float3(0.2126, 0.7152, 0.0722));

    float3 momentsX  = SAMPLE_TEXTURECUBE_LOD(_PreIntegratedWSdotL_X1_GGX,  s_trilinear_clamp_sampler, iblR, iblMipLevel).rgb;
    float3 momentsX2 = SAMPLE_TEXTURECUBE_LOD(_PreIntegratedWSdotL_X2_GGX, s_trilinear_clamp_sampler, iblR, iblMipLevel).rgb;
    float3 momentsXY = SAMPLE_TEXTURECUBE_LOD(_PreIntegratedWSdotL_XY_GGX, s_trilinear_clamp_sampler, iblR, iblMipLevel).rgb;

    momentsX  /= weight;
    momentsX2 /= weight;
    momentsXY /= weight;

    VdotL_mean = dot(momentsX.xyz, V);
    VdotL_mean = min(1, max(-1, VdotL_mean));

    float3x3 viewWScovar = float3x3(
            momentsX2.x, momentsXY.x, momentsXY.z,
            momentsXY.x, momentsX2.y, momentsXY.y,
            momentsXY.z, momentsXY.y, momentsX2.z)
        - float3x3(
            momentsX.x*momentsX.x, momentsX.x*momentsX.y, momentsX.x*momentsX.z,
            momentsX.x*momentsX.y, momentsX.y*momentsX.y, momentsX.y*momentsX.z,
            momentsX.x*momentsX.z, momentsX.y*momentsX.z, momentsX.z*momentsX.z);

    VdotL_var = max(0, dot(V, mul(viewWScovar, V)));
}
