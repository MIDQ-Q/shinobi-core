// SHINOBICORE SPRINT A FILE
package com.example.shinobicore.jutsu;

import com.example.shinobicore.stat.component.IStatsComponent;
import com.example.shinobicore.stat.component.NinjaComponents;
import com.example.shinobicore.stat.component.StatType;
import com.example.shinobicore.jutsu.data.JutsuDefinition;
import com.example.shinobicore.util.ShinobiLogger;
import net.minecraft.server.network.ServerPlayerEntity;
import net.minecraft.text.Text;
import net.minecraft.util.Formatting;

/**
* Jutsu casting service.
* Handles jutsu execution and awards XP on successful cast.
*
* NOTE: This is a stub for Sprint A. Full casting logic
* will be implemented in later sprints.
*/
public final class JutsuCaster {
private JutsuCaster() {}

private static boolean registered = false;

public static void register() {
if (registered) return;
registered = true;
ShinobiLogger.info("[JUTSU-CASTER] JutsuCaster registered");
}

/**
* Attempt to cast a jutsu.
*
* @param player The player casting the jutsu
* @param jutsu The jutsu definition to cast
* @return true if cast was successful
*/
public static boolean cast(ServerPlayerEntity player, JutsuDefinition jutsu) {
if (player == null || jutsu == null) return false;

// Check requirements
if (!checkRequirements(player, jutsu)) {
player.sendMessage(
Text.literal("Cannot cast " + jutsu.name() + " - requirements not met")
.formatted(Formatting.RED),
false
);
return false;
}

// Check chakra cost
IStatsComponent stats = NinjaComponents.getStats(player);
if (stats == null) return false;

float chakraCost = jutsu.baseCost();
// TODO: Check chakra and deduct

// TODO: Execute jutsu behavior
// This will be implemented in later sprints

// Award XP on successful cast
XpHookService.awardJutsuXp(player, jutsu);

player.sendMessage(
Text.literal("Cast " + jutsu.name() + "! (Tier " + jutsu.tier() + ")")
.formatted(Formatting.GREEN),
false
);

return true;
}

/**
* Check if player meets jutsu requirements.
*/
private static boolean checkRequirements(ServerPlayerEntity player, JutsuDefinition jutsu) {
if (jutsu.requirements() == null) return true;

IStatsComponent stats = NinjaComponents.getStats(player);
if (stats == null) return false;

for (var entry : jutsu.requirements().entrySet()) {
String statId = entry.getKey();
int requiredLevel = entry.getValue();

StatType statType = StatType.fromId(statId);
if (statType == null) continue;

int currentLevel = stats.getStatLevel(statType);
if (currentLevel < requiredLevel) {
return false;
}
}

return true;
}
}