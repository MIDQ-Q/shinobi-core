package com.example.shinobicore.modules.clans.service;
import com.example.shinobicore.core.event.CoreEvents;
import com.example.shinobicore.core.service.CoreServices;
import com.example.shinobicore.core.api.ProgressionApi;
import com.example.shinobicore.core.log.ShinobiLogger;
import com.example.shinobicore.modules.clans.component.ClanComponent;
import com.example.shinobicore.modules.clans.component.ClanComponentKey;
import com.example.shinobicore.modules.clans.config.ClansConfig;
import com.example.shinobicore.modules.clans.data.ClanDefinition;
import com.example.shinobicore.modules.clans.data.ClanRegistry;
import com.example.shinobicore.modules.clans.event.*;
import com.example.shinobicore.modules.clans.network.ClansPackets;
import net.minecraft.server.network.ServerPlayerEntity;
import java.util.Optional;
public final class ClanService {
    public static void init() {}
    public static boolean changeClan(ServerPlayerEntity player, String newClanId) {
            boolean isOperator = player.hasPermissionLevel(2);
    if (isOperator && !ClansConfig.ALLOW_OPERATOR_CHANGE) return false;
    if (!isOperator && !ClansConfig.ALLOW_PLAYER_CHANGE) return false;
    if (!isOperator) return false; // Player change requires separate UI flow (Sprint 2)
        ClanDefinition newClan = ClanRegistry.get(newClanId).orElse(null);
        if (newClan == null) return false;
        Optional<ClanComponent> compOpt = ClanComponentKey.get(player);
        if (compOpt.isEmpty()) return false;
        ClanComponent comp = compOpt.get();
        String oldClanId = comp.getClanId();
        if (oldClanId != null && !"none".equals(oldClanId) && ClansConfig.REMOVE_CLAN_JUTSU_ON_CHANGE) {
            ClanRegistry.get(oldClanId).ifPresent(oldClan -> {
                for (String jutsuId : oldClan.exclusiveJutsu()) CoreEvents.publish(new ClanJutsuLockedEvent(player, jutsuId));
            });
        }
        if (ClansConfig.RESET_REPUTATION_ON_CHANGE) ReputationService.resetAll(player);
        comp.setClanId(newClanId);
        CoreServices.get(ProgressionApi.class).ifPresent(prog -> {
            for (String jutsuId : newClan.startingJutsu()) {
                prog.unlockNode(player, jutsuId);
                CoreEvents.publish(new ClanJutsuUnlockedEvent(player, jutsuId));
            }
        });
        if (newClan.dojutsuHook() != null && ClansConfig.RESET_DOJUTSU_ON_CHANGE) DojutsuHookService.applyHook(player, newClanId);
        CoreEvents.publish(new ClanChangedEvent(player, oldClanId, newClanId));
        syncToClient(player);
        if (ClansConfig.LOG_CLAN_CHANGES) ShinobiLogger.module("clans", "Clan changed: " + oldClanId + " -> " + newClanId);
        return true;
    }
    public static void setClan(ServerPlayerEntity player, String newClanId) { changeClan(player, newClanId); }
    public static void syncToClient(ServerPlayerEntity player) { ClansPackets.sendClanState(player); }
}