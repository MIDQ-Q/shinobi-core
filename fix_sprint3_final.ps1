param(
    [string]$Root = "",
    [switch]$SkipBuild
)

# ============================================================
# FIX SPRINT 3 FINAL
# Force update KeyBindings and MovementActionType
# ============================================================

$ErrorActionPreference = "Stop"
$script:utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Write-Step([string]$Message) {
    Write-Host ""
    Write-Host "[FIX-FINAL] $Message" -ForegroundColor Cyan
}

function Write-Ok([string]$Message) {
    Write-Host "  [OK] $Message" -ForegroundColor Green
}

function Write-Err([string]$Message) {
    Write-Host "  [FAIL] $Message" -ForegroundColor Red
}

function Write-TextFile([string]$Path, [string]$Content) {
    $dir = Split-Path $Path -Parent
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    $Content = $Content -replace "`r`n", "`n"
    [System.IO.File]::WriteAllText($Path, $Content, $script:utf8NoBom)
}

function Invoke-GradleBuildDetailed([string]$RootPath, [string]$LogDir) {
    $gradle = Join-Path $RootPath "gradlew.bat"
    if (-not (Test-Path $gradle)) { return $false }

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
            $output | ForEach-Object { $_.ToString() } | Where-Object { $_ -match "error:|symbol:|location:" } | Select-Object -First 50 | ForEach-Object { Write-Host $_ -ForegroundColor Red }
        }
        return $false
    }
    finally { Pop-Location }
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " FIX SPRINT 3 FINAL" -ForegroundColor Cyan
Write-Host " Force update KeyBindings & MovementActionType" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

if ([string]::IsNullOrWhiteSpace($Root)) { $Root = (Get-Location).Path }
if (-not (Test-Path (Join-Path $Root "gradlew.bat"))) { $Root = "E:\Games\mod" }
if (-not (Test-Path (Join-Path $Root "gradlew.bat"))) { Write-Err "Project root not found."; exit 1 }

Write-Ok "Project root: $Root"
$srcJava = Join-Path $Root "src\main\java"
$outDir = Join-Path $Root "scripts\out\sprint3_final"
if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }

# ------------------------------------------------------------
# 1. Force overwrite client/input/KeyBindings.java
# ------------------------------------------------------------
Write-Step "Force updating client/input/KeyBindings.java"

$keyBindingsPath = Join-Path $srcJava "com\example\shinobicore\client\input\KeyBindings.java"

$keyBindingsContent = @'
// SHINOBICORE:SPRINT3-FINAL:FILE
package com.example.shinobicore.client.input;

import net.fabricmc.fabric.api.client.keybinding.v1.KeyBindingHelper;
import net.minecraft.client.option.KeyBinding;
import net.minecraft.client.util.InputUtil;
import org.lwjgl.glfw.GLFW;

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

Write-TextFile -Path $keyBindingsPath -Content $keyBindingsContent
Write-Ok "Updated client/input/KeyBindings.java with all keys"

# ------------------------------------------------------------
# 2. Force overwrite MovementActionType.java with ID system
# ------------------------------------------------------------
Write-Step "Force updating MovementActionType.java with ID system"

$actionTypePath = Join-Path $srcJava "com\example\shinobicore\movement\common\MovementActionType.java"

$actionTypeContent = @'
// SHINOBICORE:SPRINT3-FINAL:FILE
package com.example.shinobicore.movement.common;

/**
 * SPRINT 3 FINAL action types with network IDs.
 */
public enum MovementActionType {
    NONE(0),
    CHAKRA_MODE_ON(1),
    CHAKRA_MODE_OFF(2),
    WATER_START(3),
    WATER_STOP(4),
    WALL_START(5),
    WALL_STOP(6),
    WALL_JUMP(7),
    SLIDE_START(8),
    SLIDE_STOP(9),
    CRAWL_START(10),
    CRAWL_STOP(11),
    ROLL_START(12),
    ROLL_STOP(13),
    DODGE_LEFT(14),
    DODGE_RIGHT(15),
    CHARGED_JUMP_START(16),
    CHARGED_JUMP_RELEASE(17),
    DOUBLE_JUMP(18),
    EDGE_GRAB_START(19),
    EDGE_GRAB_STOP(20),
    MEDITATION_START(21),
    MEDITATION_STOP(22),
    MOVEMENT_HEARTBEAT(23),
    RESET(24);

    private final int id;

    MovementActionType(int id) {
        this.id = id;
    }

    public int getId() {
        return id;
    }

    public static MovementActionType fromId(int id) {
        for (MovementActionType t : values()) {
            if (t.id == id) return t;
        }
        return NONE;
    }
}
'@

Write-TextFile -Path $actionTypePath -Content $actionTypeContent
Write-Ok "Updated MovementActionType.java with fromId() support"

# ------------------------------------------------------------
# 3. Build
# ------------------------------------------------------------
if (-not $SkipBuild) {
    Write-Step "Running Gradle build"
    $buildOk = Invoke-GradleBuildDetailed -RootPath $Root -LogDir $outDir
    if (-not $buildOk) {
        Write-Err "Final fix failed."
        exit 1
    }
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host " FIX SPRINT 3 FINAL COMPLETE" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Now run: .\gradlew.bat runClient" -ForegroundColor Yellow
Write-Host "Test L key and /shinobicore movement state" -ForegroundColor Yellow
Write-Host ""

exit 0