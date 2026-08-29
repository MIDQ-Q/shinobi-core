package com.example.shinobicore.command;

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
 * Debug command: grants stats, learns all jutsu, refills chakra.
 * Usage: /devshinobi
 * HLD: Section 1.1 (debug tooling for manual testing)
 */
public class DevCommand {

    private static final int DEV_STAT_LEVEL = 50;

    public static void register(CommandDispatcher<ServerCommandSource> dispatcher) {
        dispatcher.register(CommandManager.literal("devshinobi")
            .requires(source -> source.hasPermissionLevel(2))
            .executes(DevCommand::execute));
    }

    private static int execute(CommandContext<ServerCommandSource> ctx) {
        ServerPlayerEntity player = ctx.getSource().getPlayer();
        if (player == null) {
            ctx.getSource().sendError(Text.literal("Players only"));
            return 0;
        }

        IStatsComponent stats = NinjaComponents.getStats(player);
        IJutsuComponent jutsu = NinjaComponents.getJutsu(player);
        IChakraComponent chakra = NinjaComponents.getChakra(player);

        if (stats == null || jutsu == null || chakra == null) {
            player.sendMessage(Text.literal("Components not available"), false);
            return 0;
        }

        for (StatType type : StatType.values()) {
            stats.setStatLevel(type, DEV_STAT_LEVEL);
        }

        int learned = 0;
        for (JutsuDefinition def : JutsuRegistry.getAll()) {
            if (jutsu.learnJutsu(def.id())) {
                learned++;
            }
        }

        chakra.resetToDefaults();

        player.sendMessage(Text.literal(
            "Dev mode ON: all stats=" + DEV_STAT_LEVEL
            + ", learned " + learned + " jutsus, chakra full"), false);
        return 1;
    }
}