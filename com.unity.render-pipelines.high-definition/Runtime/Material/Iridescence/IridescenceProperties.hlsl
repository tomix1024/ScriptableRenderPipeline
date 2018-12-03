// ===========================================================================
//                              WARNING:
// On PS4, texture/sampler declarations need to be outside of CBuffers
// Otherwise those parameters are not bound correctly at runtime.
// ===========================================================================

// TEXTURE2D(_NormalMap);
// SAMPLER(sampler_NormalMap);

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

float _IridescenceThickness;
float _IridescenceEta2;
float _IridescenceEta3;
float _IridescenceKappa3;


// Following two variables are feeded by the C++ Editor for Scene selection
int _ObjectId;
int _PassValue;




float _ReferenceUseBetterIblR;
float _ReferenceUseCorrectOPD;
float _ReferenceUseCorrectCoeffs;
float _ReferenceUseMeanVdotH;
float _ReferenceUseVdotHWeightWithLight;
float _IBLUsePreIntegratedFGD;
float _IBLUseFresnel0Iridescence;

float _MeanScale;
float _MeanOffset;
float _DevScale;
float _DevOffset;


CBUFFER_END
