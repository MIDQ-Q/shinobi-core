package com.example.shinobicore.stat.component;

import net.fabricmc.fabric.api.networking.v1.ServerPlayNetworking;
import net.minecraft.server.network.ServerPlayerEntity;

public final class ComponentSyncHandler {
    private ComponentSyncHandler() {}

    public static void syncAll(ServerPlayerEntity player) {
        syncChakra(player); syncStats(player); syncClan(player);
        syncJutsu(player); syncDojutsu(player); syncParkour(player); syncCombat(player);
    }
    public static void syncChakra(ServerPlayerEntity player) { IChakraComponent c = NinjaComponents.getChakra(player); if (c != null) NinjaComponents.CHAKRA.sync(player); }
    public static void syncStats(ServerPlayerEntity player) { IStatsComponent c = NinjaComponents.getStats(player); if (c != null) NinjaComponents.STATS.sync(player); }
    public static void syncClan(ServerPlayerEntity player) { IClanComponent c = NinjaComponents.getClan(player); if (c != null) NinjaComponents.CLAN.sync(player); }
    public static void syncJutsu(ServerPlayerEntity player) { IJutsuComponent c = NinjaComponents.getJutsu(player); if (c != null) NinjaComponents.JUTSU.sync(player); }
    public static void syncDojutsu(ServerPlayerEntity player) { IDojutsuComponent c = NinjaComponents.getDojutsu(player); if (c != null) NinjaComponents.DOJUTSU.sync(player); }
    public static void syncParkour(ServerPlayerEntity player) { IParkourComponent c = NinjaComponents.getParkour(player); if (c != null) NinjaComponents.PARKOUR.sync(player); }
    public static void syncCombat(ServerPlayerEntity player) { ICombatComponent c = NinjaComponents.getCombat(player); if (c != null) NinjaComponents.COMBAT.sync(player); }
}