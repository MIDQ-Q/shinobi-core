param(
    [string]$Root = "",
    [switch]$SkipBuild
)

# ============================================================
# FIX SPRINT 3
# Quarantine old conflicting movement files and stabilize build
# ============================================================

$ErrorActionPreference = "Stop"
$script:utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Write-Step([string]$Message) {
    Write-Host ""
    Write-Host "[FIX-SPRINT3] $Message" -ForegroundColor Cyan
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

function Ensure-Directory([string]$Path) {
    if (-not (Test-Path $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Move-SourceFile([string]$RelativePath, [string]$ArchiveDir) {
    $src = Join-Path $Root $RelativePath

    if (-not (Test-Path $src)) {
        return
    }

    $dest = Join-Path $ArchiveDir $RelativePath
    $destDir = Split-Path $dest -Parent

    Ensure-Directory $destDir
    Move-Item -Path $src -Destination $dest -Force
    Write-Ok "Quarantined $RelativePath"
}

function Backup-File([string]$RelativePath, [string]$BackupDir) {
    $src = Join-Path $Root $RelativePath

    if (-not (Test-Path $src)) {
        return
    }

    $dest = Join-Path $BackupDir $RelativePath
    $destDir = Split-Path $dest -Parent

    Ensure-Directory $destDir
    Copy-Item -Path $src -Destination $dest -Force
    Write-Ok "Backed up $RelativePath"
}

function Invoke-GradleBuildDetailed([string]$RootPath, [string]$LogDir) {
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
        Write-Host "Detailed errors:" -ForegroundColor Red

        if ($output) {
            $output |
                ForEach-Object { $_.ToString() } |
                Where-Object { $_ -match "error:|symbol:|location:" } |
                Select-Object -First 100 |
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
Write-Host " FIX SPRINT 3" -ForegroundColor Cyan
Write-Host " Quarantine old movement files + stabilize build" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

# ------------------------------------------------------------
# 1. Resolve root
# ------------------------------------------------------------

if ([string]::IsNullOrWhiteSpace($Root)) {
    $Root = (Get-Location).Path
}

if (-not (Test-Path (Join-Path $Root "gradlew.bat"))) {
    $Root = "E:\Games\mod"
}

if (-not (Test-Path (Join-Path $Root "gradlew.bat"))) {
    Write-Err "Project root not found. Use -Root `"E:\Games\mod`"."
    exit 1
}

Write-Ok "Project root: $Root"

$srcJava = Join-Path $Root "src\main\java"
$resMain = Join-Path $Root "src\main\resources"
$outDir = Join-Path $Root "scripts\out\sprint3_fix"

Ensure-Directory $outDir

$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$archiveDir = Join-Path $Root "archive\sprint3_quarantine_$stamp"
$backupDir = Join-Path $Root "backup\sprint3_fix_$stamp"

# ------------------------------------------------------------
# 2. Backup files we may patch
# ------------------------------------------------------------

Write-Step "Creating backup"

Backup-File "src\main\resources\shinobicore.mixins.json" $backupDir
Backup-File "src\main\java\com\example\shinobicore\ShinobiCore.java" $backupDir
Backup-File "src\main\java\com\example\shinobicore\ShinobiCoreClient.java" $backupDir
Backup-File "src\main\java\com\example\shinobicore\chakra\client\ChakraClientController.java" $backupDir
Backup-File "src\main\java\com\example\shinobicore\client\input\KeyBindings.java" $backupDir
Backup-File "src\main\java\com\example\shinobicore\client\KeyBindings.java" $backupDir
Backup-File "src\main\java\com\example\shinobicore\bootstrap\Sprint3ClientBootstrap.java" $backupDir

# ------------------------------------------------------------
# 3. Quarantine conflicting old movement files
# ------------------------------------------------------------

Write-Step "Quarantining old conflicting movement files"

$quarantineFiles = @(
    "src\main\java\com\example\shinobicore\mixin\ChakraMovementTravelMixin.java",
    "src\main\java\com\example\shinobicore\movement\client\ClientMovementService.java",
    "src\main\java\com\example\shinobicore\movement\client\MovementInputService.java",
    "src\main\java\com\example\shinobicore\movement\client\ChargedJumpClient.java",
    "src\main\java\com\example\shinobicore\movement\client\DodgeClient.java",
    "src\main\java\com\example\shinobicore\movement\client\DoubleJumpClient.java",
    "src\main\java\com\example\shinobicore\movement\client\EdgeGrabClient.java",
    "src\main\java\com\example\shinobicore\movement\client\SlideClient.java",
    "src\main\java\com\example\shinobicore\movement\client\CrawlClient.java",
    "src\main\java\com\example\shinobicore\movement\client\RollClient.java",
    "src\main\java\com\example\shinobicore\movement\client\WaterWalkClient.java",
    "src\main\java\com\example\shinobicore\movement\client\WallRunClient.java",
    "src\main\java\com\example\shinobicore\movement\client\MeditationClient.java"
)

foreach ($rel in $quarantineFiles) {
    Move-SourceFile -RelativePath $rel -ArchiveDir $archiveDir
}

Write-Ok "Quarantine folder: $archiveDir"

# ------------------------------------------------------------
# 4. Comment imports and direct references to quarantined classes
# ------------------------------------------------------------

Write-Step "Commenting imports and references to quarantined classes"

$quarantinedClassNames = @(
    "ChakraMovementTravelMixin",
    "ClientMovementService",
    "MovementInputService",
    "ChargedJumpClient",
    "DodgeClient",
    "DoubleJumpClient",
    "EdgeGrabClient",
    "SlideClient",
    "CrawlClient",
    "RollClient",
    "WaterWalkClient",
    "WallRunClient",
    "MeditationClient"
)

$classPattern = '\b(' + ($quarantinedClassNames -join '|') + ')\b'

# Comment imports globally
$javaFiles = Get-ChildItem -Path $srcJava -Recurse -Filter *.java -File -ErrorAction SilentlyContinue

foreach ($file in $javaFiles) {
    $lines = (Read-TextFile $file.FullName) -split "`r?`n"
    $changed = $false

    for ($i = 0; $i -lt $lines.Count; $i++) {
        $trimmed = $lines[$i].Trim()

        if ($trimmed.StartsWith("import") -and $trimmed -match $classPattern -and -not $trimmed.StartsWith("//")) {
            $lines[$i] = "// [SPRINT3-QUARANTINE] " + $trimmed
            $changed = $true
        }
    }

    if ($changed) {
        Write-TextFile -Path $file.FullName -Content ($lines -join "`n")
        Write-Ok "Commented imports in $($file.Name)"
    }
}

# Comment direct calls in main/client entrypoints
$entrypointFiles = @(
    (Join-Path $srcJava "com\example\shinobicore\ShinobiCore.java"),
    (Join-Path $srcJava "com\example\shinobicore\ShinobiCoreClient.java")
)

foreach ($path in $entrypointFiles) {
    if (-not (Test-Path $path)) {
        continue
    }

    $lines = (Read-TextFile $path) -split "`r?`n"
    $changed = $false

    for ($i = 0; $i -lt $lines.Count; $i++) {
        $trimmed = $lines[$i].Trim()

        if ($trimmed -eq "" -or $trimmed.StartsWith("//")) {
            continue
        }

        if ($lines[$i] -match $classPattern) {
            $lines[$i] = "// [SPRINT3-QUARANTINE] " + $trimmed
            $changed = $true
        }
    }

    if ($changed) {
        Write-TextFile -Path $path -Content ($lines -join "`n")
        Write-Ok "Commented references in $(Split-Path $path -Leaf)"
    }
}

# ------------------------------------------------------------
# 5. Remove ChakraMovementTravelMixin from mixins.json
# ------------------------------------------------------------

Write-Step "Cleaning shinobicore.mixins.json"

$mixinsPath = Join-Path $resMain "shinobicore.mixins.json"

if (Test-Path $mixinsPath) {
    $raw = Read-TextFile $mixinsPath

    try {
        $json = $raw | ConvertFrom-Json
        $changed = $false

        foreach ($key in @("mixins", "client")) {
            if ($json.PSObject.Properties.Name -contains $key) {
                $old = @($json.$key)
                $new = @($old | Where-Object { $_ -ne "ChakraMovementTravelMixin" })

                if ($new.Count -ne $old.Count) {
                    $json.$key = $new
                    $changed = $true
                }
            }
        }

        if ($changed) {
            $newJson = $json | ConvertTo-Json -Depth 20
            Write-TextFile -Path $mixinsPath -Content $newJson
            Write-Ok "Removed ChakraMovementTravelMixin from mixins.json"
        }
        else {
            Write-Ok "mixins.json already clean"
        }
    }
    catch {
        Write-Warn "Could not parse mixins.json, using regex fallback"

        $raw = $raw -replace '"ChakraMovementTravelMixin"\s*,?', ''
        $raw = $raw -replace ',\s*]', ']'
        Write-TextFile -Path $mixinsPath -Content $raw
        Write-Ok "Regex-cleaned mixins.json"
    }
}
else {
    Write-Warn "shinobicore.mixins.json not found"
}

# ------------------------------------------------------------
# 6. Ensure safe input KeyBindings exists
# ------------------------------------------------------------

Write-Step "Ensuring safe input KeyBindings exists"

$inputKeyBindingsPath = Join-Path $srcJava "com\example\shinobicore\client\input\KeyBindings.java"

if (-not (Test-Path $inputKeyBindingsPath)) {
    $inputKeyBindingsContent = @'
// SHINOBICORE:SPRINT3-FIX:FILE
package com.example.shinobicore.client.input;

import net.fabricmc.fabric.api.client.keybinding.v1.KeyBindingHelper;
import net.minecraft.client.option.KeyBinding;
import net.minecraft.client.util.InputUtil;
import org.lwjgl.glfw.GLFW;

/**
 * SPRINT 3 safe key bindings foundation.
 */
public final class KeyBindings {
    private KeyBindings() {}

    public static KeyBinding CHAKRA_MODE;
    public static KeyBinding ROLL;
    public static KeyBinding DODGE_LEFT;
    public static KeyBinding DODGE_RIGHT;
    public static KeyBinding MEDITATE;
    public static KeyBinding PROGRESSION;
    public static KeyBinding CRAWL;

    private static boolean registered = false;

    public static void register() {
        if (registered) return;
        registered = true;

        CHAKRA_MODE = KeyBindingHelper.registerKeyBinding(new KeyBinding(
                "key.shinobicore.chakra_mode",
                InputUtil.Type.KEYSYM,
                GLFW.GLFW_KEY_L,
                "key.categories.shinobicore"
        ));

        ROLL = KeyBindingHelper.registerKeyBinding(new KeyBinding(
                "key.shinobicore.roll",
                InputUtil.Type.KEYSYM,
                GLFW.GLFW_KEY_R,
                "key.categories.shinobicore.movement"
        ));

        DODGE_LEFT = KeyBindingHelper.registerKeyBinding(new KeyBinding(
                "key.shinobicore.dodge_left",
                InputUtil.Type.KEYSYM,
                GLFW.GLFW_KEY_Z,
                "key.categories.shinobicore.movement"
        ));

        DODGE_RIGHT = KeyBindingHelper.registerKeyBinding(new KeyBinding(
                "key.shinobicore.dodge_right",
                InputUtil.Type.KEYSYM,
                GLFW.GLFW_KEY_C,
                "key.categories.shinobicore.movement"
        ));

        MEDITATE = KeyBindingHelper.registerKeyBinding(new KeyBinding(
                "key.shinobicore.meditate",
                InputUtil.Type.KEYSYM,
                GLFW.GLFW_KEY_M,
                "key.categories.shinobicore.movement"
        ));

        PROGRESSION = KeyBindingHelper.registerKeyBinding(new KeyBinding(
                "key.shinobicore.progression",
                InputUtil.Type.KEYSYM,
                GLFW.GLFW_KEY_K,
                "key.categories.shinobicore"
        ));

        CRAWL = KeyBindingHelper.registerKeyBinding(new KeyBinding(
                "key.shinobicore.crawl",
                InputUtil.Type.KEYSYM,
                GLFW.GLFW_KEY_N,
                "key.categories.shinobicore.movement"
        ));
    }
}
'@

    Write-TextFile -Path $inputKeyBindingsPath -Content $inputKeyBindingsContent
    Write-Ok "Created client/input/KeyBindings.java"
}
else {
    Write-Ok "client/input/KeyBindings.java already exists"
}

# ------------------------------------------------------------
# 7. Ensure legacy client KeyBindings wrapper exists
# ------------------------------------------------------------

Write-Step "Ensuring legacy client KeyBindings wrapper exists"

$legacyKeyBindingsPath = Join-Path $srcJava "com\example\shinobicore\client\KeyBindings.java"

if (-not (Test-Path $legacyKeyBindingsPath)) {
    $legacyKeyBindingsContent = @'
// SHINOBICORE:SPRINT3-FIX:FILE
package com.example.shinobicore.client;

import net.minecraft.client.option.KeyBinding;

/**
 * SPRINT 3 legacy compatibility wrapper.
 * Delegates registration to client.input.KeyBindings.
 */
public final class KeyBindings {
    private KeyBindings() {}

    public static KeyBinding CHAKRA_MODE;
    public static KeyBinding ROLL;
    public static KeyBinding DODGE_LEFT;
    public static KeyBinding DODGE_RIGHT;
    public static KeyBinding MEDITATE;
    public static KeyBinding PROGRESSION;
    public static KeyBinding CRAWL;

    private static boolean registered = false;

    public static void register() {
        if (registered) return;
        registered = true;

        com.example.shinobicore.client.input.KeyBindings.register();

        CHAKRA_MODE = com.example.shinobicore.client.input.KeyBindings.CHAKRA_MODE;
        ROLL = com.example.shinobicore.client.input.KeyBindings.ROLL;
        DODGE_LEFT = com.example.shinobicore.client.input.KeyBindings.DODGE_LEFT;
        DODGE_RIGHT = com.example.shinobicore.client.input.KeyBindings.DODGE_RIGHT;
        MEDITATE = com.example.shinobicore.client.input.KeyBindings.MEDITATE;
        PROGRESSION = com.example.shinobicore.client.input.KeyBindings.PROGRESSION;
        CRAWL = com.example.shinobicore.client.input.KeyBindings.CRAWL;
    }

    public static void init() {
        register();
    }
}
'@

    Write-TextFile -Path $legacyKeyBindingsPath -Content $legacyKeyBindingsContent
    Write-Ok "Created client/KeyBindings.java compatibility wrapper"
}
else {
    Write-Ok "client/KeyBindings.java already exists"
}

# ------------------------------------------------------------
# 8. Update Sprint3ClientBootstrap to register keybindings safely
# ------------------------------------------------------------

Write-Step "Updating Sprint3ClientBootstrap"

$clientBootstrapPath = Join-Path $srcJava "com\example\shinobicore\bootstrap\Sprint3ClientBootstrap.java"

$clientBootstrapContent = @'
// SHINOBICORE:SPRINT3-FIX:FILE
package com.example.shinobicore.bootstrap;

import com.example.shinobicore.chakra.client.ChakraKeyHandler;
import com.example.shinobicore.config.FeatureFlags;
import com.example.shinobicore.util.ShinobiLogger;
import net.fabricmc.api.ClientModInitializer;

/**
 * SPRINT 3 client-side bootstrap.
 * Registers key bindings and chakra key handler.
 */
public class Sprint3ClientBootstrap implements ClientModInitializer {
    @Override
    public void onInitializeClient() {
        if (!FeatureFlags.movementV3) {
            ShinobiLogger.info("[SPRINT3] movementV3 flag disabled, skipping client bootstrap");
            return;
        }

        try {
            Class<?> inputKeys = Class.forName("com.example.shinobicore.client.input.KeyBindings");
            inputKeys.getMethod("register").invoke(null);
        } catch (Throwable ignored) {}

        try {
            Class<?> legacyKeys = Class.forName("com.example.shinobicore.client.KeyBindings");
            legacyKeys.getMethod("register").invoke(null);
        } catch (Throwable ignored) {}

        ChakraKeyHandler.register();
        ShinobiLogger.info("[SPRINT3] Client key handler registered (L = chakra mode toggle)");
    }
}
'@

Write-TextFile -Path $clientBootstrapPath -Content $clientBootstrapContent
Write-Ok "Updated Sprint3ClientBootstrap.java"

# ------------------------------------------------------------
# 9. Add compatibility methods to ChakraClientController
# ------------------------------------------------------------

Write-Step "Adding compatibility methods to ChakraClientController"

$controllerPath = Join-Path $srcJava "com\example\shinobicore\chakra\client\ChakraClientController.java"

if (Test-Path $controllerPath) {
    $content = Read-TextFile $controllerPath
    $additions = ""

    if (-not $content.Contains("public static boolean isChakraModeActive()")) {
        $additions += @"

    public static boolean isChakraModeActive() {
        return isChakraMode();
    }
"@
    }

    if (-not $content.Contains("public static boolean canUseChakra(float amount)")) {
        $additions += @"

    public static boolean canUseChakra(float amount) {
        return !isExhausted() && getCurrentChakra() >= amount;
    }
"@
    }

    if (-not $content.Contains("public static boolean consumeChakra(float amount)")) {
        $additions += @"

    public static boolean consumeChakra(float amount) {
        if (!canUseChakra(amount)) {
            return false;
        }

        currentChakra = Math.max(0.0f, currentChakra - amount);

        if (currentChakra <= 0.0f) {
            chakraMode = false;
            exhausted = true;
        }

        return true;
    }
"@
    }

    if (-not $content.Contains("public static float getFatigue()")) {
        $additions += @"

    public static float getFatigue() {
        return fatigue;
    }
"@
    }

    if (-not $content.Contains("public static void addFatigue(float amount)")) {
        $additions += @"

    public static void addFatigue(float amount) {
        fatigue = Math.max(0.0f, fatigue + amount);
    }
"@
    }

    if ($additions -ne "") {
        $lastBrace = $content.LastIndexOf("}")

        if ($lastBrace -ge 0) {
            $newContent = $content.Substring(0, $lastBrace) + $additions + "`n" + $content.Substring($lastBrace)
            Write-TextFile -Path $controllerPath -Content $newContent
            Write-Ok "Added compatibility methods to ChakraClientController"
        }
        else {
            Write-Warn "Could not locate closing brace in ChakraClientController"
        }
    }
    else {
        Write-Ok "ChakraClientController already has compatibility methods"
    }
}
else {
    Write-Warn "ChakraClientController.java not found"
}

# ------------------------------------------------------------
# 10. Build
# ------------------------------------------------------------

if (-not $SkipBuild) {
    Write-Step "Running Gradle build"

    $buildOk = Invoke-GradleBuildDetailed -RootPath $Root -LogDir $outDir

    if (-not $buildOk) {
        Write-Err "Fix Sprint 3 failed. See detailed errors above."
        Write-Err "Log: $(Join-Path $outDir 'gradle_build.log')"
        exit 1
    }
}
else {
    Write-Warn "Build skipped because -SkipBuild was specified"
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host " FIX SPRINT 3 COMPLETE" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Quarantine folder: $archiveDir" -ForegroundColor Cyan
Write-Host "Log: $(Join-Path $outDir 'gradle_build.log')" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next: MASTER SPRINT 4 - Water Walk foundation on clean state" -ForegroundColor Yellow
Write-Host ""

exit 0