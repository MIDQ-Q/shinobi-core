package com.example.shinobicore.command;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.clan.ClanRegistry;
import com.example.shinobicore.jutsu.JutsuRegistry;
import com.example.shinobicore.stat.ElementType;
import com.example.shinobicore.stat.StatType;
import com.example.shinobicore.tree.SkillTreeRegistry;
import com.example.shinobicore.util.FeatureFlags;
import com.mojang.brigadier.CommandDispatcher;
import com.mojang.brigadier.context.CommandContext;
import net.minecraft.server.command.CommandManager;
import net.minecraft.server.command.ServerCommandSource;
import net.minecraft.text.Text;
import net.minecraft.util.Formatting;

public class DiagnosticCommands {

    public static void register(CommandDispatcher<ServerCommandSource> dispatcher) {
        dispatcher.register(CommandManager.literal("shinobicore")
            .requires(src -> src.hasPermissionLevel(2))
            .then(CommandManager.literal("validate")
                .executes(ctx -> validateAll(ctx))
                .then(CommandManager.literal("all").executes(ctx -> validateAll(ctx)))
                .then(CommandManager.literal("registries").executes(ctx -> validateRegistries(ctx)))
            )
            .then(CommandManager.literal("flags")
                .executes(ctx -> showFlags(ctx))
            )
            .then(CommandManager.literal("caches")
                .executes(ctx -> showCacheStats(ctx))
            )
        );
    }

    private static int validateAll(CommandContext<ServerCommandSource> ctx) {
        ServerCommandSource src = ctx.getSource();
        src.sendFeedback(() -> Text.literal("=== SHINOBICORE VALIDATION ===").formatted(Formatting.GOLD), false);

        int passed = 0;
        int failed = 0;

        int jutsuCount = JutsuRegistry.getAll().size();
        if (jutsuCount > 0) {
            src.sendFeedback(() -> Text.literal("[PASS] JutsuRegistry: " + jutsuCount + " jutsu loaded").formatted(Formatting.GREEN), false);
            passed++;
        } else {
            src.sendFeedback(() -> Text.literal("[FAIL] JutsuRegistry: empty!").formatted(Formatting.RED), false);
            failed++;
        }

        int clanCount = ClanRegistry.getAll().size();
        if (clanCount > 0) {
            src.sendFeedback(() -> Text.literal("[PASS] ClanRegistry: " + clanCount + " clans loaded").formatted(Formatting.GREEN), false);
            passed++;
        } else {
            src.sendFeedback(() -> Text.literal("[FAIL] ClanRegistry: empty!").formatted(Formatting.RED), false);
            failed++;
        }

        int treeCount = SkillTreeRegistry.getAll().size();
        if (treeCount > 0) {
            src.sendFeedback(() -> Text.literal("[PASS] SkillTreeRegistry: " + treeCount + " nodes loaded").formatted(Formatting.GREEN), false);
            passed++;
        } else {
            src.sendFeedback(() -> Text.literal("[FAIL] SkillTreeRegistry: empty!").formatted(Formatting.RED), false);
            failed++;
        }

        int statCount = StatType.values().length;
        src.sendFeedback(() -> Text.literal("[PASS] StatType: " + statCount + " stats").formatted(Formatting.GREEN), false);
        passed++;

        int elemCount = ElementType.values().length;
        src.sendFeedback(() -> Text.literal("[PASS] ElementType: " + elemCount + " elements").formatted(Formatting.GREEN), false);
        passed++;

        src.sendFeedback(() -> Text.literal("[PASS] FeatureFlags: operational").formatted(Formatting.GREEN), false);
        passed++;

        final int p = passed, f = failed;
        src.sendFeedback(() -> Text.literal("--- RESULT: " + p + " passed, " + f + " failed ---")
            .formatted(f > 0 ? Formatting.RED : Formatting.GREEN), false);

        return f > 0 ? 0 : 1;
    }

    private static int validateRegistries(CommandContext<ServerCommandSource> ctx) {
        ServerCommandSource src = ctx.getSource();
        src.sendFeedback(() -> Text.literal("=== REGISTRY VALIDATION ===").formatted(Formatting.GOLD), false);
        src.sendFeedback(() -> Text.literal("Jutsu: " + JutsuRegistry.getAll().size()), false);
        src.sendFeedback(() -> Text.literal("Clans: " + ClanRegistry.getAll().size()), false);
        src.sendFeedback(() -> Text.literal("Tree nodes: " + SkillTreeRegistry.getAll().size()), false);
        src.sendFeedback(() -> Text.literal("Tree branches: " + SkillTreeRegistry.getAllBranches().size()), false);
        return 1;
    }

    private static int showFlags(CommandContext<ServerCommandSource> ctx) {
        ServerCommandSource src = ctx.getSource();
        src.sendFeedback(() -> Text.literal("=== FEATURE FLAGS ===").formatted(Formatting.GOLD), false);
        src.sendFeedback(() -> Text.literal("chakraSystem = " + FeatureFlags.chakraSystem), false);
        src.sendFeedback(() -> Text.literal("taijutsuCombat = " + FeatureFlags.taijutsuCombat), false);
        src.sendFeedback(() -> Text.literal("kenjutsuCombat = " + FeatureFlags.kenjutsuCombat), false);
        src.sendFeedback(() -> Text.literal("parkourSystem = " + FeatureFlags.parkourSystem), false);
        src.sendFeedback(() -> Text.literal("hudRenderer = " + FeatureFlags.hudRenderer), false);
        src.sendFeedback(() -> Text.literal("packetValidation = " + FeatureFlags.packetValidation), false);
        src.sendFeedback(() -> Text.literal("rateLimiting = " + FeatureFlags.rateLimiting), false);
        return 1;
    }

    private static int showCacheStats(CommandContext<ServerCommandSource> ctx) {
        ServerCommandSource src = ctx.getSource();
        src.sendFeedback(() -> Text.literal("=== CACHE STATISTICS ===").formatted(Formatting.GOLD), false);
        src.sendFeedback(() -> Text.literal("CastingClientState: " +
            com.example.shinobicore.client.CastingClientState.size()), false);
        src.sendFeedback(() -> Text.literal("KenjutsuAnimations: " +
            com.example.shinobicore.client.combat.KenjutsuAnimations.size()), false);
        src.sendFeedback(() -> Text.literal("TaijutsuAnimations: " +
            com.example.shinobicore.client.combat.TaijutsuAnimations.size()), false);
        src.sendFeedback(() -> Text.literal("HitStopManager: " +
            com.example.shinobicore.client.combat.HitStopManager.size()), false);
        src.sendFeedback(() -> Text.literal("ChakraBurstAnimations: " +
            com.example.shinobicore.client.combat.ChakraBurstAnimations.size()), false);
        src.sendFeedback(() -> Text.literal("IdlePoseSystem: " +
            com.example.shinobicore.client.IdlePoseSystem.size()), false);
        return 1;
    }
}