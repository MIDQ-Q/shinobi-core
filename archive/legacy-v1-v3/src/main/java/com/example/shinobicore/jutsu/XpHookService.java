// SHINOBICORE SPRINT A FILE
package com.example.shinobicore.jutsu;

import com.example.shinobicore.stat.component.IStatsComponent;
import com.example.shinobicore.stat.component.NinjaComponents;
import com.example.shinobicore.stat.component.StatType;
import com.example.shinobicore.util.ShinobiConstants;
import com.example.shinobicore.jutsu.data.JutsuDefinition;
import com.example.shinobicore.util.ShinobiLogger;
import net.minecraft.server.network.ServerPlayerEntity;

/**
* Centralized XP reward service.
* All xp awards go through this service to apply INSIGHT multiplier
* and send level-up events.
*/
public final class XpHookService {
private XpHookService() {}

private static boolean registered = false;

public static void register() {
if (registered) return;
registered = true;
ShinobiLogger.info("[XP-HOOK] XpHookService registered");
}

/**
* Award xp for combat (melee attack).
* xp = 10% of damage dealt, minimum 1.
*/
public static void awardCombatXp(ServerPlayerEntity player, float damage, StatType attackStat) {
if (player == null) return;
IStatsComponent stats = NinjaComponents.getStats(player);
if (stats == null) return;

int xpReward = Math.max(1, (int)(damage * 0.1f));
awardXp(player, stats, attackStat, xpReward);
}

/**
* Award xp for jutsu usage.
* xp = baseReward * jutsuTier, modified by INSIGHT multiplier.
*/
public static void awardJutsuXp(ServerPlayerEntity player, JutsuDefinition jutsu) {
if (player == null || jutsu == null) return;
IStatsComponent stats = NinjaComponents.getStats(player);
if (stats == null) return;

StatType primaryStat = getPrimaryStatForJutsu(jutsu);
int xpReward = getJutsuXpReward(jutsu);

awardXp(player, stats, primaryStat, xpReward);

// Also award 50% xp to CHAKRA_CONTROL
int controlXp = Math.max(1, xpReward / 2);
awardXp(player, stats, StatType.CONTROL, controlXp);
}

/**
* Core xp award method. Applies INSIGHT multiplier.
*/
public static void awardXp(ServerPlayerEntity player, IStatsComponent stats, StatType type, int amount) {
if (amount <= 0) return;

// Apply INSIGHT multiplier
float insightMult = stats.getInsightXpMultiplier();
int finalAmount = Math.max(1, (int)(amount * insightMult));

stats.addXp(type, finalAmount);

// Send level-up event if leveled up
// (handled inside addXp via tryLevelUp)
}

/**
* Determine primary stat for jutsu xp.
*/
public static StatType getPrimaryStatForJutsu(JutsuDefinition jutsu) {
if (jutsu == null) return StatType.NINJUTSU;

String name = jutsu.name();
if (name == null) return StatType.NINJUTSU;

String lower = name.toLowerCase();

if (lower.contains("taijutsu") || lower.contains("fist") || lower.contains("punch")) {
return StatType.TAIJUTSU;
}
if (lower.contains("kenjutsu") || lower.contains("sword") || lower.contains("katana")) {
return StatType.KENJUTSU;
}
if (lower.contains("shuriken") || lower.contains("kunai")) {
return StatType.SHURIKEN;
}
if (lower.contains("genjutsu") || lower.contains("illusion")) {
return StatType.GENJUTSU;
}
return StatType.NINJUTSU;
}

/**
* Calculate xp reward for jutsu based on tier.
* Tier 1: 10 xp, Tier 2: 20 xp, Tier 3: 40 xp, Tier 4: 80 xp, Tier 5: 160 xp
*/
public static int getJutsuXpReward(JutsuDefinition jutsu) {
if (jutsu == null) return 10;
int tier = jutsu.tier();
return 10 * (int)Math.pow(2, tier - 1);
}
}