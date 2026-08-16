# ============================================================
#  SPRINT 1 / S1-03: CAST TIME BY TIER
#  Base cast time depends on jutsu tier.
#  Control + mastery reduce cast time (max 40%).
#  Formula: cast_time = base * (1 - min(0.4, control_bonus + mastery_bonus))
#
#  PS 5.1 compatible. ASCII only. UTF8 no BOM.
#  Run: powershell -ExecutionPolicy Bypass -File .\sprint1_s03_cast_time.ps1
# ============================================================
$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$root = "E:\Games\mod"
$java = "$root\src\main\java\com\example\shinobicore"
$ok = 0; $skip = 0; $err = 0

function Patch-File($p, $old, $new) {
    if (-not (Test-Path $p)) {
        Write-Host "[MISS] $p" -ForegroundColor Red
        $script:err++
        return
    }
    $c = [System.IO.File]::ReadAllText($p, $utf8)
    $cNorm = $c.Replace("`r`n", "`n")
    $oldNorm = $old.Replace("`r`n", "`n")
    $newNorm = $new.Replace("`r`n", "`n")
    if ($cNorm.Contains($newNorm)) {
        Write-Host "[SKIP] already: $([System.IO.Path]::GetFileName($p))" -ForegroundColor Yellow
        $script:skip++
        return
    }
    if (-not $cNorm.Contains($oldNorm)) {
        Write-Host "[FAIL] pattern not found: $([System.IO.Path]::GetFileName($p))" -ForegroundColor Red
        $script:err++
        return
    }
    $c = $c.Replace($oldNorm, $newNorm)
    [System.IO.File]::WriteAllText($p, $c, $utf8)
    Write-Host "[OK] patched: $([System.IO.Path]::GetFileName($p))" -ForegroundColor Green
    $script:ok++
}

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  SPRINT 1 / S1-03: CAST TIME BY TIER" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

# ================================================================
# 1. ModConfig.java - add CastTime config section
# ================================================================
Write-Host "[1/3] ModConfig.java (CastTime section)..." -ForegroundColor White

# 1a. Add field declaration after stamina
Patch-File "$java\config\ModConfig.java" `
    "public Stamina stamina = new Stamina();" `
    "public Stamina stamina = new Stamina();`n    public CastTime castTime = new CastTime();"

# 1b. Add CastTime class after Stamina class
Patch-File "$java\config\ModConfig.java" `
    "public static class Stamina {`n        public float baseStamina = 100f;`n        public float baseRegen = 5.0f;`n        public float sprintCostPerSecond = 2.0f;`n    }" `
    "public static class Stamina {`n        public float baseStamina = 100f;`n        public float baseRegen = 5.0f;`n        public float sprintCostPerSecond = 2.0f;`n    }`n`n    public static class CastTime {`n        public float tier1Time = 0.5f;`n        public float tier2Time = 1.0f;`n        public float tier3Time = 2.0f;`n        public float tier4Time = 3.0f;`n        public float tier5Time = 5.0f;`n        public float maxReduction = 0.4f;`n        public float controlBonusPerLevel = 0.003f;`n        public float masteryBonusFactor = 0.1f;`n    }"

# ================================================================
# 2. JutsuRegistry.java - castTime default 0 (means: use tier)
# ================================================================
Write-Host "[2/3] JutsuRegistry.java (castTime default)..." -ForegroundColor White

Patch-File "$java\jutsu\JutsuRegistry.java" `
    "float castTime = json.has(""cast_time"") ? json.get(""cast_time"").getAsFloat() : 1.0f;" `
    "float castTime = json.has(""cast_time"") ? json.get(""cast_time"").getAsFloat() : 0f; // S1-03: 0 = use tier default"

# ================================================================
# 3. JutsuCaster.java - rewrite calculateCastTime
# ================================================================
Write-Host "[3/3] JutsuCaster.java (calculateCastTime)..." -ForegroundColor White

