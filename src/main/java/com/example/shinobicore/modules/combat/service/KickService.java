package com.example.shinobicore.modules.combat.service;

import com.example.shinobicore.core.event.CoreEvents;

import com.example.shinobicore.core.api.ModuleContext;
import com.example.shinobicore.core.log.ShinobiLogger;
import com.example.shinobicore.core.service.CoreServices;
import com.example.shinobicore.core.api.ChakraApi;
import com.example.shinobicore.core.api.StatsApi;
import com.example.shinobicore.modules.combat.CombatModule;
import com.example.shinobicore.modules.combat.config.CombatConfig;
import com.example.shinobicore.modules.combat.event.CombatEvents;
import net.minecraft.entity.LivingEntity;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.util.math.Box;
import net.minecraft.util.math.Vec3d;
import java.util.List;

public final class KickService {
    private static ModuleContext ctx;

    public static void init(ModuleContext context) {
        ctx = context;
    }

    public static void performKick(ServerPlayerEntity player) {
        CombatConfig.KickConfig cfg = CombatConfig.get().kick;
        if (!cfg.enabled) return;

        boolean hasStamina = CoreServices.get(ChakraApi.class)
                .map(api -> api.getCurrent(player) >= cfg.staminaCost)
                .orElse(true);
        
        if (!hasStamina) {
            ShinobiLogger.module(CombatModule.ID, "Player " + player.getName().getString() + " failed kick: not enough stamina");
            return;
        }

        CoreServices.get(ChakraApi.class).ifPresent(api -> api.trySpend(player, cfg.staminaCost));

        Vec3d pos = player.getPos();
        Vec3d look = player.getRotationVec(1.0f);
        Box searchBox = new Box(pos.add(-1.5, -1, -1.5), pos.add(1.5, 2, 1.5));
        searchBox = searchBox.offset(look.multiply(1.5));

        List<LivingEntity> targets = player.getWorld().getEntitiesByClass(LivingEntity.class, searchBox, e -> e != player && e.isAlive());
        
        int taijutsu = CoreServices.get(StatsApi.class)
                .map(api -> api.getStatLevel(player, "taijutsu"))
                .orElse(0);

        float damage = (float) (cfg.baseDamage * (1.0 + taijutsu * cfg.taijutsuPerLevel));

        for (LivingEntity target : targets) {
            target.damage(player.getDamageSources().playerAttack(player), damage);
            
            Vec3d knockback = look.multiply(cfg.knockbackStrength).add(0, 0.2, 0);
            target.addVelocity(knockback.x, knockback.y, knockback.z);
            target.velocityModified = true;

            CoreEvents.publish(new CombatEvents.KickEvent(player, target, damage));
        }

        ShinobiLogger.module(CombatModule.ID, "Player " + player.getName().getString() + " performed kick, hitting " + targets.size() + " targets");
    }
}