# ============================================================
#  FIX S0-04: SkillTreeScreen invalid node border
#  Uses regex to match any indentation level
#  PS 5.1 compatible. ASCII only. UTF8 no BOM.
# ============================================================
$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$root = "E:\Games\mod"
$java = "$root\src\main\java\com\example\shinobicore"
$file = "$java\client\SkillTreeScreen.java"

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  FIX S0-04: SkillTreeScreen invalid node border" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $file)) {
    Write-Host "[MISS] $file" -ForegroundColor Red
    exit 1
}

$c = [System.IO.File]::ReadAllText($file, $utf8)

# Idempotency check: n.id() is used in render loop (node.id() in tooltip)
if ($c.Contains("isInvalid(n.id())")) {
    Write-Host "[SKIP] border patch already applied" -ForegroundColor Yellow
    exit 0
}

# Step 1: Insert "boolean invalid" line before "int border;"
# Regex captures leading whitespace so indentation is preserved
$c = [regex]::Replace($c,
    '(?m)^(\s+)int border;',
    '$1boolean invalid = SkillTreeRegistry.isInvalid(n.id());$1int border;')

# Step 2: Change "if (unlocked) {" to "if (invalid) { ... } else if (unlocked) {"
# Regex captures indentation of the if-line and the border-line separately
$c = [regex]::Replace($c,
    '(?m)^(\s+)if \(unlocked\) \{\r?\n(\s+)border = bc;',
    '$1if (invalid) {$1    border = 0xFFFF2222;$1} else if (unlocked) {$2border = bc;')

# Verify patch was actually applied
if (-not $c.Contains("isInvalid(n.id())")) {
    Write-Host "[FAIL] regex did not match - check SkillTreeScreen.java manually" -ForegroundColor Red
    exit 1
}

[System.IO.File]::WriteAllText($file, $c, $utf8)
Write-Host "[OK] border patch applied to SkillTreeScreen.java" -ForegroundColor Green
Write-Host ""
Write-Host "  Changes:" -ForegroundColor White
Write-Host "    + boolean invalid = SkillTreeRegistry.isInvalid(n.id())" -ForegroundColor White
Write-Host "    + if (invalid) border = 0xFFFF2222 (red)" -ForegroundColor White
Write-Host "    + else if (unlocked) border = bc" -ForegroundColor White
Write-Host ""
Write-Host "  Next: .\gradlew.bat build" -ForegroundColor Yellow
exit 0