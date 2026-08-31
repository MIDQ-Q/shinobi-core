# ShinobiCore: Visual Module Finalization (Phase 7 - Definition of Done)
# Completes all remaining DoD items: commands, listeners, colors, README, full config.
# Run from the root directory of your project.

$ErrorActionPreference = "Stop"

Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "  ShinobiCore: Visual Finalization (Phase 7 - DoD)" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan

$BasePath = "src/main/java/com/example/shinobicore/modules/visual"
$UtilPath = Join-Path $BasePath "util"
$ListenerPath = Join-Path $BasePath "listener"
$CommandPath = Join-Path $BasePath "command"
$ConfigPath = Join-Path $BasePath "config"
$StubPath = Join-Path $BasePath "stub"
$ReadmePath = $BasePath

Write-Host "[1/8] Creating directory structure..." -ForegroundColor Yellow
New-Item -ItemType Directory -Force -Path $UtilPath, $ListenerPath, $CommandPath, $ConfigPath, $StubPath | Out-Null
Write-Host "      Directories created." -ForegroundColor Green

function Write-JavaFile {
    param ([string]$FilePath, [string]$Content)
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($FilePath, $Content, $utf8NoBom)
    Write-Host "      [OK] Created: $FilePath" -ForegroundColor Green
}

function Write-TextFile {
    param ([string]$FilePath, [string]$Content)
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($FilePath, $Content, $utf8NoBom)
    Write-Host "      [OK] Created: $FilePath" -ForegroundColor Green
}

# ---- [2/8] ParticleColors ----
Write-Host "[2/8] Generating ParticleColors.java..." -ForegroundColor Yellow
$f1 = @"
package com.example.shinobicore.modules.visual.util;

public final class ParticleColors {
    public static final int FIRE = 0xFFFF4400;
    public static final int WATER = 0xFF0088FF;
    public static final int WIND = 0xFF88FFCC;
    public static final int EARTH = 0xFFAA7744;
    public static final int LIGHTNING = 0xFFFFEE00;
    public static final int ICE = 0xFFAAEEFF;
    public static final int LAVA = 0xFFFF2200;
    public static final int POISON = 0xFF88FF00;
    public static final int HEAL = 0xFF00FF88;
    public static final int DARK = 0xFF440066;
    public static final int LIGHT = 0xFFFFDDAA;
    public static final int WHITE = 0xFFFFFFFF;
    public static final int GOLD = 0xFFFFD700;
    public static final int BLUE = 0xFF4499FF;
    public static final int RED = 0xFFFF3333;
    public static final int GREEN = 0xFF33FF33;
    public static final int BROWN = 0xFF8B6914;
    public static final int GRAY = 0xFFAAAAAA;

    public static int getElementColor(String elementId) {
        if (elementId == null) return WHITE;
        switch (elementId.toLowerCase()) {
            case "fire": case "katon": return FIRE;
            case "water": case "suiton": return WATER;
            case "wind": case "fuuton": return WIND;
            case "earth": case "doton": return EARTH;
            case "lightning": case "raiton": return LIGHTNING;
            case "ice": case "hyouton": return ICE;
            case "lava": case "youton": return LAVA;
            case "poison": return POISON;
            case "heal": case "medical": return HEAL;
            case "dark": case "shadow": return DARK;
            case "light": return LIGHT;
            default: return WHITE;
        }
    }

    public static float getRed(int color) { return ((color >> 16) & 0xFF) / 255.0f; }
    public static float getGreen(int color) { return ((color >> 8) & 0xFF) / 255.0f; }
    public static float getBlue(int color) { return (color & 0xFF) / 255.0f; }
    public static float getAlpha(int color) { return ((color >> 24) & 0xFF) / 255.0f; }
}
"@
Write-JavaFile -FilePath "$UtilPath\ParticleColors.java" -Content $f1

# ---- [3/8] Full VisualConfig (all fields from TZ) ----
Write-Host "[3/8] Generating Full VisualConfig.java..." -ForegroundColor Yellow
$f2 = @"
package com.example.shinobicore.modules.visual.config;

import com.example.shinobicore.core.log.ShinobiLogger;
import com.google.gson.JsonObject;

public class VisualConfig {
    private static VisualConfig INSTANCE;

    public boolean enabled = true;
    public boolean debug = false;
    public String qualityPreset = "default";

    public ParticleConfig particles = new ParticleConfig();
    public TrailConfig trails = new TrailConfig();
    public AuraConfig auras = new AuraConfig();
    public CameraShakeConfig cameraShake = new CameraShakeConfig();
    public ScreenFlashConfig screenFlash = new ScreenFlashConfig();
    public MovementEffectsConfig movement = new MovementEffectsConfig();
    public CombatEffectsConfig combat = new CombatEffectsConfig();
    public CullingConfig culling = new CullingConfig();
    public LoggingConfig logging = new LoggingConfig();

