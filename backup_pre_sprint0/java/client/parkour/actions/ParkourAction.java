package com.example.shinobicore.client.parkour.actions;

import net.minecraft.client.network.ClientPlayerEntity;

public interface ParkourAction {
    String getId();
    
    // Проверяет, можно ли активировать действие сейчас
    boolean canActivate(ClientPlayerEntity player, ParkourContext ctx);
    
    // Активирует действие (применяет эффект)
    void activate(ClientPlayerEntity player, ParkourContext ctx);
    
    // Вызывается каждый тик пока действие активно
    void tick(ClientPlayerEntity player, ParkourContext ctx);
    
    // Деактивирует действие (если активна логика деактивации)
    void deactivate(ClientPlayerEntity player, ParkourContext ctx);
    
    // Кулдаун в тиках после деактивации
    int getCooldownTicks();
    
    // Усталость за активацию
    float getFatigueCost();
}