# ============================================================
# SHINOBI CORE: MASTER MOVEMENT REWRITE (Steps 0-10)
# Ver 3 Architecture + Ver 1/2 Mechanics Hybrid
# ============================================================
param(
    [string]$Root = "",
    [switch]$SkipBuild
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($Root)) { $Root = $PSScriptRoot }

$srcJava = Join-Path $Root "src\main\java\com\example\shinobicore"
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Write-Step([string]$msg) {
    Write-Host "`n>> $msg" -ForegroundColor Cyan
}
function Write-Ok([string]$msg) {
    Write-Host "   [OK] $msg" -ForegroundColor Green
}
function Write-Utf8([string]$path, [string]$content) {
    $dir = Split-Path $path -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [System.IO.File]::WriteAllText($path, $content, $utf8NoBom)
}

Write-Host "============================================================" -ForegroundColor Yellow
Write-Host " SHINOBI CORE: MASTER MOVEMENT REWRITE (0-10)" -ForegroundColor Yellow
Write-Host "============================================================" -ForegroundColor Yellow

# ============================================================
# STEP 0: Feature Flags & Cleanup
# ============================================================
Write-Step "STEP 0: Updating FeatureFlags (Disabling Roll)"
$flagsPath = Join-Path $srcJava "config\FeatureFlags.java"
$flagsContent = @'
package com.example.shinobicore.config;

public class FeatureFlags {
    public static boolean combatV3 = false;
    public static boolean waterWalk = true;
    public static boolean wallRun = true;
    public static boolean slide = true;
    public static boolean crawl = true;
    public static boolean roll = false; // REMOVED
    public static boolean dodge = true;
    public static boolean chargedJump = true;
    public static boolean doubleJump = true;
    public static boolean edgeGrab = true;
    public static boolean meditation = true;
    
    public static boolean debugMovement = false;
    public static boolean debugChakra = false;
    public static boolean debugServerMirror = false;
    public static boolean chakraCommands = true;
}
'@
Write-Utf8 $flagsPath $flagsContent
Write-Ok "FeatureFlags updated (Roll disabled)"

# Stub out RollClient so nothing breaks if it's called elsewhere
$rollPath = Join-Path $srcJava "movement\client\RollClient.java"
$rollContent = @'
package com.example.shinobicore.movement.client;
import net.minecraft.client.network.ClientPlayerEntity;
public final class RollClient {
    public static boolean isActive() { return false; }
    public static void tick(ClientPlayerEntity player) {}
    public static void stop(ClientPlayerEntity player) {}
}
'@
Write-Utf8 $rollPath $rollContent
Write-Ok "RollClient stubbed out"

# ============================================================
# STEP 1: Config & State
# ============================================================
Write-Step "STEP 1: Updating ClientMovementState"
$statePath = Join-Path $srcJava "movement\common\ClientMovementState.java"
$stateContent = @'
package com.example.shinobicore.movement.common;
import net.minecraft.util.math.Vec3d;

public class ClientMovementState {
    private static MovementPhase phase = MovementPhase.NORMAL;
    private static int jumpsLeft = 3;
    private static int maxAirJumps = 2;
    private static int iframeTicks = 0;
    private static int wallCooldownTicks = 0;
    private static Vec3d wallNormal = null;
    private static boolean onWater = false;

    public static MovementPhase getPhase() { return phase; }
    public static void setPhase(MovementPhase p) { phase = p; }
    
    public static int getJumpsLeft() { return jumpsLeft; }
    public static void useAirJump() { if (jumpsLeft > 0) jumpsLeft--; }
    public static void resetAirJumps() { jumpsLeft = 3; }
    
    public static int getIframeTicks() { return iframeTicks; }
    public static void setIframeTicks(int t) { iframeTicks = t; }
    public static void tickIframes() { if (iframeTicks > 0) iframeTicks--; }
    public static boolean isInvulnerable() { return iframeTicks > 0; }
    
