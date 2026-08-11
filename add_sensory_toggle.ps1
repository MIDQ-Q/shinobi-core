$utf8 = New-Object System.Text.UTF8Encoding($false)
$src = "E:\Games\mod\src\main\java\com\example\shinobicore"

Write-Host "=== ADD SENSORY TOGGLE ===" -ForegroundColor Cyan

# === [1] NinjaPlayerData: sensoryEnabled ===
$file = "$src\stat\NinjaPlayerData.java"
$c = [System.IO.File]::ReadAllText($file, $utf8)

# 1a. Поле
if (-not $c.Contains("sensoryEnabled")) {
    $marker = "private boolean chakraMode = false;"
    $c = $c.Replace($marker, "private boolean chakraMode = false;
    private boolean sensoryEnabled = true;")
    
    # 1b. Геттер/сеттер
    $marker = "public boolean isChakraMode() { return chakraMode; }"
    $c = $c.Replace($marker, "public boolean isChakraMode() { return chakraMode; }
    public boolean isSensoryEnabled() { return sensoryEnabled; }
    public void setSensoryEnabled(boolean v) { this.sensoryEnabled = v; statsDirty = true; }")
    
    # 1c. writeNbt
    $marker = 'nbt.putBoolean("ChakraMode", chakraMode);'
    $c = $c.Replace($marker, 'nbt.putBoolean("ChakraMode", chakraMode);
        nbt.putBoolean("SensoryEnabled", sensoryEnabled);')
    
    # 1d. readNbt
    $marker = 'chakraMode = nbt.getBoolean("ChakraMode");'
    $c = $c.Replace($marker, 'chakraMode = nbt.getBoolean("ChakraMode");
        sensoryEnabled = nbt.getBoolean("SensoryEnabled");')
    
    [System.IO.File]::WriteAllText($file, $c, $utf8)
    Write-Host "[1] NinjaPlayerData: sensoryEnabled added" -ForegroundColor Green
}

# === [2] NinjaTickHandler: проверка sensoryEnabled ===
$file = "$src\event\NinjaTickHandler.java"
$c = [System.IO.File]::ReadAllText($file, $utf8)

if (-not $c.Contains("isSensoryEnabled")) {
    $marker = 'if (pbs.sensory) {'
    $c = $c.Replace($marker, 'if (pbs.sensory && data.isSensoryEnabled()) {')
    [System.IO.File]::WriteAllText($file, $c, $utf8)
    Write-Host "[2] NinjaTickHandler: sensoryEnabled check" -ForegroundColor Green
}

# === [3] KeyBindings: клавиша Y ===
$file = "$src\client\KeyBindings.java"
$c = [System.IO.File]::ReadAllText($file, $utf8)

if (-not $c.Contains("TOGGLE_SENSORY")) {
    $marker = "public static KeyBinding SWITCH_STYLE;"
    $c = $c.Replace($marker, "public static KeyBinding SWITCH_STYLE;
    public static KeyBinding TOGGLE_SENSORY;")
    
    $marker = '"key.shinobicore.switch_style", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_B, COMBAT_CATEGORY));'
    $c = $c.Replace($marker, '"key.shinobicore.switch_style", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_B, COMBAT_CATEGORY));

        TOGGLE_SENSORY = KeyBindingHelper.registerKeyBinding(new KeyBinding(
            "key.shinobicore.toggle_sensory", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_Y, CATEGORY));')
    
    [System.IO.File]::WriteAllText($file, $c, $utf8)
    Write-Host "[3] KeyBindings: TOGGLE_SENSORY (Y)" -ForegroundColor Green
}

# === [4] ClientInputHandler: обработка Y ===
$file = "$src\client\ClientInputHandler.java"
$c = [System.IO.File]::ReadAllText($file, $utf8)

if (-not $c.Contains("TOGGLE_SENSORY")) {
    $marker = '// === ПОЛЗАНИЕ (N) ===
        if (KeyBindings.CRAWL.wasPressed()) {
            ShinobiCore.LOGGER.info("[INPUT] CRAWL (N) pressed");
        }'
    $insert = @'
// === ПОЛЗАНИЕ (N) ===
        if (KeyBindings.CRAWL.wasPressed()) {
            ShinobiCore.LOGGER.info("[INPUT] CRAWL (N) pressed");
        }
        
        // === ПЕРЕКЛЮЧЕНИЕ SENSORY (Y) ===
        if (KeyBindings.TOGGLE_SENSORY.wasPressed()) {
            boolean newState = !ClientNinjaState.sensoryEnabled;
            ClientNinjaState.sensoryEnabled = newState;
            ShinobiCore.LOGGER.info("[SENSORY] Toggled: {}", newState);
            if (client.getNetworkHandler() != null) {
                PacketByteBuf buf = new PacketByteBuf(Unpooled.buffer());
                buf.writeBoolean(newState);
                ClientPlayNetworking.send(ModPackets.SENSORY_TOGGLE_ID, buf);
                ShinobiCore.LOGGER.info("[SENSORY] Packet sent: enabled={}", newState);
            }
            client.player.sendMessage(Text.literal(newState ? "§aSensory: ON" : "§7Sensory: OFF"), false);
        }
'@
    $c = $c.Replace($marker, $insert)
    [System.IO.File]::WriteAllText($file, $c, $utf8)
    Write-Host "[4] ClientInputHandler: Y handler" -ForegroundColor Green
}

# === [5] ClientNinjaState: sensoryEnabled ===
$file = "$src\client\ClientNinjaState.java"
$c = [System.IO.File]::ReadAllText($file, $utf8)

if (-not $c.Contains("sensoryEnabled")) {
    $c = $c.Replace("public static boolean dangerSense = false;",
        "public static boolean dangerSense = false;
    public static boolean sensoryEnabled = true;")
    [System.IO.File]::WriteAllText($file, $c, $utf8)
    Write-Host "[5] ClientNinjaState: sensoryEnabled" -ForegroundColor Green
}

# === [6] ModPackets: SENSORY_TOGGLE_ID ===
$file = "$src\network\ModPackets.java"
$c = [System.IO.File]::ReadAllText($file, $utf8)

if (-not $c.Contains("SENSORY_TOGGLE_ID")) {
    $marker = 'public static final Identifier DANGER_SYNC_ID = new Identifier("shinobicore", "danger_sync");'
    $c = $c.Replace($marker, 'public static final Identifier DANGER_SYNC_ID = new Identifier("shinobicore", "danger_sync");
    public static final Identifier SENSORY_TOGGLE_ID = new Identifier("shinobicore", "sensory_toggle");')
    
    $marker = 'ServerPlayNetworking.registerGlobalReceiver(DODGE_ID,'
    $c = $c.Replace($marker, @'
ServerPlayNetworking.registerGlobalReceiver(SENSORY_TOGGLE_ID, (server, player, handler, buf, responseSender) -> {
            boolean enabled = buf.readBoolean();
            server.execute(() -> {
                NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
                data.setSensoryEnabled(enabled);
                ShinobiCore.sendStatsSync(player);
            });
        });
        
        ServerPlayNetworking.registerGlobalReceiver(DODGE_ID,
'@)
    [System.IO.File]::WriteAllText($file, $c, $utf8)
    Write-Host "[6] ModPackets: SENSORY_TOGGLE_ID" -ForegroundColor Green
}

# === [7] ShinobiCoreClient: синхронизация sensoryEnabled ===
$file = "$src\client\ShinobiCoreClient.java"
$c = [System.IO.File]::ReadAllText($file, $utf8)

if (-not $c.Contains("sensoryEnabled")) {
    $marker = 'ClientNinjaState.natureUnlocked.clear(); ClientNinjaState.natureUnlocked.putAll(nu);'
    $c = $c.Replace($marker, 'ClientNinjaState.natureUnlocked.clear(); ClientNinjaState.natureUnlocked.putAll(nu);
                ClientNinjaState.sensoryEnabled = buf.readBoolean();')
    [System.IO.File]::WriteAllText($file, $c, $utf8)
    Write-Host "[7] ShinobiCoreClient: sensoryEnabled sync" -ForegroundColor Green
}

# === [8] ShinobiCore: sendStatsSync отправляет sensoryEnabled ===
$file = "$src\ShinobiCore.java"
$c = [System.IO.File]::ReadAllText($file, $utf8)

if (-not $c.Contains("sensoryEnabled")) {
    $marker = 'for (ElementType e : ElementType.values()) buf.writeBoolean(data.isNatureUnlocked(e));'
    $c = $c.Replace($marker, 'for (ElementType e : ElementType.values()) buf.writeBoolean(data.isNatureUnlocked(e));
        buf.writeBoolean(data.isSensoryEnabled());')
    [System.IO.File]::WriteAllText($file, $c, $utf8)
    Write-Host "[8] ShinobiCore: sensoryEnabled in sendStatsSync" -ForegroundColor Green
}

Write-Host "`n=== SENSORY TOGGLE COMPLETE ===" -ForegroundColor Cyan
Write-Host "Run: .\gradlew.bat build" -ForegroundColor Yellow