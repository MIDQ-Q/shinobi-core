# ==============================================================================
# SHINOBICORE MOVEMENT MODULE - PHASE 3: CLIENT SERVICES & DETECTORS
# Generates events, detectors, and core parkour services.
# ==============================================================================

$baseJava = "src\main\java\com\example\shinobicore\modules\movement"

# Helper: Write file with UTF-8 NO BOM
function Write-File($path, $content) {
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($path, $content, $utf8NoBom)
    Write-Host "Generated: $path" -ForegroundColor Cyan
}

# Create events directory
$eventsDir = "$baseJava\common\events"
if (-not (Test-Path $eventsDir)) { New-Item -ItemType Directory -Path $eventsDir -Force | Out-Null }

# ==============================================================================
# 1. GENERATE EVENTS (TZ 4.4)
# ==============================================================================
$events = @(
    "WaterWalkStartedEvent|PlayerEntity player",
    "WaterWalkStoppedEvent|PlayerEntity player",
    "WallRunStartedEvent|PlayerEntity player, Vec3d normal",
    "WallRunStoppedEvent|PlayerEntity player",
    "WallJumpedEvent|PlayerEntity player, Vec3d normal",
    "SlideStartedEvent|PlayerEntity player",
    "SlideStoppedEvent|PlayerEntity player",
    "RollStartedEvent|PlayerEntity player",
    "RollStoppedEvent|PlayerEntity player",
    "DodgeEvent|PlayerEntity player, Vec3d direction",
    "DoubleJumpedEvent|PlayerEntity player",
    "ChargedJumpReleasedEvent|PlayerEntity player, float chargeTime",
    "EdgeGrabStartedEvent|PlayerEntity player",
    "EdgeGrabStoppedEvent|PlayerEntity player"
)

foreach ($evt in $events) {
    $parts = $evt -split '\|'
    $name = $parts[0]
    $params = $parts[1]
    
    $imports = "import net.minecraft.entity.player.PlayerEntity;`n"
    if ($params -match "Vec3d") { $imports += "import net.minecraft.util.math.Vec3d;`n" }
    
    $content = @"
package com.example.shinobicore.modules.movement.common.events;

$imports
public record $name($params) {}
"@
    Write-File "$eventsDir\$name.java" $content
}

# ==============================================================================
# 2. DETECTORS (TZ 14.1, 14.2)
# ==============================================================================

$waterDetectorJava = @'
package com.example.shinobicore.modules.movement.client.util;

import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.fluid.Fluids;
import net.minecraft.util.math.BlockPos;
import net.minecraft.world.World;

import java.util.Optional;

public final class WaterSurfaceDetector {
    private WaterSurfaceDetector() {}

    public static Optional<Double> getSurfaceY(ClientPlayerEntity player) {
        World world = player.getWorld();
        BlockPos feet = player.getBlockPos();
        
        for (int dy = 0; dy >= -2; dy--) {
            BlockPos check = feet.down(-dy);
            var fs = world.getFluidState(check);
            
            if (!fs.isEmpty() && (fs.isOf(Fluids.WATER) || fs.isOf(Fluids.FLOWING_WATER))) {
                double surfaceY = check.getY() + fs.getHeight(world, check);
                double playerFeetY = player.getY();
                
                if (playerFeetY >= surfaceY - 0.05 && playerFeetY <= surfaceY + 0.25) {
                    return Optional.of(surfaceY);
                }
            }
        }
        return Optional.empty();
    }
}
'@
Write-File "$baseJava\client\util\WaterSurfaceDetector.java" $waterDetectorJava

$wallDetectorJava = @'
package com.example.shinobicore.modules.movement.client.util;

import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.util.hit.BlockHitResult;
import net.minecraft.util.hit.HitResult;
import net.minecraft.util.math.Vec3d;
import net.minecraft.world.RaycastContext;
import net.minecraft.world.World;

public final class WallDetector {
    private static final double RAYCAST_DIST = 0.6;
    private static final int[][] DIRS = {{1,0},{-1,0},{0,1},{0,-1}};

    private WallDetector() {}

