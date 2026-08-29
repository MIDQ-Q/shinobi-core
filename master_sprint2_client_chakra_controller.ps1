param(
    [string]$Root = "",
    [switch]$SkipBuild
)

# ============================================================
# SHINOBI CORE
# MASTER SPRINT 2: CLIENT CHAKRA CONTROLLER + SYNC
# ============================================================

$ErrorActionPreference = "Stop"
$script:utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Write-Step([string]$Message) {
    Write-Host ""
    Write-Host "[SPRINT2] $Message" -ForegroundColor Cyan
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
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $Content = $Content -replace "`r`n", "`n"
    [System.IO.File]::WriteAllText($Path, $Content, $script:utf8NoBom)
}

function Ensure-Directory([string]$Path) {
    if (-not (Test-Path $Path)) { New-Item -ItemType Directory -Path $Path -Force | Out-Null }
}

function Backup-File([string]$RelativePath, [string]$BackupDir) {
    $src = Join-Path $Root $RelativePath
    if (-not (Test-Path $src)) { return }
    $dest = Join-Path $BackupDir $RelativePath
    $destDir = Split-Path $dest -Parent
    Ensure-Directory $destDir
    Copy-Item -Path $src -Destination $dest -Force
    Write-Ok "Backed up $RelativePath"
}

function Add-ClientEntrypoint([string]$FabricPath, [string]$Entrypoint) {
    if (-not (Test-Path $FabricPath)) { return $false }
    $raw = Read-TextFile $FabricPath
    try { $json = $raw | ConvertFrom-Json } catch { return $false }

    if (-not ($json.PSObject.Properties.Name -contains "entrypoints")) {
        Add-Member -InputObject $json -MemberType NoteProperty -Name "entrypoints" -Value ([PSCustomObject]@{})
    }
    $ep = $json.entrypoints
    if (-not ($ep.PSObject.Properties.Name -contains "client")) {
        Add-Member -InputObject $ep -MemberType NoteProperty -Name "client" -Value @()
    }
    
    $clientEps = @($ep.client)
    if ($clientEps -contains $Entrypoint) { return $false }
    
    $clientEps += $Entrypoint
    $ep.client = $clientEps
    
    $newJson = $json | ConvertTo-Json -Depth 20
    Write-TextFile -Path $FabricPath -Content $newJson
    return $true
}

function Invoke-GradleBuild([string]$RootPath, [string]$LogDir) {
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
            $output | Where-Object { $_ -match "error:" } | Select-Object -First 15 | ForEach-Object {
                Write-Host " $_" -ForegroundColor Red
            }
        }
        return $false
    }
    finally { Pop-Location }
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " SHINOBI CORE - MASTER SPRINT 2" -ForegroundColor Cyan
Write-Host " Client chakra controller + tick loop + sync" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

# 1. Resolve root
if ([string]::IsNullOrWhiteSpace($Root)) { $Root = (Get-Location).Path }
if (-not (Test-Path (Join-Path $Root "gradlew.bat"))) { $Root = "E:\Games\mod" }
if (-not (Test-Path (Join-Path $Root "gradlew.bat"))) { Write-Err "Project root not found."; exit 1 }

Write-Ok "Project root: $Root"
$srcJava = Join-Path $Root "src\main\java"
$resMain = Join-Path $Root "src\main\resources"
$outDir = Join-Path $Root "scripts\out\sprint2"
Ensure-Directory $outDir

$actions = New-Object System.Collections.Generic.List[string]
$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupDir = Join-Path $Root "backup\sprint2_$stamp"

Write-Step "Creating backup"
Backup-File "src\main\resources\fabric.mod.json" $backupDir
Backup-File "src\main\java\com\example\shinobicore\network\ModPackets.java" $backupDir

