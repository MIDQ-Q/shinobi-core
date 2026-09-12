#Requires -Version 5.1
<#
================================================================================
  ShinobiCore — tools\check_jutsu.ps1
  Офлайн-валидатор техник и целостности дерева навыков.
  НЕ требует Minecraft, Gradle или запуска игры.

      powershell -ExecutionPolicy Bypass -File tools\check_jutsu.ps1
      powershell -ExecutionPolicy Bypass -File tools\check_jutsu.ps1 -Capabilities
      powershell -ExecutionPolicy Bypass -File tools\check_jutsu.ps1 -ReportPassives

  Код возврата: 0 — ошибок нет, 1 — есть ошибки.

  Все whitelist'ы сняты с кода движка:
      ElementType, FormType, ActivationType, ResourceType, StatType  (enums)
      EffectExecutor.applyDamage/applyControl/applyBuff/applyDebuff  (подтипы)
      WorldEffectExecutor.applyWorld                                 (world)
      ProjectileSystem / StickSystem / OrbitingSystem / HitProperties (свойства)
  Отдельно отмечены ЛОВУШКИ — значения, объявленные в enum, но не
  обрабатываемые в switch, то есть молча ничего не делающие.
================================================================================
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)][string] $ProjectRoot = (Split-Path -Parent $PSScriptRoot),
    [switch] $Capabilities,
    [switch] $ReportPassives
)
Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

# ---- безопасный доступ к свойствам JSON (Set-StrictMode 2.0 бросает
#      исключение при обращении к отсутствующему свойству PSCustomObject) -----
function Get-Prop {
    param($Obj, [Parameter(Mandatory = $true)][string]$Name)
    if ($null -eq $Obj) { return $null }
    $ps = $Obj.PSObject
    if ($null -eq $ps) { return $null }
    $p = $ps.Properties[$Name]
    if ($null -eq $p) { return $null }
    return $p.Value
}
function Get-Props {
    param($Obj)
    if ($null -eq $Obj) { return @() }
    $ps = $Obj.PSObject
    if ($null -eq $ps) { return @() }
    return @($ps.Properties)
}
function Test-HasProp {
    param($Obj, [Parameter(Mandatory = $true)][string]$Name)
    if ($null -eq $Obj) { return $false }
    $ps = $Obj.PSObject
    if ($null -eq $ps) { return $false }
    return ($null -ne $ps.Properties[$Name])
}

# ---- whitelist'ы, снятые с кода движка ---------------------------------------
$ELEMENTS     = @('fire','water','wind','earth','lightning','yin','yang','none')
$FORMS        = @('point','projectile','beam','zone','dash','summon','construct','handheld')
$ACTIVATIONS  = @('instant','conditional','handseals','charge','hold','counter','on_death','passive')
$ACT_DEAD     = @('combo')                       # объявлен, в switch JutsuCaster отсутствует
$RANKS        = @('D','C','B','A','S')
$COST_KEYS    = @('chakra','fatigue','hunger','health','item','eye')
$STAT_KEYS    = @('control','ninjutsu','taijutsu','genjutsu','medical','space_time','perception')

$EFFECTS = @{
    'damage'  = @('instant','true','percent','dot','cellular')
    'control' = @('push','launch','pull','stun','root','silence','blind','fear','confusion','sleep','paralysis','slow')
    'buff'    = @('heal','regen','shield','speed','strength','invisibility','haste','chakra_regen','purify')
    'debuff'  = @('burn','slow','weakness','poison','bleed','vulnerability','curse','exhaustion','chakra_drain')
    'world'   = @('ignite','freeze','place_block','remove_block','transform_block','create_entity')
}
# объявлены в EffectSubType, но НЕ обрабатываются -> молча ничего не делают
$EFFECT_TRAPS = @('buff:resistance')

$PROPS = @('aura','bouncing','chain_explosion','chaining','chakra_drain_on_hit','channeled',
           'execute_bonus','gravity_affected','homing','invisible_projectile','lifesteal','multi_use',
           'no_gravity','orbiting','permanent','piercing','silent','splitting','stick_on_hit',
           'throwable','toggle','volley','multi_target','unblockable','unreflectable',
           'delayed_explosion','explode_on_hit','implosion','knockback','radius','damage')

