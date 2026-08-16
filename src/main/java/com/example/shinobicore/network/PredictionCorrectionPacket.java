package com.example.shinobicore.network;

import net.minecraft.network.PacketByteBuf;
import net.minecraft.util.Identifier;
import net.minecraft.util.math.Vec3d;

/**
 * S0-07: Server -> Client correction packet.
 * Sent when server authoritative state diverges from client prediction.
 */
public record PredictionCorrectionPacket(double x, double y, double z, double vx, double vy, double vz) {
    public static final Identifier ID = new Identifier("shinobicore", "prediction_correction");

    public void write(PacketByteBuf buf) {
        buf.writeDouble(x);
        buf.writeDouble(y);
        buf.writeDouble(z);
        buf.writeDouble(vx);
        buf.writeDouble(vy);
        buf.writeDouble(vz);
    }

    public static PredictionCorrectionPacket read(PacketByteBuf buf) {
        return new PredictionCorrectionPacket(
            buf.readDouble(), buf.readDouble(), buf.readDouble(),
            buf.readDouble(), buf.readDouble(), buf.readDouble()
        );
    }
    
    public Vec3d getPos() { return new Vec3d(x, y, z); }
    public Vec3d getVel() { return new Vec3d(vx, vy, vz); }
}