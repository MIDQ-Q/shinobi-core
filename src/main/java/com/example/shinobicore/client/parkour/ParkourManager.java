package com.example.shinobicore.client.parkour;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.client.parkour.actions.ParkourAction;
import com.example.shinobicore.client.parkour.actions.ParkourContext;
import com.example.shinobicore.client.parkour.actions.SlideAction;
import com.example.shinobicore.client.parkour.actions.WallRunAction;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.network.ClientPlayerEntity;

import java.util.ArrayList;
import java.util.List;

public class ParkourManager {
    private static final List<ParkourAction> actions = new ArrayList<>();
    private static final ParkourContext ctx = new ParkourContext();
    private static int logTimer = 0;

    public static void register() {
        actions.add(new SlideAction());
        actions.add(new WallRunAction());
        ShinobiCore.LOGGER.info("ParkourManager: registered {} actions", actions.size());
    }

    public static void tick(MinecraftClient client) {
        ClientPlayerEntity player = client.player;
        if (player == null) return;

        ctx.tickCooldowns();
        boolean doLog = (logTimer == 0);

        for (ParkourAction action : actions) {
            if (action instanceof SlideAction slide) {
                slide.updateInput(player);
                if (slide.isActive()) {
                    slide.tick(player, ctx);
                } else if (slide.canActivate(player, ctx)) {
                    slide.activate(player, ctx);
                    if (doLog) ShinobiCore.LOGGER.info("[parkour] slide activated");
                }
            } else if (action instanceof WallRunAction wallRun) {
                if (wallRun.isActive()) {
                    wallRun.tick(player, ctx);
                } else if (wallRun.canActivate(player, ctx)) {
                    wallRun.activate(player, ctx);
                    if (doLog) ShinobiCore.LOGGER.info("[parkour] wall run activated");
                }
            }
        }

        logTimer = (logTimer + 1) % 20;
    }

    public static boolean isSliding() {
        for (ParkourAction action : actions) {
            if (action instanceof SlideAction slide) return slide.isActive();
        }
        return false;
    }

    public static boolean isWallRunning() {
        for (ParkourAction action : actions) {
            if (action instanceof WallRunAction wallRun) return wallRun.isActive();
        }
        return false;
    }
}