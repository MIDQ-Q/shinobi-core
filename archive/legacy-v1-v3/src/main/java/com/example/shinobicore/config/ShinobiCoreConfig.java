package com.example.shinobicore.config;

import com.example.shinobicore.util.ShinobiConstants;
import com.example.shinobicore.util.ShinobiLogger;
import com.google.gson.Gson;
import com.google.gson.GsonBuilder;
import net.fabricmc.loader.api.FabricLoader;
import java.io.FileReader;
import java.io.FileWriter;
import java.nio.file.Files;
import java.nio.file.Path;

public class ShinobiCoreConfig {
    private static final Gson GSON = new GsonBuilder().setPrettyPrinting().create();
    private static ShinobiCoreConfig instance;

    public float baseMaxChakra = ShinobiConstants.BASE_MAX_CHAKRA;
    public float chakraRegenPerSec = ShinobiConstants.CHAKRA_REGEN_PER_SEC;
    public float chakraModeDrainPerSec = ShinobiConstants.CHAKRA_MODE_DRAIN_PER_SEC;
    public float waterWalkDrainPerTick = ShinobiConstants.WATER_WALK_DRAIN_PER_TICK;
    public float wallWalkDrainPerTick = ShinobiConstants.WALL_WALK_DRAIN_PER_TICK;
    public float doubleJumpYVelocity = ShinobiConstants.DOUBLE_JUMP_Y_VELOCITY;
    public int jumpsPerReset = ShinobiConstants.JUMPS_PER_RESET;
    public float dashStrength = ShinobiConstants.DASH_STRENGTH;
    public int dodgeCooldownTicks = ShinobiConstants.DODGE_COOLDOWN_TICKS;
    public int dodgeIframeTicks = ShinobiConstants.DODGE_IFRAME_TICKS;
    public int slideDurationTicks = ShinobiConstants.SLIDE_DURATION_TICKS;
    public int slideChakraDurationTicks = ShinobiConstants.SLIDE_CHAKRA_DURATION_TICKS;
    public float blockDamageReduction = ShinobiConstants.BLOCK_DAMAGE_REDUCTION;
    public float blockStaminaCost = ShinobiConstants.BLOCK_STAMINA_COST_PER_HIT;
    public int maxStatLevel = ShinobiConstants.MAX_STAT_LEVEL;
    public int xpBase = ShinobiConstants.XP_BASE;
    public float xpFactor = ShinobiConstants.XP_FACTOR;
    public float xpSquaredFactor = ShinobiConstants.XP_SQUARED_FACTOR;
    public double worldBorderSize = ShinobiConstants.WORLD_BORDER_SIZE;
    public int villageSpacing = ShinobiConstants.VILLAGE_SPACING;
    public boolean debugLogging = false;
    public String logLevel = "DEBUG";

    // === MOVEMENT V3 SECTIONS (Script 02) ===
    public MovementSection movement = new MovementSection();
    public ChakraClientSection chakraClient = new ChakraClientSection();
    public WaterWalkSection waterWalk = new WaterWalkSection();
    public WallRunSection wallRun = new WallRunSection();
    public SlideSection slide = new SlideSection();
    public CrawlSection crawl = new CrawlSection();
    public RollSection roll = new RollSection();
    public DodgeSection dodge = new DodgeSection();
    public ChargedJumpSection chargedJump = new ChargedJumpSection();
    public DoubleJumpSection doubleJump = new DoubleJumpSection();
    public EdgeGrabSection edgeGrab = new EdgeGrabSection();
    public MeditationSection meditation = new MeditationSection();
    public WallBlocksSection wallBlocks = new WallBlocksSection();
    public WaterBlocksSection waterBlocks = new WaterBlocksSection();
    public LoggingSection logging = new LoggingSection();

    public static ShinobiCoreConfig getInstance() {
        if (instance == null) instance = new ShinobiCoreConfig();
        return instance;
    }

    public static Path getPath() {
        return FabricLoader.getInstance().getConfigDir().resolve("shinobicore").resolve("main.json");
    }

    public static void load() {
        Path p = getPath();
        try {
            if (!Files.exists(p)) {
                Files.createDirectories(p.getParent());
                instance = new ShinobiCoreConfig();
                save();
                ShinobiLogger.info("Config created at: %s", p);
            } else {
                try (FileReader reader = new FileReader(p.toFile())) {
                    ShinobiCoreConfig loaded = GSON.fromJson(reader, ShinobiCoreConfig.class);
                    if (loaded != null) instance = loaded;
                }
                save();
                ShinobiLogger.info("Config loaded from: %s", p);
            }
        } catch (Exception e) {
            ShinobiLogger.exception("Config load", e);
            instance = new ShinobiCoreConfig();
        }
    }

    public static void save() {
        Path p = getPath();
        try {
            Files.createDirectories(p.getParent());
            try (FileWriter writer = new FileWriter(p.toFile())) {
                GSON.toJson(getInstance(), writer);
            }
        } catch (Exception e) {
            ShinobiLogger.exception("Config save", e);
        }
    }

    public static void reload() {
        load();
        ShinobiLogger.info("Config reloaded");
    }

    // ================================================================
    // MOVEMENT V3 NESTED CONFIG SECTIONS (Script 02)
    // ================================================================

    public static class MovementSection {
        public boolean enabled = true;
        public boolean debugLogging = false;
        public boolean serverMirrorPhysics = false;
        public int heartbeatIntervalTicks = 20;
        public int doubleTapShiftMs = 300;
        public boolean disableWhileFlying = true;
        public boolean disableWhileRiding = true;
    }

