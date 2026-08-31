# ==============================================================================
# SHINOBICORE MOVEMENT MODULE - PHASE 3 PART 2: GROUND & AIR PARKOUR
# Generates Slide, Crawl, Roll, Dodge, DoubleJump, ChargedJump, EdgeGrab.
# Updates Controller, State, Config, and ServerMirror.
# ==============================================================================

$baseJava = "src\main\java\com\example\shinobicore\modules\movement"

# Helper: Write file with UTF-8 NO BOM
function Write-File($path, $content) {
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($path, $content, $utf8NoBom)
    Write-Host "Generated: $path" -ForegroundColor Cyan
}

# ==============================================================================
# 1. CLIENT SERVICES (Ground & Air)
# ==============================================================================

$slideJava = @'
package com.example.shinobicore.modules.movement.client;

import com.example.shinobicore.modules.movement.common.MovementActions;
import com.example.shinobicore.modules.movement.common.MovementPose;
import com.example.shinobicore.modules.movement.common.events.SlideStartedEvent;
import com.example.shinobicore.modules.movement.common.events.SlideStoppedEvent;
import com.example.shinobicore.modules.movement.config.MovementConfig;
import com.example.shinobicore.modules.movement.network.MovementPackets;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.util.math.Vec3d;

public final class SlideService {
    private static int slideTicks = 0;

    private SlideService() {}

    public static void start(ClientPlayerEntity player) {
        if (slideTicks > 0) return;
        slideTicks = MovementConfig.SLIDE_DURATION;
        ClientMovementState.setPose(MovementPose.SLIDING);
        player.setSwimming(true);
        ClientMovementController.events().publish(new SlideStartedEvent(player));
        MovementPackets.sendActionToServer(MovementActions.START_SLIDE, player.getYaw(), 0, 0);
    }

    public static void tick(ClientPlayerEntity player) {
        if (slideTicks <= 0) return;

        slideTicks--;
        Vec3d vel = player.getVelocity();
        player.setVelocity(vel.x * MovementConfig.SLIDE_FRICTION, vel.y, vel.z * MovementConfig.SLIDE_FRICTION);
        
        if (slideTicks <= 0 || player.isSneaking()) {
            stop(player);
        }
    }

    public static void stop(ClientPlayerEntity player) {
        if (slideTicks > 0 || ClientMovementState.getPose() == MovementPose.SLIDING) {
            slideTicks = 0;
            if (ClientMovementState.getPose() == MovementPose.SLIDING) {
                ClientMovementState.setPose(MovementPose.NORMAL);
            }
            player.setSwimming(false);
            ClientMovementController.events().publish(new SlideStoppedEvent(player));
            MovementPackets.sendActionToServer(MovementActions.STOP_SLIDE, player.getYaw(), 0, 0);
        }
    }
}
'@
Write-File "$baseJava\client\SlideService.java" $slideJava

$crawlJava = @'
package com.example.shinobicore.modules.movement.client;

import com.example.shinobicore.modules.movement.common.MovementPose;
import net.minecraft.client.network.ClientPlayerEntity;

public final class CrawlService {
    private CrawlService() {}

    public static void toggle(ClientPlayerEntity player) {
        if (ClientMovementState.getPose() == MovementPose.CRAWLING) {
            ClientMovementState.setPose(MovementPose.NORMAL);
            player.setSwimming(false);
        } else {
            ClientMovementState.setPose(MovementPose.CRAWLING);
            player.setSwimming(true);
        }
    }

    public static void tick(ClientPlayerEntity player) {
        if (ClientMovementState.getPose() == MovementPose.CRAWLING) {
            if (!player.isSwimming()) player.setSwimming(true);
        }
    }
}
'@
Write-File "$baseJava\client\CrawlService.java" $crawlJava

$rollJava = @'
package com.example.shinobicore.modules.movement.client;

import com.example.shinobicore.modules.movement.common.MovementActions;
import com.example.shinobicore.modules.movement.common.MovementPose;
import com.example.shinobicore.modules.movement.common.events.RollStartedEvent;
import com.example.shinobicore.modules.movement.common.events.RollStoppedEvent;
import com.example.shinobicore.modules.movement.config.MovementConfig;
import com.example.shinobicore.modules.movement.network.MovementPackets;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.util.math.Vec3d;

