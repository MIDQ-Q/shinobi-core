$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$base = "E:\Games\mod\src\main"

function Write-File($p, $c) {
    $dir = [System.IO.Path]::GetDirectoryName($p)
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [System.IO.File]::WriteAllText($p, $c, $utf8)
    Write-Host "[OK] $p"
}

Write-Host "=== PHASE G3: 3D PROJECTILE RENDERERS ==="

# 1. Enhanced NinjaProjectileRenderer with 3D Rasengan Ring and Fireball Pulse
$rendererPath = "$base\java\com\example\shinobicore\entity\NinjaProjectileRenderer.java"
$rendererCode = @'
package com.example.shinobicore.entity;

import net.minecraft.client.render.OverlayTexture;
import net.minecraft.client.render.RenderLayer;
import net.minecraft.client.render.VertexConsumer;
import net.minecraft.client.render.VertexConsumerProvider;
import net.minecraft.client.render.entity.EntityRenderer;
import net.minecraft.client.render.entity.EntityRendererFactory;
import net.minecraft.client.util.math.MatrixStack;
import net.minecraft.util.Identifier;
import net.minecraft.util.math.MathHelper;
import net.minecraft.util.math.RotationAxis;
import org.joml.Matrix4f;

public class NinjaProjectileRenderer extends EntityRenderer<NinjaProjectileEntity> {
    private static final Identifier WHITE_TEXTURE = new Identifier("textures/misc/white.png");
    private static final Identifier LAVA_TEXTURE = new Identifier("textures/block/lava_still.png");
    private static final Identifier WATER_TEXTURE = new Identifier("textures/block/water_still.png");

    public NinjaProjectileRenderer(EntityRendererFactory.Context ctx) {
        super(ctx);
    }

    @Override
    public void render(NinjaProjectileEntity entity, float yaw, float tickDelta,
                       MatrixStack matrices, VertexConsumerProvider vertexConsumers, int light) {
        super.render(entity, yaw, tickDelta, matrices, vertexConsumers, light);
        float radius = entity.getRadius() * 0.25f;
        if (radius < 0.1f) radius = 0.1f;
        String particle = entity.getParticleType();
        
        matrices.push();
        matrices.translate(0, entity.getHeight() / 2.0, 0);
        
        // Use system time for smooth animation independent of entity age
        float animTime = (float)(System.currentTimeMillis() % 10000) / 50.0f;

        if ("rasengan".equals(particle)) {
            renderRasengan(matrices, vertexConsumers, radius, light, animTime);
        } else if ("fireball".equals(particle) || "flame".equals(particle)) {
            renderFireball(matrices, vertexConsumers, radius, light, animTime);
        } else {
            Identifier texture = getTextureForParticle(particle);
            int innerColor = getInnerColor(particle);
            int outerColor = getOuterColor(particle);
            renderSphereQuads(matrices, vertexConsumers, radius, innerColor, light, texture);
            renderSphereQuads(matrices, vertexConsumers, radius * 1.4f, outerColor, light, WHITE_TEXTURE);
        }
        
        matrices.pop();
    }

    private void renderRasengan(MatrixStack matrices, VertexConsumerProvider vc, float radius, int light, float age) {
        // Core sphere
        renderSphereQuads(matrices, vc, radius, 0xFF44AAFF, light, WHITE_TEXTURE);
        
        // Rotating Rings (Torus approximation)
        matrices.push();
        float rotation = age * 20.0f; // Fast rotation
        for (int i = 0; i < 3; i++) {
            matrices.push();
            matrices.multiply(RotationAxis.POSITIVE_Y.rotationDegrees(rotation + i * 60f));
            matrices.multiply(RotationAxis.POSITIVE_X.rotationDegrees(90f));
            renderRing(matrices, vc, radius * 1.6f, 0.08f, 0xCCFFFFFF, light);
            matrices.pop();
        }
        // Outer glow
        renderSphereQuads(matrices, vc, radius * 1.8f, 0x4488DDFF, light, WHITE_TEXTURE);
        matrices.pop();
    }

    private void renderFireball(MatrixStack matrices, VertexConsumerProvider vc, float radius, int light, float age) {
        // Pulsing effect
        float pulse = 1.0f + MathHelper.sin(age * 0.5f) * 0.15f;
        float r = radius * pulse;
        
        // Core (Lava texture)
        renderSphereQuads(matrices, vc, r, 0xFFFFFFFF, light, LAVA_TEXTURE);
        // Outer glow
        renderSphereQuads(matrices, vc, r * 1.5f, 0x88FF4400, light, WHITE_TEXTURE);
    }

