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
 * Makes the game treat water walking as standing on solid ground.
 * This removes water drag and allows jumping, fixing the "slippery" feel.
 */
@Mixin(Entity.class)
public abstract class WaterWalkOnGroundMixin {

    @Inject(method = "isOnGround", at = @At("HEAD"), cancellable = true)
    private void shinobicore_waterWalkIsOnGround(CallbackInfoReturnable<Boolean> cir) {
        if ((Object) this instanceof PlayerEntity player) {
            IParkourComponent parkour = NinjaComponents.getParkour(player);
            if (parkour != null && parkour.getCurrentPose() == NinjaPose.WATER_WALKING) {
                cir.setReturnValue(true);
            }
        }
    }
}