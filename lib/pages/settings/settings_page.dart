library pica_settings;

import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_reorderable_grid_view/widgets/reorderable_builder.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pica_comic/base.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pica_comic/foundation/comic_source/built_in/picacg.dart';
import 'package:pica_comic/foundation/js_engine.dart';
import 'package:pica_comic/foundation/comic_source/built_in/jm.dart';
import 'package:pica_comic/foundation/log.dart';
import 'package:pica_comic/foundation/cache_manager.dart';
import 'package:pica_comic/foundation/ui_mode.dart';
import 'package:pica_comic/main.dart';
import 'package:pica_comic/network/app_dio.dart';
import 'package:pica_comic/pages/about/about_page.dart';
import 'package:pica_comic/components/components.dart' as components;
import 'package:pica_comic/components/components.dart' hide Select;
import 'package:pica_comic/pages/logs_page.dart';
import 'package:pica_comic/utils/extensions.dart';
import 'package:pica_comic/utils/app_url_launcher.dart';
import 'package:pica_comic/utils/io_tools.dart';
import '../../foundation/comic_source/comic_source.dart';
import '../../components/components.dart' hide Select;
import '../../foundation/app.dart';
import '../../foundation/local_favorites.dart';
import '../../network/cookie_jar.dart';
import '../../network/download.dart';
import '../../network/eh_network/eh_main_network.dart';
import '../../network/http_client.dart';
import '../../network/http_proxy.dart';
import '../../network/jm_network/jm_network.dart';
import '../../network/nhentai_network/nhentai_main_network.dart';
import '../../network/update.dart';
import 'package:pica_comic/pages/settings/app_updater.dart';
import 'package:pica_comic/pages/settings/app_updater_history.dart';
import '../../network/webdav.dart';
import '../../utils/background_service.dart';
import '../../utils/debug.dart';
import '../../utils/io.dart';
import '../welcome_page.dart';
import 'package:pica_comic/utils/translations.dart';
import 'package:pica_comic/utils/font_manager.dart';
import 'package:pica_comic/pages/settings/font_management_page.dart';
import 'package:pica_comic/pages/settings/file_manager_page.dart';
import 'user_comments_page.dart';
import 'pikacg_leavemsg_page.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;

part "reading_settings.dart";
part "picacg_settings.dart";
part "network_setting.dart";
part "multi_pages_filter.dart";
part "local_favorite_settings.dart";
part "jm_settings.dart";
part "hi_settings.dart";
part "ht_settings.dart";
part "explore_settings.dart";
part "eh_settings.dart";
part "nh_settings.dart";
part "comic_source_settings.dart";
part "blocking_keyword_page.dart";
part "app_settings.dart";
part 'components.dart';
part 'debug.dart';
part 'chapter_comments_manager_page.dart';
part 'comic_comments_manager_page.dart';

String get _platformName {
  if (Platform.isIOS) {
    return "iOS版";
  }
  if (Platform.isAndroid) {
    return "Android版";
  }
  if (Platform.isMacOS) {
    return "macOS版";
  }
  if (Platform.isLinux) {
    return "Linux版";
  }
  if (Platform.isWindows) {
    return "Windows版";
  }
  //if (PlatformUtils.isOhos) {
  //  return "Ohos版";
 // }
  return "unknown";
}

Widget? get _platformIcon {
  if (Platform.isIOS) {
    return const SizedBox(
      width: 24,
      height: 12,
      child: CustomPaint(
        painter: _IosPlatformPainter(),
      ),
    );
  }
  if (Platform.isAndroid) {
    return const Icon(Icons.android, size: 16);
  }
  if (Platform.isMacOS) {
    return const SizedBox(
      width: 24,
      height: 6,
      child: CustomPaint(
        painter: _MacosPlatformPainter(),
      ),
    );
  }
      if (Platform.isLinux) {
        return const SizedBox(
          width: 24,
          height: 24,
          child: CustomPaint(
            painter: _LinuxPlatformPainter(),
          ),
        );
      }
  if (Platform.isWindows) {
        return const _WindowsPlatformIcon(size: 24);
  }
      /*
      if (PlatformUtils.isOhos) {
        return const SizedBox(
          width: 24,
          height: 20,
          child: CustomPaint(
            painter: _OhosPlatformPainter(),
          ),
        );
      }
      */
  return null;
}

class _IosPlatformPainter extends CustomPainter {
  const _IosPlatformPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const double designWidth = 117.62;
    const double designHeight = 58.36;

    final double scaleX = size.width / designWidth;
    final double scaleY = size.height / designHeight;
    final double scale = scaleX < scaleY ? scaleX : scaleY;

    final double dx = (size.width - designWidth * scale) / 2;
    final double dy = (size.height - designHeight * scale) / 2;

    canvas.translate(dx, dy);
    canvas.scale(scale, scale);

    final path = Path();
    path.moveTo(0.55, 57.42);
    path.lineTo(10.27, 57.42);
    path.lineTo(10.27, 16.02);
    path.lineTo(0.55, 16.02);
    path.close();
    path.moveTo(5.39, 10.59);
    path.cubicTo(8.44, 10.59, 10.82, 8.24, 10.82, 5.31);
    path.cubicTo(10.82, 2.34, 8.44, 0.00, 5.39, 0.00);
    path.cubicTo(2.38, 0.00, -0.00, 2.34, -0.00, 5.31);
    path.cubicTo(-0.00, 8.24, 2.38, 10.59, 5.39, 10.59);
    path.close();
    path.moveTo(42.66, 0.12);
    path.cubicTo(26.21, 0.12, 15.90, 11.33, 15.90, 29.26);
    path.cubicTo(15.90, 47.19, 26.21, 58.36, 42.66, 58.36);
    path.cubicTo(59.06, 58.36, 69.38, 47.19, 69.38, 29.26);
    path.cubicTo(69.38, 11.33, 59.06, 0.12, 42.66, 0.12);
    path.close();
    path.moveTo(42.66, 8.71);
    path.cubicTo(52.70, 8.71, 59.10, 16.68, 59.10, 29.26);
    path.cubicTo(59.10, 41.80, 52.70, 49.77, 42.66, 49.77);
    path.cubicTo(32.58, 49.77, 26.21, 41.80, 26.21, 29.26);
    path.cubicTo(26.21, 16.68, 32.58, 8.71, 42.66, 8.71);
    path.close();
    path.moveTo(73.48, 41.56);
    path.cubicTo(73.91, 51.95, 82.42, 58.36, 95.39, 58.36);
    path.cubicTo(109.03, 58.36, 117.62, 51.64, 117.62, 40.94);
    path.cubicTo(117.62, 32.54, 112.78, 27.81, 101.33, 25.20);
    path.lineTo(94.85, 23.71);
    path.cubicTo(87.93, 22.07, 85.08, 19.88, 85.08, 16.13);
    path.cubicTo(85.08, 11.45, 89.38, 8.32, 95.75, 8.32);
    path.cubicTo(102.19, 8.32, 106.60, 11.48, 107.07, 16.76);
    path.lineTo(116.68, 16.76);
    path.cubicTo(116.45, 6.84, 108.25, 0.12, 95.82, 0.12);
    path.cubicTo(83.56, 0.12, 74.85, 6.88, 74.85, 16.88);
    path.cubicTo(74.85, 24.92, 79.77, 29.92, 90.16, 32.31);
    path.lineTo(97.46, 34.02);
    path.cubicTo(104.57, 35.70, 107.46, 38.05, 107.46, 42.11);
    path.cubicTo(107.46, 46.80, 102.74, 50.16, 95.94, 50.16);
    path.cubicTo(89.07, 50.16, 83.87, 46.76, 83.25, 41.56);
    path.lineTo(73.48, 41.56);
    path.close();

