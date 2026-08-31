package com.example.shinobicore.modules.movement.client.util;

import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.fluid.Fluids;
import net.minecraft.util.math.BlockPos;
import net.minecraft.world.World;

import java.util.Optional;

public final class WaterSurfaceDetector {
    private WaterSurfaceDetector() {}

    public static Optional<Double> getSurfaceY(ClientPlayerEntity player) {
        World world = player.getWorld();
        BlockPos feet = player.getBlockPos();
        
        for (int dy = 0; dy >= -2; dy--) {
            BlockPos check = feet.down(-dy);
            var fs = world.getFluidState(check);
            
            if (!fs.isEmpty() && (fs.isOf(Fluids.WATER) || fs.isOf(Fluids.FLOWING_WATER))) {
                double surfaceY = check.getY() + fs.getHeight(world, check);
                double playerFeetY = player.getY();
                
                if (playerFeetY >= surfaceY - 0.05 && playerFeetY <= surfaceY + 0.25) {
                    return Optional.of(surfaceY);
                }
            }
        }
        return Optional.empty();
    }
}