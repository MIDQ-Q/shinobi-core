package com.example.shinobicore.stat.component;

public enum StatType {
    NINJUTSU("ninjutsu", "Ninjutsu"),
    TAIJUTSU("taijutsu", "Taijutsu"),
    GENJUTSU("genjutsu", "Genjutsu"),
    KENJUTSU("kenjutsu", "Kenjutsu"),
    SHURIKEN("shuriken", "Shurikenjutsu"),
    CONTROL("control", "Chakra Control"),
    PERCEPTION("perception", "Perception"),
    MEDICAL("medical", "Medical"),
    SPACE_TIME("space_time", "Space-Time"),
    NATURE_FIRE("nature_fire", "Fire Nature"),
    NATURE_WATER("nature_water", "Water Nature"),
    NATURE_WIND("nature_wind", "Wind Nature"),
    NATURE_EARTH("nature_earth", "Earth Nature"),
    NATURE_LIGHTNING("nature_lightning", "Lightning Nature"),
    // SPRINT A: New stats
    PHYSICAL("physical", "Physical"),
    SPIRITUAL("spiritual", "Spiritual"),
    FOCUS("focus", "Focus"),
    WILLPOWER("willpower", "Willpower"),
    INSIGHT("insight", "Insight");

    private final String id;
    private final String displayName;

    StatType(String id, String displayName) {
        this.id = id;
        this.displayName = displayName;
    }

    public String getId() { return id; }
    public String getDisplayName() { return displayName; }

    public static StatType fromId(String id) {
        if (id == null || id.isEmpty()) return null;
        for (StatType t : values()) {
            if (t.id.equals(id)) return t;
        }
        return null;
    }

    public boolean isNature() { return this.name().startsWith("NATURE_"); }

    // SPRINT A: Stat categories
    public StatCategory getCategory() {
        switch (this) {
            case TAIJUTSU: case KENJUTSU: case SHURIKEN: case GENJUTSU:
            case NINJUTSU: case PHYSICAL:
                return StatCategory.COMBAT;
            case CONTROL: case SPIRITUAL: case FOCUS: case WILLPOWER:
                return StatCategory.CHAKRA;
            case PERCEPTION: case INSIGHT: case MEDICAL: case SPACE_TIME:
                return StatCategory.UTILITY;
            case NATURE_FIRE: case NATURE_WATER: case NATURE_WIND:
            case NATURE_EARTH: case NATURE_LIGHTNING:
                return StatCategory.ELEMENT;
            default:
                return StatCategory.UTILITY;
        }
    }

    public enum StatCategory {
        COMBAT, CHAKRA, UTILITY, ELEMENT
    }
}