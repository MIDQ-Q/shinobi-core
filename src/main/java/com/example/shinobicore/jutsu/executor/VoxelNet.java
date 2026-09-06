package com.example.shinobicore.jutsu.executor;

import com.example.shinobicore.jutsu.core.VisualDefinition;
import io.netty.buffer.Unpooled;
import net.fabricmc.fabric.api.networking.v1.PlayerLookup;
import net.fabricmc.fabric.api.networking.v1.ServerPlayNetworking;
import net.minecraft.network.PacketByteBuf;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.util.Identifier;
import net.minecraft.util.math.Vec3d;

public final class VoxelNet {
    public static final Identifier SPAWN_ID = new Identifier("shinobicore", "voxel_proj_spawn");
    public static final Identifier IMPACT_ID = new Identifier("shinobicore", "voxel_proj_impact");
    private VoxelNet() {}

    public static void sendSpawn(CastContext ctx, Vec3d pos, Vec3d vel, double gravity, int lifetime) {
        VisualDefinition vis = ctx.jutsu.getVisual();
        if (vis == null || vis.getVoxelModel() == null || vis.getVoxelModel().isEmpty()) return;
        float scale = (float) vis.getScale();
        if (scale <= 0) scale = 1.0f;
        System.out.println("[DIAG] voxel sendSpawn: model=" + vis.getVoxelModel() + " scale=" + scale + " life=" + lifetime);
        PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
        buf.writeDouble(pos.x); buf.writeDouble(pos.y); buf.writeDouble(pos.z);
        buf.writeDouble(vel.x); buf.writeDouble(vel.y); buf.writeDouble(vel.z);
        buf.writeDouble(gravity);
        buf.writeInt(lifetime);
        buf.writeString(vis.getVoxelModel());
        buf.writeFloat(scale);
        for (ServerPlayerEntity p : PlayerLookup.world(ctx.world())) ServerPlayNetworking.send(p, SPAWN_ID, buf);
    }

    public static void sendImpact(CastContext ctx, Vec3d pos) {
        VisualDefinition vis = ctx.jutsu.getVisual();
        if (vis == null || vis.getVoxelModel() == null || vis.getVoxelModel().isEmpty()) return;
        PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
        buf.writeDouble(pos.x); buf.writeDouble(pos.y); buf.writeDouble(pos.z);
        for (ServerPlayerEntity p : PlayerLookup.world(ctx.world())) ServerPlayNetworking.send(p, IMPACT_ID, buf);
    }
}