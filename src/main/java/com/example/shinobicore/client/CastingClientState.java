package com.example.shinobicore.client;
import net.minecraft.client.network.AbstractClientPlayerEntity;
import com.example.shinobicore.util.TimedCache;
import java.util.UUID;
public class CastingClientState {
    public static class Cast {
        public final long start; public final String nature;
        public Cast(long start, String nature) { this.start = start; this.nature = nature; }
    }
    private static final TimedCache<UUID, Cast> CASTS = new TimedCache<>(600);
    public static void startCast(UUID id, String nature) { CASTS.put(id, new Cast(System.currentTimeMillis(), nature)); }
    public static Cast get(AbstractClientPlayerEntity p) {
        return CASTS.get(p.getUuid());
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

    public static void clear() {
        CASTS.clear();
    }

    public static int size() {
        return CASTS.size();
    }

    public static void cleanup() {
        CASTS.cleanup();
    }
}