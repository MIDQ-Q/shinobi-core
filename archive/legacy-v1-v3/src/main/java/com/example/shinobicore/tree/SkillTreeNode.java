package com.example.shinobicore.tree;

import java.util.List;
import java.util.Map;

/**
 * Skill tree node definition loaded from JSON.
 * Uses record-style accessors for compatibility with DataValidator.
 */
public class SkillTreeNode {
    private final String id;
    private final String name;
    private final String description;
    private final String type;
    private final String jutsuId;
    private final String clanRequired;
    private final int x;
    private final int y;
    private final int cost;
    private final int spCost;
    private final String reputationRequired;
    private final List<String> requires;
    private final Map<String, Object> effects;

    public SkillTreeNode(String id, String name, String description, String type,
                         String jutsuId, String clanRequired, int x, int y,
                         int cost, int spCost, String reputationRequired,
                         List<String> requires, Map<String, Object> effects) {
        this.id = id;
        this.name = name;
        this.description = description;
        this.type = type;
        this.jutsuId = jutsuId;
        this.clanRequired = clanRequired;
        this.x = x;
        this.y = y;
        this.cost = cost;
        this.spCost = spCost;
        this.reputationRequired = reputationRequired;
        this.requires = requires;
        this.effects = effects;
    }

    // Record-style accessors
    public String id() { return id; }
    public String name() { return name; }
    public String description() { return description; }
    public String type() { return type; }
    public String jutsuId() { return jutsuId; }
    public String clanRequired() { return clanRequired; }
    public int x() { return x; }
    public int y() { return y; }
    public int cost() { return cost; }
    public int spCost() { return spCost; }
    public String reputationRequired() { return reputationRequired; }
    public List<String> requires() { return requires; }
    public Map<String, Object> effects() { return effects; }

    // Standard getters for compatibility
    public String getId() { return id; }
    public String getName() { return name; }
    public String getDescription() { return description; }
    public String getType() { return type; }
    public String getJutsuId() { return jutsuId; }
    public String getClanRequired() { return clanRequired; }
    public int getX() { return x; }
    public int getY() { return y; }
    public int getCost() { return cost; }
    public int getSpCost() { return spCost; }
    public String getReputationRequired() { return reputationRequired; }
    public List<String> getRequires() { return requires; }
    public Map<String, Object> getEffects() { return effects; }
}