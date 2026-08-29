package com.example.shinobicore.command;

import com.example.shinobicore.combat.NinjaFormula;
import com.example.shinobicore.combat.StanceManager;
import com.example.shinobicore.item.ModItems;
import com.example.shinobicore.stat.component.IChakraComponent;
import com.example.shinobicore.stat.component.ICombatComponent;
import com.example.shinobicore.stat.component.IStatsComponent;
import com.example.shinobicore.stat.component.NinjaComponents;
import com.mojang.brigadier.CommandDispatcher;
import com.mojang.brigadier.arguments.StringArgumentType;
import com.mojang.brigadier.context.CommandContext;
import net.minecraft.entity.mob.ZombieEntity;
import net.minecraft.entity.EntityType;
import net.minecraft.server.command.CommandManager;
import net.minecraft.server.command.ServerCommandSource;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.text.Text;

/**
 * Combat debug commands (HLD 2.5, 4).
 * /stance <aggressive|iai|seigan>
 * /test_combat - spawns a dummy and prints the damage formula breakdown.
 */
public class CombatCommands {

    public static void register(CommandDispatcher<ServerCommandSource> dispatcher) {
        dispatcher.register(CommandManager.literal("stance")
            .requires(source -> source.hasPermissionLevel(2))
            .then(CommandManager.argument("id", StringArgumentType.word())
                .suggests((ctx, builder) -> {
                    builder.suggest("aggressive");
                    builder.suggest("iai");
                    builder.suggest("seigan");
                    return builder.buildFuture();
                })
                .executes(CombatCommands::executeStance)));

        dispatcher.register(CommandManager.literal("test_combat")
            .requires(source -> source.hasPermissionLevel(2))
            .executes(CombatCommands::executeTestCombat));
    }

    private static int executeStance(CommandContext<ServerCommandSource> ctx) {
        ServerPlayerEntity player = ctx.getSource().getPlayer();
        if (player == null) {
            ctx.getSource().sendError(Text.literal("Players only"));
            return 0;
        }
        String id = StringArgumentType.getString(ctx, "id");
        StanceManager.set(player, id);
        return 1;
    }

    private static int executeTestCombat(CommandContext<ServerCommandSource> ctx) {
        ServerPlayerEntity player = ctx.getSource().getPlayer();
        if (player == null) {
            ctx.getSource().sendError(Text.literal("Players only"));
            return 0;
        }

        IStatsComponent stats = NinjaComponents.getStats(player);
        ICombatComponent combat = NinjaComponents.getCombat(player);
        IChakraComponent chakra = NinjaComponents.getChakra(player);
        if (stats == null || combat == null || chakra == null) {
            player.sendMessage(Text.literal("Components not available"), false);
            return 0;
        }

        msg(player, "=== Combat Formula Test ===", "6");

        float mult = NinjaFormula.getMeleeMultiplier(stats, combat, chakra);
        boolean katana = player.getMainHandStack().isOf(ModItems.KATANA);

        msg(player, "Taijutsu: " + stats.getStatLevel(com.example.shinobicore.stat.StatType.TAIJUTSU), "f");
        msg(player, "Stance: " + combat.getStanceId(), "f");
        msg(player, "Fatigue: " + chakra.getFatigue(), "f");
        msg(player, "Melee multiplier: " + mult, "b");
        msg(player, "Katana in hand: " + katana, "f");

        float base = 5.0f;
        float extra = base * Math.max(0.0f, mult - 1.0f);
        if (katana) {
            extra *= 1.5f;
        }
        msg(player, "Bonus magic damage on hit: " + extra, "a");

        // Spawn training dummy
        ZombieEntity dummy = EntityType.ZOMBIE.create(player.getWorld());
        if (dummy != null) {
            dummy.setPosition(player.getPos().add(2.0, 0.0, 2.0));
            dummy.setCustomName(Text.literal("Training Dummy"));
            dummy.setCustomNameVisible(true);
            dummy.setPersistent();
            player.getWorld().spawnEntity(dummy);
            msg(player, "Training dummy spawned. Hit it!", "a");
        }

        return 1;
    }

    private static void msg(ServerPlayerEntity player, String message, String colorCode) {
        player.sendMessage(Text.literal("\u00a7" + colorCode + message), false);
    }
}