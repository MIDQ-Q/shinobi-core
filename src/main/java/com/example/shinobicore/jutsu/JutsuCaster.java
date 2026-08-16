package com.example.shinobicore.jutsu;

import com.example.shinobicore.clan.ClanDefinition;
import com.example.shinobicore.clan.ClanRegistry;
import com.example.shinobicore.config.ModConfig;
import com.example.shinobicore.stat.NinjaDataHolder;
import com.example.shinobicore.stat.NinjaFormula;
import com.example.shinobicore.stat.NinjaPlayerData;
import com.example.shinobicore.ShinobiCore;
import com.example.shinobicore.stat.StatType;
import net.minecraft.server.network.ServerPlayerEntity;
import com.example.shinobicore.tree.TreePassives;
import com.example.shinobicore.stat.ElementType;
import net.minecraft.item.ItemStack;
import net.minecraft.text.Text;

public class JutsuCaster {
    public static boolean cast(ServerPlayerEntity player, String jutsuId) {
        NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
        TreePassives.Bonuses pbs = TreePassives.collectServer(data);
        if (!data.getLearnedJutsus().contains(jutsuId)) {
            player.sendMessage(Text.literal("§cYou haven't learned this jutsu!"), false);
            return false;
        }
        JutsuDefinition def = JutsuRegistry.get(jutsuId);
        if (def == null) {
            player.sendMessage(Text.literal("§cJutsu not found!"), false);
            return false;
        }
        // === DOJUTSU CHECK ===
        if (def.requiresDojutsu() != null) {
            String activeDojutsu = data.getActiveDojutsu();
            if (activeDojutsu == null || !activeDojutsu.equals(def.requiresDojutsu())) {
                // Check if player has a scroll for this jutsu
                boolean hasScroll = false;
                if (def.requiresScroll() != null) {
                    for (int i = 0; i < player.getInventory().size(); i++) {
                        ItemStack stack = player.getInventory().getStack(i);
                        if (stack.getItem() instanceof com.example.shinobicore.item.ScrollItem) {
                            String scrollJutsu = com.example.shinobicore.item.ScrollItem.getJutsuId(stack);
                            if (def.id().equals(scrollJutsu)) {
                                hasScroll = true;
                                break;
                            }
                        }
                    }
                }
                if (!hasScroll) {
                    player.sendMessage(Text.literal("\u00a7cThis jutsu requires " + def.requiresDojutsu()
                        + "! (Or a scroll)"), false);
                    JutsuLogger.logBehavior("caster",
                        String.format("REJECTED dojutsu: player=%s, jutsu=%s, required=%s, active=%s",
                            player.getName().getString(), def.id(), def.requiresDojutsu(), activeDojutsu));
                    return false;
                }
            }
        }

        // === SCROLL CHECK (for jutsu that only need scroll, no dojutsu) ===
        if (def.requiresScroll() != null && def.requiresDojutsu() == null) {
            boolean hasScroll = false;
            for (int i = 0; i < player.getInventory().size(); i++) {
                ItemStack stack = player.getInventory().getStack(i);
                if (stack.getItem() instanceof com.example.shinobicore.item.ScrollItem) {
                    String scrollJutsu = com.example.shinobicore.item.ScrollItem.getJutsuId(stack);
                    if (def.id().equals(scrollJutsu)) {
                        hasScroll = true;
                        break;
                    }
                }
            }
            if (!hasScroll) {
                player.sendMessage(Text.literal("\u00a7cThis jutsu requires a scroll: "
                    + def.requiresScroll()), false);
                return false;
            }
        }

        // === DOJUTSU CHECK ===
        if (def.requiresDojutsu() != null) {
            String active = data.getActiveDojutsu();
            if (active == null || !active.equals(def.requiresDojutsu())) {
                boolean hasScroll = false;
                for (int i = 0; i < player.getInventory().size(); i++) {
                    net.minecraft.item.ItemStack st = player.getInventory().getStack(i);
                    if (st.getItem() instanceof com.example.shinobicore.item.ScrollItem) {
                        String sid = com.example.shinobicore.item.ScrollItem.getJutsuId(st);
                        if (def.id().equals(sid)) { hasScroll = true; break; }
                    }
                }
                if (!hasScroll) {
                    player.sendMessage(Text.literal("\u00a7cRequires " + def.requiresDojutsu() + "!"), false);
                    return false;
                }
            }
        }
        // === SCROLL CHECK ===
        if (def.requiresScroll() != null && def.requiresDojutsu() == null) {
            boolean hasScroll = false;
            for (int i = 0; i < player.getInventory().size(); i++) {
                net.minecraft.item.ItemStack st = player.getInventory().getStack(i);
                if (st.getItem() instanceof com.example.shinobicore.item.ScrollItem) {
                    String sid = com.example.shinobicore.item.ScrollItem.getJutsuId(st);
                    if (def.id().equals(sid)) { hasScroll = true; break; }
                }
            }
            if (!hasScroll) {
                player.sendMessage(Text.literal("\u00a7cRequires scroll: " + def.requiresScroll()), false);
                return false;
            }
        }
        if (!NinjaFormula.checkRequirements(def, data)) {
            player.sendMessage(Text.literal("§cYour stats are too low for this jutsu!"), false);
            JutsuLogger.logBehavior("caster",
                    String.format("REJECTED requirements: player=%s, jutsu=%s",
                            player.getName().getString(), jutsuId));
            return false;
        }
        float cost = NinjaFormula.calculateCost(def, data);
        if (data.getCurrentChakra() < cost) {
            player.sendMessage(Text.literal("§cNot enough chakra!"), false);
            JutsuLogger.logBehavior("caster",
                    String.format("REJECTED chakra: player=%s, need=%.1f, have=%.1f",
                            player.getName().getString(), cost, data.getCurrentChakra()));
            return false;
        }

        // Списываем чакру
        data.setCurrentChakra(data.getCurrentChakra() - cost);

        // Усталость с учётом клана
        float strain = def.strain() * (1f - pbs.fatigueReduction);
        ClanDefinition clan = ClanRegistry.get(data.getClanId());
        if (clan != null) {
            strain *= clan.fatigueMultiplier();
        }
        data.setFatigue(data.getFatigue() + strain);

        // Опыт
        NinjaFormula.grantUsage(data, jutsuId, 1);
        if (def.hasNature() && data.isNatureUnlocked(def.nature())) {
            float xpMult = (data.getAffinity() == def.nature())
                    ? ModConfig.instance.combat.affinityXpMultiplier
                    : 1f;
            int natureXp = Math.max(1, Math.round(cost * 0.2f * xpMult));
            NinjaFormula.grantNatureXp(data, def.nature(), natureXp);
        }
        int ninjutsuXp = Math.max(1, Math.round(cost * 0.1f));
        NinjaFormula.grantStatXp(data, StatType.NINJUTSU, ninjutsuXp);

        // Урон
        float damage = def.baseDamage() * NinjaFormula.damageMultiplier(data, def);
        if (def.hasNature()) {
            String nid = def.nature().getId();
            float elemBonus = 0f;
            if (nid.equals("fire")) {
                elemBonus += pbs.kekkeiFire;
                if (pbs.fireWindSynergy > 0 && data.isNatureUnlocked(ElementType.WIND)) elemBonus += pbs.fireWindSynergy;
            } else if (nid.equals("earth")) {
                elemBonus += pbs.kekkeiEarth;
            } else if (nid.equals("lightning")) {
                elemBonus += pbs.kekkeiLightning;
            }
            if (elemBonus > 0) damage *= (1f + elemBonus);
        }

        // === ЛОГИРОВАНИЕ ===
        JutsuLogger.logCast(player, def, data, damage, cost);

        // Вызываем behavior
        ShinobiCore.broadcastCastFx(player, def.hasNature() ? def.nature().getId() : "none");
        JutsuBehavior behavior = BehaviorRegistry.getFor(def);
        behavior.cast(player, def, data, def.params(), damage);

        return true;
    }

