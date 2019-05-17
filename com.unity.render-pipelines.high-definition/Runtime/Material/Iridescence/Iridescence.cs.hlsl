//
// This file was automatically generated. Please don't edit by hand.
//

#ifndef IRIDESCENCE_CS_HLSL
#define IRIDESCENCE_CS_HLSL

//
// UnityEngine.Experimental.Rendering.HDPipeline.Iridescence+SurfaceData:  static fields
//
#define DEBUGVIEW_IRIDESCENCE_SURFACEDATA_AMBIENT_OCCLUSION           (1000)
#define DEBUGVIEW_IRIDESCENCE_SURFACEDATA_SPECULAR_OCCLUSION          (1001)
#define DEBUGVIEW_IRIDESCENCE_SURFACEDATA_NORMAL                      (1002)
#define DEBUGVIEW_IRIDESCENCE_SURFACEDATA_NORMAL_VIEW_SPACE           (1003)
#define DEBUGVIEW_IRIDESCENCE_SURFACEDATA_SMOOTHNESS                  (1004)
#define DEBUGVIEW_IRIDESCENCE_SURFACEDATA_FRESNEL0                    (1005)
#define DEBUGVIEW_IRIDESCENCE_SURFACEDATA_IRIDESCENCE_LAYER_THICKNESS (1006)
#define DEBUGVIEW_IRIDESCENCE_SURFACEDATA_IRIDESCENCE_LAYER_ETA       (1007)
#define DEBUGVIEW_IRIDESCENCE_SURFACEDATA_IRIDESCENCE_BASE_ETA        (1008)
#define DEBUGVIEW_IRIDESCENCE_SURFACEDATA_IRIDESCENCE_BASE_KAPPA      (1009)

//
// UnityEngine.Experimental.Rendering.HDPipeline.Iridescence+BSDFData:  static fields
//
#define DEBUGVIEW_IRIDESCENCE_BSDFDATA_AMBIENT_OCCLUSION     (1050)
#define DEBUGVIEW_IRIDESCENCE_BSDFDATA_SPECULAR_OCCLUSION    (1051)
#define DEBUGVIEW_IRIDESCENCE_BSDFDATA_DIFFUSE_COLOR         (1052)
#define DEBUGVIEW_IRIDESCENCE_BSDFDATA_FRESNEL0              (1053)
#define DEBUGVIEW_IRIDESCENCE_BSDFDATA_NORMAL_WS             (1054)
#define DEBUGVIEW_IRIDESCENCE_BSDFDATA_NORMAL_VIEW_SPACE     (1055)
#define DEBUGVIEW_IRIDESCENCE_BSDFDATA_PERCEPTUAL_ROUGHNESS  (1056)
#define DEBUGVIEW_IRIDESCENCE_BSDFDATA_ROUGHNESS             (1057)
#define DEBUGVIEW_IRIDESCENCE_BSDFDATA_IRIDESCENCE_THICKNESS (1058)
#define DEBUGVIEW_IRIDESCENCE_BSDFDATA_IRIDESCENCE_ETA2      (1059)
#define DEBUGVIEW_IRIDESCENCE_BSDFDATA_IRIDESCENCE_ETA3      (1060)
#define DEBUGVIEW_IRIDESCENCE_BSDFDATA_IRIDESCENCE_KAPPA3    (1061)

// Generated from UnityEngine.Experimental.Rendering.HDPipeline.Iridescence+SurfaceData
// PackingRules = Exact
struct SurfaceData
{
    float ambientOcclusion;
    float specularOcclusion;
    float3 normalWS;
    float perceptualSmoothness;
    float3 fresnel0;
    float iridescenceThickness;
    float4 iridescenceThicknessSphereModel;
    float iridescenceEta2;
    float iridescenceEta3;
    float iridescenceKappa3;
};

// Generated from UnityEngine.Experimental.Rendering.HDPipeline.Iridescence+BSDFData
// PackingRules = Exact
struct BSDFData
{
    float ambientOcclusion;
    float specularOcclusion;
    float3 diffuseColor;
    float3 fresnel0;
    float3 normalWS;
    float perceptualRoughness;
    float roughness;
    float iridescenceThickness;
    float4 iridescenceThicknessSphereModel;
    float iridescenceEta2;
    float iridescenceEta3;
    float iridescenceKappa3;
};

