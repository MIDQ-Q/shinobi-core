package com.example.shinobicore.jutsu.enums;

/**
 * 8 элементов (стихий).
 * Опционально - может быть NONE.
 */
public enum ElementType {
    FIRE("fire", "Огонь", 0xFF6600, "entity.blaze.shoot"),
    WATER("water", "Вода", 0x4488FF, "entity.generic.splash"),
    WIND("wind", "Ветер", 0x88DDAA, "entity.player.attack.sweep"),
    EARTH("earth", "Земля", 0xBB8844, "block.stone.hit"),
    LIGHTNING("lightning", "Молния", 0xFFFF44, "entity.lightning_bolt.thunder"),
    YIN("yin", "Инь", 0xCC66FF, "entity.illusioner.cast_spell"),
    YANG("yang", "Ян", 0xFFFFFF, "entity.player.levelup"),
    NONE("none", "Нет", 0x888888, null);

    private final String id;
    private final String displayName;
    private final int defaultColor;
    private final String defaultSound;

    ElementType(String id, String displayName, int defaultColor, String defaultSound) {
        this.id = id;
        this.displayName = displayName;
        this.defaultColor = defaultColor;
        this.defaultSound = defaultSound;
    }

    public String getId() { return id; }
    public String getDisplayName() { return displayName; }
    public int getDefaultColor() { return defaultColor; }
    public String getDefaultSound() { return defaultSound; }

    public static ElementType fromId(String id) {
        for (ElementType type : values()) {
            if (type.id.equals(id)) return type;
        }
        return NONE;
    }
}