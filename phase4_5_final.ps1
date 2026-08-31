# ==============================================================================
# SHINOBICORE MOVEMENT MODULE - PHASE 4 & 5: ANIMATIONS, COMMANDS, CLEANUP
# Generates animation controller, full commands, event cleanup, and README.
# ==============================================================================

$baseJava = "src\main\java\com\example\shinobicore\modules\movement"
$animDir = "$baseJava\client\anim"

# Helper: Write file with UTF-8 NO BOM
function Write-File($path, $content) {
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($path, $content, $utf8NoBom)
    Write-Host "Generated: $path" -ForegroundColor Cyan
}

if (-not (Test-Path $animDir)) { New-Item -ItemType Directory -Path $animDir -Force | Out-Null }

# ==============================================================================
# 1. ANIMATION CONTROLLER (Phase 4)
# ==============================================================================

$animControllerJava = @'
package com.example.shinobicore.modules.movement.client.anim;

import com.example.shinobicore.modules.movement.client.ClientMovementState;
import com.example.shinobicore.modules.movement.common.MovementPose;
import com.example.shinobicore.modules.movement.config.MovementConfig;
import net.minecraft.client.network.ClientPlayerEntity;

/**
 * Bridges MovementPose to visual/animation states.
 * In a full implementation, this would call PlayerAnimator API.
 * For now, it manages vanilla pose overrides and prepares data for rendering.
 */
public final class ParkourAnimationController {
    private static MovementPose lastRenderedPose = MovementPose.NORMAL;

    private ParkourAnimationController() {}

    public static void tick(ClientPlayerEntity player) {
        MovementPose currentPose = ClientMovementState.getPose();
        
        if (currentPose == lastRenderedPose) return;
        lastRenderedPose = currentPose;

        // Apply vanilla overrides / trigger PlayerAnimator events
        switch (currentPose) {
            case WATER_WALKING:
                // Trigger water walk animation (arms slightly raised)
                break;
            case WALL_RUNNING:
                // Trigger wall run animation (tilted)
                break;
            case SLIDING:
            case CRAWLING:
                player.setSwimming(true);
                break;
            case ROLLING:
                // Trigger roll animation
                break;
            case DODGING:
                // Trigger dodge blur/shift
                break;
            case CHARGING_JUMP:
                // Trigger crouch charge
                break;
            case EDGE_GRABBING:
                // Trigger hang animation
                break;
            case NORMAL:
            default:
                if (currentPose != MovementPose.SLIDING && currentPose != MovementPose.CRAWLING) {
                    player.setSwimming(false);
                }
                break;
        }
    }

    public static boolean isNarutoRunning(ClientPlayerEntity player) {
        if (!MovementConfig.NARUTO_RUN_ENABLED) return false;
        if (!player.isSprinting()) return false;
        
        float speed = (float) player.getVelocity().horizontalLength();
        return speed >= MovementConfig.NARUTO_RUN_MIN_SPEED && 
               ClientMovementState.getPose() == MovementPose.NORMAL;
    }
}
'@
Write-File "$animDir\ParkourAnimationController.java" $animControllerJava

# Update ClientMovementController to tick animations
$controllerJava = @'
package com.example.shinobicore.modules.movement.client;

import com.example.shinobicore.core.event.CoreEvents;
import com.example.shinobicore.core.log.ShinobiLogger;
import com.example.shinobicore.modules.movement.client.anim.ParkourAnimationController;
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
        if (events == null) throw new IllegalStateException("ClientMovementController not initialized!");
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

        // Visuals & Animations
        ParkourAnimationController.tick(client.player);
    }
}
'@
Write-File "$baseJava\client\ClientMovementController.java" $controllerJava

# Add Naruto Run config flags
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

    public static boolean NARUTO_RUN_ENABLED = true;
    public static float NARUTO_RUN_MIN_SPEED = 0.18f;
    
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
            if (json.has("narutoRun")) {
                JsonObject nr = json.getAsJsonObject("narutoRun");
                NARUTO_RUN_ENABLED = nr.has("enabled") ? nr.get("enabled").getAsBoolean() : true;
                NARUTO_RUN_MIN_SPEED = nr.has("minSprintSpeed") ? nr.get("minSprintSpeed").getAsFloat() : 0.18f;
            }
        } catch (Exception e) {
            ShinobiLogger.error("movement", "Failed to parse config, using defaults.", e);
        }
    }
}
'@
Write-File "$baseJava\config\MovementConfig.java" $configJava

# ==============================================================================
# 2. COMMANDS & SERVER MIRROR EXPOSURE (Phase 5)
# ==============================================================================

