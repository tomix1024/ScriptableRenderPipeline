#ifndef IRIDESCENCE_BSDF_INCLUDED
#define IRIDESCENCE_BSDF_INCLUDED

#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/BSDF.hlsl"

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

real3 EvalSensitivityGauss(real opd, real3 phi, real opdSigma = 0)
{
    real opdVar = Sq(opdSigma);

    // Use Gaussian fits, given by 3 parameters: val, pos and var
    // xyzx (x twice!)
    real4 pos = real4(1.6810, 1.7953, 2.2084, 2.2399);
    real4 var = real4(4.3278e-03, 9.3046e-03, 6.6121e-03, 4.5282e-03) * 2;
    real4 val = real4(5.4856e-7, 4.4201e-7, 5.2481e-7, 9.7470e-8) * sqrt(PI * var);

    real4 atten = 1.0 + 4.0 * Sq(PI) * opdVar * var;

    // TODO phi is for RGB, not XYZ!!

    // phase from gaussian is negative, therefore add phi... cos(phase - phi)
    real4 xyzx = val / sqrt(atten) * cos(2.0 * PI * pos * opd / atten + phi.xxxx) * exp(-2.0 * Sq(PI) * var * Sq(opd) / atten) * exp(-0.5 * Sq(pos) / var * (atten - 1) / atten);

    real3 xyz = xyzx.xyz;
    xyz.x += xyzx.w;
    xyz /= 1.0685e-7;

    real3x3 XYZ2SRGB = real3x3(
         3.2406, -1.5372, -0.4986,
        -0.9489,  1.8758,  0.0415,
         0.0557, -0.2040,  1.0570
    );
    // normalize each color band individually, assume xyz is normalized!
    // WHY DOES THE UNNORMALIZED MATRIX YIELD THE RESULT WE EXPECT FROM THE NORMALIZED ONE?!
    //XYZ2SRGB[0] = normalize(XYZ2SRGB[0]);
    //XYZ2SRGB[1] = normalize(XYZ2SRGB[1]);
    //XYZ2SRGB[2] = normalize(XYZ2SRGB[2]);

    real3 rgb = mul(XYZ2SRGB, xyz);
    return rgb;
}

real3 EvalSensitivity(real opd, real3 phi, real opdSigma = 0)
{
    #ifdef IRIDESCENCE_USE_GAUSSIAN_FIT
    return EvalSensitivityGauss(opd, phi, opdSigma);
    #else
    return EvalSensitivityTable(opd, phi, opdSigma);
    #endif // IRIDESCENCE_USE_GAUSSIAN_FIT
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

real3 EvalIridescenceCorrectOPD(real eta1, real cosTheta1, real cosTheta1Var, real eta2, real3 eta3, real3 kappa3, real OPD, real OPDSigma, bool use_phase_shift = true)
{
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
    if (use_phase_shift)
    {
        phi21p *= step(eta1*cosTheta2, eta2*cosTheta1);
        phi21s *= step(eta2*cosTheta2, eta1*cosTheta1);
    }


    // Second interface
    real3 R23p, R23s;
    F_FresnelConductor(eta3/eta2, kappa3/eta2, cosTheta2, R23p, R23s);

    real3 phi23p = float3(0,0,0);
    real3 phi23s = float3(0,0,0);
    if (use_phase_shift)
    {
        FresnelConductorPhase(cosTheta2, eta2, eta3, kappa3, phi23p, phi23s);
    }


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
    for (int m = 1; m <= _IridescenceTerms /*2*/; ++m)
    {
        Cmp *= r123p;
        real3 Smp = 2.0 * EvalSensitivity(m * OPD, m * phi2p, m * OPDSigma);
        Ip += Cmp * Smp;

        Cms *= r123s;
        real3 Sms = 2.0 * EvalSensitivity(m * OPD, m * phi2s, m * OPDSigma);
        Is += Cms * Sms;
    }

    // This helps with black pixels:
    real3 I = max(Is, float3(0,0,0)) + max(Ip, float3(0,0,0));

    return 0.5 * I;
}

// Evaluate the reflectance for a thin-film layer on top of a conducting medum.
real3 EvalIridescenceCorrect(real eta1, real cosTheta1, real cosTheta1Var, real eta2, real layerThickness, real3 eta3, real3 kappa3, bool use_phase_shift = true, bool use_ukf = false, real ukf_lambda = 1.0)
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

    if (use_ukf)
    {
        real3 sigmaWeights = real3(0.5, ukf_lambda, 0.5) / (1 + ukf_lambda);
        real3 sigmaPoints = cosTheta1.xxx + sqrt((1 + ukf_lambda) * cosTheta1Var) * real3(-1, 0, 1); // cosTheta1
        real3 sigmaPointsBelow = sqrt(1.0 - Sq(eta1 / eta2) * (1.0 - Sq(sigmaPoints)));

        cosTheta2 = dot(sigmaWeights, sigmaPointsBelow);
        cosTheta2Var = dot(sigmaWeights, Sq(sigmaPointsBelow - cosTheta2));
    }

    // First interface
    real3 R12p, R12s;
    F_FresnelConductor(eta2/eta1, 0, cosTheta1, R12p, R12s);
    real3 T12p = 1.0 - R12p;
    real3 T12s = 1.0 - R12s;

    real phi21p = PI;
    real phi21s = PI;
    if (use_phase_shift)
    {
        phi21p *= step(eta1*cosTheta2, eta2*cosTheta1);
        phi21s *= step(eta2*cosTheta2, eta1*cosTheta1);
    }


    // Second interface
    real3 R23p, R23s;
    F_FresnelConductor(eta3/eta2, kappa3/eta2, cosTheta2, R23p, R23s);

    real3 phi23p = float3(0,0,0);
    real3 phi23s = float3(0,0,0);
    if (use_phase_shift)
    {
        FresnelConductorPhase(cosTheta2, eta2, eta3, kappa3, phi23p, phi23s);
    }


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
    for (int m = 1; m <= _IridescenceTerms /*2*/; ++m)
    {
        Cmp *= r123p;
        real3 Smp = 2.0 * EvalSensitivity(m * OPD, m * phi2p, m * OPDSigma);
        Ip += Cmp * Smp;

        Cms *= r123s;
        real3 Sms = 2.0 * EvalSensitivity(m * OPD, m * phi2s, m * OPDSigma);
        Is += Cms * Sms;
    }

    // This helps with black pixels:
    real3 I = max(Is, float3(0,0,0)) + max(Ip, float3(0,0,0));

    return 0.5 * I;
}

#endif // IRIDESCENCE_BSDF_INCLUDED
