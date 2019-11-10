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

#endif // IRIDESCENCE_BSDF_INCLUDED
