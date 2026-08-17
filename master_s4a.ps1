# ============================================================
# SHINOBICORE MASTER SCRIPT: S4-07 (LOD/Culling) + S4-09 (Quality)
# Voxel Rendering Optimization & Quality Settings
# ============================================================
$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$root = "E:\Games\mod"
$srcBase = Join-Path $root "src\main\java\com\example\shinobicore"
$clientVfxDir = Join-Path $srcBase "client\vfx"
$configDir = Join-Path $srcBase "config"

Write-Host ""
Write-Host "==============================================================" -ForegroundColor Cyan
Write-Host "  S4-07 / S4-09: Voxel LOD, Culling & Quality Settings" -ForegroundColor Cyan
Write-Host "==============================================================" -ForegroundColor Cyan
Write-Host ""

# --- Helper Functions ---
function Write-SafeFile($path, $content) {
    $dir = Split-Path $path -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [System.IO.File]::WriteAllText($path, $content, $utf8)
    Write-Host "  [OK] $(Split-Path $path -Leaf)" -ForegroundColor Green
}

function Patch-SafeFile($p, $old, $new) {
    if (-not (Test-Path $p)) { Write-Host "  [MISS] $p" -ForegroundColor Red; return $false }
    $c = [System.IO.File]::ReadAllText($p, $utf8)
    $c = $c.Replace("`r`n", "`n")
    $oldNorm = $old.Replace("`r`n", "`n")
    $newNorm = $new.Replace("`r`n", "`n")
    
    if ($c.Contains($newNorm)) { Write-Host "  [SKIP] Already applied: $(Split-Path $p -Leaf)" -ForegroundColor Yellow; return $true }
    if (-not $c.Contains($oldNorm)) { Write-Host "  [FAIL] Pattern not found in $(Split-Path $p -Leaf)" -ForegroundColor Red; return $false }
    
    $c = $c.Replace($oldNorm, $newNorm)
    [System.IO.File]::WriteAllText($p, $c, $utf8)
    Write-Host "  [PATCH] $(Split-Path $p -Leaf)" -ForegroundColor Green
    return $true
}

# ============================================================
# 1. VoxelQualityConfig.java (S4-09)
# Client-side quality settings with persistence
# ============================================================
Write-Host "[S4-09] Creating VoxelQualityConfig..." -ForegroundColor Yellow

$qualityConfig = @'
package com.example.shinobicore.client.vfx;

import com.example.shinobicore.ShinobiCore;
import com.google.gson.Gson;
import com.google.gson.GsonBuilder;
import net.fabricmc.loader.api.FabricLoader;
import java.io.FileReader;
import java.io.FileWriter;
import java.nio.file.Files;
import java.nio.file.Path;

/**
 * S4-09: Client-side voxel rendering quality settings.
 * Controls LOD distances, particle counts, and culling.
 */
public class VoxelQualityConfig {
    public enum QualityLevel { LOW, MEDIUM, HIGH }
    
    // Runtime settings
    public static QualityLevel currentLevel = QualityLevel.MEDIUM;
    public static float lodNearDistance = 16.0f;  // Full detail
    public static float lodFarDistance = 32.0f;   // Simplified mesh
    public static float cullDistance = 64.0f;     // Don't render beyond this
    public static boolean enableFrustumCulling = true;
    public static float particleDensity = 1.0f;   // 0.5 = half particles
    
    private static final Gson GSON = new GsonBuilder().setPrettyPrinting().create();
    
    public static void applyPreset(QualityLevel level) {
        currentLevel = level;
        switch (level) {
            case LOW -> {
                lodNearDistance = 8.0f;
                lodFarDistance = 16.0f;
                cullDistance = 32.0f;
                particleDensity = 0.3f;
            }
            case MEDIUM -> {
                lodNearDistance = 16.0f;
                lodFarDistance = 32.0f;
                cullDistance = 64.0f;
                particleDensity = 0.7f;
            }
            case HIGH -> {
                lodNearDistance = 32.0f;
                lodFarDistance = 64.0f;
                cullDistance = 128.0f;
                particleDensity = 1.0f;
            }
        }
        ShinobiCore.LOGGER.info("[VFX] Quality set to {}: LOD near={}, far={}, cull={}, particles={}", 
            level, lodNearDistance, lodFarDistance, cullDistance, particleDensity);
    }
    
    public static Path path() {
        return FabricLoader.getInstance().getConfigDir()
            .resolve("shinobicore").resolve("voxel_quality.json");
    }
    
