# ShinobiCore Jutsu Generator

## How to Use

1. Open `jutsu_generator.html` in any web browser
2. Fill in the tabs:
   - **Basic**: Name, category, element, rank, tags
   - **Behavior**: Select behavior type, target mode, cast time, cooldown
   - **Stats & Balance**: Cost, damage, range, radius, duration, strain
   - **Leveling**: Max level, scaling, uses per level, level effects
   - **Visual**: Particles, colors, trail, sounds
   - **Requirements**: Stat requirements, element requirements, learn sources
3. Go to **Preview** tab to see visual preview
4. Go to **Export** tab and click **Generate JSON**
5. Click **Download .json** to save the file
6. Place the downloaded `.json` file in:
   `src/main/resources/data/shinobicore/jutsu/`
7. Rebuild the mod: `gradlew.bat build`
8. Launch the game - the jutsu will be loaded automatically

## Import

You can also import existing jutsu JSON files:
1. Go to **Import** tab
2. Click the drop area to select a `.json` file
3. The form will be populated with the imported values
4. Modify as needed and export again

## Presets

`visual_presets.json` contains preset visual configurations for common jutsu types:
- Fireball (fire projectile)
- Water Bullet (water projectile)
- Wind Blade (wind projectile)
- Lightning Strike (lightning AoE)
- Earth Wall (earth wall)
- Genjutsu (mental attack)
- Sensory (detection)
- Healing (buff)

## File Placement

Generated files must be placed in:
`src/main/resources/data/shinobicore/jutsu/<jutsu_id>.json`

The file name should match the jutsu ID (without the `shinobicore:` prefix).

## Notes

- All values are validated by the generator before export
- The generator produces JSON compatible with ShinobiCore 4.0.0
- Leveling uses interpolation between base and max values
- Level effects can add special effects at specific levels