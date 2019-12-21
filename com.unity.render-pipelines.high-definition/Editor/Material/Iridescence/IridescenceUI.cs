using System;
using UnityEngine;
using UnityEngine.Rendering.HighDefinition;
using UnityEngine.Rendering;

namespace UnityEditor.Rendering.HighDefinition
{
    public class IridescenceGUI : ShaderGUI
    {
        protected static class Styles
        {
            public static GUIContent surfaceTypeText = new GUIContent("Surface Type");
            public static GUIContent screenSpaceTransmissionText = new GUIContent("Screen Space Transmission");
            public static GUIContent doubleSidedEnableText = new GUIContent("Double Sided");
            public static GUIContent doubleSidedNormalModeText = new GUIContent("Normal Mode", "This will modify the normal base on the selected mode. Mirror: Mirror the normal with vertex normal plane, Flip: Flip the normal");
        }

        public enum SurfaceType
        {
            Opaque,
            Transparent
        }

        public enum DoubleSidedNormalMode
        {
            Flip,
            Mirror,
            None
        }

        protected MaterialEditor m_MaterialEditor;

        protected MaterialProperty surfaceType = null;
        protected const string kSurfaceType = "_SurfaceType";
        // protected MaterialProperty transparentBackfaceEnable = null;
        // protected const string kTransparentBackfaceEnable = "_TransparentBackfaceEnable";

        protected MaterialProperty screenSpaceTransmission = null;
        protected const string kScreenSpaceTransmission = "_ScreenSpaceTransmission";

        // Double Sided
        protected MaterialProperty doubleSidedEnable = null;
        protected const string kDoubleSidedEnable = "_DoubleSidedEnable";
        protected MaterialProperty doubleSidedNormalMode = null;
        protected const string kDoubleSidedNormalMode = "_DoubleSidedNormalMode";
        protected MaterialProperty doubleSidedConstants = null;
        protected const string kDoubleSidedConstants = "_DoubleSidedConstants";


        // Blend State
        protected MaterialProperty cullMode = null;
        protected const string kCullMode = "_CullMode";
        protected MaterialProperty srcBlend = null;
        protected const string kSrcBlend = "_SrcBlend";
        protected MaterialProperty dstBlend = null;
        protected const string kDstBlend = "_DstBlend";


        protected void FindProperties(MaterialProperty[] props)
        {
            surfaceType = FindProperty(kSurfaceType, props, false);

            screenSpaceTransmission = FindProperty(kScreenSpaceTransmission, props, false);

            doubleSidedEnable = FindProperty(kDoubleSidedEnable, props, false);
            doubleSidedNormalMode = FindProperty(kDoubleSidedNormalMode, props, false);
            doubleSidedConstants = FindProperty(kDoubleSidedConstants, props, false);

            cullMode = FindProperty(kCullMode, props, false);
            srcBlend = FindProperty(kSrcBlend, props, false);
            dstBlend = FindProperty(kDstBlend, props, false);
        }

        void SurfaceTypePopup()
        {
            if (surfaceType == null)
                return;

            EditorGUI.showMixedValue = surfaceType.hasMixedValue;
            var mode = (SurfaceType)surfaceType.floatValue;

            EditorGUI.BeginChangeCheck();
            mode = (SurfaceType)EditorGUILayout.EnumPopup(Styles.surfaceTypeText, mode);
            if (EditorGUI.EndChangeCheck())
            {
                m_MaterialEditor.RegisterPropertyChangeUndo("Surface Type");
                surfaceType.floatValue = (float)mode;
            }

            EditorGUI.showMixedValue = false;
        }

        void DoubleSidedNormalModePopup()
        {
            if (doubleSidedNormalMode == null)
                return;

            EditorGUI.showMixedValue = surfaceType.hasMixedValue;
            var mode = (DoubleSidedNormalMode)doubleSidedNormalMode.floatValue;

            EditorGUI.BeginChangeCheck();
            mode = (DoubleSidedNormalMode)EditorGUILayout.EnumPopup(Styles.doubleSidedNormalModeText, mode);
            if (EditorGUI.EndChangeCheck())
            {
                m_MaterialEditor.RegisterPropertyChangeUndo("Double Sided Normal Mode");
                doubleSidedNormalMode.floatValue = (float)mode;
            }

            EditorGUI.showMixedValue = false;
        }

        protected void DoIridescenceGUI(Material material)
        {
            // TODO
        }

