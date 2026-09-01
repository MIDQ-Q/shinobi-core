package com.example.shinobicore.pose;

import java.util.Set;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

public class LowPoseTracker {
    private static final Set<UUID> LOW = ConcurrentHashMap.newKeySet();

    public static void set(UUID id, boolean low) {
        if (low) LOW.add(id);
        else LOW.remove(id);
    }

    public static boolean isLow(UUID id) {
        return LOW.contains(id);
    }
}