$FORM_PARAMS = @{
    'point'      = @('range','targetMode')
    'projectile' = @('speed','gravity','lifetime','size','count','spread')
    'beam'       = @('width','maxRange','duration','tickRate')
    'zone'       = @('radius','duration','shape','tickRate')
    'dash'       = @('distance','speed','damageOnPath')
    'summon'     = @('entityType','count','lifetime','behavior','spawnPosition','jutsus')
    'construct'  = @('shape','blockType','width','height','depth','duration')
    'handheld'   = @('chargeTime','holdDuration','size','throwable','activation','voxelModel')
}
$ACT_PARAMS = @{
    'instant'=@(); 'conditional'=@(); 'passive'=@(); 'on_death'=@()
    'handseals'=@('sealCount','sealSpeed'); 'charge'=@('minCharge','maxCharge')
    'hold'=@('chakraPerTick'); 'counter'=@('windowMs','damageThreshold')
}
$TARGET_MODES = @('self','look_entity','raycast_point')

# ---- реализованные пассивки (TreePassives.apply переключается ПО ID УЗЛА) -----
$PASSIVES_IMPLEMENTED = @('fire_synergy','gen_iron_will','gen_leaf_focus','gen_resist',
    'kg_blaze','kg_crystal','kg_lava','kg_shadow','kg_storm','kg_wood',
    'sen_danger','sen_glow','tai_combo_plus')

function J([string]$p) { return Join-Path $ProjectRoot $p }

$errors   = New-Object System.Collections.ArrayList
$warnings = New-Object System.Collections.ArrayList

# =============================================================================
#  -Capabilities : словарь движка
# =============================================================================
if ($Capabilities) {
    Write-Host ''
    Write-Host '  СЛОВАРЬ ДВИЖКА ТЕХНИК (снято с кода)' -ForegroundColor Cyan
    Write-Host ('  ' + '-' * 74) -ForegroundColor DarkCyan
    Write-Host "  element           : $($ELEMENTS -join ', ')"
    Write-Host "  form.type         : $($FORMS -join ', ')"
    Write-Host "  activation.type   : $($ACTIVATIONS -join ', ')"
    Write-Host "  rank              : $($RANKS -join ', ')"
    Write-Host "  cost ключи        : $($COST_KEYS -join ', ')"
    Write-Host "  requirements.stats: $($STAT_KEYS -join ', ')"
    Write-Host "  point.targetMode  : $($TARGET_MODES -join ', ')"
    Write-Host ''
    foreach ($t in @('damage','control','buff','debuff','world')) {
        Write-Host ("  effect {0,-8}: {1}" -f $t, ($EFFECTS[$t] -join ', '))
    }
    Write-Host ''
    Write-Host "  ЛОВУШКА effect (объявлен, но no-op) : $($EFFECT_TRAPS -join ', ')" -ForegroundColor Yellow
    Write-Host "  ЛОВУШКА activation (объявлен, но no-op): $($ACT_DEAD -join ', ')" -ForegroundColor Yellow
    Write-Host ''
    Write-Host '  свойства:' -ForegroundColor Gray
    $i = 0
    foreach ($p in $PROPS) { $i++; Write-Host ("    {0,-24}" -f $p) -NoNewline; if ($i % 3 -eq 0) { Write-Host '' } }
    Write-Host ''
    Write-Host ''
    Write-Host '  параметры форм:' -ForegroundColor Gray
    foreach ($k in ($FORM_PARAMS.Keys | Sort-Object)) { Write-Host ("    {0,-10}: {1}" -f $k, ($FORM_PARAMS[$k] -join ', ')) }
    Write-Host ''
    Write-Host '  параметры активаций:' -ForegroundColor Gray
    foreach ($k in ($ACT_PARAMS.Keys | Sort-Object)) { Write-Host ("    {0,-12}: {1}" -f $k, ($ACT_PARAMS[$k] -join ', ')) }
    Write-Host ''
    exit 0
}

