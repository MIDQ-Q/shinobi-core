$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$root = "E:\Games\mod"
$srcBase = Join-Path $root "src\main\java\com\example\shinobicore"

Write-Host ""
Write-Host "==============================================================" -ForegroundColor Cyan
Write-Host " INDEPENDENT MOVEMENT LOGGER" -ForegroundColor Cyan
Write-Host " Does NOT modify any existing movement files" -ForegroundColor Cyan
Write-Host " Output: log_movement.txt in game directory" -ForegroundColor Cyan
Write-Host "==============================================================" -ForegroundColor Cyan
Write-Host ""

# ============================================================
# STEP 1: Create MovementLogger.java (pure file writer)
# ============================================================
Write-Host "[1/3] Creating MovementLogger.java (pure file writer)..." -ForegroundColor Yellow

$loggerDir = Join-Path $srcBase "util"
if (-not (Test-Path $loggerDir)) { New-Item -ItemType Directory -Path $loggerDir -Force | Out-Null }

$loggerContent = @'
// SHINOBICORE INDEPENDENT MOVEMENT LOGGER
// This logger does NOT modify any existing movement files.
// It reads state through public APIs only.
package com.example.shinobicore.util;

import net.fabricmc.loader.api.FabricLoader;

import java.io.BufferedWriter;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardOpenOption;
import java.text.SimpleDateFormat;
import java.util.Date;

/**
 * Independent movement logger.
 * Writes to log_movement.txt in the game directory.
 * Does not modify any existing code - reads state via public APIs.
 */
public final class MovementLogger {
    private static final String FILE_NAME = "log_movement.txt";
    private static final SimpleDateFormat TIME_FMT = new SimpleDateFormat("HH:mm:ss.SSS");
    private static final Object LOCK = new Object();
    
    private static BufferedWriter writer;
    private static boolean initialized = false;
    private static boolean enabled = true;
    private static Path logPath;
    
    // Throttle control
    private static long lastLogTime = 0;
    private static final long MIN_INTERVAL_MS = 50;
    private static int tickCounter = 0;
    
    private MovementLogger() {}
    
    public static void init() {
        if (initialized) return;
        try {
            logPath = FabricLoader.getInstance().getGameDir().resolve(FILE_NAME);
            writer = Files.newBufferedWriter(logPath, StandardCharsets.UTF_8,
                    StandardOpenOption.CREATE, StandardOpenOption.APPEND);
            initialized = true;
            writeRaw("============================================================");
            writeRaw("SHINOBICORE INDEPENDENT MOVEMENT LOGGER");
            writeRaw("Session started: " + new SimpleDateFormat("yyyy-MM-dd HH:mm:ss").format(new Date()));
            writeRaw("This logger does NOT modify any existing movement code.");
            writeRaw("============================================================");
        } catch (IOException e) {
            System.err.println("[MovementLogger] Failed to init: " + e.getMessage());
            enabled = false;
        }
    }
    
    public static void close() {
        if (!initialized) return;
        try {
            writeRaw("=== SESSION ENDED ===");
            writer.flush();
            writer.close();
        } catch (IOException ignored) {}
        initialized = false;
    }
    
    public static void setEnabled(boolean value) {
        enabled = value;
    }
    
    public static boolean isEnabled() {
        return enabled;
    }
    
    // ========================================
    // EVENT LOGGING (always logged)
    // ========================================
    
    public static void event(String category, String message) {
        if (!enabled || !initialized) return;
        String line = formatLine("EVENT", category, message);
        writeRaw(line);
    }
    
    public static void event(String category, String format, Object... args) {
        if (!enabled || !initialized) return;
        String message = (args != null && args.length > 0) ? String.format(format, args) : format;
        event(category, message);
    }
    
    // ========================================
    // STATE CHANGE LOGGING
    // ========================================
    
    public static void stateChange(String from, String to, String reason) {
        if (!enabled || !initialized) return;
        String line = formatLine("STATE", "PHASE", from + " -> " + to + " | reason: " + reason);
        writeRaw(line);
    }
    
    public static void stateChange(String from, String to) {
        stateChange(from, to, "unknown");
    }
    
    // ========================================
    // WARNING LOGGING (potential bugs)
    // ========================================
    
    public static void warn(String category, String message) {
        if (!enabled || !initialized) return;
        String line = formatLine("WARN", category, message);
        writeRaw(line);
    }
    
