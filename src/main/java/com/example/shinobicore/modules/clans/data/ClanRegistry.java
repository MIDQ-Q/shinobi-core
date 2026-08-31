package com.example.shinobicore.modules.clans.data;
import java.util.Collection;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;
public final class ClanRegistry {
    private static final Map<String, ClanDefinition> CLANS = new ConcurrentHashMap<>();
    public static void register(ClanDefinition clan) { CLANS.put(clan.id(), clan); }
    public static void clear() { CLANS.clear(); }
    public static Optional<ClanDefinition> get(String id) { return Optional.ofNullable(CLANS.get(id)); }
    public static Collection<ClanDefinition> all() { return CLANS.values(); }
    public static int size() { return CLANS.size(); }
}