package com.example.shinobicore.jutsu.data;

import java.util.Map;

public record JutsuDefinition(String id, String name, int tier, float baseCost, Map<String, Integer> requirements) {}