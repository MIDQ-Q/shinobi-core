$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$base = "E:\Games\mod\src\main\java\com\example\shinobicore"

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "  ПРИМЕНЕНИЕ ИСПРАВЛЕНИЙ: 3D РЕНДЕРИНГ И ЗВУКИ" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan

# === Вспомогательные функции ===
function Write-File($p, $c) {
    $dir = [System.IO.Path]::GetDirectoryName($p)
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [System.IO.File]::WriteAllText($p, $c, $utf8)
    Write-Host "[OK] Создан/Обновлен: $p" -ForegroundColor Green
}

function Update-File($p, $old, $new) {
    if (-not (Test-Path $p)) {
        Write-Host "[!] Файл не найден: $p" -ForegroundColor Red
        return
    }
    $c = [System.IO.File]::ReadAllText($p, $utf8)
    if (-not $c.Contains($old)) {
        Write-Host "[~] Пропуск (уже применено или код изменен): $p" -ForegroundColor Yellow
        return
    }
    $c = $c.Replace($old, $new)
    [System.IO.File]::WriteAllText($p, $c, $utf8)
    Write-Host "[OK] Внесена точечная правка: $p" -ForegroundColor Green
}

# ==========================================
# 1. ПОЛНАЯ ЗАМЕНА: NinjaProjectileRenderer.java
# ==========================================
Write-Host "`n[1/8] NinjaProjectileRenderer.java (3D Cross-Quads)..." -ForegroundColor Cyan
Write-File "$base\entity\NinjaProjectileRenderer.java" @'
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

    public NinjaProjectileRenderer(EntityRendererFactory.Context ctx) {
        super(ctx);
    }

    @Override
    public void render(NinjaProjectileEntity entity, float yaw, float tickDelta,
                       MatrixStack matrices, VertexConsumerProvider vertexConsumers, int light) {
        super.render(entity, yaw, tickDelta, matrices, vertexConsumers, light);

        float rawRadius = entity.getRadius();
        float radius = Math.max(0.35f, rawRadius * 0.6f);
        String particle = entity.getParticleType();
        String model = entity.getModelType();
        float age = entity.age + tickDelta;

        matrices.push();
        matrices.translate(0, entity.getHeight() / 2.0, 0);

        if ("rasengan".equals(model) || "rasengan".equals(particle)) {
            renderRasengan(matrices, vertexConsumers, radius, age, light);
        } else {
            int[] colors = getColors(particle);
            int innerColor = colors[0];
            int outerColor = colors[1];

            float spinSpeed = getSpinSpeed(particle);
            matrices.multiply(RotationAxis.POSITIVE_Y.rotationDegrees(age * spinSpeed));
            if ("fire".equals(particle) || "flame".equals(particle)) {
                float pulse = 1.0f + MathHelper.sin(age * 0.3f) * 0.1f;
                radius *= pulse;
            }

            renderCrossSphere(matrices, vertexConsumers, radius, innerColor, light, false);
            renderCrossSphere(matrices, vertexConsumers, radius * 1.5f, outerColor, light, true);
        }

        matrices.pop();
    }

    private float getSpinSpeed(String particle) {
        return switch (particle) {
            case "wind" -> 25.0f;
            case "lightning" -> 30.0f;
            case "fire", "flame" -> 10.0f;
            case "water" -> 8.0f;
            default -> 12.0f;
        };
    }

    private int[] getColors(String particle) {
        return switch (particle) {
            case "fire", "flame" -> new int[]{0xFFFF6600, 0x88FF2200};
            case "water" -> new int[]{0xFF2288FF, 0x880044FF};
            case "lightning" -> new int[]{0xFFFFFF44, 0x88FFFF00};
            case "wind" -> new int[]{0xFFCCFFCC, 0x88AAFFAA};
            case "earth" -> new int[]{0xFF996633, 0x88553311};
            case "smoke" -> new int[]{0xFF888888, 0x88444444};
            default -> new int[]{0xFFFF6600, 0x88FF2200};
        };
    }

    private void renderCrossSphere(MatrixStack matrices, VertexConsumerProvider vc,
                                    float radius, int color, int light, boolean isGlow) {
        VertexConsumer consumer = vc.getBuffer(RenderLayer.getEntityTranslucent(WHITE_TEXTURE));
        float r = ((color >> 16) & 0xFF) / 255f;
        float g = ((color >> 8) & 0xFF) / 255f;
        float b = (color & 0xFF) / 255f;
        float a = ((color >> 24) & 0xFF) / 255f;
        if (a < 0.01f) a = 1.0f;

        for (int i = 0; i < 3; i++) {
            matrices.push();
            matrices.multiply(RotationAxis.POSITIVE_Y.rotationDegrees(i * 60f));
            Matrix4f m = matrices.peek().getPositionMatrix();
            emitDoubleSidedQuad(consumer, m,
                    -radius, -radius, 0, radius, -radius, 0, radius, radius, 0, -radius, radius, 0,
                    r, g, b, a, light);
            matrices.pop();
        }

        matrices.push();
        matrices.multiply(RotationAxis.POSITIVE_X.rotationDegrees(90));
        Matrix4f mH = matrices.peek().getPositionMatrix();
        emitDoubleSidedQuad(consumer, mH,
                -radius, -radius, 0, radius, -radius, 0, radius, radius, 0, -radius, radius, 0,
                r, g, b, a, light);
        matrices.pop();
    }

    private void renderRasengan(MatrixStack matrices, VertexConsumerProvider vc,
                                 float radius, float age, int light) {
        renderCrossSphere(matrices, vc, radius, 0xFF4499FF, light, false);

        matrices.push();
        matrices.multiply(RotationAxis.POSITIVE_Y.rotationDegrees(age * 25f));
        matrices.multiply(RotationAxis.POSITIVE_X.rotationDegrees(15f));
        renderRing(matrices, vc, radius * 1.3f, radius * 0.12f, 0xCCFFFFFF, light);
        matrices.pop();

        matrices.push();
        matrices.multiply(RotationAxis.POSITIVE_Y.rotationDegrees(-age * 18f));
        matrices.multiply(RotationAxis.POSITIVE_Z.rotationDegrees(60f));
        renderRing(matrices, vc, radius * 1.5f, radius * 0.08f, 0xCC88CCFF, light);
        matrices.pop();

        renderCrossSphere(matrices, vc, radius * 1.8f, 0x4488CCFF, light, true);
    }

    private void renderRing(MatrixStack matrices, VertexConsumerProvider vc,
                            float majorRadius, float thickness, int color, int light) {
        VertexConsumer consumer = vc.getBuffer(RenderLayer.getEntityTranslucent(WHITE_TEXTURE));
        float r = ((color >> 16) & 0xFF) / 255f;
        float g = ((color >> 8) & 0xFF) / 255f;
        float b = (color & 0xFF) / 255f;
        float a = ((color >> 24) & 0xFF) / 255f;
        if (a < 0.01f) a = 1.0f;

        int segments = 20;
        Matrix4f m = matrices.peek().getPositionMatrix();
        for (int i = 0; i < segments; i++) {
            float a1 = (float) (i * 2 * Math.PI / segments);
            float a2 = (float) ((i + 1) * 2 * Math.PI / segments);
            float x1 = MathHelper.cos(a1) * majorRadius;
            float z1 = MathHelper.sin(a1) * majorRadius;
            float x2 = MathHelper.cos(a2) * majorRadius;
            float z2 = MathHelper.sin(a2) * majorRadius;
            float ix1 = MathHelper.cos(a1) * (majorRadius - thickness);
            float iz1 = MathHelper.sin(a1) * (majorRadius - thickness);
            float ix2 = MathHelper.cos(a2) * (majorRadius - thickness);
            float iz2 = MathHelper.sin(a2) * (majorRadius - thickness);

            emitDoubleSidedQuad(consumer, m, x1, thickness, z1, x2, thickness, z2, ix2, thickness, iz2, ix1, thickness, iz1, r, g, b, a, light);
            emitDoubleSidedQuad(consumer, m, ix1, -thickness, iz1, ix2, -thickness, iz2, x2, -thickness, z2, x1, -thickness, z1, r, g, b, a, light);
        }
    }

    private void emitDoubleSidedQuad(VertexConsumer consumer, Matrix4f matrix,
                                      float x1, float y1, float z1, float x2, float y2, float z2,
                                      float x3, float y3, float z3, float x4, float y4, float z4,
                                      float r, float g, float b, float a, int light) {
        vertex(consumer, matrix, x1, y1, z1, 0, 0, r, g, b, a, light);
        vertex(consumer, matrix, x2, y2, z2, 1, 0, r, g, b, a, light);
        vertex(consumer, matrix, x3, y3, z3, 1, 1, r, g, b, a, light);
        vertex(consumer, matrix, x4, y4, z4, 0, 1, r, g, b, a, light);
        
        vertex(consumer, matrix, x4, y4, z4, 0, 1, r, g, b, a, light);
        vertex(consumer, matrix, x3, y3, z3, 1, 1, r, g, b, a, light);
        vertex(consumer, matrix, x2, y2, z2, 1, 0, r, g, b, a, light);
        vertex(consumer, matrix, x1, y1, z1, 0, 0, r, g, b, a, light);
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
        return WHITE_TEXTURE;
    }
}
'@

