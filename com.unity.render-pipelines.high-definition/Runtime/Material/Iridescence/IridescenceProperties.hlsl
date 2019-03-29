// ===========================================================================
//                              WARNING:
// On PS4, texture/sampler declarations need to be outside of CBuffers
// Otherwise those parameters are not bound correctly at runtime.
// ===========================================================================

// TEXTURE2D(_NormalMap);
// SAMPLER(sampler_NormalMap);

TEXTURE2D(_IridescenceThicknessMap);
SAMPLER(sampler_IridescenceThicknessMap);

CBUFFER_START(UnityPerMaterial)

// shared constant between lit and layered lit
float _AlphaCutoff;
float _AlphaCutoffPrepass;
float _AlphaCutoffPostpass;
float4 _DoubleSidedConstants;

// Set of users variables
float _Smoothness;

float4 _Fresnel0;

// float _NormalScale;

float4 _IridescenceThicknessMap_ST;

float _IridescenceThickness;
float _IridescenceEta2;
float _IridescenceEta3;
float _IridescenceKappa3;


// Following two variables are feeded by the C++ Editor for Scene selection
int _ObjectId;
int _PassValue;




float _ReferenceUseCorrectOPD;
float _ReferenceUseCorrectCoeffs;
float _ReferenceUseMeanVdotH;
float _ReferenceUseVarVdotH;
float _ReferenceUseVdotHWeightWithLight;
float _ReferenceUseVdotL;

#ifdef IRIDESCENCE_USE_PREINTEGRATED_IBLR
    #define _IBLUsePreIntegratedIblR 1
#else
    #define _IBLUsePreIntegratedIblR 0
#endif // IRIDESCENCE_USE_PREINTEGRATED_IBLR

#ifdef IRIDESCENCE_USE_PREINTEGRATED_IBLROUGHNESS
    #define _IBLUsePreIntegratedIblRoughness 1
#else
    #define _IBLUsePreIntegratedIblRoughness 0
#endif // IRIDESCENCE_USE_PREINTEGRATED_IBLROUGHNESS

#ifdef IRIDESCENCE_USE_VDOTH_MEAN
    #define _IBLUseMeanVdotH 1
#else
    #define _IBLUseMeanVdotH 0
#endif // IRIDESCENCE_USE_VDOTH_MEAN

#ifdef IRIDESCENCE_USE_VDOTH_VAR
    #define _IBLUseVarVdotH 1
#else
    #define _IBLUseVarVdotH 0
#endif // IRIDESCENCE_USE_VDOTH_VAR

#ifdef IRIDESCENCE_USE_UKF
    #define _IridescenceUseUKF 1
#else
    #define _IridescenceUseUKF 0
#endif // IRIDESCENCE_USE_UKF

#ifndef _IBLUsePreIntegratedIblR
    float _IBLUsePreIntegratedIblR;
#endif
#ifndef _IBLUsePreIntegratedIblRoughness
    float _IBLUsePreIntegratedIblRoughness;
#endif
#ifndef _IBLUseMeanVdotH
    float _IBLUseMeanVdotH;
#endif
#ifndef _IBLUseVarVdotH
    float _IBLUseVarVdotH;
#endif
#ifndef _IridescenceUseUKF
    float _IridescenceUseUKF;
#endif
float _IridescenceUKFLambda;

float _ReferenceDebugMeanScale;
float _ReferenceDebugMeanOffset;
float _ReferenceDebugDevScale;
float _ReferenceDebugDevOffset;


CBUFFER_END
