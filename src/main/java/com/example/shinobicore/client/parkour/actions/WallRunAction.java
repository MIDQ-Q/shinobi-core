package com.example.shinobicore.client.parkour.actions;

import com.example.shinobicore.client.ChakraHudRenderer;
import com.example.shinobicore.client.movement.MovementFeel;
import com.example.shinobicore.client.parkour.util.ParkourSounds;
import com.example.shinobicore.client.parkour.util.WallDetector;
import com.example.shinobicore.config.ModConfig;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.util.math.Vec3d;
import com.example.shinobicore.client.ClientNinjaStateHolder;

public class WallRunAction implements ParkourAction {
    public static final String ID = "wall_run";

    // CFG: было static final 40 при живом ModConfig.parkour.wallRunMaxTicks (фантом).
    // static final инициализируется ДО ModConfig.load(), поэтому методом, а не полем.
    private static int maxTicks() {
        int v = com.example.shinobicore.config.ModConfig.instance.parkour.wallRunMaxTicks;
        return v > 0 ? v : 40;
    }
    private static final float MIN_SPEED = 0.15f;  // ниже — wall run заканчивается
    private static final float REQUIRED_SPEED = 0.2f;  // нужен разбег
    private static final float GRAVITY_FACTOR = 0.4f;  // 40% от нормальной гравитации
    private static final float TANGENTIAL_BOOST = 0.08f;  // добавка скорости вдоль стены за тик

    private boolean active = false;
    private int ticksRunning = 0;

    /** Movement Pack: потолок скорости вдоль стены (конфиг movement.wallRunMaxSpeed). */
    private static float maxRunSpeed() {
        float v = ModConfig.instance.movement.wallRunMaxSpeed;
        return v > 0.05f ? v : 0.36f;
    }

    @Override
    public String getId() { return ID; }

    @Override
    public boolean canActivate(ClientPlayerEntity player, ParkourContext ctx) {
        // Только в чакра-режиме
        if (!ClientNinjaStateHolder.get().isChakraMode()) return false;
        if (ChakraHudRenderer.currentChakra <= 0) return false;
        if (ChakraHudRenderer.exhausted) return false;
        if (ctx.isOnCooldown(ID)) return false;

        // Должен быть в воздухе и прилипнуть к стене
        if (player.isOnGround()) return false;
        Vec3d wallNormal = WallDetector.getWallNormal(player);
        if (wallNormal == null) return false;

        // Должен нажимать W (вперёд)
        if (!player.input.pressingForward) return false;

        // Должен иметь достаточную горизонтальную скорость
        Vec3d horiz = new Vec3d(player.getVelocity().x, 0, player.getVelocity().z);
        return horiz.length() >= REQUIRED_SPEED;
    }

    @Override
    public void activate(ClientPlayerEntity player, ParkourContext ctx) {
        active = true;
        ticksRunning = 0;
        ctx.resetActive(ID);
        ParkourSounds.playWallStick();  // звук прилипания при старте
    }

    @Override
    public void tick(ClientPlayerEntity player, ParkourContext ctx) {
        if (!active) return;

        ticksRunning++;

        // Условия выхода
        if (ticksRunning > maxTicks() || player.isOnGround()) {
            deactivate(player, ctx);
            return;
        }

        // Проверяем что всё ещё прилип к стене
        Vec3d wallNormal = WallDetector.getWallNormal(player);
        if (wallNormal == null) {
            deactivate(player, ctx);
            return;
        }

        // Если игрок отпустил W — переходим в wall slide (деактивируем wall run)
        if (!player.input.pressingForward) {
            deactivate(player, ctx);
            return;
        }

        Vec3d v = player.getVelocity();
        double horizSpeed = Math.sqrt(v.x * v.x + v.z * v.z);

        if (horizSpeed < MIN_SPEED) {
            deactivate(player, ctx);
            return;
        }

        // Вычисляем касательный вектор (вдоль стены)
        Vec3d up = new Vec3d(0, 1, 0);
        Vec3d tangent = wallNormal.crossProduct(up).normalize();

        // Определяем направление вдоль стены (по взгляду игрока)
        Vec3d lookHoriz = new Vec3d(player.getRotationVector().x, 0, player.getRotationVector().z).normalize();
        double dot = tangent.dotProduct(lookHoriz);
        if (dot < 0) tangent = tangent.negate();  // инвертируем если смотрит в противоположную сторону

        // === Movement Pack: разгон с ПОТОЛКОМ (раньше скорость росла бесконечно) ===
        double targetSpeed = Math.min(horizSpeed + TANGENTIAL_BOOST, maxRunSpeed());
        // последние 25% дистанции — плавное затухание (забег «выдыхается», а не обрывается)
        int maxT = maxTicks();
        if (ticksRunning > maxT * 3 / 4) {
            targetSpeed *= 0.965;
        }
        Vec3d newHoriz = tangent.multiply(targetSpeed);

        // Ослабленная гравитация; удержание прыжка слегка поднимает вдоль стены
        // (забег вверх по наклонной траектории, как в аниме)
        double newVy = v.y - 0.08 * GRAVITY_FACTOR;
        if (player.input.jumping) {
            newVy = Math.max(newVy, 0.045);
        }

        player.setVelocity(newHoriz.x, newVy, newHoriz.z);
        player.velocityModified = true;

        // === Movement Pack: шаги (пыль у стены + звук), фаза для анимации, наклон камеры ===
        MovementFeel.wallRunTick(player, wallNormal, targetSpeed);
    }

    @Override
    public void deactivate(ClientPlayerEntity player, ParkourContext ctx) {
        active = false;
        ticksRunning = 0;
        MovementFeel.wallRunEnd();
        ctx.setCooldown(ID, getCooldownTicks());
        ctx.clearActive(ID);
    }

    public boolean isActive() { return active; }

    @Override
    public int getCooldownTicks() { return 20; }  // 1 сек кулдаун

    @Override
    public float getFatigueCost() { return 0.05f; }  // за тик
}