# ==========================================
# 2. НОВЫЙ ФАЙЛ: JutsuSoundHelper.java
# ==========================================
Write-Host "`n[2/8] JutsuSoundHelper.java (Система звуков)..." -ForegroundColor Cyan
Write-File "$base\jutsu\JutsuSoundHelper.java" @'
package com.example.shinobicore.jutsu;

import com.example.shinobicore.stat.ElementType;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.sound.SoundCategory;
import net.minecraft.sound.SoundEvents;
import net.minecraft.util.math.BlockPos;

public class JutsuSoundHelper {
    public static void playCastSound(ServerPlayerEntity player, JutsuDefinition def) {
        ServerWorld world = (ServerWorld) player.getWorld();
        BlockPos pos = player.getBlockPos();

        if (def.hasNature()) {
            playNatureCastSound(world, pos, def.nature(), def.baseDamage());
            return;
        }

        String type = def.type();
        String category = def.category();

        if (def.id().contains("rasengan")) {
            world.playSound(null, pos, SoundEvents.BLOCK_BEACON_POWER_SELECT, SoundCategory.PLAYERS, 1.5f, 0.8f);
        } else if (def.id().contains("rasenshuriken")) {
            world.playSound(null, pos, SoundEvents.ENTITY_ENDER_DRAGON_GROWL, SoundCategory.PLAYERS, 2.0f, 1.2f);
        } else if ("dash".equals(type) || "shunshin".equals(type)) {
            world.playSound(null, pos, SoundEvents.ENTITY_ENDERMAN_TELEPORT, SoundCategory.PLAYERS, 0.8f, 1.5f);
        } else if ("genjutsu".equals(category)) {
            world.playSound(null, pos, SoundEvents.ENTITY_WITCH_AMBIENT, SoundCategory.PLAYERS, 0.8f, 0.5f);
        } else if ("medical".equals(category)) {
            world.playSound(null, pos, SoundEvents.ENTITY_EXPERIENCE_ORB_PICKUP, SoundCategory.PLAYERS, 0.8f, 1.5f);
        } else if ("melee".equals(type)) {
            world.playSound(null, pos, SoundEvents.ENTITY_PLAYER_ATTACK_STRONG, SoundCategory.PLAYERS, 1.0f, 0.9f);
        } else {
            world.playSound(null, pos, SoundEvents.ENTITY_PLAYER_ATTACK_SWEEP, SoundCategory.PLAYERS, 0.6f, 1.0f);
        }
    }