    public static int getWallCooldownTicks() { return wallCooldownTicks; }
    public static void setWallCooldownTicks(int t) { wallCooldownTicks = t; }
    public static void tickWallCooldown() { if (wallCooldownTicks > 0) wallCooldownTicks--; }
    
    public static Vec3d getWallNormal() { return wallNormal; }
    public static void setWallNormal(Vec3d n) { wallNormal = n; }
    
    public static boolean isOnWater() { return onWater; }
    public static void setOnWater(boolean b) { onWater = b; }
}
'@
Write-Utf8 $statePath $stateContent
Write-Ok "ClientMovementState rewritten"

# ============================================================
# STEP 2: Water Walk (Ver 2 style)
# ============================================================
Write-Step "STEP 2: WaterWalkClient (Ver 2)"
$waterPath = Join-Path $srcJava "movement\client\WaterWalkClient.java"
$waterContent = @'
package com.example.shinobicore.movement.client;

import com.example.shinobicore.config.FeatureFlags;
import com.example.shinobicore.client.ClientNinjaState;
import com.example.shinobicore.movement.common.ClientMovementState;
import com.example.shinobicore.movement.common.MovementPhase;
import com.example.shinobicore.movement.common.MovementInputService;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.util.math.Vec3d;
import net.minecraft.fluid.FluidState;
import net.minecraft.tag.FluidTags;
import net.minecraft.util.math.BlockPos;

public final class WaterWalkClient {
    private static boolean active = false;
    
    public static boolean isActive() { return active; }
    
    public static void tick(ClientPlayerEntity player) {
        if (!FeatureFlags.waterWalk) { stop(player); return; }
        
        boolean chakraMode = ClientNinjaState.chakraMode;
        boolean hasChakra = ClientNinjaState.currentChakra > 0; // Adjust to your Chakra API
        
        if (!chakraMode || !hasChakra || player.isTouchingWater() || player.isSneaking()) {
            if (active) stop(player);
            return;
        }
        
        BlockPos feet = player.getBlockPos().down();
        FluidState fs = player.getWorld().getFluidState(feet);
        boolean onWaterSurface = fs.isIn(FluidTags.WATER) && player.getY() >= feet.getY() + 0.8;
        
        if (onWaterSurface) {
            if (!active) {
                active = true;
                ClientMovementState.setPhase(MovementPhase.WATER_WALKING);
                ClientMovementState.setOnWater(true);
                ClientMovementState.resetAirJumps();
            }
            
            Vec3d v = player.getVelocity();
            if (v.y < 0.0) {
                player.setVelocity(v.x, 0.0, v.z);
                player.velocityModified = true;
            }
            player.fallDistance = 0.0f;
            
            // Jump from water
            if (MovementInputService.wasJumpPressed()) {
                player.setVelocity(v.x, 0.42, v.z);
                player.velocityModified = true;
                stop(player);
            }
        } else {
            if (active) stop(player);
        }
    }
    
    private static void stop(ClientPlayerEntity player) {
        active = false;
        ClientMovementState.setOnWater(false);
        if (ClientMovementState.getPhase() == MovementPhase.WATER_WALKING) {
            ClientMovementState.setPhase(MovementPhase.NORMAL);
        }
    }
}
'@
Write-Utf8 $waterPath $waterContent
Write-Ok "WaterWalkClient rewritten"

# ============================================================
# STEP 3: Double Jump (Ver 2 style)
# ============================================================
Write-Step "STEP 3: DoubleJumpClient (Ver 2)"
$djPath = Join-Path $srcJava "movement\client\DoubleJumpClient.java"
$djContent = @'
package com.example.shinobicore.movement.client;

import com.example.shinobicore.config.FeatureFlags;
import com.example.shinobicore.movement.common.ClientMovementState;
import com.example.shinobicore.movement.common.MovementInputService;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.util.math.Vec3d;

