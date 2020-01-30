using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.HighDefinition;

// Include material common properties names
using static UnityEngine.Rendering.HighDefinition.HDMaterialProperties;

namespace UnityEditor.Rendering.HighDefinition
{
    /// <summary>
    /// GUI for HDRP unlit shaders (does not include shader graphs)
    /// </summary>
    class UnlitGUI : HDShaderGUI
    {
        MaterialUIBlockList uiBlocks = new MaterialUIBlockList
        {
            new SurfaceOptionUIBlock(MaterialUIBlock.Expandable.Base, features: SurfaceOptionUIBlock.Features.Unlit),
            new UnlitSurfaceInputsUIBlock(MaterialUIBlock.Expandable.Input),
            new TransparencyUIBlock(MaterialUIBlock.Expandable.Transparency),
            new EmissionUIBlock(MaterialUIBlock.Expandable.Emissive),
            new AdvancedOptionsUIBlock(MaterialUIBlock.Expandable.Advance, AdvancedOptionsUIBlock.Features.Instancing | AdvancedOptionsUIBlock.Features.AddPrecomputedVelocity)
        };

        protected override void OnMaterialGUI(MaterialEditor materialEditor, MaterialProperty[] props)
        {
            using (var changed = new EditorGUI.ChangeCheckScope())
            {
                uiBlocks.OnGUI(materialEditor, props);
                ApplyKeywordsAndPassesIfNeeded(changed.changed, uiBlocks.materials);
            }
        }

        protected override void SetupMaterialKeywordsAndPassInternal(Material material) => SetupUnlitMaterialKeywordsAndPass(material);

        // All Setup Keyword functions must be static. It allow to create script to automatically update the shaders with a script if code change
        public static void SetupUnlitMaterialKeywordsAndPass(Material material)
        {
            material.SetupBaseUnlitKeywords();
            material.SetupBaseUnlitPass();

            if (material.HasProperty(kEmissiveColorMap))
                CoreUtils.SetKeyword(material, "_EMISSIVE_COLOR_MAP", material.GetTexture(kEmissiveColorMap));

            // Stencil usage rules:
            // StencilUsage need to be tagged during depth prepass
            // RequiresDeferredLighting need to be tagged during GBuffer
            // SubsurfaceScattering need to be tagged during either GBuffer or Forward pass
            // ObjectVelocity need to be tagged in velocity pass.
            // As velocity pass can be use as a replacement of depth prepass it also need to have StencilUsage
            // As GBuffer pass can have no depth prepass, it also need to have StencilUsage
            // Object velocity is always render after a full depth buffer (if there is no depth prepass for GBuffer all object motion vectors are render after GBuffer)
            // so we have a guarantee than when we write object velocity no other object will be draw on top (and so would have require to overwrite velocity).
            // Final combination is:
            // Prepass: StencilUsage
            // Motion vectors: StencilUsage, ObjectVelocity
            // Forward: LightingMask

            int stencilRef = (int)StencilUsage.Clear;
            int stencilWriteMask = (int)StencilUsage.RequiresDeferredLighting | (int)StencilUsage.SubsurfaceScattering;
            int stencilRefDepth = (int)StencilUsage.Clear;
            int stencilWriteMaskDepth = (int)StencilUsage.TraceReflectionRay;
            int stencilRefMV = (int)StencilUsage.ObjectMotionVector;
            int stencilWriteMaskMV = (int)StencilUsage.ObjectMotionVector | (int)StencilUsage.TraceReflectionRay;

            // As we tag both during velocity pass and Gbuffer pass we need a separate state and we need to use the write mask
            material.SetInt(kStencilRef, stencilRef);
            material.SetInt(kStencilWriteMask, stencilWriteMask);
            material.SetInt(kStencilRefDepth, stencilRefDepth);
            material.SetInt(kStencilWriteMaskDepth, stencilWriteMaskDepth);
            material.SetInt(kStencilRefMV, stencilRefMV);
            material.SetInt(kStencilWriteMaskMV, stencilWriteMaskMV);
            material.SetInt(kStencilRefDistortionVec, (int)StencilUsage.DistortionVectors);
            material.SetInt(kStencilWriteMaskDistortionVec, (int)StencilUsage.DistortionVectors);
            if (material.HasProperty(kAddPrecomputedVelocity))
            {
                CoreUtils.SetKeyword(material, "_ADD_PRECOMPUTED_VELOCITY", material.GetInt(kAddPrecomputedVelocity) != 0);
            }

        }
    }
} // namespace UnityEditor
