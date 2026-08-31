// SHINOBICORE:SPRINT3:FILE
package com.example.shinobicore.command;

import com.example.shinobicore.chakra.server.ServerChakraMirror;
import com.example.shinobicore.config.FeatureFlags;
import com.mojang.brigadier.CommandDispatcher;
import com.mojang.brigadier.context.CommandContext;
import net.fabricmc.fabric.api.command.v2.CommandRegistrationCallback;
import net.minecraft.server.command.CommandManager;
import net.minecraft.server.command.ServerCommandSource;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.text.Text;
import net.minecraft.util.Formatting;

/**
 * SPRINT 3 movement debug commands.
 * Foundation for Sprint 4 diagnostics.
 */
public final class MovementCommands {
    private static boolean registered = false;

    private MovementCommands() {}

    public static void register() {
        if (registered) return;
        registered = true;
        // [AUTO-FIX] if (!FeatureFlags.movementV3) return;

        CommandRegistrationCallback.EVENT.register((dispatcher, registryAccess, environment) -> {
            registerCommands(dispatcher);
        });
    }

    private static void registerCommands(CommandDispatcher<ServerCommandSource> dispatcher) {
        dispatcher.register(CommandManager.literal("shinobicore")
                .then(CommandManager.literal("movement")
                        .requires(source -> source.hasPermissionLevel(2))
                        .then(CommandManager.literal("state")
                                .executes(ctx -> showState(ctx)))
                        .then(CommandManager.literal("reset")
                                .executes(ctx -> resetState(ctx)))
                )
        );
    }

    private static int showState(CommandContext<ServerCommandSource> ctx) {
        ServerPlayerEntity player = ctx.getSource().getPlayer();
        if (player == null) {
            ctx.getSource().sendError(Text.literal("Player required").formatted(Formatting.RED));
            return 0;
        }

        ServerChakraMirror.Data chakra = ServerChakraMirror.get(player.getUuid());

        ctx.getSource().sendFeedback(() -> Text.literal("=== Movement State ===").formatted(Formatting.GOLD), false);
        ctx.getSource().sendFeedback(() -> Text.literal("Chakra: " + chakra.current + " / " + chakra.max).formatted(Formatting.AQUA), false);
        ctx.getSource().sendFeedback(() -> Text.literal("Mode: " + (chakra.chakraMode ? "ON" : "OFF")).formatted(chakra.chakraMode ? Formatting.GREEN : Formatting.RED), false);
        ctx.getSource().sendFeedback(() -> Text.literal("Fatigue: " + chakra.fatigue).formatted(Formatting.WHITE), false);
        ctx.getSource().sendFeedback(() -> Text.literal("[SPRINT3] Movement foundation ready for Sprint 4").formatted(Formatting.GRAY), false);
        return 1;
    }

    private static int resetState(CommandContext<ServerCommandSource> ctx) {
        ServerPlayerEntity player = ctx.getSource().getPlayer();
        if (player == null) {
            ctx.getSource().sendError(Text.literal("Player required").formatted(Formatting.RED));
            return 0;
        }

        ServerChakraMirror.reset(player.getUuid());
        ctx.getSource().sendFeedback(() -> Text.literal("Movement state reset").formatted(Formatting.YELLOW), false);
        return 1;
    }
}