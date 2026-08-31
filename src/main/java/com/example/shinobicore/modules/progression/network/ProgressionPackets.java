package com.example.shinobicore.modules.progression.network;

import com.example.shinobicore.core.log.ShinobiLogger;

public final class ProgressionPackets {
    private ProgressionPackets() {}

    public static void registerServer() {
        ProgressionActionPacket.registerServer();
        AttunementAttemptPacket.registerServer();
        MiniGameResultPacket.registerServer();
        ShinobiLogger.module("progression", "All server packets registered");
    }

    public static void registerClient() {
        ProgressionStateSyncPacket.registerClient();
        LevelUpPacket.registerClient();
        StatChangedPacket.registerClient();
        ShinobiLogger.module("progression", "All client packets registered");
    }
}