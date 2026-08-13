$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$root = "E:\Games\mod\src\main\java\com\example\shinobicore"
function Write-File($p, $c) { [System.IO.File]::WriteAllText($p, $c, $utf8); Write-Host "[OK] $p" }

# ============ 1. ShurikenEntity: getDamage getter ============
$se = "$root\entity\ShurikenEntity.java"
$c = [System.IO.File]::ReadAllText($se, $utf8)
if ($c.Contains("getDamage()")) { Write-Host "[SKIP] getDamage exists" } else {
    $c = $c.Replace("public boolean isStuck() { return stuck; }",
        "public boolean isStuck() { return stuck; }`n    public float getDamage() { return damage; }")
    Write-File $se $c
}

# ============ 2. REWRITE: ShurikenRenderer (star + kunai) ============
Write-File "$root\entity\ShurikenRenderer.java" @'
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

public class ShurikenRenderer extends EntityRenderer<ShurikenEntity> {
    private static final Identifier TEX = new Identifier("textures/misc/white.png");
    public ShurikenRenderer(EntityRendererFactory.Context ctx) { super(ctx); }

    @Override public void render(ShurikenEntity entity, float yaw, float tickDelta,
            MatrixStack matrices, VertexConsumerProvider vc, int light) {
        super.render(entity, yaw, tickDelta, matrices, vc, light);
        matrices.push();
        matrices.translate(0, 0.25, 0);
        VertexConsumer consumer = vc.getBuffer(RenderLayer.getEntityTranslucent(TEX));
        boolean kunai = entity.getDamage() > 4f;
        if (kunai) {
            if (!entity.isStuck()) matrices.multiply(RotationAxis.POSITIVE_X.rotationDegrees(90));
            renderKunai(consumer, matrices, light);
        } else {
            if (!entity.isStuck()) {
                matrices.multiply(RotationAxis.POSITIVE_Y.rotationDegrees((entity.getAge() + tickDelta) * 25f));
                matrices.multiply(RotationAxis.POSITIVE_X.rotationDegrees(90));
            }
            renderShuriken(consumer, matrices, light);
        }
        matrices.pop();
    }

    private void renderShuriken(VertexConsumer c, MatrixStack matrices, int light) {
        for (int i = 0; i < 4; i++) {
            matrices.push();
            matrices.multiply(RotationAxis.POSITIVE_Y.rotationDegrees(i * 90f));
            Matrix4f m = matrices.peek().getPositionMatrix();
            v(c, m, -0.05f, 0, 0.02f, 0.78f, light);
            v(c, m,  0.05f, 0, 0.02f, 0.78f, light);
            v(c, m,  0.02f, 0, 0.26f, 0.95f, light);
            v(c, m, -0.02f, 0, 0.26f, 0.95f, light);
            v(c, m,  0.05f, 0, 0.02f, 0.78f, light);
            v(c, m, -0.05f, 0, 0.02f, 0.78f, light);
            v(c, m, -0.02f, 0, 0.26f, 0.95f, light);
            v(c, m,  0.02f, 0, 0.26f, 0.95f, light);
            matrices.pop();
        }
        Matrix4f m = matrices.peek().getPositionMatrix();
        v(c, m, -0.045f, 0.001f, -0.045f, 0.25f, light);
        v(c, m,  0.045f, 0.001f, -0.045f, 0.25f, light);
        v(c, m,  0.045f, 0.001f,  0.045f, 0.25f, light);
        v(c, m, -0.045f, 0.001f,  0.045f, 0.25f, light);
    }

    private void renderKunai(VertexConsumer c, MatrixStack matrices, int light) {
        Matrix4f m = matrices.peek().getPositionMatrix();
        // blade diamond (tip / left / inner / right)
        v(c, m, 0, 0.002f, 0.30f, 0.95f, light);
        v(c, m, -0.05f, 0.002f, 0.06f, 0.8f, light);
        v(c, m, 0, 0.002f, 0.02f, 0.7f, light);
        v(c, m, 0.05f, 0.002f, 0.06f, 0.8f, light);
        v(c, m, 0, 0.002f, 0.30f, 0.95f, light);
        v(c, m, 0.05f, 0.002f, 0.06f, 0.8f, light);
        v(c, m, 0, 0.002f, 0.02f, 0.7f, light);
        v(c, m, -0.05f, 0.002f, 0.06f, 0.8f, light);
        // handle
        v(c, m, -0.015f, 0, 0.06f, 0.3f, light);
        v(c, m,  0.015f, 0, 0.06f, 0.3f, light);
        v(c, m,  0.015f, 0, -0.14f, 0.3f, light);
        v(c, m, -0.015f, 0, -0.14f, 0.3f, light);
        v(c, m,  0.015f, 0, 0.06f, 0.3f, light);
        v(c, m, -0.015f, 0, 0.06f, 0.3f, light);
        v(c, m, -0.015f, 0, -0.14f, 0.3f, light);
        v(c, m,  0.015f, 0, -0.14f, 0.3f, light);
        // ring pommel
        v(c, m, -0.035f, 0, -0.14f, 0.5f, light);
        v(c, m,  0.035f, 0, -0.14f, 0.5f, light);
        v(c, m,  0.035f, 0, -0.20f, 0.5f, light);
        v(c, m, -0.035f, 0, -0.20f, 0.5f, light);
    }

