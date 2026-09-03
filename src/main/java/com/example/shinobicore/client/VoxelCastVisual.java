package com.example.shinobicore.client;

import com.example.shinobicore.jutsu.core.JutsuDefinition;
import com.example.shinobicore.jutsu.registry.JutsuRegistry;
import com.google.gson.JsonElement;
import com.google.gson.JsonObject;
import net.fabricmc.fabric.api.client.event.lifecycle.v1.ClientTickEvents;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.network.AbstractClientPlayerEntity;
import net.minecraft.particle.DustParticleEffect;
import org.joml.Vector3f;

public class VoxelCastVisual {
    private static int tick = 0;
    public static void register() {
        ClientTickEvents.END_CLIENT_TICK.register(VoxelCastVisual::tickClient);
    }
        private static void tickClient(MinecraftClient client) {
        if (client.world == null) return;
        tick++;
        if (tick % 3 != 0) return;
        
        // Iterate through players and render placeholder visual for casting players
        for (AbstractClientPlayerEntity p : client.world.getPlayers()) {
            HandSignsClientState.ActiveSigns s = HandSignsClientState.get(p.getId());
            if (s == null) continue;
            
            JutsuDefinition def = JutsuRegistry.get(s.jutsuId);
            if (def == null || def.getVisual() == null || def.getVisual().getVoxelModel() == null) continue;
            
            // TODO: Implement full voxel model rendering via Blockbench integration
            // For now, show placeholder particles at the player's hand position
            
            // Placeholder: spawn colored particles at hand position
            net.minecraft.util.math.Vec3d handPos = net.minecraft.util.math.Vec3d.ZERO;
            double px = p.getX() + handPos.x;
            double py = p.getY() + handPos.y + 1.2;
            double pz = p.getZ() + handPos.z;
            
            // Spawn particles based on element
            org.joml.Vector3f color = getElementColor(def.getElement());
            client.world.addParticle(
                new DustParticleEffect(color, 0.8f),
                px, py, pz,
                0, 0.05, 0
            );
        }
    }
    
    private static org.joml.Vector3f getElementColor(com.example.shinobicore.jutsu.enums.ElementType element) {
        if (element == null) return new org.joml.Vector3f(1f, 1f, 1f);
        return switch (element) {
            case FIRE -> new org.joml.Vector3f(1f, 0.4f, 0.1f);
            case WATER -> new org.joml.Vector3f(0.2f, 0.5f, 1f);
            case WIND -> new org.joml.Vector3f(0.5f, 0.9f, 0.6f);
            case EARTH -> new org.joml.Vector3f(0.7f, 0.5f, 0.3f);
            case LIGHTNING -> new org.joml.Vector3f(1f, 1f, 0.3f);
            case YIN -> new org.joml.Vector3f(0.6f, 0.3f, 0.9f);
            case YANG -> new org.joml.Vector3f(1f, 1f, 1f);
            default -> new org.joml.Vector3f(0.5f, 0.5f, 0.5f);
        };
    }
}