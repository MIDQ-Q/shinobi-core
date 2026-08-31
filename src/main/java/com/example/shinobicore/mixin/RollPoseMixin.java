package com.example.shinobicore.mixin;

import com.example.shinobicore.client.parkour.ParkourManager;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.entity.EntityPose;
import net.minecraft.entity.player.PlayerEntity;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfo;

@Mixin(PlayerEntity.class)
public abstract class RollPoseMixin {

    // Дополнительная проверка: если ролл активен, принудительно держим SWIMMING
    @Inject(method = "updatePose", at = @At("RETURN"))
    private void shinobicore_forceRollPose(CallbackInfo ci) {
        PlayerEntity self = (PlayerEntity) (Object) this;
        if (self instanceof ClientPlayerEntity && ParkourManager.isRolling()) {
            if (self.getPose() != EntityPose.SWIMMING) {
                self.setPose(EntityPose.SWIMMING);
            }
        }
    }
}