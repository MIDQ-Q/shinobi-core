package com.example.shinobicore.network;

import com.example.shinobicore.stat.NinjaFormula;
import com.example.shinobicore.stat.NinjaPlayerData;
import net.minecraft.network.PacketByteBuf;

public record ChakraSyncPacket(
    float currentChakra,
    float maxChakra,
    float fatigue,
    boolean exhausted,
    boolean meditating,
    int reserveLevel,
    String clanId,
    String affinityId
) {
    // === ЗАПИСЬ (сервер → сеть) ===
    // Порядок записи ОБЯЗАН совпадать с порядком чтения!
    public void write(PacketByteBuf buf) {
        buf.writeFloat(currentChakra);      // 1
        buf.writeFloat(maxChakra);          // 2
        buf.writeFloat(fatigue);            // 3
        buf.writeBoolean(exhausted);        // 4
        buf.writeBoolean(meditating);       // 5
        buf.writeInt(reserveLevel);         // 6
        buf.writeString(clanId != null ? clanId : "");      // 7
        buf.writeString(affinityId != null ? affinityId : ""); // 8
    }

    // === ЧТЕНИЕ (сеть → клиент) ===
    // Тот же самый порядок, что и в write()!
    public static ChakraSyncPacket read(PacketByteBuf buf) {
        float chakra = buf.readFloat();          // 1
        float max = buf.readFloat();             // 2
        float fatigue = buf.readFloat();         // 3
        boolean exhausted = buf.readBoolean();   // 4
        boolean meditating = buf.readBoolean();  // 5
        int reserve = buf.readInt();             // 6
        String clan = buf.readString();          // 7
        String affinity = buf.readString();      // 8

        return new ChakraSyncPacket(
            chakra,
            max,
            fatigue,
            exhausted,
            meditating,
            reserve,
            clan.isEmpty() ? null : clan,
            affinity.isEmpty() ? null : affinity
        );
    }

    // === Создание пакета из данных игрока ===
    public static ChakraSyncPacket fromData(NinjaPlayerData data) {
        return new ChakraSyncPacket(
            data.getCurrentChakra(),
            NinjaFormula.maxChakra(data),
            data.getFatigue(),
            data.isExhausted(),
            data.isMeditating(),                              // ← добавили
            data.getReserveLevel(),
            data.getClan() != null ? data.getClan().getId() : null,
            data.getAffinity() != null ? data.getAffinity().getId() : null
        );
    }
}