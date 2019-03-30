using UnityEngine.Rendering.HighDefinition.Attributes;
using UnityEngine.Experimental.Rendering;

namespace UnityEngine.Rendering.HighDefinition
{
    partial class Iridescence : RenderPipelineMaterial
    {
        //-----------------------------------------------------------------------------
        // SurfaceData
        //-----------------------------------------------------------------------------

        // Main structure that store the user data (i.e user input of master node in material graph)
        [GenerateHLSL(PackingRules.Exact, false, false, true, 1000)]
        public struct SurfaceData
        {
            [MaterialSharedPropertyMapping(MaterialSharedProperty.AmbientOcclusion)]
            [SurfaceDataAttributes("Ambient Occlusion", precision = FieldPrecision.Real)]
            public float ambientOcclusion; // Caution: This is accessible only if light layer is enabled, otherwise it is 1
            [SurfaceDataAttributes("Specular Occlusion", precision = FieldPrecision.Real)]
            public float specularOcclusion;

            [MaterialSharedPropertyMapping(MaterialSharedProperty.Normal)]
            [SurfaceDataAttributes(new string[] {"Normal", "Normal View Space"}, true)]
            public Vector3 normalWS;

            [MaterialSharedPropertyMapping(MaterialSharedProperty.Smoothness)]
            [SurfaceDataAttributes("Smoothness", precision = FieldPrecision.Real)]
            public float perceptualSmoothness;

            [SurfaceDataAttributes("Fresnel0", precision = FieldPrecision.Real)]
            public Vector3 fresnel0;

            // Iridescence
            [SurfaceDataAttributes("Iridescence Layer Thickness", precision = FieldPrecision.Real)]
            public float iridescenceThickness;
            public Vector4 iridescenceThicknessSphereModel;

            [SurfaceDataAttributes("Iridescence Layer Eta", precision = FieldPrecision.Real)]
            public float iridescenceEta2;

            [SurfaceDataAttributes("Iridescence Base Eta", precision = FieldPrecision.Real)]
            public float iridescenceEta3;

            [SurfaceDataAttributes("Iridescence Base Kappa", precision = FieldPrecision.Real)]
            public float iridescenceKappa3;
        };

        //-----------------------------------------------------------------------------
        // BSDFData
        //-----------------------------------------------------------------------------

        [GenerateHLSL(PackingRules.Exact, false, false, true, 1050)]
        public struct BSDFData
        {
            [SurfaceDataAttributes(precision = FieldPrecision.Real)]
            public float ambientOcclusion; // Caution: This is accessible only if light layer is enabled, otherwise it is 1
            [SurfaceDataAttributes(precision = FieldPrecision.Real)]
            public float specularOcclusion;

            [SurfaceDataAttributes("", false, true, FieldPrecision.Real)]
            public Vector3 diffuseColor;
            [SurfaceDataAttributes(precision = FieldPrecision.Real)]
            public Vector3 fresnel0;

            [SurfaceDataAttributes(new string[] { "Normal WS", "Normal View Space" }, true)]
            public Vector3 normalWS;

            [SurfaceDataAttributes(precision = FieldPrecision.Real)]
            public float perceptualRoughness;
            [SurfaceDataAttributes(precision = FieldPrecision.Real)]
            public float roughness;

            // Iridescence
            [SurfaceDataAttributes(precision = FieldPrecision.Real)]
            public float iridescenceThickness;
            [SurfaceDataAttributes(precision = FieldPrecision.Real)]
            public Vector4 iridescenceThicknessSphereModel;
            [SurfaceDataAttributes(precision = FieldPrecision.Real)]
            public float iridescenceEta2;
            [SurfaceDataAttributes(precision = FieldPrecision.Real)]
            public float iridescenceEta3;
            [SurfaceDataAttributes(precision = FieldPrecision.Real)]
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

        public override void Build(HDRenderPipelineAsset hdAsset, RenderPipelineResources defaultResources)
        {
            LoadSpectralSensitivity.instance.Build();
            PreIntegratedFGD.instance.Build(PreIntegratedFGD.FGDIndex.FGD_GGXAndDisneyDiffuse);
            PreIntegratedVdotH.instance.Build();
            PreIntegratedVdotL.instance.Build();
            LTCAreaLight.instance.Build();
        }

        public override void Cleanup()
        {
            LoadSpectralSensitivity.instance.Cleanup();
            PreIntegratedFGD.instance.Cleanup(PreIntegratedFGD.FGDIndex.FGD_GGXAndDisneyDiffuse);
            PreIntegratedVdotH.instance.Cleanup();
            PreIntegratedVdotL.instance.Cleanup();
            LTCAreaLight.instance.Cleanup();
        }

        public override void RenderInit(CommandBuffer cmd)
        {
            LoadSpectralSensitivity.instance.RenderInit(cmd);
            PreIntegratedFGD.instance.RenderInit(PreIntegratedFGD.FGDIndex.FGD_GGXAndDisneyDiffuse, cmd);
            PreIntegratedVdotH.instance.RenderInit(cmd);
            PreIntegratedVdotL.instance.RenderInit(cmd);
        }

        public override void Bind(CommandBuffer cmd)
        {
            LoadSpectralSensitivity.instance.Bind(cmd);
            PreIntegratedFGD.instance.Bind(cmd, PreIntegratedFGD.FGDIndex.FGD_GGXAndDisneyDiffuse);
            PreIntegratedVdotH.instance.Bind(cmd);
            PreIntegratedVdotL.instance.Bind(cmd);
            LTCAreaLight.instance.Bind(cmd);
        }
    }
}
