package com.example.shinobicore.modules.clans.network;
import com.example.shinobicore.core.log.ShinobiLogger;
import com.example.shinobicore.modules.clans.client.ClansClientState;
import com.example.shinobicore.modules.clans.component.ClanComponent;
import com.example.shinobicore.modules.clans.component.ClanComponentKey;
import com.example.shinobicore.modules.clans.data.ClanDefinition;
import com.example.shinobicore.modules.clans.data.ClanRegistry;
import net.fabricmc.fabric.api.client.networking.v1.ClientPlayNetworking;
import net.fabricmc.fabric.api.networking.v1.PacketByteBufs;
import net.fabricmc.fabric.api.networking.v1.ServerPlayNetworking;
import net.minecraft.network.PacketByteBuf;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.util.Identifier;
import java.util.Optional;
public final class ClansPackets {
    public static final Identifier CLAN_STATE_SYNC_ID = new Identifier("shinobicore", "clan_state_sync");
    public static void registerServer() {
        ShinobiLogger.module("clans", "Server packets registered.");
    }
    public static void registerClient() {
        ClientPlayNetworking.registerGlobalReceiver(CLAN_STATE_SYNC_ID, (client, handler, buf, sender) -> {
            // CRITICAL: Read ALL data FIRST (TZ 5.3)
            final String clanId = buf.readString();
            final String clanName = buf.readString();
            final String clanColor = buf.readString();
            client.execute(() -> {
                ClansClientState.update(clanId, clanName, clanColor);
                ShinobiLogger.module("clans", "Client state updated: " + clanId);
            });
        });
        ShinobiLogger.module("clans", "Client packets registered.");
    }
    public static void sendClanState(ServerPlayerEntity player) {
        Optional<ClanComponent> compOpt = ClanComponentKey.get(player);
        if (compOpt.isEmpty()) return;
        ClanComponent comp = compOpt.get();
        String clanId = comp.getClanId();
        String name = "No Clan";
        String color = "#FFFFFF";
        if (!"none".equals(clanId)) {
            ClanDefinition def = ClanRegistry.get(clanId).orElse(null);
            if (def != null) { name = def.name(); color = def.color(); }
        }
        PacketByteBuf buf = PacketByteBufs.create();
        buf.writeString(clanId);
        buf.writeString(name);
        buf.writeString(color);
        ServerPlayNetworking.send(player, CLAN_STATE_SYNC_ID, buf);
    }
}