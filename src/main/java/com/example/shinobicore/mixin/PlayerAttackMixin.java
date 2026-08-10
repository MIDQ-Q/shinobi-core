package com.example.shinobicore.mixin;

import com.example.shinobicore.client.combat.TaijutsuClientHandler;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.entity.Entity;
import net.minecraft.entity.player.PlayerEntity;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfo;

@Mixin(PlayerEntity.class)
public abstract class PlayerAttackMixin {

    @Inject(method = "attack", at = @At("HEAD"), cancellable = true)
    private void shinobicore_taijutsuAttack(Entity target, CallbackInfo ci) {
        PlayerEntity self = (PlayerEntity) (Object) this;
        if (!(self instanceof ClientPlayerEntity player)) return;
        
        if (player.getMainHandStack().isEmpty()) {
            if (TaijutsuClientHandler.tryAttack(player)) {
                ci.cancel();
            }
        }
    }
}