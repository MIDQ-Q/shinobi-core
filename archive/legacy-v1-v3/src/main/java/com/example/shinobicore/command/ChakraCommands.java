// SHINOBICORE:SPRINT1:FILE
package com.example.shinobicore.command;

import com.example.shinobicore.chakra.server.ServerChakraMirror;
import com.example.shinobicore.config.FeatureFlags;
import com.example.shinobicore.config.MovementChakraConfig;
import com.mojang.brigadier.CommandDispatcher;
import com.mojang.brigadier.context.CommandContext;
import net.fabricmc.fabric.api.command.v2.CommandRegistrationCallback;
import com.mojang.brigadier.arguments.FloatArgumentType;
import net.minecraft.server.command.CommandManager;
import net.minecraft.server.command.ServerCommandSource;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.text.Text;
import net.minecraft.util.Formatting;

/**
 * SPRINT 1 chakra debug/foundation commands.
 *
 * Commands:
 * /shinobicore chakra info
 * /shinobicore chakra set <value>
 * /shinobicore chakra add <value>
 * /shinobicore chakra reset
 * /shinobicore chakra config reload
 */
public final class ChakraCommands {
    private static boolean registered = false;

    private ChakraCommands() {}

    public static void register() {
        if (registered) {
            return;
        }

        registered = true;

        if (!FeatureFlags.chakraCommands) {
            return;
        }

        CommandRegistrationCallback.EVENT.register((dispatcher, registryAccess, environment) -> {
            registerCommands(dispatcher);
        });
    }

    private static void registerCommands(CommandDispatcher<ServerCommandSource> dispatcher) {
        dispatcher.register(CommandManager.literal("shinobicore")
                .then(CommandManager.literal("chakra")
                        .requires(source -> source.hasPermissionLevel(2))
                        .then(CommandManager.literal("info")
                                .executes(ctx -> info(ctx)))
                        .then(CommandManager.literal("set")
                                .then(CommandManager.argument("value", FloatArgumentType.floatArg(0.0f, 1000000.0f))
                                        .executes(ctx -> set(ctx))))
                        .then(CommandManager.literal("add")
                                .then(CommandManager.argument("value", FloatArgumentType.floatArg(-1000000.0f, 1000000.0f))
                                        .executes(ctx -> add(ctx))))
                        .then(CommandManager.literal("reset")
                                .executes(ctx -> reset(ctx)))
                        .then(CommandManager.literal("config")
                                .then(CommandManager.literal("reload")
                                        .executes(ctx -> configReload(ctx))))
                )
        );
    }

    private static int info(CommandContext<ServerCommandSource> ctx) {
        ServerPlayerEntity player = ctx.getSource().getPlayer();

        if (player == null) {
            ctx.getSource().sendError(Text.literal("Player required").formatted(Formatting.RED));
            return 0;
        }

        ServerChakraMirror.Data data = ServerChakraMirror.get(player.getUuid());

        ctx.getSource().sendFeedback(() -> Text.literal(
                "Chakra: " + data.current + " / " + data.max +
                " | Fatigue: " + data.fatigue +
                " | Mode: " + (data.chakraMode ? "ON" : "OFF")
        ).formatted(Formatting.AQUA), false);

        return 1;
    }

    private static int set(CommandContext<ServerCommandSource> ctx) {
        ServerPlayerEntity player = ctx.getSource().getPlayer();

        if (player == null) {
            ctx.getSource().sendError(Text.literal("Player required").formatted(Formatting.RED));
            return 0;
        }

        float value = FloatArgumentType.getFloat(ctx, "value");
        ServerChakraMirror.set(player.getUuid(), value);

        ServerChakraMirror.Data data = ServerChakraMirror.get(player.getUuid());

        ctx.getSource().sendFeedback(() -> Text.literal(
                "Set chakra to " + data.current + " / " + data.max
        ).formatted(Formatting.GREEN), false);

        return 1;
    }

    private static int add(CommandContext<ServerCommandSource> ctx) {
        ServerPlayerEntity player = ctx.getSource().getPlayer();

        if (player == null) {
            ctx.getSource().sendError(Text.literal("Player required").formatted(Formatting.RED));
            return 0;
        }

        float value = FloatArgumentType.getFloat(ctx, "value");
        ServerChakraMirror.add(player.getUuid(), value);

        ServerChakraMirror.Data data = ServerChakraMirror.get(player.getUuid());

        ctx.getSource().sendFeedback(() -> Text.literal(
                "Added " + value + " chakra. Current: " + data.current + " / " + data.max
        ).formatted(Formatting.GREEN), false);

        return 1;
    }

    private static int reset(CommandContext<ServerCommandSource> ctx) {
        ServerPlayerEntity player = ctx.getSource().getPlayer();

        if (player == null) {
            ctx.getSource().sendError(Text.literal("Player required").formatted(Formatting.RED));
            return 0;
        }

        ServerChakraMirror.reset(player.getUuid());

        ctx.getSource().sendFeedback(() -> Text.literal(
                "Reset chakra mirror for " + player.getName().getString()
        ).formatted(Formatting.YELLOW), false);

        return 1;
    }

    private static int configReload(CommandContext<ServerCommandSource> ctx) {
        MovementChakraConfig.reload();

        ctx.getSource().sendFeedback(() -> Text.literal(
                "Movement/chakra config reloaded"
        ).formatted(Formatting.GREEN), false);

        return 1;
    }
}