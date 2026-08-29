package com.example.shinobicore.item;
import com.example.shinobicore.combat.ThrowingHelper;
import com.example.shinobicore.entity.ShurikenEntity;
import net.minecraft.entity.player.PlayerEntity;
import net.minecraft.item.Item;
import net.minecraft.item.ItemStack;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.sound.SoundEvents;
import net.minecraft.util.Hand;
import net.minecraft.util.TypedActionResult;
import net.minecraft.util.math.Vec3d;
import net.minecraft.world.World;
public class ThrowingWeaponItem extends Item {
    private final float damage;
    private final float speed;
    private final int cooldown;
    public ThrowingWeaponItem(Settings settings, float damage, float speed, int cooldown) {
        super(settings);
        this.damage = damage; this.speed = speed; this.cooldown = cooldown;
    }
    @Override public TypedActionResult<ItemStack> use(World world, PlayerEntity user, Hand hand) {
        ItemStack stack = user.getStackInHand(hand);
        if (!world.isClient && user instanceof ServerPlayerEntity sp) {
            Vec3d dir = ThrowingHelper.aimAssist(sp, user.getRotationVector(), 24.0);
            world.spawnEntity(new ShurikenEntity(world, user, dir.multiply(speed), damage));
            if (ThrowingHelper.doubleThrow(sp)) {
                world.spawnEntity(new ShurikenEntity(world, user, rotate(dir, 4.0).multiply(speed), damage));
            }
            user.playSound(SoundEvents.ENTITY_ARROW_SHOOT, 0.8f, 1.4f);
            if (!user.getAbilities().creativeMode) stack.decrement(1);
            user.getItemCooldownManager().set(this, cooldown);
        }
        if (world.isClient && user instanceof net.minecraft.client.network.ClientPlayerEntity cp) { com.example.shinobicore.client.combat.ThrowAnimations.playThrow(cp); } // PHASE_A_THROW_HOOK
        return TypedActionResult.success(stack, world.isClient());
    }
    private Vec3d rotate(Vec3d v, double deg) {
        double rad = Math.toRadians(deg), cos = Math.cos(rad), sin = Math.sin(rad);
        return new Vec3d(v.x * cos - v.z * sin, v.y, v.x * sin + v.z * cos).normalize();
    }
}