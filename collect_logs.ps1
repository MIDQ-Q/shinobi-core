# collect_logs.ps1 — собирает всю диагностику в один файл
$ErrorActionPreference = "Continue"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$root = "E:\Games\mod"
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$diagFile = "$root\DIAG_$timestamp.txt"
$logDir = "$root\run\logs"
$crashDir = "$root\run\crash-reports"

function Log($msg) {
    $line = "[$(Get-Date -Format 'HH:mm:ss')] $msg"
    Write-Host $line
    Add-Content -Path $diagFile -Value $line -Encoding UTF8
}

function Section($title) {
    $sep = "=" * 70
    Add-Content -Path $diagFile -Value "`n$sep`n  $title`n$sep" -Encoding UTF8
    Write-Host "`n$sep" -ForegroundColor Cyan
    Write-Host "  $title" -ForegroundColor Cyan
    Write-Host "$sep" -ForegroundColor Cyan
}

# ============ HEADER ============
Log "╔══════════════════════════════════════════════════════════╗"
Log "║   SHINOBICORE DIAGNOSTIC LOG COLLECTOR                   ║"
Log "║   Started: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')                    ║"
Log "╚══════════════════════════════════════════════════════════╝"
Log "Output file: $diagFile"

# ============ 1. SYSTEM INFO ============
Section "1. SYSTEM INFO"
Log "OS: $([System.Environment]::OSVersion.VersionString)"
Log "Java: $(& java -version 2>&1 | Select-Object -First 1)"
Log "Project dir: $root"
Log "Files count (java): $((Get-ChildItem -Path "$root\src\main\java" -Recurse -Filter *.java).Count)"
Log "Files count (json): $((Get-ChildItem -Path "$root\src\main\resources" -Recurse -Filter *.json).Count)"

# ============ 2. GRADLE PROPERTIES ============
Section "2. BUILD CONFIG"
$gradleProps = "$root\gradle.properties"
if (Test-Path $gradleProps) {
    Get-Content $gradleProps | ForEach-Object { Log "  $_" }
} else {
    Log "[MISSING] gradle.properties"
}

# ============ 3. FABRIC.MOD.JSON ============
Section "3. FABRIC.MOD.JSON"
$fabricJson = "$root\src\main\resources\fabric.mod.json"
if (Test-Path $fabricJson) {
    Get-Content $fabricJson | ForEach-Object { Log "  $_" }
} else {
    Log "[MISSING] fabric.mod.json"
}

# ============ 4. MIXINS.JSON ============
Section "4. MIXINS CONFIG"
$mixinsJson = "$root\src\main\resources\shinobicore.mixins.json"
if (Test-Path $mixinsJson) {
    Get-Content $mixinsJson | ForEach-Object { Log "  $_" }
}

# ============ 5. GRADLE BUILD (compile check) ============
Section "5. GRADLE BUILD"
Log "Running: .\gradlew.bat build --info"
$buildOutput = & "$root\gradlew.bat" build --stacktrace 2>&1
$buildExit = $LASTEXITCODE
$buildText = $buildOutput -join "`n"

# Сохраняем полный build log
$buildLog = "$root\build_log_$timestamp.txt"
$buildText | Out-File -FilePath $buildLog -Encoding UTF8
Log "Full build log saved: $buildLog"
Log "Build exit code: $buildExit"

# Ищем ошибки
$errors = @()
$warnings = @()
foreach ($line in ($buildText -split "`n")) {
    if ($line -match '(?i)error[:\s]|FAILED|Exception|cannot find symbol|does not exist') {
        $errors += $line.Trim()
    }
    if ($line -match '(?i)warning:') {
        $warnings += $line.Trim()
    }
}

Log "Errors found: $($errors.Count)"
Log "Warnings found: $($warnings.Count)"

if ($errors.Count -gt 0) {
    Log "`n--- FIRST 30 ERRORS ---"
    $errors | Select-Object -First 30 | ForEach-Object { Log "  $_" }
}

