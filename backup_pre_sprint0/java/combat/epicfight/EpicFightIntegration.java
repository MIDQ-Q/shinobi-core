package com.example.shinobicore.combat.epicfight;

/**
 * DEPRECATED (Sprint 2, ADR-04 v2).
 *
 * Epic Fight has no Fabric port for Minecraft 1.20.1, therefore
 * the combat animation layer was migrated to Better Combat.
 * See com.example.shinobicore.combat.bettercombat.BetterCombatIntegration.
 *
 * This stub is kept only to avoid dangling references and will be
 * removed in a later cleanup sprint.
 */
public final class EpicFightIntegration {

    private EpicFightIntegration() {}

    /**
     * No-op. Kept for binary compatibility with old call sites.
     */
    public static void detect() {
        // Intentionally empty. Better Combat is the active integration.
    }

    /**
     * Always false. Epic Fight is not supported on Fabric 1.20.1.
     */
    public static boolean isPresent() {
        return false;
    }
}