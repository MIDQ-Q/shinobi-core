package com.example.shinobicore.client.combat;

import com.example.shinobicore.ShinobiCore;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.sound.SoundCategory;
import net.minecraft.sound.SoundEvent;
import net.minecraft.sound.SoundEvents;
import net.minecraft.util.Identifier;

public class TaijutsuSounds {
    // Кастомные звуки (пока используем ванильные как заглушки)
    public static final SoundEvent PUNCH_LIGHT = SoundEvent.of(new Identifier("shinobicore", "punch_light"));
    public static final SoundEvent PUNCH_HEAVY = SoundEvent.of(new Identifier("shinobicore", "punch_heavy"));
    public static final SoundEvent KICK = SoundEvent.of(new Identifier("shinobicore", "kick"));
    public static final SoundEvent WHOOSH = SoundEvent.of(new Identifier("shinobicore", "whoosh"));

    // Флаг для определения, зарегистрированы ли кастомные звуки
    private static boolean customSoundsRegistered = false;

    public static void playPunchSound(int comboStep) {
        MinecraftClient client = MinecraftClient.getInstance();
        ClientPlayerEntity player = client.player;
        if (player == null) {
            ShinobiCore.LOGGER.warn("[SOUND] playPunchSound: player is null");
            return;
        }

        SoundEvent sound;
        String soundName;
        float pitch;

        if (comboStep >= 2) {
            // Тяжёлый удар (шаги 2-3)
            if (customSoundsRegistered) {
                sound = PUNCH_HEAVY;
                soundName = "punch_heavy";
            } else {
                sound = SoundEvents.ENTITY_PLAYER_ATTACK_STRONG;
                soundName = "ENTITY_PLAYER_ATTACK_STRONG (fallback)";
            }
            pitch = 0.9f + (float) Math.random() * 0.2f;
        } else {
            // Лёгкий удар (шаги 0-1)
            if (customSoundsRegistered) {
                sound = PUNCH_LIGHT;
                soundName = "punch_light";
            } else {
                sound = SoundEvents.ENTITY_PLAYER_ATTACK_WEAK;
                soundName = "ENTITY_PLAYER_ATTACK_WEAK (fallback)";
            }
            pitch = 1.0f + (float) Math.random() * 0.2f;
        }

        ShinobiCore.LOGGER.info("[SOUND] Playing punch sound: comboStep={}, sound={}, pitch={:.2f}",
                comboStep, soundName, pitch);

        try {
            player.playSound(sound, SoundCategory.PLAYERS, 1.0f, pitch);
            ShinobiCore.LOGGER.info("[SOUND] ✓ Punch sound played successfully");
        } catch (Exception e) {
            ShinobiCore.LOGGER.error("[SOUND] ✗ Failed to play punch sound: {}", e.getMessage());
            e.printStackTrace();
        }
    }

    public static void playKickSound() {
        MinecraftClient client = MinecraftClient.getInstance();
        ClientPlayerEntity player = client.player;
        if (player == null) {
            ShinobiCore.LOGGER.warn("[SOUND] playKickSound: player is null");
            return;
        }

        SoundEvent sound;
        String soundName;

        if (customSoundsRegistered) {
            sound = KICK;
            soundName = "kick";
        } else {
            sound = SoundEvents.ENTITY_PLAYER_ATTACK_CRIT;
            soundName = "ENTITY_PLAYER_ATTACK_CRIT (fallback)";
        }

        float pitch = 0.95f + (float) Math.random() * 0.1f;

        ShinobiCore.LOGGER.info("[SOUND] Playing kick sound: sound={}, pitch={:.2f}", soundName, pitch);

        try {
            player.playSound(sound, SoundCategory.PLAYERS, 1.0f, pitch);
            ShinobiCore.LOGGER.info("[SOUND] ✓ Kick sound played successfully");
        } catch (Exception e) {
            ShinobiCore.LOGGER.error("[SOUND] ✗ Failed to play kick sound: {}", e.getMessage());
            e.printStackTrace();
        }
    }

    public static void playWhoosh() {
        MinecraftClient client = MinecraftClient.getInstance();
        ClientPlayerEntity player = client.player;
        if (player == null) {
            ShinobiCore.LOGGER.warn("[SOUND] playWhoosh: player is null");
            return;
        }

        SoundEvent sound;
        String soundName;

        if (customSoundsRegistered) {
            sound = WHOOSH;
            soundName = "whoosh";
        } else {
            sound = SoundEvents.ENTITY_PLAYER_ATTACK_SWEEP;
            soundName = "ENTITY_PLAYER_ATTACK_SWEEP (fallback)";
        }

        float pitch = 0.8f + (float) Math.random() * 0.3f;

        ShinobiCore.LOGGER.info("[SOUND] Playing whoosh sound: sound={}, pitch={:.2f}", soundName, pitch);

        try {
            player.playSound(sound, SoundCategory.PLAYERS, 0.6f, pitch);
            ShinobiCore.LOGGER.info("[SOUND] ✓ Whoosh sound played successfully");
        } catch (Exception e) {
            ShinobiCore.LOGGER.error("[SOUND] ✗ Failed to play whoosh sound: {}", e.getMessage());
            e.printStackTrace();
        }
    }

    public static void setCustomSoundsRegistered(boolean registered) {
        customSoundsRegistered = registered;
        ShinobiCore.LOGGER.info("[SOUND] Custom sounds registered: {}", registered);
    }
}