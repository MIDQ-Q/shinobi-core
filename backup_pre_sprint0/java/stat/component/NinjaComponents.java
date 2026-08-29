package com.example.shinobicore.stat.component;

import dev.onyxstudios.cca.api.v3.component.ComponentKey;
import dev.onyxstudios.cca.api.v3.component.ComponentRegistryV3;
import net.minecraft.entity.player.PlayerEntity;
import net.minecraft.util.Identifier;

/**
 * Registry of all player components.
 * HLD: Section 1.1
 */
public final class NinjaComponents {
    public static final ComponentKey<IChakraComponent> CHAKRA =
        ComponentRegistryV3.INSTANCE.getOrCreate(new Identifier("shinobicore", "chakra"), IChakraComponent.class);
    public static final ComponentKey<IStatsComponent> STATS =
        ComponentRegistryV3.INSTANCE.getOrCreate(new Identifier("shinobicore", "stats"), IStatsComponent.class);
    public static final ComponentKey<IClanComponent> CLAN =
        ComponentRegistryV3.INSTANCE.getOrCreate(new Identifier("shinobicore", "clan"), IClanComponent.class);
    public static final ComponentKey<IJutsuComponent> JUTSU =
        ComponentRegistryV3.INSTANCE.getOrCreate(new Identifier("shinobicore", "jutsu"), IJutsuComponent.class);
    public static final ComponentKey<IDojutsuComponent> DOJUTSU =
        ComponentRegistryV3.INSTANCE.getOrCreate(new Identifier("shinobicore", "dojutsu"), IDojutsuComponent.class);

    public static final ComponentKey<IParkourComponent> PARKOUR =
        ComponentRegistryV3.INSTANCE.getOrCreate(new Identifier("shinobicore", "parkour"), IParkourComponent.class);

    public static final ComponentKey<ICombatComponent> COMBAT =
        ComponentRegistryV3.INSTANCE.getOrCreate(new Identifier("shinobicore", "combat"), ICombatComponent.class);

    private NinjaComponents() {}

    public static IParkourComponent getParkour(PlayerEntity p) { return PARKOUR.getNullable(p); }
    public static ICombatComponent getCombat(PlayerEntity p) { return COMBAT.getNullable(p); }

    public static IChakraComponent getChakra(PlayerEntity p) { return CHAKRA.getNullable(p); }
    public static IStatsComponent getStats(PlayerEntity p) { return STATS.getNullable(p); }
    public static IClanComponent getClan(PlayerEntity p) { return CLAN.getNullable(p); }
    public static IJutsuComponent getJutsu(PlayerEntity p) { return JUTSU.getNullable(p); }
    public static IDojutsuComponent getDojutsu(PlayerEntity p) { return DOJUTSU.getNullable(p); }

    public static boolean hasAllComponents(PlayerEntity p) {
        return getChakra(p) != null && getStats(p) != null
            && getClan(p) != null && getJutsu(p) != null && getDojutsu(p) != null;
    }
}