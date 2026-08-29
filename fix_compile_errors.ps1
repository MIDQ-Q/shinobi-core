$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$root = "E:\Games\mod"
$srcJava = Join-Path $root "src\main\java"

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " SHINOBI CORE: FIXING COMPILATION ERRORS" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

# 1. Fix FluidTags import in WaterWalkClient.java (Yarn 1.20.1 mapping fix)
$waterPath = Join-Path $srcJava "com\example\shinobicore\movement\client\WaterWalkClient.java"
if (Test-Path $waterPath) {
    $c = [System.IO.File]::ReadAllText($waterPath, $utf8)
    $c = $c.Replace("import net.minecraft.tag.FluidTags;", "import net.minecraft.registry.tag.FluidTags;")
    [System.IO.File]::WriteAllText($waterPath, $c, $utf8)
    Write-Host " [OK] Fixed FluidTags import in WaterWalkClient.java" -ForegroundColor Green
}

# 2. Fix WallDetector import in WallRunClient.java
$wrPath = Join-Path $srcJava "com\example\shinobicore\movement\client\WallRunClient.java"
if (Test-Path $wrPath) {
    $c = [System.IO.File]::ReadAllText($wrPath, $utf8)
    $c = $c.Replace("import com.example.shinobicore.client.parkour.WallDetector;", "import com.example.shinobicore.client.parkour.util.WallDetector;")
    [System.IO.File]::WriteAllText($wrPath, $c, $utf8)
    Write-Host " [OK] Fixed WallDetector import in WallRunClient.java" -ForegroundColor Green
}

# 3. Rewrite EdgeGrabClient.java (remove WallDetector dependency, add inline ledge detection)
$egPath = Join-Path $srcJava "com\example\shinobicore\movement\client\EdgeGrabClient.java"
$egContent = @'
package com.example.shinobicore.movement.client;

import com.example.shinobicore.config.FeatureFlags;
import com.example.shinobicore.movement.common.ClientMovementState;
import com.example.shinobicore.movement.common.MovementPhase;
import com.example.shinobicore.movement.common.MovementInputService;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.util.math.BlockPos;
import net.minecraft.util.math.Vec3d;
import net.minecraft.block.BlockState;
import net.minecraft.util.math.Direction;

public final class EdgeGrabClient {
    private static boolean active = false;
    private static int ticksOnEdge = 0;
    private static int cooldown = 0;
    private static BlockPos ledgePos = null;
    
    public static boolean isActive() { return active; }
    
    public static void tick(ClientPlayerEntity player) {
        if (cooldown > 0) cooldown--;
        if (!FeatureFlags.edgeGrab) { stop(player); return; }
        
        if (active) {
            ticksOnEdge++;
            player.setVelocity(0, 0, 0);
            player.velocityModified = true;
            player.fallDistance = 0;
            
            if (MovementInputService.isMovingForward(player) || MovementInputService.wasJumpPressed()) {
                // Smooth climb
                player.addVelocity(0, 0.15, 0);
                if (ledgePos != null) {
                    player.setPosition(player.getX(), ledgePos.getY() + 0.001, player.getZ());
                }
                player.velocityModified = true;
                player.setOnGround(true);
                stop(player);
                return;
            }
            
            if (MovementInputService.isSneaking(player) || ticksOnEdge > 40) {
                stop(player);
                return;
            }
            return;
        }
        
        if (cooldown > 0 || player.isOnGround() || player.getVelocity().y > -0.1) return;
        
        // Simple inline ledge detection
        BlockPos playerPos = player.getBlockPos();
        Direction facing = Direction.fromRotation(player.getYaw());
        
        BlockPos wallPos = playerPos.offset(facing);
        BlockPos aboveWall = wallPos.up();
        BlockPos abovePlayer = playerPos.up();
        
        BlockState wallState = player.getWorld().getBlockState(wallPos);
        BlockState aboveWallState = player.getWorld().getBlockState(aboveWall);
        BlockState abovePlayerState = player.getWorld().getBlockState(abovePlayer);
        
        if (wallState.isSolidBlock(player.getWorld(), wallPos) && 
            aboveWallState.isAir() && 
            abovePlayerState.isAir()) {
            
            active = true;
            ticksOnEdge = 0;
            ledgePos = aboveWall;
            ClientMovementState.setPhase(MovementPhase.EDGE_GRABBING);
        }
    }
    
