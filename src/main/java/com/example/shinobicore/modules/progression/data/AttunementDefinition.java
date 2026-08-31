package com.example.shinobicore.modules.progression.data;

import java.util.List;

public record AttunementDefinition(
    String id,
    String name,
    boolean combined,
    List<String> components
) {}