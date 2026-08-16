# ============================================================
#  SPRINT 1 / S1-04..S1-07 CONTINUATION (steps 7-15)
#  Fixes path error from previous run.
#  PS 5.1 compatible. ASCII only. UTF8 no BOM.
# ============================================================
$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$root = "E:\Games\mod"
$java = Join-Path $root "src\main\java\com\example\shinobicore"
$res  = Join-Path $root "src\main\resources\data\shinobicore"
$ok = 0; $skip = 0; $err = 0

function Patch-File($p, $old, $new) {
    if (-not (Test-Path $p)) { Write-Host "[MISS] $p" -ForegroundColor Red; $script:err++; return }
    $c = [System.IO.File]::ReadAllText($p, $utf8)
    $cNorm = $c.Replace("`r`n", "`n")
    $oldNorm = $old.Replace("`r`n", "`n")
    $newNorm = $new.Replace("`r`n", "`n")
    if ($cNorm.Contains($newNorm)) { Write-Host "[SKIP] already: $([System.IO.Path]::GetFileName($p))" -ForegroundColor Yellow; $script:skip++; return }
    if (-not $cNorm.Contains($oldNorm)) { Write-Host "[FAIL] pattern: $([System.IO.Path]::GetFileName($p))" -ForegroundColor Red; $script:err++; return }
    $c = $c.Replace($oldNorm, $newNorm)
    [System.IO.File]::WriteAllText($p, $c, $utf8)
    Write-Host "[OK] patched: $([System.IO.Path]::GetFileName($p))" -ForegroundColor Green
    $script:ok++
}

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  S1-04/05/06/07 CONTINUATION: STEPS 7-15" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

