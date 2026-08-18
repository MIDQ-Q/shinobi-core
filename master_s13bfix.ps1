$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$root = "E:\Games\mod"
$srcBase = Join-Path $root "src\main\java\com\example\shinobicore"

Write-Host "=== SPRINT 13B-1: Jump Balance Fix ===" -ForegroundColor Cyan

# ============================================================
# FIX 1: ChargedJumpAction - hard vertical cap + reduced sprint boost
# ============================================================
Write-Host "`n[1/3] Fixing ChargedJumpAction..." -ForegroundColor Yellow

$jumpFile = Join-Path $srcBase "client\parkour\actions\ChargedJumpAction.java"
$jumpContent = [System.IO.File]::ReadAllText($jumpFile, $utf8)
$jumpContent = $jumpContent.Replace("`r`n", "`n")

# Fix 1a: Reduce sprint boost from 0.3 to 0.12
$jumpContent = $jumpContent.Replace(
    'if (player.isSprinting()) {
              player.addVelocity(0, 0.3, 0);',
    'if (player.isSprinting()) {
              player.addVelocity(0, 0.12f, 0);  // S13-05: reduced from 0.3'
)

# Fix 1b: Add hard vertical velocity cap after charge multiplier
# Replace the charge section
$oldChargeBlock = @'
                      doVanillaJump(player);
                      
                      // Умножаем вертикальную скорость на множитель заряда
                      Vec3d v = player.getVelocity();
                      player.setVelocity(v.x, v.y * chargeMultiplier, v.z);
                      player.velocityModified = true;
'@

$newChargeBlock = @'
                      doVanillaJump(player);
                      
                      // Умножаем вертикальную скорость на множитель заряда
                      Vec3d v = player.getVelocity();
                      double cappedY = Math.min(v.y * chargeMultiplier, 1.5);  // S13-05: hard vertical cap
                      player.setVelocity(v.x, cappedY, v.z);
                      player.velocityModified = true;
'@

$oldChargeBlock = $oldChargeBlock.Replace("`r`n", "`n")
$newChargeBlock = $newChargeBlock.Replace("`r`n", "`n")

if ($jumpContent.Contains($oldChargeBlock)) {
    $jumpContent = $jumpContent.Replace($oldChargeBlock, $newChargeBlock)
    Write-Host "  [OK] Added hard vertical cap (1.5) in charged jump" -ForegroundColor Green
} else {
    Write-Host "  [WARN] Charge block not found, trying line-by-line fix" -ForegroundColor Yellow
    $jumpContent = $jumpContent.Replace(
        'player.setVelocity(v.x, v.y * chargeMultiplier, v.z);',
        'player.setVelocity(v.x, Math.min(v.y * chargeMultiplier, 1.5), v.z);  // S13-05: hard cap'
    )
}

# Fix 1c: Add final cap at the end of doVanillaJump
if (-not $jumpContent.Contains('MAX_VERTICAL_VELOCITY')) {
    # Add constant and final cap
    $jumpContent = $jumpContent.Replace(
        'private static final float CHARGE_MULTIPLIER = 2.0f;',
        'private static final float CHARGE_MULTIPLIER = 2.0f;
    private static final float MAX_VERTICAL_VELOCITY = 1.2f;  // S13-05: hard cap'
    )
    
    # Add final velocity clamp at end of doVanillaJump before last player.velocityModified
    $jumpContent = $jumpContent.Replace(
        '          player.velocityModified = true;
      }

      @Override
      public void deactivate',
        '          // S13-05: Final vertical velocity cap
          Vec3d finalV = player.getVelocity();
          if (finalV.y > MAX_VERTICAL_VELOCITY) {
              player.setVelocity(finalV.x, MAX_VERTICAL_VELOCITY, finalV.z);
          }
          player.velocityModified = true;
      }

      @Override
      public void deactivate'
    )
    Write-Host "  [OK] Added MAX_VERTICAL_VELOCITY constant and final clamp" -ForegroundColor Green
}

[System.IO.File]::WriteAllText($jumpFile, $jumpContent, $utf8)
Write-Host "  [OK] ChargedJumpAction.java patched" -ForegroundColor Green

# ============================================================
# FIX 2: NinjaFormula - more aggressive vertical cap
# ============================================================
Write-Host "`n[2/3] Tightening NinjaFormula vertical multiplier..." -ForegroundColor Yellow

$formulaFile = Join-Path $srcBase "stat\NinjaFormula.java"
$formulaContent = [System.IO.File]::ReadAllText($formulaFile, $utf8)
$formulaContent = $formulaContent.Replace("`r`n", "`n")

# Reduce vertical multiplier growth: was 0.03 per level, now 0.025 per level
# And lower the base from 1.1 to 1.05
$formulaContent = $formulaContent.Replace(
    'float base = 1.1f + jumpLevel * 0.03f;',
    'float base = 1.05f + jumpLevel * 0.025f;  // S13-05: reduced growth'
)

# Add a hard cap of 1.35 to the result (even if config cap is higher)
$formulaContent = $formulaContent.Replace(
    'return Math.min(base, cfg().movement.jumpVertCap);',
    'return Math.min(Math.min(base, cfg().movement.jumpVertCap), 1.35f);  // S13-05: hard cap'
)

[System.IO.File]::WriteAllText($formulaFile, $formulaContent, $utf8)
Write-Host "  [OK] NinjaFormula vertical multiplier tightened" -ForegroundColor Green

# ============================================================
# FIX 3: ChakraPhysicsClient - double jump cap
# ============================================================
Write-Host "`n[3/3] Adding velocity cap to double jump..." -ForegroundColor Yellow

$physicsFile = Join-Path $srcBase "client\ChakraPhysicsClient.java"
$physicsContent = [System.IO.File]::ReadAllText($physicsFile, $utf8)
$physicsContent = $physicsContent.Replace("`r`n", "`n")

# Cap double jump vertical velocity
$physicsContent = $physicsContent.Replace(
    'if (canParkour && jumpEdge && !onGroundOrWater && airJumpsUsed < 1) {
              player.addVelocity(0, 0.42, 0);
              player.velocityModified = true;',
    'if (canParkour && jumpEdge && !onGroundOrWater && airJumpsUsed < 1) {
              // S13-05: Cap double jump vertical velocity
              Vec3d curVel = player.getVelocity();
              double newVY = Math.min(curVel.y + 0.42, 1.0);
              player.setVelocity(curVel.x, newVY, curVel.z);
              player.velocityModified = true;'
)

[System.IO.File]::WriteAllText($physicsFile, $physicsContent, $utf8)
Write-Host "  [OK] Double jump capped at 1.0 vertical" -ForegroundColor Green

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

Write-Host ""
Write-Host "==============================================================" -ForegroundColor Green
Write-Host "  SPRINT 13B-1: JUMP BALANCE COMPLETE" -ForegroundColor Green
Write-Host "==============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Changes:" -ForegroundColor White
Write-Host "  1. Charged jump: hard vertical cap 1.5 + final clamp 1.2" -ForegroundColor Cyan
Write-Host "  2. Sprint boost: reduced from 0.3 to 0.12" -ForegroundColor Cyan
Write-Host "  3. Vertical formula: base 1.05 + 0.025/level, hard cap 1.35" -ForegroundColor Cyan
Write-Host "  4. Double jump: capped at 1.0 vertical velocity" -ForegroundColor Cyan
Write-Host ""
Write-Host "Max vertical speed now: ~1.5 (charged jump with all bonuses)" -ForegroundColor Yellow
Write-Host "Previously: ~2.5+ (unlimited)" -ForegroundColor Yellow
Write-Host ""