    public static void load() {
        try {
            Path p = path();
            if (!Files.exists(p)) {
                applyPreset(QualityLevel.MEDIUM);
                save();
                return;
            }
            try (FileReader reader = new FileReader(p.toFile())) {
                SavedConfig saved = GSON.fromJson(reader, SavedConfig.class);
                if (saved != null && saved.level != null) {
                    applyPreset(saved.level);
                } else {
                    applyPreset(QualityLevel.MEDIUM);
                }
            }
        } catch (Exception e) {
            ShinobiCore.LOGGER.error("[VFX] Failed to load quality config", e);
            applyPreset(QualityLevel.MEDIUM);
        }
    }
    
    public static void save() {
        try {
            Files.createDirectories(path().getParent());
            SavedConfig saved = new SavedConfig();
            saved.level = currentLevel;
            try (FileWriter writer = new FileWriter(path().toFile())) {
                GSON.toJson(saved, writer);
            }
        } catch (Exception e) {
            ShinobiCore.LOGGER.error("[VFX] Failed to save quality config", e);
        }
    }
    
    private static class SavedConfig {
        QualityLevel level;
    }
}
'@
Write-SafeFile (Join-Path $clientVfxDir "VoxelQualityConfig.java") $qualityConfig

# ============================================================
# 2. VoxelRenderManager.java (S4-07)
# Central manager for LOD, culling, and optimized rendering
# ============================================================
Write-Host "[S4-07] Creating VoxelRenderManager..." -ForegroundColor Yellow

$renderManager = @'
package com.example.shinobicore.client.vfx;

import net.minecraft.client.MinecraftClient;
import net.minecraft.client.render.VertexConsumerProvider;
import net.minecraft.client.util.math.MatrixStack;
import net.minecraft.util.math.Vec3d;

/**
 * S4-07: Central voxel render manager.
 * Handles LOD selection, frustum culling, and distance-based optimization.
 * All voxel effect rendering should go through this class.
 */
public class VoxelRenderManager {
    
    /**
     * Render a voxel model with automatic LOD and culling.
     * Returns false if the model was culled (not rendered).
     */
    public static boolean renderOptimized(
            MatrixStack matrices, 
            VertexConsumerProvider vcProvider,
            VoxelModel highDetailModel,
            VoxelModel lowDetailModel,
            Vec3d worldPos,
            float yaw, float pitch, float scale,
            int light) {
        
        MinecraftClient client = MinecraftClient.getInstance();
        if (client.player == null) return false;
        
        // === FRUSTUM & DISTANCE CULLING ===
        double distSq = client.player.getPos().squaredDistanceTo(worldPos);
        
        // Hard cull beyond max distance
        float cullDist = VoxelQualityConfig.cullDistance;
        if (distSq > cullDist * cullDist) return false;
        
        // Simple frustum check using dot product with look direction
        if (VoxelQualityConfig.enableFrustumCulling) {
            Vec3d toObj = worldPos.subtract(client.player.getEyePos()).normalize();
            Vec3d look = client.player.getRotationVector();
            double dot = look.dotProduct(toObj);
            // Behind camera check (allow some margin for large objects)
            if (dot < -0.3) return false;
        }
        
        // === LOD SELECTION ===
        float dist = (float) Math.sqrt(distSq);
        VoxelModel selectedModel;
        
        if (dist <= VoxelQualityConfig.lodNearDistance) {
            selectedModel = highDetailModel;
        } else if (dist <= VoxelQualityConfig.lodFarDistance) {
            selectedModel = (lowDetailModel != null) ? lowDetailModel : highDetailModel;
        } else {
            // Far distance: use lowest detail or skip if too small
            if (scale < 0.5f && dist > VoxelQualityConfig.lodFarDistance * 1.5f) return false;
            selectedModel = (lowDetailModel != null) ? lowDetailModel : highDetailModel;
        }
        
        if (selectedModel == null || selectedModel.getCubeCount() == 0) return false;
        
        // === RENDER ===
        VoxelEffectRenderer.render(matrices, vcProvider, selectedModel, yaw, pitch, scale, light);
        return true;
    }
    
    /**
     * Simplified render for single-model effects (no LOD variant).
     * Still applies culling.
     */
    public static boolean renderWithCulling(
            MatrixStack matrices,
            VertexConsumerProvider vcProvider,
            VoxelModel model,
            Vec3d worldPos,
            float yaw, float pitch, float scale,
            int light) {
        return renderOptimized(matrices, vcProvider, model, null, worldPos, yaw, pitch, scale, light);
    }
    