# ================================================================
# 7. ModPackets.java (RELEASE_CAST_ID + handler)
# ================================================================
Write-Host "[7/15] ModPackets.java (RELEASE_CAST)..." -ForegroundColor White
$mpPath = Join-Path $java "network\ModPackets.java"
if (-not (Test-Path $mpPath)) {
    Write-Host "[MISS] $mpPath" -ForegroundColor Red; $err++
} else {
    $mp = [System.IO.File]::ReadAllText($mpPath, $utf8)
    $mpNorm = $mp.Replace("`r`n", "`n")
    if ($mpNorm.Contains("RELEASE_CAST_ID")) {
        Write-Host "[SKIP] RELEASE_CAST already present" -ForegroundColor Yellow; $skip++
    } else {
        # 7a. Add RELEASE_CAST_ID constant after PREDICTION_CORRECTION_ID
        $mp = $mp.Replace(
            'public static final Identifier PREDICTION_CORRECTION_ID = new Identifier("shinobicore", "prediction_correction");',
            'public static final Identifier PREDICTION_CORRECTION_ID = new Identifier("shinobicore", "prediction_correction");
    public static final Identifier RELEASE_CAST_ID = new Identifier("shinobicore", "release_cast");')
        # 7b. Insert handler before the closing } of register()
        $lastBrace = $mp.LastIndexOf("}")
        $secondLastBrace = $mp.LastIndexOf("}", $lastBrace - 1)
        $handler = '

        // === S1-05: RELEASE CAST (charge release) ===
        ServerPlayNetworking.registerGlobalReceiver(RELEASE_CAST_ID, (server, player, handler, buf, responseSender) -> {
            server.execute(() -> {
                com.example.shinobicore.combat.CastingServerState.releaseCast(player);
            });
        });
    '
        $mp = $mp.Substring(0, $secondLastBrace) + $handler + $mp.Substring($secondLastBrace)
        [System.IO.File]::WriteAllText($mpPath, $mp, $utf8)
        Write-Host "[OK] RELEASE_CAST added to ModPackets.java" -ForegroundColor Green; $ok++
    }
}

# ================================================================
# 8. ClientInputHandler.java (cast key release tracking)
# ================================================================
Write-Host "[8/15] ClientInputHandler.java..." -ForegroundColor White
$cihPath = Join-Path $java "client\ClientInputHandler.java"
Patch-File $cihPath `
    "private static boolean prevLmbDown = false;" `
    "private static boolean prevLmbDown = false;`n    private static boolean prevCastAHeld = false;`n    private static boolean prevCastBHeld = false;"

Patch-File $cihPath `
    "if (KeyBindings.CAST_B.wasPressed()) ClientNinjaState.castActiveJutsu(1);" `
    "if (KeyBindings.CAST_B.wasPressed()) ClientNinjaState.castActiveJutsu(1);`n        // S1-05: Track cast key release for chargeable jutsu`n        boolean castAHeld = KeyBindings.CAST_A.isPressed();`n        if (!castAHeld && prevCastAHeld && client.getNetworkHandler() != null) {`n            PacketByteBuf releaseBuf = new PacketByteBuf(Unpooled.buffer());`n            ClientPlayNetworking.send(ModPackets.RELEASE_CAST_ID, releaseBuf);`n        }`n        prevCastAHeld = castAHeld;`n        boolean castBHeld = KeyBindings.CAST_B.isPressed();`n        if (!castBHeld && prevCastBHeld && client.getNetworkHandler() != null) {`n            PacketByteBuf releaseBuf2 = new PacketByteBuf(Unpooled.buffer());`n            ClientPlayNetworking.send(ModPackets.RELEASE_CAST_ID, releaseBuf2);`n        }`n        prevCastBHeld = castBHeld;"

# ================================================================
# 9. tree.json: remove duplicate gen_basic_fear
# ================================================================
Write-Host "[9/15] tree.json (remove duplicate)..." -ForegroundColor White
$treePath = Join-Path $res "skill_tree\tree.json"
if (Test-Path $treePath) {
    $tc = [System.IO.File]::ReadAllText($treePath, $utf8)
    if ($tc.Contains('"gen_basic_fear"')) {
        $tc = [regex]::Replace($tc, '\{[^{}]*"id":\s*"gen_basic_fear"[^{}]*\},?\s*', '')
        $tc = $tc.Replace(',,', ',')
        $tc = [regex]::Replace($tc, ',\s*\]', ']')
        [System.IO.File]::WriteAllText($treePath, $tc, $utf8)
        Write-Host "[OK] Removed duplicate gen_basic_fear" -ForegroundColor Green; $ok++
    } else {
        Write-Host "[SKIP] gen_basic_fear already removed" -ForegroundColor Yellow; $skip++
    }
} else { Write-Host "[MISS] tree.json" -ForegroundColor Red; $err++ }

# ================================================================
# 10. SkillTreeRegistry: validate only jutsu nodes in forbidden
#     + tree.json: add requires_teacher
# ================================================================
Write-Host "[10/15] Forbidden validation + requires_teacher..." -ForegroundColor White
$stPath = Join-Path $java "tree\SkillTreeRegistry.java"
Patch-File $stPath `
    'if (node.branch().equals("forbidden")) {' `
    'if (node.branch().equals("forbidden") && "jutsu".equals(node.type())) {'

if (Test-Path $treePath) {
    $tc2 = [System.IO.File]::ReadAllText($treePath, $utf8)
    $changed2 = $false
    # forb_gates_node
    $idx1 = $tc2.IndexOf('"forb_gates_node"')
    if ($idx1 -ge 0) {
        $near1 = $tc2.Substring($idx1, [Math]::Min(300, $tc2.Length - $idx1))
        if (-not $near1.Contains('requires_teacher')) {
            $tc2 = [regex]::Replace($tc2, '("id":\s*"forb_gates_node",)', "`$1`n            `"requires_teacher`":  true,")
            $changed2 = $true
        }
    }
    # forb_edo_n
    $idx2 = $tc2.IndexOf('"forb_edo_n"')
    if ($idx2 -ge 0) {
        $near2 = $tc2.Substring($idx2, [Math]::Min(300, $tc2.Length - $idx2))
        if (-not $near2.Contains('requires_teacher')) {
            $tc2 = [regex]::Replace($tc2, '("id":\s*"forb_edo_n",)', "`$1`n            `"requires_teacher`":  true,")
            $changed2 = $true
        }
    }
    if ($changed2) {
        [System.IO.File]::WriteAllText($treePath, $tc2, $utf8)
        Write-Host "[OK] requires_teacher added to forbidden jutsu nodes" -ForegroundColor Green; $ok++
    } else {
        Write-Host "[SKIP] requires_teacher already present" -ForegroundColor Yellow; $skip++
    }
}

# ================================================================
# 11. ClientNinjaState.java: teacherApproved set
# ================================================================
Write-Host "[11/15] ClientNinjaState.java..." -ForegroundColor White
$cnsPath = Join-Path $java "client\ClientNinjaState.java"
Patch-File $cnsPath `
    "public static final Set<String> unlockedNodes = new HashSet<>();" `
    "public static final Set<String> unlockedNodes = new HashSet<>();`n    public static final Set<String> teacherApproved = new HashSet<>();"

# ================================================================
# 12. ShinobiCore.java: sendTreeSync with teacherApproved
# ================================================================
Write-Host "[12/15] ShinobiCore.java (sendTreeSync)..." -ForegroundColor White
$corePath = Join-Path $java "ShinobiCore.java"
Patch-File $corePath `
    "for (String nodeId : data.getUnlockedNodes()) buf.writeString(nodeId);" `
    "for (String nodeId : data.getUnlockedNodes()) buf.writeString(nodeId);`n        // S1-07: Teacher approved nodes`n        buf.writeInt(data.getTeacherApprovedNodes().size());`n        for (String nodeId : data.getTeacherApprovedNodes()) buf.writeString(nodeId);"

# ================================================================
# 13. ShinobiCore.java: handleUnlockNode teacher+scroll check
# ================================================================
Write-Host "[13/15] ShinobiCore.java (handleUnlockNode)..." -ForegroundColor White
Patch-File $corePath `
    "return;`n        }`n        if (data.isNodeUnlocked(nodeId)) {" `
    "return;`n        }`n        // S1-07: Check teacher requirement`n        if (node.requiresTeacher() && !data.getTeacherApprovedNodes().contains(nodeId)) {`n            player.sendMessage(Text.literal(""\u00a7cThis technique requires a teacher!""), false);`n            return;`n        }`n        // S1-07: Check scroll requirement`n        if (node.requiresScroll() != null && !node.requiresScroll().isEmpty()) {`n            boolean hasScroll = false;`n            for (int i = 0; i < player.getInventory().size(); i++) {`n                net.minecraft.item.ItemStack stack = player.getInventory().getStack(i);`n                if (stack.getItem() instanceof com.example.shinobicore.item.ScrollItem) {`n                    String scrollId = com.example.shinobicore.item.ScrollItem.getJutsuId(stack);`n                    if (node.requiresScroll().equals(scrollId)) { hasScroll = true; break; }`n                }`n            }`n            if (!hasScroll) {`n                player.sendMessage(Text.literal(""\u00a7cRequires scroll: "" + node.requiresScroll()), false);`n                return;`n            }`n        }`n        if (data.isNodeUnlocked(nodeId)) {"

# ================================================================
# 14. SkillTreeScreen.java: canUnlock + tooltip
# ================================================================
Write-Host "[14/15] SkillTreeScreen.java..." -ForegroundColor White
$stsPath = Join-Path $java "client\SkillTreeScreen.java"
Patch-File $stsPath `
    "if (ClientNinjaState.skillPoints < node.spCost()) return false;" `
    "if (ClientNinjaState.skillPoints < node.spCost()) return false;`n        if (node.requiresTeacher() && !ClientNinjaState.teacherApproved.contains(node.id())) return false;"

Patch-File $stsPath `
    'else lines.add("[Locked]");' `
    'else {
            lines.add("[Locked]");
            if (node.requiresTeacher() && !ClientNinjaState.teacherApproved.contains(node.id())) {
                lines.add("  Requires a teacher");
            }
            if (node.requiresScroll() != null && !node.requiresScroll().isEmpty()) {
                lines.add("  Requires scroll: " + node.requiresScroll());
            }
        }'