        protected void ShaderPropertiesGUI(Material material)
        {
            // Use default labelWidth
            EditorGUIUtility.labelWidth = 0f;

            // Detect any changes to the material
            EditorGUI.BeginChangeCheck();
            {
                SurfaceTypePopup();

                var mode = (SurfaceType)surfaceType.floatValue;
                if (mode == SurfaceType.Transparent)
                {
                    m_MaterialEditor.ShaderProperty(screenSpaceTransmission, Styles.screenSpaceTransmissionText);
                }

                m_MaterialEditor.ShaderProperty(doubleSidedEnable, Styles.doubleSidedEnableText);

                if (doubleSidedEnable.floatValue > 0.0f)
                {
                    EditorGUI.indentLevel++;
                    DoubleSidedNormalModePopup();
                    EditorGUI.indentLevel--;
                }

                // DoIridescenceGUI(material);
            }

            if (EditorGUI.EndChangeCheck())
            {
                foreach (var obj in m_MaterialEditor.targets)
                    SetupMaterialKeywordsAndPass((Material)obj);
            }
        }

        public override void AssignNewShaderToMaterial(Material material, Shader oldShader, Shader newShader)
        {
            base.AssignNewShaderToMaterial(material, oldShader, newShader);

            SetupMaterialKeywordsAndPass(material);
        }

        // This is called by the inspector
        public override void OnGUI(MaterialEditor materialEditor, MaterialProperty[] props)
        {
            m_MaterialEditor = materialEditor;
            // We should always do this call at the beginning
            m_MaterialEditor.serializedObject.Update();

            // MaterialProperties can be animated so we do not cache them but fetch them every event to ensure animated values are updated correctly
            FindProperties(props);

            Material material = materialEditor.target as Material;
            ShaderPropertiesGUI(material);


            // Show default GUI as well
            base.OnGUI(materialEditor, props);


            // We should always do this call at the end
            m_MaterialEditor.serializedObject.ApplyModifiedProperties();
        }

        // All Setup Keyword functions must be static. It allow to create script to automatically update the shaders with a script if code change
        static public void SetupMaterialKeywordsAndPass(Material material)
        {
            SurfaceType surfaceType = material.HasProperty(kSurfaceType) ? (SurfaceType)material.GetFloat(kSurfaceType) : SurfaceType.Opaque;
            CoreUtils.SetKeyword(material, "_SURFACE_TYPE_TRANSPARENT", surfaceType == SurfaceType.Transparent);

            bool doubleSidedEnable = material.HasProperty(kDoubleSidedEnable) && material.GetFloat(kDoubleSidedEnable) > 0.0f;
            CoreUtils.SetKeyword(material, "_DOUBLESIDED_ON", doubleSidedEnable);

            bool screenSpaceTransmission = material.HasProperty(kScreenSpaceTransmission) && material.GetFloat(kScreenSpaceTransmission) > 0.0f;

            switch (surfaceType)
            {
                case SurfaceType.Opaque:
                {
                    material.SetOverrideTag("RenderType", "");
                    material.SetInt("_ZWrite", 1);
                    material.renderQueue = (int)HDRenderQueue.Priority.Opaque;

                    material.SetInt("_SrcBlend", (int)UnityEngine.Rendering.BlendMode.One);
                    material.SetInt("_DstBlend", (int)UnityEngine.Rendering.BlendMode.Zero);

                    // Disable culling if double sided
                    material.SetInt("_CullMode", doubleSidedEnable ? (int)UnityEngine.Rendering.CullMode.Off : (int)UnityEngine.Rendering.CullMode.Back);
                } break;
                case SurfaceType.Transparent:
                {
                    material.SetOverrideTag("RenderType", "Transparent");
                    material.SetInt("_ZWrite", 0);
                    material.renderQueue = (int)HDRenderQueue.Priority.Transparent; // + (int)material.GetFloat(kTransparentSortPriority);

                    material.SetInt("_SrcBlend", (int)UnityEngine.Rendering.BlendMode.One);
                    material.SetInt("_DstBlend", screenSpaceTransmission ? (int) UnityEngine.Rendering.BlendMode.Zero : (int)UnityEngine.Rendering.BlendMode.One);

                    // Enable TransparentBackface pass if material is double sided
                    material.SetShaderPassEnabled(HDShaderPassNames.s_TransparentBackfaceStr, doubleSidedEnable);

                    // Always cull backfaces
                    material.SetInt("_CullMode", (int)UnityEngine.Rendering.CullMode.Back);
                } break;
            }

        }
    }
} // namespace UnityEditor

/*

- SurfaceType
    - Opaque
    - Transparent
        - Transmission
            - White
            - Iridescent Grey
            - Iridescent Sky Box
    - Transparent Sphere
        -- TODO

- [ ] Double Sided
    - Normal Mode
        - Flip
        - Mirror

*/