    public static Vec3d getWallNormal(ClientPlayerEntity player) {
        World world = player.getWorld();
        Vec3d feet = player.getPos().add(0, 0.2, 0);
        Vec3d body = player.getPos().add(0, 1.2, 0);

        for (int[] d : DIRS) {
            Vec3d dir = new Vec3d(d[0], 0, d[1]);
            if (hitsWall(world, feet, dir)) return new Vec3d(-d[0], 0, -d[1]);
            if (hitsWall(world, body, dir)) return new Vec3d(-d[0], 0, -d[1]);
        }
        return null;
    }

    private static boolean hitsWall(World world, Vec3d origin, Vec3d dir) {
        Vec3d end = origin.add(dir.multiply(RAYCAST_DIST));
        BlockHitResult hit = world.raycast(new RaycastContext(
            origin, end,
            RaycastContext.ShapeType.COLLIDER,
            RaycastContext.FluidHandling.NONE,
            null
        ));
        return hit.getType() != HitResult.Type.MISS;
    }
}
'@
Write-File "$baseJava\client\util\WallDetector.java" $wallDetectorJava

# ==============================================================================
# 3. SERVICES
# ==============================================================================

$waterWalkJava = @'
package com.example.shinobicore.modules.movement.client;

import com.example.shinobicore.core.api.ChakraApi;
import com.example.shinobicore.core.service.CoreServices;
import com.example.shinobicore.modules.movement.client.util.WaterSurfaceDetector;
import com.example.shinobicore.modules.movement.common.MovementActions;
import com.example.shinobicore.modules.movement.common.MovementPose;
import com.example.shinobicore.modules.movement.common.events.WaterWalkStartedEvent;
import com.example.shinobicore.modules.movement.common.events.WaterWalkStoppedEvent;
import com.example.shinobicore.modules.movement.config.MovementConfig;
import com.example.shinobicore.modules.movement.network.MovementPackets;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.util.math.Vec3d;

import java.util.Optional;

public final class WaterWalkService {
    private static boolean wasWalking = false;

    private WaterWalkService() {}

    public static void tick(ClientPlayerEntity player) {
        if (!MovementConfig.ENABLED) return;

        boolean canWalk = checkConditions(player);
        Optional<Double> surfaceY = WaterSurfaceDetector.getSurfaceY(player);

        if (canWalk && surfaceY.isPresent()) {
            if (!wasWalking) {
                wasWalking = true;
                ClientMovementState.setPose(MovementPose.WATER_WALKING);
                ClientMovementController.events().publish(new WaterWalkStartedEvent(player));
                MovementPackets.sendActionToServer(MovementActions.START_WATER_WALK, player.getYaw(), player.getVelocity().x, player.getVelocity().z);
            }

            double targetY = surfaceY.get() + MovementConfig.WATER_WALK_SURFACE_OFFSET;
            Vec3d vel = player.getVelocity();
            
            player.setVelocity(vel.x, 0.0, vel.z);
            player.setPosition(player.getX(), targetY, player.getZ());
            player.fallDistance = 0.0f;
            player.setSwimming(false);
        } else {
            if (wasWalking) {
                wasWalking = false;
                if (ClientMovementState.getPose() == MovementPose.WATER_WALKING) {
                    ClientMovementState.setPose(MovementPose.NORMAL);
                }
                ClientMovementController.events().publish(new WaterWalkStoppedEvent(player));
                MovementPackets.sendActionToServer(MovementActions.STOP_WATER_WALK, player.getYaw(), 0, 0);
            }
        }
    }

    private static boolean checkConditions(ClientPlayerEntity player) {
        if (player.isSneaking() || player.isSwimming() || player.isTouchingWater()) return false;
        
        return CoreServices.get(ChakraApi.class).map(chakra -> 
            chakra.isChakraModeActive(player) && 
            chakra.getCurrent(player) > 0 && 
            !chakra.isExhausted(player)
        ).orElse(false);
    }
}
'@
Write-File "$baseJava\client\WaterWalkService.java" $waterWalkJava

$wallRunJava = @'
package com.example.shinobicore.modules.movement.client;

import com.example.shinobicore.core.api.ChakraApi;
import com.example.shinobicore.core.service.CoreServices;
import com.example.shinobicore.modules.movement.client.util.WallDetector;
import com.example.shinobicore.modules.movement.common.MovementActions;
import com.example.shinobicore.modules.movement.common.MovementPose;
import com.example.shinobicore.modules.movement.common.events.WallRunStartedEvent;
import com.example.shinobicore.modules.movement.common.events.WallRunStoppedEvent;
import com.example.shinobicore.modules.movement.config.MovementConfig;
import com.example.shinobicore.modules.movement.network.MovementPackets;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.util.math.Vec3d;

