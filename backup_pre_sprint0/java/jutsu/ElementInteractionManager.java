package com.example.shinobicore.jutsu;

import net.minecraft.block.Blocks;
import net.minecraft.entity.Entity;
import net.minecraft.entity.LivingEntity;
import net.minecraft.entity.effect.StatusEffectInstance;
import net.minecraft.entity.effect.StatusEffects;
import net.minecraft.fluid.FluidState;
import net.minecraft.fluid.Fluids;
import net.minecraft.item.ItemStack;
import net.minecraft.item.Items;
import net.minecraft.particle.ParticleTypes;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.sound.SoundCategory;
import net.minecraft.sound.SoundEvents;
import net.minecraft.util.math.BlockPos;
import net.minecraft.util.math.Box;
import net.minecraft.util.math.Vec3d;

import java.util.List;

/**
 * Central manager for elemental interactions with the environment.
 * Called from NinjaProjectileEntity, AoeBehavior, DashBehavior.
 *
 * Interactions:
 * 1. Fire + Water = Steam (blindness cloud)
 * 2. Lightning + Water = Electrocute (bonus damage in water)
 * 3. Wind + Fire = Amplification (+15% fire damage)
 * 4. Earth + Water = Mud (slowness zone)
 * 5. Water + Fire = Extinguish (removes fire blocks)
 * 6. Lightning + Metal Armor = Conductivity (+12.5% per piece)
 * 7. Fire + Flammable = Spread fire to wood/leaves
 * 8. Water + Lava = Obsidian/Cobblestone
 */
public class ElementInteractionManager {

    // === 1. FIRE + WATER -> STEAM ===
    public static void fireMeetsWater(ServerWorld world, Vec3d pos, float radius) {
        for (int i = 0; i < 30; i++) {
            double angle = Math.random() * Math.PI * 2;
            double r = Math.random() * radius;
            world.spawnParticles(ParticleTypes.CLOUD,
                pos.x + Math.cos(angle) * r,
                pos.y + 0.5 + Math.random() * 2.0,
                pos.z + Math.sin(angle) * r,
                3, 0.2, 0.5, 0.2, 0.01);
        }
        world.spawnParticles(ParticleTypes.LARGE_SMOKE,
            pos.x, pos.y + 1, pos.z, 10, 1.0, 1.5, 1.0, 0.01);

        for (Entity e : world.getOtherEntities(null,
                new Box(pos, pos).expand(radius))) {
            if (e instanceof LivingEntity liv) {
                liv.addStatusEffect(new StatusEffectInstance(
                    StatusEffects.BLINDNESS, 60, 0, false, false));
            }
        }
        world.playSound(null, BlockPos.ofFloored(pos),
            SoundEvents.BLOCK_FIRE_EXTINGUISH, SoundCategory.BLOCKS, 1.5f, 0.8f);
    }

    // === 2. LIGHTNING + WATER -> ELECTROCUTE ===
    public static void lightningMeetsWater(ServerWorld world, Vec3d pos,
            float radius, float bonusDmg, ServerPlayerEntity caster) {
        BlockPos center = BlockPos.ofFloored(pos);
        boolean hasWater = false;
        for (int dx = -2; dx <= 2 && !hasWater; dx++) {
            for (int dz = -2; dz <= 2 && !hasWater; dz++) {
                FluidState fs = world.getFluidState(center.add(dx, 0, dz));
                if (!fs.isEmpty()) hasWater = true;
            }
        }
        if (!hasWater) return;

        for (int i = 0; i < 40; i++) {
            double a = Math.random() * Math.PI * 2;
            double r = Math.random() * radius;
            world.spawnParticles(ParticleTypes.ELECTRIC_SPARK,
                pos.x + Math.cos(a) * r, pos.y + 0.1,
                pos.z + Math.sin(a) * r,
                2, 0.1, 0.05, 0.1, 0.05);
        }
        for (Entity e : world.getOtherEntities(caster,
                new Box(pos, pos).expand(radius))) {
            if (e instanceof LivingEntity liv && liv.isTouchingWater()) {
                liv.damage(caster != null
                    ? caster.getDamageSources().magic()
                    : world.getDamageSources().magic(), bonusDmg);
                liv.addStatusEffect(new StatusEffectInstance(
                    StatusEffects.SLOWNESS, 40, 1, false, false));
            }
        }
        world.playSound(null, center,
            SoundEvents.ENTITY_LIGHTNING_BOLT_IMPACT,
            SoundCategory.BLOCKS, 1.0f, 1.5f);
    }

