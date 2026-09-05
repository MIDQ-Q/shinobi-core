package com.example.shinobicore.client.sakura.ui;

import com.example.shinobicore.config.ModConfig;
import net.minecraft.client.MinecraftClient;
import net.minecraft.sound.SoundEvent;
import net.minecraft.util.Identifier;

/** UI feedback sounds on vanilla events (no custom assets). */
public final class UiSounds {
    private static final SoundEvent HOVER = SoundEvent.of(new Identifier("minecraft:block.note_block.hat"));
    private static final SoundEvent TAB = SoundEvent.of(new Identifier("minecraft:item.book.page_turn"));
    private static final SoundEvent CLICK = SoundEvent.of(new Identifier("minecraft:ui.button.click"));
    private static final SoundEvent UNLOCK = SoundEvent.of(new Identifier("minecraft:block.amethyst_block.chime"));
    private static final SoundEvent DENY = SoundEvent.of(new Identifier("minecraft:entity.villager.no"));

    private UiSounds() {}

    public static void hover() { play(HOVER, 0.05f, 1.6f); }
    public static void tab() { play(TAB, 0.35f, 1.1f); }
    public static void click() { play(CLICK, 0.5f, 1.2f); }
    public static void unlock() { play(UNLOCK, 0.6f, 1.2f); play(CLICK, 0.3f, 1.4f); }
    public static void deny() { play(DENY, 0.3f, 1.2f); }

    private static void play(SoundEvent e, float vol, float pitch) {
        if (!ModConfig.instance.hud.uiSounds) return;
        MinecraftClient c = MinecraftClient.getInstance();
        if (c.player != null) c.player.playSound(e, vol, pitch);
    }
}