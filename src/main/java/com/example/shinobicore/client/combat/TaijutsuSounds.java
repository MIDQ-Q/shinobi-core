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