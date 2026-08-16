package com.example.shinobicore.network;

import net.minecraft.network.PacketByteBuf;
import net.minecraft.util.math.Vec3d;

/**
 * S0-06: Helpers for compact packet serialization.
 * Use compact IDs instead of full NBT. Delta-sync for frequent updates.
 */
public class PacketHelper {

    /** Write Vec3d as 3 floats (12 bytes vs NBT overhead). */
    public static void writeVec3d(PacketByteBuf buf, Vec3d v) {
        buf.writeFloat((float) v.x);
        buf.writeFloat((float) v.y);
        buf.writeFloat((float) v.z);
    }

    /** Read Vec3d from 3 floats. */
    public static Vec3d readVec3d(PacketByteBuf buf) {
        return new Vec3d(buf.readFloat(), buf.readFloat(), buf.readFloat());
    }

    /** Write optional string (empty string = null). */
    public static void writeOptionalString(PacketByteBuf buf, String s) {
        buf.writeString(s != null ? s : "");
    }

    /** Read optional string (empty string = null). */
    public static String readOptionalString(PacketByteBuf buf) {
        String s = buf.readString();
        return s.isEmpty() ? null : s;
    }

    /** Write compact entity reference (entity ID, 4 bytes). */
    public static void writeEntityId(PacketByteBuf buf, int entityId) {
        buf.writeVarInt(entityId);
    }

    /** Read compact entity reference. */
    public static int readEntityId(PacketByteBuf buf) {
        return buf.readVarInt();
    }

    /** Write compact VFX type ID (byte, max 255 types). */
    public static void writeVfxType(PacketByteBuf buf, int vfxType) {
        buf.writeByte(vfxType);
    }

    /** Read compact VFX type ID. */
    public static int readVfxType(PacketByteBuf buf) {
        return buf.readByte() & 0xFF;
    }

    /** Write delta float (only if changed more than epsilon). */
    public static boolean writeDeltaFloat(PacketByteBuf buf, float current, float lastSynced, float epsilon) {
        if (Math.abs(current - lastSynced) > epsilon) {
            buf.writeFloat(current);
            return true;
        }
        return false;
    }
}