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

/// 强制整窗（含 WebView2 子窗口）重绘：取消区域裁剪后，
/// WebView2 不会主动重绘先前被裁掉的部位，会留下透出桌面的洞
#[cfg(windows)]
fn redraw_window(win: &WebviewWindow) {
    use windows_sys::Win32::Graphics::Gdi::{
        RedrawWindow, RDW_ALLCHILDREN, RDW_ERASE, RDW_FRAME, RDW_INVALIDATE, RDW_UPDATENOW,
    };
    let Ok(hwnd) = win.hwnd() else { return };
    unsafe {
        RedrawWindow(
            hwnd.0 as _,
            std::ptr::null(),
            std::ptr::null_mut(),
            RDW_INVALIDATE | RDW_ERASE | RDW_FRAME | RDW_ALLCHILDREN | RDW_UPDATENOW,
        );
    }
}

#[cfg(not(windows))]
fn redraw_window(_win: &WebviewWindow) {}

#[cfg(not(windows))]
fn clip_region(_win: &WebviewWindow, _l: i32, _r: i32, _h: i32) {}

#[cfg(not(windows))]
fn clear_region(_win: &WebviewWindow) {}

/// 收起状态重摆：窗口物理收窄到边条宽度并贴边停放。
/// 静止状态不依赖区域裁剪——纯裁剪挡不住 WebView2 子窗口在相邻屏上的鼠标命中
fn place_sliver(d: &Dock, win: &WebviewWindow, mon: &Monitor, sliver: i32) {
    let side_left = d.side_left.load(Ordering::Relaxed);
    let mon_x = mon.position().x;
    let mon_y = mon.position().y;
    let mon_w = mon.size().width as i32;
    // 先缩后挪：两个中间态都不会越出屏幕
    let _ = win.set_size(PhysicalSize::new(sliver.max(1) as u32, mon.size().height));
    let x = if side_left { mon_x } else { mon_x + mon_w - sliver };
    let _ = win.set_position(PhysicalPosition::new(x, mon_y));
    clear_region(win);
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

    // 首次使用 / 固定状态：直接展开（先挪位后放尺寸）；否则物理收窄成边条（先缩后挪）
    let first_run = !store_exists(&handle);
    let expanded_start = first_run || pin;
    if expanded_start {
        let x = if side_left { mon_x } else { mon_x + mon_w - width_px };
        let _ = win.set_position(PhysicalPosition::new(x, mon_y));
        let _ = win.set_size(PhysicalSize::new(width_px as u32, height));
    } else {
        let x = if side_left { mon_x } else { mon_x + mon_w - sliver };
        let _ = win.set_size(PhysicalSize::new(sliver.max(1) as u32, height));
        let _ = win.set_position(PhysicalPosition::new(x, mon_y));
    }
    let _ = win.show();
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

/// 展开/收起动画。窗口全程停在所在屏的展开矩形内（矩形本身不出屏，
/// 即使区域裁剪完全失效也不会压到相邻屏）：
/// - 展开前：先整窗遮住，再摆到展开位并还原全尺寸——尺寸切换与网页重排
///   都在不可见时完成，取消遮蔽时 WebView 已是画好的完整画面（修"透洞"）
/// - 动画中：只改窗口区域，从吸边一侧揭示/收拢，位置与尺寸都不动
/// - 收起后：物理收窄到边条宽度贴边停放，静止不依赖区域
fn animate_edge(app: &AppHandle, win: &WebviewWindow, mon: &Monitor, expanding: bool) {
    let d = app.state::<Dock>().inner();
    let side_left = d.side_left.load(Ordering::Relaxed);
    let width_l = d.width_l.load(Ordering::Relaxed) as f64;
    let sliver_w = d.sliver.load(Ordering::Relaxed).max(1);
    let full_w = ((width_l * mon.scale_factor()).round() as i32).max(sliver_w);
    let (mon_x, mon_y) = (mon.position().x, mon.position().y);
    let (mon_w, mon_h) = (mon.size().width as i32, mon.size().height as i32);
    let full_x = if side_left { mon_x } else { mon_x + mon_w - full_w };

    let reveal = |v: i32| {
        if side_left {
            clip_region(win, 0, v, mon_h)
        } else {
            clip_region(win, full_w - v, full_w, mon_h)
        }
    };

    if expanding {
        // 整窗遮住后摆到展开位（先挪位后放尺寸，中间态不出屏）
        clip_region(win, if side_left { 0 } else { full_w }, if side_left { 0 } else { full_w }, mon_h);
        let _ = win.set_position(PhysicalPosition::new(full_x, mon_y));
        let _ = win.set_size(PhysicalSize::new(full_w as u32, mon_h as u32));
        for step in 1..=ANIM_STEPS {
            let t = step as f64 / ANIM_STEPS as f64;
            let eased = 1.0 - (1.0 - t) * (1.0 - t);
            let v = (sliver_w as f64 + (full_w - sliver_w) as f64 * eased).round() as i32;
            reveal(v);
            thread::sleep(Duration::from_millis(FRAME_MS));
        }
        clear_region(win);
        redraw_window(win);
    } else {
        for step in 1..=ANIM_STEPS {
            let t = step as f64 / ANIM_STEPS as f64;
            let eased = 1.0 - (1.0 - t) * (1.0 - t);
            let v = (full_w as f64 + (sliver_w - full_w) as f64 * eased).round() as i32;
            reveal(v);
            thread::sleep(Duration::from_millis(FRAME_MS));
        }
        // 内容已隐藏：物理收窄贴边（先缩后挪，中间态不出屏）
        let edge_x = if side_left { mon_x } else { mon_x + mon_w - sliver_w };
        let _ = win.set_size(PhysicalSize::new(sliver_w as u32, mon_h as u32));
        let _ = win.set_position(PhysicalPosition::new(edge_x, mon_y));
        clear_region(win);
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
            let width_l = d.width_l.load(Ordering::Relaxed) as f64;
            let full_w = ((width_l * mon.scale_factor()).round() as i32).max(1);
            let side_left = d.side_left.load(Ordering::Relaxed);
            let mon_x = mon.position().x;
            let mon_y = mon.position().y;
            let mon_w = mon.size().width as i32;
            let x = if side_left { mon_x } else { mon_x + mon_w - full_w };
            // 从隐藏/收起状态唤出：先挪到展开位再放尺寸（中间态不出屏），取消区域并强制重绘
            let _ = win.set_position(PhysicalPosition::new(x, mon_y));
            let _ = win.set_size(PhysicalSize::new(full_w as u32, mon.size().height));
            clear_region(&win);
            redraw_window(&win);
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
                    let width_l = d.width_l.load(Ordering::Relaxed) as f64;
                    let full_w = ((width_l * mon.scale_factor()).round() as i32).max(1);
                    let mon_x = mon.position().x;
                    let mon_y = mon.position().y;
                    let mon_w = mon.size().width as i32;
                    let x = if side_left { mon_x } else { mon_x + mon_w - full_w };
                    let _ = win.set_position(PhysicalPosition::new(x, mon_y));
                    let _ = win.set_size(PhysicalSize::new(full_w as u32, mon.size().height));
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
            let side_left = d.side_left.load(Ordering::Relaxed);
            let w = ((logical * mon.scale_factor()).round() as i32).max(1);
            let mon_x = mon.position().x;
            let mon_y = mon.position().y;
            let mon_w = mon.size().width as i32;
            match { *dock(app) } {
                DockState::Expanded => {
                    // 先挪到新宽度对应的位置再改尺寸（中间态不出屏）
                    let x = if side_left { mon_x } else { mon_x + mon_w - w };
                    let _ = win.set_position(PhysicalPosition::new(x, mon_y));
                    let _ = win.set_size(PhysicalSize::new(w as u32, mon.size().height));
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
