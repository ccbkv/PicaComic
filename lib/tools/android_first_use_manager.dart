import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pica_comic/foundation/log.dart';
import 'package:pica_comic/base.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Android平台的firstUse管理器
/// 将firstUse状态存储在外部存储目录中，与log.txt放在同一目录下
class AndroidFirstUseManager {
  static AndroidFirstUseManager? _instance;
  static AndroidFirstUseManager get instance {
    _instance ??= AndroidFirstUseManager._();
    return _instance!;
  }
  
  AndroidFirstUseManager._();
  
  File? _firstUseFile;
  List<String>? _firstUse;
  
  /// 初始化firstUse文件
  Future<void> init() async {
    try {
      var externalDirectory = await getExternalStorageDirectory();
      if (externalDirectory != null) {
        _firstUseFile = File("${externalDirectory.path}/firstuse.txt");
        LogManager.addLog(LogLevel.info, "AndroidFirstUseManager", 
            "FirstUse file path: ${_firstUseFile?.path}");
        
        // 如果文件不存在，创建并初始化
        if (!await _firstUseFile!.exists()) {
          await _initializeFile();
        }
        
        // 读取文件内容到内存
        await _loadFromFile();
      } else {
        LogManager.addLog(LogLevel.error, "AndroidFirstUseManager", 
            "Failed to get external storage directory");
      }
    } catch (e) {
      LogManager.addLog(LogLevel.error, "AndroidFirstUseManager", 
          "Error initializing firstUse file: $e");
    }
  }
  
  /// 初始化文件内容
  Future<void> _initializeFile() async {
    try {
      if (_firstUseFile == null) return;
      
      // 从SharedPreferences读取现有数据
      var s = await SharedPreferences.getInstance();
      var firstUseData = s.getStringList("firstUse");
      
      // 如果SharedPreferences中有数据，使用它；否则使用默认值
      List<String> initialData = ["0", "0", "0", "0", "0"];
      if (firstUseData != null && firstUseData.isNotEmpty) {
        // 确保数组长度足够
        while (initialData.length < firstUseData.length) {
          initialData.add("0");
        }
        for (int i = 0; i < firstUseData.length && i < initialData.length; i++) {
          initialData[i] = firstUseData[i];
        }
      }
      
      // 写入文件
      await _firstUseFile!.writeAsString(initialData.join(","));
      LogManager.addLog(LogLevel.info, "AndroidFirstUseManager", 
          "Initialized firstUse file with data: ${initialData.join(",")}");
    } catch (e) {
      LogManager.addLog(LogLevel.error, "AndroidFirstUseManager", 
          "Error initializing firstUse file: $e");
    }
  }
  
  /// 从文件加载数据到内存
  Future<void> _loadFromFile() async {
    try {
      if (_firstUseFile == null || !await _firstUseFile!.exists()) {
        _firstUse = ["0", "0", "0", "0", "0"];
        return;
      }
      
      String content = await _firstUseFile!.readAsString();
      List<String> firstUseData = content.split(",");
      
      // 确保数组长度足够
      while (firstUseData.length < 5) {
        firstUseData.add("0");
      }
      
      _firstUse = firstUseData;
      LogManager.addLog(LogLevel.info, "AndroidFirstUseManager", 
          "Loaded firstUse data: ${_firstUse!.join(",")}");
    } catch (e) {
      LogManager.addLog(LogLevel.error, "AndroidFirstUseManager", 
          "Error loading firstUse data: $e");
      _firstUse = ["0", "0", "0", "0", "0"];
    }
  }
  
  /// 保存数据到文件
  Future<void> _saveToFile() async {
    try {
      if (_firstUseFile == null || _firstUse == null) return;
      
      // 确保数组长度足够
      List<String> dataToWrite = List.from(_firstUse!);
      while (dataToWrite.length < 5) {
        dataToWrite.add("0");
      }
      
      await _firstUseFile!.writeAsString(dataToWrite.join(","));
      LogManager.addLog(LogLevel.info, "AndroidFirstUseManager", 
          "Saved firstUse data: ${dataToWrite.join(",")}");
    } catch (e) {
      LogManager.addLog(LogLevel.error, "AndroidFirstUseManager", 
          "Error saving firstUse data: $e");
    }
  }
  