public final class RollService {
    private static int rollTicks = 0;
    private static int cooldown = 0;

    private RollService() {}

    public static void start(ClientPlayerEntity player) {
        if (rollTicks > 0 || cooldown > 0) return;
        
        rollTicks = MovementConfig.ROLL_DURATION;
        ClientMovementState.setPose(MovementPose.ROLLING);
        ClientMovementState.setIFrames(MovementConfig.ROLL_IFRAMES);
        
        Vec3d look = player.getRotationVector();
        Vec3d dash = look.multiply(MovementConfig.ROLL_DISTANCE / MovementConfig.ROLL_DURATION);
        player.setVelocity(dash.x, 0.1, dash.z);
        
        ClientMovementController.events().publish(new RollStartedEvent(player));
        MovementPackets.sendActionToServer(MovementActions.START_ROLL, player.getYaw(), dash.x, dash.z);
    }

    public static void tick(ClientPlayerEntity player) {
        if (cooldown > 0) cooldown--;
        if (rollTicks <= 0) return;

        rollTicks--;
        if (rollTicks <= 0) {
            ClientMovementState.setPose(MovementPose.NORMAL);
            cooldown = MovementConfig.ROLL_COOLDOWN;
            ClientMovementController.events().publish(new RollStoppedEvent(player));
            MovementPackets.sendActionToServer(MovementActions.STOP_ROLL, player.getYaw(), 0, 0);
        }
    }
}
'@
Write-File "$baseJava\client\RollService.java" $rollJava

$dodgeJava = @'
package com.example.shinobicore.modules.movement.client;

import com.example.shinobicore.core.api.ChakraApi;
import com.example.shinobicore.core.service.CoreServices;
import com.example.shinobicore.modules.movement.common.MovementActions;
import com.example.shinobicore.modules.movement.common.MovementPose;
import com.example.shinobicore.modules.movement.common.events.DodgeEvent;
import com.example.shinobicore.modules.movement.config.MovementConfig;
import com.example.shinobicore.modules.movement.network.MovementPackets;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.util.math.Vec3d;

public final class DodgeService {
    private static int cooldown = 0;

    private DodgeService() {}

    public static void start(ClientPlayerEntity player) {
        if (cooldown > 0) return;
        
        boolean hasChakra = CoreServices.get(ChakraApi.class).map(c -> 
            c.isChakraModeActive(player) && c.trySpend(player, (float) MovementConfig.DODGE_CHAKRA_COST)
        ).orElse(false);
        
        if (!hasChakra) return;

        cooldown = MovementConfig.DODGE_COOLDOWN;
        ClientMovementState.setPose(MovementPose.DODGING);
        ClientMovementState.setIFrames(MovementConfig.DODGE_IFRAMES);
        
        Vec3d look = player.getRotationVector();
        Vec3d dash = look.multiply(MovementConfig.DODGE_STRENGTH);
        player.setVelocity(dash.x, 0.0, dash.z);
        player.velocityModified = true;

        ClientMovementController.events().publish(new DodgeEvent(player, dash));
        MovementPackets.sendActionToServer(MovementActions.DODGE, player.getYaw(), dash.x, dash.z);
    }

    public static void tick(ClientPlayerEntity player) {
        if (cooldown > 0) cooldown--;
        if (ClientMovementState.getPose() == MovementPose.DODGING && cooldown < MovementConfig.DODGE_COOLDOWN - 4) {
            ClientMovementState.setPose(MovementPose.NORMAL);
        }
    }
}
'@
Write-File "$baseJava\client\DodgeService.java" $dodgeJava

$doubleJumpJava = @'
package com.example.shinobicore.modules.movement.client;

import com.example.shinobicore.modules.movement.common.MovementActions;
import com.example.shinobicore.modules.movement.common.events.DoubleJumpedEvent;
import com.example.shinobicore.modules.movement.config.MovementConfig;
import com.example.shinobicore.modules.movement.network.MovementPackets;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.util.math.Vec3d;

public final class DoubleJumpService {
    private DoubleJumpService() {}

