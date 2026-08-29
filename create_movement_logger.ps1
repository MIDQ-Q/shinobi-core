$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$root = "E:\Games\mod"
$srcBase = Join-Path $root "src\main\java\com\example\shinobicore"

Write-Host ""
Write-Host "==============================================================" -ForegroundColor Cyan
Write-Host " CREATING: Comprehensive Movement Logger" -ForegroundColor Cyan
Write-Host " Output: log_movement.txt in game directory" -ForegroundColor Cyan
Write-Host "==============================================================" -ForegroundColor Cyan
Write-Host ""

# ============================================================
# STEP 1: Create MovementLogger.java
# ============================================================
Write-Host "[1/8] Creating MovementLogger.java..." -ForegroundColor Yellow

$loggerDir = Join-Path $srcBase "util"
if (-not (Test-Path $loggerDir)) { New-Item -ItemType Directory -Path $loggerDir -Force | Out-Null }

$loggerContent = @'
// SHINOBICORE MOVEMENT LOGGER
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
 * Comprehensive movement logger.
 * Writes to log_movement.txt in the game directory.
 * Tracks all movement events, state changes, velocity, and bugs.
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
    private static final long MIN_INTERVAL_MS = 50; // Max 20 logs per second for tick logs
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
            writeRaw("SHINOBICORE MOVEMENT LOGGER - Session started: " + new SimpleDateFormat("yyyy-MM-dd HH:mm:ss").format(new Date()));
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
    // ERROR LOGGING (definite bugs)
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
        
        // Log every 10 ticks (0.5 seconds) or on significant velocity changes
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
    // CHAKRA LOGGING
    // ========================================
    
    public static void chakra(String action, float current, float max, boolean mode) {
        if (!enabled || !initialized) return;
        String msg = String.format("action=%s chakra=%.0f/%.0f mode=%s", action, current, max, mode ? "ON" : "OFF");
        String line = formatLine("CHAKRA", "CHAKRA", msg);
        writeRaw(line);
    }
    
    // ========================================
    // VELOCITY TELEPORT DETECTION
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
                writer.flush(); // Flush immediately for debugging
            } catch (IOException ignored) {}
        }
    }
}
'@

[System.IO.File]::WriteAllText((Join-Path $loggerDir "MovementLogger.java"), $loggerContent, $utf8)
Write-Host " [OK] MovementLogger.java created" -ForegroundColor Green

# ============================================================
# STEP 2: Create MovementLoggerInitializer.java
# ============================================================
Write-Host "[2/8] Creating MovementLoggerInitializer.java..." -ForegroundColor Yellow

$initDir = Join-Path $srcBase "bootstrap"
if (-not (Test-Path $initDir)) { New-Item -ItemType Directory -Path $initDir -Force | Out-Null }

$initContent = @'
// SHINOBICORE MOVEMENT LOGGER INITIALIZER
package com.example.shinobicore.bootstrap;

import com.example.shinobicore.util.MovementLogger;
import net.fabricmc.api.ModInitializer;

/**
 * Initializes the movement logger.
 */
public class MovementLoggerInitializer implements ModInitializer {
    @Override
    public void onInitialize() {
        MovementLogger.init();
        MovementLogger.event("INIT", "Movement logger initialized");
    }
}
'@

[System.IO.File]::WriteAllText((Join-Path $initDir "MovementLoggerInitializer.java"), $initContent, $utf8)
Write-Host " [OK] MovementLoggerInitializer.java created" -ForegroundColor Green

# ============================================================
# STEP 3: Patch ClientMovementService.java
# ============================================================
Write-Host "[3/8] Patching ClientMovementService.java..." -ForegroundColor Yellow

$servicePath = Join-Path $srcBase "movement\client\ClientMovementService.java"
if (Test-Path $servicePath) {
    $c = [System.IO.File]::ReadAllText($servicePath, $utf8)
    
    # Add import
    if (-not $c.Contains("import com.example.shinobicore.util.MovementLogger;")) {
        $c = $c.Replace("package com.example.shinobicore.movement.client;", 
                        "package com.example.shinobicore.movement.client;`nimport com.example.shinobicore.util.MovementLogger;")
    }
    
    # Add tick logging after ClientMovementState.tick()
    if (-not $c.Contains("MovementLogger.tick(")) {
        $oldTick = "ClientMovementState.tick();"
        $newTick = @'
ClientMovementState.tick();
        
        // MOVEMENT LOGGER: Track every tick
        MovementLogger.tick(
            ClientMovementState.getPhase().name(),
            client.player.getX(), client.player.getY(), client.player.getZ(),
            client.player.getVelocity().x, client.player.getVelocity().y, client.player.getVelocity().z,
            client.player.isOnGround()
        );
'@
        $c = $c.Replace($oldTick, $newTick)
        Write-Host " [OK] Added tick logging" -ForegroundColor Green
    }
    
    # Log phase resets
    if (-not $c.Contains('MovementLogger.stateChange')) {
        $oldReset = "ClientMovementState.setPhase(MovementPhase.NORMAL);"
        $newReset = @'
MovementLogger.stateChange(ClientMovementState.getPhase().name(), "NORMAL", "all subsystems inactive");
            ClientMovementState.setPhase(MovementPhase.NORMAL);
'@
        $c = $c.Replace($oldReset, $newReset)
        Write-Host " [OK] Added phase reset logging" -ForegroundColor Green
    }
    
    [System.IO.File]::WriteAllText($servicePath, $c, $utf8)
} else {
    Write-Host " [MISS] ClientMovementService.java not found" -ForegroundColor Red
}

