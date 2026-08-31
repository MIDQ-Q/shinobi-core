package com.example.shinobicore.data;

import com.example.shinobicore.tree.SkillTreeRegistry;
import com.example.shinobicore.tree.SkillTreeNode;
import com.example.shinobicore.clan.ClanDefinition;
import com.example.shinobicore.clan.ClanRegistry;
import com.example.shinobicore.jutsu.data.JutsuDefinition;
import com.example.shinobicore.jutsu.data.JutsuRegistry;

import java.util.*;

public final class DataValidator {
    private static final List<String> ERRORS = new ArrayList<>();

    public record ValidationResult(int errorCount, boolean hasErrors, List<String> errors) {}

    public static ValidationResult validate() {
        ERRORS.clear();
        validateJutsu();
        validateClans();
        validateSkillTree();
        validateCrossReferences();
        return new ValidationResult(ERRORS.size(), !ERRORS.isEmpty(), List.copyOf(ERRORS));
    }

    private static void validateJutsu() {
        Set<String> ids = new HashSet<>();
        for (JutsuDefinition jutsu : JutsuRegistry.getAll()) {
            if (!ids.add(jutsu.id())) {
                ERRORS.add("Duplicate jutsu ID: " + jutsu.id());
            }
            if (jutsu.baseCost() < 0) {
                ERRORS.add("Negative chakra cost in jutsu: " + jutsu.id());
            }
            if (jutsu.tier() < 1 || jutsu.tier() > 5) {
                ERRORS.add("Invalid tier (" + jutsu.tier() + ") in jutsu: " + jutsu.id());
            }
        }
    }

    private static void validateClans() {
        Set<String> ids = new HashSet<>();
        for (ClanDefinition clan : ClanRegistry.getAll()) {
            if (!ids.add(clan.id())) {
                ERRORS.add("Duplicate clan ID: " + clan.id());
            }
        }
    }

    private static void validateSkillTree() {
        for (SkillTreeNode node : SkillTreeRegistry.getAll()) {
            Set<String> path = new HashSet<>();
            Set<String> visited = new HashSet<>();
            if (hasCycle(node.id(), path, visited)) {
                ERRORS.add("Circular dependency detected involving node: " + node.id());
            }
            
            if (node.requires() != null) {
                for (String req : node.requires()) {
                    if (SkillTreeRegistry.get(req) == null) {
                        ERRORS.add("Node '" + node.id() + "' requires non-existent node: '" + req + "'");
                    }
                }
            }
        }
    }

    private static boolean hasCycle(String nodeId, Set<String> path, Set<String> visited) {
        if (path.contains(nodeId)) return true;
        if (visited.contains(nodeId)) return false;
        
        path.add(nodeId);
        SkillTreeNode node = SkillTreeRegistry.get(nodeId);
        
        if (node != null && node.requires() != null) {
            for (String req : node.requires()) {
                if (hasCycle(req, path, visited)) return true;
            }
        }
        
        path.remove(nodeId);
        visited.add(nodeId);
        return false;
    }

    private static void validateCrossReferences() {
        for (ClanDefinition clan : ClanRegistry.getAll()) {
            if (clan.startingJutsu() != null) {
                for (String jutsuId : clan.startingJutsu()) {
                    if (JutsuRegistry.get(jutsuId) == null) {
                        ERRORS.add("Clan '" + clan.id() + "' has unknown starting jutsu: '" + jutsuId + "'");
                    }
                }
            }
        }
        
        for (SkillTreeNode node : SkillTreeRegistry.getAll()) {
            if ("jutsu".equals(node.type()) && node.jutsuId() != null && !node.jutsuId().isEmpty()) {
                if (JutsuRegistry.get(node.jutsuId()) == null) {
                    ERRORS.add("Skill tree node '" + node.id() + "' references unknown jutsu: '" + node.jutsuId() + "'");
                }
            }
        }
    }
}