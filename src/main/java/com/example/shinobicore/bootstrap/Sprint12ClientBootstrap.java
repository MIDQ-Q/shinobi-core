package com.example.shinobicore.bootstrap;
import net.fabricmc.api.ClientModInitializer;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class Sprint12ClientBootstrap implements ClientModInitializer {
    private static final Logger LOGGER = LoggerFactory.getLogger("ShinobiCore");
    @Override
    public void onInitializeClient() {
        LOGGER.info("[ShinobiCore] Sprint12ClientBootstrap initialized (Safe Stub).");
    }
}