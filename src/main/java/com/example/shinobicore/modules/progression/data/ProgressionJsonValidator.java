package com.example.shinobicore.modules.progression.data;

import com.example.shinobicore.core.log.ShinobiLogger;
import java.util.HashSet;
import java.util.Set;

public final class ProgressionJsonValidator {
    private ProgressionJsonValidator() {}

    public static boolean validateTree() {
        boolean valid = true;
        for (TreeNodeDefinition node : TreeNodeRegistry.getAll()) {
            for (String req : node.requires()) {
                if (TreeNodeRegistry.get(req).isEmpty()) {
                    ShinobiLogger.error("progression", "Tree node " + node.id() + " has missing prerequisite: " + req, null);
                    valid = false;
                }
            }
            if (hasCycle(node.id(), new HashSet<>(), new HashSet<>())) {
                ShinobiLogger.error("progression", "Cycle detected in skill tree involving node: " + node.id(), null);
                valid = false;
            }
        }
        if (valid) {
            ShinobiLogger.module("progression", "Skill tree validation passed. Nodes: " + TreeNodeRegistry.size());
        }
        return valid;
    }

    private static boolean hasCycle(String nodeId, Set<String> visited, Set<String> recursionStack) {
        if (recursionStack.contains(nodeId)) return true;
        if (visited.contains(nodeId)) return false;

        visited.add(nodeId);
        recursionStack.add(nodeId);

        TreeNodeRegistry.get(nodeId).ifPresent(node -> {
            for (String req : node.requires()) {
                if (hasCycle(req, visited, recursionStack)) {
                    return;
                }
            }
        });

        recursionStack.remove(nodeId);
        return false;
    }
}