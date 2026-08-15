# ============================================================
#  SHINOBICORE — FULL CODE DUMP SCRIPT
#  Собирает весь код проекта в один .txt файл
#  Запуск: powershell -ExecutionPolicy Bypass -File .\create_code_dump.ps1
# ============================================================

$ErrorActionPreference = "Continue"
$utf8 = New-Object System.Text.UTF8Encoding($false)  # UTF-8 без BOM

# Автоматическое определение пути к проекту
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$outFile = Join-Path $root "full_code_dump_$timestamp.txt"

$sb = New-Object System.Text.StringBuilder
$totalFiles = 0
$totalLines = 0

# ============================================================
#  Вспомогательные функции
# ============================================================

function Write-Header($title) {
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("################################################################################")
    [void]$sb.AppendLine("# $title")
    [void]$sb.AppendLine("################################################################################")
    Write-Host "" 
    Write-Host "  >> $title" -ForegroundColor Cyan
}

function Add-FileBlock($relPath, $fullPath) {
    if (-not (Test-Path $fullPath)) { return 0 }
    
    $script:totalFiles++
    [void]$sb.AppendLine("--------------------------------------------------------------------------------")
    [void]$sb.AppendLine("FILE: $relPath")
    [void]$sb.AppendLine("--------------------------------------------------------------------------------")
    
    try {
        $content = [System.IO.File]::ReadAllText($fullPath, $utf8)
        [void]$sb.AppendLine($content)
        $lines = ($content -split "`n").Count
        $script:totalLines += $lines
        Write-Host "    [OK] $relPath ($lines lines)" -ForegroundColor Green
        return $lines
    }
    catch {
        [void]$sb.AppendLine("[ERROR reading file: $($_.Exception.Message)]")
        Write-Host "    [ERR] $relPath - $($_.Exception.Message)" -ForegroundColor Red
        return 0
    }
}

function Add-DirectoryFiles($sectionName, $dirPath, $filter) {
    if (-not (Test-Path $dirPath)) {
        Write-Host "    [SKIP] Directory not found: $dirPath" -ForegroundColor Yellow
        return
    }
    
    Write-Host ""
    Write-Host "  Scanning $sectionName..." -ForegroundColor White
    
    $files = Get-ChildItem -Path $dirPath -Recurse -Filter $filter | Sort-Object FullName
    $count = 0
    $lines = 0
    
    foreach ($f in $files) {
        $rel = $f.FullName.Substring($root.Length + 1)
        $l = Add-FileBlock $rel $f.FullName
        $count++
        $lines += $l
    }
    
    Write-Host "  -> ${sectionName}: $count files, $lines lines" -ForegroundColor DarkCyan
}

# ============================================================
#  Заголовок дампа
# ============================================================