    final paint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF000000)
      ..isAntiAlias = true;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MacosPlatformPainter extends CustomPainter {
  const _MacosPlatformPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const double designWidth = 248.05;
    const double designHeight = 58.24;

    final double scaleX = size.width / designWidth;
    final double scaleY = size.height / designHeight;
    final double scale = scaleX < scaleY ? scaleX : scaleY;

    final double dx = (size.width - designWidth * scale) / 2;
    final double dy = (size.height - designHeight * scale) / 2;

    canvas.translate(dx, dy);
    canvas.scale(scale, scale);

    final path = Path();
    path.moveTo(0.00, 57.30);
    path.lineTo(9.73, 57.30);
    path.lineTo(9.73, 31.95);
    path.cubicTo(9.73, 26.95, 13.01, 23.32, 17.70, 23.32);
    path.cubicTo(22.23, 23.32, 25.04, 26.17, 25.04, 30.78);
    path.lineTo(25.04, 57.30);
    path.lineTo(34.49, 57.30);
    path.lineTo(34.49, 31.72);
    path.cubicTo(34.49, 26.76, 37.70, 23.32, 42.38, 23.32);
    path.cubicTo(47.15, 23.32, 49.80, 26.21, 49.80, 31.29);
    path.lineTo(49.80, 57.30);
    path.lineTo(59.53, 57.30);
    path.lineTo(59.53, 28.91);
    path.cubicTo(59.53, 20.63, 54.18, 15.12, 46.02, 15.12);
    path.cubicTo(40.04, 15.12, 35.12, 18.32, 33.12, 23.44);
    path.lineTo(32.89, 23.44);
    path.cubicTo(31.37, 18.13, 27.19, 15.12, 21.33, 15.12);
    path.cubicTo(15.70, 15.12, 11.33, 18.28, 9.53, 23.09);
    path.lineTo(9.34, 23.09);
    path.lineTo(9.34, 15.90);
    path.lineTo(-0.00, 15.90);
    path.lineTo(-0.00, 57.30);
    path.close();
    path.moveTo(80.82, 50.63);
    path.cubicTo(76.60, 50.63, 73.79, 48.48, 73.79, 45.08);
    path.cubicTo(73.79, 41.80, 76.49, 39.69, 81.17, 39.38);
    path.lineTo(90.74, 38.79);
    path.lineTo(90.74, 41.95);
    path.cubicTo(90.74, 46.95, 86.33, 50.63, 80.82, 50.63);
    path.close();
    path.moveTo(77.89, 57.97);
    path.cubicTo(83.20, 57.97, 88.40, 55.20, 90.78, 50.70);
    path.lineTo(90.98, 50.70);
    path.lineTo(90.98, 57.30);
    path.lineTo(100.35, 57.30);
    path.lineTo(100.35, 28.79);
    path.cubicTo(100.35, 20.47, 93.67, 15.04, 83.40, 15.04);
    path.cubicTo(72.85, 15.04, 66.25, 20.59, 65.82, 28.32);
    path.lineTo(74.85, 28.32);
    path.cubicTo(75.47, 24.88, 78.40, 22.66, 83.01, 22.66);
    path.cubicTo(87.81, 22.66, 90.74, 25.16, 90.74, 29.49);
    path.lineTo(90.74, 32.46);
    path.lineTo(79.81, 33.09);
    path.cubicTo(69.73, 33.71, 64.06, 38.12, 64.06, 45.47);
    path.cubicTo(64.06, 52.93, 69.88, 57.97, 77.89, 57.97);
    path.close();
    path.moveTo(143.05, 30.66);
    path.cubicTo(142.39, 21.95, 135.63, 15.04, 124.69, 15.04);
    path.cubicTo(112.66, 15.04, 104.85, 23.36, 104.85, 36.60);
    path.cubicTo(104.85, 50.04, 112.66, 58.12, 124.77, 58.12);
    path.cubicTo(135.16, 58.12, 142.31, 52.03, 143.09, 42.77);
    path.lineTo(133.91, 42.77);
    path.cubicTo(133.01, 47.46, 129.81, 50.27, 124.89, 50.27);
    path.cubicTo(118.71, 50.27, 114.73, 45.27, 114.73, 36.60);
    path.cubicTo(114.73, 28.08, 118.68, 22.93, 124.81, 22.93);
    path.cubicTo(130.00, 22.93, 133.09, 26.25, 133.87, 30.66);
    path.lineTo(143.05, 30.66);
    path.close();
    path.moveTo(173.09, 0.00);
    path.cubicTo(156.65, 0.00, 146.33, 11.21, 146.33, 29.14);
    path.cubicTo(146.33, 47.07, 156.65, 58.24, 173.09, 58.24);
    path.cubicTo(189.50, 58.24, 199.81, 47.07, 199.81, 29.14);
    path.cubicTo(199.81, 11.21, 189.50, -0.00, 173.09, -0.00);
    path.close();
    path.moveTo(173.09, 8.59);
    path.cubicTo(183.13, 8.59, 189.54, 16.56, 189.54, 29.14);
    path.cubicTo(189.54, 41.68, 183.13, 49.65, 173.09, 49.65);
    path.cubicTo(163.01, 49.65, 156.65, 41.68, 156.65, 29.14);
    path.cubicTo(156.65, 16.56, 163.01, 8.59, 173.09, 8.59);
    path.close();
    path.moveTo(203.91, 41.45);
    path.cubicTo(204.34, 51.84, 212.86, 58.24, 225.83, 58.24);
    path.cubicTo(239.46, 58.24, 248.05, 51.52, 248.05, 40.82);
    path.cubicTo(248.05, 32.42, 243.21, 27.70, 231.77, 25.08);
    path.lineTo(225.28, 23.59);
    path.cubicTo(218.37, 21.95, 215.52, 19.77, 215.52, 16.02);
    path.cubicTo(215.52, 11.33, 219.81, 8.20, 226.18, 8.20);
    path.cubicTo(232.62, 8.20, 237.04, 11.37, 237.51, 16.64);
    path.lineTo(247.12, 16.64);
    path.cubicTo(246.88, 6.72, 238.68, 0.00, 226.26, 0.00);
    path.cubicTo(213.99, 0.00, 205.28, 6.76, 205.28, 16.76);
    path.cubicTo(205.28, 24.81, 210.20, 29.81, 220.59, 32.19);
    path.lineTo(227.90, 33.91);
    path.cubicTo(235.01, 35.59, 237.90, 37.93, 237.90, 41.99);
    path.cubicTo(237.90, 46.68, 233.17, 50.04, 226.37, 50.04);
    path.cubicTo(219.50, 50.04, 214.30, 46.64, 213.68, 41.45);
    path.lineTo(203.91, 41.45);
    path.close();

    final paint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF000000)
      ..isAntiAlias = true;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LinuxPlatformPainter extends CustomPainter {
  const _LinuxPlatformPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const double designWidth = 424.60;
    const double designHeight = 513.40;

    final double scaleX = size.width / designWidth;
    final double scaleY = size.height / designHeight;
    final double scale = scaleX < scaleY ? scaleX : scaleY;

    final double dx = (size.width - designWidth * scale) / 2;
    final double dy = (size.height - designHeight * scale) / 2;

    canvas.translate(dx, dy);
    canvas.scale(scale, scale);

    final path = Path();
    path.moveTo(209.60, 123.50);
    path.cubicTo(210.60, 124.00, 211.40, 125.20, 212.60, 125.20);
    path.cubicTo(213.70, 125.20, 215.40, 124.80, 215.50, 123.70);
    path.cubicTo(215.70, 122.30, 213.60, 121.40, 212.30, 120.80);
    path.cubicTo(210.60, 120.10, 208.40, 119.80, 206.80, 120.70);
    path.cubicTo(206.40, 120.90, 206.00, 121.40, 206.20, 121.80);
    path.cubicTo(206.50, 123.10, 208.50, 122.90, 209.60, 123.50);
    path.close();
    path.moveTo(187.70, 125.20);
    path.cubicTo(188.90, 125.20, 189.70, 124.00, 190.70, 123.50);
    path.cubicTo(191.80, 122.90, 193.80, 123.10, 194.20, 121.90);
    path.cubicTo(194.40, 121.50, 194.00, 121.00, 193.60, 120.80);
    path.cubicTo(192.00, 119.90, 189.80, 120.20, 188.10, 120.90);
    path.cubicTo(186.80, 121.50, 184.70, 122.40, 184.90, 123.80);
    path.cubicTo(185.00, 124.80, 186.70, 125.30, 187.70, 125.20);
    path.close();
    path.moveTo(408.70, 404.00);
    path.cubicTo(405.10, 400.00, 403.40, 392.40, 401.50, 384.30);
    path.cubicTo(399.70, 376.20, 397.60, 367.50, 391.00, 361.90);
    path.cubicTo(389.70, 360.80, 388.40, 359.80, 387.00, 359.00);
    path.cubicTo(385.70, 358.20, 384.30, 357.50, 382.90, 357.00);
    path.cubicTo(392.10, 329.70, 388.50, 302.50, 379.20, 277.90);
    path.cubicTo(367.80, 247.80, 347.90, 221.50, 332.70, 203.50);
    path.cubicTo(315.60, 182.00, 299.00, 161.60, 299.30, 131.50);
    path.cubicTo(299.80, 85.60, 304.40, 0.30, 223.50, 0.20);
    path.cubicTo(121.10, -0.00, 146.70, 103.60, 145.60, 135.40);
    path.cubicTo(143.90, 158.80, 139.20, 177.20, 123.10, 200.10);
    path.cubicTo(104.20, 222.60, 77.60, 258.90, 65.00, 296.80);
    path.cubicTo(59.00, 314.70, 56.20, 332.90, 58.80, 350.10);
    path.cubicTo(52.30, 355.90, 47.40, 364.80, 42.20, 370.30);
    path.cubicTo(38.00, 374.60, 31.90, 376.20, 25.20, 378.60);
    path.cubicTo(18.50, 381.00, 11.20, 384.60, 6.70, 393.10);
    path.cubicTo(4.60, 397.00, 3.90, 401.20, 3.90, 405.50);
    path.cubicTo(3.90, 409.40, 4.50, 413.40, 5.10, 417.30);
    path.cubicTo(6.30, 425.40, 7.60, 433.00, 5.90, 438.10);
    path.cubicTo(0.70, 452.50, -0.00, 462.50, 3.70, 469.80);
    path.cubicTo(7.50, 477.10, 15.10, 480.30, 23.80, 482.10);
    path.cubicTo(41.10, 485.70, 64.60, 484.80, 83.10, 494.60);
    path.cubicTo(102.90, 505.00, 123.00, 508.70, 139.00, 505.00);
    path.cubicTo(150.60, 502.40, 160.10, 495.40, 164.90, 484.80);
    path.cubicTo(177.40, 484.70, 191.20, 479.40, 213.20, 478.20);
    path.cubicTo(228.10, 477.00, 246.80, 483.50, 268.30, 482.30);
    path.cubicTo(268.90, 484.60, 269.70, 486.90, 270.80, 489.00);
    path.lineTo(270.80, 489.10);
    path.cubicTo(279.10, 505.80, 294.60, 513.40, 311.10, 512.10);
    path.cubicTo(327.70, 510.80, 345.20, 501.10, 359.40, 484.20);
    path.cubicTo(373.00, 467.80, 395.40, 461.00, 410.30, 452.00);
    path.cubicTo(417.70, 447.50, 423.70, 441.90, 424.20, 433.70);
    path.cubicTo(424.60, 425.50, 419.80, 416.40, 408.70, 404.00);
    path.close();
    path.moveTo(212.50, 87.50);
    path.cubicTo(222.30, 65.30, 246.70, 65.70, 256.50, 87.10);
    path.cubicTo(263.00, 101.30, 260.10, 118.00, 252.20, 127.50);
    path.cubicTo(250.60, 126.70, 246.30, 124.90, 239.60, 122.60);
    path.cubicTo(240.70, 121.40, 242.70, 119.90, 243.50, 118.00);
    path.cubicTo(248.30, 106.20, 243.30, 91.00, 234.40, 90.70);
    path.cubicTo(227.10, 90.20, 220.50, 101.50, 222.60, 113.70);
    path.cubicTo(218.50, 111.70, 213.20, 110.20, 209.60, 109.30);
    path.cubicTo(208.60, 102.40, 209.30, 94.70, 212.50, 87.50);
    path.close();
    path.moveTo(171.80, 76.00);
    path.cubicTo(181.90, 76.00, 192.60, 90.20, 190.90, 109.50);
    path.cubicTo(187.40, 110.50, 183.80, 112.00, 180.70, 114.10);
    path.cubicTo(181.90, 105.20, 177.40, 94.00, 171.10, 94.50);
    path.cubicTo(162.70, 95.20, 161.30, 115.70, 169.30, 122.60);
    path.cubicTo(170.30, 123.40, 171.20, 122.40, 163.40, 128.10);
    path.cubicTo(147.80, 113.50, 152.90, 76.00, 171.80, 76.00);
    path.close();
    path.moveTo(158.20, 136.70);
    path.cubicTo(164.40, 132.10, 171.80, 126.70, 172.30, 126.20);
    path.cubicTo(177.00, 121.80, 185.80, 112.00, 200.20, 112.00);
    path.cubicTo(207.30, 112.00, 215.80, 114.30, 226.10, 120.90);
    path.cubicTo(232.40, 125.00, 237.40, 125.30, 248.70, 130.20);
    path.cubicTo(257.10, 133.70, 262.40, 139.90, 259.20, 148.40);
    path.cubicTo(256.60, 155.50, 248.20, 162.80, 236.50, 166.50);
    path.cubicTo(225.40, 170.10, 216.70, 182.50, 198.30, 181.40);
    path.cubicTo(194.40, 181.20, 191.30, 180.40, 188.70, 179.30);
    path.cubicTo(180.70, 175.80, 176.50, 168.90, 168.70, 164.30);
    path.cubicTo(160.10, 159.50, 155.50, 153.90, 154.00, 149.00);
    path.cubicTo(152.60, 144.10, 154.00, 140.00, 158.20, 136.70);
    path.close();
    path.moveTo(161.50, 470.70);
    path.cubicTo(158.80, 505.80, 117.60, 505.10, 86.20, 488.70);
    path.cubicTo(56.30, 472.90, 17.60, 482.20, 9.70, 466.80);
    path.cubicTo(7.30, 462.10, 7.30, 454.10, 12.30, 440.40);
    path.lineTo(12.30, 440.20);
    path.cubicTo(14.70, 432.60, 12.90, 424.20, 11.70, 416.30);
    path.cubicTo(10.50, 408.50, 9.90, 401.30, 12.60, 396.30);
    path.cubicTo(16.10, 389.60, 21.10, 387.20, 27.40, 385.00);
    path.cubicTo(37.70, 381.30, 39.20, 381.60, 47.00, 375.10);
    path.cubicTo(52.50, 369.40, 56.50, 362.20, 61.30, 357.10);
    path.cubicTo(66.40, 351.60, 71.30, 349.00, 79.00, 350.20);
    path.cubicTo(87.10, 351.40, 94.10, 357.00, 100.90, 366.20);
    path.lineTo(120.50, 401.80);
    path.cubicTo(130.00, 421.70, 163.60, 450.20, 161.50, 470.70);
    path.close();
    path.moveTo(160.10, 444.80);
    path.cubicTo(156.00, 438.20, 150.50, 431.20, 145.70, 425.20);
    path.cubicTo(152.80, 425.20, 159.90, 423.00, 162.40, 416.30);
    path.cubicTo(164.70, 410.10, 162.40, 401.40, 155.00, 391.40);
    path.cubicTo(141.50, 373.20, 116.70, 358.90, 116.70, 358.90);
    path.cubicTo(103.20, 350.50, 95.60, 340.20, 92.10, 329.00);
    path.cubicTo(88.60, 317.80, 89.10, 305.70, 91.80, 293.80);
    path.cubicTo(97.00, 270.90, 110.40, 248.60, 119.00, 234.60);
    path.cubicTo(121.30, 232.90, 119.80, 237.80, 110.30, 255.40);
    path.cubicTo(101.80, 271.50, 85.90, 308.70, 107.70, 337.80);
    path.cubicTo(108.30, 317.10, 113.20, 296.00, 121.50, 276.30);
    path.cubicTo(133.50, 248.90, 158.80, 201.40, 160.80, 163.60);
    path.cubicTo(161.90, 164.40, 165.40, 166.80, 167.00, 167.70);
    path.cubicTo(171.60, 170.40, 175.10, 174.40, 179.60, 178.00);
    path.cubicTo(192.00, 188.00, 208.10, 187.20, 222.00, 179.20);
    path.cubicTo(228.20, 175.70, 233.20, 171.70, 237.90, 170.20);
    path.cubicTo(247.80, 167.10, 255.70, 161.60, 260.20, 155.20);
    path.cubicTo(267.90, 185.60, 285.90, 229.50, 297.40, 250.90);
    path.cubicTo(303.50, 262.30, 315.70, 286.40, 321.00, 315.50);
    path.cubicTo(324.30, 315.40, 328.00, 315.90, 331.90, 316.90);
    path.cubicTo(345.70, 281.20, 320.20, 242.70, 308.60, 232.00);
    path.cubicTo(303.90, 227.40, 303.70, 225.40, 306.00, 225.50);
    path.cubicTo(318.60, 236.70, 335.20, 259.20, 341.20, 284.50);
    path.cubicTo(344.00, 296.10, 344.50, 308.20, 341.60, 320.20);
    path.cubicTo(358.00, 327.00, 377.50, 338.10, 372.30, 355.00);
    path.cubicTo(370.10, 354.90, 369.10, 355.00, 368.10, 355.00);
    path.cubicTo(371.30, 344.90, 364.20, 337.40, 345.30, 328.90);
    path.cubicTo(325.70, 320.30, 309.30, 320.30, 307.00, 341.40);
    path.cubicTo(294.90, 345.60, 288.70, 356.10, 285.60, 368.70);
    path.cubicTo(282.80, 379.90, 282.00, 393.40, 281.20, 408.60);
    path.cubicTo(280.70, 416.30, 277.60, 426.60, 274.40, 437.60);
    path.cubicTo(242.30, 460.50, 197.70, 470.50, 160.10, 444.80);
    path.close();
    path.moveTo(417.50, 433.30);
    path.cubicTo(416.60, 450.10, 376.30, 453.20, 354.30, 479.80);
    path.cubicTo(341.10, 495.50, 324.90, 504.20, 310.70, 505.30);
    path.cubicTo(296.50, 506.40, 284.20, 500.50, 277.00, 486.00);
    path.cubicTo(272.30, 474.90, 274.60, 462.90, 278.10, 449.70);
    path.cubicTo(281.80, 435.50, 287.30, 420.90, 288.00, 409.10);
    path.cubicTo(288.80, 393.90, 289.70, 380.60, 292.20, 370.40);
    path.cubicTo(294.80, 360.10, 298.80, 353.20, 305.90, 349.30);
    path.cubicTo(306.20, 349.10, 306.60, 349.00, 306.90, 348.80);
    path.cubicTo(307.70, 362.00, 314.20, 375.40, 325.70, 378.30);
    path.cubicTo(338.30, 381.60, 356.40, 370.80, 364.10, 362.00);
    path.cubicTo(373.10, 361.70, 379.80, 361.10, 386.70, 367.10);
    path.cubicTo(396.60, 375.60, 393.80, 397.40, 403.80, 408.70);
    path.cubicTo(414.40, 420.30, 417.80, 428.20, 417.50, 433.30);
    path.close();
    path.moveTo(162.10, 148.90);
    path.cubicTo(164.10, 150.80, 166.80, 153.40, 170.10, 156.00);
    path.cubicTo(176.70, 161.20, 185.90, 166.60, 197.40, 166.60);
    path.cubicTo(209.00, 166.60, 219.90, 160.70, 229.20, 155.80);
    path.cubicTo(234.10, 153.20, 240.10, 148.80, 244.00, 145.40);
    path.cubicTo(247.90, 142.00, 249.90, 139.10, 247.10, 138.80);
    path.cubicTo(244.30, 138.50, 244.50, 141.40, 241.10, 143.90);
    path.cubicTo(236.70, 147.10, 231.40, 151.30, 227.20, 153.70);
    path.cubicTo(219.80, 157.90, 207.70, 163.90, 197.30, 163.90);
    path.cubicTo(186.90, 163.90, 178.60, 159.10, 172.40, 154.20);
    path.cubicTo(169.30, 151.70, 166.70, 149.20, 164.70, 147.30);
    path.cubicTo(163.20, 145.90, 162.80, 142.70, 160.40, 142.40);
    path.cubicTo(159.00, 142.30, 158.60, 146.10, 162.10, 148.90);
    path.close();

    final paint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF000000)
      ..isAntiAlias = true;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _WindowsPlatformIcon extends StatelessWidget {
  const _WindowsPlatformIcon({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: const CustomPaint(
        painter: _WindowsPlatformPainter(),
      ),
    );
  }
}

