package com.example.shinobicore.mixin;

import com.example.shinobicore.stat.NinjaDataHolder;
import com.example.shinobicore.stat.NinjaPlayerData;
import net.minecraft.entity.LivingEntity;
import net.minecraft.entity.damage.DamageSource;
import net.minecraft.entity.player.PlayerEntity;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfoReturnable;

@Mixin(LivingEntity.class)
public abstract class FallDamageMixin {

    @Inject(method = "handleFallDamage", at = @At("HEAD"), cancellable = true)
    private void shinobicore_reduceFallDamage(float fallDistance, float damageMultiplier, DamageSource damageSource, CallbackInfoReturnable<Boolean> cir) {
        LivingEntity self = (LivingEntity) (Object) this;
        if (self instanceof PlayerEntity player) {
            NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
            if (data != null && data.isChakraMode() && data.getCurrentChakra() > 0) {
                // До 40 блоков — 0 урона
                if (fallDistance <= 40.0f) {
                    cir.setReturnValue(false); // Нет урона
                    return;
                }
                
                // Дальше каждые 5 блоков = 1 урон (0.5 сердца)
                float extraBlocks = fallDistance - 40.0f;
                float damage = (extraBlocks / 5.0f);
                
                // Применяем уменьшенный урон
                if (damage >= 1.0f) {
                    player.damage(player.getDamageSources().fall(), damage);
                }
                cir.setReturnValue(true); // Урон обработан
            }
        }
    }
}