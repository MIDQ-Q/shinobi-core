package com.example.shinobicore.dojutsu;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.jutsu.behavior.BehaviorRegistry;
import com.example.shinobicore.jutsu.behavior.CloneBehavior;
import net.fabricmc.fabric.api.event.lifecycle.v1.ServerTickEvents;

/**
 * Wires dojutsu registry, clone behavior and per-tick dojutsu logic.
 * HLD: Section 7
 */
public final class DojutsuBootstrap {

    private DojutsuBootstrap() {}

    public static void init() {
        DojutsuRegistry.registerReloadListener();
        BehaviorRegistry.register("clone", new CloneBehavior());

        ServerTickEvents.END_SERVER_TICK.register(server -> {
            for (net.minecraft.server.network.ServerPlayerEntity p : server.getPlayerManager().getPlayerList()) {
                var comp = com.example.shinobicore.stat.component.NinjaComponents.DOJUTSU.get(p);
                if (comp == null) continue;
                String active = comp.getActiveDojutsu();
                if (active == null) continue;

                if (SharinganManager.ID.equals(active)) {
                    SharinganManager.tick(p, comp, DojutsuRegistry.get(active));
                } else if (ByakuganManager.ID.equals(active)) {
                    ByakuganManager.tick(p);
                }
            }
        });

        ShinobiCore.LOGGER.info("DojutsuBootstrap initialized (Sprint 4)");
    }
}