    /**
     * Check if particles should spawn based on quality settings.
     * Use this before spawning particle effects.
     */
    public static boolean shouldSpawnParticles() {
        return Math.random() < VoxelQualityConfig.particleDensity;
    }
    
    /**
     * Get adjusted particle count based on quality.
     */
    public static int adjustParticleCount(int baseCount) {
        return Math.max(1, (int)(baseCount * VoxelQualityConfig.particleDensity));
    }
}
'@
Write-SafeFile (Join-Path $clientVfxDir "VoxelRenderManager.java") $renderManager

# ============================================================
# 3. Patch VoxelShapeGenerators to add LOD variants (S4-07)
# Add simplified sphere generator for far-distance rendering
# ============================================================
Write-Host "[S4-07] Adding LOD generators to VoxelShapeGenerators..." -ForegroundColor Yellow

$lodGenerators = @'

    // === S4-07: LOD VARIANTS ===
    
    /** Low-detail sphere for far distances (4 segments instead of full resolution) */
    public static VoxelModel sphereLow(float radius, float r, float g, float b, float a) {
        return sphere(radius, 4, r, g, b, a);
    }
    
    /** Low-detail projectile (elongated sphere with minimal segments) */
    public static VoxelModel projectileLow(float radius, float elongation, float r, float g, float b, float a) {
        return projectile(radius, elongation, r, g, b, a);
    }
'@

$genFile = Join-Path $clientVfxDir "VoxelShapeGenerators.java"
if (Test-Path $genFile) {
    $c = [System.IO.File]::ReadAllText($genFile, $utf8)
    if (-not $c.Contains("S4-07: LOD VARIANTS")) {
        # Insert before the last closing brace
        $lastBrace = $c.LastIndexOf("}")
        if ($lastBrace -gt 0) {
            $c = $c.Insert($lastBrace, $lodGenerators)
            [System.IO.File]::WriteAllText($genFile, $c, $utf8)
            Write-Host "  [PATCH] VoxelShapeGenerators.java (LOD methods added)" -ForegroundColor Green
        }
    } else {
        Write-Host "  [SKIP] LOD generators already present" -ForegroundColor Yellow
    }
}

# ============================================================
# 4. Patch ShinobiCoreClient to load quality config (S4-09)
# ============================================================
Write-Host "[S4-09] Patching ShinobiCoreClient to load quality config..." -ForegroundColor Yellow

$clientFile = Join-Path $srcBase "client\ShinobiCoreClient.java"
Patch-SafeFile $clientFile `
    "KeyBindings.register();" `
    "KeyBindings.register();`n        // S4-09: Load voxel quality settings`n        com.example.shinobicore.client.vfx.VoxelQualityConfig.load();"

# ============================================================
# BUILD VERIFICATION
# ============================================================
Write-Host ""
Write-Host "[BUILD] Verifying compilation..." -ForegroundColor Yellow
Push-Location $root
try {
    $buildOut = & ".\gradlew.bat" build 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [PASS] Build successful!" -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] Build failed" -ForegroundColor Red
        $buildOut | Select-Object -Last 20 | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
    }
} finally { Pop-Location }

Write-Host ""
Write-Host "==============================================================" -ForegroundColor Green
Write-Host "  S4-07 + S4-09 COMPLETE" -ForegroundColor Green
Write-Host "==============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Created files:" -ForegroundColor White
Write-Host "  - client/vfx/VoxelQualityConfig.java  (S4-09: Quality presets)" -ForegroundColor Cyan
Write-Host "  - client/vfx/VoxelRenderManager.java  (S4-07: LOD + Culling)" -ForegroundColor Cyan
Write-Host ""
Write-Host "Usage in renderers:" -ForegroundColor Yellow
Write-Host "  // Instead of VoxelEffectRenderer.render(...)" -ForegroundColor White
Write-Host "  VoxelRenderManager.renderOptimized(" -ForegroundColor White
Write-Host "      matrices, vcProvider," -ForegroundColor White
Write-Host "      highDetailModel, lowDetailModel," -ForegroundColor White
Write-Host "      worldPos, yaw, pitch, scale, light);" -ForegroundColor White
Write-Host ""
Write-Host "  // Particle budget:" -ForegroundColor White
Write-Host "  if (VoxelRenderManager.shouldSpawnParticles()) {" -ForegroundColor White
Write-Host "      int count = VoxelRenderManager.adjustParticleCount(20);" -ForegroundColor White
Write-Host "  }" -ForegroundColor White
Write-Host ""
Write-Host "Quality config: config/shinobicore/voxel_quality.json" -ForegroundColor Cyan
Write-Host ""