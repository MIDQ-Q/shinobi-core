$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$root = "E:\Games\mod"
$cmdPath = Join-Path $root "src\main\java\com\example\shinobicore\command\ChakraCommands.java"

Write-Host ""
Write-Host "==============================================================" -ForegroundColor Cyan
Write-Host " FIX SPRINT 1: FloatArgumentType import" -ForegroundColor Cyan
Write-Host "==============================================================" -ForegroundColor Cyan
Write-Host ""

if (Test-Path $cmdPath) {
    $content = [System.IO.File]::ReadAllText($cmdPath, $utf8)
    $oldImport = "import net.minecraft.command.argument.FloatArgumentType;"
    $newImport = "import com.mojang.brigadier.arguments.FloatArgumentType;"
    
    if ($content.Contains($oldImport)) {
        $content = $content.Replace($oldImport, $newImport)
        [System.IO.File]::WriteAllText($cmdPath, $content, $utf8)
        Write-Host " [OK] Replaced import with com.mojang.brigadier.arguments.FloatArgumentType" -ForegroundColor Green
    } else {
        Write-Host " [SKIP] Import already fixed or not found" -ForegroundColor Yellow
    }
} else {
    Write-Host " [FAIL] ChakraCommands.java not found!" -ForegroundColor Red
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
        Write-Host "You can run .\gradlew.bat runClient and test:" -ForegroundColor White
        Write-Host "  /shinobicore chakra info" -ForegroundColor Yellow
        Write-Host "  /shinobicore chakra set 1500" -ForegroundColor Yellow
        Write-Host "  /shinobicore chakra add 250" -ForegroundColor Yellow
        Write-Host "  /shinobicore chakra reset" -ForegroundColor Yellow
    } else {
        Write-Host " [FAIL] Build failed:" -ForegroundColor Red
        $out | Select-Object -Last 25 | ForEach-Object { Write-Host " $_" -ForegroundColor Red }
    }
} finally {
    Pop-Location
}