# fix_find_duplicates.ps1 - Find and fix duplicate taijutsuLevel
$ErrorActionPreference = "Stop"
$root = "E:\Games\mod\src\main\java\com\example\shinobicore"
$utf8 = New-Object System.Text.UTF8Encoding($false)

$mp = "$root\network\ModPackets.java"
$content = [System.IO.File]::ReadAllText($mp, $utf8)
$lines = $content -split "`n"

Write-Host "=== All lines with 'taijutsuLevel' ==="
$found = @()
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match 'taijutsuLevel') {
        Write-Host "Line $($i+1): $($lines[$i].TrimStart())"
        $found += $i
    }
}

Write-Host ""
Write-Host "Found $($found.Count) occurrences"

# Strategy: remove the FIRST occurrence (added by script), keep the SECOND (original)
# The first one is near 'long lastAttack' (added by fix_phase7_errors.ps1)
# The second one is the original in the 'apply damage' section

if ($found.Count -ge 2) {
    # Remove the first occurrence
    $firstIdx = $found[0]
    $lineContent = $lines[$firstIdx]
    Write-Host ""
    Write-Host "Removing line $($firstIdx+1): $($lineContent.TrimStart())"
    
    $lines[$firstIdx] = ""  # Remove the line
    
    $newContent = $lines -join "`n"
    [System.IO.File]::WriteAllText($mp, $newContent, $utf8)
    Write-Host "[FIX] Removed duplicate taijutsuLevel declaration"
    Write-Host "Run: .\gradlew.bat build"
} elseif ($found.Count -eq 1) {
    Write-Host "Only one occurrence found - no duplicate to fix"
    Write-Host "The error might be from a different source"
} else {
    Write-Host "No occurrences found - something is wrong"
}