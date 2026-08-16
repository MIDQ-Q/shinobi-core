# ============================================================
#  FIX: NinjaPlayerData stamina fields + NBT + regen + tick
#  Idempotent: checks current state before patching
#  PS 5.1 compatible. ASCII only. UTF8 no BOM.
# ============================================================
$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$root = "E:\Games\mod"
$java = "$root\src\main\java\com\example\shinobicore"
$ok = 0; $skip = 0; $err = 0

function Read-File($p) {
    if (-not (Test-Path $p)) { return $null }
    return [System.IO.File]::ReadAllText($p, $utf8)
}

function Write-File($p, $c) {
    [System.IO.File]::WriteAllText($p, $c, $utf8)
}

function Patch-File($p, $old, $new) {
    if (-not (Test-Path $p)) { Write-Host "[MISS] $p" -ForegroundColor Red; $script:err++; return $false }
    $c = [System.IO.File]::ReadAllText($p, $utf8)
    $cNorm = $c.Replace("`r`n", "`n")
    $oldNorm = $old.Replace("`r`n", "`n")
    $newNorm = $new.Replace("`r`n", "`n")
    if ($cNorm.Contains($newNorm)) {
        Write-Host "[SKIP] already: $([System.IO.Path]::GetFileName($p))" -ForegroundColor Yellow
        $script:skip++
        return $true
    }
    if (-not $cNorm.Contains($oldNorm)) {
        Write-Host "[FAIL] pattern not found: $([System.IO.Path]::GetFileName($p))" -ForegroundColor Red
        $script:err++
        return $false
    }
    $c = $c.Replace($oldNorm, $newNorm)
    [System.IO.File]::WriteAllText($p, $c, $utf8)
    Write-Host "[OK] patched: $([System.IO.Path]::GetFileName($p))" -ForegroundColor Green
    $script:ok++
    return $true
}

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  FIX: STAMINA IN NinjaPlayerData + NBT + TICK" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

# ================================================================
# 1. Check and add stamina fields to NinjaPlayerData.java
# ================================================================
Write-Host "[1/6] NinjaPlayerData.java (stamina fields)..." -ForegroundColor White
$npdPath = "$java\stat\NinjaPlayerData.java"
$c = Read-File $npdPath

if ($null -eq $c) {
    Write-Host "[FAIL] File not found: $npdPath" -ForegroundColor Red
    $err++
} elseif ($c.Contains("private float currentStamina")) {
    Write-Host "[SKIP] stamina fields already present" -ForegroundColor Yellow
    $skip++
} else {
    # Try to insert after currentChakra declaration (any value)
    if ($c.Contains("private int reserveLevel = 1;")) {
        $c = $c.Replace("private int reserveLevel = 1;",
            "private float currentStamina = 100f;`n    private float maxStamina = 100f;`n    private float modeBuffer = 0f;`n    private int reserveLevel = 1;")
        Write-File $npdPath $c
        Write-Host "[OK] stamina fields added (after currentChakra)" -ForegroundColor Green
        $ok++
    } else {
        Write-Host "[FAIL] Could not find insertion point for stamina fields" -ForegroundColor Red
        $err++
    }
}

# ================================================================
# 2. Check and add stamina getters/setters
# ================================================================
Write-Host "[2/6] NinjaPlayerData.java (stamina getters)..." -ForegroundColor White
$c = Read-File $npdPath
if ($null -ne $c) {
    if ($c.Contains("public float getCurrentStamina()")) {
        Write-Host "[SKIP] stamina getters already present" -ForegroundColor Yellow
        $skip++
    } else {
        # Insert after getCurrentChakra method
        $result = Patch-File $npdPath `
            "public float getCurrentChakra() { return currentChakra; }" `
            "public float getCurrentChakra() { return currentChakra; }`n    public float getCurrentStamina() { return currentStamina; }`n    public void setCurrentStamina(float v) { this.currentStamina = Math.max(0, Math.min(v, maxStamina)); }`n    public float getMaxStamina() { return maxStamina; }`n    public void setMaxStamina(float v) { this.maxStamina = Math.max(1, v); }`n    public float getModeBuffer() { return modeBuffer; }`n    public void setModeBuffer(float v) { this.modeBuffer = Math.max(0, v); }"
    }
}