    private static void playNatureCastSound(ServerWorld world, BlockPos pos, ElementType nature, float damage) {
        float volume = Math.min(2.0f, 0.6f + damage * 0.03f);
        switch (nature) {
            case FIRE -> {
                world.playSound(null, pos, SoundEvents.ENTITY_BLAZE_SHOOT, SoundCategory.PLAYERS, volume, 0.8f);
                if (damage > 15) world.playSound(null, pos, SoundEvents.ITEM_FIRECHARGE_USE, SoundCategory.PLAYERS, volume * 0.5f, 0.6f);
            }
            case WATER -> {
                world.playSound(null, pos, SoundEvents.ENTITY_DOLPHIN_SPLASH, SoundCategory.PLAYERS, volume, 0.9f);
                if (damage > 12) world.playSound(null, pos, SoundEvents.ENTITY_PLAYER_SPLASH_HIGH_SPEED, SoundCategory.PLAYERS, volume * 0.4f, 0.7f);
            }
            case WIND -> {
                world.playSound(null, pos, SoundEvents.ENTITY_PLAYER_ATTACK_SWEEP, SoundCategory.PLAYERS, volume, 0.7f);
                if (damage > 12) world.playSound(null, pos, SoundEvents.ENTITY_PHANTOM_FLAP, SoundCategory.PLAYERS, volume * 0.3f, 0.5f);
            }
            case LIGHTNING -> {
                world.playSound(null, pos, SoundEvents.ENTITY_LIGHTNING_BOLT_IMPACT, SoundCategory.PLAYERS, volume * 0.6f, 1.3f);
                if (damage > 15) world.playSound(null, pos, SoundEvents.BLOCK_BEEHIVE_WORK, SoundCategory.PLAYERS, volume * 0.4f, 2.0f);
            }
            case EARTH -> {
                world.playSound(null, pos, SoundEvents.BLOCK_STONE_BREAK, SoundCategory.PLAYERS, volume, 0.6f);
                if (damage > 10) world.playSound(null, pos, SoundEvents.BLOCK_GRAVEL_BREAK, SoundCategory.PLAYERS, volume * 0.5f, 0.5f);
            }
        }
    }

