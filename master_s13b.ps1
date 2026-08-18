$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$root = "E:\Games\mod"
$srcBase = Join-Path $root "src\main\java\com\example\shinobicore"

Write-Host "=== FIX: Add gate fields to NinjaPlayerData + integration ===" -ForegroundColor Cyan

# ============================================================
# STEP 1: Add gate fields and methods to NinjaPlayerData
# ============================================================
Write-Host "`n[1/3] Adding gate fields to NinjaPlayerData..." -ForegroundColor Yellow

$dataFile = Join-Path $srcBase "stat\NinjaPlayerData.java"
$dataLines = [System.IO.File]::ReadAllLines($dataFile, $utf8)
$dataText = $dataLines -join "`n"

$fieldsToAdd = @(
    '    private int activeGate = 0;',
    '    private int gate8RemainingTicks = 0;',
    '    private int gateCooldownTicks = 0;'
)

$methodsToAdd = @(
    '',
    '    public int getActiveGate() { return activeGate; }',
    '    public void setActiveGate(int v) { this.activeGate = v; }',
    '    public int getGate8RemainingTicks() { return gate8RemainingTicks; }',
    '    public void setGate8RemainingTicks(int v) { this.gate8RemainingTicks = v; }',
    '    public int getGateCooldownTicks() { return gateCooldownTicks; }',
    '    public void setGateCooldownTicks(int v) { this.gateCooldownTicks = v; }'
)

$modified = $false

# Add fields after the last existing field (before first public method)
if (-not $dataText.Contains('private int activeGate')) {
    $newLines = @()
    $fieldsInserted = $false
    foreach ($line in $dataLines) {
        $newLines += $line
        # Insert after the last private field declaration (before first getter)
        if (-not $fieldsInserted -and $line.Trim().StartsWith('private final Set<String> unlockedNodes')) {
            foreach ($f in $fieldsToAdd) { $newLines += $f }
            $fieldsInserted = $true
        }
    }
    $dataLines = $newLines
    $modified = $true
    Write-Host "  [OK] Added 3 gate fields" -ForegroundColor Green
}

# Add methods after getUnlockedNodes()
$dataText = $dataLines -join "`n"
if (-not $dataText.Contains('public int getActiveGate()')) {
    $newLines = @()
    $methodsInserted = $false
    foreach ($line in $dataLines) {
        $newLines += $line
        if (-not $methodsInserted -and $line.Contains('public Set<String> getUnlockedNodes()')) {
            foreach ($m in $methodsToAdd) { $newLines += $m }
            $methodsInserted = $true
        }
    }
    $dataLines = $newLines
    $modified = $true
    Write-Host "  [OK] Added 7 gate getter/setter methods" -ForegroundColor Green
}

if ($modified) {
    $finalText = $dataLines -join "`n"
    [System.IO.File]::WriteAllText($dataFile, $finalText, $utf8)
} else {
    Write-Host "  [SKIP] All gate fields and methods already present" -ForegroundColor Yellow
}

# ============================================================
# STEP 2: Check GatesManager.tick() integration in NinjaTickHandler
# ============================================================
Write-Host "`n[2/3] Checking GatesManager.tick() integration..." -ForegroundColor Yellow

$tickFile = Join-Path $srcBase "event\NinjaTickHandler.java"
if (Test-Path $tickFile) {
    $tickContent = [System.IO.File]::ReadAllText($tickFile, $utf8)
    if ($tickContent.Contains('GatesManager.tick')) {
        Write-Host "  [SKIP] GatesManager.tick() already integrated" -ForegroundColor Yellow
    } else {
        # Find a good insertion point and add the call
        $tickLines = [System.IO.File]::ReadAllLines($tickFile, $utf8)
        $newLines = @()
        $inserted = $false
        foreach ($line in $tickLines) {
            $newLines += $line
            # Insert after the server-side tick start
            if (-not $inserted -and $line.Contains('if (!player.getWorld().isClient)')) {
                $newLines += '            com.example.shinobicore.modes.GatesManager.tick(player);'
                $inserted = $true
            }
        }
        $finalText = $newLines -join "`n"
        [System.IO.File]::WriteAllText($tickFile, $finalText, $utf8)
        Write-Host "  [OK] Added GatesManager.tick() to NinjaTickHandler" -ForegroundColor Green
    }
} else {
    Write-Host "  [MISS] NinjaTickHandler.java not found" -ForegroundColor Red
}

# ============================================================
# STEP 3: Check packet registration in ShinobiCore
# ============================================================
Write-Host "`n[3/3] Checking gate packet handlers in ShinobiCore..." -ForegroundColor Yellow

$scFile = Join-Path $srcBase "ShinobiCore.java"
if (Test-Path $scFile) {
    $scContent = [System.IO.File]::ReadAllText($scFile, $utf8)
    if ($scContent.Contains('GatesManager.activateNextGate')) {
        Write-Host "  [SKIP] Gate packet handlers already registered" -ForegroundColor Yellow
    } else {
        Write-Host "  [INFO] Gate packet handlers missing - showing context for manual addition" -ForegroundColor Yellow
        # Show where to insert
        $scLines = [System.IO.File]::ReadAllLines($scFile, $utf8)
        for ($i = 0; $i -lt $scLines.Count; $i++) {
            if ($scLines[$i] -match 'ServerPlayNetworking.registerGlobalReceiver') {
                Write-Host ("  Line " + ($i+1) + ": " + $scLines[$i].Trim()) -ForegroundColor Cyan
            }
        }
        Write-Host "  Add gate handlers near the existing packet handlers" -ForegroundColor White
    }
}

# ============================================================
# BUILD
# ============================================================
Write-Host "`n[BUILD]..." -ForegroundColor Cyan
Push-Location $root
try {
    $out = & ".\gradlew.bat" build 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [PASS] Build successful!" -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] Build failed" -ForegroundColor Red
        $out | Select-Object -Last 15 | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
    }
} finally { Pop-Location }