if ($buildExit -ne 0) {
    Log "[FAIL] Build failed! See $buildLog for details."
    Log "Skipping runClient because build failed."
} else {
    Log "[OK] Build successful"
    
    # ============ 6. RUN CLIENT (with timeout) ============
    Section "6. RUN CLIENT (30 sec timeout)"
    Log "Starting client... will auto-kill after 30 seconds"
    
    # Удаляем старый latest.log чтобы не путаться
    $latestLog = "$logDir\latest.log"
    if (Test-Path $latestLog) {
        Remove-Item $latestLog -Force
        Log "Removed old latest.log"
    }
    
    # Запускаем в фоне
    $clientJob = Start-Process -FilePath "$root\gradlew.bat" `
        -ArgumentList "runClient" `
        -WorkingDirectory $root `
        -PassThru `
        -WindowStyle Hidden `
        -RedirectStandardOutput "$root\client_stdout_$timestamp.txt" `
        -RedirectStandardError "$root\client_stderr_$timestamp.txt"
    
    Log "Client PID: $($clientJob.Id)"
    Log "Waiting up to 45 seconds..."
    
    # Ждём с проверкой лога
    $waited = 0
    $maxWait = 45
    $crashDetected = $false
    
    while ($waited -lt $maxWait -and -not $clientJob.HasExited) {
        Start-Sleep -Seconds 3
        $waited += 3
        Log "  ...waited ${waited}s"
        
        # Проверяем не появился ли crash-report
        if (Test-Path $crashDir) {
            $crashes = Get-ChildItem $crashDir -Filter "crash-*.txt" -ErrorAction SilentlyContinue
            if ($crashes.Count -gt 0 -and -not $crashDetected) {
                $crashDetected = $true
                Log "[CRASH DETECTED] $($crashes[-1].Name)"
            }
        }
        
        # Проверяем latest.log на фатальные ошибки
        if (Test-Path $latestLog) {
            $content = Get-Content $latestLog -ErrorAction SilentlyContinue -Raw
            if ($content -match 'FATAL|Shutting down|Exception in thread|crashed') {
                Log "[FATAL ERROR in log]"
                break
            }
            if ($content -match 'Loaded.*mixin|Started!|Sound engine started') {
                Log "[OK] Client seems to have started"
            }
        }
    }
    
    # Убиваем если ещё жив
    if (-not $clientJob.HasExited) {
        Log "Killing client process (timeout reached)"
        Stop-Process -Id $clientJob.Id -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
    }
    
    Log "Client exit code: $($clientJob.ExitCode)"
    
    # ============ 7. ANALYZE LATEST.LOG ============
    Section "7. LATEST.LOG ANALYSIS"
    if (Test-Path $latestLog) {
        $logContent = Get-Content $latestLog
        Log "Log size: $($logContent.Count) lines"
        
        # Копируем в диагностику
        Copy-Item $latestLog "$root\latest_log_$timestamp.txt"
        Log "Saved: latest_log_$timestamp.txt"
        
        # Ищем важные строки
        $fatals = @()
        $errors = @()
        $mixins = @()
        $shinobicore = @()
        
        foreach ($line in $logContent) {
            if ($line -match '\[FATAL\]|FATAL') { $fatals += $line }
            elseif ($line -match '\[ERROR\]|ERROR') { $errors += $line }
            elseif ($line -match 'shinobicore|ShinobiCore') { $shinobicore += $line }
            elseif ($line -match 'Mixin apply|mixin.*FAIL|mixin.*error') { $mixins += $line }
        }
        
        Log "FATAL messages: $($fatals.Count)"
        if ($fatals.Count -gt 0) {
            $fatals | Select-Object -First 20 | ForEach-Object { Log "  $_" }
        }
        
        Log "ERROR messages: $($errors.Count)"
        if ($errors.Count -gt 0) {
            $errors | Select-Object -First 20 | ForEach-Object { Log "  $_" }
        }
        
        Log "Mixin issues: $($mixins.Count)"
        if ($mixins.Count -gt 0) {
            $mixins | Select-Object -First 20 | ForEach-Object { Log "  $_" }
        }
        
        Log "ShinobiCore messages: $($shinobicore.Count)"
        if ($shinobicore.Count -gt 0) {
            $shinobicore | Select-Object -First 30 | ForEach-Object { Log "  $_" }
        }
    } else {
        Log "[MISSING] latest.log not found — client may not have started"
    }
    
    # ============ 8. CRASH REPORTS ============
    Section "8. CRASH REPORTS"
    if (Test-Path $crashDir) {
        $crashes = Get-ChildItem $crashDir -Filter "crash-*.txt" | Sort-Object LastWriteTime -Descending
        if ($crashes.Count -eq 0) {
            Log "No crash reports found"
        } else {
            Log "Found $($crashes.Count) crash report(s)"
            $latest = $crashes[0]
            Log "Latest: $($latest.Name) ($($latest.LastWriteTime))"
            Copy-Item $latest.FullName "$root\latest_crash_$timestamp.txt"
            Log "Saved: latest_crash_$timestamp.txt"
            
            Log "`n--- CRASH SUMMARY (first 60 lines) ---"
            Get-Content $latest.FullName | Select-Object -First 60 | ForEach-Object { Log "  $_" }
        }
    } else {
        Log "No crash-reports directory"
    }
    
    # ============ 9. CLIENT STDERR ============
    Section "9. CLIENT STDERR (last 40 lines)"
    $stderrFile = "$root\client_stderr_$timestamp.txt"
    if (Test-Path $stderrFile -and (Get-Item $stderrFile).Length -gt 0) {
        Get-Content $stderrFile | Select-Object -Last 40 | ForEach-Object { Log "  $_" }
    } else {
        Log "(empty)"
    }
}

