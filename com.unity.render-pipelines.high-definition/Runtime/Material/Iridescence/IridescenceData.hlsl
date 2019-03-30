//-------------------------------------------------------------------------------------
// Fill SurfaceData/Builtin data function
//-------------------------------------------------------------------------------------
#include "Packages/com.unity.render-pipelines.high-definition/Runtime/Material/BuiltinUtilities.hlsl"
#include "Packages/com.unity.render-pipelines.high-definition/Runtime/Material/MaterialUtilities.hlsl"

float2x3 ReflectScreenSpaceDerivatives(float3 i, float2x3 didxyT, float3 n, float2x3 dndxyT)
{
    float1x3 irow = i;
    float3x1 icol = transpose(irow);

    float1x3 nrow = n;
    float3x1 ncol = transpose(nrow);

    float2x3 dodxyT = didxyT;

    dodxyT -= mul(mul(didxyT, 2*ncol), nrow);

    dodxyT -= dndxyT * 2*dot(i, n);

    dodxyT -= mul(mul(dndxyT, 2*icol), nrow);

    return dodxyT;
}


void GetSurfaceAndBuiltinData(FragInputs input, float3 V, inout PositionInputs posInput, out SurfaceData surfaceData, out BuiltinData builtinData)
{
#ifdef _DOUBLESIDED_ON
    float3 doubleSidedConstants = _DoubleSidedConstants.xyz;
#else
    float3 doubleSidedConstants = float3(1.0, 1.0, 1.0);
#endif

    ApplyDoubleSidedFlipOrMirror(input, doubleSidedConstants); // Apply double sided flip on the vertex normal

    // Apply offset and tiling
    float2 uvNormal = input.texCoord0.xy * _NormalMap_ST.xy + _NormalMap_ST.zw;

    surfaceData.normalWS = input.tangentToWorld[2].xyz;
#ifdef _NORMALMAP
    float3 normalTS = UnpackNormalmapRGorAG(SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, uvNormal), _NormalScale);
    GetNormalWS(input, normalTS, surfaceData.normalWS, doubleSidedConstants);
#endif

    // No occlusion...
    surfaceData.ambientOcclusion = 1;
    surfaceData.specularOcclusion = 1;

    // Fill uniform data
    surfaceData.fresnel0 = _Fresnel0.rgb;
    surfaceData.perceptualSmoothness = _Smoothness;
    surfaceData.iridescenceThickness = _IridescenceThickness;
    surfaceData.iridescenceThicknessSphereModel = _IridescenceThickness.xxxx;
    surfaceData.iridescenceEta2 = _IridescenceEta2;
    surfaceData.iridescenceEta3 = _IridescenceEta3;
    surfaceData.iridescenceKappa3 = _IridescenceKappa3;

    // Apply offset and tiling
    float2 uvThickness = input.texCoord0.xy * _IridescenceThicknessMap_ST.xy + _IridescenceThicknessMap_ST.zw;

#ifdef IRIDESCENCE_USE_THICKNESS_MAP
    float2 uvPolar2 = float2(atan2(surfaceData.normalWS.z, surfaceData.normalWS.x) / TWO_PI, acos(surfaceData.normalWS.y) / PI); // TODO verify axes and orientations
    surfaceData.iridescenceThickness += _IridescenceThicknessMapScale * SAMPLE_TEXTURE2D(_IridescenceThicknessMap, sampler_IridescenceThicknessMap, uvThickness).x;

    // For sphere model:

    // TODO get normalOS and viewDirOS from somewhere?!
    float3 normalOS = surfaceData.normalWS;
    float3 viewDirOS = V;

    // NOTE this is transposed jacobian!
    float2x3 dnormalOSdxyT;
    dnormalOSdxyT[0] = ddx(surfaceData.normalWS);
    dnormalOSdxyT[1] = ddy(surfaceData.normalWS);
    float2x3 dviewDirOSdxyT; // Assume view dir constant
    dviewDirOSdxyT[0] = float3(0, 0, 0);
    dviewDirOSdxyT[1] = float3(0, 0, 0);

    for (int i = 0; i < 4; ++i)
    {
        float2 uvPolar = float2(atan2(normalOS.z, normalOS.x) / TWO_PI, acos(-normalOS.y) / PI); // TODO verify axes and orientations

        float3x2 duvPolardnormalOST;
        // duvPolarxdnormalOSx
        duvPolardnormalOST[0][0] = -normalOS.z / dot(normalOS.xz, normalOS.xz) / TWO_PI;
        // duvPolarxdnormalOSy
        duvPolardnormalOST[1][0] = 0;
        // duvPolarxdnormalOSz
        duvPolardnormalOST[2][0] = normalOS.x / dot(normalOS.xz, normalOS.xz) / TWO_PI;

        // duvPolarydnormalOSx
        duvPolardnormalOST[0][1] = 0;
        // duvPolarydnormalOSy
        duvPolardnormalOST[1][1] = -1.0 / sqrt(1 - normalOS.y*normalOS.y) / PI;
        // duvPolarydnormalOSz
        duvPolardnormalOST[2][1] = 0;

        // NOTE this is transposed jacobain!
        float2x2 duvPolardxyT;
        duvPolardxyT = mul(dnormalOSdxyT, duvPolardnormalOST);
        // duvPolardxyT[0] = ddx(uvPolar);
        // duvPolardxyT[1] = ddy(uvPolar);

        surfaceData.iridescenceThicknessSphereModel[i] += _IridescenceThicknessMapScale * SAMPLE_TEXTURE2D_GRAD(_IridescenceThicknessMap, sampler_IridescenceThicknessMap, uvPolar, duvPolardxyT[0], duvPolardxyT[1]).x;
        // surfaceData.iridescenceThicknessSphereModel[i] += _IridescenceThicknessMapScale * SAMPLE_TEXTURE2D(_IridescenceThicknessMap, sampler_IridescenceThicknessMap, uvPolar).x;

        {
            ReflectScreenSpaceDerivatives(normalOS, dnormalOSdxyT, viewDirOS, dviewDirOSdxyT);
            normalOS = reflect(normalOS, viewDirOS); // TODO remove minus signs, they should cancle out here!
        }

        {
            ReflectScreenSpaceDerivatives(viewDirOS, dviewDirOSdxyT, normalOS, dnormalOSdxyT);
            viewDirOS = reflect(viewDirOS, normalOS);
        }
    }
#endif // IRIDESCENCE_USE_THICKNESS_MAP

    // -------------------------------------------------------------
    // Builtin Data:
    // -------------------------------------------------------------

    float alpha = 1;
    InitBuiltinData(posInput, alpha, surfaceData.normalWS, surfaceData.normalWS, input.texCoord1, input.texCoord2, builtinData);
    PostInitBuiltinData(V, posInput, surfaceData, builtinData);
}
