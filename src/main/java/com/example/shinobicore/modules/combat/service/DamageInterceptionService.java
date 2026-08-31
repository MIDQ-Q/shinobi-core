package com.example.shinobicore.modules.combat.service;

import com.example.shinobicore.core.api.ModuleContext;
import com.example.shinobicore.core.log.ShinobiLogger;
import com.example.shinobicore.core.service.CoreServices;
import com.example.shinobicore.core.api.StatsApi;
import com.example.shinobicore.modules.combat.CombatModule;
import com.example.shinobicore.modules.combat.component.CombatComponent;
import com.example.shinobicore.modules.combat.component.CombatComponentKey;
import net.fabricmc.fabric.api.event.player.AttackEntityCallback;
import net.minecraft.entity.LivingEntity;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.ActionResult;

public final class DamageInterceptionService {
    private static ModuleContext ctx;

    public static void init(ModuleContext context) {
        ctx = context;
        registerAttackCallback();
    }

    private static void registerAttackCallback() {
        AttackEntityCallback.EVENT.register((player, world, hand, target, hitResult) -> {
            if (!(player instanceof ServerPlayerEntity sp)) return ActionResult.PASS;
            if (!(target instanceof LivingEntity le)) return ActionResult.PASS;

            CombatComponent comp = CombatComponentKey.KEY.getNullable(sp);
            if (comp == null) return ActionResult.PASS;

            float bonus = calculateShinobiBonus(sp, comp);

            if (bonus > 0.01f) {
                ((ServerWorld) world).getServer().execute(() -> {
                    if (le.isAlive()) {
                        // Apply bonus as magic damage to avoid double-dipping armor reduction
                        le.damage(sp.getDamageSources().magic(), bonus);
                    }
                });
            }

            // Update combo tracker
            // ComboTracker.onAttack(sp, BetterCombatAdapter.resolveWeaponClass(sp.getMainHandStack()));

            return ActionResult.PASS; // NEVER cancel vanilla damage
        });
    }

    private static float calculateShinobiBonus(ServerPlayerEntity player, CombatComponent comp) {
        float baseDamage = 1.0f; // Placeholder
        int taijutsu = CoreServices.get(StatsApi.class)
                .map(api -> api.getStatLevel(player, "taijutsu"))
                .orElse(0);
        
        // Formula: baseDamage * (1 + taijutsuLevel * 0.05)
        return baseDamage * (1.0f + taijutsu * 0.05f);
    }
}