# 2. Create ChakraClientController
Write-Step "Creating ChakraClientController"
$controllerPath = Join-Path $srcJava "com\example\shinobicore\chakra\client\ChakraClientController.java"
$controllerContent = @'
// SHINOBICORE:SPRINT2:FILE
package com.example.shinobicore.chakra.client;

import com.example.shinobicore.config.FeatureFlags;
import com.example.shinobicore.config.MovementChakraConfig;
import com.example.shinobicore.util.ShinobiLogger;
import net.fabricmc.fabric.api.client.event.lifecycle.v1.ClientTickEvents;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.network.ClientPlayerEntity;

/**
 * SPRINT 2 client-side chakra controller.
 * Handles tick-based regen, drain, exhaustion and mirrors state to legacy HUD.
 */
public final class ChakraClientController {
    private static float currentChakra = 2000.0f;
    private static float maxChakra = 2000.0f;
    private static float fatigue = 0.0f;
    private static boolean chakraMode = false;
    private static boolean exhausted = false;
    private static boolean meditating = false;

    private static float lastSyncedCurrent = -1.0f;
    private static boolean lastSyncedMode = false;

    private ChakraClientController() {}

    public static void register() {
        ClientTickEvents.END_CLIENT_TICK.register(ChakraClientController::tickClient);
    }

    public static void tickClient(MinecraftClient client) {
        if (!FeatureFlags.chakraV3) return;
        if (client == null || client.player == null || client.world == null) return;
        if (client.isPaused()) return;

        ClientPlayerEntity player = client.player;
        MovementChakraConfig config = MovementChakraConfig.getInstance();
        if (config == null || config.chakra == null) return;

        maxChakra = config.chakra.baseMaxChakra;

        // 1. Passive regen (if not exhausted and not in active drain mode)
        if (!exhausted && !chakraMode) {
            float regen = config.chakra.chakraRegenPerSec / 20.0f;
            if (meditating) regen *= config.chakra.meditationRegenMultiplier;
            currentChakra = Math.min(maxChakra, currentChakra + regen);
        }

        // 2. Active drain (chakra mode)
        if (chakraMode && !exhausted) {
            float drain = config.chakra.chakraModeDrainPerSec / 20.0f;
            currentChakra -= drain;
        }

        // 3. Exhaustion check
        if (currentChakra <= 0.0f) {
            currentChakra = 0.0f;
            if (chakraMode) {
                chakraMode = false;
                exhausted = true;
                ShinobiLogger.info("[CHAKRA] Exhausted! Mode disabled.");
            }
        }

        // 4. Sync to server (only if changed significantly to save bandwidth)
        boolean needsSync = false;
        if (Math.abs(currentChakra - lastSyncedCurrent) > 1.0f || chakraMode != lastSyncedMode) {
            needsSync = true;
        }

        if (needsSync) {
            try {
                // Safe reflection call to ModPackets.sendChakraUpdate
                Class<?> packets = Class.forName("com.example.shinobicore.network.ModPackets");
                java.lang.reflect.Method m = packets.getMethod("sendChakraUpdate", float.class, float.class, float.class, boolean.class, boolean.class);
                m.invoke(null, currentChakra, maxChakra, fatigue, chakraMode, exhausted);
            } catch (Exception ignored) {}
            
            lastSyncedCurrent = currentChakra;
            lastSyncedMode = chakraMode;
        }

        // 5. Mirror to legacy HUD/State via reflection (safe fallback)
        mirrorToLegacySystems();
    }

    private static void mirrorToLegacySystems() {
        try {
            Class<?> stateClass = Class.forName("com.example.shinobicore.client.ClientNinjaState");
            stateClass.getField("chakraMode").setBoolean(null, chakraMode);
        } catch (Exception ignored) {}

        try {
            Class<?> hudClass = Class.forName("com.example.shinobicore.client.hud.ChakraHudRenderer");
            hudClass.getField("currentChakra").setFloat(null, currentChakra);
            hudClass.getField("maxChakra").setFloat(null, maxChakra);
            hudClass.getField("exhausted").setBoolean(null, exhausted);
        } catch (Exception ignored) {}
    }