    public static void tryJump(ClientPlayerEntity player) {
        int charges = ClientMovementState.getDoubleJumpCharges();
        if (charges <= 0) return;
        
        ClientMovementState.setDoubleJumpCharges(charges - 1);
        
        Vec3d vel = player.getVelocity();
        player.setVelocity(vel.x, MovementConfig.DOUBLE_JUMP_BOOST, vel.z);
        player.velocityModified = true;
        
        ClientMovementController.events().publish(new DoubleJumpedEvent(player));
        MovementPackets.sendActionToServer(MovementActions.DOUBLE_JUMP, player.getYaw(), vel.x, vel.z);
    }

    public static void resetOnGround(ClientPlayerEntity player) {
        if (player.isOnGround()) {
            ClientMovementState.setDoubleJumpCharges(MovementConfig.DOUBLE_JUMP_MAX_CHARGES);
        }
    }
}
'@
Write-File "$baseJava\client\DoubleJumpService.java" $doubleJumpJava

$chargedJumpJava = @'
package com.example.shinobicore.modules.movement.client;

import com.example.shinobicore.core.api.ChakraApi;
import com.example.shinobicore.core.service.CoreServices;
import com.example.shinobicore.modules.movement.common.MovementPose;
import com.example.shinobicore.modules.movement.common.events.ChargedJumpReleasedEvent;
import com.example.shinobicore.modules.movement.config.MovementConfig;
import net.minecraft.client.network.ClientPlayerEntity;

public final class ChargedJumpService {
    private static int chargeTicks = 0;
    private static boolean isCharging = false;

    private ChargedJumpService() {}

    public static void tickCharge(ClientPlayerEntity player) {
        if (isCharging) {
            chargeTicks++;
            ClientMovementState.setPose(MovementPose.CHARGING_JUMP);
            if (chargeTicks >= MovementConfig.CHARGED_JUMP_CHARGE_TICKS) {
                chargeTicks = MovementConfig.CHARGED_JUMP_CHARGE_TICKS;
            }
        }
    }

    public static void startCharge(ClientPlayerEntity player) {
        if (player.isOnGround() && player.getVelocity().horizontalLengthSquared() < 0.01) {
            isCharging = true;
            chargeTicks = 0;
        }
    }

    public static void releaseJump(ClientPlayerEntity player) {
        if (!isCharging) return;
        isCharging = false;
        
        float multiplier = 1.0f + ((float)chargeTicks / MovementConfig.CHARGED_JUMP_CHARGE_TICKS) * (MovementConfig.CHARGED_JUMP_MAX_MULT - 1.0f);
        
        boolean hasChakra = CoreServices.get(ChakraApi.class).map(c -> 
            c.isChakraModeActive(player) && c.trySpend(player, (float) MovementConfig.CHARGED_JUMP_CHAKRA_COST)
        ).orElse(false);

        if (hasChakra) {
            player.jump();
            Vec3d vel = player.getVelocity();
            player.setVelocity(vel.x, vel.y * multiplier, vel.z);
            player.velocityModified = true;
        }
        
        ClientMovementState.setPose(MovementPose.NORMAL);
        ClientMovementController.events().publish(new ChargedJumpReleasedEvent(player, chargeTicks));
        chargeTicks = 0;
    }
    
    public static float getChargeProgress() {
        return (float)chargeTicks / MovementConfig.CHARGED_JUMP_CHARGE_TICKS;
    }
}
'@
Write-File "$baseJava\client\ChargedJumpService.java" $chargedJumpJava

$edgeGrabJava = @'
package com.example.shinobicore.modules.movement.client;

import com.example.shinobicore.core.api.ChakraApi;
import com.example.shinobicore.core.service.CoreServices;
import com.example.shinobicore.modules.movement.common.MovementActions;
import com.example.shinobicore.modules.movement.common.MovementPose;
import com.example.shinobicore.modules.movement.common.events.EdgeGrabStartedEvent;
import com.example.shinobicore.modules.movement.common.events.EdgeGrabStoppedEvent;
import com.example.shinobicore.modules.movement.config.MovementConfig;
import com.example.shinobicore.modules.movement.network.MovementPackets;
import net.minecraft.block.BlockState;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.util.hit.BlockHitResult;
import net.minecraft.util.hit.HitResult;
import net.minecraft.util.math.BlockPos;
import net.minecraft.util.math.Vec3d;
import net.minecraft.world.World;

