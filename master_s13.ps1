# ============================================================
# SPRINT 13 PHASE A: Critical Fixes
# ============================================================
$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$root = "E:\Games\mod"
$srcBase = Join-Path $root "src\main\java\com\example\shinobicore"

Write-Host ""
Write-Host "==============================================================" -ForegroundColor Cyan
Write-Host "  SPRINT 13 PHASE A: Critical Fixes" -ForegroundColor Cyan
Write-Host "==============================================================" -ForegroundColor Cyan
Write-Host ""

function Write-File($path, $content) {
    $dir = Split-Path $path -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [System.IO.File]::WriteAllText($path, $content, $utf8)
    Write-Host ("  [OK] " + (Split-Path $path -Leaf)) -ForegroundColor Green
}

function Patch-File($p, $old, $new) {
    if (-not (Test-Path $p)) { Write-Host ("  [MISS] " + $p) -ForegroundColor Red; return $false }
    $c = [System.IO.File]::ReadAllText($p, $utf8)
    $c = $c.Replace("`r`n", "`n")
    $oldN = $old.Replace("`r`n", "`n")
    $newN = $new.Replace("`r`n", "`n")
    if ($c.Contains($newN)) { Write-Host ("  [SKIP] already: " + (Split-Path $p -Leaf)) -ForegroundColor Yellow; return $true }
    if (-not $c.Contains($oldN)) { Write-Host ("  [FAIL] pattern: " + (Split-Path $p -Leaf)) -ForegroundColor Red; return $false }
    $c = $c.Replace($oldN, $newN)
    [System.IO.File]::WriteAllText($p, $c, $utf8)
    Write-Host ("  [PATCH] " + (Split-Path $p -Leaf)) -ForegroundColor Green
    return $true
}

# ============================================================
# FIX 1: NinjaProjectileEntity - elemental particles
# ============================================================
Write-Host "[1/4] Fixing NinjaProjectileEntity particles..." -ForegroundColor Yellow

$projFile = Join-Path $srcBase "entity\NinjaProjectileEntity.java"
$projContent = [System.IO.File]::ReadAllText($projFile, $utf8)
$projContent = $projContent.Replace("`r`n", "`n")

# Add getParticleForNature method before the last closing brace
$particleMethod = @'

    /**
     * S13-01: Returns correct particle type based on jutsu nature.
     */
    private net.minecraft.particle.ParticleEffect getParticleForNature() {
        if (this.nature == null) return net.minecraft.particle.ParticleTypes.POOF;
        switch (this.nature) {
            case "fire": return net.minecraft.particle.ParticleTypes.FLAME;
            case "water": return net.minecraft.particle.ParticleTypes.SPLASH;
            case "wind": return net.minecraft.particle.ParticleTypes.CLOUD;
            case "lightning": return net.minecraft.particle.ParticleTypes.ELECTRIC_SPARK;
            case "earth": return net.minecraft.particle.ParticleTypes.CRIT;
            default: return net.minecraft.particle.ParticleTypes.POOF;
        }
    }
'@
$particleMethod = $particleMethod.Replace("`r`n", "`n")

# Insert method before last closing brace
if (-not $projContent.Contains('getParticleForNature')) {
    $lastBrace = $projContent.LastIndexOf('}')
    if ($lastBrace -gt 0) {
        $projContent = $projContent.Substring(0, $lastBrace) + $particleMethod + "`n}"
        Write-Host "  [OK] Added getParticleForNature method" -ForegroundColor Green
    }
}

# Replace FLAME particle usage with getParticleForNature()
$projContent = $projContent.Replace(
    'this.getWorld().addParticle(ParticleTypes.FLAME,',
    'this.getWorld().addParticle(getParticleForNature(),'
)
$projContent = $projContent.Replace(
    'this.getWorld().addParticle(net.minecraft.particle.ParticleTypes.FLAME,',
    'this.getWorld().addParticle(getParticleForNature(),'
)

[System.IO.File]::WriteAllText($projFile, $projContent, $utf8)
Write-Host "  [OK] Replaced FLAME with elemental particles" -ForegroundColor Green

# ============================================================
# FIX 2: EnemyCombatController - reuse list
# ============================================================
Write-Host "[2/4] Optimizing EnemyCombatController..." -ForegroundColor Yellow