    private void renderRing(MatrixStack matrices, VertexConsumerProvider vc, float radius, float thickness, int color, int light) {
        VertexConsumer consumer = vc.getBuffer(RenderLayer.getEntityTranslucent(WHITE_TEXTURE));
        Matrix4f m = matrices.peek().getPositionMatrix();
        float r = ((color >> 16) & 0xFF) / 255f;
        float g = ((color >> 8) & 0xFF) / 255f;
        float b = (color & 0xFF) / 255f;
        float a = ((color >> 24) & 0xFF) / 255f;
        
        int segments = 24;
        for (int i = 0; i < segments; i++) {
            float angle1 = (float)(i * 2 * Math.PI / segments);
            float angle2 = (float)((i + 1) * 2 * Math.PI / segments);
            float x1 = MathHelper.cos(angle1) * radius;
            float z1 = MathHelper.sin(angle1) * radius;
            float x2 = MathHelper.cos(angle2) * radius;
            float z2 = MathHelper.sin(angle2) * radius;
            
            consumer.vertex(m, x1, -thickness, z1).color(r, g, b, a).texture(0, 0).overlay(OverlayTexture.DEFAULT_UV).light(light).normal(0, 1, 0).next();
            consumer.vertex(m, x2, -thickness, z2).color(r, g, b, a).texture(1, 0).overlay(OverlayTexture.DEFAULT_UV).light(light).normal(0, 1, 0).next();
            consumer.vertex(m, x2, thickness, z2).color(r, g, b, a).texture(1, 1).overlay(OverlayTexture.DEFAULT_UV).light(light).normal(0, 1, 0).next();
            consumer.vertex(m, x1, thickness, z1).color(r, g, b, a).texture(0, 1).overlay(OverlayTexture.DEFAULT_UV).light(light).normal(0, 1, 0).next();
        }
    }

    private Identifier getTextureForParticle(String particle) {
        if ("fire".equals(particle) || "flame".equals(particle) || "fireball".equals(particle)) return LAVA_TEXTURE;
        if ("water".equals(particle)) return WATER_TEXTURE;
        return WHITE_TEXTURE;
    }

    private int getInnerColor(String particle) {
        if ("fire".equals(particle) || "flame".equals(particle) || "fireball".equals(particle)) return 0xFFFFFFFF;
        if ("water".equals(particle)) return 0xFFFFFFFF;
        if ("lightning".equals(particle)) return 0xFFFFFF44;
        if ("wind".equals(particle)) return 0xFFDDDDDD;
        if ("earth".equals(particle)) return 0xFF996633;
        if ("smoke".equals(particle)) return 0xFF888888;
        return 0xFFFF6600;
    }

    private int getOuterColor(String particle) {
        if ("fire".equals(particle) || "flame".equals(particle) || "fireball".equals(particle)) return 0x66FF4400;
        if ("water".equals(particle)) return 0x662266FF;
        if ("lightning".equals(particle)) return 0x66FFFF00;
        if ("wind".equals(particle)) return 0x66CCCCCC;
        if ("earth".equals(particle)) return 0x66774422;
        if ("smoke".equals(particle)) return 0x66666666;
        return 0x66FF4400;
    }

    private void renderSphereQuads(MatrixStack matrices, VertexConsumerProvider vc,
                                   float size, int color, int light, Identifier texture) {
        VertexConsumer consumer = vc.getBuffer(RenderLayer.getEntityTranslucent(texture));
        float r = ((color >> 16) & 0xFF) / 255f;
        float g = ((color >> 8) & 0xFF) / 255f;
        float b = (color & 0xFF) / 255f;
        float a = ((color >> 24) & 0xFF) / 255f;
        float half = size;

        for (int i = 0; i < 3; i++) {
            float angle = i * 60f;
            matrices.push();
            matrices.multiply(RotationAxis.POSITIVE_Y.rotationDegrees(angle));
            Matrix4f m = matrices.peek().getPositionMatrix();
            emitQuad(consumer, m, -half, -half, 0, half, -half, 0, half, half, 0, -half, half, 0, r, g, b, a, light);
            matrices.pop();
        }
        
        matrices.push();
        matrices.multiply(RotationAxis.POSITIVE_X.rotationDegrees(90));
        Matrix4f mH = matrices.peek().getPositionMatrix();
        emitQuad(consumer, mH, -half, -half, 0, half, -half, 0, half, half, 0, -half, half, 0, r, g, b, a, light);
        matrices.pop();

        for (int i = 0; i < 2; i++) {
            float yAngle = i * 90f;
            matrices.push();
            matrices.multiply(RotationAxis.POSITIVE_Y.rotationDegrees(yAngle));
            matrices.multiply(RotationAxis.POSITIVE_X.rotationDegrees(45));
            Matrix4f mD = matrices.peek().getPositionMatrix();
            emitQuad(consumer, mD, -half, -half, 0, half, -half, 0, half, half, 0, -half, half, 0, r, g, b, a, light);
            matrices.pop();
        }
    }

