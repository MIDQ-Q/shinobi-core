$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$root = "E:\Games\mod"

function Patch-File($p, $old, $new) {
    if (-not (Test-Path $p)) { 
        Write-Host "[MISS] $p" -ForegroundColor Red; return 
    }
    $c = [System.IO.File]::ReadAllText($p, $utf8)
    
    # Normalize line endings to avoid CRLF/LF mismatch errors
    $c = $c.Replace("`r`n", "`n")
    $old = $old.Replace("`r`n", "`n")
    $new = $new.Replace("`r`n", "`n")
    
    if ($c.Contains($new)) { 
        Write-Host "[SKIP] already applied: $p" -ForegroundColor Yellow; return 
    }
    if (-not $c.Contains($old)) { 
        Write-Host "[FAIL] pattern not found in $p" -ForegroundColor Red; return 
    }
    
    $c = $c.Replace($old, $new)
    [System.IO.File]::WriteAllText($p, $c, $utf8)
    Write-Host "[OK] patched $p" -ForegroundColor Green
}

# =====================================================================
# PATCH 1: ModConfig.java (Add showCastBar)
# =====================================================================
$modConfigPath = "$root\src\main\java\com\example\shinobicore\config\ModConfig.java"
if (Test-Path $modConfigPath) {
    # USE ONLY ASCII COMMENTS INSIDE PS1 SCRIPTS!
    $oldStr = "public float maxReduction = 0.4f;"
    $newStr = "public float maxReduction = 0.4f;`n        public boolean showCastBar = true;"
    Patch-File $modConfigPath $oldStr $newStr
}

# =====================================================================
# PATCH 2: Remove non-existent load call (Example)
# =====================================================================
# $clientPath = "$root\src\main\java\com\example\shinobicore\client\SomeClientFile.java"
# if (Test-Path $clientPath) {
#     $oldCall = "someNonExistentMethod();"
#     $newCall = "// removed non-existent load call"
#     Patch-File $clientPath $oldCall $newCall
# }