$ErrorActionPreference = "Continue"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$root = "E:\Games\mod"
$outFile = "$root\full_code_dump_15_08_2026.txt"

$sb = New-Object System.Text.StringBuilder

[void]$sb.AppendLine("================================================================================")
[void]$sb.AppendLine("SHINOBICORE MOD - FULL CODE DUMP")
[void]$sb.AppendLine("Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
[void]$sb.AppendLine("Project: $root")
[void]$sb.AppendLine("================================================================================")

$javaCount = 0; $jsonCount = 0; $psCount = 0; $mdCount = 0
$javaLines = 0; $jsonLines = 0; $psLines = 0; $mdLines = 0

function Add-FileBlock($relPath, $fullPath) {
    if (-not (Test-Path $fullPath)) { return }
    [void]$sb.AppendLine("--------------------------------------------------------------------------------")
    [void]$sb.AppendLine("FILE: $relPath")
    [void]$sb.AppendLine("--------------------------------------------------------------------------------")
    try {
        $content = [System.IO.File]::ReadAllText($fullPath, $utf8)
        [void]$sb.AppendLine($content)
        return ($content -split "`n").Count
    } catch {
        [void]$sb.AppendLine("[ERROR reading file]")
        return 0
    }
}

# --- SECTION 1: BUILD CONFIG ---
[void]$sb.AppendLine("")
[void]$sb.AppendLine("################################################################################")
[void]$sb.AppendLine("# SECTION 1: BUILD CONFIGURATION")
[void]$sb.AppendLine("################################################################################")

$buildFiles = @(
    "build.gradle",
    "gradle.properties",
    "settings.gradle",
    "src\main\resources\fabric.mod.json",
    "src\main\resources\shinobicore.mixins.json"
)
foreach ($bf in $buildFiles) {
    $full = Join-Path $root $bf
    $lines = Add-FileBlock $bf $full
}

# --- SECTION 2: JAVA SOURCE ---
[void]$sb.AppendLine("")
[void]$sb.AppendLine("################################################################################")
[void]$sb.AppendLine("# SECTION 2: JAVA SOURCE CODE")
[void]$sb.AppendLine("################################################################################")

$javaDir = "$root\src\main\java"
if (Test-Path $javaDir) {
    $javaFiles = Get-ChildItem -Path $javaDir -Recurse -Filter "*.java" | Sort-Object FullName
    foreach ($jf in $javaFiles) {
        $rel = $jf.FullName.Substring($root.Length + 1)
        $lines = Add-FileBlock $rel $jf.FullName
        $javaCount++
        $javaLines += $lines
    }
}

# --- SECTION 3: JSON RESOURCES ---
[void]$sb.AppendLine("")
[void]$sb.AppendLine("################################################################################")
[void]$sb.AppendLine("# SECTION 3: RESOURCE FILES - JSON")
[void]$sb.AppendLine("################################################################################")

$resDir = "$root\src\main\resources\data"
if (Test-Path $resDir) {
    $jsonFiles = Get-ChildItem -Path $resDir -Recurse -Filter "*.json" | Sort-Object FullName
    foreach ($jf in $jsonFiles) {
        $rel = $jf.FullName.Substring($root.Length + 1)
        $lines = Add-FileBlock $rel $jf.FullName
        $jsonCount++
        $jsonLines += $lines
    }
}

# --- SECTION 4: DOCUMENTATION ---
[void]$sb.AppendLine("")
[void]$sb.AppendLine("################################################################################")
[void]$sb.AppendLine("# SECTION 4: DOCUMENTATION")
[void]$sb.AppendLine("################################################################################")

$mdFiles = Get-ChildItem -Path $root -Filter "*.md" -File -ErrorAction SilentlyContinue | Sort-Object Name
foreach ($mf in $mdFiles) {
    $lines = Add-FileBlock $mf.Name $mf.FullName
    $mdCount++
    $mdLines += $lines
}

# --- SECTION 5: POWERSHELL SCRIPTS ---
[void]$sb.AppendLine("")
[void]$sb.AppendLine("################################################################################")
[void]$sb.AppendLine("# SECTION 5: POWERSHELL SCRIPTS")
[void]$sb.AppendLine("################################################################################")

$psFiles = Get-ChildItem -Path $root -Filter "*.ps1" -File -ErrorAction SilentlyContinue | Sort-Object Name
foreach ($pf in $psFiles) {
    $lines = Add-FileBlock $pf.Name $pf.FullName
    $psCount++
    $psLines += $lines
}

# --- STATISTICS ---
$totalLines = $javaLines + $jsonLines + $psLines + $mdLines
[void]$sb.AppendLine("")
[void]$sb.AppendLine("################################################################################")
[void]$sb.AppendLine("# STATISTICS")
[void]$sb.AppendLine("################################################################################")
[void]$sb.AppendLine("Java files: $javaCount")
[void]$sb.AppendLine("JSON files: $jsonCount")
[void]$sb.AppendLine("PowerShell scripts: $psCount")
[void]$sb.AppendLine("Markdown files: $mdCount")
[void]$sb.AppendLine("Total Java lines: $javaLines")
[void]$sb.AppendLine("Total JSON lines: $jsonLines")
[void]$sb.AppendLine("Total lines in dump: $totalLines")

# --- WRITE OUTPUT ---
[System.IO.File]::WriteAllText($outFile, $sb.ToString(), $utf8)
$fileSize = [math]::Round((Get-Item $outFile).Length / 1MB, 2)

Write-Host ""
Write-Host "==================================================================" -ForegroundColor Green
Write-Host "           CODE DUMP CREATED SUCCESSFULLY" -ForegroundColor Green
Write-Host "==================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  File: $outFile" -ForegroundColor Cyan
Write-Host "  Size: $fileSize MB" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Statistics:" -ForegroundColor White
Write-Host "    Java files:        $javaCount ($javaLines lines)"
Write-Host "    JSON files:        $jsonCount ($jsonLines lines)"
Write-Host "    PowerShell:        $psCount ($psLines lines)"
Write-Host "    Markdown:          $mdCount ($mdLines lines)"
Write-Host "    Total:             $totalLines lines"