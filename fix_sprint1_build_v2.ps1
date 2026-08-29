$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$root = "E:\Games\mod"
$mirrorPath = Join-Path $root "src\main\java\com\example\shinobicore\chakra\server\ServerChakraMirror.java"

Write-Host ""
Write-Host "==============================================================" -ForegroundColor Cyan
Write-Host " FIX SPRINT 1 v2: Add missing methods to ServerChakraMirror" -ForegroundColor Cyan
Write-Host "==============================================================" -ForegroundColor Cyan
Write-Host ""

if (Test-Path $mirrorPath) {
    $content = [System.IO.File]::ReadAllText($mirrorPath, $utf8)
    
    # 1. Add import if missing
    if (-not $content.Contains("import net.minecraft.server.network.ServerPlayerEntity;")) {
        $content = $content -replace "(import java\.util\.concurrent\.ConcurrentHashMap;)", "`$1`nimport net.minecraft.server.network.ServerPlayerEntity;"
        Write-Host " [OK] Added ServerPlayerEntity import" -ForegroundColor Green
    }
    
    # 2. Add stub methods if missing
    if (-not $content.Contains("public static void register()")) {
        $stubMethods = @"

    /**
     * SPRINT 1 safe stub for legacy callers (ShinobiCore, ModPackets).
     */
    public static void register() {
        // No-op in Sprint 1. Packet registration handled elsewhere.
    }

    public static void updateFromClient(ServerPlayerEntity player, float current, float max, float fatigue, boolean mode, boolean exhausted) {
        updateFromClient(player.getUuid(), current, max, fatigue, mode, exhausted);
    }

    public static void updateFromClient(UUID uuid, float current, float max, float fatigue, boolean mode, boolean exhausted) {
        Data data = get(uuid);
        data.current = clamp(current, 0.0f, max);
        data.max = max;
        data.fatigue = fatigue;
        data.chakraMode = mode;
    }
"@
        # Insert before the last closing brace
        $content = $content -replace "(\s*)\}\s*$", "`$1$stubMethods`n}"
        Write-Host " [OK] Added register() and updateFromClient() methods" -ForegroundColor Green
    } else {
        Write-Host " [SKIP] Methods already present" -ForegroundColor Yellow
    }
    
    [System.IO.File]::WriteAllText($mirrorPath, $content, $utf8)
} else {
    Write-Host " [FAIL] ServerChakraMirror.java not found!" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Rebuilding project..." -ForegroundColor Yellow

Push-Location $root
try {
    $prevEAP = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $out = & ".\gradlew.bat" build 2>&1
    $exitCode = $LASTEXITCODE
    $ErrorActionPreference = $prevEAP

    if ($exitCode -eq 0) {
        Write-Host " [PASS] BUILD SUCCESSFUL!" -ForegroundColor Green
        Write-Host ""
        Write-Host "Sprint 1 is now fully complete." -ForegroundColor Cyan
        Write-Host "You can run: .\gradlew.bat runClient" -ForegroundColor Yellow
    } else {
        Write-Host " [FAIL] Build failed:" -ForegroundColor Red
        $out | Where-Object { $_ -match "error:" } | Select-Object -First 25 | ForEach-Object { Write-Host " $_" -ForegroundColor Red }
    }
} finally {
    Pop-Location
}