package com.example.shinobicore.modules.jutsu.slot;

public record JutsuLoadout(
    String slot0, // A
    String slot1, // B
    String slot2, // C
    int selectedSlot // 0, 1, or 2
) {
    public static JutsuLoadout DEFAULT = new JutsuLoadout(
        "shinobicore:test_projectile", 
        "shinobicore:test_dash", 
        null, 
        0
    );

    public String getSlot(int index) {
        return switch (index) {
            case 0 -> slot0;
            case 1 -> slot1;
            case 2 -> slot2;
            default -> null;
        };
    }

    public JutsuLoadout withSlot(int index, String jutsuId) {
        return switch (index) {
            case 0 -> new JutsuLoadout(jutsuId, slot1, slot2, selectedSlot);
            case 1 -> new JutsuLoadout(slot0, jutsuId, slot2, selectedSlot);
            case 2 -> new JutsuLoadout(slot0, slot1, jutsuId, selectedSlot);
            default -> this;
        };
    }

    public JutsuLoadout withSelected(int index) {
        return new JutsuLoadout(slot0, slot1, slot2, index);
    }
}