#ifndef UNITY_BSDF_INCLUDED
#define UNITY_BSDF_INCLUDED

// Note: All NDF and diffuse term have a version with and without divide by PI.
// Version with divide by PI are use for direct lighting.
// Version without divide by PI are use for image based lighting where often the PI cancel during importance sampling

//-----------------------------------------------------------------------------
// Fresnel term
//-----------------------------------------------------------------------------

real F_Schlick(real f0, real f90, real u)
{
    real x = 1.0 - u;
    real x2 = x * x;
    real x5 = x * x2 * x2;
    return (f90 - f0) * x5 + f0;                // sub mul mul mul sub mad
}

real F_Schlick(real f0, real u)
{
    return F_Schlick(f0, 1.0, u);               // sub mul mul mul sub mad
}

real3 F_Schlick(real3 f0, real f90, real u)
{
    real x = 1.0 - u;
    real x2 = x * x;
    real x5 = x * x2 * x2;
    return f0 * (1.0 - x5) + (f90 * x5);        // sub mul mul mul sub mul mad*3
}

real3 F_Schlick(real3 f0, real u)
{
    return F_Schlick(f0, 1.0, u);               // sub mul mul mul sub mad*3
}

// Does not handle TIR.
real F_Transm_Schlick(real f0, real f90, real u)
{
    real x = 1.0 - u;
    real x2 = x * x;
    real x5 = x * x2 * x2;
    return (1.0 - f90 * x5) - f0 * (1.0 - x5);  // sub mul mul mul mad sub mad
}

// Does not handle TIR.
real F_Transm_Schlick(real f0, real u)
{
    return F_Transm_Schlick(f0, 1.0, u);        // sub mul mul mad mad
}

// Does not handle TIR.
real3 F_Transm_Schlick(real3 f0, real f90, real u)
{
    real x = 1.0 - u;
    real x2 = x * x;
    real x5 = x * x2 * x2;
    return (1.0 - f90 * x5) - f0 * (1.0 - x5);  // sub mul mul mul mad sub mad*3
}

// Does not handle TIR.
real3 F_Transm_Schlick(real3 f0, real u)
{
    return F_Transm_Schlick(f0, 1.0, u);        // sub mul mul mad mad*3
}

// Ref: https://seblagarde.wordpress.com/2013/04/29/memo-on-fresnel-equations/
// Fresnel dieletric / dielectric
real F_FresnelDieletric(real ior, real u)
{
    real g = sqrt(Sq(ior) + Sq(u) - 1.0);
    return 0.5 * Sq((g - u) / (g + u)) * (1.0 + Sq(((g + u) * u - 1.0) / ((g - u) * u + 1.0)));
}

// Fresnel dieletric / conductor
// Note: etak2 = etak * etak (optimization for Artist Friendly Metallic Fresnel below)
// eta = eta_t / eta_i and etak = k_t / n_i
real3 F_FresnelConductor(real3 eta, real3 etak2, real cosTheta)
{
    real cosTheta2 = cosTheta * cosTheta;
    real sinTheta2 = 1.0 - cosTheta2;
    real3 eta2 = eta * eta;

    real3 t0 = eta2 - etak2 - sinTheta2;
    real3 a2plusb2 = sqrt(t0 * t0 + 4.0 * eta2 * etak2);
    real3 t1 = a2plusb2 + cosTheta2;
    real3 a = sqrt(0.5 * (a2plusb2 + t0));
    real3 t2 = 2.0 * a * cosTheta;
    real3 Rs = (t1 - t2) / (t1 + t2);

    real3 t3 = cosTheta2 * a2plusb2 + sinTheta2 * sinTheta2;
    real3 t4 = t2 * sinTheta2;
    real3 Rp = Rs * (t3 - t4) / (t3 + t4);

    return 0.5 * (Rp + Rs);
}

real3 F_FresnelConductor(real3 eta, real3 etak2, real cosTheta, out real3 Rp, out real3 Rs)
{
    real cosTheta2 = cosTheta * cosTheta;
    real sinTheta2 = 1.0 - cosTheta2;
    real3 eta2 = eta * eta;

    real3 t0 = eta2 - etak2 - sinTheta2;
    real3 a2plusb2 = sqrt(t0 * t0 + 4.0 * eta2 * etak2);
    real3 t1 = a2plusb2 + cosTheta2;
    real3 a = sqrt(0.5 * (a2plusb2 + t0));
    real3 t2 = 2.0 * a * cosTheta;
    Rs = (t1 - t2) / (t1 + t2);

    real3 t3 = cosTheta2 * a2plusb2 + sinTheta2 * sinTheta2;
    real3 t4 = t2 * sinTheta2;
    Rp = Rs * (t3 - t4) / (t3 + t4);

    return 0.5 * (Rp + Rs);
}

// Phase shift due to a conducting material.
// See [A Practical Extension to Microfacet Theory for the Modeling of Varying Iridescence]
// Their implementation apparently uses n = eta * (1 + i kappa), but is inconsistent on that.
// We use n = eta + i kappa
void FresnelConductorPhase(real cosTheta,
                                real3 eta1,
                                real3 eta2, real3 kappa2,
                                out real3 phiP, out real3 phiS)
{
    real sinThetaSq = 1.0 - Sq(cosTheta);
    real3 A = Sq(eta2) - Sq(kappa2) - Sq(eta1)*sinThetaSq;
    real3 B = sqrt(Sq(A) + 4*Sq(eta2)*Sq(kappa2));
    real3 USq = (A+B) / 2.0;
    real3 VSq = (B-A) / 2.0;
    real3 U = sqrt(USq);
    real3 V = sqrt(VSq);

    phiS = atan2(-2*eta1*V*cosTheta, Sq(eta1*cosTheta) - USq - VSq);
    phiP = atan2(2*eta1*cosTheta * (2*eta2*kappa2*U - (Sq(eta2) - Sq(kappa2)) * V),
                 Sq((Sq(eta2)+Sq(kappa2))*cosTheta) - Sq(eta1)*B/*(USq+VSq)*/);
}

