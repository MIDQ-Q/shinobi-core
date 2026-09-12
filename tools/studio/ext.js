/* =============================================================================
   ShinobiCore Studio — РАСШИРЕНИЕ (ToolsPack 2 / 1.1.3)
   -----------------------------------------------------------------------------
   Разделы: FX Lab (живая симуляция визуала техник), Воксели (3D-редактор и
   генератор моделей), Генераторы (пакетная генерация техник/прокачки/дерева),
   Форматы (шаблоны будущих паков дорожной карты).

   Подключается ПОСЛЕ app.js и не заменяет его: дополняет SECTIONS и
   оборачивает renderSection. Использует глобальные функции студии:
   S, D, dirty, api(), markDirty(), refreshFileText(), saveAll(), loadState(),
   toast(), esc(), h(), $(), canon(), RANK_BALANCE, C().
   ============================================================================= */
'use strict';
(function () {

const EXT_VERSION = 'toolspack-2.0';
const VOX_DIR = 'src/main/resources/assets/shinobicore/voxels';
const TPL_DIR = 'src/main/resources/data/shinobicore/_templates';
const FMT_DIR = 'docs/formats';
const DEFAULT_MODELS = ['fireball', 'water_orb', 'wind_orb', 'earth_orb', 'lightning_orb',
  'yin_orb', 'yang_orb', 'chakra_orb', 'rasengan_blue', 'rasenshuriken', 'shuriken_voxel', 'kunai_voxel'];
const DEFAULT_TEMPLATES = ['item_catalog', 'biome_template', 'structure_template',
  'npc_template', 'quest_template', 'dialog_template'];
const DEFAULT_FORMATS = ['fx_styles', 'items', 'biomes', 'structures', 'npcs', 'quests', 'dialogs'];

/* Каталог стилей — зеркалит switch'и Fx.java v3 и docs/formats/fx_styles.md */
const FX_STYLES = {
  trailStyle:  { label: 'трейл снаряда',   def: 'default',
    opts: { default: 'ядро+ореол', ribbon: 'лента', helix: 'спираль ДНК', smoke: 'дымный шлейф', sparks: 'искры', lightning: 'молния' } },
  impactStyle: { label: 'вспышка попадания', def: 'default',
    opts: { default: 'вспышка+кольцо', nova: 'нова (столп+2 кольца)', shockwave: 'ударная волна', implosion: 'имплозия (сжатие)' } },
  castStyle:   { label: 'круг каста',      def: 'default',
    opts: { default: 'два кольца', runes: 'руны+глифы', pillars: '6 столбов', spiral: 'спиральные руки' } },
  zoneStyle:   { label: 'зона',            def: 'default',
    opts: { default: 'граница+столбы', dome: 'купол', rune_circle: 'рунный круг', vortex: 'воронка', wall: 'стена света' } },
  beamStyle:   { label: 'луч',             def: 'default',
    opts: { default: 'ядро+импульс', lightning: 'ломаная молния', spiral: 'спиральные нити', pulse: 'бегущие сгустки' } }
};
const STYLE_KEYS = ['trailStyle', 'impactStyle', 'castStyle', 'zoneStyle', 'beamStyle'];

/* ---------- состояние расширения ---------- */
const XSV = { models: [], templates: [], formats: [], curModel: -1, fxSel: -1, sim: null, genTab: 'wizard' };

function wrapFile(f) {
  let data = null;
  try { data = JSON.parse(f.text); } catch (e) { /* не json — отдадим как текст */ }
  return { path: f.path, name: f.name, text: f.text, data: data };
}

async function probeFiles(dir, names, ext) {
  const out = [];
  for (const n of names) {
    try {
      const j = await api('/api/file?path=' + encodeURIComponent(dir + '/' + n + ext));
      if (j && j.ok) out.push(wrapFile({ path: j.path, name: n + ext, text: j.text }));
    } catch (e) { /* файла нет — пропускаем */ }
  }
  return out;
}

async function refreshExtData() {
  if (S.files && Array.isArray(S.files.voxels)) {
    XSV.models = S.files.voxels.map(wrapFile);
  } else {
    XSV.models = await probeFiles(VOX_DIR, DEFAULT_MODELS, '.json');
  }
  if (S.files && Array.isArray(S.files.templates)) {
    XSV.templates = S.files.templates.map(wrapFile);
  } else {
    XSV.templates = await probeFiles(TPL_DIR, DEFAULT_TEMPLATES, '.json');
  }
  if (S.files && Array.isArray(S.files.formats)) {
    XSV.formats = S.files.formats.map(wrapFile);
  } else {
    XSV.formats = await probeFiles(FMT_DIR, DEFAULT_FORMATS, '.md');
  }
  if (XSV.curModel >= XSV.models.length) XSV.curModel = XSV.models.length ? 0 : -1;
}

/* ---------- палитры: зеркалят FxPalette.java (одни значения в игре и в превью) ---------- */
const FX_PAL = {
  fire:      { core: '#FF7A1A', glow: '#FFD24A', main: 'flame',        trail: 'flame',       spark: 'lava' },
  water:     { core: '#3FA9FF', glow: '#A8E4FF', main: 'splash',       trail: 'splash',      spark: 'bubble' },
  wind:      { core: '#B8FFD8', glow: '#FFFFFF', main: 'cloud',        trail: 'cloud',       spark: 'crit' },
  earth:     { core: '#C98F4E', glow: '#E8C088', main: 'smoke',        trail: 'smoke',       spark: 'crit' },
  lightning: { core: '#FFF25E', glow: '#FFFFFF', main: 'spark',        trail: 'spark',       spark: 'end_rod' },
  yin:       { core: '#C56BFF', glow: '#E9B8FF', main: 'enchant',      trail: 'enchant',     spark: 'reverse_portal' },
  yang:      { core: '#FFF6C8', glow: '#FFFFFF', main: 'end_rod',      trail: 'end_rod',     spark: 'happy_villager' },
  none:      { core: '#5FA8FF', glow: '#BFE0FF', main: 'soul_fire',    trail: 'end_rod',     spark: 'enchant' }
};
const EL_RU = { fire: 'Огонь', water: 'Вода', wind: 'Ветер', earth: 'Земля',
  lightning: 'Молния', yin: 'Инь', yang: 'Ян', none: 'Чакра' };
const PARTICLE_PRESETS = ['flame', 'soul_fire_flame', 'smoke', 'large_smoke', 'cloud', 'splash',
  'falling_water', 'bubble', 'crit', 'end_rod', 'electric_spark', 'enchant', 'reverse_portal',
  'portal', 'happy_villager', 'witch', 'glow', 'snowflake', 'lava', 'dust'];
/* как пресет частицы выглядит в симуляции */
const P_LOOK = {
  flame:            { col: '#FF9A2E', life: 26, size: 2.6, rise: -0.35, jitter: 0.25 },
  soul_fire_flame:  { col: '#59D8FF', life: 26, size: 2.6, rise: -0.35, jitter: 0.25 },
  soul_fire:        { col: '#59D8FF', life: 26, size: 2.6, rise: -0.35, jitter: 0.25 },
  smoke:            { col: '#847C8A', life: 46, size: 4.2, rise: -0.50, jitter: 0.35, alpha: 0.55 },
  large_smoke:      { col: '#77727E', life: 50, size: 5.0, rise: -0.45, jitter: 0.40, alpha: 0.5 },
  cloud:            { col: '#DFFFEF', life: 34, size: 4.6, rise: -0.10, jitter: 0.55, alpha: 0.6 },
  splash:           { col: '#5FB8FF', life: 18, size: 2.2, rise:  0.55, jitter: 0.40 },
  falling_water:    { col: '#3FA9FF', life: 20, size: 2.0, rise:  0.80, jitter: 0.15 },
  bubble:           { col: '#BFE8FF', life: 30, size: 1.8, rise: -0.60, jitter: 0.15 },
  crit:             { col: '#FFE9A8', life: 14, size: 1.9, rise:  0.00, jitter: 0.90 },
  spark:            { col: '#FFF6A0', life: 12, size: 1.7, rise:  0.10, jitter: 1.20 },
  electric_spark:   { col: '#FFF6A0', life: 12, size: 1.7, rise:  0.10, jitter: 1.20 },
  enchant:          { col: '#C9A0FF', life: 42, size: 1.7, rise: -0.70, jitter: 0.30 },
  end_rod:          { col: '#FFF6D0', life: 34, size: 1.9, rise: -0.15, jitter: 0.08 },
  reverse_portal:   { col: '#B06BFF', life: 30, size: 2.0, rise: -0.20, jitter: 0.30 },
  portal:           { col: '#D070FF', life: 28, size: 1.8, rise: -0.30, jitter: 0.30 },
  happy_villager:   { col: '#A8FF9E', life: 24, size: 2.0, rise: -0.30, jitter: 0.20 },
  witch:            { col: '#B040D0', life: 26, size: 2.0, rise: -0.25, jitter: 0.30 },
  glow:             { col: '#FFF2A0', life: 40, size: 2.2, rise: -0.05, jitter: 0.10 },
  snowflake:        { col: '#EAF6FF', life: 40, size: 2.0, rise:  0.25, jitter: 0.20 },
  lava:             { col: '#FF6A20', life: 30, size: 2.3, rise: -0.20, jitter: 0.50 },
  dust:             { col: null,      life: 36, size: 2.5, rise: -0.05, jitter: 0.10 }
};

/* визуальные пресеты стихий — те же, что применяет мастер-скрипт к JSON */
const ELEMENT_PRESETS = {
  fire:      { particle: 'flame',          trail: 'flame',          color: '#FF7A1A', glow: true,  orb: 'fireball' },
  water:     { particle: 'splash',         trail: 'splash',         color: '#3FA9FF', glow: true,  orb: 'water_orb' },
  wind:      { particle: 'cloud',          trail: 'cloud',          color: '#B8FFD8', glow: true,  orb: 'wind_orb' },
  earth:     { particle: 'large_smoke',    trail: 'crit',           color: '#C98F4E', glow: false, orb: 'earth_orb' },
  lightning: { particle: 'electric_spark', trail: 'electric_spark', color: '#FFF25E', glow: true,  orb: 'lightning_orb' },
  yin:       { particle: 'reverse_portal', trail: 'reverse_portal', color: '#C56BFF', glow: true,  orb: 'yin_orb' },
  yang:      { particle: 'happy_villager', trail: 'end_rod',        color: '#FFF6C8', glow: true,  orb: 'yang_orb' },
  none:      { particle: 'soul_fire_flame',trail: 'end_rod',        color: '#5FA8FF', glow: true,  orb: 'chakra_orb' }
};

function visualPresetFor(el, formType, size) {
  const p = ELEMENT_PRESETS[el] || ELEMENT_PRESETS.none;
  const v = { particle: p.particle, trail: p.trail, color: p.color };
  if (formType === 'projectile' || formType === 'handheld') {
    v.voxelModel = p.orb;
    v.scale = (size && size > 0) ? Math.round(size * 100) / 100 : 1.0;
  } else {
    v.scale = 1.0;
  }
  v.glow = !!p.glow;
  return v;
}

function fxCommitVisual(j, vis) {
  j.data.visual = vis;
  const txt = JSON.stringify(canon(j.data), null, 2) + '\n';
  markDirty(j.path, txt);
  refreshFileText(j.path, txt);
}

/* ---------- хуки в ядро студии ---------- */
const MY_SECTIONS = ['fxlab', 'voxels', 'gen', 'fmts'];

function boot() {
  if (typeof SECTIONS === 'undefined' || typeof D === 'undefined' || typeof api !== 'function') {
    console.warn('[ext] app.js студии не найден — расширение не активируется');
    return;
  }
  if (!SECTIONS.some(function (s) { return s.id === 'fxlab'; })) {
    SECTIONS.push({ sep: true },
      { id: 'fxlab',  label: '🎆 FX Lab',     count: function () { return D.jutsu.length; } },
      { id: 'voxels', label: '🧊 Воксели',    count: function () { return XSV.models.length || ''; } },
      { id: 'gen',    label: '⚙ Генераторы',  count: function () { return ''; } },
      { id: 'fmts',   label: '📐 Форматы',    count: function () { return ''; } });
  }

  const baseRender = window.renderSection;
  window.renderSection = function () {
    if (MY_SECTIONS.indexOf(section) >= 0) {
      if (XSV.sim && section !== 'fxlab') { XSV.sim.stop(); XSV.sim = null; }
      if (XSV.voxPreview && section !== 'voxels') { XSV.voxPreview.stop(); XSV.voxPreview = null; }
      if (XSV.wizSim && section !== 'gen') { XSV.wizSim.stop(); XSV.wizSim = null; }
      const v = $('#view');
      v.scrollTop = 0;
      try {
        if (section === 'fxlab')  return renderFxLab(v);
        if (section === 'voxels') return renderVoxels(v);
        if (section === 'gen')    return renderGen(v);
        if (section === 'fmts')   return renderFmts(v);
      } catch (e) {
        console.error('[ext]', e);
        v.innerHTML = '<div class="card"><h3>Ошибка расширения Studio</h3>' +
          '<div class="issue err">' + esc(e && e.message ? e.message : e) + '</div></div>';
      }
      return;
    }
    if (XSV.sim) { XSV.sim.stop(); XSV.sim = null; }
    if (XSV.voxPreview) { XSV.voxPreview.stop(); XSV.voxPreview = null; }
    if (XSV.wizSim) { XSV.wizSim.stop(); XSV.wizSim = null; }
    return baseRender.apply(this, arguments);
  };

  const baseLoad = window.loadState;
  window.loadState = async function () {
    await baseLoad.apply(this, arguments);
    try { await refreshExtData(); } catch (e) { console.warn('[ext] refreshExtData', e); }
    if (MY_SECTIONS.indexOf(section) >= 0) { renderNav(); renderSection(); }
  };

  refreshExtData().then(function () {
    if (MY_SECTIONS.indexOf(section) >= 0) { renderNav(); renderSection(); }
  }).catch(function () { /* студия ещё не загрузилась — loadState догонит */ });

  console.log('[ShinobiCore Studio ext] ' + EXT_VERSION + ' активен');
}

if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', boot);
else boot();
/* ============================== FX LAB ===================================== */

function palFor(el) { return FX_PAL[el] || FX_PAL.none; }

function simLook(preset, coreColor) {
  const l = P_LOOK[preset] || P_LOOK.dust;
  return Object.assign({}, l, { col: l.col || coreColor });
}

function FxSim(canvas) {
  this.cv = canvas;
  this.ctx = canvas.getContext('2d');
  this.W = canvas.width; this.H = canvas.height;
  this.GROUND = this.H - 46;
  this.parts = [];
  this.t = 0;
  this.raf = null;
  this.kind = 'projectile';
  this.el = 'none';
  this.vis = {};
  this.styles = { trail: 'default', impact: 'default', cast: 'default', zone: 'default', beam: 'default' };
  this.projSpeed = 6.0;
  this.beamLen = 0;
  this.zoneR = 0;
  this.casterX = 70;
}

FxSim.prototype.set = function (kind, el, vis, formParams) {
  this.kind = kind; this.el = el || 'none'; this.vis = vis || {};
  this.syncStyles();
  this.parts.length = 0; this.t = 0;
  const fp = formParams || {};
  this.projSpeed = Math.max(2.5, Math.min(11, (Number(fp.speed) || 1.4) * 4.2));
  this.beamLen = Math.max(120, Math.min(this.W - 120, (Number(fp.maxRange) || 16) * 22));
  this.zoneR = Math.max(70, Math.min(210, (Number(fp.radius) || 5) * 26));
};

FxSim.prototype.syncStyles = function () {
  const v = this.vis || {};
  this.styles = {
    trail:  v.trailStyle  || 'default',
    impact: v.impactStyle || 'default',
    cast:   v.castStyle   || 'default',
    zone:   v.zoneStyle   || 'default',
    beam:   v.beamStyle   || 'default'
  };
};

FxSim.prototype.pal = function () { return palFor(this.el); };

FxSim.prototype.coreColor = function () {
  const v = this.vis || {};
  if (v.color && /^#[0-9a-fA-F]{6}$/.test(v.color)) return v.color;
  return this.pal().core;
};

FxSim.prototype.glowColor = function () { return this.pal().glow; };

FxSim.prototype.scale = function () {
  const s = Number((this.vis || {}).scale);
  return (s > 0) ? Math.max(0.4, Math.min(3, s)) : 1;
};

FxSim.prototype.mainPreset = function () { return (this.vis && this.vis.particle) || this.pal().main; };
FxSim.prototype.trailPreset = function () { return (this.vis && this.vis.trail) || this.pal().trail; };
FxSim.prototype.sparkPreset = function () { return this.pal().spark; };

FxSim.prototype.emit = function (x, y, n, preset, opts) {
  const o = opts || {};
  const look = simLook(preset, this.coreColor());
  const sc = this.scale() * (o.scaleMul || 1);
  for (let i = 0; i < n; i++) {
    const a = o.angle !== undefined ? o.angle + (Math.random() - 0.5) * (o.spread || 0.6)
                                    : Math.random() * Math.PI * 2;
    const sp = (o.speed || 0.6) * (0.5 + Math.random());
    this.parts.push({
      x: x + (Math.random() - 0.5) * (o.jitterPos || 4),
      y: y + (Math.random() - 0.5) * (o.jitterPos || 4),
      vx: o.vx !== undefined ? o.vx + (Math.random() - 0.5) * (o.spreadV || 0.4) : Math.cos(a) * sp,
      vy: o.vy !== undefined ? o.vy + (Math.random() - 0.5) * (o.spreadV || 0.4) : Math.sin(a) * sp * 0.6 + (look.rise || 0) * 0.4,
      life: (look.life || 24) * (o.lifeMul || 1),
      age: 0,
      size: (look.size || 2.2) * sc * (o.sizeMul || 1),
      col: o.color || look.col,
      alpha: look.alpha === undefined ? 1 : look.alpha,
      glow: !!o.glow,
      grav: o.grav || 0
    });
  }
  if (this.parts.length > 1400) this.parts.splice(0, this.parts.length - 1400);
};

FxSim.prototype.ring = function (cx, cy, r, n, preset, opts) {
  const o = opts || {};
  for (let i = 0; i < n; i++) {
    const a = (o.rot || 0) + i * Math.PI * 2 / n;
    this.emit(cx + Math.cos(a) * r, cy + Math.sin(a) * r * (o.flat || 1), 1, preset,
      Object.assign({}, o, { angle: a, speed: o.speed || 0.5, jitterPos: 1 }));
  }
};

FxSim.prototype.trailAt = function (px, py, t) {
  const st = (this.styles && this.styles.trail) || 'default';
  if (st === 'ribbon') {
    const ph = t * 0.55;
    for (let k = -1; k <= 1; k += 2) {
      this.emit(px, py + Math.sin(ph) * 6 * k, 1, 'dust', { speed: 0.05, color: this.glowColor(), jitterPos: 1 });
      this.emit(px - 3, py + Math.cos(ph) * 4 * k, 1, this.trailPreset(), { speed: 0.12, jitterPos: 1.5 });
    }
    this.emit(px, py, 1, 'dust', { speed: 0.05, color: this.coreColor(), jitterPos: 1 });
    return;
  }
  if (st === 'helix') {
    for (let k = 0; k < 2; k++) {
      const ph = t * 0.5 + k * Math.PI;
      this.emit(px + Math.cos(ph) * 2, py + Math.sin(ph) * 7, 1, k ? 'dust' : this.mainPreset(),
        { speed: 0.04, color: k ? this.glowColor() : undefined, jitterPos: 0.8 });
    }
    this.emit(px, py, 1, 'dust', { speed: 0.04, color: this.coreColor(), jitterPos: 1 });
    return;
  }
  if (st === 'smoke') {
    this.emit(px - 2, py, 1, 'large_smoke', { speed: 0.15, scaleMul: 1.1 });
    this.emit(px, py, 1, 'dust', { speed: 0.08, color: this.coreColor(), jitterPos: 2 });
    if (t % 3 === 0) this.emit(px, py, 1, this.mainPreset(), { speed: 0.25 });
    if (t % 6 === 0) this.emit(px, py, 2, this.sparkPreset(), { speed: 0.6 });
    return;
  }
  if (st === 'sparks') {
    this.emit(px, py, 3, this.sparkPreset(), { speed: 1.1, jitterPos: 2 });
    this.emit(px, py, 1, 'dust', { speed: 0.05, color: this.coreColor(), jitterPos: 1 });
    if (this.vis.glow && t % 3 === 0) this.emit(px, py, 1, 'end_rod', { speed: 0.1, glow: true });
    return;
  }
  if (st === 'lightning') {
    this.emit(px, py, 1, 'dust', { speed: 0.04, color: this.coreColor(), jitterPos: 1 });
    for (let i = 0; i < 2; i++) {
      this.emit(px + (Math.random() - 0.5) * 14, py + (Math.random() - 0.5) * 12, 1, 'electric_spark', { speed: 0.5, jitterPos: 1 });
    }
    if (t % 4 === 0) this.emit(px, py, 1, 'end_rod', { speed: 0.1, glow: true });
    return;
  }
  // default (v2)
  this.emit(px, py, 1, 'dust', { speed: 0.12, color: this.coreColor(), jitterPos: 2, scaleMul: 0.9 });
  this.emit(px - 4, py, 2, this.trailPreset(), { speed: 0.3, jitterPos: 3 });
  if ((this.vis && this.vis.glow) && t % 3 === 0) this.emit(px, py, 1, 'end_rod', { speed: 0.1, glow: true });
  if (t % 5 === 0) this.emit(px, py, 1, this.sparkPreset(), { speed: 0.7 });
};

FxSim.prototype.impactFlash = function (x, y, power) {
  const pw = Math.max(0.6, power || 1.4);
  const st = (this.styles && this.styles.impact) || 'default';
  if (st === 'shockwave') {
    this.ring(x, y, 8 * pw, Math.round(26 * pw), 'dust', { speed: 3.4 * pw, flat: 0.35, color: this.coreColor() });
    this.ring(x, y, 6 * pw, Math.round(12 * pw), this.mainPreset(), { speed: 2.6 * pw, flat: 0.35 });
    this.emit(x, y, 4, 'end_rod', { speed: 0.7, glow: true });
    this.emit(x, y - 2, Math.round(3 * pw), 'large_smoke', { speed: 0.7, scaleMul: 1.3 });
    return;
  }
  if (st === 'implosion') {
    for (let i = 0; i < 16; i++) {
      const a = i * Math.PI * 2 / 16;
      const rad = 26 * pw;
      this.emit(x + Math.cos(a) * rad, y + Math.sin(a) * rad * 0.7, 1, i % 3 === 0 ? 'dust' : this.mainPreset(),
        { vx: -Math.cos(a) * 2.2, vy: -Math.sin(a) * 1.6, spreadV: 0.1, color: i % 3 === 0 ? this.glowColor() : undefined, jitterPos: 1 });
    }
    this.emit(x, y, Math.round(5 * pw), 'end_rod', { speed: 0.6, glow: true });
    this.emit(x, y, 6, this.sparkPreset(), { speed: 0.8 });
    return;
  }
  // default + nova
  this.emit(x, y, Math.round(7 * pw), 'end_rod', { speed: 1.1 * pw, glow: true, scaleMul: 1.1 });
  this.ring(x, y, 10 * pw, Math.round(16 * pw), this.mainPreset(), { speed: 1.7 * pw, flat: 0.75 });
  this.emit(x, y, Math.round(8 * pw), this.sparkPreset(), { speed: 2.4 * pw });
  this.emit(x, y, Math.round(6 * pw), 'dust', { speed: 1.0 * pw, color: this.glowColor(), scaleMul: 1.2 });
  if (pw >= 1.4) this.emit(x, y - 6, Math.round(3 * pw), 'large_smoke', { speed: 0.5, scaleMul: 1.2 });
  if (st === 'nova') {
    for (let i = 0; i < 9; i++) {
      this.emit(x + (Math.random() - 0.5) * 5, y - i * 7, 1, i % 3 === 0 ? 'end_rod' : 'dust',
        { vy: -1.6, vx: 0, spreadV: 0.15, color: i % 3 === 0 ? undefined : this.glowColor(), glow: i % 3 === 0 });
    }
    this.ring(x, y, 18 * pw, Math.round(14 * pw), this.trailPreset(), { speed: 2.6 * pw, flat: 0.5 });
  }
};

FxSim.prototype.castCircle = function (cx, cy) {
  const st = (this.styles && this.styles.cast) || 'default';
  const r = 30 * this.scale();
  if (st === 'runes') return this.castRunes(cx, cy, r);
  if (st === 'pillars') return this.castPillars(cx, cy, r);
  if (st === 'spiral') return this.castSpiralArms(cx, cy, r);
  const rot = this.t * 0.07;
  this.ring(cx, cy, r, 12, this.mainPreset(), { rot: rot, speed: 0.25, flat: 0.32 });
  if (this.t % 2 === 0) this.ring(cx, cy, r * 0.66, 7, 'dust', { rot: -rot * 1.7, speed: 0.2, flat: 0.32, color: this.coreColor() });
  if (this.t % 4 === 0) {
    const a = Math.random() * Math.PI * 2;
    this.emit(cx + Math.cos(a) * r * 1.25, cy - 26, 1, (this.vis && this.vis.glow) ? 'end_rod' : this.sparkPreset(),
      { vx: -Math.cos(a) * 0.7, vy: 1.1, spreadV: 0.1, glow: true });
  }
  if (this.t % 24 === 0) this.emit(cx, cy - 4, 4, 'end_rod', { speed: 0.5, glow: true });
};

FxSim.prototype.castRunes = function (cx, cy, r) {
  const t = this.t;
  this.ring(cx, cy, r, 14, 'dust', { rot: 0, speed: 0.05, flat: 0.32, color: this.coreColor() });
  if (t % 2 === 0) this.ring(cx, cy, r * 0.72, 9, 'dust', { rot: 0, speed: 0.05, flat: 0.32, color: this.glowColor() });
  for (let g = 0; g < 4; g++) {
    const a = t * 0.045 + g * Math.PI / 2;
    const gx = cx + Math.cos(a) * r * 0.86, gy = cy + Math.sin(a) * r * 0.86 * 0.32;
    for (let k = 0; k < 3; k++) {
      const da = t * 0.15 + k * Math.PI * 2 / 3;
      this.emit(gx + Math.cos(da) * 3, gy + Math.sin(da) * 1.5, 1, (this.vis.glow ? 'end_rod' : this.sparkPreset()), { speed: 0.02, jitterPos: 0.5, glow: true });
    }
  }
  if (t % 5 === 0) this.emit(cx + (Math.random() - 0.5) * r, cy - 4, 1, this.mainPreset(), { vy: -0.5, vx: 0, spreadV: 0.2 });
};

FxSim.prototype.castPillars = function (cx, cy, r) {
  const t = this.t;
  for (let p = 0; p < 6; p++) {
    const a = t * 0.03 + p * Math.PI / 3;
    const px = cx + Math.cos(a) * r, py = cy + Math.sin(a) * r * 0.32;
    for (let h = 0; h < 4; h++) {
      if ((t + h * 3 + p) % 4 === 0) {
        this.emit(px, py - h * 9 - Math.sin(t * 0.15 + p + h) * 2, 1, h === 3 ? (this.vis.glow ? 'end_rod' : this.sparkPreset()) : this.mainPreset(), { speed: 0.05, jitterPos: 1, glow: h === 3 });
      }
    }
  }
  if (t % 3 === 0) this.ring(cx, cy, r * 0.92, 8, 'dust', { rot: -t * 0.08, speed: 0.05, flat: 0.32, color: this.coreColor() });
};

FxSim.prototype.castSpiralArms = function (cx, cy, r) {
  const t = this.t;
  for (let arm = 0; arm < 2; arm++) {
    for (let i = 0; i < 8; i++) {
      const prog = ((t * 2.2 + i * 8 + arm * 30) % 64) / 64;
      const rad = r * (1.15 - prog);
      const a = arm * Math.PI + prog * 6 + t * 0.04;
      this.emit(cx + Math.cos(a) * rad, cy + Math.sin(a) * rad * 0.32 - prog * 6, 1, i % 3 === 0 ? 'dust' : this.mainPreset(),
        { speed: 0.04, jitterPos: 0.8, color: i % 3 === 0 ? this.glowColor() : undefined });
    }
  }
  if (t % 10 === 0) this.emit(cx, cy - 3, 2, this.vis.glow ? 'end_rod' : this.sparkPreset(), { speed: 0.4, glow: true });
};

FxSim.prototype.chargeGather = function (hx, hy) {
  for (let i = 0; i < 3; i++) {
    const a = this.t * 0.21 + i * Math.PI * 2 / 3 + Math.random() * 0.4;
    const rr = 34 + Math.random() * 8;
    const x = hx + Math.cos(a) * rr, y = hy + Math.sin(a) * rr * 0.7;
    this.emit(x, y, 1, i % 2 ? this.mainPreset() : 'dust',
      { vx: (hx - x) * 0.05, vy: (hy - y) * 0.05, spreadV: 0.05, color: i % 2 ? undefined : this.coreColor(), jitterPos: 1 });
  }
  if (this.t % 6 === 0) this.emit(hx, hy, 2, 'end_rod', { speed: 0.35, glow: true });
};

FxSim.prototype.zoneDraw = function (t, cx, r, G) {
  const st = (this.styles && this.styles.zone) || 'default';
  const baseY = G - 6;
  if (st === 'dome') {
    for (let i = 0; i <= 16; i++) {
      const a = Math.PI * (i / 16);
      const shimmer = ((t + i * 3) % 9 < 2);
      if ((t + i) % 2 === 0) {
        this.emit(cx + Math.cos(a + t * 0.01) * r, baseY - Math.sin(a) * r * 0.62, 1,
          shimmer ? (this.vis.glow ? 'end_rod' : 'dust') : 'dust',
          { speed: 0.03, jitterPos: 1, color: shimmer ? this.glowColor() : this.coreColor(), glow: shimmer });
      }
    }
    if (t % 3 === 0) this.ring(cx, baseY, r, 10, this.mainPreset(), { rot: t * 0.05, speed: 0.1, flat: 0.25 });
    return;
  }
  if (st === 'rune_circle') {
    if (t % 2 === 0) {
      this.ring(cx, baseY, r, 12, 'dust', { rot: t * 0.045, speed: 0.05, flat: 0.28, color: this.coreColor() });
      this.ring(cx, baseY - 3, r * 0.82, 9, 'dust', { rot: -t * 0.06, speed: 0.05, flat: 0.28, color: this.glowColor() });
    }
    if (t % 4 === 0) {
      for (let k = 0; k < 8; k++) {
        const a = t * 0.02 + k * Math.PI / 4;
        const rr = r * (0.25 + ((t + k * 5) % 20) / 20 * 0.7);
        this.emit(cx + Math.cos(a) * rr, baseY - 2, 1, this.mainPreset(), { speed: 0.05, jitterPos: 1 });
      }
    }
    if (t % 60 < 3) this.emit(cx, baseY - 5, 3, this.vis.glow ? 'end_rod' : this.sparkPreset(), { speed: 0.6, glow: true });
    return;
  }
  if (st === 'vortex') {
    for (let i = 0; i < 10; i++) {
      const life = ((t * 2.4 + i * 11) % 40) / 40;
      const a = t * 0.12 + i * Math.PI * 2 / 10 + life * 3.5;
      const rr = r * (1 - life * 0.65);
      this.emit(cx + Math.cos(a) * rr, baseY - life * 95, 1, life > 0.75 ? 'dust' : this.mainPreset(),
        { speed: 0.08, jitterPos: 1.5, color: life > 0.75 ? this.glowColor() : undefined });
    }
    if (t % 5 === 0) this.ring(cx, baseY, r, 6, 'dust', { rot: -t * 0.05, speed: 0.05, flat: 0.25, color: this.coreColor() });
    return;
  }
  if (st === 'wall') {
    for (let i = 0; i < 18; i++) {
      const a = i * Math.PI * 2 / 18 + t * 0.01;
      const rise = ((t * 3 + i * 13) % 44) / 44;
      const px = cx + Math.cos(a) * r;
      const depth = Math.sin(a) * r * 0.22;
      this.emit(px, baseY - rise * 80 + depth * 0.1, 1, rise > 0.8 ? 'dust' : (rise < 0.15 ? 'dust' : this.mainPreset()),
        { speed: 0.04, jitterPos: 1, color: rise > 0.8 ? this.glowColor() : (rise < 0.15 ? this.coreColor() : undefined) });
    }
    if (t % 4 === 0) {
      this.ring(cx, baseY - 80, r, 8, 'dust', { rot: t * 0.04, speed: 0.05, flat: 0.25, color: this.glowColor() });
    }
    return;
  }
  // default (v2)
  const rot = t * 0.02;
  for (let i = 0; i < 20; i++) {
    const a = rot + i * Math.PI / 10;
    if ((t + i) % 3 === 0) {
      this.emit(cx + Math.cos(a) * r, baseY + Math.sin(a) * r * 0.22, 1, (i % 5 === 0) ? 'dust' : this.mainPreset(),
        { speed: 0.12, vy: -0.35, spreadV: 0.1, color: (i % 5 === 0) ? this.coreColor() : undefined, jitterPos: 2 });
    }
  }
  if (t % 7 === 0) {
    for (let q = 0; q < 4; q++) {
      const a = rot * 0.4 + q * Math.PI / 2;
      this.emit(cx + Math.cos(a) * r, baseY - 4, 1, (this.vis && this.vis.glow) ? 'end_rod' : this.sparkPreset(),
        { vx: 0, vy: -1.1, spreadV: 0.12, glow: true });
    }
  }
  if (t % 9 === 0) {
    const a = Math.random() * Math.PI * 2, rr = Math.sqrt(Math.random()) * r * 0.8;
    this.emit(cx + Math.cos(a) * rr, G - 5, 1, this.trailPreset(), { speed: 0.2, vy: -0.25, spreadV: 0.2 });
  }
  if (t % 60 === 0) this.ring(cx, baseY, r * 0.5, 12, 'dust', { speed: 0.5, flat: 0.3, color: this.glowColor() });
};

FxSim.prototype.beamDraw = function (t, x0, y0, len) {
  const st = (this.styles && this.styles.beam) || 'default';
  if (st === 'lightning') {
    let py = y0;
    const seg = Math.max(14, len / 8);
    for (let x = x0; x < x0 + len; x += seg) {
      const ny = y0 + Math.sin((Math.floor(t / 4) * 7919 + x * 13) % 17 / 17 * Math.PI * 2) * 9;
      const steps = 3;
      for (let k = 0; k <= steps; k++) {
        const px2 = x + (seg * k) / steps;
        const py2 = py + ((ny - py) * k) / steps;
        this.emit(px2, py2, 1, 'dust', { speed: 0.03, color: this.coreColor(), jitterPos: 1 });
        if (k % 2 === 0) this.emit(px2, py2, 1, 'electric_spark', { speed: 0.35, jitterPos: 2 });
      }
      py = ny;
    }
    if (t % 4 === 0) {
      this.emit(x0, y0, 2, 'end_rod', { speed: 0.4, glow: true });
      this.emit(x0 + len, py, 3, this.sparkPreset(), { speed: 1.2 });
    }
    return;
  }
  if (st === 'spiral') {
    for (let x = x0; x < x0 + len; x += 7) {
      const a = (x - x0) * 0.09 + t * 0.4;
      this.emit(x, y0 + Math.sin(a) * 8, 1, this.mainPreset(), { speed: 0.06, jitterPos: 1 });
      this.emit(x, y0 + Math.sin(a + Math.PI) * 8, 1, 'dust', { speed: 0.06, color: this.glowColor(), jitterPos: 1 });
      if (x % 21 < 7) this.emit(x, y0, 1, 'dust', { speed: 0.04, color: this.coreColor(), jitterPos: 2 });
    }
    return;
  }
  if (st === 'pulse') {
    for (let x = x0; x < x0 + len; x += 13) {
      this.emit(x, y0, 1, 'dust', { speed: 0.03, color: this.coreColor(), jitterPos: 2 });
    }
    for (let b = 0; b < 2; b++) {
      const bx = x0 + ((t * 5.5 + b * len * 0.5) % len);
      this.emit(bx, y0, 3, 'dust', { speed: 0.25, color: this.glowColor(), scaleMul: 1.35 });
      this.emit(bx, y0, 1, this.vis.glow ? 'end_rod' : this.mainPreset(), { speed: 0.2, glow: true });
    }
    if (t % 5 === 0) this.emit(x0 + len, y0, 2, this.sparkPreset(), { speed: 1.0 });
    return;
  }
  // default (v2)
  for (let x = x0; x < x0 + len; x += 9) {
    this.emit(x, y0, 1, 'dust', { speed: 0.08, color: this.coreColor(), jitterPos: 3, scaleMul: 1.05 });
    if (x % 18 < 9) this.emit(x, y0, 1, this.mainPreset(), { speed: 0.3, jitterPos: 5 });
    if ((this.vis && this.vis.glow) && x % 27 < 9) this.emit(x, y0, 1, 'end_rod', { speed: 0.06, glow: true });
  }
  const pulseX = x0 + ((t * 7) % len);
  this.emit(pulseX, y0, 2, 'dust', { speed: 0.4, color: this.glowColor(), scaleMul: 1.3 });
  if (t % 4 === 0) this.emit(x0 + len, y0, 2, this.sparkPreset(), { speed: 1.1 });
};

FxSim.prototype.step = function () {
  this.t++;
  const t = this.t, G = this.GROUND, W = this.W;
  const handY = G - 62;
  const k = this.kind;

  if (k === 'projectile') {
    if (t < 46) { this.castCircle(this.casterX, G - 4); }
    else if (t === 46) { this.emit(this.casterX + 16, handY, 12, this.mainPreset(), { speed: 1.5 }); this.emit(this.casterX + 16, handY, 5, 'end_rod', { speed: 0.8, glow: true }); }
    else if (t < 46 + Math.ceil((W - 150 - this.casterX) / this.projSpeed)) {
      const px = this.casterX + 16 + (t - 46) * this.projSpeed;
      this.trailAt(px, handY, t);
    }
    else if (t === 46 + Math.ceil((W - 150 - this.casterX) / this.projSpeed)) { this.impactFlash(W - 150, handY, 1.6); }
    if (t > 200) this.t = 0;
  }
  else if (k === 'beam') {
    if (t < 40) { this.castCircle(this.casterX, G - 4); }
    else if (t < 210) {
      const x0 = this.casterX + 14, len = Math.min(this.beamLen, W - 60 - x0);
      this.beamDraw(t, x0, handY, len);
    }
    if (t > 260) this.t = 0;
  }
  else if (k === 'zone') {
    const cx = this.W * 0.55;
    if (t < 40) { this.castCircle(this.casterX, G - 4); }
    else {
      if (t === 41) { this.ring(cx, G - 6, 12, 22, this.mainPreset(), { speed: 2.2, flat: 0.4 }); this.emit(cx, G - 10, 10, 'end_rod', { speed: 1.2, glow: true }); }
      const r = this.zoneR;
      this.zoneDraw(t, cx, r, G);
    }
    if (t > 340) this.t = 0;
  }
  else if (k === 'dash') {
    if (t < 30) { this.castCircle(this.casterX, G - 4); }
    else if (t < 58) {
      const prog = (t - 30) / 28;
      const x = this.casterX + prog * (this.W - 240 - this.casterX);
      this.casterOffset = x - this.casterX;
      if (t % 2 === 0) {
        this.ring(x, G - 34, 16 * this.scale(), 6, 'dust', { speed: 0.3, color: this.coreColor(), flat: 1 });
        this.emit(x - 10, G - 30, 2, this.mainPreset(), { speed: 0.5, jitterPos: 8 });
      }
      if (t === 57) { this.impactFlash(this.W - 240, G - 40, 1.2); this.casterOffset = 0; }
    }
    if (t > 150) { this.t = 0; this.casterOffset = 0; }
  }
  else if (k === 'handheld') {
    const hx = this.casterX + 34, hy = handY - 12;
    if (t < 64) { this.chargeGather(hx, hy); }
    else if (t < 320) {
      const st = t - 64, r = 24 * this.scale();
      for (let ringIdx = 0; ringIdx < 3; ringIdx++) {
        const phi = ringIdx * Math.PI / 3;
        for (let i = 0; i < 6; i++) {
          const a = st * 0.24 + i * Math.PI / 3;
          const x = hx + Math.cos(a) * r * Math.cos(phi) * 1.4;
          const y = hy + Math.sin(a) * r;
          if ((st + i + ringIdx) % 2 === 0) {
            this.emit(x, y, 1, i % 2 ? this.mainPreset() : 'dust',
              { speed: 0.05, color: i % 2 ? undefined : this.glowColor(), jitterPos: 1, scaleMul: 0.9 });
          }
        }
      }
      if (st % 5 === 0) this.emit(hx, hy, 2, 'end_rod', { speed: 0.25, glow: true });
      if (st % 9 === 0) this.emit(hx, hy, 1, this.sparkPreset(), { speed: 1.1 });
    }
    if (t > 380) this.t = 0;
  }
  else if (k === 'point') {
    const tx = this.W - 210;
    if (t < 40) { this.castCircle(this.casterX, G - 4); }
    else if (t === 40) { this.impactFlash(tx, G - 42, 1.3); }
    else if (t < 90 && t % 4 === 0) { this.emit(tx, G - 50, 2, this.mainPreset(), { vy: -0.7, vx: 0, spreadV: 0.3 }); }
    if (t > 150) this.t = 0;
  }
  else {
    const tx = this.W * 0.55;
    if (t < 40) { this.castCircle(this.casterX, G - 4); }
    else if (t === 40) {
      this.emit(tx, G - 8, 16, this.mainPreset(), { speed: 1.6 });
      this.emit(tx, G - 8, 8, 'large_smoke', { speed: 0.7, scaleMul: 1.4 });
    }
    else if (t < 100 && t % 3 === 0) {
      this.emit(tx + (Math.random() - 0.5) * 30, G - 10 - Math.random() * 40, 1, 'dust',
        { speed: 0.15, color: this.coreColor(), vy: -0.4, spreadV: 0.15 });
    }
    if (t > 170) this.t = 0;
  }

  for (let i = this.parts.length - 1; i >= 0; i--) {
    const p = this.parts[i];
    p.age++;
    p.x += p.vx; p.y += p.vy; p.vy += p.grav;
    p.vx *= 0.985; p.vy *= 0.985;
    if (p.age >= p.life) this.parts.splice(i, 1);
  }
};

FxSim.prototype.figure = function (x, y, color) {
  const c = this.ctx;
  c.save();
  c.fillStyle = '#1d1526';
  c.strokeStyle = color;
  c.lineWidth = 1.4;
  c.beginPath(); c.arc(x, y - 46, 7, 0, Math.PI * 2); c.fill(); c.stroke();
  c.beginPath();
  c.moveTo(x - 8, y - 38); c.lineTo(x + 8, y - 38); c.lineTo(x + 5, y - 8); c.lineTo(x - 5, y - 8);
  c.closePath(); c.fill(); c.stroke();
  c.beginPath(); c.moveTo(x - 4, y - 8); c.lineTo(x - 6, y); c.moveTo(x + 4, y - 8); c.lineTo(x + 6, y); c.stroke();
  c.restore();
};

FxSim.prototype.draw = function () {
  const c = this.ctx, W = this.W, H = this.H, G = this.GROUND;
  c.globalCompositeOperation = 'source-over';
  const bg = c.createLinearGradient(0, 0, 0, H);
  bg.addColorStop(0, '#0d0912'); bg.addColorStop(1, '#171021');
  c.fillStyle = bg; c.fillRect(0, 0, W, H);
  c.strokeStyle = 'rgba(255,158,196,0.16)';
  c.beginPath(); c.moveTo(0, G); c.lineTo(W, G); c.stroke();
  c.fillStyle = 'rgba(255,255,255,0.045)';
  for (let x = 0; x < W; x += 32) c.fillRect(x, G, 16, H - G);

  const core = this.coreColor();
  this.figure(this.casterX + (this.casterOffset || 0), G, core);
  if (this.kind === 'projectile' || this.kind === 'point' || this.kind === 'dash') {
    const tx = (this.kind === 'point') ? W - 210 : W - 150;
    c.save();
    c.fillStyle = '#241a2c'; c.strokeStyle = 'rgba(255,255,255,0.25)';
    c.fillRect(tx - 9, G - 44, 18, 44); c.strokeRect(tx - 9, G - 44, 18, 44);
    c.restore();
  }

  c.globalCompositeOperation = 'lighter';
  for (const p of this.parts) {
    const f = 1 - p.age / p.life;
    const r = Math.max(0.4, p.size * (0.55 + f * 0.65));
    c.globalAlpha = Math.max(0, Math.min(1, f * (p.alpha === undefined ? 1 : p.alpha)));
    if (p.glow) {
      c.fillStyle = '#ffffff';
      c.beginPath(); c.arc(p.x, p.y, r * 0.55, 0, Math.PI * 2); c.fill();
    }
    c.fillStyle = p.col;
    c.beginPath(); c.arc(p.x, p.y, r, 0, Math.PI * 2); c.fill();
  }
  c.globalAlpha = 1;
  c.globalCompositeOperation = 'source-over';

  c.fillStyle = 'rgba(255,255,255,0.55)';
  c.font = '10px sans-serif';
  const kindRu = { projectile: 'снаряд', beam: 'луч', zone: 'зона', dash: 'рывок', handheld: 'ручной конструкт', point: 'точка', summon: 'призыв', construct: 'конструкт' };
  c.fillText((EL_RU[this.el] || this.el) + ' · ' + (kindRu[this.kind] || this.kind), 10, 16);
};

FxSim.prototype.start = function () {
  if (this.raf) return;
  const self = this;
  const loop = function () { self.step(); self.draw(); self.raf = requestAnimationFrame(loop); };
  loop();
};

FxSim.prototype.stop = function () {
  if (this.raf) cancelAnimationFrame(this.raf);
  this.raf = null;
};

/* ---------- UI ---------- */
function fxCur() { return (XSV.fxSel >= 0 && D.jutsu[XSV.fxSel]) ? D.jutsu[XSV.fxSel] : null; }

function renderFxLab(v) {
  if (XSV.sim) { XSV.sim.stop(); XSV.sim = null; }
  const j = fxCur();

  v.innerHTML =
    '<h2 class="title">🎆 FX Lab <span class="sub">симуляция визуала — палитры синхронны с FxPalette.java; правки пишутся в visual-блок техники</span></h2>' +
    '<div class="jwrap" style="grid-template-columns:240px minmax(0,1fr)">' +
      '<div class="jlist" id="fx-list">' +
        '<div class="filters"><input id="fx-filter" placeholder="поиск…" style="width:100%"></div>' +
        '<div id="fx-items"></div>' +
      '</div>' +
      '<div>' +
        '<div class="card"><h3>Симуляция <span class="hint" id="fx-scene"></span></h3>' +
          '<div class="viz" style="padding:0;overflow:hidden"><canvas id="fx-canvas" width="660" height="330" style="display:block;width:100%"></canvas></div>' +
          '<div class="vizcap" id="fx-cap"></div>' +
        '</div>' +
        '<div class="card"><h3>visual-блок <span class="hint">изменения применяются сразу и помечаются к сохранению</span></h3>' +
          '<div class="grid g3" id="fx-controls"></div>' +
          '<div class="row tight" style="margin-top:12px" id="fx-buttons"></div>' +
        '</div>' +
      '</div>' +
    '</div>';

  const fillItems = function (filter) {
    const box = $('#fx-items'); if (!box) return;
    box.innerHTML = '';
    const f = (filter || '').toLowerCase();
    D.jutsu.forEach(function (jj, i) {
      const d = jj.data || {};
      const hay = (String(d.id) + ' ' + String(d.name)).toLowerCase();
      if (f && hay.indexOf(f) < 0) return;
      const el = d.element || 'none';
      const it = h('<div class="item' + (XSV.fxSel === i ? ' on' : '') + '">' +
        '<span class="dot" style="background:' + esc(elColor(el)) + '"></span>' +
        '<span class="nm">' + esc(d.name || jj.name) + '</span>' +
        '<span class="rk" style="color:var(--gold)">' + esc(d.rank || '') + '</span></div>');
      it.onclick = function () { XSV.fxSel = i; renderSection(); };
      box.appendChild(it);
    });
  };
  fillItems('');
  $('#fx-filter').oninput = function () { fillItems(this.value); };

  const d = j ? (j.data || {}) : null;
  const el = d ? (d.element || 'none') : 'none';
  const formType = d ? ((d.form || {}).type || 'projectile') : 'projectile';
  const vis = (d && d.visual) ? d.visual : {};

  const canvas = $('#fx-canvas');
  const sim = new FxSim(canvas);
  sim.set(formType, el, vis, (d && d.form) ? d.form.params : null);
  sim.start();
  XSV.sim = sim;

  $('#fx-scene').textContent = j ? (d.name + ' — форма «' + formType + '»') : 'демо-сцена (техника не выбрана)';
  $('#fx-cap').innerHTML = 'Слева кастер, справа цель. Фазы: <b>круг каста</b> → ' +
    ({ projectile: 'вылет → трейл → вспышка попадания', beam: 'ядро луча с бегущим импульсом',
       zone: 'граница зоны + столбы + туман', dash: 'призрачные кольца рывка',
       handheld: 'сбор чакры → вращающаяся сфера', point: 'вспышка на цели',
       summon: 'столб призыва', construct: 'столб конструкта' }[formType] || '') +
    '. В игре к этому добавляется воксельная модель снаряда (раздел «Воксели»).';

  const pal = palFor(el);
  const opts = PARTICLE_PRESETS.map(function (p) { return '<option value="' + p + '">' + p + '</option>'; }).join('');
  const modelNames = XSV.models.map(function (m) { return m.name.replace(/\.json$/, ''); });
  const modelOpts = '<option value="">(без модели)</option>' + modelNames.map(function (m) {
    return '<option value="' + esc(m) + '">' + esc(m) + '</option>';
  }).join('');

  $('#fx-controls').innerHTML =
    '<label class="f"><span>цвет (color)</span><input type="color" id="v-color" value="' +
      esc(/^#[0-9a-fA-F]{6}$/.test(vis.color || '') ? vis.color : pal.core) + '"></label>' +
    '<label class="f"><span>частица (particle)</span><select id="v-particle"><option value="">по стихии (' + esc(pal.main) + ')</option>' + opts + '</select></label>' +
    '<label class="f"><span>трейл (trail)</span><select id="v-trail"><option value="">по стихии (' + esc(pal.trail) + ')</option>' + opts + '</select></label>' +
    '<label class="f"><span>масштаб (scale): <b id="v-scale-n">' + esc(fmt(vis.scale === undefined ? 1 : vis.scale)) + '</b></span>' +
      '<input type="range" id="v-scale" min="0.4" max="3" step="0.1" value="' + esc(vis.scale === undefined ? 1 : vis.scale) + '"></label>' +
    '<label class="f"><span>свечение (glow)</span><select id="v-glow"><option value="true">вкл — слой END_ROD</option><option value="false">выкл</option></select></label>' +
    '<label class="f"><span>воксельная модель</span><select id="v-voxel">' + modelOpts + '</select></label>';

  const styleBox = h('<div class="grid g3" id="fx-styles" style="grid-column:1/-1;margin-top:4px"></div>');
  $('#fx-controls').appendChild(styleBox);
  for (const key of STYLE_KEYS) {
    const meta = FX_STYLES[key];
    let o = '';
    for (const id of Object.keys(meta.opts)) {
      o += '<option value="' + id + '"' + ((vis[key] || 'default') === id ? ' selected' : '') + '>' + esc(meta.opts[id]) + '</option>';
    }
    styleBox.appendChild(h('<label class="f"><span>' + esc(meta.label) + ' <b class="mono dim">' + key + '</b></span>' +
      '<select id="v-' + key + '">' + o + '</select></label>'));
  }

  $('#v-particle').value = vis.particle || '';
  $('#v-trail').value = vis.trail || '';
  $('#v-glow').value = vis.glow ? 'true' : 'false';
  $('#v-voxel').value = vis.voxelModel || '';

  const rebuildVis = function () {
    const nv = {
      particle: $('#v-particle').value || undefined,
      trail: $('#v-trail').value || undefined,
      color: $('#v-color').value || undefined,
      voxelModel: $('#v-voxel').value || undefined,
      scale: Number($('#v-scale').value) || 1,
      glow: $('#v-glow').value === 'true'
    };
    for (const key of STYLE_KEYS) {
      const sel = $('#v-' + key);
      const v = sel ? sel.value : 'default';
      nv[key] = (v && v !== 'default') ? v : undefined;
    }
    Object.keys(nv).forEach(function (k) { if (nv[k] === undefined || nv[k] === '') delete nv[k]; });
    sim.vis = nv;
    sim.syncStyles();
    $('#v-scale-n').textContent = fmt(nv.scale);
    if (j) { fxCommitVisual(j, nv); }
    return nv;
  };
  const bindSels = ['#v-color', '#v-particle', '#v-trail', '#v-scale', '#v-glow', '#v-voxel'];
  for (const key of STYLE_KEYS) bindSels.push('#v-' + key);
  bindSels.forEach(function (sel) {
    const node = $(sel);
    if (!node) return;
    node.oninput = rebuildVis;
    node.onchange = rebuildVis;
  });

  $('#fx-buttons').innerHTML =
    '<button class="btn sm" id="fx-default">↺ Дефолт стихии</button>' +
    '<button class="btn sm" id="fx-rand">🎲 Случайный визуал</button>' +
    '<button class="btn sm" id="fx-cmd">📋 Команда каста</button>' +
    '<button class="btn sm" id="fx-copy-el">⧉ На все техники «' + esc(EL_RU[el] || el) + '»</button>' +
    '<button class="btn sm pri" id="fx-bright-all">✨ Яркий пресет всем без visual</button>' +
    '<button class="btn sm danger" id="fx-clear">✕ Убрать visual у выбранной</button>';

  $('#fx-rand').onclick = function () {
    if (!j) { toast('Выберите технику', 'err'); return; }
    const pick = function (obj) { const ks = Object.keys(obj); return ks[Math.floor(Math.random() * ks.length)]; };
    const nv = {
      color: $('#v-color').value,
      scale: Number($('#v-scale').value) || 1,
      glow: Math.random() < 0.75
    };
    for (const key of STYLE_KEYS) {
      const v = pick(FX_STYLES[key].opts);
      if (v !== 'default') nv[key] = v;
    }
    fxCommitVisual(j, nv);
    toast('Случайный визуал для ' + (d.name || '') + ' — покрутите ползунки или нажмите ещё раз');
    renderSection();
  };
  $('#fx-cmd').onclick = function () {
    if (!j) { toast('Выберите технику', 'err'); return; }
    const cmd = '/shinobicore jutsu cast ' + (d.id || '');
    const done = function () { toast('Скопировано: ' + cmd, 'ok'); };
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(cmd).then(done).catch(function () { prompt('Скопируйте вручную:', cmd); });
    } else { prompt('Скопируйте вручную:', cmd); }
  };

  $('#fx-default').onclick = function () {
    if (!j) { toast('Выберите технику', 'err'); return; }
    const size = ((d.form || {}).params || {}).size;
    fxCommitVisual(j, visualPresetFor(el, formType, size));
    toast('Визуал сброшен к пресету стихии');
    renderSection();
  };
  $('#fx-copy-el').onclick = function () {
    if (!j) { toast('Выберите технику-источник', 'err'); return; }
    const src = JSON.parse(JSON.stringify(vis));
    let n = 0;
    for (const jj of D.jutsu) {
      if (jj === j) continue;
      if ((jj.data || {}).element !== el) continue;
      const ft = ((jj.data.form || {}).type) || '';
      const copy = JSON.parse(JSON.stringify(src));
      if (ft !== 'projectile' && ft !== 'handheld') delete copy.voxelModel;
      fxCommitVisual(jj, copy);
      n++;
    }
    toast('Скопировано на ' + n + ' техник(и) той же стихии. Сохраните (Ctrl+S).', 'ok');
  };
  $('#fx-bright-all').onclick = function () {
    let n = 0;
    for (const jj of D.jutsu) {
      const dd = jj.data || {};
      if (dd.visual) continue;
      const ft = ((dd.form || {}).type) || '';
      const size = ((dd.form || {}).params || {}).size;
      fxCommitVisual(jj, visualPresetFor(dd.element || 'none', ft, size));
      n++;
    }
    if (n) { toast('Яркий пресет добавлен в ' + n + ' техник. Сохраните (Ctrl+S).', 'ok'); renderSection(); }
    else toast('visual уже есть у всех техник');
  };
  $('#fx-clear').onclick = function () {
    if (!j) { toast('Выберите технику', 'err'); return; }
    delete j.data.visual;
    const txt = JSON.stringify(canon(j.data), null, 2) + '\n';
    markDirty(j.path, txt);
    refreshFileText(j.path, txt);
    toast('visual удалён у ' + (d.name || j.name));
    renderSection();
  };
}
/* ============================== ВОКСЕЛИ v3 ================================= */
/* 3D-превью + РУЧНАЯ ОТРИСОВКА (пейнт по сетке 1/16), генераторы примитивов,
   композиция (добавление/массив по кругу), импорт Blockbench .bbmodel.       */

function hexToRgb(hex) {
  const m = /^#?([0-9a-fA-F]{6})$/.exec(hex || '');
  if (!m) return [255, 102, 0];
  const n = parseInt(m[1], 16);
  return [(n >> 16) & 255, (n >> 8) & 255, n & 255];
}

const GRID_N = 32;            // ячеек на блок (сетка от -0.5 до 1.5)
const CELL = 1 / 16;          // размер ячейки
const GRID_ORIGIN = -0.5;

function cellCoord(i) { return GRID_ORIGIN + i * CELL; }
function cellIndex(x) { return Math.floor((x - GRID_ORIGIN) / CELL); }

function VoxelPreview(canvas) {
  this.cv = canvas;
  this.ctx = canvas.getContext('2d');
  this.yaw = 0.6; this.pitch = 0.35;
  this.auto = true;
  this.root = null;
  this.t0 = performance.now();
  this.raf = null;
  this.drag = null;
  // режимы: 'view' | 'paint' | 'erase' | 'pick'
  this.mode = 'view';
  this.gridOn = true;
  this.layer = 16;             // активный Y-слой (0..31)
  this.brush = '#5FA8FF';
  this.brushAlpha = 1.0;
  this.symX = false;
  this.symZ = false;
  this.hover = null;           // {kind:'face', ci, fn} | {kind:'grid', c:[ix,iy,iz]}
  this.mouse = null;           // {x,y} в координатах canvas
  this.pickList = [];
  this.onChange = null;        // callback(root) после paint/erase
  const self = this;
  canvas.addEventListener('mousedown', function (e) {
    if (self.mode === 'view' || e.button === 1) {
      self.drag = { x: e.clientX, y: e.clientY, yaw: self.yaw, pitch: self.pitch };
      return;
    }
    if (e.button === 0) self.applyBrush(e);
    if (e.button === 2) self.applyErase(e);
  });
  canvas.addEventListener('contextmenu', function (e) { e.preventDefault(); });
  window.addEventListener('mouseup', function () { self.drag = null; });
  window.addEventListener('mousemove', function (e) {
    if (self.drag) {
      self.yaw = self.drag.yaw + (e.clientX - self.drag.x) * 0.01;
      self.pitch = Math.max(-1.2, Math.min(1.2, self.drag.pitch + (e.clientY - self.drag.y) * 0.01));
      return;
    }
    const r = self.cv.getBoundingClientRect();
    const sx = (e.clientX - r.left) * (self.cv.width / r.width);
    const sy = (e.clientY - r.top) * (self.cv.height / r.height);
    if (sx >= 0 && sy >= 0 && sx <= self.cv.width && sy <= self.cv.height) {
      self.mouse = { x: sx, y: sy };
    } else { self.mouse = null; self.hover = null; }
  });
}

VoxelPreview.prototype.set = function (root) { this.root = root; };

VoxelPreview.prototype.start = function () {
  if (this.raf) return;
  const self = this;
  const loop = function () { self.draw(); self.raf = requestAnimationFrame(loop); };
  loop();
};
VoxelPreview.prototype.stop = function () { if (this.raf) cancelAnimationFrame(this.raf); this.raf = null; };

function rotAxis(p, axis, ang, origin) {
  const c = Math.cos(ang), s = Math.sin(ang);
  let x = p[0] - origin[0], y = p[1] - origin[1], z = p[2] - origin[2];
  let nx = x, ny = y, nz = z;
  if (axis === 'x') { ny = y * c - z * s; nz = y * s + z * c; }
  else if (axis === 'y') { nx = x * c + z * s; nz = -x * s + z * c; }
  else { nx = x * c - y * s; ny = x * s + y * c; }
  return [nx + origin[0], ny + origin[1], nz + origin[2]];
}

const V_FACES = [
  { n: [0, 0, 1], v: [[0, 0, 1], [1, 0, 1], [1, 1, 1], [0, 1, 1]] },
  { n: [0, 0, -1], v: [[1, 0, 0], [0, 0, 0], [0, 1, 0], [1, 1, 0]] },
  { n: [1, 0, 0], v: [[1, 0, 1], [1, 0, 0], [1, 1, 0], [1, 1, 1]] },
  { n: [-1, 0, 0], v: [[0, 0, 0], [0, 0, 1], [0, 1, 1], [0, 1, 0]] },
  { n: [0, 1, 0], v: [[0, 1, 1], [1, 1, 1], [1, 1, 0], [0, 1, 0]] },
  { n: [0, -1, 0], v: [[0, 0, 0], [1, 0, 0], [1, 0, 1], [0, 0, 1]] }
];

VoxelPreview.prototype.frame = function () {
  const root = this.root;
  const W = this.cv.width, H = this.cv.height;
  let minX = 1e9, minY = 1e9, minZ = 1e9, maxX = -1e9, maxY = -1e9, maxZ = -1e9;
  const els = (root && Array.isArray(root.elements)) ? root.elements : [];
  for (const e of els) {
    if (!e || !e.from || !e.to) continue;
    minX = Math.min(minX, e.from[0]); maxX = Math.max(maxX, e.to[0]);
    minY = Math.min(minY, e.from[1]); maxY = Math.max(maxY, e.to[1]);
    minZ = Math.min(minZ, e.from[2]); maxZ = Math.max(maxZ, e.to[2]);
  }
  if (this.gridOn) {
    minX = Math.min(minX, GRID_ORIGIN); maxX = Math.max(maxX, GRID_ORIGIN + 2);
    minY = Math.min(minY, GRID_ORIGIN); maxY = Math.max(maxY, GRID_ORIGIN + 2);
    minZ = Math.min(minZ, GRID_ORIGIN); maxZ = Math.max(maxZ, GRID_ORIGIN + 2);
  }
  const cx = (minX + maxX) / 2, cy = (minY + maxY) / 2, cz = (minZ + maxZ) / 2;
  const extent = Math.max(0.2, Math.max(maxX - minX, maxY - minY, maxZ - minZ));
  const S = Math.min(W, H) * 0.62 / extent;
  return { cx: cx, cy: cy, cz: cz, S: S };
};

VoxelPreview.prototype.makeProject = function (fr, animT) {
  const root = this.root || {};
  const anim = (this.mode === 'view') ? (root.anim || {}) : {};
  const spin = anim.spin || [0, 0, 0];
  const pulse = anim.pulse ? 1 + anim.pulse * Math.sin(animT * (anim.pulseSpeed || 3)) : 1;
  const bob = anim.bob ? anim.bob * Math.sin(animT * (anim.bobSpeed || 2)) : 0;
  const yaw = this.yaw, pitch = this.pitch;
  const cyaw = Math.cos(yaw), syaw = Math.sin(yaw);
  const cpit = Math.cos(pitch), spit = Math.sin(pitch);
  const sxr = spin[0] * animT * Math.PI / 180, syr = spin[1] * animT * Math.PI / 180, szr = spin[2] * animT * Math.PI / 180;
  const W = this.cv.width, H = this.cv.height;
  const cx = fr.cx, cy = fr.cy, cz = fr.cz, S = fr.S;
  return function (p) {
    let x = (p[0] - cx) * pulse, y = (p[1] - cy) * pulse + bob, z = (p[2] - cz) * pulse;
    if (sxr) { const q = rotAxis([x, y, z], 'x', sxr, [0, 0, 0]); x = q[0]; y = q[1]; z = q[2]; }
    if (syr) { const q = rotAxis([x, y, z], 'y', syr, [0, 0, 0]); x = q[0]; y = q[1]; z = q[2]; }
    if (szr) { const q = rotAxis([x, y, z], 'z', szr, [0, 0, 0]); x = q[0]; y = q[1]; z = q[2]; }
    const x1 = x * cyaw + z * syaw;
    const z1 = -x * syaw + z * cyaw;
    const y2 = y * cpit - z1 * spit;
    const z2 = y * spit + z1 * cpit;
    return [W / 2 + x1 * S, H / 2 - y2 * S, z2];
  };
};

VoxelPreview.prototype.draw = function () {
  const c = this.ctx, W = this.cv.width, H = this.cv.height;
  c.clearRect(0, 0, W, H);
  c.fillStyle = '#120d15'; c.fillRect(0, 0, W, H);
  const root = this.root;
  const t = (performance.now() - this.t0) / 1000;
  if (this.auto && !this.drag && this.mode === 'view') this.yaw += 0.006;

  const fr = this.frame();
  const project = this.makeProject(fr, t);

  // ---- сетка активного слоя (в режиме пейнта) ----
  if (this.gridOn && this.mode !== 'view') {
    const yTop = GRID_ORIGIN + (this.layer + 1) * CELL;
    c.strokeStyle = 'rgba(255,158,196,0.14)';
    c.lineWidth = 1;
    for (let i = 0; i <= GRID_N; i += 4) {
      const w = GRID_ORIGIN + i * CELL;
      let a = project([w, yTop, GRID_ORIGIN]);
      let b = project([w, yTop, GRID_ORIGIN + 2]);
      c.beginPath(); c.moveTo(a[0], a[1]); c.lineTo(b[0], b[1]); c.stroke();
      a = project([GRID_ORIGIN, yTop, w]);
      b = project([GRID_ORIGIN + 2, yTop, w]);
      c.beginPath(); c.moveTo(a[0], a[1]); c.lineTo(b[0], b[1]); c.stroke();
    }
    const corners = [
      project([GRID_ORIGIN, yTop, GRID_ORIGIN]), project([GRID_ORIGIN + 2, yTop, GRID_ORIGIN]),
      project([GRID_ORIGIN + 2, yTop, GRID_ORIGIN + 2]), project([GRID_ORIGIN, yTop, GRID_ORIGIN + 2])
    ];
    c.strokeStyle = 'rgba(255,158,196,0.4)';
    c.beginPath();
    c.moveTo(corners[0][0], corners[0][1]);
    for (let i = 1; i < 4; i++) c.lineTo(corners[i][0], corners[i][1]);
    c.closePath(); c.stroke();
  }

  if (!root || !Array.isArray(root.elements) || (!root.elements.length && this.mode === 'view')) {
    c.fillStyle = 'rgba(255,255,255,0.35)'; c.font = '12px sans-serif';
    c.fillText(this.mode === 'view' ? 'нет модели — выберите или сгенерируйте' : 'пустая модель — рисуйте по сетке', 14, 24);
    this.pickList = [];
    return;
  }

  const light = (function () {
    const l = [0.42, 0.78, 0.46];
    const n = Math.sqrt(l[0] * l[0] + l[1] * l[1] + l[2] * l[2]);
    return [l[0] / n, l[1] / n, l[2] / n];
  })();

  const quads = [];
  this.pickList = [];
  let ci = 0;
  for (const e of root.elements) {
    if (!e || !e.from || !e.to) { ci++; continue; }
    const rgb = hexToRgb(e.color);
    const alpha = e.alpha === undefined ? 1 : e.alpha;
    let corners = [];
    for (let i = 0; i < 8; i++) {
      corners.push([
        i & 1 ? e.to[0] : e.from[0],
        i & 2 ? e.to[1] : e.from[1],
        i & 4 ? e.to[2] : e.from[2]
      ]);
    }
    if (e.rotation && e.rotation.axis && e.rotation.angle) {
      const org = e.rotation.origin || [0.5, 0.5, 0.5];
      const ang = e.rotation.angle * Math.PI / 180;
      corners = corners.map(function (p) { return rotAxis(p, e.rotation.axis, ang, org); });
    }
    const idx = function (x, y, z) { return (x ? 1 : 0) | (y ? 2 : 0) | (z ? 4 : 0); };
    for (const f of V_FACES) {
      let n = f.n.slice();
      if (e.rotation && e.rotation.axis && e.rotation.angle) {
        const org = e.rotation.origin || [0.5, 0.5, 0.5];
        const ang = e.rotation.angle * Math.PI / 180;
        const base = [org[0] + n[0], org[1] + n[1], org[2] + n[2]];
        const rb = rotAxis(org, e.rotation.axis, ang, org);
        const rt = rotAxis(base, e.rotation.axis, ang, org);
        n = [rt[0] - rb[0], rt[1] - rb[1], rt[2] - rb[2]];
      }
      const yaw = this.yaw, pitch = this.pitch;
      const cyaw = Math.cos(yaw), syaw = Math.sin(yaw);
      const cpit = Math.cos(pitch), spit = Math.sin(pitch);
      const ny = n[0] * cyaw + n[2] * syaw;
      const nz1 = -n[0] * syaw + n[2] * cyaw;
      const nzz = n[1] * spit + nz1 * cpit;
      if (nzz <= 0.02) continue;
      const pts = f.v.map(function (vv) { return project(corners[idx(vv[0], vv[1], vv[2])]); });
      const depth = pts.reduce(function (a, p) { return a + p[2]; }, 0) / 4;
      const shade = 0.38 + 0.62 * Math.max(0, n[0] * light[0] + n[1] * light[1] + n[2] * light[2]);
      quads.push({ pts: pts, depth: depth, rgb: rgb, alpha: alpha, shade: shade });
      this.pickList.push({ pts: pts, depth: depth, ci: ci, fn: f.n });
    }
    ci++;
  }
  quads.sort(function (a, b) { return a.depth - b.depth; });
  this.pickList.sort(function (a, b) { return b.depth - a.depth; });
  for (const q of quads) {
    c.globalAlpha = Math.max(0.05, Math.min(1, q.alpha));
    const r = Math.round(q.rgb[0] * q.shade), g = Math.round(q.rgb[1] * q.shade), b = Math.round(q.rgb[2] * q.shade);
    c.fillStyle = 'rgb(' + r + ',' + g + ',' + b + ')';
    c.strokeStyle = 'rgba(0,0,0,0.28)';
    c.lineWidth = 0.6;
    c.beginPath();
    c.moveTo(q.pts[0][0], q.pts[0][1]);
    for (let i = 1; i < 4; i++) c.lineTo(q.pts[i][0], q.pts[i][1]);
    c.closePath();
    c.fill();
    c.stroke();
  }
  c.globalAlpha = 1;

  // ---- ховер + призрак ----
  this.hover = this.computeHover();
  if (this.hover && this.mode !== 'view') {
    const cell = this.hoverCell();
    if (cell) {
      const x0 = cellCoord(cell[0]), y0 = cellCoord(cell[1]), z0 = cellCoord(cell[2]);
      const corners = [
        project([x0, y0 + CELL, z0]), project([x0 + CELL, y0 + CELL, z0]),
        project([x0 + CELL, y0 + CELL, z0 + CELL]), project([x0, y0 + CELL, z0 + CELL])
      ];
      c.fillStyle = this.mode === 'erase' ? 'rgba(255,80,80,0.35)' : 'rgba(140,220,255,0.35)';
      c.strokeStyle = this.mode === 'erase' ? 'rgba(255,120,120,0.9)' : 'rgba(180,235,255,0.9)';
      c.lineWidth = 1.2;
      c.beginPath();
      c.moveTo(corners[0][0], corners[0][1]);
      for (let i = 1; i < 4; i++) c.lineTo(corners[i][0], corners[i][1]);
      c.closePath(); c.fill(); c.stroke();
    }
  }

  c.fillStyle = 'rgba(255,255,255,0.4)';
  c.font = '10px sans-serif';
  const modeRu = { view: 'обзор', paint: 'кисть', erase: 'ластик', pick: 'пипетка' };
  c.fillText('кубов: ' + root.elements.length + ' · ' + (modeRu[this.mode] || this.mode) +
    (this.mode === 'view' ? ' · тяните мышью' : ' · ЛКМ поставить / ПКМ стереть · колесо-слоёв нет, слой внизу'), 10, 16);
};

/* ---------- выбор ячейки под курсором ---------- */
VoxelPreview.prototype.pointInQuad = function (pts, x, y) {
  function sign(ax, ay, bx, by, cx, cy) { return (ax - cx) * (by - cy) - (bx - cx) * (ay - cy); }
  const inTri = function (a, b, cc) {
    const d1 = sign(x, y, a[0], a[1], b[0], b[1]);
    const d2 = sign(x, y, b[0], b[1], cc[0], cc[1]);
    const d3 = sign(x, y, cc[0], cc[1], a[0], a[1]);
    const hasNeg = (d1 < 0) || (d2 < 0) || (d3 < 0);
    const hasPos = (d1 > 0) || (d2 > 0) || (d3 > 0);
    return !(hasNeg && hasPos);
  };
  return inTri(pts[0], pts[1], pts[2]) || inTri(pts[0], pts[2], pts[3]);
};

VoxelPreview.prototype.computeHover = function () {
  if (!this.mouse || this.mode === 'view') return null;
  const mx = this.mouse.x, my = this.mouse.y;
  // 1) попадание в грань существующего куба (ближайшая к камере)
  for (const q of this.pickList) {
    if (this.pointInQuad(q.pts, mx, my)) return { kind: 'face', ci: q.ci, fn: q.fn };
  }
  // 2) попадание в плоскость активного слоя (ортографический обратный луч)
  if (this.gridOn) {
    const fr = this.frame();
    const yaw = this.yaw, pitch = this.pitch;
    const cyaw = Math.cos(yaw), syaw = Math.sin(yaw);
    const cpit = Math.cos(pitch), spit = Math.sin(pitch);
    if (Math.abs(spit) > 0.08) {
      const W = this.cv.width, H = this.cv.height;
      const x1 = (mx - W / 2) / fr.S;
      const y2 = -(my - H / 2) / fr.S;
      const yPlane = GRID_ORIGIN + (this.layer + 1) * CELL;
      const d = (yPlane - fr.cy - y2 * cpit) / spit;
      const y = y2 * cpit + d * spit;
      const z1 = -y2 * spit + d * cpit;
      const x = x1 * cyaw - z1 * syaw + fr.cx;
      const z = x1 * syaw + z1 * cyaw + fr.cz;
      const ix = cellIndex(x), iz = cellIndex(z);
      if (ix >= 0 && ix < GRID_N && iz >= 0 && iz < GRID_N) {
        return { kind: 'grid', c: [ix, this.layer, iz] };
      }
    }
  }
  return null;
};

VoxelPreview.prototype.hoverCell = function () {
  const h = this.hover;
  if (!h) return null;
  if (h.kind === 'grid') return h.c;
  const e = this.root.elements[h.ci];
  if (!e) return null;
  const cx = cellIndex((e.from[0] + e.to[0]) / 2);
  const cy = cellIndex((e.from[1] + e.to[1]) / 2);
  const cz = cellIndex((e.from[2] + e.to[2]) / 2);
  if (this.mode === 'erase') return [cx, cy, cz];
  return [cx + h.fn[0], cy + h.fn[1], cz + h.fn[2]];
};

/* ---------- операции пейнта ---------- */
VoxelPreview.prototype.pushUndo = function () {
  if (!this.root) return;
  if (!XSV.voxUndo) XSV.voxUndo = [];
  XSV.voxUndo.push(JSON.stringify(this.root.elements));
  if (XSV.voxUndo.length > 40) XSV.voxUndo.shift();
  XSV.voxRedo = [];
};

VoxelPreview.prototype.addCell = function (cell, color, alpha) {
  if (!cell) return false;
  const ix = cell[0], iy = cell[1], iz = cell[2];
  if (ix < 0 || ix >= GRID_N || iy < 0 || iy >= GRID_N || iz < 0 || iz >= GRID_N) return false;
  const x0 = cellCoord(ix), y0 = cellCoord(iy), z0 = cellCoord(iz);
  const eps = 1e-4;
  for (const e of this.root.elements) {
    if (Math.abs(e.from[0] - x0) < eps && Math.abs(e.from[1] - y0) < eps && Math.abs(e.from[2] - z0) < eps &&
        Math.abs(e.to[0] - (x0 + CELL)) < eps) {
      e.color = color; if (alpha < 0.999) e.alpha = Math.round(alpha * 100) / 100; else delete e.alpha;
      return true;
    }
  }
  const cube = { from: [x0, y0, z0], to: [x0 + CELL, y0 + CELL, z0 + CELL], color: color };
  if (alpha < 0.999) cube.alpha = Math.round(alpha * 100) / 100;
  this.root.elements.push(cube);
  return true;
};

VoxelPreview.prototype.applyBrush = function (ev) {
  if (!this.root || !this.hover) return;
  if (this.mode === 'pick') {
    if (this.hover.kind === 'face') {
      const e = this.root.elements[this.hover.ci];
      if (e && e.color) { this.brush = e.color; if (this.onPickColor) this.onPickColor(e.color); }
    }
    return;
  }
  if (this.mode !== 'paint') return;
  this.pushUndo();
  const cell = this.hoverCell();
  this.addCell(cell, this.brush, this.brushAlpha);
  if (this.symX && cell) this.addCell([GRID_N - 1 - cell[0], cell[1], cell[2]], this.brush, this.brushAlpha);
  if (this.symZ && cell) this.addCell([cell[0], cell[1], GRID_N - 1 - cell[2]], this.brush, this.brushAlpha);
  if (this.symX && this.symZ && cell) this.addCell([GRID_N - 1 - cell[0], cell[1], GRID_N - 1 - cell[2]], this.brush, this.brushAlpha);
  if (this.onChange) this.onChange(this.root);
};

VoxelPreview.prototype.applyErase = function (ev) {
  if (!this.root || !this.hover || this.hover.kind !== 'face') return;
  this.pushUndo();
  this.root.elements.splice(this.hover.ci, 1);
  if (this.onChange) this.onChange(this.root);
};

VoxelPreview.prototype.undo = function () {
  if (!this.root || !XSV.voxUndo || !XSV.voxUndo.length) return;
  if (!XSV.voxRedo) XSV.voxRedo = [];
  XSV.voxRedo.push(JSON.stringify(this.root.elements));
  this.root.elements = JSON.parse(XSV.voxUndo.pop());
  if (this.onChange) this.onChange(this.root);
};

VoxelPreview.prototype.redo = function () {
  if (!this.root || !XSV.voxRedo || !XSV.voxRedo.length) return;
  XSV.voxUndo.push(JSON.stringify(this.root.elements));
  this.root.elements = JSON.parse(XSV.voxRedo.pop());
  if (this.onChange) this.onChange(this.root);
};

VoxelPreview.prototype.voxelize = function () {
  // привести все кубы к сетке 1/16 (чтобы пейнт «слипался» с примитивами)
  if (!this.root) return;
  this.pushUndo();
  const out = [];
  const seen = {};
  for (const e of this.root.elements) {
    if (!e || !e.from || !e.to) continue;
    const i0 = Math.max(0, cellIndex(e.from[0] + 1e-6)), i1 = Math.min(GRID_N - 1, cellIndex(e.to[0] - 1e-6));
    const j0 = Math.max(0, cellIndex(e.from[1] + 1e-6)), j1 = Math.min(GRID_N - 1, cellIndex(e.to[1] - 1e-6));
    const k0 = Math.max(0, cellIndex(e.from[2] + 1e-6)), k1 = Math.min(GRID_N - 1, cellIndex(e.to[2] - 1e-6));
    for (let i = i0; i <= i1; i++) for (let j = j0; j <= j1; j++) for (let k = k0; k <= k1; k++) {
      const key = i + ',' + j + ',' + k;
      if (seen[key]) continue;
      seen[key] = true;
      const x0 = cellCoord(i), y0 = cellCoord(j), z0 = cellCoord(k);
      const cube = { from: [x0, y0, z0], to: [x0 + CELL, y0 + CELL, z0 + CELL], color: e.color || '#FFFFFF' };
      if (e.alpha !== undefined && e.alpha < 0.999) cube.alpha = e.alpha;
      out.push(cube);
    }
  }
  this.root.elements = out;
  if (this.onChange) this.onChange(this.root);
};

/* ---------- генераторы геометрии (те же алгоритмы, что в мастер-скрипте) ---------- */
const VoxGen = {
  num: function (v) { const r = Math.round(v * 10000) / 10000; return r; },
  cube: function (x1, y1, z1, x2, y2, z2, color, alpha, rot) {
    const c = { from: [this.num(x1), this.num(y1), this.num(z1)], to: [this.num(x2), this.num(y2), this.num(z2)], color: color };
    if (alpha !== undefined && alpha < 0.999) c.alpha = Math.round(alpha * 100) / 100;
    if (rot) c.rotation = rot;
    return c;
  },
  sphere: function (r, n, core, mid, shell, shellA) {
    const els = [];
    const cell = 2 * r / n;
    const mn = 0.5 - r;
    for (let ix = 0; ix < n; ix++) for (let iy = 0; iy < n; iy++) for (let iz = 0; iz < n; iz++) {
      const px = mn + (ix + 0.5) * cell, py = mn + (iy + 0.5) * cell, pz = mn + (iz + 0.5) * cell;
      const d = Math.sqrt((px - 0.5) * (px - 0.5) + (py - 0.5) * (py - 0.5) + (pz - 0.5) * (pz - 0.5));
      if (d > r) continue;
      const f = d / r;
      const col = f <= 0.4 ? core : (f <= 0.72 ? mid : shell);
      const a = f <= 0.4 ? 1 : (f <= 0.72 ? 0.95 : shellA);
      els.push(this.cube(mn + ix * cell, mn + iy * cell, mn + iz * cell,
        mn + (ix + 1) * cell, mn + (iy + 1) * cell, mn + (iz + 1) * cell, col, a));
    }
    return els;
  },
  star: function (blades, radius, thick, color, hubColor) {
    const els = [];
    for (let k = 0; k < Math.max(1, Math.round(blades / 2)); k++) {
      const ang = 180 / blades * 2 * k + 90 / blades;
      els.push(this.cube(0.5 - radius, 0.5 - thick / 2, 0.5 - thick, 0.5 + radius, 0.5 + thick / 2, 0.5 + thick,
        color, 1, { axis: 'y', angle: this.num(ang), origin: [0.5, 0.5, 0.5] }));
    }
    els.push(this.cube(0.5 - thick * 1.4, 0.5 - thick * 1.1, 0.5 - thick * 1.4, 0.5 + thick * 1.4, 0.5 + thick * 1.1, 0.5 + thick * 1.4, hubColor || '#8A919E'));
    return els;
  },
  torus: function (R, tube, seg, colA, colB) {
    const els = [];
    for (let i = 0; i < seg; i++) {
      const a = 2 * Math.PI * i / seg;
      const x = 0.5 + R * Math.cos(a), z = 0.5 + R * Math.sin(a);
      els.push(this.cube(x - tube, 0.5 - tube, z - tube, x + tube, 0.5 + tube, z + tube, i % 2 ? colB : colA, 0.92));
    }
    return els;
  },
  blade: function (len, wid, bladeCol, handleCol, pommelCol) {
    const els = [];
    els.push(this.cube(0.5 - wid / 2, 0.5 - wid / 2, 0.5 - len / 2, 0.5 + wid / 2, 0.5 + wid / 2, 0.5 + len * 0.18, bladeCol));
    els.push(this.cube(0.5 - wid * 0.4, 0.5 - wid * 0.4, 0.5 + len * 0.18, 0.5 + wid * 0.4, 0.5 + wid * 0.4, 0.5 + len * 0.42, handleCol));
    els.push(this.cube(0.5 - wid * 0.6, 0.5 - wid * 0.6, 0.5 + len * 0.42, 0.5 + wid * 0.6, 0.5 + wid * 0.6, 0.5 + len * 0.48, pommelCol));
    return els;
  },
  disc: function (ringR, tube, seg, blades, coreR, colRingA, colRingB, colBlade, colCore) {
    let els = this.torus(ringR, tube, seg, colRingA, colRingB);
    for (let k = 0; k < blades; k++) {
      const ang = 90 / blades + (180 / blades) * 2 * k;
      els.push(this.cube(0.5 - tube * 0.5, 0.5 - tube * 0.18, 0.5 - ringR * 0.92, 0.5 + tube * 0.5, 0.5 + tube * 0.18, 0.5 + ringR * 0.92,
        colBlade, 0.85, { axis: 'y', angle: this.num(ang), origin: [0.5, 0.5, 0.5] }));
    }
    els = els.concat(this.sphere(coreR, 5, '#FFFFFF', colCore, colCore, 0.6));
    return els;
  },
  /* --- новые примитивы ToolsPack 2 --- */
  cone: function (r, h, n, color, tipColor) {
    const els = [];
    const levels = Math.max(3, Math.round(h / (2 * r / n)));
    const cell = 2 * r / n;
    for (let l = 0; l < levels; l++) {
      const f = 1 - l / levels;                 // 1 у основания -> ~0 к вершине
      const rr = r * f;
      const y0 = 0.5 - h / 2 + l * (h / levels);
      const y1 = y0 + h / levels;
      const steps = Math.max(3, Math.round(n * f));
      for (let s = 0; s < steps; s++) {
        const a = 2 * Math.PI * s / steps + (l % 2 ? Math.PI / steps : 0);
        for (let q = 0; q < (f > 0.55 ? 2 : 1); q++) {
          const rad = rr * (q === 0 ? 1 : 0.5);
          const x = 0.5 + Math.cos(a) * rad, z = 0.5 + Math.sin(a) * rad;
          const cc = cell * 0.62;
          els.push(this.cube(x - cc, y0, z - cc, x + cc, y1, z + cc, (l >= levels - 2 && tipColor) ? tipColor : color, 1));
        }
      }
    }
    return els;
  },
  cylinder: function (r, h, n, color, color2, hollow) {
    const els = [];
    const levels = Math.max(2, Math.round(h / (2 * r / n)));
    const cell = 2 * r / n;
    for (let l = 0; l < levels; l++) {
      const y0 = 0.5 - h / 2 + l * (h / levels);
      const y1 = y0 + h / levels;
      const steps = Math.max(6, n * 2);
      const rings = hollow ? 1 : 2;
      for (let q = 0; q < rings; q++) {
        const rad = r * (q === 0 ? 1 : 0.55);
        for (let s = 0; s < steps; s++) {
          const a = 2 * Math.PI * s / steps;
          const x = 0.5 + Math.cos(a) * rad, z = 0.5 + Math.sin(a) * rad;
          const cc = cell * 0.6;
          els.push(this.cube(x - cc, y0, z - cc, x + cc, y1, z + cc, (l + s) % 2 ? color : (color2 || color), 1));
        }
      }
    }
    return els;
  },
  helix: function (r, h, turns, tube, color, color2) {
    const els = [];
    const steps = Math.max(12, Math.round(turns * 14));
    for (let i = 0; i < steps; i++) {
      const t2 = i / steps;
      const a = t2 * turns * Math.PI * 2;
      const x = 0.5 + Math.cos(a) * r, z = 0.5 + Math.sin(a) * r;
      const y = 0.5 - h / 2 + t2 * h;
      els.push(this.cube(x - tube, y - tube, z - tube, x + tube, y + tube, z + tube, i % 2 ? color : (color2 || color), 1));
      const a2 = a + Math.PI;
      const x2 = 0.5 + Math.cos(a2) * r, z2 = 0.5 + Math.sin(a2) * r;
      els.push(this.cube(x2 - tube, y - tube, z2 - tube, x2 + tube, y + tube, z2 + tube, i % 2 ? (color2 || color) : color, 1));
    }
    return els;
  },
  pyramid: function (base, h, color, color2) {
    const els = [];
    const levels = Math.max(3, Math.round(h / CELL / 2));
    for (let l = 0; l < levels; l++) {
      const f = 1 - l / levels;
      const half = base * f / 2;
      const y0 = 0.5 - h / 2 + l * (h / levels);
      const y1 = y0 + h / levels;
      els.push(this.cube(0.5 - half, y0, 0.5 - half, 0.5 + half, y1, 0.5 + half, l % 2 ? color : (color2 || color), 0.95));
    }
    return els;
  },
  diamond: function (r, h, core, shell) {
    // два конуса высотой h/2: верхний стоит основанием на 0.5, нижний — зеркальный
    const coneH = h / 2;
    const dy = coneH / 2;
    const top = this.cone(r, coneH, 8, shell, core);
    const out = [];
    for (const c of top) {
      const up = JSON.parse(JSON.stringify(c));
      up.from[1] = this.num(c.from[1] + dy);
      up.to[1] = this.num(c.to[1] + dy);
      out.push(up);
      const dn = JSON.parse(JSON.stringify(c));
      dn.from[1] = this.num(1 - (c.to[1] + dy));
      dn.to[1] = this.num(1 - (c.from[1] + dy));
      out.push(dn);
    }
    return out;
  },
  cross: function (len, thick, color) {
    const els = [];
    els.push(this.cube(0.5 - len / 2, 0.5 - thick / 2, 0.5 - thick / 2, 0.5 + len / 2, 0.5 + thick / 2, 0.5 + thick / 2, color));
    els.push(this.cube(0.5 - thick / 2, 0.5 - len / 2, 0.5 - thick / 2, 0.5 + thick / 2, 0.5 + len / 2, 0.5 + thick / 2, color));
    els.push(this.cube(0.5 - thick / 2, 0.5 - thick / 2, 0.5 - len / 2, 0.5 + thick / 2, 0.5 + thick / 2, 0.5 + len / 2, color));
    return els;
  },
  box: function (w, h, d, color, hollow) {
    const els = [];
    const x0 = 0.5 - w / 2, x1 = 0.5 + w / 2;
    const y0 = 0.5 - h / 2, y1 = 0.5 + h / 2;
    const z0 = 0.5 - d / 2, z1 = 0.5 + d / 2;
    if (!hollow) { els.push(this.cube(x0, y0, z0, x1, y1, z1, color)); return els; }
    const t = Math.min(w, h, d) * 0.18;
    els.push(this.cube(x0, y0, z0, x1, y0 + t, z1, color));
    els.push(this.cube(x0, y1 - t, z0, x1, y1, z1, color));
    els.push(this.cube(x0, y0, z0, x0 + t, y1, z1, color));
    els.push(this.cube(x1 - t, y0, z0, x1, y1, z1, color));
    els.push(this.cube(x0, y0, z0, x1, y1, z0 + t, color));
    els.push(this.cube(x0, y0, z1 - t, x1, y1, z1, color));
    return els;
  },
  /* --- композиция: перенос/поворот/круговой массив --- */
  transform: function (els, dx, dy, dz, angleDeg) {
    return els.map(function (e) {
      const c = JSON.parse(JSON.stringify(e));
      c.from = [c.from[0] + dx, c.from[1] + dy, c.from[2] + dz];
      c.to = [c.to[0] + dx, c.to[1] + dy, c.to[2] + dz];
      if (angleDeg) {
        if (c.rotation && c.rotation.axis === 'y') c.rotation.angle = VoxGen.num(c.rotation.angle + angleDeg);
        else c.rotation = { axis: 'y', angle: VoxGen.num(angleDeg), origin: [0.5, 0.5, 0.5] };
      }
      return c;
    });
  },
  arrayAroundY: function (els, n) {
    let out = [];
    const cnt = Math.max(1, n);
    for (let k = 0; k < cnt; k++) {
      out = out.concat(this.transform(els, 0, 0, 0, 360 * k / cnt));
    }
    return out;
  }
};

/* импорт Blockbench .bbmodel: только кубы, единицы 1/16 -> блоки */
function importBBModel(json, fallbackColor) {
  const els = [];
  let skipped = 0;
  const arr = (json && Array.isArray(json.elements)) ? json.elements : [];
  for (const e of arr) {
    if (!e || !e.from || !e.to) { skipped++; continue; }
    if (e.type && e.type !== 'cube') { skipped++; continue; }
    const c = {
      from: e.from.map(function (v) { return Math.round(v / 16 * 10000) / 10000; }),
      to: e.to.map(function (v) { return Math.round(v / 16 * 10000) / 10000; }),
      color: (typeof e.color === 'string' && /^#[0-9a-fA-F]{6}$/.test(e.color)) ? e.color : fallbackColor
    };
    if (e.rotation && e.rotation.axis && e.rotation.angle) {
      c.rotation = {
        axis: e.rotation.axis, angle: e.rotation.angle,
        origin: (e.rotation.origin || [8, 8, 8]).map(function (v) { return Math.round(v / 16 * 10000) / 10000; })
      };
    }
    els.push(c);
  }
  return { els: els, skipped: skipped };
}

function defaultModelRoot(presetName) {
  const root = { elements: [], particle: 'end_rod', particleColor: '#5FA8FF', particleRate: 2, particleRadius: 0.5,
                 anim: { spin: [0, 120, 0], pulse: 0.06, pulseSpeed: 6, bob: 0, bobSpeed: 2 } };
  if (presetName === 'sphere') {
    root.elements = VoxGen.sphere(0.42, 7, '#EAF6FF', '#5FA8FF', '#2E5FD9', 0.5);
  } else if (presetName === 'star') {
    root.elements = VoxGen.star(4, 0.34, 0.05, '#C8CDD6', '#8A919E');
    root.anim.spin = [0, 0, 1080]; root.particle = 'none';
  } else if (presetName === 'disc') {
    root.elements = VoxGen.disc(0.72, 0.09, 20, 4, 0.22, '#DFFBFF', '#8FE8FF', '#BFF4FF', '#7FD4FF');
    root.anim.spin = [0, 720, 0]; root.particle = 'cloud'; root.particleColor = '#BFFFFF'; root.particleRadius = 0.8;
  } else if (presetName === 'blade') {
    root.elements = VoxGen.blade(0.86, 0.07, '#B9C2CC', '#5C4A33', '#3E3223');
    root.anim.spin = [0, 0, 0]; root.particle = 'none';
  } else if (presetName === 'ring') {
    root.elements = VoxGen.torus(0.55, 0.08, 18, '#FFF6C8', '#FFD75E');
    root.anim.spin = [0, 240, 0];
  }
  return root;
}

function voxByName(name) {
  for (let i = 0; i < XSV.models.length; i++) if (XSV.models[i].name.replace(/\.json$/, '') === name) return i;
  return -1;
}

/* ---------- UI раздела «Воксели» ---------- */
function renderVoxels(v) {
  if (XSV.voxPreview) { XSV.voxPreview.stop(); XSV.voxPreview = null; }

  const refs = {};
  for (const j of D.jutsu) {
    const d = j.data || {};
    const add = function (m) { if (m) { if (!refs[m]) refs[m] = []; refs[m].push(d.name || j.name); } };
    add((d.visual || {}).voxelModel);
    add((((d.form || {}).params) || {}).voxelModel);
  }
  const refNames = Object.keys(refs).sort();
  const modelNames = XSV.models.map(function (m) { return m.name.replace(/\.json$/, ''); });
  const missing = refNames.filter(function (r) { return modelNames.indexOf(r) < 0; });

  let listHtml = '';
  for (let i = 0; i < XSV.models.length; i++) {
    const nm = XSV.models[i].name.replace(/\.json$/, '');
    const n = (XSV.models[i].data && XSV.models[i].data.elements) ? XSV.models[i].data.elements.length : '?';
    listHtml += '<div class="item' + (XSV.curModel === i ? ' on' : '') + '" data-i="' + i + '">' +
      '<span class="dot" style="background:#7FD4FF"></span><span class="nm">' + esc(nm) + '</span>' +
      '<span class="pill">' + n + '</span></div>';
  }

  v.innerHTML =
    '<h2 class="title">🧊 Воксельные модели <span class="sub">assets/shinobicore/voxels/*.json — снаряды и ручные конструкты ·ToolsPack 2: ручная отрисовка, 12 примитивов, импорт Blockbench</span></h2>' +
    '<div class="jwrap" style="grid-template-columns:230px minmax(0,1fr) 330px">' +
      '<div class="jlist"><div class="filters">' +
        '<div class="row tight">' +
          '<button class="btn sm" id="vx-new" style="flex:1">＋ Новая модель</button>' +
        '</div></div>' +
        '<div id="vx-items">' + listHtml + '</div>' +
        '<div class="filters" style="border-top:1px solid var(--edge);border-bottom:none">' +
          '<div style="font-size:10px;text-transform:uppercase;color:var(--dim);margin-bottom:5px">ссылки из техник</div>' +
          (refNames.length ? refNames.map(function (r) {
            const ok = modelNames.indexOf(r) >= 0;
            return '<div class="row tight" style="font-size:11px;margin-bottom:2px">' +
              '<span class="' + (ok ? 'tag-ok' : 'tag-bad') + '">' + (ok ? '✔' : '✘') + '</span>' +
              '<span class="mono">' + esc(r) + '</span></div>';
          }).join('') : '<div class="dim" style="font-size:11px">техники не ссылаются на модели</div>') +
          (missing.length ? '<button class="btn sm danger" id="vx-fix-missing" style="margin-top:6px;width:100%">Создать ' + missing.length + ' недостающих</button>' : '') +
        '</div>' +
      '</div>' +
      '<div>' +
        '<div class="card"><h3>3D-редактор <span class="hint" id="vx-title"></span></h3>' +
          '<div class="viz" style="padding:0;overflow:hidden"><canvas id="vx-canvas" width="520" height="400" style="display:block;width:100%;cursor:crosshair"></canvas></div>' +
          '<div class="row tight" style="margin-top:8px" id="vx-modes"></div>' +
          '<div class="grid g4" style="margin-top:8px" id="vx-painter"></div>' +
        '</div>' +
        '<div class="card"><h3>Свойства модели</h3><div class="grid g3" id="vx-props"></div>' +
          '<div class="row tight" style="margin-top:10px" id="vx-actions"></div>' +
        '</div>' +
      '</div>' +
      '<div class="jside">' +
        '<div class="card"><h3>Генератор геометрии <span class="hint">12 примитивов</span></h3>' +
          '<label class="f"><span>примитив</span><select id="vx-preset">' +
            ['sphere|сфера', 'star|звезда/сюрикен', 'disc|диск с лопастями', 'blade|клинок/кунай', 'ring|кольцо/тор',
             'cone|конус', 'cylinder|цилиндр', 'helix|спираль ДНК', 'pyramid|пирамида', 'diamond|ромб/кристалл',
             'cross|крестовина', 'box|коробка/сундук'].map(function (o) {
              const p = o.split('|');
              return '<option value="' + p[0] + '">' + p[1] + '</option>';
            }).join('') + '</select></label>' +
          '<div class="grid g2" id="vx-gen-form" style="margin-top:8px"></div>' +
          '<div style="margin-top:8px;font-size:10px;text-transform:uppercase;color:var(--dim)">режим вставки</div>' +
          '<div class="row tight" id="vx-compose" style="margin-top:4px">' +
            '<label class="pill" style="cursor:pointer"><input type="radio" name="vx-cmode" value="replace" checked> заменить</label>' +
            '<label class="pill" style="cursor:pointer"><input type="radio" name="vx-cmode" value="add"> добавить</label>' +
            '<label class="pill" style="cursor:pointer"><input type="radio" name="vx-cmode" value="array"> массив ×N</label>' +
          '</div>' +
          '<div class="grid g3" style="margin-top:6px" id="vx-compose-params"></div>' +
          '<div class="row tight" style="margin-top:10px"><button class="btn sm pri" id="vx-gen">⚙ Сгенерировать</button></div>' +
          '<div class="vizcap">«массив ×N» copies N повёрнутых копий вокруг оси Y — лопасти, шипы, кольца.</div>' +
        '</div>' +
        '<div class="card"><h3>Импорт Blockbench (.bbmodel)</h3>' +
          '<input type="file" id="vx-bb-file" accept=".bbmodel,.json" style="width:100%;font-size:11px">' +
          '<div class="row tight" style="margin-top:6px;align-items:flex-end">' +
            '<label class="f"><span>цвет кубов</span><input type="color" id="vx-bb-color" value="#B9C2CC"></label>' +
            '<button class="btn sm" id="vx-bb-import">⬇ Импорт (добавить)</button>' +
          '</div>' +
          '<div class="vizcap">Кубы из Blockbench конвертируются в нативный формат (1/16 → блоки), меши пропускаются. Текстуры не переносятся — задайте цвет.</div>' +
        '</div>' +
        '<div class="card"><h3>JSON <span class="hint">прямая правка</span></h3>' +
          '<textarea id="vx-json" class="mono" style="width:100%;height:180px" spellcheck="false"></textarea>' +
          '<div class="row tight" style="margin-top:8px"><button class="btn sm" id="vx-json-apply">Применить JSON</button></div>' +
        '</div>' +
      '</div>' +
    '</div>';

  $$('#vx-items .item').forEach(function (it) {
    it.onclick = function () { XSV.curModel = Number(it.getAttribute('data-i')); XSV.voxUndo = []; XSV.voxRedo = []; renderSection(); };
  });

  $('#vx-new').onclick = function () {
    const nm = prompt('Имя новой модели (латиница, без пробелов):', 'my_model');
    if (!nm) return;
    const clean = nm.trim().toLowerCase().replace(/[^a-z0-9_]/g, '_');
    if (!clean) { toast('Пустое имя', 'err'); return; }
    if (voxByName(clean) >= 0) { toast('Модель «' + clean + '» уже есть', 'err'); return; }
    const root = defaultModelRoot('sphere');
    XSV.models.push({ path: VOX_DIR + '/' + clean + '.json', name: clean + '.json', text: '', data: root, isNew: true });
    XSV.curModel = XSV.models.length - 1;
    XSV.voxUndo = []; XSV.voxRedo = [];
    renderSection();
    toast('Модель создана в памяти — настройте и нажмите «Сохранить»');
  };

  const fixBtn = $('#vx-fix-missing');
  if (fixBtn) fixBtn.onclick = async function () {
    for (const nm of missing) {
      const root = defaultModelRoot('sphere');
      root.particleColor = '#5FA8FF';
      try {
        await api('/api/save', { method: 'POST', headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ path: VOX_DIR + '/' + nm + '.json', content: JSON.stringify(root, null, 2) + '\n' }) });
      } catch (e) { toast('Не удалось создать ' + nm + ': ' + e.message, 'err'); }
    }
    await refreshExtData();
    renderNav(); renderSection();
    toast('Создано моделей: ' + missing.length + '. В игре выполните /reload', 'ok');
  };

  const m = (XSV.curModel >= 0) ? XSV.models[XSV.curModel] : null;
  const canvas = $('#vx-canvas');
  const prev = new VoxelPreview(canvas);
  XSV.voxPreview = prev;
  if (m && m.data) prev.set(m.data);
  prev.start();

  $('#vx-title').textContent = m ? m.name : 'модель не выбрана';

  /* --- тулбар режимов --- */
  const MODES = [
    { id: 'view',  label: '👁 Обзор' },
    { id: 'paint', label: '🖌 Кисть' },
    { id: 'erase', label: '⌫ Ластик' },
    { id: 'pick',  label: '💉 Пипетка' }
  ];
  const modesBox = $('#vx-modes');
  for (const md of MODES) {
    const b = h('<button class="btn sm' + (prev.mode === md.id ? ' pri' : '') + '">' + md.label + '</button>');
    b.onclick = function () {
      prev.mode = md.id;
      prev.auto = (md.id === 'view');
      renderSection();
    };
    modesBox.appendChild(b);
  }
  const undoB = h('<button class="btn sm" id="vx-undo" title="Ctrl+Z">↺ Отменить</button>');
  const redoB = h('<button class="btn sm" id="vx-redo" title="Ctrl+Y">↻ Вернуть</button>');
  const voxelizeB = h('<button class="btn sm" id="vx-voxelize" title="Привести все кубы к сетке 1/16 — чтобы кисть «слипалась» с примитивами">⌗ Вокселизировать</button>');
  modesBox.appendChild(undoB); modesBox.appendChild(redoB); modesBox.appendChild(voxelizeB);
  undoB.onclick = function () { prev.undo(); };
  redoB.onclick = function () { prev.redo(); };
  voxelizeB.onclick = function () {
    if (!m) return;
    if (!confirm('Разбить все кубы модели на ячейки 1/16? Файл станет больше, зато ручная отрисовка будет ровно стыковаться.')) return;
    prev.voxelize();
    syncJsonBox();
    toast('Вокселизировано: ' + (m.data.elements || []).length + ' кубов');
  };

  if (!XSV.voxKeysBound) {
    XSV.voxKeysBound = true;
    document.addEventListener('keydown', function (e) {
      if (section !== 'voxels' || !XSV.voxPreview) return;
      const tag = (document.activeElement && document.activeElement.tagName) || '';
      if (tag === 'INPUT' || tag === 'TEXTAREA' || tag === 'SELECT') return;
      if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'z' && !e.shiftKey) { e.preventDefault(); XSV.voxPreview.undo(); }
      if ((e.ctrlKey || e.metaKey) && (e.key.toLowerCase() === 'y' || (e.shiftKey && e.key.toLowerCase() === 'z'))) { e.preventDefault(); XSV.voxPreview.redo(); }
    });
  }

  /* --- панель кисти --- */
  $('#vx-painter').innerHTML =
    '<label class="f"><span>цвет кисти</span><input type="color" id="vp-brush" value="' + esc(prev.brush) + '"></label>' +
    '<label class="f"><span>прозрачность</span><input type="number" id="vp-balpha" min="0.1" max="1" step="0.05" value="' + esc(prev.brushAlpha) + '"></label>' +
    '<label class="f"><span>слой Y: <b id="vp-layer-n">' + prev.layer + '</b></span><input type="range" id="vp-layer" min="0" max="31" step="1" value="' + prev.layer + '"></label>' +
    '<label class="f"><span>симметрия</span><span class="row tight">' +
      '<label class="pill" style="cursor:pointer"><input type="checkbox" id="vp-symx"' + (prev.symX ? ' checked' : '') + '> X</label>' +
      '<label class="pill" style="cursor:pointer"><input type="checkbox" id="vp-symz"' + (prev.symZ ? ' checked' : '') + '> Z</label></span></label>';
  $('#vp-brush').oninput = function () { prev.brush = this.value; };
  $('#vp-balpha').onchange = function () { prev.brushAlpha = Math.max(0.1, Math.min(1, Number(this.value) || 1)); };
  $('#vp-layer').oninput = function () { prev.layer = Number(this.value); $('#vp-layer-n').textContent = this.value; };
  $('#vp-symx').onchange = function () { prev.symX = this.checked; };
  $('#vp-symz').onchange = function () { prev.symZ = this.checked; };
  prev.onPickColor = function (col) {
    prev.brush = col;
    const b = $('#vp-brush'); if (b) b.value = col;
    toast('Цвет подобран: ' + col);
  };

  const root = (m && m.data) ? m.data : null;
  const syncJsonBox = function () {
    const ta = $('#vx-json');
    if (ta && root) ta.value = JSON.stringify(root, null, 2);
    if (m && m.data) {
      const cnt = document.querySelector('#vx-items .item.on .pill');
      if (cnt) cnt.textContent = (m.data.elements || []).length;
    }
  };
  prev.onChange = function () { syncJsonBox(); };

  /* --- свойства модели --- */
  const anim = (root && root.anim) ? root.anim : {};
  const spin = anim.spin || [0, 0, 0];
  $('#vx-props').innerHTML = root ?
      '<label class="f"><span>particle (аура)</span><select id="vp-particle">' +
        ['none', 'flame', 'smoke', 'spark', 'soul_fire', 'enchant', 'cloud', 'splash', 'crit', 'end_rod'].map(function (p) {
          return '<option' + (root.particle === p ? ' selected' : '') + '>' + p + '</option>'; }).join('') + '</select></label>' +
      '<label class="f"><span>particleColor</span><input type="color" id="vp-pcolor" value="' + esc(/^#[0-9a-fA-F]{6}$/.test(root.particleColor || '') ? root.particleColor : '#5FA8FF') + '"></label>' +
      '<label class="f"><span>particleRate</span><input type="number" id="vp-prate" min="0" max="8" step="1" value="' + esc(root.particleRate || 0) + '"></label>' +
      '<label class="f"><span>particleRadius</span><input type="number" id="vp-prad" min="0.1" max="3" step="0.05" value="' + esc(root.particleRadius || 0.5) + '"></label>' +
      '<label class="f"><span>spin X (°/с)</span><input type="number" id="vp-sx" step="10" value="' + esc(spin[0] || 0) + '"></label>' +
      '<label class="f"><span>spin Y (°/с)</span><input type="number" id="vp-sy" step="10" value="' + esc(spin[1] || 0) + '"></label>' +
      '<label class="f"><span>spin Z (°/с)</span><input type="number" id="vp-sz" step="10" value="' + esc(spin[2] || 0) + '"></label>' +
      '<label class="f"><span>pulse</span><input type="number" id="vp-pulse" min="0" max="0.5" step="0.01" value="' + esc(anim.pulse || 0) + '"></label>' +
      '<label class="f"><span>pulseSpeed</span><input type="number" id="vp-pspeed" min="0" max="30" step="0.5" value="' + esc(anim.pulseSpeed || 3) + '"></label>' +
      '<label class="f"><span>bob</span><input type="number" id="vp-bob" min="0" max="0.5" step="0.01" value="' + esc(anim.bob || 0) + '"></label>' +
      '<label class="f"><span>bobSpeed</span><input type="number" id="vp-bspeed" min="0" max="10" step="0.5" value="' + esc(anim.bobSpeed || 2) + '"></label>' +
      '<label class="f"><span>кубов</span><input readonly id="vp-count" value="' + (root.elements || []).length + '"></label>'
    : '<div class="dim">Выберите модель слева или создайте новую (＋).</div>';

  $('#vx-actions').innerHTML = m ?
      '<button class="btn sm pri" id="vx-save">💾 Сохранить</button>' +
      '<button class="btn sm" id="vx-dup">⧉ Дублировать</button>' +
      '<button class="btn sm" id="vx-to-jutsu">→ В технику (FX Lab)</button>' +
      '<button class="btn sm danger" id="vx-del">✕ Удалить файл</button>' : '';

  if (m && root) {
    const bind = function (sel, fn) { const n = $(sel); if (n) n.onchange = function () { fn(this.value); syncJsonBox(); prev.set(root); }; };
    bind('#vp-particle', function (x) { root.particle = x; });
    bind('#vp-pcolor', function (x) { root.particleColor = x; });
    bind('#vp-prate', function (x) { root.particleRate = Math.max(0, Number(x) || 0); });
    bind('#vp-prad', function (x) { root.particleRadius = Math.max(0.05, Number(x) || 0.5); });
    bind('#vp-sx', function (x) { root.anim = root.anim || {}; root.anim.spin = root.anim.spin || [0, 0, 0]; root.anim.spin[0] = Number(x) || 0; });
    bind('#vp-sy', function (x) { root.anim = root.anim || {}; root.anim.spin = root.anim.spin || [0, 0, 0]; root.anim.spin[1] = Number(x) || 0; });
    bind('#vp-sz', function (x) { root.anim = root.anim || {}; root.anim.spin = root.anim.spin || [0, 0, 0]; root.anim.spin[2] = Number(x) || 0; });
    bind('#vp-pulse', function (x) { root.anim = root.anim || {}; root.anim.pulse = Number(x) || 0; });
    bind('#vp-pspeed', function (x) { root.anim = root.anim || {}; root.anim.pulseSpeed = Number(x) || 3; });
    bind('#vp-bob', function (x) { root.anim = root.anim || {}; root.anim.bob = Number(x) || 0; });
    bind('#vp-bspeed', function (x) { root.anim = root.anim || {}; root.anim.bobSpeed = Number(x) || 2; });
    syncJsonBox();

    $('#vx-save').onclick = async function () {
      const txt = JSON.stringify(root, null, 2) + '\n';
      try { JSON.parse(txt); } catch (e) { toast('JSON модели битый: ' + e.message, 'err'); return; }
      try {
        await api('/api/save', { method: 'POST', headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ path: m.path, content: txt }) });
        m.text = txt; delete m.isNew;
        toast('Сохранено: ' + m.path + '. В игре: /reload', 'ok');
        await refreshExtData();
        XSV.curModel = Math.max(0, voxByName(m.name.replace(/\.json$/, '')));
        renderNav(); renderSection();
      } catch (e) { toast('Ошибка сохранения: ' + e.message, 'err'); }
    };
    $('#vx-dup').onclick = function () {
      const nm = prompt('Имя копии:', m.name.replace(/\.json$/, '') + '_copy');
      if (!nm) return;
      const clean = nm.trim().toLowerCase().replace(/[^a-z0-9_]/g, '_');
      if (!clean || voxByName(clean) >= 0) { toast('Некорректное или занятое имя', 'err'); return; }
      XSV.models.push({ path: VOX_DIR + '/' + clean + '.json', name: clean + '.json', text: '',
        data: JSON.parse(JSON.stringify(root)), isNew: true });
      XSV.curModel = XSV.models.length - 1;
      renderSection();
    };
    $('#vx-to-jutsu').onclick = function () {
      const j = fxCur();
      if (!j) { toast('Сначала выберите технику в FX Lab', 'err'); return; }
      const vis = JSON.parse(JSON.stringify(j.data.visual || {}));
      vis.voxelModel = m.name.replace(/\.json$/, '');
      fxCommitVisual(j, vis);
      toast('voxelModel="' + vis.voxelModel + '" записан в ' + (j.data.name || j.id) + ' — сохраните (Ctrl+S)', 'ok');
    };
    $('#vx-del').onclick = async function () {
      if (!confirm('Удалить файл модели ' + m.name + '?')) return;
      if (m.isNew) { XSV.models.splice(XSV.curModel, 1); XSV.curModel = -1; renderSection(); return; }
      try {
        await api('/api/delete', { method: 'POST', headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ path: m.path }) });
        toast('Удалено: ' + m.path);
        await refreshExtData();
        XSV.curModel = XSV.models.length ? 0 : -1;
        renderNav(); renderSection();
      } catch (e) { toast('Ошибка удаления: ' + e.message, 'err'); }
    };

    $('#vx-json-apply').onclick = function () {
      try {
        const parsed = JSON.parse($('#vx-json').value);
        if (!parsed || !Array.isArray(parsed.elements)) throw new Error('нужен массив "elements"');
        for (const k of Object.keys(root)) delete root[k];
        Object.assign(root, parsed);
        prev.set(root);
        toast('JSON применён — не забудьте «Сохранить»', 'ok');
        renderSection();
      } catch (e) { toast('JSON не парсится: ' + e.message, 'err'); }
    };
  }

  /* --- генератор --- */
  const GEN_PARAMS = {
    sphere:   ['r', 'n', 'core', 'mid', 'shell', 'sa'],
    star:     ['r', 'blades', 'mid', 'core'],
    disc:     ['r', 'n', 'blades', 'mid', 'shell', 'core'],
    blade:    ['r', 'mid', 'core', 'shell'],
    ring:     ['r', 'mid', 'shell', 'n'],
    cone:     ['r', 'h', 'n', 'mid', 'core'],
    cylinder: ['r', 'h', 'n', 'mid', 'shell'],
    helix:    ['r', 'h', 'turns', 'mid', 'shell'],
    pyramid:  ['r', 'h', 'mid', 'shell'],
    diamond:  ['r', 'h', 'core', 'shell'],
    cross:    ['r', 'mid'],
    box:      ['r', 'h', 'mid']
  };
  const PARAM_LABELS = {
    r: 'радиус/размер', n: 'детализация', h: 'высота', blades: 'лопастей', turns: 'витков',
    core: 'цвет ядра', mid: 'цвет тела', shell: 'цвет оболочки', sa: 'прозрачн. оболочки'
  };
  const PARAM_DEFAULTS = {
    r: 0.42, n: 7, h: 0.8, blades: 4, turns: 3,
    core: '#EAF6FF', mid: '#5FA8FF', shell: '#2E5FD9', sa: 0.5
  };
  function renderGenParams() {
    const preset = $('#vx-preset').value;
    const keys = GEN_PARAMS[preset] || ['r', 'n', 'core', 'mid', 'shell', 'sa'];
    $('#vx-gen-form').innerHTML = keys.map(function (k) {
      const d = PARAM_DEFAULTS[k];
      if (typeof d === 'string' && d.charAt(0) === '#') {
        return '<label class="f"><span>' + PARAM_LABELS[k] + '</span><input type="color" id="vg-' + k + '" value="' + d + '"></label>';
      }
      return '<label class="f"><span>' + PARAM_LABELS[k] + '</span><input type="number" id="vg-' + k + '" step="' + (k === 'n' || k === 'blades' || k === 'turns' ? '1' : '0.02') + '" value="' + d + '"></label>';
    }).join('');
    const el = $('#vg-el');
    if (el) el.onchange = null;
  }
  renderGenParams();
  $('#vx-preset').onchange = renderGenParams;

  $('#vx-compose-params').innerHTML =
    '<label class="f"><span>сдвиг X</span><input type="number" id="vg-dx" step="0.05" value="0"></label>' +
    '<label class="f"><span>сдвиг Y</span><input type="number" id="vg-dy" step="0.05" value="0"></label>' +
    '<label class="f"><span>сдвиг Z</span><input type="number" id="vg-dz" step="0.05" value="0"></label>' +
    '<label class="f"><span>поворот °</span><input type="number" id="vg-ang" step="5" value="0"></label>' +
    '<label class="f"><span>N (массив)</span><input type="number" id="vg-arrn" step="1" min="1" max="24" value="4"></label>' +
    '<label class="f"><span>элемент-палитра</span><select id="vg-el"><option value="">—</option>' +
      Object.keys(FX_PAL).map(function (e) { return '<option value="' + e + '">' + esc(EL_RU[e] || e) + '</option>'; }).join('') + '</select></label>';

  $('#vg-el').onchange = function () {
    const p = FX_PAL[this.value];
    if (!p) return;
    const setv = function (id, v) { const n = $(id); if (n) n.value = v; };
    setv('#vg-core', '#FFFFFF'); setv('#vg-mid', p.core);
    setv('#vg-shell', p.glow === '#FFFFFF' ? p.core : p.glow);
  };

  $('#vx-gen').onclick = function () {
    if (!m || !m.data) { toast('Сначала выберите или создайте модель', 'err'); return; }
    const preset = $('#vx-preset').value;
    const gv = function (k) { const n = $('#vg-' + k); return n ? n.value : null; };
    const gn = function (k, dflt) { const v = Number(gv(k)); return (v === null || isNaN(v) || v === 0 && k !== 'r') ? dflt : v; };
    const r = Math.max(0.05, Number(gv('r')) || 0.42);
    const n = Math.max(3, Math.min(15, Number(gv('n')) || 7));
    const hh = Math.max(0.1, Number(gv('h')) || 0.8);
    const blades = Math.max(2, Math.min(12, Number(gv('blades')) || 4));
    const turns = Math.max(1, Math.min(12, Number(gv('turns')) || 3));
    const core = gv('core') || '#EAF6FF', mid = gv('mid') || '#5FA8FF', shell = gv('shell') || '#2E5FD9';
    const sa = Math.max(0.1, Math.min(1, Number(gv('sa')) || 0.5));

    let els;
    if (preset === 'sphere') els = VoxGen.sphere(r, n, core, mid, shell, sa);
    else if (preset === 'star') els = VoxGen.star(blades, r, Math.max(0.02, r * 0.14), mid, core);
    else if (preset === 'disc') els = VoxGen.disc(r, Math.max(0.03, r * 0.14), 20, blades, r * 0.5, mid, shell, mid, core);
    else if (preset === 'blade') els = VoxGen.blade(r * 2, Math.max(0.03, r * 0.16), mid, core, shell);
    else if (preset === 'ring') els = VoxGen.torus(r, Math.max(0.03, r * 0.18), Math.max(8, n * 2 + 4), mid, shell);
    else if (preset === 'cone') els = VoxGen.cone(r, hh, n, mid, core);
    else if (preset === 'cylinder') els = VoxGen.cylinder(r, hh, n, mid, shell, false);
    else if (preset === 'helix') els = VoxGen.helix(r, hh, turns, Math.max(0.02, r * 0.14), mid, shell);
    else if (preset === 'pyramid') els = VoxGen.pyramid(r * 2, hh, mid, shell);
    else if (preset === 'diamond') els = VoxGen.diamond(r, hh, core, shell);
    else if (preset === 'cross') els = VoxGen.cross(r * 2, Math.max(0.03, r * 0.16), mid);
    else els = VoxGen.box(r * 2, hh, r * 2, mid, true);

    const mode = (document.querySelector('input[name="vx-cmode"]:checked') || {}).value || 'replace';
    const dx = Number(($('#vg-dx') || {}).value) || 0;
    const dy = Number(($('#vg-dy') || {}).value) || 0;
    const dz = Number(($('#vg-dz') || {}).value) || 0;
    const ang = Number(($('#vg-ang') || {}).value) || 0;

    prev.pushUndo();
    if (mode === 'replace') {
      m.data.elements = els;
    } else if (mode === 'add') {
      m.data.elements = (m.data.elements || []).concat(VoxGen.transform(els, dx, dy, dz, ang));
    } else {
      const arrN = Math.max(1, Math.min(24, Number(($('#vg-arrn') || {}).value) || 4));
      const shifted = VoxGen.transform(els, dx, dy, dz, ang);
      m.data.elements = (m.data.elements || []).concat(VoxGen.arrayAroundY(shifted, arrN));
    }
    prev.set(m.data);
    syncJsonBox();
    toast('Кубов: ' + (m.data.elements || []).length + ' · режим «' + mode + '» — проверьте превью и сохраните');
  };

  /* --- импорт bbmodel --- */
  let bbJson = null;
  $('#vx-bb-file').onchange = function () {
    const f = this.files && this.files[0];
    if (!f) { bbJson = null; return; }
    const rd = new FileReader();
    rd.onload = function () {
      try { bbJson = JSON.parse(String(rd.result)); toast('Файл прочитан: ' + f.name + ' — нажмите «Импорт»', 'ok'); }
      catch (e) { bbJson = null; toast('Не JSON: ' + e.message, 'err'); }
    };
    rd.readAsText(f);
  };
  $('#vx-bb-import').onclick = function () {
    if (!m || !m.data) { toast('Сначала выберите модель-приёмник', 'err'); return; }
    if (!bbJson) { toast('Сначала выберите .bbmodel файл', 'err'); return; }
    const res = importBBModel(bbJson, $('#vx-bb-color').value || '#B9C2CC');
    if (!res.els.length) { toast('В файле нет кубов (меши не поддерживаются)', 'err'); return; }
    prev.pushUndo();
    m.data.elements = (m.data.elements || []).concat(res.els);
    prev.set(m.data);
    syncJsonBox();
    toast('Импортировано кубов: ' + res.els.length + (res.skipped ? (' · пропущено: ' + res.skipped) : '') + ' — сохраните', 'ok');
  };
}

