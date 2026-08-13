$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$root = "E:\Games\mod\src\main\java\com\example\shinobicore"
function Write-File($p, $c) { [System.IO.File]::WriteAllText($p, $c, $utf8); Write-Host "[OK] $p" }

# ============ 1. NinjaPlayerData: new fields ============
$np = "$root\stat\NinjaPlayerData.java"
$c = [System.IO.File]::ReadAllText($np, $utf8)
if ($c.Contains("lastDangerState")) { Write-Host "[SKIP] NinjaPlayerData fields" } else {
    $c = $c.Replace("private boolean statsDirty = true;",
        "private boolean statsDirty = true;`n    private boolean lastDangerState = false;`n    private int rasenganReadyTicks = 0;")
    $c = $c.Replace("public boolean consumeStatsDirty()",
        "public boolean getLastDangerState() { return lastDangerState; }`n    public void setLastDangerState(boolean v) { this.lastDangerState = v; }`n    public int getRasenganReadyTicks() { return rasenganReadyTicks; }`n    public void setRasenganReadyTicks(int v) { this.rasenganReadyTicks = v; }`n    public boolean consumeStatsDirty()")
    Write-File $np $c
}

# ============ 2. NinjaTickHandler: imports + sensory/danger/rasengan + slow 25 ============
$nt = "$root\event\NinjaTickHandler.java"
$c = [System.IO.File]::ReadAllText($nt, $utf8)
if ($c.Contains("PHASE_FIX2_TICK")) { Write-Host "[SKIP] NinjaTickHandler block" } else {
    $c = $c.Replace("import com.example.shinobicore.combat.KenjutsuStance;",
        "import com.example.shinobicore.combat.KenjutsuStance;`nimport com.example.shinobicore.tree.TreePassives;`nimport com.example.shinobicore.network.ModPackets;`nimport io.netty.buffer.Unpooled;`nimport net.minecraft.network.PacketByteBuf;`nimport net.fabricmc.fabric.api.networking.v1.ServerPlayNetworking;")
    $block = @"
        // === PHASE_FIX2_TICK: sensory glow + danger sense + rasengan dissipate ===
        TreePassives.Bonuses b2 = TreePassives.collectServer(data);
        if (b2.sensory && data.isSensoryEnabled()) {
            int radius = b2.sensoryRadius > 0 ? b2.sensoryRadius : 20;
            for (net.minecraft.entity.LivingEntity mob : player.getWorld().getEntitiesByClass(
                    net.minecraft.entity.LivingEntity.class, player.getBoundingBox().expand(radius),
                    m -> m instanceof net.minecraft.entity.mob.Monster)) {
                mob.addStatusEffect(new StatusEffectInstance(StatusEffects.GLOWING, 40, 0, false, false));
            }
        }
        if (b2.dangerSense) {
            boolean danger = false;
            for (net.minecraft.entity.mob.MobEntity mob : player.getWorld().getEntitiesByClass(
                    net.minecraft.entity.mob.MobEntity.class, player.getBoundingBox().expand(16),
                    m -> m.getTarget() == player)) {
                danger = true;
                break;
            }
            if (danger != data.getLastDangerState()) {
                data.setLastDangerState(danger);
                PacketByteBuf dbuf = new PacketByteBuf(Unpooled.buffer());
                dbuf.writeBoolean(danger);
                ServerPlayNetworking.send(player, ModPackets.DANGER_SYNC_ID, dbuf);
            }
        }
        if (data.isRasenganReady()) {
            data.setRasenganReadyTicks(data.getRasenganReadyTicks() + 20);
            if (data.getRasenganReadyTicks() >= 600) {
                data.setRasenganReady(false);
                data.setRasenganReadyTicks(0);
                player.sendMessage(Text.literal("\u00a77Rasengan dissipated..."), false);
                ShinobiCore.sendRasenganSync(player);
            }
        } else if (data.getRasenganReadyTicks() != 0) {
            data.setRasenganReadyTicks(0);
        }
        // === SEIGAN SHIELD SLOW ===
"@
    $c = $c.Replace("        // === SEIGAN SHIELD SLOW ===", $block)
    $c = $c.Replace("StatusEffects.SLOWNESS, 5, 2, false, false, false", "StatusEffects.SLOWNESS, 25, 2, false, false, false")
    Write-File $nt $c
}

