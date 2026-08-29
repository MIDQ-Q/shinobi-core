param(
    [string]$Root = "",
    [switch]$SkipBuild
)

# ============================================================
# SHINOBI CORE
# MASTER SPRINT 4: MOVEMENT FOUNDATION + WATER WALK
# ============================================================

$ErrorActionPreference = "Stop"
$script:utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Write-Step([string]$Message) {
    Write-Host ""
    Write-Host "[SPRINT4] $Message" -ForegroundColor Cyan
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
    
    $list = @($ep.client)
    if ($list -contains $Entrypoint) { return $false }
    
    $list += $Entrypoint
    $ep.client = $list
    
    $newJson = $json | ConvertTo-Json -Depth 20
    Write-TextFile -Path $FabricPath -Content $newJson
    return $true
}

function Add-MixinEntry([string]$MixinsPath, [string]$MixinClass) {
    if (-not (Test-Path $MixinsPath)) { return $false }
    $raw = Read-TextFile $MixinsPath
    try {
        $json = $raw | ConvertFrom-Json
        if (-not ($json.PSObject.Properties.Name -contains "client")) {
            Add-Member -InputObject $json -MemberType NoteProperty -Name "client" -Value @()
        }
        
        $list = @($json.client)
        if ($list -contains $MixinClass) { return $false }
        
        $list += $MixinClass
        $json.client = $list
        
        $newJson = $json | ConvertTo-Json -Depth 20
        Write-TextFile -Path $MixinsPath -Content $newJson
        return $true
    }
    catch {
        Write-Warn "Could not parse mixins.json, skipping mixin registration"
        return $false
    }
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
Write-Host " SHINOBI CORE - MASTER SPRINT 4" -ForegroundColor Cyan
Write-Host " Movement foundation + Water Walk" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

# 1. Resolve root
if ([string]::IsNullOrWhiteSpace($Root)) { $Root = (Get-Location).Path }
if (-not (Test-Path (Join-Path $Root "gradlew.bat"))) { $Root = "E:\Games\mod" }
if (-not (Test-Path (Join-Path $Root "gradlew.bat"))) { Write-Err "Project root not found."; exit 1 }

Write-Ok "Project root: $Root"
$srcJava = Join-Path $Root "src\main\java"
$resMain = Join-Path $Root "src\main\resources"
$outDir = Join-Path $Root "scripts\out\sprint4"
Ensure-Directory $outDir

$actions = New-Object System.Collections.Generic.List[string]
$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupDir = Join-Path $Root "backup\sprint4_$stamp"

Write-Step "Creating backup"
Backup-File "src\main\resources\fabric.mod.json" $backupDir
Backup-File "src\main\resources\shinobicore.mixins.json" $backupDir

# 2. Create MovementInputService
Write-Step "Creating MovementInputService"
$inputServicePath = Join-Path $srcJava "com\example\shinobicore\movement\client\MovementInputService.java"
$inputServiceContent = @'
// SHINOBICORE:SPRINT4:FILE
package com.example.shinobicore.movement.client;

import net.minecraft.client.network.ClientPlayerEntity;

/**
 * SPRINT 4 safe input service.
 */
public final class MovementInputService {
    private MovementInputService() {}

    public static boolean isSneaking(ClientPlayerEntity player) {
        return player != null && player.isSneaking();
    }

    public static boolean isSprinting(ClientPlayerEntity player) {
        return player != null && player.isSprinting();
    }
}
'@
Write-TextFile -Path $inputServicePath -Content $inputServiceContent
Write-Ok "Created MovementInputService.java"
$actions.Add("Created MovementInputService.java")

# 3. Create ClientMovementService
Write-Step "Creating ClientMovementService"
$moveServicePath = Join-Path $srcJava "com\example\shinobicore\movement\client\ClientMovementService.java"
$moveServiceContent = @'
// SHINOBICORE:SPRINT4:FILE
package com.example.shinobicore.movement.client;

import com.example.shinobicore.config.FeatureFlags;
import com.example.shinobicore.movement.common.MovementPhase;
import net.fabricmc.fabric.api.client.event.lifecycle.v1.ClientTickEvents;
import net.minecraft.client.MinecraftClient;

/**
 * SPRINT 4 central client movement tick handler.
 */
public final class ClientMovementService {
    private static boolean registered = false;

    private ClientMovementService() {}

    public static void register() {
        if (registered) return;
        registered = true;
        ClientTickEvents.END_CLIENT_TICK.register(ClientMovementService::tickClient);
    }

    private static void tickClient(MinecraftClient client) {
        if (!FeatureFlags.movementV3) return;
        if (client == null || client.player == null || client.world == null) return;
        if (client.isPaused()) return;

        // Update state timers
        ClientMovementState.tick();

        // Tick subsystems
        WaterWalkClient.tick(client.player);
        // Future: WallRunClient.tick(...), SlideClient.tick(...), etc.

        // If no subsystem is active, reset phase to NORMAL
        if (!WaterWalkClient.isActive()) {
            if (ClientMovementState.getPhase() != MovementPhase.NORMAL) {
                ClientMovementState.setPhase(MovementPhase.NORMAL);
            }
        }
    }
}
'@
Write-TextFile -Path $moveServicePath -Content $moveServiceContent
Write-Ok "Created ClientMovementService.java"
$actions.Add("Created ClientMovementService.java")

# 4. Create WaterWalkClient
Write-Step "Creating WaterWalkClient"
$waterWalkPath = Join-Path $srcJava "com\example\shinobicore\movement\client\WaterWalkClient.java"
$waterWalkContent = @'
// SHINOBICORE:SPRINT4:FILE
package com.example.shinobicore.movement.client;

import com.example.shinobicore.chakra.client.ChakraClientController;
import com.example.shinobicore.config.FeatureFlags;
import com.example.shinobicore.config.MovementChakraConfig;
import com.example.shinobicore.movement.common.MovementPhase;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.registry.tag.FluidTags;
import net.minecraft.util.math.BlockPos;
import net.minecraft.util.math.Vec3d;

/**
 * SPRINT 4 water walking subsystem.
 */
public final class WaterWalkClient {
    private static boolean active = false;

    private WaterWalkClient() {}

    public static boolean isActive() { return active; }

    public static void tick(ClientPlayerEntity player) {
        if (!FeatureFlags.waterWalk) {
            setActive(false);
            return;
        }

        if (!ChakraClientController.isChakraModeActive()) {
            setActive(false);
            return;
        }

        boolean onWaterSurface = isOnWaterSurface(player);

        if (onWaterSurface && !MovementInputService.isSneaking(player)) {
            if (!active) {
                setActive(true);
                ClientMovementState.setPhase(MovementPhase.WATER_WALKING);
            }

            // Drain chakra
            MovementChakraConfig config = MovementChakraConfig.getInstance();
            float drain = config.chakra.waterWalkDrainPerTick;
            ChakraClientController.consumeChakra(drain);

            // Stabilize: prevent sinking below water surface
            Vec3d vel = player.getVelocity();
            if (vel.y < 0.0) {
                player.setVelocity(vel.x, 0.0, vel.z);
                player.velocityModified = true;
            }

            // Prevent fall damage
            player.fallDistance = 0.0f;
        } else {
            if (active) {
                setActive(false);
                ClientMovementState.setPhase(MovementPhase.NORMAL);
            }
        }
    }

    private static boolean isOnWaterSurface(ClientPlayerEntity player) {
        BlockPos pos = player.getBlockPos();
        BlockPos below = pos.down();

        if (player.getWorld().getFluidState(below).isIn(FluidTags.WATER)) {
            double playerY = player.getY();
            double waterSurfaceY = below.getY() + 1.0;
            return Math.abs(playerY - waterSurfaceY) < 0.3;
        }

        return false;
    }

    private static void setActive(boolean value) { active = value; }
}
'@
Write-TextFile -Path $waterWalkPath -Content $waterWalkContent
Write-Ok "Created WaterWalkClient.java"
$actions.Add("Created WaterWalkClient.java")

# 5. Create PlayerWaterWalkMixin
Write-Step "Creating PlayerWaterWalkMixin"
$mixinPath = Join-Path $srcJava "com\example\shinobicore\mixin\PlayerWaterWalkMixin.java"
$mixinContent = @'
// SHINOBICORE:SPRINT4:FILE
package com.example.shinobicore.mixin;

import com.example.shinobicore.movement.client.WaterWalkClient;
import net.minecraft.entity.Entity;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfoReturnable;

/**
 * SPRINT 4 water walk mixin.
 * Bypasses vanilla water physics when water walking is active.
 */
@Mixin(Entity.class)
public abstract class PlayerWaterWalkMixin {

    @Inject(method = "isTouchingWater", at = @At("HEAD"), cancellable = true)
    private void shinobicore_bypassWaterTouch(CallbackInfoReturnable<Boolean> cir) {
        if (WaterWalkClient.isActive()) {
            cir.setReturnValue(false);
        }
    }
}
'@
Write-TextFile -Path $mixinPath -Content $mixinContent
Write-Ok "Created PlayerWaterWalkMixin.java"
$actions.Add("Created PlayerWaterWalkMixin.java")

# 6. Register mixin in shinobicore.mixins.json
Write-Step "Registering mixin in shinobicore.mixins.json"
$mixinsJsonPath = Join-Path $resMain "shinobicore.mixins.json"
if (Add-MixinEntry -MixinsPath $mixinsJsonPath -MixinClass "com.example.shinobicore.mixin.PlayerWaterWalkMixin") {
    Write-Ok "Registered PlayerWaterWalkMixin in mixins.json"
    $actions.Add("Registered PlayerWaterWalkMixin")
} else {
    Write-Ok "Mixin already registered"
}

# 7. Create Sprint4ClientBootstrap
Write-Step "Creating Sprint4ClientBootstrap"
$bootstrapPath = Join-Path $srcJava "com\example\shinobicore\bootstrap\Sprint4ClientBootstrap.java"
$bootstrapContent = @'
// SHINOBICORE:SPRINT4:FILE
package com.example.shinobicore.bootstrap;

import com.example.shinobicore.config.FeatureFlags;
import com.example.shinobicore.movement.client.ClientMovementService;
import com.example.shinobicore.util.ShinobiLogger;
import net.fabricmc.api.ClientModInitializer;

/**
 * SPRINT 4 client-side bootstrap.
 * Registers movement services and subsystems.
 */
public class Sprint4ClientBootstrap implements ClientModInitializer {
    @Override
    public void onInitializeClient() {
        if (!FeatureFlags.movementV3) {
            ShinobiLogger.info("[SPRINT4] movementV3 flag disabled, skipping client bootstrap");
            return;
        }

        ClientMovementService.register();
        ShinobiLogger.info("[SPRINT4] Client movement service registered (Water Walk foundation)");
    }
}
'@
Write-TextFile -Path $bootstrapPath -Content $bootstrapContent
Write-Ok "Created Sprint4ClientBootstrap.java"
$actions.Add("Created Sprint4ClientBootstrap.java")

# 8. Register client entrypoint in fabric.mod.json
Write-Step "Registering Sprint4ClientBootstrap in fabric.mod.json"
$fmjPath = Join-Path $resMain "fabric.mod.json"
if (Add-ClientEntrypoint -FabricPath $fmjPath -Entrypoint "com.example.shinobicore.bootstrap.Sprint4ClientBootstrap") {
    Write-Ok "Registered Sprint4ClientBootstrap"
    $actions.Add("Registered Sprint4ClientBootstrap")
} else {
    Write-Ok "Sprint4ClientBootstrap already registered"
}

# 9. Build
if (-not $SkipBuild) {
    Write-Step "Running Gradle build"
    $buildOk = Invoke-GradleBuildDetailed -RootPath $Root -LogDir $outDir
    if (-not $buildOk) {
        Write-Err "Sprint 4 failed build."
        exit 1
    }
}

# 10. Report
Write-Step "Generating Sprint 4 report"
$report = New-Object System.Text.StringBuilder
[void]$report.AppendLine("SHINOBI CORE - SPRINT 4 REPORT")
[void]$report.AppendLine("Generated: " + (Get-Date -Format "yyyy-MM-dd HH:mm:ss"))
[void]$report.AppendLine("")
[void]$report.AppendLine("=== ACTIONS ===")
foreach ($a in $actions) { [void]$report.AppendLine($a) }

$reportPath = Join-Path $outDir "sprint4_report.txt"
Write-TextFile -Path $reportPath -Content $report.ToString()
Write-Ok "Report saved: $reportPath"

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host " MASTER SPRINT 4 COMPLETE" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Test in-game:" -ForegroundColor Yellow
Write-Host "  1. Enable Chakra Mode with L" -ForegroundColor White
Write-Host "  2. Walk onto water surface" -ForegroundColor White
Write-Host "  3. You should not sink while Chakra Mode is active" -ForegroundColor White
Write-Host "  4. Sneak to fall into water" -ForegroundColor White
Write-Host ""
Write-Host "Next step: MASTER SPRINT 5 (Wall Run foundation)" -ForegroundColor Yellow
Write-Host ""

exit 0