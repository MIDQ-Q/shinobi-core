package com.example.shinobicore.faction;
import dev.onyxstudios.cca.api.v3.component.sync.AutoSyncedComponent;
import net.minecraft.nbt.NbtCompound;
import java.util.HashMap;
import java.util.Map;
public class ReputationComponentImpl implements ReputationComponent, AutoSyncedComponent {
    private final Map<String, Integer> reputations = new HashMap<>();
    @Override public int getReputation(String factionId) { return reputations.getOrDefault(factionId, 0); }
    @Override public void addReputation(String factionId, int amount) { reputations.put(factionId, getReputation(factionId) + amount); }
    @Override public Map<String, Integer> getAllReputations() { return reputations; }
    @Override public void readFromNbt(NbtCompound tag) { reputations.clear(); for (String key : tag.getKeys()) { reputations.put(key, tag.getInt(key)); } }
    @Override public void writeToNbt(NbtCompound tag) { for (Map.Entry<String, Integer> entry : reputations.entrySet()) { tag.putInt(entry.getKey(), entry.getValue()); } }
}