    // === 3. WIND + FIRE -> AMPLIFICATION ===
    public static float getWindFireBonus(ServerPlayerEntity caster) {
        try {
            var data = ((com.example.shinobicore.stat.NinjaDataHolder) caster)
                .shinobicore_getData();
            if (data.isNatureUnlocked(
                    com.example.shinobicore.stat.ElementType.WIND)
                && data.getNatureLevel(
                    com.example.shinobicore.stat.ElementType.WIND) >= 20) {
                return 0.15f;
            }
        } catch (Exception ignored) {}
        return 0f;
    }

    // === 4. EARTH + WATER -> MUD ===
    public static void earthMeetsWater(ServerWorld world, Vec3d pos, float radius) {
        for (int i = 0; i < 25; i++) {
            double a = Math.random() * Math.PI * 2;
            double r = Math.random() * radius;
            world.spawnParticles(ParticleTypes.POOF,
                pos.x + Math.cos(a) * r, pos.y + 0.2,
                pos.z + Math.sin(a) * r,
                2, 0.15, 0.1, 0.15, 0.02);
        }
        for (Entity e : world.getOtherEntities(null,
                new Box(pos, pos).expand(radius))) {
            if (e instanceof LivingEntity liv) {
                liv.addStatusEffect(new StatusEffectInstance(
                    StatusEffects.SLOWNESS, 100, 2, false, false));
                liv.addStatusEffect(new StatusEffectInstance(
                    StatusEffects.MINING_FATIGUE, 100, 1, false, false));
            }
        }
    }

    // === 5. WATER + FIRE -> EXTINGUISH ===
    public static void waterExtinguishes(ServerWorld world, Vec3d pos, float radius) {
        BlockPos center = BlockPos.ofFloored(pos);
        int r = (int) radius;
        int count = 0;
        for (int dx = -r; dx <= r; dx++) {
            for (int dy = -1; dy <= 2; dy++) {
                for (int dz = -r; dz <= r; dz++) {
                    BlockPos p = center.add(dx, dy, dz);
                    if (world.getBlockState(p).isOf(Blocks.FIRE)) {
                        world.removeBlock(p, false);
                        count++;
                    }
                }
            }
        }
        if (count > 0) {
            world.playSound(null, center,
                SoundEvents.BLOCK_FIRE_EXTINGUISH,
                SoundCategory.BLOCKS, 1.0f, 1.0f);
        }
    }

    // === 6. LIGHTNING + METAL ARMOR -> CONDUCTIVITY ===
    public static float getLightningMetalBonus(LivingEntity target) {
        int metal = 0;
        for (ItemStack armor : target.getArmorItems()) {
            if (armor.getItem() == Items.IRON_HELMET
                || armor.getItem() == Items.IRON_CHESTPLATE
                || armor.getItem() == Items.IRON_LEGGINGS
                || armor.getItem() == Items.IRON_BOOTS
                || armor.getItem() == Items.CHAINMAIL_HELMET
                || armor.getItem() == Items.CHAINMAIL_CHESTPLATE
                || armor.getItem() == Items.CHAINMAIL_LEGGINGS
                || armor.getItem() == Items.CHAINMAIL_BOOTS) {
                metal++;
            }
        }
        return metal * 0.125f; // +12.5% per piece, max +50%
    }

