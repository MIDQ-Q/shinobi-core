# ==============================================================================
# SHINOBICORE MOVEMENT MODULE - MASTER SCAFFOLDING SCRIPT
# Generates Phase 1, 2, and 6 skeleton.
# MUST BE RUN FROM PROJECT ROOT (where build.gradle is located).
# ==============================================================================

$baseJava = "src\main\java\com\example\shinobicore\modules\movement"
$baseRes  = "src\main\resources"

# 1. Create Directory Structure
$dirs = @(
    "$baseJava\config",
    "$baseJava\common",
    "$baseJava\client\input",
    "$baseJava\client\util",
    "$baseJava\server",
    "$baseJava\network",
    "$baseJava\view",
    "$baseJava\commands",
    "$baseRes\data\shinobicore\movement",
    "$baseRes\assets\shinobicore\movement"
)

foreach ($dir in $dirs) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Write-Host "Created dir: $dir" -ForegroundColor Green
    }
}

# Helper: Write file with UTF-8 NO BOM (Strict Core Rule)
function Write-File($path, $content) {
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($path, $content, $utf8NoBom)
    Write-Host "Generated: $path" -ForegroundColor Cyan
}

# ==============================================================================
# 2. GENERATE JAVA FILES
# ==============================================================================

# --- MovementModule.java ---
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
        ClientMovementController.init();
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

# --- MovementConfig.java ---
$configJava = @'
package com.example.shinobicore.modules.movement.config;

import com.example.shinobicore.core.log.ShinobiLogger;
import com.google.gson.JsonObject;

public final class MovementConfig {
    public static boolean ENABLED = true;
    public static boolean DEBUG = false;
    
    public static double WATER_WALK_DRAIN = 1.5;
    public static double WALL_RUN_DRAIN = 1.5;
    public static int WALL_RUN_COOLDOWN = 20;
    
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
            }
            if (json.has("wallRun")) {
                JsonObject wr = json.getAsJsonObject("wallRun");
                WALL_RUN_DRAIN = wr.has("drainPerSecond") ? wr.get("drainPerSecond").getAsDouble() : 1.5;
                WALL_RUN_COOLDOWN = wr.has("stickCooldownTicks") ? wr.get("stickCooldownTicks").getAsInt() : 20;
            }
        } catch (Exception e) {
            ShinobiLogger.error("movement", "Failed to parse config, using defaults.", e);
        }
    }
}
'@
Write-File "$baseJava\config\MovementConfig.java" $configJava

# --- MovementPose.java & MovementActions.java ---
$poseJava = @'
package com.example.shinobicore.modules.movement.common;

public enum MovementPose {
    NORMAL, WATER_WALKING, WALL_RUNNING, SLIDING, CRAWLING, 
    ROLLING, DODGING, EDGE_GRABBING, CHARGING_JUMP
}
'@
Write-File "$baseJava\common\MovementPose.java" $poseJava

$actionsJava = @'
package com.example.shinobicore.modules.movement.common;

public final class MovementActions {
    public static final int START_WATER_WALK = 1;
    public static final int STOP_WATER_WALK = 2;
    public static final int START_WALL_RUN = 3;
    public static final int STOP_WALL_RUN = 4;
    public static final int WALL_JUMP = 5;
    public static final int START_SLIDE = 6;
    public static final int STOP_SLIDE = 7;
    public static final int START_ROLL = 8;
    public static final int STOP_ROLL = 9;
    public static final int DODGE = 10;
    public static final int DOUBLE_JUMP = 11;
    public static final int START_EDGE_GRAB = 12;
    public static final int STOP_EDGE_GRAB = 13;
    
    private MovementActions() {}
}
'@
Write-File "$baseJava\common\MovementActions.java" $actionsJava

# --- DrainAccumulator.java ---
$drainJava = @'
package com.example.shinobicore.modules.movement.server;

public final class DrainAccumulator {
    private double accumulator = 0.0;
    private final double perSecond;

    public DrainAccumulator(double perSecond) {
        this.perSecond = perSecond;
    }

    public int tick(double deltaTimeSeconds) {
        accumulator += perSecond * deltaTimeSeconds;
        int toSpend = (int) accumulator;
        accumulator -= toSpend;
        return toSpend;
    }

    public void reset() { 
        accumulator = 0.0; 
    }
    
    public double getAccumulator() {
        return accumulator;
    }
}
'@
Write-File "$baseJava\server\DrainAccumulator.java" $drainJava

