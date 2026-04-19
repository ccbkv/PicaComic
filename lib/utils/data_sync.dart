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

  Future<void> downloadData() async {
    if (_isUploading || _isDownloading) return;

    _isDownloading = true;
    _lastError = null;
    update();

    try {
      var result = await Webdav.downloadData();
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