    private static void stop(ClientPlayerEntity player) {
        active = false;
        ticksOnEdge = 0;
        ledgePos = null;
        cooldown = 20;
        if (ClientMovementState.getPhase() == MovementPhase.EDGE_GRABBING) {
            ClientMovementState.setPhase(MovementPhase.NORMAL);
        }
    }
}
'@
[System.IO.File]::WriteAllText($egPath, $egContent, $utf8)
Write-Host " [OK] Rewrote EdgeGrabClient.java with inline ledge detection" -ForegroundColor Green

# 4. Create MovementInputService.java (was missing in previous script)
$inputServicePath = Join-Path $srcJava "com\example\shinobicore\movement\common\MovementInputService.java"
$inputServiceContent = @'
package com.example.shinobicore.movement.common;

import net.minecraft.client.network.ClientPlayerEntity;

public final class MovementInputService {
    private static boolean jumpPressedLastTick = false;
    private static boolean jumpPressedThisTick = false;

    public static void update(ClientPlayerEntity player) {
        jumpPressedLastTick = jumpPressedThisTick;
        jumpPressedThisTick = player.input.jumping;
    }

    public static boolean wasJumpPressed() {
        return jumpPressedThisTick && !jumpPressedLastTick;
    }

    public static boolean isJumpHeld() {
        return jumpPressedThisTick;
    }

    public static boolean isSneaking(ClientPlayerEntity player) {
        return player.input.sneaking;
    }

    public static boolean isMovingForward(ClientPlayerEntity player) {
        return player.input.pressingForward;
    }

    public static boolean isMoving(ClientPlayerEntity player) {
        return player.input.pressingForward || player.input.pressingBack 
            || player.input.pressingLeft || player.input.pressingRight;
    }

    public static float getForwardInput(ClientPlayerEntity player) {
        return player.input.movementForward;
    }

    public static float getStrafeInput(ClientPlayerEntity player) {
        return player.input.movementSideways;
    }
}
'@
$dir = Split-Path $inputServicePath -Parent
if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
[System.IO.File]::WriteAllText($inputServicePath, $inputServiceContent, $utf8)
Write-Host " [OK] Created MovementInputService.java" -ForegroundColor Green

# 5. Ensure ClientNinjaState exists in main source set
$cnStatePath = Join-Path $srcJava "com\example\shinobicore\client\ClientNinjaState.java"
if (-not (Test-Path $cnStatePath)) {
    Write-Host " [WARN] ClientNinjaState.java not found in src/main/java. Creating minimal stub." -ForegroundColor Yellow
    $cnStateContent = @'
package com.example.shinobicore.client;

public class ClientNinjaState {
    public static boolean chakraMode = false;
    public static float currentChakra = 100.0f;
}
'@
    $dir = Split-Path $cnStatePath -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [System.IO.File]::WriteAllText($cnStatePath, $cnStateContent, $utf8)
    Write-Host " [OK] Created minimal ClientNinjaState.java stub" -ForegroundColor Green
} else {
    Write-Host " [OK] ClientNinjaState.java already exists." -ForegroundColor Green
}

# 6. Update ClientMovementService to call MovementInputService.update()
$svcPath = Join-Path $srcJava "com\example\shinobicore\movement\client\ClientMovementService.java"
if (Test-Path $svcPath) {
    $c = [System.IO.File]::ReadAllText($svcPath, $utf8)
    if (-not $c.Contains("MovementInputService.update(player);")) {
        $c = $c.Replace("ClientMovementState.tickIframes();", "ClientMovementState.tickIframes();`n        MovementInputService.update(player);")
        [System.IO.File]::WriteAllText($svcPath, $c, $utf8)
        Write-Host " [OK] Updated ClientMovementService to tick MovementInputService" -ForegroundColor Green
    }
}

Write-Host "`n============================================================" -ForegroundColor Green
Write-Host " ALL COMPILATION FIXES APPLIED" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host "Now run: .\gradlew.bat build" -ForegroundColor Yellow