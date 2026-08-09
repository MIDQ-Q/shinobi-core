package com.example.shinobicore.client.parkour.actions;

import com.example.shinobicore.client.KeyBindings;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.entity.EntityPose;
import net.minecraft.util.math.Vec3d;

public class CrawlAction implements ParkourAction {
    public static final String ID = "crawl";

    private boolean active = false;

    @Override
    public String getId() { return ID; }

    @Override
    public boolean canActivate(ClientPlayerEntity player, ParkourContext ctx) {
        if (!player.isOnGround()) return false;
        if (!KeyBindings.CRAWL.isPressed()) return false;  // N зажата
        return true;  // Работает в любом режиме (без чакра-режима)
    }

    @Override
    public void activate(ClientPlayerEntity player, ParkourContext ctx) {
        active = true;
        player.setPose(EntityPose.SWIMMING);
        ctx.resetActive(ID);
    }

    @Override
    public void tick(ClientPlayerEntity player, ParkourContext ctx) {
        if (!active) return;
        
        player.setPose(EntityPose.SWIMMING);
        
        if (!KeyBindings.CRAWL.isPressed() || !player.isOnGround()) {
            deactivate(player, ctx);
            return;
        }
        
        Vec3d v = player.getVelocity();
        player.setVelocity(v.x * 0.5, v.y, v.z * 0.5);
    }

    @Override
    public void deactivate(ClientPlayerEntity player, ParkourContext ctx) {
        active = false;
        player.setPose(EntityPose.STANDING);
        ctx.setCooldown(ID, getCooldownTicks());
        ctx.clearActive(ID);
    }

    public boolean isActive() { return active; }

    @Override
    public int getCooldownTicks() { return 10; }

    @Override
    public float getFatigueCost() { return 0f; }
}