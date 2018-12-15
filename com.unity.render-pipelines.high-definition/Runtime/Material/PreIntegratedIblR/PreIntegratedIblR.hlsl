// #include "PreIntegratedVdotH.cs.hlsl"

TEXTURE2D(_PreIntegratedIblR);

#define IBLRTEXTURE_RESOLUTION 128

void GetPreIntegratedIblR(float thetaV, float perceptualRoughness, out float iblThetaR, out float iblRoughness)
{
    // We want the LUT to contain the entire [0, 1] range, without losing half a texel at each side.
    float2 coordLUT = Remap01ToHalfTexelCoord(float2(thetaV* INV_HALF_PI, perceptualRoughness), IBLRTEXTURE_RESOLUTION);

    float4 val = SAMPLE_TEXTURE2D_LOD(_PreIntegratedIblR, s_linear_clamp_sampler, coordLUT, 0);
    iblThetaR = val.x;
    iblRoughness = val.y;
}

float3 RotateVector(float3 v, float3 axis, float angle)
{
    float2 sin_cos;
    sincos(angle, sin_cos.x, sin_cos.y);
    float3 v_o = v * sin_cos.y;
    v_o += cross(axis, v) * sin_cos.x;
    v_o += axis * (dot(axis, v)) * (1.0 - sin_cos.y);
    return v_o;
}

void GetPreIntegratedIblR(float NdotV, float perceptualRoughness, float3 N, float3 R, out float3 iblR, out float iblRoughness)
{
    float thetaV = acos(NdotV);
    float iblThetaR;
    GetPreIntegratedIblR(thetaV, perceptualRoughness, iblThetaR, iblRoughness);

    // Get Axis of N -> R rotation.
    float3 axis = normalize(cross(N, R));
    // Rotate by iblThetaR around axis.
    iblR = RotateVector(N, axis, iblThetaR);
}
