#[cfg(target_os = "ios")]
mod ios_push;

#[tauri::command]
fn pending_push_token() -> Option<String> {
    #[cfg(target_os = "ios")]
    {
        return ios_push::pending_token();
    }
    #[cfg(not(target_os = "ios"))]
    {
        None
    }
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_opener::init())
        .plugin(tauri_plugin_store::Builder::default().build())
        .plugin(tauri_plugin_notification::init())
        .plugin(tauri_plugin_deep_link::init())
        .setup(|app| {
            #[cfg(target_os = "ios")]
            ios_push::install(app.handle());

            if cfg!(debug_assertions) {
                app.handle().plugin(
                    tauri_plugin_log::Builder::default()
                        .level(log::LevelFilter::Info)
                        .build(),
                )?;
            }
            Ok(())
        })
        .invoke_handler(tauri::generate_handler![pending_push_token])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
