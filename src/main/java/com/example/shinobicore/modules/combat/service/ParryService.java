package com.example.shinobicore.modules.combat.service;

import com.example.shinobicore.core.api.ModuleContext;
import com.example.shinobicore.core.log.ShinobiLogger;
import com.example.shinobicore.core.service.CoreServices;
import com.example.shinobicore.core.api.ChakraApi;
import com.example.shinobicore.core.api.StatsApi;
import com.example.shinobicore.modules.combat.CombatModule;
import com.example.shinobicore.modules.combat.common.Stance;
import com.example.shinobicore.modules.combat.component.CombatComponent;
import com.example.shinobicore.modules.combat.component.CombatComponentKey;
import com.example.shinobicore.modules.combat.config.CombatConfig;
import net.minecraft.server.MinecraftServer;
import net.minecraft.server.network.ServerPlayerEntity;

public final class ParryService {
    private static ModuleContext ctx;

    public static void init(ModuleContext context) {
        ctx = context;
    }

    public static void attemptParry(ServerPlayerEntity defender, long clientPressTimeMs) {
        CombatComponent comp = CombatComponentKey.KEY.getNullable(defender);
        if (comp == null || comp.getStance() != Stance.DEFENSIVE) return;

        long now = System.currentTimeMillis();
        if (now < comp.getParryFailRecoveryUntil()) return; // Still in recovery

        long windowMs = calculateParryWindow(defender);
        comp.setParrying(true);
        
        // Grant chakra on successful parry attempt (simplified logic)
        CoreServices.get(ChakraApi.class).ifPresent(chakra -> {
            chakra.add(defender, CombatConfig.get().parry.successChakraGain);
        });

        ShinobiLogger.module(CombatModule.ID, "Player " + defender.getName().getString() + " attempted parry");
    }

    public static void serverTick(MinecraftServer server) {
        // TODO: Check parry window expiration and reset isParrying flag
    }

    private static long calculateParryWindow(ServerPlayerEntity player) {
        CombatConfig cfg = CombatConfig.get();
        int perception = CoreServices.get(StatsApi.class)
                .map(api -> api.getStatLevel(player, "perception"))
                .orElse(0);
        
        long window = (long) (cfg.parry.baseWindowMs * (1.0 - perception * 0.003));
        return Math.max(80, window);
    }
}