void ComplexSquareRoot(float3 sq_re, float3 sq_im, out float3 re, out float3 im)
{
    float3 phi = atan2(sq_im, sq_re);
    float3 r = sqrt(sq_re * sq_re + sq_im * sq_im);

    r = sqrt(r);
    phi /= 2;

    re = r * cos(phi);
    im = r * sin(phi);
}

/*
void F_FresnelConductorPhase(real3 eta_re, real3 eta_im, real cosTheta, out real3 phi_p, out real3 phi_s)
{
    real cosTheta_sq = cosTheta * cosTheta;

    real3 eta_re_sq = eta_re * eta_re;
    real3 eta_im_sq = eta_im * eta_im;

    real3 eta_abs_sq = eta_re_sq + eta_im_sq;

    real3 eta_sq_re = eta_re_sq - eta_im_sq;
    // real3 eta_sq_im = 2 * eta_re * eta_im;

    real3 eta_sq_re_sq = eta_sq_re * eta_sq_re;
    // real3 eta_sq_im_sq = eta_sq_im * eta_sq_im;
    real3 eta_sq_im_sq = 4 * eta_re_sq * eta_im_sq;

    real3 eta_sq_inv_re = eta_sq_re_sq / (eta_sq_re_sq + eta_sq_im_sq);
    real3 eta_sq_inv_im = -eta_sq_im_sq / (eta_sq_re_sq + eta_sq_im_sq);

    real3 cosThetaTrans_sq_re = 1 - eta_sq_inv_re * (1 - cosTheta_sq);
    real3 cosThetaTrans_sq_im = 0 - eta_sq_inv_im * (1 - cosTheta_sq);

    real3 cosThetaTrans_re = 0; // TODO!
    real3 cosThetaTrans_im = 0; // TODO!
    ComplexSquareRoot(cosThetaTrans_sq_re, cosThetaTrans_sq_im, cosThetaTrans_re, cosThetaTrans_im);

    real3 cosThetaTrans_re_sq = cosThetaTrans_re * cosThetaTrans_re;
    real3 cosThetaTrans_im_sq = cosThetaTrans_im * cosThetaTrans_im;
    real3 cosThetaTrans_abs_sq = cosThetaTrans_re_sq + cosThetaTrans_im_sq;

    real3 rp_re = eta_abs_sq * cosTheta_sq - cosThetaTrans_abs_sq;
    real3 rp_im = 2 * cosTheta * (eta_im * cosThetaTrans_re - eta_re * cosThetaTrans_im);

    real3 rs_re = cosTheta_sq - eta_abs_sq * cosThetaTrans_abs_sq;
    real3 rs_im = -2 * cosTheta * (eta_im * cosThetaTrans_re + eta_re * cosThetaTrans_im);

    phi_p = atan2(rp_im, rp_re);
    phi_s = atan2(rs_im, rs_re);
}
*/

// Conversion FO/IOR

TEMPLATE_2_REAL(IorToFresnel0, transmittedIor, incidentIor, return Sq((transmittedIor - incidentIor) / (transmittedIor + incidentIor)) )
// ior is a value between 1.0 and 3.0. 1.0 is air interface
real IorToFresnel0(real transmittedIor)
{
    return IorToFresnel0(transmittedIor, 1.0);
}

// Assume air interface for top
// Note: We don't handle the case fresnel0 == 1
//real Fresnel0ToIor(real fresnel0)
//{
//    real sqrtF0 = sqrt(fresnel0);
//    return (1.0 + sqrtF0) / (1.0 - sqrtF0);
//}
TEMPLATE_1_REAL(Fresnel0ToIor, fresnel0, return ((1.0 + sqrt(fresnel0)) / (1.0 - sqrt(fresnel0))) )

// This function is a coarse approximation of computing fresnel0 for a different top than air (here clear coat of IOR 1.5) when we only have fresnel0 with air interface
// This function is equivalent to IorToFresnel0(Fresnel0ToIor(fresnel0), 1.5)
// mean
// real sqrtF0 = sqrt(fresnel0);
// return Sq(1.0 - 5.0 * sqrtF0) / Sq(5.0 - sqrtF0);
// Optimization: Fit of the function (3 mad) for range [0.04 (should return 0), 1 (should return 1)]
TEMPLATE_1_REAL(ConvertF0ForAirInterfaceToF0ForClearCoat15, fresnel0, return saturate(-0.0256868 + fresnel0 * (0.326846 + (0.978946 - 0.283835 * fresnel0) * fresnel0)))

// Artist Friendly Metallic Fresnel Ref: http://jcgt.org/published/0003/04/03/paper.pdf

real3 GetIorN(real3 f0, real3 edgeTint)
{
    real3 sqrtF0 = sqrt(f0);
    return lerp((1.0 - f0) / (1.0 + f0), (1.0 + sqrtF0) / (1.0 - sqrt(f0)), edgeTint);
}

real3 getIorK2(real3 f0, real3 n)
{
    real3 nf0 = Sq(n + 1.0) * f0 - Sq(f0 - 1.0);
    return nf0 / (1.0 - f0);
}

// same as regular refract except there is not the test for total internal reflection + the vector is flipped for processing
real3 CoatRefract(real3 X, real3 N, real ieta)
{
    real XdotN = saturate(dot(N, X));
    return ieta * X + (sqrt(1 + ieta * ieta * (XdotN * XdotN - 1)) - ieta * XdotN) * N;
}

//-----------------------------------------------------------------------------
// Specular BRDF
//-----------------------------------------------------------------------------

