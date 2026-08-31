package com.example.shinobicore.combat;
import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.jutsu.JutsuCaster;
import com.example.shinobicore.stat.NinjaDataHolder;
import com.example.shinobicore.stat.NinjaFormula;
import com.example.shinobicore.stat.NinjaPlayerData;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.text.Text;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;
public class CastingServerState {
    public static class ActiveCast {
        public final String jutsuId;
        public final long startTimeMs;
        public final int durationTicks;
        public final float chakraCost;
        public ActiveCast(String jutsuId, int durationTicks, float chakraCost) {
            this.jutsuId = jutsuId;
            this.startTimeMs = System.currentTimeMillis();
            this.durationTicks = durationTicks;
            this.chakraCost = chakraCost;
        }
        public boolean isComplete() {
            return System.currentTimeMillis() - startTimeMs >= (durationTicks * 50L);
        }
        public float getProgress() {
            long elapsed = System.currentTimeMillis() - startTimeMs;
            return Math.min(1f, (float) elapsed / (durationTicks * 50L));
        }
    }
    private static final Map<UUID, ActiveCast> ACTIVE = new ConcurrentHashMap<>();
    public static void startCast(ServerPlayerEntity player, String jutsuId, int durationTicks, float chakraCost) {
        ACTIVE.put(player.getUuid(), new ActiveCast(jutsuId, durationTicks, chakraCost));
    }
    public static boolean isCasting(ServerPlayerEntity player) {
        ActiveCast c = ACTIVE.get(player.getUuid());
        return c != null && !c.isComplete();
    }
    public static ActiveCast getActive(ServerPlayerEntity player) {
        return ACTIVE.get(player.getUuid());
    }
    public static void tickPlayer(ServerPlayerEntity player) {
        ActiveCast cast = ACTIVE.get(player.getUuid());
        if (cast == null) return;
        if (cast.isComplete()) {
            ACTIVE.remove(player.getUuid());
            JutsuCaster.executeCast(player, cast.jutsuId);
        }
    }
    public static void interruptCast(ServerPlayerEntity player) {
        ActiveCast cast = ACTIVE.remove(player.getUuid());
        if (cast == null) return;
        NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
        float refund = cast.chakraCost * 0.5f;
        data.setCurrentChakra(Math.min(data.getCurrentChakra() + refund, NinjaFormula.maxChakra(data)));
        ShinobiCore.sendChakraSync(player);
        ShinobiCore.broadcastCastInterrupt(player);
        player.sendMessage(Text.literal("\u00a7cJutsu interrupted! (-" + (int)(cast.chakraCost * 0.5f) + " chakra lost)"), false);
    }
    public static void clearAll() { ACTIVE.clear(); }
}