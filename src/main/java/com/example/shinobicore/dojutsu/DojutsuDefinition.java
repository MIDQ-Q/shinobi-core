package com.example.shinobicore.dojutsu;

import java.util.List;

public record DojutsuDefinition(
    String id, String name, String clanId,
    List<String> grantedJutsu, float damageMultiplier, float costReduction, String description
) {
    public boolean grantsJutsu(String jutsuId) {
        return grantedJutsu != null && grantedJutsu.contains(jutsuId);
    }
}