public final class DoubleJumpClient {
    public static void tick(ClientPlayerEntity player) {
        if (!FeatureFlags.doubleJump) return;
        
        if (player.isOnGround() || WaterWalkClient.isActive() || WallRunClient.isActive()) {
            ClientMovementState.resetAirJumps();
            return;
        }
        
        if (MovementInputService.wasJumpPressed() && ClientMovementState.getJumpsLeft() > 0) {
            Vec3d current = player.getVelocity();
            float rad = (float)Math.toRadians(player.getYaw());
            
            double forwardBoost = 1.8;
            double preserve = 0.5;
            double jumpY = 0.95;
            
            double boostX = -Math.sin(rad) * forwardBoost;
            double boostZ = Math.cos(rad) * forwardBoost;
            
            player.setVelocity(
                current.x * preserve + boostX,
                jumpY,
                current.z * preserve + boostZ
            );
            player.velocityModified = true;
            ClientMovementState.useAirJump();
        }
    }
}
'@
Write-Utf8 $djPath $djContent
Write-Ok "DoubleJumpClient rewritten"

# ============================================================
# STEP 4: Dodge (Ver 2 style, No Roll)
# ============================================================
Write-Step "STEP 4: DodgeClient & InputHandler (Ver 2)"
$dodgePath = Join-Path $srcJava "movement\client\DodgeClient.java"
$dodgeContent = @'
package com.example.shinobicore.movement.client;

import com.example.shinobicore.config.FeatureFlags;
import com.example.shinobicore.movement.common.ClientMovementState;
import com.example.shinobicore.movement.common.MovementPhase;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.util.math.Vec3d;

public final class DodgeClient {
    private static boolean active = false;
    private static int ticks = 0;
    private static int cooldown = 0;
    
    public static boolean isActive() { return active; }
    
    public static void tick(ClientPlayerEntity player) {
        if (cooldown > 0) cooldown--;
        if (!FeatureFlags.dodge) { stop(player); return; }
        
        if (active) {
            ticks++;
            if (ticks > 8) { stop(player); return; }
        }
    }
    
    public static void start(ClientPlayerEntity player, float yaw) {
        if (cooldown > 0 || !player.isOnGround()) return;
        
        active = true;
        ticks = 0;
        cooldown = 30;
        ClientMovementState.setPhase(MovementPhase.DODGING);
        ClientMovementState.setIframeTicks(8);
        
        float rad = (float)Math.toRadians(yaw);
        float strength = 1.6f;
        
        Vec3d current = player.getVelocity();
        player.setVelocity(
            current.x * 0.2 + (-Math.sin(rad) * strength),
            0.35,
            current.z * 0.2 + (Math.cos(rad) * strength)
        );
        player.velocityModified = true;
    }
    
    private static void stop(ClientPlayerEntity player) {
        active = false;
        ticks = 0;
        if (ClientMovementState.getPhase() == MovementPhase.DODGING) {
            ClientMovementState.setPhase(MovementPhase.NORMAL);
        }
    }
}
'@
Write-Utf8 $dodgePath $dodgeContent

$inputPath = Join-Path $srcJava "movement\client\RollDodgeInputHandler.java"
$inputContent = @'
package com.example.shinobicore.movement.client;

import com.example.shinobicore.movement.common.MovementInputService;
import net.minecraft.client.network.ClientPlayerEntity;

public final class RollDodgeInputHandler {
    private static long lastShiftTime = 0;
    
    public static void tick(ClientPlayerEntity player) {
        boolean shift = MovementInputService.isSneaking(player);
        long now = System.currentTimeMillis();
        
        if (shift && (now - lastShiftTime) < 250) {
            float yaw = player.getYaw();
            float forward = MovementInputService.getForwardInput(player);
            float strafe = MovementInputService.getStrafeInput(player);
            
            if (forward > 0.1f) yaw += 0;
            else if (forward < -0.1f) yaw += 180;
            else if (strafe > 0.1f) yaw += 90;
            else if (strafe < -0.1f) yaw -= 90;
            else { lastShiftTime = now; return; }
            
            DodgeClient.start(player, yaw);
            lastShiftTime = 0; // Prevent spam
        }
        
        if (shift) lastShiftTime = now;
    }
}
'@
Write-Utf8 $inputPath $inputContent
Write-Ok "Dodge & InputHandler rewritten"