class _WindowsPlatformPainter extends CustomPainter {
  const _WindowsPlatformPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const double designWidth = 448.00;
    const double designHeight = 448.00;

    final double scaleX = size.width / designWidth;
    final double scaleY = size.height / designHeight;
    final double scale = scaleX < scaleY ? scaleX : scaleY;

    final double dx = (size.width - designWidth * scale) / 2;
    final double dy = (size.height - designHeight * scale) / 2;

    canvas.translate(dx, dy);
    canvas.scale(scale, scale);

    final path = Path();
    path.moveTo(0.00, 61.70);
    path.lineTo(183.60, 36.40);
    path.lineTo(183.60, 213.80);
    path.lineTo(0.00, 213.80);
    path.close();
    path.moveTo(0.00, 386.30);
    path.lineTo(183.60, 411.60);
    path.lineTo(183.60, 236.40);
    path.lineTo(0.00, 236.40);
    path.close();
    path.moveTo(203.80, 414.30);
    path.lineTo(448.00, 448.00);
    path.lineTo(448.00, 236.40);
    path.lineTo(203.80, 236.40);
    path.close();
    path.moveTo(203.80, 33.70);
    path.lineTo(203.80, 213.80);
    path.lineTo(448.00, 213.80);
    path.lineTo(448.00, 0.00);
    path.close();