real D_GGXNoPI(real NdotH, real roughness)
{
    real a2 = Sq(roughness);
    real s = (NdotH * a2 - NdotH) * NdotH + 1.0;

    // If roughness is 0, returns (NdotH == 1 ? 1 : 0).
    // That is, it returns 1 for perfect mirror reflection, and 0 otherwise.
    return SafeDiv(a2, s * s);
}

real D_GGX(real NdotH, real roughness)
{
    return INV_PI * D_GGXNoPI(NdotH, roughness);
}

// Ref: Understanding the Masking-Shadowing Function in Microfacet-Based BRDFs, p. 19, 29.
real G_MaskingSmithGGX(real NdotV, real roughness)
{
    // G1(V, H)    = HeavisideStep(VdotH) / (1 + Λ(V)).
    // Λ(V)        = -0.5 + 0.5 * sqrt(1 + 1 / a²).
    // a           = 1 / (roughness * tan(theta)).
    // 1 + Λ(V)    = 0.5 + 0.5 * sqrt(1 + roughness² * tan²(theta)).
    // tan²(theta) = (1 - cos²(theta)) / cos²(theta) = 1 / cos²(theta) - 1.
    // Assume that (VdotH > 0), e.i. (acos(LdotV) < Pi).

    return 1.0 / (0.5 + 0.5 * sqrt(1.0 + Sq(roughness) * (1.0 / Sq(NdotV) - 1.0)));
}

// Ref: Understanding the Masking-Shadowing Function in Microfacet-Based BRDFs, p. 12.
real D_GGX_Visible(real NdotH, real NdotV, real VdotH, real roughness)
{
    return D_GGX(NdotH, roughness) * G_MaskingSmithGGX(NdotV, roughness) * VdotH / NdotV;
}

// Precompute part of lambdaV
real GetSmithJointGGXPartLambdaV(real NdotV, real roughness)
{
    real a2 = Sq(roughness);
    return sqrt((-NdotV * a2 + NdotV) * NdotV + a2);
}

// Note: V = G / (4 * NdotL * NdotV)
// Ref: http://jcgt.org/published/0003/02/03/paper.pdf
real V_SmithJointGGX(real NdotL, real NdotV, real roughness, real partLambdaV)
{
    real a2 = Sq(roughness);

    // Original formulation:
    // lambda_v = (-1 + sqrt(a2 * (1 - NdotL2) / NdotL2 + 1)) * 0.5
    // lambda_l = (-1 + sqrt(a2 * (1 - NdotV2) / NdotV2 + 1)) * 0.5
    // G        = 1 / (1 + lambda_v + lambda_l);

    // Reorder code to be more optimal:
    real lambdaV = NdotL * partLambdaV;
    real lambdaL = NdotV * sqrt((-NdotL * a2 + NdotL) * NdotL + a2);

    // Simplify visibility term: (2.0 * NdotL * NdotV) /  ((4.0 * NdotL * NdotV) * (lambda_v + lambda_l))
    return 0.5 / (lambdaV + lambdaL);
}

real V_SmithJointGGX(real NdotL, real NdotV, real roughness)
{
    real partLambdaV = GetSmithJointGGXPartLambdaV(NdotV, roughness);
    return V_SmithJointGGX(NdotL, NdotV, roughness, partLambdaV);
}

// Inline D_GGX() * V_SmithJointGGX() together for better code generation.
real DV_SmithJointGGX(real NdotH, real NdotL, real NdotV, real roughness, real partLambdaV)
{
    real a2 = Sq(roughness);
    real s = (NdotH * a2 - NdotH) * NdotH + 1.0;

    real lambdaV = NdotL * partLambdaV;
    real lambdaL = NdotV * sqrt((-NdotL * a2 + NdotL) * NdotL + a2);

    real2 D = real2(a2, s * s);            // Fraction without the multiplier (1/Pi)
    real2 G = real2(1, lambdaV + lambdaL); // Fraction without the multiplier (1/2)

    // This function is only used for direct lighting.
    // If roughness is 0, the probability of hitting a punctual or directional light is also 0.
    // Therefore, we return 0. The most efficient way to do it is with a max().
    return INV_PI * 0.5 * (D.x * G.x) / max(D.y * G.y, FLT_MIN);
}

real DV_SmithJointGGX(real NdotH, real NdotL, real NdotV, real roughness)
{
    real partLambdaV = GetSmithJointGGXPartLambdaV(NdotV, roughness);
    return DV_SmithJointGGX(NdotH, NdotL, NdotV, roughness, partLambdaV);
}

// Precompute a part of LambdaV.
// Note on this linear approximation.
// Exact for roughness values of 0 and 1. Also, exact when the cosine is 0 or 1.
// Otherwise, the worst case relative error is around 10%.
// https://www.desmos.com/calculator/wtp8lnjutx
real GetSmithJointGGXPartLambdaVApprox(real NdotV, real roughness)
{
    real a = roughness;
    return NdotV * (1 - a) + a;
}

real V_SmithJointGGXApprox(real NdotL, real NdotV, real roughness, real partLambdaV)
{
    real a = roughness;

    real lambdaV = NdotL * partLambdaV;
    real lambdaL = NdotV * (NdotL * (1 - a) + a);

    return 0.5 / (lambdaV + lambdaL);
}

real V_SmithJointGGXApprox(real NdotL, real NdotV, real roughness)
{
    real partLambdaV = GetSmithJointGGXPartLambdaVApprox(NdotV, roughness);
    return V_SmithJointGGXApprox(NdotL, NdotV, roughness, partLambdaV);
}