# ============================================================
# STEP 5: Slide & Crawl (Ver 2 style)
# ============================================================
Write-Step "STEP 5: SlideClient & CrawlClient (Ver 2)"
$slidePath = Join-Path $srcJava "movement\client\SlideClient.java"
$slideContent = @'
package com.example.shinobicore.movement.client;

import com.example.shinobicore.config.FeatureFlags;
import com.example.shinobicore.client.ClientNinjaState;
import com.example.shinobicore.movement.common.ClientMovementState;
import com.example.shinobicore.movement.common.MovementPhase;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.entity.EntityPose;
import net.minecraft.util.math.Vec3d;

public final class SlideClient {
    private static boolean active = false;
    private static int ticks = 0;
    
    public static boolean isActive() { return active; }
    
    public static void tick(ClientPlayerEntity player) {
        if (!FeatureFlags.slide) { stop(player); return; }
        
        if (active) {
            ticks++;
            int maxTicks = ClientNinjaState.chakraMode ? 25 : 15;
            if (ticks > maxTicks || !player.isOnGround() || MovementInputService.wasJumpPressed()) {
                stop(player);
                return;
            }
            player.setPose(EntityPose.SWIMMING);
            return;
        }
        
        if (player.isOnGround() && player.isSprinting() && MovementInputService.isSneaking(player) && !CrawlClient.isActive()) {
            active = true;
            ticks = 0;
            ClientMovementState.setPhase(MovementPhase.SLIDING);
            
            float rad = (float)Math.toRadians(player.getYaw());
            float boost = ClientNinjaState.chakraMode ? 0.81f : 0.45f;
            
            Vec3d v = player.getVelocity();
            player.setVelocity(v.x + (-Math.sin(rad) * boost), 0.0, v.z + (Math.cos(rad) * boost));
            player.velocityModified = true;
        }
    }
    
    private static void stop(ClientPlayerEntity player) {
        active = false;
        ticks = 0;
        if (player != null && !CrawlClient.isActive()) player.setPose(EntityPose.STANDING);
        if (ClientMovementState.getPhase() == MovementPhase.SLIDING) {
            ClientMovementState.setPhase(MovementPhase.NORMAL);
        }
    }
}
'@
Write-Utf8 $slidePath $slideContent

$crawlPath = Join-Path $srcJava "movement\client\CrawlClient.java"
$crawlContent = @'
package com.example.shinobicore.movement.client;

import com.example.shinobicore.config.FeatureFlags;
import com.example.shinobicore.movement.common.ClientMovementState;
import com.example.shinobicore.movement.common.MovementPhase;
import com.example.shinobicore.movement.common.MovementInputService;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.entity.EntityPose;

public final class CrawlClient {
    private static boolean active = false;
    private static long lastShiftTime = 0;
    
    public static boolean isActive() { return active; }
    
    public static void tick(ClientPlayerEntity player) {
        if (!FeatureFlags.crawl) { stop(player); return; }
        
        boolean shift = MovementInputService.isSneaking(player);
        long now = System.currentTimeMillis();
        
        if (shift && (now - lastShiftTime) < 250) {
            toggle(player);
            lastShiftTime = 0;
        } else if (shift) {
            lastShiftTime = now;
        }
        
        if (active) {
            player.setPose(EntityPose.SWIMMING);
            if (!player.isOnGround()) stop(player);
        }
    }
    
