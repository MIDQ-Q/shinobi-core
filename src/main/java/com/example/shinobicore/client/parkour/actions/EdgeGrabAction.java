package com.example.shinobicore.client.parkour.actions;

import com.example.shinobicore.client.ChakraHudRenderer;
import com.example.shinobicore.client.ClientNinjaState;
import com.example.shinobicore.client.parkour.util.ParkourSounds;
import com.example.shinobicore.client.parkour.util.WallDetector;
import net.minecraft.client.network.ClientPlayerEntity;
import net.minecraft.util.math.BlockPos;
import net.minecraft.util.math.Vec3d;
import com.example.shinobicore.client.ClientNinjaStateHolder;

public class EdgeGrabAction implements ParkourAction {
    public static final String ID = "edge_grab";

    private boolean active = false;
    private BlockPos ledgePos = null;

    @Override
    public String getId() { return ID; }

    @Override
    public boolean canActivate(ClientPlayerEntity player, ParkourContext ctx) {
        if (!ClientNinjaStateHolder.get().isChakraMode()) return false;
        if (ChakraHudRenderer.currentChakra <= 0) return false;
        if (ChakraHudRenderer.exhausted) return false;
        if (ctx.isOnCooldown(ID)) return false;
        
        // Должен падать
        if (player.isOnGround()) return false;
        if (player.getVelocity().y >= 0) return false; // только при падении
        
        // Проверяем наличие края
        BlockPos ledge = WallDetector.getLedgeAbove(player);
        if (ledge == null) return false;
        
        // Сохраняем позицию края для tick()
        this.ledgePos = ledge;
        return true;
    }

    @Override
    public void activate(ClientPlayerEntity player, ParkourContext ctx) {
        active = true;
        
        // Обнуляем скорость (зависаем на краю)
        player.setVelocity(0, 0, 0);
        player.velocityModified = true;
        
        ctx.resetActive(ID);
        ParkourSounds.playEdgeGrab();
    }

    @Override
    public void tick(ClientPlayerEntity player, ParkourContext ctx) {
        if (!active) return;
        
        // Удерживаем игрока на месте
        player.setVelocity(0, 0, 0);
        player.velocityModified = true;
        player.fallDistance = 0f;
        
        // Если нажал Space — подтягивание
        if (player.input.jumping && ledgePos != null) {
            player.setPosition(player.getX(), ledgePos.getY() + 0.001, player.getZ());
            player.setVelocity(player.getVelocity().x * 0.3, 0.42, player.getVelocity().z * 0.3);
            player.velocityModified = true;
            player.setOnGround(true);
            ParkourSounds.playEdgeClimb();
            deactivate(player, ctx);
        }
        
        // Если отпустил все клавиши — продолжаем падать
        if (!player.input.sneaking && !player.input.pressingForward && !player.input.jumping) {
            // Проверяем что всё ещё есть край (может стена исчезла)
            if (WallDetector.getLedgeAbove(player) == null) {
                deactivate(player, ctx);
            }
        }
    }

    @Override
    public void deactivate(ClientPlayerEntity player, ParkourContext ctx) {
        active = false;
        ledgePos = null;
        ctx.setCooldown(ID, getCooldownTicks());
        ctx.clearActive(ID);
    }

    public boolean isActive() { return active; }

    @Override
    public int getCooldownTicks() { return 20; }  // 1 сек

    @Override
    public float getFatigueCost() { return 0.5f; }
}