// roughnessT -> roughness in tangent direction
// roughnessB -> roughness in bitangent direction
real D_GGXAnisoNoPI(real TdotH, real BdotH, real NdotH, real roughnessT, real roughnessB)
{
    real a2 = roughnessT * roughnessB;
    real3 v = real3(roughnessB * TdotH, roughnessT * BdotH, a2 * NdotH);
    real  s = dot(v, v);

    // If roughness is 0, returns (NdotH == 1 ? 1 : 0).
    // That is, it returns 1 for perfect mirror reflection, and 0 otherwise.
    return SafeDiv(a2 * a2 * a2, s * s);
}

real D_GGXAniso(real TdotH, real BdotH, real NdotH, real roughnessT, real roughnessB)
{
    return INV_PI * D_GGXAnisoNoPI(TdotH, BdotH, NdotH, roughnessT, roughnessB);
}

real GetSmithJointGGXAnisoPartLambdaV(real TdotV, real BdotV, real NdotV, real roughnessT, real roughnessB)
{
    return length(real3(roughnessT * TdotV, roughnessB * BdotV, NdotV));
}

// Note: V = G / (4 * NdotL * NdotV)
// Ref: https://cedec.cesa.or.jp/2015/session/ENG/14698.html The Rendering Materials of Far Cry 4
real V_SmithJointGGXAniso(real TdotV, real BdotV, real NdotV, real TdotL, real BdotL, real NdotL, real roughnessT, real roughnessB, real partLambdaV)
{
    real lambdaV = NdotL * partLambdaV;
    real lambdaL = NdotV * length(real3(roughnessT * TdotL, roughnessB * BdotL, NdotL));

    return 0.5 / (lambdaV + lambdaL);
}

real V_SmithJointGGXAniso(real TdotV, real BdotV, real NdotV, real TdotL, real BdotL, real NdotL, real roughnessT, real roughnessB)
{
    real partLambdaV = GetSmithJointGGXAnisoPartLambdaV(TdotV, BdotV, NdotV, roughnessT, roughnessB);
    return V_SmithJointGGXAniso(TdotV, BdotV, NdotV, TdotL, BdotL, NdotL, roughnessT, roughnessB, partLambdaV);
}

// Inline D_GGXAniso() * V_SmithJointGGXAniso() together for better code generation.
real DV_SmithJointGGXAniso(real TdotH, real BdotH, real NdotH, real NdotV,
                           real TdotL, real BdotL, real NdotL,
                           real roughnessT, real roughnessB, real partLambdaV)
{
    real a2 = roughnessT * roughnessB;
    real3 v = real3(roughnessB * TdotH, roughnessT * BdotH, a2 * NdotH);
    real  s = dot(v, v);

    real lambdaV = NdotL * partLambdaV;
    real lambdaL = NdotV * length(real3(roughnessT * TdotL, roughnessB * BdotL, NdotL));

    real2 D = real2(a2 * a2 * a2, s * s);  // Fraction without the multiplier (1/Pi)
    real2 G = real2(1, lambdaV + lambdaL); // Fraction without the multiplier (1/2)

    // This function is only used for direct lighting.
    // If roughness is 0, the probability of hitting a punctual or directional light is also 0.
    // Therefore, we return 0. The most efficient way to do it is with a max().
    return (INV_PI * 0.5) * (D.x * G.x) / max(D.y * G.y, FLT_MIN);
}

real DV_SmithJointGGXAniso(real TdotH, real BdotH, real NdotH,
                           real TdotV, real BdotV, real NdotV,
                           real TdotL, real BdotL, real NdotL,
                           real roughnessT, real roughnessB)
{
    real partLambdaV = GetSmithJointGGXAnisoPartLambdaV(TdotV, BdotV, NdotV, roughnessT, roughnessB);
    return DV_SmithJointGGXAniso(TdotH, BdotH, NdotH, NdotV,
                                 TdotL, BdotL, NdotL,
                                 roughnessT, roughnessB, partLambdaV);
}

//-----------------------------------------------------------------------------
// Diffuse BRDF - diffuseColor is expected to be multiply by the caller
//-----------------------------------------------------------------------------

real LambertNoPI()
{
    return 1.0;
}

real Lambert()
{
    return INV_PI;
}

real DisneyDiffuseNoPI(real NdotV, real NdotL, real LdotV, real perceptualRoughness)
{
    // (2 * LdotH * LdotH) = 1 + LdotV
    // real fd90 = 0.5 + 2 * LdotH * LdotH * perceptualRoughness;
    real fd90 = 0.5 + (perceptualRoughness + perceptualRoughness * LdotV);
    // Two schlick fresnel term
    real lightScatter = F_Schlick(1.0, fd90, NdotL);
    real viewScatter = F_Schlick(1.0, fd90, NdotV);

    // Normalize the BRDF for polar view angles of up to (Pi/4).
    // We use the worst case of (roughness = albedo = 1), and, for each view angle,
    // integrate (brdf * cos(theta_light)) over all light directions.
    // The resulting value is for (theta_view = 0), which is actually a little bit larger
    // than the value of the integral for (theta_view = Pi/4).
    // Hopefully, the compiler folds the constant together with (1/Pi).
    return rcp(1.03571) * (lightScatter * viewScatter);
}

real DisneyDiffuse(real NdotV, real NdotL, real LdotV, real perceptualRoughness)
{
    return INV_PI * DisneyDiffuseNoPI(NdotV, NdotL, LdotV, perceptualRoughness);
}

// Ref: Diffuse Lighting for GGX + Smith Microsurfaces, p. 113.
real3 DiffuseGGXNoPI(real3 albedo, real NdotV, real NdotL, real NdotH, real LdotV, real roughness)
{
    real facing = 0.5 + 0.5 * LdotV;              // (LdotH)^2
    real rough = facing * (0.9 - 0.4 * facing) * (0.5 / NdotH + 1);
    real transmitL = F_Transm_Schlick(0, NdotL);
    real transmitV = F_Transm_Schlick(0, NdotV);
    real smooth = transmitL * transmitV * 1.05;   // Normalize F_t over the hemisphere
    real single = lerp(smooth, rough, roughness); // Rescaled by PI
    real multiple = roughness * (0.1159 * PI);      // Rescaled by PI

    return single + albedo * multiple;
}

