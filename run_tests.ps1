$ErrorActionPreference = "Continue"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$root = "E:\Games\mod"
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$reportDir = "$root\test_results"
if (-not (Test-Path $reportDir)) { New-Item -ItemType Directory -Path $reportDir -Force | Out-Null }

Write-Host ""
Write-Host "==============================================================" -ForegroundColor Cyan
Write-Host "     SHINOBICORE AUTOMATED TEST PIPELINE" -ForegroundColor Cyan
Write-Host "==============================================================" -ForegroundColor Cyan
Write-Host ""

# ============ PHASE 1: Unit Tests ============
Write-Host "[1/4] Running unit tests (gradlew test)..." -ForegroundColor Yellow
$unitOutput = & "$root\gradlew.bat" test --stacktrace 2>&1
$unitExit = $LASTEXITCODE
$unitOutput | Out-File "$reportDir\unit_test_$timestamp.txt" -Encoding UTF8

if ($unitExit -eq 0) {
    Write-Host "  [PASS] Unit tests passed" -ForegroundColor Green
} else {
    Write-Host "  [FAIL] Unit tests failed (exit code: $unitExit)" -ForegroundColor Red
    Write-Host "  See: $reportDir\unit_test_$timestamp.txt" -ForegroundColor Red
}

# ============ PHASE 2: Build ============
Write-Host ""
Write-Host "[2/4] Building project..." -ForegroundColor Yellow
$buildOutput = & "$root\gradlew.bat" build 2>&1
$buildExit = $LASTEXITCODE
$buildOutput | Out-File "$reportDir\build_$timestamp.txt" -Encoding UTF8

if ($buildExit -eq 0) {
    Write-Host "  [PASS] Build successful" -ForegroundColor Green
} else {
    Write-Host "  [FAIL] Build failed! Cannot continue." -ForegroundColor Red
    Write-Host "  See: $reportDir\build_$timestamp.txt" -ForegroundColor Red
    exit 1
}

# ============ PHASE 3: In-game test command ============
Write-Host ""
Write-Host "[3/4] Launching client for in-game tests..." -ForegroundColor Yellow
Write-Host "  Starting runClient (auto-test via /testall)..." -ForegroundColor Cyan

$oldReports = Get-ChildItem "$root\run\config\shinobicore" -Filter "test_report_*.txt" -ErrorAction SilentlyContinue
$preCount = 0
if ($oldReports) { $preCount = $oldReports.Count }

$clientProcess = Start-Process -FilePath "$root\gradlew.bat" `
    -ArgumentList "runClient" `
    -WorkingDirectory $root `
    -PassThru `
    -WindowStyle Normal

Write-Host "  Client started (PID: $($clientProcess.Id))" -ForegroundColor White
Write-Host "  Waiting 60 seconds for client to load..." -ForegroundColor White
Start-Sleep -Seconds 60

Write-Host ""
Write-Host "  =============================================================" -ForegroundColor Magenta
Write-Host "  |  NOW IN GAME: Type /testall and press Enter              |" -ForegroundColor Magenta
Write-Host "  =============================================================" -ForegroundColor Magenta
Write-Host ""

Write-Host "  Waiting 30 seconds for tests to complete..." -ForegroundColor White
Start-Sleep -Seconds 30

$newReports = Get-ChildItem "$root\run\config\shinobicore" -Filter "test_report_*.txt" -ErrorAction SilentlyContinue
$postCount = 0
if ($newReports) { $postCount = $newReports.Count }

$inGameReportPath = $null
if ($postCount -gt $preCount) {
    $inGameReportPath = ($newReports | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
    Write-Host "  [PASS] In-game test report generated!" -ForegroundColor Green
    Write-Host "  Report: $inGameReportPath" -ForegroundColor Green
    Copy-Item $inGameReportPath "$reportDir\ingame_test_$timestamp.txt" -Force
} else {
    Write-Host "  [WARN] No in-game report found. Type /testall manually in game." -ForegroundColor Yellow
}

# ============ PHASE 4: Summary ============
Write-Host ""
Write-Host "[4/4] Generating summary..." -ForegroundColor Yellow

$summaryFile = "$reportDir\SUMMARY_$timestamp.txt"
$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine("==============================================================")
[void]$sb.AppendLine("  SHINOBICORE TEST SUMMARY - $timestamp")
[void]$sb.AppendLine("==============================================================")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("Phase 1: Unit Tests")
if ($unitExit -eq 0) {
    [void]$sb.AppendLine("  Status: PASSED")
} else {
    [void]$sb.AppendLine("  Status: FAILED")
    [void]$sb.AppendLine("  Log: unit_test_$timestamp.txt")
}
[void]$sb.AppendLine("")
[void]$sb.AppendLine("Phase 2: Build")
if ($buildExit -eq 0) {
    [void]$sb.AppendLine("  Status: PASSED")
} else {
    [void]$sb.AppendLine("  Status: FAILED")
    [void]$sb.AppendLine("  Log: build_$timestamp.txt")
}
[void]$sb.AppendLine("")
[void]$sb.AppendLine("Phase 3: In-Game Tests (/testall)")
if ($inGameReportPath) {
    [void]$sb.AppendLine("  Status: COMPLETED")
    [void]$sb.AppendLine("  Report: ingame_test_$timestamp.txt")
} else {
    [void]$sb.AppendLine("  Status: NOT RUN (type /testall in game)")
}
[void]$sb.AppendLine("")
[void]$sb.AppendLine("All reports in: $reportDir")
[void]$sb.AppendLine("==============================================================")

[System.IO.File]::WriteAllText($summaryFile, $sb.ToString(), $utf8)

Write-Host ""
Write-Host "==============================================================" -ForegroundColor Green
Write-Host "              TEST PIPELINE COMPLETE" -ForegroundColor Green
Write-Host "==============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Results:" -ForegroundColor White
if ($unitExit -eq 0) {
    Write-Host "  Unit tests:  PASSED" -ForegroundColor Green
} else {
    Write-Host "  Unit tests:  FAILED" -ForegroundColor Red
}
if ($buildExit -eq 0) {
    Write-Host "  Build:       PASSED" -ForegroundColor Green
} else {
    Write-Host "  Build:       FAILED" -ForegroundColor Red
}
if ($inGameReportPath) {
    Write-Host "  In-game:     COMPLETED" -ForegroundColor Green
} else {
    Write-Host "  In-game:     PENDING - type /testall" -ForegroundColor Yellow
}
Write-Host ""
Write-Host "Reports: $reportDir" -ForegroundColor Cyan
Write-Host ""
Write-Host "To kill client: Stop-Process -Id $($clientProcess.Id) -Force" -ForegroundColor DarkGray