/* ============================== ГЕНЕРАТОРЫ ================================= */

const GEN_RANK = {
  D: { cost: 6,  dmg: 4,  cd: 2.5, stat: 5,  dist: 1, sp: 2 },
  C: { cost: 18, dmg: 8,  cd: 4,   stat: 15, dist: 2, sp: 4 },
  B: { cost: 28, dmg: 14, cd: 6,   stat: 25, dist: 3, sp: 6 },
  A: { cost: 40, dmg: 22, cd: 8,   stat: 35, dist: 4, sp: 10 },
  S: { cost: 70, dmg: 40, cd: 12,  stat: 45, dist: 5, sp: 15 }
};
const EL_EN = { fire: 'Fire Release', water: 'Water Release', wind: 'Wind Release', earth: 'Earth Release',
  lightning: 'Lightning Release', yin: 'Yin Release', yang: 'Yang Release', none: 'Chakra' };
const GEN_NOUNS = {
  projectile: ['Bullet', 'Barrage', 'Lance', 'Fang', 'Shard'],
  beam: ['Beam', 'Ray', 'Piercer', 'Judgement'],
  zone: ['Zone', 'Field', 'Domain', 'Prison', 'Mist'],
  dash: ['Dash', 'Rush', 'Step', 'Flicker'],
  point: ['Strike', 'Touch', 'Palm', 'Impact'],
  handheld: ['Sphere', 'Orb', 'Disc', 'Saw'],
  summon: ['Summoning', 'Calling', 'Contract'],
  construct: ['Wall', 'Bulwark', 'Pillar', 'Rampart']
};
const GEN_ADJ = ['', 'Great ', 'Greater ', 'Twin ', 'Spiraling ', 'Howling ', 'Silent ', 'Rending ', 'Ancient ', 'Crimson '];
const EL_RU_GEN = { fire: 'огня', water: 'воды', wind: 'ветра', earth: 'земли',
  lightning: 'молнии', yin: 'инь', yang: 'ян', none: 'чакры' };