public final class WallRunService {
    private static boolean wasRunning = false;
    private static Vec3d currentNormal = null;

    private WallRunService() {}

    public static void tick(ClientPlayerEntity player) {
        if (!MovementConfig.ENABLED) return;
        if (player.isOnGround()) {
            stopWallRun(player);
            return;
        }

        boolean canRun = checkConditions(player);
        Vec3d normal = WallDetector.getWallNormal(player);

        if (canRun && normal != null && ClientMovementState.getWallRunCooldown() <= 0) {
            if (!wasRunning) {
                wasRunning = true;
                currentNormal = normal;
                ClientMovementState.setPose(MovementPose.WALL_RUNNING);
                ClientMovementController.events().publish(new WallRunStartedEvent(player, normal));
                MovementPackets.sendActionToServer(MovementActions.START_WALL_RUN, player.getYaw(), player.getVelocity().x, player.getVelocity().z);
            }
            currentNormal = normal;

            Vec3d vel = player.getVelocity();
            double dot = vel.dotProduct(normal);
            if (dot < 0) {
                vel = vel.subtract(normal.multiply(dot));
                player.setVelocity(vel);
            }

            if (vel.y < 0) {
                player.setVelocity(vel.x, vel.y * MovementConfig.WALL_RUN_GRAVITY_MULT, vel.z);
            }
            
            player.fallDistance = 0.0f;
        } else {
            stopWallRun(player);
        }
    }

    private static void stopWallRun(ClientPlayerEntity player) {
        if (wasRunning) {
            wasRunning = false;
            currentNormal = null;
            if (ClientMovementState.getPose() == MovementPose.WALL_RUNNING) {
                ClientMovementState.setPose(MovementPose.NORMAL);
            }
            ClientMovementState.setWallRunCooldown(MovementConfig.WALL_RUN_COOLDOWN);
            ClientMovementController.events().publish(new WallRunStoppedEvent(player));
            MovementPackets.sendActionToServer(MovementActions.STOP_WALL_RUN, player.getYaw(), 0, 0);
        }
    }

    public static Vec3d getCurrentNormal() { return currentNormal; }

    private static boolean checkConditions(ClientPlayerEntity player) {
        return CoreServices.get(ChakraApi.class).map(chakra -> 
            chakra.isChakraModeActive(player) && 
            chakra.getCurrent(player) > 0 && 
            !chakra.isExhausted(player)
        ).orElse(false);
    }
}
'@
Write-File "$baseJava\client\WallRunService.java" $wallRunJava

$wallJumpJava = @'
package com.example.shinobicore.modules.movement.client;

import com.example.shinobicore.modules.movement.common.MovementActions;
import com.example.shinobicore.modules.movement.common.MovementPose;
import com.example.shinobicore.modules.movement.common.events.WallJumpedEvent;
import com.example.shinobicore.modules.movement.config.MovementConfig;
import com.example.shinobicore.modules.movement.network.MovementPackets;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.util.math.Vec3d;

public final class WallJumpService {
    private WallJumpService() {}

    public static void tryJump(ClientPlayerEntity player) {
        if (ClientMovementState.getPose() != MovementPose.WALL_RUNNING) return;
        
        Vec3d normal = WallRunService.getCurrentNormal();
        if (normal == null) return;

        Vec3d vel = player.getVelocity();
        double pushX = normal.x * MovementConfig.WALL_JUMP_PUSH + vel.x * 0.2;
        double pushZ = normal.z * MovementConfig.WALL_JUMP_PUSH + vel.z * 0.2;
        double pushY = MovementConfig.WALL_JUMP_UP;

        player.setVelocity(pushX, pushY, pushZ);
        player.velocityModified = true;
        
        ClientMovementState.setPose(MovementPose.NORMAL);
        ClientMovementState.setWallRunCooldown(MovementConfig.WALL_JUMP_COOLDOWN);
        
        ClientMovementController.events().publish(new WallJumpedEvent(player, normal));
        MovementPackets.sendActionToServer(MovementActions.WALL_JUMP, player.getYaw(), pushX, pushZ);
    }
}
'@
Write-File "$baseJava\client\WallJumpService.java" $wallJumpJava

