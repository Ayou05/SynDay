#![cfg(target_os = "ios")]

use std::{
    ffi::CString,
    os::raw::{c_char, c_void},
    slice,
    sync::{Mutex, OnceLock},
};

use tauri::{AppHandle, Emitter};

type ObjcId = *mut c_void;
type ObjcClass = *mut c_void;
type ObjcSel = *mut c_void;

static APP_HANDLE: OnceLock<AppHandle> = OnceLock::new();
static PENDING_TOKEN: OnceLock<Mutex<Option<String>>> = OnceLock::new();

#[link(name = "objc")]
extern "C" {
    fn objc_getClass(name: *const c_char) -> ObjcClass;
    fn sel_registerName(name: *const c_char) -> ObjcSel;
    fn class_addMethod(
        cls: ObjcClass,
        name: ObjcSel,
        implementation: *const c_void,
        types: *const c_char,
    ) -> i8;

    #[link_name = "objc_msgSend"]
    fn send_id(receiver: ObjcId, selector: ObjcSel) -> ObjcId;
    #[link_name = "objc_msgSend"]
    fn send_void(receiver: ObjcId, selector: ObjcSel);
    #[link_name = "objc_msgSend"]
    fn send_bytes(receiver: ObjcId, selector: ObjcSel) -> *const u8;
    #[link_name = "objc_msgSend"]
    fn send_length(receiver: ObjcId, selector: ObjcSel) -> usize;
}

extern "C" fn did_register_remote_notifications(
    _delegate: ObjcId,
    _selector: ObjcSel,
    _application: ObjcId,
    device_token: ObjcId,
) {
    unsafe {
        let bytes_selector = selector("bytes");
        let length_selector = selector("length");
        let bytes = send_bytes(device_token, bytes_selector);
        let length = send_length(device_token, length_selector);
        if bytes.is_null() || length == 0 {
            return;
        }
        let token = slice::from_raw_parts(bytes, length)
            .iter()
            .map(|byte| format!("{byte:02x}"))
            .collect::<String>();
        if let Ok(mut pending) = PENDING_TOKEN.get_or_init(|| Mutex::new(None)).lock() {
            *pending = Some(token.clone());
        }
        if let Some(app) = APP_HANDLE.get() {
            let _ = app.emit("synday://push-token", token);
        }
    }
}

pub fn pending_token() -> Option<String> {
    PENDING_TOKEN
        .get_or_init(|| Mutex::new(None))
        .lock()
        .ok()
        .and_then(|token| token.clone())
}

pub fn install(app: &AppHandle) {
    let _ = APP_HANDLE.set(app.clone());
    unsafe {
        let delegate = class("AppDelegate");
        if !delegate.is_null() {
            let method = selector("application:didRegisterForRemoteNotificationsWithDeviceToken:");
            let types = CString::new("v@:@@").expect("valid Objective-C type encoding");
            class_addMethod(
                delegate,
                method,
                did_register_remote_notifications as *const c_void,
                types.as_ptr(),
            );
        }

        let application_class = class("UIApplication");
        if application_class.is_null() {
            return;
        }
        let application = send_id(application_class, selector("sharedApplication"));
        if !application.is_null() {
            send_void(application, selector("registerForRemoteNotifications"));
        }
    }
}

unsafe fn class(name: &str) -> ObjcClass {
    let name = CString::new(name).expect("valid Objective-C class name");
    objc_getClass(name.as_ptr())
}

unsafe fn selector(name: &str) -> ObjcSel {
    let name = CString::new(name).expect("valid Objective-C selector");
    sel_registerName(name.as_ptr())
}
