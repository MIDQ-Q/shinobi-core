package com.example.shinobicore.block;

import com.example.shinobicore.block.entity.OnsenBlockEntity;
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
 * S7-04: Onsen water block.
 * Standing in it grants permanent stat buffs (with cooldown).
 */
public class OnsenBlock extends net.minecraft.block.Block implements BlockEntityProvider {

    public OnsenBlock(Settings settings) {
        super(settings);
    }

    @Override
    public BlockEntity createBlockEntity(BlockPos pos, BlockState state) {
        return new OnsenBlockEntity(pos, state);
    }

    @Override
    public ActionResult onUse(BlockState state, World world, BlockPos pos,
                              PlayerEntity player, Hand hand, BlockHitResult hit) {
        if (world.isClient) return ActionResult.SUCCESS;
        BlockEntity be = world.getBlockEntity(pos);
        if (be instanceof OnsenBlockEntity onsen) {
            onsen.onPlayerEnter(player);
        }
        return ActionResult.SUCCESS;
    }
}