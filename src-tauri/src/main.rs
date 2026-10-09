#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

mod dock;

use serde::{Deserialize, Serialize};
use std::fs;
use std::path::PathBuf;
use tauri::{AppHandle, Manager};
use tauri_plugin_autostart::ManagerExt;
use tauri_plugin_notification::NotificationExt;

/// 托盘里"开机自启"复选项的句柄，供设置面板改动后同步勾选状态
struct TrayAutoItem(std::sync::Mutex<Option<tauri::menu::CheckMenuItem<tauri::Wry>>>);

#[derive(Debug, Clone, Serialize, Deserialize)]
struct Memo {
    id: String,
    content: String,
    done: bool,
    pinned: bool,
    #[serde(default)]
    remind_at: u64,
    #[serde(default)]
    reminded: bool,
    created_at: u64,
    updated_at: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
struct Note {
    id: String,
    title: String,
    content: String,
    pinned: bool,
    #[serde(default)]
    archived: bool,
    created_at: u64,
    updated_at: u64,
}

fn default_width() -> f64 {
    340.0
}

fn default_edge_width() -> f64 {
    10.0
}

fn default_retract_ms() -> u64 {
    dock::DEFAULT_RETRACT_MS
}

fn default_bg_opacity() -> f64 {
    1.0
}

fn default_font_size() -> u32 {
    13
}

fn default_dock_side() -> String {
    "right".into()
}

#[derive(Debug, Clone, Serialize, Deserialize)]
struct Store {
    theme: String,
    #[serde(default)]
    active_tab: String,
    #[serde(default)]
    pin: bool,
    #[serde(default = "default_dock_side")]
    dock_side: String,
    #[serde(default)]
    hotkey: String,
    #[serde(default)]
    label: String,
    #[serde(default)]
    edge_mode: String,
    #[serde(default = "default_edge_width")]
    edge_width: f64,
    #[serde(default = "default_retract_ms")]
    retract_ms: u64,
    #[serde(default)]
    bg_color: String,
    #[serde(default)]
    bg_image: String,
    #[serde(default = "default_bg_opacity")]
    bg_opacity: f64,
    #[serde(default)]
    bg_blur: u32,
    #[serde(default)]
    bg_blur_on: bool,
    #[serde(default)]
    bg_dim: u32,
    #[serde(default)]
    accent: String,
    #[serde(default = "default_font_size")]
    font_size: u32,
    #[serde(default = "default_width")]
    width: f64,
    #[serde(default)]
    memos: Vec<Memo>,
    #[serde(default)]
    notes: Vec<Note>,
}

impl Default for Store {
    fn default() -> Self {
        Self {
            theme: "dark".into(),
            active_tab: "memos".into(),
            pin: false,
            dock_side: "right".into(),
            hotkey: "ctrl+alt+m".into(),
            label: String::new(),
            edge_mode: String::new(),
            edge_width: 10.0,
            retract_ms: dock::DEFAULT_RETRACT_MS,
            bg_color: String::new(),
            bg_image: String::new(),
            bg_opacity: 1.0,
            bg_blur: 0,
            bg_blur_on: false,
            bg_dim: 0,
            accent: String::new(),
            font_size: 13,
            width: 340.0,
            memos: Vec::new(),
            notes: Vec::new(),
        }
    }
}

fn store_path(app: &AppHandle) -> PathBuf {
    app.path()
        .app_data_dir()
        .unwrap_or_else(|_| std::env::temp_dir())
        .join("memos.json")
}

fn images_dir(app: &AppHandle) -> PathBuf {
    app.path()
        .app_data_dir()
        .unwrap_or_else(|_| std::env::temp_dir())
        .join("images")
}

fn backups_dir(app: &AppHandle) -> PathBuf {
    app.path()
        .app_data_dir()
        .unwrap_or_else(|_| std::env::temp_dir())
        .join("backups")
}

/// 备份文件名 memos-<毫秒时间戳>.json；同一时间门限内不重复备份
const BACKUP_MIN_INTERVAL_MS: u64 = 10 * 60 * 1000;
const BACKUP_KEEP: usize = 10;

fn list_backups(app: &AppHandle) -> Vec<u64> {
    let mut names: Vec<u64> = Vec::new();
    if let Ok(entries) = fs::read_dir(backups_dir(app)) {
        for e in entries.flatten() {
            if let Some(n) = e.file_name().to_str() {
                if let Some(num) = n
                    .strip_prefix("memos-")
                    .and_then(|s| s.strip_suffix(".json"))
                    .and_then(|s| s.parse::<u64>().ok())
                {
                    names.push(num);
                }
            }
        }
    }
    names.sort_unstable();
    names
}

/// 把当前数据文件留档一份（10 分钟内只备一次），并清理超出保留数的旧备份
fn maybe_backup(app: &AppHandle) {
    let src = store_path(app);
    if !src.exists() {
        return;
    }
    let dir = backups_dir(app);
    if fs::create_dir_all(&dir).is_err() {
        return;
    }
    let now_ms = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_millis() as u64)
        .unwrap_or(0);
    if let Some(last) = list_backups(app).last() {
        if now_ms.saturating_sub(*last) < BACKUP_MIN_INTERVAL_MS {
            return;
        }
    }
    let name = format!("memos-{}.json", now_ms);
    if fs::copy(&src, dir.join(&name)).is_ok() {
        let keep = list_backups(app);
        if keep.len() > BACKUP_KEEP {
            for old in &keep[..keep.len() - BACKUP_KEEP] {
                let _ = fs::remove_file(dir.join(format!("memos-{}.json", old)));
            }
        }
    }
}

