package com.example.shinobicore.jutsu.executor;

import com.example.shinobicore.jutsu.core.EffectDefinition;
import net.minecraft.entity.LivingEntity;
import net.minecraft.block.BlockState;
import net.minecraft.block.Blocks;
import net.minecraft.registry.Registries;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.Identifier;
import net.minecraft.util.math.BlockPos;
import net.minecraft.util.math.Box;
import net.minecraft.util.math.Vec3d;

public class WorldEffectExecutor {

    public static void applyWorld(CastContext ctx, EffectDefinition effect, Vec3d center) {
        ServerWorld world = ctx.world();
        switch (effect.getSubType()) {
            case IGNITE -> ignite(world, center, effect.getInt("area", 3), ctx.caster);
            case FREEZE -> freeze(world, center, effect.getInt("area", 3));
            case PLACE_BLOCK -> placeBlock(world, center, effect.getString("blockType", "stone"), effect.getInt("duration", 200));
            case REMOVE_BLOCK -> removeBlock(world, center, effect.getInt("area", 3));
            case TRANSFORM_BLOCK -> transform(world, center, effect.getString("from", "minecraft:dirt"), effect.getString("to", "minecraft:grass_block"), effect.getInt("area", 3));
            case CREATE_ENTITY -> createEntity(world, center, effect.getString("entityType", "minecraft:armor_stand"));
            default -> {}
        }
    }

    private static void ignite(ServerWorld world, Vec3d center, int area, LivingEntity caster) {
        BlockPos base = BlockPos.ofFloored(center);
        // Fire on ground
        for (int x = -area; x <= area; x++) for (int z = -area; z <= area; z++) {
            if (x*x + z*z > area*area) continue;
            BlockPos p = base.add(x, 0, z);
            if (world.getBlockState(p).isAir() && !world.getBlockState(p.down()).isAir()) {
                world.setBlockState(p, Blocks.FIRE.getDefaultState(), 3);
            }
        }
        // Ignite entities but NOT the caster
        for (Object o : world.getOtherEntities(caster, new Box(center, center).expand(area))) {
            if (o instanceof net.minecraft.entity.LivingEntity e && e.isAlive() && !e.equals(caster)) {
                e.setOnFireFor(5);
            }
        }
    }

    private static void freeze(ServerWorld world, Vec3d center, int area) {
        BlockPos base = BlockPos.ofFloored(center);
        for (int x = -area; x <= area; x++) for (int y = -area; y <= area; y++) for (int z = -area; z <= area; z++) {
            if (x*x + y*y + z*z > area*area) continue;
            BlockPos p = base.add(x, y, z);
            BlockState s = world.getBlockState(p);
            if (s.isOf(Blocks.WATER)) world.setBlockState(p, Blocks.ICE.getDefaultState(), 3);
            else if (s.isOf(Blocks.LAVA)) world.setBlockState(p, Blocks.OBSIDIAN.getDefaultState(), 3);
        }
    }

    private static void placeBlock(ServerWorld world, Vec3d center, String blockType, int duration) {
        BlockPos p = BlockPos.ofFloored(center);
        var opt = Registries.BLOCK.getOrEmpty(new Identifier(blockType));
        if (opt.isEmpty()) return;
        BlockState prev = world.getBlockState(p);
        world.setBlockState(p, opt.get().getDefaultState(), 3);
        if (duration > 0) {
            TempBlockSystem.scheduleRemoval(world, p, prev, duration);
        }
    }

    private static void removeBlock(ServerWorld world, Vec3d center, int area) {
        BlockPos base = BlockPos.ofFloored(center);
        for (int x = -area; x <= area; x++) for (int y = -area; y <= area; y++) for (int z = -area; z <= area; z++) {
            BlockPos p = base.add(x, y, z);
            if (!world.getBlockState(p).isAir() && world.getBlockState(p).getBlock() != Blocks.BEDROCK && world.getBlockState(p).getHardness(world, p) >= 0) {
                world.breakBlock(p, false, null);
            }
        }
    }

    private static void transform(ServerWorld world, Vec3d center, String from, String to, int area) {
        // Strip "minecraft:" if present for registry lookup
        String fromId = from.contains(":") ? from : "minecraft:" + from;
        String toId = to.contains(":") ? to : "minecraft:" + to;
        var fromOpt = Registries.BLOCK.getOrEmpty(new Identifier(fromId));
        var toOpt = Registries.BLOCK.getOrEmpty(new Identifier(toId));
        if (fromOpt.isEmpty() || toOpt.isEmpty()) return;
        BlockPos base = BlockPos.ofFloored(center);
        int count = 0;
        for (int x = -area; x <= area; x++) for (int y = -area; y <= area; y++) for (int z = -area; z <= area; z++) {
            if (x*x + y*y + z*z > area*area) continue;
            BlockPos p = base.add(x, y, z);
            if (world.getBlockState(p).isOf(fromOpt.get())) {
                world.setBlockState(p, toOpt.get().getDefaultState(), 3);
                count++;
            }
        }
        VerificationLogger.log("WORLD_TRANSFORM", "from=" + from + " to=" + to + " area=" + area + " count=" + count);
    }

    private static void createEntity(ServerWorld world, Vec3d center, String entityType) {
        var opt = Registries.ENTITY_TYPE.getOrEmpty(new Identifier(entityType));
        if (opt.isEmpty()) return;
        net.minecraft.entity.Entity e = opt.get().create(world);
        if (e == null) return;
        e.setPosition(center);
        world.spawnEntity(e);
    }
}