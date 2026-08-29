package com.example.shinobicore;

import com.example.shinobicore.network.ModPackets;
import net.fabricmc.api.ModInitializer;
import com.example.shinobicore.util.DebugTraceLogger;
import net.fabricmc.fabric.api.command.v2.CommandRegistrationCallback;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Main entrypoint for ShinobiCore v2.0.
 * HLD: Section 1.1 (CCA Architecture)
 */
public class ShinobiCore implements ModInitializer {
    public static final String MOD_ID = "shinobicore";
    public static final Logger LOGGER = LoggerFactory.getLogger(MOD_ID);

    @Override
    public void onInitialize() {
        LOGGER.info("Initializing ShinobiCore v2.0 (CCA Architecture)...");
        DebugTraceLogger.init();
        
        ModPackets.registerServer();

        // Sprint 1: Data-Driven Jutsu Engine (HLD Section 2)
        com.example.shinobicore.jutsu.JutsuEngineBootstrap.init();

        // Sprint 2: Combat system (HLD Section 4)
        com.example.shinobicore.combat.CombatBootstrap.init();

        // Sprint 4: Dojutsu and Clones (HLD Section 7)
        com.example.shinobicore.dojutsu.DojutsuBootstrap.init();
        com.example.shinobicore.world.ShinobiWorldBorder.init();
        com.example.shinobicore.world.ShinobiSpawnLocator.init();
        com.example.shinobicore.world.gen.VillageTracker.init();
        com.example.shinobicore.progression.ProgressionSystem.init();
        com.example.shinobicore.parkour.ParkourBootstrap.init();
        com.example.shinobicore.combat.ChakraModeSystem.init();
        com.example.shinobicore.combat.BlockSystem.init();



        // Sprint 5 Roads Step 1: village tracking persistence
        net.fabricmc.fabric.api.event.lifecycle.v1.ServerLifecycleEvents.SERVER_STARTED.register(server -> {
            com.example.shinobicore.world.gen.VillageTracker.get(server); // load from NBT
        });
        net.fabricmc.fabric.api.event.lifecycle.v1.ServerLifecycleEvents.SERVER_STOPPING.register(server -> {
            com.example.shinobicore.world.gen.VillageTracker.get(server).markDirty(); // save
        });
        net.fabricmc.fabric.api.command.v2.CommandRegistrationCallback.EVENT.register(
            (dispatcher, registryAccess, environment) -> com.example.shinobicore.command.DojutsuCommands.register(dispatcher)
        );
        net.fabricmc.fabric.api.command.v2.CommandRegistrationCallback.EVENT.register(
            (dispatcher, registryAccess, environment) -> com.example.shinobicore.command.EnemyCommands.register(dispatcher)
        );

        // Sprint 3: enemy commands (HLD Section 5)
        net.fabricmc.fabric.api.command.v2.CommandRegistrationCallback.EVENT.register(
            (dispatcher, registryAccess, environment) -> {
                com.example.shinobicore.command.EnemyCommands.register(dispatcher);
            }
        );
        
        CommandRegistrationCallback.EVENT.register((dispatcher, registryAccess, environment) -> {
            com.example.shinobicore.command.TestComponentsCommand.register(dispatcher);
        });
    }
}