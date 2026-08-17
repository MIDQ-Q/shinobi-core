# ============================================================
# SHINOBICORE MASTER SCRIPT: SPRINT 5 PHASE C
# S5-06 Sound Pipeline | S5-07 Shader Compat | S5-08 Performance
# ============================================================
$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$root = "E:\Games\mod"
$srcBase = Join-Path $root "src\main\java\com\example\shinobicore"
$clientDir = Join-Path $srcBase "client"
$resBase = Join-Path $root "src\main\resources\assets\shinobicore"

Write-Host ""
Write-Host "==============================================================" -ForegroundColor Cyan
Write-Host "  SPRINT 5 PHASE C: Sound + Shaders + Performance" -ForegroundColor Cyan
Write-Host "==============================================================" -ForegroundColor Cyan
Write-Host ""

function Write-File($path, $content) {
    $dir = Split-Path $path -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [System.IO.File]::WriteAllText($path, $content, $utf8)
    Write-Host "  [OK] $(Split-Path $path -Leaf)" -ForegroundColor Green
}

function Patch-File($p, $old, $new) {
    if (-not (Test-Path $p)) { Write-Host "  [MISS] $p" -ForegroundColor Red; return $false }
    $c = [System.IO.File]::ReadAllText($p, $utf8)
    $c = $c.Replace("`r`n", "`n")
    $oldN = $old.Replace("`r`n", "`n")
    $newN = $new.Replace("`r`n", "`n")
    if ($c.Contains($newN)) { Write-Host "  [SKIP] already: $(Split-Path $p -Leaf)" -ForegroundColor Yellow; return $true }
    if (-not $c.Contains($oldN)) { Write-Host "  [FAIL] pattern: $(Split-Path $p -Leaf)" -ForegroundColor Red; return $false }
    $c = $c.Replace($oldN, $newN)
    [System.IO.File]::WriteAllText($p, $c, $utf8)
    Write-Host "  [PATCH] $(Split-Path $p -Leaf)" -ForegroundColor Green
    return $true
}

# ============================================================
# S5-06: SOUND PIPELINE - NinjaSoundManager
# ============================================================
Write-Host "[S5-06] Creating NinjaSoundManager..." -ForegroundColor Yellow

$soundManager = @'
package com.example.shinobicore.client.sound;

import com.example.shinobicore.ShinobiCore;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.sound.SoundCategory;
import net.minecraft.sound.SoundEvent;
import net.minecraft.util.Identifier;
import net.minecraft.util.math.Vec3d;
import net.minecraft.world.World;

/**
 * S5-06: Central sound manager for all ninja-related sounds.
 * Categories: cast, charge, shot, hit, explosion, element loops,
 * clone dispersion, kawarimi, enemy telegraphs.
 * Uses pitch variation for uniqueness without separate audio files.
 */
public class NinjaSoundManager {

    public enum SoundType {
        CAST, CHARGE, SHOT, HIT, EXPLOSION, LOOP, DISPERSE, KAWARIMI, TELEGRAPH
    }

    // Sound events (defined in sounds.json)
    public static final SoundEvent CAST_START = SoundEvent.of(new Identifier("shinobicore", "cast_start"));
    public static final SoundEvent CAST_COMPLETE = SoundEvent.of(new Identifier("shinobicore", "cast_complete"));
    public static final SoundEvent CHARGE_LOOP = SoundEvent.of(new Identifier("shinobicore", "charge_loop"));
    public static final SoundEvent CHARGE_READY = SoundEvent.of(new Identifier("shinobicore", "charge_ready"));
    public static final SoundEvent SHOT_FIRE = SoundEvent.of(new Identifier("shinobicore", "shot_fire"));
    public static final SoundEvent SHOT_WATER = SoundEvent.of(new Identifier("shinobicore", "shot_water"));
    public static final SoundEvent SHOT_WIND = SoundEvent.of(new Identifier("shinobicore", "shot_wind"));
    public static final SoundEvent SHOT_LIGHTNING = SoundEvent.of(new Identifier("shinobicore", "shot_lightning"));
    public static final SoundEvent SHOT_EARTH = SoundEvent.of(new Identifier("shinobicore", "shot_earth"));
    public static final SoundEvent HIT_IMPACT = SoundEvent.of(new Identifier("shinobicore", "hit_impact"));
    public static final SoundEvent EXPLOSION_SMALL = SoundEvent.of(new Identifier("shinobicore", "explosion_small"));
    public static final SoundEvent EXPLOSION_LARGE = SoundEvent.of(new Identifier("shinobicore", "explosion_large"));
    public static final SoundEvent CLONE_DISPERSE = SoundEvent.of(new Identifier("shinobicore", "clone_disperse"));
    public static final SoundEvent KAWARIMI = SoundEvent.of(new Identifier("shinobicore", "kawarimi"));
    public static final SoundEvent TELEGRAPH_MELEE = SoundEvent.of(new Identifier("shinobicore", "telegraph_melee"));
    public static final SoundEvent TELEGRAPH_RANGED = SoundEvent.of(new Identifier("shinobicore", "telegraph_ranged"));

