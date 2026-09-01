package com.example.shinobicore.mixin;

import com.example.shinobicore.stat.NinjaDataHolder;
import com.example.shinobicore.stat.NinjaPlayerData;
import net.minecraft.entity.player.PlayerEntity;
import net.minecraft.nbt.NbtCompound;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.Unique;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfo;

@Mixin(PlayerEntity.class)
public abstract class ServerPlayerEntityMixin implements NinjaDataHolder {

    @Unique
    private final NinjaPlayerData shinobicore_data = new NinjaPlayerData();

    @Override
    public NinjaPlayerData shinobicore_getData() {
        return shinobicore_data;
    }

    @Inject(method = "writeCustomDataToNbt", at = @At("TAIL"))
    private void shinobicore_writeData(NbtCompound nbt, CallbackInfo ci) {
        nbt.put("ShinobiCoreData", shinobicore_data.writeNbt());
    }

    @Inject(method = "readCustomDataFromNbt", at = @At("TAIL"))
    private void shinobicore_readData(NbtCompound nbt, CallbackInfo ci) {
        if (nbt.contains("ShinobiCoreData")) {
            shinobicore_data.readNbt(nbt.getCompound("ShinobiCoreData"));
        }
    }
}