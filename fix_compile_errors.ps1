$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$base = "E:\Games\mod\src\main\java\com\example\shinobicore"

Write-Host "=== ИСПРАВЛЕНИЕ ОШИБОК КОМПИЛЯЦИИ ===" -ForegroundColor Cyan

# 1. Fix NinjaProjectileEntity.java (Добавляем импорт ServerPlayerEntity)
$npe = "$base\entity\NinjaProjectileEntity.java"
if (Test-Path $npe) {
    $c1 = [System.IO.File]::ReadAllText($npe, $utf8)
    if (-not $c1.Contains("import net.minecraft.server.network.ServerPlayerEntity;")) {
        $c1 = $c1.Replace("import net.minecraft.server.world.ServerWorld;", "import net.minecraft.server.world.ServerWorld;`nimport net.minecraft.server.network.ServerPlayerEntity;")
        [System.IO.File]::WriteAllText($npe, $c1, $utf8)
        Write-Host "[OK] Добавлен импорт ServerPlayerEntity в NinjaProjectileEntity.java" -ForegroundColor Green
    } else {
        Write-Host "[SKIP] Импорт ServerPlayerEntity уже присутствует" -ForegroundColor Yellow
    }
}

# 2. Fix ElementInteractionManager.java (Исправляем несуществующий Blocks.WOOL)
$eim = "$base\jutsu\ElementInteractionManager.java"
if (Test-Path $eim) {
    $c2 = [System.IO.File]::ReadAllText($eim, $utf8)
    if ($c2.Contains("Blocks.WOOL")) {
        # Заменяем на проверку типа блока (охватывает шерсть любого цвета)
        $c2 = $c2.Replace("b == Blocks.WOOL", "b instanceof net.minecraft.block.WoolBlock")
        [System.IO.File]::WriteAllText($eim, $c2, $utf8)
        Write-Host "[OK] Исправлен Blocks.WOOL на instanceof WoolBlock в ElementInteractionManager.java" -ForegroundColor Green
    } else {
        Write-Host "[SKIP] Blocks.WOOL не найден или уже исправлен" -ForegroundColor Yellow
    }
}

Write-Host "`n=== ОШИБКИ ИСПРАВЛЕНЫ ===" -ForegroundColor Green
Write-Host "Теперь запустите сборку:" -ForegroundColor Cyan
Write-Host ".\gradlew.bat build" -ForegroundColor White