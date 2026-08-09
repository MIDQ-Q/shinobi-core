package com.example.shinobicore.mixin;

import com.example.shinobicore.client.parkour.ParkourManager;
import net.minecraft.entity.Entity;
import net.minecraft.entity.EntityDimensions;
import net.minecraft.entity.EntityPose;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfoReturnable;

@Mixin(Entity.class)
public abstract class SlideDimensionsMixin {

    @Inject(method = "getDimensions", at = @At("HEAD"), cancellable = true)
    private void shinobicore_slideDimensions(EntityPose pose, CallbackInfoReturnable<EntityDimensions> cir) {
        Entity self = (Entity) (Object) this;
        
        // Если это игрок и он сейчас скользит — уменьшаем хитбокс до 1.0 блока
        if (self instanceof net.minecraft.client.network.ClientPlayerEntity) {
            if (ParkourManager.isSliding()) {
                // Возвращаем размеры: ширина 0.6, высота 1.0 (вместо 1.8)
                cir.setReturnValue(EntityDimensions.fixed(0.6f, 1.0f));
            }
        }
    }
}