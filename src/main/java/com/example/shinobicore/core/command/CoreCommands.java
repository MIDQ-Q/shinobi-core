package com.example.shinobicore.core.command;

import com.example.shinobicore.core.module.ModuleEntry;
import com.example.shinobicore.core.module.ModuleManager;
import com.mojang.brigadier.CommandDispatcher;
import com.mojang.brigadier.context.CommandContext;
import net.minecraft.server.command.CommandManager;
import net.minecraft.server.command.ServerCommandSource;
import net.minecraft.text.Text;
import net.minecraft.util.Formatting;

public final class CoreCommands {
    private CoreCommands() {}

    public static void register(CommandDispatcher<ServerCommandSource> dispatcher) {
        dispatcher.register(CommandManager.literal("shinobicore")
            .then(CommandManager.literal("systems")
                .executes(CoreCommands::cmdSystems))
            .then(CommandManager.literal("modules")
                .then(CommandManager.literal("list")
                    .executes(CoreCommands::cmdModulesList)))
            .then(CommandManager.literal("version")
                .executes(ctx -> {
                    ctx.getSource().sendFeedback(
                        () -> Text.literal("ShinobiCore 4.0.0").formatted(Formatting.AQUA), false);
                    return 1;
                }))
            .then(CommandManager.literal("movement")
                .then(CommandManager.literal("debug")
                    .executes(CoreCommands::cmdMovementDebug)))
        );
    }

    private static int cmdSystems(CommandContext<ServerCommandSource> ctx) {
        ServerCommandSource src = ctx.getSource();
        src.sendFeedback(() -> Text.literal("=== ShinobiCore Systems ===").formatted(Formatting.GOLD), false);
        for (ModuleEntry e : ModuleManager.all()) {
            Formatting f = Formatting.WHITE;
            switch (e.state()) {
                case ENABLED:  f = Formatting.GREEN; break;
                case DISABLED: f = Formatting.YELLOW; break;
                case FAILED:   f = Formatting.RED; break;
            }
            final Formatting ff = f;
            final String line = e.module().id() + " [" + e.provider() + "] -> " + e.state()
                    + (e.failReason().isEmpty() ? "" : " (" + e.failReason() + ")");
            src.sendFeedback(() -> Text.literal(line).formatted(ff), false);
        }
        return 1;
    }

    private static int cmdModulesList(CommandContext<ServerCommandSource> ctx) {
        return cmdSystems(ctx);
    }

    private static int cmdMovementDebug(CommandContext<ServerCommandSource> ctx) {
        ServerCommandSource src = ctx.getSource();
        try {
            int ticks = com.example.shinobicore.modules.movement.client.ClientMovementController.getTickCount();
            int errors = com.example.shinobicore.modules.movement.client.ClientMovementController.getErrorCount();
            boolean wallRunning = com.example.shinobicore.modules.movement.client.WallRunService.isRunning();

            String msg = "[Movement Debug] ticks=" + ticks
                + " errors=" + errors
                + " wallrunning=" + wallRunning;

            src.sendFeedback(() -> Text.literal(msg).formatted(Formatting.AQUA), false);
        } catch (Throwable t) {
            src.sendFeedback(() -> Text.literal("[Movement Debug] Error: " + t.getMessage()).formatted(Formatting.RED), false);
        }
        return 1;
    }
}