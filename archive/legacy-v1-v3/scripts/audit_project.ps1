# ============================================================
#  SHINOBICORE GLOBAL AUDIT SCRIPT (PowerShell 5.1 compatible)
#  Запуск: powershell -ExecutionPolicy Bypass -File .\audit_project.ps1
# ============================================================
$ErrorActionPreference = "Continue"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$root = "E:\Games\mod"
$srcJava = "$root\src\main\java"
$srcRes  = "$root\src\main\resources"
$report  = "$root\AUDIT_REPORT_$(Get-Date -Format 'yyyyMMdd_HHmmss').md"

$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine("# ShinobiCore Audit Report")
[void]$sb.AppendLine("**Date:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
[void]$sb.AppendLine("")

$critCount = 0
$warnCount = 0
$infoCount = 0

function Log($level, $msg) {
    if ($level -eq "CRIT") { $script:critCount++ }
    elseif ($level -eq "WARN") { $script:warnCount++ }
    else { $script:infoCount++ }

    $icon = "?"
    if ($level -eq "CRIT") { $icon = "[CRIT]" }
    elseif ($level -eq "WARN") { $icon = "[WARN]" }
    else { $icon = "[INFO]" }

    [void]$sb.AppendLine("- $icon $msg")
    Write-Host "$icon $msg"
}

# ============ 1. JAVA VERSION CONSISTENCY ============
[void]$sb.AppendLine("## 1. Java Version Consistency")
$gradleFile = "$root\build.gradle"
$mixinsFile = "$srcRes\shinobicore.mixins.json"
$gradleJava = ""
$mixinsJava = ""
if (Test-Path $gradleFile) {
    $g = Get-Content $gradleFile -Raw
    if ($g -match 'options\.release\s*=\s*(\d+)') { $gradleJava = $matches[1] }
}
if (Test-Path $mixinsFile) {
    $m = Get-Content $mixinsFile -Raw
    if ($m -match '"compatibilityLevel"\s*:\s*"JAVA_(\d+)"') { $mixinsJava = $matches[1] }
}
if ($gradleJava -and $mixinsJava -and $gradleJava -ne $mixinsJava) {
    Log "CRIT" "Java mismatch: build.gradle targets Java $gradleJava, mixins.json declares JAVA_$mixinsJava"
} else {
    Log "INFO" "Java versions consistent: $gradleJava / JAVA_$mixinsJava"
}
[void]$sb.AppendLine("")

# ============ 2. DEBUG PRINTS IN PRODUCTION CODE ============
[void]$sb.AppendLine("## 2. Debug Prints (System.out / System.err)")
$debugFiles = @{}
Get-ChildItem $srcJava -Recurse -Filter "*.java" | ForEach-Object {
    $content = Get-Content $_.FullName -Encoding UTF8
    $lineNum = 0
    foreach ($line in $content) {
        $lineNum++
        if ($line -match 'System\.out\.print|System\.err\.print') {
            $rel = $_.FullName.Replace($root + "\", "")
            if (-not $debugFiles.ContainsKey($rel)) { $debugFiles[$rel] = @() }
            $trimmed = $line.Trim()
            if ($trimmed.Length -gt 100) { $trimmed = $trimmed.Substring(0, 100) }
            $debugFiles[$rel] += "  Line $lineNum`: $trimmed"
        }
    }
}
if ($debugFiles.Count -gt 0) {
    Log "CRIT" "Found debug prints in $($debugFiles.Count) files:"
    foreach ($f in $debugFiles.Keys) {
        [void]$sb.AppendLine("  - **$f**")
        $debugFiles[$f] | Select-Object -First 5 | ForEach-Object { [void]$sb.AppendLine("    $_") }
    }
} else {
    Log "INFO" "No System.out/err prints found"
}
[void]$sb.AppendLine("")

# ============ 3. MIXIN REGISTRATION CHECK ============
[void]$sb.AppendLine("## 3. Mixin Registration")
$mixinClasses = @()
$mixinDir = "$srcJava\com\example\shinobicore\mixin"
if (Test-Path $mixinDir) {
    Get-ChildItem $mixinDir -Filter "*.java" | ForEach-Object {
        $mixinClasses += $_.BaseName
    }
}
if (Test-Path $mixinsFile) {
    $mixinsJson = Get-Content $mixinsFile -Raw | ConvertFrom-Json
    $registered = $mixinsJson.mixins
    foreach ($mc in $mixinClasses) {
        if ($registered -notcontains $mc) {
            Log "CRIT" "Mixin class '$mc.java' exists but NOT registered in shinobicore.mixins.json"
        }
    }
    foreach ($r in $registered) {
        if ($mixinClasses -notcontains $r) {
            Log "CRIT" "Mixin '$r' registered in JSON but .java file NOT found"
        }
    }
    Log "INFO" "Mixin check done: $($mixinClasses.Count) files, $($registered.Count) registered"
} else {
    Log "CRIT" "shinobicore.mixins.json not found!"
}
[void]$sb.AppendLine("")

# ============ 4. DEAD JAVA FILES ============
[void]$sb.AppendLine("## 4. Potentially Dead / Unused Java Files")
$knownDead = @("ClanType", "GameRendererMixin")
foreach ($d in $knownDead) {
    $path = Get-ChildItem $srcJava -Recurse -Filter "$d.java" -ErrorAction SilentlyContinue
    if ($path) {
        Log "WARN" "Likely dead file: $($path.FullName.Replace($root + '\', ''))"
    }
}
# Check for nearly empty Java files
Get-ChildItem $srcJava -Recurse -Filter "*.java" | ForEach-Object {
    $content = [System.IO.File]::ReadAllText($_.FullName, $utf8).Trim()
    $body = $content -replace '(?s)package\s+[^;]+;', ''
    $body = $body -replace '(?s)import\s+[^;]+;', ''
    if ($body.Length -lt 50) {
        Log "WARN" "Nearly empty file: $($_.FullName.Replace($root + '\', ''))"
    }
}
[void]$sb.AppendLine("")

# ============ 5. DUPLICATE IMPORTS ============
[void]$sb.AppendLine("## 5. Duplicate Imports")
$dupeCount = 0
Get-ChildItem $srcJava -Recurse -Filter "*.java" | ForEach-Object {
    $lines = Get-Content $_.FullName -Encoding UTF8
    $imports = $lines | Where-Object { $_ -match '^\s*import\s+' } | ForEach-Object { $_.Trim() }
    $grouped = $imports | Group-Object | Where-Object { $_.Count -gt 1 }
    if ($grouped) {
        $dupeCount++
        $rel = $_.FullName.Replace($root + "\", "")
        foreach ($g in $grouped) {
            Log "WARN" "Duplicate import in $rel`: $($g.Name) (x$($g.Count))"
        }
    }
}
if ($dupeCount -eq 0) { Log "INFO" "No duplicate imports found" }
[void]$sb.AppendLine("")

# ============ 6. JSON VALIDATION (JUTSU) ============
[void]$sb.AppendLine("## 6. Jutsu JSON Validation")
$jutsuDir = "$srcRes\data\shinobicore\jutsu"
$jutsuIds = @{}
$jutsuCount = 0
if (Test-Path $jutsuDir) {
    Get-ChildItem $jutsuDir -Filter "*.json" | ForEach-Object {
        $jutsuCount++
        try {
            $json = Get-Content $_.FullName -Raw | ConvertFrom-Json
            $id = $json.id
            if ($jutsuIds.ContainsKey($id)) {
                Log "CRIT" "DUPLICATE jutsu ID: '$id' in $($_.Name) and $($jutsuIds[$id])"
            }
            $jutsuIds[$id] = $_.Name
            # Check behaviorClass exists
            if ($json.behaviorClass) {
                $cls = $json.behaviorClass
                $clsPath = $cls.Replace(".", "\") + ".java"
                $fullPath = "$srcJava\$clsPath"
                if (-not (Test-Path $fullPath)) {
                    Log "CRIT" "Jutsu '$id' references missing behaviorClass: $cls"
                }
            }
            # Check required fields
            if (-not $json.baseCost) { Log "WARN" "Jutsu '$id' missing baseCost" }
            if (-not $json.type) { Log "WARN" "Jutsu '$id' missing type" }
        } catch {
            Log "CRIT" "INVALID JSON: $($_.Name)"
        }
    }
    Log "INFO" "Checked $jutsuCount jutsu definitions"
} else {
    Log "CRIT" "Jutsu directory not found: $jutsuDir"
}
[void]$sb.AppendLine("")

# ============ 7. TREE.JSON DUPLICATE NODES ============
[void]$sb.AppendLine("## 7. Skill Tree Node Duplicates")
$treeFile = "$srcRes\data\shinobicore\skill_tree\tree.json"
if (Test-Path $treeFile) {
    try {
        $tree = Get-Content $treeFile -Raw | ConvertFrom-Json
        $nodeIds = @{}
        $nodeCount = 0
        foreach ($n in $tree.nodes) {
            $nodeCount++
            if ($nodeIds.ContainsKey($n.id)) {
                Log "CRIT" "DUPLICATE tree node ID: '$($n.id)' (branch: $($n.branch), dist: $($n.distance))"
            }
            $nodeIds[$n.id] = $true
        }
        Log "INFO" "Checked $nodeCount tree nodes"
    } catch {
        Log "CRIT" "tree.json parse error: $_"
    }
} else {
    Log "CRIT" "tree.json not found"
}
[void]$sb.AppendLine("")

# ============ 8. MISSING RESOURCES ============
[void]$sb.AppendLine("## 8. Missing Resources")
$soundsJson = "$srcRes\assets\shinobicore\sounds.json"
if (Test-Path $soundsJson) {
    try {
        $sounds = Get-Content $soundsJson -Raw | ConvertFrom-Json
        foreach ($prop in $sounds.PSObject.Properties) {
            $sndName = $prop.Name
            $hasOgg = Get-ChildItem "$srcRes\assets\shinobicore\sounds" -Recurse -Filter "*.ogg" -ErrorAction SilentlyContinue |
                      Where-Object { $_.Name -match $sndName }
            if (-not $hasOgg) {
                $refsVanilla = $false
                foreach ($s in $prop.Value.sounds) {
                    if ($s -is [string] -and $s -match '^minecraft:') { $refsVanilla = $true }
                }
                if (-not $refsVanilla) {
                    Log "WARN" "Sound '$sndName' declared but no .ogg file found"
                }
            }
        }
    } catch { Log "WARN" "sounds.json parse error" }
} else {
    Log "WARN" "sounds.json not found"
}
if (-not (Test-Path "$srcRes\assets\shinobicore\icon.png")) {
    Log "WARN" "icon.png not found (referenced in fabric.mod.json)"
}
[void]$sb.AppendLine("")

# ============ 9. GOD CLASS CHECK (file sizes) ============
[void]$sb.AppendLine("## 9. Large Files (God Classes > 300 lines)")
Get-ChildItem $srcJava -Recurse -Filter "*.java" | ForEach-Object {
    $lines = (Get-Content $_.FullName -Encoding UTF8).Count
    if ($lines -gt 300) {
        $rel = $_.FullName.Replace($root + "\", "")
        Log "WARN" "Large file ($lines lines): $rel"
    }
}
[void]$sb.AppendLine("")

# ============ 10. PERFORMANCE ANTI-PATTERNS ============
[void]$sb.AppendLine("## 10. Performance Anti-Patterns")
Get-ChildItem $srcJava -Recurse -Filter "*.java" | ForEach-Object {
    $content = [System.IO.File]::ReadAllText($_.FullName, $utf8)
    $rel = $_.FullName.Replace($root + "\", "")
    if ($content -match 'Thread\.sleep') {
        Log "CRIT" "Thread.sleep() found in $rel"
    }
    if ($content -match 'static\s+.*Map<.*>\s+\w+\s*=\s*new\s+(Concurrent)?HashMap' -and $rel -notmatch 'Registry|Config|Behavior') {
        Log "WARN" "Static Map in $rel — potential memory leak if not cleaned on disconnect"
    }
}
[void]$sb.AppendLine("")

# ============ 11. NON-ESSENTIAL FILES IN ROOT ============
[void]$sb.AppendLine("## 11. Non-Essential Files in Root")
$nonEssentialPatterns = @("*.ps1", "FULL_DUMP.md", "PROJECT_HANDOFF*.md", "PHASE_G25_NOTES.md", "last_doc.md", "code_dump_*.txt")
foreach ($pat in $nonEssentialPatterns) {
    Get-ChildItem $root -Filter $pat -File -ErrorAction SilentlyContinue | ForEach-Object {
        Log "INFO" "Non-essential file: $($_.Name)"
    }
}
[void]$sb.AppendLine("")

# ============ 12. CLIENT CODE IN SERVER CLASSES ============
[void]$sb.AppendLine("## 12. Client Code in Server Classes")
Get-ChildItem "$srcJava\com\example\shinobicore" -Filter "*.java" -Recurse | Where-Object {
    $_.FullName -notmatch '\\client\\' -and $_.FullName -notmatch '\\mixin\\'
} | ForEach-Object {
    $content = [System.IO.File]::ReadAllText($_.FullName, $utf8)
    if ($content -match 'MinecraftClient|ClientPlayerEntity|DrawContext') {
        $rel = $_.FullName.Replace($root + "\", "")
        Log "WARN" "Client-side class referenced in server code: $rel"
    }
}
[void]$sb.AppendLine("")

# ============ SUMMARY ============
[void]$sb.AppendLine("---")
[void]$sb.AppendLine("## Summary")
[void]$sb.AppendLine("| Level | Count |")
[void]$sb.AppendLine("|-------|-------|")
[void]$sb.AppendLine("| CRIT | $critCount |")
[void]$sb.AppendLine("| WARN | $warnCount |")
[void]$sb.AppendLine("| INFO | $infoCount |")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("*Generated by audit_project.ps1*")

# Write report
[System.IO.File]::WriteAllText($report, $sb.ToString(), $utf8)
Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "  AUDIT COMPLETE" -ForegroundColor Green
Write-Host "  Report: $report" -ForegroundColor Green
Write-Host "  CRIT: $critCount | WARN: $warnCount | INFO: $infoCount" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green