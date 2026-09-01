package com.example.shinobicore.stat;

public enum ClanType {
    NONE("none"),
    UCHIHA("uchiha"),
    HYUGA("hyuga"),
    UZUMAKI("uzumaki"),
    NARA("nara"),
    HATAKE("hatake"),
    SARUTOBI("sarutobi");

    private final String id;

    ClanType(String id) {
        this.id = id;
    }

    public String getId() {
        return id;
    }
}