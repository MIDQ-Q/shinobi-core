package com.example.shinobicore;

import com.example.shinobicore.tree.SkillTreeRegistry;

import com.example.shinobicore.tree.SkillTreeRegistry;

import com.example.shinobicore.jutsu.data.JutsuRegistry;
import com.example.shinobicore.clan.ClanRegistry;

import com.example.shinobicore.command.ShinobiCommands;

import com.example.shinobicore.combat.CombatIntegration;
import com.example.shinobicore.config.ShinobiCoreConfig;
import com.example.shinobicore.util.ModCompatibilityChecker;
import com.example.shinobicore.util.ShinobiConstants;
import com.example.shinobicore.util.ShinobiLogger;
import net.fabricmc.api.ModInitializer;
import net.fabricmc.fabric.api.event.lifecycle.v1.ServerLifecycleEvents;

public class ShinobiCore implements ModInitializer {
    public static final String MOD_ID = ShinobiConstants.MOD_ID;
    public static final org.slf4j.Logger LOGGER = org.slf4j.LoggerFactory.getLogger(MOD_ID);

    @Override
    public void onInitialize() {
        ShinobiCommands.register();
        ShinobiLogger.init();
        ShinobiLogger.info("=== ShinobiCore v3.0.0 Starting ===");

        ModCompatibilityChecker.init();
        ShinobiCoreConfig.load();

        ShinobiCoreConfig cfg = ShinobiCoreConfig.getInstance();
        try {
            ShinobiLogger.setLevel(ShinobiLogger.Level.valueOf(cfg.logLevel));
        } catch (IllegalArgumentException e) {
            ShinobiLogger.setLevel(ShinobiLogger.Level.DEBUG);
        }

        CombatIntegration.init();
        com.example.shinobicore.event.CombatXpEvents.register();

        ServerLifecycleEvents.SERVER_STARTED.register(server -> {
            ShinobiLogger.info("Server started - ShinobiCore ready!");
        });

        ServerLifecycleEvents.SERVER_STOPPING.register(server -> {
            ShinobiLogger.info("Server stopping - ShinobiCore shutting down...");
            ShinobiLogger.close();
        });

        ShinobiLogger.info("=== ShinobiCore v3.0.0 Initialized ===");

        // SHINOBICORE:MOVEMENT_V3:BEGIN
        // Packet registration (must be before ServerChakraMirror)
        com.example.shinobicore.network.ModPackets.registerServer();
        // Chakra mirror (server stores client values)
        com.example.shinobicore.chakra.server.ServerChakraMirror.register();
        // Movement mirror (server logs movement events)
        com.example.shinobicore.movement.server.ServerMovementMirror.register();
        // SHINOBICORE:MOVEMENT_V3:END
        ShinobiLogger.info("Data loaded: {} jutsu, {} clans, {} skill nodes", 
            JutsuRegistry.getAll().size(), 
            ClanRegistry.getAll().size(), 
            SkillTreeRegistry.getAll().size());
    }
}