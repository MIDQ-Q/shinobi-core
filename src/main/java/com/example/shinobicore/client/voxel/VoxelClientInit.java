package com.example.shinobicore.client.voxel;

import com.example.shinobicore.jutsu.executor.VoxelNet;
import net.fabricmc.fabric.api.client.event.lifecycle.v1.ClientTickEvents;
import net.fabricmc.fabric.api.client.networking.v1.ClientPlayNetworking;
import net.fabricmc.fabric.api.client.rendering.v1.WorldRenderEvents;
import net.fabricmc.fabric.api.resource.ResourceManagerHelper;
import net.minecraft.resource.ResourceType;

public final class VoxelClientInit {
    private VoxelClientInit() {}
    public static void register() {
        ResourceManagerHelper.get(ResourceType.CLIENT_RESOURCES).registerReloadListener(VoxelModelRegistry.INSTANCE);
        ResourceManagerHelper.get(ResourceType.SERVER_DATA).registerReloadListener(VoxelRotationConfig.INSTANCE);
        ClientTickEvents.END_CLIENT_TICK.register(c -> ClientVoxelProjectiles.tick());
        WorldRenderEvents.AFTER_ENTITIES.register(ctx -> {
            ClientVoxelProjectiles.render(ctx);
            HandheldVoxelRenderer.render(ctx);
        });
        ClientPlayNetworking.registerGlobalReceiver(VoxelNet.SPAWN_ID, (client, handler, buf, sender) -> {
            final double px=buf.readDouble(), py=buf.readDouble(), pz=buf.readDouble();
            final double vx=buf.readDouble(), vy=buf.readDouble(), vz=buf.readDouble();
            final double g=buf.readDouble(); final int life=buf.readInt();
            final String model=buf.readString(64); final float scale=buf.readFloat();
            client.execute(() -> ClientVoxelProjectiles.onSpawn(px, py, pz, vx, vy, vz, g, life, model, scale));
        });
        ClientPlayNetworking.registerGlobalReceiver(VoxelNet.IMPACT_ID, (client, handler, buf, sender) -> {
            final double x=buf.readDouble(), y=buf.readDouble(), z=buf.readDouble();
            client.execute(() -> ClientVoxelProjectiles.onImpact(x, y, z));
        });
    }
}