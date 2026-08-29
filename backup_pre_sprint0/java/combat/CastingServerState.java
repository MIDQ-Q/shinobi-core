package com.example.shinobicore.combat;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.jutsu.JutsuCaster;
import com.example.shinobicore.jutsu.JutsuDefinition;
import com.example.shinobicore.jutsu.JutsuRegistry;
import com.example.shinobicore.stat.NinjaDataHolder;
import com.example.shinobicore.stat.NinjaFormula;
import com.example.shinobicore.stat.NinjaPlayerData;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.text.Text;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

/**
* S1-05: Casting state with chargeable jutsu support.
* Flow: castTime -> chargePhase (if chargeable) -> executeCast
*/
public class CastingServerState {

    public static class ActiveCast {
        public final String jutsuId;
        public final long startTimeMs;
        public final int durationTicks;
        public final float chakraCost;
        // S1-05: Charge support
        public final boolean chargeable;
        public final float chargeMax;
        public boolean chargePhase = false;
        public long chargeStartTimeMs = 0;
        public int chargeMaxTicks = 0;

        public ActiveCast(String jutsuId, int durationTicks, float chakraCost,
                          boolean chargeable, float chargeMax) {
            this.jutsuId = jutsuId;
            this.startTimeMs = System.currentTimeMillis();
            this.durationTicks = durationTicks;
            this.chakraCost = chakraCost;
            this.chargeable = chargeable;
            this.chargeMax = chargeMax;
        }

        public boolean isCastComplete() {
            return System.currentTimeMillis() - startTimeMs >= (durationTicks * 50L);
        }

        public float getProgress() {
            long elapsed = System.currentTimeMillis() - startTimeMs;
            return Math.min(1f, (float) elapsed / (durationTicks * 50L));
        }

        public void startChargePhase() {
            this.chargePhase = true;
            this.chargeStartTimeMs = System.currentTimeMillis();
            this.chargeMaxTicks = (int)(chargeMax * 20);
        }

        public boolean isChargeComplete() {
            if (!chargePhase) return false;
            long elapsed = System.currentTimeMillis() - chargeStartTimeMs;
            return elapsed >= (chargeMaxTicks * 50L);
        }

        public float getChargeLevel() {
            if (!chargePhase || !chargeable) return 1.0f;
            long elapsed = System.currentTimeMillis() - chargeStartTimeMs;
            return Math.min(1f, (float) elapsed / (chargeMaxTicks * 50L));
        }
    }

    private static final Map<UUID, ActiveCast> ACTIVE = new ConcurrentHashMap<>();

    public static void startCast(ServerPlayerEntity player, String jutsuId,
            int durationTicks, float chakraCost, boolean chargeable, float chargeMax) {
        ACTIVE.put(player.getUuid(), new ActiveCast(jutsuId, durationTicks,
                chakraCost, chargeable, chargeMax));
    }

    public static boolean isCasting(ServerPlayerEntity player) {
        ActiveCast c = ACTIVE.get(player.getUuid());
        return c != null;
    }

    public static ActiveCast getActive(ServerPlayerEntity player) {
        return ACTIVE.get(player.getUuid());
    }

    public static void tickPlayer(ServerPlayerEntity player) {
        ActiveCast cast = ACTIVE.get(player.getUuid());
        if (cast == null) return;

        if (cast.isCastComplete()) {
            if (cast.chargeable && !cast.chargePhase) {
                // Transition to charge phase
                cast.startChargePhase();
                JutsuDefinition def = JutsuRegistry.get(cast.jutsuId);
                if (def != null) {
                    ShinobiCore.LOGGER.debug("[CAST] {} entered charge phase for {}",
                            player.getName().getString(), cast.jutsuId);
                }
            } else if (!cast.chargeable || cast.isChargeComplete()) {
                ACTIVE.remove(player.getUuid());
                JutsuCaster.executeCast(player, cast.jutsuId, cast.getChargeLevel());
            }
        }
    }

    /** S1-05: Called when player releases cast button */
    public static void releaseCast(ServerPlayerEntity player) {
        ActiveCast cast = ACTIVE.get(player.getUuid());
        if (cast == null) return;
        if (cast.chargePhase) {
            ACTIVE.remove(player.getUuid());
            float chargeLevel = cast.getChargeLevel();
            JutsuCaster.executeCast(player, cast.jutsuId, chargeLevel);
            ShinobiCore.LOGGER.debug("[CAST] {} released at charge {:.2f}",
                    player.getName().getString(), chargeLevel);
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