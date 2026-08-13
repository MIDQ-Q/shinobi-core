package com.example.shinobicore.client;
import net.minecraft.client.network.AbstractClientPlayerEntity;
import java.util.HashMap;
import java.util.Map;
import java.util.UUID;
public class CastingClientState {
    public static class Cast {
        public final long start; public final String nature;
        public Cast(long start, String nature) { this.start = start; this.nature = nature; }
    }
    private static final Map<UUID, Cast> CASTS = new HashMap<>();
    public static void startCast(UUID id, String nature) { CASTS.put(id, new Cast(System.currentTimeMillis(), nature)); }
    public static Cast get(AbstractClientPlayerEntity p) {
        Cast c = CASTS.get(p.getUuid());
        if (c == null) return null;
        if (System.currentTimeMillis() - c.start > 500) { CASTS.remove(p.getUuid()); return null; }
        return c;
    }
    public static boolean isCasting(AbstractClientPlayerEntity p) { return get(p) != null; }
    public static int color(String nature) {
        return switch (nature) {
            case "fire" -> 0xFFFF6622;
            case "water" -> 0xFF4488FF;
            case "wind" -> 0xFF88DDAA;
            case "lightning" -> 0xFFFFEE44;
            case "earth" -> 0xFFBB8844;
            default -> 0xFF88AAFF;
        };
    }
}