    public static void playChargeStartSound(ServerPlayerEntity player, JutsuDefinition def) {
        ServerWorld world = (ServerWorld) player.getWorld();
        BlockPos pos = player.getBlockPos();
        if (def.id().contains("rasengan")) {
            world.playSound(null, pos, SoundEvents.BLOCK_BEACON_AMBIENT, SoundCategory.PLAYERS, 0.5f, 0.8f);
        } else if (def.id().contains("rasenshuriken")) {
            world.playSound(null, pos, SoundEvents.BLOCK_BEACON_AMBIENT, SoundCategory.PLAYERS, 0.8f, 0.6f);
            world.playSound(null, pos, SoundEvents.ENTITY_PLAYER_ATTACK_SWEEP, SoundCategory.PLAYERS, 0.3f, 0.4f);
        } else {
            world.playSound(null, pos, SoundEvents.BLOCK_PORTAL_AMBIENT, SoundCategory.PLAYERS, 0.3f, 0.8f);
        }
    }

    public static void playChargeReadySound(ServerPlayerEntity player, JutsuDefinition def) {
        ServerWorld world = (ServerWorld) player.getWorld();
        BlockPos pos = player.getBlockPos();
        if (def.id().contains("rasengan")) {
            world.playSound(null, pos, SoundEvents.BLOCK_BEACON_POWER_SELECT, SoundCategory.PLAYERS, 1.5f, 1.2f);
        } else if (def.id().contains("rasenshuriken")) {
            world.playSound(null, pos, SoundEvents.ENTITY_ENDER_DRAGON_GROWL, SoundCategory.PLAYERS, 1.5f, 1.0f);
        } else {
            world.playSound(null, pos, SoundEvents.ENTITY_EXPERIENCE_ORB_PICKUP, SoundCategory.PLAYERS, 1.0f, 0.5f);
        }
    }

    public static void playRasenganStrikeSound(ServerPlayerEntity player) {
        ServerWorld world = (ServerWorld) player.getWorld();
        BlockPos pos = player.getBlockPos();
        world.playSound(null, pos, SoundEvents.ENTITY_GENERIC_EXPLODE, SoundCategory.PLAYERS, 1.5f, 1.2f);
        world.playSound(null, pos, SoundEvents.ENTITY_PLAYER_ATTACK_CRIT, SoundCategory.PLAYERS, 1.0f, 0.6f);
    }

    public static void playRasenshurikenThrowSound(ServerPlayerEntity player) {
        ServerWorld world = (ServerWorld) player.getWorld();
        BlockPos pos = player.getBlockPos();
        world.playSound(null, pos, SoundEvents.ENTITY_ENDER_DRAGON_GROWL, SoundCategory.PLAYERS, 2.0f, 1.2f);
        world.playSound(null, pos, SoundEvents.ENTITY_PLAYER_ATTACK_SWEEP, SoundCategory.PLAYERS, 1.0f, 0.5f);
    }

    public static void playSubstitutionSound(ServerPlayerEntity player) {
        ServerWorld world = (ServerWorld) player.getWorld();
        BlockPos pos = player.getBlockPos();
        world.playSound(null, pos, SoundEvents.ENTITY_ENDERMAN_TELEPORT, SoundCategory.PLAYERS, 1.0f, 1.0f);
        world.playSound(null, pos, SoundEvents.ENTITY_GENERIC_EXTINGUISH_FIRE, SoundCategory.PLAYERS, 0.5f, 1.5f);
    }

