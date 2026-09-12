package com.example.shinobicore.client.parkour.util;

import net.minecraft.client.MinecraftClient;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.sound.SoundCategory;
import net.minecraft.sound.SoundEvents;

public class ParkourSounds {
    public static void playSlide() {
        play(SoundEvents.BLOCK_GRAVEL_STEP, 0.6f, 0.8f);
    }

    public static void playSlideLoop() {
        play(SoundEvents.BLOCK_SAND_STEP, 0.3f, 1.2f);
    }

    public static void playWallStick() {
        play(SoundEvents.BLOCK_STONE_HIT, 0.8f, 1.0f);
    }

    public static void playWallRunStep() {
        play(SoundEvents.BLOCK_STONE_STEP, 0.5f, 1.1f);
    }

    public static void playEdgeGrab() {
        play(SoundEvents.BLOCK_WOOD_HIT, 0.9f, 0.9f);
    }

    public static void playEdgeClimb() {
        play(SoundEvents.ENTITY_PLAYER_ATTACK_STRONG, 0.6f, 1.2f);
    }

    public static void playChargeHum(float charge) {
        float pitch = 0.8f + charge * 0.5f;
        play(SoundEvents.BLOCK_BEACON_AMBIENT, 0.3f, pitch);
    }

    public static void playChargedJump() {
        play(SoundEvents.ENTITY_GENERIC_EXPLODE, 0.5f, 1.5f);
    }

    public static void playRoll() {
        play(SoundEvents.BLOCK_WOOL_FALL, 0.7f, 1.1f);
    }

    // === Movement Pack (1.1.4): обратная связь шагов ===

    /** Шаг по воде: короткий всплеск с вариацией высоты. */
    public static void playWaterStep() {
        play(SoundEvents.ENTITY_PLAYER_SPLASH, 0.22f, 1.35f + (float) Math.random() * 0.35f);
    }

    /** Касание воды после прыжка/падения. */
    public static void playWaterTouchdown() {
        play(SoundEvents.ENTITY_GENERIC_SPLASH, 0.65f, 0.95f);
    }

    /** Двойной прыжок: резкий взмах. */
    public static void playAirJump() {
        play(SoundEvents.ENTITY_PLAYER_ATTACK_SWEEP, 0.45f, 1.35f);
    }

    /** Приземление: глухой удар, громкость от силы. */
    public static void playLandThud(float strength) {
        float vol = Math.min(0.75f, 0.25f + strength * 0.18f);
        float pitch = Math.max(0.55f, 1.0f - strength * 0.12f);
        play(SoundEvents.BLOCK_GRAVEL_FALL, vol, pitch);
    }

    /** Шаг при подъёме по стене (быстрый режим; тихий режим звук не играет). */
    public static void playClimbStep() {
        play(SoundEvents.BLOCK_STONE_STEP, 0.34f, 0.9f + (float) Math.random() * 0.25f);
    }

    private static void play(net.minecraft.sound.SoundEvent event, float volume, float pitch) {
        MinecraftClient client = MinecraftClient.getInstance();
        ClientPlayerEntity player = client.player;
        if (player == null) return;
        player.playSound(event, SoundCategory.PLAYERS, volume, pitch);
    }
}