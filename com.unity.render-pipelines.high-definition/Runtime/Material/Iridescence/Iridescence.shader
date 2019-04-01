Shader "HDRenderPipeline/Iridescence"
{
    Properties
    {
        // Following set of parameters represent the parameters node inside the MaterialGraph.
        // They are use to fill a SurfaceData. With a MaterialGraph this should not exist.

        // Reminder. Color here are in linear but the UI (color picker) do the conversion sRGB to linear

        _Smoothness("Smoothness", Range(0.0, 1.0)) = 1.0
        _Fresnel0("Fresnel0 for IBL", Color) = (1,1,1,1)

        // _NormalMap("NormalMap", 2D) = "bump" {}     // Tangent space normal map
        // _NormalScale("_NormalScale", Range(0.0, 8.0)) = 1

        [Toggle(IRIDESCENCE_USE_THICKNESS_MAP)]_IridescenceUseThicknessMap("Use Thickness Map", Float) = 0
        _IridescenceThicknessMap("Iridescence Thickness Map", 2D) = "white" {}

        _IridescenceThickness("Iridescence Thickness (µm)", Range(0.0, 3.0)) = 1.0
        _IridescenceEta2("Iridescence Eta 2", Range(1.0, 5.0)) = 1.21
        _IridescenceEta3("Iridescence Eta 3", Range(1.0, 5.0)) = 2.0
        _IridescenceKappa3("Iridescence Kappa 3", Range(0.0, 5.0)) = 0.0


        [Toggle(IRIDESCENCE_USE_PREINTEGRATED_IBLR)]_IBLUsePreIntegratedIblR("IBL Preintegrated R", Float) = 0.0
        [Toggle(IRIDESCENCE_USE_PREINTEGRATED_IBLROUGHNESS)]_IBLUsePreIntegratedIblRoughness("IBL Preintegrated Roughness", Float) = 0.0

        [Toggle(IRIDESCENCE_USE_VDOTH_MEAN)]_IBLUseMeanVdotH("IBL Mean VdotH", Float) = 0.0
        [Toggle(IRIDESCENCE_USE_VDOTH_VAR)]_IBLUseVarVdotH("IBL Var VdotH", Float) = 0.0
        [Toggle(IRIDESCENCE_USE_VDOTL)]_IBLUseVdotL("IBL VdotL", Float) = 0.0

        [Toggle(IRIDESCENCE_USE_PHASE_SHIFT)]_IridescenceUsePhaseShift("Use Phase Shifts", Float) = 1.0

        [Toggle(IRIDESCENCE_ENABLE_TRANSMISSION)]_IridescenceEnableTransmission("Enable Transmission", Float) = 0.0

        _ReferenceUseCorrectOPD("Ref Correct OPD", Range(0.0, 1.0)) = 1.0
        _ReferenceUseCorrectCoeffs("Ref Correct Coeffs", Range(0.0, 1.0)) = 1.0
        _ReferenceUseMeanVdotH("Ref Mean VdotH", Range(0.0, 1.0)) = 0.0
        _ReferenceUseVarVdotH("Ref Var VdotH", Range(0.0, 1.0)) = 0.0
        _ReferenceUseVdotHWeightWithLight("Ref Weight VdotH with Light", Range(0.0, 1.0)) = 0.0

        _ReferenceDebugMeanScale("Ref Debug Mean Scale", Float) = 1.0
        _ReferenceDebugMeanOffset("Ref Debug Mean Offset", Float) = 0.0
        _ReferenceDebugDevScale("Ref Debug Dev Scale", Float) = 1.0
        _ReferenceDebugDevOffset("Ref Debug Dev Offset", Float) = 0.0

        [Toggle(IRIDESCENCE_REFERENCE_VDOTH_MEAN_VAR)]_IridescenceReferenceVdotHMeanVar("Show VdotH Mean/Var", Float) = 0

        [Toggle(IRIDESCENCE_DISPLAY_REFERENCE_IBL_16)]_IridescenceDisplayReferenceIBL16("16 Sample Ref. IBL", Float) = 0
        [Toggle(IRIDESCENCE_DISPLAY_REFERENCE_IBL_256)]_IridescenceDisplayReferenceIBL256("256 Sample Ref. IBL", Float) = 0
        [Toggle(IRIDESCENCE_DISPLAY_REFERENCE_IBL_2048)]_IridescenceDisplayReferenceIBL2048("2048 Sample Ref. IBL", Float) = 0
        [Toggle(IRIDESCENCE_DISPLAY_REFERENCE_IBL_16K)]_IridescenceDisplayReferenceIBL16k("16k Sample Ref. IBL", Float) = 0

        [Toggle(LIT_USE_GGX_ENERGY_COMPENSATION)]_UseGGXEnergyCompensation("Use GGX Energy Compensation", Float) = 1

        // Stencil state
        [HideInInspector] _StencilRef("_StencilRef", Int) = 2 // StencilLightingUsage.RegularLighting  (fixed at compile time)
        [HideInInspector] _StencilWriteMask("_StencilWriteMask", Int) = 7 // StencilMask.Lighting  (fixed at compile time)
        [HideInInspector] _StencilRefMV("_StencilRefMV", Int) = 128 // StencilLightingUsage.RegularLighting  (fixed at compile time)
        [HideInInspector] _StencilWriteMaskMV("_StencilWriteMaskMV", Int) = 128 // StencilMask.ObjectsVelocity  (fixed at compile time)

        // Blending state
        [HideInInspector] _SurfaceType("__surfacetype", Float) = 0.0
        [HideInInspector] _BlendMode("__blendmode", Float) = 0.0
        [HideInInspector] _SrcBlend("__src", Float) = 1.0
        [HideInInspector] _DstBlend("__dst", Float) = 0.0
        [HideInInspector] _ZWrite("__zw", Float) = 1.0
        [Enum(Both, 0, Back, 1, Front, 2)]_CullMode("Cull Mode", Float) = 2
        [HideInInspector] _ZTestDepthEqualForOpaque("_ZTestDepthEqualForOpaque", Int) = 4 // Less equal
        [HideInInspector] _ZTestModeDistortion("_ZTestModeDistortion", Int) = 8
        [HideInInspector] _ZTestGBuffer("_ZTestGBuffer", Int) = 4

        [Toggle(_DOUBLESIDED_ON)] _DoubleSidedEnable("Double sided enable", Float) = 0.0
        [Enum(Flip, 0, Mirror, 1, None, 2)] _DoubleSidedNormalMode("Double sided normal mode", Float) = 1
        [HideInInspector] _DoubleSidedConstants("_DoubleSidedConstants", Vector) = (1, 1, -1, 0)

        // HACK: GI Baking system relies on some properties existing in the shader ("_MainTex", "_Cutoff" and "_Color") for opacity handling, so we need to store our version of those parameters in the hard-coded name the GI baking system recognizes.
        _MainTex("Albedo", 2D) = "white" {}
        _Color("Color", Color) = (1,1,1,1)
        _Cutoff("Alpha Cutoff", Range(0.0, 1.0)) = 0.5

        // this will let collapsable element of material be persistant
        [HideInInspector] _EditorExpendedAreas("_EditorExpendedAreas", Float) = 0
    }

    HLSLINCLUDE

    #pragma target 4.5
    #pragma only_renderers d3d11 ps4 xboxone vulkan metal

    //-------------------------------------------------------------------------------------
    // Variant
    //-------------------------------------------------------------------------------------

    #pragma shader_feature _ALPHATEST_ON
    #pragma shader_feature _DOUBLESIDED_ON

    #pragma shader_feature LIT_USE_GGX_ENERGY_COMPENSATION

    // Keyword for transparent
    #pragma shader_feature _SURFACE_TYPE_TRANSPARENT
    #pragma shader_feature _ _BLENDMODE_ALPHA _BLENDMODE_ADD _BLENDMODE_PRE_MULTIPLY
    #pragma shader_feature _BLENDMODE_PRESERVE_SPECULAR_LIGHTING // easily handled in material.hlsl, so adding this already.
    #pragma shader_feature _ENABLE_FOG_ON_TRANSPARENT

    //enable GPU instancing support
    #pragma multi_compile_instancing

    #pragma shader_feature _ IRIDESCENCE_DISPLAY_REFERENCE_IBL_16 IRIDESCENCE_DISPLAY_REFERENCE_IBL_256 IRIDESCENCE_DISPLAY_REFERENCE_IBL_2048 IRIDESCENCE_DISPLAY_REFERENCE_IBL_16K
    #pragma shader_feature _ IRIDESCENCE_REFERENCE_VDOTH_MEAN_VAR

    #pragma shader_feature _ IRIDESCENCE_ENABLE_TRANSMISSION

    #pragma shader_feature _ IRIDESCENCE_USE_THICKNESS_MAP

    #pragma shader_feature _ IRIDESCENCE_USE_PREINTEGRATED_IBLR
    #pragma shader_feature _ IRIDESCENCE_USE_PREINTEGRATED_IBLROUGHNESS

    #pragma shader_feature _ IRIDESCENCE_USE_VDOTH_MEAN
    #pragma shader_feature _ IRIDESCENCE_USE_VDOTH_VAR
    #pragma shader_feature _ IRIDESCENCE_USE_VDOTL

    #pragma shader_feature _ IRIDESCENCE_USE_UKF
    #pragma shader_feature _ IRIDESCENCE_USE_PHASE_SHIFT

    //-------------------------------------------------------------------------------------
    // Define
    //-------------------------------------------------------------------------------------

    #define UNITY_MATERIAL_IRIDESCENCE // Need to be define before including Material.hlsl

    //-------------------------------------------------------------------------------------
    // Include
    //-------------------------------------------------------------------------------------

    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
    #include "Packages/com.unity.render-pipelines.high-definition/Runtime/RenderPipeline/ShaderPass/FragInputs.hlsl"
    #include "Packages/com.unity.render-pipelines.high-definition/Runtime/RenderPipeline/ShaderPass/ShaderPass.cs.hlsl"

    //-------------------------------------------------------------------------------------
    // variable declaration
    //-------------------------------------------------------------------------------------

    #include "Packages/com.unity.render-pipelines.high-definition/Runtime/Material/Iridescence/IridescenceProperties.hlsl"

    // All our shaders use same name for entry point
    #pragma vertex Vert
    #pragma fragment Frag

    ENDHLSL

    SubShader
    {
        // This tags allow to use the shader replacement features
        Tags{ "RenderPipeline" = "HDRenderPipeline" "RenderType" = "HDIridescenceShader" }

        Pass
        {
            Name "SceneSelectionPass" // Name is not used
            Tags { "LightMode" = "SceneSelectionPass" }

            Cull Off

            HLSLPROGRAM

            // Note: Require _ObjectId and _PassValue variables

            // We reuse depth prepass for the scene selection, allow to handle alpha correctly as well as tessellation and vertex animation
            #define SHADERPASS SHADERPASS_DEPTH_ONLY
            #define SCENESELECTIONPASS // This will drive the output of the scene selection shader
            #include "Packages/com.unity.render-pipelines.high-definition/Runtime/ShaderLibrary/ShaderVariables.hlsl"
            #include "Packages/com.unity.render-pipelines.high-definition/Runtime/Material/Material.hlsl"
            #include "ShaderPass/IridescenceDepthPass.hlsl"
            #include "IridescenceData.hlsl"
            #include "Packages/com.unity.render-pipelines.high-definition/Runtime/RenderPipeline/ShaderPass/ShaderPassDepthOnly.hlsl"

            ENDHLSL
        }

        Pass
        {
            Name "Depth prepass"
            Tags{ "LightMode" = "DepthForwardOnly" }

            Cull[_CullMode]

            ZWrite On

            HLSLPROGRAM

            #define WRITE_NORMAL_BUFFER
            #define SHADERPASS SHADERPASS_DEPTH_ONLY
            #include "Packages/com.unity.render-pipelines.high-definition/Runtime/ShaderLibrary/ShaderVariables.hlsl"
            #include "Packages/com.unity.render-pipelines.high-definition/Runtime/Material/Material.hlsl"
            #include "ShaderPass/IridescenceDepthPass.hlsl"
            #include "IridescenceData.hlsl"
            #include "Packages/com.unity.render-pipelines.high-definition/Runtime/RenderPipeline/ShaderPass/ShaderPassDepthOnly.hlsl"

            ENDHLSL
        }

        Pass
        {
            Name "Motion Vectors"
            Tags{ "LightMode" = "MotionVectors" } // Caution, this need to be call like this to setup the correct parameters by C++ (legacy Unity)

            // If velocity pass (motion vectors) is enabled we tag the stencil so it don't perform CameraMotionVelocity
            Stencil
            {
                WriteMask [_StencilWriteMaskMV]
                Ref [_StencilRefMV]
                Comp Always
                Pass Replace
            }

            Cull[_CullMode]

            ZWrite On

            HLSLPROGRAM
            #define WRITE_NORMAL_BUFFER
            #pragma multi_compile _ WRITE_MSAA_DEPTH

            #define SHADERPASS SHADERPASS_VELOCITY
            #include "Packages/com.unity.render-pipelines.high-definition/Runtime/ShaderLibrary/ShaderVariables.hlsl"
            #include "Packages/com.unity.render-pipelines.high-definition/Runtime/Material/Material.hlsl"
            #include "ShaderPass/IridescenceSharePass.hlsl"
            #include "IridescenceData.hlsl"
            #include "Packages/com.unity.render-pipelines.high-definition/Runtime/RenderPipeline/ShaderPass/ShaderPassVelocity.hlsl"

            ENDHLSL
        }

        // Extracts information for lightmapping, GI (emission, albedo, ...)
        // This pass it not used during regular rendering.
        Pass
        {
            Name "META"
            Tags{ "LightMode" = "Meta" }

            Cull Off

            HLSLPROGRAM

            // Lightmap memo
            // DYNAMICLIGHTMAP_ON is used when we have an "enlighten lightmap" ie a lightmap updated at runtime by enlighten.This lightmap contain indirect lighting from realtime lights and realtime emissive material.Offline baked lighting(from baked material / light,
            // both direct and indirect lighting) will hand up in the "regular" lightmap->LIGHTMAP_ON.

            #define SHADERPASS SHADERPASS_LIGHT_TRANSPORT
            #include "Packages/com.unity.render-pipelines.high-definition/Runtime/ShaderLibrary/ShaderVariables.hlsl"
            #include "Packages/com.unity.render-pipelines.high-definition/Runtime/Material/Material.hlsl"
            #include "ShaderPass/IridescenceSharePass.hlsl"
            #include "IridescenceData.hlsl"
            #include "Packages/com.unity.render-pipelines.high-definition/Runtime/RenderPipeline/ShaderPass/ShaderPassLightTransport.hlsl"

            ENDHLSL
        }

        Pass
        {
            Name "ShadowCaster"
            Tags{ "LightMode" = "ShadowCaster" }

            Cull[_CullMode]

            ZClip [_ZClip]
            ZWrite On
            ZTest LEqual

            ColorMask 0

            HLSLPROGRAM

            #define SHADERPASS SHADERPASS_SHADOWS
            #define USE_LEGACY_UNITY_MATRIX_VARIABLES
            #include "Packages/com.unity.render-pipelines.high-definition/Runtime/ShaderLibrary/ShaderVariables.hlsl"
            #include "Packages/com.unity.render-pipelines.high-definition/Runtime/Material/Material.hlsl"

            #include "ShaderPass/IridescenceDepthPass.hlsl"
            #include "IridescenceData.hlsl"
            #include "Packages/com.unity.render-pipelines.high-definition/Runtime/RenderPipeline/ShaderPass/ShaderPassDepthOnly.hlsl"

            ENDHLSL
        }

        // Iridescence shader always render in forward
        Pass
        {
            Name "Forward" // Name is not used
            Tags { "LightMode" = "ForwardOnly" }

            Stencil
            {
                WriteMask [_StencilWriteMask]
                Ref [_StencilRef]
                Comp Always
                Pass Replace
            }

            Blend [_SrcBlend] [_DstBlend]
            // In case of forward we want to have depth equal for opaque mesh
            ZTest [_ZTestDepthEqualForOpaque]
            ZWrite [_ZWrite]
            Cull [_CullMode]

            HLSLPROGRAM

            #pragma multi_compile _ DEBUG_DISPLAY
            //NEWLITTODO
            #pragma multi_compile _ LIGHTMAP_ON
            #pragma multi_compile _ DIRLIGHTMAP_COMBINED
            #pragma multi_compile _ DYNAMICLIGHTMAP_ON
            #pragma multi_compile _ SHADOWS_SHADOWMASK
            // Setup DECALS_OFF so the shader stripper can remove variants
            // #pragma multi_compile DECALS_OFF DECALS_3RT DECALS_4RT

            // Supported shadow modes per light type
            #pragma multi_compile PUNCTUAL_SHADOW_LOW PUNCTUAL_SHADOW_MEDIUM PUNCTUAL_SHADOW_HIGH
            #pragma multi_compile DIRECTIONAL_SHADOW_LOW DIRECTIONAL_SHADOW_MEDIUM DIRECTIONAL_SHADOW_HIGH

            // #include "Packages/com.unity.render-pipelines.high-definition/Runtime/RenderPipeline/Lighting/Forward.hlsl" : nothing left in there.
            //#pragma multi_compile LIGHTLOOP_SINGLE_PASS LIGHTLOOP_TILE_PASS
            #define LIGHTLOOP_TILE_PASS
            #pragma multi_compile USE_FPTL_LIGHTLIST USE_CLUSTERED_LIGHTLIST

            #define SHADERPASS SHADERPASS_FORWARD
            // In case of opaque we don't want to perform the alpha test, it is done in depth prepass and we use depth equal for ztest (setup from UI)
            #ifndef _SURFACE_TYPE_TRANSPARENT
                #define SHADERPASS_FORWARD_BYPASS_ALPHA_TEST
            #endif
            #include "Packages/com.unity.render-pipelines.high-definition/Runtime/ShaderLibrary/ShaderVariables.hlsl"
            #ifdef DEBUG_DISPLAY
            #include "Packages/com.unity.render-pipelines.high-definition/Runtime/Debug/DebugDisplay.hlsl"
            #endif
            #include "Packages/com.unity.render-pipelines.high-definition/Runtime/Lighting/Lighting.hlsl"
            //...this will include #include "Packages/com.unity.render-pipelines.high-definition/Runtime/Material/Material.hlsl" but also LightLoop which the forward pass directly uses.

            #include "ShaderPass/IridescenceSharePass.hlsl"
            #include "IridescenceData.hlsl"
            #include "Packages/com.unity.render-pipelines.high-definition/Runtime/RenderPipeline/ShaderPass/ShaderPassForward.hlsl"

            ENDHLSL
        }

    }

    // CustomEditor "Experimental.Rendering.HDPipeline.IridescenceGUI"
}
