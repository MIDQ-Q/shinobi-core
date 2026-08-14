$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$jutsuDir = "E:\Games\mod\src\main\resources\data\shinobicore\jutsu"

$models = @{
    # === Rasengan & Rasenshuriken ===
    "rasengan.json" = "rasengan"
    "rasenshuriken.json" = "rasenshuriken"
    
    # === Fireballs ===
    "fire_release_great_fireball.json" = "fireball"
    "fire_release_flame_bullet.json" = "fireball"
    "fire_release_dragon_flame.json" = "fireball"
    "fire_release_phoenix_sage.json" = "fireball"
    "fire_phoenix_sage_f.json" = "fireball"
    "uchiha_amaterasu.json" = "fireball"
    "fire_barrage.json" = "fireball"
    "fire_exploding.json" = "fireball"
    "fire_toad_oil.json" = "fireball"
    "fire_flower.json" = "fireball"
    "fire_hard_work.json" = "fireball"
    
    # === Water projectiles & dragons ===
    "water_dragon_bullet.json" = "water_dragon"
    "water_release_water_bullet.json" = "sphere"
    "water_shark_bullet.json" = "sphere"
    "water_shark.json" = "sphere"
    "water_gun.json" = "sphere"
    "water_whip.json" = "sphere"
    "water_five_sharks.json" = "sphere"
    
    # === Lightning ===
    "light_ball.json" = "sphere"
    "light_spear.json" = "sphere"
    "lightning_release_false_darkness.json" = "sphere"
    
    # === Earth ===
    "earth_dragon_bullet.json" = "sphere"
    
    # === Wind, Shurikens, Blades ===
    "shu_triple.json" = "shuriken"
    "shu_homing.json" = "shuriken"
    "shuriken_boomerang.json" = "shuriken"
    "shu_senbon.json" = "shuriken"
    "shu_flash.json" = "shuriken"
    "wind_sickle.json" = "shuriken"
    "wind_vacuum_blade.json" = "shuriken"
    "wind_spiral_shuriken.json" = "shuriken"
    "kenjutsu_wind_slash.json" = "shuriken"
    "wind_air_bullet.json" = "sphere"
    "wind_vacuum_bullet.json" = "sphere"
}

$updatedCount = 0
$skippedCount = 0
$notFoundCount = 0

Write-Host "=== Adding 'model' parameter to jutsu JSON files ===" -ForegroundColor Cyan
Write-Host ""

foreach ($file in $models.Keys) {
    $path = Join-Path $jutsuDir $file
    if (-not (Test-Path $path)) {
        Write-Host "[NOT FOUND] $file" -ForegroundColor DarkGray
        $notFoundCount++
        continue
    }
    
    $content = [System.IO.File]::ReadAllText($path, $utf8)
    $modelName = $models[$file]
    
    # Check if "model" already exists to prevent duplicates
    if ($content -match '"model"\s*:\s*"') {
        Write-Host "[SKIP] Already has model: $file" -ForegroundColor Yellow
        $skippedCount++
        continue
    }
    
    # Find the first '{' and insert the parameter right after it
    $idx = $content.IndexOf('{')
    if ($idx -ge 0) {
        $insertion = "`r`n  `"model`": `"$modelName`","
        $newContent = $content.Insert($idx + 1, $insertion)
        [System.IO.File]::WriteAllText($path, $newContent, $utf8)
        Write-Host "[OK] Added model '$modelName' to $file" -ForegroundColor Green
        $updatedCount++
    } else {
        Write-Host "[ERROR] No '{' found in $file" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor White
Write-Host "Updated: $updatedCount files" -ForegroundColor Green
Write-Host "Skipped: $skippedCount files" -ForegroundColor Yellow
Write-Host "Not found: $notFoundCount files" -ForegroundColor DarkGray
Write-Host "========================================" -ForegroundColor White