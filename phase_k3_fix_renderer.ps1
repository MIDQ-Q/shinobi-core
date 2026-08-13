$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$root = "E:\Games\mod\src\main\java\com\example\shinobicore"

# ============================================================
# 1. REWRITE: KatanaBuiltinRenderer.java - use correct Fabric API class
# ============================================================
$krPath = "$root\client\render\KatanaBuiltinRenderer.java"
$krCode = @'
package com.example.shinobicore.client.render;

import net.minecraft.client.render.RenderLayer;
import net.minecraft.client.render.VertexConsumer;
import net.minecraft.client.render.VertexConsumerProvider;
import net.minecraft.client.util.math.MatrixStack;
import net.minecraft.item.ItemStack;
import net.minecraft.client.render.model.json.ModelTransformationMode;
import net.minecraft.util.Identifier;
import net.minecraft.util.math.RotationAxis;
import org.joml.Matrix4f;

/**
 * 3D Katana renderer using cuboids.
 * Static render method for use with Fabric BuiltinItemRendererRegistry.
 */
public class KatanaBuiltinRenderer {
    private static final Identifier WHITE_TEX = new Identifier("textures/misc/white.png");

    // Colors
    private static final float BLADE_R = 0.85f, BLADE_G = 0.87f, BLADE_B = 0.90f;
    private static final float EDGE_R  = 0.95f, EDGE_G  = 0.97f, EDGE_B  = 1.0f;
    private static final float TSUBA_R = 0.60f, TSUBA_G = 0.45f, TSUBA_B = 0.15f;
    private static final float HANDLE_R = 0.25f, HANDLE_G = 0.18f, HANDLE_B = 0.12f;
    private static final float WRAP_R = 0.70f, WRAP_G = 0.15f, WRAP_B = 0.10f;

    public static void render(ItemStack stack, ModelTransformationMode mode, MatrixStack matrices,
                               VertexConsumerProvider vertexConsumers, int light, int overlay) {
        matrices.push();

        // Adjust position based on transform mode
        if (mode == ModelTransformationMode.FIRST_PERSON_RIGHT_HAND ||
            mode == ModelTransformationMode.FIRST_PERSON_LEFT_HAND) {
            matrices.translate(0.56, -0.12, 0.0);
            matrices.multiply(RotationAxis.POSITIVE_Y.rotationDegrees(-15));
            matrices.multiply(RotationAxis.POSITIVE_X.rotationDegrees(10));
        } else if (mode == ModelTransformationMode.THIRD_PERSON_RIGHT_HAND ||
                   mode == ModelTransformationMode.THIRD_PERSON_LEFT_HAND) {
            matrices.translate(0.56, 0.15, 0.05);
            matrices.multiply(RotationAxis.POSITIVE_Y.rotationDegrees(-10));
        } else if (mode == ModelTransformationMode.GROUND) {
            matrices.translate(0.5, 0.25, 0.5);
            matrices.scale(0.5f, 0.5f, 0.5f);
        } else if (mode == ModelTransformationMode.GUI) {
            matrices.translate(0.5, 0.5, 0.0);
            matrices.multiply(RotationAxis.POSITIVE_Z.rotationDegrees(-45));
            matrices.scale(0.65f, 0.65f, 0.65f);
        } else {
            matrices.translate(0.5, 0.5, 0.5);
            matrices.scale(0.5f, 0.5f, 0.5f);
        }

        VertexConsumer vc = vertexConsumers.getBuffer(RenderLayer.getEntityTranslucent(WHITE_TEX));

        // === BLADE (long thin cuboid) ===
        drawCuboid(matrices, vc, light, overlay,
            -0.02f, -0.85f, -0.0075f,
             0.04f,  0.85f,  0.015f,
            BLADE_R, BLADE_G, BLADE_B);

        // === BLADE EDGE (thinner highlight strip) ===
        drawCuboid(matrices, vc, light, overlay,
            -0.025f, -0.85f, -0.002f,
             0.008f,  0.85f,  0.004f,
            EDGE_R, EDGE_G, EDGE_B);

        // === TIP (angled end of blade) ===
        drawCuboid(matrices, vc, light, overlay,
            -0.015f, -0.92f, -0.005f,
             0.03f,   0.07f,  0.01f,
            EDGE_R, EDGE_G, EDGE_B);

        // === TSUBA (crossguard - flat disc) ===
        drawCuboid(matrices, vc, light, overlay,
            -0.06f, 0.0f, -0.06f,
             0.12f, 0.02f, 0.12f,
            TSUBA_R, TSUBA_G, TSUBA_B);

        // === HANDLE (tsuka) ===
        drawCuboid(matrices, vc, light, overlay,
            -0.02f, 0.02f, -0.02f,
             0.04f, 0.28f,  0.04f,
            HANDLE_R, HANDLE_G, HANDLE_B);

        // === WRAP (ito-maki - cord wrapping on handle) ===
        for (int i = 0; i < 4; i++) {
            float yPos = 0.04f + i * 0.065f;
            drawCuboid(matrices, vc, light, overlay,
                -0.025f, yPos, -0.025f,
                 0.05f,  0.02f, 0.05f,
                WRAP_R, WRAP_G, WRAP_B);
        }

        // === KASHIRA (pommel at end of handle) ===
        drawCuboid(matrices, vc, light, overlay,
            -0.025f, 0.30f, -0.025f,
             0.05f,  0.02f,  0.05f,
            TSUBA_R, TSUBA_G, TSUBA_B);

        matrices.pop();
    }

