#ifndef IRIDESCENCE_BSDF_INCLUDED
#define IRIDESCENCE_BSDF_INCLUDED

#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/BSDF.hlsl"

TEXTURE2D_ARRAY(_IridescenceFourierTransformedSensitivityMap);
SAMPLER(sampler_IridescenceFourierTransformedSensitivityMap);
real4 _IridescenceFourierTransformedSensitivityMap_ST;

real3 EvalFourierTransformedSensitivityTable(real opd, real3 phi, real opdSigma = 0)
{
    real3 result;
    real2 uv = TRANSFORM_TEX(real2(opd, opdSigma), _IridescenceFourierTransformedSensitivityMap);
    for (int index = 0; index < 3; ++index)
    {
        real2 magsqrt_phase = SAMPLE_TEXTURE2D_ARRAY_LOD(_IridescenceFourierTransformedSensitivityMap, sampler_IridescenceFourierTransformedSensitivityMap, uv, index, 0).rg;
        real mag = Sq(magsqrt_phase.r);
        real phase = magsqrt_phase.g;
        result[index] = mag * cos(phase - phi[index]);
        ///   cos(phase - phi)
        /// = cos(phase) * cos(phi) + sin(phase) * sin(phi)
    }
    return result;
}

real3 EvalFourierTransformedSensitivityGauss(real opd, real3 phi, real opdSigma = 0)
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

real3 EvalFourierTransformedSensitivity(real opd, real3 phi, real opdSigma = 0)
{
    #ifdef IRIDESCENCE_USE_GAUSSIAN_FIT
    return EvalFourierTransformedSensitivityGauss(opd, phi, opdSigma);
    #else
    return EvalFourierTransformedSensitivityTable(opd, phi, opdSigma);
    #endif // IRIDESCENCE_USE_GAUSSIAN_FIT
}


TEXTURE2D(_IridescenceSensitivityMap);
SAMPLER(sampler_IridescenceSensitivityMap);
real4 _IridescenceSensitivityMap_ST;

real3 EvalSensitivityTable(real wavelength)
{
    real2 uv = TRANSFORM_TEX(real2(wavelength, 0), _IridescenceSensitivityMap);
    return SAMPLE_TEXTURE2D_LOD(_IridescenceSensitivityMap, sampler_IridescenceSensitivityMap, uv, 0).rgb;
}


real3 EvalSensitivity(real wavelength)
{
    // TODO use the same units as optical path difference!

    //#ifdef IRIDESCENCE_USE_GAUSSIAN_FIT
    //return EvalSensitivityGauss(opd, phi, opdSigma);
    //#else
    return EvalSensitivityTable(wavelength);
    //#endif // IRIDESCENCE_USE_GAUSSIAN_FIT
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
        real3 Smp = 2.0 * EvalFourierTransformedSensitivity(m * OPD, m * phi2p, m * OPDSigma);
        Ip += Cmp * Smp;

        Cms *= r123s;
        real3 Sms = 2.0 * EvalFourierTransformedSensitivity(m * OPD, m * phi2s, m * OPDSigma);
        Is += Cms * Sms;
    }

    // This helps with black pixels:
    real3 I = max(Is, float3(0,0,0)) + max(Ip, float3(0,0,0));

    return 0.5 * I;
}

