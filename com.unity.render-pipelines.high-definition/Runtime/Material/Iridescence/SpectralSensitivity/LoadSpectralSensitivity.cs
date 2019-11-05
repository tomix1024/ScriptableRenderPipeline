using System;
using UnityEngine.Rendering;
using System.IO;
using System.Collections.Generic;

namespace UnityEngine.Rendering.HighDefinition
{
    public class LoadSpectralSensitivity
    {
        static LoadSpectralSensitivity s_Instance;

        public static LoadSpectralSensitivity instance
        {
            get
            {
                if (s_Instance == null)
                    s_Instance = new LoadSpectralSensitivity();

                return s_Instance;
            }
        }

        int m_refCounting = 0;

        Texture2DArray m_SpectralSensitivity;
        Vector4 m_SpectralSensitivity_ST;

        LoadSpectralSensitivity() {}


        private void LoadData(out Texture2DArray texture, out float muOffset, out float muScale, out float sigmaOffset, out float sigmaScale)
        {
            int numMu = SpectralSensitivityDataSRGB.numMu;
            int numSigma = SpectralSensitivityDataSRGB.numSigma;
            float maxMu = SpectralSensitivityDataSRGB.maxMu;
            float maxSigma = SpectralSensitivityDataSRGB.maxSigma;

            float[] Rmag = SpectralSensitivityDataSRGB.Rmag;
            float[] Rphi = SpectralSensitivityDataSRGB.Rphi;
            float[] Gmag = SpectralSensitivityDataSRGB.Gmag;
            float[] Gphi = SpectralSensitivityDataSRGB.Gphi;
            float[] Bmag = SpectralSensitivityDataSRGB.Bmag;
            float[] Bphi = SpectralSensitivityDataSRGB.Bphi;

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
                LoadData(out m_SpectralSensitivity, out muOffset, out muScale, out sigmaOffset, out sigmaScale);
                m_SpectralSensitivity_ST = new Vector4(muScale, sigmaScale, muOffset, sigmaOffset);
            }

            m_refCounting++;
        }

        public void RenderInit(CommandBuffer cmd)
        {
            // Data is already loaded!
            // But sometimes it disappears...
            if (m_SpectralSensitivity == null)
            {
                float muOffset, muScale;
                float sigmaOffset, sigmaScale;
                LoadData(out m_SpectralSensitivity, out muOffset, out muScale, out sigmaOffset, out sigmaScale);
                m_SpectralSensitivity_ST = new Vector4(muScale, sigmaScale, muOffset, sigmaOffset);
            }
        }

        public void Cleanup()
        {
            m_refCounting--;

            if (m_refCounting == 0)
            {
                CoreUtils.Destroy(m_SpectralSensitivity);
                m_SpectralSensitivity = null;
            }

            Debug.Assert(m_refCounting >= 0);
        }

        public void Bind(CommandBuffer cmd)
        {
            // TODO HDShaderIDs!
            cmd.SetGlobalTexture("_IridescenceSensitivityMap", m_SpectralSensitivity);
            cmd.SetGlobalVector("_IridescenceSensitivityMap_ST", m_SpectralSensitivity_ST);
        }
    }
}
