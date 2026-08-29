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
Write-Host " FIX SPRINT 5: WallDetector Direction -> Vec3d" -ForegroundColor Cyan
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
$outDir = Join-Path $Root "scripts\out\sprint5"

if (-not (Test-Path $outDir)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}

# ------------------------------------------------------------
# Fix WallDetector.java
# ------------------------------------------------------------

Write-Host ""
Write-Host "[FIX] Rewriting WallDetector.java" -ForegroundColor Yellow

$wallDetectorPath = Join-Path $srcJava "com\example\shinobicore\movement\client\WallDetector.java"

$wallDetectorContent = @'
// SHINOBICORE:SPRINT5-FIX:FILE
package com.example.shinobicore.movement.client;

import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.util.hit.BlockHitResult;
import net.minecraft.util.hit.HitResult;
import net.minecraft.util.math.Direction;
import net.minecraft.util.math.Vec3d;
import net.minecraft.world.RaycastContext;

/**
 * SPRINT 5 wall detector.
 * Performs a short horizontal raycast in the player's movement direction.
 *
 * FIX: In Yarn 1.20.1, Entity.getMovementDirection() returns Direction,
 * not Vec3d. We convert it manually.
 */
public final class WallDetector {
    public static final double WALL_REACH = 0.7;

    private WallDetector() {}

    public static Vec3d detectWallNormal(ClientPlayerEntity player) {
        if (player == null || player.getWorld() == null) {
            return null;
        }

        Direction movementDir = player.getMovementDirection();
        if (movementDir == null) {
            return null;
        }

        // Convert Direction to horizontal Vec3d
        Vec3d look = new Vec3d(
                movementDir.getOffsetX(),
                0.0,
                movementDir.getOffsetZ()
        );

        if (look.lengthSquared() < 1.0E-6) {
            return null;
        }

        look = look.normalize();

        Vec3d start = player.getPos().add(0.0, 0.25, 0.0);
        Vec3d end = start.add(look.multiply(WALL_REACH));

        BlockHitResult hit = player.getWorld().raycast(new RaycastContext(
                start,
                end,
                RaycastContext.ShapeType.COLLIDER,
                RaycastContext.FluidHandling.NONE,
                player
        ));

        if (hit == null || hit.getType() != HitResult.Type.BLOCK) {
            return null;
        }

        Vec3d normal = new Vec3d(
                hit.getSide().getOffsetX(),
                hit.getSide().getOffsetY(),
                hit.getSide().getOffsetZ()
        );

        // Ignore floors/ceilings; only vertical wall surfaces.
        if (Math.abs(normal.y) > 0.01) {
            return null;
        }

        return normal;
    }
}
'@

Write-TextFile -Path $wallDetectorPath -Content $wallDetectorContent
Write-Ok "WallDetector.java fixed"

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
Write-Host " FIX SPRINT 5 COMPLETE" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Now test:" -ForegroundColor Yellow
Write-Host "  .\gradlew.bat runClient" -ForegroundColor White
Write-Host "  L = chakra mode" -ForegroundColor White
Write-Host "  Jump toward wall + hold W" -ForegroundColor White
Write-Host ""

exit 0