    private void emitQuad(VertexConsumer consumer, Matrix4f matrix,
                          float x1, float y1, float z1, float x2, float y2, float z2,
                          float x3, float y3, float z3, float x4, float y4, float z4,
                          float r, float g, float b, float a, int light) {
        vertex(consumer, matrix, x1, y1, z1, 0, 1, r, g, b, a, light);
        vertex(consumer, matrix, x2, y2, z2, 1, 1, r, g, b, a, light);
        vertex(consumer, matrix, x3, y3, z3, 1, 0, r, g, b, a, light);
        vertex(consumer, matrix, x4, y4, z4, 0, 0, r, g, b, a, light);
        vertex(consumer, matrix, x2, y2, z2, 0, 1, r, g, b, a, light);
        vertex(consumer, matrix, x1, y1, z1, 1, 1, r, g, b, a, light);
        vertex(consumer, matrix, x4, y4, z4, 1, 0, r, g, b, a, light);
        vertex(consumer, matrix, x3, y3, z3, 0, 0, r, g, b, a, light);
    }

    private void vertex(VertexConsumer consumer, Matrix4f matrix,
                        float x, float y, float z, float u, float v,
                        float r, float g, float b, float a, int light) {
        consumer.vertex(matrix, x, y, z)
                .color(r, g, b, a)
                .texture(u, v)
                .overlay(OverlayTexture.DEFAULT_UV)
                .light(light)
                .normal(0, 1, 0)
                .next();
    }

    @Override
    public Identifier getTexture(NinjaProjectileEntity entity) {
        return getTextureForParticle(entity.getParticleType());
    }
}
'@
Write-File $rendererPath $rendererCode

# 2. Update JSONs to trigger the new 3D particle types
Write-Host "[OK] Updating Rasengan and Fireball JSONs..."

$rasenganJson = @'
{
  "id": "shinobicore:rasengan",
  "name": "Rasengan",
  "category": "shape_ninjutsu",
  "type": "custom",
  "behaviorClass": "com.example.shinobicore.jutsu.custom.RasenganBehavior",
  "params": {
    "baseChargeTicks": 10,
    "minChargeTicks": 4,
    "dashDistance": 6.0,
    "hitRadius": 2.5,
    "knockback": 3.5,
    "particleCount": 60,
    "particle": "rasengan"
  },
  "baseCost": 80,
  "baseDamage": 32,
  "strain": 15,
  "requiredUsesForFullProficiency": 100,
  "requirements": {
    "control": 30,
    "ninjutsu": 30
  }
}
'@
Write-File "$base\resources\data\shinobicore\jutsu\rasengan.json" $rasenganJson

$fireballJson = @'
{
  "id": "shinobicore:fire_release_great_fireball",
  "name": "Fire Release: Great Fireball Jutsu",
  "category": "elemental_ninjutsu",
  "nature": "fire",
  "type": "projectile",
  "params": {
    "speed": 1.5,
    "radius": 8.0,
    "particle": "fireball",
    "lifetime": 100,
    "gravity": false
  },
  "baseCost": 30,
  "baseDamage": 10,
  "strain": 8,
  "requiredUsesForFullProficiency": 50,
  "requirements": {
    "control": 15,
    "nature_fire": 20,
    "ninjutsu": 10
  }
}
'@
Write-File "$base\resources\data\shinobicore\jutsu\fire_release_great_fireball.json" $fireballJson

Write-Host "=== PHASE G3 COMPLETE ==="
Write-Host "Run: .\gradlew.bat build"
Write-Host "Run: .\gradlew.bat runClient"