#[derive(Debug, Serialize)]
struct BackupStatus {
    count: usize,
    last: u64,
    path: String,
}

#[tauri::command]
fn backup_status(app: AppHandle) -> BackupStatus {
    let stamps = list_backups(&app);
    BackupStatus {
        count: stamps.len(),
        last: stamps.last().copied().unwrap_or(0),
        path: backups_dir(&app).to_string_lossy().into_owned(),
    }
}

#[tauri::command]
fn open_backups(app: AppHandle) -> Result<(), String> {
    let dir = backups_dir(&app);
    let _ = fs::create_dir_all(&dir);
    open::that(&dir).map_err(|e| e.to_string())
}

const IMG_NEEDLE: &str = "sidememo-img://";

/// 正文中引用的所有图片文件名
fn referenced_images(content: &str, out: &mut std::collections::HashSet<String>) {
    let mut rest = content;
    while let Some(i) = rest.find(IMG_NEEDLE) {
        let tail = &rest[i + IMG_NEEDLE.len()..];
        let end = tail.find(')').unwrap_or(tail.len());
        let name = tail[..end].trim();
        if !name.is_empty() && !name.contains(['\\', '/', '\n']) {
            out.insert(name.to_string());
        }
        rest = &rest[i + IMG_NEEDLE.len() + end..];
    }
}

/// 删除不再被任何笔记引用、且超过 1 小时未被修改的图片文件
fn gc_images(app: &AppHandle, store: &Store) {
    let dir = images_dir(app);
    let Ok(entries) = fs::read_dir(&dir) else {
        return;
    };
    let mut referenced = std::collections::HashSet::new();
    for n in &store.notes {
        referenced_images(&n.content, &mut referenced);
    }
    // 背景图只被设置引用（不在任何笔记正文里），不能被当垃圾清掉
    if !store.bg_image.is_empty() {
        referenced.insert(store.bg_image.clone());
    }
    let Ok(now) = std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH) else {
        return;
    };
    for e in entries.flatten() {
        let Ok(meta) = e.metadata() else { continue };
        if !meta.is_file() {
            continue;
        }
        let fname = e.file_name().to_string_lossy().into_owned();
        if referenced.contains(&fname) {
            continue;
        }
        let stale = e
            .metadata()
            .ok()
            .and_then(|m| m.modified().ok())
            .and_then(|t| t.duration_since(std::time::UNIX_EPOCH).ok())
            .map(|d| now.as_secs().saturating_sub(d.as_secs()) > 3600)
            .unwrap_or(false);
        if stale {
            let _ = fs::remove_file(e.path());
        }
    }
}

fn detect_image_ext(b: &[u8]) -> &'static str {
    if b.starts_with(&[0x89, b'P', b'N', b'G']) {
        "png"
    } else if b.starts_with(&[0xFF, 0xD8, 0xFF]) {
        "jpg"
    } else if b.starts_with(b"GIF8") {
        "gif"
    } else if b.len() > 12 && &b[0..4] == b"RIFF" && &b[8..12] == b"WEBP" {
        "webp"
    } else if b.starts_with(b"BM") {
        "bmp"
    } else {
        "png"
    }
}

#[tauri::command]
fn load_store(app: AppHandle) -> Store {
    fs::read_to_string(store_path(&app))
        .ok()
        .and_then(|s| serde_json::from_str(&s).ok())
        .unwrap_or_default()
}

#[tauri::command]
fn save_store(app: AppHandle, store: Store) -> Result<(), String> {
    let path = store_path(&app);
    if let Some(dir) = path.parent() {
        fs::create_dir_all(dir).map_err(|e| e.to_string())?;
    }
    let tmp = path.with_extension("json.tmp");
    let json = serde_json::to_string_pretty(&store).map_err(|e| e.to_string())?;
    fs::write(&tmp, json).map_err(|e| e.to_string())?;
    // 覆盖前把旧数据留档（10 分钟门限）
    maybe_backup(&app);
    fs::rename(&tmp, &path).map_err(|e| e.to_string())?;
    gc_images(&app, &store);
    Ok(())
}

