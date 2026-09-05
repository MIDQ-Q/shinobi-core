package com.example.shinobicore.compat;

import net.fabricmc.loader.api.FabricLoader;

/** Soft dependency gate for Trinkets / Artifacts mods. */
public final class TrinketsCompat {
    private static Boolean loaded = null;

    private TrinketsCompat() {}

    public static boolean isLoaded() {
        if (loaded == null) {
            loaded = FabricLoader.getInstance().isModLoaded("trinkets")
                || FabricLoader.getInstance().isModLoaded("artifacts");
        }
        return loaded;
    }
}