function slugify(s) {
  return String(s).toLowerCase().replace(/[^a-z0-9]+/g, '_').replace(/^_+|_+$/g, '');
}

function usedJutsuIds() {
  const set = {};
  for (const j of D.jutsu) { const id = (j.data || {}).id; if (id) set[id] = true; }
  return set;
}

function genElementDebuff(el, dmg) {
  if (el === 'fire')      return { type: 'debuff', subtype: 'burn',  params: { dps: Math.max(0.5, Math.round(dmg * 0.15 * 10) / 10), duration: 40 } };
  if (el === 'water')     return { type: 'debuff', subtype: 'slow',  params: { percent: 30, duration: 60 } };
  if (el === 'wind')      return { type: 'control', subtype: 'push', params: { force: 1.2 } };
  if (el === 'earth')     return { type: 'control', subtype: 'root', params: { duration: 30, breakDamage: 6 } };
  if (el === 'lightning') return { type: 'control', subtype: 'stun', params: { duration: 14 } };
  if (el === 'yin')       return { type: 'control', subtype: 'blind', params: { duration: 60 } };
  if (el === 'yang')      return { type: 'debuff', subtype: 'vulnerability', params: { percent: 15, duration: 60 } };
  return { type: 'debuff', subtype: 'weakness', params: { duration: 60 } };
}

