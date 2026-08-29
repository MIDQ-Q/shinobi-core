package com.example.shinobicore.stat;

public enum ElementType {
    FIRE("fire"),
    WATER("water"),
    WIND("wind"),
    LIGHTNING("lightning"),
    EARTH("earth");

    private final String id;

    ElementType(String id) {
        this.id = id;
    }

    public String getId() {
        return id;
    }
}