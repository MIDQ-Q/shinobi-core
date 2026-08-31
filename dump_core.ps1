$ErrorActionPreference = 'Stop'
$utf8 = New-Object System.Text.UTF8Encoding($false)
$root = 'E:\Games\mod'
$outDir = Join-Path $root 'team_packages'
$dumpFile = Join-Path $outDir 'CORE_CODE_DUMP.md'

if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }

$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine('# SHINOBICORE 4.0.0 - CORE CODE DUMP')
[void]$sb.AppendLine('')
[void]$sb.AppendLine('Generated: ' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))
[void]$sb.AppendLine('This file contains the complete source code of the ShinobiCore kernel.')
[void]$sb.AppendLine('Teams must use this code as the foundation. Do NOT modify core files.')
[void]$sb.AppendLine('')
[void]$sb.AppendLine('---')
[void]$sb.AppendLine('')

$filesDumped = 0
$linesDumped = 0

function Add-File {
    param([string]$relPath, [string]$lang = 'java')
    $full = Join-Path $root $relPath
    if (-not (Test-Path $full)) {
        Write-Host (' [SKIP] ' + $relPath) -ForegroundColor Yellow
        return
    }
    $content = [System.IO.File]::ReadAllText($full, [System.Text.Encoding]::UTF8)
    $lineCount = ($content -split [char]10).Count
    $script:filesDumped++
    $script:linesDumped += $lineCount

    [void]$sb.AppendLine('## FILE: ' + $relPath)
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('```' + $lang)
    [void]$sb.AppendLine($content)
    [void]$sb.AppendLine('```')
    [void]$sb.AppendLine('')
    Write-Host (' [OK] ' + $relPath + ' - ' + $lineCount + ' lines') -ForegroundColor Green
}

Write-Host ''
Write-Host '=== DUMPING CORE CODE ===' -ForegroundColor Cyan
Write-Host ''

Add-File 'src\main\java\com\example\shinobicore\ShinobiCoreMod.java'
Add-File 'src\main\java\com\example\shinobicore\ShinobiCoreClient.java'
Add-File 'src\main\java\com\example\shinobicore\core\api\ShinobiModule.java'
Add-File 'src\main\java\com\example\shinobicore\core\api\ClientAwareModule.java'
Add-File 'src\main\java\com\example\shinobicore\core\api\ModuleContext.java'
Add-File 'src\main\java\com\example\shinobicore\core\module\ModuleState.java'
Add-File 'src\main\java\com\example\shinobicore\core\module\ModuleEntry.java'
Add-File 'src\main\java\com\example\shinobicore\core\module\ModuleManager.java'
Add-File 'src\main\java\com\example\shinobicore\core\event\CoreEvents.java'
Add-File 'src\main\java\com\example\shinobicore\core\view\CoreViews.java'
Add-File 'src\main\java\com\example\shinobicore\core\service\CoreServices.java'
Add-File 'src\main\java\com\example\shinobicore\core\log\ShinobiLogger.java'
Add-File 'src\main\java\com\example\shinobicore\core\config\ModuleConfigLoader.java'
Add-File 'src\main\java\com\example\shinobicore\core\command\CoreCommands.java'
Add-File 'src\main\java\com\example\shinobicore\core\compat\CompatibilityChecker.java'
Add-File 'src\main\java\com\example\shinobicore\modules\example\ExampleModule.java'

Write-Host ''
Write-Host '=== DUMPING RESOURCES ===' -ForegroundColor Cyan
Write-Host ''

Add-File 'src\main\resources\fabric.mod.json' 'json'
Add-File 'src\main\resources\shinobicore.mixins.json' 'json'
Add-File 'gradle.properties' 'text'

[void]$sb.AppendLine('---')
[void]$sb.AppendLine('')
[void]$sb.AppendLine('## DUMP STATISTICS')
[void]$sb.AppendLine('Total files: ' + $filesDumped)
[void]$sb.AppendLine('Total lines: ' + $linesDumped)

[System.IO.File]::WriteAllText($dumpFile, $sb.ToString(), $utf8)

Write-Host ''
Write-Host '============================================================' -ForegroundColor Green
Write-Host ' CORE DUMP COMPLETE' -ForegroundColor Green
Write-Host '============================================================' -ForegroundColor Green
Write-Host ''
Write-Host (' Output: ' + $dumpFile) -ForegroundColor White
Write-Host (' Files:  ' + $filesDumped) -ForegroundColor White
Write-Host (' Lines:  ' + $linesDumped) -ForegroundColor White