    public static void load(JsonObject json) {
        INSTANCE = new VisualConfig();
        if (json == null) return;

        try {
            if (json.has("enabled")) INSTANCE.enabled = json.get("enabled").getAsBoolean();
            if (json.has("debug")) INSTANCE.debug = json.get("debug").getAsBoolean();
            if (json.has("qualityPreset")) INSTANCE.qualityPreset = json.get("qualityPreset").getAsString();

            if (json.has("particles") && json.get("particles").isJsonObject()) {
                JsonObject p = json.getAsJsonObject("particles");
                if (p.has("particlePoolSize")) INSTANCE.particles.poolSize = p.get("particlePoolSize").getAsInt();
                if (p.has("maxParticlesPerFrame")) INSTANCE.particles.maxPerFrame = p.get("maxParticlesPerFrame").getAsInt();
                if (p.has("maxParticlesPerSecond")) INSTANCE.particles.maxPerSecond = p.get("maxParticlesPerSecond").getAsInt();
                if (p.has("cullDistance")) INSTANCE.culling.distance = p.get("cullDistance").getAsDouble();
                if (p.has("cooldownMs")) INSTANCE.particles.cooldownMs = p.get("cooldownMs").getAsLong();
            }
            if (json.has("trails") && json.get("trails").isJsonObject()) {
                JsonObject t = json.getAsJsonObject("trails");
                if (t.has("trailPoolSize")) INSTANCE.trails.poolSize = t.get("trailPoolSize").getAsInt();
                if (t.has("weaponTrailLifetime")) INSTANCE.trails.weaponLifetime = t.get("weaponTrailLifetime").getAsInt();
                if (t.has("dashTrailLifetime")) INSTANCE.trails.dashLifetime = t.get("dashTrailLifetime").getAsInt();
            }
            if (json.has("auras") && json.get("auras").isJsonObject()) {
                JsonObject a = json.getAsJsonObject("auras");
                if (a.has("chakraAuraColor")) INSTANCE.auras.chakraAuraColor = parseColor(a.get("chakraAuraColor").getAsString());
                if (a.has("chakraAuraParticleRate")) INSTANCE.auras.particleRate = a.get("chakraAuraParticleRate").getAsInt();
            }
            if (json.has("cameraShake") && json.get("cameraShake").isJsonObject()) {
                JsonObject cs = json.getAsJsonObject("cameraShake");
                if (cs.has("enabled")) INSTANCE.cameraShake.enabled = cs.get("enabled").getAsBoolean();
                if (cs.has("maxIntensity")) INSTANCE.cameraShake.maxIntensity = cs.get("maxIntensity").getAsFloat();
                if (cs.has("impactShakeIntensity")) INSTANCE.cameraShake.impactIntensity = cs.get("impactShakeIntensity").getAsFloat();
                if (cs.has("explosionShakeIntensity")) INSTANCE.cameraShake.explosionIntensity = cs.get("explosionShakeIntensity").getAsFloat();
            }
            if (json.has("screenFlash") && json.get("screenFlash").isJsonObject()) {
                JsonObject sf = json.getAsJsonObject("screenFlash");
                if (sf.has("enabled")) INSTANCE.screenFlash.enabled = sf.get("enabled").getAsBoolean();
                if (sf.has("levelUpFlashColor")) INSTANCE.screenFlash.levelUpColor = parseColor(sf.get("levelUpFlashColor").getAsString());
                if (sf.has("levelUpFlashDuration")) INSTANCE.screenFlash.levelUpDuration = sf.get("levelUpFlashDuration").getAsInt();
                if (sf.has("castFlashEnabled")) INSTANCE.screenFlash.castFlashEnabled = sf.get("castFlashEnabled").getAsBoolean();
            }
            if (json.has("movement") && json.get("movement").isJsonObject()) {
                JsonObject m = json.getAsJsonObject("movement");
                if (m.has("waterRippleEnabled")) INSTANCE.movement.waterRipple = m.get("waterRippleEnabled").getAsBoolean();
                if (m.has("wallRunDustEnabled")) INSTANCE.movement.wallRunDust = m.get("wallRunDustEnabled").getAsBoolean();
                if (m.has("slideDustEnabled")) INSTANCE.movement.slideDust = m.get("slideDustEnabled").getAsBoolean();
                if (m.has("rollDustEnabled")) INSTANCE.movement.rollDust = m.get("rollDustEnabled").getAsBoolean();
                if (m.has("dodgeBlurEnabled")) INSTANCE.movement.dodgeBlur = m.get("dodgeBlurEnabled").getAsBoolean();
            }
            if (json.has("combat") && json.get("combat").isJsonObject()) {
                JsonObject c = json.getAsJsonObject("combat");
                if (c.has("hitSparkEnabled")) INSTANCE.combat.hitSpark = c.get("hitSparkEnabled").getAsBoolean();
                if (c.has("blockFlashEnabled")) INSTANCE.combat.blockFlash = c.get("blockFlashEnabled").getAsBoolean();
                if (c.has("parryFlashEnabled")) INSTANCE.combat.parryFlash = c.get("parryFlashEnabled").getAsBoolean();
                if (c.has("kickDustEnabled")) INSTANCE.combat.kickDust = c.get("kickDustEnabled").getAsBoolean();
            }
            if (json.has("logging") && json.get("logging").isJsonObject()) {
                JsonObject l = json.getAsJsonObject("logging");
                if (l.has("logParticleSpawns")) INSTANCE.logging.logSpawns = l.get("logParticleSpawns").getAsBoolean();
                if (l.has("logPoolExhaustion")) INSTANCE.logging.logPoolExhaustion = l.get("logPoolExhaustion").getAsBoolean();
            }

            // Apply quality preset overrides
            applyPreset(INSTANCE.qualityPreset);

        } catch (Exception e) {
            ShinobiLogger.error("visual", "Failed to parse config, using defaults", e);
        }
    }

