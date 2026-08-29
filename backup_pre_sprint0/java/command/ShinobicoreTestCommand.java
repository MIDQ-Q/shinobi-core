package com.example.shinobicore.command;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.clan.ClanDefinition;
import com.example.shinobicore.clan.ClanRegistry;
import com.example.shinobicore.clan.ClanReputation;
import com.example.shinobicore.dojutsu.DojutsuDefinition;
import com.example.shinobicore.dojutsu.DojutsuRegistry;
import com.example.shinobicore.entity.ModEntities;
import com.example.shinobicore.entity.enemy.NinjaEnemyEntity;
import com.example.shinobicore.entity.enemy.NinjaRank;
import com.example.shinobicore.jutsu.JutsuDefinition;
import com.example.shinobicore.jutsu.JutsuRegistry;
import com.example.shinobicore.stat.NinjaDataHolder;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.example.shinobicore.tree.SkillTreeNode;
import com.example.shinobicore.tree.SkillTreeRegistry;
import com.mojang.brigadier.CommandDispatcher;
import com.mojang.brigadier.arguments.StringArgumentType;
import com.mojang.brigadier.context.CommandContext;
import net.minecraft.command.argument.EntityArgumentType;
import net.minecraft.server.command.CommandManager;
import net.minecraft.server.command.ServerCommandSource;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.text.Text;
import net.minecraft.util.math.BlockPos;
import java.util.Collection;
import java.util.Map;

/**
 * S13-FINAL: Comprehensive test command for all systems.
 * Usage: /shinobicore_test [subcommand]
 */
public class ShinobicoreTestCommand {

    public static void register(CommandDispatcher<ServerCommandSource> dispatcher) {
        dispatcher.register(CommandManager.literal("shinobicore_test")
            .requires(source -> source.hasPermissionLevel(2))
            .then(CommandManager.literal("systems")
                .executes(ShinobicoreTestCommand::testAllSystems))
            .then(CommandManager.literal("balance")
                .executes(ShinobicoreTestCommand::testBalance))
            .then(CommandManager.literal("spawn")
                .then(CommandManager.argument("rank", StringArgumentType.word())
                    .suggests((ctx, builder) -> {
                        for (NinjaRank rank : NinjaRank.values()) {
                            builder.suggest(rank.getId());
                        }
                        return builder.buildFuture();
                    })
                    .executes(ShinobicoreTestCommand::spawnEnemy)))
            .then(CommandManager.literal("reputation")
                .then(CommandManager.argument("target", EntityArgumentType.players())
                    .executes(ShinobicoreTestCommand::showReputation)))
            .then(CommandManager.literal("reset_reputation")
                .executes(ShinobicoreTestCommand::resetReputation))
        );
    }

    private static int testAllSystems(CommandContext<ServerCommandSource> ctx) {
        ServerCommandSource source = ctx.getSource();
        ServerPlayerEntity player = source.getPlayer();

        sendTestHeader(player, "SHINOBICORE SYSTEM TEST");

        // Test 1: Jutsu Registry
        int jutsuCount = 0;
        try {
            for (JutsuDefinition def : JutsuRegistry.getAll()) {
                jutsuCount++;
            }
            sendTestResult(player, "Jutsu Registry", jutsuCount + " jutsu loaded", true);
        } catch (Exception e) {
            sendTestResult(player, "Jutsu Registry", "FAILED: " + e.getMessage(), false);
        }

        // Test 2: Clan Registry
        int clanCount = 0;
        try {
            for (ClanDefinition def : ClanRegistry.getAll()) {
                clanCount++;
            }
            sendTestResult(player, "Clan Registry", clanCount + " clans loaded", true);
        } catch (Exception e) {
            sendTestResult(player, "Clan Registry", "FAILED: " + e.getMessage(), false);
        }

        // Test 3: Skill Tree
        int nodeCount = 0;
        try {
            for (SkillTreeNode node : SkillTreeRegistry.getAll()) {
                nodeCount++;
            }
            sendTestResult(player, "Skill Tree", nodeCount + " nodes loaded", true);
        } catch (Exception e) {
            sendTestResult(player, "Skill Tree", "FAILED: " + e.getMessage(), false);
        }

        // Test 4: Dojutsu Registry
        int dojutsuCount = 0;
        try {
            for (DojutsuDefinition def : DojutsuRegistry.getAll()) {
                dojutsuCount++;
            }
            sendTestResult(player, "Dojutsu Registry", dojutsuCount + " dojutsu loaded", true);
        } catch (Exception e) {
            sendTestResult(player, "Dojutsu Registry", "FAILED: " + e.getMessage(), false);
        }

        // Test 5: Entity Registration
        try {
            sendTestResult(player, "Entity Registration", "NinjaEnemy: " + (ModEntities.NINJA_ENEMY != null), true);
        } catch (Exception e) {
            sendTestResult(player, "Entity Registration", "FAILED: " + e.getMessage(), false);
        }

        // Test 6: Player Data
        if (player != null) {
            try {
                NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
                String clanId = data.getClanId();
                int gate = data.getActiveGate();
                sendTestResult(player, "Player Data", "Clan: " + clanId + ", Gate: " + gate, true);
            } catch (Exception e) {
                sendTestResult(player, "Player Data", "FAILED: " + e.getMessage(), false);
            }
        }

        sendTestFooter(player);
        return 1;
    }