    public static void warn(String category, String format, Object... args) {
        if (!enabled || !initialized) return;
        String message = (args != null && args.length > 0) ? String.format(format, args) : format;
        warn(category, message);
    }
    
    // ========================================
    // ERROR LOGGING
    // ========================================
    
    public static void error(String category, String message) {
        if (!enabled || !initialized) return;
        String line = formatLine("ERROR", category, message);
        writeRaw(line);
    }
    
    // ========================================
    // TICK LOGGING (throttled)
    // ========================================
    
    public static void tick(String phase, double x, double y, double z, 
                           double vx, double vy, double vz, boolean onGround) {
        if (!enabled || !initialized) return;
        
        tickCounter++;
        
        boolean significantVelocity = Math.abs(vy) > 0.5 || Math.abs(vx) > 1.0 || Math.abs(vz) > 1.0;
        boolean shouldLog = (tickCounter % 10 == 0) || significantVelocity;
        
        if (!shouldLog) return;
        
        long now = System.currentTimeMillis();
        if (now - lastLogTime < MIN_INTERVAL_MS && !significantVelocity) return;
        lastLogTime = now;
        
        String msg = String.format("phase=%s pos=(%.1f, %.1f, %.1f) vel=(%.2f, %.2f, %.2f) ground=%b",
                phase, x, y, z, vx, vy, vz, onGround);
        String line = formatLine("TICK", "MOVE", msg);
        writeRaw(line);
    }
    
    // ========================================
    // VELOCITY/POSITION ANOMALY DETECTION
    // ========================================
    
    public static void velocityCheck(String source, double oldVy, double newVy) {
        if (!enabled || !initialized) return;
        double delta = Math.abs(newVy - oldVy);
        if (delta > 0.5) {
            warn("VELOCITY", String.format("LARGE VELOCITY CHANGE: source=%s oldVy=%.2f newVy=%.2f delta=%.2f",
                    source, oldVy, newVy, delta));
        }
    }
    
    public static void positionJump(String source, double oldY, double newY) {
        if (!enabled || !initialized) return;
        double delta = Math.abs(newY - oldY);
        if (delta > 1.0) {
            warn("POSITION", String.format("POSITION JUMP DETECTED: source=%s oldY=%.2f newY=%.2f delta=%.2f",
                    source, oldY, newY, delta));
        }
    }
    
    // ========================================
    // INTERNAL
    // ========================================
    
    private static String formatLine(String level, String category, String message) {
        String time = TIME_FMT.format(new Date());
        String thread = Thread.currentThread().getName();
        return String.format("[%s] [%-5s] [%-10s] [%-12s] %s", time, level, category, thread, message);
    }
    
    private static void writeRaw(String line) {
        synchronized (LOCK) {
            try {
                writer.write(line);
                writer.newLine();
                writer.flush();
            } catch (IOException ignored) {}
        }
    }
}
'@

[System.IO.File]::WriteAllText((Join-Path $loggerDir "MovementLogger.java"), $loggerContent, $utf8)
Write-Host " [OK] MovementLogger.java created" -ForegroundColor Green

# ============================================================
# STEP 2: Create MovementLoggerService.java (state reader)
# ============================================================
Write-Host "[2/3] Creating MovementLoggerService.java (reads state via public APIs)..." -ForegroundColor Yellow

$serviceContent = @'
// SHINOBICORE INDEPENDENT MOVEMENT LOGGER SERVICE
// This service reads state through public APIs ONLY.
// It does NOT modify any existing movement files.
package com.example.shinobicore.movement.client;

import com.example.shinobicore.util.MovementLogger;
import net.fabricmc.fabric.api.client.event.lifecycle.v1.ClientTickEvents;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.network.ClientPlayerEntity;

/**
 * Independent movement logger service.
 * Subscribes to client ticks and reads state via public APIs.
 * Does NOT modify any existing movement code.
 */
public final class MovementLoggerService {
    private static boolean registered = false;
    
    // State tracking for change detection
    private static String lastPhase = "NORMAL";
    private static boolean lastChakraMode = false;
    private static float lastChakra = -1.0f;
    private static double lastY = Double.NaN;
    private static double lastVy = Double.NaN;
    
    private MovementLoggerService() {}
    
    public static void register() {
        if (registered) return;
        registered = true;
        
        ClientTickEvents.END_CLIENT_TICK.register(MovementLoggerService::tickClient);
        MovementLogger.event("LOGGER", "MovementLoggerService registered");
    }
    
