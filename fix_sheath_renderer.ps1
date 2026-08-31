$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$filePath = "E:\Games\mod\src\main\java\com\example\shinobicore\ShinobiCoreClient.java"

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  FINAL FIX: Completely rewrite ShinobiCoreClient.java" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

# Minimal content - ONLY what's absolutely needed
$minimalContent = @'
package com.example.shinobicore;

import com.example.shinobicore.core.module.ModuleManager;
import net.fabricmc.api.ClientModInitializer;
import net.fabricmc.fabric.api.client.event.lifecycle.v1.ClientTickEvents;

public class ShinobiCoreClient implements ClientModInitializer {

    @Override
    public void onInitializeClient() {
        ModuleManager.initClient();
        ClientTickEvents.END_CLIENT_TICK.register(client -> ModuleManager.clientTick());
    }
}
'@

[System.IO.File]::WriteAllText($filePath, $minimalContent, $utf8)

Write-Host "  [FIX] Completely rewrote ShinobiCoreClient.java" -ForegroundColor Green
Write-Host "  Removed ALL client-side command registrations" -ForegroundColor Green
Write-Host "  Commands now go directly to server" -ForegroundColor Green
Write-Host ""

# Build
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  BUILD" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

Push-Location "E:\Games\mod"
try {
    $prevEAP = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $out = & ".\gradlew.bat" build 2>&1
    $exitCode = $LASTEXITCODE
    $ErrorActionPreference = $prevEAP

    Write-Host ""
    if ($exitCode -eq 0) {
        Write-Host "================================================================" -ForegroundColor Green
        Write-Host "  [PASS] BUILD SUCCESSFUL!" -ForegroundColor Green
        Write-Host "================================================================" -ForegroundColor Green
        Write-Host ""
        Write-Host "  Run: .\gradlew.bat runClient" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  Commands that should now work:" -ForegroundColor White
        Write-Host "    /shinobicore chakra toggle" -ForegroundColor Cyan
        Write-Host "    /shinobicore chakra info" -ForegroundColor Cyan
        Write-Host "    /shinobicore systems" -ForegroundColor Cyan
        Write-Host "    /shinobicore version" -ForegroundColor Cyan
        Write-Host "    /shinobicore movement debug" -ForegroundColor Cyan
        Write-Host "    /jutsu_editor" -ForegroundColor Cyan
    } else {
        Write-Host "================================================================" -ForegroundColor Red
        Write-Host "  [FAIL] BUILD FAILED" -ForegroundColor Red
        Write-Host "================================================================" -ForegroundColor Red
        Write-Host ""
        Write-Host "  Last 20 lines:" -ForegroundColor Yellow
        $out | Select-Object -Last 20 | ForEach-Object {
            Write-Host "  $_" -ForegroundColor Red
        }
    }
} finally {
    Pop-Location
}