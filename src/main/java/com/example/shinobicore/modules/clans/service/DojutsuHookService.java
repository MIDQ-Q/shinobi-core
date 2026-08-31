package com.example.shinobicore.modules.clans.service;
import com.example.shinobicore.core.event.CoreEvents;
import com.example.shinobicore.core.log.ShinobiLogger;
import com.example.shinobicore.modules.clans.data.ClanDefinition;
import com.example.shinobicore.modules.clans.data.ClanRegistry;
import com.example.shinobicore.modules.clans.event.DojutsuHookAppliedEvent;
import net.minecraft.server.network.ServerPlayerEntity;
public final class DojutsuHookService {
    public static void init() {}
    public static void applyHook(ServerPlayerEntity player, String clanId) {
        ClanDefinition clan = ClanRegistry.get(clanId).orElse(null);
        if (clan == null || clan.dojutsuHook() == null) return;
        CoreEvents.publish(new DojutsuHookAppliedEvent(player, clanId, clan.dojutsuHook()));
        ShinobiLogger.module("clans", "Dojutsu hook applied: " + clan.dojutsuHook());
    }
}