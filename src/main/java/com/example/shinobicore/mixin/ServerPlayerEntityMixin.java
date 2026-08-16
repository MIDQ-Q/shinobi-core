package com.example.shinobicore.mixin;

import com.example.shinobicore.stat.NinjaDataHolder;
import com.example.shinobicore.stat.NinjaPlayerData;
import net.minecraft.nbt.NbtCompound;
import net.minecraft.server.network.ServerPlayerEntity;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.Unique;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfo;

@Mixin(ServerPlayerEntity.class)
public abstract class ServerPlayerEntityMixin implements NinjaDataHolder {
    @Unique
    private NinjaPlayerData shinobicore_data = new NinjaPlayerData();

    @Override
    public NinjaPlayerData shinobicore_getData() {
        return this.shinobicore_data;
    }

    @Inject(method = "writeCustomDataToNbt", at = @At("HEAD"))
    private void shinobicore_writeData(NbtCompound nbt, CallbackInfo ci) {
        // writeNbt() РЅРµ РїСЂРёРЅРёРјР°РµС‚ Р°СЂРіСѓРјРµРЅС‚РѕРІ, Р° РІРѕР·РІСЂР°С‰Р°РµС‚ NbtCompound
        nbt.put("ShinobiCoreData", this.shinobicore_data.writeNbt());
    }

    @Inject(method = "readCustomDataFromNbt", at = @At("HEAD"))
    private void shinobicore_readData(NbtCompound nbt, CallbackInfo ci) {
        if (nbt.contains("ShinobiCoreData")) {
            this.shinobicore_data.readNbt(nbt.getCompound("ShinobiCoreData"));
        }
    }
}