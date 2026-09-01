package com.example.shinobicore.client;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.client.combat.TaijutsuClientHandler;
import com.example.shinobicore.client.combat.TaijutsuKickHandler;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.util.math.MathHelper;
import net.minecraft.util.math.Vec3d;
import com.example.shinobicore.client.ClientNinjaStateHolder;

public class CinematicCamera {
    // === OVER-THE-SHOULDER: НАСТРОЙКИ КАМЕРЫ (как в Gears of War / RE4) ===
    // Сильное смещение вправо — камера за правым плечом
    private static final float SHOULDER_OFFSET_RIGHT = 0.75f;
    // Чуть выше плеча (не головы!)
    private static final float SHOULDER_OFFSET_UP = 0.05f;
    // ПРИБЛИЖЕНИЕ камеры (forward offset) — камера ближе к игроку
    private static final float FORWARD_OFFSET = 1.3f;
    // Базовое расстояние — меньше чем ванила (которая 4.0)
    private static final float BASE_DISTANCE_REDUCTION = 0.8f;

    // === ПЛАВНОЕ СЛЕДОВАНИЕ (высокий коэфф = плавно) ===
    private static final float POSITION_SMOOTHING = 0.18f;
    private static final float OFFSET_SMOOTHING = 0.12f;

    // Текущие плавные значения
    private static float currentRightOffset = 0f;
    private static float currentUpOffset = 0f;
    private static float currentForwardOffset = 0f;
    private static float currentDistanceReduction = 0f;

    // Лёгкая тряска
    private static float shakeIntensity = 0f;
    private static final float SHAKE_DECAY = 0.85f;

    private static boolean enabled = true;

    public static void tick(MinecraftClient client) {
        if (!enabled || client.player == null) return;

        ClientPlayerEntity player = client.player;
        boolean chakraMode = ClientNinjaStateHolder.get().isChakraMode() && ChakraHudRenderer.currentChakra > 0;
        boolean sprinting = player.isSprinting();
        boolean attacking = TaijutsuClientHandler.isAttacking() || TaijutsuKickHandler.isOnCooldown();

        // Целевые значения
        float targetRight = SHOULDER_OFFSET_RIGHT;
        float targetUp = SHOULDER_OFFSET_UP;
        float targetForward = FORWARD_OFFSET;
        float targetDistanceRed = BASE_DISTANCE_REDUCTION;

        // В чакра-режиме чуть отдаляем для эпичности (но всё равно ближе ванилы)
        if (chakraMode) {
            targetForward -= 0.3f;
            targetRight += 0.05f;
        }

        // При спринте — чуть шире плечо
        if (sprinting && !chakraMode) {
            targetRight += 0.1f;
            targetForward -= 0.2f;
        }

        // Плавная интерполяция
        currentRightOffset = MathHelper.lerp(OFFSET_SMOOTHING, currentRightOffset, targetRight);
        currentUpOffset = MathHelper.lerp(OFFSET_SMOOTHING, currentUpOffset, targetUp);
        currentForwardOffset = MathHelper.lerp(POSITION_SMOOTHING, currentForwardOffset, targetForward);
        currentDistanceReduction = MathHelper.lerp(POSITION_SMOOTHING, currentDistanceReduction, targetDistanceRed);

        // Тряска при ударе (очень мягкая)
        if (attacking) {
            shakeIntensity = Math.max(shakeIntensity, 0.05f);
        }
        shakeIntensity *= SHAKE_DECAY;
        if (shakeIntensity < 0.001f) shakeIntensity = 0f;
    }

    public static float getRightOffset() {
        return currentRightOffset;
    }

    public static float getUpOffset() {
        return currentUpOffset;
    }

    /**
     * Смещение вперёд (по направлению взгляда) — приближает камеру.
     * Положительное значение = ближе к игроку.
     */
    public static float getForwardOffset() {
        return currentForwardOffset;
    }

    /**
     * На сколько сократить расстояние от игрока (с учётом клипинга стен).
     */
    public static float getDistanceReduction() {
        return currentDistanceReduction;
    }

    public static void addShake(float intensity) {
        shakeIntensity = Math.max(shakeIntensity, intensity);
    }

    public static Vec3d getShakeOffset() {
        if (shakeIntensity < 0.001f) return Vec3d.ZERO;
        double x = (Math.random() - 0.5) * shakeIntensity * 0.05;
        double y = (Math.random() - 0.5) * shakeIntensity * 0.05;
        double z = (Math.random() - 0.5) * shakeIntensity * 0.05;
        return new Vec3d(x, y, z);
    }

    public static boolean isEnabled() {
        return enabled;
    }

    public static void setEnabled(boolean value) {
        enabled = value;
    }

    public static void reset() {
        currentRightOffset = 0f;
        currentUpOffset = 0f;
        currentForwardOffset = 0f;
        currentDistanceReduction = 0f;
        shakeIntensity = 0f;
    }
}