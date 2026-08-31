package com.example.shinobicore.modules.visual.pool;

import java.util.ArrayList;
import java.util.List;

public final class TrailPool {
    private static final List<PooledTrail> pool = new ArrayList<>();
    private static int activeCount = 0;

    public static void init(int poolSize) {
        pool.clear();
        activeCount = 0;
        for (int i = 0; i < poolSize; i++) {
            pool.add(new PooledTrail());
        }
    }

    public static PooledTrail acquire() {
        if (activeCount >= pool.size()) return null;
        PooledTrail t = pool.get(activeCount);
        activeCount++;
        return t;
    }

    public static PooledTrail get(int index) {
        return pool.get(index);
    }

    public static void releaseAt(int index) {
        if (activeCount <= 0) return;
        activeCount--;
        if (index != activeCount) {
            PooledTrail temp = pool.get(activeCount);
            pool.set(activeCount, pool.get(index));
            pool.set(index, temp);
        }
        pool.get(index).reset();
    }

    public static int getActiveCount() { return activeCount; }
    
    public static class PooledTrail {
        public float startX, startY, startZ;
        public float endX, endY, endZ;
        public int color;
        public float width;
        public int lifetime;
        public int age;

        public void init(float sx, float sy, float sz, float ex, float ey, float ez, int color, float width, int lifetime) {
            this.startX = sx; this.startY = sy; this.startZ = sz;
            this.endX = ex; this.endY = ey; this.endZ = ez;
            this.color = color; this.width = width; this.lifetime = lifetime; this.age = 0;
        }

        public void reset() { this.age = 0; this.lifetime = 0; }
        public boolean isExpired() { return age >= lifetime; }
    }
}