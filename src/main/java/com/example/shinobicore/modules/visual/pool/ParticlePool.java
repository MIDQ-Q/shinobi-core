package com.example.shinobicore.modules.visual.pool;

import java.util.ArrayList;
import java.util.List;

public final class ParticlePool {
    private static final List<PooledParticle> pool = new ArrayList<>();
    private static int activeCount = 0;

    public static void init(int poolSize) {
        pool.clear();
        activeCount = 0;
        for (int i = 0; i < poolSize; i++) {
            pool.add(new PooledParticle());
        }
    }

    public static PooledParticle acquire() {
        if (activeCount >= pool.size()) return null;
        PooledParticle p = pool.get(activeCount);
        activeCount++;
        return p;
    }

    public static PooledParticle get(int index) {
        return pool.get(index);
    }

    public static void releaseAt(int index) {
        if (activeCount <= 0) return;
        activeCount--;
        if (index != activeCount) {
            PooledParticle temp = pool.get(activeCount);
            pool.set(activeCount, pool.get(index));
            pool.set(index, temp);
        }
        pool.get(index).reset();
    }

    public static int getActiveCount() { return activeCount; }
    public static int getPoolSize() { return pool.size(); }
    
    public static class PooledParticle {
        public float x, y, z;
        public float vx, vy, vz;
        public int color;
        public int lifetime;
        public int age;

        public void init(float x, float y, float z, float vx, float vy, float vz, int color, int lifetime) {
            this.x = x; this.y = y; this.z = z;
            this.vx = vx; this.vy = vy; this.vz = vz;
            this.color = color;
            this.lifetime = lifetime;
            this.age = 0;
        }

        public void reset() { this.age = 0; this.lifetime = 0; }
        public boolean isExpired() { return age >= lifetime; }
    }
}