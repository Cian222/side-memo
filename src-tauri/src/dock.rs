//! 贴边停靠：窗口平时在屏幕左缘/右缘只露出一条把手/标签/完全隐藏（可在设置中选），
//! 鼠标靠近吸边一侧时滑出，鼠标离开且失焦一段时间后自动收回（可被"固定"禁用）。
//! 窗口尺寸全程保持展开尺寸不变（WebView 不重排、不出花屏/透底），
//! 收起与滑动过程用 SetWindowRgn 窗口区域在屏幕边缘处裁剪：
//! 被裁掉的部分不渲染也不拦截鼠标，双屏下绝不会压到相邻显示器的桌面。

use std::sync::atomic::{AtomicBool, AtomicI32, AtomicU32, AtomicU64, AtomicU8, Ordering};
use std::sync::{Mutex, MutexGuard};
use std::thread;
use std::time::{Duration, Instant};

use tauri::{App, AppHandle, Emitter, Manager, Monitor, PhysicalPosition, PhysicalSize, WebviewWindow};

const WIN_LABEL: &str = "sidebar";
const PANEL_DEFAULT_WIDTH: f64 = 340.0;
const PANEL_MIN_WIDTH: f64 = 280.0;
const PANEL_MAX_WIDTH: f64 = 480.0;
/// 收起状态的显示模式：0=描述标签 1=细把手 2=完全隐藏
pub const EDGE_LABEL: u8 = 0;
pub const EDGE_SLIVER: u8 = 1;
pub const EDGE_HIDDEN: u8 = 2;
/// 标签模式的最小逻辑宽度（竖排文字需要）
const LABEL_MIN_LOGICAL: f64 = 28.0;
/// 边条宽度范围（逻辑像素）
pub const EDGE_MIN_WIDTH: f64 = 8.0;
pub const EDGE_MAX_WIDTH: f64 = 48.0;
/// 鼠标距吸边多少像素内视为"想唤出"（至少覆盖收起宽度）
const EDGE_TRIGGER_PX: i32 = 12;
/// 判定"鼠标离开"时窗口外扩的余量
const LEAVE_MARGIN_PX: i32 = 32;
/// 失焦多久后收回（默认值；设置里可调 0~60000ms，0 为立即收回）
pub const DEFAULT_RETRACT_MS: u64 = 900;
const ANIM_STEPS: u32 = 10;
const FRAME_MS: u64 = 16;

#[derive(Clone, Copy, PartialEq, Eq, Debug)]
enum DockState {
    Expanded,
    Retracted,
    Hidden,
}

pub struct Dock {
    state: Mutex<DockState>,
    outside_since: Mutex<Option<Instant>>,
    pinned: AtomicBool,
    /// 收起显示模式（EDGE_*）
    mode: AtomicU8,
    /// 收起时露出的物理像素宽度（隐藏模式为 0）
    sliver: AtomicI32,
    /// 失焦收回延迟（毫秒）
    retract_ms: AtomicU64,
    /// 吸边侧：true=屏幕左缘，false=屏幕右缘
    side_left: AtomicBool,
    /// 面板展开宽度（逻辑像素）
    width_l: AtomicU32,
}

fn dock<'a>(app: &'a AppHandle) -> MutexGuard<'a, DockState> {
    app.state::<Dock>().inner().state.lock().unwrap()
}

pub fn store_json(app: &AppHandle) -> Option<serde_json::Value> {
    let p = app.path().app_data_dir().ok()?.join("memos.json");
    let s = std::fs::read_to_string(p).ok()?;
    serde_json::from_str(&s).ok()
}

fn store_bool(v: &Option<serde_json::Value>, key: &str, default: bool) -> bool {
    v.as_ref()
        .and_then(|j| j.get(key))
        .and_then(|b| b.as_bool())
        .unwrap_or(default)
}

fn store_f64(v: &Option<serde_json::Value>, key: &str, default: f64, min: f64, max: f64) -> f64 {
    v.as_ref()
        .and_then(|j| j.get(key))
        .and_then(|n| n.as_f64())
        .filter(|n| (*n >= min) && (*n <= max))
        .unwrap_or(default)
}

