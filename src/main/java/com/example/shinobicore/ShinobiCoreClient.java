package com.example.shinobicore;

import com.example.shinobicore.core.module.ModuleManager;
import net.fabricmc.api.ClientModInitializer;
import net.fabricmc.fabric.api.client.event.lifecycle.v1.ClientTickEvents;

public class ShinobiCoreClient implements ClientModInitializer {

    @Override
    public void onInitializeClient() {
        ModuleManager.initClient();
        ClientTickEvents.END_CLIENT_TICK.register(client -> ModuleManager.clientTick());
    }
}