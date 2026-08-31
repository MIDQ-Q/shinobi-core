package com.example.shinobicore.modules.progression.component;

import net.minecraft.entity.player.PlayerEntity;
import java.util.Optional;

public class ProgressionComponentKey {
    public static void register() {
    }

    public static Optional<ProgressionComponent> get(PlayerEntity player) {
        return Optional.ofNullable(ProgressionComponentInitializer.PROGRESSION.getNullable(player));
    }
}