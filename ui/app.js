(() => {
  'use strict';

  const tauri = window.__TAURI__;
  const invoke = tauri && tauri.core ? tauri.core.invoke : null;
  const LS_KEY = 'sidememo-store';

  const $ = (s) => document.querySelector(s);
  const themeBtn = $('#themeBtn');
  const tabMemos = $('#tabMemos');
  const tabNotes = $('#tabNotes');
  const viewMemos = $('#viewMemos');
  const viewNotes = $('#viewNotes');
  const listEl = $('#list');
  const noteListEl = $('#noteList');
  const inputEl = $('#input');
  const searchMemosEl = $('#searchMemos');
  const searchNotesEl = $('#searchNotes');
  const countEl = $('#count');
  const clearBtn = $('#clearDone');
  const newNoteBtn = $('#newNoteBtn');
  const editorEl = $('#editor');
  const backBtn = $('#backBtn');
  const editorMeta = $('#editorMeta');
  const noteTitleEl = $('#noteTitle');
  const noteBodyEl = $('#noteBody');
  const saveStateEl = $('#saveState');
  const charCountEl = $('#charCount');
  const imgBtn = $('#imgBtn');
  const imgFile = $('#imgFile');
  const mdBtn = $('#mdBtn');
  const notePreviewEl = $('#notePreview');
  const lightboxEl = $('#lightbox');
  const lightboxImg = $('#lightboxImg');
  const pinBtn = $('#pinBtn');
  const settingsBtn = $('#settingsBtn');
  const settingsEl = $('#settings');
  const settingsBack = $('#settingsBack');
  const hotkeyDisplay = $('#hotkeyDisplay');
  const hotkeyEdit = $('#hotkeyEdit');
  const hotkeyHint = $('#hotkeyHint');
  const labelInput = $('#labelInput');
  const widthRange = $('#widthRange');
  const widthValue = $('#widthValue');
  const edgeLabelEl = $('#edgeLabel');
  const edgeModeSeg = $('#edgeModeSeg');
  const edgeWidthRow = $('#edgeWidthRow');
  const edgeWidthRange = $('#edgeWidthRange');
  const edgeWidthValue = $('#edgeWidthValue');
  const edgeHint = $('#edgeHint');
  const dockSideSeg = $('#dockSideSeg');
  const autoStartToggle = $('#autoStartToggle');
  const tagChipsEl = $('#tagChips');
  const archiveToggle = $('#archiveToggle');
  const hotkeyRow = document.querySelector('.hotkeyRow');
  const panelEl = $('#panel');
  const panelBgEl = $('#panelBg');
  const panelBgImgEl = $('#panelBgImg');
  const retractRange = $('#retractRange');
  const retractValue = $('#retractValue');
  const opacityRange = $('#opacityRange');
  const opacityValue = $('#opacityValue');
  const swatchesEl = $('#swatches');
  const bgColorInput = $('#bgColorInput');
  const bgImgBtn = $('#bgImgBtn');
  const bgImgClear = $('#bgImgClear');
  const blurToggle = $('#blurToggle');
  const blurRange = $('#blurRange');
  const blurValue = $('#blurValue');
  const bgHint = $('#bgHint');
  const bgFile = $('#bgFile');
  const presetRowEl = $('#presetRow');
  const dimRange = $('#dimRange');
  const dimValue = $('#dimValue');
  const accentSwatchesEl = $('#accentSwatches');
  const accentColorInput = $('#accentColorInput');
  const fontRange = $('#fontRange');
  const fontValue = $('#fontValue');

  // 正文里图片的存储标记（磁盘上仍是纯文本）
  const IMG_RE = /!\[img\]\(sidememo-img:\/\/([^)\s]+)\)/g;
  // 标签：# 后跟非空白/非标点的 1-24 个字符（中英文皆可）
  const TAG_RE = /[#＃]([^\s#＃,，.。;；:：!！?？()（）\[\]【】《》「」『』“”‘’…·、\\/|~`@#$%^&*=+<>-]{1,24})/g;
  let imagesDirAbs = '';
  let editorMode = 'edit'; // 'edit' | 'preview'
  let hotkeyRecording = false;
  let viewArchived = false;
  let tagFilter = '';

  const ICONS = {
    check: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><path d="M20 6 9 17l-5-5"/></svg>',
    pin: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 17v5"/><path d="M9 10.76a2 2 0 0 1-1.11 1.79l-1.78.9A2 2 0 0 0 5 15.24V16h14v-.76a2 2 0 0 0-1.11-1.79l-1.78-.9A2 2 0 0 1 15 10.76V6h1a2 2 0 0 0 0-4H8a2 2 0 0 0 0 4h1z"/></svg>',
    pinFilled: '<svg viewBox="0 0 24 24" fill="currentColor" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 17v5"/><path d="M9 10.76a2 2 0 0 1-1.11 1.79l-1.78.9A2 2 0 0 0 5 15.24V16h14v-.76a2 2 0 0 0-1.11-1.79l-1.78-.9A2 2 0 0 1 15 10.76V6h1a2 2 0 0 0 0-4H8a2 2 0 0 0 0 4h1z"/></svg>',
    edit: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M17 3a2.83 2.83 0 1 1 4 4L7.5 20.5 2 22l1.5-5.5Z"/></svg>',
    trash: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 6h18"/><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6"/><path d="M8 6V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/></svg>',
    archive: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="2" y="3" width="20" height="5" rx="1"/><path d="M4 8v11a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8"/><path d="M10 12h4"/></svg>',
    bell: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M6 8a6 6 0 0 1 12 0c0 7 3 9 3 9H3s3-2 3-9"/><path d="M10.3 21a1.94 1.94 0 0 0 3.4 0"/></svg>',
    bellActive: '<svg viewBox="0 0 24 24" fill="currentColor" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M6 8a6 6 0 0 1 12 0c0 7 3 9 3 9H3s3-2 3-9"/><path d="M10.3 21a1.94 1.94 0 0 0 3.4 0"/></svg>',
    sun: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M4.93 4.93l1.41 1.41M17.66 17.66l1.41 1.41M2 12h2M20 12h2M6.34 17.66l-1.41 1.41M19.07 4.93l-1.41 1.41"/></svg>',
    moon: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 3a6 6 0 0 0 9 9 9 9 0 1 1-9-9Z"/></svg>',
    note: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><path d="M15.5 3H5a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V8.5L15.5 3Z"/><path d="M15 3v6h6"/></svg>',
  };

  let store = { theme: 'dark', active_tab: 'memos', memos: [], notes: [] };
  let memoFilter = '';
  let noteFilter = '';
  let firstRender = true;
  let saveTimer = null;
  let noteTimer = null;
  let currentNoteId = null;

  /* ---------- 存取 ---------- */
  async function load() {
    if (invoke) {
      try {
        const s = await invoke('load_store');
        if (s) store = s;
      } catch (e) {
        console.error('load_store failed', e);
      }
    } else {
      try {
        store = JSON.parse(localStorage.getItem(LS_KEY)) || store;
      } catch (e) { /* ignore */ }
    }
    if (!Array.isArray(store.memos)) store.memos = [];
    if (!Array.isArray(store.notes)) store.notes = [];
    store.pin = !!store.pin;
    store.hotkey = store.hotkey || '';
    store.label = store.label || '';
    const w = Number(store.width);
    store.width = w >= 280 && w <= 480 ? w : 340;
    // 兼容旧数据：没有 edge_mode 时按是否有描述标签推断
    if (['label', 'sliver', 'hidden'].includes(store.edge_mode)) {
      // keep
    } else {
      store.edge_mode = store.label.trim() ? 'label' : 'sliver';
    }
    store.dock_side = store.dock_side === 'left' ? 'left' : 'right';
    const ew = Number(store.edge_width);
    store.edge_width = ew >= 8 && ew <= 48 ? ew : 10;
    const rm = Number(store.retract_ms);
    store.retract_ms = rm >= 0 && rm <= 60_000 ? Math.round(rm) : 900;
    const op = Number(store.bg_opacity);
    store.bg_opacity = op >= 0.2 && op <= 1 ? op : 1;
    store.bg_color = typeof store.bg_color === 'string' ? store.bg_color : '';
    store.bg_image = typeof store.bg_image === 'string' ? store.bg_image : '';
    const bl = Number(store.bg_blur);
    store.bg_blur = bl >= 2 && bl <= 30 ? Math.round(bl) : 8;
    store.bg_blur_on = !!store.bg_blur_on;
    const dm = Number(store.bg_dim);
    store.bg_dim = dm >= 0 && dm <= 80 ? Math.round(dm) : 0;
    store.accent = typeof store.accent === 'string' ? store.accent : '';
    const fz = Number(store.font_size);
    store.font_size = fz >= 12 && fz <= 18 ? Math.round(fz) : 13;
    applyTheme();
    applyPin();
    applyEdge();
    applyAppearance();
    applyAccent();
    applyFontSize();
    listenDockState();
  }

  function save() {
    clearTimeout(saveTimer);
    saveTimer = setTimeout(() => {
      if (invoke) {
        invoke('save_store', { store }).catch((e) => console.error('save_store failed', e));
      } else {
        localStorage.setItem(LS_KEY, JSON.stringify(store));
      }
    }, 200);
  }

  /* ---------- 主题 ---------- */
  function applyTheme() {
    const theme = store.theme === 'light' ? 'light' : 'dark';
    document.body.dataset.theme = theme;
    themeBtn.innerHTML = theme === 'light' ? ICONS.moon : ICONS.sun;
    themeBtn.title = theme === 'light' ? '切换到深色' : '切换到浅色';
    applyAppearance();
  }

  themeBtn.addEventListener('click', () => {
    store.theme = document.body.dataset.theme === 'dark' ? 'light' : 'dark';
    applyTheme();
    save();
  });

  /* ---------- 固定面板（书钉） ---------- */
  function applyPin() {
    pinBtn.classList.toggle('active', !!store.pin);
    pinBtn.innerHTML = store.pin ? ICONS.pinFilled : ICONS.pin;
    pinBtn.title = store.pin ? '取消固定：恢复自动收起' : '固定面板：鼠标离开不再自动收起';
  }

  pinBtn.addEventListener('click', () => {
    store.pin = !store.pin;
    applyPin();
    save();
    if (invoke) invoke('set_pinned', { pinned: !!store.pin }).catch(() => {});
  });

  /* ---------- 停靠状态同步（收起标签的显隐） ---------- */
  function listenDockState() {
    if (tauri && tauri.event && tauri.event.listen) {
      tauri.event.listen('dock-state', (e) => {
        document.body.dataset.dock = String(e.payload);
      });
    }
  }

  function applyLabel() {
    const label = (store.label || '').trim();
    edgeLabelEl.textContent = label;
    document.body.classList.toggle('has-label', !!label && store.edge_mode === 'label');
  }

  /* ---------- 收起状态（边条模式 / 宽度） ---------- */
  function applyEdge() {
    const mode = store.edge_mode;
    const sideLeft = store.dock_side === 'left';
    document.body.dataset.dockside = sideLeft ? 'left' : 'right';
    dockSideSeg.querySelectorAll('.segBtn').forEach((b) => {
      b.classList.toggle('active', b.dataset.side === store.dock_side);
    });
    // 标签模式需要最小宽度放竖排文字；Rust 端有同样的钳制
    const effW =
      mode === 'hidden' ? 0 : mode === 'label' ? Math.max(store.edge_width, 28) : store.edge_width;
    document.body.style.setProperty('--sliver', effW + 'px');
    applyLabel();
    edgeModeSeg.querySelectorAll('.segBtn').forEach((b) => {
      b.classList.toggle('active', b.dataset.mode === mode);
    });
    edgeWidthRange.value = store.edge_width;
    edgeWidthValue.textContent = `${store.edge_width} px`;
    edgeWidthRow.classList.toggle('disabled', mode === 'hidden');
    edgeHint.textContent =
      mode === 'hidden'
        ? '完全隐藏：贴边悬停不再唤出，用快捷键或托盘唤出'
        : mode === 'label' && !(store.label || '').trim()
          ? '先在下方填写悬浮窗描述，即可显示文字标签'
          : sideLeft
            ? '鼠标靠近屏幕左缘唤出面板'
            : '鼠标靠近屏幕右缘唤出面板';
  }

  function pushEdge() {
    save();
    if (invoke) invoke('set_edge', { mode: store.edge_mode, width: store.edge_width }).catch(() => {});
  }

  edgeModeSeg.addEventListener('click', (e) => {
    const btn = e.target.closest('.segBtn');
    if (!btn || btn.dataset.mode === store.edge_mode) return;
    store.edge_mode = btn.dataset.mode;
    applyEdge();
    pushEdge();
  });

  dockSideSeg.addEventListener('click', (e) => {
    const btn = e.target.closest('.segBtn');
    if (!btn || btn.dataset.side === store.dock_side) return;
    store.dock_side = btn.dataset.side;
    applyEdge();
    save();
    if (invoke) invoke('set_dock_side', { side: store.dock_side }).catch(() => {});
  });

  let edgeWidthTimer = null;
  edgeWidthRange.addEventListener('input', () => {
    store.edge_width = Number(edgeWidthRange.value);
    applyEdge();
    clearTimeout(edgeWidthTimer);
    edgeWidthTimer = setTimeout(pushEdge, 200);
  });

  /* ---------- 外观（背景 / 不透明度 / 模糊 / 收起延迟） ---------- */
  const SWATCHES = [
    { v: '', t: '跟随主题' },
    { v: '#1b1e27', t: '墨黑' },
    { v: '#22302a', t: '墨绿' },
    { v: '#2a2438', t: '暗紫' },
    { v: '#f5efe6', t: '暖白' },
    { v: '#f2dcd8', t: '豆沙' },
    { v: '#dfe9e4', t: '青瓷' },
    { v: '#dde6f0', t: '雾蓝' },
  ];
  // 无自定义背景时的主题底色（等效原渐变的平均色与不透明度）
  const THEME_BASE = {
    dark: { c: '23, 25, 33', a: 0.88 },
    light: { c: '250, 250, 254', a: 0.93 },
  };

  function fmtRetract(ms) {
    const s = ms / 1000;
    return (s % 1 ? s.toFixed(1) : String(s)) + ' 秒';
  }

  function applyRetractUI() {
    retractRange.value = store.retract_ms;
    retractValue.textContent = fmtRetract(store.retract_ms);
  }

  function renderSwatches() {
    swatchesEl.innerHTML = '';
    SWATCHES.forEach(({ v, t }) => {
      const b = document.createElement('button');
      b.type = 'button';
      b.className = 'swatch' + (store.bg_color === v ? ' active' : '');
      b.title = t;
      b.style.background = v || 'linear-gradient(135deg, var(--bg2), var(--bg))';
      b.addEventListener('click', () => {
        store.bg_color = v;
        bgColorInput.value = v || '#1b1e27';
        renderSwatches();
        applyAppearance();
        save();
      });
      swatchesEl.appendChild(b);
    });
  }

  // 默认状态（透明度 100% 且无自定义背景）不启用图层，完全保持原外观
  function applyAppearance() {
    const hasCustom = !!(store.bg_color || store.bg_image);
    const base = THEME_BASE[document.body.dataset.theme] || THEME_BASE.dark;
    const layerMode = hasCustom || store.bg_opacity < 1;
    if (layerMode) {
      panelEl.style.background = 'none';
      panelBgEl.style.display = 'block';
      panelBgEl.style.backgroundColor = store.bg_color || `rgba(${base.c}, ${base.a})`;
      const src = store.bg_image ? imgSrc(store.bg_image) : '';
      panelBgImgEl.style.backgroundImage = src ? `url("${src}")` : '';
    } else {
      panelEl.style.background = '';
      panelBgEl.style.display = 'none';
      panelBgImgEl.style.backgroundImage = '';
    }
    panelBgEl.style.opacity = store.bg_opacity;
    const filters = [];
    if (store.bg_blur_on && store.bg_blur > 0) filters.push(`blur(${store.bg_blur}px)`);
    if (store.bg_dim > 0) filters.push(`brightness(${1 - store.bg_dim / 100})`);
    panelBgImgEl.style.filter = filters.join(' ');
    syncBlurControls();
    refreshPresetActive();
  }

  function syncBlurControls() {
    const hasImg = !!store.bg_image;
    blurToggle.disabled = !hasImg;
    blurRange.disabled = !hasImg || !store.bg_blur_on;
    blurValue.textContent = `${store.bg_blur} px`;
    dimRange.disabled = !hasImg;
    dimValue.textContent = `${store.bg_dim}%`;
  }

  let retractTimer = null;
  retractRange.addEventListener('input', () => {
    store.retract_ms = Number(retractRange.value);
    retractValue.textContent = fmtRetract(store.retract_ms);
    clearTimeout(retractTimer);
    retractTimer = setTimeout(() => {
      save();
      if (invoke) invoke('set_retract_ms', { ms: store.retract_ms }).catch(() => {});
    }, 200);
  });

  let opacityTimer = null;
  opacityRange.addEventListener('input', () => {
    store.bg_opacity = Number(opacityRange.value) / 100;
    opacityValue.textContent = `${opacityRange.value}%`;
    applyAppearance();
    clearTimeout(opacityTimer);
    opacityTimer = setTimeout(save, 200);
  });

  bgColorInput.addEventListener('input', () => {
    store.bg_color = bgColorInput.value;
    renderSwatches();
    applyAppearance();
    save();
  });

  bgImgBtn.addEventListener('click', () => {
    if (invoke) bgFile.click();
  });

  bgFile.addEventListener('change', async () => {
    const f = bgFile.files && bgFile.files[0];
    bgFile.value = '';
    if (!f || !invoke) return;
    if (f.size > 15 * 1024 * 1024) {
      bgHint.textContent = '图片超过 15MB，未设置';
      return;
    }
    try {
      const buf = new Uint8Array(await f.arrayBuffer());
      store.bg_image = await invoke('save_image', buf);
      bgImgClear.classList.remove('hidden');
      bgHint.textContent = '背景图已更新';
      applyAppearance();
      save();
    } catch (e) {
      bgHint.textContent = '背景图保存失败';
    }
  });

  bgImgClear.addEventListener('click', () => {
    store.bg_image = '';
    bgImgClear.classList.add('hidden');
    applyAppearance();
    save();
  });

  blurToggle.addEventListener('change', () => {
    store.bg_blur_on = blurToggle.checked;
    applyAppearance();
    save();
  });

  let blurTimer = null;
  blurRange.addEventListener('input', () => {
    store.bg_blur = Number(blurRange.value);
    blurValue.textContent = `${store.bg_blur} px`;
    applyAppearance();
    clearTimeout(blurTimer);
    blurTimer = setTimeout(save, 200);
  });

  /* ---------- 风格预设 / 强调色 / 字号 ---------- */
  const STYLE_PRESETS = [
    { name: '跟随主题', color: '', opacity: 1, blurOn: false, blur: 8, dim: 0 },
    { name: '海洋', color: '#16324f', opacity: 0.9, blurOn: false, blur: 8, dim: 0 },
    { name: '暗夜', color: '#14161d', opacity: 0.82, blurOn: false, blur: 8, dim: 0 },
    { name: '暗夜紫', color: '#2a2438', opacity: 0.88, blurOn: false, blur: 8, dim: 0 },
    { name: '奶油', color: '#f5efe6', opacity: 1, blurOn: false, blur: 8, dim: 0 },
    { name: '青瓷', color: '#dfe9e4', opacity: 0.95, blurOn: false, blur: 8, dim: 0 },
    { name: '雾蓝', color: '#dde6f0', opacity: 0.92, blurOn: false, blur: 8, dim: 0 },
    { name: '壁纸毛玻璃', color: '', opacity: 0.55, blurOn: true, blur: 14, dim: 25 },
  ];
  const ACCENTS = [
    { v: '', t: '跟随主题' },
    { v: '#4f8ef8', t: '蓝' },
    { v: '#3fb8af', t: '青' },
    { v: '#f06e9c', t: '粉' },
    { v: '#ef9f4c', t: '橙' },
    { v: '#62b576', t: '绿' },
    { v: '#e0c25a', t: '金' },
  ];

  function presetMatches(p) {
    return (
      store.bg_color === p.color &&
      store.bg_opacity === p.opacity &&
      store.bg_blur_on === p.blurOn &&
      store.bg_blur === p.blur &&
      store.bg_dim === p.dim
    );
  }

  function renderPresets() {
    presetRowEl.innerHTML = '';
    STYLE_PRESETS.forEach((p) => {
      const b = document.createElement('button');
      b.type = 'button';
      b.className = 'presetChip';
      const dot = document.createElement('span');
      dot.className = 'dot';
      dot.style.background =
        p.color ||
        (p.blurOn
          ? 'linear-gradient(135deg, #5a6478, #2c3242)'
          : 'linear-gradient(135deg, var(--bg2), var(--bg))');
      b.append(dot, document.createTextNode(p.name));
      b.title = `不透明度 ${Math.round(p.opacity * 100)}%` + (p.blurOn ? ` · 模糊 ${p.blur}px` : '') + (p.dim ? ` · 压暗 ${p.dim}%` : '');
      b.addEventListener('click', () => {
        store.bg_color = p.color;
        store.bg_opacity = p.opacity;
        store.bg_blur_on = p.blurOn;
        store.bg_blur = p.blur;
        store.bg_dim = p.dim;
        applyAppearance();
        save();
        syncAppearanceControls();
      });
      presetRowEl.appendChild(b);
    });
    refreshPresetActive();
  }

  function refreshPresetActive() {
    [...presetRowEl.children].forEach((b, i) => {
      if (STYLE_PRESETS[i]) b.classList.toggle('active', presetMatches(STYLE_PRESETS[i]));
    });
  }

  function hexRgb(hex) {
    const m = /^#?([0-9a-f]{6})$/i.exec(hex || '');
    if (!m) return null;
    const n = parseInt(m[1], 16);
    return `${(n >> 16) & 255}, ${(n >> 8) & 255}, ${n & 255}`;
  }

  function applyAccent() {
    const rgb = hexRgb(store.accent);
    if (rgb) {
      document.body.style.setProperty('--accent', store.accent);
      document.body.style.setProperty('--accent-border', `rgba(${rgb}, 0.45)`);
      document.body.style.setProperty('--accent-soft', `rgba(${rgb}, 0.16)`);
      document.body.style.setProperty('--accent2', store.accent);
    } else {
      ['--accent', '--accent-border', '--accent-soft', '--accent2'].forEach((p) =>
        document.body.style.removeProperty(p)
      );
    }
  }

  function renderAccentSwatches() {
    accentSwatchesEl.innerHTML = '';
    ACCENTS.forEach(({ v, t }) => {
      const b = document.createElement('button');
      b.type = 'button';
      b.className = 'swatch' + (store.accent === v ? ' active' : '');
      b.title = t;
      b.style.background = v || 'linear-gradient(135deg, #8b7cf8, #6a5cf0)';
      b.addEventListener('click', () => {
        store.accent = v;
        accentColorInput.value = v || '#8b7cf8';
        renderAccentSwatches();
        applyAccent();
        save();
      });
      accentSwatchesEl.appendChild(b);
    });
  }

  function applyFontSize() {
    document.body.style.setProperty('--fs', store.font_size + 'px');
  }

  accentColorInput.addEventListener('input', () => {
    store.accent = accentColorInput.value;
    renderAccentSwatches();
    applyAccent();
    save();
  });

  let dimTimer = null;
  dimRange.addEventListener('input', () => {
    store.bg_dim = Number(dimRange.value);
    dimValue.textContent = `${store.bg_dim}%`;
    applyAppearance();
    clearTimeout(dimTimer);
    dimTimer = setTimeout(save, 200);
  });

  let fontTimer = null;
  fontRange.addEventListener('input', () => {
    store.font_size = Number(fontRange.value);
    fontValue.textContent = `${store.font_size} px`;
    applyFontSize();
    clearTimeout(fontTimer);
    fontTimer = setTimeout(save, 200);
  });

  // 打开设置面板 / 应用预设后，把所有外观控件同步到 store 当前值
  function syncAppearanceControls() {
    opacityRange.value = Math.round(store.bg_opacity * 100);
    opacityValue.textContent = `${Math.round(store.bg_opacity * 100)}%`;
    bgColorInput.value = store.bg_color || '#1b1e27';
    renderSwatches();
    blurToggle.checked = !!store.bg_blur_on;
    blurRange.value = store.bg_blur;
    syncBlurControls();
    accentColorInput.value = store.accent || '#8b7cf8';
    renderAccentSwatches();
    fontRange.value = store.font_size;
    fontValue.textContent = `${store.font_size} px`;
    bgImgClear.classList.toggle('hidden', !store.bg_image);
    bgHint.textContent = '不透明度低于 100% 可透出毛玻璃；压暗/模糊对背景图生效';
    renderPresets();
  }

  /* ---------- 设置面板 ---------- */
  function fmtHotkey(s) {
    return (s || '')
      .split('+')
      .map((p) => {
        const k = p.trim().toLowerCase();
        if (k === 'ctrl') return 'Ctrl';
        if (k === 'alt') return 'Alt';
        if (k === 'shift') return 'Shift';
        if (k === 'super' || k === 'meta' || k === 'command') return 'Win';
        if (/^f\d+$/.test(k)) return k.toUpperCase();
        if (k === 'space') return 'Space';
        if (k.startsWith('arrow')) return 'Arrow' + k.slice(5).toLowerCase().replace(/^./, (c) => c.toUpperCase());
        return k.length === 1 ? k.toUpperCase() : k;
      })
      .join(' + ');
  }

  function openSettings() {
    hotkeyDisplay.textContent = fmtHotkey(store.hotkey || 'ctrl+alt+m');
    labelInput.value = store.label || '';
    widthRange.value = store.width;
    widthValue.textContent = `${store.width} px`;
    edgeWidthRange.value = store.edge_width;
    edgeWidthValue.textContent = `${store.edge_width} px`;
    hotkeyHint.textContent = '任意界面唤出 / 隐藏面板';
    hotkeyRow.classList.remove('recording');
    applyEdge();
    applyRetractUI();
    syncAppearanceControls();
    refreshAutostart();
    refreshBackupStatus();
    settingsEl.classList.remove('hidden');
    settingsEl.classList.remove('slide-in');
    void settingsEl.offsetWidth;
    settingsEl.classList.add('slide-in');
  }

  function closeSettings() {
    if (hotkeyRecording) stopRecording();
    settingsEl.classList.add('hidden');
  }

  settingsBtn.addEventListener('click', openSettings);
  settingsBack.addEventListener('click', closeSettings);

  /* ---------- 开机自启 ---------- */
  async function refreshAutostart() {
    if (!invoke) return;
    try {
      autoStartToggle.checked = await invoke('get_autostart');
    } catch (e) { /* ignore */ }
  }

  autoStartToggle.addEventListener('change', async () => {
    if (!invoke) {
      autoStartToggle.checked = false;
      return;
    }
    try {
      await invoke('set_autostart', { enable: autoStartToggle.checked });
    } catch (e) {
      autoStartToggle.checked = !autoStartToggle.checked;
    }
  });

  /* ---------- 数据与备份 ---------- */
  const backupHint = $('#backupHint');
  const openBackupsBtn = $('#openBackups');

  async function refreshBackupStatus() {
    if (!invoke) return;
    try {
      const s = await invoke('backup_status');
      backupHint.textContent = s.count
        ? `已备份 ${s.count} 份 · 上次 ${fmtTime(s.last)}`
        : '每次修改自动留档，保留最近 10 份';
    } catch (e) { /* ignore */ }
  }

  openBackupsBtn.addEventListener('click', () => {
    if (invoke) invoke('open_backups').catch(() => {});
  });

  /* ---------- 快捷键录制 ---------- */
  function keyNameFromEvent(e) {
    const c = e.code || '';
    if (/^Key[A-Z]$/.test(c)) return c.slice(3).toLowerCase();
    if (/^Digit[0-9]$/.test(c)) return c.slice(5);
    if (/^F([1-9]|1[0-2])$/.test(c)) return c.toLowerCase();
    if (/^Arrow(Up|Down|Left|Right)$/.test(c)) return c.toLowerCase();
    if (c === 'Space') return 'space';
    // 部分注入的按键没有扫描码（e.code 为空），回退到 e.key
    if (!c && e.key) {
      const k = e.key.toLowerCase();
      if (/^[a-z0-9]$/.test(k)) return k;
      if (/^f([1-9]|1[0-2])$/.test(k)) return k;
    }
    return null;
  }

  function stopRecording() {
    hotkeyRecording = false;
    hotkeyRow.classList.remove('recording');
    hotkeyHint.textContent = '任意界面唤出 / 隐藏面板';
  }

  async function finishRecording(combo) {
    hotkeyRecording = false;
    hotkeyRow.classList.remove('recording');
    const old = store.hotkey || 'ctrl+alt+m';
    try {
      await invoke('set_shortcut', { old, new: combo });
      store.hotkey = combo;
      save();
      hotkeyDisplay.textContent = fmtHotkey(combo);
      hotkeyHint.textContent = '已生效，任意界面唤出 / 隐藏面板';
    } catch (e) {
      hotkeyHint.textContent = String(e);
    }
  }

  hotkeyEdit.addEventListener('click', () => {
    if (hotkeyRecording) return;
    hotkeyRecording = true;
    hotkeyRow.classList.add('recording');
    hotkeyHint.textContent = '请按下新的快捷键（Esc 取消）';
  });

  document.addEventListener(
    'keydown',
    (e) => {
      if (!hotkeyRecording) return;
      e.preventDefault();
      e.stopPropagation();
      if (e.key === 'Escape') {
        stopRecording();
        return;
      }
      if (['Control', 'Alt', 'Shift', 'Meta'].includes(e.key)) return; // 等主键
      const mods = [];
      if (e.ctrlKey) mods.push('ctrl');
      if (e.altKey) mods.push('alt');
      if (e.shiftKey) mods.push('shift');
      if (e.metaKey) mods.push('super');
      const key = keyNameFromEvent(e);
      if (!key) {
        hotkeyHint.textContent = '暂不支持该按键，请用字母 / 数字 / F 键 / 方向键 / 空格';
        return;
      }
      if (!mods.length) {
        hotkeyHint.textContent = '至少需要一个修饰键（Ctrl / Alt / Shift）';
        return;
      }
      finishRecording([...mods, key].join('+'));
    },
    true
  );

  /* ---------- 悬浮窗描述 / 宽度 ---------- */
  let labelTimer = null;
  labelInput.addEventListener('input', () => {
    store.label = labelInput.value;
    applyEdge();
    clearTimeout(labelTimer);
    labelTimer = setTimeout(save, 300);
  });

  let widthTimer = null;
  widthRange.addEventListener('input', () => {
    const v = Number(widthRange.value);
    widthValue.textContent = `${v} px`;
    clearTimeout(widthTimer);
    widthTimer = setTimeout(() => {
      store.width = v;
      save();
      if (invoke) invoke('set_width', { width: v }).catch(() => {});
    }, 200);
  });

  /* ---------- 标签页 ---------- */
  function activeTab() {
    return store.active_tab === 'notes' ? 'notes' : 'memos';
  }

  function switchTab(tab, skipSave) {
    store.active_tab = tab;
    tabMemos.classList.toggle('active', tab === 'memos');
    tabNotes.classList.toggle('active', tab === 'notes');
    viewMemos.classList.toggle('hidden', tab !== 'memos');
    viewNotes.classList.toggle('hidden', tab !== 'notes');
    render();
    if (!skipSave) save();
  }

  tabMemos.addEventListener('click', () => switchTab('memos'));
  tabNotes.addEventListener('click', () => switchTab('notes'));

  /* ---------- 时间显示 ---------- */
  function fmtTime(ts) {
    const d = new Date(ts);
    const now = new Date();
    const diff = now - ts;
    if (diff < 60_000) return '刚刚';
    if (diff < 3_600_000) return `${Math.floor(diff / 60_000)} 分钟前`;
    const hm = `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`;
    const sameDay = (a, b) => a.toDateString() === b.toDateString();
    if (sameDay(d, now)) return `今天 ${hm}`;
    const yest = new Date(now);
    yest.setDate(now.getDate() - 1);
    if (sameDay(d, yest)) return `昨天 ${hm}`;
    return `${d.getMonth() + 1}-${String(d.getDate()).padStart(2, '0')} ${hm}`;
  }

  /* ---------- 通用 ---------- */
  function opBtn(icon, title) {
    const b = document.createElement('button');
    b.className = 'opbtn';
    b.title = title;
    b.innerHTML = icon;
    return b;
  }

  function autosize(ta) {
    ta.style.height = 'auto';
    ta.style.height = Math.min(ta.scrollHeight, 200) + 'px';
  }

  /* ---------- 备忘：渲染 ---------- */
  function sortedMemos() {
    const q = memoFilter.trim().toLowerCase();
    return store.memos
      .filter((m) => !q || m.content.toLowerCase().includes(q))
      .sort((a, b) => (b.pinned - a.pinned) || (b.updated_at - a.updated_at));
  }

  function card(m, i) {
    const el = document.createElement('article');
    el.className = 'card' + (m.done ? ' done' : '') + (m.pinned ? ' pinned' : '');
    if (firstRender) el.style.animationDelay = `${Math.min(i, 10) * 24}ms`;

    const check = document.createElement('button');
    check.className = 'check';
    check.title = m.done ? '标记为未完成' : '标记为完成';
    check.innerHTML = ICONS.check;
    check.addEventListener('click', () => {
      m.done = !m.done;
      m.updated_at = Date.now();
      save();
      render();
    });

    const body = document.createElement('div');
    body.className = 'body';
    const text = document.createElement('div');
    text.className = 'text clamp';
    text.textContent = m.content;
    text.title = '双击编辑';
    const meta = document.createElement('div');
    meta.className = 'meta' + (m.remind_at && !m.reminded ? ' reminding' : '');
    meta.textContent = (m.pinned ? '📌 ' : '') + remindLabel(m) + fmtTime(m.updated_at);
    const more = document.createElement('button');
    more.className = 'more hidden';
    more.addEventListener('click', (e) => {
      e.stopPropagation();
      const clamped = text.classList.toggle('clamp');
      more.textContent = clamped ? '展开' : '收起';
      if (!clamped) text.dataset.expanded = '1';
      else delete text.dataset.expanded;
    });
    const metaRow = document.createElement('div');
    metaRow.className = 'metaRow';
    metaRow.append(meta, more);
    body.append(text, metaRow);

    const ops = document.createElement('div');
    ops.className = 'ops';
    const bell = opBtn(
      m.remind_at && !m.reminded ? ICONS.bellActive : ICONS.bell,
      '提醒'
    );
    if (m.remind_at && !m.reminded) bell.classList.add('active');
    bell.addEventListener('click', (e) => {
      e.stopPropagation();
      openRemindPop(e.currentTarget, m);
    });
    const pin = opBtn(m.pinned ? ICONS.pinFilled : ICONS.pin, m.pinned ? '取消置顶' : '置顶');
    if (m.pinned) pin.classList.add('active');
    pin.addEventListener('click', () => {
      m.pinned = !m.pinned;
      m.updated_at = Date.now();
      save();
      render();
    });
    const edit = opBtn(ICONS.edit, '编辑');
    edit.addEventListener('click', () => startEdit(m, el, text));
    const del = opBtn(ICONS.trash, '删除');
    del.classList.add('danger');
    del.addEventListener('click', () => {
      el.classList.add('removing');
      setTimeout(() => {
        store.memos = store.memos.filter((x) => x.id !== m.id);
        save();
        render();
      }, 170);
    });
    ops.append(bell, pin, edit, del);

    text.addEventListener('dblclick', () => startEdit(m, el, text));

    el.append(check, body, ops);
    return el;
  }

  function startEdit(m, el, text) {
    if (el.querySelector('textarea.edit')) return;
    const ta = document.createElement('textarea');
    ta.className = 'edit';
    ta.value = m.content;
    text.replaceWith(ta);
    ta.focus();
    ta.setSelectionRange(ta.value.length, ta.value.length);
    autosize(ta);
    ta.addEventListener('input', () => autosize(ta));
    const commit = () => {
      const v = ta.value.trim();
      if (v) {
        m.content = v;
        m.updated_at = Date.now();
        save();
      }
      render();
    };
    ta.addEventListener('blur', commit);
    ta.addEventListener('keydown', (e) => {
      if (e.key === 'Enter' && !e.shiftKey) {
        e.preventDefault();
        ta.removeEventListener('blur', commit);
        commit();
      } else if (e.key === 'Escape') {
        e.stopPropagation();
        ta.removeEventListener('blur', commit);
        render();
      }
    });
  }

  function emptyMemos() {
    const d = document.createElement('div');
    d.className = 'empty';
    const big = document.createElement('div');
    big.className = 'big';
    big.innerHTML = ICONS.note;
    const title = document.createElement('div');
    title.className = 'title';
    title.textContent = '一切尽在掌握';
    const sub = document.createElement('div');
    sub.className = 'sub';
    sub.append(
      document.createTextNode('在上方输入第一条备忘，或按 '),
      Object.assign(document.createElement('kbd'), { textContent: 'Ctrl + Alt + M' }),
      document.createTextNode(' 随时唤出')
    );
    d.append(big, title, sub);
    return d;
  }

  function noResults(text) {
    const d = document.createElement('div');
    d.className = 'empty';
    const title = document.createElement('div');
    title.className = 'title';
    title.textContent = text;
    d.append(title);
    return d;
  }

  function renderMemos() {
    listEl.innerHTML = '';
    const items = sortedMemos();
    const total = store.memos.length;
    const doneCount = total - store.memos.filter((m) => !m.done).length;
    countEl.textContent = total ? `${total} 条备忘 · ${total - doneCount} 条待办` : '';
    clearBtn.classList.toggle('hidden', doneCount === 0);

    if (!total) {
      listEl.appendChild(emptyMemos());
      return;
    }
    if (!items.length) {
      listEl.appendChild(noResults('没有找到匹配的备忘'));
      return;
    }
    items.forEach((m, i) => listEl.appendChild(card(m, i)));
    detectClamps(listEl);
  }

  // 渲染后检测哪些备忘超过 6 行，显示"展开"按钮
  function detectClamps(root) {
    requestAnimationFrame(() => {
      root.querySelectorAll('.card').forEach((c) => {
        const t = c.querySelector('.text');
        const more = c.querySelector('.more');
        if (!t || !more || t.dataset.expanded) return;
        if (t.scrollHeight > t.clientHeight + 2) {
          more.classList.remove('hidden');
          more.textContent = '展开';
        } else {
          more.classList.add('hidden');
        }
      });
    });
  }

  /* ---------- 笔记：列表（分组 / 标签 / 归档） ---------- */
  function extractTags(n) {
    const found = [];
    for (const m of (`${n.title}\n${n.content}`).matchAll(TAG_RE)) {
      const t = m[1].trim();
      if (t && !found.includes(t)) found.push(t);
    }
    return found;
  }

  function dayGroup(ts) {
    const d = new Date(ts);
    const now = new Date();
    const day0 = (x) => {
      const t = new Date(x);
      t.setHours(0, 0, 0, 0);
      return t;
    };
    const diffDays = Math.round((day0(now) - day0(d)) / 86_400_000);
    if (diffDays <= 0) return '今天';
    if (diffDays === 1) return '昨天';
    const monday = day0(now);
    monday.setDate(monday.getDate() - ((now.getDay() + 6) % 7));
    if (d >= monday) return '本周';
    if (d.getFullYear() === now.getFullYear() && d.getMonth() === now.getMonth()) return '本月';
    return '更早';
  }

  function sortedNotes() {
    const q = noteFilter.trim().toLowerCase();
    return store.notes
      .filter((n) => !!n.archived === viewArchived)
      .filter((n) => !q || n.title.toLowerCase().includes(q) || n.content.toLowerCase().includes(q))
      .filter((n) => !tagFilter || extractTags(n).includes(tagFilter))
      .sort((a, b) => (b.pinned - a.pinned) || (b.updated_at - a.updated_at));
  }

  function snippet(n) {
    const line = (n.content.split('\n').find((l) => l.trim()) || '').replace(/\s+/g, ' ').trim();
    let s = line.replace(IMG_RE, '[图片]');
    s = s
      .replace(/^#+\s+/, '')
      .replace(/^>\s?/, '')
      .replace(/\*\*|__|~~|`/g, '')
      .replace(/\[([^\]]+)\]\([^)]*\)/g, '$1');
    return s.length > 90 ? s.slice(0, 90) + '…' : s;
  }

  function noteCard(n, i) {
    const el = document.createElement('article');
    el.className = 'note-card' + (n.pinned ? ' pinned' : '');
    if (firstRender) el.style.animationDelay = `${Math.min(i, 10) * 24}ms`;

    const body = document.createElement('div');
    body.className = 'n-body';

    const meta = document.createElement('div');
    meta.className = 'n-meta';
    const imgCount = (n.content.match(IMG_RE) || []).length;
    meta.textContent =
      (n.pinned ? '📌 ' : '') + (imgCount ? `📷${imgCount} ` : '') + fmtTime(n.updated_at);

    // 标题/摘要里的 #标签 高亮
    const highlight = (container, s) => {
      const parts = s.split(TAG_RE);
      parts.forEach((p, idx) => {
        if (idx % 2 === 1) {
          const sp = document.createElement('span');
          sp.className = 'tag-inline';
          sp.textContent = '#' + p;
          container.append(sp);
        } else if (p) {
          container.append(document.createTextNode(p));
        }
      });
    };

    const title = document.createElement('div');
    title.className = 'n-title';
    const t = n.title.trim();
    if (t) highlight(title, t);
    else {
      title.textContent = '无标题';
      title.classList.add('untitled');
    }

    const snip = document.createElement('div');
    snip.className = 'n-snip';
    const s = snippet(n);
    if (s) {
      highlight(snip, s);
    } else {
      snip.style.display = 'none';
    }

    body.append(title, snip, meta);
    body.addEventListener('click', () => openEditor(n));

    const ops = document.createElement('div');
    ops.className = 'ops';
    if (!n.archived) {
      const pin = opBtn(n.pinned ? ICONS.pinFilled : ICONS.pin, n.pinned ? '取消置顶' : '置顶');
      if (n.pinned) pin.classList.add('active');
      pin.addEventListener('click', () => {
        n.pinned = !n.pinned;
        n.updated_at = Date.now();
        save();
        render();
      });
      ops.append(pin);
    }
    const arch = opBtn(ICONS.archive, n.archived ? '取消归档' : '归档');
    if (n.archived) arch.classList.add('active');
    arch.addEventListener('click', () => {
      n.archived = !n.archived;
      save();
      render();
    });
    ops.append(arch);
    const del = opBtn(ICONS.trash, '删除');
    del.classList.add('danger');
    let armed = false;
    let armTimer = null;
    del.addEventListener('click', () => {
      if (!armed) {
        armed = true;
        del.classList.add('confirm');
        del.innerHTML = '';
        del.textContent = '确认删除';
        armTimer = setTimeout(() => {
          armed = false;
          del.classList.remove('confirm');
          del.innerHTML = ICONS.trash;
        }, 2500);
      } else {
        clearTimeout(armTimer);
        el.classList.add('removing');
        setTimeout(() => {
          store.notes = store.notes.filter((x) => x.id !== n.id);
          save();
          render();
        }, 170);
      }
    });
    ops.append(del);

    el.append(body, ops);
    return el;
  }

  function emptyNotes() {
    const d = document.createElement('div');
    d.className = 'empty';
    const big = document.createElement('div');
    big.className = 'big';
    big.innerHTML = ICONS.note;
    const title = document.createElement('div');
    title.className = 'title';
    title.textContent = '记点长的：方案、灵感、摘抄';
    const sub = document.createElement('div');
    sub.className = 'sub';
    sub.textContent = '点击上方「新建笔记」开始，自动保存';
    d.append(big, title, sub);
    return d;
  }

  function renderNotes() {
    noteListEl.innerHTML = '';
    const pool = store.notes.filter((n) => !!n.archived === viewArchived);
    const archivedCount = store.notes.filter((n) => n.archived).length;

    // 标签筛选条（来自当前视图的笔记）
    const tagCounts = new Map();
    pool.forEach((n) => {
      extractTags(n).forEach((t) => tagCounts.set(t, (tagCounts.get(t) || 0) + 1));
    });
    if (tagFilter && !tagCounts.has(tagFilter)) tagFilter = '';
    renderChips(tagCounts, pool.length, archivedCount);

    const items = sortedNotes();
    countEl.textContent = pool.length
      ? viewArchived
        ? `${pool.length} 篇已归档`
        : `${pool.length} 篇笔记`
      : '';
    clearBtn.classList.add('hidden');

    if (!pool.length) {
      noteListEl.appendChild(viewArchived ? noResults('还没有归档的笔记') : emptyNotes());
      return;
    }
    if (!items.length) {
      noteListEl.appendChild(noResults('没有找到匹配的笔记'));
      return;
    }

    if (viewArchived) {
      items.forEach((n, i) => noteListEl.appendChild(noteCard(n, i)));
      return;
    }
    let lastGroup = null;
    items.forEach((n, i) => {
      const g = n.pinned ? '📌 置顶' : dayGroup(n.updated_at);
      if (g !== lastGroup) {
        const h = document.createElement('div');
        h.className = 'group-head';
        h.textContent = g;
        noteListEl.appendChild(h);
        lastGroup = g;
      }
      noteListEl.appendChild(noteCard(n, i));
    });
  }

  function renderChips(tagCounts, activeCount, archivedCount) {
    tagChipsEl.innerHTML = '';
    archiveToggle.textContent = archivedCount ? `归档 ${archivedCount}` : '归档';
    archiveToggle.classList.toggle('active', viewArchived);
    if (!tagCounts.size) {
      tagChipsEl.classList.add('hidden');
      return;
    }
    tagChipsEl.classList.remove('hidden');
    const mk = (label, count, active, fn) => {
      const b = document.createElement('button');
      b.className = 'chip' + (active ? ' active' : '');
      b.type = 'button';
      b.append(document.createTextNode(label));
      if (count !== null) {
        const s = document.createElement('span');
        s.className = 'n';
        s.textContent = count;
        b.append(s);
      }
      b.addEventListener('click', fn);
      return b;
    };
    tagChipsEl.append(
      mk('全部', activeCount, !tagFilter, () => {
        if (!tagFilter) return;
        tagFilter = '';
        render();
      })
    );
    [...tagCounts.entries()]
      .sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0]))
      .forEach(([t, c]) => {
        tagChipsEl.append(
          mk(t, c, tagFilter === t, () => {
            tagFilter = tagFilter === t ? '' : t;
            render();
          })
        );
      });
  }

  function render() {
    if (activeTab() === 'notes') renderNotes();
    else renderMemos();
  }

  /* ---------- 图片 ---------- */
  async function ensureImagesDir() {
    if (!imagesDirAbs && invoke) {
      try {
        imagesDirAbs = await invoke('images_dir_cmd');
      } catch (e) {
        console.error('images_dir failed', e);
      }
    }
    return imagesDirAbs;
  }

  function imgSrc(file) {
    if (!imagesDirAbs) return '';
    return window.__TAURI__.core.convertFileSrc(imagesDirAbs + '\\' + file);
  }

  function imgNode(file) {
    const img = document.createElement('img');
    img.className = 'editor-img';
    img.dataset.file = file;
    img.src = imgSrc(file);
    img.alt = '图片';
    img.contentEditable = 'false';
    img.draggable = false;
    return img;
  }

  // 正文（纯文本标记）→ 编辑器 DOM
  function buildContentInto(root, content) {
    root.innerHTML = '';
    let last = 0;
    for (const m of content.matchAll(IMG_RE)) {
      if (m.index > last) {
        root.appendChild(document.createTextNode(content.slice(last, m.index)));
      }
      root.appendChild(imgNode(m[1]));
      last = m.index + m[0].length;
    }
    if (last < content.length) {
      root.appendChild(document.createTextNode(content.slice(last)));
    }
  }

  // 编辑器 DOM → 正文（纯文本标记）
  function serializeContent(root) {
    let out = '';
    for (const node of root.childNodes) {
      if (node.nodeType === Node.TEXT_NODE) {
        out += node.nodeValue;
      } else if (node.nodeType === Node.ELEMENT_NODE) {
        if (node.tagName === 'IMG' && node.dataset.file) {
          out += `![img](sidememo-img://${node.dataset.file})`;
        } else {
          out += serializeContent(node);
        }
      }
    }
    return out;
  }

  async function insertImageFromFile(file) {
    if (!file || !invoke) return;
    if (file.size > 15 * 1024 * 1024) {
      setSaveState('图片超过 15MB');
      return;
    }
    try {
      const buf = new Uint8Array(await file.arrayBuffer());
      const name = await invoke('save_image', buf);
      insertImgNodeAtCaret(name);
      scheduleNoteSave();
      updateCharCount();
    } catch (e) {
      console.error('save_image failed', e);
      setSaveState('图片保存失败');
    }
  }

  function insertImgNodeAtCaret(file) {
    noteBodyEl.focus();
    const sel = window.getSelection();
    const img = imgNode(file);
    const caretOk = sel && sel.rangeCount > 0 && noteBodyEl.contains(sel.getRangeAt(0).startContainer);
    if (!caretOk) {
      if (serializeContent(noteBodyEl) && !serializeContent(noteBodyEl).endsWith('\n')) {
        noteBodyEl.appendChild(document.createTextNode('\n'));
      }
      noteBodyEl.appendChild(img);
      return;
    }
    const range = sel.getRangeAt(0);
    const beforeRange = document.createRange();
    beforeRange.setStart(noteBodyEl, 0);
    beforeRange.setEnd(range.startContainer, range.startOffset);
    const beforeText = beforeRange.toString();
    const afterRange = document.createRange();
    afterRange.setStart(range.startContainer, range.startOffset);
    afterRange.setEnd(noteBodyEl, noteBodyEl.childNodes.length);
    const afterText = afterRange.toString();

    range.deleteContents();
    const frag = document.createDocumentFragment();
    if (beforeText && !beforeText.endsWith('\n')) {
      frag.appendChild(document.createTextNode('\n'));
    }
    frag.appendChild(img);
    if (afterText && !afterText.startsWith('\n')) {
      frag.appendChild(document.createTextNode('\n'));
    }
    range.insertNode(frag);

    const r2 = document.createRange();
    r2.setStartAfter(img);
    r2.collapse(true);
    sel.removeAllRanges();
    sel.addRange(r2);
  }

  imgBtn.addEventListener('click', () => imgFile.click());
  imgFile.addEventListener('change', () => {
    const f = imgFile.files && imgFile.files[0];
    if (f) insertImageFromFile(f);
    imgFile.value = '';
  });

  // 粘贴：图片直接插入，文本走纯文本
  noteBodyEl.addEventListener('paste', (e) => {
    e.preventDefault();
    const cd = e.clipboardData;
    if (!cd) return;
    const item = [...(cd.items || [])].find(
      (i) => i.kind === 'file' && i.type.startsWith('image/')
    );
    if (item) {
      insertImageFromFile(item.getAsFile());
      return;
    }
    const text = cd.getData('text/plain');
    if (text) document.execCommand('insertText', false, text);
  });

  noteBodyEl.addEventListener('keydown', (e) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      document.execCommand('insertText', false, '\n');
    } else if (e.key === 'Escape') {
      e.stopPropagation();
      if (!lightboxEl.classList.contains('hidden')) {
        lightboxEl.classList.add('hidden');
      } else {
        backToList();
      }
    }
  });

  // 点击图片放大预览
  noteBodyEl.addEventListener('click', (e) => {
    const img = e.target.closest('.editor-img');
    if (img && img.src) {
      lightboxImg.src = img.src;
      lightboxEl.classList.remove('hidden');
    }
  });
  lightboxEl.addEventListener('click', () => lightboxEl.classList.add('hidden'));

  /* ---------- Markdown 渲染 ---------- */
  function escHtml(s) {
    return s
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;');
  }

  function fmtPlain(s) {
    let h = escHtml(s);
    h = h.replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>');
    h = h.replace(/~~([^~]+)~~/g, '<del>$1</del>');
    h = h.replace(/\*([^*\n]+)\*/g, '<em>$1</em>');
    h = h.replace(/\[([^\]]+)\]\(([^)\s]+)\)/g, (m0, t, u) => {
      const safe = /^(https?:\/\/|mailto:)/i.test(u) ? u : '#';
      return `<a href="${escHtml(safe)}" data-href="${escHtml(safe)}">${t}</a>`;
    });
    return h;
  }

  function inlineText(s) {
    let out = '';
    let last = 0;
    for (const m of s.matchAll(/`([^`\n]+)`/g)) {
      out += fmtPlain(s.slice(last, m.index));
      out += '<code>' + escHtml(m[1]) + '</code>';
      last = m.index + m[0].length;
    }
    out += fmtPlain(s.slice(last));
    return out;
  }

  // 行内：先拆图片标记，其余走文本渲染
  function inlineLine(line) {
    const parts = [];
    let last = 0;
    for (const m of line.matchAll(IMG_RE)) {
      if (m.index > last) parts.push({ t: 'text', v: line.slice(last, m.index) });
      parts.push({ t: 'img', file: m[1] });
      last = m.index + m[0].length;
    }
    if (last < line.length) parts.push({ t: 'text', v: line.slice(last) });
    return parts
      .map((p) =>
        p.t === 'img'
          ? `<img class="preview-img" src="${escHtml(imgSrc(p.file))}" data-file="${escHtml(p.file)}" alt="图片" draggable="false">`
          : inlineText(p.v)
      )
      .join('');
  }

  function renderMarkdown(src) {
    const lines = src.split('\n');
    const out = [];
    let i = 0;
    let para = [];

    const flushPara = () => {
      if (para.length) {
        out.push('<p>' + para.map(inlineLine).join('<br>') + '</p>');
        para = [];
      }
    };

    while (i < lines.length) {
      const line = lines[i];

      // 围栏代码块
      if (/^\s*```/.test(line)) {
        flushPara();
        const buf = [];
        i++;
        while (i < lines.length && !/^\s*```/.test(lines[i])) {
          buf.push(lines[i]);
          i++;
        }
        i++;
        out.push('<pre><code>' + escHtml(buf.join('\n')) + '</code></pre>');
        continue;
      }

      if (!line.trim()) {
        flushPara();
        i++;
        continue;
      }

      const h = line.match(/^(#{1,6})\s+(.*)/);
      if (h) {
        flushPara();
        const lv = Math.min(h[1].length, 3);
        out.push(`<h${lv}>` + inlineText(h[2]) + `</h${lv}>`);
        i++;
        continue;
      }

      if (/^\s*(-{3,}|\*{3,})\s*$/.test(line)) {
        flushPara();
        out.push('<hr>');
        i++;
        continue;
      }

      if (/^\s*>\s?/.test(line)) {
        flushPara();
        const buf = [];
        while (i < lines.length && /^\s*>\s?/.test(lines[i])) {
          buf.push(lines[i].replace(/^\s*>\s?/, ''));
          i++;
        }
        out.push('<blockquote>' + buf.map(inlineLine).join('<br>') + '</blockquote>');
        continue;
      }

      // 列表（无序 / 有序 / 任务清单）
      if (/^\s*[-*]\s+/.test(line) || /^\s*\d+[.)]\s+/.test(line)) {
        flushPara();
        const isOrdered = /^\s*\d+[.)]\s+/.test(line);
        const items = [];
        while (i < lines.length) {
          if (isOrdered) {
            const m = lines[i].match(/^\s*\d+[.)]\s+(.*)/);
            if (!m) break;
            items.push({ task: null, text: m[1] });
            i++;
          } else {
            const m = lines[i].match(/^\s*[-*]\s+(.*)/);
            if (!m) break;
            const t = m[1].match(/^\[( |x|X)\]\s+(.*)/);
            items.push({ task: t ? t[1] !== ' ' : null, text: t ? t[2] : m[1] });
            i++;
          }
        }
        if (isOrdered) {
          out.push('<ol>' + items.map((it) => '<li>' + inlineText(it.text) + '</li>').join('') + '</ol>');
        } else {
          const anyTask = items.some((it) => it.task !== null);
          out.push(
            '<ul class="' + (anyTask ? 'task-list' : '') + '">' +
              items
                .map((it) =>
                  it.task !== null
                    ? `<li class="task"><input type="checkbox" disabled${it.task ? ' checked' : ''}><span>` +
                        inlineText(it.text) +
                        '</span></li>'
                    : '<li>' + inlineText(it.text) + '</li>'
                )
                .join('') +
            '</ul>'
          );
        }
        continue;
      }

      para.push(line);
      i++;
    }
    flushPara();
    return out.join('\n');
  }

  /* ---------- 编辑 / 预览切换 ---------- */
  function setMode(mode) {
    editorMode = mode;
    if (mode === 'preview') {
      doSaveNote();
      const n = currentNote();
      notePreviewEl.innerHTML = renderMarkdown(n ? n.content : '');
      noteBodyEl.classList.add('hidden');
      notePreviewEl.classList.remove('hidden');
      mdBtn.innerHTML = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M17 3a2.83 2.83 0 1 1 4 4L7.5 20.5 2 22l1.5-5.5Z"/></svg>';
      mdBtn.title = '返回编辑';
    } else {
      notePreviewEl.classList.add('hidden');
      noteBodyEl.classList.remove('hidden');
      mdBtn.innerHTML = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M2 12s3-7 10-7 10 7 10 7-3 7-10 7-10-7-10-7Z"/><circle cx="12" cy="12" r="3"/></svg>';
      mdBtn.title = '预览 Markdown';
      // 光标放到正文末尾
      const r = document.createRange();
      r.selectNodeContents(noteBodyEl);
      r.collapse(false);
      const sel = window.getSelection();
      if (sel) {
        sel.removeAllRanges();
        sel.addRange(r);
      }
    }
  }

  mdBtn.addEventListener('click', () => {
    if (editorMode === 'edit') setMode('preview');
    else {
      setMode('edit');
      noteBodyEl.focus();
    }
  });

  // 预览里：点图片放大，点链接用系统浏览器打开
  notePreviewEl.addEventListener('click', (e) => {
    const img = e.target.closest('.preview-img');
    if (img && img.src) {
      lightboxImg.src = img.src;
      lightboxEl.classList.remove('hidden');
      return;
    }
    const link = e.target.closest('a[data-href]');
    if (link && invoke) {
      e.preventDefault();
      invoke('open_external', { url: link.dataset.href }).catch(() => {});
    }
  });

  /* ---------- 笔记：编辑器 ---------- */
  function currentNote() {
    return store.notes.find((n) => n.id === currentNoteId) || null;
  }

  function setSaveState(text) {
    saveStateEl.textContent = text;
  }

  function updateEditorMeta(n) {
    editorMeta.textContent = n.updated_at ? '修改于 ' + fmtTime(n.updated_at) : '';
  }

  function updateCharCount() {
    const content = serializeContent(noteBodyEl);
    const imgCount = (content.match(IMG_RE) || []).length;
    const len = content.replace(IMG_RE, '').length;
    charCountEl.textContent = len + (imgCount ? ` 字 · ${imgCount} 图` : '');
  }

  function openEditor(n) {
    currentNoteId = n.id;
    noteTitleEl.value = n.title;
    buildContentInto(noteBodyEl, n.content);
    updateEditorMeta(n);
    updateCharCount();
    setSaveState('');
    lightboxEl.classList.add('hidden');
    editorEl.classList.remove('hidden');
    editorEl.classList.remove('slide-in');
    void editorEl.offsetWidth;
    editorEl.classList.add('slide-in');
    setMode('edit');
    if (n.title.trim()) noteBodyEl.focus();
    else noteTitleEl.focus();
  }

  function doSaveNote() {
    const n = currentNote();
    if (!n) return;
    let changed = false;
    const content = serializeContent(noteBodyEl);
    if (n.title !== noteTitleEl.value) {
      n.title = noteTitleEl.value;
      changed = true;
    }
    if (n.content !== content) {
      n.content = content;
      changed = true;
    }
    if (changed) {
      n.updated_at = Date.now();
      save();
    }
    setSaveState('已保存 · ' + fmtTime(n.updated_at));
    updateEditorMeta(n);
  }

  function scheduleNoteSave() {
    setSaveState('编辑中…');
    clearTimeout(noteTimer);
    noteTimer = setTimeout(doSaveNote, 400);
  }

  function noteIsEmpty(n) {
    return !n.title.trim() && !n.content.trim();
  }

  function backToList() {
    clearTimeout(noteTimer);
    doSaveNote();
    // 空白笔记（新建后什么都没写）直接清除
    const n = currentNote();
    if (n && noteIsEmpty(n)) {
      store.notes = store.notes.filter((x) => x.id !== n.id);
      save();
    }
    currentNoteId = null;
    editorEl.classList.add('hidden');
    firstRender = false;
    render();
  }

  noteTitleEl.addEventListener('input', scheduleNoteSave);
  noteBodyEl.addEventListener('input', () => {
    scheduleNoteSave();
    updateCharCount();
  });
  noteTitleEl.addEventListener('keydown', (e) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      noteBodyEl.focus();
    } else if (e.key === 'Escape') {
      e.stopPropagation();
      backToList();
    }
  });
  backBtn.addEventListener('click', backToList);

  newNoteBtn.addEventListener('click', () => {
    const now = Date.now();
    const n = {
      id: crypto.randomUUID(),
      title: '',
      content: '',
      pinned: false,
      archived: false,
      created_at: now,
      updated_at: now,
    };
    store.notes.unshift(n);
    save();
    firstRender = false;
    if (viewArchived) {
      viewArchived = false;
      render();
    }
    openEditor(n);
  });

  /* ---------- 提醒 ---------- */
  function remindLabel(m) {
    if (!m.remind_at) return '';
    if (m.reminded) return '⏰ 已提醒 · ';
    const d = new Date(m.remind_at);
    const hm = `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`;
    const now = new Date();
    const day = d.toDateString() === now.toDateString() ? '今天' : `${d.getMonth() + 1}-${String(d.getDate()).padStart(2, '0')}`;
    return `⏰ ${day} ${hm} `;
  }

  function closeRemindPop() {
    document.querySelectorAll('.remindPop').forEach((p) => p.remove());
  }

  function openRemindPop(bellBtn, m) {
    const existed = bellBtn.parentElement.querySelector('.remindPop');
    closeRemindPop();
    if (existed) return;
    const pop = document.createElement('div');
    pop.className = 'remindPop';
    const set = (ts) => {
      m.remind_at = ts;
      m.reminded = false;
      m.updated_at = Date.now();
      save();
      closeRemindPop();
      render();
    };
    const mk = (label, fn, cls) => {
      const b = document.createElement('button');
      if (cls) b.className = cls;
      b.textContent = label;
      b.addEventListener('click', (ev) => {
        ev.stopPropagation();
        fn();
      });
      return b;
    };
    pop.append(
      mk('10 分钟', () => set(Date.now() + 10 * 60_000)),
      mk('1 小时', () => set(Date.now() + 3_600_000)),
      mk('明早 9 点', () => {
        const d = new Date();
        d.setDate(d.getDate() + 1);
        d.setHours(9, 0, 0, 0);
        set(d.getTime());
      }),
      mk('明天此时', () => set(Date.now() + 86_400_000))
    );
    const inp = document.createElement('input');
    inp.type = 'datetime-local';
    inp.addEventListener('click', (ev) => ev.stopPropagation());
    inp.addEventListener('keydown', (ev) => ev.stopPropagation());
    inp.addEventListener('change', () => {
      const t = new Date(inp.value).getTime();
      if (!isNaN(t)) set(t);
    });
    pop.append(inp);
    if (m.remind_at) {
      pop.append(mk('清除提醒', () => {
        m.remind_at = 0;
        m.reminded = false;
        save();
        closeRemindPop();
        render();
      }, 'full danger'));
    }
    bellBtn.parentElement.appendChild(pop);
  }

  document.addEventListener('click', (e) => {
    if (!e.target.closest('.remindPop') && !e.target.closest('.ops')) closeRemindPop();
  });

  // 每 5 秒检查到期提醒（面板隐藏时 webview 依然运行）
  function checkReminders() {
    if (!invoke || !Array.isArray(store.memos)) return;
    const now = Date.now();
    const due = store.memos.filter((m) => m.remind_at && !m.reminded && m.remind_at <= now);
    if (!due.length) return;
    due.forEach((m) => {
      m.reminded = true;
    });
    save();
    if (activeTab() === 'memos') render();
    invoke('fire_reminders', {
      items: due.map((m) => ({
        title: '备忘提醒',
        body: m.content.split('\n')[0].slice(0, 100),
      })),
    }).catch(() => {});
  }

  /* ---------- 备忘：新增 ---------- */
  function add() {
    const v = inputEl.value.trim();
    if (!v) return;
    const now = Date.now();
    store.memos.unshift({
      id: crypto.randomUUID(),
      content: v,
      done: false,
      pinned: false,
      created_at: now,
      updated_at: now,
    });
    inputEl.value = '';
    autosize(inputEl);
    firstRender = false;
    save();
    render();
    inputEl.focus();
  }

  inputEl.addEventListener('keydown', (e) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      add();
    }
  });
  inputEl.addEventListener('input', () => autosize(inputEl));
  $('#addBtn').addEventListener('click', add);

  /* ---------- 搜索 / 清除 / 快捷键 ---------- */
  searchMemosEl.addEventListener('input', () => {
    memoFilter = searchMemosEl.value;
    firstRender = false;
    render();
  });
  searchMemosEl.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && searchMemosEl.value) {
      e.stopPropagation();
      searchMemosEl.value = '';
      memoFilter = '';
      render();
    }
  });

  searchNotesEl.addEventListener('input', () => {
    noteFilter = searchNotesEl.value;
    firstRender = false;
    render();
  });
  searchNotesEl.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && searchNotesEl.value) {
      e.stopPropagation();
      searchNotesEl.value = '';
      noteFilter = '';
      render();
    }
  });

  archiveToggle.addEventListener('click', () => {
    viewArchived = !viewArchived;
    tagFilter = '';
    render();
  });

  clearBtn.addEventListener('click', () => {
    store.memos = store.memos.filter((m) => !m.done);
    save();
    render();
  });

  document.addEventListener('keydown', (e) => {
    if (e.key !== 'Escape') return;
    if (hotkeyRecording) return;
    if (!lightboxEl.classList.contains('hidden')) {
      lightboxEl.classList.add('hidden');
    } else if (editorMode === 'preview') {
      setMode('edit');
    } else if (!settingsEl.classList.contains('hidden')) {
      closeSettings();
    } else if (!editorEl.classList.contains('hidden')) {
      backToList();
    } else if (invoke) {
      invoke('hide_panel');
    }
  });

  // 窗口被快捷键唤出时，自动聚焦输入框
  window.addEventListener('focus', () => {
    if (document.activeElement === document.body && activeTab() === 'memos') inputEl.focus();
  });

  /* ---------- 启动 ---------- */
  (async () => {
    await load();
    await ensureImagesDir();
    applyAppearance();
    // 设置页底部带上版本号，方便用户确认自己在跑哪个版本
    try {
      const v = await window.__TAURI__.app.getVersion();
      const foot = document.querySelector('#setFoot') || document.querySelector('.setFoot');
      if (foot && v) foot.textContent = `数据保存在本地 · 侧边备忘录 v${v}`;
    } catch (e) { /* 无 Tauri 环境时保持原文案 */ }
    switchTab(activeTab(), true);
    inputEl.focus();
    setInterval(checkReminders, 5000);
    setTimeout(() => {
      firstRender = false;
    }, 600);
  })();
})();