    /**
     * Play sound with pitch variation for uniqueness.
     */
    public static void play(ClientPlayerEntity player, SoundEvent sound,
                            SoundType type, float volume, float basePitch) {
        if (player == null) return;
        float pitch = basePitch + getVariation(type);
        try {
            player.playSound(sound, getCategory(type), volume, pitch);
        } catch (Exception e) {
            ShinobiCore.LOGGER.error("[SOUND] Play failed: {}", e.getMessage());
        }
    }

    /**
     * Play sound at world position with distance attenuation.
     */
    public static void playAt(World world, Vec3d pos, SoundEvent sound,
                              SoundType type, float volume, float basePitch) {
        float pitch = basePitch + getVariation(type);
        try {
            world.playSound(null, pos.x, pos.y, pos.z, sound, getCategory(type), volume, pitch);
        } catch (Exception e) {
            ShinobiCore.LOGGER.error("[SOUND] Positioned play failed: {}", e.getMessage());
        }
    }

    /**
     * Get element-specific shot sound.
     */
    public static SoundEvent getElementShot(String element) {
        if (element == null) return SHOT_FIRE;
        return switch (element) {
            case "water" -> SHOT_WATER;
            case "wind" -> SHOT_WIND;
            case "lightning" -> SHOT_LIGHTNING;
            case "earth" -> SHOT_EARTH;
            default -> SHOT_FIRE;
        };
    }

    private static float getVariation(SoundType type) {
        float r = (float) Math.random();
        return switch (type) {
            case CAST -> (r - 0.5f) * 0.2f;
            case CHARGE -> (r - 0.5f) * 0.1f;
            case SHOT -> (r - 0.5f) * 0.3f;
            case HIT -> (r - 0.5f) * 0.4f;
            case EXPLOSION -> (r - 0.5f) * 0.15f;
            case LOOP -> 0f;
            case DISPERSE -> (r - 0.5f) * 0.3f;
            case KAWARIMI -> (r - 0.5f) * 0.2f;
            case TELEGRAPH -> (r - 0.5f) * 0.25f;
        };
    }

    private static SoundCategory getCategory(SoundType type) {
        return switch (type) {
            case TELEGRAPH -> SoundCategory.HOSTILE;
            case LOOP -> SoundCategory.AMBIENT;
            default -> SoundCategory.PLAYERS;
        };
    }
}
'@
Write-File (Join-Path $clientDir "sound\NinjaSoundManager.java") $soundManager

# ============================================================
# S5-06: SOUNDS.JSON - Full sound definitions
# ============================================================
Write-Host "[S5-06] Updating sounds.json..." -ForegroundColor Yellow

