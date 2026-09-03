package com.example.shinobicore.jutsu.core;

/**
 * Визуальное оформление техники.
 */
public class VisualDefinition {
    private final String particle;
    private final String trailParticle;
    private final String color;
    private final String voxelModel;
    private final double scale;
    private final boolean glow;

    public VisualDefinition(String particle, String trailParticle, String color, String voxelModel, double scale, boolean glow) {
        this.particle = particle;
        this.trailParticle = trailParticle;
        this.color = color;
        this.voxelModel = voxelModel;
        this.scale = scale;
        this.glow = glow;
    }

    public String getParticle() { return particle; }
    public String getTrailParticle() { return trailParticle; }
    public String getColor() { return color; }
    public String getVoxelModel() { return voxelModel; }
    public double getScale() { return scale; }
    public boolean isGlow() { return glow; }
}