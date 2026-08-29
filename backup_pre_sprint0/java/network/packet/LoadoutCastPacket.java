package com.example.shinobicore.network.packet;

import com.example.shinobicore.jutsu.JutsuCaster;
import com.example.shinobicore.stat.component.IJutsuComponent;
import com.example.shinobicore.stat.component.NinjaComponents;
import net.fabricmc.fabric.api.client.networking.v1.ClientPlayNetworking;
import net.fabricmc.fabric.api.networking.v1.PacketByteBufs;
import net.fabricmc.fabric.api.networking.v1.ServerPlayNetworking;
import net.minecraft.network.PacketByteBuf;
import net.minecraft.util.Identifier;

/** Client -> server: cast jutsu from a loadout slot. */
public class LoadoutCastPacket {
    public static final Identifier ID = new Identifier("shinobicore", "loadout_cast");

    public static void send(int loadout, int slot) {
        PacketByteBuf buf = PacketByteBufs.create();
        buf.writeInt(loadout);
        buf.writeInt(slot);
        ClientPlayNetworking.send(ID, buf);
    }

    public static void registerServer() {
        ServerPlayNetworking.registerGlobalReceiver(ID, (server, player, handler, buf, sender) -> {
            final int loadout = buf.readInt();
            final int slot = buf.readInt();
            server.execute(() -> {
                IJutsuComponent comp = NinjaComponents.getJutsu(player);
                if (comp == null) return;
                String jutsuId = comp.getLoadoutSlot(loadout, slot);
                if (jutsuId != null) {
                    JutsuCaster.cast(player, jutsuId);
                }
            });
        });
    }
}