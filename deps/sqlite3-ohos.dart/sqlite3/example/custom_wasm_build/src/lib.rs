use std::ffi::c_int;

#[no_mangle]
pub extern "C" fn sqlite3_os_init() -> c_int {
    // This would be a good place to set up extensions.
    unsafe {
        // package:sqlite3 provides access to Dart's print function via dart.error_log
        wasm::dartLogError("Hello from a custom Rust build!".as_ptr().cast());
    }

    return 0;
}

#[no_mangle]
pub extern "C" fn sqlite3_os_end() -> c_int {
    return 0;
}

mod wasm {
    use std::ffi::c_char;

    #[link(wasm_import_module = "dart")]
    extern "C" {
        #[link_name = "error_log"]
        pub fn dartLogError(msg: *const c_char);
    }
}
