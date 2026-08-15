$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$base = "E:\Games\mod\src\main\java\com\example\shinobicore"

Write-Host "=== ИСПРАВЛЕНИЕ ОШИБОК КОМПИЛЯЦИИ (1.20.1 Yarn API) ===" -ForegroundColor Cyan

# 1. Fix BackKatanaRenderer.java (удаление несуществующей переменной sheatheKatana)
$file1 = "$base\client\render\BackKatanaRenderer.java"
if (Test-Path $file1) {
    $c = [System.IO.File]::ReadAllText($file1, $utf8)
    if ($c -match 'sheatheKatana') {
        $c = $c -replace '(?m)^(\s*)if\s*\(\s*sheatheKatana\s*==\s*null\s*\)\s*return;\s*$', '$1// Fixed: removed invalid sheatheKatana check'
        [System.IO.File]::WriteAllText($file1, $c, $utf8)
        Write-Host "[OK] Исправлен BackKatanaRenderer.java" -ForegroundColor Green
    } else {
        Write-Host "[SKIP] BackKatanaRenderer.java уже исправлен" -ForegroundColor Yellow
    }
}

# 2. Fix NarutoArmorRenderer.java (замена getRotation() на rotate())
$file2 = "$base\client\render\NarutoArmorRenderer.java"
if (Test-Path $file2) {
    $c = [System.IO.File]::ReadAllText($file2, $utf8)
    if ($c -match 'getRotation\(\)') {
        # В 1.20.1 Yarn ModelPart применяет поворот напрямую в MatrixStack
        $c = $c -replace 'matrices\.multiply\((model\.[a-zA-Z]+)\.getRotation\(\)\);', '$1.rotate(matrices);'
        [System.IO.File]::WriteAllText($file2, $c, $utf8)
        Write-Host "[OK] Исправлен NarutoArmorRenderer.java" -ForegroundColor Green
    } else {
        Write-Host "[SKIP] NarutoArmorRenderer.java уже исправлен" -ForegroundColor Yellow
    }
}

# 3. Fix ShinobiCoreClient.java (правильный каст к PlayerEntityModel)
$file3 = "$base\client\ShinobiCoreClient.java"
if (Test-Path $file3) {
    $c = [System.IO.File]::ReadAllText($file3, $utf8)
    if ($c -match '\(PlayerEntityModel\)') {
        # LivingEntityRenderer нужно кастить к PlayerEntityRenderer и брать getModel()
        $c = $c -replace '\(PlayerEntityModel\)\s*([a-zA-Z_][a-zA-Z0-9_]*)', '((net.minecraft.client.render.entity.PlayerEntityRenderer) $1).getModel()'
        [System.IO.File]::WriteAllText($file3, $c, $utf8)
        Write-Host "[OK] Исправлен ShinobiCoreClient.java" -ForegroundColor Green
    } else {
        Write-Host "[SKIP] ShinobiCoreClient.java уже исправлен" -ForegroundColor Yellow
    }
}

Write-Host "`n=== ВСЕ ОШИБКИ ИСПРАВЛЕНЫ ===" -ForegroundColor Green
Write-Host "Теперь запустите сборку:" -ForegroundColor Cyan
Write-Host ".\gradlew.bat build" -ForegroundColor White