package com.example.shinobicore.modules.progression.commands;

import com.example.shinobicore.modules.progression.component.ProgressionComponent;
import com.example.shinobicore.modules.progression.component.ProgressionComponentKey;
import com.example.shinobicore.modules.progression.network.ProgressionStateSyncPacket;
import com.example.shinobicore.modules.progression.service.AttunementService;
import com.example.shinobicore.modules.progression.service.BodyStatService;
import com.example.shinobicore.modules.progression.service.LevelService;
import com.example.shinobicore.modules.progression.service.ReputationService;
import com.example.shinobicore.modules.progression.service.SpService;
import com.example.shinobicore.modules.progression.service.StatService;
import com.example.shinobicore.modules.progression.service.XpSourceService;
import com.mojang.brigadier.CommandDispatcher;
import com.mojang.brigadier.arguments.IntegerArgumentType;
import com.mojang.brigadier.arguments.StringArgumentType;
import com.mojang.brigadier.context.CommandContext;
import net.minecraft.server.command.CommandManager;
import net.minecraft.server.command.ServerCommandSource;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.text.Text;
import net.minecraft.util.Formatting;

public final class ProgressionCommands {
    private ProgressionCommands() {}

    public static void register(CommandDispatcher<ServerCommandSource> dispatcher) {
        dispatcher.register(CommandManager.literal("shinobicore")
            .then(CommandManager.literal("progression")
                .then(CommandManager.literal("info").executes(ProgressionCommands::cmdInfo))
                .then(CommandManager.literal("statinfo").executes(ProgressionCommands::cmdStatInfo))
                .then(CommandManager.literal("addxp")
                    .requires(src -> src.hasPermissionLevel(2))
                    .then(CommandManager.argument("amount", IntegerArgumentType.integer(1))
                        .executes(ctx -> cmdAddXp(ctx, IntegerArgumentType.getInteger(ctx, "amount")))))
                .then(CommandManager.literal("addsp")
                    .requires(src -> src.hasPermissionLevel(2))
                    .then(CommandManager.argument("amount", IntegerArgumentType.integer(1))
                        .executes(ctx -> cmdAddSp(ctx, IntegerArgumentType.getInteger(ctx, "amount")))))
                .then(CommandManager.literal("setlevel")
                    .requires(src -> src.hasPermissionLevel(2))
                    .then(CommandManager.argument("level", IntegerArgumentType.integer(1))
                        .executes(ctx -> cmdSetLevel(ctx, IntegerArgumentType.getInteger(ctx, "level")))))
                .then(CommandManager.literal("setstat")
                    .requires(src -> src.hasPermissionLevel(2))
                    .then(CommandManager.argument("stat", StringArgumentType.word())
                        .then(CommandManager.argument("level", IntegerArgumentType.integer(0))
                            .executes(ctx -> cmdSetStat(ctx,
                                StringArgumentType.getString(ctx, "stat"),
                                IntegerArgumentType.getInteger(ctx, "level"))))))
                .then(CommandManager.literal("attune")
                    .requires(src -> src.hasPermissionLevel(2))
                    .then(CommandManager.argument("element", StringArgumentType.word())
                        .executes(ctx -> cmdAttune(ctx,
                            StringArgumentType.getString(ctx, "element")))))
                .then(CommandManager.literal("reputation")
                    .requires(src -> src.hasPermissionLevel(2))
                    .then(CommandManager.argument("faction", StringArgumentType.word())
                        .then(CommandManager.argument("amount", IntegerArgumentType.integer(-1000, 1000))
                            .executes(ctx -> cmdReputation(ctx,
                                StringArgumentType.getString(ctx, "faction"),
                                IntegerArgumentType.getInteger(ctx, "amount"))))))
                .then(CommandManager.literal("sync").executes(ProgressionCommands::cmdSync))
            )
        );
    }

    private static int cmdInfo(CommandContext<ServerCommandSource> ctx) {
        ServerPlayerEntity player = ctx.getSource().getPlayer();
        if (player == null) return 0;
        ProgressionComponentKey.get(player).ifPresent(comp -> {
            ctx.getSource().sendFeedback(() -> Text.literal("=== Progression ===").formatted(Formatting.GOLD), false);
            ctx.getSource().sendFeedback(() -> Text.literal("Level: " + comp.getPlayerLevel()), false);
            ctx.getSource().sendFeedback(() -> Text.literal("XP: " + comp.getCurrentXp()), false);
            ctx.getSource().sendFeedback(() -> Text.literal("SP: " + comp.getAvailableSp()), false);
            ctx.getSource().sendFeedback(() -> Text.literal("Nodes: " + comp.getUnlockedNodes().size()), false);
            ctx.getSource().sendFeedback(() -> Text.literal("Elements: " + comp.getUnlockedElements().size()), false);
            ctx.getSource().sendFeedback(() -> Text.literal("Reputations: " + comp.getAllReputation().size()), false);
        });
        return 1;
    }

