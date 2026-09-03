package com.example.shinobicore.jutsu.registry;

import com.example.shinobicore.jutsu.core.JutsuDefinition;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Реестр всех техник.
 */
public class JutsuRegistry {
    private static final Map<String, JutsuDefinition> TECHNIQUES = new ConcurrentHashMap<>();

    public static void register(JutsuDefinition def) {
        if (def == null || def.getId() == null) return;
        TECHNIQUES.put(def.getId(), def);
    }

    public static void unregister(String id) {
        TECHNIQUES.remove(id);
    }

    public static JutsuDefinition get(String id) {
        return TECHNIQUES.get(id);
    }

    public static boolean exists(String id) {
        return TECHNIQUES.containsKey(id);
    }

    public static Collection<JutsuDefinition> getAll() {
        return Collections.unmodifiableCollection(TECHNIQUES.values());
    }

    public static List<JutsuDefinition> getByCategory(String category) {
        return TECHNIQUES.values().stream()
            .filter(t -> t.getCategory().equals(category))
            .toList();
    }

    public static List<JutsuDefinition> getByElement(String elementId) {
        return TECHNIQUES.values().stream()
            .filter(t -> t.getElement().getId().equals(elementId))
            .toList();
    }

    public static List<JutsuDefinition> getByTag(String tag) {
        return TECHNIQUES.values().stream()
            .filter(t -> t.getTags().contains(tag))
            .toList();
    }

    public static int size() {
        return TECHNIQUES.size();
    }

    public static void clear() {
        TECHNIQUES.clear();
    }
}