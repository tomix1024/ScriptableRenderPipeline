using System;
using UnityEngine.Rendering;

namespace UnityEngine.Experimental.Rendering.HDPipeline
{
    public partial class Iridescence : RenderPipelineMaterial
    {
        //-----------------------------------------------------------------------------
        // SurfaceData
        //-----------------------------------------------------------------------------

        // Main structure that store the user data (i.e user input of master node in material graph)
        [GenerateHLSL(PackingRules.Exact, false, true, 1000)]
        public struct SurfaceData
        {
            public float ambientOcclusion; // Caution: This is accessible only if light layer is enabled, otherwise it is 1
            public float specularOcclusion;

            [SurfaceDataAttributes(new string[] {"Normal", "Normal View Space"}, true)]
            public Vector3 normalWS;

            [SurfaceDataAttributes("Smoothness")]
            public float perceptualSmoothness;

            [SurfaceDataAttributes("Fresnel0")]
            public Vector3 fresnel0;

            // Iridescence
            [SurfaceDataAttributes("Iridescence Layer Thickness")]
            public float iridescenceThickness;

            [SurfaceDataAttributes("Iridescence Layer Eta")]
            public float iridescenceEta2;

            [SurfaceDataAttributes("Iridescence Base Eta")]
            public float iridescenceEta3;

            [SurfaceDataAttributes("Iridescence Base Kappa")]
            public float iridescenceKappa3;
        };

        //-----------------------------------------------------------------------------
        // BSDFData
        //-----------------------------------------------------------------------------

        [GenerateHLSL(PackingRules.Exact, false, true, 1050)]
        public struct BSDFData
        {
            public float ambientOcclusion; // Caution: This is accessible only if light layer is enabled, otherwise it is 1
            public float specularOcclusion;

            [SurfaceDataAttributes("", false, true)]
            public Vector3 diffuseColor;
            public Vector3 fresnel0;

            [SurfaceDataAttributes(new string[] { "Normal WS", "Normal View Space" }, true)]
            public Vector3 normalWS;

            public float perceptualRoughness;
            public float roughness;

            // Iridescence
            public float iridescenceThickness;
            public float iridescenceEta2;
            public float iridescenceEta3;
            public float iridescenceKappa3;
        };

        //-----------------------------------------------------------------------------
        // GBuffer management
        //-----------------------------------------------------------------------------

        public override bool IsDefferedMaterial() { return false; }

        //-----------------------------------------------------------------------------
        // Init precomputed texture
        //-----------------------------------------------------------------------------

        public Iridescence() {}

        public override void Build(HDRenderPipelineAsset hdAsset)
        {
            PreIntegratedFGD.instance.Build(PreIntegratedFGD.FGDIndex.FGD_GGXAndDisneyDiffuse);
            PreIntegratedVdotH.instance.Build();
            LTCAreaLight.instance.Build();
        }

        public override void Cleanup()
        {
            PreIntegratedFGD.instance.Cleanup(PreIntegratedFGD.FGDIndex.FGD_GGXAndDisneyDiffuse);
            PreIntegratedVdotH.instance.Cleanup();
            LTCAreaLight.instance.Cleanup();
        }

        public override void RenderInit(CommandBuffer cmd)
        {
            PreIntegratedFGD.instance.RenderInit(PreIntegratedFGD.FGDIndex.FGD_GGXAndDisneyDiffuse, cmd);
            PreIntegratedVdotH.instance.RenderInit(cmd);
        }

        public override void Bind()
        {
            PreIntegratedFGD.instance.Bind(PreIntegratedFGD.FGDIndex.FGD_GGXAndDisneyDiffuse);
            PreIntegratedVdotH.instance.Bind();
            LTCAreaLight.instance.Bind();
        }
    }
}
