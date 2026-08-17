$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$root = "E:\Games\mod"

function Patch-File($p, $old, $new) {
    $path = Join-Path $root $p
    if (-not (Test-Path $path)) { Write-Host "[MISS] $path" -ForegroundColor Red; return }
    $c = [System.IO.File]::ReadAllText($path, $utf8)
    $c = $c.Replace("`r`n", "`n")
    $old = $old.Replace("`r`n", "`n")
    $new = $new.Replace("`r`n", "`n")
    if ($c.Contains($new)) { Write-Host "[SKIP] already applied: $p" -ForegroundColor Yellow; return }
    if (-not $c.Contains($old)) { Write-Host "[FAIL] pattern not found in $p" -ForegroundColor Red; return }
    $c = $c.Replace($old, $new)
    [System.IO.File]::WriteAllText($path, $c, $utf8)
    Write-Host "[OK] patched $p" -ForegroundColor Green
}

Write-Host "=== S3-02: Contextual HUD (ChakraHudRenderer) ===" -ForegroundColor Cyan
Patch-File "src\main\java\com\example\shinobicore\client\ChakraHudRenderer.java" @"
        float chakraRatio = maxChakra > 0 ? currentChakra / maxChakra : 0;
        bars.add(new BarSpec(chakraRatio, CHAKRA_LIGHT, CHAKRA_DARK, chakraRatio < 0.25f && !exhausted,
                             "CH", (int) currentChakra + "/" + (int) maxChakra));
        float stamRatio = maxStamina > 0 ? currentStamina / maxStamina : 0;
        bars.add(new BarSpec(stamRatio, 0xFF44EE44, 0xFF22AA22, stamRatio < 0.25f,
                             "ST", (int) currentStamina + "/" + (int) maxStamina));
"@ @"
        boolean inCombat = client.player.hurtTime > 0 || client.player.isSprinting() || com.example.shinobicore.client.combat.TaijutsuClientHandler.isAttacking();
        float chakraRatio = maxChakra > 0 ? currentChakra / maxChakra : 0;
        if (chakraRatio < 1.0f || inCombat) {
            bars.add(new BarSpec(chakraRatio, CHAKRA_LIGHT, CHAKRA_DARK, chakraRatio < 0.25f && !exhausted,
                                 "CH", (int) currentChakra + "/" + (int) maxChakra));
        }
        float stamRatio = maxStamina > 0 ? currentStamina / maxStamina : 0;
        if (stamRatio < 1.0f || inCombat) {
            bars.add(new BarSpec(stamRatio, 0xFF44EE44, 0xFF22AA22, stamRatio < 0.25f,
                                 "ST", (int) currentStamina + "/" + (int) maxStamina));
        }
"@

Write-Host "=== S3-04: State Icons (ChakraHudRenderer) ===" -ForegroundColor Cyan
Patch-File "src\main\java\com\example\shinobicore\client\ChakraHudRenderer.java" @"
        if (ClientNinjaState.chakraMode) {
            int alpha = (int) (150 + 105 * Math.sin(System.currentTimeMillis() / 200.0));
            context.drawTextWithShadow(client.textRenderer, Text.literal("CHAKRA MODE"), 10, y,
                                       ColorHelper.Argb.getArgb(alpha, 255, 136, 0));
            y += 10;
        }
        if (exhausted) {
            context.drawTextWithShadow(client.textRenderer, Text.literal("EXHAUSTED"), 10, y, 0xFF3333);
            y += 10;
        }
        if (ClientNinjaState.unlockedNodes.contains("sen_glow")) {
            context.drawTextWithShadow(client.textRenderer,
                                       Text.literal(ClientNinjaState.sensoryEnabled ? "SENSORY ON" : "SENSORY OFF"),
                                       10, y, ClientNinjaState.sensoryEnabled ? 0xFF66DDFF : 0xFF666666);
            y += 10;
        }
        if (ClientNinjaState.dangerSense) {
            int alpha = (int) (150 + 105 * Math.sin(System.currentTimeMillis() / 150.0));
            context.drawTextWithShadow(client.textRenderer, Text.literal("!! DANGER !!"), 10, y,
                                       ColorHelper.Argb.getArgb(alpha, 255, 60, 60));
            y += 10;
        }
