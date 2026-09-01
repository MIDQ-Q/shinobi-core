package com.example.shinobicore.mixin;
import com.example.shinobicore.combat.CastingServerState;
import net.minecraft.entity.LivingEntity;
import net.minecraft.entity.damage.DamageSource;
import net.minecraft.server.network.ServerPlayerEntity;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfoReturnable;
@Mixin(LivingEntity.class)
public abstract class InterruptCastMixin {
    @Inject(method = "damage", at = @At("HEAD"))
    private void shinobicore_checkInterrupt(DamageSource source, float amount, CallbackInfoReturnable<Boolean> cir) {
        LivingEntity self = (LivingEntity) (Object) this;
        if (self instanceof ServerPlayerEntity player && amount > 0) {
            if (CastingServerState.isCasting(player)) {
                CastingServerState.interruptCast(player);
            }
        }
    }
}