    private static void applyPreset(String preset) {
        if (INSTANCE == null) return;
        switch (preset.toLowerCase()) {
            case "low":
                INSTANCE.particles.maxPerFrame = 20;
                INSTANCE.particles.maxPerSecond = 80;
                INSTANCE.culling.distance = 16.0;
                INSTANCE.cameraShake.enabled = false;
                INSTANCE.trails.enabled = false;
                break;
            case "medium":
                INSTANCE.particles.maxPerFrame = 35;
                INSTANCE.particles.maxPerSecond = 140;
                INSTANCE.culling.distance = 24.0;
                break;
            case "high":
            case "default":
            default:
                break;
        }
    }

    private static int parseColor(String hex) {
        try {
            String clean = hex.replace("0x", "").replace("#", "");
            return (int) Long.parseLong(clean, 16);
        } catch (NumberFormatException e) {
            return 0xFFFFFFFF;
        }
    }

    public static VisualConfig get() {
        if (INSTANCE == null) INSTANCE = new VisualConfig();
        return INSTANCE;
    }

    public static class ParticleConfig {
        public int poolSize = 512;
        public int maxPerFrame = 50;
        public int maxPerSecond = 200;
        public long cooldownMs = 100;
    }
    public static class TrailConfig {
        public boolean enabled = true;
        public int poolSize = 64;
        public int weaponLifetime = 8;
        public int dashLifetime = 5;
    }
    public static class AuraConfig {
        public boolean enabled = true;
        public int chakraAuraColor = 0xFF4499FF;
        public int particleRate = 3;
    }
    public static class CameraShakeConfig {
        public boolean enabled = true;
        public float maxIntensity = 5.0f;
        public float impactIntensity = 1.0f;
        public float explosionIntensity = 3.0f;
    }
    public static class ScreenFlashConfig {
        public boolean enabled = true;
        public int levelUpColor = 0xFFFFD700;
        public int levelUpDuration = 15;
        public boolean castFlashEnabled = true;
    }
    public static class MovementEffectsConfig {
        public boolean waterRipple = true;
        public boolean wallRunDust = true;
        public boolean slideDust = true;
        public boolean rollDust = true;
        public boolean dodgeBlur = true;
    }
    public static class CombatEffectsConfig {
        public boolean hitSpark = true;
        public boolean blockFlash = true;
        public boolean parryFlash = true;
        public boolean kickDust = true;
    }
    public static class CullingConfig {
        public double distance = 32.0;
    }
    public static class LoggingConfig {
        public boolean logSpawns = false;
        public boolean logPoolExhaustion = true;
    }
}
"@
Write-JavaFile -FilePath "$ConfigPath\VisualConfig.java" -Content $f2

# ---- [4/8] Missing Listeners ----
Write-Host "[4/8] Generating Movement/Enemy/Progression Listeners..." -ForegroundColor Yellow

$f3 = @"
package com.example.shinobicore.modules.visual.listener;

import com.example.shinobicore.modules.visual.config.VisualConfig;
import com.example.shinobicore.modules.visual.particle.ParticleService;
import com.example.shinobicore.modules.visual.pool.ParticlePool;
import com.example.shinobicore.modules.visual.stub.StubEvents;
import com.example.shinobicore.modules.visual.util.EffectRateLimiter;
import com.example.shinobicore.modules.visual.util.ParticleColors;
import net.minecraft.util.math.Vec3d;

public final class MovementVisualListener {

    public static void onWaterWalkStarted(StubEvents.WaterWalkStartedEvent event) {
        if (!VisualConfig.get().movement.waterRipple) return;
        if (!EffectRateLimiter.canPlayEffect("water_ripple")) return;
        emitRipple(event.player.getPos(), ParticleColors.WATER, 15);
        EffectRateLimiter.onEffectPlayed("water_ripple");
    }

    public static void onWallRunStarted(StubEvents.WallRunStartedEvent event) {
        if (!VisualConfig.get().movement.wallRunDust) return;
        if (!EffectRateLimiter.canPlayEffect("wallrun_dust")) return;
        emitDust(event.player.getPos(), ParticleColors.GRAY, 5);
        EffectRateLimiter.onEffectPlayed("wallrun_dust");
    }

    public static void onSlideStarted(StubEvents.SlideStartedEvent event) {
        if (!VisualConfig.get().movement.slideDust) return;
        if (!EffectRateLimiter.canPlayEffect("slide_dust")) return;
        emitDust(event.player.getPos(), ParticleColors.BROWN, 6);
        EffectRateLimiter.onEffectPlayed("slide_dust");
    }

    public static void onRollStarted(StubEvents.RollStartedEvent event) {
        if (!VisualConfig.get().movement.rollDust) return;
        if (!EffectRateLimiter.canPlayEffect("roll_dust")) return;
        emitDust(event.player.getPos(), ParticleColors.BROWN, 8);
        EffectRateLimiter.onEffectPlayed("roll_dust");
    }