    // === PHASE5 BEGINCAST ===
    public static int calculateCastTime(com.example.shinobicore.jutsu.JutsuDefinition def, NinjaPlayerData data) {
        float baseTime = 1.5f;
        float complexity = Math.max(0.5f, def.baseCost() / 30f);
        int control = data.getStatLevel(StatType.CONTROL);
        float controlFactor = 1f - (control / 100f * 0.5f);
        float castTimeSeconds = baseTime * complexity * controlFactor;
        int ticks = (int)(castTimeSeconds * 20f);
        return Math.max(10, Math.min(100, ticks));
    }

    public static boolean beginCast(ServerPlayerEntity player, String jutsuId) {
        NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
        TreePassives.Bonuses pbs = TreePassives.collectServer(data);
        if (!data.getLearnedJutsus().contains(jutsuId)) {
            player.sendMessage(Text.literal("\u00a7cYou haven't learned this jutsu!"), false);
            return false;
        }
        com.example.shinobicore.jutsu.JutsuDefinition def = com.example.shinobicore.jutsu.JutsuRegistry.get(jutsuId);
        if (def == null) {
            player.sendMessage(Text.literal("\u00a7cJutsu not found!"), false);
            return false;
        }
        // === DOJUTSU CHECK ===
        if (def.requiresDojutsu() != null) {
            String activeDojutsu = data.getActiveDojutsu();
            if (activeDojutsu == null || !activeDojutsu.equals(def.requiresDojutsu())) {
                // Check if player has a scroll for this jutsu
                boolean hasScroll = false;
                if (def.requiresScroll() != null) {
                    for (int i = 0; i < player.getInventory().size(); i++) {
                        ItemStack stack = player.getInventory().getStack(i);
                        if (stack.getItem() instanceof com.example.shinobicore.item.ScrollItem) {
                            String scrollJutsu = com.example.shinobicore.item.ScrollItem.getJutsuId(stack);
                            if (def.id().equals(scrollJutsu)) {
                                hasScroll = true;
                                break;
                            }
                        }
                    }
                }
                if (!hasScroll) {
                    player.sendMessage(Text.literal("\u00a7cThis jutsu requires " + def.requiresDojutsu()
                        + "! (Or a scroll)"), false);
                    JutsuLogger.logBehavior("caster",
                        String.format("REJECTED dojutsu: player=%s, jutsu=%s, required=%s, active=%s",
                            player.getName().getString(), def.id(), def.requiresDojutsu(), activeDojutsu));
                    return false;
                }
            }
        }

        // === SCROLL CHECK (for jutsu that only need scroll, no dojutsu) ===
        if (def.requiresScroll() != null && def.requiresDojutsu() == null) {
            boolean hasScroll = false;
            for (int i = 0; i < player.getInventory().size(); i++) {
                ItemStack stack = player.getInventory().getStack(i);
                if (stack.getItem() instanceof com.example.shinobicore.item.ScrollItem) {
                    String scrollJutsu = com.example.shinobicore.item.ScrollItem.getJutsuId(stack);
                    if (def.id().equals(scrollJutsu)) {
                        hasScroll = true;
                        break;
                    }
                }
            }
            if (!hasScroll) {
                player.sendMessage(Text.literal("\u00a7cThis jutsu requires a scroll: "
                    + def.requiresScroll()), false);
                return false;
            }
        }

        // === DOJUTSU CHECK ===
        if (def.requiresDojutsu() != null) {
            String active = data.getActiveDojutsu();
            if (active == null || !active.equals(def.requiresDojutsu())) {
                boolean hasScroll = false;
                for (int i = 0; i < player.getInventory().size(); i++) {
                    net.minecraft.item.ItemStack st = player.getInventory().getStack(i);
                    if (st.getItem() instanceof com.example.shinobicore.item.ScrollItem) {
                        String sid = com.example.shinobicore.item.ScrollItem.getJutsuId(st);
                        if (def.id().equals(sid)) { hasScroll = true; break; }
                    }
                }
                if (!hasScroll) {
                    player.sendMessage(Text.literal("\u00a7cRequires " + def.requiresDojutsu() + "!"), false);
                    return false;
                }
            }
        }
        // === SCROLL CHECK ===
        if (def.requiresScroll() != null && def.requiresDojutsu() == null) {
            boolean hasScroll = false;
            for (int i = 0; i < player.getInventory().size(); i++) {
                net.minecraft.item.ItemStack st = player.getInventory().getStack(i);
                if (st.getItem() instanceof com.example.shinobicore.item.ScrollItem) {
                    String sid = com.example.shinobicore.item.ScrollItem.getJutsuId(st);
                    if (def.id().equals(sid)) { hasScroll = true; break; }
                }
            }
            if (!hasScroll) {
                player.sendMessage(Text.literal("\u00a7cRequires scroll: " + def.requiresScroll()), false);
                return false;
            }
        }
        if (!NinjaFormula.checkRequirements(def, data)) {
            player.sendMessage(Text.literal("\u00a7cYour stats are too low for this jutsu!"), false);
            return false;
        }
        float cost = NinjaFormula.calculateCost(def, data);
        if (data.getCurrentChakra() < cost) {
            player.sendMessage(Text.literal("\u00a7cNot enough chakra!"), false);
            return false;
        }
        if (com.example.shinobicore.combat.CastingServerState.isCasting(player)) {
            com.example.shinobicore.combat.CastingServerState.interruptCast(player);
        }
        data.setCurrentChakra(data.getCurrentChakra() - cost);
        float strain = def.strain() * (1f - pbs.fatigueReduction);
        com.example.shinobicore.clan.ClanDefinition clan = com.example.shinobicore.clan.ClanRegistry.get(data.getClanId());
        if (clan != null) strain *= clan.fatigueMultiplier();
        data.setFatigue(data.getFatigue() + strain);
        NinjaFormula.grantUsage(data, jutsuId, 1);
        if (def.hasNature() && data.isNatureUnlocked(def.nature())) {
            float xpMult = (data.getAffinity() == def.nature())
                ? com.example.shinobicore.config.ModConfig.instance.combat.affinityXpMultiplier : 1f;
            int natureXp = Math.max(1, Math.round(cost * 0.2f * xpMult));
            NinjaFormula.grantNatureXp(data, def.nature(), natureXp);
        }
        int ninjutsuXp = Math.max(1, Math.round(cost * 0.1f));
        NinjaFormula.grantStatXp(data, StatType.NINJUTSU, ninjutsuXp);
        int castTimeTicks = calculateCastTime(def, data);
        ShinobiCore.sendChakraSync(player);
        // === ЗВУК НАЧАЛА ЗАРЯДКИ ===
        JutsuSoundHelper.playChargeStartSound(player, def);

        com.example.shinobicore.combat.CastingServerState.startCast(player, jutsuId, castTimeTicks, cost, def.chargeable(), def.chargeMax());
        ShinobiCore.broadcastCastStart(player, jutsuId, castTimeTicks);
        JutsuLogger.logBehavior("hand_signs", String.format(
            "START: player=%s, jutsu=%s, castTime=%dticks, cost=%.1f",
            player.getName().getString(), jutsuId, castTimeTicks, cost));
        return true;
    }

