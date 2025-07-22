use std::{env, path::PathBuf};

use cmake::Config;

fn main() {
    let sysroot =
        env::var("WASI_SYSROOT").unwrap_or_else(|_| "/usr/share/wasi-sysroot".to_string());

    let cmake_dir = Config::new("../../assets/wasm/")
        .define("wasi_sysroot", &sysroot)
        .define("CMAKE_C_COMPILER_WORKS", "1")
        .build_target("sqlite3_opt_lib")
        .build_target("help") // We only need the sources
        .build();
    let sqlite3_src = cmake_dir.join("build/_deps/sqlite3-src/");

    let mut c_build = cc::Build::new();
    let objects = c_build
        .target("wasm32-unknown-wasi")
        .cargo_warnings(false)
        .flag("--sysroot")
        .flag(&sysroot)
        .file(sqlite3_src.join("sqlite3.c"))
        .file("../../assets/wasm/helpers.c")
        .flag("-flto=thin")
        .include(&sqlite3_src)
        .include("../../assets/wasm/")
        .define("_HAVE_SQLITE_CONFIG_H", None)
        .define("SQLITE_API", "__attribute__((visibility(\"default\")))")
        // Ideally we should be able to compile this into a static library and use that one, but
        // for some reasons that drops all exported symbols. So we're compiling to objects and
        // we only compile Rust code to a static library. Then we use the clang driver to link
        // these objects and the static Rust library in one go.
        .compile_intermediates();

    let output_dir = get_output_path();
    for object in objects {
        // The file name is something like <hash>-sqlite3.o
        let file_name = object.file_name().unwrap().to_str().unwrap().to_owned();
        let (_, file_name) = file_name.split_once("-").unwrap();

        std::fs::copy(object, output_dir.join(file_name)).unwrap();
    }
}

fn get_output_path() -> PathBuf {
    let mut out = PathBuf::from(env::var("OUT_DIR").unwrap());

    loop {
        match out.file_name() {
            Some(name) if name == "build" => {
                break;
            }
            _ => out = out.parent().unwrap().to_path_buf(),
        }
    }

    out.parent().unwrap().to_path_buf()
}