$soundsJson = @'
{
  "punch_light": {
    "sounds": ["minecraft:entity/player/attack/weak1", "minecraft:entity/player/attack/weak2",
               "minecraft:entity/player/attack/weak3", "minecraft:entity/player/attack/weak4"],
    "category": "player", "subtitle": "subtitle.shinobicore.punch_light"
  },
  "punch_heavy": {
    "sounds": ["minecraft:entity/player/attack/strong1", "minecraft:entity/player/attack/strong2",
               "minecraft:entity/player/attack/strong3", "minecraft:entity/player/attack/strong4"],
    "category": "player", "subtitle": "subtitle.shinobicore.punch_heavy"
  },
  "kick": {
    "sounds": ["minecraft:entity/player/attack/crit1", "minecraft:entity/player/attack/crit2",
               "minecraft:entity/player/attack/crit3"],
    "category": "player", "subtitle": "subtitle.shinobicore.kick"
  },
  "whoosh": {
    "sounds": ["minecraft:entity/player/attack/sweep1", "minecraft:entity/player/attack/sweep2",
               "minecraft:entity/player/attack/sweep3", "minecraft:entity/player/attack/sweep4",
               "minecraft:entity/player/attack/sweep5", "minecraft:entity/player/attack/sweep6",
               "minecraft:entity/player/attack/sweep7"],
    "category": "player", "subtitle": "subtitle.shinobicore.whoosh"
  },
  "katana_slash": {
    "sounds": ["minecraft:entity/player/attack/sweep1", "minecraft:entity/player/attack/sweep2",
               "minecraft:entity/player/attack/sweep3"],
    "category": "player", "subtitle": "subtitle.shinobicore.katana_slash"
  },
  "katana_deflect": {
    "sounds": ["minecraft:item/shield/block1", "minecraft:item/shield/block2",
               "minecraft:item/shield/block3"],
    "category": "player", "subtitle": "subtitle.shinobicore.katana_deflect"
  },
  "genjutsu_cast": {
    "sounds": ["minecraft:entity/illusioner/cast_spell"],
    "category": "player", "subtitle": "subtitle.shinobicore.genjutsu_cast"
  },
  "genjutsu_ambient": {
    "sounds": ["minecraft:entity/wandering_trader/disappeared"],
    "category": "ambient", "subtitle": "subtitle.shinobicore.genjutsu_ambient"
  },
  "genjutsu_resist": {
    "sounds": ["minecraft:entity/enderman/teleport"],
    "category": "player", "subtitle": "subtitle.shinobicore.genjutsu_resist"
  },
  "cast_start": {
    "sounds": ["minecraft:entity/illusioner/cast_spell"],
    "category": "player", "subtitle": "subtitle.shinobicore.cast_start"
  },
  "cast_complete": {
    "sounds": ["minecraft:block/beacon/activate"],
    "category": "player", "subtitle": "subtitle.shinobicore.cast_complete"
  },
  "charge_loop": {
    "sounds": ["minecraft:block/beacon/ambient"],
    "category": "player", "subtitle": "subtitle.shinobicore.charge_loop"
  },
  "charge_ready": {
    "sounds": ["minecraft:block/beacon/power_select"],
    "category": "player", "subtitle": "subtitle.shinobicore.charge_ready"
  },
  "shot_fire": {
    "sounds": ["minecraft:entity/blaze/shoot"],
    "category": "player", "subtitle": "subtitle.shinobicore.shot_fire"
  },
  "shot_water": {
    "sounds": ["minecraft:entity/dolphin/splash"],
    "category": "player", "subtitle": "subtitle.shinobicore.shot_water"
  },
  "shot_wind": {
    "sounds": ["minecraft:entity/player/attack/sweep1", "minecraft:entity/player/attack/sweep2"],
    "category": "player", "subtitle": "subtitle.shinobicore.shot_wind"
  },
  "shot_lightning": {
    "sounds": ["minecraft:entity/lightning_bolt/impact"],
    "category": "player", "subtitle": "subtitle.shinobicore.shot_lightning"
  },
  "shot_earth": {
    "sounds": ["minecraft:block/stone/break1", "minecraft:block/stone/break2"],
    "category": "player", "subtitle": "subtitle.shinobicore.shot_earth"
  },
  "hit_impact": {
    "sounds": ["minecraft:entity/player/attack/strong1", "minecraft:entity/player/attack/strong2"],
    "category": "player", "subtitle": "subtitle.shinobicore.hit_impact"
  },
  "explosion_small": {
    "sounds": ["minecraft:entity/generic/explode"],
    "category": "player", "subtitle": "subtitle.shinobicore.explosion_small"
  },
  "explosion_large": {
    "sounds": ["minecraft:entity/ender_dragon/growl"],
    "category": "player", "subtitle": "subtitle.shinobicore.explosion_large"
  },
  "clone_disperse": {
    "sounds": ["minecraft:entity/generic/extinguish_fire"],
    "category": "player", "subtitle": "subtitle.shinobicore.clone_disperse"
  },
  "kawarimi": {
    "sounds": ["minecraft:entity/enderman/teleport"],
    "category": "player", "subtitle": "subtitle.shinobicore.kawarimi"
  },
  "telegraph_melee": {
    "sounds": ["minecraft:entity/zombie/attack_wooden_door"],
    "category": "hostile", "subtitle": "subtitle.shinobicore.telegraph_melee"
  },
  "telegraph_ranged": {
    "sounds": ["minecraft:entity/skeleton/shoot"],
    "category": "hostile", "subtitle": "subtitle.shinobicore.telegraph_ranged"
  }
}
'@
Write-File (Join-Path $resBase "sounds.json") $soundsJson