real3 EvalIridescenceTransmissionCorrectOPD(real eta1, real cosTheta1, real cosTheta1Var, real eta2, real3 eta3, real3 kappa3, real OPD, real OPDSigma, bool use_phase_shift = true)
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
    if (use_phase_shift)
    {
        phi21p *= step(eta1*cosTheta2, eta2*cosTheta1);
        phi21s *= step(eta2*cosTheta2, eta1*cosTheta1);
    }


    // Second interface
    real3 R23p, R23s;
    F_FresnelConductor(eta3/eta2, kappa3/eta2, cosTheta2, R23p, R23s);
    real3 T23p = 1.0 - R23p;
    real3 T23s = 1.0 - R23s;

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
    for (int m = 1; m <= _IridescenceTerms /*2*/; ++m)
    {
        Cmp *= r123p;
        real3 Smp = 2.0 * EvalFourierTransformedSensitivity(m * OPD, m * phi2p, m * OPDSigma);
        Ip += Cmp * Smp;

        Cms *= r123s;
        real3 Sms = 2.0 * EvalFourierTransformedSensitivity(m * OPD, m * phi2s, m * OPDSigma);
        Is += Cms * Sms;
    }

    // This helps with black pixels:
    real3 I = max(Is, float3(0,0,0)) + max(Ip, float3(0,0,0));

    // TODO why do some directions return black values here!?
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
        real3 Smp = 2.0 * EvalFourierTransformedSensitivity(m * OPD, m * phi2p, m * OPDSigma);
        Ip += Cmp * Smp;

        Cms *= r123s;
        real3 Sms = 2.0 * EvalFourierTransformedSensitivity(m * OPD, m * phi2s, m * OPDSigma);
        Is += Cms * Sms;
    }

    // This helps with black pixels:
    real3 I = max(Is, float3(0,0,0)) + max(Ip, float3(0,0,0));

    return 0.5 * I;
}


real4 _IridescenceWavelengthMinMaxSampleCount; // min, max, sampleCount, 1/sampleCount

real4 jonesMul(real4 J1, real4 J2)
{
    // J = real4(re(s), im(s), re(p), im(p))

    real4 Jres;
    Jres.xz = J1.xz * J2.xz - J1.yw * J2.yw;
    Jres.yw = J1.xz * J2.yw + J1.yw * J2.xz;

    return Jres;
}

real4 jonesDiv(real4 J1, real4 J2)
{
    // J = real4(re(s), im(s), re(p), im(p))

    real4 Jres = jonesMul(J1, real4(1, -1, 1, -1) * J2);
    Jres /= real2(dot(J2.xy, J2.xy), dot(J2.zw, J2.zw)).xxyy;

    return Jres;
}

real2 complexMul(real2 C1, real2 C2)
{
    real2 Cres;
    Cres.x = C1.x * C2.x - C1.y * C2.y;
    Cres.y = C1.x * C2.y + C1.y * C2.x;

    return Cres;
}

real2 complexDiv(real2 C1, real2 C2)
{
    real2 Cres = complexMul(C1, real2(1, -1) * C2);
    Cres /= dot(C2.xy, C2.xy);

    return Cres;
}

real2 complexSqrt(real2 C)
{
    // TODO
}

void fresnelCoefficientsDielectric(real cosTheta1, real eta2, out real rs, out real rp, out real ts, out real tp)
{
    // return: real4(re(rs), im(rs), re(rp), im(rp))

    // real2 n2 = real2(eta2, kappa2);

    real sinTheta1Sq = 1 - Sq(cosTheta1);
    real sinTheta2Sq = sinTheta1Sq / Sq(eta2);
    real cosTheta2 = sqrt(1 - sinTheta2Sq);

    // rs = (cos1 - n2 cos2) / (cos1 + n2 cos2)
    // rp = (n2 cos1 - cos2) / (n2 cos1 + cos2)

    real rsnum = cosTheta1 - eta2 * cosTheta2;
    real rsden = cosTheta1 + eta2 * cosTheta2;

    real rpnum = eta2 * cosTheta1 - cosTheta2;
    real rpden = eta2 * cosTheta1 + cosTheta2;

    rs = rsnum / rsden;
    rp = rpnum / rpden;

    ts = 2 * cosTheta1 / rsden;
    tp = 2 * cosTheta1 / rpden;
}