$oldCalc = @'
public static int calculateCastTime(com.example.shinobicore.jutsu.JutsuDefinition def, NinjaPlayerData data) {
        float baseTime = 1.5f;
        float complexity = Math.max(0.5f, def.baseCost() / 30f);
        int control = data.getStatLevel(StatType.CONTROL);
        float controlFactor = 1f - (control / 100f * 0.5f);
        float castTimeSeconds = baseTime * complexity * controlFactor;
        int ticks = (int)(castTimeSeconds * 20f);
        return Math.max(10, Math.min(100, ticks));
    }
'@

$newCalc = @'
// === S1-03: Cast time by tier with control/mastery reduction ===
    public static int calculateCastTime(com.example.shinobicore.jutsu.JutsuDefinition def, NinjaPlayerData data) {
        // Base time: explicit JSON override or tier default
        float baseTime;
        if (def.castTime() > 0) {
            baseTime = def.castTime();
        } else {
            baseTime = getCastTimeForTier(def.tier());
        }
        // Reduction from control + mastery (capped at maxReduction)
        float controlBonus = data.getStatLevel(StatType.CONTROL)
                * ModConfig.instance.castTime.controlBonusPerLevel;
        float mastery = NinjaFormula.mastery(def, data);
        float masteryBonus = (mastery / 100f)
                * ModConfig.instance.castTime.masteryBonusFactor;
        float reduction = Math.min(ModConfig.instance.castTime.maxReduction,
                controlBonus + masteryBonus);
        float castTimeSeconds = baseTime * (1f - reduction);
        int ticks = (int)(castTimeSeconds * 20f);
        return Math.max(10, Math.min(100, ticks));
    }

    private static float getCastTimeForTier(int tier) {
        ModConfig.CastTime cfg = ModConfig.instance.castTime;
        switch (tier) {
            case 1: return cfg.tier1Time;
            case 2: return cfg.tier2Time;
            case 3: return cfg.tier3Time;
            case 4: return cfg.tier4Time;
            case 5: return cfg.tier5Time;
            default: return cfg.tier3Time;
        }
    }
'@

Patch-File "$java\jutsu\JutsuCaster.java" $oldCalc $newCalc

# ================================================================
# SUMMARY & EXIT CODE
# ================================================================
Write-Host ""
Write-Host "================================================================" -ForegroundColor Green
Write-Host "  S1-03 COMPLETE: OK=$ok SKIP=$skip ERR=$err" -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Changes:" -ForegroundColor White
Write-Host "    ModConfig.java    +CastTime section (tier times, maxReduction," -ForegroundColor White
Write-Host "                       controlBonusPerLevel, masteryBonusFactor)" -ForegroundColor White
Write-Host "    JutsuRegistry.java castTime default 1.0 -> 0 (0 = use tier)" -ForegroundColor White
Write-Host "    JutsuCaster.java   calculateCastTime rewritten:" -ForegroundColor White
Write-Host "                       - base from tier (T1=0.5s .. T5=5s)" -ForegroundColor White
Write-Host "                       - explicit cast_time JSON overrides tier" -ForegroundColor White
Write-Host "                       - control+mastery reduce up to 40%" -ForegroundColor White
Write-Host ""
Write-Host "  Config defaults (main.json):" -ForegroundColor White
Write-Host "    tier1Time: 0.5s  |  tier2Time: 1.0s  |  tier3Time: 2.0s" -ForegroundColor White
Write-Host "    tier4Time: 3.0s  |  tier5Time: 5.0s" -ForegroundColor White
Write-Host "    maxReduction: 0.4 (40%)" -ForegroundColor White
Write-Host "    controlBonusPerLevel: 0.003 (100 control = 30%)" -ForegroundColor White
Write-Host "    masteryBonusFactor: 0.1 (100 mastery = 10%)" -ForegroundColor White
Write-Host ""

if ($err -gt 0) {
    Write-Host "  [ABORT] $err error(s) detected - stopping sprint chain!" -ForegroundColor Red
    Write-Host "  Fix errors before running next sprint step" -ForegroundColor Red
    exit 1
}

Write-Host "  Next: .\gradlew.bat build" -ForegroundColor Yellow
Write-Host "  Then: sprint1_s04_tier_table.ps1 (tier balance table)" -ForegroundColor Yellow
exit 0