# ================================================================
# 15. NinjaCommand + ShinobiCoreClient
# ================================================================
Write-Host "[15/15] NinjaCommand + ShinobiCoreClient..." -ForegroundColor White
$cmdPath = Join-Path $java "command\NinjaCommand.java"

# 15a. Add imports
Patch-File $cmdPath `
    "import com.example.shinobicore.stat.StatType;" `
    "import com.example.shinobicore.stat.StatType;`nimport com.example.shinobicore.tree.SkillTreeNode;`nimport com.example.shinobicore.tree.SkillTreeRegistry;"

# 15b. Add .then(teachBranch()) before .then(clanBranch())
Patch-File $cmdPath `
    ".then(clanBranch())" `
    ".then(teachBranch())`n                .then(clanBranch())"

# 15c. Add teachBranch() + teach() + suggestTreeNodes() before clanBranch()
Patch-File $cmdPath `
    "private static ArgumentBuilder<ServerCommandSource, ?> clanBranch() {" `
    "private static ArgumentBuilder<ServerCommandSource, ?> teachBranch() {`n        return CommandManager.literal(""teach"")`n            .then(CommandManager.argument(""node"", StringArgumentType.word())`n                .suggests(NinjaCommand::suggestTreeNodes)`n                .executes(ctx -> teach(ctx.getSource(), StringArgumentType.getString(ctx, ""node""))));`n    }`n`n    private static int teach(ServerCommandSource source, String nodeId) {`n        ServerPlayerEntity p = source.getPlayer();`n        NinjaPlayerData d = data(p);`n        SkillTreeNode node = SkillTreeRegistry.get(nodeId);`n        if (node == null) {`n            source.sendFeedback(() -> Text.literal(""\u00a7cUnknown node: "" + nodeId), false);`n            return 0;`n        }`n        d.approveTeacherNode(nodeId);`n        ShinobiCore.sendTreeSync(p);`n        source.sendFeedback(() -> Text.literal(""\u00a7aTeacher approved for: "" + nodeId), false);`n        return 1;`n    }`n`n    private static CompletableFuture<Suggestions> suggestTreeNodes(CommandContext<ServerCommandSource> ctx, SuggestionsBuilder b) {`n        for (SkillTreeNode node : SkillTreeRegistry.getAll()) b.suggest(node.id());`n        return b.buildFuture();`n    }`n`n    private static ArgumentBuilder<ServerCommandSource, ?> clanBranch() {"