fn store_str(v: &Option<serde_json::Value>, key: &str) -> String {
    v.as_ref()
        .and_then(|j| j.get(key))
        .and_then(|s| s.as_str())
        .unwrap_or("")
        .to_string()
}

/// 依据模式与宽度计算收起露出宽度（逻辑像素），标签模式有最小宽度
fn effective_logical(mode: u8, width: f64) -> f64 {
    if mode == EDGE_LABEL {
        width.max(LABEL_MIN_LOGICAL)
    } else if mode == EDGE_HIDDEN {
        0.0
    } else {
        width
    }
}

fn sliver_physical(app: &AppHandle, mode: u8, width: f64) -> i32 {
    let scale = app
        .primary_monitor()
        .ok()
        .flatten()
        .map(|m| m.scale_factor())
        .unwrap_or(1.0);
    (effective_logical(mode, width) * scale).round() as i32
}

/// 光标所在的显示器（没有则回退主屏）——贴边唤出跟随光标所在屏幕
fn pick_monitor(app: &AppHandle) -> Option<Monitor> {
    if let Some((cx, cy)) = cursor_pos() {
        if let Ok(monitors) = app.available_monitors() {
            for m in monitors {
                let (mx, my) = (m.position().x, m.position().y);
                let (mw, mh) = (m.size().width as i32, m.size().height as i32);
                if cx >= mx && cx < mx + mw && cy >= my && cy < my + mh {
                    return Some(m);
                }
            }
        }
    }
    app.primary_monitor().ok().flatten()
}

/// 窗口中心点所在的显示器
fn monitor_of_window(app: &AppHandle, win: &WebviewWindow) -> Option<Monitor> {
    if let (Ok(pos), Ok(size)) = (win.outer_position(), win.outer_size()) {
        let cx = pos.x + size.width as i32 / 2;
        let cy = pos.y + size.height as i32 / 2;
        if let Ok(monitors) = app.available_monitors() {
            for m in monitors {
                let (mx, my) = (m.position().x, m.position().y);
                let (mw, mh) = (m.size().width as i32, m.size().height as i32);
                if cx >= mx && cx < mx + mw && cy >= my && cy < my + mh {
                    return Some(m);
                }
            }
        }
    }
    app.primary_monitor().ok().flatten()
}

/// 光标是否落在某块屏的吸边触发区
fn edge_hit(mon: &Monitor, cx: i32, cy: i32, sliver: i32, side_left: bool) -> bool {
    let (mx, my) = (mon.position().x, mon.position().y);
    let (mw, mh) = (mon.size().width as i32, mon.size().height as i32);
    let trigger = sliver.max(EDGE_TRIGGER_PX);
    if side_left {
        cx <= mx + trigger && cy >= my && cy <= my + mh
    } else {
        cx >= mx + mw - trigger && cy >= my && cy <= my + mh
    }
}

/// 把窗口按窗口坐标裁剪到 [l, r) 竖条；r<=l 时为空区域（整窗不渲染不拦鼠标，
/// 供"完全隐藏"模式用）。被裁掉的部分不渲染也不参与命中测试。
#[cfg(windows)]
fn clip_region(win: &WebviewWindow, l: i32, r: i32, h: i32) {
    use windows_sys::Win32::Graphics::Gdi::{CreateRectRgn, SetWindowRgn};
    let Ok(hwnd) = win.hwnd() else { return };
    let ptr = hwnd.0 as isize as *mut core::ffi::c_void;
    unsafe {
        let rgn = CreateRectRgn(l, 0, r.max(l), h);
        if !rgn.is_null() {
            SetWindowRgn(ptr, rgn, 1);
        }
    }
}

/// 取消裁剪，恢复完整矩形窗口
#[cfg(windows)]
fn clear_region(win: &WebviewWindow) {
    use windows_sys::Win32::Graphics::Gdi::SetWindowRgn;
    let Ok(hwnd) = win.hwnd() else { return };
    let ptr = hwnd.0 as isize as *mut core::ffi::c_void;
    unsafe {
        SetWindowRgn(ptr, std::ptr::null_mut(), 1);
    }
}

