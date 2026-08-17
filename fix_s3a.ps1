$utf8 = New-Object System.Text.UTF8Encoding($false)
$root = "E:\Games\mod"
$path = Join-Path $root "src\main\java\com\example\shinobicore\client\ChakraHudRenderer.java"

$c = [System.IO.File]::ReadAllText($path, $utf8)

$injection = @"

        // S3-02: Contextual HUD — hide bars when full and not in combat
        boolean inCombat = ClientNinjaState.chakraMode || ChakraHudRenderer.currentChakra < ChakraHudRenderer.maxChakra * 0.95f;
        boolean hideBars = HudSettings.current.hideBarsWhenFull && !inCombat;
"@

$anchor = "if (client.player == null) return;"

if ($c.Contains("boolean hideBars =")) {
    Write-Host "[SKIP] hideBars is already defined." -ForegroundColor Yellow
} elseif ($c.Contains($anchor)) {
    $c = $c.Replace($anchor, $anchor + $injection)
    [System.IO.File]::WriteAllText($path, $c, $utf8)
    Write-Host "[OK] Successfully injected hideBars logic into ChakraHudRenderer.java" -ForegroundColor Green
} else {
    Write-Host "[FAIL] Could not find anchor. Manual fix required." -ForegroundColor Red
    exit 1
}

Write-Host "`nBuilding project..." -ForegroundColor Cyan
& "$root\gradlew.bat" build