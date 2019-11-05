using System;
using UnityEngine.Experimental.Rendering;

namespace UnityEngine.Rendering.HighDefinition
{
    public partial class PreIntegratedVdotL
    {
        [GenerateHLSL]
        public enum VdotLTexture
        {
            Resolution = 64
        }

        static PreIntegratedVdotL s_Instance;

        public static PreIntegratedVdotL instance
        {
            get
            {
                if (s_Instance == null)
                    s_Instance = new PreIntegratedVdotL();

                return s_Instance;
            }
        }

        bool m_isInit = false;
        int m_refCounting = 0;

        Material m_PreIntegratedVdotLMaterial;
        RenderTexture m_PreIntegratedVdotL;

        PreIntegratedVdotL()
        {
        }

        public void Build()
        {
            Debug.Assert(m_refCounting >= 0);

            if (m_refCounting == 0)
            {
                var hdrp = HDRenderPipeline.defaultAsset;
                int res  = (int)VdotLTexture.Resolution;

                m_PreIntegratedVdotLMaterial = CoreUtils.CreateEngineMaterial(hdrp.renderPipelineResources.shaders.preIntegratedVdotL_GGXPS);
                m_PreIntegratedVdotL = new RenderTexture(res, res, 0, RenderTextureFormat.ARGBFloat/*ARGB2101010*/, RenderTextureReadWrite.Linear);
                m_PreIntegratedVdotL.hideFlags = HideFlags.HideAndDontSave;
                m_PreIntegratedVdotL.filterMode = FilterMode.Bilinear;
                m_PreIntegratedVdotL.wrapMode = TextureWrapMode.Clamp;
                m_PreIntegratedVdotL.name = CoreUtils.GetRenderTargetAutoName(res, res, 1, RenderTextureFormat.ARGB2101010, "preIntegratedVdotL_GGX");
                m_PreIntegratedVdotL.Create();

                m_isInit = false;
            }

            m_refCounting++;
        }

        public void RenderInit(CommandBuffer cmd)
        {
            // Here we have to test IsCreated because in some circumstances (like loading RenderDoc), the texture is internally destroyed but we don't know from C# side.
            // In this case IsCreated will return false, allowing us to re-render the texture (setting the texture as current RT during DrawFullScreen will automatically re-create it internally)
            if (m_isInit && m_PreIntegratedVdotL.IsCreated())
                return;

            using (new ProfilingSample(cmd, "PreIntegratedVdotL Material Generation"))
            {
                CoreUtils.DrawFullScreen(cmd, m_PreIntegratedVdotLMaterial, new RenderTargetIdentifier(m_PreIntegratedVdotL));
            }

            m_isInit = true;
        }

        public void Cleanup()
        {
            m_refCounting--;

            if (m_refCounting == 0)
            {
                CoreUtils.Destroy(m_PreIntegratedVdotLMaterial);
                CoreUtils.Destroy(m_PreIntegratedVdotL);

                m_isInit = false;
            }

            Debug.Assert(m_refCounting >= 0);
        }

        public void Bind(CommandBuffer cmd)
        {
            cmd.SetGlobalTexture(HDShaderIDs._PreIntegratedVdotL_GGX, m_PreIntegratedVdotL);
        }
    }
}
