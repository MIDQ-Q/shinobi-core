$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$root = "E:\Games\mod\src\main\java\com\example\shinobicore"
function Write-File($p, $c) { [System.IO.File]::WriteAllText($p, $c, $utf8); Write-Host "[OK] $p" }

# ============ 1. KATANA RENDERER: orientation fix ============
$kr = "$root\client\render\KatanaBuiltinRenderer.java"
$code = @'
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

public class KatanaBuiltinRenderer {
    private static final Identifier TEX = new Identifier("textures/misc/white.png");

    public static void render(ItemStack stack, ModelTransformationMode mode, MatrixStack matrices,
                              VertexConsumerProvider vertexConsumers, int light, int overlay) {
        matrices.push();
        VertexConsumer vc = vertexConsumers.getBuffer(RenderLayer.getEntityTranslucent(TEX));

        if (mode == ModelTransformationMode.GUI) {
            matrices.translate(0.5, 0.4, 0.0);
            matrices.multiply(RotationAxis.POSITIVE_Z.rotationDegrees(135));
            matrices.scale(0.62f, 0.62f, 0.62f);
        } else if (mode == ModelTransformationMode.GROUND) {
            matrices.translate(0.5, 0.05, 0.5);
            matrices.multiply(RotationAxis.POSITIVE_X.rotationDegrees(90));
            matrices.scale(0.9f, 0.9f, 0.9f);
        } else if (mode == ModelTransformationMode.FIXED) {
            matrices.translate(0.0, -0.17, 0.0);
            matrices.multiply(RotationAxis.POSITIVE_Z.rotationDegrees(180));
            matrices.scale(0.8f, 0.8f, 0.8f);
        } else {
            // FIRST/THIRD person hands: grip at handle, blade UP
            matrices.translate(0.0, -0.17, 0.0);
            matrices.multiply(RotationAxis.POSITIVE_Z.rotationDegrees(180));
        }

        // BLADE
        cuboid(matrices, vc, light, overlay, -0.02f, -0.85f, -0.0075f, 0.04f, 0.85f, 0.015f, 0.85f, 0.87f, 0.90f);
        // EDGE highlight
        cuboid(matrices, vc, light, overlay, -0.026f, -0.85f, -0.002f, 0.008f, 0.85f, 0.004f, 0.95f, 0.97f, 1.0f);
        // TIP
        cuboid(matrices, vc, light, overlay, -0.015f, -0.92f, -0.005f, 0.03f, 0.07f, 0.01f, 0.95f, 0.97f, 1.0f);
        // TSUBA (guard)
        cuboid(matrices, vc, light, overlay, -0.06f, 0.0f, -0.06f, 0.12f, 0.02f, 0.12f, 0.60f, 0.45f, 0.15f);
        // HANDLE
        cuboid(matrices, vc, light, overlay, -0.02f, 0.02f, -0.02f, 0.04f, 0.28f, 0.04f, 0.25f, 0.18f, 0.12f);
        // WRAP bands
        for (int i = 0; i < 4; i++) {
            float y = 0.04f + i * 0.065f;
            cuboid(matrices, vc, light, overlay, -0.025f, y, -0.025f, 0.05f, 0.02f, 0.05f, 0.70f, 0.15f, 0.10f);
        }
        // KASHIRA (pommel)
        cuboid(matrices, vc, light, overlay, -0.025f, 0.30f, -0.025f, 0.05f, 0.02f, 0.05f, 0.60f, 0.45f, 0.15f);

        matrices.pop();
    }

