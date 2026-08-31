# Clans Module (ShinobiCore)

## Overview
Implements the complete shinobi clan system with 9 canonical Naruto clans.
Provides stat bonuses, elemental affinities, dojutsu hooks, starting jutsu, passive effects, and faction reputation.

## Architecture
- **Data**: Loaded from data/shinobicore/clans/*.json.
- **Storage**: Uses Cardinal Components API (shinobicore:clan).
- **Modifiers**: Applied via FormulaCalculationEvent (no direct stat manipulation).
- **Network**: Server -> Client sync via ClanStateSyncPacket.

## Commands
- /shinobicore clan info - Show current clan info.
- /shinobicore clan list - List all registered clans.
- /shinobicore clan set <target> <clanId> - Set clan (Operator).
- /shinobicore clan change <target> <clanId> - Change clan, resets reputation/jutsu (Operator).
- /shinobicore clan reputation info - Show faction reputations.
- /shinobicore clan reputation set <target> <faction> <value> - Set reputation (Operator).
- /shinobicore clan validate - Validate all clan JSON files.
- /shinobicore clan sync - Force sync state to client.

## JSON Format
See data/shinobicore/clans/uchiha.json for a full example.
Key fields: id, 
ame, ffinity, statBonuses, 
atureBonuses, costMultiplier, atigueMultiplier, chakraCap, dojutsuHook, startingJutsu, passives, exclusiveJutsu.

## Passive Effects
Supported effect types in passives array:
- esistance (elemental damage reduction)
- egen_bonus (HP/chakra regeneration multiplier)
- speed_bonus (movement speed multiplier)
- damage_bonus (elemental/physical damage increase)
- cost_reduction (jutsu cost reduction for element)

## Integration
- **HUD/Visual**: Reads ClanVisualView via CoreViews.
- **Progression**: Listens to ClanJutsuUnlockedEvent / ClanJutsuLockedEvent.
- **Dojutsu**: Listens to DojutsuHookAppliedEvent.