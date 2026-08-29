package com.example.shinobicore.mixin;

import com.example.shinobicore.client.ChakraPhysicsClient;
import com.example.shinobicore.client.ClientNinjaState;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.entity.LivingEntity;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfo;

@Mixin(LivingEntity.class)
public abstract class ChargedJumpMixin {

    @Inject(method = "jump", at = @At("HEAD"), cancellable = true)
    private void shinobicore_cancelVanillaJump(CallbackInfo ci) {
        LivingEntity self = (LivingEntity) (Object) this;
        if (!(self instanceof ClientPlayerEntity player)) return;
        
        if (ClientNinjaState.chakraMode && (player.isOnGround() || ChakraPhysicsClient.standingOnWater)) {
            ci.cancel();
        }
    }
}