package com.example.shinobicore.ai.v2;

import java.util.Map;

public class AiTierDefinition {
    public String id;
    public String displayName;
    public float healthMultiplier;
    public float speedMultiplier;
    public float damageMultiplier;
    public Map<String, Float> thresholds;
    public boolean canUseEnvironment;
    public boolean canInterruptCasts;
}