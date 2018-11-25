using System;
using UnityEngine.Rendering;

namespace UnityEngine.Experimental.Rendering.HDPipeline
{
    public partial class PreIntegratedVdotH
    {
        [GenerateHLSL]
        public enum VdotHTexture
        {
            Resolution = 64
        }

        static PreIntegratedVdotH s_Instance;

        public static PreIntegratedVdotH instance
        {
            get
            {
                if (s_Instance == null)
                    s_Instance = new PreIntegratedVdotH();

                return s_Instance;
            }
        }

        bool m_isInit = false;
        int m_refCounting = 0;

        Material m_PreIntegratedVdotHMaterial;
        RenderTexture m_PreIntegratedVdotH;

        PreIntegratedVdotH()
        {
        }

        public void Build()
        {
            Debug.Assert(m_refCounting >= 0);

            if (m_refCounting == 0)
            {
                var hdrp = GraphicsSettings.renderPipelineAsset as HDRenderPipelineAsset;
                int res  = (int)VdotHTexture.Resolution;

                m_PreIntegratedVdotHMaterial = CoreUtils.CreateEngineMaterial(hdrp.renderPipelineResources.shaders.preIntegratedVdotH_GGXPS);
                m_PreIntegratedVdotH = new RenderTexture(res, res, 0, RenderTextureFormat.ARGB2101010, RenderTextureReadWrite.Linear);
                m_PreIntegratedVdotH.hideFlags = HideFlags.HideAndDontSave;
                m_PreIntegratedVdotH.filterMode = FilterMode.Bilinear;
                m_PreIntegratedVdotH.wrapMode = TextureWrapMode.Clamp;
                m_PreIntegratedVdotH.name = CoreUtils.GetRenderTargetAutoName(res, res, 1, RenderTextureFormat.ARGB2101010, "preIntegratedVdotH_GGX");
                m_PreIntegratedVdotH.Create();

                m_isInit = false;
            }

            m_refCounting++;
        }

        public void RenderInit(CommandBuffer cmd)
        {
            // Here we have to test IsCreated because in some circumstances (like loading RenderDoc), the texture is internally destroyed but we don't know from C# side.
            // In this case IsCreated will return false, allowing us to re-render the texture (setting the texture as current RT during DrawFullScreen will automatically re-create it internally)
            if (m_isInit && m_PreIntegratedVdotH.IsCreated())
                return;

            using (new ProfilingSample(cmd, "PreIntegratedVdotH Material Generation"))
            {
                CoreUtils.DrawFullScreen(cmd, m_PreIntegratedVdotHMaterial, new RenderTargetIdentifier(m_PreIntegratedVdotH));
            }

            m_isInit = true;
        }

        public void Cleanup()
        {
            m_refCounting--;

            if (m_refCounting == 0)
            {
                CoreUtils.Destroy(m_PreIntegratedVdotHMaterial);
                CoreUtils.Destroy(m_PreIntegratedVdotH);

                m_isInit = false;
            }

            Debug.Assert(m_refCounting >= 0);
        }

        public void Bind()
        {
            Shader.SetGlobalTexture(HDShaderIDs._PreIntegratedVdotH, m_PreIntegratedVdotH);
        }
    }
}
