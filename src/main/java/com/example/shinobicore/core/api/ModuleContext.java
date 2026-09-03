package com.example.shinobicore.core.api;

import com.mojang.brigadier.CommandDispatcher;
import net.minecraft.server.MinecraftServer;
import net.minecraft.server.command.ServerCommandSource;

/**
 * Context provided to modules during lifecycle events.
 */
public interface ModuleContext {
    CommandDispatcher<ServerCommandSource> getCommandDispatcher();
    MinecraftServer getServer();
}