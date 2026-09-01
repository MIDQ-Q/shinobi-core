package com.example.shinobicore.client.parkour.actions;

import com.example.shinobicore.client.KeyBindings;
import com.example.shinobicore.client.parkour.ParkourManager;
import com.example.shinobicore.client.parkour.util.PoseHelper;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.util.math.Vec3d;

public class CrawlAction implements ParkourAction {
    public static final String ID = "crawl";

    private boolean active = false;

    @Override
    public String getId() { return ID; }

    @Override
    public boolean canActivate(ClientPlayerEntity player, ParkourContext ctx) {
        if (!player.isOnGround()) return false;
        if (ParkourManager.isSliding()) return false;
        return KeyBindings.CRAWL.isPressed() || PoseHelper.cannotStand(player);
    }

    @Override
    public void activate(ClientPlayerEntity player, ParkourContext ctx) {
        active = true;
        PoseHelper.forceLowPose(player);
        ctx.resetActive(ID);
    }

    @Override
    public void tick(ClientPlayerEntity player, ParkourContext ctx) {
        if (!active) return;

        boolean wantCrawl = KeyBindings.CRAWL.isPressed();
        boolean forced = PoseHelper.cannotStand(player);

        if (!player.isOnGround() || (!wantCrawl && !forced)) {
            deactivate(player, ctx);
            return;
        }

        Vec3d v = player.getVelocity();
        player.setVelocity(v.x * 0.5, v.y, v.z * 0.5);
    }

    @Override
    public void deactivate(ClientPlayerEntity player, ParkourContext ctx) {
        active = false;
        PoseHelper.releasePose(player);
        ctx.setCooldown(ID, getCooldownTicks());
        ctx.clearActive(ID);
    }

    public boolean isActive() { return active; }

    @Override
    public int getCooldownTicks() { return 5; }

    @Override
    public float getFatigueCost() { return 0f; }
}