#[tauri::command]
fn images_dir_cmd(app: AppHandle) -> Result<String, String> {
    Ok(images_dir(&app).to_string_lossy().into_owned())
}

/// 前端用 invoke('save_image', uint8Array) 传原始字节，
/// 扩展名由文件头魔数判断，返回生成的文件名
#[tauri::command]
async fn save_image(app: AppHandle, request: tauri::ipc::Request<'_>) -> Result<String, String> {
    let bytes: Vec<u8> = match request.body() {
        tauri::ipc::InvokeBody::Raw(b) => b.clone(),
        tauri::ipc::InvokeBody::Json(v) => {
            let Some(arr) = v.get("bytes").and_then(|x| x.as_array()) else {
                return Err("missing image bytes".into());
            };
            arr.iter()
                .map(|x| x.as_u64().unwrap_or(0) as u8)
                .collect::<Vec<u8>>()
        }
    };
    if bytes.is_empty() {
        return Err("empty image".into());
    }
    if bytes.len() > 15 * 1024 * 1024 {
        return Err("image too large (max 15MB)".into());
    }
    let dir = images_dir(&app);
    fs::create_dir_all(&dir).map_err(|e| e.to_string())?;
    let nanos = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_nanos())
        .unwrap_or(0);
    let name = format!("img{}{}.{}", nanos, std::process::id(), detect_image_ext(&bytes));
    fs::write(dir.join(&name), &bytes).map_err(|e| e.to_string())?;
    Ok(name)
}

#[tauri::command]
fn hide_panel(app: AppHandle) {
    dock::hide(&app);
}

#[derive(Debug, Deserialize)]
struct ReminderItem {
    title: String,
    body: String,
}

/// 前端定时检查到期的备忘，逐条发系统通知并静默滑出面板（不抢键盘焦点）
#[tauri::command]
fn fire_reminders(app: AppHandle, items: Vec<ReminderItem>) -> Result<(), String> {
    for it in &items {
        let _ = app
            .notification()
            .builder()
            .title(&it.title)
            .body(&it.body)
            .show();
    }
    if !items.is_empty() {
        dock::show_expanded(&app, false);
    }
    Ok(())
}

/// 预览模式里点击链接：只允许 http/https，用系统默认浏览器打开
#[tauri::command]
fn open_external(url: String) -> Result<(), String> {
    if !(url.starts_with("http://") || url.starts_with("https://")) {
        return Err("unsupported url scheme".into());
    }
    match open::that(&url) {
        Ok(_) => Ok(()),
        Err(e) => Err(e.to_string()),
    }
}

#[tauri::command]
fn set_pinned(app: AppHandle, pinned: bool) {
    dock::set_pinned(&app, pinned);
}

#[tauri::command]
fn get_autostart(app: AppHandle) -> bool {
    app.autolaunch().is_enabled().unwrap_or(false)
}

#[tauri::command]
fn set_autostart(app: AppHandle, enable: bool) -> Result<(), String> {
    let al = app.autolaunch();
    if enable {
        al.enable().map_err(|e| e.to_string())?;
    } else {
        al.disable().map_err(|e| e.to_string())?;
    }
    if let Some(item) = app.state::<TrayAutoItem>().0.lock().unwrap().as_ref() {
        let _ = item.set_checked(enable);
    }
    Ok(())
}

/// 收起状态：mode = "label" | "sliver" | "hidden"，width 为逻辑像素
#[tauri::command]
fn set_edge(app: AppHandle, mode: String, width: f64) {
    let m = match mode.as_str() {
        "hidden" => dock::EDGE_HIDDEN,
        "sliver" => dock::EDGE_SLIVER,
        _ => dock::EDGE_LABEL,
    };
    dock::set_edge(&app, m, width);
}

#[tauri::command]
fn set_width(app: AppHandle, width: f64) {
    dock::set_width(&app, width);
}

/// 失焦收起延迟只改运行态，持久化由前端 save_store 完成
#[tauri::command]
fn set_retract_ms(app: AppHandle, ms: u64) {
    dock::set_retract_ms(&app, ms.min(60_000));
}

/// 切换吸边侧（left/right），立即生效；持久化由前端 save_store 完成
#[tauri::command]
fn set_dock_side(app: AppHandle, side: String) {
    dock::set_dock_side(&app, side == "left");
}

