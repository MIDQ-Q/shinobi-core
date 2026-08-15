package com.example.shinobicore;

import com.example.shinobicore.stat.NinjaFormula;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.example.shinobicore.config.ModConfig;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

public class FormulaTest {

    @BeforeAll
    static void setup() {
        ModConfig.instance = new ModConfig();
    }

    @Test
    void testMaxChakraPositive() {
        NinjaPlayerData data = new NinjaPlayerData();
        float max = NinjaFormula.maxChakra(data);
        assertTrue(max > 0, "Max chakra should be positive, got: " + max);
    }

    @Test
    void testRegenPositive() {
        NinjaPlayerData data = new NinjaPlayerData();
        float regen = NinjaFormula.regenPerSecond(data);
        assertTrue(regen > 0, "Regen should be positive");
    }

    @Test
    void testXpCurveIncreasing() {
        int xp1 = NinjaFormula.xpToNextLevel(1);
        int xp10 = NinjaFormula.xpToNextLevel(10);
        int xp50 = NinjaFormula.xpToNextLevel(50);
        assertTrue(xp1 < xp10, "XP should increase with level");
        assertTrue(xp10 < xp50, "XP should increase with level");
    }

    @Test
    void testSpCostPositive() {
        int cost = NinjaFormula.spCostForLevel(1);
        assertTrue(cost > 0, "SP cost should be positive");
    }

    @Test
    void testMaxHealthFormula() {
        assertEquals(20, NinjaFormula.maxHealth(0));
        assertEquals(40, NinjaFormula.maxHealth(1));
        assertEquals(160, NinjaFormula.maxHealth(7));
    }

    @Test
    void testSpeedMultiplierBounds() {
        float min = NinjaFormula.speedMultiplier(0, false);
        float max = NinjaFormula.speedMultiplier(7, true);
        assertTrue(min >= 1.0f, "Speed should be >= 1.0");
        assertTrue(max <= 4.0f, "Speed should be <= 4.0");
    }

    @Test
    void testJumpMultiplierBounds() {
        float min = NinjaFormula.jumpHorizontalMultiplier(0, false);
        float max = NinjaFormula.jumpHorizontalMultiplier(7, true);
        assertTrue(min >= 1.0f, "Jump mult should be >= 1.0");
        assertTrue(max <= 5.5f, "Jump mult should be <= 5.5");
    }

    @Test
    void testMeditationMultipliers() {
        assertTrue(NinjaFormula.meditationRegenMultiplier() > 1.0f);
        assertTrue(NinjaFormula.meditationFatigueDecayMultiplier() > 1.0f);
    }

    @Test
    void testBodySpCost() {
        int cost = NinjaFormula.bodySpCost();
        assertTrue(cost > 0, "Body SP cost should be positive");
    }

    @Test
    void testChakraModeDrain() {
        NinjaPlayerData data = new NinjaPlayerData();
        float drain = NinjaFormula.chakraModeDrainPerSecond(data);
        assertTrue(drain > 0, "Drain should be positive");
        assertTrue(drain < 5, "Drain should be reasonable");
    }
}