    final paint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF000000)
      ..isAntiAlias = true;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/*
class _OhosPlatformPainter extends CustomPainter {
  const _OhosPlatformPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const double designWidth = 298.90;
    const double designHeight = 246.83;

    final double scaleX = size.width / designWidth;
    final double scaleY = size.height / designHeight;
    final double scale = scaleX < scaleY ? scaleX : scaleY;

    final double dx = (size.width - designWidth * scale) / 2;
    final double dy = (size.height - designHeight * scale) / 2;

    canvas.translate(dx, dy);
    canvas.scale(scale, scale);

    final path = Path();
    path.moveTo(243.86, 136.82);
    path.lineTo(218.86, 136.82);
    path.cubicTo(218.34, 136.82, 217.91, 137.22, 217.86, 137.73);
    path.lineTo(217.86, 138.04);
    path.cubicTo(217.36, 141.28, 216.69, 144.49, 215.86, 147.65);
    path.lineTo(215.10, 150.41);
    path.lineTo(214.76, 151.59);
    path.lineTo(214.39, 152.77);
    path.lineTo(213.66, 154.96);
    path.lineTo(213.23, 156.20);
    path.lineTo(212.36, 158.48);
    path.lineTo(211.95, 159.54);
    path.lineTo(210.57, 162.80);
    path.lineTo(210.15, 163.69);
    path.lineTo(208.95, 166.24);
    path.cubicTo(204.99, 174.16, 199.97, 181.49, 194.02, 188.04);
    path.lineTo(191.55, 190.67);
    path.lineTo(188.71, 193.48);
    path.lineTo(188.26, 193.89);
    path.lineTo(185.65, 196.31);
    path.lineTo(184.58, 197.22);
    path.lineTo(182.44, 198.97);
    path.lineTo(181.20, 199.97);
    path.lineTo(179.08, 201.56);
    path.lineTo(177.80, 202.48);
    path.lineTo(175.50, 204.03);
    path.lineTo(174.32, 204.81);
    path.lineTo(171.26, 206.69);
    path.lineTo(170.76, 206.99);
    path.lineTo(167.10, 208.99);
    path.lineTo(165.98, 209.55);
    path.lineTo(163.33, 210.85);
    path.lineTo(161.92, 211.49);
    path.lineTo(159.44, 212.56);
    path.lineTo(157.95, 213.17);
    path.lineTo(155.40, 214.17);
    path.lineTo(153.95, 214.70);
    path.lineTo(150.95, 215.70);
    path.lineTo(149.87, 216.05);
    path.lineTo(145.75, 217.17);
    path.lineTo(144.84, 217.38);
    path.lineTo(141.55, 218.11);
    path.lineTo(140.06, 218.38);
    path.lineTo(137.27, 218.86);
    path.lineTo(135.63, 219.10);
    path.lineTo(132.86, 219.44);
    path.lineTo(131.22, 219.61);
    path.lineTo(128.22, 219.83);
    path.lineTo(126.80, 219.91);
    path.lineTo(122.35, 220.02);
    path.cubicTo(69.02, 220.02, 25.79, 176.79, 25.79, 123.46);
    path.cubicTo(25.79, 70.13, 69.02, 26.90, 122.35, 26.90);
    path.lineTo(126.81, 27.01);
    path.lineTo(128.23, 27.09);
    path.lineTo(131.23, 27.31);
    path.lineTo(132.86, 27.48);
    path.lineTo(135.63, 27.81);
    path.lineTo(137.27, 28.05);
    path.lineTo(140.06, 28.53);
    path.lineTo(141.56, 28.81);
    path.lineTo(144.85, 29.54);
    path.lineTo(145.76, 29.75);
    path.lineTo(149.87, 30.87);
    path.lineTo(150.95, 31.21);
    path.lineTo(153.95, 32.21);
    path.lineTo(155.39, 32.74);
    path.lineTo(157.95, 33.74);
    path.lineTo(159.44, 34.35);
    path.lineTo(161.91, 35.42);
    path.lineTo(163.33, 36.06);
    path.lineTo(165.98, 37.36);
    path.lineTo(167.10, 37.92);
    path.lineTo(170.76, 39.92);
    path.lineTo(171.25, 40.22);
    path.lineTo(174.32, 42.10);
    path.lineTo(175.50, 42.87);
    path.lineTo(177.79, 44.43);
    path.lineTo(179.07, 45.35);
    path.lineTo(181.02, 46.61);
    path.lineTo(181.94, 47.34);
    path.lineTo(185.35, 50.15);
    path.cubicTo(186.48, 51.13, 187.59, 52.13, 188.67, 53.15);
    path.lineTo(190.90, 55.35);
    path.cubicTo(191.09, 55.54, 191.35, 55.65, 191.62, 55.64);
    path.lineTo(223.62, 55.64);
    path.cubicTo(224.02, 55.68, 224.39, 55.47, 224.58, 55.13);
    path.cubicTo(224.77, 54.78, 224.74, 54.36, 224.50, 54.04);
    path.cubicTo(221.74, 49.97, 218.73, 46.06, 215.50, 42.34);
    path.lineTo(212.42, 39.00);
    path.lineTo(211.47, 38.00);
    path.lineTo(210.47, 36.94);
    path.lineTo(210.12, 36.60);
    path.lineTo(209.66, 36.12);
    path.cubicTo(208.26, 34.73, 206.83, 33.36, 205.37, 32.04);
    path.lineTo(205.25, 31.94);
    path.lineTo(205.17, 31.85);
    path.lineTo(204.58, 31.35);
    path.lineTo(200.90, 28.16);
    path.lineTo(200.11, 27.54);
    path.lineTo(199.57, 27.08);
    path.lineTo(198.42, 26.21);
    path.lineTo(196.28, 24.53);
    path.lineTo(194.62, 23.31);
    path.lineTo(193.62, 22.56);
    path.lineTo(193.57, 22.56);
    path.lineTo(192.67, 21.96);
    path.lineTo(191.34, 21.02);
    path.lineTo(188.68, 19.31);
    path.lineTo(187.47, 18.50);
    path.lineTo(187.42, 18.50);
    path.lineTo(186.96, 18.24);
    path.lineTo(186.35, 17.84);
    path.cubicTo(184.66, 16.84, 182.93, 15.84, 181.18, 14.84);
    path.lineTo(181.09, 14.84);
    path.lineTo(181.02, 14.79);
    path.cubicTo(179.92, 14.21, 178.82, 13.63, 177.72, 13.07);
    path.lineTo(176.41, 12.44);
    path.lineTo(175.86, 12.15);
    path.lineTo(175.37, 11.93);
    path.lineTo(174.37, 11.45);
    path.cubicTo(173.24, 10.92, 172.11, 10.45, 170.96, 9.92);
    path.lineTo(170.61, 9.77);
    path.lineTo(170.40, 9.68);
    path.lineTo(169.90, 9.49);
    path.lineTo(167.49, 8.49);
    path.lineTo(165.39, 7.70);
    path.lineTo(164.80, 7.47);
    path.lineTo(164.50, 7.37);
    path.lineTo(163.97, 7.17);
    path.cubicTo(162.79, 6.75, 161.59, 6.34, 160.40, 5.95);
    path.lineTo(159.52, 5.68);
    path.lineTo(159.07, 5.53);
    path.lineTo(158.44, 5.35);
    path.lineTo(156.79, 4.84);
    path.lineTo(153.35, 3.90);
    path.lineTo(153.15, 3.90);
    path.cubicTo(151.92, 3.59, 150.68, 3.29, 149.44, 3.01);
    path.lineTo(147.91, 2.69);
    path.lineTo(147.27, 2.55);
    path.lineTo(146.76, 2.45);
    path.lineTo(145.69, 2.23);
    path.cubicTo(144.43, 1.99, 143.17, 1.78, 141.90, 1.57);
    path.lineTo(141.45, 1.51);
    path.lineTo(141.19, 1.46);
    path.lineTo(140.60, 1.39);
    path.lineTo(138.02, 0.91);
    path.lineTo(135.60, 0.64);
    path.lineTo(134.97, 0.56);
    path.lineTo(134.68, 0.56);
    path.lineTo(134.15, 0.51);
    path.cubicTo(132.86, 0.38, 131.56, 0.28, 130.25, 0.20);
    path.lineTo(129.25, 0.15);
    path.lineTo(128.02, 0.15);
    path.lineTo(126.31, 0.07);
    path.cubicTo(124.99, 0.07, 123.68, 0.00, 122.31, 0.00);
    path.cubicTo(54.59, 0.61, 0.00, 55.69, 0.00, 123.42);
    path.cubicTo(0.00, 191.15, 54.59, 246.22, 122.31, 246.83);
    path.cubicTo(123.64, 246.83, 124.96, 246.83, 126.31, 246.76);
    path.lineTo(127.71, 246.76);
    path.lineTo(128.55, 246.71);
    path.lineTo(130.24, 246.63);
    path.lineTo(132.15, 246.47);
    path.lineTo(133.02, 246.31);
    path.lineTo(133.47, 246.26);
    path.lineTo(134.15, 246.21);
    path.cubicTo(135.44, 246.09, 136.73, 245.95, 138.01, 245.78);
    path.lineTo(138.25, 245.78);
    path.lineTo(138.73, 245.71);
    path.lineTo(141.84, 245.27);
    path.lineTo(142.84, 245.10);
    path.lineTo(143.44, 245.00);
    path.lineTo(144.21, 244.85);
    path.lineTo(145.65, 244.60);
    path.lineTo(147.73, 244.17);
    path.lineTo(148.55, 244.01);
    path.lineTo(148.90, 243.93);
    path.lineTo(149.41, 243.83);
    path.cubicTo(150.65, 243.56, 151.89, 243.26, 153.11, 242.94);
    path.lineTo(153.38, 242.87);
    path.lineTo(153.57, 242.87);
    path.lineTo(154.23, 242.68);
    path.lineTo(156.77, 241.99);
    path.lineTo(157.87, 241.65);
    path.lineTo(158.51, 241.47);
    path.lineTo(159.20, 241.24);
    path.lineTo(160.39, 240.88);
    path.lineTo(162.65, 240.11);
    path.lineTo(163.37, 239.87);
    path.lineTo(163.61, 239.78);
    path.lineTo(163.96, 239.66);
    path.cubicTo(165.14, 239.24, 166.31, 238.80, 167.48, 238.35);
    path.lineTo(167.86, 238.19);
    path.lineTo(168.13, 238.08);
    path.lineTo(168.85, 237.78);
    path.lineTo(170.94, 236.92);
    path.lineTo(172.13, 236.39);
    path.lineTo(172.80, 236.10);
    path.lineTo(173.38, 235.83);
    path.lineTo(174.38, 235.39);
    path.lineTo(176.84, 234.20);
    path.lineTo(177.39, 233.94);
    path.lineTo(177.54, 233.87);
    path.lineTo(177.74, 233.77);
    path.cubicTo(178.85, 233.21, 179.95, 232.64, 181.04, 232.05);
    path.lineTo(181.35, 231.87);
    path.lineTo(181.85, 231.60);
    path.cubicTo(183.32, 230.80, 184.77, 229.95, 186.21, 229.09);
    path.lineTo(186.99, 228.59);
    path.lineTo(187.43, 228.33);
    path.cubicTo(187.45, 228.34, 187.47, 228.34, 187.48, 228.33);
    path.lineTo(188.28, 227.81);
    path.lineTo(190.42, 226.31);
    path.lineTo(192.81, 224.66);
    path.lineTo(193.57, 224.15);
    path.lineTo(193.63, 224.15);
    path.lineTo(193.95, 223.91);
    path.lineTo(194.54, 223.50);
    path.cubicTo(195.90, 222.50, 197.23, 221.50, 198.54, 220.50);
    path.lineTo(199.13, 220.02);
    path.lineTo(199.48, 219.76);
    path.lineTo(199.53, 219.76);
    path.lineTo(200.24, 219.16);
    path.lineTo(202.41, 217.38);
    path.lineTo(204.41, 215.62);
    path.lineTo(205.12, 215.01);
    path.lineTo(205.48, 214.66);
    path.lineTo(206.13, 214.09);
    path.cubicTo(207.35, 212.97, 208.55, 211.81, 209.72, 210.62);
    path.lineTo(210.15, 210.18);
    path.lineTo(210.40, 209.93);
    path.lineTo(210.45, 209.93);
    path.lineTo(211.04, 209.28);
    path.lineTo(213.18, 207.05);
    path.lineTo(214.78, 205.25);
    path.lineTo(215.42, 204.56);
    path.lineTo(215.42, 204.51);
    path.lineTo(215.78, 204.07);
    path.lineTo(216.46, 203.31);
    path.cubicTo(217.53, 202.04, 218.59, 200.75, 219.62, 199.43);
    path.lineTo(219.89, 199.06);
    path.lineTo(220.06, 198.85);
    path.lineTo(220.52, 198.21);
    path.lineTo(222.52, 195.48);
    path.lineTo(223.76, 193.67);
    path.lineTo(224.33, 192.89);
    path.lineTo(224.81, 192.16);
    path.lineTo(225.36, 191.35);
    path.cubicTo(230.93, 182.90, 235.43, 173.79, 238.76, 164.23);
    path.lineTo(238.86, 163.95);
    path.lineTo(238.86, 163.88);
    path.lineTo(239.34, 162.37);
    path.lineTo(240.34, 159.37);
    path.lineTo(240.45, 158.99);
    path.lineTo(240.56, 158.64);
    path.lineTo(241.01, 156.95);
    path.lineTo(241.72, 154.42);
    path.lineTo(241.84, 153.90);
    path.lineTo(242.01, 153.31);
    path.lineTo(242.73, 150.07);
    path.lineTo(242.89, 149.38);
    path.lineTo(243.22, 147.87);
    path.cubicTo(243.59, 146.05, 243.92, 144.21, 244.22, 142.36);
    path.lineTo(244.75, 138.23);
    path.cubicTo(244.89, 137.93, 244.86, 137.57, 244.69, 137.29);
    path.cubicTo(244.51, 137.01, 244.20, 136.83, 243.86, 136.82);
    path.moveTo(162.28, 106.47);
    path.lineTo(163.37, 109.47);
    path.lineTo(191.16, 109.47);
    path.lineTo(191.11, 109.20);
    path.cubicTo(189.27, 100.23, 185.69, 91.70, 180.56, 84.10);
    path.lineTo(179.41, 82.50);
    path.lineTo(136.79, 82.50);
    path.lineTo(137.27, 82.66);
    path.cubicTo(148.54, 86.81, 157.59, 95.42, 162.28, 106.47);
    path.moveTo(180.56, 162.56);
    path.cubicTo(185.69, 154.97, 189.28, 146.45, 191.11, 137.47);
    path.lineTo(191.19, 136.93);
    path.lineTo(163.46, 136.93);
    path.lineTo(162.27, 140.18);
    path.cubicTo(157.87, 150.57, 149.60, 158.83, 139.22, 163.23);
    path.lineTo(137.53, 163.90);
    path.lineTo(179.60, 163.90);
    path.close();
    path.moveTo(272.02, 108.04);
    path.lineTo(272.17, 110.04);
    path.lineTo(298.90, 110.04);
    path.lineTo(298.90, 109.82);
    path.cubicTo(298.34, 102.41, 297.31, 95.04, 295.82, 87.76);
    path.lineTo(294.73, 83.07);
    path.lineTo(267.30, 83.07);
    path.lineTo(268.09, 85.84);
    path.cubicTo(269.96, 93.13, 271.27, 100.56, 272.02, 108.04);
    path.moveTo(272.17, 136.78);
    path.lineTo(272.02, 138.78);
    path.cubicTo(271.25, 146.28, 269.92, 153.71, 268.02, 161.00);
    path.lineTo(267.25, 163.71);
    path.lineTo(294.70, 163.71);
    path.lineTo(295.77, 159.09);
    path.cubicTo(297.27, 151.81, 298.30, 144.44, 298.85, 137.03);
    path.lineTo(298.85, 136.74);
    path.close();
    path.moveTo(239.02, 82.91);
    path.lineTo(238.86, 82.49);
    path.lineTo(209.86, 82.49);
    path.lineTo(210.46, 83.74);
    path.cubicTo(214.00, 91.63, 216.45, 99.97, 217.76, 108.51);
    path.lineTo(217.91, 109.74);
    path.lineTo(245.02, 109.74);
    path.lineTo(244.34, 104.43);
    path.cubicTo(243.22, 97.11, 241.44, 89.91, 239.02, 82.91);

    final paint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF000000)
      ..isAntiAlias = true;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
*/

class SettingsPage extends StatefulWidget {
  static void open([int initialPage = -1, VoidCallback? onPop]) {
    App.globalTo(() => SettingsPage(initialPage: initialPage, onPop: onPop));
  }

  const SettingsPage({this.initialPage = -1, this.onPop, super.key});

  final int initialPage;
  final VoidCallback? onPop;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> implements PopEntry {
  static const int _aboutPageIndex = 6;
  static const int _appUpdaterHistoryIndex = 7;
  static const int _fileManagerIndex = 8;
  static const int _debugPageIndex = 9;

  int currentPage = -1;

  ColorScheme get colors => Theme.of(context).colorScheme;

  bool get enableTwoViews => !UiMode.m1(context);

  bool get enableLiquidGlassSettingsUi =>
      appdata.settings.length > 103 && appdata.settings[103] == "1";

  final categories = <String>[
    "浏览",
    "阅读",
    "外观",
    "本地收藏",
    "APP",
    "网络",
    "关于",
    "历史版本",
    "文件管理器",
    "Debug"
  ];

  final icons = <IconData>[
    Icons.explore,
    Icons.book,
    Icons.color_lens,
    Icons.collections_bookmark_rounded,
    Icons.apps,
    Icons.public,
    Icons.info,
    Icons.history,
    Icons.folder_open,
    Icons.bug_report,
  ];

  double offset = 0;

  late final HorizontalDragGestureRecognizer gestureRecognizer;

  ModalRoute? _route;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ModalRoute<dynamic>? nextRoute = ModalRoute.of(context);
    if (nextRoute != _route) {
      _route?.unregisterPopEntry(this);
      _route = nextRoute;
      _route?.registerPopEntry(this);
    }
  }

