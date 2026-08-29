package com.example.shinobicore.mixin;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.stat.NinjaDataHolder;
import com.example.shinobicore.stat.NinjaPlayerData;
import net.minecraft.entity.LivingEntity;
import net.minecraft.entity.damage.DamageSource;
import net.minecraft.server.network.ServerPlayerEntity;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.ModifyArg;

@Mixin(LivingEntity.class)
public abstract class LivingEntityBlockMixin {
    @ModifyArg(method = "damage", at = @At(value = "INVOKE", target = "Lnet/minecraft/entity/LivingEntity;applyDamage(Lnet/minecraft/entity/damage/DamageSource;F)V"), index = 1)
    private float shinobicore_modifyBlockDamage(DamageSource source, float amount) {
        LivingEntity self = (LivingEntity)(Object)this;
        if (self instanceof ServerPlayerEntity player) {
            NinjaPlayerData data = ((NinjaDataHolder)player).shinobicore_getData();
            if (data.isBlocking() && amount > 0 && !source.isSourceCreativePlayer()) {
                float blockEfficiency = 0.6f; // 60% damage reduction
                float staminaCost = amount * 5.0f; // 5 stamina per 1 HP blocked
                if (data.getCurrentStamina() >= staminaCost) {
                    data.setCurrentStamina(data.getCurrentStamina() - staminaCost);
                    ShinobiCore.sendChakraSync(player);
                    return amount * (1.0f - blockEfficiency);
                } else {
                    // Guard break: stamina depleted
                    data.setBlocking(false);
                    ShinobiCore.sendChakraSync(player);
                }
            }
        }
        return amount;
    }
}