# ================================================================
# 3. Check and add NBT write for stamina
# ================================================================
Write-Host "[3/6] NinjaPlayerData.java (NBT write)..." -ForegroundColor White
$c = Read-File $npdPath
if ($null -ne $c) {
    if ($c.Contains('nbt.putFloat("Stamina", currentStamina)')) {
        Write-Host "[SKIP] NBT write for stamina already present" -ForegroundColor Yellow
        $skip++
    } else {
        $result = Patch-File $npdPath `
            'nbt.putFloat("Chakra", currentChakra);' `
            'nbt.putFloat("Chakra", currentChakra);
        nbt.putFloat("Stamina", currentStamina);
        nbt.putFloat("MaxStamina", maxStamina);
        nbt.putFloat("ModeBuffer", modeBuffer);'
    }
}

# ================================================================
# 4. Check and add NBT read for stamina
# ================================================================
Write-Host "[4/6] NinjaPlayerData.java (NBT read)..." -ForegroundColor White
$c = Read-File $npdPath
if ($null -ne $c) {
    if ($c.Contains('currentStamina = nbt.contains("Stamina")')) {
        Write-Host "[SKIP] NBT read for stamina already present" -ForegroundColor Yellow
        $skip++
    } else {
        $result = Patch-File $npdPath `
            'currentChakra = nbt.getFloat("Chakra");' `
            'currentChakra = nbt.getFloat("Chakra");
        currentStamina = nbt.contains("Stamina") ? nbt.getFloat("Stamina") : 100f;
        maxStamina = nbt.contains("MaxStamina") ? nbt.getFloat("MaxStamina") : 100f;
        modeBuffer = nbt.getFloat("ModeBuffer");'
    }
}

# ================================================================
# 5. Check and add stamina regen in NinjaTickHandler.java
# ================================================================
Write-Host "[5/6] NinjaTickHandler.java (stamina regen)..." -ForegroundColor White
$nthPath = "$java\event\NinjaTickHandler.java"
$c = Read-File $nthPath
if ($null -eq $c) {
    Write-Host "[MISS] $nthPath" -ForegroundColor Red
    $err++
} elseif ($c.Contains("data.getCurrentStamina() < data.getMaxStamina()")) {
    Write-Host "[SKIP] stamina regen already present" -ForegroundColor Yellow
    $skip++
} else {
    $result = Patch-File $nthPath `
        "if (data.getFatigue() > 0) {" `
        "// === S1-02: STAMINA REGEN & SPRINT COST ===
            if (data.getCurrentStamina() < data.getMaxStamina()) {
                float stRegen = ModConfig.instance.stamina.baseRegen;
                data.setCurrentStamina(data.getCurrentStamina() + stRegen);
            }
            if (player.isSprinting() && data.getCurrentStamina() > 0) {
                data.setCurrentStamina(data.getCurrentStamina() - ModConfig.instance.stamina.sprintCostPerSecond);
            }

            if (data.getFatigue() > 0) {"
}

# ================================================================
# 6. Check stamina factor in NinjaFormula.java
# ================================================================
Write-Host "[6/6] NinjaFormula.java (stamina factor)..." -ForegroundColor White
$nfPath = "$java\stat\NinjaFormula.java"
$c = Read-File $nfPath
if ($null -eq $c) {
    Write-Host "[MISS] $nfPath" -ForegroundColor Red
    $err++
} elseif ($c.Contains("staminaFactor")) {
    Write-Host "[SKIP] stamina factor already present" -ForegroundColor Yellow
    $skip++
} else {
    $result = Patch-File $nfPath `
        "return regen;
    }" `
        "// S1-02: Stamina factor
        float staminaFactor = 0.3f + 0.7f * (data.getCurrentStamina() / Math.max(1f, data.getMaxStamina()));
        regen *= staminaFactor;

        return regen;
    }"
}

# ================================================================
# SUMMARY
# ================================================================
Write-Host ""
Write-Host "================================================================" -ForegroundColor Green
Write-Host "  FIX COMPLETE: OK=$ok SKIP=$skip ERR=$err" -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Green
Write-Host ""

if ($err -gt 0) {
    Write-Host "  [ABORT] $err error(s) detected!" -ForegroundColor Red
    exit 1
}

Write-Host "  Next: .\gradlew.bat build" -ForegroundColor Yellow
exit 0