real3 EvalIridescenceSpectralOPD(real eta1, real cosTheta1, real eta2, real eta3, real kappa3, real OPD, int thin_film_bounces)
{
    real minWavelength = _IridescenceWavelengthMinMaxSampleCount.x;
    real maxWavelength = _IridescenceWavelengthMinMaxSampleCount.y;
    int sampleCount = _IridescenceWavelengthMinMaxSampleCount.z;

    real dx = 1.0 / (sampleCount-1);

    real sinTheta1Sq = 1 - Sq(cosTheta1);
    real cosTheta2 = sqrt(1 - Sq(eta1/eta2) * sinTheta1Sq);

    // TODO Thin-film reflection coefficients and phase shifts!

    real r12s;
    real r12p;
    real t12s;
    real t12p;
    fresnelCoefficientsDielectric(cosTheta1, eta2/eta1, r12s, r12p, t12s, t12p);

    real r21s;
    real r21p;
    real t21s;
    real t21p;
    fresnelCoefficientsDielectric(cosTheta2, eta1/eta2, r21s, r21p, t21s, t21p);

    // assume n3 = n1!
    real r23s = r21s;
    real r23p = r21p;
    real t23s = t21s;
    real t23p = t21p;


    real4 Jr23 = real4(r23s, 0, r23p, 0);
    real4 Jr23r21 = Jr23 * real2(r21s, r21p).xxyy; // jonesMul(Jr23, real4(r21s, 0, r21p, 0)); // jones vector that is applied to get the next higher order path! (without phase shift)
    real4 Jt12r23t21 = Jr23 * real2(t12s * t21s, t12p * t21p).xxyy;

    // TODO first contribute wave amplitudes without phase shift for first N paths
    // Then phase-shift them and perform spactral integration

    real3 Ip = 0;
    real3 Is = 0;

    for (int i = 0; i < sampleCount; ++i)
    {
        // TODO verify that use of dx is correct!
        real wavelength = lerp(minWavelength, maxWavelength, i * dx);
        real3 sensitivity = EvalSensitivity(wavelength); // * dx

        // Compute reflection and transmission for each encounter for the current wavelength!

        real phaseShift = 2*PI * OPD / wavelength;
        real cosPhaseShift, sinPhaseShift;
        sincos(phaseShift, sinPhaseShift, cosPhaseShift);
        // same phase shift for s- and p-polarization
        real4 JphaseShift = real4(cosPhaseShift, sinPhaseShift, cosPhaseShift, sinPhaseShift);

        real4 Jrefl = real4(r12s, 0, r12p, 0);
        real4 Jtrans = real4(0, 0, 0, 0);

        real4 JpathR = jonesMul(Jt12r23t21, JphaseShift); // for reflection
        real4 JpathT = real4(t12s*t21s, 0 , t12p*t21p, 0); // for transmission, ignore phase shift of 0-th order path
        real4 JincPath = jonesMul(Jr23r21, JphaseShift); // for reflection + transmission
        for (int k = 0; k < thin_film_bounces; ++k)
        {
            Jrefl += JpathR;
            Jtrans += JpathT;
            JpathR *= JincPath;
            JpathT *= JincPath;
        }

        real2 rs = Jrefl.xy;
        real2 rp = Jrefl.zw;

        real2 ts = Jtrans.xy;
        real2 tp = Jtrans.zw;

        real Rs = dot(rs, rs);
        real Rp = dot(rp, rp);

        real Ts = dot(ts, ts);
        real Tp = dot(tp, tp);

        Is += sensitivity * Rs;
        Ip += sensitivity * Rp;
    }

    // This helps with black pixels:
    return 0.5 * max(Is.rgb, float3(0,0,0)) + max(Ip.rgb, float3(0,0,0));
}


struct IridescenceData
{
    // NOTE: real C0 = 1 + C0 for reflection!
    // M=3
    float3 reflectionC0p;
    float3 reflectionC0s;

    float3 transmissionC0p;
    float3 transmissionC0s;

    float3 nextCmFactors;
    float3 nextCmFactorp;

    float3 phi2p;
    float3 phi2s;
};

