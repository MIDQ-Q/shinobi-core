package com.example.shinobicore.jutsu.enums;

/**
 * 6 типов ресурсов для каста.
 */
public enum ResourceType {
    CHAKRA("chakra", "Чакра"),
    FATIGUE("fatigue", "Усталость"),
    HUNGER("hunger", "Голод"),
    HEALTH("health", "Здоровье"),
    ITEM("item", "Предмет"),
    EYE("eye", "Додзюцу-ресурс");

    private final String id;
    private final String displayName;

    ResourceType(String id, String displayName) {
        this.id = id;
        this.displayName = displayName;
    }

    public String getId() { return id; }
    public String getDisplayName() { return displayName; }

    public static ResourceType fromId(String id) {
        for (ResourceType type : values()) {
            if (type.id.equals(id)) return type;
        }
        throw new IllegalArgumentException("Unknown resource type: " + id);
    }
}