/// 换全局快捷键：先解析新键，失败/被占用则自动恢复旧的
#[tauri::command]
fn set_shortcut(app: AppHandle, old: String, new: String) -> Result<(), String> {
    use tauri_plugin_global_shortcut::{GlobalShortcutExt, Shortcut, ShortcutState};
    let new_sc: Shortcut = new
        .parse()
        .map_err(|e| format!("无法识别的快捷键：{e}"))?;
    let gs = app.global_shortcut();
    let _ = gs.unregister_all();
    match gs.on_shortcut(new_sc, |app, _shortcut, event| {
        if event.state == ShortcutState::Pressed {
            dock::toggle(app);
        }
    }) {
        Ok(()) => Ok(()),
        Err(e) => {
            if let Ok(old_sc) = old.parse::<Shortcut>() {
                let _ = gs.on_shortcut(old_sc, |app, _shortcut, event| {
                    if event.state == ShortcutState::Pressed {
                        dock::toggle(app);
                    }
                });
            }
            Err(format!("注册失败（可能已被其他程序占用）：{e}"))
        }
    }
}

fn main() {
    tauri::Builder::default()
        .plugin(tauri_plugin_single_instance::init(|app, _args, _cwd| {
            dock::show_expanded(app, true);
        }))
        .plugin(tauri_plugin_autostart::init(
            tauri_plugin_autostart::MacosLauncher::LaunchAgent,
            None,
        ))
        .plugin(tauri_plugin_global_shortcut::Builder::new().build())
        .plugin(tauri_plugin_notification::init())
        .invoke_handler(tauri::generate_handler![
            load_store,
            save_store,
            hide_panel,
            fire_reminders,
            save_image,
            images_dir_cmd,
            open_external,
            set_pinned,
            get_autostart,
            set_autostart,
            set_edge,
            set_width,
            set_retract_ms,
            set_dock_side,
            set_shortcut,
            backup_status,
            open_backups
        ])
        .setup(|app| {
            use tauri_plugin_global_shortcut::{GlobalShortcutExt, ShortcutState};
            let hotkey = dock::store_json(app.handle())
                .and_then(|v| v.get("hotkey").and_then(|h| h.as_str()).map(String::from))
                .filter(|s| !s.trim().is_empty())
                .unwrap_or_else(|| "ctrl+alt+m".into());
            // 注册失败（快捷键被其他程序占用等）只放弃热键，不能让应用启动失败：
            // 托盘左键和菜单仍可呼出面板，之后可在设置里换键重试
            if let Err(e) = app.global_shortcut().on_shortcut(hotkey.as_str(), move |app, _shortcut, event| {
                if event.state == ShortcutState::Pressed {
                    dock::toggle(app);
                }
            }) {
                eprintln!("global shortcut register failed: {e}");
            }

            dock::init(app)?;

            let toggle_i = tauri::menu::MenuItem::with_id(
                app,
                "toggle",
                "显示 / 隐藏  (Ctrl+Alt+M)",
                true,
                None::<&str>,
            )?;
            let autostart_on = app.autolaunch().is_enabled().unwrap_or(false);
            let autostart_i = tauri::menu::CheckMenuItem::with_id(
                app,
                "autostart",
                "开机自启",
                true,
                autostart_on,
                None::<&str>,
            )?;
            let quit_i =
                tauri::menu::MenuItem::with_id(app, "quit", "退出", true, None::<&str>)?;
            let menu = tauri::menu::Menu::with_items(app, &[&toggle_i, &autostart_i, &quit_i])?;

            let autostart_handle = autostart_i.clone();
            app.manage(TrayAutoItem(std::sync::Mutex::new(Some(autostart_i.clone()))));
            tauri::tray::TrayIconBuilder::with_id("main-tray")
                .icon(tauri::image::Image::from_bytes(include_bytes!(
                    "../icons/icon.png"
                ))?)
                .tooltip(format!(
                    "侧边备忘录 v{} · Ctrl+Alt+M",
                    app.package_info().version
                ))
                .show_menu_on_left_click(false)
                .menu(&menu)
                .on_menu_event(move |app, event| match event.id().as_ref() {
                    "toggle" => dock::toggle(app),
                    "quit" => app.exit(0),
                    "autostart" => {
                        let al = app.autolaunch();
                        let enabled = if al.is_enabled().unwrap_or(false) {
                            let _ = al.disable();
                            false
                        } else {
                            let _ = al.enable();
                            true
                        };
                        let _ = autostart_handle.set_checked(enabled);
                    }
                    _ => {}
                })
                .on_tray_icon_event(|tray, event| {
                    if let tauri::tray::TrayIconEvent::Click {
                        button: tauri::tray::MouseButton::Left,
                        button_state: tauri::tray::MouseButtonState::Up,
                        ..
                    } = event
                    {
                        dock::toggle(tray.app_handle());
                    }
                })
                .build(app)?;

            Ok(())
        })
        .run(tauri::generate_context!())
        .expect("error while running side-memo");
}