    private static int testBalance(CommandContext<ServerCommandSource> ctx) {
        ServerCommandSource source = ctx.getSource();
        ServerPlayerEntity player = source.getPlayer();

        sendTestHeader(player, "CLAN BALANCE TEST");

        for (ClanDefinition clan : ClanRegistry.getAll()) {
            String clanId = clan.id();
            Map<String, Float> bonuses = clan.bonuses();
            if (bonuses != null && !bonuses.isEmpty()) {
                StringBuilder sb = new StringBuilder();
                for (Map.Entry<String, Float> entry : bonuses.entrySet()) {
                    sb.append(entry.getKey()).append("=").append(String.format("%.2f", entry.getValue())).append(", ");
                }
                String bonusStr = sb.length() > 2 ? sb.substring(0, sb.length() - 2) : "none";
                sendTestResult(player, clanId, bonusStr, true);
            } else {
                sendTestResult(player, clanId, "NO BONUSES", false);
            }
        }

        sendTestFooter(player);
        return 1;
    }

    private static int spawnEnemy(CommandContext<ServerCommandSource> ctx) {
        ServerCommandSource source = ctx.getSource();
        ServerPlayerEntity player = source.getPlayer();
        String rankId = StringArgumentType.getString(ctx, "rank");

        if (player == null) {
            source.sendError(Text.literal("Player required"));
            return 0;
        }

        NinjaRank rank = null;
        for (NinjaRank r : NinjaRank.values()) {
            if (r.getId().equals(rankId)) {
                rank = r;
                break;
            }
        }

        if (rank == null) {
            source.sendError(Text.literal("Unknown rank: " + rankId));
            return 0;
        }

        ServerWorld world = (ServerWorld) player.getWorld();
        BlockPos pos = player.getBlockPos().add(3, 0, 3);

        NinjaEnemyEntity enemy = new NinjaEnemyEntity(ModEntities.NINJA_ENEMY, world);
        enemy.setRank(rank);
        enemy.setPosition(pos.getX() + 0.5, pos.getY(), pos.getZ() + 0.5);
        enemy.setTarget(player);
        world.spawnEntity(enemy);

        player.sendMessage(Text.literal("\u00a7aSpawned " + rank.getId() + " enemy at " + pos.toShortString()), false);
        return 1;
    }

    private static int showReputation(CommandContext<ServerCommandSource> ctx) {
        ServerCommandSource source = ctx.getSource();
        Collection<ServerPlayerEntity> targets;
        try {
            targets = EntityArgumentType.getPlayers(ctx, "target");
        } catch (com.mojang.brigadier.exceptions.CommandSyntaxException e) {
            source.sendError(Text.literal("Invalid target: " + e.getMessage()));
            return 0;
        }

        for (ServerPlayerEntity target : targets) {
            sendTestHeader(source.getPlayer(), "REPUTATION: " + target.getName().getString());
            Map<String, Integer> reps = ClanReputation.getAllReputations(target);
            for (Map.Entry<String, Integer> entry : reps.entrySet()) {
                String clanId = entry.getKey();
                int rep = entry.getValue();
                ClanReputation.Standing standing = ClanReputation.getStanding(target, clanId);
                String repStr = String.format("%d (%s)", rep, standing.getDisplayName());
                sendTestResult(source.getPlayer(), clanId, repStr, rep >= 0);
            }
            sendTestFooter(source.getPlayer());
        }

        return 1;
    }

    private static int resetReputation(CommandContext<ServerCommandSource> ctx) {
        ServerCommandSource source = ctx.getSource();
        ServerPlayerEntity player = source.getPlayer();

        if (player == null) {
            source.sendError(Text.literal("Player required"));
            return 0;
        }

        ClanReputation.resetAll(player);
        return 1;
    }

    private static void sendTestHeader(ServerPlayerEntity player, String title) {
        if (player == null) return;
        player.sendMessage(Text.literal(""), false);
        player.sendMessage(Text.literal("\u00a76\u2550".repeat(40)), false);
        player.sendMessage(Text.literal("\u00a7e\u2551 " + title + " \u00a7e\u2551"), false);
        player.sendMessage(Text.literal("\u00a76\u2550".repeat(40)), false);
    }

    private static void sendTestResult(ServerPlayerEntity player, String system, String result, boolean success) {
        if (player == null) return;
        String icon = success ? "\u00a7a\u2713" : "\u00a7c\u2717";
        player.sendMessage(Text.literal(icon + " \u00a77" + system + ": \u00a7f" + result), false);
    }

    private static void sendTestFooter(ServerPlayerEntity player) {
        if (player == null) return;
        player.sendMessage(Text.literal("\u00a76\u2550".repeat(40)), false);
        player.sendMessage(Text.literal(""), false);
    }
}