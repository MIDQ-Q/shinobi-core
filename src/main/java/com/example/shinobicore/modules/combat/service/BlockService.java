package com.example.shinobicore.modules.combat.service;

import com.example.shinobicore.core.api.ModuleContext;
import com.example.shinobicore.core.log.ShinobiLogger;
import com.example.shinobicore.core.service.CoreServices;
import com.example.shinobicore.core.api.ChakraApi;
import com.example.shinobicore.modules.combat.CombatModule;
import com.example.shinobicore.modules.combat.common.Stance;
import com.example.shinobicore.modules.combat.component.CombatComponent;
import com.example.shinobicore.modules.combat.component.CombatComponentKey;
import com.example.shinobicore.modules.combat.config.CombatConfig;
import net.minecraft.server.MinecraftServer;
import net.minecraft.server.network.ServerPlayerEntity;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

public final class BlockService {
    private static final Map<UUID, DrainAccumulator> accumulators = new ConcurrentHashMap<>();
    private static ModuleContext ctx;

    public static void init(ModuleContext context) {
        ctx = context;
    }

    public static void startBlock(ServerPlayerEntity player) {
        CombatComponent comp = CombatComponentKey.KEY.getNullable(player);
        if (comp == null || comp.getStance() != Stance.AGGRESSIVE) return;
        
        comp.setBlocking(true);
        accumulators.putIfAbsent(player.getUuid(), new DrainAccumulator(CombatConfig.get().block.drainPerSecond));
        ShinobiLogger.module(CombatModule.ID, "Player " + player.getName().getString() + " started blocking");
    }

    public static void stopBlock(ServerPlayerEntity player) {
        CombatComponent comp = CombatComponentKey.KEY.getNullable(player);
        if (comp != null) comp.setBlocking(false);
        accumulators.remove(player.getUuid());
    }

    public static void serverTick(MinecraftServer server) {
        for (ServerPlayerEntity player : server.getPlayerManager().getPlayerList()) {
            CombatComponent comp = CombatComponentKey.KEY.getNullable(player);
            if (comp == null || !comp.isBlocking()) continue;

            DrainAccumulator acc = accumulators.get(player.getUuid());
            if (acc == null) continue;

            // 1 tick = 0.05 seconds
            int fatigueGain = acc.tick(0.05);
            if (fatigueGain > 0) {
                CoreServices.get(ChakraApi.class).ifPresent(chakra -> {
                    chakra.addFatigue(player, fatigueGain);
                });
            }
        }
    }

    public static float calculateDamageReduction() {
        return CombatConfig.get().block.damageReductionMultiplier;
    }
}