    public static void onDodge(StubEvents.DodgeEvent event) {
        if (!VisualConfig.get().movement.dodgeBlur) return;
        if (!EffectRateLimiter.canPlayEffect("dodge_blur")) return;
        emitDust(event.player.getPos(), ParticleColors.WHITE, 12);
        EffectRateLimiter.onEffectPlayed("dodge_blur");
    }

    private static void emitRipple(Vec3d pos, int color, int count) {
        for (int i = 0; i < count; i++) {
            if (!ParticleService.canSpawnParticle()) break;
            ParticlePool.PooledParticle p = ParticlePool.acquire();
            if (p == null) break;
            float angle = (float)(Math.random() * Math.PI * 2);
            float speed = 0.05f + (float)(Math.random() * 0.08f);
            p.init((float)pos.x, (float)pos.y + 0.1f, (float)pos.z,
                   (float)Math.cos(angle) * speed, 0.02f, (float)Math.sin(angle) * speed,
                   color, 20);
            ParticleService.onParticleSpawned();
        }
    }

    private static void emitDust(Vec3d pos, int color, int count) {
        for (int i = 0; i < count; i++) {
            if (!ParticleService.canSpawnParticle()) break;
            ParticlePool.PooledParticle p = ParticlePool.acquire();
            if (p == null) break;
            float vx = (float)(Math.random() - 0.5) * 0.1f;
            float vy = (float)(Math.random()) * 0.08f;
            float vz = (float)(Math.random() - 0.5) * 0.1f;
            p.init((float)pos.x, (float)pos.y + 0.2f, (float)pos.z, vx, vy, vz, color, 10);
            ParticleService.onParticleSpawned();
        }
    }
}
"@
Write-JavaFile -FilePath "$ListenerPath\MovementVisualListener.java" -Content $f3

$f4 = @"
package com.example.shinobicore.modules.visual.listener;

import com.example.shinobicore.modules.visual.particle.ParticleService;
import com.example.shinobicore.modules.visual.pool.ParticlePool;
import com.example.shinobicore.modules.visual.stub.StubEvents;
import com.example.shinobicore.modules.visual.util.EffectRateLimiter;
import com.example.shinobicore.modules.visual.util.ParticleColors;
import net.minecraft.util.math.Vec3d;

public final class EnemyVisualListener {

    public static void onEnemyStateChanged(StubEvents.EnemyStateChangedEvent event) {
        if (!EffectRateLimiter.canPlayEffect("enemy_state_" + event.entityId)) return;

        Vec3d pos = event.pos;
        int color = ParticleColors.WHITE;

        switch (event.newState.toLowerCase()) {
            case "chase": color = ParticleColors.RED; break;
            case "attack": color = ParticleColors.FIRE; break;
            case "cast": color = ParticleColors.LIGHTNING; break;
            case "retreat": color = ParticleColors.GRAY; break;
            default: return;
        }

        for (int i = 0; i < 5; i++) {
            if (!ParticleService.canSpawnParticle()) break;
            ParticlePool.PooledParticle p = ParticlePool.acquire();
            if (p == null) break;
            float vx = (float)(Math.random() - 0.5) * 0.05f;
            float vy = 0.05f + (float)(Math.random() * 0.05f);
            float vz = (float)(Math.random() - 0.5) * 0.05f;
            p.init((float)pos.x, (float)pos.y + 1.5f, (float)pos.z, vx, vy, vz, color, 15);
            ParticleService.onParticleSpawned();
        }
        EffectRateLimiter.onEffectPlayed("enemy_state_" + event.entityId);
    }
}
"@
Write-JavaFile -FilePath "$ListenerPath\EnemyVisualListener.java" -Content $f4

$f5 = @"
package com.example.shinobicore.modules.visual.listener;

import com.example.shinobicore.modules.visual.config.VisualConfig;
import com.example.shinobicore.modules.visual.screen.ScreenFlashService;
import com.example.shinobicore.modules.visual.stub.StubEvents;
import com.example.shinobicore.modules.visual.util.ParticleColors;

public final class ProgressionVisualListener {

    public static void onLevelUp(StubEvents.LevelChangedEvent event) {
        if (!VisualConfig.get().screenFlash.enabled) return;
        if (event.newLevel <= event.oldLevel) return;

        ScreenFlashService.flash(
            VisualConfig.get().screenFlash.levelUpColor,
            VisualConfig.get().screenFlash.levelUpDuration
        );
    }

    public static void onXpGained(StubEvents.XpGainedEvent event) {
        // Optional: small sparkle effect on XP gain
        // Kept minimal to avoid spam
    }
}
"@
Write-JavaFile -FilePath "$ListenerPath\ProgressionVisualListener.java" -Content $f5

# ---- [5/8] Updated StubEvents (add movement/enemy/progression) ----
Write-Host "[5/8] Updating StubEvents.java..." -ForegroundColor Yellow
$f6 = @"
package com.example.shinobicore.modules.visual.stub;

import net.minecraft.entity.player.PlayerEntity;
import net.minecraft.util.math.Vec3d;

