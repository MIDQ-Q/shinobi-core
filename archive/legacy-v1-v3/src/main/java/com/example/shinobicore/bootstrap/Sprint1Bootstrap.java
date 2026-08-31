package com.example.shinobicore.bootstrap;
import net.fabricmc.api.ModInitializer;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class Sprint1Bootstrap implements ModInitializer {
    private static final Logger LOGGER = LoggerFactory.getLogger("ShinobiCore");
    @Override
    public void onInitialize() {
        LOGGER.info("[ShinobiCore] Sprint1Bootstrap initialized (Safe Stub).");
    }
}