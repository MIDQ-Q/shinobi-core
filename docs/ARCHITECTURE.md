# ShinobiCore 4.0.0 - Architecture Overview

## Module Structure
com.example.shinobicore/
в”њв”Ђв”Ђ ShinobiCoreMod.java (main entry, module manager init)
в”њв”Ђв”Ђ ShinobiCoreClient.java (client entry)
в”њв”Ђв”Ђ core/
в”‚ в”њв”Ђв”Ђ api/ (module interfaces)
в”‚ в”њв”Ђв”Ђ module/ (module manager)
в”‚ в”њв”Ђв”Ђ event/ (event bus)
в”‚ в”њв”Ђв”Ђ view/ (view registry)
в”‚ в”њв”Ђв”Ђ service/ (service registry)
в”‚ в”њв”Ђв”Ђ log/ (unified logging)
в”‚ в”њв”Ђв”Ђ config/ (config loader)
в”‚ в”њв”Ђв”Ђ command/ (core commands)
в”‚ в””в”Ђв”Ђ compat/ (dependency checker)
в”њв”Ђв”Ђ config/
в”‚ в”њв”Ђв”Ђ ConfigSection.java (section interface)
в”‚ в”њв”Ђв”Ђ ConfigManager.java (central config manager)
в”‚ в”њв”Ђв”Ђ ChakraConfigSection.java
в”‚ в”њв”Ђв”Ђ CombatConfigSection.java
в”‚ в”њв”Ђв”Ђ ProgressionConfigSection.java
в”‚ в””в”Ђв”Ђ LoggingConfigSection.java
в”њв”Ђв”Ђ modules/
в”‚ в”њв”Ђв”Ђ jutsu/ (jutsu module)
в”‚ в”њв”Ђв”Ђ combat/ (combat module)
в”‚ в”њв”Ђв”Ђ movement/ (movement module)
в”‚ в”њв”Ђв”Ђ progression/ (progression module)
в”‚ в””в”Ђв”Ђ worldgen/ (worldgen module)
в”њв”Ђв”Ђ command/
в”‚ в”њв”Ђв”Ђ DiagnosticCommands.java (diagnostic commands)
в”‚ в””в”Ђв”Ђ ShinobiCommands.java (game commands)
в””в”Ђв”Ђ stat/
в”њв”Ђв”Ђ StatType.java
в”њв”Ђв”Ђ FormulaService.java
в””в”Ђв”Ђ component/ (CCA components)

## Configuration

All configuration is stored in:
config/shinobicore/shinobicore.json

Sections:
- `chakra` - Chakra system parameters
- `combat` - Combat balance parameters
- `progression` - XP and leveling parameters
- `logging` - Logging configuration

Reload with: `/shinobicore config reload`

## Logging

Unified logging via `ShinobiLogger`:
- Console output via SLF4J
- File output to `logs/shinobicore/`
- Rotation: 3 files, 5MB each
- Module-based filtering

Commands:
- `/shinobicore log level <TRACE|DEBUG|INFO|WARN|ERROR>`
- `/shinobicore log status`

## Commands

### Diagnostic
/shinobicore validate [all|config|modules]
/shinobicore systems
/shinobicore config reload|validate|loglevel <level>
/shinobicore test [chakra|stats|jutsu|all]
/shinobicore version