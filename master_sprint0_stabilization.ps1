param(
    [string]$Root = "",
    [switch]$SkipBuild
)

# ============================================================
# SHINOBI CORE
# MASTER SPRINT 0: STABILIZATION, AUDIT, SAFE BOOTSTRAP
# ============================================================

$ErrorActionPreference = "Stop"

$script:utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Write-Step([string]$Message) {
    Write-Host ""
    Write-Host "[SPRINT0] $Message" -ForegroundColor Cyan
}

function Write-Ok([string]$Message) {
    Write-Host "  [OK] $Message" -ForegroundColor Green
}

function Write-Warn([string]$Message) {
    Write-Host "  [WARN] $Message" -ForegroundColor Yellow
}

function Write-Err([string]$Message) {
    Write-Host "  [FAIL] $Message" -ForegroundColor Red
}

function Read-TextFile([string]$Path) {
    if (-not (Test-Path $Path)) {
        return ""
    }

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

function Ensure-File([string]$Path, [string]$Content) {
    if (Test-Path $Path) {
        return $false
    }

    Write-TextFile -Path $Path -Content $Content
    return $true
}

function Invoke-GradleBuild([string]$RootPath, [string]$LogDir) {
    $gradle = Join-Path $RootPath "gradlew.bat"

    if (-not (Test-Path $gradle)) {
        Write-Err "gradlew.bat not found: $gradle"
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
        Write-Host ""
        Write-Host "Last output lines:" -ForegroundColor Red

        if ($output) {
            $output | Select-Object -Last 40 | ForEach-Object {
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
Write-Host " SHINOBI CORE - MASTER SPRINT 0" -ForegroundColor Cyan
Write-Host " Stabilization, audit, safe bootstrap" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

# ------------------------------------------------------------
# 1. Determine project root
# ------------------------------------------------------------

if ([string]::IsNullOrWhiteSpace($Root)) {
    $Root = (Get-Location).Path
}

if (-not (Test-Path (Join-Path $Root "gradlew.bat"))) {
    $candidate = "E:\Games\mod"

    if (Test-Path (Join-Path $candidate "gradlew.bat")) {
        $Root = $candidate
    }
}

if (-not (Test-Path (Join-Path $Root "gradlew.bat"))) {
    Write-Err "Project root not found. Use -Root `"E:\Games\mod`" or run from project root."
    exit 1
}

Write-Ok "Project root: $Root"

$srcMain = Join-Path $Root "src\main\java"
$resMain = Join-Path $Root "src\main\resources"
$outDir = Join-Path $Root "scripts\out\sprint0"

if (-not (Test-Path $outDir)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}

Write-Ok "Output directory: $outDir"

$issues = New-Object System.Collections.Generic.List[string]
$actions = New-Object System.Collections.Generic.List[string]

# ------------------------------------------------------------
# 2. Backup critical files
# ------------------------------------------------------------

Write-Step "Creating backup of critical files"

$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupDir = Join-Path $Root "backup\sprint0_$stamp"

$criticalFiles = @(
    "build.gradle",
    "settings.gradle",
    "gradle.properties",
    "src\main\resources\fabric.mod.json",
    "src\main\resources\shinobicore.mixins.json"
)

foreach ($rel in $criticalFiles) {
    $srcFile = Join-Path $Root $rel

    if (Test-Path $srcFile) {
        $destFile = Join-Path $backupDir $rel
        $destDir = Split-Path $destFile -Parent

        if (-not (Test-Path $destDir)) {
            New-Item -ItemType Directory -Path $destDir -Force | Out-Null
        }

        Copy-Item -Path $srcFile -Destination $destFile -Force
        Write-Ok "Backed up $rel"
    }
}

$actions.Add("Backup created at $backupDir")

# ------------------------------------------------------------
# 3. Audit Java files
# ------------------------------------------------------------

Write-Step "Auditing Java sources"

$javaFiles = @()

if (Test-Path $srcMain) {
    $javaFiles = Get-ChildItem -Path $srcMain -Recurse -Filter *.java -File -ErrorAction SilentlyContinue
}

$javaCount = $javaFiles.Count
$javaLineCount = 0

foreach ($file in $javaFiles) {
    try {
        $lines = [System.IO.File]::ReadAllLines($file.FullName, [System.Text.Encoding]::UTF8)
        $javaLineCount += $lines.Count
    }
    catch {
        $issues.Add("Cannot read file: $($file.FullName)")
    }
}

Write-Ok "Java files found: $javaCount"
Write-Ok "Java line count: $javaLineCount"

$debugPatterns = @(
    "System.out.println",
    "[DEBUG-WALL]",
    "[DEBUG CHAKRA KEY]",
    "[DEBUG PHYSICS]",
    "[DEBUG SERVER WALL]"
)

foreach ($file in $javaFiles) {
    try {
        $content = Read-TextFile $file.FullName
    }
    catch {
        continue
    }

    foreach ($pattern in $debugPatterns) {
        $matches = [regex]::Matches($content, [regex]::Escape($pattern))

        if ($matches.Count -gt 0) {
            $issues.Add("$($file.FullName): found $($matches.Count) occurrences of '$pattern'")
        }
    }

    if ($file.Name -eq "ClientMovementState.java") {
        $fieldMatches = [regex]::Matches(
            $content,
            '(?m)^\s*(?:private\s+|public\s+|protected\s+)?(?:static\s+)?boolean\s+isChargingJump\s*;'
        )

        if ($fieldMatches.Count -gt 1) {
            $issues.Add("$($file.FullName): duplicate field declaration 'boolean isChargingJump;' detected ($($fieldMatches.Count) times)")
        }
    }
}

# ------------------------------------------------------------
# 4. Patch gradle.properties
# ------------------------------------------------------------

Write-Step "Checking gradle.properties"

$gradlePropsPath = Join-Path $Root "gradle.properties"

if (Test-Path $gradlePropsPath) {
    $propsContent = Read-TextFile $gradlePropsPath
    $originalProps = $propsContent

    if ($propsContent -match '(?m)^\s*mod_version\s*=') {
        $propsContent = [regex]::Replace(
            $propsContent,
            '(?m)^\s*mod_version\s*=.*$',
            'mod_version=3.0.0'
        )
    }
    else {
        $propsContent = $propsContent.TrimEnd() + "`nmod_version=3.0.0`n"
    }

    if ($propsContent -ne $originalProps) {
        Write-TextFile -Path $gradlePropsPath -Content $propsContent
        Write-Ok "Set mod_version=3.0.0 in gradle.properties"
        $actions.Add("Updated gradle.properties mod_version to 3.0.0")
    }
    else {
        Write-Ok "gradle.properties already has mod_version=3.0.0 or no change needed"
    }
}
else {
    $propsContent = @"
mod_version=3.0.0
"@

    Write-TextFile -Path $gradlePropsPath -Content $propsContent
    Write-Warn "gradle.properties was missing. Created minimal file with mod_version=3.0.0"
    $actions.Add("Created minimal gradle.properties")
}

# ------------------------------------------------------------
# 5. Patch fabric.mod.json version and audit entrypoints
# ------------------------------------------------------------

Write-Step "Checking fabric.mod.json"

$fmjPath = Join-Path $resMain "fabric.mod.json"

if (Test-Path $fmjPath) {
    $fmjContent = Read-TextFile $fmjPath
    $originalFmj = $fmjContent

    $fmjContent = [regex]::Replace(
        $fmjContent,
        '"version"\s*:\s*"[0-9]+\.[0-9]+\.[0-9]+"',
        { param($m) '"version": "${version}"' }
    )

    if ($fmjContent -ne $originalFmj) {
        Write-TextFile -Path $fmjPath -Content $fmjContent
        Write-Ok "Updated fabric.mod.json version to `${version}"
        $actions.Add("Updated fabric.mod.json version to `${version}")
    }
    else {
        Write-Ok "fabric.mod.json version already safe or no numeric version found"
    }

    try {
        $fmjJson = $fmjContent | ConvertFrom-Json

        $hasMain = $false
        $hasClient = $false
        $hasCardinal = $false
        $hasCustomComponents = $false

        if ($fmjJson.PSObject.Properties.Name -contains "entrypoints") {
            $entrypoints = $fmjJson.entrypoints

            if ($entrypoints.PSObject.Properties.Name -contains "main") {
                $hasMain = $true
            }

            if ($entrypoints.PSObject.Properties.Name -contains "client") {
                $hasClient = $true
            }

            if ($entrypoints.PSObject.Properties.Name -contains "cardinal-components") {
                $hasCardinal = $true
            }
        }

        if ($fmjJson.PSObject.Properties.Name -contains "custom") {
            $custom = $fmjJson.custom

            if ($custom.PSObject.Properties.Name -contains "cardinal-components") {
                $hasCustomComponents = $true
            }
        }

        if (-not $hasMain) {
            $issues.Add("fabric.mod.json missing main entrypoint")
        }

        if (-not $hasClient) {
            $issues.Add("fabric.mod.json missing client entrypoint")
        }

        if (-not $hasCardinal) {
            $issues.Add("fabric.mod.json missing cardinal-components entrypoint")
        }

        if (-not $hasCustomComponents) {
            $issues.Add("fabric.mod.json missing custom.cardinal-components list")
        }

        Write-Ok "fabric.mod.json parsed successfully"
    }
    catch {
        $issues.Add("fabric.mod.json could not be parsed: $($_.Exception.Message)")
    }
}
else {
    $issues.Add("fabric.mod.json not found at $fmjPath")
}

# ------------------------------------------------------------
# 6. Patch mixins compatibility level and audit mixins
# ------------------------------------------------------------

Write-Step "Checking shinobicore.mixins.json"

$mixinsPath = Join-Path $resMain "shinobicore.mixins.json"

if (Test-Path $mixinsPath) {
    $mixinsContent = Read-TextFile $mixinsPath
    $originalMixins = $mixinsContent

    $mixinsContent = [regex]::Replace(
        $mixinsContent,
        '"compatibilityLevel"\s*:\s*"JAVA_[0-9]+"',
        { param($m) '"compatibilityLevel": "JAVA_17"' }
    )

    if ($mixinsContent -ne $originalMixins) {
        Write-TextFile -Path $mixinsPath -Content $mixinsContent
        Write-Ok "Updated mixin compatibilityLevel to JAVA_17"
        $actions.Add("Updated shinobicore.mixins.json compatibilityLevel to JAVA_17")
    }
    else {
        Write-Ok "Mixin compatibilityLevel already JAVA_17 or no change needed"
    }

    try {
        $mixinsJson = $mixinsContent | ConvertFrom-Json

        $commonMixins = @()
        $clientMixins = @()

        if ($mixinsJson.PSObject.Properties.Name -contains "mixins" -and $mixinsJson.mixins) {
            $commonMixins = @($mixinsJson.mixins)
        }

        if ($mixinsJson.PSObject.Properties.Name -contains "client" -and $mixinsJson.client) {
            $clientMixins = @($mixinsJson.client)
        }

        Write-Ok "Common mixins: $($commonMixins.Count)"
        Write-Ok "Client mixins: $($clientMixins.Count)"

        foreach ($mixin in $commonMixins) {
            $actions.Add("Common mixin registered: $mixin")
        }

        foreach ($mixin in $clientMixins) {
            $actions.Add("Client mixin registered: $mixin")
        }
    }
    catch {
        $issues.Add("shinobicore.mixins.json could not be parsed: $($_.Exception.Message)")
    }
}
else {
    $issues.Add("shinobicore.mixins.json not found at $mixinsPath")
}

# ------------------------------------------------------------
# 7. Create missing safe bootstrap classes
# ------------------------------------------------------------

Write-Step "Creating missing safe bootstrap classes"

$featureFlagsPath = Join-Path $srcMain "com\example\shinobicore\config\FeatureFlags.java"

$featureFlagsContent = @'
// SHINOBICORE:SPRINT0:FILE
package com.example.shinobicore.config;

/**
 * SPRINT 0 safe feature flags.
 *
 * These flags are intended to allow safe staged enable/disable of systems
 * during migration to version 3.0.
 *
 * This file is created only if missing. Existing file is not overwritten.
 */
public final class FeatureFlags {
    private FeatureFlags() {}

    public static boolean movementV3 = true;
    public static boolean chakraV3 = true;
    public static boolean progression = true;
    public static boolean combatV3 = false;

    public static boolean waterWalk = true;
    public static boolean wallRun = true;
    public static boolean slide = true;
    public static boolean crawl = true;
    public static boolean roll = true;
    public static boolean dodge = true;
    public static boolean chargedJump = true;
    public static boolean doubleJump = true;
    public static boolean edgeGrab = true;
    public static boolean meditation = true;

    public static boolean debugMovement = false;
    public static boolean debugChakra = false;
    public static boolean debugServerMirror = false;
}
'@

if (Ensure-File -Path $featureFlagsPath -Content $featureFlagsContent) {
    Write-Ok "Created FeatureFlags.java"
    $actions.Add("Created FeatureFlags.java")
}
else {
    Write-Ok "FeatureFlags.java already exists"
}

$loggerPath = Join-Path $srcMain "com\example\shinobicore\util\ShinobiLogger.java"

$loggerContent = @'
// SHINOBICORE:SPRINT0:FILE
package com.example.shinobicore.util;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * SPRINT 0 fallback logger.
 *
 * This file is created only if missing. Existing logger is not overwritten.
 */
public final class ShinobiLogger {
    private static final Logger LOGGER = LoggerFactory.getLogger("ShinobiCore");

    private ShinobiLogger() {}

    public enum Level {
        TRACE,
        DEBUG,
        INFO,
        WARN,
        ERROR,
        FATAL
    }

    public static void setLevel(Level level) {
        // Intentionally simple for Sprint 0.
        // Later this can be wired to config-driven logging.
    }

    public static void trace(String message, Object... args) {
        LOGGER.trace(format(message, args));
    }

    public static void debug(String message, Object... args) {
        LOGGER.debug(format(message, args));
    }

    public static void info(String message, Object... args) {
        LOGGER.info(format(message, args));
    }

    public static void warn(String message, Object... args) {
        LOGGER.warn(format(message, args));
    }

    public static void error(String message, Object... args) {
        LOGGER.error(format(message, args));
    }

    public static void fatal(String message, Object... args) {
        LOGGER.error("[FATAL] " + format(message, args));
    }

    private static String format(String message, Object... args) {
        if (message == null) {
            return "";
        }

        if (args == null || args.length == 0) {
            return message;
        }

        try {
            return String.format(message, args);
        }
        catch (Exception ex) {
            return message;
        }
    }
}
'@

if (Ensure-File -Path $loggerPath -Content $loggerContent) {
    Write-Ok "Created fallback ShinobiLogger.java"
    $actions.Add("Created fallback ShinobiLogger.java")
}
else {
    Write-Ok "ShinobiLogger.java already exists"
}

# ------------------------------------------------------------
# 8. Generate audit report
# ------------------------------------------------------------

Write-Step "Generating audit report"

$report = New-Object System.Text.StringBuilder

[void]$report.AppendLine("SHINOBI CORE - SPRINT 0 AUDIT REPORT")
[void]$report.AppendLine("Generated: " + (Get-Date -Format "yyyy-MM-dd HH:mm:ss"))
[void]$report.AppendLine("Root: " + $Root)
[void]$report.AppendLine("")
[void]$report.AppendLine("=== STATS ===")
[void]$report.AppendLine("Java files: $javaCount")
[void]$report.AppendLine("Java lines: $javaLineCount")
[void]$report.AppendLine("")
[void]$report.AppendLine("=== ACTIONS ===")

if ($actions.Count -eq 0) {
    [void]$report.AppendLine("No actions performed.")
}
else {
    foreach ($action in $actions) {
        [void]$report.AppendLine($action)
    }
}

[void]$report.AppendLine("")
[void]$report.AppendLine("=== ISSUES ===")

if ($issues.Count -eq 0) {
    [void]$report.AppendLine("No issues detected.")
}
else {
    foreach ($issue in $issues) {
        [void]$report.AppendLine($issue)
    }
}

$reportPath = Join-Path $outDir "audit_report.txt"
Write-TextFile -Path $reportPath -Content $report.ToString()

Write-Ok "Audit report saved: $reportPath"

# ------------------------------------------------------------
# 9. Build
# ------------------------------------------------------------

if (-not $SkipBuild) {
    Write-Step "Running Gradle build"

    $buildOk = Invoke-GradleBuild -RootPath $Root -LogDir $outDir

    if (-not $buildOk) {
        Write-Err "Sprint 0 master script finished with BUILD FAILURE."
        Write-Err "See log: $(Join-Path $outDir 'gradle_build.log')"
        exit 1
    }
}
else {
    Write-Warn "Build skipped because -SkipBuild was specified"
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host " MASTER SPRINT 0 COMPLETE" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Report: $reportPath" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next step: MASTER SPRINT 1 - config, feature flags, chakra foundation" -ForegroundColor Yellow
Write-Host ""

exit 0