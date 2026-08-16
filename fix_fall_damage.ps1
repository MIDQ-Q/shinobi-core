$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$root = "E:\Games\mod"
$file = "$root\src\main\java\com\example\shinobicore\mixin\FallDamageMixin.java"

$content = @'
package com.example.shinobicore.mixin;

import com.example.shinobicore.stat.NinjaDataHolder;
import com.example.shinobicore.stat.NinjaPlayerData;
import net.minecraft.entity.LivingEntity;
import net.minecraft.entity.damage.DamageSource;
import net.minecraft.server.network.ServerPlayerEntity;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfoReturnable;

@Mixin(LivingEntity.class)
public class FallDamageMixin {
    
    @Inject(method = "handleFallDamage", at = @At("HEAD"), cancellable = true)
    private void shinobicore$reduceFallDamage(float fallDistance, float damageMultiplier, DamageSource damageSource, CallbackInfoReturnable<Boolean> cir) {
        LivingEntity entity = (LivingEntity) (Object) this;
        
        // CRITICAL FIX: 
        // 1. ClientPlayerEntity does NOT implement NinjaDataHolder.
        // 2. Mobs (zombies, cows) do NOT implement NinjaDataHolder.
        // We MUST strictly check for ServerPlayerEntity before casting.
        if (!(entity instanceof ServerPlayerEntity)) {
            return;
        }
        
        NinjaPlayerData data = ((NinjaDataHolder) entity).shinobicore_getData();
        
        // Safe logic: Cancel fall damage if in Chakra Mode and not exhausted
        if (data.isChakraMode() && data.getCurrentChakra() > 0 && !data.isExhausted()) {
            // Consume a bit of chakra for the safe landing
            data.setCurrentChakra(data.getCurrentChakra() - (fallDistance * 1.0f));
            cir.setReturnValue(false); // Cancel vanilla fall damage
        }
    }
}
'@

[System.IO.File]::WriteAllText($file, $content, $utf8)
Write-Host "[OK] FallDamageMixin.java fixed with instanceof check!" -ForegroundColor Green
Write-Host "Run: .\gradlew.bat build" -ForegroundColor Cyan