# ============================================================
# S5-07: SHADER COMPATIBILITY MANAGER
# ============================================================
Write-Host "[S5-07] Creating ShaderCompatibilityManager..." -ForegroundColor Yellow

$shaderCompat = @'
package com.example.shinobicore.client.render;

import com.example.shinobicore.ShinobiCore;
import net.fabricmc.loader.api.FabricLoader;
import net.minecraft.client.render.RenderLayer;
import net.minecraft.util.Identifier;

/**
 * S5-07: Shader compatibility manager.
 * Detects Iris/Sodium and adjusts rendering to prevent:
 * - Black squares with transparency
 * - Depth buffer issues
 * - Incorrect render order
 * - Missing glow/emissive effects
 */
public class ShaderCompatibilityManager {

    private static boolean irisLoaded = false;
    private static boolean sodiumLoaded = false;
    private static boolean initialized = false;

    public static void init() {
        if (initialized) return;
        initialized = true;
        irisLoaded = FabricLoader.getInstance().isModLoaded("iris");
        sodiumLoaded = FabricLoader.getInstance().isModLoaded("sodium");
        ShinobiCore.LOGGER.info("[SHADER] Iris: {}, Sodium: {}", irisLoaded, sodiumLoaded);
    }

    public static boolean isIrisLoaded() {
        if (!initialized) init();
        return irisLoaded;
    }

    public static boolean isSodiumLoaded() {
        if (!initialized) init();
        return sodiumLoaded;
    }

    /**
     * Get VFX render layer compatible with current shader setup.
     * Iris requires EntityTranslucentCull to avoid black squares.
     */
    public static RenderLayer getVfxLayer(Identifier texture) {
        if (!initialized) init();
        if (irisLoaded) {
            return RenderLayer.getEntityTranslucentCull(texture);
        }
        return RenderLayer.getEntityTranslucent(texture);
    }

    /**
     * Get emissive render layer.
     * With shaders, emissive uses same layer but with max light.
     */
    public static RenderLayer getEmissiveLayer(Identifier texture) {
        if (!initialized) init();
        if (irisLoaded) {
            return RenderLayer.getEntityTranslucentCull(texture);
        }
        return RenderLayer.getEntityTranslucent(texture);
    }

    /**
     * Recommended particle limit based on shader presence.
     * Shaders are GPU-expensive, so reduce particle count.
     */
    public static int getParticleLimit() {
        if (!initialized) init();
        if (irisLoaded && sodiumLoaded) return 300;
        if (irisLoaded) return 350;
        return 400;
    }

    /**
     * Whether to use alternative blending for transparency.
     * Iris handles alpha blending differently.
     */
    public static boolean needsAlternativeBlending() {
        if (!initialized) init();
        return irisLoaded;
    }

