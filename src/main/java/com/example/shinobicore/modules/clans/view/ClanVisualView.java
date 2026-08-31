package com.example.shinobicore.modules.clans.view;

import java.util.List;
import java.util.Map;

public interface ClanVisualView {
    String getClanId();
    boolean hasClan();
    String getClanName();
    String getClanColor();
    String getAffinity();
    int getExtraAffinityCount();
    boolean hasDojutsuHook();
    String getDojutsuId();
    List<String> getStartingJutsu();
    int getReputation(String factionId);
    Map<String, Integer> getAllReputations();
}