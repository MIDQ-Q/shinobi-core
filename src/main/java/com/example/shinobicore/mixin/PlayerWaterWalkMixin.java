// SHINOBICORE:SPRINT4:FILE
package com.example.shinobicore.mixin;

import com.example.shinobicore.movement.client.WaterWalkClient;
import net.minecraft.entity.Entity;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfoReturnable;

/**
 * SPRINT 4 water walk mixin.
 * Bypasses vanilla water physics when water walking is active.
 */
@Mixin(Entity.class)
public abstract class PlayerWaterWalkMixin {

    @Inject(method = "isTouchingWater", at = @At("HEAD"), cancellable = true)
    private void shinobicore_bypassWaterTouch(CallbackInfoReturnable<Boolean> cir) {
        if (WaterWalkClient.isActive()) {
            cir.setReturnValue(false);
        }
    }
}