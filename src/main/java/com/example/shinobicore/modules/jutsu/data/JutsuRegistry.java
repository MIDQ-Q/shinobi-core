package com.example.shinobicore.modules.jutsu.data;

import com.example.shinobicore.core.log.ShinobiLogger;
import java.util.Collection;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;

public final class JutsuRegistry {
    private static final Map<String, JutsuDefinition> JUTSU_MAP = new ConcurrentHashMap<>();

    public static void register(JutsuDefinition def) {
        if (def == null || def.id() == null) return;
        if (JUTSU_MAP.containsKey(def.id())) {
            ShinobiLogger.error("jutsu", "Duplicate jutsu id ignored: " + def.id(), null);
            return;
        }
        JUTSU_MAP.put(def.id(), def);
    }

    public static Optional<JutsuDefinition> get(String id) {
        return Optional.ofNullable(JUTSU_MAP.get(id));
    }

    public static Collection<JutsuDefinition> all() {
        return JUTSU_MAP.values();
    }

    public static int size() {
        return JUTSU_MAP.size();
    }
    
    public static void clear() {
        JUTSU_MAP.clear();
    }
}