package com.example.shinobicore.core.api;
import com.mojang.brigadier.CommandDispatcher;
import net.minecraft.server.MinecraftServer;
import net.minecraft.server.command.ServerCommandSource;
public interface ShinobiModule {
    String id();
    default void onRegister(ModuleContext ctx) {}
    default void onEnable(ModuleContext ctx) {}
    default void onDisable(ModuleContext ctx) {}
    default void registerEvents(ModuleContext ctx) {}
    default void registerViews(ModuleContext ctx) {}
    default void registerCommands(ModuleContext ctx, CommandDispatcher<ServerCommandSource> dispatcher) {}
    default void onServerStarting(ModuleContext ctx, MinecraftServer server) {}
    default void onServerStopping(ModuleContext ctx, MinecraftServer server) {}
    default void onServerTick(ModuleContext ctx, MinecraftServer server) {}
}