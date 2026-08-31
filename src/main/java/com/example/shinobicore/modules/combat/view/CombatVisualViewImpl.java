package com.example.shinobicore.modules.combat.view;

import com.example.shinobicore.modules.combat.common.Stance;
import com.example.shinobicore.modules.combat.component.CombatComponent;
import com.example.shinobicore.modules.combat.component.CombatComponentKey;
import net.minecraft.entity.player.PlayerEntity;
import java.util.Optional;

public class CombatVisualViewImpl implements CombatVisualView {
    private final PlayerEntity player;

    public CombatVisualViewImpl(PlayerEntity player) {
        this.player = player;
    }

    @Override
    public String getCurrentStance() {
        return getComp().map(c -> c.getStance() == Stance.NONE ? "none" : c.getStance().name().toLowerCase()).orElse("none");
    }

    @Override
    public boolean isBlocking() {
        return getComp().map(CombatComponent::isBlocking).orElse(false);
    }

    @Override
    public boolean isParrying() {
        return getComp().map(CombatComponent::isParrying).orElse(false);
    }

    @Override
    public int getComboStep() {
        return getComp().map(CombatComponent::getComboStep).orElse(0);
    }

    @Override
    public boolean isSheathed() {
        return getComp().map(CombatComponent::isSheathed).orElse(false);
    }

    @Override
    public boolean isThrowing() {
        // TODO: Read from client state or component
        return false; 
    }

    @Override
    public float getBlockProgress() {
        // TODO: Calculate based on stamina drain accumulator
        return 0.0f; 
    }

    @Override
    public float getParryWindowProgress() {
        // TODO: Calculate based on parry fail recovery timer
        return 0.0f; 
    }

    @Override
    public String getWeaponClass() {
        // TODO: Resolve from BetterCombatAdapter.resolveWeaponClass(player.getMainHandStack())
        return "katana"; 
    }

    private Optional<CombatComponent> getComp() {
        return Optional.ofNullable(CombatComponentKey.KEY.getNullable(player));
    }
}