#[cfg(not(windows))]
fn clip_region(_win: &WebviewWindow, _l: i32, _r: i32, _h: i32) {}

#[cfg(not(windows))]
fn clear_region(_win: &WebviewWindow) {}

/// 把窗口调到展开尺寸（按 Dock 记录的逻辑宽度 × 目标屏缩放，高度=屏幕高），返回物理宽度
fn ensure_full_size(d: &Dock, win: &WebviewWindow, mon: &Monitor) -> i32 {
    let width_l = d.width_l.load(Ordering::Relaxed) as f64;
    let want_w = ((width_l * mon.scale_factor()).round() as u32).max(1);
    let want_h = mon.size().height;
    let Ok(size) = win.outer_size() else {
        return want_w as i32;
    };
    if size.width != want_w || size.height != want_h {
        let _ = win.set_size(PhysicalSize::new(want_w, want_h));
    }
    want_w as i32
}

/// 收起状态重摆：位置贴边 + 区域只留边条（不改窗口尺寸）
fn place_sliver(d: &Dock, win: &WebviewWindow, mon: &Monitor, sliver: i32) {
    let side_left = d.side_left.load(Ordering::Relaxed);
    let mon_x = mon.position().x;
    let mon_y = mon.position().y;
    let mon_w = mon.size().width as i32;
    let x = if side_left { mon_x } else { mon_x + mon_w - sliver };
    let _ = win.set_position(PhysicalPosition::new(x, mon_y));
    clip_region(win, 0, sliver, mon.size().height as i32);
}

pub fn init(app: &App) -> Result<(), Box<dyn std::error::Error>> {
    let handle = app.handle().clone();
    let win = handle
        .get_webview_window(WIN_LABEL)
        .ok_or("main window not found")?;
    let mon = handle.primary_monitor()?.ok_or("no primary monitor")?;

    let cfg = store_json(&handle);
    let pin = store_bool(&cfg, "pin", false);
    let width = store_f64(&cfg, "width", PANEL_DEFAULT_WIDTH, PANEL_MIN_WIDTH, PANEL_MAX_WIDTH);
    let label = store_str(&cfg, "label");
    let side_left = store_str(&cfg, "dock_side") == "left";

    // 兼容旧数据：没有 edge_mode 时按是否有描述标签推断
    let mode = match store_str(&cfg, "edge_mode").as_str() {
        "sliver" => EDGE_SLIVER,
        "hidden" => EDGE_HIDDEN,
        "label" => EDGE_LABEL,
        _ => {
            if label.trim().is_empty() {
                EDGE_SLIVER
            } else {
                EDGE_LABEL
            }
        }
    };
    let edge_width = store_f64(&cfg, "edge_width", 10.0, EDGE_MIN_WIDTH, EDGE_MAX_WIDTH);
    let retract_ms = cfg
        .as_ref()
        .and_then(|v| v.get("retract_ms"))
        .and_then(|n| n.as_u64())
        .filter(|n| *n <= 60_000)
        .unwrap_or(DEFAULT_RETRACT_MS);
    let sliver = sliver_physical(&handle, mode, edge_width);

    let scale = mon.scale_factor();
    let width_px = ((width * scale).round() as i32).max(1);
    let height = mon.size().height;

    let mon_x = mon.position().x;
    let mon_y = mon.position().y;
    let mon_w = mon.size().width as i32;

    // 首次使用 / 固定状态：直接展开；否则收起成边条
    let first_run = !store_exists(&handle);
    let expanded_start = first_run || pin;
    let x = if expanded_start {
        if side_left { mon_x } else { mon_x + mon_w - width_px }
    } else if side_left {
        mon_x
    } else {
        mon_x + mon_w - sliver
    };
    let _ = win.set_size(PhysicalSize::new(width_px as u32, height));
    let _ = win.set_position(PhysicalPosition::new(x, mon_y));
    let _ = win.show();
    if expanded_start {
        clear_region(&win);
    } else {
        clip_region(&win, 0, sliver, height as i32);
    }
    if first_run {
        let _ = win.set_focus();
    }

    handle.manage(Dock {
        state: Mutex::new(if expanded_start {
            DockState::Expanded
        } else {
            DockState::Retracted
        }),
        outside_since: Mutex::new(None),
        pinned: AtomicBool::new(pin),
        mode: AtomicU8::new(mode),
        sliver: AtomicI32::new(sliver),
        retract_ms: AtomicU64::new(retract_ms),
        side_left: AtomicBool::new(side_left),
        width_l: AtomicU32::new(width.round() as u32),
    });

    let initial = if expanded_start { "expanded" } else { "retracted" };
    let _ = handle.emit("dock-state", initial);

    thread::spawn(move || poll_loop(handle));
    Ok(())
}