    private static void toggle(ClientPlayerEntity player) {
        if (active) {
            if (player.getWorld().isSpaceEmpty(player, player.getBoundingBox().expand(0, 0.9, 0))) {
                stop(player);
            }
        } else {
            if (player.isOnGround()) {
                active = true;
                ClientMovementState.setPhase(MovementPhase.CRAWLING);
            }
        }
    }
    
    private static void stop(ClientPlayerEntity player) {
        active = false;
        if (player != null) player.setPose(EntityPose.STANDING);
        if (ClientMovementState.getPhase() == MovementPhase.CRAWLING) {
            ClientMovementState.setPhase(MovementPhase.NORMAL);
        }
    }
}
'@
Write-Utf8 $crawlPath $crawlContent
Write-Ok "Slide & Crawl rewritten"

# ============================================================
# STEP 6: Charged Jump (Ver 1 style)
# ============================================================
Write-Step "STEP 6: ChargedJumpClient (Ver 1)"
$cjPath = Join-Path $srcJava "movement\client\ChargedJumpClient.java"
$cjContent = @'
package com.example.shinobicore.movement.client;

import com.example.shinobicore.config.FeatureFlags;
import com.example.shinobicore.client.ClientNinjaState;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.util.math.Vec3d;

public final class ChargedJumpClient {
    private static boolean charging = false;
    private static int chargeTicks = 0;
    
    public static boolean isCharging() { return charging; }
    
    public static void tick(ClientPlayerEntity player) {
        if (!FeatureFlags.chargedJump) return;
        if (!ClientNinjaState.chakraMode || !player.isOnGround()) {
            charging = false;
            chargeTicks = 0;
            return;
        }
        
        boolean jumpHeld = player.input.jumping;
        
        if (jumpHeld) {
            charging = true;
            chargeTicks++;
            if (chargeTicks > 40) chargeTicks = 40;
            
            // Slow down while charging
            Vec3d v = player.getVelocity();
            player.setVelocity(v.x * 0.8, v.y, v.z * 0.8);
            player.velocityModified = true;
        } else if (charging) {
            // Release
            if (chargeTicks >= 5) {
                float ratio = (float)chargeTicks / 40.0f;
                float mult = 1.0f + (ratio * 2.0f); // Up to x3
                
                Vec3d v = player.getVelocity();
                double newY = Math.min(v.y * mult, 1.5); // Cap
                
                player.setVelocity(v.x, newY, v.z);
                player.velocityModified = true;
            }
            charging = false;
            chargeTicks = 0;
        }
    }
}
'@
Write-Utf8 $cjPath $cjContent
Write-Ok "ChargedJumpClient rewritten"

# ============================================================
# STEP 7: Edge Grab (Ver 1 style, Smooth Climb)
# ============================================================
Write-Step "STEP 7: EdgeGrabClient (Ver 1 Smooth)"
$egPath = Join-Path $srcJava "movement\client\EdgeGrabClient.java"
$egContent = @'
package com.example.shinobicore.movement.client;

