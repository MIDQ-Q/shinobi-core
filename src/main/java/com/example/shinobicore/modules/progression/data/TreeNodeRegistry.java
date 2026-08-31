package com.example.shinobicore.modules.progression.data;

import com.example.shinobicore.core.log.ShinobiLogger;
import java.util.Collection;
import java.util.HashMap;
import java.util.Map;
import java.util.Optional;

public final class TreeNodeRegistry {
    private static final Map<String, TreeNodeDefinition> NODES = new HashMap<>();

    private TreeNodeRegistry() {}

    public static void register(TreeNodeDefinition node) {
        if (node == null || node.id() == null) {
            ShinobiLogger.error("progression", "Attempted to register null or ID-less tree node", null);
            return;
        }
        if (NODES.containsKey(node.id())) {
            ShinobiLogger.error("progression", "Duplicate tree node ID: " + node.id(), null);
            return;
        }
        NODES.put(node.id(), node);
    }

    public static Optional<TreeNodeDefinition> get(String id) {
        return Optional.ofNullable(NODES.get(id));
    }

    public static Collection<TreeNodeDefinition> getAll() {
        return NODES.values();
    }

    public static void clear() {
        NODES.clear();
    }

    public static int size() {
        return NODES.size();
    }
}