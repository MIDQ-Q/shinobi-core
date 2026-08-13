# fix_duplicate_var.ps1 - Remove duplicate taijutsuLevel declaration
$ErrorActionPreference = "Stop"
$root = "E:\Games\mod\src\main\java\com\example\shinobicore"
$utf8 = New-Object System.Text.UTF8Encoding($false)

$mp = "$root\network\ModPackets.java"
$mpContent = [System.IO.File]::ReadAllText($mp, $utf8)

# Remove the duplicate declaration we added
$mpContent = $mpContent.Replace(
    "            long lastAttack = data.getLastAttackTimeMs();`n            int taijutsuLevel = data.getStatLevel(StatType.TAIJUTSU);",
    "            long lastAttack = data.getLastAttackTimeMs();"
)

[System.IO.File]::WriteAllText($mp, $mpContent, $utf8)
Write-Host "[FIX] ModPackets: removed duplicate taijutsuLevel declaration"
Write-Host "Run: .\gradlew.bat build"