IridescenceData EvalIridescenceCoefficientsOnly(real eta1, real cosTheta1, real cosTheta1Var, real eta2, real3 eta3, real3 kappa3, bool use_phase_shift = true, bool use_ukf = false, real ukf_lambda = 1.0)
{
    IridescenceData result;

    // Following line from original code is not needed for us, it create a discontinuity
    // Force eta_2 -> eta_1 when Dinc -> 0.0
    // real eta_2 = lerp(eta_1, eta_2, smoothstep(0.0, 0.03, Dinc));
    // Evaluate the cosTheta on the base layer (Snell law)
    real sinTheta2sq = Sq(eta1 / eta2) * (1.0 - Sq(cosTheta1));

    // Handle TIR
    // if (sinTheta2sq > 1.0)
    // {
    //     // TODO everything is reflected!
    //     return result;
    // }

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
    real3 T23p = 1.0 - R23p;
    real3 T23s = 1.0 - R23s;

    real3 phi23p = float3(0,0,0);
    real3 phi23s = float3(0,0,0);
    if (use_phase_shift)
    {
        FresnelConductorPhase(cosTheta2, eta2, eta3, kappa3, phi23p, phi23s);
    }


    // Compound terms
    real3 R123p = R12p * R23p;
    real3 r123p = sqrt(R123p);
    real3 Rstarp = Sq(T12p) * R23p / (real3(1.0, 1.0, 1.0) - R123p);
    real3 Tstarp = T12p * T23p / (real3(1.0, 1.0, 1.0) - R123p);
    real3 R123s = R12s * R23s;
    real3 r123s = sqrt(R123s);
    real3 Rstars = Sq(T12s) * R23s / (real3(1.0, 1.0, 1.0) - R123s);
    real3 Tstars = T12s * T23s / (real3(1.0, 1.0, 1.0) - R123s);


    // Coefficients
    result.reflectionC0p = Rstarp - T12p;
    result.reflectionC0s = Rstars - T12s;

    result.transmissionC0p = Tstarp;
    result.transmissionC0s = Tstars;

    result.nextCmFactorp = r123p;
    result.nextCmFactors = r123s;

    // Phase shift
    result.phi2p = phi21p + phi23p;
    result.phi2s = phi21s + phi23s;

    return result;
}

#ifndef SPHERE_MODEL_BOUNCES
    // Work around compiler errors in shaders that don't use sphere model anyways...
    #define SPHERE_MODEL_BOUNCES 4
#endif // SPHERE_MODEL_BOUNCES

