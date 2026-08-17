$ErrorActionPreference = "Continue"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$root = "E:\Games\mod"
$src = "$root\src\main\java\com\example\shinobicore"

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "  SHINOBI CORE: S3 HUD Integration Script" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""

# ---------------------------------------------------------
# 1. Patch ProgressionScreen.java (Добавляем кнопку HUD)
# ---------------------------------------------------------
$progFile = "$src\client\ProgressionScreen.java"
if (Test-Path $progFile) {
    $c = [System.IO.File]::ReadAllText($progFile, $utf8).Replace("`r`n", "`n")
    
    # Патчим render()
    $oldRender = 'drawCentered(context, clanText + "  |  " + affText + "  |  SP: " + ClientNinjaState.skillPoints,'
    $newRender = @'
drawCentered(context, clanText + "  |  " + affText + "  |  SP: " + ClientNinjaState.skillPoints,
x0 + w / 2, y0 + 8, INK);

// === S3 HUD SETTINGS BUTTON ===
int btnX = x0 + w - 45;
int btnY = y0 + 4;
int btnW = 40;
int btnH = 12;
boolean hoverBtn = inRect(mouseX, mouseY, btnX, btnY, btnW, btnH);
context.fill(btnX, btnY, btnX + btnW, btnY + btnH, hoverBtn ? ACCENT : WOOD_DARK);
drawCentered(context, "HUD", btnX + btnW / 2, btnY + 2, 0xFFFFFFFF);
'@
    
    if ($c.Contains("S3 HUD SETTINGS BUTTON")) {
        Write-Host "[SKIP] ProgressionScreen.java already patched (render)" -ForegroundColor Yellow
    } elseif ($c.Contains($oldRender)) {
        $c = $c.Replace($oldRender, $newRender)
        Write-Host "[OK] Patched ProgressionScreen.java (render)" -ForegroundColor Green
    } else {
        Write-Host "[WARN] Could not find render pattern in ProgressionScreen.java" -ForegroundColor Red
    }

    # Патчим mouseClicked()
    $oldClick = 'if (tab == 4) {'
    $newClick = @'
// === S3 HUD SETTINGS BUTTON CLICK ===
int btnX = x0 + w - 45;
int btnY = y0 + 4;
int btnW = 40;
int btnH = 12;
if (inRect(mouseX, mouseY, btnX, btnY, btnW, btnH)) {
if (this.client != null) {
this.client.setScreen(new com.example.shinobicore.client.HudSettingsScreen(this));
}
return true;
}

if (tab == 4) {
'@

    if ($c.Contains("S3 HUD SETTINGS BUTTON CLICK")) {
        Write-Host "[SKIP] ProgressionScreen.java already patched (click)" -ForegroundColor Yellow
    } elseif ($c.Contains($oldClick)) {
        $c = $c.Replace($oldClick, $newClick)
        Write-Host "[OK] Patched ProgressionScreen.java (click)" -ForegroundColor Green
    } else {
        Write-Host "[WARN] Could not find click pattern in ProgressionScreen.java" -ForegroundColor Red
    }
    
    [System.IO.File]::WriteAllText($progFile, $c, $utf8)
}

# ---------------------------------------------------------
# 2. Patch ChakraHudRenderer.java (Применяем масштаб и альфу)
# ---------------------------------------------------------
$hudFile = "$src\client\ChakraHudRenderer.java"
if (Test-Path $hudFile) {
    $c = [System.IO.File]::ReadAllText($hudFile, $utf8).Replace("`r`n", "`n")
    
    # Патчим начало render()
    $oldRenderStart = 'public static void render(DrawContext context, float tickDelta) {
MinecraftClient client = MinecraftClient.getInstance();
if (client.player == null) return;
int sw = client.getWindow().getScaledWidth();
int sh = client.getWindow().getScaledHeight();'

    $newRenderStart = @'
public static void render(DrawContext context, float tickDelta) {
MinecraftClient client = MinecraftClient.getInstance();
if (client.player == null) return;

// === S3 HUD CONFIG INTEGRATION ===
com.example.shinobicore.config.HudConfig hudCfg = com.example.shinobicore.config.HudConfig.getInstance();
float hudScale = hudCfg.scale;
// int hudAlpha = hudCfg.getAlpha(); // Apply to colors later if needed

context.getMatrices().push();
context.getMatrices().scale(hudScale, hudScale, 1.0f);

int sw = (int)(client.getWindow().getScaledWidth() / hudScale);
int sh = (int)(client.getWindow().getScaledHeight() / hudScale);
'@

    if ($c.Contains("S3 HUD CONFIG INTEGRATION")) {
        Write-Host "[SKIP] ChakraHudRenderer.java already patched (start)" -ForegroundColor Yellow
    } elseif ($c.Contains($oldRenderStart)) {
        $c = $c.Replace($oldRenderStart, $newRenderStart)
        Write-Host "[OK] Patched ChakraHudRenderer.java (start)" -ForegroundColor Green
    } else {
        Write-Host "[WARN] Could not find render start pattern in ChakraHudRenderer.java" -ForegroundColor Red
    }

    # Патчим конец render() (закрываем матрицу)
    $oldRenderEnd = 'String.format("Charge: %.0f%%", charge * 100), barX + barWidth / 2, barY - 10, 0xFFFFFF);
}
}'
    $newRenderEnd = @'
String.format("Charge: %.0f%%", charge * 100), barX + barWidth / 2, barY - 10, 0xFFFFFF);
}

// === S3 HUD CONFIG POP ===
context.getMatrices().pop();
}
'@
    
    if ($c.Contains("S3 HUD CONFIG POP")) {
        Write-Host "[SKIP] ChakraHudRenderer.java already patched (end)" -ForegroundColor Yellow
    } elseif ($c.Contains($oldRenderEnd)) {
        $c = $c.Replace($oldRenderEnd, $newRenderEnd)
        Write-Host "[OK] Patched ChakraHudRenderer.java (end)" -ForegroundColor Green
    } else {
        Write-Host "[WARN] Could not find render end pattern in ChakraHudRenderer.java." -ForegroundColor Red
    }

    [System.IO.File]::WriteAllText($hudFile, $c, $utf8)
}

Write-Host ""
Write-Host "==================================================" -ForegroundColor Green
Write-Host "  Integration Complete!" -ForegroundColor Green
Write-Host "==================================================" -ForegroundColor Green