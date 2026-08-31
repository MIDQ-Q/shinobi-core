package com.example.shinobicore.modules.clans.view;

import com.example.shinobicore.modules.clans.component.ClanComponent;
import com.example.shinobicore.modules.clans.component.ClanComponentKey;
import com.example.shinobicore.modules.clans.data.ClanDefinition;
import com.example.shinobicore.modules.clans.data.ClanRegistry;
import net.minecraft.entity.player.PlayerEntity;
import java.util.Collections;
import java.util.List;
import java.util.Map;
import java.util.Optional;

public class ClanVisualViewImpl implements ClanVisualView {
    private final PlayerEntity player;

    public ClanVisualViewImpl(PlayerEntity player) {
        this.player = player;
    }

    private Optional<ClanComponent> comp() {
        return ClanComponentKey.get(player);
    }

    private Optional<ClanDefinition> def() {
        return comp().flatMap(c -> ClanRegistry.get(c.getClanId()));
    }

    @Override
    public String getClanId() {
        return comp().map(ClanComponent::getClanId).orElse(null);
    }

    @Override
    public boolean hasClan() {
        String id = getClanId();
        return id != null && !id.isEmpty() && !"none".equals(id);
    }

    @Override
    public String getClanName() {
        return def().map(ClanDefinition::name).orElse("No Clan");
    }

    @Override
    public String getClanColor() {
        return def().map(ClanDefinition::color).orElse("#FFFFFF");
    }

    @Override
    public String getAffinity() {
        return def().map(ClanDefinition::affinity).orElse("none");
    }

    @Override
    public int getExtraAffinityCount() {
        return def().map(ClanDefinition::extraAffinityCount).orElse(0);
    }

    @Override
    public boolean hasDojutsuHook() {
        return def().map(d -> d.dojutsuHook() != null).orElse(false);
    }

    @Override
    public String getDojutsuId() {
        return def().map(ClanDefinition::dojutsuHook).orElse(null);
    }

    @Override
    public List<String> getStartingJutsu() {
        return def().map(ClanDefinition::startingJutsu).orElse(Collections.emptyList());
    }

    @Override
    public int getReputation(String factionId) {
        return comp().map(c -> c.getReputation(factionId)).orElse(0);
    }

    @Override
    public Map<String, Integer> getAllReputations() {
        return comp().map(ClanComponent::getAllReputations).orElse(Collections.emptyMap());
    }
}