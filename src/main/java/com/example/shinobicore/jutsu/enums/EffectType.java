package com.example.shinobicore.jutsu.enums;

/**
 * 5 типов эффектов техники.
 * Определяет ЧТО происходит при срабатывании.
 */
public enum EffectType {
    DAMAGE("damage", "Урон"),
    CONTROL("control", "Контроль"),
    BUFF("buff", "Бафф"),
    DEBUFF("debuff", "Дебафф"),
    WORLD("world", "Мир");

    private final String id;
    private final String displayName;

    EffectType(String id, String displayName) {
        this.id = id;
        this.displayName = displayName;
    }

    public String getId() { return id; }
    public String getDisplayName() { return displayName; }

    public static EffectType fromId(String id) {
        for (EffectType type : values()) {
            if (type.id.equals(id)) return type;
        }
        throw new IllegalArgumentException("Unknown effect type: " + id);
    }
}