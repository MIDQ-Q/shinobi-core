$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$res = "E:\Games\mod\src\main\resources\data\shinobicore\jutsu"

function Patch-JsonFile($path, $field, $value) {
    if (-not (Test-Path $path)) {
        Write-Host "[SKIP] File not found: $path" -ForegroundColor Yellow
        return
    }
    $c = [System.IO.File]::ReadAllText($path, $utf8)
    
    # Already patched check
    if ($c.Contains($field)) {
        Write-Host "[SKIP] Already patched: $path" -ForegroundColor Yellow
        return
    }
    
    # Remove trailing whitespace/newlines and closing brace
    $c = $c.TrimEnd()
    if ($c.EndsWith("}")) {
        $c = $c.Substring(0, $c.Length - 1).TrimEnd()
        # Remove trailing comma if exists
        if ($c.EndsWith(",")) {
            $c = $c.Substring(0, $c.Length - 1)
        }
        $c += ',' + "`n" + '    "' + $field + '":' + '"' + $value + '"' + "`n" + "}"
    }
    
    [System.IO.File]::WriteAllText($path, $c, $utf8)
    Write-Host "[OK] Patched: $path" -ForegroundColor Green
}

Write-Host "=== PATCHING JUTSU JSON FILES ===" -ForegroundColor Cyan

# 1. amaterasu.json -> requiresDojutsu: sharingan
Patch-JsonFile "$res\amaterasu.json" "requiresDojutsu" "sharingan"

# 2. uchiha_amaterasu.json -> requiresDojutsu: sharingan
Patch-JsonFile "$res\uchiha_amaterasu.json" "requiresDojutsu" "sharingan"

# 3. forbidden_eight_gates.json -> requiresScroll: scroll_of_eight_gates
Patch-JsonFile "$res\forbidden_eight_gates.json" "requiresScroll" "scroll_of_eight_gates"

# 4. forbidden_edo_tensei.json -> requiresScroll: scroll_of_edo_tensei
Patch-JsonFile "$res\forbidden_edo_tensei.json" "requiresScroll" "scroll_of_edo_tensei"

Write-Host ""
Write-Host "=== ALL JSON PATCHES APPLIED ===" -ForegroundColor Green