$eccFile = Join-Path $srcBase "entity\enemy\EnemyCombatController.java"
if (Test-Path $eccFile) {
    $eccContent = [System.IO.File]::ReadAllText($eccFile, $utf8)
    $eccContent = $eccContent.Replace("`r`n", "`n")
    
    # Add reusable list field
    if (-not $eccContent.Contains('private final List<EnemyAttack> availableAttacks')) {
        $eccContent = $eccContent.Replace(
            'private final List<EnemyAttack> attacks = new ArrayList<>();',
            'private final List<EnemyAttack> attacks = new ArrayList<>();
    private final List<EnemyAttack> availableAttacks = new ArrayList<>();'
        )
        Write-Host "  [OK] Added reusable availableAttacks list" -ForegroundColor Green
    }
    
    # Replace new ArrayList<>() with reusable list
    $eccContent = $eccContent.Replace(
        'List<EnemyAttack> available = new ArrayList<>();',
        'availableAttacks.clear();'
    )
    $eccContent = $eccContent.Replace(
        'available.add(atk)',
        'availableAttacks.add(atk)'
    )
    $eccContent = $eccContent.Replace(
        'if (available.isEmpty()) return null;',
        'if (availableAttacks.isEmpty()) return null;'
    )
    $eccContent = $eccContent.Replace(
        'return available.get(entity.getWorld().getRandom().nextInt(available.size()));',
        'return availableAttacks.get(entity.getWorld().getRandom().nextInt(availableAttacks.size()));'
    )
    
    [System.IO.File]::WriteAllText($eccFile, $eccContent, $utf8)
    Write-Host "  [OK] Optimized chooseAttack to reuse list" -ForegroundColor Green
} else {
    Write-Host "  [MISS] EnemyCombatController.java not found" -ForegroundColor Red
}

# ============================================================
# FIX 3: GatesManager - limit particles
# ============================================================
Write-Host "[3/4] Limiting GatesManager particles..." -ForegroundColor Yellow

$gatesFile = Join-Path $srcBase "modes\GatesManager.java"
if (Test-Path $gatesFile) {
    $gatesContent = [System.IO.File]::ReadAllText($gatesFile, $utf8)
    $gatesContent = $gatesContent.Replace("`r`n", "`n")
    
    # Limit particle count to 5
    $gatesContent = $gatesContent.Replace(
        'int count = (int) gd[4];',
        'int count = Math.min((int) gd[4], 5); // S13-03: Cap particles'
    )
    
    # Change spawn frequency from every 2 ticks to every 4 ticks
    $gatesContent = $gatesContent.Replace(
        'player.age % 2 == 0',
        'player.age % 4 == 0'
    )
    
    [System.IO.File]::WriteAllText($gatesFile, $gatesContent, $utf8)
    Write-Host "  [OK] Limited particles to 5 max, every 4 ticks" -ForegroundColor Green
} else {
    Write-Host "  [MISS] GatesManager.java not found" -ForegroundColor Red
}

# ============================================================
# FIX 4: ClanAuraRenderer - null safety
# ============================================================
Write-Host "[4/4] Adding null safety to ClanAuraRenderer..." -ForegroundColor Yellow

$auraFile = Join-Path $srcBase "client\ClanAuraRenderer.java"
if (Test-Path $auraFile) {
    $auraContent = [System.IO.File]::ReadAllText($auraFile, $utf8)
    $auraContent = $auraContent.Replace("`r`n", "`n")
    
    # Add null/none check
    $auraContent = $auraContent.Replace(
        'if (clanId == null || clanId.isEmpty()) return;',
        'if (clanId == null || clanId.isEmpty() || "none".equals(clanId)) return;'
    )
    
    [System.IO.File]::WriteAllText($auraFile, $auraContent, $utf8)
    Write-Host "  [OK] Added 'none' check for clanId" -ForegroundColor Green
} else {
    Write-Host "  [MISS] ClanAuraRenderer.java not found" -ForegroundColor Red
}

# ============================================================
# BUILD
# ============================================================
Write-Host ""
Write-Host "[BUILD] Verifying compilation..." -ForegroundColor Yellow
Push-Location $root
try {
    $out = & ".\gradlew.bat" build 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [PASS] Build successful!" -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] Build failed" -ForegroundColor Red
        $out | Select-Object -Last 20 | ForEach-Object { Write-Host ("  " + $_) -ForegroundColor Red }
    }
} finally { Pop-Location }

Write-Host ""
Write-Host "==============================================================" -ForegroundColor Green
Write-Host "  SPRINT 13 PHASE A COMPLETE" -ForegroundColor Green
Write-Host "==============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Fixed:" -ForegroundColor White
Write-Host "  1. NinjaProjectileEntity: elemental particles per nature" -ForegroundColor Cyan
Write-Host "  2. EnemyCombatController: reusable list (no GC pressure)" -ForegroundColor Cyan
Write-Host "  3. GatesManager: max 5 particles, every 4 ticks" -ForegroundColor Cyan
Write-Host "  4. ClanAuraRenderer: 'none' clanId safety check" -ForegroundColor Cyan
Write-Host ""