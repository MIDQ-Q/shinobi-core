package com.example.shinobicore.modules.clans.component;
import dev.onyxstudios.cca.api.v3.component.Component;
import dev.onyxstudios.cca.api.v3.component.sync.AutoSyncedComponent;
import net.minecraft.nbt.NbtCompound;
import java.util.HashMap;
import java.util.Map;
public class ClanComponent implements Component, AutoSyncedComponent {
    private String clanId = "none";
    private final Map<String, Integer> reputation = new HashMap<>();
    public String getClanId() { return clanId; }
    public void setClanId(String id) { this.clanId = id != null ? id : "none"; }
    public int getReputation(String faction) { return reputation.getOrDefault(faction, 0); }
    public void setReputation(String faction, int value) { reputation.put(faction, value); }
    public void clearReputation() { reputation.clear(); }
    public Map<String, Integer> getAllReputations() { return new HashMap<>(reputation); }
    @Override
    public void readFromNbt(NbtCompound tag) {
        if (tag.contains("ClanId")) clanId = tag.getString("ClanId");
        if (tag.contains("Reputation")) {
            reputation.clear();
            NbtCompound repTag = tag.getCompound("Reputation");
            for (String key : repTag.getKeys()) reputation.put(key, repTag.getInt(key));
        }
    }
    @Override
    public void writeToNbt(NbtCompound tag) {
        tag.putString("ClanId", clanId);
        NbtCompound repTag = new NbtCompound();
        for (Map.Entry<String, Integer> entry : reputation.entrySet()) repTag.putInt(entry.getKey(), entry.getValue());
        tag.put("Reputation", repTag);
    }
}