# ============================================================
# STEP 4: Patch ChakraClientController.java
# ============================================================
Write-Host "[4/8] Patching ChakraClientController.java..." -ForegroundColor Yellow

$chakraPath = Join-Path $srcBase "chakra\client\ChakraClientController.java"
if (Test-Path $chakraPath) {
    $c = [System.IO.File]::ReadAllText($chakraPath, $utf8)
    
    # Add import
    if (-not $c.Contains("import com.example.shinobicore.util.MovementLogger;")) {
        $c = $c.Replace("package com.example.shinobicore.chakra.client;", 
                        "package com.example.shinobicore.chakra.client;`nimport com.example.shinobicore.util.MovementLogger;")
    }
    
    # Log chakra mode toggle
    if (-not $c.Contains('MovementLogger.chakra("MODE_TOGGLE"')) {
        $oldToggle = "public static void toggleChakraMode()"
        if ($c.Contains($oldToggle)) {
            $c = $c.Replace($oldToggle, @'
public static void toggleChakraMode() {
        MovementLogger.chakra("MODE_TOGGLE", currentChakra, maxChakra, chakraMode);
'@)
            Write-Host " [OK] Added chakra mode toggle logging" -ForegroundColor Green
        }
    }
    
    # Log chakra consumption
    if (-not $c.Contains('MovementLogger.chakra("CONSUME"')) {
        $oldConsume = "public static boolean consumeChakra(float amount)"
        if ($c.Contains($oldConsume)) {
            $c = $c.Replace($oldConsume, @'
public static boolean consumeChakra(float amount) {
        MovementLogger.chakra("CONSUME_" + amount, currentChakra, maxChakra, chakraMode);
'@)
            Write-Host " [OK] Added chakra consume logging" -ForegroundColor Green
        }
    }
    
    [System.IO.File]::WriteAllText($chakraPath, $c, $utf8)
} else {
    Write-Host " [MISS] ChakraClientController.java not found" -ForegroundColor Red
}

# ============================================================
# STEP 5: Patch WaterWalkClient.java
# ============================================================
Write-Host "[5/8] Patching WaterWalkClient.java..." -ForegroundColor Yellow

$waterPath = Join-Path $srcBase "movement\client\WaterWalkClient.java"
if (Test-Path $waterPath) {
    $c = [System.IO.File]::ReadAllText($waterPath, $utf8)
    
    if (-not $c.Contains("import com.example.shinobicore.util.MovementLogger;")) {
        $c = $c.Replace("package com.example.shinobicore.movement.client;", 
                        "package com.example.shinobicore.movement.client;`nimport com.example.shinobicore.util.MovementLogger;")
    }
    
    # Log water walk start
    if (-not $c.Contains('MovementLogger.event("WATER"')) {
        $oldStart = "setActive(true);"
        if ($c.Contains($oldStart)) {
            $c = $c.Replace($oldStart, @'
setActive(true);
            MovementLogger.event("WATER", "Water walk STARTED | pos=(%.1f, %.1f, %.1f)", player.getX(), player.getY(), player.getZ());
'@)
            Write-Host " [OK] Added water walk start logging" -ForegroundColor Green
        }
    }
    
    # Log water walk stop
    if (-not $c.Contains('MovementLogger.event("WATER", "Water walk STOPPED"')) {
        $oldStop = "setActive(false);"
        if ($c.Contains($oldStop)) {
            $c = $c.Replace($oldStop, @'
setActive(false);
            MovementLogger.event("WATER", "Water walk STOPPED | pos=(%.1f, %.1f, %.1f)", player.getX(), player.getY(), player.getZ());
'@)
            Write-Host " [OK] Added water walk stop logging" -ForegroundColor Green
        }
    }
    
    # Log water jump
    if ($c.Contains("FIX: Allow jumping from water") -and -not $c.Contains('MovementLogger.event("WATER", "JUMP from water"')) {
        $oldJump = "player.setVelocity(jumpVel.x, 0.42, jumpVel.z);"
        if ($c.Contains($oldJump)) {
            $c = $c.Replace($oldJump, @'
player.setVelocity(jumpVel.x, 0.42, jumpVel.z);
            MovementLogger.event("WATER", "JUMP from water | velY=0.42");
            MovementLogger.velocityCheck("WATER_JUMP", player.getVelocity().y, 0.42);
'@)
            Write-Host " [OK] Added water jump logging" -ForegroundColor Green
        }
    }
    
    [System.IO.File]::WriteAllText($waterPath, $c, $utf8)
} else {
    Write-Host " [MISS] WaterWalkClient.java not found" -ForegroundColor Red
}

# ============================================================
# STEP 6: Patch WallRunClient.java
# ============================================================
Write-Host "[6/8] Patching WallRunClient.java..." -ForegroundColor Yellow

$wallPath = Join-Path $srcBase "movement\client\WallRunClient.java"
if (Test-Path $wallPath) {
    $c = [System.IO.File]::ReadAllText($wallPath, $utf8)
    
    if (-not $c.Contains("import com.example.shinobicore.util.MovementLogger;")) {
        $c = $c.Replace("package com.example.shinobicore.movement.client;", 
                        "package com.example.shinobicore.movement.client;`nimport com.example.shinobicore.util.MovementLogger;")
    }
    
    # Log wall run start
    if (-not $c.Contains('MovementLogger.event("WALL"')) {
        $oldActive = "active = true;"
        if ($c.Contains($oldActive)) {
            $c = $c.Replace($oldActive, @'
active = true;
            MovementLogger.event("WALL", "Wall run STARTED | pos=(%.1f, %.1f, %.1f) normal=%s", 
                player.getX(), player.getY(), player.getZ(), normal != null ? normal.toString() : "null");
'@)
            Write-Host " [OK] Added wall run start logging" -ForegroundColor Green
        }
    }
    
    # Log wall run stop
    if (-not $c.Contains('MovementLogger.event("WALL", "Wall run STOPPED"')) {
        $oldStop = "active = false;"
        if ($c.Contains($oldStop)) {
            $c = $c.Replace($oldStop, @'
active = false;
            MovementLogger.event("WALL", "Wall run STOPPED | pos=(%.1f, %.1f, %.1f)", player.getX(), player.getY(), player.getZ());
'@)
            Write-Host " [OK] Added wall run stop logging" -ForegroundColor Green
        }
    }
    
    # Log wall jump
    if ($c.Contains("performWallJump") -and -not $c.Contains('MovementLogger.event("WALL", "WALL JUMP"')) {
        $oldWallJump = "private static void performWallJump(ClientPlayerEntity player, Vec3d normal)"
        if ($c.Contains($oldWallJump)) {
            $c = $c.Replace($oldWallJump, @'
private static void performWallJump(ClientPlayerEntity player, Vec3d normal) {
        MovementLogger.event("WALL", "WALL JUMP | normal=%s vel=(%.2f, %.2f, %.2f)", 
            normal != null ? normal.toString() : "null", 
            player.getVelocity().x, player.getVelocity().y, player.getVelocity().z);
'@)
            Write-Host " [OK] Added wall jump logging" -ForegroundColor Green
        }
    }
    
    [System.IO.File]::WriteAllText($wallPath, $c, $utf8)
} else {
    Write-Host " [MISS] WallRunClient.java not found" -ForegroundColor Red
}

# ============================================================
# STEP 7: Patch ChargedJumpClient.java and EdgeGrabClient.java
# ============================================================
Write-Host "[7/8] Patching ChargedJumpClient.java and EdgeGrabClient.java..." -ForegroundColor Yellow

# ChargedJumpClient
$chargedPath = Join-Path $srcBase "movement\client\ChargedJumpClient.java"
if (Test-Path $chargedPath) {
    $c = [System.IO.File]::ReadAllText($chargedPath, $utf8)
    
    if (-not $c.Contains("import com.example.shinobicore.util.MovementLogger;")) {
        $c = $c.Replace("package com.example.shinobicore.movement.client;", 
                        "package com.example.shinobicore.movement.client;`nimport com.example.shinobicore.util.MovementLogger;")
    }
    
    # Log charged jump release
    if (-not $c.Contains('MovementLogger.event("JUMP"')) {
        $oldRelease = "private static void release(ClientPlayerEntity player)"
        if ($c.Contains($oldRelease)) {
            $c = $c.Replace($oldRelease, @'
private static void release(ClientPlayerEntity player) {
        MovementLogger.event("JUMP", "Charged jump RELEASE | chargeTicks=%d | pos=(%.1f, %.1f, %.1f)", 
            chargeTicks, player.getX(), player.getY(), player.getZ());
'@)
            Write-Host " [OK] Added charged jump logging" -ForegroundColor Green
        }
    }
    
    [System.IO.File]::WriteAllText($chargedPath, $c, $utf8)
} else {
    Write-Host " [MISS] ChargedJumpClient.java not found" -ForegroundColor Red
}

# EdgeGrabClient
$edgePath = Join-Path $srcBase "movement\client\EdgeGrabClient.java"
if (Test-Path $edgePath) {
    $c = [System.IO.File]::ReadAllText($edgePath, $utf8)
    
    if (-not $c.Contains("import com.example.shinobicore.util.MovementLogger;")) {
        $c = $c.Replace("package com.example.shinobicore.movement.client;", 
                        "package com.example.shinobicore.movement.client;`nimport com.example.shinobicore.util.MovementLogger;")
    }
    
    # Log edge grab
    if (-not $c.Contains('MovementLogger.event("EDGE"')) {
        $oldStart = "private static void start(ClientPlayerEntity player)"
        if ($c.Contains($oldStart)) {
            $c = $c.Replace($oldStart, @'
private static void start(ClientPlayerEntity player) {
        MovementLogger.event("EDGE", "Edge grab STARTED | pos=(%.1f, %.1f, %.1f)", 
            player.getX(), player.getY(), player.getZ());
'@)
            Write-Host " [OK] Added edge grab logging" -ForegroundColor Green
        }
    }
    
    # Log edge climb
    if ($c.Contains("climbUp") -and -not $c.Contains('MovementLogger.event("EDGE", "Edge CLIMB"')) {
        $oldClimb = "private static void climbUp(ClientPlayerEntity player)"
        if ($c.Contains($oldClimb)) {
            $c = $c.Replace($oldClimb, @'
private static void climbUp(ClientPlayerEntity player) {
        double oldY = player.getY();
        MovementLogger.event("EDGE", "Edge CLIMB | oldY=%.2f", oldY);
'@)
            # Also log position change after setPosition
            if ($c.Contains("player.setPosition(position.x, position.y + CLIMB_UP_Y, position.z);")) {
                $c = $c.Replace("player.setPosition(position.x, position.y + CLIMB_UP_Y, position.z);", @'
player.setPosition(position.x, position.y + CLIMB_UP_Y, position.z);
        MovementLogger.positionJump("EDGE_CLIMB", oldY, player.getY());
'@)
            }
            Write-Host " [OK] Added edge climb logging" -ForegroundColor Green
        }
    }
    
    [System.IO.File]::WriteAllText($edgePath, $c, $utf8)
} else {
    Write-Host " [MISS] EdgeGrabClient.java not found" -ForegroundColor Red
}

# ============================================================
# STEP 8: Register logger in fabric.mod.json
# ============================================================
Write-Host "[8/8] Registering logger entrypoint..." -ForegroundColor Yellow

$fabricModPath = Join-Path $root "src\main\resources\fabric.mod.json"
if (Test-Path $fabricModPath) {
    $json = [System.IO.File]::ReadAllText($fabricModPath, $utf8)
    
    $entrypoint = "com.example.shinobicore.bootstrap.MovementLoggerInitializer"
    
    if (-not $json.Contains($entrypoint)) {
        # Add to main entrypoints
        $json = $json -replace '("main"\s*:\s*\[)', "`$1`n    `"$entrypoint`","
        [System.IO.File]::WriteAllText($fabricModPath, $json, $utf8)
        Write-Host " [OK] Registered MovementLoggerInitializer in fabric.mod.json" -ForegroundColor Green
    } else {
        Write-Host " [SKIP] Already registered" -ForegroundColor Yellow
    }
} else {
    Write-Host " [MISS] fabric.mod.json not found" -ForegroundColor Red
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
        Write-Host " MOVEMENT LOGGER INSTALLED" -ForegroundColor Green
        Write-Host "==============================================================" -ForegroundColor Green
        Write-Host ""
        Write-Host "How to use:" -ForegroundColor Yellow
        Write-Host "  1. Run: .\gradlew.bat runClient" -ForegroundColor White
        Write-Host "  2. Play and test all movement mechanics" -ForegroundColor White
        Write-Host "  3. Close the game" -ForegroundColor White
        Write-Host "  4. Open: E:\Games\mod\run\log_movement.txt" -ForegroundColor White
        Write-Host ""
        Write-Host "The log will contain:" -ForegroundColor Cyan
        Write-Host "  [EVENT]  - State changes (water start/stop, wall start/stop, etc.)" -ForegroundColor White
        Write-Host "  [STATE]  - Phase transitions" -ForegroundColor White
        Write-Host "  [WARN]   - Potential bugs (large velocity changes, position jumps)" -ForegroundColor White
        Write-Host "  [ERROR]  - Definite bugs" -ForegroundColor White
        Write-Host "  [TICK]   - Periodic position/velocity snapshots (every 10 ticks)" -ForegroundColor White
        Write-Host "  [CHAKRA] - Chakra mode changes and consumption" -ForegroundColor White
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