public final class StubEvents {
    public static class JutsuCastStartedEvent {
        public final PlayerEntity caster;
        public final String elementId;
        public JutsuCastStartedEvent(PlayerEntity caster, String elementId) {
            this.caster = caster; this.elementId = elementId;
        }
    }
    public static class JutsuCastFinishedEvent {
        public final PlayerEntity caster;
        public final String elementId;
        public JutsuCastFinishedEvent(PlayerEntity caster, String elementId) {
            this.caster = caster; this.elementId = elementId;
        }
    }
    public static class CombatHitEvent {
        public final PlayerEntity attacker;
        public final float damage;
        public CombatHitEvent(PlayerEntity attacker, float damage) {
            this.attacker = attacker; this.damage = damage;
        }
    }
    public static class CombatBlockedEvent {
        public final PlayerEntity blocker;
        public CombatBlockedEvent(PlayerEntity blocker) { this.blocker = blocker; }
    }
    public static class CombatParriedEvent {
        public final PlayerEntity parrier;
        public CombatParriedEvent(PlayerEntity parrier) { this.parrier = parrier; }
    }
    public static class LevelChangedEvent {
        public final PlayerEntity player;
        public final int oldLevel;
        public final int newLevel;
        public LevelChangedEvent(PlayerEntity player, int oldLevel, int newLevel) {
            this.player = player; this.oldLevel = oldLevel; this.newLevel = newLevel;
        }
    }
    public static class XpGainedEvent {
        public final PlayerEntity player;
        public final int amount;
        public XpGainedEvent(PlayerEntity player, int amount) {
            this.player = player; this.amount = amount;
        }
    }
    public static class ChakraModeEnabledEvent {
        public final PlayerEntity player;
        public ChakraModeEnabledEvent(PlayerEntity player) { this.player = player; }
    }
    public static class ChakraModeDisabledEvent {
        public final PlayerEntity player;
        public ChakraModeDisabledEvent(PlayerEntity player) { this.player = player; }
    }
    public static class WaterWalkStartedEvent {
        public final PlayerEntity player;
        public WaterWalkStartedEvent(PlayerEntity player) { this.player = player; }
    }
    public static class WallRunStartedEvent {
        public final PlayerEntity player;
        public WallRunStartedEvent(PlayerEntity player) { this.player = player; }
    }
    public static class SlideStartedEvent {
        public final PlayerEntity player;
        public SlideStartedEvent(PlayerEntity player) { this.player = player; }
    }
    public static class RollStartedEvent {
        public final PlayerEntity player;
        public RollStartedEvent(PlayerEntity player) { this.player = player; }
    }
    public static class DodgeEvent {
        public final PlayerEntity player;
        public DodgeEvent(PlayerEntity player) { this.player = player; }
    }
    public static class EnemyStateChangedEvent {
        public final int entityId;
        public final Vec3d pos;
        public final String newState;
        public EnemyStateChangedEvent(int entityId, Vec3d pos, String newState) {
            this.entityId = entityId; this.pos = pos; this.newState = newState;
        }
    }
}
"@
Write-JavaFile -FilePath "$StubPath\StubEvents.java" -Content $f6

# ---- [6/8] Full Client Commands (info, test, clear, debug, preset) ----
Write-Host "[6/8] Generating Full VisualClientCommands.java..." -ForegroundColor Yellow
$f7 = @"
package com.example.shinobicore.modules.visual.command;

import com.example.shinobicore.modules.visual.aura.AuraService;
import com.example.shinobicore.modules.visual.camera.CameraShakeService;
import com.example.shinobicore.modules.visual.config.VisualConfig;
import com.example.shinobicore.modules.visual.particle.ParticleService;
import com.example.shinobicore.modules.visual.pool.ParticlePool;
import com.example.shinobicore.modules.visual.pool.TrailPool;
import com.example.shinobicore.modules.visual.screen.ScreenFlashService;
import com.example.shinobicore.modules.visual.trail.TrailService;
import net.fabricmc.fabric.api.client.command.v2.FabricClientCommandSource;
import net.minecraft.client.MinecraftClient;
import net.minecraft.text.Text;
import net.minecraft.util.Formatting;
import net.minecraft.util.math.Vec3d;

public final class VisualClientCommands {

    public static void executeTest(FabricClientCommandSource source) {
        MinecraftClient client = MinecraftClient.getInstance();
        if (client.player == null) return;
        Vec3d pos = client.player.getPos().add(0, 1.5, 0);

        for (int i = 0; i < 50; i++) {
            if (!ParticleService.canSpawnParticle()) break;
            ParticlePool.PooledParticle p = ParticlePool.acquire();
            if (p == null) break;
            double angle = Math.random() * Math.PI * 2;
            double pitch = Math.random() * Math.PI - Math.PI / 2;
            float vx = (float)(Math.cos(angle) * Math.cos(pitch)) * 0.1f;
            float vy = (float)Math.sin(pitch) * 0.1f;
            float vz = (float)(Math.sin(angle) * Math.cos(pitch)) * 0.1f;
            p.init((float)pos.x, (float)pos.y, (float)pos.z, vx, vy, vz, 0xFFFF00FF, 40);
            ParticleService.onParticleSpawned();
        }
        TrailService.spawnTrail((float)pos.x, (float)pos.y, (float)pos.z,
            (float)pos.x + 2.0f, (float)pos.y + 1.0f, (float)pos.z, 0xFF00FF00, 0.1f, 20);
        CameraShakeService.shake(2.0f, 20);
        source.sendFeedback(Text.literal("Visual Test Executed!").formatted(Formatting.GREEN), false);
    }