public final class EdgeGrabService {
    private static boolean isGrabbing = false;

    private EdgeGrabService() {}

    public static void tick(ClientPlayerEntity player) {
        if (isGrabbing) {
            player.setVelocity(0, 0, 0);
            return;
        }

        if (player.getVelocity().y >= 0 || player.isOnGround()) return;

        World world = player.getWorld();
        Vec3d eyePos = player.getEyePos();
        Vec3d look = player.getRotationVector();
        Vec3d end = eyePos.add(look.multiply(MovementConfig.EDGE_GRAB_REACH));

        BlockHitResult hit = world.raycast(new net.minecraft.world.RaycastContext(
            eyePos, end,
            net.minecraft.world.RaycastContext.ShapeType.COLLIDER,
            net.minecraft.world.RaycastContext.FluidHandling.NONE,
            player
        ));

        if (hit.getType() == HitResult.Type.BLOCK) {
            BlockPos hitPos = hit.getBlockPos();
            BlockPos above = hitPos.up();
            BlockState aboveState = world.getBlockState(above);
            
            if (aboveState.isAir()) {
                boolean hasChakra = CoreServices.get(ChakraApi.class).map(c -> 
                    c.isChakraModeActive(player) && c.trySpend(player, (float) MovementConfig.EDGE_GRAB_CHAKRA_COST)
                ).orElse(false);

                if (hasChakra) {
                    isGrabbing = true;
                    ClientMovementState.setPose(MovementPose.EDGE_GRABBING);
                    ClientMovementController.events().publish(new EdgeGrabStartedEvent(player));
                    MovementPackets.sendActionToServer(MovementActions.START_EDGE_GRAB, player.getYaw(), 0, 0);
                }
            }
        }
    }

    public static void climb(ClientPlayerEntity player) {
        if (!isGrabbing) return;
        isGrabbing = false;
        ClientMovementState.setPose(MovementPose.NORMAL);
        
        Vec3d vel = player.getVelocity();
        player.setVelocity(vel.x, MovementConfig.EDGE_GRAB_CLIMB_BOOST, vel.z);
        player.velocityModified = true;
        
        ClientMovementController.events().publish(new EdgeGrabStoppedEvent(player));
        MovementPackets.sendActionToServer(MovementActions.STOP_EDGE_GRAB, player.getYaw(), 0, 0);
    }

    public static void drop(ClientPlayerEntity player) {
        if (!isGrabbing) return;
        isGrabbing = false;
        ClientMovementState.setPose(MovementPose.NORMAL);
        ClientMovementController.events().publish(new EdgeGrabStoppedEvent(player));
        MovementPackets.sendActionToServer(MovementActions.STOP_EDGE_GRAB, player.getYaw(), 0, 0);
    }
}
'@
Write-File "$baseJava\client\EdgeGrabService.java" $edgeGrabJava

# ==============================================================================
# 2. UPDATE STATE, CONFIG, INPUT HANDLER, CONTROLLER
# ==============================================================================

$stateJava = @'
package com.example.shinobicore.modules.movement.client;

import com.example.shinobicore.modules.movement.common.MovementPose;

public final class ClientMovementState {
    private static MovementPose currentPose = MovementPose.NORMAL;
    private static int wallRunCooldown = 0;
    private static int doubleJumpCharges = 1;
    private static int iFrames = 0;
    private static long lastSneakPress = 0;

    private ClientMovementState() {}

    public static MovementPose getPose() { return currentPose; }
    public static void setPose(MovementPose pose) { currentPose = pose; }
    
    public static int getWallRunCooldown() { return wallRunCooldown; }
    public static void setWallRunCooldown(int ticks) { wallRunCooldown = ticks; }
    
    public static int getDoubleJumpCharges() { return doubleJumpCharges; }
    public static void setDoubleJumpCharges(int c) { doubleJumpCharges = c; }

    public static int getIFrames() { return iFrames; }
    public static void setIFrames(int ticks) { iFrames = ticks; }

    public static long getLastSneakPress() { return lastSneakPress; }
    public static void setLastSneakPress(long time) { lastSneakPress = time; }

