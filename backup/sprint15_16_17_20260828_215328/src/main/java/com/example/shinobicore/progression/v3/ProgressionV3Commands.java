// SHINOBICORE:SPRINT13:FILE
package com.example.shinobicore.progression.v3;

import com.mojang.brigadier.CommandDispatcher;
import com.mojang.brigadier.arguments.IntegerArgumentType;
import com.mojang.brigadier.arguments.StringArgumentType;
import com.mojang.brigadier.context.CommandContext;
import net.fabricmc.fabric.api.command.v2.CommandRegistrationCallback;
import net.minecraft.server.command.CommandManager;
import net.minecraft.server.command.ServerCommandSource;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.text.Text;
import net.minecraft.util.Formatting;

/**
 * SPRINT 13 progression debug commands.
 *
 * Commands:
 * /shinobicore progressionv3 info
 * /shinobicore progressionv3 addxp <amount>
 * /shinobicore progressionv3 addsp <amount>
 * /shinobicore progressionv3 statxp <stat> <amount>
 * /shinobicore progressionv3 reset
 */
public final class ProgressionV3Commands {
    private static boolean registered = false;

    private ProgressionV3Commands() {}

    public static void register() {
        if (registered) {
            return;
        }

        registered = true;

        CommandRegistrationCallback.EVENT.register((dispatcher, registryAccess, environment) -> {
            registerCommands(dispatcher);
        });
    }

    private static void registerCommands(CommandDispatcher<ServerCommandSource> dispatcher) {
        dispatcher.register(CommandManager.literal("shinobicore")
                .then(CommandManager.literal("progressionv3")
                        .requires(source -> source.hasPermissionLevel(2))
                        .then(CommandManager.literal("info")
                                .executes(ctx -> info(ctx)))
                        .then(CommandManager.literal("addxp")
                                .then(CommandManager.argument("amount", IntegerArgumentType.integer(0, 1000000))
                                        .executes(ctx -> addXp(ctx))))
                        .then(CommandManager.literal("addsp")
                                .then(CommandManager.argument("amount", IntegerArgumentType.integer(0, 100000))
                                        .executes(ctx -> addSp(ctx))))
                        .then(CommandManager.literal("statxp")
                                .then(CommandManager.argument("stat", StringArgumentType.word())
                                        .then(CommandManager.argument("amount", IntegerArgumentType.integer(0, 1000000))
                                                .executes(ctx -> addStatXp(ctx)))))
                        .then(CommandManager.literal("reset")
                                .executes(ctx -> reset(ctx)))
                )
        );
    }

    private static int info(CommandContext<ServerCommandSource> ctx) {
        ServerPlayerEntity player = ctx.getSource().getPlayer();

        if (player == null) {
            ctx.getSource().sendError(Text.literal("Player required").formatted(Formatting.RED));
            return 0;
        }

        ProgressionV3.Data data = ProgressionV3.get(player.getUuid());

        ctx.getSource().sendFeedback(() -> Text.literal("=== Progression V3 ===").formatted(Formatting.GOLD), false);
        ctx.getSource().sendFeedback(() -> Text.literal(
                "Level: " + data.level +
                " | XP: " + data.xp +
                " | Next: " + ProgressionV3.getXpForNextLevel(data.level) +
                " | SP: " + data.sp
        ).formatted(Formatting.AQUA), false);

        return 1;
    }

    private static int addXp(CommandContext<ServerCommandSource> ctx) {
        ServerPlayerEntity player = ctx.getSource().getPlayer();

        if (player == null) {
            ctx.getSource().sendError(Text.literal("Player required").formatted(Formatting.RED));
            return 0;
        }

        int amount = IntegerArgumentType.getInteger(ctx, "amount");
        ProgressionV3.addXp(player.getUuid(), amount);

        ctx.getSource().sendFeedback(() -> Text.literal("Added " + amount + " XP").formatted(Formatting.GREEN), false);

        return 1;
    }

    private static int addSp(CommandContext<ServerCommandSource> ctx) {
        ServerPlayerEntity player = ctx.getSource().getPlayer();

        if (player == null) {
            ctx.getSource().sendError(Text.literal("Player required").formatted(Formatting.RED));
            return 0;
        }

        int amount = IntegerArgumentType.getInteger(ctx, "amount");
        ProgressionV3.addSp(player.getUuid(), amount);

        ctx.getSource().sendFeedback(() -> Text.literal("Added " + amount + " SP").formatted(Formatting.GREEN), false);

        return 1;
    }

    private static int addStatXp(CommandContext<ServerCommandSource> ctx) {
        ServerPlayerEntity player = ctx.getSource().getPlayer();

        if (player == null) {
            ctx.getSource().sendError(Text.literal("Player required").formatted(Formatting.RED));
            return 0;
        }

        String stat = StringArgumentType.getString(ctx, "stat");
        int amount = IntegerArgumentType.getInteger(ctx, "amount");

        ProgressionV3.addStatXp(player.getUuid(), stat, amount);

        ctx.getSource().sendFeedback(() -> Text.literal(
                "Added " + amount + " XP to stat: " + stat
        ).formatted(Formatting.GREEN), false);

        return 1;
    }

    private static int reset(CommandContext<ServerCommandSource> ctx) {
        ServerPlayerEntity player = ctx.getSource().getPlayer();

        if (player == null) {
            ctx.getSource().sendError(Text.literal("Player required").formatted(Formatting.RED));
            return 0;
        }

        ProgressionV3.reset(player.getUuid());

        ctx.getSource().sendFeedback(() -> Text.literal("Progression V3 reset").formatted(Formatting.YELLOW), false);

        return 1;
    }
}