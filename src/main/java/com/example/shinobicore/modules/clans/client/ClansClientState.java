package com.example.shinobicore.modules.clans.client;
public final class ClansClientState {
    private static String clanId = "none";
    private static String clanName = "No Clan";
    private static String clanColor = "#FFFFFF";
    public static String getClanId() { return clanId; }
    public static String getClanName() { return clanName; }
    public static String getClanColor() { return clanColor; }
    public static void update(String id, String name, String color) {
        clanId = id != null ? id : "none";
        clanName = name != null ? name : "No Clan";
        clanColor = color != null ? color : "#FFFFFF";
    }
    public static void reset() {
        clanId = "none";
        clanName = "No Clan";
        clanColor = "#FFFFFF";
    }
}