real3 DiffuseGGX(real3 albedo, real NdotV, real NdotL, real NdotH, real LdotV, real roughness)
{
    // Note that we could save 2 cycles by inlining the multiplication by INV_PI.
    return INV_PI * DiffuseGGXNoPI(albedo, NdotV, NdotL, NdotH, LdotV, roughness);
}

//-----------------------------------------------------------------------------
// Iridescence
//-----------------------------------------------------------------------------

// Ref: https://belcour.github.io/blog/research/2017/05/01/brdf-thin-film.html
// Evaluation XYZ sensitivity curves in Fourier space
real3 EvalSensitivity(real opd, real shift)
{
    // Use Gaussian fits, given by 3 parameters: val, pos and var
    real phase = 2.0 * PI * opd * 1e-6;
    real3 val = real3(5.4856e-13, 4.4201e-13, 5.2481e-13);
    real3 pos = real3(1.6810e+06, 1.7953e+06, 2.2084e+06);
    real3 var = real3(4.3278e+09, 9.3046e+09, 6.6121e+09);
    real3 xyz = val * sqrt(2.0 * PI * var) * cos(pos * phase + shift) * exp(-var * phase * phase);
    xyz.x += 9.7470e-14 * sqrt(2.0 * PI * 4.5282e+09) * cos(2.2399e+06 * phase + shift) * exp(-4.5282e+09 * phase * phase);
    return xyz / 1.0685e-7;
}

TEXTURE2D_ARRAY(_IridescenceSensitivityMap);
SAMPLER(sampler_IridescenceSensitivityMap);
real4 _IridescenceSensitivityMap_ST;

real3 EvalSensitivityTable(real opd, real3 phi, real opdSigma = 0)
{
    real3 result;
    real2 uv = TRANSFORM_TEX(real2(opd, opdSigma), _IridescenceSensitivityMap);
    for (int index = 0; index < 3; ++index)
    {
        real2 magsqrt_phase = SAMPLE_TEXTURE2D_ARRAY_LOD(_IridescenceSensitivityMap, sampler_IridescenceSensitivityMap, uv, index, 0).rg;
        real mag = Sq(magsqrt_phase.r);
        real phase = magsqrt_phase.g;
        result[index] = mag * cos(phase - phi[index]);
        ///   cos(phase - phi)
        /// = cos(phase) * cos(phi) + sin(phase) * sin(phi)
    }
    return result;
}

// Evaluate the reflectance for a thin-film layer on top of a dielectric medum.
real3 EvalIridescence(real eta_1, real cosTheta1, real iridescenceThickness, real3 baseLayerFresnel0, real iorOverBaseLayer = 0.0)
{
    // iridescenceThickness unit is micrometer for this equation here. Mean 0.5 is 500nm.
    real Dinc = 3.0 * iridescenceThickness;

    // Note: Unlike the code provide with the paper, here we use schlick approximation
    // Schlick is a very poor approximation when dealing with iridescence to the Fresnel
    // term and there is no "neutral" value in this unlike in the original paper.
    // We use Iridescence mask here to allow to have neutral value

    // Hack: In order to use only one parameter (DInc), we deduced the ior of iridescence from current Dinc iridescenceThickness
    // and we use mask instead to fade out the effect
    real eta_2 = lerp(2.0, 1.0, iridescenceThickness);
    // Following line from original code is not needed for us, it create a discontinuity
    // Force eta_2 -> eta_1 when Dinc -> 0.0
    // real eta_2 = lerp(eta_1, eta_2, smoothstep(0.0, 0.03, Dinc));
    // Evaluate the cosTheta on the base layer (Snell law)
    real sinTheta2 = Sq(eta_1 / eta_2) * (1.0 - Sq(cosTheta1));

    // Handle TIR
    if (sinTheta2 > 1.0)
        return real3(1.0, 1.0, 1.0);
    //Or use this "artistic hack" to get more continuity even though wrong (test with dual normal maps to understand the difference)
    //if( sinTheta2 > 1.0 ) { sinTheta2 = 2 - sinTheta2; }

    real cosTheta2 = sqrt(1.0 - sinTheta2);

    // First interface
    real R0 = IorToFresnel0(eta_2, eta_1);
    real R12 = F_Schlick(R0, cosTheta1);
    real R21 = R12;
    real T121 = 1.0 - R12;
    real phi12 = 0.0;
    real phi21 = PI - phi12;

    // Second interface
    // The f0 or the base should account for the new computed eta_2 on top.
    // This is optionally done if we are given the needed current ior over the base layer that is accounted for
    // in the baseLayerFresnel0 parameter:
    if (iorOverBaseLayer > 0.0)
    {
        // Fresnel0ToIor will give us a ratio of baseIor/topIor, hence we * iorOverBaseLayer to get the baseIor
        real3 baseIor = iorOverBaseLayer * Fresnel0ToIor(baseLayerFresnel0 + 0.0001); // guard against 1.0
        baseLayerFresnel0 = IorToFresnel0(baseIor, eta_2);
    }

    real3 R23 = F_Schlick(baseLayerFresnel0, cosTheta2);
    real  phi23 = 0.0;

    // Phase shift
    real OPD = Dinc * cosTheta2;
    real phi = phi21 + phi23;

    // Compound terms
    real3 R123 = R12 * R23;
    real3 r123 = sqrt(R123);
    real3 Rs = Sq(T121) * R23 / (real3(1.0, 1.0, 1.0) - R123);

    // Reflectance term for m = 0 (DC term amplitude)
    real3 C0 = R12 + Rs;
    real3 I = C0;

    // Reflectance term for m > 0 (pairs of diracs)
    real3 Cm = Rs - T121;
    for (int m = 1; m <= 2; ++m)
    {
        Cm *= r123;
        real3 Sm = 2.0 * EvalSensitivity(m * OPD, m * phi);
        //vec3 SmP = 2.0 * evalSensitivity(m*OPD, m*phi2.y);
        I += Cm * Sm;
    }

    // Convert back to RGB reflectance
    //I = clamp(mul(I, XYZ_TO_RGB), real3(0.0, 0.0, 0.0), real3(1.0, 1.0, 1.0));
    //I = mul(XYZ_TO_RGB, I);

    return I;
}

