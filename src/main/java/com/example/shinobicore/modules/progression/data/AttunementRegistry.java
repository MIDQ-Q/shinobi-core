package com.example.shinobicore.modules.progression.data;

import com.example.shinobicore.core.log.ShinobiLogger;
import java.util.Collection;
import java.util.HashMap;
import java.util.Map;
import java.util.Optional;

public final class AttunementRegistry {
    private static final Map<String, AttunementDefinition> ELEMENTS = new HashMap<>();

    private AttunementRegistry() {}

    public static void register(AttunementDefinition def) {
        if (def == null || def.id() == null) return;
        if (ELEMENTS.containsKey(def.id())) {
            ShinobiLogger.error("progression", "Duplicate element ID: " + def.id(), null);
            return;
        }
        ELEMENTS.put(def.id(), def);
    }

    public static Optional<AttunementDefinition> get(String id) {
        return Optional.ofNullable(ELEMENTS.get(id));
    }

    public static Collection<AttunementDefinition> getAll() {
        return ELEMENTS.values();
    }

    public static void clear() { ELEMENTS.clear(); }

    public static int size() { return ELEMENTS.size(); }

    public static boolean isCombined(String id) {
        AttunementDefinition def = ELEMENTS.get(id);
        return def != null && def.combined();
    }

    public static boolean hasComponentsUnlocked(
            java.util.Set<String> unlocked, String elementId) {
        AttunementDefinition def = ELEMENTS.get(elementId);
        if (def == null) return false;
        if (!def.combined()) return true;
        for (String comp : def.components()) {
            if (!unlocked.contains(comp)) return false;
        }
        return true;
    }
}