    private static void cuboid(MatrixStack matrices, VertexConsumer vc, int light, int overlay,
                               float x, float y, float z, float w, float h, float d,
                               float r, float g, float b) {
        Matrix4f m = matrices.peek().getPositionMatrix();
        float x2 = x + w, y2 = y + h, z2 = z + d;
        face(vc, m, x, y, z2, x2, y, z2, x2, y2, z2, x, y2, z2, r, g, b, light, overlay);
        face(vc, m, x2, y, z, x, y, z, x, y2, z, x2, y2, z, r, g, b, light, overlay);
        face(vc, m, x, y, z, x, y, z2, x, y2, z2, x, y2, z, r, g, b, light, overlay);
        face(vc, m, x2, y, z2, x2, y, z, x2, y2, z, x2, y2, z2, r, g, b, light, overlay);
        face(vc, m, x, y2, z2, x2, y2, z2, x2, y2, z, x, y2, z, r, g, b, light, overlay);
        face(vc, m, x, y, z, x2, y, z, x2, y, z2, x, y, z2, r, g, b, light, overlay);
    }

    private static void face(VertexConsumer vc, Matrix4f m,
                             float x1, float y1, float z1, float x2, float y2, float z2,
                             float x3, float y3, float z3, float x4, float y4, float z4,
                             float r, float g, float b, int light, int overlay) {
        v(vc, m, x1, y1, z1, r, g, b, light, overlay);
        v(vc, m, x2, y2, z2, r, g, b, light, overlay);
        v(vc, m, x3, y3, z3, r, g, b, light, overlay);
        v(vc, m, x4, y4, z4, r, g, b, light, overlay);
        v(vc, m, x4, y4, z4, r, g, b, light, overlay);
        v(vc, m, x3, y3, z3, r, g, b, light, overlay);
        v(vc, m, x2, y2, z2, r, g, b, light, overlay);
        v(vc, m, x1, y1, z1, r, g, b, light, overlay);
    }

    private static void v(VertexConsumer vc, Matrix4f m, float x, float y, float z,
                          float r, float g, float b, int light, int overlay) {
        vc.vertex(m, x, y, z).color(r, g, b, 1.0f).texture(0, 0)
          .overlay(overlay).light(light).normal(0, 1, 0).next();
    }
}
'@
Write-File $kr $code

# ============ 2. DEFLECT: cooldown only for tap (fix 50/50) ============
$kd = "$root\mixin\KatanaDeflectMixin.java"
$c = [System.IO.File]::ReadAllText($kd, $utf8)
$c = $c.Replace("if (now - data.getLastDeflectReflectMs() < 200) return;", "// cooldown moved below (shield ignores it)")
$c = $c.Replace("boolean isSeiganShield = holdActive && stance == KenjutsuStance.SEIGAN;",
"boolean isSeiganShield = holdActive && stance == KenjutsuStance.SEIGAN;`n        if (!isSeiganShield && now - data.getLastDeflectReflectMs() < 200) return;")
Write-File $kd $c

# ============ 3. SEIGAN SLOW: duration 5 -> 25 ============
$nt = "$root\event\NinjaTickHandler.java"
$c = [System.IO.File]::ReadAllText($nt, $utf8)
$c = $c.Replace("StatusEffects.SLOWNESS, 5, 2, false, false, false", "StatusEffects.SLOWNESS, 25, 2, false, false, false")

# ============ 4. RASENGAN DISSIPATE (30s) ============
$ras = @"
// === RASENGAN DISSIPATE ===
if (data.isRasenganReady()) {
    data.setRasenganReadyTicks(data.getRasenganReadyTicks() + 20);
    if (data.getRasenganReadyTicks() >= 600) {
        data.setRasenganReady(false);
        data.setRasenganReadyTicks(0);
        player.sendMessage(Text.literal("\u00a77Rasengan dissipated..."), false);
        ShinobiCore.sendRasenganSync(player);
    }
} else {
    data.setRasenganReadyTicks(0);
}
"@
$c = $c.Replace("// === SEIGAN SHIELD SLOW ===", $ras + "`n        // === SEIGAN SHIELD SLOW ===")
Write-File $nt $c