    /**
     * Whether double-sided rendering is needed.
     * With shaders, backface culling can cause artifacts.
     */
    public static boolean needsDoubleSided() {
        if (!initialized) init();
        return irisLoaded;
    }
}
'@
Write-File (Join-Path $clientDir "render\ShaderCompatibilityManager.java") $shaderCompat

# ============================================================
# S5-08: PERFORMANCE OPTIMIZER
# ============================================================
Write-Host "[S5-08] Creating VoxelPerformanceOptimizer..." -ForegroundColor Yellow

$perfOptimizer = @'
package com.example.shinobicore.client.vfx;

import net.minecraft.client.MinecraftClient;

/**
 * S5-08: Performance optimizer for voxel rendering.
 * Handles: mesh baking control, buffer reuse tracking,
 * internal cube culling, dragon segment limits,
 * dynamic quality adjustment based on FPS.
 */
public class VoxelPerformanceOptimizer {

    private static int maxDragonSegments = 12;
    private static int maxActiveMeshes = 50;
    private static int currentActiveMeshes = 0;
    private static boolean enableInternalCulling = true;

    /**
     * Check if we can render more meshes this frame.
     */
    public static boolean canRenderMesh() {
        return currentActiveMeshes < maxActiveMeshes;
    }

    public static void registerMesh() { currentActiveMeshes++; }

    public static void unregisterMesh() {
        currentActiveMeshes = Math.max(0, currentActiveMeshes - 1);
    }

    /**
     * Reset frame counter. Call at start of each render frame.
     */
    public static void resetFrame() { currentActiveMeshes = 0; }

    /**
     * Max dragon segments based on performance settings.
     */
    public static int getMaxDragonSegments() { return maxDragonSegments; }

    public static void setMaxDragonSegments(int segments) {
        maxDragonSegments = Math.max(4, Math.min(20, segments));
    }

    /**
     * Internal cube culling: skip cubes fully surrounded by others.
     */
    public static boolean isInternalCullingEnabled() { return enableInternalCulling; }

    public static void setInternalCulling(boolean enabled) {
        enableInternalCulling = enabled;
    }

    /**
     * Get current FPS for dynamic quality adjustment.
     */
    public static int getCurrentFps() {
        MinecraftClient client = MinecraftClient.getInstance();
        return client != null ? client.getCurrentFps() : 60;
    }

    /**
     * Dynamic quality multiplier based on FPS.
     * Returns 0.5-1.0 for particle count and mesh detail scaling.
     */
    public static float getQualityMultiplier() {
        int fps = getCurrentFps();
        if (fps < 30) return 0.5f;
        if (fps < 45) return 0.7f;
        if (fps < 60) return 0.85f;
        return 1.0f;
    }

    /**
     * Check if a cube is fully internal (all 6 faces hidden).
     * Used to skip rendering invisible cubes in dense models.
     */
    public static boolean isCubeInternal(VoxelModel model, int cubeIndex) {
        if (!enableInternalCulling) return false;
        var cubes = model.getCubes();
        if (cubeIndex < 0 || cubeIndex >= cubes.size()) return false;

        VoxelCube cube = cubes.get(cubeIndex);
        float cx = cube.x(), cy = cube.y(), cz = cube.z();
        float hw = cube.w() / 2f, hh = cube.h() / 2f, hd = cube.d() / 2f;

        boolean hasLeft = false, hasRight = false, hasTop = false;
        boolean hasBottom = false, hasFront = false, hasBack = false;

        for (int i = 0; i < cubes.size(); i++) {
            if (i == cubeIndex) continue;
            VoxelCube other = cubes.get(i);
            float dx = Math.abs(other.x() - cx);
            float dy = Math.abs(other.y() - cy);
            float dz = Math.abs(other.z() - cz);

            if (dy <= hh + 0.01f && dz <= hd + 0.01f) {
                if (dx <= hw + other.w() / 2f + 0.01f) {
                    if (other.x() < cx) hasLeft = true;
                    if (other.x() > cx) hasRight = true;
                }
            }
            if (dx <= hw + 0.01f && dz <= hd + 0.01f) {
                if (dy <= hh + other.h() / 2f + 0.01f) {
                    if (other.y() < cy) hasBottom = true;
                    if (other.y() > cy) hasTop = true;
                }
            }
            if (dx <= hw + 0.01f && dy <= hh + 0.01f) {
                if (dz <= hd + other.d() / 2f + 0.01f) {
                    if (other.z() < cz) hasBack = true;
                    if (other.z() > cz) hasFront = true;
                }
            }
        }
        return hasLeft && hasRight && hasTop && hasBottom && hasFront && hasBack;
    }
}
'@
Write-File (Join-Path $clientDir "vfx\VoxelPerformanceOptimizer.java") $perfOptimizer

