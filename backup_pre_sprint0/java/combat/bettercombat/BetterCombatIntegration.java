package com.example.shinobicore.combat.bettercombat;

import com.example.shinobicore.ShinobiCore;
import net.fabricmc.loader.api.FabricLoader;

/**
 * Better Combat soft integration (HLD Section 4, ADR-04 v2).
 *
 * Better Combat (Fabric 1.20.1) is data-driven: it reads weapon
 * attributes from datapack JSON files, so our katana gets swing
 * animations and combos purely via
 * data/shinobicore/weapon_attributes/katana.json
 *
 * No compile dependency on BC classes is needed. This class only
 * detects BC at runtime to tune logging and future hooks.
 *
 * To enable: drop Better Combat + PlayerAnimator jars into libs/
 * (see libs/README.txt). Loom loads them via fileTree("libs").
 */
public final class BetterCombatIntegration {

    private static boolean present = false;

    private BetterCombatIntegration() {}

    /**
     * Runtime detection. Called from CombatBootstrap.init().
     */
    public static void detect() {
        present = FabricLoader.getInstance().isModLoaded("bettercombat");
        if (present) {
            ShinobiCore.LOGGER.info("Better Combat detected - BC weapon attributes ACTIVE (katana datapack)");
        } else {
            ShinobiCore.LOGGER.info("Better Combat not present - vanilla swing fallback. Drop BC jar into libs/ to enable animations");
        }
    }

    public static boolean isPresent() {
        return present;
    }
}