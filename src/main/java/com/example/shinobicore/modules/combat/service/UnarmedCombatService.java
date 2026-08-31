package com.example.shinobicore.modules.combat.service;

import com.example.shinobicore.core.api.ModuleContext;
import com.example.shinobicore.core.log.ShinobiLogger;
import com.example.shinobicore.core.service.CoreServices;
import com.example.shinobicore.core.api.StatsApi;
import com.example.shinobicore.modules.combat.CombatModule;
import com.example.shinobicore.modules.combat.config.CombatConfig;
import net.minecraft.entity.LivingEntity;
import net.minecraft.server.network.ServerPlayerEntity;

public final class UnarmedCombatService {
    private static ModuleContext ctx;

    public static void init(ModuleContext context) {
        ctx = context;
    }

    public static float calculateUnarmedDamage(ServerPlayerEntity player) {
        CombatConfig cfg = CombatConfig.get();
        if (!cfg.unarmed.enabled) return 1.0f;

        int taijutsu = CoreServices.get(StatsApi.class)
                .map(api -> api.getStatLevel(player, "taijutsu"))
                .orElse(0);

        // Formula: baseDamage * (1 + taijutsuLevel * 0.05)
        float bonus = cfg.unarmed.baseDamage * (1.0f + taijutsu * cfg.unarmed.taijutsuDamagePerLevel);
        return bonus;
    }
}