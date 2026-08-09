package com.example.shinobicore.client.parkour.actions;

import com.example.shinobicore.client.ChakraHudRenderer;
import com.example.shinobicore.client.parkour.util.ParkourSounds;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.util.math.Vec3d;

public class SlideAction implements ParkourAction {
    public static final String ID = "slide";

    private static final int MAX_TICKS = 30;        // 1.5 сек
    private static final float MIN_SPEED = 0.1f;    // ниже — слайд заканчивается
    private static final float REQUIRED_SPEED = 0.25f; // нужен разбег
    private static final float INITIAL_BOOST = 0.35f;  // разовый импульс

    private boolean active = false;
    private boolean prevSneaking = false;
    private boolean justPressed = false;

    @Override
    public String getId() { return ID; }

    // Вызывается КАЖДЫЙ тик менеджером (независимо от active)
    public void updateInput(ClientPlayerEntity player) {
        boolean now = player.input.sneaking;
        justPressed = now && !prevSneaking;
        prevSneaking = now;
    }

    @Override
    public boolean canActivate(ClientPlayerEntity player, ParkourContext ctx) {
        if (!justPressed) return false;                 // Shift нажат только что
        if (!player.isOnGround()) return false;
        if (ChakraHudRenderer.exhausted) return false;  // истощение блокирует паркур
        if (ctx.isOnCooldown(ID)) return false;
        Vec3d horiz = new Vec3d(player.getVelocity().x, 0, player.getVelocity().z);
        return horiz.length() >= REQUIRED_SPEED;        // только разбег
    }

    @Override
    public void activate(ClientPlayerEntity player, ParkourContext ctx) {
        active = true;
        Vec3d dir = new Vec3d(player.getVelocity().x, 0, player.getVelocity().z).normalize();
        player.addVelocity(dir.x * INITIAL_BOOST, 0, dir.z * INITIAL_BOOST);
        player.velocityModified = true;
        player.setSprinting(true);
        ctx.resetActive(ID);
        ParkourSounds.playSlide();
    }

    @Override
    public void tick(ClientPlayerEntity player, ParkourContext ctx) {
        if (!active) return;
        int ticks = ctx.getActiveTicks(ID);
        Vec3d horiz = new Vec3d(player.getVelocity().x, 0, player.getVelocity().z);

        if (ticks > MAX_TICKS || !player.isOnGround() || !player.input.sneaking || horiz.length() < MIN_SPEED) {
            deactivate(player, ctx);
            return;
        }

        player.setSprinting(true); // держим спринт-визуал (ваниль его сбрасывает из-за Shift)
        if (ticks % 6 == 0) ParkourSounds.playSlideLoop();
    }

    @Override
    public void deactivate(ClientPlayerEntity player, ParkourContext ctx) {
        active = false;
        ctx.setCooldown(ID, getCooldownTicks());
        ctx.clearActive(ID);
    }

    public boolean isActive() { return active; }

    @Override
    public int getCooldownTicks() { return 10; }

    @Override
    public float getFatigueCost() { return 0f; }
}