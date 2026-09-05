package com.example.shinobicore.jutsu.progression;

import net.minecraft.nbt.NbtCompound;
import net.minecraft.server.MinecraftServer;
import net.minecraft.world.PersistentState;
import net.minecraft.world.PersistentStateManager;

import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

public class JutsuProgressionState extends PersistentState {
    public final Map<UUID, Map<String, Integer>> levels = new HashMap<>();
    public final Map<UUID, Map<String, Integer>> uses = new HashMap<>();

    @Override
    public NbtCompound writeNbt(NbtCompound nbt) {
        NbtCompound lv = new NbtCompound();
        levels.forEach((uuid, m) -> {
            NbtCompound pm = new NbtCompound();
            m.forEach(pm::putInt);
            lv.put(uuid.toString(), pm);
        });
        nbt.put("levels", lv);
        NbtCompound us = new NbtCompound();
        uses.forEach((uuid, m) -> {
            NbtCompound pm = new NbtCompound();
            m.forEach(pm::putInt);
            us.put(uuid.toString(), pm);
        });
        nbt.put("uses", us);
        return nbt;
    }

    public static JutsuProgressionState fromNbt(NbtCompound nbt) {
        JutsuProgressionState s = new JutsuProgressionState();
        NbtCompound lv = nbt.getCompound("levels");
        for (String uuid : lv.getKeys()) {
            NbtCompound pm = lv.getCompound(uuid);
            Map<String, Integer> m = new HashMap<>();
            for (String id : pm.getKeys()) m.put(id, pm.getInt(id));
            try { s.levels.put(UUID.fromString(uuid), m); } catch (Exception ignored) {}
        }
        NbtCompound us = nbt.getCompound("uses");
        for (String uuid : us.getKeys()) {
            NbtCompound pm = us.getCompound(uuid);
            Map<String, Integer> m = new HashMap<>();
            for (String id : pm.getKeys()) m.put(id, pm.getInt(id));
            try { s.uses.put(UUID.fromString(uuid), m); } catch (Exception ignored) {}
        }
        return s;
    }

    public static JutsuProgressionState get(MinecraftServer server) {
        PersistentStateManager manager = server.getOverworld().getPersistentStateManager();
        return manager.getOrCreate(JutsuProgressionState::fromNbt, JutsuProgressionState::new, "shinobicore_jutsu_progression");
    }

    public int getLevel(UUID uuid, String jutsuId) {
        Map<String, Integer> m = levels.get(uuid);
        return m == null ? 1 : m.getOrDefault(jutsuId, 1);
    }

    public int getUses(UUID uuid, String jutsuId) {
        Map<String, Integer> m = uses.get(uuid);
        return m == null ? 0 : m.getOrDefault(jutsuId, 0);
    }

    public void addUse(UUID uuid, String jutsuId) {
        uses.computeIfAbsent(uuid, k -> new HashMap<>()).merge(jutsuId, 1, Integer::sum);
        markDirty();
    }

    public void setLevel(UUID uuid, String jutsuId, int level) {
        levels.computeIfAbsent(uuid, k -> new HashMap<>()).put(jutsuId, level);
        markDirty();
    }
}