package com.example.shinobicore.mixin;

import com.example.shinobicore.stat.component.IParkourComponent;
import com.example.shinobicore.stat.component.NinjaComponents;
import com.example.shinobicore.stat.component.NinjaPose;
import net.minecraft.entity.Entity;
import net.minecraft.entity.player.PlayerEntity;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfoReturnable;

/**
 * HLD v2 Sprint 2: Water Walking.
 * Bypasses vanilla water physics (friction, swimming sounds, drowning)
 * when the player is in Chakra Mode and actively water walking.
 */
@Mixin(Entity.class)
public abstract class EntityWaterWalkMixin {

    @Inject(method = "isTouchingWater", at = @At("HEAD"), cancellable = true)
    private void shinobicore_bypassWaterTouch(CallbackInfoReturnable<Boolean> cir) {
        if ((Object) this instanceof PlayerEntity player) {
            IParkourComponent parkour = NinjaComponents.getParkour(player);
            if (parkour != null && parkour.getCurrentPose() == NinjaPose.WATER_WALKING) {
                // Tell the game we are NOT touching water.
                // This disables the 0.8x friction multiplier and swimming logic.
                cir.setReturnValue(false);
            }
        }
    }
}