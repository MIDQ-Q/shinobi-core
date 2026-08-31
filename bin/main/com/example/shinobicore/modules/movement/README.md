# Movement Module (ShinobiCore)

## Overview
This module implements a complete shinobi-style movement system, including water walking, wall running, sliding, rolling, dodging, and edge grabbing. It relies on the core Chakra service for resource management.

## Key Mechanics
- **Water Walking**: Requires active Chakra mode. Drains chakra over time.
- **Wall Running**: Stick to walls while in air. Requires horizontal momentum.
- **Dodging/Rolling**: Grants i-frames (damage immunity). Dodging costs chakra.
- **Edge Grabbing**: Automatically catches edges when falling near them.

## Configuration
Located at `config/shinobicore/modules/movement.json`.
All values have safe defaults. The module will NOT crash if the file is missing or malformed.

## Commands
- `/shinobicore movement state` - Shows current server-side pose and drain accumulator.
- `/shinobicore movement test` - Spawns a water pool, wall, and edge for testing.
- `/shinobicore movement debug` - Toggles debug logging/overlay.
- `/shinobicore movement reset` - Forces pose back to NORMAL.

## Architecture Notes
- **Client Authority**: Physics and pose detection happen on the client for responsive feel.
- **Server Mirror**: The server only tracks the current pose and drains chakra once per second using an accumulator pattern to prevent double-drain bugs.
- **Memory Safety**: All player-specific data in static maps is cleaned up via `PlayerLeaveEvent` and `PlayerDiedEvent`.

## Dependencies
- Core: `ChakraApi`, `CoreEvents`, `CoreServices`
- External: `player-animator` (optional, for advanced pose blending)