void EvalOpticalPathDifference(real eta1, real cosTheta1, real cosTheta1Var, real eta2, real layerThickness, out real OPD, out real OPDSigma)
{
    // layerThickness unit is micrometer for this equation here. 0.5 is 500nm.
    real Dinc = layerThickness;

    real sinTheta2Sq = Sq(eta1 / eta2) * (1.0 - Sq(cosTheta1));
    real cosTheta2 = sqrt(1.0 - sinTheta2Sq);
    real cosTheta2Var = cosTheta1Var * Sq( cosTheta1 * Sq(eta1 / eta2) ) / (1 - Sq(eta1 / eta2) * (1 - Sq(cosTheta1))); // cf. EKF

    // Phase shift
    OPD = 2*eta2 * Dinc * cosTheta2;
    OPDSigma = 2*eta2 * Dinc * sqrt(cosTheta2Var);
}

void EvalOpticalPathDifferenceVdotL(real eta1, real VdotL, real VdotLVar, real eta2, real layerThickness, out real OPD, out real OPDSigma)
{
    // layerThickness unit is micrometer for this equation here. 0.5 is 500nm.
    real Dinc = layerThickness;

    real sinTheta2Sq = 0.5 * Sq(eta1 / eta2) * (1.0 - VdotL);
    real cosTheta2 = sqrt(1.0 - sinTheta2Sq);
    real cosTheta2Var = VdotLVar * Sq( 0.25 * Sq(eta1 / eta2) ) / (1 - 0.5 * Sq(eta1 / eta2) * (1 - VdotL)); // cf. EKF

    // Phase shift
    OPD = 2*eta2 * Dinc * cosTheta2;
    OPDSigma = 2*eta2 * Dinc * sqrt(cosTheta2Var);
}

real3 EvalIridescenceCorrectOPD(real eta1, real cosTheta1, real cosTheta1Var, real eta2, real3 eta3, real3 kappa3, real OPD, real OPDSigma)
{
    // Following line from original code is not needed for us, it create a discontinuity
    // Force eta_2 -> eta_1 when Dinc -> 0.0
    // real eta_2 = lerp(eta_1, eta_2, smoothstep(0.0, 0.03, Dinc));
    // Evaluate the cosTheta on the base layer (Snell law)
    real sinTheta2 = Sq(eta1 / eta2) * (1.0 - Sq(cosTheta1));

    // Handle TIR
    if (sinTheta2 > 1.0)
        return real3(1.0, 1.0, 1.0);
    //Or use this "artistic hack" to get more continuity even though wrong (test with dual normal maps to understand the difference)
    //if( sinTheta2 > 1.0 ) { sinTheta2 = 2 - sinTheta2; }

    real cosTheta2 = sqrt(1.0 - sinTheta2);

    // First interface
    real3 R12p, R12s;
    F_FresnelConductor(eta2/eta1, 0, cosTheta1, R12p, R12s);
    real3 T12p = 1.0 - R12p;
    real3 T12s = 1.0 - R12s;

    real phi21p = PI;
    real phi21s = PI;
#ifdef IRIDESCENCE_USE_PHASE_SHIFT
    phi21p *= step(eta1*cosTheta2, eta2*cosTheta1);
    phi21s *= step(eta2*cosTheta2, eta1*cosTheta1);
#endif // IRIDESCENCE_USE_PHASE_SHIFT


    // Second interface
    real3 R23p, R23s;
    F_FresnelConductor(eta3/eta2, kappa3/eta2, cosTheta2, R23p, R23s);

    real3 phi23p = float3(0,0,0);
    real3 phi23s = float3(0,0,0);
#ifdef IRIDESCENCE_USE_PHASE_SHIFT
    FresnelConductorPhase(cosTheta2, eta2, eta3, kappa3, phi23p, phi23s);
#endif // IRIDESCENCE_USE_PHASE_SHIFT


    // Phase
    real3 phi2p = phi21p + phi23p;
    real3 phi2s = phi21s + phi23s;

    // Compound terms
    real3 R123p = R12p * R23p;
    real3 r123p = sqrt(R123p);
    real3 Rstarp = Sq(T12p) * R23p / (real3(1.0, 1.0, 1.0) - R123p);
    real3 R123s = R12s * R23s;
    real3 r123s = sqrt(R123s);
    real3 Rstars = Sq(T12s) * R23s / (real3(1.0, 1.0, 1.0) - R123s);

    // Reflectance term for m = 0 (DC term amplitude)
    real3 C0p = R12p + Rstarp;
    real3 C0s = R12s + Rstars;
    // real3 I = C0p + C0s;
    real3 Ip = C0p;
    real3 Is = C0s;

    // Reflectance term for m > 0 (pairs of diracs)
    real3 Cmp = Rstarp - T12p;
    real3 Cms = Rstars - T12s;
    for (int m = 1; m <= 2; ++m)
    {
        Cmp *= r123p;
        real3 Smp = 2.0 * EvalSensitivityTable(m * OPD, m * phi2p, m * OPDSigma);
        Ip += Cmp * Smp;

        Cms *= r123s;
        real3 Sms = 2.0 * EvalSensitivityTable(m * OPD, m * phi2s, m * OPDSigma);
        Is += Cms * Sms;
    }

    // This helps with black pixels:
    real3 I = max(Is, float3(0,0,0)) + max(Ip, float3(0,0,0));

    // TODO why do some directions return black values here!?
    return 0.5 * I;
}