function buildGeneratedJutsu(el, form, rank, variant, usedIds) {
  const R = GEN_RANK[rank] || GEN_RANK.C;
  const nouns = GEN_NOUNS[form] || GEN_NOUNS.projectile;
  const noun = nouns[variant % nouns.length];
  const adj = GEN_ADJ[Math.floor(variant / nouns.length) % GEN_ADJ.length];
  const baseName = (el === 'none' ? '' : EL_EN[el] + ': ') + adj + noun;
  let slug = slugify((el === 'none' ? 'chakra_' : el + '_') + (adj + noun));
  let id = 'shinobicore:' + slug;
  let guard = 2;
  while (usedIds[id]) { id = 'shinobicore:' + slug + '_' + guard; guard++; if (guard > 50) break; }
  usedIds[id] = true;

  const dmg = R.dmg;
  const j = {
    id: id,
    name: baseName,
    description: 'Сгенерировано: ' + (EL_RU_GEN[el] || el) + ', форма «' + form + '», ранг ' + rank + '. Отредактируйте описание в Studio.',
    category: el === 'none' ? 'shape_ninjutsu' : 'elemental_ninjutsu',
    rank: rank,
    tags: [el === 'none' ? 'shape' : el, form, 'offensive'],
    element: el
  };
  j.cooldown = R.cd;

  const effects = [];
  const props = [];
  let activation = { type: 'instant', params: {} };
  const bigRank = (rank === 'A' || rank === 'S');

  if (form === 'projectile') {
    const volley = (variant % 2 === 1);
    const speed = el === 'lightning' ? 1.9 : (el === 'earth' ? 1.1 : 1.4);
    const gravity = el === 'earth' ? 0.05 : (el === 'wind' ? 0.0 : 0.02);
    j.form = { type: 'projectile', params: { speed: speed, gravity: gravity, lifetime: 80, size: volley ? 0.3 : 0.5 } };
    if (volley) {
      j.form.params.count = rank === 'S' ? 7 : 5;
      j.form.params.spread = 0.22;
      effects.push({ type: 'damage', subtype: 'instant', params: { amount: Math.max(2, Math.round(dmg * 0.6)) } });
    } else {
      effects.push({ type: 'damage', subtype: 'instant', params: { amount: dmg } });
    }
    effects.push(genElementDebuff(el, dmg));
    if (bigRank) props.push({ id: 'explode_on_hit', params: { radius: rank === 'S' ? 4 : 3, damage: Math.round(dmg * 0.8), knockback: 0.6 } });
    if (rank === 'S') props.push({ id: 'piercing', params: { count: 3 } });
    if (bigRank) activation = { type: 'handseals', params: { sealCount: rank === 'S' ? 4 : 2, sealSpeed: 1 } };
  }
  else if (form === 'beam') {
    j.form = { type: 'beam', params: { maxRange: rank === 'S' ? 24 : 16, width: bigRank ? 1.4 : 1.0, duration: 60, tickRate: 5 } };
    effects.push({ type: 'damage', subtype: 'dot', params: { amount: Math.max(1, Math.round(dmg * 0.3)), duration: 10 } });
    props.push({ id: 'channeled', params: { chakraPerTick: 0.5 } });
    activation = { type: 'hold', params: { chakraPerTick: 0.5 } };
  }
  else if (form === 'zone') {
    j.form = { type: 'zone', params: { radius: 3 + R.dist, duration: rank === 'S' ? 240 : 160, shape: 'cylinder', tickRate: 20 } };
    effects.push({ type: 'damage', subtype: 'dot', params: { amount: Math.max(1, Math.round(dmg * 0.25)), duration: 10 } });
    effects.push(genElementDebuff(el, dmg));
    if (el === 'fire') effects.push({ type: 'world', subtype: 'ignite', params: { area: 3 } });
    if (bigRank) props.push({ id: 'toggle', params: {} });
    if (bigRank) activation = { type: 'handseals', params: { sealCount: 3, sealSpeed: 1 } };
  }
  else if (form === 'dash') {
    j.form = { type: 'dash', params: { distance: 6 + R.dist * 1.5, speed: el === 'lightning' ? 4 : 3, damageOnPath: true } };
    effects.push({ type: 'damage', subtype: 'instant', params: { amount: Math.round(dmg * 0.9) } });
    effects.push({ type: 'control', subtype: 'push', params: { force: 0.8 } });
  }
  else if (form === 'point') {
    const selfBuff = (variant % 2 === 0);
    j.form = { type: 'point', params: { targetMode: selfBuff ? 'self' : 'look_entity', range: 3.5 } };
    if (selfBuff) {
      effects.push({ type: 'buff', subtype: 'strength', params: { duration: 100 + R.dist * 40 } });
      effects.push({ type: 'buff', subtype: 'speed', params: { bonus: 0.15, duration: 100 + R.dist * 40 } });
      j.tags = [el === 'none' ? 'shape' : el, 'point', 'utility'];
    } else {
      effects.push({ type: 'damage', subtype: 'instant', params: { amount: dmg } });
      effects.push(genElementDebuff(el, dmg));
    }
  }
  else if (form === 'handheld') {
    j.form = { type: 'handheld', params: { chargeTime: bigRank ? 60 : 40, holdDuration: 400, size: bigRank ? 1.2 : 0.8, throwable: bigRank, activation: 'on_hit' } };
    effects.push({ type: 'damage', subtype: 'instant', params: { amount: Math.round(dmg * 1.3) } });
    props.push({ id: 'explode_on_hit', params: { radius: bigRank ? 3 : 2, damage: Math.round(dmg * 1.1), knockback: 1.4 } });
    if (bigRank) props.push({ id: 'multi_use', params: {} });
    activation = { type: 'charge', params: { minCharge: bigRank ? 40 : 20, maxCharge: bigRank ? 100 : 60 } };
  }
  else if (form === 'summon') {
    j.form = { type: 'summon', params: { entityType: bigRank ? 'minecraft:iron_golem' : 'minecraft:wolf',
      count: bigRank ? 2 : 1, lifetime: 600 + R.dist * 200, behavior: 'fight_for_caster', spawnPosition: 'around_caster' } };
    activation = { type: 'handseals', params: { sealCount: 3, sealSpeed: 1 } };
    j.tags = [el === 'none' ? 'shape' : el, 'summon', 'utility'];
    j.category = 'summon';
  }
  else {
    const bt = el === 'water' ? 'ice' : (el === 'wind' ? 'wood' : (el === 'earth' ? 'earth' : 'stone'));
    j.form = { type: 'construct', params: { shape: 'wall', blockType: bt, width: 3 + R.dist, height: 3, depth: 1, duration: 200 + R.dist * 100 } };
    j.tags = [el === 'none' ? 'shape' : el, 'construct', 'utility'];
  }

  j.activation = activation;
  j.cost = { chakra: R.cost };
  if (form !== 'construct' && form !== 'summon') j.cost.fatigue = Math.max(2, Math.round(R.cost * 0.25));
  const req = { stats: { control: R.stat, ninjutsu: R.stat } };
  if (el !== 'none') req.elements = {}; if (el !== 'none') req.elements[el] = R.dist;
  j.requirements = req;
  j.effects = effects;
  if (props.length) j.properties = props;

  const maxLevel = 15;
  j.leveling = { maxLevel: maxLevel, levels: {
    '1': { damage: effects.length && effects[0].params && effects[0].params.amount ? effects[0].params.amount : dmg, cost: R.cost },
    '10': { damage: Math.round(dmg * 1.8), cost: Math.round(R.cost * 0.8), requirements: { uses: 80, sp: 7 } },
    '15': { damage: Math.round(dmg * 2.4), cost: Math.round(R.cost * 0.65), requirements: { uses: 150, sp: 12 } }
  } };

  const size = (j.form.params || {}).size;
  j.visual = visualPresetFor(el, form, size);
  return j;
}

