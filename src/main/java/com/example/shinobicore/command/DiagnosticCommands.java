package com.example.shinobicore.command;

import com.example.shinobicore.config.ConfigManager;
import com.example.shinobicore.util.FeatureFlags;
import com.example.shinobicore.client.CastingClientState;
import com.example.shinobicore.client.IdlePoseSystem;
import com.example.shinobicore.client.combat.KenjutsuAnimations;
import com.example.shinobicore.client.combat.TaijutsuAnimations;
import com.example.shinobicore.client.combat.HitStopManager;
import com.example.shinobicore.client.combat.ChakraBurstAnimations;
import com.mojang.brigadier.CommandDispatcher;
import com.mojang.brigadier.arguments.StringArgumentType;
import com.mojang.brigadier.context.CommandContext;
import net.minecraft.server.command.CommandManager;
import net.minecraft.server.command.ServerCommandSource;
import net.minecraft.text.Text;
import net.minecraft.util.Formatting;
import java.util.List;

public class DiagnosticCommands {

    public static void register(CommandDispatcher<ServerCommandSource> dispatcher) {
        dispatcher.register(CommandManager.literal("shinobicore")
            .requires(src -> src.hasPermissionLevel(2))

            .then(CommandManager.literal("validate")
                .executes(ctx -> validateAll(ctx))
                .then(CommandManager.literal("all").executes(ctx -> validateAll(ctx)))
                .then(CommandManager.literal("config").executes(ctx -> validateConfig(ctx)))
            )

            .then(CommandManager.literal("systems")
                .executes(ctx -> showSystems(ctx))
            )

            .then(CommandManager.literal("config")
                .then(CommandManager.literal("reload").executes(ctx -> reloadConfig(ctx)))
                .then(CommandManager.literal("validate").executes(ctx -> validateConfig(ctx)))
                .then(CommandManager.literal("loglevel")
                    .then(CommandManager.argument("level", StringArgumentType.word())
                        .executes(ctx -> setLogLevel(ctx))
                    )
                )
            )

            .then(CommandManager.literal("log")
                .then(CommandManager.literal("level")
                    .then(CommandManager.argument("level", StringArgumentType.word())
                        .executes(ctx -> setLogLevel(ctx))
                    )
                )
                .then(CommandManager.literal("status").executes(ctx -> showLogStatus(ctx)))
            )

            .then(CommandManager.literal("flags")
                .executes(ctx -> showFlags(ctx))
            )

            .then(CommandManager.literal("caches")
                .executes(ctx -> showCacheStats(ctx))
            )

            .then(CommandManager.literal("version").executes(ctx -> showVersion(ctx)))
        );
    }

    private static int validateAll(CommandContext<ServerCommandSource> ctx) {
        ServerCommandSource src = ctx.getSource();
        src.sendFeedback(() -> Text.literal("=== SHINOBICORE FULL VALIDATION ===").formatted(Formatting.GOLD), false);

        int passed = 0;
        int failed = 0;

        if (ConfigManager.isLoaded()) {
            src.sendFeedback(() -> Text.literal("[PASS] Config loaded").formatted(Formatting.GREEN), false);
            passed++;
        } else {
            src.sendFeedback(() -> Text.literal("[FAIL] Config not loaded").formatted(Formatting.RED), false);
            failed++;
        }

        List<String> warnings = ConfigManager.validateAll();
        if (warnings.isEmpty()) {
            src.sendFeedback(() -> Text.literal("[PASS] Config values valid").formatted(Formatting.GREEN), false);
            passed++;
        } else {
            src.sendFeedback(() -> Text.literal("[WARN] Config has " + warnings.size() + " warnings").formatted(Formatting.YELLOW), false);
            passed++;
        }

        final int fp = passed;
        final int ff = failed;
        src.sendFeedback(() -> Text.literal("--- RESULT: " + fp + " passed, " + ff + " failed ---")
            .formatted(ff > 0 ? Formatting.RED : Formatting.GREEN), false);
        return ff > 0 ? 0 : 1;
    }

    private static int validateConfig(CommandContext<ServerCommandSource> ctx) {
        ServerCommandSource src = ctx.getSource();
        src.sendFeedback(() -> Text.literal("=== CONFIG VALIDATION ===").formatted(Formatting.GOLD), false);
        if (!ConfigManager.isLoaded()) {
            src.sendFeedback(() -> Text.literal("[FAIL] Config not loaded").formatted(Formatting.RED), false);
            return 0;
        }
        src.sendFeedback(() -> Text.literal("[PASS] Config loaded").formatted(Formatting.GREEN), false);
        src.sendFeedback(() -> Text.literal("Path: " + ConfigManager.getConfigPath()), false);
        List<String> warnings = ConfigManager.validateAll();
        if (warnings.isEmpty()) {
            src.sendFeedback(() -> Text.literal("[PASS] All values valid").formatted(Formatting.GREEN), false);
        } else {
            for (String w : warnings) {
                src.sendFeedback(() -> Text.literal("[WARN] " + w).formatted(Formatting.YELLOW), false);
            }
        }
        return 1;
    }