fn poll_loop(app: AppHandle) {
    loop {
        thread::sleep(Duration::from_millis(60));
        let st = { *dock(&app) };
        if st == DockState::Hidden {
            continue;
        }
        let Some(win) = app.get_webview_window(WIN_LABEL) else {
            continue;
        };
        let Some((cx, cy)) = cursor_pos() else {
            continue;
        };

        let d = app.state::<Dock>().inner();
        let pinned = d.pinned.load(Ordering::Relaxed);
        let mode = d.mode.load(Ordering::Relaxed);
        let sliver = d.sliver.load(Ordering::Relaxed);
        let side_left = d.side_left.load(Ordering::Relaxed);
        let retract_ms = d.retract_ms.load(Ordering::Relaxed) as u128;

        match st {
            DockState::Retracted => {
                // 在哪块屏的吸边一侧悬停，面板就滑出到哪块屏
                if mode != EDGE_HIDDEN {
                    if let Some(cur) = pick_monitor(&app) {
                        if edge_hit(&cur, cx, cy, sliver, side_left) {
                            expand(&app, &win, &cur);
                        }
                    }
                }
            }
            DockState::Expanded => {
                // 收回固定回窗口所在屏的吸边处，绝不跨屏、绝不压到相邻显示器
                let Some(mon) = monitor_of_window(&app, &win) else {
                    continue;
                };
                let (Ok(pos), Ok(size)) = (win.outer_position(), win.outer_size()) else {
                    continue;
                };
                let should_retract = {
                    let mut since = d.outside_since.lock().unwrap();
                    if pinned {
                        *since = None;
                        false
                    } else {
                        let focused = win.is_focused().unwrap_or(false);
                        let inside = cx >= pos.x - LEAVE_MARGIN_PX
                            && cx <= pos.x + size.width as i32 + LEAVE_MARGIN_PX
                            && cy >= pos.y - LEAVE_MARGIN_PX
                            && cy <= pos.y + size.height as i32 + LEAVE_MARGIN_PX;
                        if focused || inside {
                            *since = None;
                            false
                        } else {
                            match *since {
                                None => {
                                    *since = Some(Instant::now());
                                    false
                                }
                                Some(t) => t.elapsed().as_millis() >= retract_ms,
                            }
                        }
                    }
                };
                if should_retract {
                    retract(&app, &win, &mon);
                }
            }
            DockState::Hidden => {}
        }
    }
}