real3 EvalIridescenceTransmissionCorrectOPD(real eta1, real cosTheta1, real cosTheta1Var, real eta2, real3 eta3, real3 kappa3, real OPD, real OPDSigma)
{
    // Evaluate the cosTheta on the base layer (Snell law)
    real sinTheta2 = Sq(eta1 / eta2) * (1.0 - Sq(cosTheta1));

    // Handle TIR
    if (sinTheta2 > 1.0)
        return real3(1.0, 1.0, 1.0);

    real cosTheta2 = sqrt(1.0 - sinTheta2);

    // First interface
    real3 R12p, R12s;
    F_FresnelConductor(eta2/eta1, 0, cosTheta1, R12p, R12s);
    real3 T12p = 1.0 - R12p;
    real3 T12s = 1.0 - R12s;

    real phi21p = PI;
    real phi21s = PI;
#ifdef IRIDESCENCE_USE_PHASE_SHIFT
    phi21p *= step(eta1*cosTheta2, eta2*cosTheta1);
    phi21s *= step(eta2*cosTheta2, eta1*cosTheta1);
#endif // IRIDESCENCE_USE_PHASE_SHIFT


    // Second interface
    real3 R23p, R23s;
    F_FresnelConductor(eta3/eta2, kappa3/eta2, cosTheta2, R23p, R23s);
    real3 T23p = 1.0 - R23p;
    real3 T23s = 1.0 - R23s;

    real3 phi23p = float3(0,0,0);
    real3 phi23s = float3(0,0,0);
#ifdef IRIDESCENCE_USE_PHASE_SHIFT
    FresnelConductorPhase(cosTheta2, eta2, eta3, kappa3, phi23p, phi23s);
#endif // IRIDESCENCE_USE_PHASE_SHIFT


    // Phase
    real3 phi2p = phi21p + phi23p;
    real3 phi2s = phi21s + phi23s;

    // Compound terms
    real3 R123p = R12p * R23p;
    real3 r123p = sqrt(R123p);
    real3 Tstarp = T12p * T23p / (real3(1.0, 1.0, 1.0) - R123p);
    real3 R123s = R12s * R23s;
    real3 r123s = sqrt(R123s);
    real3 Tstars = T12s * T23s / (real3(1.0, 1.0, 1.0) - R123s);

    // Reflectance term for m = 0 (DC term amplitude)
    real3 C0p = Tstarp;
    real3 C0s = Tstars;
    // real3 I = C0p + C0s;
    real3 Ip = C0p;
    real3 Is = C0s;

    // Reflectance term for m > 0 (pairs of diracs)
    real3 Cmp = C0p;
    real3 Cms = C0s;
    for (int m = 1; m <= 2; ++m)
    {
        Cmp *= r123p;
        real3 Smp = 2.0 * EvalSensitivityTable(m * OPD, m * phi2p, m * OPDSigma);
        Ip += Cmp * Smp;

        Cms *= r123s;
        real3 Sms = 2.0 * EvalSensitivityTable(m * OPD, m * phi2s, m * OPDSigma);
        Is += Cms * Sms;
    }

    // This helps with black pixels:
    real3 I = max(Is, float3(0,0,0)) + max(Ip, float3(0,0,0));

    // TODO why do some directions return black values here!?
    return 0.5 * I;
}