# Update Mirror to expose state for commands
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
                POSES.put(id, MovementPose.NORMAL);
                break;
        }
    }

    public static void forceStopParkour(ServerPlayerEntity player) {
        UUID id = player.getUuid();
        POSES.put(id, MovementPose.NORMAL);
        DRAINS.remove(id);
    }

    public static void cleanupPlayer(UUID uuid) {
        POSES.remove(uuid);
        DRAINS.remove(uuid);
    }

    // --- Exposed getters for Commands ---
    public static MovementPose getPose(UUID uuid) {
        return POSES.getOrDefault(uuid, MovementPose.NORMAL);
    }

    public static double getDrainAccumulator(UUID uuid) {
        DrainAccumulator acc = DRAINS.get(uuid);
        return acc != null ? acc.getAccumulator() : 0.0;
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
}
'@
Write-File "$baseJava\server\MovementServerMirror.java" $mirrorJava

# Full Commands Implementation
$commandsJava = @'
package com.example.shinobicore.modules.movement.commands;

import com.example.shinobicore.core.api.ChakraApi;
import com.example.shinobicore.core.service.CoreServices;
import com.example.shinobicore.modules.movement.common.MovementPose;
import com.example.shinobicore.modules.movement.config.MovementConfig;
import com.example.shinobicore.modules.movement.server.MovementServerMirror;
import com.mojang.brigadier.CommandDispatcher;
import com.mojang.brigadier.context.CommandContext;
import net.minecraft.server.command.CommandManager;
import net.minecraft.server.command.ServerCommandSource;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.text.Text;
import net.minecraft.util.Formatting;
import net.minecraft.util.math.BlockPos;
import net.minecraft.block.Blocks;

import java.util.UUID;

public final class MovementCommands {
    private MovementCommands() {}

    public static void register(CommandDispatcher<ServerCommandSource> dispatcher) {
        dispatcher.register(CommandManager.literal("shinobicore")
            .then(CommandManager.literal("movement")
                .then(CommandManager.literal("state").executes(MovementCommands::cmdState))
                .then(CommandManager.literal("test").executes(MovementCommands::cmdTest))
                .then(CommandManager.literal("debug").executes(MovementCommands::cmdDebug))
                .then(CommandManager.literal("reset").executes(MovementCommands::cmdReset))
            )
        );
    }

    private static int cmdState(CommandContext<ServerCommandSource> ctx) {
        ServerPlayerEntity player = ctx.getSource().getPlayer();
        if (player == null) return 0;
        
        UUID id = player.getUuid();
        MovementPose pose = MovementServerMirror.getPose(id);
        double drainAcc = MovementServerMirror.getDrainAccumulator(id);

        ctx.getSource().sendFeedback(() -> Text.literal("=== Movement State ===").formatted(Formatting.GOLD), false);
        ctx.getSource().sendFeedback(() -> Text.literal("Pose: " + pose.name()).formatted(Formatting.WHITE), false);
        
        CoreServices.get(ChakraApi.class).ifPresent(chakra -> {
            float cur = chakra.getCurrent(player);
            float max = chakra.getMax(player);
            boolean mode = chakra.isChakraModeActive(player);
            ctx.getSource().sendFeedback(() -> Text.literal(String.format("Chakra: %.0f/%.0f (mode: %s)", cur, max, mode ? "ON" : "OFF")).formatted(Formatting.AQUA), false);
        });

        ctx.getSource().sendFeedback(() -> Text.literal("Wall normal: Client-side only").formatted(Formatting.GRAY), false);
        ctx.getSource().sendFeedback(() -> Text.literal("Water surface: Client-side only").formatted(Formatting.GRAY), false);
        ctx.getSource().sendFeedback(() -> Text.literal(String.format("Drain acc: %.2f", drainAcc)).formatted(Formatting.YELLOW), false);
        ctx.getSource().sendFeedback(() -> Text.literal("Cooldowns: Tracked on client").formatted(Formatting.GRAY), false);
        
        return 1;
    }

    private static int cmdTest(CommandContext<ServerCommandSource> ctx) {
        ServerPlayerEntity player = ctx.getSource().getPlayer();
        if (player == null) return 0;

        BlockPos origin = player.getBlockPos().east(5);
        var world = player.getWorld();

        // Create a 5x5 water pool
        for (int x = 0; x < 5; x++) {
            for (int z = 0; z < 5; z++) {
                world.setBlockState(origin.add(x, 0, z), Blocks.WATER.getDefaultState());
                world.setBlockState(origin.add(x, -1, z), Blocks.STONE.getDefaultState());
            }
        }

        // Create a wall for wall-running
        for (int y = 0; y < 4; y++) {
            for (int z = 0; z < 5; z++) {
                world.setBlockState(origin.add(6, y, z), Blocks.STONE_BRICKS.getDefaultState());
            }
        }

        // Create an edge to grab
        world.setBlockState(origin.add(-2, 2, 0), Blocks.STONE_BRICKS.getDefaultState());
        world.setBlockState(origin.add(-2, 3, 0), Blocks.AIR.getDefaultState());

        ctx.getSource().sendFeedback(() -> Text.literal("Test structures spawned: Water pool, Wall, Edge.").formatted(Formatting.GREEN), false);
        return 1;
    }