# ============ 3. KatanaDeflectMixin: shield ignores cooldown ============
$kd = "$root\mixin\KatanaDeflectMixin.java"
$c = [System.IO.File]::ReadAllText($kd, $utf8)
if ($c.Contains("PHASE_FIX2_DEFLECT")) { Write-Host "[SKIP] Deflect cooldown" } else {
    $c = $c.Replace("if (now - data.getLastDeflectReflectMs() < 200) return;",
        "// PHASE_FIX2_DEFLECT: cooldown moved below (shield ignores it)")
    $c = $c.Replace("boolean isSeiganShield = holdActive && stance == KenjutsuStance.SEIGAN;",
        "boolean isSeiganShield = holdActive && stance == KenjutsuStance.SEIGAN;`n        if (!isSeiganShield && now - data.getLastDeflectReflectMs() < 200) return;")
    Write-File $kd $c
}

# ============ 4. ModPackets: IAI crit feedback ============
$mp = "$root\network\ModPackets.java"
$c = [System.IO.File]::ReadAllText($mp, $utf8)
if ($c.Contains("PHASE_FIX2_IAI")) { Write-Host "[SKIP] IAI feedback" } else {
    $c = $c.Replace("if (stance == KenjutsuStance.IAI && now - data.getKatanaLastAttackMs() > 2000) damage *= 2.2f;",
        "if (stance == KenjutsuStance.IAI && now - data.getKatanaLastAttackMs() > 2000) { // PHASE_FIX2_IAI`n                damage *= 2.2f;`n                player.sendMessage(Text.literal(`"\u00a76IAI CRIT!`"), false);`n                player.playSound(net.minecraft.sound.SoundEvents.ENTITY_PLAYER_ATTACK_CRIT, 1.0f, 0.8f);`n                if (player.getWorld() instanceof ServerWorld sw2) {`n                    sw2.spawnParticles(net.minecraft.particle.ParticleTypes.CRIT, player.getX(), player.getY() + 1, player.getZ(), 20, 0.5, 0.5, 0.5, 0.1);`n                }`n            }")
    Write-File $mp $c
}

# ============ 5. KenjutsuAnimations: finisher spin fix ============
$ka = "$root\client\combat\KenjutsuAnimations.java"
$c = [System.IO.File]::ReadAllText($ka, $utf8)
if ($c.Contains("PHASE_FIX2_SPIN")) { Write-Host "[SKIP] Spin fix" } else {
    $c = $c.Replace("body.yaw += s.getProgress() * 6.283f;",
        "body.yaw += (float) Math.sin(s.getProgress() * Math.PI) * 1.2f; // PHASE_FIX2_SPIN")
    Write-File $ka $c
}

# ============ 6. ShurikenEntity: getDamage getter ============
$se = "$root\entity\ShurikenEntity.java"
$c = [System.IO.File]::ReadAllText($se, $utf8)
if ($c.Contains("getDamage()")) { Write-Host "[SKIP] getDamage" } else {
    $c = $c.Replace("public int getAge() { return age; }",
        "public int getAge() { return age; }`n    public float getDamage() { return damage; }")
    Write-File $se $c
}

