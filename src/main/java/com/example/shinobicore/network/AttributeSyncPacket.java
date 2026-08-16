package com.example.shinobicore.network;

import com.example.shinobicore.stat.AttributeType;
import net.minecraft.network.PacketByteBuf;
import java.util.EnumMap;
import java.util.Map;

/**
 * S0-01 / S0-06: Delta-sync packet for attributes.
 * Server -> Client. Sends only changed attributes.
 * RULE: READ ALL DATA BEFORE server.execute()!
 */
public record AttributeSyncPacket(Map<AttributeType, Float> changedAttributes) {

    public static final net.minecraft.util.Identifier ID =
        new net.minecraft.util.Identifier("shinobicore", "attribute_sync");

    public void write(PacketByteBuf buf) {
        buf.writeInt(changedAttributes.size());
        for (Map.Entry<AttributeType, Float> e : changedAttributes.entrySet()) {
            buf.writeString(e.getKey().getId());
            buf.writeFloat(e.getValue());
        }
    }

    public static AttributeSyncPacket read(PacketByteBuf buf) {
        int count = buf.readInt();
        Map<AttributeType, Float> attrs = new EnumMap<>(AttributeType.class);
        for (int i = 0; i < count; i++) {
            String id = buf.readString();
            float value = buf.readFloat();
            AttributeType attr = AttributeType.fromId(id);
            if (attr != null) {
                attrs.put(attr, value);
            }
        }
        return new AttributeSyncPacket(attrs);
    }
}