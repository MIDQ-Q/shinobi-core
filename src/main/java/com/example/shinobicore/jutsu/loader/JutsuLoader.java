package com.example.shinobicore.jutsu.loader;

import com.example.shinobicore.jutsu.core.JutsuDefinition;
import com.example.shinobicore.jutsu.registry.JutsuRegistry;
import com.example.shinobicore.ShinobiCore;
import net.minecraft.resource.Resource;
import net.minecraft.resource.ResourceManager;
import net.minecraft.util.Identifier;
import java.io.InputStream;
import java.util.Map;

/**
 * Загрузчик техник из JSON файлов.
 * Читает только файлы, созданные редактором.
 */
public class JutsuLoader {
    private static final String JUTSU_PATH = "jutsu";

    public static void loadAll(ResourceManager manager) {
        Map<Identifier, Resource> resources = manager.findResources(
            JUTSU_PATH,
            id -> id.getPath().endsWith(".json")
        );

        int loaded = 0;
        int failed = 0;

        for (Map.Entry<Identifier, Resource> entry : resources.entrySet()) {
            Identifier id = entry.getKey();
            Resource resource = entry.getValue();

            try {
                InputStream stream = resource.getInputStream();
                JutsuDefinition jutsu = JutsuParser.parse(stream);
                stream.close();

                JutsuRegistry.register(jutsu);
                loaded++;
                ShinobiCore.LOGGER.info("[Jutsu] Loaded: {}", jutsu.getId());
            } catch (Exception e) {
                failed++;
                ShinobiCore.LOGGER.error("[Jutsu] Failed to load: {}", id, e);
            }
        }

        ShinobiCore.LOGGER.info("[Jutsu] Loading complete: {} loaded, {} failed", loaded, failed);
    }

    public static void reload(ResourceManager manager) {
        JutsuRegistry.clear();
        loadAll(manager);
    }
}