    public static void playKatanaDeflectSound(ServerPlayerEntity player) {
        ServerWorld world = (ServerWorld) player.getWorld();
        BlockPos pos = player.getBlockPos();
        world.playSound(null, pos, SoundEvents.ITEM_SHIELD_BLOCK, SoundCategory.PLAYERS, 0.8f, 1.5f);
        world.playSound(null, pos, SoundEvents.BLOCK_ANVIL_LAND, SoundCategory.PLAYERS, 0.3f, 2.0f);
    }
}
'@

# ==========================================
# 3. ТОЧЕЧНЫЕ ПРАВКИ: JutsuCaster.java
# ==========================================
Write-Host "`n[3/8] JutsuCaster.java (Интеграция звуков)..." -ForegroundColor Cyan

$castOld = @"
        // Вызываем behavior
        ShinobiCore.broadcastCastFx(player, def.hasNature() ? def.nature().getId() : "none");
"@
$castNew = @"
        // === ЗВУК КАСТА ===
        JutsuSoundHelper.playCastSound(player, def);

        // Вызываем behavior
        ShinobiCore.broadcastCastFx(player, def.hasNature() ? def.nature().getId() : "none");
"@
Update-File "$base\jutsu\JutsuCaster.java" $castOld $castNew

$beginCastOld = @"
        com.example.shinobicore.combat.CastingServerState.startCast(player, jutsuId, castTimeTicks, cost);
        ShinobiCore.broadcastCastStart(player, jutsuId, castTimeTicks);
"@
$beginCastNew = @"
        // === ЗВУК НАЧАЛА ЗАРЯДКИ ===
        JutsuSoundHelper.playChargeStartSound(player, def);

        com.example.shinobicore.combat.CastingServerState.startCast(player, jutsuId, castTimeTicks, cost);
        ShinobiCore.broadcastCastStart(player, jutsuId, castTimeTicks);
"@
Update-File "$base\jutsu\JutsuCaster.java" $beginCastOld $beginCastNew

$executeCastOld = @"
        com.example.shinobicore.jutsu.JutsuDefinition def = com.example.shinobicore.jutsu.JutsuRegistry.get(jutsuId);
        if (def == null) return false;
        float cost = NinjaFormula.calculateCost(def, data);
"@
$executeCastNew = @"
        com.example.shinobicore.jutsu.JutsuDefinition def = com.example.shinobicore.jutsu.JutsuRegistry.get(jutsuId);
        if (def == null) return false;

        // === ЗВУК ЗАВЕРШЕНИЯ ЗАРЯДКИ ===
        JutsuSoundHelper.playChargeReadySound(player, def);

        float cost = NinjaFormula.calculateCost(def, data);
"@
Update-File "$base\jutsu\JutsuCaster.java" $executeCastOld $executeCastNew

# ==========================================
# 4. ПОЛНАЯ ЗАМЕНА: TaijutsuSounds.java
# ==========================================
Write-Host "`n[4/8] TaijutsuSounds.java (Улучшенные ванильные звуки)..." -ForegroundColor Cyan
Write-File "$base\client\combat\TaijutsuSounds.java" @'
package com.example.shinobicore.client.combat;

import com.example.shinobicore.ShinobiCore;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.sound.SoundCategory;
import net.minecraft.sound.SoundEvent;
import net.minecraft.sound.SoundEvents;
import net.minecraft.util.Identifier;

public class TaijutsuSounds {
    public static final SoundEvent PUNCH_LIGHT = SoundEvent.of(new Identifier("shinobicore", "punch_light"));
    public static final SoundEvent PUNCH_HEAVY = SoundEvent.of(new Identifier("shinobicore", "punch_heavy"));
    public static final SoundEvent KICK = SoundEvent.of(new Identifier("shinobicore", "kick"));
    public static final SoundEvent WHOOSH = SoundEvent.of(new Identifier("shinobicore", "whoosh"));
    public static final SoundEvent KATANA_SLASH = SoundEvent.of(new Identifier("shinobicore", "katana_slash"));
    public static final SoundEvent KATANA_DEFLECT = SoundEvent.of(new Identifier("shinobicore", "katana_deflect"));

    private static boolean customSoundsRegistered = false;

