package com.example.shinobicore.network;

import com.example.shinobicore.stat.NinjaFormula;
import com.example.shinobicore.stat.NinjaPlayerData;
import net.minecraft.network.PacketByteBuf;

public record ChakraSyncPacket(
    float currentChakra,
    float maxChakra,
    float currentStamina,
    float maxStamina,
    float fatigue,
    boolean exhausted,
    boolean meditating,
    int reserveLevel,
    String clanId,
    String affinityId
) {
    public void write(PacketByteBuf buf) {
        buf.writeFloat(currentChakra);
        buf.writeFloat(maxChakra);
        buf.writeFloat(currentStamina);
        buf.writeFloat(maxStamina);
        buf.writeFloat(fatigue);
        buf.writeBoolean(exhausted);
        buf.writeBoolean(meditating);
        buf.writeInt(reserveLevel);
        buf.writeString(clanId != null ? clanId : "");
        buf.writeString(affinityId != null ? affinityId : "");
    }

    public static ChakraSyncPacket read(PacketByteBuf buf) {
        float chakra = buf.readFloat();
        float max = buf.readFloat();
        float stam = buf.readFloat();
        float maxStam = buf.readFloat();
        float fatigue = buf.readFloat();
        boolean exhausted = buf.readBoolean();
        boolean meditating = buf.readBoolean();
        int reserve = buf.readInt();
        String clan = buf.readString();
        String affinity = buf.readString();
        return new ChakraSyncPacket(
                chakra, max, stam, maxStam, fatigue, exhausted, meditating, reserve,
                clan.isEmpty() ? null : clan,
                affinity.isEmpty() ? null : affinity
        );
    }

    public static ChakraSyncPacket fromData(NinjaPlayerData data) {
        return new ChakraSyncPacket(
                data.getCurrentChakra(),
                NinjaFormula.maxChakra(data),
                data.getCurrentStamina(),
                data.getMaxStamina(),
                data.getFatigue(),
                data.isExhausted(),
                data.isMeditating(),
                data.getReserveLevel(),
                data.getClanId(),
                data.getAffinity() != null ? data.getAffinity().getId() : null
        );
    }
}