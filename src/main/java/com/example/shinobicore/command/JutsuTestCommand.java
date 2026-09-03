package com.example.shinobicore.command;

import com.example.shinobicore.jutsu.core.JutsuDefinition;
import com.example.shinobicore.jutsu.executor.JutsuCaster;
import com.example.shinobicore.jutsu.registry.JutsuRegistry;
import com.mojang.brigadier.CommandDispatcher;
import com.mojang.brigadier.arguments.StringArgumentType;
import net.minecraft.server.command.ServerCommandSource;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.text.Text;
import static net.minecraft.server.command.CommandManager.argument;
import static net.minecraft.server.command.CommandManager.literal;

public class JutsuTestCommand {

    public static void register(CommandDispatcher<ServerCommandSource> dispatcher) {
        // Brigadier automatically merges subcommands when registering the same root command
        dispatcher.register(
            literal("shinobicore")
                .then(literal("jutsu")
                    .then(literal("cast")
                        .then(argument("id", StringArgumentType.word())
                            .suggests((ctx, b) -> {
                                for (JutsuDefinition def : JutsuRegistry.getAll()) b.suggest(def.getId());
                                return b.buildFuture();
                            })
                            .executes(ctx -> {
                                ServerPlayerEntity p = ctx.getSource().getPlayer();
                                String rawId = StringArgumentType.getString(ctx, "id");
                                final String id = rawId.contains(":") ? rawId : "shinobicore:" + rawId;
                                JutsuDefinition def = JutsuRegistry.get(id);
                                if (def == null) {
                                    ctx.getSource().sendFeedback(() -> Text.literal("§cUnknown jutsu: " + id), false);
                                    return 0;
                                }
                                boolean ok = JutsuCaster.cast(p, def);
                                if (!ok) ctx.getSource().sendFeedback(() -> Text.literal("§cCast failed"), false);
                                return ok ? 1 : 0;
                            })))
                    .then(literal("list")
                        .executes(ctx -> {
                            StringBuilder sb = new StringBuilder("§e=== Jutsu v2 loaded: " + JutsuRegistry.size() + " ===\n");
                            for (JutsuDefinition def : JutsuRegistry.getAll()) {
                                sb.append("§7- §f").append(def.getId())
                                  .append(" §8[").append(def.getForm().getType().getId()).append("]\n");
                            }
                            ctx.getSource().sendFeedback(() -> Text.literal(sb.toString()), false);
                            return 1;
                        }))
                )
        );
    }
}