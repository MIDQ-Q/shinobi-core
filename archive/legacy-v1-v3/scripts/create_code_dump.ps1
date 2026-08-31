$ErrorActionPreference = "Continue"
$root = "E:\Games\mod"
$outFile = "$root\code_dump_15_08_2026.txt"
$utf8 = New-Object System.Text.UTF8Encoding($false)

# Счётчики
$javaCount = 0; $jsonCount = 0; $psCount = 0
$javaLines = 0; $jsonLines = 0; $psLines = 0
$mdCount = 0; $mdLines = 0

# Вспомогательная функция записи секции
function Write-Header($sb, $text) {
    [void]$sb.AppendLine("################################################################################")
    [void]$sb.AppendLine("# $text")
    [void]$sb.AppendLine("################################################################################")
}

function Write-FileBlock($sb, $relPath, $content) {
    [void]$sb.AppendLine("--------------------------------------------------------------------------------")
    [void]$sb.AppendLine("FILE: $relPath")
    [void]$sb.AppendLine("--------------------------------------------------------------------------------")
    [void]$sb.AppendLine($content)
}

$sb = New-Object System.Text.StringBuilder
$now = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

[void]$sb.AppendLine("================================================================================")
[void]$sb.AppendLine("SHINOBICORE MOD - FULL CODE DUMP")
[void]$sb.AppendLine("Generated: $now")
[void]$sb.AppendLine("Project: $root")
[void]$sb.AppendLine("================================================================================")

# ============ SECTION 1: BUILD CONFIGURATION ============
Write-Header $sb "SECTION 1: BUILD CONFIGURATION"

$buildFiles = @("build.gradle", "gradle.properties", "settings.gradle",
                "src\main\resources\fabric.mod.json",
                "src\main\resources\shinobicore.mixins.json")
foreach ($bf in $buildFiles) {
    $full = Join-Path $root $bf
    if (Test-Path $full) {
        $content = [System.IO.File]::ReadAllText($full, $utf8)
        Write-FileBlock $sb $bf $content
    }
}

# ============ SECTION 2: JAVA SOURCE CODE ============
Write-Header $sb "SECTION 2: JAVA SOURCE CODE"

$javaFiles = Get-ChildItem -Path "$root\src\main\java" -Recurse -Filter "*.java" |
    Sort-Object { $_.FullName }
foreach ($jf in $javaFiles) {
    $rel = $jf.FullName.Substring($root.Length + 1)
    $content = [System.IO.File]::ReadAllText($jf.FullName, $utf8)
    Write-FileBlock $sb $rel $content
    $javaCount++
    $javaLines += ($content -split "`n").Count
}

# ============ SECTION 3: RESOURCE FILES - JSON ============
Write-Header $sb "SECTION 3: RESOURCE FILES - JSON"

$jsonFiles = Get-ChildItem -Path "$root\src\main\resources\data" -Recurse -Filter "*.json" |
    Sort-Object { $_.FullName }
foreach ($jf in $jsonFiles) {
    $rel = $jf.FullName.Substring($root.Length + 1)
    $content = [System.IO.File]::ReadAllText($jf.FullName, $utf8)
    Write-FileBlock $sb $rel $content
    $jsonCount++
    $jsonLines += ($content -split "`n").Count
}

# ============ SECTION 4: DOCUMENTATION ============
Write-Header $sb "SECTION 4: DOCUMENTATION"

$mdFiles = Get-ChildItem -Path $root -Filter "*.md" -File | Sort-Object Name
foreach ($mf in $mdFiles) {
    $content = [System.IO.File]::ReadAllText($mf.FullName, $utf8)
    Write-FileBlock $sb $mf.Name $content
    $mdCount++
    $mdLines += ($content -split "`n").Count
}

# ============ SECTION 5: POWERSHELL SCRIPTS ============
Write-Header $sb "SECTION 5: POWERSHELL SCRIPTS"

$psFiles = Get-ChildItem -Path $root -Filter "*.ps1" -File | Sort-Object Name
foreach ($pf in $psFiles) {
    $content = [System.IO.File]::ReadAllText($pf.FullName, $utf8)
    Write-FileBlock $sb $pf.Name $content
    $psCount++
    $psLines += ($content -split "`n").Count
}

# ============ STATISTICS ============
$totalLines = $javaLines + $jsonLines + $psLines + $mdLines
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

# Запись файла
[System.IO.File]::WriteAllText($outFile, $sb.ToString(), $utf8)

$fileSize = [math]::Round((Get-Item $outFile).Length / 1MB, 2)

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║              CODE DUMP CREATED SUCCESSFULLY              ║" -ForegroundColor Green
Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Green
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