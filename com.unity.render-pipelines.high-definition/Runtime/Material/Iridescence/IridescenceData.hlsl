//-------------------------------------------------------------------------------------
// Fill SurfaceData/Builtin data function
//-------------------------------------------------------------------------------------
#include "Packages/com.unity.render-pipelines.high-definition/Runtime/Material/BuiltinUtilities.hlsl"
#include "Packages/com.unity.render-pipelines.high-definition/Runtime/Material/MaterialUtilities.hlsl"

void GetSurfaceAndBuiltinData(FragInputs input, float3 V, inout PositionInputs posInput, out SurfaceData surfaceData, out BuiltinData builtinData)
{
    ApplyDoubleSidedFlipOrMirror(input); // Apply double sided flip on the vertex normal

    surfaceData.normalWS = input.worldToTangent[2].xyz;

    // No occlusion...
    surfaceData.ambientOcclusion = 1;
    surfaceData.specularOcclusion = 1;

    // Fill uniform data
    surfaceData.perceptualSmoothness = _Smoothness;
    surfaceData.iridescenceThickness = _IridescenceThickness;
    surfaceData.iridescenceEta2 = _IridescenceEta2;
    surfaceData.iridescenceEta3 = _IridescenceEta3;
    surfaceData.iridescenceKappa3 = _IridescenceKappa3;

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
