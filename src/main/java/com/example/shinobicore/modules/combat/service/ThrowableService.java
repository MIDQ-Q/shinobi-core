package com.example.shinobicore.modules.combat.service;

import com.example.shinobicore.core.event.CoreEvents;

import com.example.shinobicore.core.api.ModuleContext;
import com.example.shinobicore.core.log.ShinobiLogger;
import com.example.shinobicore.core.service.CoreServices;
import com.example.shinobicore.core.api.StatsApi;
import com.example.shinobicore.modules.combat.CombatModule;
import com.example.shinobicore.modules.combat.config.CombatConfig;
import com.example.shinobicore.modules.combat.event.CombatEvents;
import net.minecraft.entity.projectile.TridentEntity;
import net.minecraft.item.ItemStack;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.math.Vec3d;

public final class ThrowableService {
    private static ModuleContext ctx;

    public static void init(ModuleContext context) {
        ctx = context;
    }

    public static void throwWeapon(ServerPlayerEntity player, float yaw, float pitch) {
        ItemStack stack = player.getMainHandStack();
        if (stack.isEmpty()) return;

        String itemId = stack.getItem().getTranslationKey();
        if (!itemId.contains("shuriken") && !itemId.contains("kunai")) return;

        ServerWorld world = (ServerWorld) player.getWorld();
        
        TridentEntity projectile = new TridentEntity(world, player, stack);
        projectile.setPosition(player.getEyePos());
        
        Vec3d direction = player.getRotationVec(1.0f);
        
        int perception = CoreServices.get(StatsApi.class)
                .map(api -> api.getStatLevel(player, "perception"))
                .orElse(0);
        float spreadReduction = perception * CombatConfig.get().thrown.perceptionSpreadReductionPerLevel;
        float spread = Math.max(0.0f, 1.0f - spreadReduction);
        
        double speed = CombatConfig.get().thrown.speed;
        projectile.setVelocity(direction.x, direction.y, direction.z, (float)speed, spread);
        
        world.spawnEntity(projectile);
        
        if (!player.getAbilities().creativeMode) {
            stack.decrement(1);
        }

        CoreEvents.publish(new CombatEvents.ThrowableThrownEvent(player, projectile, itemId));
        ShinobiLogger.module(CombatModule.ID, "Player " + player.getName().getString() + " threw " + itemId);
    }
}