# =============================================================================
#  1. ВАЛИДАЦИЯ ТЕХНИК
# =============================================================================
$jdir = J 'src\main\resources\data\shinobicore\jutsu'
$files = @()
if (Test-Path -LiteralPath $jdir) { $files = @(Get-ChildItem -LiteralPath $jdir -Filter '*.json' -File) }
Write-Host ''
Write-Host "  Проверка техник: $($files.Count) файл(ов) в data\shinobicore\jutsu" -ForegroundColor Cyan

$ids = @{}
foreach ($f in $files) {
    $rel = 'jutsu\' + $f.Name
    $d = $null
    try {
        $txt = [System.IO.File]::ReadAllText($f.FullName, [System.Text.Encoding]::UTF8)
        $d = $txt | ConvertFrom-Json
    } catch {
        [void]$errors.Add("$rel : JSON не парсится - $($_.Exception.Message)")
        continue
    }
    $jid = [string](Get-Prop $d 'id')
    if ([string]::IsNullOrEmpty($jid)) { [void]$errors.Add("$rel : нет поля id"); continue }
    if ($ids.ContainsKey($jid)) { [void]$errors.Add("$rel : дубликат id $jid (уже в $($ids[$jid]))") }
    else { $ids[$jid] = $rel }

    if ($jid -notlike 'shinobicore:*') { [void]$errors.Add("$rel : id должен начинаться с shinobicore: - $jid") }
    foreach ($k in @('name','category','rank','form','element','activation')) {
        if (-not (Test-HasProp $d $k)) { [void]$errors.Add("$rel : отсутствует обязательное поле '$k'") }
    }

    $el = [string](Get-Prop $d 'element')
    if ($ELEMENTS -notcontains $el) { [void]$errors.Add("$rel : element '$el' не существует") }
    $rk = [string](Get-Prop $d 'rank')
    if ($RANKS -notcontains $rk) { [void]$errors.Add("$rel : rank '$rk' не существует") }

    # --- форма
    $form = Get-Prop $d 'form'
    if ($null -ne $form) {
        $ft = [string](Get-Prop $form 'type')
        if ($FORMS -notcontains $ft) { [void]$errors.Add("$rel : form.type '$ft' не существует") }
        else {
            $allowed = $FORM_PARAMS[$ft]
            foreach ($pn in @(Get-Props (Get-Prop $form 'params'))) {
                if ($allowed -notcontains $pn.Name) {
                    [void]$warnings.Add("$rel : form.params '$($pn.Name)' не читается формой '$ft'")
                }
            }
            if ($ft -eq 'point') {
                $tm = [string](Get-Prop (Get-Prop $form 'params') 'targetMode')
                if ($TARGET_MODES -notcontains $tm) { [void]$warnings.Add("$rel : point.targetMode '$tm' неизвестен (не 'self' -> lookEntity)") }
            }
        }
    }

    # --- активация
    $act = Get-Prop $d 'activation'
    if ($null -ne $act) {
        $at = [string](Get-Prop $act 'type')
        if ($ACT_DEAD -contains $at) { [void]$errors.Add("$rel : activation.type '$at' объявлен, но НЕ обрабатывается JutsuCaster") }
        elseif ($ACTIVATIONS -notcontains $at) { [void]$errors.Add("$rel : activation.type '$at' не существует") }
        else {
            foreach ($pn in @(Get-Props (Get-Prop $act 'params'))) {
                if ($ACT_PARAMS[$at] -notcontains $pn.Name) { [void]$warnings.Add("$rel : activation.params '$($pn.Name)' не читается активацией '$at'") }
            }
        }
    }

    # --- эффекты
    foreach ($e in @(Get-Prop $d 'effects')) {
        if ($null -eq $e) { continue }
        $et = [string](Get-Prop $e 'type'); $es = [string](Get-Prop $e 'subtype')
        if (-not $EFFECTS.ContainsKey($et)) { [void]$errors.Add("$rel : effect.type '$et' не существует"); continue }
        $pair = $et + ':' + $es
        if ($EFFECT_TRAPS -contains $pair) { [void]$errors.Add("$rel : ЛОВУШКА '$pair' объявлен в enum, но не обрабатывается (молча no-op)") }
        elseif ($EFFECTS[$et] -notcontains $es) { [void]$errors.Add("$rel : effect.subtype '$pair' не обрабатывается (молча no-op)") }
    }

    # --- свойства
    foreach ($p in @(Get-Prop $d 'properties')) {
        if ($null -eq $p) { continue }
        $pid2 = [string](Get-Prop $p 'id')
        if ($PROPS -notcontains $pid2) { [void]$errors.Add("$rel : property '$pid2' не встречается в коде движка") }
    }

    # --- стоимость и требования
    foreach ($cn in @(Get-Props (Get-Prop $d 'cost'))) {
        if ($COST_KEYS -notcontains $cn.Name) { [void]$errors.Add("$rel : cost.'$($cn.Name)' не является ResourceType") }
    }
    foreach ($sn in @(Get-Props (Get-Prop (Get-Prop $d 'requirements') 'stats'))) {
        if ($STAT_KEYS -notcontains $sn.Name) { [void]$errors.Add("$rel : requirements.stats.'$($sn.Name)' не является StatType") }
    }
    foreach ($en in @(Get-Props (Get-Prop (Get-Prop $d 'requirements') 'elements'))) {
        if ($ELEMENTS -notcontains $en.Name) { [void]$errors.Add("$rel : requirements.elements.'$($en.Name)' не является ElementType") }
    }

    # --- отладочные техники в ресурсах
    $path = $jid -replace '^shinobicore:', ''
    if ($path -like 'test*') { [void]$warnings.Add("$rel : отладочная техника в ресурсах (TreeAutoGen её пропускает, но файл грузится)") }
}

