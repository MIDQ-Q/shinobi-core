package com.example.shinobicore.mixin;

import com.example.shinobicore.client.parkour.ParkourManager;
import com.example.shinobicore.pose.LowPoseTracker;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.entity.Entity;
import net.minecraft.entity.EntityDimensions;
import net.minecraft.entity.EntityPose;
import net.minecraft.server.network.ServerPlayerEntity;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfoReturnable;

@Mixin(Entity.class)
public abstract class SlideDimensionsMixin {

    @Inject(method = "getDimensions", at = @At("HEAD"), cancellable = true)
    private void shinobicore_slideDimensions(EntityPose pose, CallbackInfoReturnable<EntityDimensions> cir) {
        Entity self = (Entity) (Object) this;

        // === КЛИЕНТ: локальный игрок ===
        if (self instanceof ClientPlayerEntity) {
            if (ParkourManager.isSliding()) {
                cir.setReturnValue(EntityDimensions.fixed(0.6f, 1.0f));
            }
            return;
        }

        // === СЕРВЕР: все игроки через LowPoseTracker ===
        if (self instanceof ServerPlayerEntity sp) {
            if (LowPoseTracker.isLow(sp.getUuid())) {
                cir.setReturnValue(EntityDimensions.fixed(0.6f, 1.0f));
            }
        }
    }
}