    public static void executeInfo(FabricClientCommandSource source) {
        VisualConfig cfg = VisualConfig.get();
        source.sendFeedback(Text.literal("=== Visual Module Info ===").formatted(Formatting.GOLD), false);
        source.sendFeedback(Text.literal("Particles: " + ParticlePool.getActiveCount() + "/" + cfg.particles.poolSize).formatted(Formatting.AQUA), false);
        source.sendFeedback(Text.literal("Trails: " + TrailPool.getActiveCount() + "/" + cfg.trails.poolSize).formatted(Formatting.AQUA), false);
        source.sendFeedback(Text.literal("Aura: " + (AuraService.isChakraModeActive() ? "ON" : "OFF")).formatted(Formatting.AQUA), false);
        source.sendFeedback(Text.literal("Shake: " + (CameraShakeService.isShaking() ? "ON" : "OFF")).formatted(Formatting.AQUA), false);
        source.sendFeedback(Text.literal("Flash: " + (ScreenFlashService.isFlashing() ? "ON" : "OFF")).formatted(Formatting.AQUA), false);
        source.sendFeedback(Text.literal("Preset: " + cfg.qualityPreset).formatted(Formatting.AQUA), false);
        source.sendFeedback(Text.literal("Cull: " + cfg.culling.distance + " blocks").formatted(Formatting.AQUA), false);
    }

    public static void executeClear(FabricClientCommandSource source) {
        ParticlePool.init(VisualConfig.get().particles.poolSize);
        TrailPool.init(VisualConfig.get().trails.poolSize);
        CameraShakeService.init();
        ScreenFlashService.init();
        AuraService.init();
        source.sendFeedback(Text.literal("All visual effects cleared.").formatted(Formatting.YELLOW), false);
    }

    public static void executeDebug(FabricClientCommandSource source) {
        VisualConfig cfg = VisualConfig.get();
        cfg.debug = !cfg.debug;
        source.sendFeedback(Text.literal("Debug overlay: " + (cfg.debug ? "ON" : "OFF")).formatted(Formatting.YELLOW), false);
    }

    public static void executePreset(FabricClientCommandSource source, String preset) {
        VisualConfig cfg = VisualConfig.get();
        switch (preset.toLowerCase()) {
            case "low":
                cfg.particles.maxPerFrame = 20;
                cfg.particles.maxPerSecond = 80;
                cfg.culling.distance = 16.0;
                cfg.cameraShake.enabled = false;
                cfg.trails.enabled = false;
                break;
            case "medium":
                cfg.particles.maxPerFrame = 35;
                cfg.particles.maxPerSecond = 140;
                cfg.culling.distance = 24.0;
                cfg.cameraShake.enabled = true;
                cfg.trails.enabled = true;
                break;
            case "high":
            case "default":
                cfg.particles.maxPerFrame = 50;
                cfg.particles.maxPerSecond = 200;
                cfg.culling.distance = 32.0;
                cfg.cameraShake.enabled = true;
                cfg.trails.enabled = true;
                break;
            default:
                source.sendFeedback(Text.literal("Unknown preset: " + preset).formatted(Formatting.RED), false);
                return;
        }
        cfg.qualityPreset = preset.toLowerCase();
        source.sendFeedback(Text.literal("Quality preset set to: " + preset).formatted(Formatting.GREEN), false);
    }

    public static void executeFlash(FabricClientCommandSource source) {
        ScreenFlashService.flash(0xFFFFD700, 30);
        source.sendFeedback(Text.literal("Screen Flash triggered!").formatted(Formatting.GOLD), false);
    }

    public static void executeAura(FabricClientCommandSource source) {
        boolean current = AuraService.isChakraModeActive();
        if (current) AuraService.onChakraModeDisabled(null);
        else AuraService.onChakraModeEnabled(null);
        source.sendFeedback(Text.literal("Chakra Aura: " + (!current ? "ON" : "OFF")).formatted(Formatting.AQUA), false);
    }
}
"@
Write-JavaFile -FilePath "$CommandPath\VisualClientCommands.java" -Content $f7

# ---- [7/8] Updated VisualModule (Full Integration) ----
Write-Host "[7/8] Updating VisualModule.java (Full DoD Integration)..." -ForegroundColor Yellow
$f8 = @"
package com.example.shinobicore.modules.visual;