function renderGen(v) {
  v.innerHTML =
    '<h2 class="title">⚙ Генераторы <span class="sub">контент без правки кода: техники, прокачка, дерево, визуал</span></h2>' +
    '<div class="card"><div class="tabs" id="gen-tabs"></div><div id="gen-body"></div></div>';
  const tabs = [
    { id: 'wizard', label: '🧙 Мастер' },
    { id: 'pack',   label: '📦 Пакет техник' },
    { id: 'level',  label: '📈 Кривая прокачки' },
    { id: 'tree',   label: '🌳 Достройка дерева' },
    { id: 'visual', label: '✨ Визуал всем' }
  ];
  const tb = $('#gen-tabs');
  for (const t of tabs) {
    const b = h('<button class="' + (XSV.genTab === t.id ? 'on' : '') + '">' + t.label + '</button>');
    b.onclick = function () { XSV.genTab = t.id; renderGen(v); };
    tb.appendChild(b);
  }
  const body = $('#gen-body');
  if (XSV.wizSim && XSV.genTab !== 'wizard') { XSV.wizSim.stop(); XSV.wizSim = null; }
  if (XSV.genTab === 'wizard') return genWizard(body);
  if (XSV.genTab === 'pack') return genPack(body);
  if (XSV.genTab === 'level') return genLevel(body);
  if (XSV.genTab === 'tree') return genTree(body);
  return genVisual(body);
}


