package com.example.shinobicore.modules.progression.client;

import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;

public final class ProgressionClientState {
    public static int level = 1;
    public static int xp = 0;
    public static int sp = 0;
    public static final Set<String> unlockedNodes = new HashSet<>();
    public static final Set<String> unlockedElements = new HashSet<>();
    public static final Map<String, Integer> statLevels = new HashMap<>();
    public static final Map<String, Integer> bodyStatLevels = new HashMap<>();

    private ProgressionClientState() {}

    public static void update(int lvl, int currentXp, int currentSp,
            String[] nodes, String[] elements,
            String[] statIds, int[] statVals,
            String[] bodyIds, int[] bodyVals) {

        level = lvl;
        xp = currentXp;
        sp = currentSp;

        unlockedNodes.clear();
        if (nodes != null) for (String n : nodes) unlockedNodes.add(n);

        unlockedElements.clear();
        if (elements != null) for (String e : elements) unlockedElements.add(e);

        statLevels.clear();
        if (statIds != null) {
            for (int i = 0; i < statIds.length; i++) {
                statLevels.put(statIds[i], statVals[i]);
            }
        }

        bodyStatLevels.clear();
        if (bodyIds != null) {
            for (int i = 0; i < bodyIds.length; i++) {
                bodyStatLevels.put(bodyIds[i], bodyVals[i]);
            }
        }
    }
}