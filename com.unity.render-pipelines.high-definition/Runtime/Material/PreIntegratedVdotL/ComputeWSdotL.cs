using UnityEngine.Rendering;
using System.Collections.Generic;

namespace UnityEngine.Experimental.Rendering.HDPipeline
{
    public class ComputeWSdotL
    {
        Material      m_ComputeWSdotLMaterial;

        Matrix4x4[]   m_faceWorldToViewMatrixMatrices     = new Matrix4x4[6];

        RenderPipelineResources m_RenderPipelineResources;

        public ComputeWSdotL(RenderPipelineResources renderPipelineResources)
        {
            m_RenderPipelineResources = renderPipelineResources;
        }

        public bool IsInitialized()
        {
            return m_ComputeWSdotLMaterial != null;
        }

        public void Initialize(CommandBuffer cmd)
        {
            if (m_ComputeWSdotLMaterial == null)
            {
                // TODO
                m_ComputeWSdotLMaterial = CoreUtils.CreateEngineMaterial(m_RenderPipelineResources.shaders.computeWSdotLPS);
            }

            for (int i = 0; i < 6; ++i)
            {
                var lookAt = Matrix4x4.LookAt(Vector3.zero, CoreUtils.lookAtList[i], CoreUtils.upVectorList[i]);
                m_faceWorldToViewMatrixMatrices[i] = lookAt * Matrix4x4.Scale(new Vector3(1.0f, 1.0f, -1.0f)); // Need to scale -1.0 on Z to match what is being done in the camera.wolrdToCameraMatrix API. ...
            }
        }

        public void Cleanup()
        {
            CoreUtils.Destroy(m_ComputeWSdotLMaterial);
            m_ComputeWSdotLMaterial = null;
        }

        public void Compute(CommandBuffer cmd, Texture source, RenderTexture target1, RenderTexture target2, RenderTexture target3)
        {
            var props = new MaterialPropertyBlock();
            props.SetTexture("_MainTex", source);

            using (new ProfilingSample(cmd, "Compute Cubemap Moments"))
            {
                for (int face = 0; face < 6; ++face)
                {
                    // Assume all targets same size!
                    var faceSize = new Vector4(target1.width, target1.height, 1.0f / target1.width, 1.0f / target1.height);
                    var transform = HDUtils.ComputePixelCoordToWorldSpaceViewDirectionMatrix(0.5f * Mathf.PI, faceSize, m_faceWorldToViewMatrixMatrices[face], true);

                    props.SetMatrix(HDShaderIDs._PixelCoordToViewDirWS, transform);

                    // Write 0th mipmap
                    props.SetInt("_OutputIndex", 0);
                    CoreUtils.SetRenderTarget(cmd, target1, ClearFlag.None, 0, (CubemapFace)face);
                    CoreUtils.DrawFullScreen(cmd, m_ComputeWSdotLMaterial, props);

                    props.SetInt("_OutputIndex", 1);
                    CoreUtils.SetRenderTarget(cmd, target2, ClearFlag.None, 0, (CubemapFace)face);
                    CoreUtils.DrawFullScreen(cmd, m_ComputeWSdotLMaterial, props);

                    props.SetInt("_OutputIndex", 2);
                    CoreUtils.SetRenderTarget(cmd, target3, ClearFlag.None, 0, (CubemapFace)face);
                    CoreUtils.DrawFullScreen(cmd, m_ComputeWSdotLMaterial, props);
                }
            }
        }
    }
}
