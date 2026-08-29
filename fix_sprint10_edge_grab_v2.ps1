param(
    [string]$Root = "",
    [switch]$SkipBuild
)

$ErrorActionPreference = "Stop"
$script:utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Write-Ok([string]$Message) {
    Write-Host "  [OK] $Message" -ForegroundColor Green
}

function Write-Err([string]$Message) {
    Write-Host "  [FAIL] $Message" -ForegroundColor Red
}

function Read-TextFile([string]$Path) {
    if (-not (Test-Path $Path)) { return "" }
    return [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
}

function Write-TextFile([string]$Path, [string]$Content) {
    $dir = Split-Path $Path -Parent
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    $Content = $Content -replace "`r`n", "`n"
    [System.IO.File]::WriteAllText($Path, $Content, $script:utf8NoBom)
}

function Invoke-GradleBuild([string]$RootPath, [string]$LogDir) {
    $gradle = Join-Path $RootPath "gradlew.bat"

    if (-not (Test-Path $gradle)) {
        Write-Err "gradlew.bat not found"
        return $false
    }

    Push-Location $RootPath

    try {
        $prevEap = $ErrorActionPreference
        $ErrorActionPreference = "Continue"

        $output = & $gradle build 2>&1
        $exitCode = $LASTEXITCODE

        $ErrorActionPreference = $prevEap

        if ($output) {
            $logPath = Join-Path $LogDir "gradle_build.log"
            $output | Out-File -FilePath $logPath -Encoding utf8
        }

        if ($exitCode -eq 0) {
            Write-Ok "Gradle build successful"
            return $true
        }

        Write-Err "Gradle build failed with exit code $exitCode"

        if ($output) {
            $output |
                ForEach-Object { $_.ToString() } |
                Where-Object { $_ -match "error:" } |
                Select-Object -First 30 |
                ForEach-Object {
                    Write-Host $_ -ForegroundColor Red
                }
        }

        return $false
    }
    finally {
        Pop-Location
    }
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " FIX SPRINT 10 v2: BlockPos int conversion" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

if ([string]::IsNullOrWhiteSpace($Root)) {
    $Root = (Get-Location).Path
}

if (-not (Test-Path (Join-Path $Root "gradlew.bat"))) {
    $Root = "E:\Games\mod"
}

if (-not (Test-Path (Join-Path $Root "gradlew.bat"))) {
    Write-Err "Project root not found."
    exit 1
}

Write-Ok "Project root: $Root"

$srcJava = Join-Path $Root "src\main\java"
$outDir = Join-Path $Root "scripts\out\sprint10"

if (-not (Test-Path $outDir)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}

# ------------------------------------------------------------
# Fix EdgeGrabClient.java
# ------------------------------------------------------------

Write-Host ""
Write-Host "[FIX] Patching EdgeGrabClient.java" -ForegroundColor Yellow

$edgeGrabPath = Join-Path $srcJava "com\example\shinobicore\movement\client\EdgeGrabClient.java"

if (-not (Test-Path $edgeGrabPath)) {
    Write-Err "EdgeGrabClient.java not found!"
    exit 1
}

$content = Read-TextFile $edgeGrabPath

# Replace "new BlockPos(checkPos.x, checkPos.y, checkPos.z)" with floored int version
$oldPattern = "new BlockPos(checkPos.x, checkPos.y, checkPos.z)"
$newPattern = "new BlockPos((int) Math.floor(checkPos.x), (int) Math.floor(checkPos.y), (int) Math.floor(checkPos.z))"

if ($content.Contains($oldPattern)) {
    $content = $content.Replace($oldPattern, $newPattern)
    Write-Ok "Replaced BlockPos constructor with int cast"
} else {
    Write-Ok "BlockPos constructor already fixed or pattern not found"
}

Write-TextFile -Path $edgeGrabPath -Content $content

# ------------------------------------------------------------
# Build
# ------------------------------------------------------------

if (-not $SkipBuild) {
    Write-Host ""
    Write-Host "[BUILD] Running Gradle build..." -ForegroundColor Yellow

    $buildOk = Invoke-GradleBuild -RootPath $Root -LogDir $outDir

    if (-not $buildOk) {
        Write-Err "Fix failed."
        exit 1
    }
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host " FIX SPRINT 10 v2 COMPLETE" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Now test:" -ForegroundColor Yellow
Write-Host "  .\gradlew.bat runClient" -ForegroundColor White
Write-Host "  Jump off ledge, auto-grab edge" -ForegroundColor White
Write-Host "  W/Space to climb, S/Shift to release" -ForegroundColor White
Write-Host ""

exit 0