# =============================================================================
#  2. ЦЕЛОСТНОСТЬ ДЕРЕВА
# =============================================================================
$tpath = J 'src\main\resources\data\shinobicore\skill_tree\tree.json'
Write-Host ''
$tree = $null
if (Test-Path -LiteralPath $tpath) {
    try {
        $tree = ([System.IO.File]::ReadAllText($tpath, [System.Text.Encoding]::UTF8)) | ConvertFrom-Json
    } catch {
        [void]$errors.Add("tree.json : JSON не парсится - $($_.Exception.Message)")
        $tree = $null
    }
}
if ($null -ne $tree) {
    $nodes = @(Get-Prop $tree 'nodes')
    Write-Host "  Проверка дерева: $($nodes.Count) узел(ов)" -ForegroundColor Cyan

    $byId = @{}; $byJutsu = @{}
    foreach ($n in $nodes) {
        if ($null -eq $n) { continue }
        $nid = [string](Get-Prop $n 'id')
        if ($byId.ContainsKey($nid)) { [void]$errors.Add("tree.json : дубликат id узла '$nid'") }
        else { $byId[$nid] = $n }
        $jj = Get-Prop $n 'jutsuId'
        if ($null -ne $jj -and "$jj" -ne '') {
            $key = [string]$jj
            if ($byJutsu.ContainsKey($key)) { [void]$byJutsu[$key].Add($nid) }
            else { $byJutsu[$key] = New-Object System.Collections.ArrayList; [void]$byJutsu[$key].Add($nid) }
        }
    }
    foreach ($k in $byJutsu.Keys) {
        if ($byJutsu[$k].Count -gt 1) {
            [void]$errors.Add("tree.json : jutsuId '$k' у нескольких узлов: $($byJutsu[$k] -join ', ')")
        }
    }
    foreach ($n in $nodes) {
        if ($null -eq $n) { continue }
        $nid = [string](Get-Prop $n 'id')
        foreach ($r in @(Get-Prop $n 'requires')) {
            if ($null -eq $r -or "$r" -eq '') { continue }
            if (-not $byId.ContainsKey([string]$r)) { [void]$errors.Add("tree.json : узел '$nid' требует несуществующий '$r'") }
        }
    }

    # разрешение jutsuId в файлы
    $unresolved = New-Object System.Collections.ArrayList
    foreach ($n in $nodes) {
        if ($null -eq $n) { continue }
        $jj = Get-Prop $n 'jutsuId'
        if ($null -eq $jj -or "$jj" -eq '') { continue }
        if (-not $ids.ContainsKey([string]$jj)) { [void]$unresolved.Add("$jj (узел $((Get-Prop $n 'id')))") }
    }
    if ($unresolved.Count -gt 0) {
        Write-Host "  Ссылок дерева без файла техники: $($unresolved.Count)" -ForegroundColor Yellow
        foreach ($u in $unresolved) { Write-Host "      $u" -ForegroundColor DarkYellow }
    } else {
        Write-Host '  Все jutsuId дерева разрешаются в файлы' -ForegroundColor Green
    }

    # инертные пассивки
    $pass = @($nodes | Where-Object { $null -ne $_ -and ((Get-Prop $_ 'type') -eq 'passive') })
    $inert = @($pass | Where-Object { $PASSIVES_IMPLEMENTED -notcontains ([string](Get-Prop $_ 'id')) })
    $impl = $pass.Count - $inert.Count
    $col = 'Green'; if ($inert.Count -gt 0) { $col = 'Yellow' }
    Write-Host ''
    Write-Host "  Пассивок: $($pass.Count), реализовано в TreePassives: $impl, инертных: $($inert.Count)" -ForegroundColor $col

    $dep = @{}
    foreach ($n in $nodes) {
        if ($null -eq $n) { continue }
        foreach ($r in @(Get-Prop $n 'requires')) {
            if ($null -eq $r -or "$r" -eq '') { continue }
            $rk2 = [string]$r
            if (-not $dep.ContainsKey($rk2)) { $dep[$rk2] = 0 }
            $dep[$rk2] = $dep[$rk2] + 1
        }
    }
    if ($ReportPassives -and $inert.Count -gt 0) {
        $pureLoss = 0; $pureCount = 0
        foreach ($n in $inert) {
            $nid = [string](Get-Prop $n 'id')
            $isGate = $dep.ContainsKey($nid)
            $sp = 0; $spv = Get-Prop $n 'spCost'; if ($null -ne $spv) { $sp = [int]$spv }
            if (-not $isGate) { $pureLoss += $sp; $pureCount++ }
            $eff = Get-Prop $n 'effect'; if ($null -eq $eff) { $eff = '-' }
            $cline = 'DarkYellow'; if (-not $isGate) { $cline = 'Red' }
            $tag = 'гейт prerequisite'; if (-not $isGate) { $tag = 'ЧИСТАЯ ПОТЕРЯ SP' }
            Write-Host ("      {0,-20} effect={1,-20} sp={2,-3} {3}" -f $nid, $eff, $sp, $tag) -ForegroundColor $cline
        }
        Write-Host ''
        Write-Host '  TreePassives.apply() переключается по ID УЗЛА, а не по полю effect.' -ForegroundColor Yellow
        Write-Host "  Инертных узлов: $($inert.Count), тупиковых (не гейт): $pureCount, потеря SP: $pureLoss" -ForegroundColor Yellow
        Write-Host '  Починка требует новых полей в TreePassives.Bonuses и новых потребителей -' -ForegroundColor Yellow
        Write-Host '  это работа отдельного спринта, а не данных.' -ForegroundColor Yellow
    }
} else {
    Write-Host '  tree.json не найден или не парсится - проверка дерева пропущена' -ForegroundColor DarkYellow
}

# =============================================================================
#  ОТЧЁТ
# =============================================================================
Write-Host ''
Write-Host ('=' * 76) -ForegroundColor DarkCyan
if ($warnings.Count -gt 0) {
    Write-Host "  ПРЕДУПРЕЖДЕНИЙ: $($warnings.Count)" -ForegroundColor Yellow
    foreach ($w in $warnings) { Write-Host "    ! $w" -ForegroundColor DarkYellow }
    Write-Host ''
}
if ($errors.Count -eq 0) {
    Write-Host '  ОШИБОК НЕТ' -ForegroundColor Green
    Write-Host ('=' * 76) -ForegroundColor DarkCyan
    exit 0
}
Write-Host "  ОШИБОК: $($errors.Count)" -ForegroundColor Red
foreach ($e in $errors) { Write-Host "    x $e" -ForegroundColor Red }
Write-Host ('=' * 76) -ForegroundColor DarkCyan
exit 1