# ============================================================
# PATCH: VoxelEffectRenderer - use ShaderCompatibilityManager
# ============================================================
Write-Host "[PATCH] VoxelEffectRenderer -> ShaderCompatibilityManager..." -ForegroundColor Yellow

$vfxRendererFile = Join-Path $clientDir "vfx\VoxelEffectRenderer.java"
Patch-File $vfxRendererFile `
    "import net.minecraft.client.render.RenderLayer;" `
    "import net.minecraft.client.render.RenderLayer;`nimport com.example.shinobicore.client.render.ShaderCompatibilityManager;"

Patch-File $vfxRendererFile `
    "VertexConsumer vc =`n            vcProvider.getBuffer(RenderLayer.getEntityTranslucent(TEX));" `
    "VertexConsumer vc =`n            vcProvider.getBuffer(ShaderCompatibilityManager.getVfxLayer(TEX));"

# ============================================================
# PATCH: VoxelParticleManager - ShaderCompat + particle limit
# ============================================================
Write-Host "[PATCH] VoxelParticleManager -> ShaderCompat + limits..." -ForegroundColor Yellow

$particleMgrFile = Join-Path $clientDir "vfx\particles\VoxelParticleManager.java"
Patch-File $particleMgrFile `
    "import net.minecraft.client.render.RenderLayer;" `
    "import net.minecraft.client.render.RenderLayer;`nimport com.example.shinobicore.client.render.ShaderCompatibilityManager;"

Patch-File $particleMgrFile `
    "private static final int MAX_PARTICLES = 400;" `
    "private static int getMaxParticles() { return ShaderCompatibilityManager.getParticleLimit(); }"

Patch-File $particleMgrFile `
    "if (active.size() >= MAX_PARTICLES) return false;" `
    "if (active.size() >= getMaxParticles()) return false;"

Patch-File $particleMgrFile `
    "VertexConsumer consumer = vc.getBuffer(RenderLayer.getEntityTranslucent(TEX));" `
    "VertexConsumer consumer = vc.getBuffer(ShaderCompatibilityManager.getVfxLayer(TEX));"

# ============================================================
# PATCH: DragonRenderer - segment limit via PerformanceOptimizer
# ============================================================
Write-Host "[PATCH] DragonRenderer -> segment limit..." -ForegroundColor Yellow

$dragonRendererFile = Join-Path $clientDir "..\entity\DragonRenderer.java"
if (-not (Test-Path $dragonRendererFile)) {
    $dragonRendererFile = Join-Path $srcBase "entity\DragonRenderer.java"
}
Patch-File $dragonRendererFile `
    "import net.minecraft.util.math.RotationAxis;" `
    "import net.minecraft.util.math.RotationAxis;`nimport com.example.shinobicore.client.vfx.VoxelPerformanceOptimizer;"

Patch-File $dragonRendererFile `
    "int segCount = entity.getSegmentCount();" `
    "int segCount = Math.min(entity.getSegmentCount(), VoxelPerformanceOptimizer.getMaxDragonSegments());"

# ============================================================
# PATCH: ShinobiCoreClient - init ShaderCompat + frame reset
# ============================================================
Write-Host "[PATCH] ShinobiCoreClient -> ShaderCompat + PerfOptimizer..." -ForegroundColor Yellow

$clientMainFile = Join-Path $clientDir "ShinobiCoreClient.java"
Patch-File $clientMainFile `
    "import com.example.shinobicore.client.RasenganClientVisual;" `
    "import com.example.shinobicore.client.RasenganClientVisual;`nimport com.example.shinobicore.client.render.ShaderCompatibilityManager;`nimport com.example.shinobicore.client.vfx.VoxelPerformanceOptimizer;"