# ============ 7. REWRITE: ShurikenRenderer (star + kunai) ============
$sr = "$root\entity\ShurikenRenderer.java"
Write-File $sr @'
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

    @Override
    public void render(ShurikenEntity entity, float yaw, float tickDelta,
                       MatrixStack matrices, VertexConsumerProvider vc, int light) {
        super.render(entity, yaw, tickDelta, matrices, vc, light);
        matrices.push();
        matrices.translate(0, 0.25, 0);
        if (!entity.isStuck()) {
            matrices.multiply(RotationAxis.POSITIVE_Y.rotationDegrees((entity.getAge() + tickDelta) * 25f));
            matrices.multiply(RotationAxis.POSITIVE_X.rotationDegrees(90));
        }
        VertexConsumer consumer = vc.getBuffer(RenderLayer.getEntityTranslucent(TEX));
        boolean kunai = entity.getDamage() > 4f;
        if (kunai) {
            renderKunai(consumer, matrices.peek().getPositionMatrix(), light);
        } else {
            renderShuriken(consumer, matrices, light);
        }
        matrices.pop();
    }

    private void renderShuriken(VertexConsumer c, MatrixStack matrices, int light) {
        for (int i = 0; i < 4; i++) {
            matrices.push();
            matrices.multiply(RotationAxis.POSITIVE_Y.rotationDegrees(i * 90f));
            Matrix4f m = matrices.peek().getPositionMatrix();
            // blade: trapezoid (wide at hub, narrow tip)
            v(c, m, -0.05f, 0, 0.02f, 0.80f, 0.80f, 0.85f, light);
            v(c, m, -0.012f, 0, 0.26f, 0.95f, 0.95f, 1.0f, light);
            v(c, m, 0.012f, 0, 0.26f, 0.95f, 0.95f, 1.0f, light);
            v(c, m, 0.05f, 0, 0.02f, 0.80f, 0.80f, 0.85f, light);
            // back face
            v(c, m, 0.05f, 0, 0.02f, 0.80f, 0.80f, 0.85f, light);
            v(c, m, 0.012f, 0, 0.26f, 0.95f, 0.95f, 1.0f, light);
            v(c, m, -0.012f, 0, 0.26f, 0.95f, 0.95f, 1.0f, light);
            v(c, m, -0.05f, 0, 0.02f, 0.80f, 0.80f, 0.85f, light);
            matrices.pop();
        }
        Matrix4f m = matrices.peek().getPositionMatrix();
        // hub (dark center)
        v(c, m, -0.045f, 0, -0.045f, 0.25f, 0.25f, 0.28f, light);
        v(c, m, -0.045f, 0, 0.045f, 0.25f, 0.25f, 0.28f, light);
        v(c, m, 0.045f, 0, 0.045f, 0.25f, 0.25f, 0.28f, light);
        v(c, m, 0.045f, 0, -0.045f, 0.25f, 0.25f, 0.28f, light);
        v(c, m, 0.045f, 0, -0.045f, 0.25f, 0.25f, 0.28f, light);
        v(c, m, 0.045f, 0, 0.045f, 0.25f, 0.25f, 0.28f, light);
        v(c, m, -0.045f, 0, 0.045f, 0.25f, 0.25f, 0.28f, light);
        v(c, m, -0.045f, 0, -0.045f, 0.25f, 0.25f, 0.28f, light);
    }

    private void renderKunai(VertexConsumer c, Matrix4f m, int light) {
        // blade (bright, pointed)
        v(c, m, 0f, 0, 0.30f, 0.95f, 0.95f, 1.0f, light);
        v(c, m, -0.05f, 0, 0.10f, 0.85f, 0.85f, 0.9f, light);
        v(c, m, 0.05f, 0, 0.10f, 0.85f, 0.85f, 0.9f, light);
        v(c, m, 0.05f, 0, 0.10f, 0.85f, 0.85f, 0.9f, light);
        v(c, m, -0.05f, 0, 0.10f, 0.85f, 0.85f, 0.9f, light);
        v(c, m, 0f, 0, 0.30f, 0.95f, 0.95f, 1.0f, light);
        // handle (dark)
        v(c, m, -0.02f, 0, 0.10f, 0.3f, 0.3f, 0.32f, light);
        v(c, m, -0.02f, 0, -0.20f, 0.3f, 0.3f, 0.32f, light);
        v(c, m, 0.02f, 0, -0.20f, 0.3f, 0.3f, 0.32f, light);
        v(c, m, 0.02f, 0, 0.10f, 0.3f, 0.3f, 0.32f, light);
        v(c, m, 0.02f, 0, 0.10f, 0.3f, 0.3f, 0.32f, light);
        v(c, m, 0.02f, 0, -0.20f, 0.3f, 0.3f, 0.32f, light);
        v(c, m, -0.02f, 0, -0.20f, 0.3f, 0.3f, 0.32f, light);
        v(c, m, -0.02f, 0, 0.10f, 0.3f, 0.3f, 0.32f, light);
        // ring (pommel)
        v(c, m, -0.05f, 0, -0.20f, 0.5f, 0.5f, 0.55f, light);
        v(c, m, -0.05f, 0, -0.30f, 0.5f, 0.5f, 0.55f, light);
        v(c, m, 0.05f, 0, -0.30f, 0.5f, 0.5f, 0.55f, light);
        v(c, m, 0.05f, 0, -0.20f, 0.5f, 0.5f, 0.55f, light);
        v(c, m, 0.05f, 0, -0.20f, 0.5f, 0.5f, 0.55f, light);
        v(c, m, 0.05f, 0, -0.30f, 0.5f, 0.5f, 0.55f, light);
        v(c, m, -0.05f, 0, -0.30f, 0.5f, 0.5f, 0.55f, light);
        v(c, m, -0.05f, 0, -0.20f, 0.5f, 0.5f, 0.55f, light);
    }

    private void v(VertexConsumer c, Matrix4f m, float x, float y, float z,
                   float r, float g, float b, int light) {
        c.vertex(m, x, y, z).color(r, g, b, 1f).texture(0, 0)
         .overlay(OverlayTexture.DEFAULT_UV).light(light).normal(0, 1, 0).next();
    }

    @Override
    public Identifier getTexture(ShurikenEntity entity) { return TEX; }
}
'@

