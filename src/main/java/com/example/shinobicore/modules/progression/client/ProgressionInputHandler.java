package com.example.shinobicore.modules.progression.client;

import com.example.shinobicore.modules.progression.ui.ProgressionHubTab;
import net.minecraft.client.MinecraftClient;

public final class ProgressionInputHandler {
    private ProgressionInputHandler() {}

    public static void init() {
        // Initialization if needed
    }

    public static void tick() {
        MinecraftClient client = MinecraftClient.getInstance();
        if (client.player == null) return;

        if (ProgressionKeyBindings.OPEN_PROGRESSION_KEY.wasPressed()) {
            client.setScreen(new ProgressionHubTab());
        }
    }
}