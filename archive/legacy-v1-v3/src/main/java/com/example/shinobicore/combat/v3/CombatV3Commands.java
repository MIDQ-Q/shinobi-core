// SHINOBICORE:SPRINT14:FILE
package com.example.shinobicore.combat.v3;

import com.mojang.brigadier.CommandDispatcher;
import com.mojang.brigadier.arguments.FloatArgumentType;
import com.mojang.brigadier.context.CommandContext;
import net.fabricmc.fabric.api.command.v2.CommandRegistrationCallback;
import net.minecraft.server.command.CommandManager;
import net.minecraft.server.command.ServerCommandSource;
import net.minecraft.text.Text;
import net.minecraft.util.Formatting;

/**
 * SPRINT 14 combat debug commands.
 *
 * Commands:
 * /shinobicore combatv3 systems
 * /shinobicore combatv3 formula <baseDamage>
 */
public final class CombatV3Commands {
    private static boolean registered = false;

    private CombatV3Commands() {}

    public static void register() {
        if (registered) {
            return;
        }

        registered = true;

        CommandRegistrationCallback.EVENT.register((dispatcher, registryAccess, environment) -> {
            registerCommands(dispatcher);
        });
    }

    private static void registerCommands(CommandDispatcher<ServerCommandSource> dispatcher) {
        dispatcher.register(CommandManager.literal("shinobicore")
                .then(CommandManager.literal("combatv3")
                        .requires(source -> source.hasPermissionLevel(2))
                        .then(CommandManager.literal("systems")
                                .executes(ctx -> systems(ctx)))
                        .then(CommandManager.literal("formula")
                                .then(CommandManager.argument("base", FloatArgumentType.floatArg(0.0f, 10000.0f))
                                        .executes(ctx -> formula(ctx))))
                )
        );
    }

    private static int systems(CommandContext<ServerCommandSource> ctx) {
        ctx.getSource().sendFeedback(() -> Text.literal("=== Combat V3 Systems ===").formatted(Formatting.GOLD), false);
        ctx.getSource().sendFeedback(() -> Text.literal("Module initialized: " + CombatV3Module.isInitialized()).formatted(Formatting.AQUA), false);
        ctx.getSource().sendFeedback(() -> Text.literal("Compat: " + CombatCompatibilityChecker.getReport()).formatted(Formatting.WHITE), false);

        return 1;
    }

    private static int formula(CommandContext<ServerCommandSource> ctx) {
        float base = FloatArgumentType.getFloat(ctx, "base");

        float damage = CombatFormula.calculateMeleeDamage(
                base,
                10.0f,
                10.0f,
                1.0f
        );

        ctx.getSource().sendFeedback(() -> Text.literal(
                "Formula sample: base " + base + " -> " + damage
        ).formatted(Formatting.GREEN), false);

        return 1;
    }
}