    public static void toggleChakraMode() {
        if (exhausted) {
            if (currentChakra >= maxChakra * 0.5f) {
                exhausted = false; // Recover from exhaustion if half full
            } else {
                return;
            }
        }
        chakraMode = !chakraMode;
    }

    public static float getCurrentChakra() { return currentChakra; }
    public static float getMaxChakra() { return maxChakra; }
    public static boolean isChakraMode() { return chakraMode; }
    public static boolean isExhausted() { return exhausted; }
    
    public static void setMeditating(boolean state) { meditating = state; }
}
'@
Write-TextFile -Path $controllerPath -Content $controllerContent
Write-Ok "Wrote ChakraClientController.java"
$actions.Add("Created ChakraClientController.java")

# 3. Create Sprint2ClientBootstrap
Write-Step "Creating Sprint2ClientBootstrap"
$bootstrapPath = Join-Path $srcJava "com\example\shinobicore\bootstrap\Sprint2ClientBootstrap.java"
$bootstrapContent = @'
// SHINOBICORE:SPRINT2:FILE
package com.example.shinobicore.bootstrap;

import com.example.shinobicore.chakra.client.ChakraClientController;
import com.example.shinobicore.config.FeatureFlags;
import com.example.shinobicore.util.ShinobiLogger;
import net.fabricmc.api.ClientModInitializer;

public class Sprint2ClientBootstrap implements ClientModInitializer {
    @Override
    public void onInitializeClient() {
        if (!FeatureFlags.chakraV3) {
            ShinobiLogger.info("[SPRINT2] chakraV3 flag disabled, skipping client bootstrap");
            return;
        }
        ChakraClientController.register();
        ShinobiLogger.info("[SPRINT2] Client chakra controller registered");
    }
}
'@
Write-TextFile -Path $bootstrapPath -Content $bootstrapContent
Write-Ok "Wrote Sprint2ClientBootstrap.java"
$actions.Add("Created Sprint2ClientBootstrap.java")

# 4. Add sendChakraUpdate stub to ModPackets
Write-Step "Adding sendChakraUpdate stub to ModPackets"
$packetsPath = Join-Path $srcJava "com\example\shinobicore\network\ModPackets.java"
if (Test-Path $packetsPath) {
    $pContent = Read-TextFile $packetsPath
    if (-not $pContent.Contains("public static void sendChakraUpdate(")) {
        $stub = "`n    public static void sendChakraUpdate(float current, float max, float fatigue, boolean mode, boolean exhausted) {`n        // SPRINT 2 no-op stub for client sync.`n    }`n}"
        $pContent = $pContent -replace "(\s*)\}\s*$", "$stub"
        Write-TextFile -Path $packetsPath -Content $pContent
        Write-Ok "Added sendChakraUpdate stub"
        $actions.Add("Added sendChakraUpdate stub")
    } else {
        Write-Ok "sendChakraUpdate already present"
    }
}

# 5. Register client entrypoint
Write-Step "Registering Sprint2ClientBootstrap in fabric.mod.json"
$fmjPath = Join-Path $resMain "fabric.mod.json"
$entrypoint = "com.example.shinobicore.bootstrap.Sprint2ClientBootstrap"
if (Add-ClientEntrypoint -FabricPath $fmjPath -Entrypoint $entrypoint) {
    Write-Ok "Registered client entrypoint"
    $actions.Add("Registered client entrypoint")
} else {
    Write-Ok "Client entrypoint already registered"
}

# 6. Build
if (-not $SkipBuild) {
    Write-Step "Running Gradle build"
    $buildOk = Invoke-GradleBuild -RootPath $Root -LogDir $outDir
    if (-not $buildOk) {
        Write-Err "Sprint 2 failed build."
        exit 1
    }
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host " MASTER SPRINT 2 COMPLETE" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
exit 0