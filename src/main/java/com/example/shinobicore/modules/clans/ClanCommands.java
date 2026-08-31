package com.example.shinobicore.modules.clans;
import com.example.shinobicore.modules.clans.component.ClanComponentKey;
import com.example.shinobicore.modules.clans.config.ClansConfig;
import com.example.shinobicore.modules.clans.data.ClanDefinition;
import com.example.shinobicore.modules.clans.data.ClanRegistry;
import com.example.shinobicore.modules.clans.data.ClanJsonValidator;
import com.example.shinobicore.modules.clans.service.ClanService;
import com.example.shinobicore.modules.clans.service.ReputationService;
import com.mojang.brigadier.CommandDispatcher;
import com.mojang.brigadier.exceptions.CommandSyntaxException;
import com.mojang.brigadier.arguments.IntegerArgumentType;
import com.mojang.brigadier.arguments.StringArgumentType;
import com.mojang.brigadier.context.CommandContext;
import net.minecraft.command.argument.EntityArgumentType;
import net.minecraft.server.command.CommandManager;
import net.minecraft.server.command.ServerCommandSource;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.text.Text;
import net.minecraft.util.Formatting;
public final class ClanCommands {
    public static void register(CommandDispatcher<ServerCommandSource> dispatcher) {
        dispatcher.register(CommandManager.literal("shinobicore")
            .then(CommandManager.literal("clan")
                .then(CommandManager.literal("info").executes(ClanCommands::infoSelf)
                    .then(CommandManager.argument("target", EntityArgumentType.player()).requires(src -> src.hasPermissionLevel(2)).executes(ClanCommands::infoTarget)))
                .then(CommandManager.literal("list").executes(ClanCommands::list))
                .then(CommandManager.literal("set").requires(src -> src.hasPermissionLevel(2))
                    .then(CommandManager.argument("target", EntityArgumentType.player())
                        .then(CommandManager.argument("clanId", StringArgumentType.word()).executes(ClanCommands::setClan))))
                .then(CommandManager.literal("change").requires(src -> src.hasPermissionLevel(2))
                    .then(CommandManager.argument("target", EntityArgumentType.player())
                        .then(CommandManager.argument("clanId", StringArgumentType.word()).executes(ClanCommands::changeClan))))
                .then(CommandManager.literal("reputation")
                    .then(CommandManager.literal("info").executes(ClanCommands::repInfo))
                    .then(CommandManager.literal("set").requires(src -> src.hasPermissionLevel(2))
                        .then(CommandManager.argument("target", EntityArgumentType.player())
                            .then(CommandManager.argument("faction", StringArgumentType.word())
                                .then(CommandManager.argument("value", IntegerArgumentType.integer()).executes(ClanCommands::repSet)))))
                    .then(CommandManager.literal("add").requires(src -> src.hasPermissionLevel(2))
                        .then(CommandManager.argument("target", EntityArgumentType.player())
                            .then(CommandManager.argument("faction", StringArgumentType.word())
                                .then(CommandManager.argument("amount", IntegerArgumentType.integer()).executes(ClanCommands::repAdd))))))
                .then(CommandManager.literal("validate").requires(src -> src.hasPermissionLevel(2)).executes(ClanCommands::validate))
                .then(CommandManager.literal("sync").requires(src -> src.hasPermissionLevel(2)).executes(ClanCommands::sync))
                .then(CommandManager.literal("debug").requires(src -> src.hasPermissionLevel(2)).executes(ClanCommands::debug))
            )
        );
    }
    private static int infoSelf(CommandContext<ServerCommandSource> ctx) throws CommandSyntaxException { return showInfo(ctx, ctx.getSource().getPlayer()); }
    private static int infoTarget(CommandContext<ServerCommandSource> ctx) throws CommandSyntaxException { return showInfo(ctx, EntityArgumentType.getPlayer(ctx, "target")); }
    private static int showInfo(CommandContext<ServerCommandSource> ctx, ServerPlayerEntity player) {
        var comp = ClanComponentKey.get(player).orElse(null);
        if (comp == null || "none".equals(comp.getClanId())) {
            ctx.getSource().sendFeedback(() -> Text.literal("Player is not in a clan.").formatted(Formatting.GRAY), false); return 1;
        }
        ClanRegistry.get(comp.getClanId()).ifPresentOrElse(
            clan -> ctx.getSource().sendFeedback(() -> Text.literal("Clan: " + clan.name() + " [" + clan.affinity() + "]").formatted(Formatting.GOLD), false),
            () -> ctx.getSource().sendFeedback(() -> Text.literal("Error: clan data not found.").formatted(Formatting.RED), false)
        );
        return 1;
    }
    private static int list(CommandContext<ServerCommandSource> ctx) {
        ctx.getSource().sendFeedback(() -> Text.literal("=== Registered Clans ===").formatted(Formatting.GOLD), false);
        for (ClanDefinition clan : ClanRegistry.all()) {
            ctx.getSource().sendFeedback(() -> Text.literal("- " + clan.name() + " (ID: " + clan.id() + ")").formatted(Formatting.WHITE), false);
        }
        return 1;
    }
    private static int setClan(CommandContext<ServerCommandSource> ctx) throws CommandSyntaxException {
        ServerPlayerEntity target = EntityArgumentType.getPlayer(ctx, "target");
        String clanId = StringArgumentType.getString(ctx, "clanId");
        ClanService.setClan(target, clanId);
        ctx.getSource().sendFeedback(() -> Text.literal("Clan set: " + clanId).formatted(Formatting.GREEN), false);
        return 1;
    }
    private static int changeClan(CommandContext<ServerCommandSource> ctx) throws CommandSyntaxException {
        ServerPlayerEntity target = EntityArgumentType.getPlayer(ctx, "target");
        String clanId = StringArgumentType.getString(ctx, "clanId");
        boolean success = ClanService.changeClan(target, clanId);
        ctx.getSource().sendFeedback(() -> Text.literal(success ? "Clan changed: " + clanId : "Failed to change clan.").formatted(success ? Formatting.GREEN : Formatting.RED), false);
        return success ? 1 : 0;
    }
    private static int repInfo(CommandContext<ServerCommandSource> ctx) throws CommandSyntaxException {
        ServerPlayerEntity player = ctx.getSource().getPlayer();
        var comp = ClanComponentKey.get(player).orElse(null);
        if (comp == null || comp.getAllReputations().isEmpty()) {
            ctx.getSource().sendFeedback(() -> Text.literal("No reputation data.").formatted(Formatting.GRAY), false); return 1;
        }
        ctx.getSource().sendFeedback(() -> Text.literal("=== Reputation ===").formatted(Formatting.GOLD), false);
        for (var entry : comp.getAllReputations().entrySet()) {
            ctx.getSource().sendFeedback(() -> Text.literal("- " + entry.getKey() + ": " + entry.getValue()).formatted(Formatting.WHITE), false);
        }
        return 1;
    }
    private static int repSet(CommandContext<ServerCommandSource> ctx) throws CommandSyntaxException {
        ServerPlayerEntity target = EntityArgumentType.getPlayer(ctx, "target");
        String faction = StringArgumentType.getString(ctx, "faction");
        int value = IntegerArgumentType.getInteger(ctx, "value");
        ReputationService.addReputation(target, faction, value);
        ctx.getSource().sendFeedback(() -> Text.literal("Reputation " + faction + " set to " + value).formatted(Formatting.GREEN), false);
        return 1;
    }
    private static int repAdd(CommandContext<ServerCommandSource> ctx) throws CommandSyntaxException {
        ServerPlayerEntity target = EntityArgumentType.getPlayer(ctx, "target");
        String faction = StringArgumentType.getString(ctx, "faction");
        int amount = IntegerArgumentType.getInteger(ctx, "amount");
        ReputationService.addReputation(target, faction, amount);
        ctx.getSource().sendFeedback(() -> Text.literal("Added " + amount + " to " + faction).formatted(Formatting.GREEN), false);
        return 1;
    }
    private static int validate(CommandContext<ServerCommandSource> ctx) {
        ClanJsonValidator.validateAll();
        ctx.getSource().sendFeedback(() -> Text.literal("Validation complete. Check logs/shinobicore/clans-1.log").formatted(Formatting.GREEN), false);
        return 1;
    }
    private static int sync(CommandContext<ServerCommandSource> ctx) throws CommandSyntaxException {
        ServerPlayerEntity target = ctx.getSource().getPlayer();
        ClanService.syncToClient(target);
        ctx.getSource().sendFeedback(() -> Text.literal("State synced to client.").formatted(Formatting.GREEN), false);
        return 1;
    }
    private static int debug(CommandContext<ServerCommandSource> ctx) {
        ClansConfig.DEBUG = !ClansConfig.DEBUG;
        ctx.getSource().sendFeedback(() -> Text.literal("Debug mode: " + ClansConfig.DEBUG).formatted(Formatting.YELLOW), false);
        return 1;
    }
}