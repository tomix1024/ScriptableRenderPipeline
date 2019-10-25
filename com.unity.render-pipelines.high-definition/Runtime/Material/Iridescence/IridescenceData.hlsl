//-------------------------------------------------------------------------------------
// Fill SurfaceData/Builtin data function
//-------------------------------------------------------------------------------------
#include "Packages/com.unity.render-pipelines.high-definition/Runtime/Material/BuiltinUtilities.hlsl"
#include "Packages/com.unity.render-pipelines.high-definition/Runtime/Material/MaterialUtilities.hlsl"

void GetSurfaceAndBuiltinData(FragInputs input, float3 V, inout PositionInputs posInput, out SurfaceData surfaceData, out BuiltinData builtinData)
{
    ApplyDoubleSidedFlipOrMirror(input); // Apply double sided flip on the vertex normal

    // Apply offset and tiling
    float2 uvNormal = input.texCoord0.xy * _NormalMap_ST.xy + _NormalMap_ST.zw;

    surfaceData.normalWS = input.worldToTangent[2].xyz;
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
    for (int i = 0; i < 4; ++i)
    {
        float2 uvPolar = float2(atan2(normalOS.z, normalOS.x) / TWO_PI, acos(-normalOS.y) / PI); // TODO verify axes and orientations
        surfaceData.iridescenceThicknessSphereModel[i] += _IridescenceThicknessMapScale * SAMPLE_TEXTURE2D(_IridescenceThicknessMap, sampler_IridescenceThicknessMap, uvPolar).x;

        normalOS = -reflect(-normalOS, viewDirOS);
        viewDirOS = reflect(viewDirOS, normalOS);
    }
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
    InitBuiltinData(alpha, surfaceData.normalWS, surfaceData.normalWS, input.positionRWS, input.texCoord1, input.texCoord2, builtinData);
    PostInitBuiltinData(V, posInput, surfaceData, builtinData);
}
