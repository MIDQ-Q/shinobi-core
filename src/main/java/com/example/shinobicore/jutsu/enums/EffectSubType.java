package com.example.shinobicore.jutsu.enums;

/**
 * Подтипы эффектов.
 * Каждый тип эффекта имеет свои подтипы.
 */
public enum EffectSubType {
    // === DAMAGE ===
    INSTANT("instant", EffectType.DAMAGE, "Мгновенный урон"),
    DOT("dot", EffectType.DAMAGE, "Урон со временем"),
    PERCENT("percent", EffectType.DAMAGE, "% от макс. HP"),
    TRUE_DAMAGE("true", EffectType.DAMAGE, "Истинный урон"),
    CELLULAR("cellular", EffectType.DAMAGE, "Клеточный урон"),

    // === CONTROL ===
    STUN("stun", EffectType.CONTROL, "Полное оглушение"),
    ROOT("root", EffectType.CONTROL, "Обездвиживание"),
    SILENCE("silence", EffectType.CONTROL, "Запрет каста"),
    BLIND("blind", EffectType.CONTROL, "Ослепление"),
    FEAR("fear", EffectType.CONTROL, "Паника"),
    CONFUSION("confusion", EffectType.CONTROL, "Дезориентация"),
    SLEEP("sleep", EffectType.CONTROL, "Сон"),
    PARALYSIS("paralysis", EffectType.CONTROL, "Паралич"),
    PULL("pull", EffectType.CONTROL, "Притягивание"),
    PUSH("push", EffectType.CONTROL, "Отталкивание"),
    LAUNCH("launch", EffectType.CONTROL, "Подбрасывание"),

    // === BUFF ===
    HEAL("heal", EffectType.BUFF, "Лечение"),
    REGEN("regen", EffectType.BUFF, "Регенерация"),
    CHAKRA_REGEN("chakra_regen", EffectType.BUFF, "Регенерация чакры"),
    SHIELD("shield", EffectType.BUFF, "Щит"),
    SPEED("speed", EffectType.BUFF, "Ускорение"),
    STRENGTH("strength", EffectType.BUFF, "Увеличение урона"),
    RESISTANCE("resistance", EffectType.BUFF, "Снижение урона"),
    HASTE("haste", EffectType.BUFF, "Ускорение каста"),
    INVISIBILITY("invisibility", EffectType.BUFF, "Невидимость"),
    PURIFY("purify", EffectType.BUFF, "Снятие дебаффов"),

    // === DEBUFF ===
    BURN("burn", EffectType.DEBUFF, "Горение"),
    POISON("poison", EffectType.DEBUFF, "Отравление"),
    SLOW("slow", EffectType.DEBUFF, "Замедление"),
    WEAKNESS("weakness", EffectType.DEBUFF, "Снижение урона"),
    VULNERABILITY("vulnerability", EffectType.DEBUFF, "Увеличение урона"),
    BLEED("bleed", EffectType.DEBUFF, "Кровотечение"),
    CURSE("curse", EffectType.DEBUFF, "Проклятие"),
    EXHAUSTION("exhaustion", EffectType.DEBUFF, "Усиление усталости"),
    CHAKRA_DRAIN("chakra_drain", EffectType.DEBUFF, "Поглощение чакры"),

    // === WORLD ===
    PLACE_BLOCK("place_block", EffectType.WORLD, "Поставить блок"),
    REMOVE_BLOCK("remove_block", EffectType.WORLD, "Удалить блок"),
    TRANSFORM_BLOCK("transform_block", EffectType.WORLD, "Трансформировать блок"),
    IGNITE("ignite", EffectType.WORLD, "Поджечь блоки"),
    FREEZE("freeze", EffectType.WORLD, "Заморозить воду"),
    CREATE_ENTITY("create_entity", EffectType.WORLD, "Создать сущность");

    private final String id;
    private final EffectType parentType;
    private final String displayName;

    EffectSubType(String id, EffectType parentType, String displayName) {
        this.id = id;
        this.parentType = parentType;
        this.displayName = displayName;
    }

    public String getId() { return id; }
    public EffectType getParentType() { return parentType; }
    public String getDisplayName() { return displayName; }

    public static EffectSubType fromId(String id) {
        for (EffectSubType type : values()) {
            if (type.id.equals(id)) return type;
        }
        throw new IllegalArgumentException("Unknown effect subtype: " + id);
    }
}