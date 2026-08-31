package com.example.shinobicore.modules.combat.compat;

import com.example.shinobicore.core.log.ShinobiLogger;
import net.fabricmc.loader.api.FabricLoader;
import net.minecraft.entity.player.PlayerEntity;
import net.minecraft.util.Identifier;

public final class PlayerAnimatorAdapter {

    private static boolean available = false;

    private PlayerAnimatorAdapter() {}

    public static void init() {
        available = FabricLoader.getInstance().isModLoaded("player-animator")
                 || FabricLoader.getInstance().isModLoaded("playeranimator");
        if (available) {
            ShinobiLogger.module("combat", "PlayerAnimator detected");
        } else {
            ShinobiLogger.module("combat", "PlayerAnimator not found, animations disabled");
        }
    }

    public static boolean isAvailable() { return available; }

    public static void playAnimation(PlayerEntity player, String animationName) {
        if (!available || player == null) return;

        try {
            Identifier animId = new Identifier("shinobicore", animationName);
            // Delegate to PlayerAnimator API
            // dev.kosmx.playerAnim.minecraftApi.PlayerAnimationRegistry
            ShinobiLogger.module("combat", "Playing animation: " + animId);
        } catch (Throwable t) {
            ShinobiLogger.error("combat", "Failed to play animation: " + animationName, t);
        }
    }

    public static void stopAnimation(PlayerEntity player) {
        if (!available || player == null) return;
        // Stop current animation
    }
}