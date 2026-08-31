# Master script for Clans Module - Phase 5 (UI, CCA Initializer, Handoff)
# STRICTLY ASCII-ONLY to comply with CORE_DOCUMENTATION.md Section 6.4

$ErrorActionPreference = "Stop"
$ProjectRoot = $PSScriptRoot

function Write-File {
    param([string]$Path, [string]$Content)
    $dir = Split-Path -Parent $Path
    if (!(Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
    Write-Host "[+] Created: $Path" -ForegroundColor Green
}

Write-Host "[*] Starting Clans Module Phase 5 (UI, CCA, Handoff)..." -ForegroundColor Cyan

# ==============================================================================
# 1. CCA COMPONENT INITIALIZER (Required for fabric.mod.json entrypoint)
# ==============================================================================
Write-File -Path "$ProjectRoot/src/main/java/com/example/shinobicore/modules/clans/component/ClanComponentInitializer.java" -Content @"
package com.example.shinobicore.modules.clans.component;

import com.example.shinobicore.modules.clans.ClansModule;
import dev.onyxstudios.cca.api.v3.component.ComponentKey;
import dev.onyxstudios.cca.api.v3.component.ComponentRegistry;
import dev.onyxstudios.cca.api.v3.entity.EntityComponentFactoryRegistry;
import dev.onyxstudios.cca.api.v3.entity.EntityComponentInitializer;
import dev.onyxstudios.cca.api.v3.entity.RespawnCopyStrategy;
import net.minecraft.util.Identifier;

public final class ClanComponentInitializer implements EntityComponentInitializer {
    public static final ComponentKey<ClanComponent> CLAN = ComponentRegistry.getOrCreate(
        new Identifier(ClansModule.ID, "clan"), ClanComponent.class
    );

    @Override
    public void registerEntityComponentFactories(EntityComponentFactoryRegistry registry) {
        registry.registerForPlayers(CLAN, player -> new ClanComponent(), RespawnCopyStrategy.ALWAYS_COPY);
    }
}
"@

# Update ClanComponentKey to use the initializer's key to avoid duplication
Write-File -Path "$ProjectRoot/src/main/java/com/example/shinobicore/modules/clans/component/ClanComponentKey.java" -Content @"
package com.example.shinobicore.modules.clans.component;

import dev.onyxstudios.cca.api.v3.component.ComponentKey;
import net.minecraft.entity.player.PlayerEntity;
import java.util.Optional;

public final class ClanComponentKey {
    public static final ComponentKey<ClanComponent> KEY = ClanComponentInitializer.CLAN;

    public static void register() {
        // Registration is handled by ClanComponentInitializer via fabric.mod.json entrypoint
    }

    public static Optional<ClanComponent> get(PlayerEntity player) {
        return Optional.ofNullable(KEY.maybeGet(player).orElse(null));
    }
}
"@

# ==============================================================================
# 2. UI: K-SCREEN TAB (Read-only clan info for HUD/Visual module)
# ==============================================================================
Write-File -Path "$ProjectRoot/src/main/java/com/example/shinobicore/modules/clans/ui/ClanTab.java" -Content @"
package com.example.shinobicore.modules.clans.ui;

import com.example.shinobicore.modules.clans.view.ClanVisualView;
import com.example.shinobicore.core.view.CoreViews;
import net.minecraft.client.gui.DrawContext;
import net.minecraft.entity.player.PlayerEntity;
import net.minecraft.text.Text;
import net.minecraft.util.Formatting;
import java.util.Optional;

public final class ClanTab {
    private ClanTab() {}

    public static void render(DrawContext context, int x, int y, PlayerEntity player) {
        Optional<ClanVisualView> viewOpt = CoreViews.get(player, com.example.shinobicore.modules.clans.view.ClanVisualView.class);
        if (viewOpt.isEmpty()) {
            context.drawText(player.getTextRenderer(), Text.literal("No clan data").formatted(Formatting.GRAY), x, y, 0xFFFFFF, false);
            return;
        }

        ClanVisualView view = viewOpt.get();
        int currentY = y;

        // Clan Name & Color
        String clanName = view.hasClan() ? view.getClanName() : "No Clan";
        int colorHex = parseColor(view.getClanColor());
        context.drawText(player.getTextRenderer(), Text.literal("Clan: " + clanName).formatted(Formatting.BOLD), x, currentY, colorHex, false);
        currentY += 12;

        if (view.hasClan()) {
            // Affinity
            context.drawText(player.getTextRenderer(), Text.literal("Affinity: " + view.getAffinity()), x, currentY, 0xAAAAAA, false);
            currentY += 10;

            // Dojutsu
            if (view.hasDojutsuHook()) {
                context.drawText(player.getTextRenderer(), Text.literal("Dojutsu: " + view.getDojutsuId()).formatted(Formatting.LIGHT_PURPLE), x, currentY, 0xFF55FF, false);
                currentY += 10;
            }

            // Reputation summary
            context.drawText(player.getTextRenderer(), Text.literal("Reputation:"), x, currentY, 0x55FF55, false);
            currentY += 10;
            for (var entry : view.getAllReputations().entrySet()) {
                String repLine = "  " + entry.getKey() + ": " + entry.getValue();
                int repColor = entry.getValue() >= 0 ? 0x55FF55 : 0xFF5555;
                context.drawText(player.getTextRenderer(), Text.literal(repLine), x, currentY, repColor, false);
                currentY += 10;
            }
        }
    }

    private static int parseColor(String hex) {
        if (hex == null || !hex.startsWith("#") || hex.length() != 7) return 0xFFFFFF;
        try {
            return Integer.parseInt(hex.substring(1), 16);
        } catch (NumberFormatException e) {
            return 0xFFFFFF;
        }
    }
}
"@

# ==============================================================================
# 3. UI: CLAN SELECTION SCREEN (Operator-only)
# ==============================================================================
Write-File -Path "$ProjectRoot/src/main/java/com/example/shinobicore/modules/clans/ui/ClanSelectionScreen.java" -Content @"
package com.example.shinobicore.modules.clans.ui;

import com.example.shinobicore.modules.clans.data.ClanDefinition;
import com.example.shinobicore.modules.clans.data.ClanRegistry;
import net.minecraft.client.gui.DrawContext;
import net.minecraft.client.gui.screen.Screen;
import net.minecraft.client.gui.widget.ButtonWidget;
import net.minecraft.text.Text;
import net.minecraft.util.Formatting;

public class ClanSelectionScreen extends Screen {
    private final Screen parent;

    public ClanSelectionScreen(Screen parent) {
        super(Text.literal("Clan Selection"));
        this.parent = parent;
    }

    @Override
    protected void init() {
        super.init();
        int y = 40;
        for (ClanDefinition clan : ClanRegistry.all()) {
            String label = clan.name() + " [" + clan.affinity() + "]";
            addDrawableChild(ButtonWidget.builder(Text.literal(label), button -> {
                // Note: Actual clan change must be done via server command or packet.
                // This is a visual placeholder for operator UI.
                if (client != null && client.player != null) {
                    client.player.networkHandler.sendChatCommand("shinobicore clan set @s " + clan.id());
                }
                close();
            }).dimensions(this.width / 2 - 100, y, 200, 20).build());
            y += 24;
        }
    }

    @Override
    public void render(DrawContext context, int mouseX, int mouseY, float delta) {
        super.render(context, mouseX, mouseY, delta);
        context.drawCenteredTextWithShadow(this.textRenderer, Text.literal("Select Clan").formatted(Formatting.GOLD), this.width / 2, 20, 0xFFFFFF);
    }

    @Override
    public void close() {
        if (this.client != null) {
            this.client.setScreen(this.parent);
        }
    }
}
"@