    private static int cmdDebug(CommandContext<ServerCommandSource> ctx) {
        MovementConfig.DEBUG = !MovementConfig.DEBUG;
        String status = MovementConfig.DEBUG ? "ENABLED" : "DISABLED";
        ctx.getSource().sendFeedback(() -> Text.literal("Movement debug overlay: " + status).formatted(Formatting.YELLOW), false);
        return 1;
    }

    private static int cmdReset(CommandContext<ServerCommandSource> ctx) {
        ServerPlayerEntity player = ctx.getSource().getPlayer();
        if (player == null) return 0;
        
        MovementServerMirror.forceStopParkour(player);
        ctx.getSource().sendFeedback(() -> Text.literal("Movement state reset to NORMAL.").formatted(Formatting.GREEN), false);
        return 1;
    }
}
'@
Write-File "$baseJava\commands\MovementCommands.java" $commandsJava

# ==============================================================================
# 3. MODULE CLEANUP & EVENT SUBSCRIPTIONS (Phase 5)
# ==============================================================================

$moduleJava = @'
package com.example.shinobicore.modules.movement;

import com.example.shinobicore.core.api.ClientAwareModule;
import com.example.shinobicore.core.api.ModuleContext;
import com.example.shinobicore.core.event.CoreEvents;
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
        CoreEvents events = ctx.events();
        
        // Stop parkour if chakra mode is disabled globally
        events.subscribe(com.example.shinobicore.core.event.ChakraModeDisabledEvent.class, e -> {
            MovementServerMirror.forceStopParkour(e.player());
        });

        // CRITICAL: Cleanup static maps on player leave/death to prevent memory leaks (TZ 11)
        events.subscribe(com.example.shinobicore.core.event.PlayerLeaveEvent.class, e -> {
            MovementServerMirror.cleanupPlayer(e.player().getUuid());
        });
        
        events.subscribe(com.example.shinobicore.core.event.PlayerDiedEvent.class, e -> {
            MovementServerMirror.cleanupPlayer(e.player().getUuid());
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
        ClientMovementController.init(ctx.events());
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

# ==============================================================================
# 4. README.md (TZ 15 Requirement)
# ==============================================================================

$readmeMd = @'
# Movement Module (ShinobiCore)

## Overview
This module implements a complete shinobi-style movement system, including water walking, wall running, sliding, rolling, dodging, and edge grabbing. It relies on the core Chakra service for resource management.

## Key Mechanics
- **Water Walking**: Requires active Chakra mode. Drains chakra over time.
- **Wall Running**: Stick to walls while in air. Requires horizontal momentum.
- **Dodging/Rolling**: Grants i-frames (damage immunity). Dodging costs chakra.
- **Edge Grabbing**: Automatically catches edges when falling near them.

## Configuration
Located at `config/shinobicore/modules/movement.json`.
All values have safe defaults. The module will NOT crash if the file is missing or malformed.

## Commands
- `/shinobicore movement state` - Shows current server-side pose and drain accumulator.
- `/shinobicore movement test` - Spawns a water pool, wall, and edge for testing.
- `/shinobicore movement debug` - Toggles debug logging/overlay.
- `/shinobicore movement reset` - Forces pose back to NORMAL.

## Architecture Notes
- **Client Authority**: Physics and pose detection happen on the client for responsive feel.
- **Server Mirror**: The server only tracks the current pose and drains chakra once per second using an accumulator pattern to prevent double-drain bugs.
- **Memory Safety**: All player-specific data in static maps is cleaned up via `PlayerLeaveEvent` and `PlayerDiedEvent`.

## Dependencies
- Core: `ChakraApi`, `CoreEvents`, `CoreServices`
- External: `player-animator` (optional, for advanced pose blending)
'@
Write-File "$baseJava\..\..\..\..\..\modules\movement\README.md" $readmeMd

Write-Host "`n[SUCCESS] Phase 4 & 5 completed: Animations, Commands, Cleanup, and README generated!" -ForegroundColor Green
Write-Host "Next steps: Run '.\gradlew.bat build' to verify compilation." -ForegroundColor Yellow