// Evaluate the reflectance for a thin-film layer on top of a conducting medum.
real3 EvalIridescenceCorrect(real eta1, real cosTheta1, real cosTheta1Var, real eta2, real layerThickness, real3 eta3, real3 kappa3, real use_ukf, real ukf_lambda)
{
    // layerThickness unit is micrometer for this equation here. 0.5 is 500nm.
    real Dinc = layerThickness;


    // Following line from original code is not needed for us, it create a discontinuity
    // Force eta_2 -> eta_1 when Dinc -> 0.0
    // real eta_2 = lerp(eta_1, eta_2, smoothstep(0.0, 0.03, Dinc));
    // Evaluate the cosTheta on the base layer (Snell law)
    real sinTheta2sq = Sq(eta1 / eta2) * (1.0 - Sq(cosTheta1));

    // Handle TIR
    if (sinTheta2sq > 1.0)
        return real3(1.0, 1.0, 1.0);
    //Or use this "artistic hack" to get more continuity even though wrong (test with dual normal maps to understand the difference)
    //if( sinTheta2sq > 1.0 ) { sinTheta2sq = 2 - sinTheta2sq; }

    real cosTheta2 = sqrt(1.0 - sinTheta2sq);
    real cosTheta2Var = cosTheta1Var * Sq( cosTheta1 * Sq(eta1 / eta2) ) / (1 - Sq(eta1 / eta2) * (1 - Sq(cosTheta1))); // cf. EKF

    real3 sigmaWeights = real3(0.5, ukf_lambda, 0.5) / (1 + ukf_lambda);
    real3 sigmaPoints = cosTheta1.xxx + sqrt((1 + ukf_lambda) * cosTheta1Var) * real3(-1, 0, 1); // cosTheta1
    real3 sigmaPointsBelow = sqrt(1.0 - Sq(eta1 / eta2) * (1.0 - Sq(sigmaPoints)));

    real cosTheta2UKF = dot(sigmaWeights, sigmaPointsBelow);
    real cosTheta2VarUKF = dot(sigmaWeights, Sq(sigmaPointsBelow - cosTheta2UKF));

    cosTheta2 = lerp(cosTheta2, cosTheta2UKF, use_ukf);
    cosTheta2Var = lerp(cosTheta2Var, cosTheta2VarUKF, use_ukf);

    // First interface
    real3 R12p, R12s;
    F_FresnelConductor(eta2/eta1, 0, cosTheta1, R12p, R12s);
    real3 T12p = 1.0 - R12p;
    real3 T12s = 1.0 - R12s;

    real phi21p = PI;
    real phi21s = PI;
#ifdef IRIDESCENCE_USE_PHASE_SHIFT
    phi21p *= step(eta1*cosTheta2, eta2*cosTheta1);
    phi21s *= step(eta2*cosTheta2, eta1*cosTheta1);
#endif // IRIDESCENCE_USE_PHASE_SHIFT


    // Second interface
    real3 R23p, R23s;
    F_FresnelConductor(eta3/eta2, kappa3/eta2, cosTheta2, R23p, R23s);

    real3 phi23p = float3(0,0,0);
    real3 phi23s = float3(0,0,0);
#ifdef IRIDESCENCE_USE_PHASE_SHIFT
    FresnelConductorPhase(cosTheta2, eta2, eta3, kappa3, phi23p, phi23s);
#endif // IRIDESCENCE_USE_PHASE_SHIFT


    // Phase shift
    real OPD = 2*eta2 * Dinc * cosTheta2;
    real OPDSigma = 2*eta2 * Dinc * sqrt(cosTheta2Var); // cf. Kalman filter
    real3 phi2p = phi21p + phi23p;
    real3 phi2s = phi21s + phi23s;

    // Compound terms
    real3 R123p = R12p * R23p;
    real3 r123p = sqrt(R123p);
    real3 Rstarp = Sq(T12p) * R23p / (real3(1.0, 1.0, 1.0) - R123p);
    real3 R123s = R12s * R23s;
    real3 r123s = sqrt(R123s);
    real3 Rstars = Sq(T12s) * R23s / (real3(1.0, 1.0, 1.0) - R123s);

    // Reflectance term for m = 0 (DC term amplitude)
    real3 C0p = R12p + Rstarp;
    real3 C0s = R12s + Rstars;
    // real3 I = C0p + C0s;
    real3 Ip = C0p;
    real3 Is = C0s;

    // Reflectance term for m > 0 (pairs of diracs)
    real3 Cmp = Rstarp - T12p;
    real3 Cms = Rstars - T12s;
    for (int m = 1; m <= 2; ++m)
    {
        Cmp *= r123p;
        real3 Smp = 2.0 * EvalSensitivityTable(m * OPD, m * phi2p, m * OPDSigma);
        Ip += Cmp * Smp;

        Cms *= r123s;
        real3 Sms = 2.0 * EvalSensitivityTable(m * OPD, m * phi2s, m * OPDSigma);
        Is += Cms * Sms;
    }

    // This helps with black pixels:
    real3 I = max(Is, float3(0,0,0)) + max(Ip, float3(0,0,0));

    return 0.5 * I;
}

//-----------------------------------------------------------------------------
// Fabric
//-----------------------------------------------------------------------------

// Ref: https://knarkowicz.wordpress.com/2018/01/04/cloth-shading/
real D_CharlieNoPI(real NdotH, real roughness)
{
    float invR = rcp(roughness);
    float cos2h = NdotH * NdotH;
    float sin2h = 1.0 - cos2h;
    // Note: We have sin^2 so multiply by 0.5 to cancel it
    return (2.0 + invR) * PositivePow(sin2h, invR * 0.5) / 2.0;
}

real D_Charlie(real NdotH, real roughness)
{
    return INV_PI * D_CharlieNoPI(NdotH, roughness);
}

real CharlieL(real x, real r)
{
    r = saturate(r);
    r = 1.0 - (1.0 - r) * (1.0 - r);

    float a = lerp(25.3245, 21.5473, r);
    float b = lerp(3.32435, 3.82987, r);
    float c = lerp(0.16801, 0.19823, r);
    float d = lerp(-1.27393, -1.97760, r);
    float e = lerp(-4.85967, -4.32054, r);

    return a / (1. + b * PositivePow(x, c)) + d * x + e;
}

// Note: This version don't include the softening of the paper: Production Friendly Microfacet Sheen BRDF
real V_Charlie(real NdotL, real NdotV, real roughness)
{
    real lambdaV = NdotV < 0.5 ? exp(CharlieL(NdotV, roughness)) : exp(2.0 * CharlieL(0.5, roughness) - CharlieL(1.0 - NdotV, roughness));
    real lambdaL = NdotL < 0.5 ? exp(CharlieL(NdotL, roughness)) : exp(2.0 * CharlieL(0.5, roughness) - CharlieL(1.0 - NdotL, roughness));

    return 1.0 / ((1.0 + lambdaV + lambdaL) * (4.0 * NdotV * NdotL));
}

// We use V_Ashikhmin instead of V_Charlie in practice for game due to the cost of V_Charlie
real V_Ashikhmin(real NdotL, real NdotV)
{
    // Use soft visibility term introduce in: Crafting a Next-Gen Material Pipeline for The Order : 1886
    return 1.0 / (4.0 * (NdotL + NdotV - NdotL * NdotV));
}

// A diffuse term use with fabric done by tech artist - empirical
real FabricLambertNoPI(real roughness)
{
    return lerp(1.0, 0.5, roughness);
}

real FabricLambert(real roughness)
{
    return INV_PI * FabricLambertNoPI(roughness);
}

real G_CookTorrance(real NdotH, real NdotV, real NdotL, real HdotV)
{
    return min(1.0, 2.0 * NdotH * min(NdotV, NdotL) / HdotV);
}

#endif // UNITY_BSDF_INCLUDED
