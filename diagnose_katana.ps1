$utf8 = New-Object System.Text.UTF8Encoding($false)
$src = "E:\Games\mod\src\main\java\com\example\shinobicore"
$logFile = "E:\Games\mod\katana_diag.txt"
$lines = New-Object System.Collections.ArrayList

function Add($s) { [void]$lines.Add($s); Write-Host $s }
function DumpFile($path, $label) {
    Add "=== $label ($path) ==="
    if (-not (Test-Path $path)) { Add "FILE NOT FOUND"; Add ""; return }
    $all = [System.IO.File]::ReadAllLines($path, $utf8)
    Add "Total lines: $($all.Count)"
    Add "--- FULL DUMP ---"
    for ($i = 0; $i -lt $all.Count; $i++) {
        Add ("{0:D4}: {1}" -f ($i+1), $all[$i])
    }
    Add "--- END ---"
    Add ""
}

# 1. Дампим KeyBindings.java полностью
DumpFile "$src\client\KeyBindings.java" "KeyBindings.java"

# 2. Дампим ClientInputHandler.java полностью
DumpFile "$src\client\ClientInputHandler.java" "ClientInputHandler.java"

# 3. Дампим KenjutsuClientHandler.java полностью
DumpFile "$src\client\combat\KenjutsuClientHandler.java" "KenjutsuClientHandler.java"

# 4. Дампим ClientNinjaState.java полностью
DumpFile "$src\client\ClientNinjaState.java" "ClientNinjaState.java"

# 5. Дампим ModPackets.java (только регистрацию katana и katana handlers)
Add "=== ModPackets.java: katana-related parts ==="
$mp = "$src\network\ModPackets.java"
if (Test-Path $mp) {
    $all = [System.IO.File]::ReadAllLines($mp, $utf8)
    $inKatana = $false
    for ($i = 0; $i -lt $all.Count; $i++) {
        $l = $all[$i]
        if ($l -match "KATANA_|katana_|KatanaItem|KatanaStance|KatanaDeflect|katanaAttack|katanaStance|katanaDeflect") {
            Add ("{0:D4}: {1}" -f ($i+1), $l)
        }
    }
}
Add ""

# Сохраняем лог
[System.IO.File]::WriteAllLines($logFile, $lines.ToArray(), $utf8)
Write-Host "`n=== FULL DUMP SAVED ===" -ForegroundColor Cyan
Write-Host "File: $logFile" -ForegroundColor Yellow
Write-Host "Now run: .\gradlew.bat build; .\gradlew.bat runClient" -ForegroundColor Yellow
Write-Host "Press F and X with katana in hand, then send me content of katana_diag.txt" -ForegroundColor White