    public static void playPunchSound(int comboStep) {
        MinecraftClient client = MinecraftClient.getInstance();
        ClientPlayerEntity player = client.player;
        if (player == null) return;

        SoundEvent sound;
        float pitch;

        if (comboStep >= 2) {
            sound = customSoundsRegistered ? PUNCH_HEAVY : SoundEvents.ENTITY_PLAYER_ATTACK_STRONG;
            pitch = 0.85f + (float) Math.random() * 0.2f;
        } else {
            sound = customSoundsRegistered ? PUNCH_LIGHT : SoundEvents.ENTITY_PLAYER_ATTACK_WEAK;
            pitch = 1.0f + (float) Math.random() * 0.2f;
        }

        try {
            player.playSound(sound, SoundCategory.PLAYERS, 1.0f, pitch);
        } catch (Exception e) {
            ShinobiCore.LOGGER.error("[SOUND] Failed to play punch sound: {}", e.getMessage());
        }
    }

    public static void playKickSound() {
        MinecraftClient client = MinecraftClient.getInstance();
        ClientPlayerEntity player = client.player;
        if (player == null) return;

        SoundEvent sound = customSoundsRegistered ? KICK : SoundEvents.ENTITY_PLAYER_ATTACK_CRIT;
        float pitch = 0.9f + (float) Math.random() * 0.15f;

        try {
            player.playSound(sound, SoundCategory.PLAYERS, 1.0f, pitch);
        } catch (Exception e) {
            ShinobiCore.LOGGER.error("[SOUND] Failed to play kick sound: {}", e.getMessage());
        }
    }

    public static void playWhoosh() {
        MinecraftClient client = MinecraftClient.getInstance();
        ClientPlayerEntity player = client.player;
        if (player == null) return;

        SoundEvent sound = customSoundsRegistered ? WHOOSH : SoundEvents.ENTITY_PLAYER_ATTACK_SWEEP;
        float pitch = 0.75f + (float) Math.random() * 0.35f;

        try {
            player.playSound(sound, SoundCategory.PLAYERS, 0.6f, pitch);
        } catch (Exception e) {
            ShinobiCore.LOGGER.error("[SOUND] Failed to play whoosh sound: {}", e.getMessage());
        }
    }

    public static void playKatanaSlash(int comboStep) {
        MinecraftClient client = MinecraftClient.getInstance();
        ClientPlayerEntity player = client.player;
        if (player == null) return;

        try {
            float pitch = 1.1f + comboStep * 0.1f + (float) Math.random() * 0.15f;
            player.playSound(SoundEvents.ENTITY_PLAYER_ATTACK_SWEEP, SoundCategory.PLAYERS, 0.8f, pitch);

            if (comboStep == 3) {
                player.playSound(SoundEvents.ENTITY_PLAYER_ATTACK_STRONG, SoundCategory.PLAYERS, 0.6f, 0.7f);
            }
        } catch (Exception e) {
            ShinobiCore.LOGGER.error("[SOUND] Failed to play katana slash: {}", e.getMessage());
        }
    }

    public static void playKatanaDeflectSound() {
        MinecraftClient client = MinecraftClient.getInstance();
        ClientPlayerEntity player = client.player;
        if (player == null) return;

        try {
            player.playSound(SoundEvents.ITEM_SHIELD_BLOCK, SoundCategory.PLAYERS, 0.8f, 1.5f);
            player.playSound(SoundEvents.BLOCK_ANVIL_LAND, SoundCategory.PLAYERS, 0.2f, 2.0f);
        } catch (Exception e) {
            ShinobiCore.LOGGER.error("[SOUND] Failed to play deflect sound: {}", e.getMessage());
        }
    }

    public static void playChakraModeSound(boolean activate) {
        MinecraftClient client = MinecraftClient.getInstance();
        ClientPlayerEntity player = client.player;
        if (player == null) return;

        try {
            if (activate) {
                player.playSound(SoundEvents.BLOCK_BEACON_ACTIVATE, SoundCategory.PLAYERS, 0.8f, 1.0f);
                player.playSound(SoundEvents.ENTITY_PLAYER_LEVELUP, SoundCategory.PLAYERS, 0.3f, 0.8f);
            } else {
                player.playSound(SoundEvents.BLOCK_BEACON_DEACTIVATE, SoundCategory.PLAYERS, 0.6f, 0.8f);
            }
        } catch (Exception ignored) {}
    }

    public static void setCustomSoundsRegistered(boolean registered) {
        customSoundsRegistered = registered;
    }
}
'@