    private static int cmdStatInfo(CommandContext<ServerCommandSource> ctx) {
        ServerPlayerEntity player = ctx.getSource().getPlayer();
        if (player == null) return 0;
        ProgressionComponentKey.get(player).ifPresent(comp -> {
            ctx.getSource().sendFeedback(() -> Text.literal("=== Primary Stats ===").formatted(Formatting.GOLD), false);
            for (String stat : StatService.PRIMARY_STATS) {
                int lvl = comp.getStatLevel(stat);
                ctx.getSource().sendFeedback(() -> Text.literal(stat + ": " + lvl), false);
            }
            ctx.getSource().sendFeedback(() -> Text.literal("=== Body Stats ===").formatted(Formatting.GOLD), false);
            for (String stat : BodyStatService.BODY_STATS) {
                int lvl = comp.getBodyStatLevel(stat);
                ctx.getSource().sendFeedback(() -> Text.literal(stat + ": " + lvl), false);
            }
        });
        return 1;
    }

    private static int cmdAddXp(CommandContext<ServerCommandSource> ctx, int amount) {
        ServerPlayerEntity player = ctx.getSource().getPlayer();
        if (player == null) return 0;
        XpSourceService.awardXp(player, amount, "command");
        ctx.getSource().sendFeedback(() -> Text.literal("Added " + amount + " XP").formatted(Formatting.GREEN), false);
        return 1;
    }

    private static int cmdAddSp(CommandContext<ServerCommandSource> ctx, int amount) {
        ServerPlayerEntity player = ctx.getSource().getPlayer();
        if (player == null) return 0;
        SpService.addSp(player, amount);
        ctx.getSource().sendFeedback(() -> Text.literal("Added " + amount + " SP").formatted(Formatting.GREEN), false);
        return 1;
    }

    private static int cmdSetLevel(CommandContext<ServerCommandSource> ctx, int level) {
        ServerPlayerEntity player = ctx.getSource().getPlayer();
        if (player == null) return 0;
        LevelService.setLevel(player, level);
        ctx.getSource().sendFeedback(() -> Text.literal("Level set to " + level).formatted(Formatting.GREEN), false);
        return 1;
    }

    private static int cmdSetStat(CommandContext<ServerCommandSource> ctx, String stat, int level) {
        ServerPlayerEntity player = ctx.getSource().getPlayer();
        if (player == null) return 0;
        if (StatService.isValidStat(stat)) {
            StatService.setStatLevel(player, stat, level);
        } else if (BodyStatService.isValidBodyStat(stat)) {
            BodyStatService.setBodyStatLevel(player, stat, level);
        } else {
            ctx.getSource().sendError(Text.literal("Unknown stat: " + stat));
            return 0;
        }
        ctx.getSource().sendFeedback(() -> Text.literal(stat + " set to " + level).formatted(Formatting.GREEN), false);
        return 1;
    }

    private static int cmdAttune(CommandContext<ServerCommandSource> ctx, String element) {
        ServerPlayerEntity player = ctx.getSource().getPlayer();
        if (player == null) return 0;
        boolean ok = AttunementService.attemptAttunement(player, element, true);
        if (ok) {
            ctx.getSource().sendFeedback(() -> Text.literal("Attuned: " + element).formatted(Formatting.GREEN), false);
        } else {
            ctx.getSource().sendError(Text.literal("Failed to attune: " + element));
        }
        return ok ? 1 : 0;
    }

    private static int cmdReputation(CommandContext<ServerCommandSource> ctx, String faction, int amount) {
        ServerPlayerEntity player = ctx.getSource().getPlayer();
        if (player == null) return 0;
        ReputationService.setReputation(player, faction, amount);
        ctx.getSource().sendFeedback(() -> Text.literal(faction + " rep set to " + amount).formatted(Formatting.GREEN), false);
        return 1;
    }

    private static int cmdSync(CommandContext<ServerCommandSource> ctx) {
        ServerPlayerEntity player = ctx.getSource().getPlayer();
        if (player == null) return 0;
        ProgressionStateSyncPacket.sendTo(player);
        ctx.getSource().sendFeedback(() -> Text.literal("State synced").formatted(Formatting.GREEN), false);
        return 1;
    }
}