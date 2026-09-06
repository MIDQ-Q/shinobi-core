package com.example.shinobicore.stealth;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.server.world.ServerWorld;
import net.minecraft.util.math.Vec3d;
import net.minecraft.world.World;

public class NoiseSystem {
    public static void emitNoise(World world, Vec3d pos, float radius, float amount) {
        if (!(world instanceof ServerWorld serverWorld)) return;
        for (ServerPlayerEntity player : serverWorld.getPlayers()) {
            if (player.getPos().distanceTo(pos) <= radius) {
                StealthComponent comp = StealthComponent.KEY.get(player);
                float distFactor = 1.0f - (float)(player.getPos().distanceTo(pos) / radius);
                comp.addNoise(amount * distFactor);
            }
        }
    }
}