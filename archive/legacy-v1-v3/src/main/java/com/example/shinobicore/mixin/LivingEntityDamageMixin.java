package com.example.shinobicore.mixin;

import com.example.shinobicore.stat.component.IStatsComponent;
import com.example.shinobicore.stat.component.NinjaComponents;
import com.example.shinobicore.stat.component.StatType;
import net.minecraft.entity.LivingEntity;
import net.minecraft.entity.damage.DamageSource;
import net.minecraft.entity.player.PlayerEntity;
import net.minecraft.item.ItemStack;
import net.minecraft.item.SwordItem;
import net.minecraft.item.RangedWeaponItem;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfoReturnable;

@Mixin(LivingEntity.class)
public class LivingEntityDamageMixin {

    @Inject(method = "damage", at = @At("HEAD"))
    private void shinobicore_onDamage(DamageSource source, float amount, CallbackInfoReturnable<Boolean> cir) {
        LivingEntity self = (LivingEntity)(Object)this;
        if (self.getWorld().isClient()) return;
        
        if (source.getAttacker() instanceof PlayerEntity attacker) {
            IStatsComponent stats = NinjaComponents.getStats(attacker);
            if (stats != null && amount > 0) {
                StatType attackStat = getAttackStat(attacker, source);
                // 0.5 XP per damage point, minimum 1
                int xpReward = Math.max(1, (int)(amount * 0.5f)); 
                stats.addXp(attackStat, xpReward);
            }
        }
    }

    private StatType getAttackStat(PlayerEntity attacker, DamageSource source) {
        ItemStack weapon = attacker.getMainHandStack();
        if (weapon.getItem() instanceof SwordItem) {
            return StatType.KENJUTSU;
        }
        if (weapon.getItem() instanceof RangedWeaponItem) {
            return StatType.SHURIKEN;
        }
        if (source.getName().equals("player")) {
            return StatType.TAIJUTSU;
        }
        return StatType.TAIJUTSU;
    }
}