# 15d. ShinobiCoreClient: TREE_SYNC with teacherApproved
$sccPath = Join-Path $java "client\ShinobiCoreClient.java"
Patch-File $sccPath `
    "for (int i = 0; i < count; i++) nodes.add(buf.readString());" `
    "for (int i = 0; i < count; i++) nodes.add(buf.readString());`n            // S1-07: Read teacher approved nodes`n            int teacherCount = buf.readInt();`n            Set<String> teacherNodes = new HashSet<>();`n            for (int i = 0; i < teacherCount; i++) teacherNodes.add(buf.readString());"

Patch-File $sccPath `
    "ClientNinjaState.unlockedNodes.addAll(nodes);" `
    "ClientNinjaState.unlockedNodes.addAll(nodes);`n                ClientNinjaState.teacherApproved.clear();`n                ClientNinjaState.teacherApproved.addAll(teacherNodes);"

# ================================================================
# SUMMARY
# ================================================================
Write-Host ""
Write-Host "================================================================" -ForegroundColor Green
Write-Host "  CONTINUATION COMPLETE: OK=$ok SKIP=$skip ERR=$err" -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Green
Write-Host ""
if ($err -gt 0) {
    Write-Host "  [ABORT] $err error(s) detected!" -ForegroundColor Red
    exit 1
}
Write-Host "  Next: .\gradlew.bat build" -ForegroundColor Yellow
exit 0