void EvalIridescenceSphereModel(real eta1, real cosTheta1, real eta2, real3 eta3, real3 kappa3, real OPD[SPHERE_MODEL_BOUNCES], out real3 result[SPHERE_MODEL_BOUNCES], bool intermediate_rgb, bool use_phase_shift = true, bool use_ukf = false, real ukf_lambda = 1.0)
{
    IridescenceData iridescenceData = EvalIridescenceCoefficientsOnly(eta1, cosTheta1, 0, eta2, eta3, kappa3, use_phase_shift, use_ukf, ukf_lambda);
    // Assume constant optical path difference for now!

    int M = _IridescenceTerms;
    const int N = SPHERE_MODEL_BOUNCES;

    real3 Is[N];
    real3 Ip[N];

    if (intermediate_rgb)
    {
        // Compute reflectance and transmittance at each film interface

        float3 Rs[N];
        float3 Rp[N];
        float3 Ts[N];
        float3 Tp[N];

        // C0's
        for (int j = 0; j < N; ++j)
        {
            Rs[j] = iridescenceData.reflectionC0s + 1;
            Rp[j] = iridescenceData.reflectionC0p + 1;

            Ts[j] = iridescenceData.transmissionC0s;
            Tp[j] = iridescenceData.transmissionC0p;
        }

        // Reflectance term for m > 0 (pairs of diracs)
        float3 reflectionCmp = iridescenceData.reflectionC0p;
        float3 reflectionCms = iridescenceData.reflectionC0s;
        float3 transmissionCmp = iridescenceData.transmissionC0p;
        float3 transmissionCms = iridescenceData.transmissionC0s;
        for (int m = 1; m <= M; ++m)
        {
            reflectionCmp *= iridescenceData.nextCmFactorp;
            reflectionCms *= iridescenceData.nextCmFactors;
            transmissionCmp *= iridescenceData.nextCmFactorp;
            transmissionCms *= iridescenceData.nextCmFactors;

            for (int j = 0; j < N; ++j)
            {
                real3 Smp = 2.0 * EvalFourierTransformedSensitivity(m * OPD[j], m * iridescenceData.phi2p, 0);
                Rp[j] += reflectionCmp * Smp;
                Tp[j] += transmissionCmp * Smp;

                real3 Sms = 2.0 * EvalFourierTransformedSensitivity(m * OPD[j], m * iridescenceData.phi2s, 0);
                Rs[j] += reflectionCms * Sms;
                Ts[j] += transmissionCms * Sms;
            }
        }

        Is[0] = Rs[0];
        Ip[0] = Rp[0];

        for (int i = 1; i < N; ++i)
        {
            real3 Rs_local = 1;
            real3 Rp_local = 1;
            for (int j = 1; j < i; ++j)
            {
                Rs_local *= Rs[j];
                Rp_local *= Rp[j];
            }
            Is[i] = Ts[0] * Rs_local * Ts[i];
            Ip[i] = Tp[0] * Rp_local * Tp[i];
        }

    }
    else // intermediate_rgb
    {

        // Prepare single bounce data (at each bounce)
        // NOTE: No C0 here!!!
        float3 reflectionCmSmp[N];
        float3 reflectionCmSms[N];
        float3 transmissionCmSmp[N];
        float3 transmissionCmSms[N];

        for (int j = 0; j < N; ++j)
        {
            reflectionCmSmp[j] = 0; // iridescenceData.reflectionC0p + 1; // NOTE that we have to add 1 here
            reflectionCmSms[j] = 0; // iridescenceData.reflectionC0s + 1; // NOTE that we have to add 1 here
            transmissionCmSmp[j] = 0; // iridescenceData.transmissionC0p;
            transmissionCmSms[j] = 0; // iridescenceData.transmissionC0s;
        }

        float3 reflectionCmp = iridescenceData.reflectionC0p;
        float3 reflectionCms = iridescenceData.reflectionC0s;
        float3 transmissionCmp = iridescenceData.transmissionC0p;
        float3 transmissionCms = iridescenceData.transmissionC0s;
        for (int m = 1; m <= M; ++m)
        {
            reflectionCmp *= iridescenceData.nextCmFactorp;
            reflectionCms *= iridescenceData.nextCmFactors;
            transmissionCmp *= iridescenceData.nextCmFactorp;
            transmissionCms *= iridescenceData.nextCmFactors;

            for (int j = 0; j < N; ++j)
            {
                real3 Smp = 2.0 * EvalFourierTransformedSensitivity(m * OPD[j], m * iridescenceData.phi2p, 0);
                reflectionCmSmp[j] += reflectionCmp * Smp;
                transmissionCmSmp[j] += transmissionCmp * Smp;

                real3 Sms = 2.0 * EvalFourierTransformedSensitivity(m * OPD[j], m * iridescenceData.phi2s, 0);
                reflectionCmSms[j] += reflectionCms * Sms;
                transmissionCmSms[j] += transmissionCms * Sms;
            }
        }

        real3 C0p[N]; // product of C0's accumulated so far for each light path
        real3 C0s[N]; // product of C0's accumulated so far for each light path
        // real3 I[N]; // result


        // 0'th reflection
        Ip[0] = iridescenceData.reflectionC0p + 1 + reflectionCmSmp[0];
        Is[0] = iridescenceData.reflectionC0s + 1 + reflectionCmSms[0];

        // (Cache) 0'th transmission
        for (int i = 1; i < N; ++i)
        {
            Ip[i] = iridescenceData.transmissionC0p + transmissionCmSmp[0];
            Is[i] = iridescenceData.transmissionC0s + transmissionCmSms[0];
            C0p[i] = iridescenceData.transmissionC0p;
            C0s[i] = iridescenceData.transmissionC0s;
        }


        for (int j = 1; j < N; ++j)
        {
            // (j'st) reflection (and transmission)

            // Finalize path with last transmission
            Ip[j] *= iridescenceData.transmissionC0p;
            Is[j] *= iridescenceData.transmissionC0s;
            // TODO fix this: C0 * C0 is counted twice this way!
            Ip[j] += C0p[j] * transmissionCmSmp[j];
            Is[j] += C0s[j] * transmissionCmSms[j];

            // Add reflection to higher order path
            // TODO only update next path here, and reuse it for next `j`!
            for (int i = j+1; i < N; ++i)
            {
                // Add attenuated version of "current" bounce
                Ip[i] *= iridescenceData.reflectionC0p + 1;
                Is[i] *= iridescenceData.reflectionC0s + 1;

                // TODO fix this: C0 * C0 is counted twice this way!
                Ip[i] += C0p[i] * reflectionCmSmp[j];
                Is[i] += C0s[i] * reflectionCmSms[j];

                C0p[i] *= iridescenceData.reflectionC0p + 1;
                C0s[i] *= iridescenceData.reflectionC0s + 1;
            }
        }

    }

    for (int j = 0; j < N; ++j)
    {
        // This helps with black pixels:
        result[j] = 0.5 * max(Is[j].rgb, float3(0,0,0)) + max(Ip[j].rgb, float3(0,0,0));
    }
}