    private static void tickClient(MinecraftClient client) {
        if (client == null || client.player == null || client.world == null) return;
        if (client.isPaused()) return;
        
        ClientPlayerEntity player = client.player;
        
        // Read current state via public APIs
        String currentPhase = getCurrentPhase();
        boolean currentChakraMode = getChakraMode();
        float currentChakra = getChakra();
        double currentY = player.getY();
        double currentVy = player.getVelocity().y;
        
        // Detect phase changes
        if (!currentPhase.equals(lastPhase)) {
            MovementLogger.stateChange(lastPhase, currentPhase, "detected via public API");
            lastPhase = currentPhase;
        }
        
        // Detect chakra mode changes
        if (currentChakraMode != lastChakraMode) {
            MovementLogger.event("CHAKRA", "Mode changed: " + (currentChakraMode ? "ON" : "OFF"));
            lastChakraMode = currentChakraMode;
        }
        
        // Detect large chakra changes
        if (lastChakra >= 0 && Math.abs(currentChakra - lastChakra) > 50.0f) {
            MovementLogger.warn("CHAKRA", String.format("Large chakra change: %.0f -> %.0f (delta=%.0f)",
                    lastChakra, currentChakra, currentChakra - lastChakra));
        }
        lastChakra = currentChakra;
        
        // Detect position jumps (potential teleports)
        if (!Double.isNaN(lastY)) {
            double deltaY = Math.abs(currentY - lastY);
            if (deltaY > 1.5 && Math.abs(currentVy) < 0.1) {
                MovementLogger.positionJump("TICK", lastY, currentY);
            }
        }
        
        // Detect velocity anomalies
        if (!Double.isNaN(lastVy)) {
            double deltaVy = Math.abs(currentVy - lastVy);
            if (deltaVy > 0.8) {
                MovementLogger.velocityCheck("TICK", lastVy, currentVy);
            }
        }
        
        lastY = currentY;
        lastVy = currentVy;
        
        // Periodic tick logging
        MovementLogger.tick(
            currentPhase,
            player.getX(), player.getY(), player.getZ(),
            player.getVelocity().x, player.getVelocity().y, player.getVelocity().z,
            player.isOnGround()
        );
    }
    
    // ========================================
    // Read state via public APIs (no modification)
    // ========================================
    
    private static String getCurrentPhase() {
        try {
            return ClientMovementState.getPhase().name();
        } catch (Throwable ignored) {
            return "UNKNOWN";
        }
    }
    
    private static boolean getChakraMode() {
        try {
            return com.example.shinobicore.chakra.client.ChakraClientController.isChakraModeActive();
        } catch (Throwable ignored) {
            return false;
        }
    }
    
    private static float getChakra() {
        try {
            return com.example.shinobicore.chakra.client.ChakraClientController.getCurrentChakra();
        } catch (Throwable ignored) {
            return 0.0f;
        }
    }
}
'@

$servicePath = Join-Path $srcBase "movement\client\MovementLoggerService.java"
[System.IO.File]::WriteAllText($servicePath, $serviceContent, $utf8)
Write-Host " [OK] MovementLoggerService.java created" -ForegroundColor Green

# ============================================================
# STEP 3: Create MovementLoggerBootstrap.java
# ============================================================
Write-Host "[3/3] Creating MovementLoggerBootstrap.java..." -ForegroundColor Yellow

$bootstrapContent = @'
// SHINOBICORE INDEPENDENT MOVEMENT LOGGER BOOTSTRAP
// Initializes logger and registers service WITHOUT modifying existing files.
package com.example.shinobicore.bootstrap;

import com.example.shinobicore.util.MovementLogger;
import com.example.shinobicore.movement.client.MovementLoggerService;
import com.example.shinobicore.config.FeatureFlags;
import net.fabricmc.api.ClientModInitializer;

/**
 * Independent movement logger bootstrap.
 * Initializes logger and registers service.
 * Does NOT modify any existing movement files.
 */
public class MovementLoggerBootstrap implements ClientModInitializer {
    @Override
    public void onInitializeClient() {
        MovementLogger.init();
        
        if (FeatureFlags.movementV3) {
            MovementLoggerService.register();
        }
    }
}
'@

$bootstrapDir = Join-Path $srcBase "bootstrap"
if (-not (Test-Path $bootstrapDir)) { New-Item -ItemType Directory -Path $bootstrapDir -Force | Out-Null }

