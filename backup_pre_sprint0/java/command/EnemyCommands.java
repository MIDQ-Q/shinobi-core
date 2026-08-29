package com.example.shinobicore.command;

import com.example.shinobicore.entity.ModEntities;
import com.example.shinobicore.entity.enemy.NinjaEnemyEntity;
import com.example.shinobicore.entity.enemy.NinjaRank;
import com.example.shinobicore.world.ShinobiWorldState;
import com.mojang.brigadier.CommandDispatcher;
import com.mojang.brigadier.arguments.StringArgumentType;
import com.mojang.brigadier.context.CommandContext;
import net.minecraft.server.command.CommandManager;
import net.minecraft.server.command.ServerCommandSource;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.text.Text;

/**
 * Enemy debug commands (HLD Section 5).
 * /spawn_enemy [rank] and /test_ai.
 */
public class EnemyCommands {

    public static void register(CommandDispatcher<ServerCommandSource> dispatcher) {
        dispatcher.register(CommandManager.literal("spawn_enemy")
            .requires(source -> source.hasPermissionLevel(2))
            .executes(ctx -> spawn(ctx, "genin"))
            .then(CommandManager.argument("rank", StringArgumentType.word())
                .suggests((ctx, builder) -> {
                    for (NinjaRank r : NinjaRank.values()) {
                        builder.suggest(r.getId());
                    }
                    return builder.buildFuture();
                })
                .executes(ctx -> spawn(ctx,
                    StringArgumentType.getString(ctx, "rank")))));

        dispatcher.register(CommandManager.literal("test_ai")
            .requires(source -> source.hasPermissionLevel(2))
            .executes(EnemyCommands::testAi));
    }

    private static int spawn(CommandContext<ServerCommandSource> ctx, String rankId) {
        ServerPlayerEntity player = ctx.getSource().getPlayer();
        if (player == null) {
            ctx.getSource().sendError(Text.literal("Players only"));
            return 0;
        }

        ServerWorld world = player.getServerWorld();
        NinjaEnemyEntity enemy = ModEntities.NINJA_ENEMY.create(world);
        if (enemy == null) {
            player.sendMessage(Text.literal("Failed to create enemy"), false);
            return 0;
        }

        enemy.setPosition(player.getPos().add(3.0, 0.0, 3.0));
        enemy.setRankId(rankId);
        world.spawnEntity(enemy);
        ShinobiWorldState.get(player.getServer()).addSpawn();

        player.sendMessage(Text.literal("Spawned " + enemy.getRank().getId()
            + " enemy (state: " + enemy.getController().getState() + ")"), false);
        return 1;
    }

    private static int testAi(CommandContext<ServerCommandSource> ctx) {
        ServerPlayerEntity player = ctx.getSource().getPlayer();
        if (player == null) {
            ctx.getSource().sendError(Text.literal("Players only"));
            return 0;
        }

        ServerWorld world = player.getServerWorld();
        ShinobiWorldState state = ShinobiWorldState.get(player.getServer());

        msg(player, "=== AI & Persistence Test ===", "6");

        NinjaRank[] ranks = { NinjaRank.GENIN, NinjaRank.CHUNIN, NinjaRank.JONIN };
        int spawned = 0;
        for (int i = 0; i < ranks.length; i++) {
            NinjaEnemyEntity enemy = ModEntities.NINJA_ENEMY.create(world);
            if (enemy == null) {
                continue;
            }
            enemy.setPosition(player.getPos().add(4.0 + i * 2.0, 0.0, 4.0));
            enemy.setRankId(ranks[i].getId());
            world.spawnEntity(enemy);
            state.addSpawn();
            spawned++;
        }

        msg(player, "Spawned " + spawned + " enemies (genin/chunin/jonin)", "a");
        msg(player, "World state: totalSpawned=" + state.getTotalSpawned(), "f");
        msg(player, "Kills: genin=" + state.getKills("genin")
            + " chunin=" + state.getKills("chunin")
            + " jonin=" + state.getKills("jonin"), "f");
        msg(player, "Fight them! Kill counts persist across reloads.", "b");
        return 1;
    }

    private static void msg(ServerPlayerEntity player, String message, String colorCode) {
        player.sendMessage(Text.literal("\u00a7" + colorCode + message), false);
    }
}