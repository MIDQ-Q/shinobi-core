package com.example.shinobicore.world.structures;

import com.example.shinobicore.block.ModBlocks;
import com.example.shinobicore.world.structure.StructureBuilder;
import com.mojang.serialization.Codec;
import net.minecraft.util.math.BlockPos;
import net.minecraft.world.IWorld;
import net.minecraft.world.gen.feature.Feature;
import net.minecraft.world.gen.feature.NoneFeatureConfig;

import java.util.Random;

/**
 * Структура скрытой деревни шиноби
 */
public class HiddenVillageStructure extends Feature<NoneFeatureConfig> {

    public HiddenVillageStructure() {
        super(NoneFeatureConfig.CODEC);
    }

    @Override
    public boolean generate(IWorld world, Random rand, BlockPos pos) {
        if (!world.isAirBlock(pos)) return false;

        int villageRadius = 25;

        // Центральная площадь
        BlockPos plazaStart = pos.add(-8, -1, -8);
        BlockPos plazaEnd = pos.add(8, -1, 8);
        StructureBuilder.fill(world, plazaStart, plazaEnd, net.minecraft.block.Blocks.COBBLESTONE.getDefaultState());

        // Главное здание (аналог здания Хокаге)
        generateMainBuilding(world, pos);

        // Дома вокруг (8 домов по кругу)
        for (int i = 0; i < 8; i++) {
            double angle = (i / 8.0) * 2 * Math.PI;
            int houseX = pos.getX() + (int)(Math.cos(angle) * 15);
            int houseZ = pos.getZ() + (int)(Math.sin(angle) * 15);
            BlockPos housePos = new BlockPos(houseX, pos.getY(), houseZ);
            
            if (world.isAirBlock(housePos)) {
                JapaneseHouseStructure.generate(world, housePos);
            }
        }

        // Ворота деревни с символом клана
        ToriiGateStructure.generate(world, pos.add(0, 0, -villageRadius + 2));
        ToriiGateStructure.generate(world, pos.add(0, 0, villageRadius - 2));

        // Тренировочные полигоны
        TrainingGroundStructure.generate(world, pos.add(-20, 0, 0));
        TrainingGroundStructure.generate(world, pos.add(20, 0, 0));

        // Дороги между зданиями
        for (int i = 0; i < 8; i++) {
            double angle = (i / 8.0) * 2 * Math.PI;
            for (int r = 10; r < villageRadius - 2; r++) {
                int roadX = pos.getX() + (int)(Math.cos(angle) * r);
                int roadZ = pos.getZ() + (int)(Math.sin(angle) * r);
                BlockPos roadPos = new BlockPos(roadX, pos.getY() - 1, roadZ);
                
                if (world.isAirBlock(roadPos.up()) && !world.getBlockState(roadPos).getBlock().isIn(net.minecraft.tags.FluidTags.WATER)) {
                    world.setBlockState(roadPos, net.minecraft.block.Blocks.GRAVEL.getDefaultState(), 3);
                }
            }
        }

        return true;
    }

    private void generateMainBuilding(IWorld world, BlockPos center) {
        int width = 10;
        int depth = 8;
        int height = 6;

        // Основание
        BlockPos baseStart = center.add(-width/2, -1, -depth/2);
        BlockPos baseEnd = center.add(width/2, -1, depth/2);
        StructureBuilder.fill(world, baseStart, baseEnd, net.minecraft.block.Blocks.STONE_BRICKS.getDefaultState());

        // Стены
        BlockPos wallStart = center.add(-width/2, 0, -depth/2);
        BlockPos wallEnd = center.add(width/2, height, depth/2);
        StructureBuilder.hollow(world, wallStart, wallEnd, ModBlocks.WOOD_PANEL.getDefaultState());

        // Коническая крыша (упрощённая пирамида)
        for (int y = 0; y <= 4; y++) {
            int roofSize = width/2 - y;
            for (int x = -roofSize; x <= roofSize; x++) {
                for (int z = -roofSize; z <= roofSize; z++) {
                    if (Math.abs(x) == roofSize || Math.abs(z) == roofSize) {
                        BlockPos roofPos = center.add(x, height + y, z);
                        if (world.isAirBlock(roofPos)) {
                            world.setBlockState(roofPos, ModBlocks.BEAM.getDefaultState(), 3);
                        }
                    }
                }
            }
        }

        // Вход
        world.setBlockState(center.add(0, 1, -depth/2), ModBlocks.SHOJI.getDefaultState(), 3);
        world.setBlockState(center.add(0, 2, -depth/2), ModBlocks.SHOJI.getDefaultState(), 3);

        // Фонари
        world.setBlockState(center.add(-4, 1, -4), ModBlocks.LANTERN.getDefaultState(), 3);
        world.setBlockState(center.add(4, 1, -4), ModBlocks.LANTERN.getDefaultState(), 3);
    }
}
