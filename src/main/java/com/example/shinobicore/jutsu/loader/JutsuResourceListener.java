package com.example.shinobicore.jutsu.loader;

import com.example.shinobicore.ShinobiCore;
import net.fabricmc.fabric.api.resource.SimpleSynchronousResourceReloadListener;
import net.minecraft.resource.ResourceManager;
import net.minecraft.resource.ResourceType;
import net.minecraft.util.Identifier;

/**
 * Fabric resource reload listener для загрузки техник.
 */
public class JutsuResourceListener implements SimpleSynchronousResourceReloadListener {
    private static final Identifier ID = new Identifier(ShinobiCore.MOD_ID, "jutsu_loader");

    @Override
    public Identifier getFabricId() {
        return ID;
    }

    @Override
    public void reload(ResourceManager manager) {
        ShinobiCore.LOGGER.info("[Jutsu] Starting reload...");
        JutsuLoader.reload(manager);
    }

    public static void register() {
        net.fabricmc.fabric.api.resource.ResourceManagerHelper.get(ResourceType.SERVER_DATA)
            .registerReloadListener(new JutsuResourceListener());
        ShinobiCore.LOGGER.info("[Jutsu] Resource listener registered");
    }
}