  @override
  void initState() {
    currentPage = widget.initialPage;
    gestureRecognizer = HorizontalDragGestureRecognizer(debugOwner: this)
      ..onUpdate = ((details) => setState(() => offset += details.delta.dx))
      ..onEnd = (details) async {
        if (details.velocity.pixelsPerSecond.dx.abs() > 1 &&
            details.velocity.pixelsPerSecond.dx >= 0) {
          setState(() {
            Future.delayed(const Duration(milliseconds: 300), () => offset = 0);
            currentPage = -1;
          });
        } else if (offset > MediaQuery.of(context).size.width / 2) {
          setState(() {
            Future.delayed(const Duration(milliseconds: 300), () => offset = 0);
            currentPage = -1;
          });
        } else {
          int i = 10;
          while (offset != 0) {
            setState(() {
              offset -= i;
              i *= 10;
              if (offset < 0) {
                offset = 0;
              }
            });
            await Future.delayed(const Duration(milliseconds: 10));
          }
        }
      }
      ..onCancel = () async {
        int i = 10;
        while (offset != 0) {
          setState(() {
            offset -= i;
            i *= 10;
            if (offset < 0) {
              offset = 0;
            }
          });
          await Future.delayed(const Duration(milliseconds: 10));
        }
      };
    super.initState();
  }

  @override
  dispose() {
    super.dispose();
    gestureRecognizer.dispose();
    App.temporaryDisablePopGesture = false;
    _route?.unregisterPopEntry(this);
  }

  @override
  Widget build(BuildContext context) {
    if (App.isFluent) {
      return buildFluent(context);
    }
    if (currentPage != -1 && !enableTwoViews) {
      canPop.value = false;
      App.temporaryDisablePopGesture = true;
    } else {
      canPop.value = true;
      App.temporaryDisablePopGesture = false;
    }
    return Material(
      child: buildBody(),
    );
  }

