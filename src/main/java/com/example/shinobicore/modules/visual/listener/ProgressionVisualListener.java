package com.example.shinobicore.modules.visual.listener;

import com.example.shinobicore.modules.visual.config.VisualConfig;
import com.example.shinobicore.modules.visual.screen.ScreenFlashService;
import com.example.shinobicore.modules.visual.stub.StubEvents;
import com.example.shinobicore.modules.visual.util.ParticleColors;

public final class ProgressionVisualListener {

    public static void onLevelUp(StubEvents.LevelChangedEvent event) {
        if (!VisualConfig.get().screenFlash.enabled) return;
        if (event.newLevel <= event.oldLevel) return;

        ScreenFlashService.flash(
            VisualConfig.get().screenFlash.levelUpColor,
            VisualConfig.get().screenFlash.levelUpDuration
        );
    }

    public static void onXpGained(StubEvents.XpGainedEvent event) {
        // Optional: small sparkle effect on XP gain
        // Kept minimal to avoid spam
    }
}