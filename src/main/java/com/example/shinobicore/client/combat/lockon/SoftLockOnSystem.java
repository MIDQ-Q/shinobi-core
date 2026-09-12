package com.example.shinobicore.client.combat.lockon;

import com.example.shinobicore.client.ChakraPhysicsClient;
import com.example.shinobicore.client.combat.TaijutsuClientHandler;
import com.example.shinobicore.client.combat.frenzy.FrenzyClientState;
import com.example.shinobicore.client.parkour.ParkourManager;
import com.example.shinobicore.config.ModConfig;
import net.fabricmc.fabric.api.client.event.lifecycle.v1.ClientTickEvents;
import net.fabricmc.fabric.api.client.networking.v1.ClientPlayConnectionEvents;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.entity.Entity;
import net.minecraft.entity.LivingEntity;
import net.minecraft.entity.mob.MobEntity;
import net.minecraft.entity.mob.Monster;
import net.minecraft.text.Text;
import net.minecraft.util.hit.BlockHitResult;
import net.minecraft.util.hit.HitResult;
import net.minecraft.util.math.MathHelper;
import net.minecraft.util.math.Vec3d;
import net.minecraft.world.RaycastContext;

/**
 * Combat Pack v1 (1.1.4): МЯГКОЕ наведение (soft lock-on).
 *
 * НЕ жёсткий лок: камера не привязывается к цели. Вместо этого:
 *   1. выбор лучшей цели в конусе (дистанция + угол + агрессия + недавний урон);
 *   2. «магнит» камеры — плавная доводка yaw к цели (не более ~2°/тик и только
 *      если цель в пределах половины конуса), игрок всегда может пересилить;
 *   3. рейкаст видимости — сквозь стены не наводим;
 *   4. паркур имеет приоритет: слайд/бег по стене/прилипание — наведение спит;
 *   5. раж 2+ уровня: радиус +20%, магнит +10% (см. план Combat Pack).
 *
 * Целиком клиентская система: серверу ничего не отправляется, античит не
 * задействован (yaw синхронизируется ванильно, как при обычном повороте).
 * Переключение — клавиша lock_on (по умолчанию J).
 */
public final class SoftLockOnSystem {

    private SoftLockOnSystem() {}

    private static boolean enabled = true;
    private static LivingEntity target;
    private static float lockStrength = 0f;
    private static int switchCooldown = 0;

    public static void register() {
        enabled = ModConfig.instance.combat == null || ModConfig.instance.combat.lockOnEnabled;
        ClientTickEvents.END_CLIENT_TICK.register(SoftLockOnSystem::tick);
        ClientPlayConnectionEvents.DISCONNECT.register((handler, client) -> clear());
    }

    public static void toggle(ClientPlayerEntity player) {
        enabled = !enabled;
        if (!enabled) { target = null; lockStrength = 0f; }
        if (player != null) {
            player.sendMessage(Text.literal(enabled ? "\u00a7aLock-On: ON" : "\u00a77Lock-On: OFF"), true);
        }
    }

    public static boolean isEnabled() { return enabled; }
    public static LivingEntity getTarget() { return target; }
    public static float getLockStrength() { return lockStrength; }

    public static void clear() {
        target = null;
        lockStrength = 0f;
        switchCooldown = 0;
    }

    private static ModConfig.Combat cfg() { return ModConfig.instance.combat; }

