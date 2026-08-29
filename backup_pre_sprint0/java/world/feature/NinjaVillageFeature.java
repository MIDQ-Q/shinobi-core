package com.example.shinobicore.world.feature;

import com.example.shinobicore.world.structure.DojoStructure;
import com.example.shinobicore.world.structure.HouseStructure;
import com.example.shinobicore.world.structure.OnsenStructure;
import com.example.shinobicore.world.structure.ToriiStructure;
import net.minecraft.util.math.BlockPos;
import net.minecraft.world.Heightmap;
import net.minecraft.world.StructureWorldAccess;
import net.minecraft.world.gen.feature.DefaultFeatureConfig;
import net.minecraft.world.gen.feature.Feature;
import net.minecraft.world.gen.feature.util.FeatureContext;
import net.minecraft.util.math.random.Random;

public class NinjaVillageFeature extends Feature<DefaultFeatureConfig> {

    public NinjaVillageFeature(com.mojang.serialization.Codec<DefaultFeatureConfig> codec) {
        super(codec);
    }

    @Override
    public boolean generate(FeatureContext<DefaultFeatureConfig> context) {
        StructureWorldAccess world = context.getWorld();
        BlockPos origin = context.getOrigin();
        Random random = context.getRandom();

        int topY = world.getTopY(Heightmap.Type.WORLD_SURFACE_WG, origin.getX(), origin.getZ());
        BlockPos ground = new BlockPos(origin.getX(), topY, origin.getZ());

        if (!world.isAir(ground.up(2))) return false;

        ToriiStructure.generate(world, ground.add(0, 0, 8));
        DojoStructure.generate(world, ground);
        HouseStructure.generate(world, ground.add(-10, 0, -5));
        HouseStructure.generate(world, ground.add(10, 0, -5));
        HouseStructure.generate(world, ground.add(-8, 0, 6));
        OnsenStructure.generate(world, ground.add(12, 0, 6));

        for (int i = 0; i < 6; i++) {
            int tx = random.nextInt(30) - 15;
            int tz = random.nextInt(30) - 15;
            int treeTopY = world.getTopY(Heightmap.Type.WORLD_SURFACE_WG,
                ground.getX() + tx, ground.getZ() + tz);
            BlockPos treePos = new BlockPos(ground.getX() + tx, treeTopY, ground.getZ() + tz);
            if (world.isAir(treePos.up())) {
                SakuraTreeFeature.generateTree(world, treePos, random);
            }
        }

        return true;
    }
}