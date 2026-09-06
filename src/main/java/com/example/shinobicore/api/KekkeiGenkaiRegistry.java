package com.example.shinobicore.api;
import java.util.HashMap;
import java.util.Map;
public class KekkeiGenkaiRegistry {
    private static final Map<String, IDojutsuProvider> DOJUTSU = new HashMap<>();
    public static void register(IDojutsuProvider provider) { DOJUTSU.put(provider.getDojutsuId(), provider); }
    public static IDojutsuProvider get(String dojutsuId) { return DOJUTSU.get(dojutsuId); }
}