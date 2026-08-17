$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)

Write-Host "=== Applying S3-02, S3-04, S3-08 safely ===" -ForegroundColor Cyan

# ==========================================
# 1. ChakraHudRenderer.java (S3-02 & S3-04)
# ==========================================
$hudFile = "src\main\java\com\example\shinobicore\client\ChakraHudRenderer.java"
$c1 = [System.IO.File]::ReadAllText($hudFile, $utf8)

# Заменяем вертикальный список текстовых статусов на горизонтальные бейджи (S3-04)
# Якорь: от if (ClientNinjaState.chakraMode) до if (RasenganClientState.charging)
$pattern1 = '(?s)if \(ClientNinjaState\.chakraMode\) \{.*?y \+= 10;\s*\}\s*(?:.*?===.*?===\s*)?if \(RasenganClientState\.charging\)'

$replacement1 = @'
        // === S3-02 & S3-04: Contextual HUD & State Badges ===
        boolean inCombat = client.player.hurtTime > 0 || client.player.getHealth() < client.player.getMaxHealth() || currentChakra < maxChakra * 0.9f || currentStamina < maxStamina * 0.9f;
        
        int badgeX = 10;
        int badgeY = y;
        int badgeW = 65;
        int badgeH = 10;
        
        if (ClientNinjaState.chakraMode) {
            context.fill(badgeX, badgeY, badgeX + badgeW, badgeY + badgeH, 0xCCFF8800);
            drawScaledText(context, client, "CHAKRA", badgeX + 2, badgeY + 1, 0xFFFFFFFF, 0.7f);
            badgeX += badgeW + 2;
        }
        if (exhausted) {
            context.fill(badgeX, badgeY, badgeX + badgeW, badgeY + badgeH, 0xCC3333);
            drawScaledText(context, client, "EXHAUST", badgeX + 2, badgeY + 1, 0xFFFFFFFF, 0.7f);
            badgeX += badgeW + 2;
        }
        if (ClientNinjaState.unlockedNodes.contains("sen_glow") && ClientNinjaState.sensoryEnabled) {
            context.fill(badgeX, badgeY, badgeX + badgeW, badgeY + badgeH, 0xCC66DDFF);
            drawScaledText(context, client, "SENSOR", badgeX + 2, badgeY + 1, 0xFFFFFFFF, 0.7f);
            badgeX += badgeW + 2;
        }
        if (ClientNinjaState.dangerSense) {
            int alpha = (int) (150 + 105 * Math.sin(System.currentTimeMillis() / 150.0));
            context.fill(badgeX, badgeY, badgeX + badgeW, badgeY + badgeH, ColorHelper.Argb.getArgb(alpha, 255, 60, 60));
            drawScaledText(context, client, "DANGER", badgeX + 2, badgeY + 1, 0xFFFFFFFF, 0.7f);
            badgeX += badgeW + 2;
        }
        if (badgeX > 10) {
            y += badgeH + 2;
        }

        if (RasenganClientState.charging)
'@

if ($c1 -match 'if \(ClientNinjaState\.chakraMode\)') {
    $c1_new = [regex]::Replace($c1, $pattern1, $replacement1)
    if ($c1 -ne $c1_new) {
        [System.IO.File]::WriteAllText($hudFile, $c1_new, $utf8)
        Write-Host "[OK] Patched ChakraHudRenderer (Badges & Context)" -ForegroundColor Green
    } else {
        Write-Host "[SKIP] ChakraHudRenderer already patched" -ForegroundColor Yellow
    }
} else {
    Write-Host "[WARN] ChakraHudRenderer anchor missing" -ForegroundColor Red
}

# ==========================================
# 2. SkillTreeScreen.java (S3-08)
# ==========================================
$treeFile = "src\main\java\com\example\shinobicore\client\SkillTreeScreen.java"
$c2 = [System.IO.File]::ReadAllText($treeFile, $utf8)

# 2.1 Добавляем поля для поиска и фильтров
if ($c2 -notmatch 'private net\.minecraft\.client\.gui\.widget\.TextFieldWidget searchBox;') {
    $c2 = $c2.Replace("private float zoom = 1.0f;", "private float zoom = 1.0f;`n    private net.minecraft.client.gui.widget.TextFieldWidget searchBox;`n    private String searchQuery = `"`";`n    private String filterMode = `"all`";")
    Write-Host "[OK] Added search fields to SkillTreeScreen" -ForegroundColor Green
}

# 2.2 Добавляем метод init() с полем ввода и кнопками
if ($c2 -notmatch 'protected void init\(\)') {
    $initMethod = @"

    @Override
    protected void init() {
        super.init();
        searchBox = new net.minecraft.client.gui.widget.TextFieldWidget(client.textRenderer, width / 2 - 100, 25, 200, 16, Text.literal("Search"));
        searchBox.setChangedListener(s -> searchQuery = s.toLowerCase());
        addDrawableChild(searchBox);
        
        int btnW = 50;
        int btnX = width / 2 - 125;
        addDrawableChild(net.minecraft.client.gui.widget.ButtonWidget.builder(Text.literal("All"), b -> filterMode = "all").dimensions(btnX, 45, btnW, 14).build());
        addDrawableChild(net.minecraft.client.gui.widget.ButtonWidget.builder(Text.literal("Avail"), b -> filterMode = "available").dimensions(btnX + 55, 45, btnW, 14).build());
        addDrawableChild(net.minecraft.client.gui.widget.ButtonWidget.builder(Text.literal("Unlck"), b -> filterMode = "unlocked").dimensions(btnX + 110, 45, btnW, 14).build());
        addDrawableChild(net.minecraft.client.gui.widget.ButtonWidget.builder(Text.literal("Lock"), b -> filterMode = "locked").dimensions(btnX + 165, 45, btnW, 14).build());
    }
"@
    $c2 = $c2.Replace("public SkillTreeScreen() { super(Text.literal(`"Skill Tree`")); }", "public SkillTreeScreen() { super(Text.literal(`"Skill Tree`")); }$initMethod")
    Write-Host "[OK] Added init() with UI elements to SkillTreeScreen" -ForegroundColor Green
}

# 2.3 Внедряем логику фильтрации в цикл отрисовки узлов
$filterLogic = @"
            if (!SkillTreeRegistry.isVisibleClient(n)) continue;
            
            // === S3-08: Search & Filter ===
            if (searchQuery != null && !searchQuery.isEmpty()) {
                boolean matches = n.id().toLowerCase().contains(searchQuery) || 
                                  n.displayName().toLowerCase().contains(searchQuery) ||
                                  (n.description() != null && n.description().toLowerCase().contains(searchQuery));
                if (!matches) continue;
            }
            if (filterMode != null && !filterMode.equals("all")) {
                boolean unlocked = ClientNinjaState.unlockedNodes.contains(n.id());
                boolean available = canUnlock(n);
                if (filterMode.equals("available") && !available) continue;
                if (filterMode.equals("unlocked") && !unlocked) continue;
                if (filterMode.equals("locked") && (unlocked || available)) continue;
            }
"@

if ($c2 -match 'if \(!SkillTreeRegistry\.isVisibleClient\(n\)\) continue;') {
    $c2 = $c2.Replace("if (!SkillTreeRegistry.isVisibleClient(n)) continue;", $filterLogic)
    Write-Host "[OK] Injected filter logic into SkillTreeScreen render loop" -ForegroundColor Green
}

[System.IO.File]::WriteAllText($treeFile, $c2, $utf8)
Write-Host "=== Done! Run .\gradlew.bat build ===" -ForegroundColor Cyan