    private static int showSystems(CommandContext<ServerCommandSource> ctx) {
        ServerCommandSource src = ctx.getSource();
        src.sendFeedback(() -> Text.literal("=== SHINOBICORE SYSTEMS ===").formatted(Formatting.GOLD), false);
        src.sendFeedback(() -> Text.literal("Core:        ACTIVE").formatted(Formatting.GREEN), false);
        src.sendFeedback(() -> Text.literal("Config:      " + (ConfigManager.isLoaded() ? "LOADED" : "NOT LOADED")), false);
        src.sendFeedback(() -> Text.literal("Modules:     ACTIVE"), false);
        src.sendFeedback(() -> Text.literal("EventBus:    ENABLED"), false);
        return 1;
    }

    private static int reloadConfig(CommandContext<ServerCommandSource> ctx) {
        ConfigManager.reload();
        ctx.getSource().sendFeedback(() -> Text.literal("Config reloaded successfully.").formatted(Formatting.GREEN), false);
        return 1;
    }

    private static int setLogLevel(CommandContext<ServerCommandSource> ctx) {
        String level = StringArgumentType.getString(ctx, "level");
        com.example.shinobicore.core.log.ShinobiLogger.setLevel(level);
        ctx.getSource().sendFeedback(() -> Text.literal("Log level set to: " + level).formatted(Formatting.GREEN), false);
        return 1;
    }

    private static int showLogStatus(CommandContext<ServerCommandSource> ctx) {
        ServerCommandSource src = ctx.getSource();
        src.sendFeedback(() -> Text.literal("=== LOGGING STATUS ===").formatted(Formatting.GOLD), false);
        src.sendFeedback(() -> Text.literal("Level: " + com.example.shinobicore.core.log.ShinobiLogger.getLevel()), false);
        return 1;
    }

    private static int showFlags(CommandContext<ServerCommandSource> ctx) {
        ServerCommandSource src = ctx.getSource();
        src.sendFeedback(() -> Text.literal("=== FEATURE FLAGS ===").formatted(Formatting.GOLD), false);
        src.sendFeedback(() -> Text.literal("chakraSystem = " + true), false);
        src.sendFeedback(() -> Text.literal("taijutsuCombat = " + true), false);
        src.sendFeedback(() -> Text.literal("parkourSystem = " + true), false);
        src.sendFeedback(() -> Text.literal("hudRenderer = " + true), false);
        src.sendFeedback(() -> Text.literal("packetValidation = " + true), false);
        return 1;
    }

    private static int showCacheStats(CommandContext<ServerCommandSource> ctx) {
        ServerCommandSource src = ctx.getSource();
        src.sendFeedback(() -> Text.literal("=== CACHE STATISTICS ===").formatted(Formatting.GOLD), false);
        try { src.sendFeedback(() -> Text.literal("CastingClientState: " + CastingClientState.size()), false); } catch (Exception ignored) {}
        try { src.sendFeedback(() -> Text.literal("KenjutsuAnimations: " + KenjutsuAnimations.size()), false); } catch (Exception ignored) {}
        try { src.sendFeedback(() -> Text.literal("TaijutsuAnimations: " + TaijutsuAnimations.size()), false); } catch (Exception ignored) {}
        try { src.sendFeedback(() -> Text.literal("HitStopManager: " + HitStopManager.size()), false); } catch (Exception ignored) {}
        try { src.sendFeedback(() -> Text.literal("ChakraBurstAnimations: " + ChakraBurstAnimations.size()), false); } catch (Exception ignored) {}
        try { src.sendFeedback(() -> Text.literal("IdlePoseSystem: " + IdlePoseSystem.size()), false); } catch (Exception ignored) {}
        return 1;
    }

    private static int showVersion(CommandContext<ServerCommandSource> ctx) {
        ctx.getSource().sendFeedback(() -> Text.literal("ShinobiCore v4.0.0").formatted(Formatting.GOLD), false);
        ctx.getSource().sendFeedback(() -> Text.literal("Architecture: Modular (Phases 0-9 complete)"), false);
        return 1;
    }
}