package com.example.shinobicore.modules.jutsu.requirement;

public record RequirementCheckResult(boolean ok, String failReason, float chakraNeeded) {

    public static RequirementCheckResult success() {
        return new RequirementCheckResult(true, "", 0.0f);
    }

    public static RequirementCheckResult fail(String reason) {
        return new RequirementCheckResult(false, reason, 0.0f);
    }

    public static RequirementCheckResult fail(String reason, float chakraNeeded) {
        return new RequirementCheckResult(false, reason, chakraNeeded);
    }

    public static RequirementCheckResult failChakra(float needed) {
        return new RequirementCheckResult(false, "insufficient_chakra", needed);
    }
}