/* ======================= МАСТЕР «ТЕХНИКА ЗА 30 СЕКУНД» ====================== */

const ARCHETYPES = {
  fireball: {
    ru: 'Огненный снаряд со взрывом', form: 'projectile', dmgMul: 1.0, costMul: 1.0, cdMul: 1.0,
    styles: { impactStyle: 'nova' },
    formP: function (dmg, rank) { return { speed: 1.4, gravity: 0.02, lifetime: 80, size: 0.5 }; },
    effects: function (el, dmg) { return [{ type: 'damage', subtype: 'instant', params: { amount: dmg } }]; },
    props: function (el, dmg, rank) { return [{ id: 'explode_on_hit', params: { radius: rank === 'S' ? 4 : 3, damage: Math.round(dmg * 0.8), knockback: 0.6 } }]; },
    act: function () { return { type: 'instant', params: {} }; }
  },
  volley: {
    ru: 'Залп рассеянных снарядов', form: 'projectile', dmgMul: 0.55, costMul: 1.1, cdMul: 1.2,
    styles: { impactStyle: 'default' },
    formP: function (dmg, rank) { return { speed: 1.6, gravity: 0.02, lifetime: 70, size: 0.3, count: rank === 'S' ? 9 : 5, spread: 0.25 }; },
    effects: function (el, dmg) { return [{ type: 'damage', subtype: 'instant', params: { amount: dmg } }]; },
    props: function () { return []; },
    act: function () { return { type: 'instant', params: {} }; }
  },
  lance: {
    ru: 'Пронзающее копьё (без гравитации)', form: 'projectile', dmgMul: 1.15, costMul: 1.1, cdMul: 1.1,
    styles: { trailStyle: 'ribbon' },
    formP: function () { return { speed: 2.0, gravity: 0.0, lifetime: 60, size: 0.35 }; },
    effects: function (el, dmg) { return [{ type: 'damage', subtype: 'instant', params: { amount: dmg } }]; },
    props: function () { return [{ id: 'piercing', params: { count: 3 } }, { id: 'no_gravity', params: {} }]; },
    act: function () { return { type: 'instant', params: {} }; }
  },
  beam: {
    ru: 'Непрерывный луч (каналирование)', form: 'beam', dmgMul: 0.35, costMul: 1.3, cdMul: 1.4,
    styles: { beamStyle: 'pulse' },
    formP: function (dmg, rank) { return { maxRange: rank === 'S' ? 24 : 16, width: 1.0, duration: 60, tickRate: 5 }; },
    effects: function (el, dmg) { return [{ type: 'damage', subtype: 'dot', params: { amount: Math.max(1, dmg), duration: 10 } }]; },
    props: function () { return [{ id: 'channeled', params: { chakraPerTick: 0.5 } }]; },
    act: function () { return { type: 'hold', params: { chakraPerTick: 0.5 } }; }
  },
  chain: {
    ru: 'Цепной разряд по нескольким целям', form: 'projectile', dmgMul: 0.9, costMul: 1.2, cdMul: 1.2,
    styles: { trailStyle: 'lightning', impactStyle: 'shockwave' },
    formP: function () { return { speed: 1.8, gravity: 0.0, lifetime: 50, size: 0.4 }; },
    effects: function (el, dmg) { return [{ type: 'damage', subtype: 'instant', params: { amount: dmg } }]; },
    props: function (el, dmg) { return [{ id: 'chaining', params: { count: 3, range: 6, falloff: 0.7 } }, { id: 'no_gravity', params: {} }]; },
    act: function () { return { type: 'instant', params: {} }; }
  },
  zone_dot: {
    ru: 'Отравленная/горящая зона', form: 'zone', dmgMul: 0.3, costMul: 1.2, cdMul: 1.5,
    styles: { zoneStyle: 'vortex' },
    formP: function (dmg, rank) { return { radius: 3 + (rank === 'S' ? 4 : 2), duration: 160, shape: 'cylinder', tickRate: 20 }; },
    effects: function (el, dmg) {
      const e = [{ type: 'damage', subtype: 'dot', params: { amount: Math.max(1, dmg), duration: 10 } }];
      e.push(genElementDebuff(el, dmg * 3));
      return e;
    },
    props: function () { return []; },
    act: function () { return { type: 'instant', params: {} }; }
  },
  prison: {
    ru: 'Тюрьма (удержание в зоне)', form: 'zone', dmgMul: 0.2, costMul: 1.3, cdMul: 1.6,
    styles: { zoneStyle: 'wall' },
    formP: function (dmg, rank) { return { radius: 3.5, duration: 120, shape: 'cylinder', tickRate: 20 }; },
    effects: function (el, dmg) {
      return [{ type: 'control', subtype: 'root', params: { duration: 40, breakDamage: Math.max(4, dmg * 2) } },
              { type: 'damage', subtype: 'dot', params: { amount: Math.max(1, Math.round(dmg / 2)), duration: 10 } }];
    },
    props: function () { return []; },
    act: function (rank) { return rank === 'A' || rank === 'S' ? { type: 'handseals', params: { sealCount: 3, sealSpeed: 1 } } : { type: 'instant', params: {} }; }
  },
  aura: {
    ru: 'Аура-бафф (переключаемая зона на себе)', form: 'zone', dmgMul: 0, costMul: 1.1, cdMul: 2.0,
    styles: { zoneStyle: 'dome' },
    formP: function () { return { radius: 5, duration: 300, shape: 'sphere', tickRate: 40 }; },
    effects: function (el, dmg) {
      return [{ type: 'buff', subtype: 'strength', params: { duration: 60 } },
              { type: 'buff', subtype: 'speed', params: { bonus: 0.15, duration: 60 } }];
    },
    props: function () { return [{ id: 'aura', params: {} }, { id: 'toggle', params: {} }]; },
    act: function () { return { type: 'instant', params: {} }; }
  },
  dash: {
    ru: 'Смертельный рывок сквозь врага', form: 'dash', dmgMul: 0.9, costMul: 0.8, cdMul: 0.7,
    styles: {},
    formP: function (dmg, rank) { return { distance: 6 + (rank === 'S' ? 4 : 2), speed: 3.2, damageOnPath: true }; },
    effects: function (el, dmg) {
      return [{ type: 'damage', subtype: 'instant', params: { amount: dmg } },
              { type: 'control', subtype: 'push', params: { force: 0.8 } }];
    },
    props: function () { return []; },
    act: function () { return { type: 'instant', params: {} }; }
  },
  mine: {
    ru: 'Мина: прилипает и взрывается позже', form: 'projectile', dmgMul: 1.2, costMul: 0.9, cdMul: 1.0,
    styles: { impactStyle: 'shockwave', trailStyle: 'smoke' },
    formP: function () { return { speed: 1.0, gravity: 0.06, lifetime: 100, size: 0.3 }; },
    effects: function (el, dmg) { return []; },
    props: function (el, dmg) {
      return [{ id: 'stick_on_hit', params: { duration: 200 } },
              { id: 'delayed_explosion', params: { delay: 40, radius: 3, damage: dmg } }];
    },
    act: function () { return { type: 'instant', params: {} }; }
  },
  orbit: {
    ru: 'Орбитальный щит из сгустков', form: 'projectile', dmgMul: 0.4, costMul: 1.2, cdMul: 2.0,
    styles: { trailStyle: 'helix' },
    formP: function (dmg, rank) { return { speed: 1.2, gravity: 0.0, lifetime: 200, size: 0.35 }; },
    effects: function (el, dmg) { return [{ type: 'damage', subtype: 'instant', params: { amount: dmg } }]; },
    props: function () { return [{ id: 'orbiting', params: { radius: 2, count: 4 } }, { id: 'no_gravity', params: {} }]; },
    act: function () { return { type: 'instant', params: {} }; }
  },
  heal: {
    ru: 'Лечащая ладонь (мгновенно + реген)', form: 'point', dmgMul: 0, costMul: 1.0, cdMul: 1.0,
    styles: { castStyle: 'spiral' },
    formP: function () { return { targetMode: 'self', range: 3.5 }; },
    effects: function (el, dmg, rank) {
      const R = GEN_RANK[rank] || GEN_RANK.C;
      return [{ type: 'buff', subtype: 'heal', params: { amount: 4 + R.dist * 2 } },
              { type: 'buff', subtype: 'regen', params: { rate: 0.5, duration: 100 } }];
    },
    props: function () { return []; },
    act: function () { return { type: 'handseals', params: { sealCount: 2, sealSpeed: 1 } }; }
  },
  strike: {
    ru: 'Удар чакрой в упор (по взгляду)', form: 'point', dmgMul: 1.25, costMul: 0.7, cdMul: 0.6,
    styles: { impactStyle: 'implosion', castStyle: 'runes' },
    formP: function () { return { targetMode: 'look_entity', range: 3.5 }; },
    effects: function (el, dmg) {
      const e = [{ type: 'damage', subtype: 'instant', params: { amount: dmg } }];
      e.push(genElementDebuff(el, dmg));
      return e;
    },
    props: function () { return []; },
    act: function () { return { type: 'instant', params: {} }; }
  },
  summon_guard: {
    ru: 'Призыв стража', form: 'summon', dmgMul: 0.5, costMul: 1.4, cdMul: 2.5,
    styles: { castStyle: 'pillars' },
    formP: function (dmg, rank) {
      return { entityType: (rank === 'A' || rank === 'S') ? 'minecraft:iron_golem' : 'minecraft:wolf',
               count: rank === 'S' ? 2 : 1, lifetime: 900, behavior: 'fight_for_caster', spawnPosition: 'around_caster' };
    },
    effects: function () { return []; },
    props: function () { return []; },
    act: function () { return { type: 'handseals', params: { sealCount: 3, sealSpeed: 1 } }; }
  },
  wall: {
    ru: 'Стена-конструкт (укрытие)', form: 'construct', dmgMul: 0, costMul: 0.9, cdMul: 1.2,
    styles: { castStyle: 'pillars' },
    formP: function (dmg, rank, el) {
      const bt = el === 'water' ? 'ice' : (el === 'wind' ? 'wood' : (el === 'earth' ? 'earth' : 'stone'));
      return { shape: 'wall', blockType: bt, width: 5, height: 3, depth: 1, duration: 300 };
    },
    effects: function () { return []; },
    props: function () { return []; },
    act: function () { return { type: 'handseals', params: { sealCount: 1, sealSpeed: 1 } }; }
  },
  handheld: {
    ru: 'Заряжаемая сфера в руке (бросок у S/A)', form: 'handheld', dmgMul: 1.3, costMul: 1.3, cdMul: 1.0,
    styles: { castStyle: 'spiral', impactStyle: 'nova' },
    formP: function (dmg, rank) {
      const big = (rank === 'A' || rank === 'S');
      return { chargeTime: big ? 60 : 40, holdDuration: 400, size: big ? 1.2 : 0.8, throwable: big, activation: 'on_hit' };
    },
    effects: function (el, dmg) { return [{ type: 'damage', subtype: 'instant', params: { amount: Math.round(dmg * 1.3) } }]; },
    props: function (el, dmg) { return [{ id: 'explode_on_hit', params: { radius: 2, damage: Math.round(dmg * 1.1), knockback: 1.4 } }]; },
    act: function (rank) { return { type: 'charge', params: { minCharge: 20, maxCharge: rank === 'S' ? 100 : 60 } }; }
  }
};

