using System;
using UnityEngine.Rendering;
using System.IO;
using System.Collections.Generic;

namespace UnityEngine.Rendering.HighDefinition
{
    public class LoadFourierTransformedSpectralSensitivity
    {
        static LoadFourierTransformedSpectralSensitivity s_Instance;

        public static LoadFourierTransformedSpectralSensitivity instance
        {
            get
            {
                if (s_Instance == null)
                    s_Instance = new LoadFourierTransformedSpectralSensitivity();

                return s_Instance;
            }
        }

        int m_refCounting = 0;

        Texture2DArray m_FourierTransformedSpectralSensitivity;
        Vector4 m_FourierTransformedSpectralSensitivity_ST;

        LoadFourierTransformedSpectralSensitivity() {}


        private void LoadFourierTransformedData(out Texture2DArray texture, out float muOffset, out float muScale, out float sigmaOffset, out float sigmaScale)
        {
            int numMu = FourierTransformedSpectralSensitivityDataSRGB.numMu;
            int numSigma = FourierTransformedSpectralSensitivityDataSRGB.numSigma;
            float maxMu = FourierTransformedSpectralSensitivityDataSRGB.maxMu;
            float maxSigma = FourierTransformedSpectralSensitivityDataSRGB.maxSigma;

            float[] Rmag = FourierTransformedSpectralSensitivityDataSRGB.Rmag;
            float[] Rphi = FourierTransformedSpectralSensitivityDataSRGB.Rphi;
            float[] Gmag = FourierTransformedSpectralSensitivityDataSRGB.Gmag;
            float[] Gphi = FourierTransformedSpectralSensitivityDataSRGB.Gphi;
            float[] Bmag = FourierTransformedSpectralSensitivityDataSRGB.Bmag;
            float[] Bphi = FourierTransformedSpectralSensitivityDataSRGB.Bphi;

            texture = new Texture2DArray(numMu, numSigma, 3, TextureFormat.RGFloat, mipChain: false, linear: true);

            var colors = new Color[numMu * numSigma];
            for (int i = 0; i < colors.Length; ++i)
            {
                colors[i].r = Rmag[i];
                colors[i].g = Rphi[i];
            }
            texture.SetPixels(colors, 0);

            for (int i = 0; i < colors.Length; ++i)
            {
                colors[i].r = Gmag[i];
                colors[i].g = Gphi[i];
            }
            texture.SetPixels(colors, 1);

            for (int i = 0; i < colors.Length; ++i)
            {
                colors[i].r = Bmag[i];
                colors[i].g = Bphi[i];
            }
            texture.SetPixels(colors, 2);

            texture.Apply();
            texture.filterMode = FilterMode.Bilinear;
            texture.wrapMode = TextureWrapMode.Clamp;

            // 0   -> 0.5f / size       => offset = 0.5f / size
            // max -> 1 - 0.5f / size   => scale  = (1 - 0.5f / size - offset) / max

            muOffset = 0.5f / numMu;
            muScale = (1.0f - 1.0f / numMu) / maxMu;

            sigmaOffset = 0.5f / numSigma;
            sigmaScale = (1.0f - 1.0f / numSigma) / maxSigma;
        }

        public void Build()
        {
            Debug.Assert(m_refCounting >= 0);

            if (m_refCounting == 0)
            {
                float muOffset, muScale;
                float sigmaOffset, sigmaScale;
                LoadFourierTransformedData(out m_FourierTransformedSpectralSensitivity, out muOffset, out muScale, out sigmaOffset, out sigmaScale);
                m_FourierTransformedSpectralSensitivity_ST = new Vector4(muScale, sigmaScale, muOffset, sigmaOffset);
            }

            m_refCounting++;
        }

        public void RenderInit(CommandBuffer cmd)
        {
            // Data is already loaded!
            // But sometimes it disappears...
            if (m_FourierTransformedSpectralSensitivity == null)
            {
                float muOffset, muScale;
                float sigmaOffset, sigmaScale;
                LoadFourierTransformedData(out m_FourierTransformedSpectralSensitivity, out muOffset, out muScale, out sigmaOffset, out sigmaScale);
                m_FourierTransformedSpectralSensitivity_ST = new Vector4(muScale, sigmaScale, muOffset, sigmaOffset);
            }
        }

        public void Cleanup()
        {
            m_refCounting--;

            if (m_refCounting == 0)
            {
                CoreUtils.Destroy(m_FourierTransformedSpectralSensitivity);
                m_FourierTransformedSpectralSensitivity = null;
            }

            Debug.Assert(m_refCounting >= 0);
        }

        public void Bind(CommandBuffer cmd)
        {
            // TODO HDShaderIDs!
            cmd.SetGlobalTexture("_IridescenceFourierTransformedSensitivityMap", m_FourierTransformedSpectralSensitivity);
            cmd.SetGlobalVector("_IridescenceFourierTransformedSensitivityMap_ST", m_FourierTransformedSpectralSensitivity_ST);
        }
    }
}
