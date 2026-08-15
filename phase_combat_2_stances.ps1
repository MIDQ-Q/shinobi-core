# ============================================================
#  PHASE 2: РАСШИРЕНИЕ СТОЕК (Seigan parry, Iai dash, Aggressive bleed)
# ============================================================
$ErrorActionPreference = "Continue"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$java = "E:\Games\mod\src\main\java\com\example\shinobicore"
$ok = 0; $skip = 0; $err = 0

function Write-File($p, $c) {
    $dir = [System.IO.Path]::GetDirectoryName($p)
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [System.IO.File]::WriteAllText($p, $c, $utf8)
    Write-Host "[OK] $($p.Replace('E:\Games\mod\src\main\', ''))" -ForegroundColor Green
    $script:ok++
}

function Patch-File($p, $old, $new) {
    if (-not (Test-Path $p)) { Write-Host "[MISS] $p" -ForegroundColor Red; $script:err++; return }
    $c = [System.IO.File]::ReadAllText($p, $utf8)
    if ($c.Contains($new)) { Write-Host "[SKIP] already: $([System.IO.Path]::GetFileName($p))" -ForegroundColor Yellow; $script:skip++; return }
    if (-not $c.Contains($old)) { Write-Host "[FAIL] pattern: $([System.IO.Path]::GetFileName($p))" -ForegroundColor Red; $script:err++; return }
    $c = $c.Replace($old, $new)
    [System.IO.File]::WriteAllText($p, $c, $utf8)
    Write-Host "[OK] patched: $([System.IO.Path]::GetFileName($p))" -ForegroundColor Green
    $script:ok++
}

Write-Host "`n=== PHASE 2: STANCE EXPANSION ===`n" -ForegroundColor Cyan

# ================================================================
# 1. KatanaDeflectMixin.java — генерация чакры при парировании
# ================================================================
Write-Host "[1/5] Patching KatanaDeflectMixin.java..." -ForegroundColor White

Patch-File "$java\mixin\KatanaDeflectMixin.java" `
    "data.setLastDeflectReflectMs(now);
        player.playSound(SoundEvents.ITEM_SHIELD_BLOCK, 1.0f, 1.2f);" `
    "data.setLastDeflectReflectMs(now);
        player.playSound(SoundEvents.ITEM_SHIELD_BLOCK, 1.0f, 1.2f);

        // === PHASE2: Chakra generation on successful parry ===
        float chakraGain = stance.getParryChakraGain();
        if (chakraGain > 0 && data.getCurrentChakra() < com.example.shinobicore.stat.NinjaFormula.maxChakra(data)) {
            data.setCurrentChakra(Math.min(
                data.getCurrentChakra() + chakraGain * 5.0f,
                com.example.shinobicore.stat.NinjaFormula.maxChakra(data)));
            com.example.shinobicore.ShinobiCore.sendChakraSync(player);
        }
        // Strain cost for parrying
        data.setFatigue(data.getFatigue() + 2.0f * stance.getFatigueMult());"

# ================================================================
# 2. NinjaTickHandler.java — эффекты стоек каждый тик
# ================================================================
Write-Host "[2/5] Patching NinjaTickHandler.java..." -ForegroundColor White

Patch-File "$java\event\NinjaTickHandler.java" `
    "boolean seiganShield = data.isKatanaDeflectHeld()
                && KenjutsuStance.fromId(data.getKatanaStanceId()) == KenjutsuStance.SEIGAN;
        if (seiganShield) {
            player.addStatusEffect(new StatusEffectInstance(StatusEffects.SLOWNESS, 25, 2, false, false, false));
        }" `
    "boolean seiganShield = data.isKatanaDeflectHeld()
                && KenjutsuStance.fromId(data.getKatanaStanceId()) == KenjutsuStance.SEIGAN;
        if (seiganShield) {
            player.addStatusEffect(new StatusEffectInstance(StatusEffects.SLOWNESS, 25, 2, false, false, false));
            // === PHASE2: Seigan passive chakra regen while shielding ===
            if (data.getCurrentChakra() < NinjaFormula.maxChakra(data)) {
                data.setCurrentChakra(Math.min(
                    data.getCurrentChakra() + 0.3f,
                    NinjaFormula.maxChakra(data)));
            }
        }

        // === PHASE2: Aggressive stance passive - slight speed boost ===
        KenjutsuStance currentStance = KenjutsuStance.fromId(data.getKatanaStanceId());
        if (currentStance == KenjutsuStance.AGGRESSIVE
                && player.getMainHandStack().getItem() instanceof com.example.shinobicore.item.KatanaItem) {
            var aggroAttr = player.getAttributeInstance(EntityAttributes.GENERIC_ATTACK_SPEED);
            if (aggroAttr != null) {
                // Vanilla handles attack speed; we just add fatigue pressure
                if (tickCounter % 5 == 0) {
                    data.setFatigue(data.getFatigue() + 0.1f * currentStance.getFatigueMult());
                }
            }
        }"

