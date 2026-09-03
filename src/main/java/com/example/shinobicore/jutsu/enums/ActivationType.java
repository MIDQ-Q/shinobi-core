package com.example.shinobicore.jutsu.enums;

/**
 * 9 типов активации техники.
 * Активация - параметр техники, не отдельный слой.
 */
public enum ActivationType {
    INSTANT("instant", "Мгновенная"),
    HANDSEALS("handseals", "Печати рук"),
    CHARGE("charge", "Зарядка"),
    HOLD("hold", "Удержание"),
    COMBO("combo", "Комбо-активация"),
    COUNTER("counter", "Контратака"),
    ON_DEATH("on_death", "При смерти"),
    PASSIVE("passive", "Пассивная"),
    CONDITIONAL("conditional", "По условию");

    private final String id;
    private final String displayName;

    ActivationType(String id, String displayName) {
        this.id = id;
        this.displayName = displayName;
    }

    public String getId() { return id; }
    public String getDisplayName() { return displayName; }

    public static ActivationType fromId(String id) {
        for (ActivationType type : values()) {
            if (type.id.equals(id)) return type;
        }
        return INSTANT;
    }
}