  /// 读取firstUse数据
  Future<List<String>> readFirstUse() async {
    try {
      if (_firstUse == null) {
        await _loadFromFile();
      }
      
      if (_firstUse == null) {
        return ["0", "0", "0", "0", "0"];
      }
      
      return List.from(_firstUse!);
    } catch (e) {
      LogManager.addLog(LogLevel.error, "AndroidFirstUseManager", 
          "Error reading firstUse data: $e");
      return ["0", "0", "0", "0", "0"];
    }
  }
  
  /// 写入firstUse数据
  Future<void> writeFirstUse(List<String> firstUseData) async {
    try {
      if (_firstUseFile == null) {
        await init();
      }
      
      if (_firstUseFile != null) {
        // 确保数组长度足够
        List<String> dataToWrite = List.from(firstUseData);
        while (dataToWrite.length < 5) {
          dataToWrite.add("0");
        }
        
        _firstUse = dataToWrite;
        await _saveToFile();
        LogManager.addLog(LogLevel.info, "AndroidFirstUseManager", 
            "Wrote firstUse data: ${dataToWrite.join(",")}");
      }
    } catch (e) {
      LogManager.addLog(LogLevel.error, "AndroidFirstUseManager", 
          "Error writing firstUse data: $e");
    }
  }
  
  /// 获取firstUse[3]的值
  Future<String> getFirstUse3() async {
    List<String> firstUseData = await readFirstUse();
    return firstUseData.length > 3 ? firstUseData[3] : "0";
  }
  
  /// 检查是否是首次使用
  static Future<bool> isFirstUse() async {
    try {
      String firstUse3 = await instance.getFirstUse3();
      return firstUse3 != "1";
    } catch (e) {
      LogManager.addLog(LogLevel.error, "AndroidFirstUseManager.isFirstUse", 
          "Error checking first use: $e");
      return true; // 发生错误时，显示欢迎页面
    }
  }
  
  /// 设置firstUse[3]的值
  Future<void> setFirstUse3(String value) async {
    try {
      if (_firstUse == null) {
        await _loadFromFile();
      }
      
      if (_firstUse != null && _firstUse!.length > 3) {
        _firstUse![3] = value;
        await _saveToFile();
      }
    } catch (e) {
      LogManager.addLog(LogLevel.error, "AndroidFirstUseManager.setFirstUse3", 
          "Error setting firstUse[3]: $e");
    }
  }

  /// 从SharedPreferences迁移firstUse数据到外部文件
  Future<void> migrateFromSharedPreferences() async {
    try {
      var s = await SharedPreferences.getInstance();
      var firstUseData = s.getStringList("firstUse");
      
      if (firstUseData != null && firstUseData.isNotEmpty) {
        await writeFirstUse(firstUseData);
        LogManager.addLog(LogLevel.info, "AndroidFirstUseManager", 
            "Migrated firstUse data from SharedPreferences");
      } else {
        LogManager.addLog(LogLevel.info, "AndroidFirstUseManager", 
            "No firstUse data in SharedPreferences to migrate");
      }
    } catch (e) {
      LogManager.addLog(LogLevel.error, "AndroidFirstUseManager", 
          "Error migrating firstUse data from SharedPreferences: $e");
    }
  }
  
  /// 同步firstUse数据到SharedPreferences（用于兼容性）
  Future<void> syncToSharedPreferences() async {
    try {
      List<String> firstUseData = await readFirstUse();
      var s = await SharedPreferences.getInstance();
      await s.setStringList("firstUse", firstUseData);
      LogManager.addLog(LogLevel.info, "AndroidFirstUseManager", 
          "Synced firstUse data to SharedPreferences");
    } catch (e) {
      LogManager.addLog(LogLevel.error, "AndroidFirstUseManager", 
          "Error syncing firstUse data to SharedPreferences: $e");
    }
  }
}