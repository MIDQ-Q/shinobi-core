package com.example.shinobicore.mixin;

import com.example.shinobicore.client.parkour.ParkourManager;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.entity.EntityPose;
import net.minecraft.entity.player.PlayerEntity;
import net.minecraft.util.math.BlockPos;
import net.minecraft.world.World;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfo;

@Mixin(PlayerEntity.class)
public abstract class SlidePoseMixin {

    @Inject(method = "updatePose", at = @At("HEAD"), cancellable = true)
    private void shinobicore_slidePose(CallbackInfo ci) {
        PlayerEntity self = (PlayerEntity) (Object) this;
        if (!(self instanceof ClientPlayerEntity)) return;

        if (ParkourManager.isSliding() || hasBlockAtChest(self)) {
            self.setPose(EntityPose.SWIMMING);
            ci.cancel();
        }
    }

    private static boolean hasBlockAtChest(PlayerEntity self) {
        World w = self.getWorld();
        BlockPos chest = BlockPos.ofFloored(self.getX(), self.getY() + 1.0, self.getZ());
        return w.getBlockState(chest).isSolidBlock(w, chest);
    }
}