    public static void tickCooldowns() {
        if (wallRunCooldown > 0) wallRunCooldown--;
        if (iFrames > 0) iFrames--;
    }

    public static void reset() {
        currentPose = MovementPose.NORMAL;
        wallRunCooldown = 0;
        doubleJumpCharges = 1;
        iFrames = 0;
        lastSneakPress = 0;
    }
}
'@
Write-File "$baseJava\client\ClientMovementState.java" $stateJava

$configJava = @'
package com.example.shinobicore.modules.movement.config;

import com.example.shinobicore.core.log.ShinobiLogger;
import com.google.gson.JsonObject;

public final class MovementConfig {
    public static boolean ENABLED = true;
    public static boolean DEBUG = false;
    
    public static double WATER_WALK_DRAIN = 1.5;
    public static double WATER_WALK_SURFACE_OFFSET = 0.05;
    
    public static double WALL_RUN_DRAIN = 1.5;
    public static double WALL_RUN_GRAVITY_MULT = 0.3;
    public static int WALL_RUN_COOLDOWN = 20;
    
    public static double WALL_JUMP_PUSH = 0.6;
    public static double WALL_JUMP_UP = 0.45;
    public static int WALL_JUMP_COOLDOWN = 20;
    
    public static int SLIDE_DURATION = 20;
    public static double SLIDE_FRICTION = 0.92;
    
    public static int ROLL_DURATION = 12;
    public static int ROLL_IFRAMES = 8;
    public static int ROLL_COOLDOWN = 40;
    public static double ROLL_DISTANCE = 3.0;
    
    public static double DODGE_STRENGTH = 3.2;
    public static int DODGE_IFRAMES = 4;
    public static int DODGE_COOLDOWN = 30;
    public static double DODGE_CHAKRA_COST = 2.0;
    
    public static double DOUBLE_JUMP_BOOST = 0.42;
    public static int DOUBLE_JUMP_MAX_CHARGES = 1;
    public static double DOUBLE_JUMP_CHAKRA_COST = 1.0;
    
    public static int CHARGED_JUMP_CHARGE_TICKS = 30;
    public static float CHARGED_JUMP_MAX_MULT = 2.5f;
    public static double CHARGED_JUMP_CHAKRA_COST = 3.0;
    
    public static double EDGE_GRAB_REACH = 0.6;
    public static double EDGE_GRAB_CHAKRA_COST = 1.0;
    public static double EDGE_GRAB_CLIMB_BOOST = 1.0;
    
    private MovementConfig() {}

