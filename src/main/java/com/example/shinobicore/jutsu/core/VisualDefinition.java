package com.example.shinobicore.jutsu.core;

/**
 * Визуальное оформление техники.
 *
 * ToolsPack 2 (1.1.3): добавлены СТИЛИ эффектов — строковые id хореографий
 * из Fx.java. Пустой/неизвестный стиль = "default" (поведение ToolsPack 1).
 * Каталог стилей: docs/formats/fx_styles.md, подбор в Studio -> FX Lab.
 *
 *   trailStyle  : default | ribbon | helix | smoke | sparks | lightning
 *   impactStyle : default | nova | shockwave | implosion
 *   castStyle   : default | runes | pillars | spiral
 *   zoneStyle   : default | dome | rune_circle | vortex | wall
 *   beamStyle   : default | lightning | spiral | pulse
 */
public class VisualDefinition {
    private final String particle;
    private final String trailParticle;
    private final String color;
    private final String voxelModel;
    private final double scale;
    private final boolean glow;
    private final String trailStyle;
    private final String impactStyle;
    private final String castStyle;
    private final String zoneStyle;
    private final String beamStyle;

    /** Совместимость с ToolsPack 1 и всеми существующими вызовами. */
    public VisualDefinition(String particle, String trailParticle, String color, String voxelModel, double scale, boolean glow) {
        this(particle, trailParticle, color, voxelModel, scale, glow, null, null, null, null, null);
    }

    public VisualDefinition(String particle, String trailParticle, String color, String voxelModel, double scale, boolean glow,
                            String trailStyle, String impactStyle, String castStyle, String zoneStyle, String beamStyle) {
        this.particle = particle;
        this.trailParticle = trailParticle;
        this.color = color;
        this.voxelModel = voxelModel;
        this.scale = scale;
        this.glow = glow;
        this.trailStyle = trailStyle;
        this.impactStyle = impactStyle;
        this.castStyle = castStyle;
        this.zoneStyle = zoneStyle;
        this.beamStyle = beamStyle;
    }

    public String getParticle() { return particle; }
    public String getTrailParticle() { return trailParticle; }
    public String getColor() { return color; }
    public String getVoxelModel() { return voxelModel; }
    public double getScale() { return scale; }
    public boolean isGlow() { return glow; }
    public String getTrailStyle() { return trailStyle; }
    public String getImpactStyle() { return impactStyle; }
    public String getCastStyle() { return castStyle; }
    public String getZoneStyle() { return zoneStyle; }
    public String getBeamStyle() { return beamStyle; }
}