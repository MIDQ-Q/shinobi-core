package com.example.shinobicore.block;

import com.example.shinobicore.block.entity.TrainingPostBlockEntity;
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
 * S7-03: Training post block.
 * Players punch/slash it to gain XP.
 * Daily cap + diminishing returns.
 */
public class TrainingPostBlock extends net.minecraft.block.PillarBlock implements BlockEntityProvider {

    public TrainingPostBlock(Settings settings) {
        super(settings);
    }

    @Override
    public BlockEntity createBlockEntity(BlockPos pos, BlockState state) {
        return new TrainingPostBlockEntity(pos, state);
    }

    @Override
    public ActionResult onUse(BlockState state, World world, BlockPos pos,
                              PlayerEntity player, Hand hand, BlockHitResult hit) {
        if (world.isClient) return ActionResult.SUCCESS;
        BlockEntity be = world.getBlockEntity(pos);
        if (be instanceof TrainingPostBlockEntity post) {
            post.onPlayerInteract(player);
        }
        return ActionResult.SUCCESS;
    }
}