package com.example.shinobicore.modules.jutsu.command;

import com.example.shinobicore.core.log.ShinobiLogger;
import com.example.shinobicore.modules.jutsu.cast.JutsuCastService;
import com.example.shinobicore.modules.jutsu.data.JutsuDefinition;
import com.example.shinobicore.modules.jutsu.data.JutsuJsonValidator;
import com.example.shinobicore.modules.jutsu.data.JutsuLoader;
import com.example.shinobicore.modules.jutsu.data.JutsuRegistry;
import com.example.shinobicore.modules.jutsu.slot.JutsuSlotService;
import com.mojang.brigadier.CommandDispatcher;
import com.mojang.brigadier.arguments.IntegerArgumentType;
import com.mojang.brigadier.arguments.StringArgumentType;
import com.mojang.brigadier.context.CommandContext;
import net.minecraft.server.command.CommandManager;
import net.minecraft.server.command.ServerCommandSource;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.text.Text;
import net.minecraft.util.Formatting;

public final class JutsuCommands {
    public static void register(CommandDispatcher<ServerCommandSource> dispatcher) {
        dispatcher.register(CommandManager.literal("shinobicore")
            .then(CommandManager.literal("jutsu").requires(src -> src.hasPermissionLevel(2))
                .then(CommandManager.literal("list").executes(JutsuCommands::cmdList))
                .then(CommandManager.literal("info").then(CommandManager.argument("id", StringArgumentType.string()).executes(JutsuCommands::cmdInfo)))
                .then(CommandManager.literal("select").then(CommandManager.argument("slot", IntegerArgumentType.integer(0, 2)).executes(JutsuCommands::cmdSelect)))
                .then(CommandManager.literal("assign").then(CommandManager.argument("slot", IntegerArgumentType.integer(0, 2))
                    .then(CommandManager.argument("id", StringArgumentType.string()).executes(JutsuCommands::cmdAssign))))
                .then(CommandManager.literal("cast").then(CommandManager.argument("slot", IntegerArgumentType.integer(0, 2)).executes(JutsuCommands::cmdCast)))
                .then(CommandManager.literal("validate").executes(JutsuCommands::cmdValidate))
                .then(CommandManager.literal("reload").executes(JutsuCommands::cmdReload))
            )
        );
    }

    private static int cmdList(CommandContext<ServerCommandSource> ctx) {
        ServerCommandSource src = ctx.getSource();
        src.sendFeedback(() -> Text.literal("=== Registered Jutsu ===").formatted(Formatting.GOLD), false);
        for (JutsuDefinition def : JutsuRegistry.all()) {
            src.sendFeedback(() -> Text.literal("- " + def.id() + " (" + def.behaviorId() + ")").formatted(Formatting.WHITE), false);
        }
        return 1;
    }

    private static int cmdInfo(CommandContext<ServerCommandSource> ctx) {
        String id = StringArgumentType.getString(ctx, "id");
        JutsuRegistry.get(id).ifPresentOrElse(def -> {
            ctx.getSource().sendFeedback(() -> Text.literal("Jutsu: " + def.name() + " | Cost: " + def.baseCost() + " | CD: " + def.cooldownTicks()).formatted(Formatting.AQUA), false);
        }, () -> {
            ctx.getSource().sendError(Text.literal("Jutsu not found: " + id));
        });
        return 1;
    }

    private static int cmdSelect(CommandContext<ServerCommandSource> ctx) {
        ServerPlayerEntity player = ctx.getSource().getPlayer();
        if (player == null) return 0;
        int slot = IntegerArgumentType.getInteger(ctx, "slot");
        JutsuSlotService.selectSlot(player, slot);
        ctx.getSource().sendFeedback(() -> Text.literal("Selected slot " + slot).formatted(Formatting.GREEN), false);
        return 1;
    }

    private static int cmdAssign(CommandContext<ServerCommandSource> ctx) {
        ServerPlayerEntity player = ctx.getSource().getPlayer();
        if (player == null) return 0;
        int slot = IntegerArgumentType.getInteger(ctx, "slot");
        String id = StringArgumentType.getString(ctx, "id");
        boolean success = JutsuSlotService.assignJutsu(player, slot, id);
        if (success) {
            ctx.getSource().sendFeedback(() -> Text.literal("Assigned " + id + " to slot " + slot).formatted(Formatting.GREEN), false);
        } else {
            ctx.getSource().sendError(Text.literal("Failed to assign jutsu. Check logs."));
        }
        return success ? 1 : 0;
        }

    private static int cmdCast(CommandContext<ServerCommandSource> ctx) {
        ServerPlayerEntity player = ctx.getSource().getPlayer();
        if (player == null) return 0;
        int slot = IntegerArgumentType.getInteger(ctx, "slot");
        String id = JutsuSlotService.getLoadout(player).getSlot(slot);
        if (id != null) {
            JutsuCastService.instance().requestCast(player, id, slot, System.currentTimeMillis(), player.getYaw(), player.getPitch());
            ctx.getSource().sendFeedback(() -> Text.literal("Force casting " + id).formatted(Formatting.YELLOW), false);
        }
        return 1;
    }

    private static int cmdValidate(CommandContext<ServerCommandSource> ctx) {
        JutsuJsonValidator.validateAll();
        ctx.getSource().sendFeedback(() -> Text.literal("Validation complete. Check logs/shinobicore/jutsu-1.log").formatted(Formatting.AQUA), false);
        return 1;
    }

    private static int cmdReload(CommandContext<ServerCommandSource> ctx) {
        JutsuLoader.load();
        JutsuJsonValidator.validateAll();
        ctx.getSource().sendFeedback(() -> Text.literal("Jutsu definitions reloaded.").formatted(Formatting.GREEN), false);
        return 1;
    }
}