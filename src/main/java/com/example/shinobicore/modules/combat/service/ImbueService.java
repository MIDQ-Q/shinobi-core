package com.example.shinobicore.modules.combat.service;

import com.example.shinobicore.core.api.ModuleContext;
import com.example.shinobicore.core.log.ShinobiLogger;
import com.example.shinobicore.core.service.CoreServices;
import com.example.shinobicore.core.api.JutsuCastGatewayApi;
import com.example.shinobicore.modules.combat.CombatModule;
import com.example.shinobicore.modules.combat.config.CombatConfig;
import net.minecraft.entity.Entity;
import net.minecraft.entity.projectile.PersistentProjectileEntity;
import net.minecraft.server.network.ServerPlayerEntity;

public final class ImbueService {
    private static ModuleContext ctx;

    public static void init(ModuleContext context) {
        ctx = context;
    }

    public static void onProjectileImpact(ServerPlayerEntity thrower, Entity projectile, Entity target) {
        CombatConfig cfg = CombatConfig.get();
        if (!cfg.imbue.enabled || !cfg.imbue.allowedOnThrowables) return;

        // TODO: Read NBT from projectile to check for imbued jutsu ID
        String imbuedJutsuId = "shinobicore:fireball"; // Stub

        CoreServices.get(JutsuCastGatewayApi.class).ifPresent(gateway -> {
            if (gateway.isJutsuAvailable(imbuedJutsuId)) {
                ShinobiLogger.module(CombatModule.ID, "Executing imbued jutsu: " + imbuedJutsuId + " on impact");
                // gateway.tryCast(thrower, imbuedJutsuId, target);
            }
        });
    }
}