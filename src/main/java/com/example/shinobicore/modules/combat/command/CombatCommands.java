package com.example.shinobicore.modules.combat.command;

import com.example.shinobicore.modules.combat.common.Stance;
import com.example.shinobicore.modules.combat.component.CombatComponent;
import com.example.shinobicore.modules.combat.component.CombatComponentKey;
import com.example.shinobicore.modules.combat.service.SheathService;
import com.mojang.brigadier.CommandDispatcher;
import com.mojang.brigadier.context.CommandContext;
import net.minecraft.server.command.CommandManager;
import net.minecraft.server.command.ServerCommandSource;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.text.Text;
import net.minecraft.util.Formatting;

public final class CombatCommands {
    private CombatCommands() {}

    public static void register(CommandDispatcher<ServerCommandSource> dispatcher) {
        dispatcher.register(CommandManager.literal("shinobicore")
            .then(CommandManager.literal("combat")
                .then(CommandManager.literal("info").executes(CombatCommands::cmdInfo))
                .then(CommandManager.literal("reset").executes(CombatCommands::cmdReset))
                .then(CommandManager.literal("sheath")
                    .then(CommandManager.literal("toggle").executes(CombatCommands::cmdSheathToggle)))
                .then(CommandManager.literal("stance")
                    .then(CommandManager.literal("set")
                        .then(CommandManager.literal("aggressive").executes(ctx -> cmdSetStance(ctx, Stance.AGGRESSIVE)))
                        .then(CommandManager.literal("defensive").executes(ctx -> cmdSetStance(ctx, Stance.DEFENSIVE)))
                    )
                )
            )
        );
    }

    private static int cmdInfo(CommandContext<ServerCommandSource> ctx) {
        ServerPlayerEntity player = ctx.getSource().getPlayer();
        CombatComponent comp = CombatComponentKey.KEY.getNullable(player);
        if (comp == null) {
            ctx.getSource().sendFeedback(() -> Text.literal("No combat component found").formatted(Formatting.RED), false);
            return 1;
        }
        
        String info = String.format("Stance: %s | Blocking: %b | Parrying: %b | Combo: %d | Sheathed: %b",
                comp.getStance(), comp.isBlocking(), comp.isParrying(), comp.getComboStep(), comp.isSheathed());
        
        ctx.getSource().sendFeedback(() -> Text.literal(info).formatted(Formatting.GOLD), false);
        return 1;
    }

    private static int cmdReset(CommandContext<ServerCommandSource> ctx) {
        ServerPlayerEntity player = ctx.getSource().getPlayer();
        CombatComponent comp = CombatComponentKey.KEY.getNullable(player);
        if (comp != null) {
            comp.setStance(Stance.NONE);
            comp.setBlocking(false);
            comp.setParrying(false);
            comp.resetCombo();
            comp.setSheathed(false);
        }
        ctx.getSource().sendFeedback(() -> Text.literal("Combat state reset").formatted(Formatting.GREEN), false);
        return 1;
    }

    private static int cmdSheathToggle(CommandContext<ServerCommandSource> ctx) {
        ServerPlayerEntity player = ctx.getSource().getPlayer();
        SheathService.toggleSheath(player);
        ctx.getSource().sendFeedback(() -> Text.literal("Sheath toggled").formatted(Formatting.GREEN), false);
        return 1;
    }

    private static int cmdSetStance(CommandContext<ServerCommandSource> ctx, Stance stance) {
        ServerPlayerEntity player = ctx.getSource().getPlayer();
        CombatComponent comp = CombatComponentKey.KEY.getNullable(player);
        if (comp != null) {
            comp.setStance(stance);
            ctx.getSource().sendFeedback(() -> Text.literal("Stance set to " + stance).formatted(Formatting.GREEN), false);
        }
        return 1;
    }
}