package com.example.shinobicore.client.parkour.actions;

import com.example.shinobicore.client.ChakraHudRenderer;
import com.example.shinobicore.client.ClientNinjaState;
import com.example.shinobicore.client.parkour.util.ParkourSounds;
import com.example.shinobicore.client.parkour.util.WallDetector;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.util.math.Vec3d;
import com.example.shinobicore.client.ClientNinjaStateHolder;

public class WallRunAction implements ParkourAction {
    public static final String ID = "wall_run";

    private static final int MAX_TICKS = 40;  // 2 сек максимум
    private static final float MIN_SPEED = 0.15f;  // ниже — wall run заканчивается
    private static final float REQUIRED_SPEED = 0.2f;  // нужен разбег
    private static final float GRAVITY_FACTOR = 0.4f;  // 40% от нормальной гравитации
    private static final float TANGENTIAL_BOOST = 0.08f;  // добавка скорости вдоль стены за тик

    private boolean active = false;
    private int ticksRunning = 0;

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
        if (ticksRunning > MAX_TICKS || player.isOnGround()) {
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
        
        // Применяем движение вдоль стены + буст
        Vec3d newHoriz = tangent.multiply(horizSpeed + TANGENTIAL_BOOST);
        
        // Ослабленная гравитация
        double newVy = v.y - 0.08 * GRAVITY_FACTOR;  // 0.08 * 0.4 = 0.032 вместо 0.08
        
        player.setVelocity(newHoriz.x, newVy, newHoriz.z);
        player.velocityModified = true;
        
        // Звук шагов каждые 8 тиков
        if (ticksRunning % 8 == 0) {
            ParkourSounds.playWallRunStep();
        }
    }

    @Override
    public void deactivate(ClientPlayerEntity player, ParkourContext ctx) {
        active = false;
        ticksRunning = 0;
        ctx.setCooldown(ID, getCooldownTicks());
        ctx.clearActive(ID);
    }

    public boolean isActive() { return active; }

    @Override
    public int getCooldownTicks() { return 20; }  // 1 сек кулдаун

    @Override
    public float getFatigueCost() { return 0.05f; }  // за тик
}