# ============ 10. KNOWN ISSUES CHECK ============
Section "10. KNOWN ISSUES CHECKLIST"
$checks = @(
    @{file="src\main\java\com\example\shinobicore\ShinobiCore.java"; pattern="onInitialize"; desc="ShinobiCore entry"},
    @{file="src\main\java\com\example\shinobicore\client\ShinobiCoreClient.java"; pattern="onInitializeClient"; desc="Client entry"},
    @{file="src\main\resources\shinobicore.mixins.json"; pattern="MobEntityAccessor"; desc="MobEntityAccessor mixin registered"},
    @{file="src\main\resources\shinobicore.mixins.json"; pattern="CameraMixin"; desc="CameraMixin registered"},
    @{file="src\main\resources\shinobicore.mixins.json"; pattern="JAVA_17|JAVA_21"; desc="Mixin compat level"},
    @{file="src\main\java\com\example\shinobicore\util\TickScheduler.java"; pattern="class TickScheduler"; desc="TickScheduler exists"}
)
foreach ($c in $checks) {
    $p = "$root\$($c.file)"
    if (Test-Path $p) {
        $content = [System.IO.File]::ReadAllText($p, $utf8)
        if ($content -match $c.pattern) {
            Log "[OK] $($c.desc)"
        } else {
            Log "[!!] $($c.desc) — pattern NOT found"
        }
    } else {
        Log "[MISSING] $($c.desc) — file: $($c.file)"
    }
}

# ============ 11. DUPLICATE IMPORTS CHECK ============
Section "11. DUPLICATE IMPORTS CHECK"
$dupes = 0
Get-ChildItem "$root\src\main\java" -Recurse -Filter *.java | ForEach-Object {
    $content = Get-Content $_.FullName
    $imports = $content | Where-Object { $_ -match '^\s*import\s+' } | ForEach-Object { $_.Trim() }
    $grouped = $imports | Group-Object | Where-Object { $_.Count -gt 1 }
    if ($grouped.Count -gt 0) {
        Log "[DUPE] $($_.Name.Replace($root, '')):"
        $grouped | ForEach-Object { Log "    $($_.Name) x$($_.Count)" }
        $dupes++
    }
}
if ($dupes -eq 0) { Log "[OK] No duplicate imports found" }

# ============ SUMMARY ============
Section "SUMMARY"
Log "All diagnostic files in: $root"
Log "  - DIAG_$timestamp.txt (this file)"
Log "  - build_log_$timestamp.txt"
if ($buildExit -eq 0) {
    Log "  - latest_log_$timestamp.txt"
    Log "  - client_stdout_$timestamp.txt"
    Log "  - client_stderr_$timestamp.txt"
    if ($crashDetected) { Log "  - latest_crash_$timestamp.txt" }
}
Log ""
Log "╔══════════════════════════════════════════════════════════╗"
Log "║  INSTRUCTIONS:                                          ║"
Log "║  1. Open this file (DIAG_$timestamp.txt)                ║"
Log "║  2. Copy its FULL content                               ║"
Log "║  3. Send it to me for analysis                          ║"
Log "║                                                         ║"
Log "║  Or tell me specifically:                               ║"
Log "║  - Build fails? (compile error)                         ║"
Log "║  - Client crashes on start?                             ║"
Log "║  - Something doesn't work in-game?                      ║"
Log "╚══════════════════════════════════════════════════════════╝"

Write-Host "`n" -ForegroundColor Green
Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║  ✅ DIAGNOSTIC COMPLETE                                  ║" -ForegroundColor Green
Write-Host "║  File: $diagFile" -ForegroundColor Green
Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Green