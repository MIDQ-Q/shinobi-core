package com.example.shinobicore.world.config;

import java.io.File;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.Properties;

import com.example.shinobicore.ShinobiCore;

/**
 * S13-01: Configuration for world generation.
 * Controls density of forests, bamboo, villages, roads, etc.
 */
public class WorldGenConfig {
    
    public static WorldGenConfig instance;
    
    // Forest density (0.0 - 1.0)
    public double forestDensity = 0.7;
    public double sakuraChance = 0.4; // 40% of trees are sakura
    public double bambooDensity = 0.3;
    
    // Village settings
    public double villageFrequency = 0.6; // Chance to spawn village per region
    public int minVillageDistance = 800; // Minimum distance between villages (blocks)
    public int maxVillageDistance = 2000; // Maximum distance for road connections
    public boolean multiClanVillages = true; // Enable large multi-clan villages
    
    // Road settings
    public boolean roadsEnabled = true;
    public double roadDensity = 0.8;
    public int lanternRadiusChunks = 3; // Lanterns within 3 chunks from village
    
    // Mountain settings
    public double mountainFrequency = 0.4;
    public boolean japaneseMountains = true; // Enable pagodas on peaks
    
    // Water features
    public double koiPondChance = 0.2;
    public double riceFieldChance = 0.3;
    
    // Decorations
    public double stoneLanternDensity = 0.5;
    public double toriiGateChance = 0.3;
    
    public WorldGenConfig() {
        instance = this;
        loadConfig();
    }
    
    private void loadConfig() {
        File configFile = new File("config/shinobicore_worldgen.properties");
        Properties props = new Properties();
        
        try {
            if (configFile.exists()) {
                props.load(Files.newInputStream(configFile.toPath()));
                forestDensity = Double.parseDouble(props.getProperty("forestDensity", "0.7"));
                sakuraChance = Double.parseDouble(props.getProperty("sakuraChance", "0.4"));
                bambooDensity = Double.parseDouble(props.getProperty("bambooDensity", "0.3"));
                villageFrequency = Double.parseDouble(props.getProperty("villageFrequency", "0.6"));
                minVillageDistance = Integer.parseInt(props.getProperty("minVillageDistance", "800"));
                maxVillageDistance = Integer.parseInt(props.getProperty("maxVillageDistance", "2000"));
                multiClanVillages = Boolean.parseBoolean(props.getProperty("multiClanVillages", "true"));
                roadsEnabled = Boolean.parseBoolean(props.getProperty("roadsEnabled", "true"));
                roadDensity = Double.parseDouble(props.getProperty("roadDensity", "0.8"));
                lanternRadiusChunks = Integer.parseInt(props.getProperty("lanternRadiusChunks", "3"));
                mountainFrequency = Double.parseDouble(props.getProperty("mountainFrequency", "0.4"));
                japaneseMountains = Boolean.parseBoolean(props.getProperty("japaneseMountains", "true"));
                koiPondChance = Double.parseDouble(props.getProperty("koiPondChance", "0.2"));
                riceFieldChance = Double.parseDouble(props.getProperty("riceFieldChance", "0.3"));
                stoneLanternDensity = Double.parseDouble(props.getProperty("stoneLanternDensity", "0.5"));
                toriiGateChance = Double.parseDouble(props.getProperty("toriiGateChance", "0.3"));
            } else {
                // Create default config
                configFile.getParentFile().mkdirs();
                props.setProperty("forestDensity", "0.7");
                props.setProperty("sakuraChance", "0.4");
                props.setProperty("bambooDensity", "0.3");
                props.setProperty("villageFrequency", "0.6");
                props.setProperty("minVillageDistance", "800");
                props.setProperty("maxVillageDistance", "2000");
                props.setProperty("multiClanVillages", "true");
                props.setProperty("roadsEnabled", "true");
                props.setProperty("roadDensity", "0.8");
                props.setProperty("lanternRadiusChunks", "3");
                props.setProperty("mountainFrequency", "0.4");
                props.setProperty("japaneseMountains", "true");
                props.setProperty("koiPondChance", "0.2");
                props.setProperty("riceFieldChance", "0.3");
                props.setProperty("stoneLanternDensity", "0.5");
                props.setProperty("toriiGateChance", "0.3");
                props.store(Files.newOutputStream(configFile.toPath()), "ShinobiCore World Generation Config");
            }
        } catch (IOException e) {
            ShinobiCore.LOGGER.warn("[WORLDGEN] Failed to load config, using defaults", e);
        }
        
        ShinobiCore.LOGGER.info("[WORLDGEN] Config loaded: forestDensity={}, sakuraChance={}, villageFrequency={}", 
            forestDensity, sakuraChance, villageFrequency);
    }
    
    public void save() {
        File configFile = new File("config/shinobicore_worldgen.properties");
        Properties props = new Properties();
        
        try {
            props.setProperty("forestDensity", String.valueOf(forestDensity));
            props.setProperty("sakuraChance", String.valueOf(sakuraChance));
            props.setProperty("bambooDensity", String.valueOf(bambooDensity));
            props.setProperty("villageFrequency", String.valueOf(villageFrequency));
            props.setProperty("minVillageDistance", String.valueOf(minVillageDistance));
            props.setProperty("maxVillageDistance", String.valueOf(maxVillageDistance));
            props.setProperty("multiClanVillages", String.valueOf(multiClanVillages));
            props.setProperty("roadsEnabled", String.valueOf(roadsEnabled));
            props.setProperty("roadDensity", String.valueOf(roadDensity));
            props.setProperty("lanternRadiusChunks", String.valueOf(lanternRadiusChunks));
            props.setProperty("mountainFrequency", String.valueOf(mountainFrequency));
            props.setProperty("japaneseMountains", String.valueOf(japaneseMountains));
            props.setProperty("koiPondChance", String.valueOf(koiPondChance));
            props.setProperty("riceFieldChance", String.valueOf(riceFieldChance));
            props.setProperty("stoneLanternDensity", String.valueOf(stoneLanternDensity));
            props.setProperty("toriiGateChance", String.valueOf(toriiGateChance));
            
            props.store(Files.newOutputStream(configFile.toPath()), "ShinobiCore World Generation Config");
        } catch (IOException e) {
            ShinobiCore.LOGGER.warn("[WORLDGEN] Failed to save config", e);
        }
    }
}
