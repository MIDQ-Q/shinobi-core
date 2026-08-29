package com.example.shinobicore.tree;

import java.util.List;

/**
* S0-04: Skill tree node definition.
* New fields: requiresTeacher, requiresScroll, positionX, positionY.
* Validation is done in SkillTreeRegistry, not here.
*/
public record SkillTreeNode(
    String id, String branch, int distance, float angleOffset,
    String type, String jutsuId, String effect, float value,
    int spCost, List<String> requires,
    String icon, String displayName, String description,
    String clanRequired,
    String visType, String visKey, int visValue,
    // S0-04: New fields from roadmap
    boolean requiresTeacher,
    String requiresScroll,
    int positionX, int positionY
) {
    public boolean hasVisibilityCondition() { return visType != null && !visType.isEmpty(); }
    public boolean hasClanRestriction() { return clanRequired != null && !clanRequired.isEmpty(); }
}