package com.example.shinobicore.command;

import com.example.shinobicore.jutsu.JutsuCaster;
import com.example.shinobicore.jutsu.data.JutsuDefinition;
import com.example.shinobicore.jutsu.data.JutsuRegistry;
import com.mojang.brigadier.CommandDispatcher;
import com.mojang.brigadier.arguments.StringArgumentType;
import com.mojang.brigadier.context.CommandContext;
import net.minecraft.server.command.CommandManager;
import net.minecraft.server.command.ServerCommandSource;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.text.Text;

/**
 * Debug command: /cast <jutsu_id>
 * HLD: Section 2 (Sprint 1 deliverable 1.8)
 */
public class CastCommand {

    public static void register(CommandDispatcher<ServerCommandSource> dispatcher) {
        dispatcher.register(CommandManager.literal("cast")
            .requires(source -> source.hasPermissionLevel(2))
            .then(CommandManager.argument("id", StringArgumentType.greedyString())
                .suggests((ctx, builder) -> {
                    for (JutsuDefinition def : JutsuRegistry.getAll()) {
                        builder.suggest(def.id());
                    }
                    return builder.buildFuture();
                })
                .executes(CastCommand::execute)));
    }

    private static int execute(CommandContext<ServerCommandSource> ctx) {
        ServerPlayerEntity player = ctx.getSource().getPlayer();
        if (player == null) {
            ctx.getSource().sendError(Text.literal("Players only"));
            return 0;
        }
        String id = StringArgumentType.getString(ctx, "id");
        boolean ok = JutsuCaster.cast(player, id);
        return ok ? 1 : 0;
    }
}