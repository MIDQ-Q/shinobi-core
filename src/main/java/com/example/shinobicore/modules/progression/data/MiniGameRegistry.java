package com.example.shinobicore.modules.progression.data;

import com.example.shinobicore.core.log.ShinobiLogger;
import java.util.Collection;
import java.util.HashMap;
import java.util.Map;
import java.util.Optional;

public final class MiniGameRegistry {
    private static final Map<String, MiniGameDefinition> GAMES = new HashMap<>();

    private MiniGameRegistry() {}

    public static void register(MiniGameDefinition def) {
        if (def == null || def.id() == null) return;
        if (GAMES.containsKey(def.id())) {
            ShinobiLogger.error("progression", "Duplicate minigame ID: " + def.id(), null);
            return;
        }
        GAMES.put(def.id(), def);
    }

    public static Optional<MiniGameDefinition> get(String id) {
        return Optional.ofNullable(GAMES.get(id));
    }

    public static Collection<MiniGameDefinition> getAll() {
        return GAMES.values();
    }

    public static void clear() { GAMES.clear(); }

    public static int size() { return GAMES.size(); }
}