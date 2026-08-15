# ============================================================
#  FIX: LONGER KATANA BLADE + LONGER SCABBARD
#  Запуск: powershell -ExecutionPolicy Bypass -File .\apply_katana_length_fix.ps1
# ============================================================
$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$root = "E:\Games\mod"
$models = "$root\src\main\resources\assets\shinobicore\models\item"
$java = "$root\src\main\java\com\example\shinobicore"
$ok = 0; $skip = 0; $err = 0

function Write-File($p, $c) {
    $dir = [System.IO.Path]::GetDirectoryName($p)
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [System.IO.File]::WriteAllText($p, $c, $utf8)
    Write-Host "[OK] $($p.Replace("$root\src\main\", ''))" -ForegroundColor Green
    $script:ok++
}
function Patch-File($p, $old, $new) {
    if (-not (Test-Path $p)) { Write-Host "[MISS] $p" -ForegroundColor Red; $script:err++; return }
    $c = [System.IO.File]::ReadAllText($p, $utf8)
    if ($c.Contains($new)) { Write-Host "[SKIP] already: $([System.IO.Path]::GetFileName($p))" -ForegroundColor Yellow; $script:skip++; return }
    if (-not $c.Contains($old)) { Write-Host "[FAIL] pattern: $([System.IO.Path]::GetFileName($p))" -ForegroundColor Red; $script:err++; return }
    $c = $c.Replace($old, $new)
    [System.IO.File]::WriteAllText($p, $c, $utf8)
    Write-Host "[OK] patched: $([System.IO.Path]::GetFileName($p))" -ForegroundColor Green
    $script:ok++
}

Write-Host "`n=== KATANA LENGTH FIX: blade 8 -> 15 units ===" -ForegroundColor Cyan

# ================================================================
# 1. Перегенерируем модели катан с ДЛИННЫМ клинком
#    Рукоять НЕ меняется -> хват в руке остаётся прежним
# ================================================================
function El($f, $t, $px) {
    $uv = @($px, 0, ($px + 1), 1)
    $faces = @{}
    foreach ($s in @("north","east","south","west","up","down")) { $faces[$s] = @{ uv = $uv; texture = "#0" } }
    return @{ from = $f; to = $t; faces = $faces }
}

function New-KatanaModelJson($tex) {
    $els = [System.Collections.ArrayList]::new()
    # --- рукоять (без изменений) ---
    [void]$els.Add((El @(7,0,7)       @(9,1.5,9)     8))   # pommel
    [void]$els.Add((El @(7.4,1.5,7.6) @(8.6,6.5,8.4) 5))   # handle
    [void]$els.Add((El @(7.2,2.4,7.4) @(8.8,3.0,8.6) 6))   # wrap 1
    [void]$els.Add((El @(7.2,3.9,7.4) @(8.8,4.5,8.6) 6))   # wrap 2
    [void]$els.Add((El @(7.2,5.4,7.4) @(8.8,6.0,8.6) 6))   # wrap 3
    [void]$els.Add((El @(6.4,6.5,6.4) @(9.6,7.3,9.6) 3))   # tsuba
    # --- клинок: УДЛИНЁН (7.3 -> 21.0, было 15.2) ---
    [void]$els.Add((El @(7.6,7.3,7.8)  @(8.4,21.0,8.2)  0))  # blade
    [void]$els.Add((El @(7.6,7.3,7.68) @(8.4,21.0,7.8)  1))  # edge (light)
    [void]$els.Add((El @(7.6,7.3,8.2)  @(8.4,21.0,8.32) 2))  # spine (dark)
    [void]$els.Add((El @(7.75,21.0,7.85) @(8.25,22.5,8.15) 1)) # kissaki
    $model = [ordered]@{
        gui_light = "front"
        textures = @{ "0" = $tex; particle = $tex }
        elements = $els
        overrides = @(@{ predicate = @{ custom_model_data = 1 }; model = "shinobicore:item/katana_sheathed" })
        display = [ordered]@{
            thirdperson_righthand = @{ rotation = @(0,-90,55); translation = @(0,4.0,0.5); scale = @(0.8,0.8,0.8) }
            thirdperson_lefthand  = @{ rotation = @(0,90,-55); translation = @(0,4.0,0.5); scale = @(0.8,0.8,0.8) }
            firstperson_righthand = @{ rotation = @(0,-90,25); translation = @(1.13,3.2,1.13); scale = @(0.8,0.8,0.8) }
            firstperson_lefthand  = @{ rotation = @(0,90,-25); translation = @(1.13,3.2,1.13); scale = @(0.8,0.8,0.8) }
            gui    = @{ rotation = @(30,225,0); translation = @(0,-1.6,0); scale = @(0.5,0.5,0.5) }
            ground = @{ rotation = @(0,0,0); translation = @(0,3,0); scale = @(0.35,0.35,0.35) }
            fixed  = @{ rotation = @(0,0,45); translation = @(0,0,0); scale = @(0.45,0.45,0.45) }
        }
    }
    return ($model | ConvertTo-Json -Depth 12)
}

foreach ($n in @("katana_iron","katana_diamond","katana_netherite")) {
    Write-File "$models\$n.json" (New-KatanaModelJson "shinobicore:item/$n")
}

# ================================================================
# 2. Ножны на спине: удлиняем под новый клинок
# ================================================================
$bk = "$java\client\render\BackKatanaRenderer.java"
Patch-File $bk `
"cuboid(matrices, vc, light, -0.05f, -0.95f, -0.05f, 0.10f, 1.30f, 0.10f, saya);" `
"cuboid(matrices, vc, light, -0.05f, -1.25f, -0.05f, 0.10f, 1.60f, 0.10f, saya);"
Patch-File $bk `
"cuboid(matrices, vc, light, -0.06f, -0.55f, -0.06f, 0.12f, 0.08f, 0.12f, wrap);" `
"cuboid(matrices, vc, light, -0.06f, -0.85f, -0.06f, 0.12f, 0.08f, 0.12f, wrap);"
Patch-File $bk `
"cuboid(matrices, vc, light, -0.06f, -0.15f, -0.06f, 0.12f, 0.08f, 0.12f, wrap);" `
"cuboid(matrices, vc, light, -0.06f, -0.25f, -0.06f, 0.12f, 0.08f, 0.12f, wrap);"
Patch-File $bk `
"cuboid(matrices, vc, light, -0.02f, -0.78f, -0.062f, 0.04f, 0.08f, 0.012f, accent);" `
"cuboid(matrices, vc, light, -0.02f, -1.05f, -0.062f, 0.04f, 0.08f, 0.012f, accent);"
Patch-File $bk `
"cuboid(matrices, vc, light, -0.02f, -0.34f, -0.062f, 0.04f, 0.08f, 0.012f, accent);" `
"cuboid(matrices, vc, light, -0.02f, -0.45f, -0.062f, 0.04f, 0.08f, 0.012f, accent);"

Write-Host "`n=== DONE: OK=$ok SKIP=$skip ERR=$err ===" -ForegroundColor Green
Write-Host "Next: .\gradlew.bat runClient" -ForegroundColor Yellow
Write-Host "Tune: если в руке слишком длинно - уменьши scale в display (firstperson/thirdperson)" -ForegroundColor DarkGray