"@ @"
        // === S3-04: STATE ICONS ===
        int iconX = 10;
        int iconY = y;
        if (ClientNinjaState.chakraMode) {
            drawStateIcon(context, iconX, iconY, 0xCCFF8800, 0xFFFFAA00, "C", 0xFFFFFFFF);
            iconX += 14;
        }
        if (exhausted) {
            drawStateIcon(context, iconX, iconY, 0xCC333333, 0xFFFF3333, "X", 0xFFFF3333);
            iconX += 14;
        }
        if (ClientNinjaState.unlockedNodes.contains("sen_glow")) {
            int bg = ClientNinjaState.sensoryEnabled ? 0xCC0088FF : 0xCC333333;
            int border = ClientNinjaState.sensoryEnabled ? 0xFF00AAFF : 0xFF666666;
            drawStateIcon(context, iconX, iconY, bg, border, "S", 0xFFFFFFFF);
            iconX += 14;
        }
        if (ClientNinjaState.dangerSense) {
            int alpha = (int) (150 + 105 * Math.sin(System.currentTimeMillis() / 150.0));
            drawStateIcon(context, iconX, iconY, ColorHelper.Argb.getArgb(alpha, 255, 60, 60), 0xFFFF3333, "!", 0xFFFFFFFF);
            iconX += 14;
        }
        if (client.player.getMainHandStack().getItem() instanceof com.example.shinobicore.item.KatanaItem) {
            String st = ClientNinjaState.kenjutsuStance;
            int bg = st.equals("seigan") ? 0xCC0066FF : st.equals("iai") ? 0xCCFFAA00 : 0xCCFF3333;
            int border = st.equals("seigan") ? 0xFF0088FF : st.equals("iai") ? 0xFFFFCC00 : 0xFFFF5555;
            String sym = st.equals("seigan") ? "D" : st.equals("iai") ? "I" : "A";
            drawStateIcon(context, iconX, iconY, bg, border, sym, 0xFFFFFFFF);
            iconX += 14;
        }
        com.example.shinobicore.combat.TaijutsuStyle currentStyle = com.example.shinobicore.client.combat.TaijutsuClientHandler.getCurrentStyle();
        if (currentStyle == com.example.shinobicore.combat.TaijutsuStyle.STRONG_FIST) {
            drawStateIcon(context, iconX, iconY, 0xCC00AA00, 0xFF44FF44, "F", 0xFFFFFFFF);
            iconX += 14;
        }
        if (iconX > 10) {
            y = iconY + 16;
        }
"@

Patch-File "src\main\java\com\example\shinobicore\client\ChakraHudRenderer.java" @"
        // === СТИЛЬ ТАЙ-ДЗЮЦУ ===
        TaijutsuStyle currentStyle = TaijutsuClientHandler.getCurrentStyle();
        String styleName = currentStyle == TaijutsuStyle.STRONG_FIST ? "[Strong Fist]" : "[Standard]";
        int styleColor = currentStyle == TaijutsuStyle.STRONG_FIST ? 0xFF44FF44 : 0xFFAAAAAA;
        ShinobiCore.LOGGER.debug("[HUD] Style: {}", currentStyle.getId());
        context.drawTextWithShadow(client.textRenderer, Text.literal(styleName), 10, y + 10, styleColor);
        y += 12;

        if (client.player.getMainHandStack().getItem() instanceof com.example.shinobicore.item.KatanaItem) {
            String st = ClientNinjaState.kenjutsuStance;
            int stColor = st.equals("seigan") ? 0xFF66AAFF : st.equals("iai") ? 0xFFFFAA00 : 0xFFFF5555;
            context.drawTextWithShadow(client.textRenderer, Text.literal("[" + st.toUpperCase() + "]"), 10, y + 10, stColor);
            y += 12;
        }
