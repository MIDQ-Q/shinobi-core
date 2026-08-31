package com.example.shinobicore.modules.clans.network;
import net.minecraft.network.PacketByteBuf;
import net.minecraft.util.Identifier;
public final class ClanStateSyncPacket {
    public static final Identifier ID = new Identifier("shinobicore", "clan_state_sync");
    public final String clanId;
    public final String clanName;
    public final String clanColor;
    public ClanStateSyncPacket(String clanId, String clanName, String clanColor) {
        this.clanId = clanId;
        this.clanName = clanName;
        this.clanColor = clanColor;
    }
    public static void write(PacketByteBuf buf, ClanStateSyncPacket packet) {
        buf.writeString(packet.clanId);
        buf.writeString(packet.clanName);
        buf.writeString(packet.clanColor);
    }
    public static ClanStateSyncPacket read(PacketByteBuf buf) {
        return new ClanStateSyncPacket(buf.readString(), buf.readString(), buf.readString());
    }
}