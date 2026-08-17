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