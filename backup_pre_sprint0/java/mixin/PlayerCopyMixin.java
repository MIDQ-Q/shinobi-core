package com.example.shinobicore.mixin;

import com.example.shinobicore.stat.NinjaDataHolder;
import com.example.shinobicore.stat.NinjaPlayerData;
import net.minecraft.server.network.ServerPlayerEntity;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfo;

@Mixin(ServerPlayerEntity.class)
public abstract class PlayerCopyMixin {
    @Inject(method = "copyFrom", at = @At("TAIL"))
    private void shinobicore_copyNinjaData(ServerPlayerEntity oldPlayer, boolean alive, CallbackInfo ci) {
        NinjaPlayerData oldData = ((NinjaDataHolder) oldPlayer).shinobicore_getData();
        NinjaPlayerData newData = ((NinjaDataHolder) (Object) this).shinobicore_getData();
        newData.readNbt(oldData.writeNbt());
    }
}