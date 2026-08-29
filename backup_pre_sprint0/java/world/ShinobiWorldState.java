package com.example.shinobicore.world;

import net.minecraft.nbt.NbtCompound;
import net.minecraft.server.MinecraftServer;
import net.minecraft.world.PersistentState;
import net.minecraft.world.PersistentStateManager;
import net.minecraft.world.World;

import java.util.HashMap;
import java.util.Map;

/**
 * Server-side persistent state tracking ninja kill counts by rank
 * and total enemies spawned.
 * HLD: Section 5 (Enemy AI persistence across world reloads).
 * Sprint 3 deliverable.
 */
public class ShinobiWorldState extends PersistentState {

    private static final String KEY = "shinobicore_state";

    private final Map<String, Integer> kills = new HashMap<>();
    private int totalSpawned = 0;

    public static ShinobiWorldState get(MinecraftServer server) {
        PersistentStateManager mgr = server.getOverworld().getPersistentStateManager();
        return mgr.getOrCreate(
            ShinobiWorldState::createFromNbt,
            ShinobiWorldState::new,
            KEY);
    }

    /**
     * Factory method for deserialization (required by getOrCreate API).
     */
    public static ShinobiWorldState createFromNbt(NbtCompound nbt) {
        ShinobiWorldState state = new ShinobiWorldState();
        state.readNbt(nbt);
        return state;
    }

    public void addKill(String rank) {
        kills.merge(rank, 1, Integer::sum);
        this.markDirty();
    }

    public int getKills(String rank) {
        return kills.getOrDefault(rank, 0);
    }

    public void addSpawn() {
        totalSpawned++;
        this.markDirty();
    }

    public int getTotalSpawned() {
        return totalSpawned;
    }

    public Map<String, Integer> getAllKills() {
        return new HashMap<>(kills);
    }

    @Override
    public NbtCompound writeNbt(NbtCompound nbt) {
        NbtCompound killsNbt = new NbtCompound();
        for (Map.Entry<String, Integer> e : kills.entrySet()) {
            killsNbt.putInt(e.getKey(), e.getValue());
        }
        nbt.put("Kills", killsNbt);
        nbt.putInt("TotalSpawned", totalSpawned);
        return nbt;
    }

    public void readNbt(NbtCompound nbt) {
        kills.clear();
        if (nbt.contains("Kills")) {
            NbtCompound killsNbt = nbt.getCompound("Kills");
            for (String key : killsNbt.getKeys()) {
                kills.put(key, killsNbt.getInt(key));
            }
        }
        if (nbt.contains("TotalSpawned")) {
            totalSpawned = nbt.getInt("TotalSpawned");
        }
    }
}