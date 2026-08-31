package com.example.shinobicore.mixin;

import com.example.shinobicore.client.ChakraHudRenderer;
import com.example.shinobicore.client.ClientNinjaState;
import com.example.shinobicore.stat.NinjaDataHolder;
import com.example.shinobicore.stat.NinjaPlayerData;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.entity.Entity;
import net.minecraft.server.network.ServerPlayerEntity;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfoReturnable;

@Mixin(Entity.class)
public abstract class ChakraWaterTouchMixin {

    @Inject(method = "isTouchingWater", at = @At("HEAD"), cancellable = true)
    private void shinobicore_noWaterPhysics(CallbackInfoReturnable<Boolean> cir) {
        Entity self = (Entity) (Object) this;

        if (self instanceof ServerPlayerEntity player) {
            NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
            if (data != null && data.isChakraMode() && data.getCurrentChakra() > 0) {
                cir.setReturnValue(false);
            }
        } else if (self instanceof ClientPlayerEntity) {
            if (ClientNinjaState.chakraMode && ChakraHudRenderer.currentChakra > 0) {
                cir.setReturnValue(false);
            }
        }
    }
}