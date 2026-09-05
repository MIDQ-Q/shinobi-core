# рџ§Є Р’Р•Р РР¤РРљРђР¦РРЇ JUTSU v2 - РџРћР›РќР«Р™ Р§Р•Рљ-Р›РРЎРў

## рџ“‹ РРЅСЃС‚СЂСѓРєС†РёРё

1. Р—Р°РїСѓСЃС‚Рё РёРіСЂСѓ: `.\gradlew.bat runClient`
2. Р’ РёРіСЂРµ: `/reload`
3. РџСЂРѕРіРѕРЅСЏР№ РєРѕРјР°РЅРґС‹ РЅРёР¶Рµ **РїРѕ РѕРґРЅРѕР№**
4. РџСЂРѕРІРµСЂСЏР№ СЂРµР·СѓР»СЊС‚Р°С‚ РІ РёРіСЂРµ + РІ С„Р°Р№Р»Рµ `verification_results.txt`

## рџ“ќ Р¤РѕСЂРјР°С‚ Р»РѕРіР°

[YYYY-MM-DD HH:MM:SS] [CATEGORY] DETAILS
**РљР°С‚РµРіРѕСЂРёРё:**
- `CAST` - РїРѕРїС‹С‚РєР° РєР°СЃС‚Р°
- `HIT` - РїРѕРїР°РґР°РЅРёРµ РїРѕ С†РµР»Рё
- `EFFECT` - РїСЂРёРјРµРЅРµРЅРёРµ СЌС„С„РµРєС‚Р°
- `PROPERTY` - Р°РєС‚РёРІР°С†РёСЏ СЃРІРѕР№СЃС‚РІР°
- `ACTIVATION` - СЃС‚Р°С‚СѓСЃ Р°РєС‚РёРІР°С†РёРё
- `PROGRESSION` - РёР·РјРµРЅРµРЅРёСЏ СѓСЂРѕРІРЅСЏ/uses
- `ERROR` - РѕС€РёР±РєРё

---

## рџЋЇ РўР•РЎРўР«

РџСЂРѕРіРѕРЅРё РІСЃРµ 30 С‚РµСЃС‚РѕРІС‹С… С‚РµС…РЅРёРє РёР· `verification_kit.ps1`:

### Р¤РѕСЂРјС‹ (8)
- test_point_heal
- test_projectile_volley
- test_beam
- test_zone_slow
- test_dash
- test_handheld
- test_construct_wall
- test_summon

### Р­С„С„РµРєС‚С‹ (4)
- test_damage_kit
- test_control_kit
- test_buff_kit
- test_debuff_kit

### World Effects (3)
- test_world_ignite
- test_world_freeze
- test_world_transform

### Properties (9)
- test_prop_homing
- test_prop_bouncing
- test_prop_splitting
- test_prop_chaining
- test_prop_piercing
- test_prop_boomerang
- test_prop_orbiting
- test_prop_stick_lifesteal
- test_prop_explosions

### РђРєС‚РёРІР°С†РёРё (6)
- test_act_handseals
- test_act_charge
- test_act_hold
- test_act_counter
- test_act_on_death
- test_act_passive

### РџСЂРѕРіСЂРµСЃСЃРёСЏ
- test_progression_fireball

---

## вњ… РРўРћР“РћР’РђРЇ РџР РћР’Р•Р РљРђ

РџРѕСЃР»Рµ РІСЃРµС… С‚РµСЃС‚РѕРІ РѕС‚РєСЂРѕР№ `verification_results.txt` Рё РїСЂРѕРІРµСЂСЊ:

- [ ] Р¤Р°Р№Р» СЃСѓС‰РµСЃС‚РІСѓРµС‚
- [ ] РЎРѕРґРµСЂР¶РёС‚ Р·Р°РїРёСЃРё РІСЃРµС… РєР°С‚РµРіРѕСЂРёР№ (CAST, HIT, EFFECT, PROPERTY, ACTIVATION, PROGRESSION)
- [ ] РќРµС‚ Р·Р°РїРёСЃРµР№ `[ERROR]`
- [ ] Р’СЃРµ 30 С‚РµСЃС‚РѕРІС‹С… С‚РµС…РЅРёРє Р±С‹Р»Рё РєР°СЃС‚РѕРІР°РЅС‹
- [ ] Timestamp РєРѕСЂСЂРµРєС‚РЅС‹Р№

**Р•СЃР»Рё РІСЃС‘ вњ… вЂ” РІРµСЂРёС„РёРєР°С†РёСЏ РїСЂРѕР№РґРµРЅР°! РџРµСЂРµС…РѕРґРёРј Рє Editor v3.** рџЌҐ