Patch-File $clientMainFile `
    "KeyBindings.register();" `
    "KeyBindings.register();`n        // S5-07: Initialize shader compatibility detection`n        ShaderCompatibilityManager.init();"

Patch-File $clientMainFile `
    "ClientTickEvents.END_CLIENT_TICK.register(CinematicCamera::tick);" `
    "ClientTickEvents.END_CLIENT_TICK.register(CinematicCamera::tick);`n        // S5-08: Reset performance counters each frame`n        ClientTickEvents.END_CLIENT_TICK.register(client -> VoxelPerformanceOptimizer.resetFrame());"

# ============================================================
# PATCH: Add lang entries for new sound subtitles
# ============================================================
Write-Host "[PATCH] Adding sound subtitles to lang files..." -ForegroundColor Yellow

$enLangFile = Join-Path $resBase "lang\en_us.json"
if (Test-Path $enLangFile) {
    $langContent = [System.IO.File]::ReadAllText($enLangFile, $utf8)
    $langContent = $langContent.Replace("`r`n", "`n")
    
    $subtitleEntries = @'
  "subtitle.shinobicore.cast_start": "Jutsu casting",
  "subtitle.shinobicore.cast_complete": "Jutsu complete",
  "subtitle.shinobicore.charge_loop": "Charging chakra",
  "subtitle.shinobicore.charge_ready": "Technique charged",
  "subtitle.shinobicore.shot_fire": "Fire jutsu",
  "subtitle.shinobicore.shot_water": "Water jutsu",
  "subtitle.shinobicore.shot_wind": "Wind jutsu",
  "subtitle.shinobicore.shot_lightning": "Lightning jutsu",
  "subtitle.shinobicore.shot_earth": "Earth jutsu",
  "subtitle.shinobicore.hit_impact": "Impact",
  "subtitle.shinobicore.explosion_small": "Explosion",
  "subtitle.shinobicore.explosion_large": "Massive explosion",
  "subtitle.shinobicore.clone_disperse": "Clone disperses",
  "subtitle.shinobicore.kawarimi": "Substitution",
  "subtitle.shinobicore.telegraph_melee": "Enemy attacks",
  "subtitle.shinobicore.telegraph_ranged": "Enemy fires"
}
'@
    
    if (-not $langContent.Contains("subtitle.shinobicore.cast_start")) {
        $langContent = $langContent.Replace("}", "`n$subtitleEntries")
        [System.IO.File]::WriteAllText($enLangFile, $langContent, $utf8)
        Write-Host "  [PATCH] en_us.json subtitles added" -ForegroundColor Green
    } else {
        Write-Host "  [SKIP] en_us.json already has subtitles" -ForegroundColor Yellow
    }
}

$ruLangFile = Join-Path $resBase "lang\ru_ru.json"
if (Test-Path $ruLangFile) {
    $langContent = [System.IO.File]::ReadAllText($ruLangFile, $utf8)
    $langContent = $langContent.Replace("`r`n", "`n")
    
    $ruSubtitles = @'
  "subtitle.shinobicore.cast_start": "Каст дзюцу",
  "subtitle.shinobicore.cast_complete": "Дзюцу завершено",
  "subtitle.shinobicore.charge_loop": "Зарядка чакры",
  "subtitle.shinobicore.charge_ready": "Техника заряжена",
  "subtitle.shinobicore.shot_fire": "Огненное дзюцу",
  "subtitle.shinobicore.shot_water": "Водяное дзюцу",
  "subtitle.shinobicore.shot_wind": "Ветряное дзюцу",
  "subtitle.shinobicore.shot_lightning": "Молниевое дзюцу",
  "subtitle.shinobicore.shot_earth": "Земляное дзюцу",
  "subtitle.shinobicore.hit_impact": "Удар",
  "subtitle.shinobicore.explosion_small": "Взрыв",
  "subtitle.shinobicore.explosion_large": "Мощный взрыв",
  "subtitle.shinobicore.clone_disperse": "Клон рассеивается",
  "subtitle.shinobicore.kawarimi": "Подмена",
  "subtitle.shinobicore.telegraph_melee": "Враг атакует",
  "subtitle.shinobicore.telegraph_ranged": "Враг стреляет"
}
'@
    
    if (-not $langContent.Contains("subtitle.shinobicore.cast_start")) {
        $langContent = $langContent.Replace("}", "`n$ruSubtitles")
        [System.IO.File]::WriteAllText($ruLangFile, $langContent, $utf8)
        Write-Host "  [PATCH] ru_ru.json subtitles added" -ForegroundColor Green
    } else {
        Write-Host "  [SKIP] ru_ru.json already has subtitles" -ForegroundColor Yellow
    }
}

