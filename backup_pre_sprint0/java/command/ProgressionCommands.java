package com.example.shinobicore.command;

import com.example.shinobicore.progression.PlayerProgressionComponent;
import com.example.shinobicore.progression.ProgressionSystem;
import com.mojang.brigadier.CommandDispatcher;
import com.mojang.brigadier.arguments.IntegerArgumentType;
import com.mojang.brigadier.arguments.StringArgumentType;
import net.minecraft.server.command.CommandManager;
import net.minecraft.server.command.ServerCommandSource;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.text.Text;

/**
 * Debug/admin commands for the progression system.
 * HLD Section 10 (Progression System).
 */
public final class ProgressionCommands {

    private ProgressionCommands() {}

    public static void register(CommandDispatcher<ServerCommandSource> dispatcher) {
        dispatcher.register(CommandManager.literal("progression")
            .requires(src -> src.hasPermissionLevel(2))

            // /progression xp add <amount>
            .then(CommandManager.literal("xp")
                .then(CommandManager.literal("add")
                    .then(CommandManager.argument("amount", IntegerArgumentType.integer(1))
                        .executes(ctx -> addXP(ctx.getSource(), IntegerArgumentType.getInteger(ctx, "amount"))))))

            // /progression sp add <amount>
            .then(CommandManager.literal("sp")
                .then(CommandManager.literal("add")
                    .then(CommandManager.argument("amount", IntegerArgumentType.integer(1))
                        .executes(ctx -> addSP(ctx.getSource(), IntegerArgumentType.getInteger(ctx, "amount"))))))

            // /progression level set <level>
            .then(CommandManager.literal("level")
                .then(CommandManager.literal("set")
                    .then(CommandManager.argument("level", IntegerArgumentType.integer(1))
                        .executes(ctx -> setLevel(ctx.getSource(), IntegerArgumentType.getInteger(ctx, "level"))))))

            // /progression stat set <stat> <value>
            .then(CommandManager.literal("stat")
                .then(CommandManager.literal("set")
                    .then(CommandManager.argument("stat", StringArgumentType.word())
                        .then(CommandManager.argument("value", IntegerArgumentType.integer(0))
                            .executes(ctx -> setStat(
                                ctx.getSource(),
                                StringArgumentType.getString(ctx, "stat"),
                                IntegerArgumentType.getInteger(ctx, "value")))))))

            // /progression info
                        // /progression jutsu_prof <jutsuId>
            .then(CommandManager.literal("jutsu_prof")
                .then(CommandManager.argument("jutsuId", StringArgumentType.word())
                    .executes(ctx -> showJutsuProf(
                        ctx.getSource(),
                        StringArgumentType.getString(ctx, "jutsuId")))))
            .then(CommandManager.literal("info")
                .executes(ctx -> showInfo(ctx.getSource())))
        );
    }

    private static ServerPlayerEntity getPlayer(ServerCommandSource source) {
        return source.getPlayer();
    }

    private static int addXP(ServerCommandSource source, int amount) {
        ServerPlayerEntity player = getPlayer(source);
        if (player == null) {
            source.sendError(Text.literal("This command can only be used by players"));
            return 0;
        }
        ProgressionSystem.awardXP(player, amount);
        int newXp = ProgressionSystem.get(player).getXp();
        source.sendFeedback(() -> Text.literal("Added " + amount + " XP. Total: " + newXp), true);
        return 1;
    }

    private static int addSP(ServerCommandSource source, int amount) {
        ServerPlayerEntity player = getPlayer(source);
        if (player == null) {
            source.sendError(Text.literal("This command can only be used by players"));
            return 0;
        }
        PlayerProgressionComponent comp = ProgressionSystem.get(player);
        comp.addSP(amount);
        source.sendFeedback(() -> Text.literal("Added " + amount + " SP. Total: " + comp.getSP()), true);
        return 1;
    }

    private static int setLevel(ServerCommandSource source, int level) {
        ServerPlayerEntity player = getPlayer(source);
        if (player == null) {
            source.sendError(Text.literal("This command can only be used by players"));
            return 0;
        }
        PlayerProgressionComponent comp = ProgressionSystem.get(player);
        comp.setLevel(level);
        source.sendFeedback(() -> Text.literal("Level set to " + level), true);
        return 1;
    }

    private static int setStat(ServerCommandSource source, String stat, int value) {
        ServerPlayerEntity player = getPlayer(source);
        if (player == null) {
            source.sendError(Text.literal("This command can only be used by players"));
            return 0;
        }
        PlayerProgressionComponent comp = ProgressionSystem.get(player);
        comp.setStat(stat, value);
        source.sendFeedback(() -> Text.literal(stat + " set to " + value), true);
        return 1;
    }

    private static int showInfo(ServerCommandSource source) {
        ServerPlayerEntity player = getPlayer(source);
        if (player == null) {
            source.sendError(Text.literal("This command can only be used by players"));
            return 0;
        }
        PlayerProgressionComponent comp = ProgressionSystem.get(player);
        int level = comp.getLevel();
        int xp = comp.getXp();
        int sp = comp.getSP();
        int nextLevel = ProgressionSystem.xpForLevel(level);

        source.sendFeedback(() -> Text.literal("=== Progression Info ==="), false);
        source.sendFeedback(() -> Text.literal("Level: " + level), false);
        source.sendFeedback(() -> Text.literal("XP: " + xp + " / " + nextLevel), false);
        source.sendFeedback(() -> Text.literal("SP: " + sp), false);
        source.sendFeedback(() -> Text.literal("Ninjutsu: " + comp.getStat("ninjutsu")), false);
        source.sendFeedback(() -> Text.literal("Genjutsu: " + comp.getStat("genjutsu")), false);
        source.sendFeedback(() -> Text.literal("Taijutsu: " + comp.getStat("taijutsu")), false);
        source.sendFeedback(() -> Text.literal("Bukijutsu: " + comp.getStat("bukijutsu")), false);
        source.sendFeedback(() -> Text.literal("Chakra Control: " + comp.getStat("chakraControl")), false);
        return 1;
    }

    private static int showJutsuProf(ServerCommandSource source, String jutsuId) {
        ServerPlayerEntity player = getPlayer(source);
        if (player == null) {
            source.sendError(Text.literal("This command can only be used by players"));
            return 0;
        }
        PlayerProgressionComponent comp = ProgressionSystem.get(player);
        int prof = comp.getStat("prof:" + jutsuId);
        source.sendFeedback(() -> Text.literal("Proficiency for " + jutsuId + ": " + prof), false);
        return 1;
    }}