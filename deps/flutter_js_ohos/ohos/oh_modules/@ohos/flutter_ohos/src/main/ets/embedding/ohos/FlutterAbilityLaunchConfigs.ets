/*
* Copyright (c) 2023 Hunan OpenValley Digital Industry Development Co., Ltd. All rights reserved.
* Use of this source code is governed by a BSD-style license that can be
* found in the LICENSE_KHZG file.
*/

/** The mode of the background of a Flutter {@code Activity}, either opaque or transparent. */
enum BackgroundMode {
  /** Indicates a FlutterActivity with an opaque background. This is the default. */
  opaque,
  /** Indicates a FlutterActivity with a transparent background. */
  transparent
}

export default class FlutterAbilityLaunchConfigs {
  static DART_ENTRYPOINT_META_DATA_KEY = "io.flutter.Entrypoint";
  static DART_ENTRYPOINT_URI_META_DATA_KEY = "io.flutter.EntrypointUri";
  static INITIAL_ROUTE_META_DATA_KEY = "io.flutter.InitialRoute";
  static SPLASH_SCREEN_META_DATA_KEY = "io.flutter.embedding.android.SplashScreenDrawable";
  static NORMAL_THEME_META_DATA_KEY = "io.flutter.embedding.android.NormalTheme";
  static HANDLE_DEEPLINKING_META_DATA_KEY = "flutter_deeplinking_enabled";
  // Intent extra arguments.
  static EXTRA_DART_ENTRYPOINT = "dart_entrypoint";
  static EXTRA_DART_ENTRYPOINT_LIBRARY_URI = "dart_entrypoint_library_uri";
  static EXTRA_INITIAL_ROUTE = "route";
  static EXTRA_BACKGROUND_MODE = "background_mode";
  static EXTRA_CACHED_ENGINE_ID = "cached_engine_id";
  static EXTRA_DART_ENTRYPOINT_ARGS = "dart_entrypoint_args";
  static EXTRA_CACHED_ENGINE_GROUP_ID = "cached_engine_group_id";
  static EXTRA_DESTROY_ENGINE_WITH_ACTIVITY = "destroy_engine_with_activity";
  static EXTRA_ENABLE_STATE_RESTORATION = "enable_state_restoration";
  // Default configuration.
  static DEFAULT_DART_ENTRYPOINT = "main";
  static DEFAULT_INITIAL_ROUTE = "/";
  static DEFAULT_BACKGROUND_MODE = BackgroundMode.opaque;
  // Preload configuration.
  static PRELOAD_VIEWPORT_METRICS_KEY = "viewport_metrics";
}