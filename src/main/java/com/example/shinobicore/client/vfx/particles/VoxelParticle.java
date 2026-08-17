package com.example.shinobicore.client.vfx.particles;

/**
 * S5-05: Single particle data. No entity per particle.
 * Stored in a pool, rendered via instancing.
 */
public class VoxelParticle {
    public float x, y, z;
    public float vx, vy, vz;
    public float r, g, b, a;
    public float size;
    public int life;
    public int maxLife;
    public boolean emissive;
    public float gravity;
    public float drag;

    public VoxelParticle() { reset(); }

    public void reset() {
        x = y = z = 0; vx = vy = vz = 0;
        r = g = b = 1; a = 1;
        size = 0.1f; life = 0; maxLife = 20;
        emissive = false; gravity = 0.02f; drag = 0.98f;
    }

    public void init(float px, float py, float pz,
                     float pvx, float pvy, float pvz,
                     float pr, float pg, float pb, float pa,
                     float pSize, int pLife, boolean pEmissive) {
        x = px; y = py; z = pz;
        vx = pvx; vy = pvy; vz = pvz;
        r = pr; g = pg; b = pb; a = pa;
        size = pSize; life = pLife; maxLife = pLife;
        emissive = pEmissive; gravity = 0.02f; drag = 0.98f;
    }

    public boolean isAlive() { return life > 0; }

    public void update() {
        life--;
        vx *= drag;
        vy = vy * drag - gravity;
        vz *= drag;
        x += vx; y += vy; z += vz;
    }

    public float getAlpha() {
        return a * ((float) life / maxLife);
    }

    public float getSize() {
        return size * (0.5f + 0.5f * ((float) life / maxLife));
    }
}