$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$root = "E:\Games\mod\src\main\java\com\example\shinobicore"

# ============================================================
# 1. REWRITE: ShurikenRenderer.java - 4-blade star + metallic look
# ============================================================
$srPath = "$root\entity\ShurikenRenderer.java"
$srContent = @'
package com.example.shinobicore.entity;

import net.minecraft.client.render.OverlayTexture;
import net.minecraft.client.render.RenderLayer;
import net.minecraft.client.render.VertexConsumer;
import net.minecraft.client.render.VertexConsumerProvider;
import net.minecraft.client.render.entity.EntityRenderer;
import net.minecraft.client.render.entity.EntityRendererFactory;
import net.minecraft.client.util.math.MatrixStack;
import net.minecraft.util.Identifier;
import net.minecraft.util.math.RotationAxis;
import org.joml.Matrix4f;

/**
 * Renders shuriken as a proper 4-blade throwing star.
 * Each blade is a flat quad rotated 90 degrees apart.
 * Metallic grey with dark center hole.
 */
public class ShurikenRenderer extends EntityRenderer<ShurikenEntity> {
    private static final Identifier TEX = new Identifier("textures/misc/white.png");

    // Metallic colors
    private static final float BLADE_R = 0.82f, BLADE_G = 0.82f, BLADE_B = 0.86f;
    private static final float EDGE_R = 0.95f, EDGE_G = 0.95f, EDGE_B = 0.98f;
    private static final float HUB_R = 0.35f, HUB_G = 0.35f, HUB_B = 0.38f;

    public ShurikenRenderer(EntityRendererFactory.Context ctx) { super(ctx); }

    @Override
    public void render(ShurikenEntity entity, float yaw, float tickDelta,
                       MatrixStack matrices, VertexConsumerProvider vc, int light) {
        super.render(entity, yaw, tickDelta, matrices, vc, light);
        matrices.push();
        matrices.translate(0, 0.12, 0);

        if (!entity.isStuck()) {
            // Spinning in flight
            matrices.multiply(RotationAxis.POSITIVE_Y.rotationDegrees((entity.getAge() + tickDelta) * 25f));
            matrices.multiply(RotationAxis.POSITIVE_X.rotationDegrees(90));
        } else {
            // Stuck in block - slight tilt, no spin
            matrices.multiply(RotationAxis.POSITIVE_X.rotationDegrees(75));
        }

        VertexConsumer consumer = vc.getBuffer(RenderLayer.getEntityTranslucent(TEX));

        // === 4 BLADES ===
        float bladeLen = 0.24f;   // length from center to tip
        float bladeW   = 0.07f;   // half-width at base
        float tipW     = 0.015f;  // half-width at tip (narrow point)

        for (int i = 0; i < 4; i++) {
            matrices.push();
            matrices.multiply(RotationAxis.POSITIVE_Z.rotationDegrees(i * 90f));
            Matrix4f m = matrices.peek().getPositionMatrix();

            // Blade shape: trapezoid (wide at hub, narrow at tip)
            // Front face
            bladeVertex(consumer, m, -bladeW, 0, 0.02f,  BLADE_R, BLADE_G, BLADE_B, light);
            bladeVertex(consumer, m, -tipW,  0, bladeLen, EDGE_R, EDGE_G, EDGE_B, light);
            bladeVertex(consumer, m,  tipW,  0, bladeLen, EDGE_R, EDGE_G, EDGE_B, light);
            bladeVertex(consumer, m,  bladeW, 0, 0.02f,  BLADE_R, BLADE_G, BLADE_B, light);
            // Back face (reversed winding)
            bladeVertex(consumer, m,  bladeW, 0, 0.02f,  BLADE_R, BLADE_G, BLADE_B, light);
            bladeVertex(consumer, m,  tipW,  0, bladeLen, EDGE_R, EDGE_G, EDGE_B, light);
            bladeVertex(consumer, m, -tipW,  0, bladeLen, EDGE_R, EDGE_G, EDGE_B, light);
            bladeVertex(consumer, m, -bladeW, 0, 0.02f,  BLADE_R, BLADE_G, BLADE_B, light);

            matrices.pop();
        }

        // === CENTER HUB (dark square) ===
        float hub = 0.045f;
        Matrix4f mH = matrices.peek().getPositionMatrix();
        bladeVertex(consumer, mH, -hub, 0, -hub, HUB_R, HUB_G, HUB_B, light);
        bladeVertex(consumer, mH, -hub, 0,  hub, HUB_R, HUB_G, HUB_B, light);
        bladeVertex(consumer, mH,  hub, 0,  hub, HUB_R, HUB_G, HUB_B, light);
        bladeVertex(consumer, mH,  hub, 0, -hub, HUB_R, HUB_G, HUB_B, light);
        // Back
        bladeVertex(consumer, mH,  hub, 0, -hub, HUB_R, HUB_G, HUB_B, light);
        bladeVertex(consumer, mH,  hub, 0,  hub, HUB_R, HUB_G, HUB_B, light);
        bladeVertex(consumer, mH, -hub, 0,  hub, HUB_R, HUB_G, HUB_B, light);
        bladeVertex(consumer, mH, -hub, 0, -hub, HUB_R, HUB_G, HUB_B, light);

        matrices.pop();
    }