    // === 7. FIRE + FLAMMABLE -> SPREAD ===
    public static void fireSpreads(ServerWorld world, Vec3d pos, float radius) {
        BlockPos center = BlockPos.ofFloored(pos);
        int r = (int) radius;
        for (int dx = -r; dx <= r; dx++) {
            for (int dz = -r; dz <= r; dz++) {
                for (int dy = 0; dy <= 2; dy++) {
                    BlockPos p = center.add(dx, dy, dz);
                    if (world.getBlockState(p).isAir()) {
                        BlockPos below = p.down();
                        if (isFlammable(world.getBlockState(below).getBlock())) {
                            if (Math.random() < 0.3) {
                                world.setBlockState(p,
                                    Blocks.FIRE.getDefaultState(), 3);
                            }
                        }
                    }
                }
            }
        }
    }

    private static boolean isFlammable(net.minecraft.block.Block b) {
        return b == Blocks.OAK_LOG || b == Blocks.BIRCH_LOG
            || b == Blocks.SPRUCE_LOG || b == Blocks.JUNGLE_LOG
            || b == Blocks.ACACIA_LOG || b == Blocks.DARK_OAK_LOG
            || b == Blocks.OAK_PLANKS || b == Blocks.OAK_LEAVES
            || b == Blocks.BIRCH_LEAVES || b == Blocks.SPRUCE_LEAVES
            || b == Blocks.GRASS || b == Blocks.TALL_GRASS
            || b == Blocks.BAMBOO || b == Blocks.WHITE_WOOL;
    }

    // === 8. WATER + LAVA -> OBSIDIAN ===
    public static void waterMeetsLava(ServerWorld world, Vec3d pos, float radius) {
        BlockPos center = BlockPos.ofFloored(pos);
        int r = (int) radius;
        int converted = 0;
        for (int dx = -r; dx <= r; dx++) {
            for (int dy = -1; dy <= 1; dy++) {
                for (int dz = -r; dz <= r; dz++) {
                    BlockPos p = center.add(dx, dy, dz);
                    if (world.getBlockState(p).isOf(Blocks.LAVA)) {
                        world.setBlockState(p,
                            Blocks.OBSIDIAN.getDefaultState(), 3);
                        converted++;
                    }
                }
            }
        }
        if (converted > 0) {
            world.playSound(null, center,
                SoundEvents.BLOCK_FIRE_EXTINGUISH,
                SoundCategory.BLOCKS, 1.5f, 0.6f);
            world.spawnParticles(ParticleTypes.LARGE_SMOKE,
                pos.x, pos.y, pos.z, 15, 1.0, 1.0, 1.0, 0.01);
        }
    }

    // === DISPATCHER: called from behaviors ===
    public static void onElementalImpact(ServerWorld world, String elementType,
            Vec3d pos, float radius, ServerPlayerEntity caster) {
        if (world == null || pos == null) return;
        BlockPos center = BlockPos.ofFloored(pos);

        switch (elementType) {
            case "fire", "flame", "fireball" -> {
                fireSpreads(world, pos, radius * 0.5f);
                for (int dx = -1; dx <= 1; dx++) {
                    for (int dz = -1; dz <= 1; dz++) {
                        FluidState fs = world.getFluidState(
                            center.add(dx, 0, dz));
                        if (!fs.isEmpty()) {
                            fireMeetsWater(world, pos, radius);
                            return;
                        }
                    }
                }
            }
            case "water" -> {
                waterExtinguishes(world, pos, radius);
                waterMeetsLava(world, pos, radius);
            }
            case "lightning" -> {
                lightningMeetsWater(world, pos, radius, 4.0f, caster);
            }
            case "earth" -> {
                for (int dx = -1; dx <= 1; dx++) {
                    for (int dz = -1; dz <= 1; dz++) {
                        FluidState fs = world.getFluidState(
                            center.add(dx, 0, dz));
                        if (!fs.isEmpty()) {
                            earthMeetsWater(world, pos, radius);
                            return;
                        }
                    }
                }
            }
            default -> {}
        }
    }
}