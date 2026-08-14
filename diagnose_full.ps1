$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$base = "E:\Games\mod\src\main\java\com\example\shinobicore"

function Show-Section($path, $pattern, $context) {
    if (-not (Test-Path $path)) {
        Write-Host "  [MISSING] $path"
        return
    }
    $content = [System.IO.File]::ReadAllText($path, $utf8)
    $idx = $content.IndexOf($pattern)
    if ($idx -lt 0) {
        Write-Host "  Pattern NOT found: '$pattern'"
        return
    }
    $start = [Math]::Max(0, $idx - $context)
    $end = [Math]::Min($content.Length, $idx + $pattern.Length + $context)
    Write-Host $content.Substring($start, $end - $start)
    Write-Host "---"
}

Write-Host "========== 1. ProgressionScreen: slot click logic =========="
Show-Section "$base\client\ProgressionScreen.java" "assignSlot = i" 200

Write-Host ""
Write-Host "========== 2. ProgressionScreen: imports =========="
if (Test-Path "$base\client\ProgressionScreen.java") {
    $c = [System.IO.File]::ReadAllText("$base\client\ProgressionScreen.java", $utf8)
    $c -split "`n" | Where-Object { $_ -match "^import" } | Select-Object -First 20 | ForEach-Object { Write-Host $_ }
}

Write-Host ""
Write-Host "========== 3. PlayerRenderAnimationMixin (naruto run) =========="
Show-Section "$base\mixin\PlayerRenderAnimationMixin.java" "naruto" 400

Write-Host ""
Write-Host "========== 4. CameraMixin (check what we do) =========="
Show-Section "$base\mixin\CameraMixin.java" "@Inject" 1500

Write-Host ""
Write-Host "========== 5. RpgCamera current state =========="
if (Test-Path "$base\client\RpgCamera.java") {
    [System.IO.File]::ReadAllText("$base\client\RpgCamera.java", $utf8) | Write-Host
}

Write-Host ""
Write-Host "========== 6. Does JutsuAssignmentScreen.java exist? =========="
if (Test-Path "$base\client\JutsuAssignmentScreen.java") {
    Write-Host "[OK] File exists"
    $c = [System.IO.File]::ReadAllText("$base\client\JutsuAssignmentScreen.java", $utf8)
    Write-Host "Size: $($c.Length) chars"
    Write-Host "Has CATEGORIES: $($c.Contains('CATEGORIES'))"
} else {
    Write-Host "[MISSING] File not found"
}