//
// Debug functions
//
void GetGeneratedSurfaceDataDebug(uint paramId, SurfaceData surfacedata, inout float3 result, inout bool needLinearToSRGB)
{
    switch (paramId)
    {
        case DEBUGVIEW_IRIDESCENCE_SURFACEDATA_AMBIENT_OCCLUSION:
            result = surfacedata.ambientOcclusion.xxx;
            break;
        case DEBUGVIEW_IRIDESCENCE_SURFACEDATA_SPECULAR_OCCLUSION:
            result = surfacedata.specularOcclusion.xxx;
            break;
        case DEBUGVIEW_IRIDESCENCE_SURFACEDATA_NORMAL:
            result = surfacedata.normalWS * 0.5 + 0.5;
            break;
        case DEBUGVIEW_IRIDESCENCE_SURFACEDATA_NORMAL_VIEW_SPACE:
            result = surfacedata.normalWS * 0.5 + 0.5;
            break;
        case DEBUGVIEW_IRIDESCENCE_SURFACEDATA_SMOOTHNESS:
            result = surfacedata.perceptualSmoothness.xxx;
            break;
        case DEBUGVIEW_IRIDESCENCE_SURFACEDATA_FRESNEL0:
            result = surfacedata.fresnel0;
            needLinearToSRGB = true;
            break;
        case DEBUGVIEW_IRIDESCENCE_SURFACEDATA_IRIDESCENCE_LAYER_THICKNESS:
            result = surfacedata.iridescenceThickness.xxx;
            break;
        case DEBUGVIEW_IRIDESCENCE_SURFACEDATA_IRIDESCENCE_LAYER_ETA:
            result = surfacedata.iridescenceEta2.xxx;
            break;
        case DEBUGVIEW_IRIDESCENCE_SURFACEDATA_IRIDESCENCE_BASE_ETA:
            result = surfacedata.iridescenceEta3.xxx;
            break;
        case DEBUGVIEW_IRIDESCENCE_SURFACEDATA_IRIDESCENCE_BASE_KAPPA:
            result = surfacedata.iridescenceKappa3.xxx;
            break;
    }
}

//
// Debug functions
//
void GetGeneratedBSDFDataDebug(uint paramId, BSDFData bsdfdata, inout float3 result, inout bool needLinearToSRGB)
{
    switch (paramId)
    {
        case DEBUGVIEW_IRIDESCENCE_BSDFDATA_AMBIENT_OCCLUSION:
            result = bsdfdata.ambientOcclusion.xxx;
            break;
        case DEBUGVIEW_IRIDESCENCE_BSDFDATA_SPECULAR_OCCLUSION:
            result = bsdfdata.specularOcclusion.xxx;
            break;
        case DEBUGVIEW_IRIDESCENCE_BSDFDATA_DIFFUSE_COLOR:
            result = bsdfdata.diffuseColor;
            needLinearToSRGB = true;
            break;
        case DEBUGVIEW_IRIDESCENCE_BSDFDATA_FRESNEL0:
            result = bsdfdata.fresnel0;
            break;
        case DEBUGVIEW_IRIDESCENCE_BSDFDATA_NORMAL_WS:
            result = bsdfdata.normalWS * 0.5 + 0.5;
            break;
        case DEBUGVIEW_IRIDESCENCE_BSDFDATA_NORMAL_VIEW_SPACE:
            result = bsdfdata.normalWS * 0.5 + 0.5;
            break;
        case DEBUGVIEW_IRIDESCENCE_BSDFDATA_PERCEPTUAL_ROUGHNESS:
            result = bsdfdata.perceptualRoughness.xxx;
            break;
        case DEBUGVIEW_IRIDESCENCE_BSDFDATA_ROUGHNESS:
            result = bsdfdata.roughness.xxx;
            break;
        case DEBUGVIEW_IRIDESCENCE_BSDFDATA_IRIDESCENCE_THICKNESS:
            result = bsdfdata.iridescenceThickness.xxx;
            break;
        case DEBUGVIEW_IRIDESCENCE_BSDFDATA_IRIDESCENCE_ETA2:
            result = bsdfdata.iridescenceEta2.xxx;
            break;
        case DEBUGVIEW_IRIDESCENCE_BSDFDATA_IRIDESCENCE_ETA3:
            result = bsdfdata.iridescenceEta3.xxx;
            break;
        case DEBUGVIEW_IRIDESCENCE_BSDFDATA_IRIDESCENCE_KAPPA3:
            result = bsdfdata.iridescenceKappa3.xxx;
            break;
    }
}


#endif
