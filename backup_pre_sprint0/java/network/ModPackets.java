package com.example.shinobicore.network;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.network.packet.CastJutsuPacket;
import com.example.shinobicore.network.packet.CombatActionPacket;
import com.example.shinobicore.network.packet.LoadoutCastPacket;
import com.example.shinobicore.network.packet.ParkourActionPacket;
import com.example.shinobicore.network.packet.ProgressionActionPacket;
import com.example.shinobicore.network.packet.VfxSpawnPacket;

public final class ModPackets {
    private ModPackets() {}

    public static void registerServer() {
        ShinobiCore.LOGGER.info("Registering server-side packets...");
        CastJutsuPacket.registerServer();
        ParkourActionPacket.registerServer();
        CombatActionPacket.registerServer();
        LoadoutCastPacket.registerServer();
        ProgressionActionPacket.registerServer();
    }

    public static void registerClient() {
        ShinobiCore.LOGGER.info("Registering client-side packets...");
        VfxSpawnPacket.registerClient();
    }
}