# ============================================================
#  FIX S0-05: NinjaPlayerData starting jutsu patch
#  Uses boundary between applyClanBonuses and removeClanBonuses
#  PS 5.1 compatible. ASCII only. UTF8 no BOM.
# ============================================================
$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$root = "E:\Games\mod"
$file = "$root\src\main\java\com\example\shinobicore\stat\NinjaPlayerData.java"

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  FIX S0-05: NinjaPlayerData starting jutsu" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $file)) {
    Write-Host "[MISS] $file" -ForegroundColor Red
    exit 1
}

$c = [System.IO.File]::ReadAllText($file, $utf8)

# Idempotency check
if ($c.Contains("S0-05: Apply starting jutsu")) {
    Write-Host "[SKIP] starting jutsu patch already applied" -ForegroundColor Yellow
    exit 0
}

# Normalize for matching
$cNorm = $c.Replace("`r`n", "`n")

# Strategy: find the boundary between applyClanBonuses closing and removeClanBonuses opening
# The unique anchor is "private void removeClanBonuses()"
$anchor = "private void removeClanBonuses()"

if (-not $cNorm.Contains($anchor)) {
    Write-Host "[FAIL] anchor 'removeClanBonuses' not found in NinjaPlayerData.java" -ForegroundColor Red
    exit 1
}

# Find the position of the anchor
$anchorIdx = $cNorm.IndexOf($anchor)

# Now find the closing brace of applyClanBonuses just before removeClanBonuses
# Walk backwards from anchor to find the "}" that closes applyClanBonuses
# The pattern we're looking for is: "    }\n\n    private void removeClanBonuses"
# We need to insert our code before that closing "}"

# Find the last "}" before the anchor that's at method level (4 spaces indent)
$searchRegion = $cNorm.Substring(0, $anchorIdx)

# Find the last occurrence of the method-closing pattern
# Looking for: line with just "}" followed by empty line(s) before removeClanBonuses
$lastCloseBrace = $searchRegion.LastIndexOf("}`n")
if ($lastCloseBrace -lt 0) {
    $lastCloseBrace = $searchRegion.LastIndexOf("}`r`n")
}
if ($lastCloseBrace -lt 0) {
    Write-Host "[FAIL] could not find method closing brace" -ForegroundColor Red
    exit 1
}

# Insert the starting jutsu code before the closing brace of applyClanBonuses
$insertCode = @"
        // S0-05: Apply starting jutsu
        if (clan.startingJutsu() != null) {
            for (String jutsuId : clan.startingJutsu()) {
                if (!learnedJutsus.contains(jutsuId)) {
                    learnedJutsus.add(jutsuId);
                    statsDirty = true;
                }
            }
        }
"@

# Build the new content
# We insert before the last "}" of applyClanBonuses
$before = $c.Substring(0, $lastCloseBrace)
$after = $c.Substring($lastCloseBrace)

$newContent = $before + $insertCode + "`n" + $after

# Verify the insertion looks correct
if (-not $newContent.Contains("S0-05: Apply starting jutsu")) {
    Write-Host "[FAIL] insertion verification failed" -ForegroundColor Red
    exit 1
}

[System.IO.File]::WriteAllText($file, $newContent, $utf8)
Write-Host "[OK] starting jutsu patch applied to NinjaPlayerData.java" -ForegroundColor Green
Write-Host ""
Write-Host "  Inserted: starting jutsu auto-learn in applyClanBonuses()" -ForegroundColor White
Write-Host ""
Write-Host "  Next: .\gradlew.bat build" -ForegroundColor Yellow
exit 0