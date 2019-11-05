//-------------------------------------------------------------------------------------
// Fill SurfaceData/Builtin data function
//-------------------------------------------------------------------------------------
#include "Packages/com.unity.render-pipelines.high-definition/Runtime/Material/BuiltinUtilities.hlsl"
#include "Packages/com.unity.render-pipelines.high-definition/Runtime/Material/MaterialUtilities.hlsl"

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
    GetNormalWS(input, normalTS, surfaceData.normalWS);
#endif

    // No occlusion...
    surfaceData.ambientOcclusion = 1;
    surfaceData.specularOcclusion = 1;

    // Fill uniform data
    surfaceData.fresnel0 = _Fresnel0.rgb;
    surfaceData.perceptualSmoothness = _Smoothness;
    surfaceData.iridescenceThickness = _IridescenceThickness;
    surfaceData.iridescenceEta2 = _IridescenceEta2;
    surfaceData.iridescenceEta3 = _IridescenceEta3;
    surfaceData.iridescenceKappa3 = _IridescenceKappa3;

    // Apply offset and tiling
    float2 uvThickness = input.texCoord0.xy * _IridescenceThicknessMap_ST.xy + _IridescenceThicknessMap_ST.zw;

#ifdef IRIDESCENCE_USE_THICKNESS_MAP
    surfaceData.iridescenceThickness += _IridescenceThicknessMapScale * SAMPLE_TEXTURE2D(_IridescenceThicknessMap, sampler_IridescenceThicknessMap, uvThickness).x;
#endif // IRIDESCENCE_USE_THICKNESS_MAP

#if defined(DEBUG_DISPLAY)
    if (_DebugMipMapMode != DEBUGMIPMAPMODE_NONE)
    {
        // Not debug streaming information with AxF (this should never be stream)
        surfaceData.diffuseColor = float3(0.0, 0.0, 0.0);
    }
#endif

    // -------------------------------------------------------------
    // Builtin Data:
    // -------------------------------------------------------------

    float alpha = 1;
    InitBuiltinData(posInput, alpha, surfaceData.normalWS, surfaceData.normalWS, input.texCoord1, input.texCoord2, builtinData);
    PostInitBuiltinData(V, posInput, surfaceData, builtinData);
}
