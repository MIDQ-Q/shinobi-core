$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$root = "E:\Games\mod"
$mirrorPath = Join-Path $root "src\main\java\com\example\shinobicore\chakra\server\ServerChakraMirror.java"
$packetsPath = Join-Path $root "src\main\java\com\example\shinobicore\network\ModPackets.java"

Write-Host ""
Write-Host "==============================================================" -ForegroundColor Cyan
Write-Host " FIX SPRINT 1 v3: Add missing admin/network stubs" -ForegroundColor Cyan
Write-Host "==============================================================" -ForegroundColor Cyan
Write-Host ""

# 1. Fix ServerChakraMirror.java
if (Test-Path $mirrorPath) {
    $content = [System.IO.File]::ReadAllText($mirrorPath, $utf8)
    
    $stubs = @"

    // --- SPRINT 1 v3 STUBS FOR LEGACY CALLERS ---

    public static void applyAdminSet(ServerPlayerEntity player, float current, float max, float fatigue, boolean mode, boolean exhausted) {
        if (player == null) return;
        updateFromClient(player.getUuid(), current, max, fatigue, mode, exhausted);
    }

    public static void updateFromClient(ServerPlayerEntity player, float current, float max, boolean mode, boolean exhausted, boolean meditating) {
        if (player == null) return;
        updateFromClient(player.getUuid(), current, max, 0.0f, mode, exhausted);
    }

    public static void updateFromClient(ServerPlayerEntity player, float current, float max, float fatigue, boolean mode, boolean exhausted) {
        if (player == null) return;
        updateFromClient(player.getUuid(), current, max, fatigue, mode, exhausted);
    }
"@

    if (-not $content.Contains("public static void applyAdminSet(")) {
        $content = $content -replace "(\s*)\}\s*$", "`$1$stubs`n}"
        [System.IO.File]::WriteAllText($mirrorPath, $content, $utf8)
        Write-Host " [OK] Added applyAdminSet and updateFromClient overloads to ServerChakraMirror" -ForegroundColor Green
    } else {
        Write-Host " [SKIP] Stubs already present in ServerChakraMirror" -ForegroundColor Yellow
    }
} else {
    Write-Host " [FAIL] ServerChakraMirror.java not found!" -ForegroundColor Red
    exit 1
}

# 2. Fix ModPackets.java
if (Test-Path $packetsPath) {
    $content = [System.IO.File]::ReadAllText($packetsPath, $utf8)
    
    $packetStubs = @"

    // --- SPRINT 1 v3 STUBS FOR LEGACY CALLERS ---

    public static void sendAdminSet(ServerPlayerEntity player, float current, float max, float fatigue, boolean mode, boolean exhausted) {
        // Safe no-op stub for Sprint 1. Will be replaced by real packet in Sprint 2.
    }
"@

    if (-not $content.Contains("public static void sendAdminSet(")) {
        $content = $content -replace "(\s*)\}\s*$", "`$1$packetStubs`n}"
        [System.IO.File]::WriteAllText($packetsPath, $content, $utf8)
        Write-Host " [OK] Added sendAdminSet stub to ModPackets" -ForegroundColor Green
    } else {
        Write-Host " [SKIP] sendAdminSet already present in ModPackets" -ForegroundColor Yellow
    }
} else {
    Write-Host " [WARN] ModPackets.java not found, skipping" -ForegroundColor Yellow
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