void EvalIridescenceSpectralSphereModel(real eta1, real cosTheta1, real eta2, real OPD[SPHERE_MODEL_BOUNCES], out real3 result[SPHERE_MODEL_BOUNCES], int thin_film_bounces, bool intermediate_rgb = false)
{
    real minWavelength = _IridescenceWavelengthMinMaxSampleCount.x;
    real maxWavelength = _IridescenceWavelengthMinMaxSampleCount.y;
    int sampleCount = _IridescenceWavelengthMinMaxSampleCount.z;

    const int N = SPHERE_MODEL_BOUNCES;

    real dx = 1.0 / (sampleCount-1);

    real sinTheta1Sq = 1 - Sq(cosTheta1);
    real cosTheta2 = sqrt(1 - Sq(eta1/eta2) * sinTheta1Sq);

    // TODO Thin-film reflection coefficients and phase shifts!

    real r12s;
    real r12p;
    real t12s;
    real t12p;
    fresnelCoefficientsDielectric(cosTheta1, eta2/eta1, r12s, r12p, t12s, t12p);

    real r21s;
    real r21p;
    real t21s;
    real t21p;
    fresnelCoefficientsDielectric(cosTheta2, eta1/eta2, r21s, r21p, t21s, t21p);

    // assume n3 = n1!
    real r23s = r21s;
    real r23p = r21p;
    real t23s = t21s;
    real t23p = t21p;


    real4 Jr23 = real4(r23s, 0, r23p, 0);
    real4 Jr23r21 = Jr23 * real2(r21s, r21p).xxyy; // jonesMul(Jr23, real4(r21s, 0, r21p, 0)); // jones vector that is applied to get the next higher order path! (without phase shift)
    real4 Jt12r23t21 = Jr23 * real2(t12s * t21s, t12p * t21p).xxyy;

    // TODO first contribute wave amplitudes without phase shift for first N paths
    // Then phase-shift them and perform spactral integration

    real3 Ip[N];
    real3 Is[N];

    real3 Rs_rgb[N];
    real3 Rp_rgb[N];
    real3 Ts_rgb[N];
    real3 Tp_rgb[N];

    for (int j = 0; j < N; ++j)
    {
        Ip[j] = 0;
        Is[j] = 0;

        Rs_rgb[j] = 0;
        Rp_rgb[j] = 0;
        Ts_rgb[j] = 0;
        Tp_rgb[j] = 0;
    }

    for (int i = 0; i < sampleCount; ++i)
    {
        // TODO verify that use of dx is correct!
        real wavelength = lerp(minWavelength, maxWavelength, i * dx);
        real3 sensitivity = EvalSensitivity(wavelength); // * dx

        // Compute reflection and transmission for each encounter for the current wavelength!

        real Rs[N];
        real Rp[N];
        real Ts[N];
        real Tp[N];

        // j'th interaction...
        for (int j = 0; j < N; ++j)
        {
            real phaseShift = 2*PI * OPD[j] / wavelength;
            real cosPhaseShift, sinPhaseShift;
            sincos(phaseShift, sinPhaseShift, cosPhaseShift);
            // same phase shift for s- and p-polarization
            real4 JphaseShift = real4(cosPhaseShift, sinPhaseShift, cosPhaseShift, sinPhaseShift);

            real4 Jrefl = real4(r12s, 0, r12p, 0);
            real4 Jtrans = real4(0, 0, 0, 0);

            real4 JpathR = jonesMul(Jt12r23t21, JphaseShift); // for reflection
            real4 JpathT = real4(t12s*t21s, 0 , t12p*t21p, 0); // for transmission, ignore phase shift of 0-th order path
            real4 JincPath = jonesMul(Jr23r21, JphaseShift); // for reflection + transmission

            if (thin_film_bounces < 0)
            {
                // Airy summation
                Jrefl += jonesDiv(JpathR, real2(1, 0).xyxy - JincPath);
                Jtrans += jonesDiv(JpathT, real2(1, 0).xyxy - JincPath);
            }
            else
            {
                for (int k = 0; k < thin_film_bounces; ++k)
                {
                    Jrefl += JpathR;
                    Jtrans += JpathT;
                    JpathR *= JincPath;
                    JpathT *= JincPath;
                }
            }

            real2 rs = Jrefl.xy;
            real2 rp = Jrefl.zw;

            real2 ts = Jtrans.xy;
            real2 tp = Jtrans.zw;

            Rs[j] = dot(rs, rs);
            Rp[j] = dot(rp, rp);

            Ts[j] = dot(ts, ts);
            Tp[j] = dot(tp, tp);

            if (intermediate_rgb)
            {
                Rs_rgb[j] += sensitivity * Rs[j];
                Rp_rgb[j] += sensitivity * Rp[j];
                Ts_rgb[j] += sensitivity * Ts[j];
                Tp_rgb[j] += sensitivity * Tp[j];
            }
        }

        if (!intermediate_rgb)
        {
            Is[0] += sensitivity * Rs[0];
            Ip[0] += sensitivity * Rp[0];

            for (j = 1; j < N; ++j)
            {
                real Rs_intermediate = 1;
                real Rp_intermediate = 1;
                for (int k = 1; k < j; ++k)
                {
                    Rs_intermediate *= Rs[k];
                    Rp_intermediate *= Rp[k];
                }
                Is[j] += sensitivity * Ts[0] * Rs_intermediate * Ts[j];
                Ip[j] += sensitivity * Tp[0] * Rp_intermediate * Tp[j];
            }
        }
    }

    if (intermediate_rgb)
    {
        // Surprisingly does not introduce much of an error...
        Is[0] = Rs_rgb[0];
        Ip[0] = Rp_rgb[0];

        for (j = 1; j < N; ++j)
        {
            real3 Rs_rgb_intermediate = 1;
            real3 Rp_rgb_intermediate = 1;
            for (int k = 1; k < j; ++k)
            {
                Rs_rgb_intermediate *= Rs_rgb[k];
                Rp_rgb_intermediate *= Rp_rgb[k];
            }
            Is[j] += Ts_rgb[0] * Rs_rgb_intermediate * Ts_rgb[j];
            Ip[j] += Tp_rgb[0] * Rp_rgb_intermediate * Tp_rgb[j];
        }
    }

    for (int j = 0; j < N; ++j)
    {
        // This helps with black pixels:
        result[j] = 0.5 * max(Is[j].rgb, float3(0,0,0)) + max(Ip[j].rgb, float3(0,0,0));
    }

    /*
    if (intermediate_rgb)
    {
        // Pretend to clip intermediate RGB colors to sRGB color gamut and discard polarization...
        real3 R_rgb[N];
        real3 T_rgb[N];

        for (int j = 0; j < N; ++j)
        {
            R_rgb[j] = 0.5 * max(Rs_rgb[j], float3(0,0,0)) + max(Rp_rgb[j], float3(0,0,0));
            T_rgb[j] = 0.5 * max(Ts_rgb[j], float3(0,0,0)) + max(Tp_rgb[j], float3(0,0,0));
        }

        result[0] = R_rgb[0];

        for (j = 1; j < N; ++j)
        {
            real3 R_rgb_intermediate = 1;
            for (int k = 1; k < j; ++k)
            {
                R_rgb_intermediate *= R_rgb[k];
            }
            result[j] += T_rgb[0] * R_rgb_intermediate * T_rgb[j];
        }
    }
    */
}


#endif // IRIDESCENCE_BSDF_INCLUDED
