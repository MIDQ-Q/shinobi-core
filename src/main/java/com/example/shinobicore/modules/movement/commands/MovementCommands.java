package com.example.shinobicore.modules.movement.commands;

import com.example.shinobicore.core.api.ChakraApi;
import com.example.shinobicore.core.service.CoreServices;
import com.example.shinobicore.modules.movement.common.MovementPose;
import com.example.shinobicore.modules.movement.config.MovementConfig;
import com.example.shinobicore.modules.movement.server.MovementServerMirror;
import com.mojang.brigadier.CommandDispatcher;
import com.mojang.brigadier.context.CommandContext;
import net.minecraft.server.command.CommandManager;
import net.minecraft.server.command.ServerCommandSource;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.text.Text;
import net.minecraft.util.Formatting;
import net.minecraft.util.math.BlockPos;
import net.minecraft.block.Blocks;

import java.util.UUID;

public final class MovementCommands {
    private MovementCommands() {}

    public static void register(CommandDispatcher<ServerCommandSource> dispatcher) {
        dispatcher.register(CommandManager.literal("shinobicore")
            .then(CommandManager.literal("movement")
                .then(CommandManager.literal("state").executes(MovementCommands::cmdState))
                .then(CommandManager.literal("test").executes(MovementCommands::cmdTest))
                .then(CommandManager.literal("debug").executes(MovementCommands::cmdDebug))
                .then(CommandManager.literal("reset").executes(MovementCommands::cmdReset))
            )
        );
    }

    private static int cmdState(CommandContext<ServerCommandSource> ctx) {
        ServerPlayerEntity player = ctx.getSource().getPlayer();
        if (player == null) return 0;
        
        UUID id = player.getUuid();
        MovementPose pose = MovementServerMirror.getPose(id);
        double drainAcc = MovementServerMirror.getDrainAccumulator(id);

        ctx.getSource().sendFeedback(() -> Text.literal("=== Movement State ===").formatted(Formatting.GOLD), false);
        ctx.getSource().sendFeedback(() -> Text.literal("Pose: " + pose.name()).formatted(Formatting.WHITE), false);
        
        CoreServices.get(ChakraApi.class).ifPresent(chakra -> {
            float cur = chakra.getCurrent(player);
            float max = chakra.getMax(player);
            boolean mode = chakra.isChakraModeActive(player);
            ctx.getSource().sendFeedback(() -> Text.literal(String.format("Chakra: %.0f/%.0f (mode: %s)", cur, max, mode ? "ON" : "OFF")).formatted(Formatting.AQUA), false);
        });

        ctx.getSource().sendFeedback(() -> Text.literal("Wall normal: Client-side only").formatted(Formatting.GRAY), false);
        ctx.getSource().sendFeedback(() -> Text.literal("Water surface: Client-side only").formatted(Formatting.GRAY), false);
        ctx.getSource().sendFeedback(() -> Text.literal(String.format("Drain acc: %.2f", drainAcc)).formatted(Formatting.YELLOW), false);
        ctx.getSource().sendFeedback(() -> Text.literal("Cooldowns: Tracked on client").formatted(Formatting.GRAY), false);
        
        return 1;
    }

    private static int cmdTest(CommandContext<ServerCommandSource> ctx) {
        ServerPlayerEntity player = ctx.getSource().getPlayer();
        if (player == null) return 0;

        BlockPos origin = player.getBlockPos().east(5);
        var world = player.getWorld();

        // Create a 5x5 water pool
        for (int x = 0; x < 5; x++) {
            for (int z = 0; z < 5; z++) {
                world.setBlockState(origin.add(x, 0, z), Blocks.WATER.getDefaultState());
                world.setBlockState(origin.add(x, -1, z), Blocks.STONE.getDefaultState());
            }
        }

        // Create a wall for wall-running
        for (int y = 0; y < 4; y++) {
            for (int z = 0; z < 5; z++) {
                world.setBlockState(origin.add(6, y, z), Blocks.STONE_BRICKS.getDefaultState());
            }
        }

        // Create an edge to grab
        world.setBlockState(origin.add(-2, 2, 0), Blocks.STONE_BRICKS.getDefaultState());
        world.setBlockState(origin.add(-2, 3, 0), Blocks.AIR.getDefaultState());

        ctx.getSource().sendFeedback(() -> Text.literal("Test structures spawned: Water pool, Wall, Edge.").formatted(Formatting.GREEN), false);
        return 1;
    }

    private static int cmdDebug(CommandContext<ServerCommandSource> ctx) {
        MovementConfig.DEBUG = !MovementConfig.DEBUG;
        String status = MovementConfig.DEBUG ? "ENABLED" : "DISABLED";
        ctx.getSource().sendFeedback(() -> Text.literal("Movement debug overlay: " + status).formatted(Formatting.YELLOW), false);
        return 1;
    }

    private static int cmdReset(CommandContext<ServerCommandSource> ctx) {
        ServerPlayerEntity player = ctx.getSource().getPlayer();
        if (player == null) return 0;
        
        MovementServerMirror.forceStopParkour(player);
        ctx.getSource().sendFeedback(() -> Text.literal("Movement state reset to NORMAL.").formatted(Formatting.GREEN), false);
        return 1;
    }
}