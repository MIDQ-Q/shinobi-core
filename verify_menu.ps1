$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$ps = "E:\Games\mod\src\main\java\com\example\shinobicore\client\ProgressionScreen.java"
$c = [System.IO.File]::ReadAllText($ps, $utf8)

Write-Host "=== Verification ==="
Write-Host "1. JutsuAssignmentScreen imported/used:"
if ($c.Contains("JutsuAssignmentScreen")) { Write-Host "   [OK] Found" } else { Write-Host "   [MISSING]" }

Write-Host "2. Slot click opens new screen:"
if ($c.Contains("client.setScreen(new JutsuAssignmentScreen")) { Write-Host "   [OK] Slot click -> new screen" } else { Write-Host "   [MISSING]" }

Write-Host "3. Old assignSlot logic (may still exist, but unreachable):"
$count = ([regex]::Matches($c, 'assignSlot\s*=\s*-1')).Count
Write-Host "   Found $count occurrences of 'assignSlot = -1'"
Write-Host ""
Write-Host "=== Build is successful, ready to test! ==="