[void]$sb.AppendLine("================================================================================")
[void]$sb.AppendLine("  SHINOBICORE MOD - FULL CODE DUMP")
[void]$sb.AppendLine("  Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
[void]$sb.AppendLine("  Project:   $root")
[void]$sb.AppendLine("================================================================================")

Write-Host ""
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "           SHINOBICORE CODE DUMP" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "  Project: $root" -ForegroundColor White
Write-Host "  Output:  $outFile" -ForegroundColor White

# ============================================================
#  SECTION 1: Build Configuration
# ============================================================

Write-Header "SECTION 1: BUILD CONFIGURATION"

$buildFiles = @(
    "build.gradle",
    "gradle.properties",
    "settings.gradle",
    "src\main\resources\fabric.mod.json",
    "src\main\resources\shinobicore.mixins.json"
)

foreach ($bf in $buildFiles) {
    $full = Join-Path $root $bf
    Add-FileBlock $bf $full
}

# ============================================================
#  SECTION 2: Java Source Code
# ============================================================

Write-Header "SECTION 2: JAVA SOURCE CODE"

$javaDir = Join-Path $root "src\main\java"
Add-DirectoryFiles "Java Sources" $javaDir "*.java"

# ============================================================
#  SECTION 3: Resource Files (JSON)
# ============================================================

Write-Header "SECTION 3: RESOURCE FILES - JSON"

$resDir = Join-Path $root "src\main\resources\data"
Add-DirectoryFiles "JSON Resources" $resDir "*.json"

# ============================================================
#  SECTION 4: Asset Files (textures, sounds, models, lang)
# ============================================================

Write-Header "SECTION 4: ASSET FILES"

$assetsDir = Join-Path $root "src\main\resources\assets"
if (Test-Path $assetsDir) {
    # JSON assets (sounds.json, lang files, models)
    Add-DirectoryFiles "Asset JSONs" $assetsDir "*.json"
    
    # List texture files (не читаем бинарные, просто список)
    $textures = Get-ChildItem -Path $assetsDir -Recurse -Include "*.png" -ErrorAction SilentlyContinue
    if ($textures) {
        [void]$sb.AppendLine("")
        [void]$sb.AppendLine("--------------------------------------------------------------------------------")
        [void]$sb.AppendLine("TEXTURE FILES ($($textures.Count) files)")
        [void]$sb.AppendLine("--------------------------------------------------------------------------------")
        foreach ($t in $textures) {
            $rel = $t.FullName.Substring($root.Length + 1)
            $size = [math]::Round($t.Length / 1KB, 1)
            [void]$sb.AppendLine("  $rel ($size KB)")
        }
        Write-Host "    [OK] Listed $($textures.Count) texture files" -ForegroundColor Green
    }
}

# ============================================================
#  SECTION 5: Documentation
# ============================================================

Write-Header "SECTION 5: DOCUMENTATION"

$mdFiles = Get-ChildItem -Path $root -Filter "*.md" -File -ErrorAction SilentlyContinue | Sort-Object Name
foreach ($mf in $mdFiles) {
    Add-FileBlock $mf.Name $mf.FullName
}

# ============================================================
#  SECTION 6: PowerShell Scripts
# ============================================================

Write-Header "SECTION 6: POWERSHELL SCRIPTS"

$psFiles = Get-ChildItem -Path $root -Filter "*.ps1" -File -ErrorAction SilentlyContinue | Sort-Object Name
foreach ($pf in $psFiles) {
    # Пропускаем сам этот скрипт
    if ($pf.FullName -eq $MyInvocation.MyCommand.Path) { continue }
    Add-FileBlock $pf.Name $pf.FullName
}

# ============================================================
#  STATISTICS
# ============================================================

[void]$sb.AppendLine("")
[void]$sb.AppendLine("################################################################################")
[void]$sb.AppendLine("# STATISTICS")
[void]$sb.AppendLine("################################################################################")
[void]$sb.AppendLine("Total files dumped: $totalFiles")
[void]$sb.AppendLine("Total lines:        $totalLines")
[void]$sb.AppendLine("Dump file size:     $([math]::Round((([System.Text.Encoding]::UTF8.GetBytes($sb.ToString())).Length) / 1MB, 2)) MB")
[void]$sb.AppendLine("Generated at:       $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")

# ============================================================
#  Запись в файл
# ============================================================

Write-Host ""
Write-Host "  Writing dump file..." -ForegroundColor White

try {
    [System.IO.File]::WriteAllText($outFile, $sb.ToString(), $utf8)
    
    $fileSize = [math]::Round((Get-Item $outFile).Length / 1MB, 2)
    
    Write-Host ""
    Write-Host "==================================================================" -ForegroundColor Green
    Write-Host "           CODE DUMP CREATED SUCCESSFULLY!" -ForegroundColor Green
    Write-Host "==================================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "  File:  $outFile" -ForegroundColor Cyan
    Write-Host "  Size:  $fileSize MB" -ForegroundColor Cyan
    Write-Host "  Files: $totalFiles" -ForegroundColor Cyan
    Write-Host "  Lines: $totalLines" -ForegroundColor Cyan
    Write-Host ""
}
catch {
    Write-Host ""
    Write-Host "  [ERROR] Failed to write dump file: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}