/// 展开/收起动画：右吸边=窗口从右缘滑出/滑入，左吸边=窗口固定在左缘用区域揭示/收拢；
/// 逐帧用窗口区域在屏幕边缘处裁断，窗口尺寸全程不变（WebView 不重排，不透底不花屏）
fn animate_edge(app: &AppHandle, win: &WebviewWindow, mon: &Monitor, expanding: bool) {
    let d = app.state::<Dock>().inner();
    let side_left = d.side_left.load(Ordering::Relaxed);
    let width_l = d.width_l.load(Ordering::Relaxed) as f64;
    let sliver_w = d.sliver.load(Ordering::Relaxed).max(1);
    let full_w = ((width_l * mon.scale_factor()).round() as i32).max(sliver_w);
    let mon_x = mon.position().x;
    let mon_y = mon.position().y;
    let mon_w = mon.size().width as i32;
    let mon_h = mon.size().height as i32;
    let (v0, v1) = if expanding { (sliver_w, full_w) } else { (full_w, sliver_w) };
    for step in 1..=ANIM_STEPS {
        let t = step as f64 / ANIM_STEPS as f64;
        let eased = 1.0 - (1.0 - t) * (1.0 - t); // easeOutQuad
        let v = (v0 as f64 + (v1 - v0) as f64 * eased).round() as i32;
        let x = if side_left { mon_x } else { mon_x + mon_w - v };
        // 先收窄裁剪区域再挪窗口：反过来会在两步之间留出"宽区域+新位置"
        // 的一帧，双屏接缝处会把面板内容溅到相邻屏上
        clip_region(win, 0, v, mon_h);
        let _ = win.set_position(PhysicalPosition::new(x, mon_y));
        thread::sleep(Duration::from_millis(FRAME_MS));
    }
    let x_end = if side_left { mon_x } else { mon_x + mon_w - v1 };
    let _ = win.set_position(PhysicalPosition::new(x_end, mon_y));
    if expanding {
        clear_region(win);
    } else {
        clip_region(win, 0, v1, mon_h);
    }
}

fn expand(app: &AppHandle, win: &WebviewWindow, mon: &Monitor) {
    {
        let mut st = dock(app);
        if *st == DockState::Expanded {
            return;
        }
        *st = DockState::Expanded;
    }
    *app.state::<Dock>().inner().outside_since.lock().unwrap() = None;
    let _ = app.emit("dock-state", "expanded");
    animate_edge(app, win, mon, true);
}

fn retract(app: &AppHandle, win: &WebviewWindow, mon: &Monitor) {
    {
        let mut st = dock(app);
        if *st != DockState::Expanded {
            return;
        }
        *st = DockState::Retracted;
    }
    // 先通知前端隐藏面板内容（边条里只留把手/标签），再播放收起动画
    let _ = app.emit("dock-state", "retracted");
    animate_edge(app, win, mon, false);
}

/// 快捷键 / 托盘 / 二次启动：展开则隐藏，否则完整展开并聚焦
pub fn toggle(app: &AppHandle) {
    if *dock(app) == DockState::Expanded {
        hide(app);
    } else {
        show_expanded(app, true);
    }
}

pub fn hide(app: &AppHandle) {
    *dock(app) = DockState::Hidden;
    if let Some(win) = app.get_webview_window(WIN_LABEL) {
        let _ = win.hide();
    }
    let _ = app.emit("dock-state", "hidden");
}

/// focus=false 用于提醒触发：面板滑出可见，但不抢键盘焦点
pub fn show_expanded(app: &AppHandle, focus: bool) {
    {
        let mut st = dock(app);
        if *st == DockState::Expanded {
            if focus {
                if let Some(win) = app.get_webview_window(WIN_LABEL) {
                    let _ = win.set_focus();
                }
            }
            return;
        }
        *st = DockState::Expanded;
    }
    *app.state::<Dock>().inner().outside_since.lock().unwrap() = None;
    if let Some(win) = app.get_webview_window(WIN_LABEL) {
        if let Some(mon) = monitor_of_window(app, &win).or_else(|| app.primary_monitor().ok().flatten()) {
            let d = app.state::<Dock>().inner();
            let full_w = ensure_full_size(&d, &win, &mon);
            let side_left = d.side_left.load(Ordering::Relaxed);
            let mon_x = mon.position().x;
            let mon_y = mon.position().y;
            let mon_w = mon.size().width as i32;
            let x = if side_left { mon_x } else { mon_x + mon_w - full_w };
            let _ = win.set_position(PhysicalPosition::new(x, mon_y));
            clear_region(&win);
        }
        let _ = win.show();
        if focus {
            let _ = win.set_focus();
        }
    }
    let _ = app.emit("dock-state", "expanded");
}

pub fn set_pinned(app: &AppHandle, pinned: bool) {
    app.state::<Dock>().inner().pinned.store(pinned, Ordering::Relaxed);
    if pinned {
        *app.state::<Dock>().inner().outside_since.lock().unwrap() = None;
    }
}