import com.example.shinobicore.core.api.ClientAwareModule;
import com.example.shinobicore.core.api.ModuleContext;
import com.example.shinobicore.core.log.ShinobiLogger;
import com.example.shinobicore.modules.visual.aura.AuraRenderer;
import com.example.shinobicore.modules.visual.aura.AuraService;
import com.example.shinobicore.modules.visual.camera.CameraShakeService;
import com.example.shinobicore.modules.visual.command.VisualClientCommands;
import com.example.shinobicore.modules.visual.config.VisualConfig;
import com.example.shinobicore.modules.visual.culling.EffectCullingService;
import com.example.shinobicore.modules.visual.listener.CombatVisualListener;
import com.example.shinobicore.modules.visual.listener.EnemyVisualListener;
import com.example.shinobicore.modules.visual.listener.JutsuVisualListener;
import com.example.shinobicore.modules.visual.listener.MovementVisualListener;
import com.example.shinobicore.modules.visual.listener.ProgressionVisualListener;
import com.example.shinobicore.modules.visual.particle.ParticleService;
import com.example.shinobicore.modules.visual.pool.ParticlePool;
import com.example.shinobicore.modules.visual.pool.TrailPool;
import com.example.shinobicore.modules.visual.render.VisualRenderDispatcher;
import com.example.shinobicore.modules.visual.screen.ScreenFlashRenderer;
import com.example.shinobicore.modules.visual.screen.ScreenFlashService;
import com.example.shinobicore.modules.visual.stub.StubEvents;
import com.example.shinobicore.modules.visual.trail.TrailService;
import com.example.shinobicore.modules.visual.util.EffectRateLimiter;
import com.example.shinobicore.modules.visual.view.VisualViewConsumer;
import com.google.gson.JsonObject;
import com.mojang.brigadier.arguments.StringArgumentType;
import net.fabricmc.fabric.api.client.command.v2.ClientCommandManager;
import net.fabricmc.fabric.api.client.command.v2.ClientCommandRegistrationCallback;

public class VisualModule implements ClientAwareModule {
    public static final String ID = "visual";

    @Override public String id() { return ID; }

    @Override
    public void onEnable(ModuleContext ctx) {
        JsonObject rawConfig = ctx.configs().readModuleConfig(ID);
        VisualConfig.load(rawConfig);

        if (!VisualConfig.get().enabled) {
            ShinobiLogger.module(ID, "Visual module disabled by config.");
            return;
        }

        ParticlePool.init(VisualConfig.get().particles.poolSize);
        TrailPool.init(VisualConfig.get().trails.poolSize);

        ParticleService.init();
        TrailService.init();
        CameraShakeService.init();
        ScreenFlashService.init();
        AuraService.init();
        EffectCullingService.init(VisualConfig.get().culling.distance);
        EffectRateLimiter.init(VisualConfig.get().particles.cooldownMs);

        ShinobiLogger.module(ID, "Visual module enabled. Pools & Services initialized.");
    }

    @Override
    public void registerEvents(ModuleContext ctx) {
        // Jutsu events
        ctx.events().subscribe(StubEvents.JutsuCastStartedEvent.class, JutsuVisualListener::onCastStarted);
        ctx.events().subscribe(StubEvents.JutsuCastFinishedEvent.class, e -> {
            ScreenFlashService.flash(0xFF4499FF, 8);
        });

        // Combat events
        ctx.events().subscribe(StubEvents.CombatHitEvent.class, CombatVisualListener::onHit);
        ctx.events().subscribe(StubEvents.CombatBlockedEvent.class, e -> {
            ScreenFlashService.flash(0xFF4444FF, 4);
        });
        ctx.events().subscribe(StubEvents.CombatParriedEvent.class, e -> {
            ScreenFlashService.flash(0xFFFFD700, 5);
        });

        // Movement events
        ctx.events().subscribe(StubEvents.WaterWalkStartedEvent.class, MovementVisualListener::onWaterWalkStarted);
        ctx.events().subscribe(StubEvents.WallRunStartedEvent.class, MovementVisualListener::onWallRunStarted);
        ctx.events().subscribe(StubEvents.SlideStartedEvent.class, MovementVisualListener::onSlideStarted);
        ctx.events().subscribe(StubEvents.RollStartedEvent.class, MovementVisualListener::onRollStarted);
        ctx.events().subscribe(StubEvents.DodgeEvent.class, MovementVisualListener::onDodge);

        // Progression events
        ctx.events().subscribe(StubEvents.LevelChangedEvent.class, ProgressionVisualListener::onLevelUp);
        ctx.events().subscribe(StubEvents.XpGainedEvent.class, ProgressionVisualListener::onXpGained);

        // Chakra/Aura events
        ctx.events().subscribe(StubEvents.ChakraModeEnabledEvent.class, AuraService::onChakraModeEnabled);
        ctx.events().subscribe(StubEvents.ChakraModeDisabledEvent.class, AuraService::onChakraModeDisabled);

        // Enemy events
        ctx.events().subscribe(StubEvents.EnemyStateChangedEvent.class, EnemyVisualListener::onEnemyStateChanged);
    }

