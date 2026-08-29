package com.example.shinobicore.stat.component.impl;

import com.example.shinobicore.stat.component.IClanComponent;
import net.minecraft.nbt.NbtCompound;
import java.util.HashMap;
import java.util.Map;

/**
 * Clan component implementation with full NBT serialization.
 * HLD: Section 1.1
 */
public class ClanComponentImpl implements IClanComponent {
    private String clanId = null;
    private final Map<String, Integer> reps = new HashMap<>();

    @Override public String getClanId() { return clanId; }
    @Override public void setClanId(String id) { this.clanId = id; }
    @Override public int getReputation(String t) {
        if (t == null) return 0;
        return reps.getOrDefault(t, 0);
    }
    @Override public int modifyReputation(String t, int a) {
        if (t == null || a == 0) return getReputation(t);
        int v = Math.max(-100, Math.min(100, getReputation(t) + a));
        reps.put(t, v);
        return v;
    }
    @Override public void setReputation(String t, int v) {
        if (t == null) return;
        reps.put(t, Math.max(-100, Math.min(100, v)));
    }
    @Override public Map<String, Integer> getAllReputations() { return new HashMap<>(reps); }
    @Override public boolean isAlly(String t) { return getReputation(t) >= 50; }
    @Override public boolean isEnemy(String t) { return getReputation(t) <= -50; }
    @Override public void resetReputations() { reps.clear(); }

    @Override
    public void readFromNbt(NbtCompound nbt) {
        if (nbt.contains("ClanId")) {
            String stored = nbt.getString("ClanId");
            this.clanId = stored.isEmpty() ? null : stored;
        }
        if (nbt.contains("Reputations")) {
            reps.clear();
            NbtCompound repNbt = nbt.getCompound("Reputations");
            for (String key : repNbt.getKeys()) {
                reps.put(key, repNbt.getInt(key));
            }
        }
    }

    @Override
    public void writeToNbt(NbtCompound nbt) {
        nbt.putString("ClanId", clanId != null ? clanId : "");
        NbtCompound repNbt = new NbtCompound();
        for (Map.Entry<String, Integer> e : reps.entrySet()) {
            repNbt.putInt(e.getKey(), e.getValue());
        }
        nbt.put("Reputations", repNbt);
    }
}