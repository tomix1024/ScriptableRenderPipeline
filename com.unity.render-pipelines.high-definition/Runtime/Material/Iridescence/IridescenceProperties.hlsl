// ===========================================================================
//                              WARNING:
// On PS4, texture/sampler declarations need to be outside of CBuffers
// Otherwise those parameters are not bound correctly at runtime.
// ===========================================================================

TEXTURE2D(_NormalMap);
SAMPLER(sampler_NormalMap);

TEXTURE2D(_IridescenceThicknessMap);
SAMPLER(sampler_IridescenceThicknessMap);
TEXTURECUBE(_IridescenceThicknessCubeMap);
SAMPLER(sampler_IridescenceThicknessCubeMap);

CBUFFER_START(UnityPerMaterial)

// shared constant between lit and layered lit
float _AlphaCutoff;
float _UseShadowThreshold;
float _AlphaCutoffShadow;
float _AlphaCutoffPrepass;
float _AlphaCutoffPostpass;
float4 _DoubleSidedConstants;

// Set of users variables
float _Smoothness;

float4 _Fresnel0;

float _NormalScale;
float4 _NormalMap_ST;

float4 _IridescenceThicknessMap_ST;
float _IridescenceThicknessMapScale;

float _IridescenceThickness;
float _IridescenceEta2;
float _IridescenceEta3;
float _IridescenceKappa3;

float4 _RayMask1;
float4 _RayMask2;
//float4 _RayMask3;
//float4 _RayMask4;

float _IridescenceSpectralThinFilmBounces;
float _IridescenceSpectralIntermediateRGB;

// Following two variables are feeded by the C++ Editor for Scene selection
int _ObjectId;
int _PassValue;



#ifdef IRIDESCENCE_VARIABLE_TERMS
    int _IridescenceTerms;
#else
    #define _IridescenceTerms 2
#endif // IRIDESCENCE_VARIABLE_TERMS

float _ReferenceUseCorrectOPD;
float _ReferenceUseCorrectCoeffs;
float _ReferenceUseMeanVdotH;
float _ReferenceUseVarVdotH;
float _ReferenceUseVdotHWeightWithLight;


#ifdef IRIDESCENCE_USE_PREINTEGRATED_IBLR
    #define _IBLUsePreIntegratedIblR true
#else
    #define _IBLUsePreIntegratedIblR false
#endif // IRIDESCENCE_USE_PREINTEGRATED_IBLR

#ifdef IRIDESCENCE_USE_PREINTEGRATED_IBLROUGHNESS
    #define _IBLUsePreIntegratedIblRoughness true
#else
    #define _IBLUsePreIntegratedIblRoughness false
#endif // IRIDESCENCE_USE_PREINTEGRATED_IBLROUGHNESS

#ifdef IRIDESCENCE_USE_VDOTH_MEAN
    #define _IridescenceUseMeanVdotH true
#else
    #define _IridescenceUseMeanVdotH false
#endif // IRIDESCENCE_USE_VDOTH_MEAN

#ifdef IRIDESCENCE_USE_VDOTH_VAR
    #define _IridescenceUseVarVdotH true
#else
    #define _IridescenceUseVarVdotH false
#endif // IRIDESCENCE_USE_VDOTH_VAR

#ifdef IRIDESCENCE_USE_VDOTL
    #define _IridescenceUseVdotL true
#else
    #define _IridescenceUseVdotL false
#endif // IRIDESCENCE_USE_VDOTL

#ifdef IRIDESCENCE_USE_PHASE_SHIFT
    #define _IridescenceUsePhaseShift true
#else
    #define _IridescenceUsePhaseShift false
#endif // IRIDESCENCE_USE_PHASE_SHIFT

#ifndef _IBLUsePreIntegratedIblR
    float _IBLUsePreIntegratedIblR;
#endif
#ifndef _IBLUsePreIntegratedIblRoughness
    float _IBLUsePreIntegratedIblRoughness;
#endif
#ifndef _IridescenceUseMeanVdotH
    float _IridescenceUseMeanVdotH;
#endif
#ifndef _IridescenceUseVarVdotH
    float _IridescenceUseVarVdotH;
#endif
#ifndef _IridescenceUseVdotL
    float _IridescenceUseVdotL;
#endif
#ifndef _IridescenceUsePhaseShift
    float _IridescenceUsePhaseShift;
#endif

float _ReferenceDebugMeanScale;
float _ReferenceDebugMeanOffset;
float _ReferenceDebugDevScale;
float _ReferenceDebugDevOffset;


CBUFFER_END
