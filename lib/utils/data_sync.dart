import 'package:pica_comic/base.dart';
import 'package:pica_comic/foundation/state_controller.dart';
import 'package:pica_comic/network/webdav.dart';

class DataSync extends StateController {
  DataSync._() {
    // Initialize if needed
  }

  static DataSync? _instance;

  factory DataSync() => _instance ?? (_instance = DataSync._());

  bool _isUploading = false;

  bool get isUploading => _isUploading;

  bool _isDownloading = false;

  bool get isDownloading => _isDownloading;

  String? _lastError;

  String? get lastError => _lastError;

  bool get isEnabled {
    var config = appdata.settings[45];
    if (config == null || config.toString().isEmpty) {
      return false;
    }
    var configs = config.toString().split(';');
    return configs.length == 4 && configs[0].isNotEmpty;
  }

  Future<void> uploadData() async {
    if (_isUploading || _isDownloading) return;

    _isUploading = true;
    _lastError = null;
    update();

    try {
      var result = await Webdav.uploadData();
      if (!result) {
        _lastError = 'Upload failed';
      }
    } catch (e) {
      _lastError = e.toString();
    } finally {
      _isUploading = false;
      update();
    }
  }

  /// 下载/导入备份数据。
  ///
  /// [force] 为 true 时表示这是**用户主动点按**的下载，必须无条件覆盖本机
  /// 数据；否则（后台自动同步）在服务器版本号与本机相同时会直接跳过。
  ///
  /// [pullSettings] 为 true 时把服务器上的设置也拉过来覆盖本机。本类的调用方
  /// 是「我的」页面的手动下载按钮，语义就是「以服务器为准」，故默认为 true。
  /// 后台自动同步请走 [Webdav.syncData]，它会显式传 false。
  Future<void> downloadData({bool force = true, bool pullSettings = true}) async {
    if (_isUploading || _isDownloading) return;

    _isDownloading = true;
    _lastError = null;
    update();

    try {
      var result = await Webdav.downloadData(null, force, pullSettings);
      if (!result) {
        _lastError = 'Download failed';
      }
    } catch (e) {
      _lastError = e.toString();
    } finally {
      _isDownloading = false;
      update();
    }
  }
}
