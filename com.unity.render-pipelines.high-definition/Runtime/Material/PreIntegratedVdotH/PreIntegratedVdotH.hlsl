#include "PreIntegratedVdotH.cs.hlsl"

TEXTURE2D(_PreIntegratedVdotH_GGX);

// For image based lighting, a part of the BSDF is pre-integrated.
// This is done both for specular GGX height-correlated and DisneyDiffuse
// reflectivity is  Integral{(BSDF_GGX / F) - use for multiscattering
void GetPreIntegratedVdotHGGX(float NdotV, float perceptualRoughness, out float4 VdotH_moments)
{
    // We want the LUT to contain the entire [0, 1] range, without losing half a texel at each side.
    float2 coordLUT = Remap01ToHalfTexelCoord(float2(sqrt(NdotV), perceptualRoughness), VDOTHTEXTURE_RESOLUTION);

    VdotH_moments = SAMPLE_TEXTURE2D_LOD(_PreIntegratedVdotH_GGX, s_linear_clamp_sampler, coordLUT, 0);
}