  Widget buildFluent(BuildContext context) {
    if (UiMode.m1(context)) {
      if (currentPage == -1) {
        return fluent.ScaffoldPage(
          header: fluent.PageHeader(
            leading: fluent.IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text("设置".tl),
          ),
          content: ListView.builder(
            itemCount: categories.length,
            itemBuilder: (context, index) {
              return fluent.ListTile(
                leading: Icon(icons[index]),
                title: Text(categories[index].tl),
                trailing: const Icon(Icons.arrow_right),
                onPressed: () => setState(() => currentPage = index),
              );
            },
          ),
        );
      } else {
        return fluent.ScaffoldPage(
          header: fluent.PageHeader(
            leading: fluent.IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                setState(() {
                  currentPage = -1;
                });
              },
            ),
            title: Text(categories[currentPage].tl),
          ),
          content: fluent.ScaffoldPage.scrollable(
            children: [
              buildFluentRight(currentPage),
            ],
          ),
        );
      }
    }
    return fluent.NavigationView(
      pane: fluent.NavigationPane(
        selected: currentPage == -1 ? 0 : currentPage,
        onChanged: (i) => setState(() => currentPage = i),
        displayMode: fluent.PaneDisplayMode.open,
        items: List.generate(categories.length, (index) {
          return fluent.PaneItem(
            icon: Icon(icons[index]),
            title: Text(categories[index].tl),
            body: fluent.ScaffoldPage.scrollable(
              children: [
                buildFluentRight(index),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget buildFluentRight(int index) {
    switch (index) {
      case 0:
        return buildExploreSettings(context, false);
      case 1:
        return const ReadingSettings(false);
      case 2:
        return buildFluentAppearanceSettings();
      case 3:
        return const LocalFavoritesSettings();
      case 4:
        return buildFluentAppSettings();
      case 5:
        return const NetworkSettings();
      case _aboutPageIndex:
        return buildFluentAbout();
      case _appUpdaterHistoryIndex:
        return const AppUpdaterHistoryPage(embedded: true);
      case _fileManagerIndex:
        return const FileManagerPage();
      case _debugPageIndex:
        return const DebugPage();
      default:
        return const SizedBox();
    }
  }

  Widget buildFluentAppSettings() {
    return Column(
      children: [
        fluent.ListTile(
          title: Text("数据".tl),
          leading: const Icon(Icons.storage),
        ),
        fluent.ListTile(
          title: Text("本地漫画的存储路径".tl),
          subtitle: Text(DownloadManager().path ?? "", softWrap: false),
          trailing: fluent.IconButton(
            icon: const Icon(Icons.copy),
            onPressed: () {
              Clipboard.setData(
                  ClipboardData(text: DownloadManager().path ?? ""));
              context.showMessage(message: "路径已复制到剪贴板".tl);
            },
          ),
        ),
        if (App.isDesktop || App.isAndroid)
          fluent.ListTile(
            title: Text("设置下载目录".tl),
            onPressed: () => setDownloadFolder(),
            trailing: fluent.Button(
              onPressed: () => setDownloadFolder(),
              child: Text('设置'.tl),
            ),
          ),
        fluent.ListTile(
          title: Text("缓存大小".tl),
          subtitle: Text(bytesToReadableString(CacheManager().currentSize)),
        ),
        fluent.ListTile(
          title: Text("清除缓存".tl),
          onPressed: () async {
            var loadingDialog = showLoadingDialog(
              context,
              barrierDismissible: false,
              allowCancel: false,
            );
            await CacheManager().clear();
            loadingDialog.close();
            context.showMessage(message: "Cache cleared".tl);
            setState(() {});
          },
          trailing: fluent.Button(
            onPressed: () async {
              var loadingDialog = showLoadingDialog(
                context,
                barrierDismissible: false,
                allowCancel: false,
              );
              await CacheManager().clear();
              loadingDialog.close();
              context.showMessage(message: "Cache cleared".tl);
              setState(() {});
            },
            child: Text("清除".tl),
          ),
        ),
        fluent.ListTile(
            title: Text("缓存限制".tl),
            subtitle:
                Text('${bytesLengthToReadableSize(CacheManager().limitSize)}'),
            onPressed: setCacheLimit,
            trailing: fluent.Button(
              onPressed: setCacheLimit,
              child: Text('设置'.tl),
            )),
        fluent.ListTile(
          title: Text("删除所有数据".tl),
          onPressed: () => clearUserData(context),
          trailing: fluent.Button(
            onPressed: () => clearUserData(context),
            child: Text('删除'.tl),
          ),
        ),
        fluent.ListTile(
          title: Text("导出用户数据".tl),
          onPressed: () => exportDataSetting(context),
          trailing: fluent.Button(
            onPressed: () => exportDataSetting(context),
            child: Text('导出'.tl),
          ),
        ),
        fluent.ListTile(
          title: Text("导入用户数据".tl),
          onPressed: () => importDataSetting(context),
          trailing: fluent.Button(
            onPressed: () => importDataSetting(context),
            child: Text('导入'.tl),
          ),
        ),
        fluent.ListTile(
          title: Text("数据同步".tl),
          onPressed: () => syncDataSettings(context),
          trailing: fluent.Button(
            onPressed: () => syncDataSettings(context),
            child: Text('同步'.tl),
          ),
        ),
        fluent.ListTile(
          title: Text("用户".tl),
          leading: const Icon(Icons.person_outline),
        ),
        fluent.ListTile(
          title: Text("语言".tl),
          trailing: fluent.ComboBox<int>(
            value: ["", "cn", "tw", "en"].indexOf(appdata.settings[50]),
            items: const [
              fluent.ComboBoxItem(value: 0, child: Text("System")),
              fluent.ComboBoxItem(value: 1, child: Text("中文(简体)")),
              fluent.ComboBoxItem(value: 2, child: Text("中文(繁體)")),
              fluent.ComboBoxItem(value: 3, child: Text("English")),
            ],
            onChanged: (value) {
              if (value == null) return;
              appdata.settings[50] = ["", "cn", "tw", "en"][value];
              appdata.updateSettings();
              MyApp.updater?.call();
            },
            placeholder: const Text("Select"),
          ),
        ),
        fluent.ListTile(
          title: Text("需要身份验证".tl),
          subtitle: Text("如果系统中未设置任何认证方法请勿开启".tl),
          trailing: fluent.ToggleSwitch(
            checked: appdata.settings[13] == "1",
            onChanged: (b) {
              setState(() {
                appdata.settings[13] = b ? "1" : "0";
              });
              appdata.updateSettings();
            },
          ),
        ),
      ],
    );
  }

  Widget buildFluentAbout() {
    return Column(
      children: [
        SizedBox(
          height: 130,
          width: double.infinity,
          child: Center(
            child: Container(
              width: 156,
              height: 156,
              decoration:
                  BoxDecoration(borderRadius: BorderRadius.circular(20)),
              child: const Image(
                image: AssetImage("images/app_icon_no_bg.png"),
                filterQuality: FilterQuality.medium,
              ),
            ),
          ),
        ),
        const Text(
          "V$appVersion",
          style: TextStyle(fontSize: 16),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_platformIcon != null) ...[
              _platformIcon!,
              const SizedBox(width: 4),
            ],
            Text(_platformName),
          ],
        ),
        Text("Pica Comic是一个免费的开源漫画阅读应用。".tl),
        const SizedBox(
          height: 16,
        ),
        fluent.ListTile(
          title: Text("检查更新".tl),
          trailing: fluent.Button(
            child: Text("检查".tl),
            onPressed: () => findUpdate(context),
          ),
        ),
        fluent.ListTile(
          title: Text("启动时检查更新".tl),
          trailing: fluent.ToggleSwitch(
            checked: appdata.settings[2] == "1",
            onChanged: (value) {
              appdata.settings[2] = value ? "1" : "0";
              appdata.updateSettings();
              setState(() {});
            },
          ),
        ),
        fluent.ListTile(
          leading: const Icon(Icons.code),
          title: Text("项目地址".tl),
          onPressed: () => AppUrlLauncher.launchExternalUrl(kProjectRepoUrl),
          trailing: const Icon(Icons.open_in_new),
        ),
        fluent.ListTile(
          leading: const Icon(Icons.comment_outlined),
          title: Text("问题反馈 (Github)".tl),
          onPressed: () => AppUrlLauncher.launchExternalUrl(kProjectIssuesUrl),
          trailing: const Icon(Icons.open_in_new),
        ),
      ],
    );
  }

  Widget buildBody() {
    if (enableLiquidGlassSettingsUi) {
      return buildGlassBody();
    }
    if (enableTwoViews) {
      return Row(
        children: [
          SizedBox(
            width: 280,
            height: double.infinity,
            child: buildLeft(),
          ),
          Container(
            height: double.infinity,
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: context.colorScheme.outlineVariant,
                  width: 0.6,
                ),
              ),
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, animation) {
                return LayoutBuilder(
                  builder: (context, constrains) {
                    return AnimatedBuilder(
                      animation: animation,
                      builder: (context, _) {
                        var width = constrains.maxWidth;
                        var value = animation.isForwardOrCompleted
                            ? 1 - animation.value
                            : 1;
                        var left = width * value;
                        return Stack(
                          children: [
                            Positioned(
                              top: 0,
                              bottom: 0,
                              left: left,
                              width: width,
                              child: child,
                            ),
                          ],
                        );
                      },
                    );
                  },
                );
              },
              child: buildRight(),
            ),
          )
        ],
      );
    } else {
      return Stack(
        children: [
          Positioned.fill(child: buildLeft()),
          Positioned(
            left: offset,
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.height,
            child: Listener(
              onPointerDown: handlePointerDown,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                reverseDuration: const Duration(milliseconds: 300),
                switchInCurve: Curves.fastOutSlowIn,
                switchOutCurve: Curves.fastOutSlowIn,
                transitionBuilder: (child, animation) {
                  var tween = Tween<Offset>(
                      begin: const Offset(1, 0), end: const Offset(0, 0));

                  return SlideTransition(
                    position: tween.animate(animation),
                    child: child,
                  );
                },
                child: currentPage == -1
                    ? const SizedBox(
                        key: Key("1"),
                      )
                    : buildRight(),
              ),
            ),
          )
        ],
      );
    }
  }

  Widget buildGlassBody() {
    if (enableTwoViews) {
      return Stack(
        children: [
          Positioned.fill(child: _buildGlassBackground()),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                SizedBox(
                  width: 304,
                  child: buildLeft(),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    child: currentPage == -1
                        ? _buildGlassPlaceholderPane()
                        : buildRight(),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Stack(
      children: [
        Positioned.fill(child: _buildGlassBackground()),
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: buildLeft(),
          ),
        ),
        Positioned(
          left: offset,
          width: MediaQuery.of(context).size.width,
          height: MediaQuery.of(context).size.height,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Listener(
              onPointerDown: handlePointerDown,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                reverseDuration: const Duration(milliseconds: 300),
                switchInCurve: Curves.fastOutSlowIn,
                switchOutCurve: Curves.fastOutSlowIn,
                transitionBuilder: (child, animation) {
                  var tween = Tween<Offset>(
                      begin: const Offset(1, 0), end: const Offset(0, 0));

                  return SlideTransition(
                    position: tween.animate(animation),
                    child: child,
                  );
                },
                child: currentPage == -1
                    ? const SizedBox(
                        key: Key("glass-left"),
                      )
                    : buildRight(),
              ),
            ),
          ),
        )
      ],
    );
  }

  Widget _buildGlassBackground() {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
      ),
    );
  }

  Widget _buildGlassPane({
    required Widget child,
    Key? key,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return GlassContainerLiteSettings(
      key: key,
      width: double.infinity,
      height: double.infinity,
      useOwnLayer: false,
      quality: GlassQuality.minimal,
      shape: const LiquidRoundedSuperellipse(borderRadius: 32),
      settings: LiquidGlassSettings(
        blur: 0,
        glassColor: isDark
            ? const Color.fromRGBO(24, 24, 28, 1)
            : const Color.fromRGBO(255, 255, 255, 1),
        ambientStrength: isDark ? 0.34 : 0.52,
        saturation: 1.16,
        thickness: 8,
      ),
      child: Material(
        color: isDark
            ? const Color.fromRGBO(24, 24, 28, 1)
            : const Color.fromRGBO(255, 255, 255, 1),
        child: child,
      ),
    );
  }

  Widget _buildGlassHeader({
    required String title,
    required VoidCallback onBack,
    bool showBack = true,
  }) {
    final titleStyle = Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          if (showBack) ...[
            GlassIconActionButton(
              icon: Icons.arrow_back,
              tooltip: "Back",
              onTap: onBack,
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Text(
              title,
              style: titleStyle,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassPlaceholderPane() {
    final scheme = Theme.of(context).colorScheme;
    return _buildGlassPane(
      key: const ValueKey("glass-placeholder"),
      child: Column(
        children: [
          SizedBox(height: MediaQuery.of(context).padding.top + 16),
          _buildGlassHeader(
            title: "设置".tl,
            showBack: false,
            onBack: () {},
          ),
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.tune,
                    size: 48,
                    color: scheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "选择左侧分类查看详细设置".tl,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void handlePointerDown(PointerDownEvent event) {
    if (event.position.dx < 20) {
      gestureRecognizer.addPointer(event);
    }
  }

  Widget buildLeft() {
    if (enableLiquidGlassSettingsUi) {
      return _buildGlassPane(
        key: const ValueKey("glass-left-pane"),
        child: Column(
          children: [
            SizedBox(
              height: MediaQuery.of(context).padding.top + 8,
            ),
            _buildGlassHeader(
              title: "设置".tl,
              onBack: () {
                if (currentPage != -1 && !enableTwoViews) {
                  setState(() => currentPage = -1);
                } else if (currentPage == -1 && !enableTwoViews) {
                  widget.onPop?.call();
                  Navigator.of(context).pop();
                } else {
                  setState(() => currentPage = -1);
                  widget.onPop?.call();
                  Navigator.of(context).pop();
                }
              },
            ),
            Expanded(
              child: buildCategories(),
            ),
          ],
        ),
      );
    }
    return Material(
      child: Column(
        children: [
          SizedBox(
            height: MediaQuery.of(context).padding.top,
          ),
          SizedBox(
            height: 56,
            child: Row(children: [
              const SizedBox(
                width: 8,
              ),
              Tooltip(
                message: "Back",
                child: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    // 检查是否在移动端的子设置页面中
                    if (currentPage != -1 && !enableTwoViews) {
                      // 如果在子设置页面，返回上一级
                      setState(() => currentPage = -1);
                    } else if (currentPage == -1 && !enableTwoViews) {
                      // 如果在主设置页面且是移动端模式，执行原有逻辑
                      widget.onPop?.call();
                      Navigator.of(context).pop();
                    } else {
                      // 双视图模式下或其他情况
                      setState(() => currentPage = -1);
                      widget.onPop?.call();
                      Navigator.of(context).pop();
                    }
                  },
                ),
              ),
              const SizedBox(
                width: 24,
              ),
              Text(
                "设置".tl,
                style: Theme.of(context).textTheme.headlineSmall,
              )
            ]),
          ),
          const SizedBox(
            height: 4,
          ),
          Expanded(
            child: buildCategories(),
          )
        ],
      ),
    );
  }

  Widget buildCategories() {
    if (enableLiquidGlassSettingsUi) {
      return ListView.builder(
        padding: EdgeInsets.fromLTRB(
          8,
          4,
          8,
          MediaQuery.of(context).padding.bottom + 12,
        ),
        itemCount: categories.length,
        itemBuilder: (context, index) => _GlassSettingsCategoryItem(
          selected: index == currentPage,
          icon: icons[index],
          label: categories[index].tl,
          onTap: () => setState(() => currentPage = index),
        ),
      );
    }
    Widget buildItem(String name, int id) {
      final bool selected = id == currentPage;

      Widget content = AnimatedContainer(
        key: ValueKey(id),
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        height: 46,
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
        decoration: BoxDecoration(
          color: selected ? colors.primaryContainer.toOpacity(0.36) : null,
          border: Border(
            left: BorderSide(
              color: selected ? colors.primary : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(children: [
          Icon(icons[id]),
          const SizedBox(width: 16),
          Text(
            name,
            style: const TextStyle(fontSize: 16),
          ),
          const Spacer(),
          if (selected) const Icon(Icons.arrow_right)
        ]),
      );

      return Padding(
        padding: enableTwoViews
            ? const EdgeInsets.fromLTRB(8, 0, 8, 0)
            : EdgeInsets.zero,
        child: InkWell(
          onTap: () => setState(() => currentPage = id),
          child: content,
        ).paddingVertical(4),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: categories.length,
      itemBuilder: (context, index) => buildItem(categories[index].tl, index),
    );
  }

  Widget buildReadingSettings() {
    return const Placeholder();
  }

  Future<FilePickerResult?> _pickFontFile() async {
    PlatformException? lastError;

    Future<FilePickerResult?> pick({
      required FileType type,
      List<String>? allowedExtensions,
    }) async {
      try {
        return await FilePicker.platform.pickFiles(
          type: type,
          allowedExtensions: allowedExtensions,
          withData: true,
          allowMultiple: false,
        );
      } on PlatformException catch (e) {
        if (e.code == 'unknown_activity' ||
            e.code == 'unknown_activity_error') {
          return null;
        }
        lastError = e;
        return null;
      }
    }

    final filtered = await pick(
      type: FileType.custom,
      allowedExtensions: const ['ttf', 'otf'],
    );
    if (filtered != null) {
      return filtered;
    }

    final unfiltered = await pick(type: FileType.any);
    if (unfiltered != null) {
      return unfiltered;
    }

    if (lastError != null &&
        lastError!.code != 'unknown_path' &&
        lastError!.code != 'unknown_activity' &&
        lastError!.code != 'unknown_activity_error') {
      throw lastError!;
    }
    return null;
  }

  Future<String?> _fontImportPath(PlatformFile file) async {
    final lowerName = file.name.toLowerCase();
    if (!(lowerName.endsWith('.ttf') || lowerName.endsWith('.otf'))) {
      if (mounted) {
        context.showMessage(message: "仅支持 .ttf / .otf 字体文件".tl);
      }
      return null;
    }

    final path = file.path;
    if (path != null && path.isNotEmpty && File(path).existsSync()) {
      return path;
    }

    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      if (mounted) {
        context.showMessage(message: "无法读取字体文件".tl);
      }
      return null;
    }

    final tempDir = await getTemporaryDirectory();
    final safeName = file.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final tempFile = File(
      "${tempDir.path}${pathSep}font_import_${DateTime.now().millisecondsSinceEpoch}_$safeName",
    );
    await tempFile.create(recursive: true);
    await tempFile.writeAsBytes(bytes, flush: true);
    return tempFile.path;
  }

  Future<void> _importFont() async {
    try {
      final result = await _pickFontFile();
      if (result == null || result.files.isEmpty) {
        return;
      }

      final path = await _fontImportPath(result.files.single);
      if (path == null) {
        return;
      }

      final name = await FontManager().addFont(path);
      if (name == null) {
        if (mounted) {
          context.showMessage(message: "导入字体失败".tl);
        }
        return;
      }

      if (mounted) {
        setState(() {});
        context.showMessage(message: "已导入".tl);
      }
      MyApp.updater?.call();
    } on PlatformException catch (e) {
      if (e.code == 'unknown_activity' || e.code == 'unknown_activity_error') {
        return;
      }
      if (mounted) {
        context.showMessage(message: "导入字体失败: ${e.code}".tl);
      }
    } catch (e, s) {
      LogManager.addLog(LogLevel.error, "Settings.importFont", "$e\n$s");
      if (mounted) {
        context.showMessage(message: "导入字体失败".tl);
      }
    }
  }

  Widget buildFluentAppearanceSettings() {
    return Column(
      children: [
        fluent.ListTile(
          leading: const Icon(Icons.color_lens),
          title: Text("主题选择".tl),
          trailing: fluent.ComboBox<int>(
            value: int.parse(appdata.settings[27]),
            items: const [
              fluent.ComboBoxItem(value: 0, child: Text("dynamic")),
              fluent.ComboBoxItem(value: 1, child: Text("red")),
              fluent.ComboBoxItem(value: 2, child: Text("pink")),
              fluent.ComboBoxItem(value: 3, child: Text("purple")),
              fluent.ComboBoxItem(value: 4, child: Text("indigo")),
              fluent.ComboBoxItem(value: 5, child: Text("blue")),
              fluent.ComboBoxItem(value: 6, child: Text("cyan")),
              fluent.ComboBoxItem(value: 7, child: Text("teal")),
              fluent.ComboBoxItem(value: 8, child: Text("green")),
              fluent.ComboBoxItem(value: 9, child: Text("lime")),
              fluent.ComboBoxItem(value: 10, child: Text("yellow")),
              fluent.ComboBoxItem(value: 11, child: Text("amber")),
              fluent.ComboBoxItem(value: 12, child: Text("orange")),
            ],
            onChanged: (i) {
              if (i == null) return;
              appdata.settings[27] = i.toString();
              appdata.updateSettings();
              MyApp.updater?.call();
            },
            placeholder: const Text("Select"),
          ),
        ),
        fluent.ListTile(
          leading: const Icon(Icons.font_download),
          title: Text("字体".tl),
          trailing: fluent.ComboBox<int>(
            value: (() {
              while (appdata.settings.length <= 95) {
                appdata.settings.add("");
              }
              var font = appdata.settings[95];
              if (font.isEmpty) return 0;
              var index = FontManager().availableFonts.indexOf(font);
              return index == -1 ? 0 : index + 1;
            })(),
            items: [
              const fluent.ComboBoxItem(value: 0, child: Text("Default")),
              ...List.generate(FontManager().availableFonts.length, (index) {
                return fluent.ComboBoxItem(
                  value: index + 1,
                  child: Text(FontManager().availableFonts[index]),
                );
              })
            ],
            onChanged: (i) {
              if (i == null) return;
              while (appdata.settings.length <= 95) {
                appdata.settings.add("");
              }
              if (i == 0) {
                appdata.settings[95] = "";
              } else {
                appdata.settings[95] = FontManager().availableFonts[i - 1];
              }
              appdata.updateSettings();
              MyApp.updater?.call();
            },
            placeholder: const Text("Select"),
          ),
        ),
        fluent.ListTile(
          leading: const Icon(Icons.add_circle_outline),
          title: Text("导入字体".tl),
          onPressed: _importFont,
        ),
        fluent.ListTile(
          leading: const Icon(Icons.folder_open),
          title: Text("字体管理器".tl),
          onPressed: () {
            App.to(context, () => const FontManagementPage());
          },
        ),
        fluent.ListTile(
          leading: const Icon(Icons.dark_mode),
          title: Text("深色模式".tl),
          trailing: fluent.ComboBox<int>(
            value: int.parse(appdata.settings[32]),
            items: [
              fluent.ComboBoxItem(value: 0, child: Text("跟随系统".tl)),
              fluent.ComboBoxItem(value: 1, child: Text("禁用".tl)),
              fluent.ComboBoxItem(value: 2, child: Text("启用".tl)),
            ],
            onChanged: (i) {
              if (i == null) return;
              appdata.settings[32] = i.toString();
              appdata.updateSettings();
              MyApp.updater?.call();
            },
            placeholder: const Text("Select"),
          ),
        ),
        if (appdata.settings[32] == "0" || appdata.settings[32] == "2")
          fluent.ListTile(
            leading: const Icon(Icons.window),
            title: const Text("Fluent UI"),
            subtitle: Text("实验性功能,注目前这ui比较多bug，而且对手机不太友好".tl),
            trailing: fluent.ToggleSwitch(
              checked: (() {
                while (appdata.settings.length <= 103) {
                  appdata.settings.add("0");
                }
                final fluentEnabled = appdata.settings[91] == "1";
                if (fluentEnabled && appdata.settings[103] == "1") {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    setState(() {
                      appdata.settings[103] = "0";
                    });
                    appdata.updateSettings();
                    MyApp.updater?.call();
                  });
                }
                return fluentEnabled;
              })(),
              onChanged: (b) {
                setState(() {
                  while (appdata.settings.length <= 103) {
                    appdata.settings.add("0");
                  }
                  appdata.settings[91] = b ? "1" : "0";
                  if (b) {
                    appdata.settings[103] = "0";
                  }
                });
                appdata.updateSettings();
                MyApp.updater?.call();
              },
            ),
          ),
        fluent.ListTile(
          leading: const Icon(Icons.remove_red_eye),
          title: Text("纯黑色模式".tl),
          trailing: fluent.ToggleSwitch(
            checked: appdata.settings[84] == "1",
            onChanged: (i) {
              setState(() {
                appdata.settings[84] = i ? "1" : "0";
              });
              appdata.updateSettings();
              MyApp.updater?.call();
            },
          ),
        ),
        fluent.ListTile(
          leading: const Icon(Icons.water_drop_outlined),
          title: Text("液态玻璃效果和导航栏".tl),
          subtitle: Text("实验性功能,可能存在性能或点击区域问题".tl),
          trailing: AdaptiveSwitch(
            value: (() {
              while (appdata.settings.length <= 103) {
                appdata.settings.add("0");
              }
              final fluentEnabled =
                  appdata.settings.length > 91 && appdata.settings[91] == "1";
              if (fluentEnabled && appdata.settings[103] == "1") {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  setState(() {
                    appdata.settings[103] = "0";
                  });
                  appdata.updateSettings();
                  MyApp.updater?.call();
                });
                return false;
              }
              return appdata.settings[103] == "1";
            })(),
            onChanged: (b) {
              setState(() {
                while (appdata.settings.length <= 103) {
                  appdata.settings.add("0");
                }
                appdata.settings[103] = b ? "1" : "0";
                if (b &&
                    appdata.settings.length > 91 &&
                    appdata.settings[91] == "1") {
                  appdata.settings[91] = "0";
                }
              });
              appdata.updateSettings();
              MyApp.updater?.call();
            },
          ),
        ),
        fluent.ListTile(
          leading: const Icon(Icons.comment),
          title: Text("显示章节评论".tl),
          trailing: AdaptiveSwitch(
            value: appdata.settings.length > 92
                ? appdata.settings[92] == "1"
                : true,
            onChanged: (b) {
              setState(() {
                while (appdata.settings.length <= 92) {
                  appdata.settings.add("1");
                }
                appdata.settings[92] = b ? "1" : "0";
              });
              appdata.updateSettings();
            },
          ),
        ),
        fluent.ListTile(
          leading: const Icon(Icons.save),
          title: Text("下载时保存章节评论".tl),
          subtitle: Text("断网时也可查看已保存的章节评论".tl),
          trailing: AdaptiveSwitch(
            value: appdata.settings.length > 102
                ? appdata.settings[102] == "1"
                : false,
            onChanged: (b) {
              setState(() {
                while (appdata.settings.length <= 102) {
                  appdata.settings.add("0");
                }
                appdata.settings[102] = b ? "1" : "0";
              });
              appdata.updateSettings();
            },
          ),
        ),
      ],
    );
  }

  Widget buildAppearanceSettings() => Column(
        children: [
          ListTile(
            leading: const Icon(Icons.color_lens),
            title: Text("主题选择".tl),
            trailing: components.Select(
              initialValue: int.parse(appdata.settings[27]),
              values: const [
                "dynamic",
                "red",
                "pink",
                "purple",
                "indigo",
                "blue",
                "cyan",
                "teal",
                "green",
                "lime",
                "yellow",
                "amber",
                "orange",
              ],
              onChange: (i) {
                appdata.settings[27] = i.toString();
                appdata.updateSettings();
                MyApp.updater?.call();
              },
              width: 140,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.font_download),
            title: Text("字体".tl),
            trailing: components.Select(
              initialValue: (() {
                while (appdata.settings.length <= 95) {
                  appdata.settings.add("");
                }
                var font = appdata.settings[95];
                if (font.isEmpty) return 0;
                var index = FontManager().availableFonts.indexOf(font);
                return index == -1 ? 0 : index + 1;
              })(),
              values: ["Default"] + FontManager().availableFonts,
              onChange: (i) {
                while (appdata.settings.length <= 95) {
                  appdata.settings.add("");
                }
                if (i == 0) {
                  appdata.settings[95] = "";
                } else {
                  appdata.settings[95] = FontManager().availableFonts[i - 1];
                }
                appdata.updateSettings();
                MyApp.updater?.call();
              },
              width: 140,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.add_circle_outline),
            title: Text("导入字体".tl),
            onTap: _importFont,
          ),
          ListTile(
            leading: const Icon(Icons.folder_open),
            title: Text("字体管理器".tl),
            //  subtitle: FutureBuilder<String?>(
            //  future: FontManager().getFontsDir(),
            //  builder: (context, snapshot) {
            //  return Text(snapshot.data ?? "");
            //   },
            // ),
            onTap: () {
              App.to(context, () => const FontManagementPage());
            },
          ),
          ListTile(
            leading: const Icon(Icons.dark_mode),
            title: Text("深色模式".tl),
            trailing: components.Select(
              initialValue: int.parse(appdata.settings[32]),
              values: ["跟随系统".tl, "禁用".tl, "启用".tl],
              onChange: (i) {
                appdata.settings[32] = i.toString();
                appdata.updateSettings();
                MyApp.updater?.call();
              },
              width: 140,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.window),
            title: const Text("Fluent UI"),
            subtitle: Text("实验性功能,注目前这ui比较多bug，而且对手机不太友好".tl),
            trailing: AdaptiveSwitch(
              value: appdata.settings.length > 91
                  ? appdata.settings[91] == "1"
                  : false,
              onChanged: (b) {
                setState(() {
                  while (appdata.settings.length <= 91) {
                    appdata.settings.add("0");
                  }
                  appdata.settings[91] = b ? "1" : "0";
                  if (b) {
                    while (appdata.settings.length <= 103) {
                      appdata.settings.add("0");
                    }
                    appdata.settings[103] = "0";
                  }
                });
                appdata.updateSettings();
                MyApp.updater?.call();
              },
            ),
          ),
          //if (PlatformUtils.isOhos)
          ListTile(
            leading: const Icon(Icons.water_drop_outlined),
            title: Text("液态玻璃效果和导航栏".tl),
            subtitle: Text("实验性功能,可能存在性能或点击区域问题".tl),
            trailing: AdaptiveSwitch(
              value: (() {
                while (appdata.settings.length <= 103) {
                  appdata.settings.add("0");
                }
                final fluentEnabled =
                    appdata.settings.length > 91 && appdata.settings[91] == "1";
                if (fluentEnabled && appdata.settings[103] == "1") {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    setState(() {
                      appdata.settings[103] = "0";
                    });
                    appdata.updateSettings();
                    MyApp.updater?.call();
                  });
                  return false;
                }
                return appdata.settings[103] == "1";
              })(),
              onChanged: (b) {
                setState(() {
                  while (appdata.settings.length <= 103) {
                    appdata.settings.add("0");
                  }
                  appdata.settings[103] = b ? "1" : "0";
                  if (b &&
                      appdata.settings.length > 91 &&
                      appdata.settings[91] == "1") {
                    appdata.settings[91] = "0";
                  }
                });
                appdata.updateSettings();
                MyApp.updater?.call();
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.comment),
            title: Text("显示章节评论".tl),
            trailing: AdaptiveSwitch(
              value: appdata.settings.length > 92
                  ? appdata.settings[92] == "1"
                  : true,
              onChanged: (b) {
                setState(() {
                  while (appdata.settings.length <= 92) {
                    appdata.settings.add("1");
                  }
                  appdata.settings[92] = b ? "1" : "0";
                });
                appdata.updateSettings();
              },
            ),
          ),

          ListTile(
            leading: const Icon(Icons.save),
            title: Text("下载时保存章节评论".tl),
            subtitle: Text("断网时也可查看已保存的章节评论".tl),
            trailing: AdaptiveSwitch(
              value: appdata.settings.length > 102
                  ? appdata.settings[102] == "1"
                  : false,
              onChanged: (b) {
                setState(() {
                  while (appdata.settings.length <= 102) {
                    appdata.settings.add("0");
                  }
                  appdata.settings[102] = b ? "1" : "0";
                });
                appdata.updateSettings();
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.comment_bank),
            title: Text("下载漫画时保存普通评论".tl),
            subtitle: Text("断网时也可查看已保存的漫画评论, 联网时会自动更新".tl),
            trailing: AdaptiveSwitch(
              value: appdata.settings.length > 104
                  ? appdata.settings[104] == "1"
                  : false,
              onChanged: (b) {
                setState(() {
                  while (appdata.settings.length <= 104) {
                    appdata.settings.add("0");
                  }
                  appdata.settings[104] = b ? "1" : "0";
                });
                appdata.updateSettings();
              },
            ),
          ),
          if (appdata.settings[32] == "0" || appdata.settings[32] == "2")
            ListTile(
              leading: const Icon(Icons.remove_red_eye),
              title: Text("纯黑色模式".tl),
              trailing: AdaptiveSwitch(
                value: appdata.settings[84] == "1",
                onChanged: (i) {
                  setState(() {
                    appdata.settings[84] = i ? "1" : "0";
                  });
                  appdata.updateSettings();
                  MyApp.updater?.call();
                },
              ),
            ),
          if (App.isAndroid)
            ListTile(
              leading: const Icon(Icons.smart_screen_outlined),
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("高刷新率模式".tl),
                  const SizedBox(
                    width: 2,
                  ),
                  InkWell(
                    borderRadius: const BorderRadius.all(Radius.circular(18)),
                    onTap: () => showDialogMessage(context, "高刷新率模式".tl,
                        "${"尝试强制设置高刷新率".tl}\n${"可能不起作用".tl}"),
                    child: const Icon(
                      Icons.info_outline,
                      size: 18,
                    ),
                  )
                ],
              ),
              trailing: AdaptiveSwitch(
                value: appdata.settings[38] == "1",
                onChanged: (b) {
                  setState(() {
                    appdata.settings[38] = b ? "1" : "0";
                  });
                  appdata.updateSettings();
                  if (b) {
                    try {
                      FlutterDisplayMode.setHighRefreshRate();
                    } catch (e) {
                      // ignore
                    }
                  } else {
                    try {
                      FlutterDisplayMode.setLowRefreshRate();
                    } catch (e) {
                      // ignore
                    }
                  }
                },
              ),
            )
        ],
      );

  Widget buildAppSettings() {
    return Column(
      children: [
        ListTile(
          title: Text("数据".tl),
          leading: const Icon(Icons.storage),
        ),
        ListTile(
          title: Text("本地漫画的存储路径".tl),
          subtitle: Text(DownloadManager().path ?? "", softWrap: false),
          trailing: IconButton(
            icon: const Icon(Icons.copy),
            onPressed: () {
              Clipboard.setData(
                  ClipboardData(text: DownloadManager().path ?? ""));
              context.showMessage(message: "路径已复制到剪贴板".tl);
            },
          ),
        ),

        if (App.isDesktop || App.isAndroid)
          ListTile(
            // leading: const Icon(Icons.folder),
            title: Text("设置下载目录".tl),
            onTap: () => setDownloadFolder(),
            trailing: TextButton(
              onPressed: () => setDownloadFolder(),
              child: Text('设置'.tl),
            ),
          ),
        ListTile(
          title: Text("缓存大小".tl),
          subtitle: Text(bytesToReadableString(CacheManager().currentSize)),
        ),
        _CallbackSetting(
          title: "清除缓存".tl,
          actionTitle: "清除".tl,
          callback: () async {
            var loadingDialog = showLoadingDialog(
              context,
              barrierDismissible: false,
              allowCancel: false,
            );
            await CacheManager().clear();
            loadingDialog.close();
            context.showMessage(message: "Cache cleared".tl);
            setState(() {});
          },
        ),
        if (App.isMobile || App.isDesktop)
          ListTile(
            leading: const Icon(Icons.folder_open),
            title: Text("文件管理器".tl),
            subtitle: Text("浏览应用私有目录".tl),
            onTap: () => context.to(() => const FileManagerPage()),
            trailing: const Icon(Icons.arrow_right),
          ),
        ListTile(
            title: Text("缓存限制".tl),
            subtitle:
                Text('${bytesLengthToReadableSize(CacheManager().limitSize)}'),
            onTap: setCacheLimit,
            //trailing: const Icon(Icons.arrow_right),
            trailing: TextButton(
              onPressed: setCacheLimit,
              child: Text('设置'.tl),
            )),

        // ListTile(
        //   leading: const Icon(Icons.sd_storage_outlined),
        //   title: Text("设置缓存限制".tl),
        //   onTap: setCacheLimit,
        //   trailing: const Icon(Icons.arrow_right),
        // ),
        ListTile(
          //leading: const Icon(Icons.delete_forever),
          title: Text("删除所有数据".tl),
          // trailing: const Icon(Icons.arrow_right),
          onTap: () => clearUserData(context),
          trailing: TextButton(
            onPressed: () => clearUserData(context),
            child: Text('删除'.tl),
          ),
        ),

        ListTile(
          // leading: const Icon(Icons.sim_card_download),
          title: Text("导出用户数据".tl),
          onTap: () => exportDataSetting(context),
          trailing: TextButton(
            onPressed: () => exportDataSetting(context),
            child: Text('导出'.tl),
          ),
        ),
        ListTile(
          // leading: const Icon(Icons.data_object),
          title: Text("导入用户数据".tl),
          onTap: () => importDataSetting(context),
          trailing: TextButton(
            onPressed: () => importDataSetting(context),
            child: Text('导入'.tl),
          ),
        ),
        ListTile(
          // leading: const Icon(Icons.sync),
          title: Text("数据同步".tl),
          onTap: () => syncDataSettings(context),
          trailing: TextButton(
            onPressed: () => syncDataSettings(context),
            child: Text('同步'.tl),
          ),
        ),

        if (App.isAndroid)
          ListTile(
            //  leading: const Icon(Icons.screenshot),
            title: Text("阻止屏幕截图".tl),
            subtitle: Text("需要重启App以应用更改".tl),
            trailing: AdaptiveSwitch(
              value: appdata.settings[12] == "1",
              onChanged: (b) {
                b ? appdata.settings[12] = "1" : appdata.settings[12] = "0";
                setState(() {});
                appdata.writeData();
              },
            ),
          ),

        ListTile(
          title: Text("用户".tl),
          leading: const Icon(Icons.person_outline),
        ),

        ListTile(
          title: Text("语言".tl),
          //leading: const Icon(Icons.language),
          trailing: components.Select(
            initialValue: ["", "cn", "tw", "en"].indexOf(appdata.settings[50]),
            values: const ["System", "中文(简体)", "中文(繁體)", "English"],
            onChange: (value) {
              appdata.settings[50] = ["", "cn", "tw", "en"][value];
              appdata.updateSettings();
              MyApp.updater?.call();
            },
          ),
        ),

        SwitchListTile(
          title: Text("需要身份验证".tl),
          subtitle: Text("如果系统中未设置任何认证方法请勿开启".tl),
          value: appdata.settings[13] == "1",
          onChanged: (b) {
            setState(() {
              appdata.settings[13] = b ? "1" : "0";
            });
            appdata.updateSettings();
          },
          //icon: const Icon(Icons.security),
        ),

        if (App.isAndroid)
          ListTile(
            title: Text("应用链接".tl),
            subtitle: Text("在系统设置中管理APP支持的链接".tl),
            leading: const Icon(Icons.link),
            trailing: const Icon(Icons.arrow_right),
            onTap: () {
              const MethodChannel("pica_comic/settings").invokeMethod("link");
            },
          ),
        //if (kDebugMode)
        //  const ListTile(
        //   title: Text("De.bug"),
        //     onTap: debug,
        //   ),
        Padding(
            padding:
                EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom))
      ],
    );
  }

  Widget buildAbout() {
    return Column(
      children: [
        SizedBox(
          height: 130,
          width: double.infinity,
          child: Center(
            child: Container(
              width: 156,
              height: 156,
              decoration:
                  BoxDecoration(borderRadius: BorderRadius.circular(20)),
              child: const Image(
                image: AssetImage("images/app_icon_no_bg.png"),
                filterQuality: FilterQuality.medium,
              ),
            ),
          ),
        ),
        const Text(
          "V$appVersion",
          style: TextStyle(fontSize: 16),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_platformIcon != null) ...[
              _platformIcon!,
              const SizedBox(width: 4),
            ],
            Text(_platformName),
          ],
        ),
        Text("Pica Comic是一个免费的开源漫画阅读应用。".tl),
        const SizedBox(
          height: 16,
        ),
        ListTile(
          leading: const Icon(Icons.description_outlined),
          title: const Text("开源许可证"),
          subtitle: const Text("查看所有开源许可证"),
          onTap: () => App.globalTo(() => const AboutLicensePage()),
          trailing: const Icon(Icons.arrow_right),
        ),
        ListTile(
          leading: const Icon(Icons.history),
          title: const Text("历史版本"),
          subtitle: const Text("查看历史版本更新"),
          onTap: () => showPopUpWidget(
              App.globalContext!, const AppUpdaterHistoryPage()),
          trailing: const Icon(Icons.arrow_right),
        ),
        ListTile(
          title: Text("检查更新".tl),
          trailing: Button.filled(
            child: Text("检查".tl),
            onPressed: () => findUpdate(context),
          ),
        ),
        SwitchListTile(
          title: Text("启动时检查更新".tl),
          value: appdata.settings[2] == "1",
          onChanged: (value) {
            appdata.settings[2] = value ? "1" : "0";
            appdata.updateSettings();
            setState(() {});
          },
        ),

        ListTile(
          leading: const Icon(Icons.code),
          title: Text("项目地址".tl),
          onTap: () => AppUrlLauncher.launchExternalUrl(kProjectRepoUrl),
          trailing: const Icon(Icons.open_in_new),
        ),
        ListTile(
          leading: const Icon(Icons.comment_outlined),
          title: Text("问题反馈 (Github)".tl),
          onTap: () => AppUrlLauncher.launchExternalUrl(kProjectIssuesUrl),
          trailing: const Icon(Icons.open_in_new),
        ),
        // ListTile(
        //   leading: const Icon(Icons.email),
        //   title: Text("EMAIL_ME_PLACEHOLDER".tl),
        //   onTap: () => launchUrlString("mailto://example@foo.bar",
        //       mode: LaunchMode.externalApplication),
        //   trailing: const Icon(Icons.arrow_right),
        // ),
        // ListTile(
        //   leading: const Icon(Icons.telegram),
        //   title: Text("JOIN_GROUP_PLACEHOLDER".tl),
        //   onTap: () => launchUrlString("https://t.me/example",
        //       mode: LaunchMode.externalApplication),
        //   trailing: const Icon(Icons.arrow_right),
        // ),
        Padding(
            padding:
                EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom))
      ],
    );
  }

  Widget buildRight() {
    if (currentPage == _fileManagerIndex) {
      return const FileManagerPage();
    }

    final Widget body = switch (currentPage) {
      -1 => const SizedBox(),
      0 => buildExploreSettings(context, false),
      // 1 => const ComicSourceSettings(),
      1 => const ReadingSettings(false),
      2 => buildAppearanceSettings(),
      3 => const LocalFavoritesSettings(),
      4 => buildAppSettings(),
      5 => const NetworkSettings(),
      _aboutPageIndex => buildAbout(),
      _appUpdaterHistoryIndex => const AppUpdaterHistoryPage(embedded: true),
      _debugPageIndex => const DebugPage(),
      _ => throw UnimplementedError()
    };

    if (enableLiquidGlassSettingsUi && currentPage != -1) {
      return _buildGlassPane(
        key: ValueKey("glass-right-$currentPage"),
        child: Column(
          children: [
            SizedBox(height: MediaQuery.of(context).padding.top + 8),
            _buildGlassHeader(
              title: categories[currentPage].tl,
              showBack: !enableTwoViews,
              onBack: () => setState(() => currentPage = -1),
            ),
            Expanded(
              child: CustomScrollView(
                primary: false,
                slivers: [
                  SliverToBoxAdapter(
                    child: body,
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: MediaQuery.of(context).padding.bottom + 16,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (currentPage != -1) {
      return Material(
        child: CustomScrollView(
          primary: false,
          slivers: [
            SliverAppBar(
                title: Text(categories[currentPage].tl),
                automaticallyImplyLeading: false,
                scrolledUnderElevation: enableTwoViews ? 0 : null,
                leading: enableTwoViews
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () {
                          // 检查是否在移动端模式下
                          if (!enableTwoViews) {
                            // 在移动端模式下，只返回到主设置页面
                            setState(() => currentPage = -1);
                          } else {
                            // 在双视图模式下，执行原有逻辑
                            setState(() => currentPage = -1);
                            widget.onPop?.call();
                            Navigator.of(context).pop();
                          }
                        },
                      )),
            SliverToBoxAdapter(
              child: body,
            )
          ],
        ),
      );
    }

    return body;
  }

  var canPop = ValueNotifier(true);

  @override
  ValueListenable<bool> get canPopNotifier => canPop;

  @override
  void onPopInvokedWithResult(bool didPop, result) {
    if (currentPage != -1) {
      setState(() {
        currentPage = -1;
      });
      // 调用onPop回调
      widget.onPop?.call();
    }
  }

  @override
  void onPopInvoked(bool didPop) {
    if (currentPage != -1) {
      setState(() {
        currentPage = -1;
      });
      // 调用onPop回调
      widget.onPop?.call();
    }
  }
}

class _GlassSettingsCategoryItem extends StatefulWidget {
  const _GlassSettingsCategoryItem({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  State<_GlassSettingsCategoryItem> createState() =>
      _GlassSettingsCategoryItemState();
}

class _GlassSettingsCategoryItemState
    extends State<_GlassSettingsCategoryItem> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool active = widget.selected || _pressed;
    final Color activeColor = scheme.primary;
    final Color restingColor = scheme.onSurface.withValues(alpha: 0.82);

    final content = Row(
      children: [
        Icon(
          widget.icon,
          color: active ? activeColor : restingColor,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: active ? FontWeight.w600 : FontWeight.w500,
              color: active ? activeColor : null,
            ),
          ),
        ),
        Icon(
          Icons.arrow_right,
          color: active ? activeColor : restingColor.withValues(alpha: 0.7),
        ),
      ],
    );

    final child = AnimatedScale(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      scale: _pressed ? 1.02 : 1.0,
      child: active
          ? DecoratedBox(
              decoration: BoxDecoration(
                color: isDark
                    ? activeColor.withValues(alpha: 0.26)
                    : activeColor.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: Colors.white.withValues(alpha: isDark ? 0.08 : 0.25),
                  width: 0.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: content,
                ),
              ),
            )
          : AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: double.infinity,
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: isDark ? 0.02 : 0.08),
                borderRadius: BorderRadius.circular(22),
              ),
              child: content,
            ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) {
          setState(() => _pressed = false);
          widget.onTap();
        },
        child: child,
      ),
    );
  }
}
