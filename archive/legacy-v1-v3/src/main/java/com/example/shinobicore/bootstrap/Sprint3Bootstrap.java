package com.example.shinobicore.bootstrap;
import net.fabricmc.api.ModInitializer;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class Sprint3Bootstrap implements ModInitializer {
    private static final Logger LOGGER = LoggerFactory.getLogger("ShinobiCore");
    @Override
    public void onInitialize() {
        LOGGER.info("[ShinobiCore] Sprint3Bootstrap initialized (Safe Stub).");
    }
}