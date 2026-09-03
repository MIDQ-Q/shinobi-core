package com.example.shinobicore.jutsu.enums;

/**
 * 8 примитивов формы техники.
 * Определяет КАК техника доставляется/проявляется.
 */
public enum FormType {
    POINT("point", "Точка", "Эффект на себе или на цели вблизи"),
    PROJECTILE("projectile", "Снаряд", "Летящий объект с траекторией"),
    BEAM("beam", "Луч", "Непрерывный поток"),
    ZONE("zone", "Зона", "Область с эффектом"),
    DASH("dash", "Рывок", "Кастер летит к цели"),
    SUMMON("summon", "Призыв", "Появление сущности"),
    CONSTRUCT("construct", "Конструкт", "Создание объекта из блоков"),
    HANDHELD("handheld", "Ручной конструкт", "Объект в руке кастера");

    private final String id;
    private final String displayName;
    private final String description;

    FormType(String id, String displayName, String description) {
        this.id = id;
        this.displayName = displayName;
        this.description = description;
    }

    public String getId() { return id; }
    public String getDisplayName() { return displayName; }
    public String getDescription() { return description; }

    public static FormType fromId(String id) {
        for (FormType type : values()) {
            if (type.id.equals(id)) return type;
        }
        throw new IllegalArgumentException("Unknown form type: " + id);
    }
}