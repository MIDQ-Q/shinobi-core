package com.example.shinobicore.command;

import com.example.shinobicore.jutsu.data.JutsuDefinition;
import com.example.shinobicore.jutsu.data.JutsuRegistry;
import com.example.shinobicore.stat.component.IJutsuComponent;
import com.example.shinobicore.stat.component.NinjaComponents;
import com.mojang.brigadier.CommandDispatcher;
import com.mojang.brigadier.arguments.StringArgumentType;
import com.mojang.brigadier.context.CommandContext;
import net.minecraft.server.command.CommandManager;
import net.minecraft.server.command.ServerCommandSource;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.text.Text;

import java.util.Set;

/**
 * Jutsu learning management commands.
 * /learn <id> | /learn all | /forget <id> | /myjutsus
 * HLD: Section 1.1 (JutsuComponent), Section 2
 */
public class LearnCommand {

    public static void register(CommandDispatcher<ServerCommandSource> dispatcher) {
        dispatcher.register(CommandManager.literal("learn")
            .requires(source -> source.hasPermissionLevel(2))
            .then(CommandManager.argument("id", StringArgumentType.greedyString())
                .suggests((ctx, builder) -> {
                    for (JutsuDefinition def : JutsuRegistry.getAll()) {
                        builder.suggest(def.id());
                    }
                    builder.suggest("all");
                    return builder.buildFuture();
                })
                .executes(LearnCommand::executeLearn)));

        dispatcher.register(CommandManager.literal("forget")
            .requires(source -> source.hasPermissionLevel(2))
            .then(CommandManager.argument("id", StringArgumentType.greedyString())
                .suggests((ctx, builder) -> {
                    ServerPlayerEntity player = ctx.getSource().getPlayer();
                    if (player != null) {
                        IJutsuComponent jutsu = NinjaComponents.getJutsu(player);
                        if (jutsu != null) {
                            for (String id : jutsu.getLearnedJutsus()) {
                                builder.suggest(id);
                            }
                        }
                    }
                    return builder.buildFuture();
                })
                .executes(LearnCommand::executeForget)));

        dispatcher.register(CommandManager.literal("myjutsus")
            .executes(LearnCommand::executeList));
    }

    private static int executeLearn(CommandContext<ServerCommandSource> ctx) {
        ServerPlayerEntity player = ctx.getSource().getPlayer();
        if (player == null) {
            ctx.getSource().sendError(Text.literal("Players only"));
            return 0;
        }

        String id = StringArgumentType.getString(ctx, "id").trim();
        IJutsuComponent jutsu = NinjaComponents.getJutsu(player);
        if (jutsu == null) {
            player.sendMessage(Text.literal("Components not available"), false);
            return 0;
        }

        if (id.equals("all")) {
            int count = 0;
            for (JutsuDefinition def : JutsuRegistry.getAll()) {
                if (jutsu.learnJutsu(def.id())) {
                    count++;
                }
            }
            player.sendMessage(Text.literal("Learned all jutsus (new: " + count + ")"), false);
            return 1;
        }

        JutsuDefinition def = JutsuRegistry.get(id);
        if (def == null) {
            player.sendMessage(Text.literal("Unknown jutsu: " + id), false);
            return 0;
        }

        if (jutsu.learnJutsu(id)) {
            player.sendMessage(Text.literal("Learned: " + def.name()), false);
        } else {
            player.sendMessage(Text.literal("Already learned: " + def.name()), false);
        }
        return 1;
    }

    private static int executeForget(CommandContext<ServerCommandSource> ctx) {
        ServerPlayerEntity player = ctx.getSource().getPlayer();
        if (player == null) {
            ctx.getSource().sendError(Text.literal("Players only"));
            return 0;
        }

        String id = StringArgumentType.getString(ctx, "id").trim();
        IJutsuComponent jutsu = NinjaComponents.getJutsu(player);
        if (jutsu == null) {
            player.sendMessage(Text.literal("Components not available"), false);
            return 0;
        }

        if (jutsu.hasLearned(id)) {
            jutsu.forgetJutsu(id);
            player.sendMessage(Text.literal("Forgot: " + id), false);
        } else {
            player.sendMessage(Text.literal("Not learned: " + id), false);
        }
        return 1;
    }

    private static int executeList(CommandContext<ServerCommandSource> ctx) {
        ServerPlayerEntity player = ctx.getSource().getPlayer();
        if (player == null) {
            ctx.getSource().sendError(Text.literal("Players only"));
            return 0;
        }

        IJutsuComponent jutsu = NinjaComponents.getJutsu(player);
        if (jutsu == null) {
            player.sendMessage(Text.literal("Components not available"), false);
            return 0;
        }

        Set<String> learned = jutsu.getLearnedJutsus();
        if (learned.isEmpty()) {
            player.sendMessage(Text.literal("No jutsu learned. Use /learn <id> or /learn all"), false);
            return 1;
        }

        player.sendMessage(Text.literal("Learned jutsus (" + learned.size() + "):"), false);
        for (String id : learned) {
            player.sendMessage(Text.literal("  - " + id), false);
        }
        return 1;
    }
}