    public static class ChakraClientSection {
        public boolean enabled = true;
        public float baseMaxChakra = 2000.0f;
        public float startingChakra = 2000.0f;
        public float regenPerSecond = 2.0f;
        public int regenDelayTicks = 40;
        public float syncMinDelta = 5.0f;
        public float fatigueSyncMinDelta = 2.0f;
        public float exhaustionThreshold = 100.0f;
        public float exhaustionExitThreshold = 60.0f;
        public float modeActivationMinChakra = 50.0f;
        public int modeToggleCooldownTicks = 10;
        public float idleDrainPerSecond = 5.0f;
        public boolean restoreModeAfterDeath = false;
        public boolean restoreModeAfterRelog = true;
        public FatigueSubSection fatigue = new FatigueSubSection();

        public static class FatigueSubSection {
            public boolean enabled = true;
            public float decayPerSecond = 2.0f;
            public float softThreshold = 50.0f;
            public float hardThreshold = 70.0f;
            public float costPenaltyMax = 1.0f;
        }
    }

    public static class WaterWalkSection {
        public boolean enabled = true;
        public float drainPerSecond = 3.0f;
        public float speedMultiplier = 1.0f;
        public float surfaceLowerTolerance = 0.15f;
        public float surfaceUpperTolerance = 0.15f;
        public boolean allowWaterlogged = true;
        public boolean allowBubbleColumn = true;
        public boolean allowWaterPlants = true;
        public boolean splashParticles = true;
        public boolean stepSound = false;
        public boolean disableWhenSneaking = false;
        public boolean disableWhenCrawling = true;
    }

    public static class WallRunSection {
        public boolean enabled = true;
        public float drainPerSecond = 4.5f;
        public boolean entryRequiresJump = true;
        public int jumpGraceTicks = 6;
        public int cooldownTicks = 20;
        public float speedMultiplier = 0.8f;
        public float gravityScale = 0.15f;
        public float idleSlidePerTick = 0.02f;
        public float maxClimbSpeed = 0.12f;
        public float maxDescendSpeed = 0.08f;
        public float stickAcceleration = 0.05f;
        public float raycastDistance = 0.8f;
        public int maxDurationTicks = 200;
        public float wallJumpHorizontal = 0.5f;
        public float wallJumpVertical = 0.45f;
        public float wallJumpLookFactor = 0.6f;
        public boolean preventJumpIntoWall = true;
        public float fatigueCostOnStart = 3.0f;
        public float fatiguePerSecond = 1.0f;
    }

    public static class SlideSection {
        public boolean enabled = true;
        public int durationNormal = 15;
        public int durationChakra = 25;
        public float boostNormal = 0.45f;
        public float boostChakra = 0.81f;
        public float fatigueCost = 2.0f;
        public float chakraCost = 5.0f;
        public int cooldownTicks = 20;
    }

    public static class CrawlSection {
        public boolean enabled = true;
        public float speedMultiplier = 0.4f;
        public boolean useOldKeybinding = true;
        public boolean doubleTapEnabled = true;
        public int doubleTapMs = 300;
        public boolean requireOnGround = true;
    }

    public static class RollSection {
        public boolean enabled = true;
        public int durationTicks = 12;
        public float boost = 0.8f;
        public int iFrameTicks = 8;
        public float fatigueCost = 5.0f;
        public float chakraCost = 10.0f;
        public int cooldownTicks = 30;
    }

    public static class DodgeSection {
        public boolean enabled = true;
        public float boost = 1.2f;
        public int iFrameTicks = 6;
        public float fatigueCost = 4.0f;
        public float chakraCost = 8.0f;
        public int cooldownTicks = 20;
    }

    public static class ChargedJumpSection {
        public boolean enabled = true;
        public int maxChargeTicks = 40;
        public int minChargeTicks = 4;
        public float baseMultiplier = 1.0f;
        public float maxMultiplier = 2.5f;
        public float chakraCost = 15.0f;
        public float fatigueCost = 5.0f;
        public float maxVerticalVelocity = 1.5f;
        public float maxHorizontalBoost = 0.8f;
        public boolean allowWithoutChakraMode = false;
        public float baseVerticalVelocity = 0.42f;
        public float baseHorizontalBoost = 0.3f;
    }

    public static class DoubleJumpSection {
        public boolean enabled = true;
        public int maxAirJumps = 1;
        public float verticalVelocity = 0.95f;
        public float chakraCost = 20.0f;
        public float fatigueCost = 3.0f;
        public boolean preserveInertia = true;
        public int cooldownTicks = 10;
    }

    public static class EdgeGrabSection {
        public boolean enabled = true;
        public boolean autoGrab = true;
        public float reach = 1.5f;
        public float climbSpeed = 0.15f;
        public float fatigueCost = 3.0f;
        public float chakraCost = 5.0f;
        public int cooldownTicks = 10;
    }

    public static class MeditationSection {
        public boolean enabled = true;
        public float regenMultiplier = 2.5f;
        public float fatigueDecayMultiplier = 3.0f;
        public int damageCooldownTicks = 60;
        public int slownessLevel = 2;
        public boolean chakraModeOptional = true;
    }

    public static class WallBlocksSection {
        public boolean allowSolidBlocks = true;
        public boolean allowWalls = true;
        public boolean allowFences = true;
        public boolean allowGlass = true;
        public boolean allowLeaves = true;
        public String[] extraIds = new String[0];
        public String[] blacklistIds = new String[0];
        public String[] extraTags = new String[0];
    }

    public static class WaterBlocksSection {
        public boolean allowWaterlogged = true;
        public boolean allowBubbleColumn = true;
        public boolean allowWaterPlants = true;
    }

    public static class LoggingSection {
        public boolean chakraSync = false;
        public boolean movementActions = false;
        public boolean suspiciousOnly = true;
        public int rateLimitTicks = 100;
    }
}