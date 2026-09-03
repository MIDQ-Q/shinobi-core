package com.example.shinobicore.core.api;

import com.mojang.brigadier.CommandDispatcher;
import net.minecraft.server.MinecraftServer;
import net.minecraft.server.command.ServerCommandSource;

/**
 * Base interface for all ShinobiCore modules.
 * Defines lifecycle methods for module initialization and management.
 */
public interface ShinobiModule {
    /**
     * Get the unique identifier for this module.
     */
    String id();
    
    /**
     * Called when the module is registered.
     * Use this for early setup before other modules load.
     */
    default void onRegister(ModuleContext ctx) {}
    
    /**
     * Called when the module is enabled.
     * Use this for initialization, loading data, registering content.
     */
    default void onEnable(ModuleContext ctx) {}
    
    /**
     * Called when the module is disabled.
     * Use this for cleanup, saving data, unregistering content.
     */
    default void onDisable(ModuleContext ctx) {}
    
    /**
     * Called every server tick.
     */
    default void onServerTick(ModuleContext ctx, MinecraftServer server) {}
    
    /**
     * Register commands for this module.
     */
    default void registerCommands(ModuleContext ctx, CommandDispatcher<ServerCommandSource> dispatcher) {}
}