package com.example.shinobicore.modules.jutsu.gateway;

import com.example.shinobicore.core.log.ShinobiLogger;
import com.example.shinobicore.modules.jutsu.cast.JutsuCastService;
import com.example.shinobicore.modules.jutsu.data.JutsuDefinition;
import com.example.shinobicore.modules.jutsu.data.JutsuRegistry;
import net.minecraft.entity.Entity;
import net.minecraft.entity.LivingEntity;
import net.minecraft.server.network.ServerPlayerEntity;

import java.util.List;

public final class JutsuCastGatewayImpl {
    
    public boolean tryCast(LivingEntity caster, String jutsuId, Entity target) {
        JutsuDefinition def = JutsuRegistry.get(jutsuId).orElse(null);
        if (def == null) {
            ShinobiLogger.module("jutsu", "Gateway: unknown jutsu " + jutsuId);
            return false;
        }
        
        // For non-player casters (enemies), we bypass loadout/slot logic
        // and go straight to the cast service. 
        // Note: Full AI support requires extending JutsuCastService to accept LivingEntity instead of just ServerPlayerEntity.
        if (caster instanceof ServerPlayerEntity player) {
            JutsuCastService.instance().requestCast(player, jutsuId, 0, System.currentTimeMillis(), caster.getYaw(), caster.getPitch());
            return true;
        }
        
        ShinobiLogger.module("jutsu", "Gateway: AI casting for non-player entities is a Sprint 2 feature.");
        return false;
    }

    public boolean isJutsuAvailable(String jutsuId) {
        return JutsuRegistry.get(jutsuId).isPresent();
    }

    public List<String> getJutsuByRank(String rank) {
        return JutsuRegistry.all().stream()
                .map(JutsuDefinition::id)
                .toList();
    }
}