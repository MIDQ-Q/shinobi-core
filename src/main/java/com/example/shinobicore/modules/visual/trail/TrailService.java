package com.example.shinobicore.modules.visual.trail;

import com.example.shinobicore.modules.visual.pool.TrailPool;

public final class TrailService {
    public static void init() {}

    public static void tick() {
        for (int i = 0; i < TrailPool.getActiveCount(); i++) {
            TrailPool.PooledTrail t = TrailPool.get(i);
            t.age++;
            if (t.isExpired()) {
                TrailPool.releaseAt(i);
                i--;
            }
        }
    }

    public static void spawnTrail(float sx, float sy, float sz, float ex, float ey, float ez, int color, float width, int lifetime) {
        TrailPool.PooledTrail t = TrailPool.acquire();
        if (t == null) return;
        t.init(sx, sy, sz, ex, ey, ez, color, width, lifetime);
    }
}