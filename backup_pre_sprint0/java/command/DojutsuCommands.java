package com.example.shinobicore.command;

import com.example.shinobicore.dojutsu.ByakuganManager;
import com.example.shinobicore.dojutsu.SharinganManager;
import com.example.shinobicore.stat.component.IDojutsuComponent;
import com.example.shinobicore.stat.component.NinjaComponents;
import com.mojang.brigadier.CommandDispatcher;
import com.mojang.brigadier.arguments.StringArgumentType;
import com.mojang.brigadier.context.CommandContext;
import net.minecraft.entity.LivingEntity;
import net.minecraft.server.command.CommandManager;
import net.minecraft.server.command.ServerCommandSource;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.text.Text;
import net.minecraft.util.math.Box;

import java.util.List;

/**
 * Dojutsu debug commands (HLD Section 7).
 * /dojutsu activate <sharingan|byakugan>, /dojutsu deactivate,
 * /dojutsu chronosphere, /test_dojutsu
 */
public class DojutsuCommands {

    public static void register(CommandDispatcher<ServerCommandSource> dispatcher) {
        dispatcher.register(CommandManager.literal("dojutsu")
            .requires(s -> s.hasPermissionLevel(2))
            .then(CommandManager.literal("activate")
                .then(CommandManager.argument("id", StringArgumentType.word())
                    .suggests((ctx, b) -> {
                        b.suggest("sharingan"); b.suggest("byakugan");
                        return b.buildFuture();
                    })
                    .executes(DojutsuCommands::activate)))
            .then(CommandManager.literal("deactivate").executes(DojutsuCommands::deactivate))
            .then(CommandManager.literal("chronosphere").executes(DojutsuCommands::chronosphere)));

        dispatcher.register(CommandManager.literal("test_dojutsu")
            .requires(s -> s.hasPermissionLevel(2))
            .executes(DojutsuCommands::test));
    }

    private static int activate(CommandContext<ServerCommandSource> ctx) {
        ServerPlayerEntity player = ctx.getSource().getPlayer();
        if (player == null) return 0;
        IDojutsuComponent comp = NinjaComponents.DOJUTSU.get(player);
        if (comp == null) return 0;
        String id = StringArgumentType.getString(ctx, "id");
        comp.activateDojutsu(id);
        player.sendMessage(Text.literal("Dojutsu activated: " + id), false);
        return 1;
    }

    private static int deactivate(CommandContext<ServerCommandSource> ctx) {
        ServerPlayerEntity player = ctx.getSource().getPlayer();
        if (player == null) return 0;
        IDojutsuComponent comp = NinjaComponents.DOJUTSU.get(player);
        if (comp == null) return 0;
        comp.deactivateDojutsu();
        player.sendMessage(Text.literal("Dojutsu deactivated"), false);
        return 1;
    }

    private static int chronosphere(CommandContext<ServerCommandSource> ctx) {
        ServerPlayerEntity player = ctx.getSource().getPlayer();
        if (player == null) return 0;
        LivingEntity target = findTarget(player);
        if (target == null) {
            player.sendMessage(Text.literal("No target nearby"), false);
            return 0;
        }
        SharinganManager.chronosphere(player, target);
        return 1;
    }

    private static int test(CommandContext<ServerCommandSource> ctx) {
        ServerPlayerEntity player = ctx.getSource().getPlayer();
        if (player == null) return 0;
        IDojutsuComponent comp = NinjaComponents.DOJUTSU.get(player);
        if (comp == null) return 0;

        msg(player, "=== Dojutsu Test ===", "6");
        comp.activateDojutsu(SharinganManager.ID);
        msg(player, "Active: " + comp.getActiveDojutsu(), "f");
        SharinganManager.addUsageAndEvolve(player, comp, null);
        msg(player, "Usage: " + comp.getUsage(SharinganManager.ID), "f");
        comp.deactivateDojutsu();
        msg(player, "Deactivated OK", "a");
        return 1;
    }

    private static LivingEntity findTarget(ServerPlayerEntity player) {
        Box box = player.getBoundingBox().expand(16.0);
        List<LivingEntity> list = player.getWorld().getEntitiesByClass(
            LivingEntity.class, box, e -> e != player);
        return list.isEmpty() ? null : list.get(0);
    }

    private static void msg(ServerPlayerEntity p, String m, String c) {
        p.sendMessage(Text.literal("\u00a7" + c + m), false);
    }
}