# --- MovementServerMirror.java ---
$mirrorJava = @'
package com.example.shinobicore.modules.movement.server;

import com.example.shinobicore.core.api.ChakraApi;
import com.example.shinobicore.core.event.CoreEvents;
import com.example.shinobicore.core.log.ShinobiLogger;
import com.example.shinobicore.core.service.CoreServices;
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
        // Soft validation & state update logic goes here
        UUID id = player.getUuid();
        if (actionId >= 1 && actionId <= 5) {
            POSES.put(id, MovementPose.WATER_WALKING); // Simplified for skeleton
        }
    }

    public static void forceStopParkour(ServerPlayerEntity player) {
        UUID id = player.getUuid();
        POSES.put(id, MovementPose.NORMAL);
        DRAINS.remove(id);
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

# --- MovementPackets.java ---
$packetsJava = @'
package com.example.shinobicore.modules.movement.network;

import com.example.shinobicore.core.log.ShinobiLogger;
import com.example.shinobicore.modules.movement.server.MovementServerMirror;
import net.fabricmc.fabric.api.client.networking.v1.ClientPlayNetworking;
import net.fabricmc.fabric.api.networking.v1.PacketByteBufs;
import net.fabricmc.fabric.api.networking.v1.ServerPlayNetworking;
import net.minecraft.network.PacketByteBuf;
import net.minecraft.util.Identifier;

public final class MovementPackets {
    public static final Identifier ACTION_ID = new Identifier("shinobicore", "movement_action");

    private MovementPackets() {}

    public static void registerServer() {
        ServerPlayNetworking.registerGlobalReceiver(ACTION_ID, (server, player, handler, buf, sender) -> {
            // CRITICAL RULE: Read ALL data from buffer FIRST
            final int actionId = buf.readInt();
            final float yaw = buf.readFloat();
            final double vx = buf.readDouble();
            final double vz = buf.readDouble();

            // THEN execute on server thread
            server.execute(() -> {
                try {
                    MovementServerMirror.handleAction(player, actionId, yaw, vx, vz);
                } catch (Exception e) {
                    ShinobiLogger.error("movement", "Failed to handle action packet", e);
                }
            });
        });
        ShinobiLogger.module("movement", "Server packets registered.");
    }

    public static void registerClient() {
        // Client receivers (e.g., state sync from server) go here
        ShinobiLogger.module("movement", "Client packets registered.");
    }

    public static void sendActionToServer(int actionId, float yaw, double vx, double vz) {
        PacketByteBuf buf = PacketByteBufs.create();
        buf.writeInt(actionId);
        buf.writeFloat(yaw);
        buf.writeDouble(vx);
        buf.writeDouble(vz);
        ClientPlayNetworking.send(ACTION_ID, buf);
    }
}
'@
Write-File "$baseJava\network\MovementPackets.java" $packetsJava

# --- ClientMovementController.java & State ---
$stateJava = @'
package com.example.shinobicore.modules.movement.client;

import com.example.shinobicore.modules.movement.common.MovementPose;

public final class ClientMovementState {
    private static MovementPose currentPose = MovementPose.NORMAL;
    private static int wallRunCooldown = 0;
    private static int doubleJumpCharges = 1;

    private ClientMovementState() {}

    public static MovementPose getPose() { return currentPose; }
    public static void setPose(MovementPose pose) { currentPose = pose; }
    
    public static int getWallRunCooldown() { return wallRunCooldown; }
    public static void setWallRunCooldown(int ticks) { wallRunCooldown = ticks; }
    
    public static int getDoubleJumpCharges() { return doubleJumpCharges; }
    public static void setDoubleJumpCharges(int c) { doubleJumpCharges = c; }

    public static void tickCooldowns() {
        if (wallRunCooldown > 0) wallRunCooldown--;
    }

    public static void reset() {
        currentPose = MovementPose.NORMAL;
        wallRunCooldown = 0;
        doubleJumpCharges = 1;
    }
}
'@
Write-File "$baseJava\client\ClientMovementState.java" $stateJava

$controllerJava = @'
package com.example.shinobicore.modules.movement.client;

import com.example.shinobicore.core.log.ShinobiLogger;
import com.example.shinobicore.modules.movement.common.MovementPose;
import net.minecraft.client.MinecraftClient;

public final class ClientMovementController {
    private ClientMovementController() {}

    public static void init() {
        ShinobiLogger.module("movement", "Client controller initialized.");
    }

    public static void tick() {
        MinecraftClient client = MinecraftClient.getInstance();
        if (client.player == null || client.world == null) return;

        ClientMovementState.tickCooldowns();

        // Phase 3 will inject service ticks here:
        // WaterWalkService.tick(client.player);
        // WallRunService.tick(client.player);
        // SlideService.tick(client.player);
    }
}
'@
Write-File "$baseJava\client\ClientMovementController.java" $controllerJava

# --- MovementKeyBindings.java ---
$keybindsJava = @'
package com.example.shinobicore.modules.movement.client.input;

import com.example.shinobicore.core.log.ShinobiLogger;
import net.fabricmc.fabric.api.client.keybinding.v1.KeyBindingHelper;
import net.minecraft.client.option.KeyBinding;
import net.minecraft.client.util.InputUtil;
import org.lwjgl.glfw.GLFW;

public final class MovementKeyBindings {
    public static KeyBinding ROLL_KEY;
    public static KeyBinding DODGE_KEY;
    public static KeyBinding CRAWL_KEY;

    private MovementKeyBindings() {}

    public static void register() {
        ROLL_KEY = KeyBindingHelper.registerKeyBinding(new KeyBinding(
            "key.shinobicore.movement.roll", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_R, "category.shinobicore.movement"));
        DODGE_KEY = KeyBindingHelper.registerKeyBinding(new KeyBinding(
            "key.shinobicore.movement.dodge", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_LEFT_ALT, "category.shinobicore.movement"));
        CRAWL_KEY = KeyBindingHelper.registerKeyBinding(new KeyBinding(
            "key.shinobicore.movement.crawl", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_Z, "category.shinobicore.movement"));
            
        ShinobiLogger.module("movement", "Keybindings registered.");
    }
}
'@
Write-File "$baseJava\client\input\MovementKeyBindings.java" $keybindsJava

# --- Views ---
$viewInterfaceJava = @'
package com.example.shinobicore.modules.movement.view;

import net.minecraft.util.math.Vec3d;

public interface MovementVisualView {
    boolean isWaterWalking();
    boolean isWallRunning();
    boolean isSliding();
    boolean isCrawling();
    boolean isRolling();
    boolean isDodging();
    boolean isChargingJump();
    boolean isEdgeGrabbing();
    float getMoveSpeed();
    float getActionProgress();
    Vec3d getWallNormal();
}
'@
Write-File "$baseJava\view\MovementVisualView.java" $viewInterfaceJava

$viewImplJava = @'
package com.example.shinobicore.modules.movement.view;

import com.example.shinobicore.modules.movement.client.ClientMovementState;
import com.example.shinobicore.modules.movement.common.MovementPose;
import net.minecraft.entity.player.PlayerEntity;
import net.minecraft.util.math.Vec3d;

public final class MovementVisualViewImpl implements MovementVisualView {
    private final PlayerEntity player;

    public MovementVisualViewImpl(PlayerEntity player) {
        this.player = player;
    }

    private boolean is(MovementPose pose) {
        return ClientMovementState.getPose() == pose;
    }

    @Override public boolean isWaterWalking() { return is(MovementPose.WATER_WALKING); }
    @Override public boolean isWallRunning() { return is(MovementPose.WALL_RUNNING); }
    @Override public boolean isSliding() { return is(MovementPose.SLIDING); }
    @Override public boolean isCrawling() { return is(MovementPose.CRAWLING); }
    @Override public boolean isRolling() { return is(MovementPose.ROLLING); }
    @Override public boolean isDodging() { return is(MovementPose.DODGING); }
    @Override public boolean isChargingJump() { return is(MovementPose.CHARGING_JUMP); }
    @Override public boolean isEdgeGrabbing() { return is(MovementPose.EDGE_GRABBING); }
    
    @Override public float getMoveSpeed() { return player.isSprinting() ? 1.3f : 1.0f; }
    @Override public float getActionProgress() { return 0.0f; }
    @Override public Vec3d getWallNormal() { return null; }
}
'@
Write-File "$baseJava\view\MovementVisualViewImpl.java" $viewImplJava

# --- Commands ---
$commandsJava = @'
package com.example.shinobicore.modules.movement.commands;

import com.example.shinobicore.modules.movement.client.ClientMovementState;
import com.example.shinobicore.modules.movement.common.MovementPose;
import com.mojang.brigadier.CommandDispatcher;
import com.mojang.brigadier.context.CommandContext;
import net.minecraft.server.command.CommandManager;
import net.minecraft.server.command.ServerCommandSource;
import net.minecraft.text.Text;
import net.minecraft.util.Formatting;

public final class MovementCommands {
    private MovementCommands() {}

    public static void register(CommandDispatcher<ServerCommandSource> dispatcher) {
        dispatcher.register(CommandManager.literal("shinobicore")
            .then(CommandManager.literal("movement")
                .then(CommandManager.literal("state").executes(MovementCommands::cmdState))
                .then(CommandManager.literal("reset").executes(MovementCommands::cmdReset))
            )
        );
    }

    private static int cmdState(CommandContext<ServerCommandSource> ctx) {
        // Note: In a real scenario, server doesn't have ClientMovementState. 
        // This is a simplified skeleton. Server should read from MovementServerMirror.
        ctx.getSource().sendFeedback(() -> Text.literal("=== Movement State ===").formatted(Formatting.GOLD), false);
        ctx.getSource().sendFeedback(() -> Text.literal("Pose: NORMAL (Server Mirror Active)").formatted(Formatting.WHITE), false);
        return 1;
    }

    private static int cmdReset(CommandContext<ServerCommandSource> ctx) {
        ctx.getSource().sendFeedback(() -> Text.literal("Movement state reset.").formatted(Formatting.GREEN), false);
        return 1;
    }
}
'@
Write-File "$baseJava\commands\MovementCommands.java" $commandsJava

# ==============================================================================
# 3. GENERATE DEFAULT CONFIG JSON
# ==============================================================================

$defaultConfig = @'
{
  "enabled": true,
  "debug": false,
  "waterWalk": {
    "enabled": true,
    "drainPerSecond": 1.5,
    "surfaceOffset": 0.05,
    "minHorizontalSpeed": 0.02
  },
  "wallRun": {
    "enabled": true,
    "drainPerSecond": 1.5,
    "gravityMultiplier": 0.3,
    "maxDurationTicks": 120,
    "stickCooldownTicks": 20,
    "minHorizontalSpeed": 0.1,
    "raycastDistance": 0.6
  },
  "wallJump": {
    "enabled": true,
    "pushStrength": 0.6,
    "upBoost": 0.45,
    "cooldownTicks": 20
  },
  "slide": {
    "enabled": true,
    "durationTicks": 20,
    "minSprintSpeed": 0.18,
    "friction": 0.92
  },
  "roll": {
    "enabled": true,
    "durationTicks": 12,
    "iframeTicks": 8,
    "cooldownTicks": 40,
    "distance": 3.0
  },
  "dodge": {
    "enabled": true,
    "strength": 3.2,
    "iframeTicks": 4,
    "cooldownTicks": 30,
    "chakraCost": 2.0
  },
  "doubleJump": {
    "enabled": true,
    "boost": 0.42,
    "maxCharges": 1,
    "chakraCost": 1.0
  },
  "chargedJump": {
    "enabled": true,
    "chargeTicks": 30,
    "maxMultiplier": 2.5,
    "chakraCost": 3.0
  },
  "edgeGrab": {
    "enabled": true,
    "reachDistance": 0.6,
    "chakraCost": 1.0,
    "climbBoost": 1.0
  },
  "narutoRun": {
    "enabled": true,
    "minSprintSpeed": 0.18,
    "maxSprintSpeed": 0.45
  },
  "formula": {
    "jumpGainPerLevel": 0.02,
    "speedGainPerLevel": 0.015,
    "chakraModeJumpMultiplier": 1.3,
    "chakraModeSpeedMultiplier": 1.15
  },
  "logging": {
    "logActions": false,
    "logDrains": false
  }
}
'@
# The core config loader handles creation, but we can pre-generate it for convenience
$configPath = "config\shinobicore\modules\movement.json"
if (-not (Test-Path "config\shinobicore\modules")) {
    New-Item -ItemType Directory -Path "config\shinobicore\modules" -Force | Out-Null
}
Write-File $configPath $defaultConfig

Write-Host "`n[SUCCESS] Movement Module skeleton generated successfully!" -ForegroundColor Green
Write-Host "Next steps: Implement Phase 3 (Client Services like WaterWalkService, WallRunService)." -ForegroundColor Yellow