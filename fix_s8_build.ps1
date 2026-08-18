$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$root = "E:\Games\mod"

Write-Host "=== Fixing S8 Compilation Errors (Yarn 1.20.1 API) ===" -ForegroundColor Cyan

# 1. Fix RoadBuilder.java (fromHorizontalDegrees -> fromRotation)
$builderFile = "$root\src\main\java\com\example\shinobicore\world\road\RoadBuilder.java"
if (Test-Path $builderFile) {
    $c = [System.IO.File]::ReadAllText($builderFile, $utf8)
    if ($c.Contains("fromHorizontalDegrees")) {
        $c = $c.Replace("Direction.fromHorizontalDegrees(", "Direction.fromRotation(")
        [System.IO.File]::WriteAllText($builderFile, $c, $utf8)
        Write-Host "[OK] Patched RoadBuilder.java" -ForegroundColor Green
    } else {
        Write-Host "[SKIP] RoadBuilder.java already fixed" -ForegroundColor Yellow
    }
} else {
    Write-Host "[MISS] RoadBuilder.java not found" -ForegroundColor Red
}

# 2. Fix RoadPathfinder.java (Direction.HORIZONTAL -> explicit array)
$pathfinderFile = "$root\src\main\java\com\example\shinobicore\world\road\RoadPathfinder.java"
if (Test-Path $pathfinderFile) {
    $c = [System.IO.File]::ReadAllText($pathfinderFile, $utf8)
    if ($c.Contains("Direction.HORIZONTAL")) {
        # Заменяем на явный массив 4-х горизонтальных направлений
        $c = $c.Replace("Direction.HORIZONTAL", "new Direction[]{Direction.NORTH, Direction.SOUTH, Direction.EAST, Direction.WEST}")
        [System.IO.File]::WriteAllText($pathfinderFile, $c, $utf8)
        Write-Host "[OK] Patched RoadPathfinder.java" -ForegroundColor Green
    } else {
        Write-Host "[SKIP] RoadPathfinder.java already fixed" -ForegroundColor Yellow
    }
} else {
    Write-Host "[MISS] RoadPathfinder.java not found" -ForegroundColor Red
}

Write-Host "`n=== Done! Run .\gradlew.bat build ===" -ForegroundColor Cyan