package com.example.shinobicore.modules.clans.component;

import dev.onyxstudios.cca.api.v3.component.ComponentKey;
import net.minecraft.entity.player.PlayerEntity;
import java.util.Optional;

public final class ClanComponentKey {
    public static final ComponentKey<ClanComponent> KEY = ClanComponentInitializer.CLAN;

    public static void register() {
        // Registration is handled by ClanComponentInitializer via fabric.mod.json entrypoint
    }

    public static Optional<ClanComponent> get(PlayerEntity player) {
        return Optional.ofNullable(KEY.maybeGet(player).orElse(null));
    }
}