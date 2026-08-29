$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$root = "E:\Games\mod"
$srcJava = Join-Path $root "src\main\java"
$resMain = Join-Path $root "src\main\resources"

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " ACTIVATING MOVEMENT: Creating Separate Client Entrypoint" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

# 1. Create MovementBootstrap.java
$bootstrapDir = Join-Path $srcJava "com\example\shinobicore\movement\client"
if (-not (Test-Path $bootstrapDir)) { New-Item -ItemType Directory -Path $bootstrapDir -Force | Out-Null }

$bootstrapPath = Join-Path $bootstrapDir "MovementBootstrap.java"
$bootstrapContent = @'
package com.example.shinobicore.movement.client;

import net.fabricmc.api.ClientModInitializer;
import net.fabricmc.fabric.api.client.event.lifecycle.v1.ClientTickEvents;
import net.fabricmc.fabric.api.client.keybinding.v1.KeyBindingHelper;
import net.minecraft.client.option.KeyBinding;
import net.minecraft.client.util.InputUtil;
import org.lwjgl.glfw.GLFW;
import com.example.shinobicore.client.ClientNinjaState;
import com.example.shinobicore.util.ShinobiLogger;

public class MovementBootstrap implements ClientModInitializer {
    private static KeyBinding chakraKey;
    private static KeyBinding meditateKey;

    @Override
    public void onInitializeClient() {
        ShinobiLogger.info("[Movement] MovementBootstrap initializing...");
        
        chakraKey = KeyBindingHelper.registerKeyBinding(new KeyBinding(
            "key.shinobicore.chakra_v3", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_LEFT_SHIFT, "category.shinobicore"));
            
        meditateKey = KeyBindingHelper.registerKeyBinding(new KeyBinding(
            "key.shinobicore.meditate_v3", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_M, "category.shinobicore"));

        ClientTickEvents.END_CLIENT_TICK.register(client -> {
            if (client.player == null || client.world == null) return;
            
            // Tick all movement modules
            ClientMovementService.tick(client);
            
            // Handle Chakra Mode Toggle
            while (chakraKey.wasPressed()) {
                ClientNinjaState.chakraMode = !ClientNinjaState.chakraMode;
                ShinobiLogger.info("[Movement] Chakra Mode: " + ClientNinjaState.chakraMode);
            }
            
            // Handle Meditation Toggle
            while (meditateKey.wasPressed()) {
                MeditationClient.toggle(client.player);
                ShinobiLogger.info("[Movement] Meditation toggled");
            }
        });
        
        ShinobiLogger.info("[Movement] MovementBootstrap initialized successfully!");
    }
}
'@
[System.IO.File]::WriteAllText($bootstrapPath, $bootstrapContent, $utf8)
Write-Host " [OK] Created MovementBootstrap.java" -ForegroundColor Green

# 2. Inject into fabric.mod.json
$fmjPath = Join-Path $resMain "fabric.mod.json"
if (Test-Path $fmjPath) {
    $jsonContent = Get-Content $fmjPath -Raw | ConvertFrom-Json
    
    if (-not $jsonContent.entrypoints.client) {
        $jsonContent.entrypoints | Add-Member -NotePropertyName "client" -NotePropertyValue @()
    }
    
    $newEntry = "com.example.shinobicore.movement.client.MovementBootstrap"
    if ($jsonContent.entrypoints.client -notcontains $newEntry) {
        $jsonContent.entrypoints.client += $newEntry
        $jsonContent | ConvertTo-Json -Depth 10 | Set-Content $fmjPath -Encoding UTF8
        Write-Host " [OK] Added MovementBootstrap to fabric.mod.json client entrypoints" -ForegroundColor Green
    } else {
        Write-Host " [SKIP] MovementBootstrap already in fabric.mod.json" -ForegroundColor Yellow
    }
} else {
    Write-Host " [ERROR] fabric.mod.json not found!" -ForegroundColor Red
}

# 3. Ensure ClientNinjaState has chakraMode field
$cnStatePath = Join-Path $srcJava "com\example\shinobicore\client\ClientNinjaState.java"
if (Test-Path $cnStatePath) {
    $c = [System.IO.File]::ReadAllText($cnStatePath, $utf8)
    if (-not $c.Contains("public static boolean chakraMode")) {
        $c = $c -replace '(public class ClientNinjaState \{)', "`$1`n    public static boolean chakraMode = false;`n    public static float currentChakra = 100.0f;`n"
        [System.IO.File]::WriteAllText($cnStatePath, $c, $utf8)
        Write-Host " [OK] Added chakraMode to ClientNinjaState" -ForegroundColor Green
    }
}

# 4. Build
Write-Host "`nBuilding..." -ForegroundColor Yellow
Push-Location $root
try {
    $prevEAP = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $out = & ".\gradlew.bat" build 2>&1
    $exitCode = $LASTEXITCODE
    $ErrorActionPreference = $prevEAP
    
    if ($exitCode -eq 0) {
        Write-Host " [PASS] Build successful!" -ForegroundColor Green
        Write-Host "`n Run: .\gradlew.bat runClient" -ForegroundColor Yellow
        Write-Host "`n In the console log, you should now see:" -ForegroundColor Cyan
        Write-Host "   [Movement] MovementBootstrap initialized successfully!" -ForegroundColor White
        Write-Host "   [Movement] Chakra Mode: true (when you press LEFT SHIFT)" -ForegroundColor White
    } else {
        Write-Host " [FAIL] Build failed:" -ForegroundColor Red
        $out | Where-Object { $_ -match "error:" } | Select-Object -First 10 | ForEach-Object { Write-Host "   $_" -ForegroundColor Red }
    }
} finally {
    Pop-Location
}