package com.example.shinobicore.stat.component;

import dev.onyxstudios.cca.api.v3.component.ComponentV3;
import dev.onyxstudios.cca.api.v3.component.sync.AutoSyncedComponent;
import java.util.Map;
import java.util.Set;

/**
 * Jutsu component. Stores learned jutsus, loadouts, mastery.
 * HLD: Section 1.1, JutsuComponent table.
 */
public interface IJutsuComponent extends ComponentV3, AutoSyncedComponent {
    Set<String> getLearnedJutsus();
    boolean hasLearned(String jutsuId);
    boolean learnJutsu(String jutsuId);
    void forgetJutsu(String jutsuId);
    String getLoadoutSlot(int loadoutIndex, int slotIndex);
    boolean setLoadoutSlot(int loadoutIndex, int slotIndex, String jutsuId);
    String[] getLoadout(int loadoutIndex);
    int getMasteryUses(String jutsuId);
    boolean addMasteryUse(String jutsuId);
    void setMasteryUses(String jutsuId, int uses);
    Map<String, Integer> getAllMasteryUses();
    int getActiveLoadout();
    void setActiveLoadout(int loadoutIndex);
    void toggleLoadout();
    void resetAll();
}