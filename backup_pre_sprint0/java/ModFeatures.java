package com.example.shinobicore;

import com.example.shinobicore.world.feature.ClanVillageFeature;
import net.minecraft.registry.Registries;
import net.minecraft.registry.Registry;
import net.minecraft.util.Identifier;
import net.minecraft.world.gen.feature.DefaultFeatureConfig;
import net.minecraft.world.gen.feature.Feature;

/**
 * S12-04: Feature registration for clan villages.
 */
public class ModFeatures {
    public static final Feature<DefaultFeatureConfig> CLAN_VILLAGE =
        Registry.register(Registries.FEATURE,
            new Identifier(ShinobiCore.MOD_ID, "clan_village"),
            new ClanVillageFeature(DefaultFeatureConfig.CODEC));

    public static void register() {
        ShinobiCore.LOGGER.info("[S12-04] Registered clan village feature");
    }
}