    private static void drawCuboid(MatrixStack matrices, VertexConsumer vc, int light, int overlay,
                            float x, float y, float z,
                            float w, float h, float d,
                            float r, float g, float b) {
        Matrix4f m = matrices.peek().getPositionMatrix();
        float x2 = x + w;
        float y2 = y + h;
        float z2 = z + d;

        // Front face (+Z)
        vertex(vc, m, x,  y,  z2, r, g, b, light, overlay);
        vertex(vc, m, x2, y,  z2, r, g, b, light, overlay);
        vertex(vc, m, x2, y2, z2, r, g, b, light, overlay);
        vertex(vc, m, x,  y2, z2, r, g, b, light, overlay);

        // Back face (-Z)
        vertex(vc, m, x2, y,  z,  r, g, b, light, overlay);
        vertex(vc, m, x,  y,  z,  r, g, b, light, overlay);
        vertex(vc, m, x,  y2, z,  r, g, b, light, overlay);
        vertex(vc, m, x2, y2, z,  r, g, b, light, overlay);

        // Left face (-X)
        vertex(vc, m, x,  y,  z,  r, g, b, light, overlay);
        vertex(vc, m, x,  y,  z2, r, g, b, light, overlay);
        vertex(vc, m, x,  y2, z2, r, g, b, light, overlay);
        vertex(vc, m, x,  y2, z,  r, g, b, light, overlay);

        // Right face (+X)
        vertex(vc, m, x2, y,  z2, r, g, b, light, overlay);
        vertex(vc, m, x2, y,  z,  r, g, b, light, overlay);
        vertex(vc, m, x2, y2, z,  r, g, b, light, overlay);
        vertex(vc, m, x2, y2, z2, r, g, b, light, overlay);

        // Top face (+Y)
        vertex(vc, m, x,  y2, z2, r, g, b, light, overlay);
        vertex(vc, m, x2, y2, z2, r, g, b, light, overlay);
        vertex(vc, m, x2, y2, z,  r, g, b, light, overlay);
        vertex(vc, m, x,  y2, z,  r, g, b, light, overlay);

        // Bottom face (-Y)
        vertex(vc, m, x,  y,  z,  r, g, b, light, overlay);
        vertex(vc, m, x2, y,  z,  r, g, b, light, overlay);
        vertex(vc, m, x2, y,  z2, r, g, b, light, overlay);
        vertex(vc, m, x,  y,  z2, r, g, b, light, overlay);
    }

    private static void vertex(VertexConsumer vc, Matrix4f m,
                        float x, float y, float z,
                        float r, float g, float b,
                        int light, int overlay) {
        vc.vertex(m, x, y, z)
          .color(r, g, b, 1.0f)
          .texture(0, 0)
          .overlay(overlay)
          .light(light)
          .normal(0, 1, 0)
          .next();
    }
}
'@
[System.IO.File]::WriteAllText($krPath, $krCode, $utf8)
Write-Host "[FIX] Rewrote KatanaBuiltinRenderer.java with correct API"

# ============================================================
# 2. PATCH: ShinobiCoreClient.java - fix import and registration
# ============================================================
$sccPath = "$root\client\ShinobiCoreClient.java"
$sccContent = [System.IO.File]::ReadAllText($sccPath, $utf8)

# Fix import: replace wrong class name with correct one
$sccContent = $sccContent.Replace(
    "import net.fabricmc.fabric.api.client.rendering.v1.BuiltinModelItemRendererRegistry;",
    "import net.fabricmc.fabric.api.client.rendering.v1.BuiltinItemRendererRegistry;"
)

# Fix registration line: use INSTANCE and method reference
$sccContent = $sccContent.Replace(
    "BuiltinModelItemRendererRegistry.register(com.example.shinobicore.item.ModItems.KATANA, new KatanaBuiltinRenderer());",
    "BuiltinItemRendererRegistry.INSTANCE.register(com.example.shinobicore.item.ModItems.KATANA, com.example.shinobicore.client.render.KatanaBuiltinRenderer::render);"
)

# Also fix import of KatanaBuiltinRenderer (remove if it was a class import)
$sccContent = $sccContent.Replace(
    "import com.example.shinobicore.client.render.KatanaBuiltinRenderer;",
    "// import not needed - using static method reference"
)

[System.IO.File]::WriteAllText($sccPath, $sccContent, $utf8)
Write-Host "[FIX] Updated ShinobiCoreClient.java with correct Fabric API names"

Write-Host ""
Write-Host "=== FIX APPLIED ==="
Write-Host "Run: .\gradlew.bat build"