# ============ 8. REWRITE: KatanaBuiltinRenderer (blade +Y) ============
$kr = "$root\client\render\KatanaBuiltinRenderer.java"
Write-File $kr @'
package com.example.shinobicore.client.render;

import net.minecraft.client.render.RenderLayer;
import net.minecraft.client.render.VertexConsumer;
import net.minecraft.client.render.VertexConsumerProvider;
import net.minecraft.client.util.math.MatrixStack;
import net.minecraft.item.ItemStack;
import net.minecraft.client.render.model.json.ModelTransformationMode;
import net.minecraft.util.Identifier;
import org.joml.Matrix4f;

public class KatanaBuiltinRenderer {
    private static final Identifier TEX = new Identifier("textures/misc/white.png");

    public static void render(ItemStack stack, ModelTransformationMode mode, MatrixStack matrices,
                              VertexConsumerProvider vertexConsumers, int light, int overlay) {
        matrices.push();
        VertexConsumer vc = vertexConsumers.getBuffer(RenderLayer.getEntityTranslucent(TEX));
        // blade (+Y up)
        cuboid(matrices, vc, light, -0.02f, 0.02f, -0.0075f, 0.04f, 0.85f, 0.015f, 0.85f, 0.87f, 0.90f);
        cuboid(matrices, vc, light, -0.026f, 0.02f, -0.002f, 0.008f, 0.85f, 0.004f, 0.95f, 0.97f, 1.0f);
        cuboid(matrices, vc, light, -0.015f, 0.87f, -0.005f, 0.03f, 0.07f, 0.01f, 0.95f, 0.97f, 1.0f);
        // tsuba
        cuboid(matrices, vc, light, -0.06f, 0.0f, -0.06f, 0.12f, 0.02f, 0.12f, 0.60f, 0.45f, 0.15f);
        // handle
        cuboid(matrices, vc, light, -0.02f, -0.30f, -0.02f, 0.04f, 0.30f, 0.04f, 0.25f, 0.18f, 0.12f);
        for (int i = 0; i < 4; i++) {
            float y = -0.28f + i * 0.065f;
            cuboid(matrices, vc, light, -0.025f, y, -0.025f, 0.05f, 0.02f, 0.05f, 0.70f, 0.15f, 0.10f);
        }
        cuboid(matrices, vc, light, -0.025f, -0.32f, -0.025f, 0.05f, 0.02f, 0.05f, 0.60f, 0.45f, 0.15f);
        matrices.pop();
    }