const ARCH_NAMES = {
  fireball: ['Flame Bullet', 'Fireball', 'Blazing Shot'],
  volley: ['Scatter Shots', 'Barrage', 'Rain of Fangs'],
  lance: ['Piercing Lance', 'Chakra Spike', 'Straight Fang'],
  beam: ['Piercing Ray', 'Chakra Beam', 'Judgement Lance'],
  chain: ['Chain Discharge', 'Arc Storm', 'Lightning Chain'],
  zone_dot: ['Blighted Field', 'Scorched Domain', 'Toxic Mist'],
  prison: ['Binding Prison', 'Holding Cell', 'Sealed Circle'],
  aura: ['Battle Aura', 'Chakra Veil', 'Inner Flame'],
  dash: ['Shadow Rush', 'Killing Step', 'Wind Dash'],
  mine: ['Sticky Trap', 'Sealed Mine', 'Delayed Tag'],
  orbit: ['Orbiting Guard', 'Chakra Satellites', 'Dancing Orbs'],
  heal: ['Healing Palm', 'Mending Touch', 'Green Mercy'],
  strike: ['Chakra Strike', 'Palm Impact', 'Inner Blow'],
  summon_guard: ['Guardian Call', 'Beast Contract', 'Sentinel Summon'],
  wall: ['Bulwark', 'Rising Barrier', 'Fortress Slab'],
  handheld: ['Chakra Sphere', 'Spiraling Orb', 'Handheld Nova']
};

function wizardDefaults() {
  return { el: 'fire', arch: 'fireball', rank: 'C', name: '', desc: '', styles: {}, addTree: true };
}

function buildArchetypeJutsu(w, usedIds) {
  const a = ARCHETYPES[w.arch] || ARCHETYPES.fireball;
  const R = GEN_RANK[w.rank] || GEN_RANK.C;
  const dmg = Math.max(1, Math.round(R.dmg * (a.dmgMul || 1)));
  const el = w.el;
  const names = ARCH_NAMES[w.arch] || ['Technique'];
  const elPrefix = el === 'none' ? '' : EL_EN[el] + ': ';
  const name = (w.name && w.name.trim()) ? w.name.trim() : elPrefix + names[0];
  let slug = slugify((el === 'none' ? 'chakra_' : el + '_') + name.replace(/^.*?:\s*/, ''));
  let id = 'shinobicore:' + slug;
  let guard = 2;
  while (usedIds[id]) { id = 'shinobicore:' + slug + '_' + guard; guard++; if (guard > 60) break; }
  usedIds[id] = true;

  const formType = a.form;
  const j = {
    id: id,
    name: name,
    description: (w.desc && w.desc.trim()) ? w.desc.trim() : (a.ru + '. Создано мастером Studio — доработайте описание.'),
    category: formType === 'summon' ? 'summon' : (el === 'none' ? 'shape_ninjutsu' : 'elemental_ninjutsu'),
    rank: w.rank,
    tags: [el === 'none' ? 'shape' : el, formType, (a.dmgMul > 0 ? 'offensive' : 'utility')],
    element: el,
    cooldown: Math.round(R.cd * (a.cdMul || 1) * 2) / 2,
    form: { type: formType, params: a.formP(dmg, w.rank, el) },
    activation: a.act(w.rank),
    cost: { chakra: Math.max(2, Math.round(R.cost * (a.costMul || 1))) },
    effects: a.effects(el, dmg, w.rank)
  };
  if (formType !== 'construct' && formType !== 'summon' && a.dmgMul > 0) {
    j.cost.fatigue = Math.max(2, Math.round(j.cost.chakra * 0.25));
  }
  const req = { stats: { control: R.stat, ninjutsu: R.stat } };
  if (el !== 'none') req.elements = { }; if (el !== 'none') req.elements[el] = R.dist;
  j.requirements = req;
  const props = a.props(el, dmg, w.rank);
  if (props && props.length) j.properties = props;
  j.leveling = { maxLevel: 15, levels: {
    '1': { damage: dmg, cost: j.cost.chakra },
    '10': { damage: Math.round(dmg * 1.8), cost: Math.round(j.cost.chakra * 0.8), requirements: { uses: 80, sp: 7 } },
    '15': { damage: Math.round(dmg * 2.4), cost: Math.round(j.cost.chakra * 0.65), requirements: { uses: 150, sp: 12 } }
  } };
  const size = j.form.params.size;
  const vis = visualPresetFor(el, formType, size);
  const st = Object.assign({}, a.styles || {}, w.styles || {});
  for (const k of STYLE_KEYS) {
    if (st[k] && st[k] !== 'default') vis[k] = st[k]; else delete vis[k];
  }
  j.visual = vis;
  return j;
}

function branchForJutsu(d, treeData) {
  const el = d.element || 'none';
  if (['fire', 'water', 'wind', 'earth', 'lightning'].indexOf(el) >= 0) return el;
  const cat = String(d.category || '');
  const tags = (d.tags || []).join(' ');
  if (cat.indexOf('medical') >= 0 || tags.indexOf('medical') >= 0 || el === 'yang') return 'medical';
  if (cat.indexOf('genjutsu') >= 0 || tags.indexOf('genjutsu') >= 0 || el === 'yin') return 'genjutsu';
  if (cat === 'summon') return 'summon';
  if (cat.indexOf('taijutsu') >= 0) return 'taijutsu';
  if (cat.indexOf('kenjutsu') >= 0) return 'kenjutsu';
  if (cat.indexOf('shuriken') >= 0) return 'shuriken';
  if (cat.indexOf('sealing') >= 0) return 'sealing';
  if (cat.indexOf('space') >= 0) return 'space';
  return 'general';
}

function genWizard(body) {
  if (!XSV.wiz) XSV.wiz = wizardDefaults();
  const w = XSV.wiz;
  const a = ARCHETYPES[w.arch] || ARCHETYPES.fireball;
  const R = GEN_RANK[w.rank] || GEN_RANK.C;
  const dmg = Math.max(1, Math.round(R.dmg * (a.dmgMul || 1)));

  const elBtns = Object.keys(FX_PAL).map(function (el) {
    return '<button class="btn sm' + (w.el === el ? ' pri' : '') + '" data-el="' + el + '" style="border-color:' + esc(elColor(el)) + '">' +
      '<span class="dot" style="display:inline-block;background:' + esc(elColor(el)) + ';margin-right:5px"></span>' + esc(EL_RU[el] || el) + '</button>';
  }).join(' ');
  const archBtns = Object.keys(ARCHETYPES).map(function (k) {
    const ar = ARCHETYPES[k];
    return '<div class="item' + (w.arch === k ? ' on' : '') + '" data-arch="' + k + '" style="cursor:pointer;padding:6px 9px;border-bottom:1px solid #241a2c;display:flex;gap:8px;align-items:center">' +
      '<span class="pill mono" style="flex:0 0 auto">' + esc(ar.form) + '</span>' +
      '<span style="flex:1;font-size:12px">' + esc(ar.ru) + '</span></div>';
  }).join('');
  const rankBtns = ['D', 'C', 'B', 'A', 'S'].map(function (r) {
    return '<button class="btn sm' + (w.rank === r ? ' pri' : '') + '" data-rank="' + r + '">' + r + '</button>';
  }).join(' ');

  const preview = buildArchetypeJutsu(Object.assign({}, w, { name: w.name || 'preview' }), {});
  const sameRank = D.jutsu.map(function (j) { return j.data || {}; })
    .filter(function (d) { return d.rank === w.rank && d.cost && d.cost.chakra; });
  const costs = sameRank.map(function (d) { return d.cost.chakra; }).sort(function (x, y) { return x - y; });
  const medCost = costs.length ? costs[Math.floor(costs.length / 2)] : R.cost;

  let styleSelects = '';
  for (const key of STYLE_KEYS) {
    const meta = FX_STYLES[key];
    const cur = (w.styles && w.styles[key]) || (a.styles && a.styles[key]) || 'default';
    let o = '';
    for (const id of Object.keys(meta.opts)) {
      o += '<option value="' + id + '"' + (cur === id ? ' selected' : '') + '>' + esc(meta.opts[id]) + '</option>';
    }
    styleSelects += '<label class="f"><span>' + esc(meta.label) + '</span><select data-style="' + key + '">' + o + '</select></label>';
  }

  body.innerHTML =
    '<div class="grid" style="grid-template-columns:minmax(0,1fr) 260px minmax(0,1.2fr);gap:12px;align-items:start">' +
      '<div>' +
        '<div class="dim" style="font-size:10px;text-transform:uppercase;margin-bottom:4px">1 · стихия</div>' +
        '<div class="row tight" id="wz-els" style="margin-bottom:12px">' + elBtns + '</div>' +
        '<div class="dim" style="font-size:10px;text-transform:uppercase;margin-bottom:4px">2 · ранг</div>' +
        '<div class="row tight" id="wz-ranks" style="margin-bottom:12px">' + rankBtns + '</div>' +
        '<div class="dim" style="font-size:10px;text-transform:uppercase;margin-bottom:4px">3 · название и описание</div>' +
        '<label class="f" style="margin-bottom:6px"><span>название (EN)</span><input id="wz-name" placeholder="' + esc((w.el === 'none' ? '' : EL_EN[w.el] + ': ') + (ARCH_NAMES[w.arch] || [''])[0]) + '" value="' + esc(w.name || '') + '"></label>' +
        '<label class="f" style="margin-bottom:6px"><span>описание (RU)</span><input id="wz-desc" placeholder="' + esc(a.ru) + '" value="' + esc(w.desc || '') + '"></label>' +
        '<label class="pill" style="cursor:pointer;margin-top:4px"><input type="checkbox" id="wz-tree"' + (w.addTree ? ' checked' : '') + '> добавить узел в дерево навыков</label>' +
      '</div>' +
      '<div><div class="dim" style="font-size:10px;text-transform:uppercase;margin-bottom:4px">архетип</div>' +
        '<div class="jlist" id="wz-archs" style="max-height:430px">' + archBtns + '</div></div>' +
      '<div>' +
        '<div class="viz" style="padding:0;overflow:hidden;margin-bottom:8px"><canvas id="wz-canvas" width="520" height="240" style="display:block;width:100%"></canvas></div>' +
        '<div class="grid g2" id="wz-styles">' + styleSelects + '</div>' +
        '<div class="card" style="margin:10px 0 0;padding:8px">' +
          '<table class="t"><tr><td>урон</td><td><b>' + dmg + '</b> <span class="dim">(ранг ' + w.rank + ')</span></td></tr>' +
          '<tr><td>цена чакры</td><td><b>' + preview.cost.chakra + '</b> <span class="dim">медиана ранга: ' + medCost + '</span></td></tr>' +
          '<tr><td>кулдаун</td><td><b>' + preview.cooldown + ' с</b></td></tr>' +
          '<tr><td>форма</td><td class="mono">' + esc(a.form) + '</td></tr></table>' +
          (preview.cost.chakra > medCost * 1.6 ? '<div class="issue warn" style="margin-top:6px">дороже медианы ранга в ' + fmt(preview.cost.chakra / Math.max(1, medCost), 1) + '× — проверьте баланс</div>' : '') +
        '</div>' +
        '<div class="row" style="margin-top:10px"><button class="btn pri" id="wz-create">⚡ Создать технику</button></div>' +
      '</div>' +
    '</div>';

  $$('#wz-els button').forEach(function (b) {
    b.onclick = function () { w.el = b.getAttribute('data-el'); w.styles = {}; genWizard(body); };
  });
  $$('#wz-ranks button').forEach(function (b) {
    b.onclick = function () { w.rank = b.getAttribute('data-rank'); genWizard(body); };
  });
  $$('#wz-archs .item').forEach(function (it) {
    it.onclick = function () { w.arch = it.getAttribute('data-arch'); w.styles = {}; genWizard(body); };
  });
  $('#wz-name').oninput = function () { w.name = this.value; };
  $('#wz-desc').oninput = function () { w.desc = this.value; };
  $('#wz-tree').onchange = function () { w.addTree = this.checked; };
  $$('#wz-styles select').forEach(function (s) {
    s.onchange = function () {
      w.styles = w.styles || {};
      w.styles[s.getAttribute('data-style')] = s.value;
      startWizSim();
    };
  });

  // мини-симуляция будущей техники
  function startWizSim() {
    if (XSV.wizSim) { XSV.wizSim.stop(); }
    const cv = $('#wz-canvas');
    if (!cv) return;
    const sim = new FxSim(cv);
    const visNow = buildArchetypeJutsu(Object.assign({}, w, { name: 'sim' }), {}).visual;
    sim.set(a.form, w.el, visNow, preview.form.params);
    sim.start();
    XSV.wizSim = sim;
  }
  startWizSim();

  $('#wz-create').onclick = async function () {
    const used = usedJutsuIds();
    const j = buildArchetypeJutsu(w, used);
    const fname = j.id.replace('shinobicore:', '') + '.json';
    const path = 'src/main/resources/data/shinobicore/jutsu/' + fname;
    const txt = JSON.stringify(canon(j), null, 2) + '\n';
    try { JSON.parse(txt); } catch (e) { toast('Внутренняя ошибка JSON: ' + e.message, 'err'); return; }
    try {
      await api('/api/save', { method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ path: path, content: txt }) });
    } catch (e) { toast('Не удалось записать: ' + e.message, 'err'); return; }
    let treeMsg = '';
    if (w.addTree && D.tree && D.tree.data) {
      const br = branchForJutsu(j, D.tree.data);
      const R2 = GEN_RANK[j.rank] || GEN_RANK.C;
      const existing = {};
      for (const nd of (D.tree.data.nodes || [])) existing[nd.id] = true;
      let nid = j.id.replace('shinobicore:', '');
      let g = 2; while (existing[nid]) { nid = j.id.replace('shinobicore:', '') + '_' + g; g++; }
      const nodes = (D.tree.data.nodes || []).filter(function (nd) { return nd.branch === br; });
      let best = null;
      for (const nd of nodes) {
        const ndist = Number(nd.distance) || 0;
        if (ndist < R2.dist && (!best || ndist > (Number(best.distance) || 0))) best = nd;
      }
      D.tree.data.nodes.push({
        id: nid, branch: br, distance: R2.dist, type: 'jutsu', jutsuId: j.id,
        spCost: R2.sp, requires: best ? [best.id] : [],
        icon: String(j.name || 'J').charAt(0).toUpperCase(),
        name: j.name, description: j.description
      });
      const ttxt = JSON.stringify(D.tree.data, null, 2) + '\n';
      markDirty(D.tree.path, ttxt);
      refreshFileText(D.tree.path, ttxt);
      treeMsg = ' + узел дерева «' + nid + '»';
      await saveAll();
    }
    toast('Создано: ' + j.name + ' (' + fname + ')' + treeMsg + '. В игре: /reload', 'ok');
    w.name = ''; w.desc = '';
    await loadState();
  };
}