    @Override
    public void onClientInit(ModuleContext ctx) {
        if (!VisualConfig.get().enabled) return;

        VisualRenderDispatcher.register();
        ScreenFlashRenderer.register();
        AuraRenderer.register();

        ClientCommandRegistrationCallback.EVENT.register((dispatcher, registryAccess) -> {
            dispatcher.register(ClientCommandManager.literal("shinobicore")
                .then(ClientCommandManager.literal("visual")
                    .then(ClientCommandManager.literal("test").executes(c -> {
                        VisualClientCommands.executeTest(c.getSource()); return 1;
                    }))
                    .then(ClientCommandManager.literal("info").executes(c -> {
                        VisualClientCommands.executeInfo(c.getSource()); return 1;
                    }))
                    .then(ClientCommandManager.literal("clear").executes(c -> {
                        VisualClientCommands.executeClear(c.getSource()); return 1;
                    }))
                    .then(ClientCommandManager.literal("debug").executes(c -> {
                        VisualClientCommands.executeDebug(c.getSource()); return 1;
                    }))
                    .then(ClientCommandManager.literal("flash").executes(c -> {
                        VisualClientCommands.executeFlash(c.getSource()); return 1;
                    }))
                    .then(ClientCommandManager.literal("aura").executes(c -> {
                        VisualClientCommands.executeAura(c.getSource()); return 1;
                    }))
                    .then(ClientCommandManager.literal("preset")
                        .then(ClientCommandManager.argument("name", StringArgumentType.word())
                            .executes(c -> {
                                VisualClientCommands.executePreset(c.getSource(), StringArgumentType.getString(c, "name"));
                                return 1;
                            })
                        )
                    )
                )
            );
        });

        ShinobiLogger.module(ID, "Visual renderers and client commands registered.");
    }

    @Override
    public void onClientTick(ModuleContext ctx) {
        if (!VisualConfig.get().enabled) return;

        VisualViewConsumer.pollViews();
        ParticleService.tick();
        TrailService.tick();
        CameraShakeService.tick();
        ScreenFlashService.tick();
        AuraService.tick();
        EffectRateLimiter.tick();

        // O(1) Particle cleanup
        for (int i = 0; i < ParticlePool.getActiveCount(); i++) {
            ParticlePool.PooledParticle p = ParticlePool.get(i);
            p.age++;
            // Apply velocity
            p.x += p.vx;
            p.y += p.vy;
            p.z += p.vz;
            p.vy -= 0.002f; // gravity
            if (p.isExpired()) {
                ParticlePool.releaseAt(i);
                i--;
            }
        }
    }
}
"@
Write-JavaFile -FilePath "$BasePath\VisualModule.java" -Content $f8

# ---- [8/8] README.md ----
Write-Host "[8/8] Generating README.md..." -ForegroundColor Yellow
$readme = @"
# ShinobiCore Visual Module

## Overview
Client-side visual effects module for ShinobiCore 4.0.0.
Renders particles, trails, auras, camera shake, and screen flash.

**This module is READ-ONLY.** It never modifies game state and never sends packets.

## Architecture
- **Pools**: ParticlePool (512), TrailPool (64) - zero GC pressure
- **Limits**: 50 particles/frame, 200 particles/second (configurable)
- **Culling**: Effects beyond 32 blocks are not rendered (squared distance, no sqrt)
- **Rate Limiter**: 100ms cooldown between identical effects (auto-cleanup every 5s)
- **Rendering**: Zero-allocation renderers using VertexConsumer batching

## Commands (Client-Side)
| Command | Description |
|---------|-------------|
| /shinobicore visual test | Spawn test particles, trail, and camera shake |
| /shinobicore visual info | Show pool usage and active effects |
| /shinobicore visual clear | Clear all active effects |
| /shinobicore visual debug | Toggle debug overlay |
| /shinobicore visual flash | Trigger screen flash |
| /shinobicore visual aura | Toggle chakra aura |
| /shinobicore visual preset <name> | Set quality (low/medium/high/default) |

## Quality Presets
| Preset | Particles/Frame | Particles/Sec | Cull Distance | Shake | Trails |
|--------|----------------|---------------|---------------|-------|--------|
| low | 20 | 80 | 16 blocks | OFF | OFF |
| medium | 35 | 140 | 24 blocks | ON | ON |
| high | 50 | 200 | 32 blocks | ON | ON |

## Event Integration
Currently uses stub events. Replace imports in listener classes when other modules
publish their real events:
- JutsuVisualListener -> JutsuCastStartedEvent, JutsuCastFinishedEvent
- CombatVisualListener -> CombatHitEvent, CombatBlockedEvent, CombatParriedEvent
- MovementVisualListener -> WaterWalkStartedEvent, WallRunStartedEvent, etc.
- ProgressionVisualListener -> LevelChangedEvent, XpGainedEvent
- EnemyVisualListener -> EnemyStateChangedEvent

## Config
File: config/shinobicore/modules/visual.json
- Missing file: defaults created automatically
- Invalid JSON: error logged, defaults used, no crash
- No hot reload: restart required

## Performance Notes
- All renderers use zero-allocation loops (no new objects per frame)
- Distance culling uses squared distance (avoids Math.sqrt)
- Pool cleanup is O(1) per element (swap-with-last)
- Rate limiter auto-cleans stale entries every 5 seconds
- Target: 60+ FPS on weak PC with all effects active
"@
Write-TextFile -FilePath "$ReadmePath\README.md" -Content $readme

Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "  Phase 7 (Finalization) Completed!" -ForegroundColor Green
Write-Host "  Run '.\gradlew.bat build' to verify." -ForegroundColor White
Write-Host "========================================================" -ForegroundColor Cyan