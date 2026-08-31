package com.example.shinobicore.modules.chakra.service;

import com.example.shinobicore.api.chakra.ChakraApi;
import com.example.shinobicore.api.chakra.IChakraComponent;
import com.example.shinobicore.modules.chakra.component.ChakraComponentKey;
import net.minecraft.entity.player.PlayerEntity;

public final class ChakraApiImpl implements ChakraApi {
    private IChakraComponent getComp(PlayerEntity p) {
        return ChakraComponentKey.get(p);
    }
    @Override public double getCurrent(PlayerEntity p) {
        IChakraComponent c = getComp(p); return c != null ? c.getCurrent() : 0.0;
    }
    @Override public double getMax(PlayerEntity p) {
        IChakraComponent c = getComp(p); return c != null ? c.getMax() : 100.0;
    }
    @Override public boolean isChakraModeActive(PlayerEntity p) {
        IChakraComponent c = getComp(p); return c != null && c.isChakraModeActive();
    }
    @Override public boolean isExhausted(PlayerEntity p) {
        IChakraComponent c = getComp(p); return c != null && c.isExhausted();
    }
    @Override public boolean trySpend(PlayerEntity p, double amount) {
        IChakraComponent c = getComp(p); return c != null && c.trySpend(amount);
    }
    @Override public void regenerate(PlayerEntity p, double amount) {
        IChakraComponent c = getComp(p); if (c != null) c.regenerate(amount);
    }
    @Override public void toggleChakraMode(PlayerEntity p) {
        IChakraComponent c = getComp(p);
        if (c != null && !c.isExhausted()) c.setChakraModeActive(!c.isChakraModeActive());
    }
}