import com.example.shinobicore.config.FeatureFlags;
import com.example.shinobicore.client.parkour.WallDetector;
import com.example.shinobicore.movement.common.ClientMovementState;
import com.example.shinobicore.movement.common.MovementPhase;
import com.example.shinobicore.movement.common.MovementInputService;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.util.math.Vec3d;
import net.minecraft.util.math.BlockPos;

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
        
        BlockPos ledge = WallDetector.getLedgeAbove(player);
        if (ledge != null) {
            active = true;
            ticksOnEdge = 0;
            ledgePos = ledge;
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
Write-Utf8 $egPath $egContent
Write-Ok "EdgeGrabClient rewritten"

# ============================================================
# STEP 8: Wall Run (Ver 1 style)
# ============================================================
Write-Step "STEP 8: WallRunClient (Ver 1)"
$wrPath = Join-Path $srcJava "movement\client\WallRunClient.java"
$wrContent = @'
package com.example.shinobicore.movement.client;

import com.example.shinobicore.config.FeatureFlags;
import com.example.shinobicore.client.ClientNinjaState;
import com.example.shinobicore.client.parkour.WallDetector;
import com.example.shinobicore.movement.common.ClientMovementState;
import com.example.shinobicore.movement.common.MovementPhase;
import com.example.shinobicore.movement.common.MovementInputService;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.util.math.Vec3d;

public final class WallRunClient {
    private static boolean active = false;
    private static int ticksOnWall = 0;
    private static int cooldown = 0;
    
    public static boolean isActive() { return active; }
    
    public static void tick(ClientPlayerEntity player) {
        if (cooldown > 0) cooldown--;
        ClientMovementState.tickWallCooldown();
        if (!FeatureFlags.wallRun) { stop(player); return; }
        
        boolean chakra = ClientNinjaState.chakraMode && ClientNinjaState.currentChakra > 0;
        
        if (active) {
            ticksOnWall++;
            Vec3d normal = WallDetector.getWallNormal(player);
            if (normal == null || player.isOnGround() || ticksOnWall > 40 || !player.input.pressingForward) {
                stop(player);
                return;
            }
            
            ClientMovementState.setWallNormal(normal);
            Vec3d v = player.getVelocity();
            if (v.y < 0.0) {
                player.setVelocity(v.x, Math.max(v.y, -0.02), v.z);
                player.velocityModified = true;
            }
            player.fallDistance = 0;
            
            if (MovementInputService.wasJumpPressed()) {
                player.addVelocity(normal.x * 0.6, 0.45, normal.z * 0.6);
                player.velocityModified = true;
                ClientMovementState.resetAirJumps();
                stop(player);
                cooldown = 8;
                ClientMovementState.setWallCooldownTicks(8);
            }
            return;
        }
        
        if (cooldown > 0 || player.isOnGround() || !chakra || !player.input.pressingForward) return;
        
        Vec3d normal = WallDetector.getWallNormal(player);
        if (normal != null && player.horizontalCollision) {
            Vec3d horiz = new Vec3d(player.getVelocity().x, 0, player.getVelocity().z);
            if (horiz.length() >= 0.15) {
                active = true;
                ticksOnWall = 0;
                ClientMovementState.setPhase(MovementPhase.WALL_RUNNING);
                ClientMovementState.setWallNormal(normal);
            }
        }
    }
    
    private static void stop(ClientPlayerEntity player) {
        active = false;
        ticksOnWall = 0;
        ClientMovementState.setWallNormal(null);
        if (ClientMovementState.getPhase() == MovementPhase.WALL_RUNNING) {
            ClientMovementState.setPhase(MovementPhase.NORMAL);
        }
    }
}
'@
Write-Utf8 $wrPath $wrContent
Write-Ok "WallRunClient rewritten"

# ============================================================
# STEP 9: Meditation (Ver 1 style, Toggle, No Chakra Req)
# ============================================================
Write-Step "STEP 9: MeditationClient (Ver 1 Toggle)"
$medPath = Join-Path $srcJava "movement\client\MeditationClient.java"
$medContent = @'
package com.example.shinobicore.movement.client;

import com.example.shinobicore.config.FeatureFlags;
import com.example.shinobicore.movement.common.ClientMovementState;
import com.example.shinobicore.movement.common.MovementPhase;
import com.example.shinobicore.movement.common.MovementInputService;
import net.minecraft.client.network.ClientPlayerEntity;

public final class MeditationClient {
    private static boolean active = false;
    private static long lastToggleTime = 0;
    
    public static boolean isActive() { return active; }
    
    public static void tick(ClientPlayerEntity player) {
        if (!FeatureFlags.meditation) { stop(player); return; }
        
        if (active) {
            if (MovementInputService.isMoving(player) || player.hurtTime > 0) {
                stop(player);
                return;
            }
            ClientMovementState.setPhase(MovementPhase.MEDITATING);
        }
    }
    
    // Called by Keybind (M)
    public static void toggle(ClientPlayerEntity player) {
        long now = System.currentTimeMillis();
        if (now - lastToggleTime < 200) return;
        lastToggleTime = now;
        
        if (active) {
            stop(player);
        } else {
            if (player.isOnGround() && !MovementInputService.isMoving(player)) {
                active = true;
                ClientMovementState.setPhase(MovementPhase.MEDITATING);
            }
        }
    }
    
    private static void stop(ClientPlayerEntity player) {
        active = false;
        if (ClientMovementState.getPhase() == MovementPhase.MEDITATING) {
            ClientMovementState.setPhase(MovementPhase.NORMAL);
        }
    }
}
'@
Write-Utf8 $medPath $medContent
Write-Ok "MeditationClient rewritten"

# ============================================================
# STEP 10: Master Ticker (ClientMovementService)
# ============================================================
Write-Step "STEP 10: ClientMovementService (Master Ticker)"
$svcPath = Join-Path $srcJava "movement\client\ClientMovementService.java"
$svcContent = @'
package com.example.shinobicore.movement.client;

import com.example.shinobicore.movement.common.ClientMovementState;
import com.example.shinobicore.movement.common.MovementPhase;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.network.ClientPlayerEntity;

public final class ClientMovementService {
    public static void tick(MinecraftClient client) {
        ClientPlayerEntity player = client.player;
        if (player == null) return;
        
        ClientMovementState.tickIframes();
        
        // Input
        RollDodgeInputHandler.tick(player);
        
        // Environment
        WaterWalkClient.tick(player);
        WallRunClient.tick(player);
        EdgeGrabClient.tick(player);
        
        // Jumps
        ChargedJumpClient.tick(player);
        DoubleJumpClient.tick(player);
        
        // Actions
        DodgeClient.tick(player);
        SlideClient.tick(player);
        CrawlClient.tick(player);
        MeditationClient.tick(player);
        
        // Fallback Phase Reset
        if (!WaterWalkClient.isActive() && !WallRunClient.isActive() && 
            !EdgeGrabClient.isActive() && !ChargedJumpClient.isCharging() && 
            !DodgeClient.isActive() && !SlideClient.isActive() && 
            !CrawlClient.isActive() && !MeditationClient.isActive()) {
            if (ClientMovementState.getPhase() != MovementPhase.NORMAL) {
                ClientMovementState.setPhase(MovementPhase.NORMAL);
            }
        }
    }
}
'@
Write-Utf8 $svcPath $svcContent
Write-Ok "ClientMovementService rewritten"

# ============================================================
# BUILD
# ============================================================
if (-not $SkipBuild) {
    Write-Step "Running Gradle Build..."
    Push-Location $Root
    try {
        $output = & .\gradlew.bat build 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "`n [SUCCESS] BUILD PASSED!" -ForegroundColor Green
        } else {
            Write-Host "`n [FAIL] BUILD FAILED:" -ForegroundColor Red
            $output | Select-Object -Last 20 | ForEach-Object { Write-Host "   $_" -ForegroundColor Red }
        }
    } finally {
        Pop-Location
    }
}

Write-Host "`n============================================================" -ForegroundColor Yellow
Write-Host " MASTER SCRIPT COMPLETE" -ForegroundColor Yellow
Write-Host "============================================================" -ForegroundColor Yellow
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host " 1. Run: .\gradlew.bat runClient" -ForegroundColor White
Write-Host " 2. Test Water Walk (Chakra Mode + Water)" -ForegroundColor White
Write-Host " 3. Test Double Jump (3 jumps, inertia)" -ForegroundColor White
Write-Host " 4. Test Dodge (Shift + WASD)" -ForegroundColor White
Write-Host " 5. Test Wall Run & Wall Jump" -ForegroundColor White
Write-Host " 6. Bind 'M' to MeditationClient.toggle() in your Keybinds class!" -ForegroundColor White