# ============ 5. NinjaPlayerData: new fields ============
$np = "$root\stat\NinjaPlayerData.java"
$c = [System.IO.File]::ReadAllText($np, $utf8)
$c = $c.Replace("private boolean rasenganReady = false;",
"private boolean rasenganReady = false;`n    private int rasenganReadyTicks = 0;`n    private boolean lastDangerState = false;")
$c = $c.Replace("public void setRasenganReady(boolean v) { this.rasenganReady = v; }",
"public void setRasenganReady(boolean v) { this.rasenganReady = v; }`n    public int getRasenganReadyTicks() { return rasenganReadyTicks; }`n    public void setRasenganReadyTicks(int v) { this.rasenganReadyTicks = v; }`n    public boolean getLastDangerState() { return lastDangerState; }`n    public void setLastDangerState(boolean v) { this.lastDangerState = v; }")
Write-File $np $c

# ============ 6. IAI CRIT feedback ============
$mp = "$root\network\ModPackets.java"
$c = [System.IO.File]::ReadAllText($mp, $utf8)
$c = $c.Replace("if (stance == KenjutsuStance.IAI && now - data.getKatanaLastAttackMs() > 2000) damage *= 2.2f;",
@"
if (stance == KenjutsuStance.IAI && now - data.getKatanaLastAttackMs() > 2000) {
    damage *= 2.2f;
    player.sendMessage(Text.literal("\u00a76IAI CRIT!"), false);
    player.playSound(net.minecraft.sound.SoundEvents.ENTITY_PLAYER_ATTACK_CRIT, 1.0f, 0.8f);
    if (player.getWorld() instanceof ServerWorld sw3) {
        sw3.spawnParticles(net.minecraft.particle.ParticleTypes.CRIT, player.getX(), player.getY() + 1, player.getZ(), 20, 0.5, 0.5, 0.5, 0.1);
    }
}
"@)
Write-File $mp $c

# ============ 7. FINISHER SPIN: 360 -> smooth turn ============
$ka = "$root\client\combat\KenjutsuAnimations.java"
$c = [System.IO.File]::ReadAllText($ka, $utf8)
$c = $c.Replace("body.yaw += s.getProgress() * 6.283f;",
"body.yaw += (float) Math.sin(s.getProgress() * Math.PI) * 1.2f;")
Write-File $ka $c

# ============ 8. RECIPES: valid 3-wide patterns ============
$rec = "E:\Games\mod\src\main\resources\data\shinobicore\recipes"
Write-File "$rec\shuriken.json" @'
{
  "type": "minecraft:crafting_shaped",
  "pattern": ["n n", " n ", "n n"],
  "key": { "n": { "item": "minecraft:iron_nugget" } },
  "result": { "item": "shinobicore:shuriken", "count": 4 }
}
'@
Write-File "$rec\kunai.json" @'
{
  "type": "minecraft:crafting_shaped",
  "pattern": ["i", "s"],
  "key": { "i": { "item": "minecraft:iron_ingot" }, "s": { "item": "minecraft:stick" } },
  "result": { "item": "shinobicore:kunai", "count": 2 }
}
'@
Write-File "$rec\katana.json" @'
{
  "type": "minecraft:crafting_shaped",
  "pattern": ["i", "i", "s"],
  "key": { "i": { "item": "minecraft:iron_ingot" }, "s": { "item": "minecraft:stick" } },
  "result": { "item": "shinobicore:katana", "count": 1 }
}
'@

# ============ 9. TREE.JSON: strip // comment lines ============
$tree = "E:\Games\mod\src\main\resources\data\shinobicore\skill_tree\tree.json"
$lines = [System.IO.File]::ReadAllLines($tree, $utf8)
$clean = @()
foreach ($ln in $lines) {
    if (-not $ln.TrimStart().StartsWith("//")) { $clean += $ln }
}
$json = ($clean -join "`n").TrimEnd()
if (-not $json.EndsWith("}")) { $json += "`n}" }
Write-File $tree $json
Write-Host "[FIX] tree.json cleaned"

Write-Host "=== BATCH 1 DONE ==="