package com.example.shinobicore.sound;

import com.example.shinobicore.ShinobiCore;
import net.minecraft.registry.Registries;
import net.minecraft.registry.Registry;
import net.minecraft.sound.SoundEvent;
import net.minecraft.util.Identifier;

/**
 * Part 3 (WS-4): регистрация звуковых событий, описанных в sounds.json.
 *
 * До этого 8 из 12 записей sounds.json были инертны: SoundEvent для них
 * никогда не регистрировался, а JutsuSoundHelper.resolve() возвращал
 * захардкоженный ванильный звук по стихии.
 *
 * punch_light / punch_heavy / kick / whoosh намеренно ИСКЛЮЧЕНЫ — их
 * регистрирует клиентский TaijutsuSounds, повторная регистрация привела бы
 * к конфликту ключей в реестре.
 */
public final class ModSounds {

    public static final String[] IDS = {
        "jutsu_fire_cast", "jutsu_water_cast", "jutsu_wind_cast", "jutsu_earth_cast",
        "jutsu_lightning_cast", "jutsu_yin_cast", "jutsu_yang_cast",
        "jutsu_fire_hit", "jutsu_water_hit", "jutsu_wind_hit", "jutsu_earth_hit",
        "jutsu_lightning_hit", "jutsu_impact", "jutsu_hit",
        "jutsu_charge_loop", "jutsu_beam_loop", "jutsu_channel_end",
        "jutsu_seal_weave", "jutsu_summon_poof", "jutsu_dash_whoosh"
    };

    private ModSounds() {}

    public static SoundEvent of(String path) {
        return SoundEvent.of(new Identifier(ShinobiCore.MOD_ID, path));
    }

    public static void register() {
        int n = 0;
        for (String id : IDS) {
            Identifier ident = new Identifier(ShinobiCore.MOD_ID, id);
            try {
                Registry.register(Registries.SOUND_EVENT, ident, SoundEvent.of(ident));
                n++;
            } catch (Exception e) {
                // уже зарегистрировано (например, клиентским TaijutsuSounds) — не ошибка
                ShinobiCore.LOGGER.warn("Sound event {} not registered: {}", id, e.getMessage());
            }
        }
        ShinobiCore.LOGGER.info("Registered {} ShinobiCore sound events", n);
    }
}
// P3_MOD_SOUNDS_DONE