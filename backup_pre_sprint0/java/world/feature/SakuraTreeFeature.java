package com.example.shinobicore.world.feature;

import com.example.shinobicore.block.ModBlocks;
import net.minecraft.block.BlockState;
import net.minecraft.util.math.BlockPos;
import net.minecraft.world.Heightmap;
import net.minecraft.world.StructureWorldAccess;
import net.minecraft.world.gen.feature.DefaultFeatureConfig;
import net.minecraft.world.gen.feature.Feature;
import net.minecraft.world.gen.feature.util.FeatureContext;
import net.minecraft.util.math.random.Random;

public class SakuraTreeFeature extends Feature<DefaultFeatureConfig> {

    public SakuraTreeFeature(com.mojang.serialization.Codec<DefaultFeatureConfig> codec) {
        super(codec);
    }

    @Override
    public boolean generate(FeatureContext<DefaultFeatureConfig> context) {
        StructureWorldAccess world = context.getWorld();
        BlockPos origin = context.getOrigin();
        Random random = context.getRandom();

        int topY = world.getTopY(Heightmap.Type.WORLD_SURFACE_WG, origin.getX(), origin.getZ());
        BlockPos ground = new BlockPos(origin.getX(), topY, origin.getZ());
        if (!world.isAir(ground.up())) return false;

        generateTree(world, ground, random);
        return true;
    }

    public static void generateTree(StructureWorldAccess world, BlockPos base, Random random) {
        int trunkHeight = 4 + random.nextInt(3);

        for (int y = 1; y <= trunkHeight; y++) {
            BlockPos pos = base.up(y);
            if (world.isAir(pos)) {
                world.setBlockState(pos, ModBlocks.SAKURA_LOG.getDefaultState(), 3);
            }
        }

        int leafRadius = 2 + random.nextInt(2);
        BlockPos leafCenter = base.up(trunkHeight + 1);
        for (int dx = -leafRadius; dx <= leafRadius; dx++) {
            for (int dy = -leafRadius / 2; dy <= leafRadius / 2; dy++) {
                for (int dz = -leafRadius; dz <= leafRadius; dz++) {
                    if (dx * dx + dy * dy * 4 + dz * dz <= leafRadius * leafRadius) {
                        BlockPos pos = leafCenter.add(dx, dy, dz);
                        if (world.isAir(pos)) {
                            world.setBlockState(pos, ModBlocks.SAKURA_LEAVES.getDefaultState(), 3);
                        }
                    }
                }
            }
        }
    }
}