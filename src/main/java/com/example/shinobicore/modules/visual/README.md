# ShinobiCore Visual Module

## Overview
Client-side visual effects module for ShinobiCore 4.0.0.
Renders particles, trails, auras, camera shake, and screen flash.

**This module is READ-ONLY.** It never modifies game state and never sends packets.

## Architecture
- **Pools**: ParticlePool (512), TrailPool (64) - zero GC pressure
- **Limits**: 50 particles/frame, 200 particles/second (configurable)
- **Culling**: Effects beyond 32 blocks are not rendered (squared distance, no sqrt)
- **Rate Limiter**: 100ms cooldown between identical effects (auto-cleanup every 5s)
- **Rendering**: Zero-allocation renderers using VertexConsumer batching

## Commands (Client-Side)
| Command | Description |
|---------|-------------|
| /shinobicore visual test | Spawn test particles, trail, and camera shake |
| /shinobicore visual info | Show pool usage and active effects |
| /shinobicore visual clear | Clear all active effects |
| /shinobicore visual debug | Toggle debug overlay |
| /shinobicore visual flash | Trigger screen flash |
| /shinobicore visual aura | Toggle chakra aura |
| /shinobicore visual preset <name> | Set quality (low/medium/high/default) |

## Quality Presets
| Preset | Particles/Frame | Particles/Sec | Cull Distance | Shake | Trails |
|--------|----------------|---------------|---------------|-------|--------|
| low | 20 | 80 | 16 blocks | OFF | OFF |
| medium | 35 | 140 | 24 blocks | ON | ON |
| high | 50 | 200 | 32 blocks | ON | ON |

## Event Integration
Currently uses stub events. Replace imports in listener classes when other modules
publish their real events:
- JutsuVisualListener -> JutsuCastStartedEvent, JutsuCastFinishedEvent
- CombatVisualListener -> CombatHitEvent, CombatBlockedEvent, CombatParriedEvent
- MovementVisualListener -> WaterWalkStartedEvent, WallRunStartedEvent, etc.
- ProgressionVisualListener -> LevelChangedEvent, XpGainedEvent
- EnemyVisualListener -> EnemyStateChangedEvent

## Config
File: config/shinobicore/modules/visual.json
- Missing file: defaults created automatically
- Invalid JSON: error logged, defaults used, no crash
- No hot reload: restart required

## Performance Notes
- All renderers use zero-allocation loops (no new objects per frame)
- Distance culling uses squared distance (avoids Math.sqrt)
- Pool cleanup is O(1) per element (swap-with-last)
- Rate limiter auto-cleans stale entries every 5 seconds
- Target: 60+ FPS on weak PC with all effects active