    private void v(VertexConsumer c, Matrix4f m, float x, float y, float z, float shade, int light) {
        c.vertex(m, x, y, z).color(shade, shade, shade + 0.03f, 1f).texture(0, 0)
         .overlay(OverlayTexture.DEFAULT_UV).light(light).normal(0, 1, 0).next();
    }

    @Override public Identifier getTexture(ShurikenEntity entity) { return TEX; }
}
'@

# ============ 3. NEW: ThrowAnimations.java ============
$f = "$root\client\combat\ThrowAnimations.java"
if (Test-Path $f) { Write-Host "[SKIP] ThrowAnimations exists" } else {
Write-File $f @'
package com.example.shinobicore.client.combat;

import net.minecraft.client.model.ModelPart;
import net.minecraft.client.network.AbstractClientPlayerEntity;
import net.minecraft.entity.player.PlayerEntity;
import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

public class ThrowAnimations {
    private static final Map<UUID, Long> THROWS = new HashMap<>();
    private static final long DURATION = 260;

    public static void playThrow(PlayerEntity p) {
        THROWS.put(p.getUuid(), System.currentTimeMillis());
    }

    public static boolean isThrowing(AbstractClientPlayerEntity p) {
        Long t = THROWS.get(p.getUuid());
        if (t == null) return false;
        if (System.currentTimeMillis() - t >= DURATION) { THROWS.remove(p.getUuid()); return false; }
        return true;
    }

    public static void apply(AbstractClientPlayerEntity p, ModelPart rArm, ModelPart lArm, ModelPart body, ModelPart head) {
        Long t = THROWS.get(p.getUuid());
        if (t == null) return;
        float pr = Math.min(1f, (System.currentTimeMillis() - t) / (float) DURATION);
        float c;
        if (pr < 0.35f) c = -0.6f * (pr / 0.35f);
        else c = -0.6f + 2.0f * ((pr - 0.35f) / 0.65f);
        rArm.pitch = c;
        rArm.yaw = -0.15f;
        lArm.pitch = -0.4f;
        lArm.yaw = 0.3f;
        body.yaw += -0.15f + 0.3f * pr;
        head.pitch -= 0.05f;
    }
}
'@
}

# ============ 4. ThrowingWeaponItem: client throw trigger ============
$tw = "$root\item\ThrowingWeaponItem.java"
$c = [System.IO.File]::ReadAllText($tw, $utf8)
if ($c.Contains("ThrowAnimations.playThrow")) { Write-Host "[SKIP] throw trigger exists" } else {
    $c = $c.Replace("return TypedActionResult.success(stack, world.isClient());",
        "if (world.isClient) { com.example.shinobicore.client.combat.ThrowAnimations.playThrow(user); }`n        return TypedActionResult.success(stack, world.isClient());")
    Write-File $tw $c
}

# ============ 5. PlayerRenderAnimationMixin: apply throw anim ============
$mx = "$root\mixin\PlayerRenderAnimationMixin.java"
$c = [System.IO.File]::ReadAllText($mx, $utf8)
if ($c.Contains("ThrowAnimations.isThrowing")) { Write-Host "[SKIP] mixin throw hook exists" } else {
    $c = $c.Replace("if (TaijutsuAnimations.isKicking(player)) {",
        "if (com.example.shinobicore.client.combat.ThrowAnimations.isThrowing(player)) {`n            com.example.shinobicore.client.combat.ThrowAnimations.apply(player, rightArm, leftArm, body, head);`n        }`n        if (TaijutsuAnimations.isKicking(player)) {")
    Write-File $mx $c
}

Write-Host "=== BATCH 2 DONE ==="