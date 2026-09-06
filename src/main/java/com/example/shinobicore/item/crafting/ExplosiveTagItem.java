package com.example.shinobicore.item.crafting;
import net.minecraft.item.Item;
import net.minecraft.item.ItemUsageContext;
import net.minecraft.util.ActionResult;
import net.minecraft.world.World;
import net.minecraft.util.math.BlockPos;
import net.minecraft.sound.SoundCategory;
import net.minecraft.sound.SoundEvents;
public class ExplosiveTagItem extends Item {
    public ExplosiveTagItem(Settings settings) { super(settings); }
    @Override
    public ActionResult useOnBlock(ItemUsageContext context) {
        World world = context.getWorld();
        BlockPos pos = context.getBlockPos().offset(context.getSide());
        if (!world.isClient) {
            world.playSound(null, pos, SoundEvents.ENTITY_TNT_PRIMED, SoundCategory.BLOCKS, 1.0f, 1.0f);
            context.getStack().decrement(1);
            return ActionResult.SUCCESS;
        }
        return ActionResult.PASS;
    }
}