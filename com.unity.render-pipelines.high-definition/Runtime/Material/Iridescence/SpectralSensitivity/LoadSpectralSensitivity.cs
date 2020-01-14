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

        Texture2D m_SpectralSensitivity;
        Vector4 m_SpectralSensitivity_ST;
        Vector4 m_IridescenceWavelengthMinMaxSampleCount;

        LoadSpectralSensitivity() {}


        private void LoadData(out Texture2D texture, out float minWavelength, out float maxWavelength, out float wavelengthOffset, out float wavelengthScale)
        {
            int numSamples = SpectralSensitivityDataSRGB.numSamples;
            minWavelength = SpectralSensitivityDataSRGB.minWavelength;
            maxWavelength = SpectralSensitivityDataSRGB.maxWavelength;

            float[] R = SpectralSensitivityDataSRGB.R;
            float[] G = SpectralSensitivityDataSRGB.G;
            float[] B = SpectralSensitivityDataSRGB.B;

            texture = new Texture2D(numSamples, 1, TextureFormat.RGBAFloat, mipChain: false, linear: true);

            var colors = new Color[numSamples];
            for (int i = 0; i < colors.Length; ++i)
            {
                colors[i].r = R[i];
                colors[i].g = G[i];
                colors[i].b = B[i];
            }
            texture.SetPixels(colors);

            texture.Apply();
            texture.filterMode = FilterMode.Bilinear;
            texture.wrapMode = TextureWrapMode.Clamp;

            // u = x * scale + offset
            // (0.5f / size) = min * scale + offset
            // (1 - 0.5f / size) = max * scale + offset

            // offset = (0.5f / size) - min * scale
            // scale = ((1 - 0.5f / size) - offset) / max

            // offset = (0.5f / size) - min * scale
            // scale = (1 - 1.0f / size) / (max - min)
            // offset = (0.5f / size) - min / (max - min) * (1 - 1.0f / size)
            // offset = (max - min) * (0.5f / size) / (max - min) - min * (1 - 1.0f / size) / (max - min)


            wavelengthOffset = (maxWavelength * (0.5f / numSamples) - minWavelength * (1 - 0.5f / numSamples)) / (maxWavelength - minWavelength);
            wavelengthScale = (1.0f - 1.0f / numSamples) / (maxWavelength - minWavelength);
        }

        public void Build()
        {
            Debug.Assert(m_refCounting >= 0);

            if (m_refCounting == 0)
            {
                float wavelengthOffset, wavelengthScale;
                float minWavelength, maxWavelength;
                LoadData(out m_SpectralSensitivity, out minWavelength, out maxWavelength, out wavelengthOffset, out wavelengthScale);
                m_SpectralSensitivity_ST = new Vector4(wavelengthScale, 1, wavelengthOffset, 0);
                m_IridescenceWavelengthMinMaxSampleCount = new Vector4(minWavelength, maxWavelength, m_SpectralSensitivity.width, 1.0f / m_SpectralSensitivity.width);
            }

            m_refCounting++;
        }

        public void RenderInit(CommandBuffer cmd)
        {
            // Data is already loaded!
            // But sometimes it disappears...
            if (m_SpectralSensitivity == null)
            {
                float wavelengthOffset, wavelengthScale;
                float minWavelength, maxWavelength;
                LoadData(out m_SpectralSensitivity, out minWavelength, out maxWavelength, out wavelengthOffset, out wavelengthScale);
                m_SpectralSensitivity_ST = new Vector4(wavelengthScale, 1, wavelengthOffset, 0);
                m_IridescenceWavelengthMinMaxSampleCount = new Vector4(minWavelength, maxWavelength, m_SpectralSensitivity.width, 1.0f / m_SpectralSensitivity.width);
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
            cmd.SetGlobalVector("_IridescenceWavelengthMinMaxSampleCount", m_IridescenceWavelengthMinMaxSampleCount);
        }
    }
}
