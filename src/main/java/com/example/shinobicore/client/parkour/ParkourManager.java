package com.example.shinobicore.client.parkour;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.client.parkour.actions.ChargedJumpAction;
import com.example.shinobicore.client.parkour.actions.CrawlAction;
import com.example.shinobicore.client.parkour.actions.EdgeGrabAction;
import com.example.shinobicore.client.parkour.actions.ParkourAction;
import com.example.shinobicore.client.parkour.actions.ParkourContext;
import com.example.shinobicore.client.parkour.actions.RollAction;
import com.example.shinobicore.client.parkour.actions.SlideAction;
import com.example.shinobicore.client.parkour.actions.WallRunAction;
import com.example.shinobicore.network.ModPackets;
import io.netty.buffer.Unpooled;
import net.fabricmc.fabric.api.client.networking.v1.ClientPlayNetworking;
import net.minecraft.client.MinecraftClient;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.network.PacketByteBuf;
import com.example.shinobicore.client.parkour.actions.DodgeAction;
import java.util.ArrayList;
import java.util.List;
import com.example.shinobicore.client.parkour.actions.CrawlAction;

public class ParkourManager {
    private static final List<ParkourAction> actions = new ArrayList<>();
    private static final ParkourContext ctx = new ParkourContext();
    private static int logTimer = 0;
    private static ChargedJumpAction chargedJumpAction;

    public static void register() {
        actions.add(new SlideAction());
        actions.add(new WallRunAction());
        actions.add(new EdgeGrabAction());
        actions.add(new RollAction());
        actions.add(new CrawlAction());
        chargedJumpAction = new ChargedJumpAction();
        ShinobiCore.LOGGER.info("ParkourManager: registered {} actions", actions.size());
    }

    public static boolean isDodging() {
        for (ParkourAction action : actions) {
            if (action instanceof DodgeAction dodge) return dodge.isActive();
        }
        return false;
    }
    public static boolean isCrawling() {
        for (ParkourAction action : actions) {
            if (action instanceof CrawlAction crawl) return crawl.isActive();
        }
        return false;
    }
    public static void tick(MinecraftClient client) {
        ClientPlayerEntity player = client.player;
        if (player == null) return;

        ctx.tickCooldowns();
        boolean doLog = (logTimer == 0);

        // Tick charged jump (всегда, независимо от других действий)
        chargedJumpAction.tick(player, ctx);

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
            } else if (action instanceof CrawlAction crawl) {
                if (crawl.isActive()) {
                    crawl.tick(player, ctx);
                } else if (crawl.canActivate(player, ctx)) {
                    crawl.activate(player, ctx);
                    if (doLog) ShinobiCore.LOGGER.info("[parkour] crawl activated");
                }
            } else if (action instanceof EdgeGrabAction edgeGrab) {
                if (edgeGrab.isActive()) {
                    edgeGrab.tick(player, ctx);
                } else if (edgeGrab.canActivate(player, ctx)) {
                    edgeGrab.activate(player, ctx);
                    if (doLog) ShinobiCore.LOGGER.info("[parkour] edge grab activated");
                }
            } else if (action instanceof RollAction roll) {
                if (roll.isActive()) {
                    roll.tick(player, ctx);
                } else if (roll.canActivate(player, ctx)) {
                    roll.activate(player, ctx);
                    if (doLog) ShinobiCore.LOGGER.info("[parkour] roll activated");
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

    public static boolean isEdgeGrabbing() {
        for (ParkourAction action : actions) {
            if (action instanceof EdgeGrabAction edgeGrab) return edgeGrab.isActive();
        }
        return false;
    }

    public static boolean isRolling() {
        for (ParkourAction action : actions) {
            if (action instanceof RollAction roll) return roll.isActive();
        }
        return false;
    }

    public static ChargedJumpAction getChargedJumpAction() {
        return chargedJumpAction;
    }

    public static void sendChargedJumpFatigue(float fatigue) {
        PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
        buf.writeString("charged_jump");
        buf.writeFloat(fatigue);
        ClientPlayNetworking.send(ModPackets.PARKOUR_ACTION_ID, buf);
    }
}