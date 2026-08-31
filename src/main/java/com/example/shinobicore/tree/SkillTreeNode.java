package com.example.shinobicore.tree;
import java.util.List;
public record SkillTreeNode(
    String id, String branch, int distance, float angleOffset,
    String type, String jutsuId, String effect, float value,
    int spCost, List<String> requires,
    String icon, String displayName, String description,
    String clanRequired,
    String visType, String visKey, int visValue
) {
    public boolean hasVisibilityCondition() { return visType != null && !visType.isEmpty(); }
    public boolean hasClanRestriction() { return clanRequired != null && !clanRequired.isEmpty(); }
}