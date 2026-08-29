$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$root = "E:\Games\mod"
$mirrorPath = Join-Path $root "src\main\java\com\example\shinobicore\chakra\server\ServerChakraMirror.java"

Write-Host ""
Write-Host "==============================================================" -ForegroundColor Cyan
Write-Host " FIX SPRINT 1 v4: Deduplicate ServerChakraMirror methods" -ForegroundColor Cyan
Write-Host "==============================================================" -ForegroundColor Cyan
Write-Host ""

if (Test-Path $mirrorPath) {
    $content = [System.IO.File]::ReadAllText($mirrorPath, $utf8)
    
    # We want to keep everything up to and including the clamp method.
    $clampRegex = [regex]"(?s)(.*?private static float clamp\(float value, float min, float max\) \{\s*return Math\.max\(min, Math\.min\(max, value\)\);\s*\})"
    $match = $clampRegex.Match($content)
    
    if ($match.Success) {
        $cleanBase = $match.Groups[1].Value
        
        $cleanStubs = @"

    // --- SPRINT 1 STUBS FOR LEGACY CALLERS ---

    public static void register() {
        // No-op in Sprint 1. Packet registration handled elsewhere.
    }

    public static void applyAdminSet(ServerPlayerEntity player, float current, float max, float fatigue, boolean mode, boolean exhausted) {
        if (player == null) return;
        updateFromClient(player.getUuid(), current, max, fatigue, mode, exhausted);
    }

    public static void updateFromClient(ServerPlayerEntity player, float current, float max, float fatigue, boolean mode, boolean exhausted) {
        if (player == null) return;
        updateFromClient(player.getUuid(), current, max, fatigue, mode, exhausted);
    }

    public static void updateFromClient(ServerPlayerEntity player, float current, float max, boolean mode, boolean exhausted, boolean meditating) {
        if (player == null) return;
        updateFromClient(player.getUuid(), current, max, 0.0f, mode, exhausted);
    }

    public static void updateFromClient(UUID uuid, float current, float max, float fatigue, boolean mode, boolean exhausted) {
        Data data = get(uuid);
        data.current = clamp(current, 0.0f, max);
        data.max = max;
        data.fatigue = fatigue;
        data.chakraMode = mode;
    }
}
"@
        $newContent = $cleanBase + $cleanStubs
        [System.IO.File]::WriteAllText($mirrorPath, $newContent, $utf8)
        Write-Host " [OK] Cleaned up and deduplicated ServerChakraMirror stubs" -ForegroundColor Green
    } else {
        Write-Host " [FAIL] Could not find clamp method to anchor the cleanup!" -ForegroundColor Red
        exit 1
    }
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