using System;
using UnityEngine.Rendering;

namespace UnityEngine.Experimental.Rendering.HDPipeline
{
    public partial class PreIntegratedVdotL
    {
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

        // RenderTexture m_PreIntegratedWSdotL_X1;
        // RenderTexture m_PreIntegratedWSdotL_X2;
        // RenderTexture m_PreIntegratedWSdotL_XY;

        PreIntegratedVdotL()
        {
        }

        public void Build()
        {
            Debug.Assert(m_refCounting >= 0);

            if (m_refCounting == 0)
            {
                // TODO

                m_isInit = false;
            }

            m_refCounting++;
        }

        public void RenderInit(CommandBuffer cmd)
        {
            // Here we have to test IsCreated because in some circumstances (like loading RenderDoc), the texture is internally destroyed but we don't know from C# side.
            // In this case IsCreated will return false, allowing us to re-render the texture (setting the texture as current RT during DrawFullScreen will automatically re-create it internally)
            if (m_isInit /*&& m_PreIntegratedWSdotL_X1.IsCreated()*/)
                return;

            /*
            using (new ProfilingSample(cmd, "PreIntegratedVdotL Material Generation"))
            {
                 CoreUtils.DrawFullScreen(cmd, m_PreIntegratedVdotHMaterial, new RenderTargetIdentifier(m_PreIntegratedVdotH));
            }
            */

            m_isInit = true;
        }

        public void Cleanup()
        {
            m_refCounting--;

            if (m_refCounting == 0)
            {
                // CoreUtils.Destroy(m_PreIntegratedWSdotL_X1);
                // CoreUtils.Destroy(m_PreIntegratedWSdotL_X2);
                // CoreUtils.Destroy(m_PreIntegratedWSdotL_XY);

                m_isInit = false;
            }

            Debug.Assert(m_refCounting >= 0);
        }

        public void Bind()
        {
            // Shader.SetGlobalTexture(HDShaderIDs._PreIntegratedWSdotL_X1_GGX, m_PreIntegratedWSdotL_X1);
            // Shader.SetGlobalTexture(HDShaderIDs._PreIntegratedWSdotL_X2_GGX, m_PreIntegratedWSdotL_X2);
            // Shader.SetGlobalTexture(HDShaderIDs._PreIntegratedWSdotL_XY_GGX, m_PreIntegratedWSdotL_XY);
        }
    }
}