    private void bladeVertex(VertexConsumer c, Matrix4f m, float x, float y, float z,
                             float r, float g, float b, int light) {
        c.vertex(m, x, y, z)
         .color(r, g, b, 1.0f)
         .texture(0.5f, 0.5f)
         .overlay(OverlayTexture.DEFAULT_UV)
         .light(light)
         .normal(0, 1, 0)
         .next();
    }

    @Override
    public Identifier getTexture(ShurikenEntity entity) { return TEX; }
}
'@
[System.IO.File]::WriteAllText($srPath, $srContent, $utf8)
Write-Host "[FIX] ShurikenRenderer.java rewritten (4-blade star)"

# ============================================================
# 2. PATCH: ShurikenEntity.java - add trail + stuck on block hit
# ============================================================
$sePath = "$root\entity\ShurikenEntity.java"
$seContent = [System.IO.File]::ReadAllText($sePath, $utf8)
$sentinel = "PHASE_K2_TRAIL_AND_STUCK"

if ($seContent.Contains($sentinel)) {
    Write-Host "[SKIP] ShurikenEntity already patched"
} else {
    # A) Replace block-hit discard with stuck
    $oldBlockHit = @"
if (blockHit.getType() == HitResult.Type.BLOCK) {
if (this.getWorld() instanceof ServerWorld swHit) {
swHit.spawnParticles(ParticleTypes.POOF, this.getX(), this.getY(), this.getZ(), 4, 0.1, 0.1, 0.1, 0.02);
}
this.playSound(SoundEvents.BLOCK_WOOD_HIT, 0.5f, 1.4f);
this.discard();
return;
}
"@
    $newBlockHit = @"
if (blockHit.getType() == HitResult.Type.BLOCK) {
    // PHASE_K2_TRAIL_AND_STUCK
    if (this.getWorld() instanceof ServerWorld swHit) {
        swHit.spawnParticles(ParticleTypes.POOF, this.getX(), this.getY(), this.getZ(), 4, 0.1, 0.1, 0.1, 0.02);
    }
    this.playSound(SoundEvents.BLOCK_WOOD_HIT, 0.5f, 1.4f);
    this.stuck = true;
    this.setVelocity(0, 0, 0);
    this.velocityDirty = true;
    return;
}
"@
    if ($seContent.Contains("this.playSound(SoundEvents.BLOCK_WOOD_HIT, 0.5f, 1.4f);")) {
        $seContent = $seContent.Replace($oldBlockHit, $newBlockHit)
        Write-Host "[FIX] Block hit now sets stuck=true instead of discard"
    } else {
        Write-Host "[WARN] Block hit pattern not found, trying alternative"
    }

    # B) Add trail particles in tick() after movement
    $oldMove = "this.setPosition(this.getX() + vel.x, this.getY() + vel.y, this.getZ() + vel.z);"
    $newMove = @"
this.setPosition(this.getX() + vel.x, this.getY() + vel.y, this.getZ() + vel.z);
     // Trail particles behind the shuriken
     if (this.getWorld() instanceof ServerWorld trailWorld && age % 2 == 0) {
         trailWorld.spawnParticles(ParticleTypes.CRIT,
             this.getX() - vel.x * 0.5, this.getY() - vel.y * 0.5, this.getZ() - vel.z * 0.5,
             1, 0.02, 0.02, 0.02, 0.01);
     }
"@
    if ($seContent.Contains($oldMove)) {
        $seContent = $seContent.Replace($oldMove, $newMove)
        Write-Host "[FIX] Added trail particles"
    } else {
        Write-Host "[WARN] Movement line not found"
    }

    [System.IO.File]::WriteAllText($sePath, $seContent, $utf8)
    Write-Host "[OK] ShurikenEntity.java updated"
}

Write-Host ""
Write-Host "=== PHASE K2 (Steps 1+2) APPLIED ==="
Write-Host "Run: .\gradlew.bat build"