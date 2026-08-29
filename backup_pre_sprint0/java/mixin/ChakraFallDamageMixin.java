package com.example.shinobicore.mixin;

import com.example.shinobicore.stat.component.IChakraComponent;
import com.example.shinobicore.stat.component.NinjaComponents;
import net.minecraft.entity.damage.DamageSource;
import net.minecraft.entity.player.PlayerEntity;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfoReturnable;

/**
 * Chakra Mode: Ignore fall damage up to 45 blocks.
 * FIXED: fallDistance is float, not int (Yarn 1.20.1 mapping).
 */
@Mixin(PlayerEntity.class)
public abstract class ChakraFallDamageMixin {

    @Inject(method = "handleFallDamage", at = @At("HEAD"), cancellable = true)
    private void chakraFallDamageProtection(float fallDistance, float damageMultiplier, DamageSource damageSource, CallbackInfoReturnable<Boolean> cir) {
        PlayerEntity player = (PlayerEntity) (Object) this;
        
        IChakraComponent chakra = NinjaComponents.getChakra(player);
        if (chakra != null && chakra.isChakraMode() && chakra.getCurrentChakra() > 0) {
            // Ignore fall damage if distance is less than 45 blocks
            if (fallDistance <= 45.0f) {
                cir.setReturnValue(false); // No damage
            }
        }
    }
}