$bootstrapPath = Join-Path $bootstrapDir "MovementLoggerBootstrap.java"
[System.IO.File]::WriteAllText($bootstrapPath, $bootstrapContent, $utf8)
Write-Host " [OK] MovementLoggerBootstrap.java created" -ForegroundColor Green

# ============================================================
# STEP 4: Register bootstrap in fabric.mod.json
# ============================================================
Write-Host ""
Write-Host "[4/4] Registering logger entrypoint in fabric.mod.json..." -ForegroundColor Yellow

$fabricModPath = Join-Path $root "src\main\resources\fabric.mod.json"
if (Test-Path $fabricModPath) {
    $json = [System.IO.File]::ReadAllText($fabricModPath, $utf8)
    
    $entrypoint = "com.example.shinobicore.bootstrap.MovementLoggerBootstrap"
    
    if (-not $json.Contains($entrypoint)) {
        # Add to client entrypoints
        $json = $json -replace '("client"\s*:\s*\[)', "`$1`n    `"$entrypoint`","
        [System.IO.File]::WriteAllText($fabricModPath, $json, $utf8)
        Write-Host " [OK] Registered MovementLoggerBootstrap in fabric.mod.json" -ForegroundColor Green
    } else {
        Write-Host " [SKIP] Already registered" -ForegroundColor Yellow
    }
} else {
    Write-Host " [FAIL] fabric.mod.json not found" -ForegroundColor Red
}

# ============================================================
# BUILD
# ============================================================
Write-Host ""
Write-Host "==============================================================" -ForegroundColor Cyan
Write-Host " BUILDING..." -ForegroundColor Cyan
Write-Host "==============================================================" -ForegroundColor Cyan

Push-Location $root
try {
    $prevEAP = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $out = & ".\gradlew.bat" build 2>&1
    $exitCode = $LASTEXITCODE
    $ErrorActionPreference = $prevEAP

    if ($exitCode -eq 0) {
        Write-Host ""
        Write-Host " [PASS] BUILD SUCCESSFUL!" -ForegroundColor Green
        Write-Host ""
        Write-Host "==============================================================" -ForegroundColor Green
        Write-Host " INDEPENDENT MOVEMENT LOGGER INSTALLED" -ForegroundColor Green
        Write-Host "==============================================================" -ForegroundColor Green
        Write-Host ""
        Write-Host "What this logger does:" -ForegroundColor Yellow
        Write-Host "  - Reads movement state via public APIs (no code modification)" -ForegroundColor White
        Write-Host "  - Detects phase transitions (NORMAL -> WALL_RUNNING, etc.)" -ForegroundColor White
        Write-Host "  - Detects chakra mode changes" -ForegroundColor White
        Write-Host "  - Detects large velocity changes (potential teleports)" -ForegroundColor White
        Write-Host "  - Detects position jumps (potential bugs)" -ForegroundColor White
        Write-Host "  - Logs periodic position/velocity snapshots" -ForegroundColor White
        Write-Host ""
        Write-Host "How to use:" -ForegroundColor Yellow
        Write-Host "  1. Run: .\gradlew.bat runClient" -ForegroundColor White
        Write-Host "  2. Play and test all movement mechanics" -ForegroundColor White
        Write-Host "  3. Close the game" -ForegroundColor White
        Write-Host "  4. Open: E:\Games\mod\run\log_movement.txt" -ForegroundColor White
        Write-Host ""
        Write-Host "The log will contain:" -ForegroundColor Cyan
        Write-Host "  [EVENT]  - State changes (chakra mode, etc.)" -ForegroundColor White
        Write-Host "  [STATE]  - Phase transitions" -ForegroundColor White
        Write-Host "  [WARN]   - Potential bugs (large velocity/position changes)" -ForegroundColor White
        Write-Host "  [TICK]   - Periodic position/velocity snapshots" -ForegroundColor White
        Write-Host ""
        Write-Host "IMPORTANT: This logger does NOT modify any existing movement files!" -ForegroundColor Green
        Write-Host "It works purely through public APIs and event subscriptions." -ForegroundColor Green
        Write-Host ""
    } else {
        Write-Host ""
        Write-Host " [FAIL] Build failed:" -ForegroundColor Red
        $out | Where-Object { $_ -match "error:" } | Select-Object -First 30 | ForEach-Object { Write-Host " $_" -ForegroundColor Red }
    }
} finally {
    Pop-Location
}

exit 0