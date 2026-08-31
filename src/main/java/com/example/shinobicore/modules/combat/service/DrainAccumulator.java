package com.example.shinobicore.modules.combat.service;

public class DrainAccumulator {
    private double accumulator = 0.0;
    private final double perSecond;

    public DrainAccumulator(double perSecond) {
        this.perSecond = perSecond;
    }

    public int tick(double deltaTimeSeconds) {
        accumulator += perSecond * deltaTimeSeconds;
        int toSpend = (int) accumulator;
        accumulator -= toSpend;
        return toSpend;
    }

    public void reset() {
        accumulator = 0.0;
    }
}