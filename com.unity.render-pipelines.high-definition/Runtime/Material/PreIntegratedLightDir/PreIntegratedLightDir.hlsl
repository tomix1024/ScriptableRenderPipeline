#ifndef PREINTEGRATED_LIGHT_DIR_HLSL
#define PREINTEGRATED_LIGHT_DIR_HLSL

TEXTURECUBE_ARRAY(_SkyTextureLightDirMoments);
// TEXTURECUBE_ARRAY(_SkyTextureLightDirMoments_X1);
// TEXTURECUBE_ARRAY(_SkyTextureLightDirMoments_X2);
// TEXTURECUBE_ARRAY(_SkyTextureLightDirMoments_XY);

void GetPreIntegratedLightDirFromSky(float3 iblR, float iblPerceptualRoughness, out float3 lightDirMean, out float3x3 lightDirCovar, int sliceIndex = 0)
{
    float iblMipLevel = PerceptualRoughnessToMipmapLevel(iblPerceptualRoughness);

    float3 weightRGB = SAMPLE_TEXTURECUBE_ARRAY_LOD(_SkyTexture,  s_trilinear_clamp_sampler, iblR, sliceIndex, iblMipLevel).rgb;
    float weight = dot(weightRGB, float3(0.2126, 0.7152, 0.0722));

    float3 momentsX  = SAMPLE_TEXTURECUBE_ARRAY_LOD(_SkyTextureLightDirMoments, s_trilinear_clamp_sampler, iblR, sliceIndex*3 + 0, iblMipLevel).rgb;
    float3 momentsX2 = SAMPLE_TEXTURECUBE_ARRAY_LOD(_SkyTextureLightDirMoments, s_trilinear_clamp_sampler, iblR, sliceIndex*3 + 1, iblMipLevel).rgb;
    float3 momentsXY = SAMPLE_TEXTURECUBE_ARRAY_LOD(_SkyTextureLightDirMoments, s_trilinear_clamp_sampler, iblR, sliceIndex*3 + 2, iblMipLevel).rgb;

    momentsX  /= weight;
    momentsX2 /= weight;
    momentsXY /= weight;

    lightDirMean = momentsX;

    lightDirCovar = float3x3(
            momentsX2.x, momentsXY.x, momentsXY.z,
            momentsXY.x, momentsX2.y, momentsXY.y,
            momentsXY.z, momentsXY.y, momentsX2.z)
        - float3x3(
            momentsX.x*momentsX.x, momentsX.x*momentsX.y, momentsX.x*momentsX.z,
            momentsX.x*momentsX.y, momentsX.y*momentsX.y, momentsX.y*momentsX.z,
            momentsX.x*momentsX.z, momentsX.y*momentsX.z, momentsX.z*momentsX.z);
}

#endif // PREINTEGRATED_LIGHT_DIR_HLSL