    public static void load(JsonObject json) {
        if (json == null || json.size() == 0) {
            ShinobiLogger.module("movement", "Config empty or missing, using defaults.");
            return;
        }
        try {
            ENABLED = json.has("enabled") ? json.get("enabled").getAsBoolean() : true;
            DEBUG = json.has("debug") ? json.get("debug").getAsBoolean() : false;
            
            if (json.has("waterWalk")) {
                JsonObject ww = json.getAsJsonObject("waterWalk");
                WATER_WALK_DRAIN = ww.has("drainPerSecond") ? ww.get("drainPerSecond").getAsDouble() : 1.5;
                WATER_WALK_SURFACE_OFFSET = ww.has("surfaceOffset") ? ww.get("surfaceOffset").getAsDouble() : 0.05;
            }
            if (json.has("wallRun")) {
                JsonObject wr = json.getAsJsonObject("wallRun");
                WALL_RUN_DRAIN = wr.has("drainPerSecond") ? wr.get("drainPerSecond").getAsDouble() : 1.5;
                WALL_RUN_GRAVITY_MULT = wr.has("gravityMultiplier") ? wr.get("gravityMultiplier").getAsDouble() : 0.3;
                WALL_RUN_COOLDOWN = wr.has("stickCooldownTicks") ? wr.get("stickCooldownTicks").getAsInt() : 20;
            }
            if (json.has("wallJump")) {
                JsonObject wj = json.getAsJsonObject("wallJump");
                WALL_JUMP_PUSH = wj.has("pushStrength") ? wj.get("pushStrength").getAsDouble() : 0.6;
                WALL_JUMP_UP = wj.has("upBoost") ? wj.get("upBoost").getAsDouble() : 0.45;
                WALL_JUMP_COOLDOWN = wj.has("cooldownTicks") ? wj.get("cooldownTicks").getAsInt() : 20;
            }
            if (json.has("slide")) {
                JsonObject s = json.getAsJsonObject("slide");
                SLIDE_DURATION = s.has("durationTicks") ? s.get("durationTicks").getAsInt() : 20;
                SLIDE_FRICTION = s.has("friction") ? s.get("friction").getAsDouble() : 0.92;
            }
            if (json.has("roll")) {
                JsonObject r = json.getAsJsonObject("roll");
                ROLL_DURATION = r.has("durationTicks") ? r.get("durationTicks").getAsInt() : 12;
                ROLL_IFRAMES = r.has("iframeTicks") ? r.get("iframeTicks").getAsInt() : 8;
                ROLL_COOLDOWN = r.has("cooldownTicks") ? r.get("cooldownTicks").getAsInt() : 40;
                ROLL_DISTANCE = r.has("distance") ? r.get("distance").getAsDouble() : 3.0;
            }
            if (json.has("dodge")) {
                JsonObject d = json.getAsJsonObject("dodge");
                DODGE_STRENGTH = d.has("strength") ? d.get("strength").getAsDouble() : 3.2;
                DODGE_IFRAMES = d.has("iframeTicks") ? d.get("iframeTicks").getAsInt() : 4;
                DODGE_COOLDOWN = d.has("cooldownTicks") ? d.get("cooldownTicks").getAsInt() : 30;
                DODGE_CHAKRA_COST = d.has("chakraCost") ? d.get("chakraCost").getAsDouble() : 2.0;
            }
            if (json.has("doubleJump")) {
                JsonObject dj = json.getAsJsonObject("doubleJump");
                DOUBLE_JUMP_BOOST = dj.has("boost") ? dj.get("boost").getAsDouble() : 0.42;
                DOUBLE_JUMP_MAX_CHARGES = dj.has("maxCharges") ? dj.get("maxCharges").getAsInt() : 1;
                DOUBLE_JUMP_CHAKRA_COST = dj.has("chakraCost") ? dj.get("chakraCost").getAsDouble() : 1.0;
            }
            if (json.has("chargedJump")) {
                JsonObject cj = json.getAsJsonObject("chargedJump");
                CHARGED_JUMP_CHARGE_TICKS = cj.has("chargeTicks") ? cj.get("chargeTicks").getAsInt() : 30;
                CHARGED_JUMP_MAX_MULT = cj.has("maxMultiplier") ? cj.get("maxMultiplier").getAsFloat() : 2.5f;
                CHARGED_JUMP_CHAKRA_COST = cj.has("chakraCost") ? cj.get("chakraCost").getAsDouble() : 3.0;
            }
            if (json.has("edgeGrab")) {
                JsonObject eg = json.getAsJsonObject("edgeGrab");
                EDGE_GRAB_REACH = eg.has("reachDistance") ? eg.get("reachDistance").getAsDouble() : 0.6;
                EDGE_GRAB_CHAKRA_COST = eg.has("chakraCost") ? eg.get("chakraCost").getAsDouble() : 1.0;
                EDGE_GRAB_CLIMB_BOOST = eg.has("climbBoost") ? eg.get("climbBoost").getAsDouble() : 1.0;
            }
        } catch (Exception e) {
            ShinobiLogger.error("movement", "Failed to parse config, using defaults.", e);
        }
    }
}
'@
Write-File "$baseJava\config\MovementConfig.java" $configJava

$inputJava = @'
package com.example.shinobicore.modules.movement.client.input;

import com.example.shinobicore.modules.movement.client.*;
import com.example.shinobicore.modules.movement.common.MovementPose;
import com.example.shinobicore.modules.movement.config.MovementConfig;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.network.ClientPlayerEntity;

public final class MovementInputHandler {
    private static boolean jumpWasPressed = false;
    private static boolean sneakWasPressed = false;

    private MovementInputHandler() {}

