# ============================================================
# DUMP CORE FOR TEAMS
# Собирает весь код ядра в один файл для отправки командам
# ============================================================

$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$root = "E:\Games\mod"
$srcBase = Join-Path $root "src\main\java\com\example\shinobicore"
$resBase = Join-Path $root "src\main\resources"
$outDir = Join-Path $root "team_packages"
$dumpFile = Join-Path $outDir "CORE_CODE_DUMP.md"

if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }

$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine("# SHINOBICORE 4.0.0 - CORE CODE DUMP")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("Generated: " + (Get-Date -Format "yyyy-MM-dd HH:mm:ss"))
[void]$sb.AppendLine("This file contains the complete source code of the ShinobiCore kernel.")
[void]$sb.AppendLine("Teams must use this code as the foundation. Do NOT modify core files.")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("---")
[void]$sb.AppendLine("")

$filesDumped = 0
$linesDumped = 0

function Add-FileToDump([string]$relPath) {
    $full = Join-Path $root $relPath
    if (-not (Test-Path $full)) {
        Write-Host " [SKIP] $relPath" -ForegroundColor Yellow
        return
    }
    $content = [System.IO.File]::ReadAllText($full, [System.Text.Encoding]::UTF8)
    $content = $content.Replace("`r`n", "`n")
    $lineCount = ($content -split "`n").Count
    $script:filesDumped++
    $script:linesDumped += $lineCount

    [void]$sb.AppendLine("## FILE: $relPath")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("```java")
    [void]$sb.AppendLine($content)
    [void]$sb.AppendLine("```")
    [void]$sb.AppendLine("")
    Write-Host " [OK] $relPath ($lineCount lines)" -ForegroundColor Green
}

function Add-ResourceToDump([string]$relPath) {
    $full = Join-Path $root $relPath
    if (-not (Test-Path $full)) {
        Write-Host " [SKIP] $relPath" -ForegroundColor Yellow
        return
    }
    $content = [System.IO.File]::ReadAllText($full, [System.Text.Encoding]::UTF8)
    $content = $content.Replace("`r`n", "`n")
    $lineCount = ($content -split "`n").Count
    $script:filesDumped++
    $script:linesDumped += $lineCount

    $ext = [System.IO.Path]::GetExtension($relPath).ToLower()
    $lang = switch ($ext) {
        ".json" { "json" }
        ".java" { "java" }
        default { "text" }
    }

    [void]$sb.AppendLine("## FILE: $relPath")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("```$lang")
    [void]$sb.AppendLine($content)
    [void]$sb.AppendLine("```")
    [void]$sb.AppendLine("")
    Write-Host " [OK] $relPath ($lineCount lines)" -ForegroundColor Green
}

Write-Host ""
Write-Host "=== DUMPING CORE CODE ===" -ForegroundColor Cyan
Write-Host ""

# Main entry points
Add-FileToDump "src\main\java\com\example\shinobicore\ShinobiCoreMod.java"
Add-FileToDump "src\main\java\com\example\shinobicore\ShinobiCoreClient.java"

# core/api
Add-FileToDump "src\main\java\com\example\shinobicore\core\api\ShinobiModule.java"
Add-FileToDump "src\main\java\com\example\shinobicore\core\api\ClientAwareModule.java"
Add-FileToDump "src\main\java\com\example\shinobicore\core\api\ModuleContext.java"

# core/module
Add-FileToDump "src\main\java\com\example\shinobicore\core\module\ModuleState.java"
Add-FileToDump "src\main\java\com\example\shinobicore\core\module\ModuleEntry.java"
Add-FileToDump "src\main\java\com\example\shinobicore\core\module\ModuleManager.java"

# core/event
Add-FileToDump "src\main\java\com\example\shinobicore\core\event\CoreEvents.java"

# core/view
Add-FileToDump "src\main\java\com\example\shinobicore\core\view\CoreViews.java"

# core/service
Add-FileToDump "src\main\java\com\example\shinobicore\core\service\CoreServices.java"

# core/log
Add-FileToDump "src\main\java\com\example\shinobicore\core\log\ShinobiLogger.java"

# core/config
Add-FileToDump "src\main\java\com\example\shinobicore\core\config\ModuleConfigLoader.java"

# core/command
Add-FileToDump "src\main\java\com\example\shinobicore\core\command\CoreCommands.java"

# core/compat
Add-FileToDump "src\main\java\com\example\shinobicore\core\compat\CompatibilityChecker.java"

# Example module
Add-FileToDump "src\main\java\com\example\shinobicore\modules\example\ExampleModule.java"

Write-Host ""
Write-Host "=== DUMPING RESOURCES ===" -ForegroundColor Cyan
Write-Host ""

# Resources
Add-ResourceToDump "src\main\resources\fabric.mod.json"
Add-ResourceToDump "src\main\resources\shinobicore.mixins.json"
Add-ResourceToDump "gradle.properties"

# Final statistics
[void]$sb.AppendLine("---")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("## DUMP STATISTICS")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("Total files: $filesDumped")
[void]$sb.AppendLine("Total lines: $linesDumped")
[void]$sb.AppendLine("Generated at: " + (Get-Date -Format "yyyy-MM-dd HH:mm:ss"))

[System.IO.File]::WriteAllText($dumpFile, $sb.ToString(), $utf8)

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host " CORE DUMP COMPLETE" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host " Output: $dumpFile" -ForegroundColor White
Write-Host " Files:  $filesDumped" -ForegroundColor White
Write-Host " Lines:  $linesDumped" -ForegroundColor White
Write-Host ""
Write-Host "Now create these 3 additional files in team_packages/:" -ForegroundColor Yellow
Write-Host "  1. CORE_DOCUMENTATION.md" -ForegroundColor Yellow
Write-Host "  2. CORE_SERVICES_API.md" -ForegroundColor Yellow
Write-Host "  3. TZ_<MODULE>.md (one per team)" -ForegroundColor Yellow
Write-Host ""