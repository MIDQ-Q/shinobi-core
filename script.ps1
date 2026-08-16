$utf8 = New-Object System.Text.UTF8Encoding($false)
$dir = "src\main\java\com\example\shinobicore\mixin"
if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }

$content = @"
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
        // writeNbt() не принимает аргументов, а возвращает NbtCompound
        nbt.put("ShinobiCoreData", this.shinobicore_data.writeNbt());
    }

    @Inject(method = "readCustomDataFromNbt", at = @At("HEAD"))
    private void shinobicore_readData(NbtCompound nbt, CallbackInfo ci) {
        if (nbt.contains("ShinobiCoreData")) {
            this.shinobicore_data.readNbt(nbt.getCompound("ShinobiCoreData"));
        }
    }
}
"@

$path = Join-Path $dir "ServerPlayerEntityMixin.java"
[System.IO.File]::WriteAllText($path, $content, $utf8)
Write-Host "[OK] Файл исправлен: writeNbt() теперь вызывается без аргументов!" -ForegroundColor Green