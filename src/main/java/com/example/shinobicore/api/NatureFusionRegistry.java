package com.example.shinobicore.api;
import java.util.HashMap;
import java.util.Map;
public class NatureFusionRegistry {
    private static final Map<String, INatureTransformer> FUSIONS = new HashMap<>();
    public static void register(INatureTransformer transformer) { FUSIONS.put(transformer.getFusionId(), transformer); }
    public static INatureTransformer get(String fusionId) { return FUSIONS.get(fusionId); }
}