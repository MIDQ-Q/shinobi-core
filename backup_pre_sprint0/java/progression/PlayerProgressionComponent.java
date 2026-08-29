package com.example.shinobicore.progression;

import dev.onyxstudios.cca.api.v3.component.Component;

/**
 * Component that stores player progression data: level, XP, SP, stats.
 * Attached to PlayerEntity via Cardinal Components API.
 * HLD Section 10 (Progression System).
 */
public interface PlayerProgressionComponent extends Component {

    // ---- Level & XP ----
    int getLevel();
    void setLevel(int level);
    int getXp();
    void addXP(int amount);

    // ---- Skill Points ----
    int getSP();
    void addSP(int amount);
    /** @return true if spent successfully, false if insufficient SP */
    boolean spendSP(int amount);

    // ---- Stats (ninjutsu, genjutsu, taijutsu, bukijutsu, chakraControl) ----
    int getStat(String name);
    void setStat(String name, int value);
    void addStat(String name, int amount);
}