# ==============================================================================
# 4. UPDATE CONFIG & CONTROLLER
# ==============================================================================

# Update MovementConfig to include new physics constants
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
        } catch (Exception e) {
            ShinobiLogger.error("movement", "Failed to parse config, using defaults.", e);
        }
    }
}
'@
Write-File "$baseJava\config\MovementConfig.java" $configJava

# Update ClientMovementController to handle CoreEvents and tick services
$controllerJava = @'
package com.example.shinobicore.modules.movement.client;

import com.example.shinobicore.core.event.CoreEvents;
import com.example.shinobicore.core.log.ShinobiLogger;
import com.example.shinobicore.modules.movement.common.MovementPose;
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

        // Wall Jump detection (Jump key pressed while on wall)
        if (client.options.jumpKey.wasPressed() && ClientMovementState.getPose() == MovementPose.WALL_RUNNING) {
            WallJumpService.tryJump(client.player);
        }

        // Service ticks
        WaterWalkService.tick(client.player);
        WallRunService.tick(client.player);
    }
}
'@
Write-File "$baseJava\client\ClientMovementController.java" $controllerJava

# Update MovementModule to pass CoreEvents to ClientMovementController
$moduleJava = @'
package com.example.shinobicore.modules.movement;

import com.example.shinobicore.core.api.ClientAwareModule;
import com.example.shinobicore.core.api.ModuleContext;
import com.example.shinobicore.core.log.ShinobiLogger;
import com.example.shinobicore.modules.movement.commands.MovementCommands;
import com.example.shinobicore.modules.movement.config.MovementConfig;
import com.example.shinobicore.modules.movement.network.MovementPackets;
import com.example.shinobicore.modules.movement.server.MovementServerMirror;
import com.example.shinobicore.modules.movement.view.MovementVisualView;
import com.example.shinobicore.modules.movement.view.MovementVisualViewImpl;
import com.example.shinobicore.modules.movement.client.ClientMovementController;
import com.example.shinobicore.modules.movement.client.input.MovementKeyBindings;
import com.mojang.brigadier.CommandDispatcher;
import net.minecraft.server.MinecraftServer;
import net.minecraft.server.command.ServerCommandSource;

public class MovementModule implements ClientAwareModule {
    public static final String ID = "movement";

    @Override public String id() { return ID; }

    @Override
    public void onEnable(ModuleContext ctx) {
        MovementConfig.load(ctx.configs().readModuleConfig(ID));
        MovementServerMirror.init();
        MovementPackets.registerServer();
        ShinobiLogger.module(ID, "Movement module enabled.");
    }

    @Override
    public void registerEvents(ModuleContext ctx) {
        ctx.events().subscribe(com.example.shinobicore.core.event.ChakraModeDisabledEvent.class, e -> {
            MovementServerMirror.forceStopParkour(e.player());
        });
    }

    @Override
    public void registerViews(ModuleContext ctx) {
        ctx.views().register(MovementVisualView.class, player -> 
            java.util.Optional.of(new MovementVisualViewImpl(player)));
    }

    @Override
    public void registerCommands(ModuleContext ctx, CommandDispatcher<ServerCommandSource> d) {
        MovementCommands.register(d);
    }

    @Override
    public void onClientInit(ModuleContext ctx) {
        MovementKeyBindings.register();
        ClientMovementController.init(ctx.events()); // Pass CoreEvents for publishing
        MovementPackets.registerClient();
    }

    @Override
    public void onClientTick(ModuleContext ctx) {
        ClientMovementController.tick();
    }

    @Override
    public void onServerTick(ModuleContext ctx, MinecraftServer server) {
        MovementServerMirror.tick(server);
    }
}
'@
Write-File "$baseJava\MovementModule.java" $moduleJava

Write-Host "`n[SUCCESS] Phase 3 completed: Events, Detectors, and Parkour Services generated!" -ForegroundColor Green
Write-Host "Next steps: Implement Phase 3 part 2 (Slide, Crawl, Roll, Dodge, DoubleJump, EdgeGrab)." -ForegroundColor Yellow