package com.example.shinobicore.mixin;

import com.example.shinobicore.client.parkour.ParkourManager;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.entity.LivingEntity;
import net.minecraft.entity.MovementType;
import net.minecraft.util.math.Vec3d;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfo;

@Mixin(LivingEntity.class)
public abstract class SlideTravelMixin {

    @Inject(method = "travel", at = @At("HEAD"), cancellable = true)
    private void shinobicore_slideTravel(Vec3d movementInput, CallbackInfo ci) {
        if ((Object) this instanceof ClientPlayerEntity player && ParkourManager.isSliding()) {
            Vec3d v = player.getVelocity();
            double friction = player.isOnGround() ? 0.985 : 0.99;
            player.setVelocity(v.x * friction, v.y - 0.08, v.z * friction); // инерция + гравитация
            player.move(MovementType.SELF, player.getVelocity());
            ci.cancel();
        }
    }
}