# ================================================================
# 3. ModPackets.java — IAI DASH (новый пакет)
# ================================================================
Write-Host "[3/5] Adding IAI_DASH packet to ModPackets.java..." -ForegroundColor White

Patch-File "$java\network\ModPackets.java" `
    "public static final Identifier HIT_STOP_ID = new Identifier(""shinobicore"", ""hit_stop"");" `
    "public static final Identifier HIT_STOP_ID = new Identifier(""shinobicore"", ""hit_stop"");
    public static final Identifier IAI_DASH_ID = new Identifier(""shinobicore"", ""iai_dash"");"

# Добавить обработчик IAI_DASH после KATANA_DEFLECT_ID
Patch-File "$java\network\ModPackets.java" `
    "ServerPlayNetworking.registerGlobalReceiver(DODGE_ID, (server, player, handler, buf, responseSender) -> {" `
    "// === PHASE2: IAI DASH ===
        ServerPlayNetworking.registerGlobalReceiver(IAI_DASH_ID, (server, player, handler, buf, responseSender) -> {
            server.execute(() -> {
                NinjaPlayerData data = ((NinjaDataHolder) player).shinobicore_getData();
                if (data.isExhausted()) return;
                KenjutsuStance stance = KenjutsuStance.fromId(data.getKatanaStanceId());
                if (stance != KenjutsuStance.IAI) return;
                long now = System.currentTimeMillis();
                if (now - data.getKatanaLastAttackMs() < 2000) return; // cooldown
                // Dash forward
                Vec3d look = player.getRotationVector();
                player.addVelocity(look.x * 1.8, 0.1, look.z * 1.8);
                player.velocityModified = true;
                // Damage in narrow cone
                int tai = data.getStatLevel(StatType.TAIJUTSU);
                float damage = KenjutsuFormulas.baseDamage(tai) * 3.0f;
                if (data.isChakraMode()) damage *= stance.getChakraDamageMult();
                java.util.List<LivingEntity> targets = KenjutsuFormulas.findTargetsInCone(
                        (ServerWorld) player.getWorld(), player, look, 5.0, 40);
                for (LivingEntity t : targets) {
                    t.damage(player.getDamageSources().playerAttack(player), damage);
                    Vec3d kb = look.normalize().multiply(1.5);
                    t.addVelocity(kb.x, 0.3, kb.z);
                    t.velocityModified = true;
                }
                data.setFatigue(data.getFatigue() + 5.0f);
                if (data.isChakraMode()) data.setCurrentChakra(Math.max(0, data.getCurrentChakra() - 5.0f));
                data.setKatanaLastAttackMs(now);
                ShinobiCore.sendChakraSync(player);
            });
        });

        ServerPlayNetworking.registerGlobalReceiver(DODGE_ID, (server, player, handler, buf, responseSender) -> {"

# ================================================================
# 4. KeyBindings.java — клавиша для IAI DASH
# ================================================================
Write-Host "[4/5] Patching KeyBindings.java..." -ForegroundColor White

Patch-File "$java\client\KeyBindings.java" `
    "public static KeyBinding KATANA_DEFLECT;" `
    "public static KeyBinding KATANA_DEFLECT;
    public static KeyBinding IAI_DASH;"

Patch-File "$java\client\KeyBindings.java" `
    "KATANA_DEFLECT = KeyBindingHelper.registerKeyBinding(new KeyBinding(
                ""key.shinobicore.katana_deflect"", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_X, COMBAT_CATEGORY));" `
    "KATANA_DEFLECT = KeyBindingHelper.registerKeyBinding(new KeyBinding(
                ""key.shinobicore.katana_deflect"", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_X, COMBAT_CATEGORY));
        IAI_DASH = KeyBindingHelper.registerKeyBinding(new KeyBinding(
                ""key.shinobicore.iai_dash"", InputUtil.Type.KEYSYM, GLFW.GLFW_KEY_R, COMBAT_CATEGORY));"

# ================================================================
# 5. ClientInputHandler.java — обработка IAI DASH
# ================================================================
Write-Host "[5/5] Patching ClientInputHandler.java..." -ForegroundColor White

Patch-File "$java\client\ClientInputHandler.java" `
    "if (KeyBindings.SWITCH_STYLE.wasPressed()) {" `
    "// === PHASE2: IAI DASH ===
        if (KeyBindings.IAI_DASH.wasPressed() && hasKatana
                && ClientNinjaState.kenjutsuStance.equals(""iai"")) {
            PacketByteBuf iaiBuf = new PacketByteBuf(Unpooled.buffer());
            ClientPlayNetworking.send(ModPackets.IAI_DASH_ID, iaiBuf);
        }

        if (KeyBindings.SWITCH_STYLE.wasPressed()) {"

# ================================================================
Write-Host "`n=== PHASE 2 COMPLETE: OK=$ok SKIP=$skip ERR=$err ===`n" -ForegroundColor Green
Write-Host "Next: .\gradlew.bat build" -ForegroundColor Yellow