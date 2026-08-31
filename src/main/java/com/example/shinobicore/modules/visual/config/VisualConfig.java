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