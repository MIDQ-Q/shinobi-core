// SHINOBICORE:SPRINT2:FILE
package com.example.shinobicore.bootstrap;

import com.example.shinobicore.chakra.client.ChakraClientController;
import com.example.shinobicore.config.FeatureFlags;
import com.example.shinobicore.util.ShinobiLogger;
import net.fabricmc.api.ClientModInitializer;

public class Sprint2ClientBootstrap implements ClientModInitializer {
    @Override
    public void onInitializeClient() {
        if (!FeatureFlags.chakraV3) {
            ShinobiLogger.info("[SPRINT2] chakraV3 flag disabled, skipping client bootstrap");
            return;
        }
        ChakraClientController.register();
        ShinobiLogger.info("[SPRINT2] Client chakra controller registered");
    }
}