    public static boolean executeCast(ServerPlayerEntity player, String jutsuId) {
        return executeCast(player, jutsuId, 1.0f);
    }

    public static boolean executeCast(ServerPlayerEntity player, String jutsuId, float chargeLevel) {
        NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
        TreePassives.Bonuses pbs = TreePassives.collectServer(data);
        com.example.shinobicore.jutsu.JutsuDefinition def = com.example.shinobicore.jutsu.JutsuRegistry.get(jutsuId);
        if (def == null) return false;

        // === ЗВУК ЗАВЕРШЕНИЯ ЗАРЯДКИ ===
        JutsuSoundHelper.playChargeReadySound(player, def);

        float cost = NinjaFormula.calculateCost(def, data);
        float damage = def.baseDamage() * NinjaFormula.damageMultiplier(data, def);
        if (def.hasNature()) {
            String nid = def.nature().getId();
            float elemBonus = 0f;
            if (nid.equals("fire")) {
                elemBonus += pbs.kekkeiFire;
                if (pbs.fireWindSynergy > 0 && data.isNatureUnlocked(com.example.shinobicore.stat.ElementType.WIND))
                    elemBonus += pbs.fireWindSynergy;
            } else if (nid.equals("earth")) { elemBonus += pbs.kekkeiEarth; }
            else if (nid.equals("lightning")) { elemBonus += pbs.kekkeiLightning; }
            if (elemBonus > 0) damage *= (1f + elemBonus);
        }
        JutsuLogger.logCast(player, def, data, damage, cost);
        ShinobiCore.broadcastCastFx(player, def.hasNature() ? def.nature().getId() : "none");
        com.example.shinobicore.jutsu.JutsuBehavior behavior = com.example.shinobicore.jutsu.BehaviorRegistry.getFor(def);
        behavior.cast(player, def, data, def.params(), damage);
        return true;
    }
}