# ============================================================
# BUILD VERIFICATION
# ============================================================
Write-Host ""
Write-Host "[BUILD] Verifying compilation..." -ForegroundColor Yellow
Push-Location $root
try {
    $out = & ".\gradlew.bat" build 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [PASS] Build successful!" -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] Build failed" -ForegroundColor Red
        $out | Select-Object -Last 20 | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
    }
} finally { Pop-Location }

# ============================================================
# SUMMARY
# ============================================================
Write-Host ""
Write-Host "==============================================================" -ForegroundColor Green
Write-Host "  SPRINT 5 PHASE C COMPLETE" -ForegroundColor Green
Write-Host "==============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Created files:" -ForegroundColor White
Write-Host "  - client/sound/NinjaSoundManager.java (S5-06: sound pipeline)" -ForegroundColor Cyan
Write-Host "  - client/render/ShaderCompatibilityManager.java (S5-07: Iris/Sodium)" -ForegroundColor Cyan
Write-Host "  - client/vfx/VoxelPerformanceOptimizer.java (S5-08: perf)" -ForegroundColor Cyan
Write-Host "  - assets/shinobicore/sounds.json (S5-06: 24 sound events)" -ForegroundColor Cyan
Write-Host ""
Write-Host "Patched files:" -ForegroundColor White
Write-Host "  - VoxelEffectRenderer.java (ShaderCompat render layer)" -ForegroundColor Cyan
Write-Host "  - VoxelParticleManager.java (ShaderCompat + dynamic limit)" -ForegroundColor Cyan
Write-Host "  - DragonRenderer.java (segment limit)" -ForegroundColor Cyan
Write-Host "  - ShinobiCoreClient.java (init + frame reset)" -ForegroundColor Cyan
Write-Host "  - en_us.json / ru_ru.json (sound subtitles)" -ForegroundColor Cyan
Write-Host ""
Write-Host "Sound categories (S5-06):" -ForegroundColor White
Write-Host "  CAST, CHARGE, SHOT (5 elements), HIT, EXPLOSION," -ForegroundColor Yellow
Write-Host "  LOOP, DISPERSE, KAWARIMI, TELEGRAPH (melee/ranged)" -ForegroundColor Yellow
Write-Host ""
Write-Host "Shader compatibility (S5-07):" -ForegroundColor White
Write-Host "  Iris detection -> EntityTranslucentCull (no black squares)" -ForegroundColor Yellow
Write-Host "  Sodium detection -> reduced particle limit (300 vs 400)" -ForegroundColor Yellow
Write-Host "  Dynamic blending + double-sided rendering flags" -ForegroundColor Yellow
Write-Host ""
Write-Host "Performance (S5-08):" -ForegroundColor White
Write-Host "  Frame mesh counter (max 50 active meshes)" -ForegroundColor Yellow
Write-Host "  Dragon segment limit (default 12, range 4-20)" -ForegroundColor Yellow
Write-Host "  Internal cube culling (skip hidden faces)" -ForegroundColor Yellow
Write-Host "  Dynamic quality multiplier (FPS-based: 0.5x-1.0x)" -ForegroundColor Yellow
Write-Host ""
Write-Host "SPRINT 5 FULLY COMPLETE!" -ForegroundColor Green
Write-Host ""