"@ @"
        // S3-04: Stance and Style are now rendered as icons above
"@

Patch-File "src\main\java\com\example\shinobicore\client\ChakraHudRenderer.java" @"
    private static void drawScaledText(DrawContext context, MinecraftClient client, String text,
                                       float x, float y, int color, float scale) {
"@ @"
    private static void drawStateIcon(DrawContext ctx, int x, int y, int bgColor, int borderColor, String symbol, int textColor) {
        ctx.fill(x, y, x + 12, y + 12, borderColor);
        ctx.fill(x + 1, y + 1, x + 11, y + 11, bgColor);
        int tw = ctx.getTextRenderer().getWidth(symbol);
        ctx.drawTextWithShadow(ctx.getTextRenderer(), Text.literal(symbol), x + 6 - tw/2, y + 2, textColor);
    }

    private static void drawScaledText(DrawContext context, MinecraftClient client, String text,
                                       float x, float y, int color, float scale) {
"@

Write-Host "=== S3-08: Skill Tree Filters (SkillTreeScreen) ===" -ForegroundColor Cyan
Patch-File "src\main\java\com\example\shinobicore\client\SkillTreeScreen.java" @"
import java.util.*;
"@ @"
import java.util.*;
import net.minecraft.client.gui.widget.TextFieldWidget;
import net.minecraft.client.gui.widget.ButtonWidget;
"@

Patch-File "src\main\java\com\example\shinobicore\client\SkillTreeScreen.java" @"
    private boolean centered = false;
"@ @"
    private boolean centered = false;
    private TextFieldWidget searchBox;
    private boolean filterAvailable = false;
    private boolean filterLearned = false;
    private boolean filterLocked = false;
    private String filterBranch = "all";
"@

Patch-File "src\main\java\com\example\shinobicore\client\SkillTreeScreen.java" @"
    public SkillTreeScreen() { super(Text.literal("Skill Tree")); }
"@ @"
    public SkillTreeScreen() { super(Text.literal("Skill Tree")); }

    @Override
    protected void init() {
        super.init();
        searchBox = new TextFieldWidget(textRenderer, width / 2 - 100, 26, 200, 14, Text.literal("Search"));
        searchBox.setMaxLength(50);
        addDrawableChild(searchBox);
        
        int bx = 10;
        int by = 26;
        addDrawableChild(ButtonWidget.builder(Text.literal("Avail"), b -> { filterAvailable = !filterAvailable; })
            .dimensions(bx, by, 40, 14).build());
        bx += 42;
        addDrawableChild(ButtonWidget.builder(Text.literal("Learned"), b -> { filterLearned = !filterLearned; })
            .dimensions(bx, by, 50, 14).build());
        bx += 52;
        addDrawableChild(ButtonWidget.builder(Text.literal("Locked"), b -> { filterLocked = !filterLocked; })
            .dimensions(bx, by, 46, 14).build());
        bx += 48;
        addDrawableChild(ButtonWidget.builder(Text.literal("Branch: All"), b -> {
            cycleBranch();
            b.setMessage(Text.literal("Branch: " + filterBranch));
        }).dimensions(bx, by, 80, 14).build());
    }

    private void cycleBranch() {
        List<String> branches = new ArrayList<>(SkillTreeRegistry.getAllBranches().stream().map(SkillTreeRegistry.BranchDef::id).toList());
        branches.add(0, "all");
        int idx = branches.indexOf(filterBranch);
        filterBranch = branches.get((idx + 1) % branches.size());
    }

    private boolean matchesSearch(SkillTreeNode n) {
        if (searchBox == null || searchBox.getText().isEmpty()) return true;
        String q = searchBox.getText().toLowerCase();
        if (n.displayName().toLowerCase().contains(q)) return true;
        if (n.id().toLowerCase().contains(q)) return true;
        if (n.branch().toLowerCase().contains(q)) return true;
        if (n.jutsuId() != null) {
            String jutsuName = ClientNinjaState.name(n.jutsuId());
            if (jutsuName.toLowerCase().contains(q)) return true;
        }
        return false;
    }

    private boolean matchesFilters(SkillTreeNode n) {
        boolean unlocked = ClientNinjaState.unlockedNodes.contains(n.id());
        boolean available = canUnlock(n);
        
        if (filterAvailable && !available) return false;
        if (filterLearned && !unlocked) return false;
        if (filterLocked && unlocked) return false;
        if (!filterBranch.equals("all") && !n.branch().equals(filterBranch)) return false;
        
        return true;
    }
"@

Patch-File "src\main\java\com\example\shinobicore\client\SkillTreeScreen.java" @"
        // === ВЕРХНЯЯ ПЛАШКА (вайб Наруто) ===
        ctx.fill(0, 0, width, 22, 0xCC000000);
        ctx.fill(0, 22, width, 23, 0xFFB4470F);
        drawCentered(ctx, "SHINOBI PATH  |  SP: " + ClientNinjaState.skillPoints
                     + "  |  Clan: " + ClientNinjaState.clanId + "  |  ESC - close",
                     width / 2, 7, 0xFFFFAA00);
"@ @"
        // === ВЕРХНЯЯ ПЛАШКА (вайб Наруто) ===
        ctx.fill(0, 0, width, 44, 0xCC000000);
        ctx.fill(0, 44, width, 45, 0xFFB4470F);
        drawCentered(ctx, "SHINOBI PATH  |  SP: " + ClientNinjaState.skillPoints
                     + "  |  Clan: " + ClientNinjaState.clanId + "  |  ESC - close",
                     width / 2, 7, 0xFFFFAA00);
"@

Patch-File "src\main\java\com\example\shinobicore\client\SkillTreeScreen.java" @"
        for (String b : order) {
            BranchDef def = SkillTreeRegistry.getBranch(b);
            if (def == null || !isBranchVisible(def)) continue;
"@ @"
        for (String b : order) {
            BranchDef def = SkillTreeRegistry.getBranch(b);
            if (def == null || !isBranchVisible(def)) continue;
            if (!filterBranch.equals("all") && !b.equals(filterBranch)) continue;
"@

Patch-File "src\main\java\com\example\shinobicore\client\SkillTreeScreen.java" @"
        for (SkillTreeNode n : SkillTreeRegistry.getAll()) {
            if (!SkillTreeRegistry.isVisibleClient(n)) continue;
            int[] c = worldPos(n);
            for (String req : n.requires()) {
                SkillTreeNode p = SkillTreeRegistry.get(req);
                if (p == null || !SkillTreeRegistry.isVisibleClient(p)) continue;
"@ @"
        for (SkillTreeNode n : SkillTreeRegistry.getAll()) {
            if (!SkillTreeRegistry.isVisibleClient(n)) continue;
            if (!matchesSearch(n) || !matchesFilters(n)) continue;
            int[] c = worldPos(n);
            for (String req : n.requires()) {
                SkillTreeNode p = SkillTreeRegistry.get(req);
                if (p == null || !SkillTreeRegistry.isVisibleClient(p)) continue;
                if (!matchesSearch(p) || !matchesFilters(p)) continue;
"@

Patch-File "src\main\java\com\example\shinobicore\client\SkillTreeScreen.java" @"
        // === УЗЛЫ-СЛОТЫ ===
        for (SkillTreeNode n : SkillTreeRegistry.getAll()) {
            if (!SkillTreeRegistry.isVisibleClient(n)) continue;
"@ @"
        // === УЗЛЫ-СЛОТЫ ===
        for (SkillTreeNode n : SkillTreeRegistry.getAll()) {
            if (!SkillTreeRegistry.isVisibleClient(n)) continue;
            if (!matchesSearch(n) || !matchesFilters(n)) continue;
"@

Write-Host "=== Done! Run gradlew build ===" -ForegroundColor Green