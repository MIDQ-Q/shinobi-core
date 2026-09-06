package com.example.shinobicore.item.crafting;
import net.minecraft.client.item.TooltipContext;
import net.minecraft.entity.player.PlayerEntity;
import net.minecraft.item.Item;
import net.minecraft.item.ItemStack;
import net.minecraft.nbt.NbtCompound;
import net.minecraft.text.Text;
import net.minecraft.util.Hand;
import net.minecraft.util.TypedActionResult;
import net.minecraft.world.World;
import java.util.List;
public class ScrollItem extends Item {
    public ScrollItem(Settings settings) { super(settings); }
    @Override
    public TypedActionResult<ItemStack> use(World world, PlayerEntity user, Hand hand) {
        ItemStack stack = user.getStackInHand(hand);
        if (!world.isClient) {
            String jutsuId = getJutsuId(stack);
            if (jutsuId != null) {
                user.sendMessage(Text.literal("Learned jutsu: " + jutsuId), false);
                stack.decrement(1);
                return TypedActionResult.success(stack);
            }
        }
        return TypedActionResult.pass(stack);
    }
    public static String getJutsuId(ItemStack stack) {
        NbtCompound nbt = stack.getNbt();
        return nbt != null && nbt.contains("JutsuId") ? nbt.getString("JutsuId") : null;
    }
    public static void setJutsuId(ItemStack stack, String jutsuId) {
        NbtCompound nbt = stack.getOrCreateNbt();
        nbt.putString("JutsuId", jutsuId);
    }
    @Override
    public void appendTooltip(ItemStack stack, World world, List<Text> tooltip, TooltipContext context) {
        String id = getJutsuId(stack);
        tooltip.add(Text.literal(id != null ? "Contains: " + id : "Empty Scroll"));
    }
}