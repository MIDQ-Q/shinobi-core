package com.example.shinobicore.mixin;

import com.example.shinobicore.stat.NinjaDataHolder;
import com.example.shinobicore.stat.NinjaPlayerData;
import net.minecraft.entity.LivingEntity;
import net.minecraft.fluid.FluidState;
import net.minecraft.registry.tag.FluidTags;
import net.minecraft.server.network.ServerPlayerEntity;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfoReturnable;

@Mixin(LivingEntity.class)
public abstract class ChakraWaterWalkMixin {

    @Inject(method = "canWalkOnFluid(Lnet/minecraft/fluid/FluidState;)Z", at = @At("HEAD"), cancellable = true)
    private void shinobicore_canWalkOnWater(FluidState fluidState, CallbackInfoReturnable<Boolean> cir) {
        LivingEntity self = (LivingEntity) (Object) this;
        if (self instanceof ServerPlayerEntity player) {
            NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
            if (data != null && data.isChakraMode() && data.getCurrentChakra() > 0) {
                if (fluidState.isIn(FluidTags.WATER)) {
                    cir.setReturnValue(true);
                }
            }
        }
    }
}