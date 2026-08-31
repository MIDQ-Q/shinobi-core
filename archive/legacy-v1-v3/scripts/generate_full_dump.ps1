$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$dumpFile = "E:\Games\mod\FULL_CODE_DUMP.md"
$srcDir = "E:\Games\mod\src\main\java"
$resDir = "E:\Games\mod\src\main\resources"

$sb = New-Object System.Text.StringBuilder

# === HEADER (English, ASCII-safe) ===
[void]$sb.AppendLine("# SHINOBI CORE - Full Code Dump")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("**Date:** " + (Get-Date -Format "yyyy-MM-dd HH:mm:ss"))
[void]$sb.AppendLine("**Minecraft Version:** 1.20.1 (Fabric)")
[void]$sb.AppendLine("**Project Path:** E:\Games\mod")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("---")
[void]$sb.AppendLine("")

# === PROJECT SUMMARY (English) ===
$summary = @'
## Project Summary

Shinobi Core is a Fabric mod for Minecraft 1.20.1 that adds a full ninja combat system inspired by Naruto.

### Implemented Systems
- **Chakra System** — resource for techniques, regeneration, fatigue, exhaustion
- **Jutsu System** — 20 techniques, JSON-driven (fire, water, wind, lightning, earth)
- **Skill Tree** — 51 nodes in 18 columns (advancement-style UI)
- **Taijutsu** — melee combat, combo system, kicks, Strong Fist style
- **Kenjutsu** — katana combat with 3 stances (Aggressive/Seigan/Iai) and deflect
- **Shurikenjutsu** — shurikens and kunai with aim assist
- **Attunement** — minigame for selecting nature affinity
- **Meditation** — chakra regen in rest state
- **Clans** — 6 clans with unique passives (uchiha, hyuga, uzumaki, nara, hatake, sarutobi)
- **Animations** — stance poses, kick/slash animations, breathing/fidgets
- **HUD** — chakra bar, stats, stance indicator
- **Passives** — tree passives (Iron Will, Combo Master+, Sensory, etc.)
- **Sensory Toggle** — Y key to toggle sensory technique (360 deg glow on enemies)
- **Kekkei Genkai** — hidden branch for clan+2natures

### Current Focus: Kenjutsu
Latest work was on the katana combat system:
- KatanaItem (iron sword material, +4 damage)
- 3 stances: Aggressive (DPS), Seigan (deflect), Iai (burst crit)
- **Seigan 360 deg deflect** — hold X in Seigan to reflect all incoming projectiles
- **Aggressive 650ms tap window** — tap X to deflect from front
- Kick (V) works with katana in hand
- Seigan shield applies Slowness III while held

### Known Issues / Incomplete
- Seigan 360 deg deflect needs final verification
- Seigan Slowness effect needs verification
- Cast animations — basic hand seals only
- Kekkei Genkai passives registered but not all effects active yet

### Planned Next Phases
- **Phase B: Genjutsu** — illusion techniques (target-based debuffs)
- **Phase D: Kekkei Genkai deepening** — bloodline powers
- **Phase E: Visual polish** — hand seal animations, cast glow, particles

### Architecture
- `NinjaPlayerData` — holds all ninja data per player
- `NinjaDataHolder` (mixin interface) — access data from PlayerEntity
- `ClientNinjaState` — client-side copy for rendering
- `ModPackets` — all network packets (cast, stance, deflect, sensory, etc.)
- `SkillTreeRegistry` / `JutsuRegistry` / `ClanRegistry` — JSON data loaders
- Mixins: NinjaData, PlayerAttack, PlayerRenderAnimation, KatanaDeflect, PlayerCopy, PlayerParry

'@
[void]$sb.AppendLine($summary)
[void]$sb.AppendLine("---")
[void]$sb.AppendLine("")

# === FULL JAVA DUMP ===
[void]$sb.AppendLine("## Full Java Code")
[void]$sb.AppendLine("")

$javaFiles = Get-ChildItem -Path $srcDir -Filter "*.java" -Recurse | Sort-Object FullName
foreach ($file in $javaFiles) {
    $rel = $file.FullName.Substring($srcDir.Length + 1).Replace('\', '/')
    [void]$sb.AppendLine("### $rel")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine('``````java')
    try {
        $content = [System.IO.File]::ReadAllText($file.FullName, $utf8)
        [void]$sb.AppendLine($content)
    } catch {
        [void]$sb.AppendLine("ERROR reading file: " + $_.Exception.Message)
    }
    [void]$sb.AppendLine('``````')
    [void]$sb.AppendLine("")
}

# === JSON RESOURCES DUMP ===
[void]$sb.AppendLine("---")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("## JSON Resources")
[void]$sb.AppendLine("")

$jsonFiles = Get-ChildItem -Path $resDir -Filter "*.json" -Recurse | Sort-Object FullName
foreach ($file in $jsonFiles) {
    $rel = $file.FullName.Substring($resDir.Length + 1).Replace('\', '/')
    [void]$sb.AppendLine("### $rel")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine('``````json')
    try {
        $content = [System.IO.File]::ReadAllText($file.FullName, $utf8)
        [void]$sb.AppendLine($content)
    } catch {
        [void]$sb.AppendLine("ERROR reading file: " + $_.Exception.Message)
    }
    [void]$sb.AppendLine('``````')
    [void]$sb.AppendLine("")
}
