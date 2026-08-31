package com.example.shinobicore.modules.progression.view;

import com.example.shinobicore.modules.progression.component.ProgressionComponent;
import com.example.shinobicore.modules.progression.component.ProgressionComponentKey;
import com.example.shinobicore.modules.progression.config.ProgressionConfig;
import com.example.shinobicore.modules.progression.service.ProgressionFormula;
import net.minecraft.entity.player.PlayerEntity;

import java.util.Optional;

public class ProgressionVisualViewImpl implements ProgressionVisualView {
    private final ProgressionComponent comp;

    public ProgressionVisualViewImpl(PlayerEntity player) {
        Optional<ProgressionComponent> opt = ProgressionComponentKey.get(player);
        this.comp = opt.orElse(null);
    }

    @Override public int getPlayerLevel() { return comp != null ? comp.getPlayerLevel() : 1; }
    @Override public int getCurrentXp() { return comp != null ? comp.getCurrentXp() : 0; }
    @Override public int getAvailableSp() { return comp != null ? comp.getAvailableSp() : 0; }

    @Override
    public int getXpToNextLevel() {
        if (comp == null) return 100;
        return ProgressionFormula.xpForLevel(comp.getPlayerLevel() + 1, ProgressionConfig.get());
    }

    @Override
    public float getProgressToNextLevel() {
        if (comp == null) return 0.0f;
        int needed = getXpToNextLevel();
        if (needed <= 0) return 1.0f;
        return (float) comp.getCurrentXp() / (float) needed;
    }

    @Override
    public int getStatLevel(String statId) {
        return comp != null ? comp.getStatLevel(statId) : 0;
    }

    @Override
    public int getBodyStatLevel(String bodyStatId) {
        return comp != null ? comp.getBodyStatLevel(bodyStatId) : 0;
    }

    @Override
    public int getJutsuLevel(String jutsuId) {
        return comp != null ? comp.getJutsuLevel(jutsuId) : 0;
    }

    @Override
    public boolean isNodeUnlocked(String nodeId) {
        return comp != null && comp.isNodeUnlocked(nodeId);
    }

    @Override
    public boolean isElementUnlocked(String elementId) {
        return comp != null && comp.isElementUnlocked(elementId);
    }

    @Override
    public float getAttunementProgress(String elementId) {
        return comp != null ? comp.getAttunementProgress(elementId) : 0.0f;
    }

    @Override
    public int getReputation(String factionId) {
        return comp != null ? comp.getReputation(factionId) : 0;
    }
}