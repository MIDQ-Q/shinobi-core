package com.example.shinobicore.command;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.jutsu.JutsuCaster;
import com.example.shinobicore.jutsu.data.JutsuDefinition;
import com.example.shinobicore.jutsu.data.JutsuRegistry;
import com.example.shinobicore.stat.StatType;
import com.example.shinobicore.stat.component.IChakraComponent;
import com.example.shinobicore.stat.component.IJutsuComponent;
import com.example.shinobicore.stat.component.IStatsComponent;
import com.example.shinobicore.stat.component.NinjaComponents;
import com.mojang.brigadier.CommandDispatcher;
import com.mojang.brigadier.context.CommandContext;
import net.minecraft.server.command.CommandManager;
import net.minecraft.server.command.ServerCommandSource;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.text.Text;

/**
 * Debug command: /test_jutsu_engine
 * HLD: Section 2 (Sprint 1 deliverable 1.9)
 * NOTE: Fail-Safe. Any exception is caught, logged and shown in chat.
 */
public class TestJutsuCommand {

    public static void register(CommandDispatcher<ServerCommandSource> dispatcher) {
        dispatcher.register(CommandManager.literal("test_jutsu_engine")
            .requires(source -> source.hasPermissionLevel(2))
            .executes(TestJutsuCommand::execute));
    }

    private static int execute(CommandContext<ServerCommandSource> ctx) {
        ServerPlayerEntity player = ctx.getSource().getPlayer();
        if (player == null) {
            ctx.getSource().sendError(Text.literal("Players only"));
            return 0;
        }

        msg(player, "=== Jutsu Engine Tests ===", "6");

        try {
            return runTests(player);
        } catch (Exception e) {
            ShinobiCore.LOGGER.error("[TestJutsu] Unexpected error", e);
            msg(player, "[FAIL] " + e.getClass().getSimpleName() + ": " + e.getMessage(), "c");
            return 0;
        }
    }

    private static int runTests(ServerPlayerEntity player) {
        if (JutsuRegistry.size() == 0) {
            msg(player, "[FAIL] JutsuRegistry is empty", "c");
            return 0;
        }
        msg(player, "[PASS] Registry loaded " + JutsuRegistry.size() + " jutsus", "a");

        JutsuDefinition fireball = JutsuRegistry.get("shinobicore:fireball");
        if (fireball == null || Math.abs(fireball.baseCost() - 30.0f) > 0.01f) {
            msg(player, "[FAIL] JSON parsing error (fireball)", "c");
            return 0;
        }
        msg(player, "[PASS] JSON parsing (fireball cost=30)", "a");

        IChakraComponent chakra = NinjaComponents.getChakra(player);
        IStatsComponent stats = NinjaComponents.getStats(player);
        IJutsuComponent jutsu = NinjaComponents.getJutsu(player);
        if (chakra == null || stats == null || jutsu == null) {
            msg(player, "[FAIL] Components missing", "c");
            return 0;
        }

        stats.setStatLevel(StatType.CONTROL, 20);
        stats.setStatLevel(StatType.NATURE_FIRE, 20);
        stats.setStatLevel(StatType.NINJUTSU, 20);
        jutsu.learnJutsu("shinobicore:fireball");

        chakra.setCurrentChakra(100.0f);
        boolean cast = JutsuCaster.cast(player, "shinobicore:fireball");
        if (!cast) {
            msg(player, "[FAIL] Cast rejected (see chat/log for reason)", "c");
            return 0;
        }
        if (chakra.getCurrentChakra() >= 100.0f) {
            msg(player, "[FAIL] Chakra was not deducted", "c");
            return 0;
        }
        msg(player, "[PASS] Cast + chakra deduction (now "
            + chakra.getCurrentChakra() + ")", "a");

        chakra.resetToDefaults();
        stats.resetToDefaults();
        jutsu.resetAll();

        msg(player, "All Jutsu Engine tests passed!", "a");
        return 1;
    }

    private static void msg(ServerPlayerEntity player, String message, String colorCode) {
        player.sendMessage(Text.literal("\u00a7" + colorCode + message), false);
    }
}