package com.example.shinobicore.stat;

public enum StatType {
    NINJUTSU("Ninjutsu"),
    TAIJUTSU("Taijutsu"),
    GENJUTSU("Genjutsu"),
    KENJUTSU("Kenjutsu"),
    SHURIKEN("Shurikenjutsu"),
    CONTROL("Control"),
    NATURE_FIRE("Fire Nature"),
    NATURE_WATER("Water Nature"),
    NATURE_WIND("Wind Nature"),
    NATURE_EARTH("Earth Nature"),
    NATURE_LIGHTNING("Lightning Nature"),
    PERCEPTION("Perception"),
    MEDICAL("Medical"),
    FUUIN("Fuuinjutsu"),
    SPACE_TIME("Space-Time");

    private final String displayName;
    StatType(String displayName) { this.displayName = displayName; }
    public String getDisplayName() { return displayName; }
    public String getId() { return name().toLowerCase(); }

    public static StatType fromString(String id) {
        if (id == null || id.isEmpty()) return null;
        try {
            return StatType.valueOf(id.toUpperCase());
        } catch (IllegalArgumentException e) {
            String lowerId = id.toLowerCase();
            for (StatType type : values()) {
                if (type.getId().equals(lowerId)) return type;
            }
            return null;
        }
    }

    public boolean isNature() { return this.name().startsWith("NATURE_"); }
}