# Progression Module

## Overview
Complete player progression system: Level, XP, SP, Stats, Skill Tree, Attunement, Jutsu Mastery, Reputation.

## Key Behaviors
- Progression NEVER resets (by design). CCA uses ALWAYS_COPY on respawn.
- XP is awarded ONLY through XpSourceService (single source of truth).
- All SP spends are validated server-side.
- Skill tree is loaded from JSON, validated for cycles and missing prerequisites.
- Attunement requires: SP cost + control stat + pulse circle mini-game success.
- First element (affinity) is free. Clans may grant extra free affinities.
- Combined elements (Kekkei Genkai) require base components to be unlocked first.

## Commands
```
/shinobicore progression info
/shinobicore progression statinfo
/shinobicore progression addxp <amount>
/shinobicore progression addsp <amount>
/shinobicore progression setlevel <lvl>
/shinobicore progression setstat <stat> <level>
/shinobicore progression attune <element>
/shinobicore progression reputation <faction> <amount>
/shinobicore progression sync
```

## Network Packets
All packets follow "read first, execute second" rule.
- shinobicore:progression_action (C2S)
- shinobicore:progression_attunement_attempt (C2S)
- shinobicore:progression_minigame_result (C2S)
- shinobicore:progression_sync (S2C)
- shinobicore:progression_level_up (S2C)
- shinobicore:progression_stat_changed (S2C)

## Data Files
- data/shinobicore/progression/tree/*.json - Skill tree nodes
- data/shinobicore/progression/attunement/elements.json - Element definitions
- data/shinobicore/progression/minigames/*.json - Mini-game definitions
- data/shinobicore/progression/balance/*.json - Balance tuning

## Config
File: config/shinobicore/modules/progression.json
Read once at module load. Missing fields use defaults. Invalid JSON does not crash.