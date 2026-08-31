$ErrorActionPreference = 'Stop'
$utf8 = New-Object System.Text.UTF8Encoding $false
$root = 'E:\Games\mod'
$srcBase = Join-Path $root 'src\main\java'

Write-Host ''
Write-Host '============================================================' -ForegroundColor Cyan
Write-Host ' SCAN AND FIX: import before package (ALL FILES)' -ForegroundColor Cyan
Write-Host '============================================================' -ForegroundColor Cyan
Write-Host ''

$allJavaFiles = Get-ChildItem -Path $srcBase -Filter '*.java' -Recurse
$fixedCount = 0
$checkedCount = 0

foreach ($file in $allJavaFiles) {
    $checkedCount++
    $content = [System.IO.File]::ReadAllText($file.FullName, [System.Text.Encoding]::UTF8)
    $lines = $content.Split("`n")

    if ($lines.Count -lt 2) { continue }

    # Find the package line index
    $packageIndex = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i].Trim().StartsWith('package ')) {
            $packageIndex = $i
            break
        }
    }

    # No package found - skip (might be package-info or something else)
    if ($packageIndex -lt 0) { continue }

    # Check if there are any import lines BEFORE the package line
    $importsBeforePackage = New-Object System.Collections.Generic.List[string]
    $hasProblem = $false

    for ($i = 0; $i -lt $packageIndex; $i++) {
        $trimmed = $lines[$i].Trim()
        if ($trimmed.StartsWith('import ')) {
            $importsBeforePackage.Add($lines[$i])
            $hasProblem = $true
        }
    }

    if (-not $hasProblem) { continue }

    # Fix: rebuild the file
    # Structure: package line, blank line, moved imports, then rest
    $newLines = New-Object System.Collections.Generic.List[string]

    # Add package line first
    $newLines.Add($lines[$packageIndex])
    $newLines.Add('')

    # Add the imports that were before package
    foreach ($imp in $importsBeforePackage) {
        $newLines.Add($imp)
    }

    # Add all remaining lines (skip the package line and the misplaced imports)
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($i -eq $packageIndex) { continue }
        $trimmed = $lines[$i].Trim()
        if ($i -lt $packageIndex -and $trimmed.StartsWith('import ')) { continue }
        $newLines.Add($lines[$i])
    }

    $newContent = $newLines -join "`n"
    [System.IO.File]::WriteAllText($file.FullName, $newContent, $utf8)
    $fixedCount++
    Write-Host (" [FIXED] " + $file.FullName.Replace($root + '\', '') + " (" + $importsBeforePackage.Count + " imports moved)") -ForegroundColor Green
}

Write-Host ''
Write-Host ("Scanned: " + $checkedCount + " files") -ForegroundColor White
Write-Host ("Fixed:   " + $fixedCount + " files") -ForegroundColor White
Write-Host ''

# BUILD
Write-Host '============================================================' -ForegroundColor Cyan
Write-Host ' RUNNING BUILD' -ForegroundColor Cyan
Write-Host '============================================================' -ForegroundColor Cyan
Write-Host ''

Push-Location $root
try {
    $prevEAP = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $out = & '.\gradlew.bat' build 2>&1
    $exitCode = $LASTEXITCODE
    $ErrorActionPreference = $prevEAP

    Write-Host ''
    if ($exitCode -eq 0) {
        Write-Host '============================================================' -ForegroundColor Green
        Write-Host ' [PASS] BUILD SUCCESSFUL!' -ForegroundColor Green
        Write-Host '============================================================' -ForegroundColor Green
    } else {
        Write-Host '============================================================' -ForegroundColor Red
        Write-Host ' [FAIL] BUILD FAILED' -ForegroundColor Red
        Write-Host '============================================================' -ForegroundColor Red
        Write-Host ''
        Write-Host 'Remaining errors:' -ForegroundColor Yellow
        $out | Where-Object { $_ -match 'error:' } | Select-Object -First 40 | ForEach-Object {
            Write-Host " $_" -ForegroundColor Red
        }
    }
} finally {
    Pop-Location
}