/* ---------- пакетная генерация техник ---------- */
const GEN_STATE = { els: ['fire'], forms: ['projectile'], rank: 'C', variants: 1, preview: [] };

function genPack(body) {
  const elBtns = Object.keys(FX_PAL).map(function (el) {
    return '<label class="pill" style="cursor:pointer;display:inline-flex;gap:5px;align-items:center;margin:2px">' +
      '<input type="checkbox" class="gp-el" value="' + el + '"' + (GEN_STATE.els.indexOf(el) >= 0 ? ' checked' : '') + '>' +
      '<span class="dot" style="background:' + esc(elColor(el)) + '"></span>' + esc(EL_RU[el] || el) + '</label>';
  }).join('');
  const formBtns = ['projectile', 'beam', 'zone', 'dash', 'point', 'handheld', 'summon', 'construct'].map(function (f) {
    return '<label class="pill" style="cursor:pointer;display:inline-flex;gap:5px;align-items:center;margin:2px">' +
      '<input type="checkbox" class="gp-form" value="' + f + '"' + (GEN_STATE.forms.indexOf(f) >= 0 ? ' checked' : '') + '>' + f + '</label>';
  }).join('');

  body.innerHTML =
    '<div class="grid g2" style="margin-bottom:10px">' +
      '<div><div class="dim" style="font-size:11px;margin-bottom:4px">СТИХИИ</div>' + elBtns + '</div>' +
      '<div><div class="dim" style="font-size:11px;margin-bottom:4px">ФОРМЫ</div>' + formBtns + '</div>' +
    '</div>' +
    '<div class="row" style="align-items:flex-end;margin-bottom:10px">' +
      '<label class="f"><span>ранг</span><select id="gp-rank">' + ['D', 'C', 'B', 'A', 'S'].map(function (r) {
        return '<option' + (GEN_STATE.rank === r ? ' selected' : '') + '>' + r + '</option>'; }).join('') + '</select></label>' +
      '<label class="f"><span>вариантов на комбинацию</span><select id="gp-var"><option>1</option><option>2</option><option>3</option></select></label>' +
      '<button class="btn" id="gp-preview">👁 Предпросмотр</button>' +
      '<button class="btn pri" id="gp-run">⚙ Сгенерировать и записать</button>' +
    '</div>' +
    '<div id="gp-out"></div>';

  $('#gp-rank').value = GEN_STATE.rank;
  $('#gp-var').value = String(GEN_STATE.variants);

  const collect = function () {
    GEN_STATE.els = $$('.gp-el').filter(function (c) { return c.checked; }).map(function (c) { return c.value; });
    GEN_STATE.forms = $$('.gp-form').filter(function (c) { return c.checked; }).map(function (c) { return c.value; });
    GEN_STATE.rank = $('#gp-rank').value;
    GEN_STATE.variants = Number($('#gp-var').value) || 1;
  };
  const build = function () {
    collect();
    const used = usedJutsuIds();
    const out = [];
    for (const el of GEN_STATE.els) for (const f of GEN_STATE.forms) for (let vv = 0; vv < GEN_STATE.variants; vv++) {
      out.push(buildGeneratedJutsu(el, f, GEN_STATE.rank, vv, used));
    }
    GEN_STATE.preview = out;
    return out;
  };

  $('#gp-preview').onclick = function () {
    const out = build();
    if (!out.length) { $('#gp-out').innerHTML = '<div class="issue warn">Выберите хотя бы одну стихию и форму</div>'; return; }
    $('#gp-out').innerHTML = '<table class="t"><tr><th>id</th><th>имя</th><th>форма</th><th>ранг</th><th>урон</th><th>цена</th><th>кулдаун</th></tr>' +
      out.map(function (j) {
        const dmg = (j.effects[0] && j.effects[0].params && (j.effects[0].params.amount || j.effects[0].params.dps)) || '—';
        return '<tr><td class="mono">' + esc(j.id) + '</td><td>' + esc(j.name) + '</td><td>' + esc(j.form.type) +
          '</td><td>' + esc(j.rank) + '</td><td>' + esc(dmg) + '</td><td>' + esc((j.cost || {}).chakra) +
          '</td><td>' + esc(j.cooldown) + '</td></tr>';
      }).join('') + '</table>' +
      '<div class="vizcap">Файлы будут созданы в data/shinobicore/jutsu/. Баланс — по ранговой шкале; после генерации откройте техники в редакторе и доведите вручную.</div>';
  };

  $('#gp-run').onclick = async function () {
    const out = GEN_STATE.preview.length ? GEN_STATE.preview : build();
    if (!out.length) { toast('Нечего генерировать', 'err'); return; }
    if (!confirm('Создать ' + out.length + ' файл(ов) техник на диске?')) return;
    let ok = 0;
    for (const j of out) {
      const fname = j.id.replace('shinobicore:', '') + '.json';
      const path = 'src/main/resources/data/shinobicore/jutsu/' + fname;
      const txt = JSON.stringify(canon(j), null, 2) + '\n';
      try {
        await api('/api/save', { method: 'POST', headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ path: path, content: txt }) });
        ok++;
      } catch (e) { toast('Ошибка записи ' + fname + ': ' + e.message, 'err'); }
    }
    GEN_STATE.preview = [];
    toast('Создано техник: ' + ok + '. Перечитываю состояние…', 'ok');
    await loadState();
  };
}

/* ---------- кривая прокачки ---------- */
function genLevel(body) {
  const opts = D.jutsu.map(function (j, i) {
    return '<option value="' + i + '">' + esc((j.data || {}).name || j.name) + ' (' + esc((j.data || {}).rank || '') + ')</option>';
  }).join('');
  body.innerHTML =
    '<div class="row" style="align-items:flex-end">' +
      '<label class="f" style="min-width:260px"><span>техника</span><select id="gl-j">' + opts + '</select></label>' +
      '<label class="f"><span>макс. уровень</span><input type="number" id="gl-max" min="5" max="30" value="15"></label>' +
      '<label class="f"><span>кривая</span><select id="gl-curve"><option value="lin">линейная</option><option value="exp">экспонента (поздний рост)</option><option value="s">S-образная</option></select></label>' +
      '<label class="f"><span>рост урона к максимуму, ×</span><input type="number" id="gl-grow" min="1.2" max="4" step="0.1" value="2.2"></label>' +
      '<label class="f"><span>снижение цены к максимуму, %</span><input type="number" id="gl-cost" min="0" max="60" step="5" value="30"></label>' +
      '<button class="btn" id="gl-preview">👁 Предпросмотр</button>' +
      '<button class="btn pri" id="gl-apply">Применить к технике</button>' +
    '</div><div id="gl-out" style="margin-top:10px"></div>';

  const calc = function () {
    const j = D.jutsu[Number($('#gl-j').value)];
    if (!j) return null;
    const d = j.data || {};
    const max = Math.max(5, Math.min(30, Number($('#gl-max').value) || 15));
    const curve = $('#gl-curve').value;
    const grow = Math.max(1.2, Number($('#gl-grow').value) || 2.2);
    const costCut = Math.max(0, Math.min(0.6, (Number($('#gl-cost').value) || 30) / 100));
    let baseDmg = 0;
    for (const e of (d.effects || [])) {
      const a = (e.params || {}).amount;
      if ((e.type === 'damage') && a && a > baseDmg) baseDmg = a;
    }
    if (!baseDmg) baseDmg = (GEN_RANK[d.rank] || GEN_RANK.C).dmg;
    const baseCost = (d.cost || {}).chakra || (GEN_RANK[d.rank] || GEN_RANK.C).cost;
    const f = function (l) {
      const x = (l - 1) / Math.max(1, max - 1);
      if (curve === 'exp') return (Math.pow(1.7, x) - 1) / (1.7 - 1);
      if (curve === 's') return x * x * (3 - 2 * x);
      return x;
    };
    const marks = [1, Math.round(max * 0.25), Math.round(max * 0.5), Math.round(max * 0.75), max];
    const levels = {};
    const uniq = marks.filter(function (x, i) { return marks.indexOf(x) === i && x >= 1; });
    for (const l of uniq) {
      const row = { damage: Math.round(baseDmg * (1 + (grow - 1) * f(l))), cost: Math.max(1, Math.round(baseCost * (1 - costCut * f(l)))) };
      if (l > 1) row.requirements = { uses: Math.round(30 * l / 5) * 2, sp: Math.max(2, Math.round(l * 0.8)) };
      levels[String(l)] = row;
    }
    return { j: j, leveling: { maxLevel: max, levels: levels }, baseDmg: baseDmg };
  };

  $('#gl-preview').onclick = function () {
    const r = calc(); if (!r) return;
    $('#gl-out').innerHTML = '<table class="t"><tr><th>уровень</th><th>урон</th><th>цена</th><th>требования</th></tr>' +
      Object.keys(r.leveling.levels).map(function (k) {
        const l = r.leveling.levels[k];
        return '<tr><td>' + k + '</td><td>' + l.damage + '</td><td>' + l.cost + '</td><td class="mono dim">' +
          esc(l.requirements ? ('uses ' + l.requirements.uses + ' · sp ' + l.requirements.sp) : '—') + '</td></tr>';
      }).join('') + '</table>';
  };
  $('#gl-apply').onclick = function () {
    const r = calc(); if (!r) return;
    r.j.data.leveling = r.leveling;
    const firstDmg = r.leveling.levels['1'] ? r.leveling.levels['1'].damage : null;
    if (firstDmg) {
      for (const e of (r.j.data.effects || [])) {
        if (e.type === 'damage' && e.subtype === 'instant' && e.params) { e.params.amount = firstDmg; break; }
      }
    }
    const txt = JSON.stringify(canon(r.j.data), null, 2) + '\n';
    markDirty(r.j.path, txt); refreshFileText(r.j.path, txt);
    toast('Прокачка применена к ' + (r.j.data.name || '') + ' — сохраните (Ctrl+S)', 'ok');
  };
}

/* ---------- достройка дерева ---------- */
function genTree(body) {
  const tree = D.tree;
  if (!tree || !tree.data) { body.innerHTML = '<div class="issue warn">tree.json не найден</div>'; return; }
  const covered = {};
  for (const n of (tree.data.nodes || [])) if (n.jutsuId) covered[n.jutsuId] = true;
  const uncovered = D.jutsu.filter(function (j) { return (j.data || {}).id && !covered[j.data.id]; });

  const branchFor = function (d) {
    const el = d.element || 'none';
    if (['fire', 'water', 'wind', 'earth', 'lightning'].indexOf(el) >= 0) return el;
    const cat = String(d.category || '');
    const tags = (d.tags || []).join(' ');
    if (cat.indexOf('medical') >= 0 || tags.indexOf('medical') >= 0 || el === 'yang') return 'medical';
    if (cat.indexOf('genjutsu') >= 0 || tags.indexOf('genjutsu') >= 0 || el === 'yin') return 'genjutsu';
    if (cat.indexOf('taijutsu') >= 0 || tags.indexOf('taijutsu') >= 0) return 'taijutsu';
    if (cat.indexOf('kenjutsu') >= 0 || tags.indexOf('kenjutsu') >= 0) return 'kenjutsu';
    if (cat.indexOf('shuriken') >= 0 || tags.indexOf('shuriken') >= 0) return 'shuriken';
    if (cat.indexOf('sealing') >= 0 || tags.indexOf('sealing') >= 0) return 'sealing';
    if (cat.indexOf('summon') >= 0 || tags.indexOf('summon') >= 0) return 'summon';
    if (cat.indexOf('space') >= 0) return 'space';
    if (cat.indexOf('kekkei') >= 0) return 'kekkei';
    if (cat.indexOf('forbidden') >= 0) return 'forbidden';
    return 'general';
  };

  body.innerHTML =
    '<div class="dim" style="margin-bottom:8px">Техник без узлов в дереве: <b>' + uncovered.length + '</b>. ' +
    'Узел получает ветку по стихии/категории, глубину по рангу (D=1 … S=5), цену SP по ранговой шкале, ' +
    'requires — ближайший существующий узел ветки глубиной ниже.</div>' +
    (uncovered.length ?
      '<table class="t"><tr><th></th><th>техника</th><th>ветка</th><th>дистанция</th><th>SP</th><th>requires</th><th>id узла</th></tr>' +
      uncovered.map(function (j, i) {
        const d = j.data || {};
        const R = GEN_RANK[d.rank] || GEN_RANK.C;
        const br = branchFor(d);
        const nodes = (tree.data.nodes || []).filter(function (n) { return n.branch === br; });
        let req = [];
        let best = null;
        for (const n of nodes) {
          const nd = Number(n.distance) || 0;
          if (nd < R.dist && (!best || nd > (Number(best.distance) || 0))) best = n;
        }
        if (best) req = [best.id];
        let nid = String(d.id).replace('shinobicore:', '');
        const existing = {};
        for (const n of (tree.data.nodes || [])) existing[n.id] = true;
        let g = 2; while (existing[nid]) { nid = String(d.id).replace('shinobicore:', '') + '_' + g; g++; }
        return '<tr><td><input type="checkbox" class="gt-pick" data-i="' + i + '" checked></td>' +
          '<td>' + esc(d.name || '') + '</td><td><span class="pill" style="color:' + esc(((tree.data.branches || {})[br] || {}).color || '#aaa') + '">' + esc(br) + '</span></td>' +
          '<td>' + R.dist + '</td><td>' + R.sp + '</td><td class="mono dim">' + esc(req.join(', ') || '—') + '</td>' +
          '<td class="mono">' + esc(nid) + '</td></tr>';
      }).join('') + '</table>' +
      '<div class="row" style="margin-top:10px"><button class="btn pri" id="gt-add">🌳 Добавить выбранные в tree.json</button></div>'
      : '<div class="issue ok" style="border-color:var(--green);background:#1c2a1e">Все техники покрыты деревом.</div>');

  const addBtn = $('#gt-add');
  if (addBtn) addBtn.onclick = function () {
    const picks = $$('.gt-pick').filter(function (c) { return c.checked; }).map(function (c) { return Number(c.getAttribute('data-i')); });
    if (!picks.length) { toast('Ничего не выбрано', 'err'); return; }
    const existing = {};
    for (const n of (tree.data.nodes || [])) existing[n.id] = true;
    let added = 0;
    for (const i of picks) {
      const j = uncovered[i];
      const d = j.data || {};
      const R = GEN_RANK[d.rank] || GEN_RANK.C;
      const br = branchFor(d);
      let nid = String(d.id).replace('shinobicore:', '');
      let g = 2; while (existing[nid]) { nid = String(d.id).replace('shinobicore:', '') + '_' + g; g++; }
      existing[nid] = true;
      const nodes = (tree.data.nodes || []).filter(function (n) { return n.branch === br; });
      let best = null;
      for (const n of nodes) {
        const nd = Number(n.distance) || 0;
        if (nd < R.dist && (!best || nd > (Number(best.distance) || 0))) best = n;
      }
      tree.data.nodes.push({
        id: nid, branch: br, distance: R.dist, type: 'jutsu', jutsuId: d.id,
        spCost: R.sp, requires: best ? [best.id] : [],
        icon: String(d.name || 'J').charAt(0).toUpperCase(),
        name: d.name || nid, description: d.description || ''
      });
      added++;
    }
    const txt = JSON.stringify(tree.data, null, 2) + '\n';
    markDirty(tree.path, txt); refreshFileText(tree.path, txt);
    toast('Узлов добавлено: ' + added + ' — сохраните (Ctrl+S)', 'ok');
    renderSection();
  };
}

/* ---------- визуал всем ---------- */
function genVisual(body) {
  const noVis = D.jutsu.filter(function (j) { return !(j.data || {}).visual; });
  const withVis = D.jutsu.length - noVis.length;
  body.innerHTML =
    '<div class="dim" style="margin-bottom:8px">Техник с visual: <b>' + withVis + '</b>, без visual: <b>' + noVis.length + '</b>.</div>' +
    '<div class="row">' +
      '<button class="btn pri" id="gv-all">✨ Применить яркий пресет ко всем без visual</button>' +
      '<button class="btn danger" id="gv-replace">♻ Пересоздать visual у ВСЕХ техник (перезапишет ручные настройки)</button>' +
    '</div>' +
    '<div class="vizcap" style="margin-top:8px">Пресет = частицы стихии + яркий цвет + glow + воксельная модель для projectile/handheld. ' +
    'Тот же алгоритм выполнил мастер-скрипт в фазе 4 — эта кнопка для техник, созданных позже.</div>';
  const applyAll = function (replace) {
    let n = 0;
    for (const j of D.jutsu) {
      const d = j.data || {};
      if (d.visual && !replace) continue;
      const ft = ((d.form || {}).type) || '';
      const size = ((d.form || {}).params || {}).size;
      fxCommitVisual(j, visualPresetFor(d.element || 'none', ft, size));
      n++;
    }
    toast(n ? ('visual записан в ' + n + ' техник — сохраните (Ctrl+S)') : 'Нечего делать', n ? 'ok' : '');
    renderSection();
  };
  $('#gv-all').onclick = function () { applyAll(false); };
  $('#gv-replace').onclick = function () {
    if (confirm('Пересоздать visual у всех техник? Ручные настройки цвета/частиц будут потеряны.')) applyAll(true);
  };
}

/* ============================== ФОРМАТЫ ==================================== */

function renderFmts(v) {
  v.innerHTML =
    '<h2 class="title">📐 Форматы будущих паков <span class="sub">docs/formats/*.md — соглашения, _templates/*.json — стартовые шаблоны</span></h2>' +
    '<div class="jwrap" style="grid-template-columns:240px minmax(0,1fr)">' +
      '<div class="jlist"><div class="filters dim" style="font-size:10px;text-transform:uppercase">документы и шаблоны</div><div id="fmt-items"></div></div>' +
      '<div class="card" id="fmt-view"><div class="empty dim">Выберите документ слева</div></div>' +
    '</div>';
  const items = [];
  XSV.formats.forEach(function (f, i) { items.push({ kind: 'doc', i: i, label: '📄 ' + f.name.replace(/\.md$/, '') }); });
  XSV.templates.forEach(function (f, i) { items.push({ kind: 'tpl', i: i, label: '🧩 ' + f.name.replace(/\.json$/, '') }); });
  const box = $('#fmt-items');
  items.forEach(function (it) {
    const el2 = h('<div class="item"><span class="nm">' + esc(it.label) + '</span></div>');
    el2.onclick = function () {
      $$('#fmt-items .item').forEach(function (x) { x.classList.remove('on'); });
      el2.classList.add('on');
      const f = it.kind === 'doc' ? XSV.formats[it.i] : XSV.templates[it.i];
      const view = $('#fmt-view');
      if (it.kind === 'doc') {
        view.innerHTML = '<h3>' + esc(f.name) + '</h3><pre class="mono" style="white-space:pre-wrap;font-size:11.5px;line-height:1.55">' + esc(f.text) + '</pre>';
      } else {
        view.innerHTML = '<h3>' + esc(f.name) + ' <span class="hint">шаблон — можно править и сохранять</span></h3>' +
          '<textarea id="fmt-json" class="mono" style="width:100%;height:420px" spellcheck="false">' + esc(f.text) + '</textarea>' +
          '<div class="row" style="margin-top:8px"><button class="btn sm pri" id="fmt-save">💾 Сохранить</button></div>';
        $('#fmt-save').onclick = function () {
          const txt = $('#fmt-json').value;
          try { JSON.parse(txt); } catch (e) { toast('JSON не парсится: ' + e.message, 'err'); return; }
          markDirty(f.path, txt); refreshFileText(f.path, txt);
          toast('Помечено к сохранению — Ctrl+S', 'ok');
        };
      }
    };
    box.appendChild(el2);
  });
  if (!items.length) {
    box.innerHTML = '<div class="item dim">нет файлов — выполните фазу 6 мастер-скрипта</div>';
  }
}

})();