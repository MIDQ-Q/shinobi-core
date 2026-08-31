package com.example.shinobicore.modules.progression.data;

import java.util.List;

public record TreeNodeDefinition(
    String id,
    String branch,
    int distance,
    String type,
    String jutsuId,
    int spCost,
    List<String> requires,
    String icon,
    String name,
    String description,
    String clanRequired
) {}