    public static void handleInput(MinecraftClient client) {
        ClientPlayerEntity player = client.player;
        if (player == null) return;

        boolean jumpPressed = client.options.jumpKey.isPressed();
        boolean sneakPressed = client.options.sneakKey.isPressed();

        // --- Jump Logic ---
        if (jumpPressed && !jumpWasPressed) {
            if (ClientMovementState.getPose() == MovementPose.WALL_RUNNING) {
                WallJumpService.tryJump(player);
            } else if (!player.isOnGround() && player.getVelocity().y >= 0) {
                DoubleJumpService.tryJump(player);
            } else if (player.isOnGround() && player.getVelocity().horizontalLengthSquared() < 0.01) {
                ChargedJumpService.startCharge(player);
            }
        }
        
        if (!jumpPressed && jumpWasPressed) {
            ChargedJumpService.releaseJump(player);
        }
        jumpWasPressed = jumpPressed;

        // --- Sneak Logic ---
        if (sneakPressed && !sneakWasPressed) {
            long now = System.currentTimeMillis();
            if (ClientMovementState.getPose() == MovementPose.EDGE_GRABBING) {
                EdgeGrabService.drop(player);
            } else if (player.isOnGround() && player.getVelocity().horizontalLengthSquared() < 0.05) {
                if (now - ClientMovementState.getLastSneakPress() < 250) {
                    CrawlService.toggle(player);
                    ClientMovementState.setLastSneakPress(0);
                } else {
                    ClientMovementState.setLastSneakPress(now);
                }
            } else if (player.isSprinting()) {
                SlideService.start(player);
            }
        }
        sneakWasPressed = sneakPressed;

        // --- Keybinds ---
        if (MovementKeyBindings.ROLL_KEY.wasPressed()) {
            RollService.start(player);
        }
        if (MovementKeyBindings.DODGE_KEY.wasPressed()) {
            DodgeService.start(player);
        }
        
        // --- Edge Grab Climb ---
        if (jumpPressed && ClientMovementState.getPose() == MovementPose.EDGE_GRABBING) {
            EdgeGrabService.climb(player);
        }
    }
}
'@
Write-File "$baseJava\client\input\MovementInputHandler.java" $inputJava

$controllerJava = @'
package com.example.shinobicore.modules.movement.client;

import com.example.shinobicore.core.event.CoreEvents;
import com.example.shinobicore.core.log.ShinobiLogger;
import com.example.shinobicore.modules.movement.client.input.MovementInputHandler;
import net.minecraft.client.MinecraftClient;

public final class ClientMovementController {
    private static CoreEvents events;

    private ClientMovementController() {}

    public static void init(CoreEvents events) {
        ClientMovementController.events = events;
        ShinobiLogger.module("movement", "Client controller initialized.");
    }

    public static CoreEvents events() {
        if (events == null) throw new IllegalStateException("ClientMovementController not initialized with CoreEvents!");
        return events;
    }

    public static void tick() {
        MinecraftClient client = MinecraftClient.getInstance();
        if (client.player == null || client.world == null) {
            ClientMovementState.reset();
            return;
        }

        ClientMovementState.tickCooldowns();
        MovementInputHandler.handleInput(client);

        // Service ticks
        WaterWalkService.tick(client.player);
        WallRunService.tick(client.player);
        SlideService.tick(client.player);
        CrawlService.tick(client.player);
        RollService.tick(client.player);
        DodgeService.tick(client.player);
        DoubleJumpService.resetOnGround(client.player);
        ChargedJumpService.tickCharge(client.player);
        EdgeGrabService.tick(client.player);
    }
}
'@
Write-File "$baseJava\client\ClientMovementController.java" $controllerJava

# ==============================================================================
# 3. UPDATE SERVER MIRROR FOR NEW ACTIONS
# ==============================================================================

$mirrorJava = @'
package com.example.shinobicore.modules.movement.server;

import com.example.shinobicore.core.api.ChakraApi;
import com.example.shinobicore.core.log.ShinobiLogger;
import com.example.shinobicore.core.service.CoreServices;
import com.example.shinobicore.modules.movement.common.MovementActions;
import com.example.shinobicore.modules.movement.common.MovementPose;
import com.example.shinobicore.modules.movement.config.MovementConfig;
import net.minecraft.server.MinecraftServer;
import net.minecraft.server.network.ServerPlayerEntity;

