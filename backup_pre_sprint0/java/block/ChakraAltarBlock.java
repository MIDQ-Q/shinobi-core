package com.example.shinobicore.block;

import com.example.shinobicore.block.entity.ChakraAltarBlockEntity;
import net.minecraft.block.BlockEntityProvider;
import net.minecraft.block.BlockState;
import net.minecraft.block.entity.BlockEntity;
import net.minecraft.entity.player.PlayerEntity;
import net.minecraft.util.ActionResult;
import net.minecraft.util.Hand;
import net.minecraft.util.hit.BlockHitResult;
import net.minecraft.util.math.BlockPos;
import net.minecraft.world.World;

/**
 * S7-05: Chakra altar block.
 * Always active. Player binds to one altar. Altar can be upgraded.
 */
public class ChakraAltarBlock extends net.minecraft.block.Block implements BlockEntityProvider {

    public ChakraAltarBlock(Settings settings) {
        super(settings);
    }

    @Override
    public BlockEntity createBlockEntity(BlockPos pos, BlockState state) {
        return new ChakraAltarBlockEntity(pos, state);
    }

    @Override
    public ActionResult onUse(BlockState state, World world, BlockPos pos,
                              PlayerEntity player, Hand hand, BlockHitResult hit) {
        if (world.isClient) return ActionResult.SUCCESS;
        BlockEntity be = world.getBlockEntity(pos);
        if (be instanceof ChakraAltarBlockEntity altar) {
            altar.onPlayerInteract(player);
        }
        return ActionResult.SUCCESS;
    }
}