    private static void tick(MinecraftClient client) {
        ClientPlayerEntity player = client.player;
        if (player == null || client.world == null) { clear(); return; }
        ModConfig.Combat c = cfg();
        if (c == null) return;

        if (switchCooldown > 0) switchCooldown--;

        boolean usable = enabled && c.lockOnEnabled
                && client.currentScreen == null
                && !player.isSpectator()
                && !ParkourManager.isSliding()
                && !ParkourManager.isWallRunning()
                && !ParkourManager.isCrawling()
                && !ChakraPhysicsClient.stickingToWall;

        if (!usable) { decay(); return; }

        LivingEntity best = findTarget(client, player, c);
        if (best != target) {
            if (target == null || !target.isAlive() || target.isRemoved() || switchCooldown == 0) {
                target = best;
                switchCooldown = 10;
            }
        }
        if (target == null || !target.isAlive() || target.isRemoved()
                || target.distanceTo(player) > rangeOf(c) * 1.35f) {
            target = null;
            decay();
            return;
        }

        lockStrength = Math.min(1f, lockStrength + 0.10f);

        // «магнит» камеры: мягкая доводка yaw, только если не атакуем
        if (lockStrength > 0.2f && c.lockOnMagnet > 0f
                && !TaijutsuClientHandler.isAttacking()
                && !player.isUsingItem()) {
            Vec3d to = target.getPos().add(0, target.getHeight() * 0.6, 0).subtract(player.getEyePos());
            if (to.lengthSquared() > 1e-6) {
                float targetYaw = (float) Math.toDegrees(Math.atan2(-to.x, to.z));
                float delta = MathHelper.wrapDegrees(targetYaw - player.getYaw());
                float halfCone = coneDeg(c) * 0.5f;
                if (Math.abs(delta) < halfCone) {
                    float frenzyBoost = FrenzyClientState.getLevel() >= 2 ? 1.1f : 1.0f;
                    float step = MathHelper.clamp(delta * c.lockOnMagnet * lockStrength * frenzyBoost, -2.0f, 2.0f);
                    player.setYaw(player.getYaw() + step);
                }
            }
        }
    }

    private static void decay() {
        lockStrength = Math.max(0f, lockStrength - 0.04f);
        if (lockStrength <= 0f) target = null;
    }

    private static float rangeOf(ModConfig.Combat c) {
        float r = c.lockOnRange > 0 ? c.lockOnRange : 8f;
        if (FrenzyClientState.getLevel() >= 2) r *= 1.2f;
        return r;
    }

    private static float coneDeg(ModConfig.Combat c) {
        return c.lockOnConeDeg > 0 ? c.lockOnConeDeg : 60f;
    }

    private static LivingEntity findTarget(MinecraftClient client, ClientPlayerEntity player, ModConfig.Combat c) {
        double range = rangeOf(c);
        double cosCone = Math.cos(Math.toRadians(coneDeg(c) * 0.5));
        Vec3d eye = player.getEyePos();
        Vec3d look = player.getRotationVector();

        LivingEntity best = null;
        double bestScore = -1e9;
        for (Entity e : client.world.getEntities()) {
            if (!(e instanceof LivingEntity le)) continue;
            if (le == player || !le.isAlive() || le.isRemoved() || le.isInvisible()) continue;
            // враждебные ИЛИ те, кто бьёт игрока
            boolean hostile = le instanceof Monster;
            boolean attackingMe = le instanceof MobEntity mob && mob.getTarget() == player;
            if (!hostile && !attackingMe) continue;

            Vec3d chest = le.getPos().add(0, le.getHeight() * 0.6, 0);
            Vec3d to = chest.subtract(eye);
            double dist = to.length();
            if (dist < 0.3 || dist > range) continue;
            double dot = to.normalize().dotProduct(look);
            if (dot < cosCone) continue;

            // видимость: не наводим сквозь стены
            BlockHitResult hit = client.world.raycast(new RaycastContext(
                    eye, chest, RaycastContext.ShapeType.COLLIDER,
                    RaycastContext.FluidHandling.NONE, player));
            if (hit.getType() == HitResult.Type.BLOCK && hit.getPos().distanceTo(eye) < dist - 0.6) continue;

            double score = 0.45 * (1.0 / dist) + 0.35 * dot
                    + (attackingMe ? 0.2 : 0.0)
                    + (le.hurtTime > 0 ? 0.1 : 0.0);
            if (score > bestScore) { bestScore = score; best = le; }
        }
        return best;
    }
}