# ==========================================
# 5. ТОЧЕЧНЫЕ ПРАВКИ: ClientInputHandler.java
# ==========================================
Write-Host "`n[5/8] ClientInputHandler.java (Звук чакра-мода)..." -ForegroundColor Cyan
$chakraOld = @"
        if (KeyBindings.CHAKRA_MODE.wasPressed()) {
            ClientNinjaState.chakraMode = !ClientNinjaState.chakraMode;
            if (ClientNinjaState.chakraMode) com.example.shinobicore.client.combat.ChakraBurstAnimations.playBurst(client.player); // PHASE_A_BURST_HOOK
"@
$chakraNew = @"
        if (KeyBindings.CHAKRA_MODE.wasPressed()) {
            ClientNinjaState.chakraMode = !ClientNinjaState.chakraMode;
            // === ЗВУК ЧАКРА-МОДА ===
            TaijutsuSounds.playChakraModeSound(ClientNinjaState.chakraMode);
            if (ClientNinjaState.chakraMode) com.example.shinobicore.client.combat.ChakraBurstAnimations.playBurst(client.player); // PHASE_A_BURST_HOOK
"@
Update-File "$base\client\ClientInputHandler.java" $chakraOld $chakraNew

# ==========================================
# 6. ТОЧЕЧНЫЕ ПРАВКИ: KenjutsuClientHandler.java
# ==========================================
Write-Host "`n[6/8] KenjutsuClientHandler.java (Звуки катаны)..." -ForegroundColor Cyan
Update-File "$base\client\combat\KenjutsuClientHandler.java" "TaijutsuSounds.playWhoosh();" "TaijutsuSounds.playKatanaSlash(comboStep);"
Update-File "$base\client\combat\KenjutsuClientHandler.java" "player.playSound(SoundEvents.ITEM_SHIELD_BLOCK, 0.4f, 1.5f);" "TaijutsuSounds.playKatanaDeflectSound();"

# ==========================================
# 7. ТОЧЕЧНЫЕ ПРАВКИ: ShinobiCore.java
# ==========================================
Write-Host "`n[7/8] ShinobiCore.java (Серверные звуки расенгана)..." -ForegroundColor Cyan
$rsThrowOld = @"
                        if (e instanceof RasenshurikenEntity rs && !rs.isLaunched()) {
                            Vec3d dir = player.getRotationVector();
                            rs.launch(dir);
                            ShinobiCore.LOGGER.info("[SERVER] Rasenshuriken launched by {}",
"@
$rsThrowNew = @"
                        if (e instanceof RasenshurikenEntity rs && !rs.isLaunched()) {
                            Vec3d dir = player.getRotationVector();
                            rs.launch(dir);
                            com.example.shinobicore.jutsu.JutsuSoundHelper.playRasenshurikenThrowSound(player);
                            ShinobiCore.LOGGER.info("[SERVER] Rasenshuriken launched by {}",
"@
Update-File "$base\ShinobiCore.java" $rsThrowOld $rsThrowNew

$rgStrikeOld = @"
                            net.minecraft.sound.SoundCategory.PLAYERS, 1.5f, 1.2f);
                    }
                    rasengan.discard();
"@
$rgStrikeNew = @"
                            net.minecraft.sound.SoundCategory.PLAYERS, 1.5f, 1.2f);
                    }
                    com.example.shinobicore.jutsu.JutsuSoundHelper.playRasenganStrikeSound(player);
                    rasengan.discard();
"@
Update-File "$base\ShinobiCore.java" $rgStrikeOld $rgStrikeNew

# ==========================================
# 8. УДАЛЕНИЕ МЁРТВОГО КОДА: GameRendererMixin.java
# ==========================================
Write-Host "`n[8/8] Удаление GameRendererMixin.java..." -ForegroundColor Cyan
$deadFile = "$base\mixin\GameRendererMixin.java"
if (Test-Path $deadFile) {
    Remove-Item $deadFile -Force
    Write-Host "[OK] Удален мёртвый файл: $deadFile" -ForegroundColor Green
} else {
    Write-Host "[~] Файл уже удален или не существует." -ForegroundColor Yellow
}

Write-Host "`n==================================================" -ForegroundColor Green
Write-Host "  ВСЕ ИЗМЕНЕНИЯ УСПЕШНО ПРИМЕНЕНЫ!" -ForegroundColor Green
Write-Host "==================================================" -ForegroundColor Green
Write-Host "Теперь запустите сборку:" -ForegroundColor Cyan
Write-Host ".\gradlew.bat build" -ForegroundColor White