/// 调整失焦收回延迟（毫秒，已由调用方钳制）
pub fn set_retract_ms(app: &AppHandle, ms: u64) {
    app.state::<Dock>().inner().retract_ms.store(ms, Ordering::Relaxed);
}

/// 切换吸边侧：收起中立即把边条挪到新边缘，展开中把面板挪到新边缘
pub fn set_dock_side(app: &AppHandle, side_left: bool) {
    let d = app.state::<Dock>().inner();
    d.side_left.store(side_left, Ordering::Relaxed);
    let st = { *dock(app) };
    if st == DockState::Hidden {
        return;
    }
    if let Some(win) = app.get_webview_window(WIN_LABEL) {
        if let Some(mon) = monitor_of_window(app, &win) {
            match st {
                DockState::Retracted => {
                    let sliver = d.sliver.load(Ordering::Relaxed);
                    place_sliver(&d, &win, &mon, sliver);
                }
                _ => {
                    let full_w = ensure_full_size(&d, &win, &mon);
                    let mon_x = mon.position().x;
                    let mon_y = mon.position().y;
                    let mon_w = mon.size().width as i32;
                    let x = if side_left { mon_x } else { mon_x + mon_w - full_w };
                    let _ = win.set_position(PhysicalPosition::new(x, mon_y));
                    clear_region(&win);
                }
            }
        }
    }
}

/// 设置收起状态：mode = "label" | "sliver" | "hidden"，width 为逻辑像素
pub fn set_edge(app: &AppHandle, mode: u8, width: f64) {
    let width = width.clamp(EDGE_MIN_WIDTH, EDGE_MAX_WIDTH);
    let d = app.state::<Dock>().inner();
    d.mode.store(mode, Ordering::Relaxed);
    let phys = sliver_physical(app, mode, width);
    d.sliver.store(phys, Ordering::Relaxed);
    // 若当前收起，立即按新宽度重摆边条（只改位置和裁剪区域，不缩放窗口）
    if { *dock(app) } == DockState::Retracted {
        if let Some(win) = app.get_webview_window(WIN_LABEL) {
            if let Some(mon) = monitor_of_window(app, &win) {
                place_sliver(&d, &win, &mon, phys);
            }
        }
    }
}

pub fn set_width(app: &AppHandle, logical: f64) {
    let logical = logical.clamp(PANEL_MIN_WIDTH, PANEL_MAX_WIDTH);
    let d = app.state::<Dock>().inner();
    d.width_l.store(logical.round() as u32, Ordering::Relaxed);
    if let Some(win) = app.get_webview_window(WIN_LABEL) {
        if let Some(mon) = monitor_of_window(app, &win) {
            let w = ((logical * mon.scale_factor()).round() as u32).max(1);
            let _ = win.set_size(PhysicalSize::new(w, mon.size().height));
            match { *dock(app) } {
                DockState::Expanded => {
                    let side_left = d.side_left.load(Ordering::Relaxed);
                    let mon_x = mon.position().x;
                    let mon_y = mon.position().y;
                    let mon_w = mon.size().width as i32;
                    let x = if side_left { mon_x } else { mon_x + mon_w - w as i32 };
                    let _ = win.set_position(PhysicalPosition::new(x, mon_y));
                    clear_region(&win);
                }
                DockState::Retracted => {
                    let sliver = d.sliver.load(Ordering::Relaxed);
                    place_sliver(&d, &win, &mon, sliver);
                }
                DockState::Hidden => {}
            }
        }
    }
}

fn store_exists(app: &AppHandle) -> bool {
    app.path()
        .app_data_dir()
        .map(|d| d.join("memos.json").exists())
        .unwrap_or(false)
}

#[cfg(windows)]
fn cursor_pos() -> Option<(i32, i32)> {
    use windows_sys::Win32::Foundation::POINT;
    use windows_sys::Win32::UI::WindowsAndMessaging::GetCursorPos;
    let mut p = POINT { x: 0, y: 0 };
    unsafe {
        if GetCursorPos(&mut p) != 0 {
            Some((p.x, p.y))
        } else {
            None
        }
    }
}

#[cfg(not(windows))]
fn cursor_pos() -> Option<(i32, i32)> {
    None
}
