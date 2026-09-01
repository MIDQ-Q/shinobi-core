package com.example.shinobicore.stat;

public enum StatType {
    CONTROL("control"),
    NINJUTSU("ninjutsu"),
    TAIJUTSU("taijutsu"),
    GENJUTSU("genjutsu"),
    MEDICAL("medical"),
    SPACE_TIME("space_time"),
    PERCEPTION("perception");

    private final String id;

    StatType(String id) {
        this.id = id;
    }

    public String getId() {
        return id;
    }
}