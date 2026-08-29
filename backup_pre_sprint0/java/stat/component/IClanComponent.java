package com.example.shinobicore.stat.component;

import dev.onyxstudios.cca.api.v3.component.ComponentV3;
import dev.onyxstudios.cca.api.v3.component.sync.AutoSyncedComponent;
import java.util.Map;

/**
 * Clan component. Stores clan membership and reputations.
 * HLD: Section 1.1, ClanComponent table.
 */
public interface IClanComponent extends ComponentV3, AutoSyncedComponent {
    String getClanId();
    void setClanId(String clanId);
    int getReputation(String targetClanId);
    int modifyReputation(String targetClanId, int amount);
    void setReputation(String targetClanId, int value);
    Map<String, Integer> getAllReputations();
    boolean isAlly(String targetClanId);
    boolean isEnemy(String targetClanId);
    void resetReputations();
}