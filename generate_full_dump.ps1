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
- **Passives** — tree passives (Iron