    private static void cuboid(MatrixStack matrices, VertexConsumer vc, int light,
                               float x, float y, float z, float w, float h, float d,
                               float r, float g, float b) {
        Matrix4f m = matrices.peek().getPositionMatrix();
        float x2 = x + w, y2 = y + h, z2 = z + d;
        face(vc, m, x, y, z2, x2, y, z2, x2, y2, z2, x, y2, z2, r, g, b, light);
        face(vc, m, x2, y, z, x, y, z, x, y2, z, x2, y2, z, r, g, b, light);
        face(vc, m, x, y, z, x, y, z2, x, y2, z2, x, y2, z, r, g, b, light);
        face(vc, m, x2, y, z2, x2, y, z, x2, y2, z, x2, y2, z2, r, g, b, light);
        face(vc, m, x, y2, z2, x2, y2, z2, x2, y2, z, x, y2, z, r, g, b, light);
        face(vc, m, x, y, z, x2, y, z, x2, y, z2, x, y, z2, r, g, b, light);
    }

    private static void face(VertexConsumer vc, Matrix4f m,
                             float x1, float y1, float z1, float x2, float y2, float z2,
                             float x3, float y3, float z3, float x4, float y4, float z4,
                             float r, float g, float b, int light) {
        v(vc, m, x1, y1, z1, r, g, b, light); v(vc, m, x2, y2, z2, r, g, b, light);
        v(vc, m, x3, y3, z3, r, g, b, light); v(vc, m, x4, y4, z4, r, g, b, light);
        v(vc, m, x4, y4, z4, r, g, b, light); v(vc, m, x3, y3, z3, r, g, b, light);
        v(vc, m, x2, y2, z2, r, g, b, light); v(vc, m, x1, y1, z1, r, g, b, light);
    }

    private static void v(VertexConsumer vc, Matrix4f m, float x, float y, float z,
                          float r, float g, float b, int light) {
        vc.vertex(m, x, y, z).color(r, g, b, 1.0f).texture(0, 0)
          .overlay(net.minecraft.client.render.OverlayTexture.DEFAULT_UV).light(light).normal(0, 1, 0).next();
    }
}
'@

# ============ 9. katana.json display transforms ============
$kj = "E:\Games\mod\src\main\resources\assets\shinobicore\models\item\katana.json"
Write-File $kj @'
{
  "parent": "builtin/entity",
  "display": {
    "gui": { "rotation": [0, 0, -45], "translation": [0, 0, 0], "scale": [0.7, 0.7, 0.7] },
    "ground": { "rotation": [0, 0, 0], "translation": [0, 3, 0], "scale": [0.6, 0.6, 0.6] },
    "fixed": { "rotation": [0, 0, 0], "translation": [0, 0, 0], "scale": [0.8, 0.8, 0.8] },
    "thirdperson_righthand": { "rotation": [0, -90, 55], "translation": [0, 4, 2], "scale": [0.85, 0.85, 0.85] },
    "thirdperson_lefthand": { "rotation": [0, 90, -55], "translation": [0, 4, 2], "scale": [0.85, 0.85, 0.85] },
    "firstperson_righthand": { "rotation": [0, -90, 25], "translation": [1, 3, 1], "scale": [0.8, 0.8, 0.8] },
    "firstperson_lefthand": { "rotation": [0, 90, -25], "translation": [1, 3, 1], "scale": [0.8, 0.8, 0.8] }
  }
}
'@

# ============ 10. Recipes rewrite ============
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

# ============ 11. tree.json: strip // comment lines ============
$tree = "E:\Games\mod\src\main\resources\data\shinobicore\skill_tree\tree.json"
$lines = [System.IO.File]::ReadAllLines($tree, $utf8)
$clean = New-Object System.Collections.Generic.List[string]
foreach ($ln in $lines) {
    if ($ln.TrimStart().StartsWith("//")) { continue }
    $clean.Add($ln)
}
$json = ($clean -join "`n").TrimEnd()
if (-not $json.EndsWith("}")) { $json = $json + "`n}" }
[System.IO.File]::WriteAllText($tree, $json, $utf8)
Write-Host "[OK] tree.json cleaned"

Write-Host "=== BATCH 2 DONE ==="