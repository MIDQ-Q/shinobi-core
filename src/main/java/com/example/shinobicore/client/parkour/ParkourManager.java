package com.example.shinobicore.client.parkour;

import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.client.KeyBindings;
import com.example.shinobicore.client.parkour.actions.ChargedJumpAction;
import com.example.shinobicore.client.parkour.actions.CrawlAction;
import com.example.shinobicore.client.parkour.actions.DodgeAction;
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

import java.util.ArrayList;
import java.util.List;

public class ParkourManager {
    private static final List<ParkourAction> actions = new ArrayList<>();
    private static final ParkourContext ctx = new ParkourContext();
    private static int logTimer = 0;
    private static ChargedJumpAction chargedJumpAction;
    private static boolean lastLowPose = false;

    public static void register() {
        actions.add(new SlideAction());
        actions.add(new WallRunAction());
        actions.add(new EdgeGrabAction());
        actions.add(new RollAction());
        actions.add(new CrawlAction());
        actions.add(new DodgeAction());  // ← ДОДЖ
        chargedJumpAction = new ChargedJumpAction();
        ShinobiCore.LOGGER.debug("ParkourManager: registered {} actions", actions.size());
    }

    public static void tick(MinecraftClient client) {
        ClientPlayerEntity player = client.player;
        if (player == null) return;

        ctx.tickCooldowns();
        logTimer = (logTimer + 1) % 200;
        boolean doLog = (logTimer == 0);

        chargedJumpAction.tick(player, ctx);

        // Синхронизация низкой позы с сервером
        boolean needsLow = isSliding() || isCrawling() || isRolling()
            || com.example.shinobicore.client.parkour.util.PoseHelper.cannotStand(player);
        if (needsLow != lastLowPose) {
            lastLowPose = needsLow;
            PacketByteBuf poseBuf = new PacketByteBuf(Unpooled.buffer());
            poseBuf.writeBoolean(needsLow);
            ClientPlayNetworking.send(ModPackets.POSE_SYNC_ID, poseBuf);
        }

        for (ParkourAction action : actions) {
            if (action instanceof SlideAction slide) {
                slide.updateInput(player);
                if (slide.isActive()) {
                    slide.tick(player, ctx);
                } else if (slide.canActivate(player, ctx)) {
                    slide.activate(player, ctx);
                    if (doLog) ShinobiCore.LOGGER.debug("[parkour] slide activated");
                }
            } else if (action instanceof WallRunAction wallRun) {
                if (wallRun.isActive()) {
                    wallRun.tick(player, ctx);
                } else if (wallRun.canActivate(player, ctx)) {
                    wallRun.activate(player, ctx);
                    if (doLog) ShinobiCore.LOGGER.debug("[parkour] wall run activated");
                }
            } else if (action instanceof EdgeGrabAction edgeGrab) {
                if (edgeGrab.isActive()) {
                    edgeGrab.tick(player, ctx);
                } else if (edgeGrab.canActivate(player, ctx)) {
                    edgeGrab.activate(player, ctx);
                    if (doLog) ShinobiCore.LOGGER.debug("[parkour] edge grab activated");
                }
            } else if (action instanceof RollAction roll) {
                if (roll.isActive()) {
                    roll.tick(player, ctx);
                } else if (roll.canActivate(player, ctx)) {
                    roll.activate(player, ctx);
                    if (doLog) ShinobiCore.LOGGER.debug("[parkour] roll activated");
                }
            } else if (action instanceof CrawlAction crawl) {
                if (crawl.isActive()) {
                    crawl.tick(player, ctx);
                } else if (crawl.canActivate(player, ctx)) {
                    crawl.activate(player, ctx);
                    if (doLog) ShinobiCore.LOGGER.debug("[parkour] crawl activated");
                }
            } else if (action instanceof DodgeAction dodge) {
                if (dodge.isActive()) {
                    dodge.tick(player, ctx);
                } else if (dodge.canActivate(player, ctx)) {
                    dodge.activate(player, ctx);
                    if (doLog) ShinobiCore.LOGGER.debug("[parkour] dodge activated");
                    
                    // Отправляем пакет на сервер
                    PacketByteBuf dodgeBuf = new PacketByteBuf(Unpooled.buffer());
                    dodgeBuf.writeInt(KeyBindings.DODGE_LEFT.wasPressed() ? -1 : 1);
                    ClientPlayNetworking.send(ModPackets.DODGE_ID, dodgeBuf);
                }
            }
        }
    }

    public static boolean isSliding() {
        for (ParkourAction a : actions) if (a instanceof SlideAction s && s.isActive()) return true;
        return false;
    }
    
    public static boolean isCrawling() {
        for (ParkourAction a : actions) if (a instanceof CrawlAction c && c.isActive()) return true;
        return false;
    }
    
    public static boolean isRolling() {
        for (ParkourAction a : actions) if (a instanceof RollAction r && r.isActive()) return true;
        return false;
    }
    
    public static boolean isWallRunning() {
        for (ParkourAction a : actions) if (a instanceof WallRunAction w && w.isActive()) return true;
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