import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

public final class MovementServerMirror {
    private static final Map<UUID, MovementPose> POSES = new ConcurrentHashMap<>();
    private static final Map<UUID, DrainAccumulator> DRAINS = new ConcurrentHashMap<>();

    private MovementServerMirror() {}

    public static void init() {
        ShinobiLogger.module("movement", "Server mirror initialized.");
    }

    public static void tick(MinecraftServer server) {
        for (ServerPlayerEntity p : server.getPlayerManager().getPlayerList()) {
            UUID id = p.getUuid();
            MovementPose pose = POSES.getOrDefault(id, MovementPose.NORMAL);
            
            if (pose == MovementPose.NORMAL) {
                DRAINS.remove(id);
                continue;
            }

            CoreServices.get(ChakraApi.class).ifPresent(chakra -> {
                if (!chakra.isChakraModeActive(p) || chakra.isExhausted(p)) {
                    forceStopParkour(p);
                    return;
                }

                double rate = getDrainRate(pose);
                if (rate <= 0) {
                    DRAINS.remove(id);
                    return;
                }

                DrainAccumulator acc = DRAINS.computeIfAbsent(id, k -> new DrainAccumulator(rate));
                int toSpend = acc.tick(1.0 / 20.0);
                
                if (toSpend > 0) {
                    if (!chakra.trySpend(p, toSpend)) {
                        forceStopParkour(p);
                    }
                }
            });
        }
    }

    public static void handleAction(ServerPlayerEntity player, int actionId, float yaw, double vx, double vz) {
        UUID id = player.getUuid();
        switch (actionId) {
            case MovementActions.START_WATER_WALK:
            case MovementActions.START_WALL_RUN:
            case MovementActions.START_EDGE_GRAB:
                POSES.put(id, getPoseForAction(actionId));
                break;
            case MovementActions.STOP_WATER_WALK:
            case MovementActions.STOP_WALL_RUN:
            case MovementActions.STOP_SLIDE:
            case MovementActions.STOP_ROLL:
            case MovementActions.STOP_EDGE_GRAB:
                if (POSES.getOrDefault(id, MovementPose.NORMAL) != MovementPose.NORMAL) {
                    POSES.put(id, MovementPose.NORMAL);
                }
                break;
            case MovementActions.DODGE:
                CoreServices.get(ChakraApi.class).ifPresent(c -> c.trySpend(player, (float) MovementConfig.DODGE_CHAKRA_COST));
                break;
            case MovementActions.DOUBLE_JUMP:
                CoreServices.get(ChakraApi.class).ifPresent(c -> c.trySpend(player, (float) MovementConfig.DOUBLE_JUMP_CHAKRA_COST));
                break;
        }
    }

    public static void forceStopParkour(ServerPlayerEntity player) {
        UUID id = player.getUuid();
        POSES.put(id, MovementPose.NORMAL);
        DRAINS.remove(id);
    }

    private static MovementPose getPoseForAction(int actionId) {
        return switch (actionId) {
            case MovementActions.START_WATER_WALK -> MovementPose.WATER_WALKING;
            case MovementActions.START_WALL_RUN -> MovementPose.WALL_RUNNING;
            case MovementActions.START_EDGE_GRAB -> MovementPose.EDGE_GRABBING;
            default -> MovementPose.NORMAL;
        };
    }

    private static double getDrainRate(MovementPose pose) {
        return switch (pose) {
            case WATER_WALKING -> MovementConfig.WATER_WALK_DRAIN;
            case WALL_RUNNING -> MovementConfig.WALL_RUN_DRAIN;
            default -> 0.0;
        };
    }
    
    public static void cleanupPlayer(UUID uuid) {
        POSES.remove(uuid);
        DRAINS.remove(uuid);
    }
}
'@
Write-File "$baseJava\server\MovementServerMirror.java" $mirrorJava

Write-Host "`n[SUCCESS] Phase 3 Part 2 completed: All parkour services, input handler, and server mirror updated!" -ForegroundColor Green
Write-Host "Next steps: Phase 4 (Visuals, Animations, PlayerAnimator integration) and Phase 5 (Commands & Finalization)." -ForegroundColor Yellow