part of 'settings_page.dart';

/// Searchable index of all settings (issue #75).
///
/// IMPORTANT: this list mirrors the settings rendered by the category pages
/// (explore_settings.dart, reader.dart, local_favorites.dart, data_sync.dart,
/// app.dart, network.dart, about.dart, debug.dart). When you add, rename, or
/// remove a setting on those pages, update the matching entry here so it stays
/// searchable.
///
/// Titles reuse the exact English source strings the pages pass to `.tl`, so a
/// single entry localizes automatically in every locale. `category` indexes
/// into [_settingsCategories] / [_settingsCategoryIcons]; tapping a result opens
/// the category and section containing the real control.
int _picaCategory(int veneraCategory) => switch (veneraCategory) {
      0 => 5, // Appearance & layout -> 外观
      1 => 2, // Reading settings -> 阅读
      2 => 6, // Library & favorites -> 本地收藏
      3 => 7, // Sync & backup -> APP
      4 => 0, // Browsing & filters -> 浏览
      5 => 8, // Network -> 网络
      6 => 12, // Debug -> Debug
      7 => 9, // About & help -> 关于
      8 => 3, // AI Translation -> AI 翻译
      9 => 11, // Downloads & storage -> 文件管理器
      10 => 7, // Privacy & device -> APP
      11 => 4, // Image enhancement -> 图片处理 / 增强
      _ => veneraCategory,
    };

class _SettingsSearchEntry {
  const _SettingsSearchEntry(
    this.title,
    this.category, {
    this.keywords = const [],
    this.visible,
  });

  /// English source string, identical to the one the page passes to `.tl`.
  final String title;

  /// Index into [_settingsCategories] / [_settingsCategoryIcons].
  final int category;

  /// Extra English match terms / synonyms beyond the localized title.
  final List<String> keywords;

  /// Optional availability guard, mirroring the page's own conditional so a
  /// result never points at a setting the current platform doesn't show.
  final bool Function()? visible;

  String get targetTitle => title == '自定义翻译脚本' ? 'LLM 服务商' : title;

  String? get fallbackTitle => switch (title) {
        '页漫阅读模式' => '自适应阅读模式',
        '夜览遮罩颜色' || '夜览强度' => '夜览模式',
        '长按缩放位置' => '长按缩放',
        '自定义翻页点击区域' => '翻页模式',
        '点击顶部区域' || '点击底部区域' || '点击左侧区域' || '点击右侧区域' => '翻页模式',
        '图片宽度（占屏幕高度的百分比）' => '限制图片宽度',
        '章节末尾显示评论' => '显示章节评论',
        '锐化强度' || '清晰度' || '对比度' || '色彩鲜艳度' => '图像增强',
        '横屏同屏幕图片数量(仅画廊模式)' ||
        '竖屏同屏幕图片数量(仅画廊模式)' ||
        '在首页显示单张图片' ||
        '铺满屏幕' ||
        '拆分双页' ||
        '翻页后居中显示' ||
        '页面间隙' ||
        '鼠标滚动速度' ||
        '自动翻页方式' =>
          '阅读模式',
        // Only one of the two shows at a time, by auto turning mode.
        '自动滚动速度' => '自动翻页间隔',
        '自动翻页间隔' => '自动滚动速度',
        '刷新颜色' || '刷新间隔（页）' || '刷新时长（毫秒）' => '翻页时全屏刷新',
        '水波纹速度' => '水波纹翻页',
        '解锁方式' => '需要授权',
        _ => null,
      };

  String? get section {
    if (category == 0) {
      return switch (title) {
        '主题模式' || '主题颜色' || '语言' => '外观',
        _ => '布局与导航',
      };
    }
    if (category == 1) {
      if (const [
        '横屏同屏幕图片数量(仅画廊模式)',
        '竖屏同屏幕图片数量(仅画廊模式)',
        '在首页显示单张图片',
        '铺满屏幕',
        '拆分双页',
        '翻页后居中显示',
        '页面间隙',
      ].contains(title)) {
        return '页面布局';
      }
      if (const [
        '自动翻页方式',
        '自动翻页间隔',
        '自动滚动速度',
        '鼠标滚动速度',
        '预加载图片数量',
      ].contains(title)) {
        return '自动翻页与预加载';
      }
      if (const [
        '翻页模式',
        '双击缩放',
        '长按缩放',
        '长按缩放位置',
        '使用音量键翻页',
        '自定义翻页点击区域',
        '点击顶部区域',
        '点击底部区域',
        '点击左侧区域',
        '点击右侧区域',
      ].contains(title)) {
        return '手势设置';
      }
      if (const [
        '收藏图片时同时收藏该章节封面',
        '快速收藏图片',
      ].contains(title)) {
        return '收藏设置';
      }
      if (const [
        '限制图片宽度',
        '图片宽度（占屏幕高度的百分比）',
        '自定义图片处理',
        '图像增强',
        '锐化强度',
        '清晰度',
        '对比度',
        '色彩鲜艳度',
      ].contains(title)) {
        return '图片处理/增强';
      }
      if (const [
        '阅读背景颜色',
        '夜览模式',
        '跟随系统深色模式',
        '夜览遮罩颜色',
        '夜览强度',
        '在阅读器中显示时间和电量信息',
        '显示系统状态栏',
        '阅读时屏幕常亮',
        '显示页码',
        '显示章节评论',
        '评论字体大小',
        '章节末尾显示评论',
      ].contains(title)) {
        return '显示设置';
      }
      if (const [
        '翻页时全屏刷新',
        '刷新颜色',
        '刷新间隔（页）',
        '刷新时长（毫秒）',
        '水波纹翻页',
        '水波纹速度',
      ].contains(title)) {
        return '墨水屏';
      }
      return '阅读模式';
    }
    if (category == 2) {
      return switch (title) {
        '在网络收藏之前显示本地收藏' || '添加新收藏到' || '阅读后移动收藏' => '排序与位置',
        '删除所有无效的本地收藏' => '收藏整理',
        _ => '收藏偏好',
      };
    }
    if (category == 3) {
      return switch (title) {
        '数据同步' || '同步模式' || '每个平台保留的备份数量' => 'WebDAV 同步',
        '同步本地漫画库' || '跳过同步项' || '同步时使用代理' => '同步范围与连接',
        '导出应用数据' || '导出翻译结果' || '导入应用数据' => '数据导入导出',
        _ => '数据管理',
      };
    }
    if (category == 4) {
      return switch (title) {
        '漫画源' || '来源库' => '漫画源管理',
        '在漫画缩略图上显示收藏状态' ||
        '在漫画缩略图上显示历史记录' ||
        '在漫画封面上显示稍后阅读标记' ||
        '在漫画缩略图上显示已加入合集标记' ||
        '在漫画缩略图上显示页数' =>
          '卡片信息',
        '自动清理阅读历史' || '手动删除单条历史记录时清除阅读进度' => '阅读历史',
        '默认搜索目标' || '自动语言筛选' || '语言筛选适用的源' || '搜索源' => '搜索偏好',
        '探索页面' || '分类页面' || '网络收藏页面' || '初始页面' || '退出前先返回首页' => '浏览页面',
        '关键词屏蔽' || '标签屏蔽' || '评论关键词屏蔽' => '内容屏蔽',
        _ => '漫画列表',
      };
    }
    if (category == 5) return '连接设置';
    if (category == 6) return '调试';
    if (category == 7) {
      return switch (title) {
        '检查更新' || '启动时检查更新' => '版本与更新',
        '应用日志' => '诊断与调试',
        _ => '帮助',
      };
    }
    if (category == 8) {
      return switch (title) {
        'LLM 服务商' || '自定义翻译脚本' || '测试翻译' => '翻译服务',
        '自定义语言' || '翻译模型' || '翻译提示词' => '模型与语言',
        '文字消除' ||
        '预翻译每次请求合并页数' ||
        'OCR 并行数（0 = 自动）' ||
        '图片下载并发数' ||
        '翻译请求并发数' =>
          '高级翻译设置',
        'AI 翻译怎么用' || '清除翻译结果' => '帮助与清理',
        _ => '翻译偏好',
      };
    }
    if (category == 9) {
      return switch (title) {
        '点击本地漫画' || '下载线程数' || '并行下载数' || '仅在 WiFi 下下载' => '下载',
        '本地漫画的存储路径' || '设置新的存储路径' || '漫画缓存目录' => '保存位置',
        _ => '缓存管理',
      };
    }
    if (category == 10) {
      return switch (title) {
        '需要授权' || '解锁方式' => '应用锁',
        _ => '设备行为',
      };
    }
    return null;
  }

  String get path {
    final group = section;
    const commonGroups = {
      '外观',
      '阅读模式',
      '收藏偏好',
      'WebDAV 同步',
      '数据管理',
      '漫画列表',
      '漫画源管理',
      '连接设置',
      '版本与更新',
      '帮助',
      '诊断与调试',
      '翻译偏好',
      '翻译服务',
      '模型与语言',
      '下载',
      '缓存管理',
      '应用锁',
      '设备行为',
    };
    return [
      categories[_picaCategory(category)].tl,
      if (group != null && !commonGroups.contains(group)) group.tl,
      if (targetTitle != title) targetTitle.tl,
    ].join(' / ');
  }
}

/// The full index. Built once; `visible` guards are evaluated lazily at match
/// time so this is safe to construct before [App] is initialized.
final _settingsSearchIndex = <_SettingsSearchEntry>[
  // --- 4: Explore ---
  _SettingsSearchEntry(
    '手动删除单条历史记录时清除阅读进度',
    4,
    keywords: ['history', 'delete', 'progress', 'read'],
  ),
  _SettingsSearchEntry("自动清理阅读历史", 4),
  _SettingsSearchEntry("漫画缩略图的显示模式", 4),
  _SettingsSearchEntry("漫画缩略图的大小", 4),
  _SettingsSearchEntry("探索页面", 4),
  _SettingsSearchEntry("分类页面", 4),
  _SettingsSearchEntry("网络收藏页面", 4),
  _SettingsSearchEntry("搜索源", 4),
  _SettingsSearchEntry("在漫画缩略图上显示收藏状态", 4),
  _SettingsSearchEntry("在漫画缩略图上显示历史记录", 4),
  _SettingsSearchEntry("在漫画封面上显示稍后阅读标记", 4),
  _SettingsSearchEntry("在漫画缩略图上显示已加入合集标记", 4),
  _SettingsSearchEntry("在漫画缩略图上显示页数", 4),
  _SettingsSearchEntry("反转默认章节顺序", 4),
  _SettingsSearchEntry("关键词屏蔽", 4, keywords: ["block", "filter"]),
  _SettingsSearchEntry("标签屏蔽", 4, keywords: ["block", "filter", "tag"]),
  _SettingsSearchEntry("评论关键词屏蔽", 4, keywords: ["block"]),
  _SettingsSearchEntry("默认搜索目标", 4, keywords: ["search"]),
  _SettingsSearchEntry("自动语言筛选", 4, keywords: ["language"]),
  _SettingsSearchEntry(
    "语言筛选适用的源",
    4,
    keywords: ["language", "source"],
  ),
  _SettingsSearchEntry("初始页面", 4),
  _SettingsSearchEntry(
    '退出前先返回首页',
    4,
    keywords: ['back', 'exit', 'gesture'],
    visible: () => App.isMobile,
  ),
  _SettingsSearchEntry("漫画列表的显示模式", 4),
  _SettingsSearchEntry("漫画源", 4, keywords: ["source", "extension"]),
  _SettingsSearchEntry(
    "来源库",
    4,
    keywords: ["source", "repository"],
  ),

  // --- 1: Reading settings ---
  _SettingsSearchEntry(
    "启用此设备特定设置",
    1,
    keywords: ["device"],
  ),
  _SettingsSearchEntry("翻页模式", 1, keywords: ["tap"]),
  _SettingsSearchEntry("页面动画", 1),
  _SettingsSearchEntry("阅读模式", 1, keywords: ["gallery", "continuous"]),
  _SettingsSearchEntry(
    '自适应阅读模式',
    1,
    keywords: ['automatic', 'layout', 'strip', 'webtoon', '自适应', '条漫', '頁漫'],
  ),
  _SettingsSearchEntry('页漫阅读模式', 1),
  _SettingsSearchEntry("连续章节阅读", 1),
  _SettingsSearchEntry(
    "横屏同屏幕图片数量(仅画廊模式)",
    1,
  ),
  _SettingsSearchEntry(
    "竖屏同屏幕图片数量(仅画廊模式)",
    1,
  ),
  _SettingsSearchEntry("在首页显示单张图片", 1),
  _SettingsSearchEntry("铺满屏幕", 1),
  _SettingsSearchEntry('拆分双页', 1, keywords: ['split']),
  _SettingsSearchEntry('翻页后居中显示', 1),
  _SettingsSearchEntry('页面间隙', 1),
  _SettingsSearchEntry(
    '开始阅读时进入全屏',
    1,
    visible: () => App.isDesktop,
  ),
  _SettingsSearchEntry('开始阅读时移出稍后阅读', 1),
  _SettingsSearchEntry("阅读背景颜色", 1, keywords: ["background"]),
  _SettingsSearchEntry("夜览模式", 1, keywords: ["dark", "eye"]),
  _SettingsSearchEntry("跟随系统深色模式", 1, keywords: ["dark"]),
  _SettingsSearchEntry("夜览遮罩颜色", 1, keywords: ["dark"]),
  _SettingsSearchEntry("夜览强度", 1, keywords: ["dark"]),
  _SettingsSearchEntry(
    "自动翻页方式",
    1,
    keywords: ["auto", "scroll"],
  ),
  _SettingsSearchEntry("自动翻页间隔", 1, keywords: ["auto"]),
  _SettingsSearchEntry("自动滚动速度", 1, keywords: ["auto", "scroll"]),
  _SettingsSearchEntry("鼠标滚动速度", 1, keywords: ["scroll"]),
  _SettingsSearchEntry("预加载图片数量", 1, keywords: ["preload"]),
  _SettingsSearchEntry("双击缩放", 1, keywords: ["gesture", "zoom"]),
  _SettingsSearchEntry("长按缩放", 1, keywords: ["gesture", "zoom"]),
  _SettingsSearchEntry("长按缩放位置", 1, keywords: ["zoom"]),
  _SettingsSearchEntry('自定义翻页点击区域', 1, keywords: ['gesture']),
  _SettingsSearchEntry('点击顶部区域', 1, keywords: ['gesture']),
  _SettingsSearchEntry('点击底部区域', 1, keywords: ['gesture']),
  _SettingsSearchEntry('点击左侧区域', 1, keywords: ['gesture']),
  _SettingsSearchEntry('点击右侧区域', 1, keywords: ['gesture']),
  _SettingsSearchEntry(
    "使用音量键翻页",
    1,
    keywords: ["volume", "gesture"],
    visible: () => App.isAndroid || PlatformUtils.isOhos,
  ),
  _SettingsSearchEntry("收藏图片时同时收藏该章节封面", 1),
  _SettingsSearchEntry("快速收藏图片", 1),
  _SettingsSearchEntry("限制图片宽度", 1),
  _SettingsSearchEntry('图片宽度（占屏幕高度的百分比）', 1),
  _SettingsSearchEntry(
    "自定义图片处理",
    1,
    keywords: ["script", "process"],
  ),
  _SettingsSearchEntry(
    "图像增强",
    11,
    keywords: ["sharpen", "enhance"],
  ),
  _SettingsSearchEntry("锐化强度", 11, keywords: ["enhance"]),
  _SettingsSearchEntry("清晰度", 11, keywords: ["enhance"]),
  _SettingsSearchEntry("对比度", 11, keywords: ["enhance"]),
  _SettingsSearchEntry("色彩鲜艳度", 11, keywords: ["enhance"]),
  _SettingsSearchEntry("在阅读器中显示时间和电量信息", 1),
  _SettingsSearchEntry("显示系统状态栏", 1),
  _SettingsSearchEntry(
    "阅读时屏幕常亮",
    1,
    keywords: ["screen", "awake", "sleep"],
    visible: () => App.isMobile,
  ),
  _SettingsSearchEntry("显示页码", 1),
  _SettingsSearchEntry("显示章节评论", 1, keywords: ["comment"]),
  _SettingsSearchEntry('评论字体大小', 1, keywords: ['comment']),
  _SettingsSearchEntry(
    "章节末尾显示评论",
    1,
    keywords: ["comment"],
  ),
  _SettingsSearchEntry(
    "翻页时全屏刷新",
    1,
    keywords: ["墨水屏", "残影"],
  ),
  _SettingsSearchEntry("刷新颜色", 1, keywords: ["墨水屏"]),
  _SettingsSearchEntry("刷新间隔（页）", 1, keywords: ["墨水屏"]),
  _SettingsSearchEntry("刷新时长（毫秒）", 1, keywords: ["墨水屏"]),
  _SettingsSearchEntry(
    "水波纹翻页",
    1,
    keywords: ["墨水屏"],
    visible: () => false,
  ),
  _SettingsSearchEntry(
    "水波纹速度",
    1,
    keywords: ["墨水屏"],
    visible: () => false,
  ),
  _SettingsSearchEntry(
    "AI 翻译",
    8,
    keywords: ["LLM", "OCR", "translate"],
  ),
  _SettingsSearchEntry("LLM 服务商", 8, keywords: ["API", "model"]),
  _SettingsSearchEntry('源语言', 8, keywords: ['language']),
  _SettingsSearchEntry('目标语言', 8, keywords: ['language']),
  _SettingsSearchEntry(
    '自定义语言',
    8,
    keywords: ['language', 'OCR', 'model'],
  ),
  _SettingsSearchEntry('测试翻译', 8, keywords: ['API', 'test']),
  _SettingsSearchEntry(
    "自定义翻译脚本",
    8,
    keywords: ["API", "javascript", "translate"],
  ),
  _SettingsSearchEntry(
    "翻译提示词",
    8,
    keywords: ["prompt", "token", "跟随系统"],
  ),
  _SettingsSearchEntry("性能模式", 8, keywords: ["speed", "mobile"]),
  _SettingsSearchEntry("文字消除", 8, keywords: ["erase", "inpaint"]),
  _SettingsSearchEntry("翻译模型", 8, keywords: ["OCR", "download"]),
  _SettingsSearchEntry(
    '预翻译每次请求合并页数',
    8,
    keywords: ['batch'],
  ),
  _SettingsSearchEntry('OCR 并行数（0 = 自动）', 8, keywords: ['speed']),
  _SettingsSearchEntry('图片下载并发数', 8, keywords: ['download']),
  _SettingsSearchEntry(
    '翻译请求并发数',
    8,
    keywords: ['API', 'speed'],
  ),
  _SettingsSearchEntry(
    'AI 翻译怎么用',
    8,
    keywords: ['help', 'guide'],
  ),
  _SettingsSearchEntry(
    '清除翻译结果',
    8,
    keywords: ['cache', 'cleanup'],
  ),

  // --- 0: App / Appearance ---
  _SettingsSearchEntry("主题模式", 0, keywords: ["dark", "light"]),
  _SettingsSearchEntry("主题颜色", 0, keywords: ["accent", "color"]),
  _SettingsSearchEntry(
    "预测性返回动画",
    0,
    keywords: ["back", "gesture", "animation"],
    visible: () => App.isAndroid,
  ),
  _SettingsSearchEntry("主页布局", 0, keywords: ["home", "layout"]),
  _SettingsSearchEntry("图片收藏标签页", 0, keywords: ["tabs"]),
  _SettingsSearchEntry(
    "应用图标",
    0,
    keywords: ["launcher", "icon"],
    visible: () => false,
  ),

  // --- 2: Local Favorites ---
  _SettingsSearchEntry("在网络收藏之前显示本地收藏", 2),
  _SettingsSearchEntry("自动关闭收藏面板", 2),
  _SettingsSearchEntry("添加新收藏到", 2),
  _SettingsSearchEntry("阅读后移动收藏", 2),
  _SettingsSearchEntry("快速收藏", 2),
  _SettingsSearchEntry("删除所有无效的本地收藏", 2),
  _SettingsSearchEntry("点击收藏", 2),
  _SettingsSearchEntry(
    "追更设置",
    2,
    keywords: ["follow", "update"],
  ),

  // --- 9: Downloads & storage ---
  _SettingsSearchEntry(
    "点击本地漫画",
    9,
    keywords: ["local", "read", "detail", "打开"],
  ),
  _SettingsSearchEntry("本地漫画的存储路径", 9, keywords: ["path"]),
  _SettingsSearchEntry("设置新的存储路径", 9, keywords: ["path"]),
  _SettingsSearchEntry("缓存大小", 9, keywords: ["cache"]),
  _SettingsSearchEntry("漫画缓存目录", 9, keywords: ["cache", "path"]),
  _SettingsSearchEntry("清除缓存", 9, keywords: ["cache"]),
  _SettingsSearchEntry("缓存限制", 9, keywords: ["cache"]),
  _SettingsSearchEntry("下载线程数", 9, keywords: ["download"]),
  _SettingsSearchEntry("并行下载数", 9, keywords: ["download"]),
  _SettingsSearchEntry(
    "仅在 WiFi 下下载",
    9,
    keywords: ["wifi", "wlan", "download", "data"],
  ),

  // --- 3: Sync & backup ---
  _SettingsSearchEntry("导出应用数据", 3, keywords: ["backup", "export"]),
  _SettingsSearchEntry(
    "导出翻译结果",
    3,
    keywords: ["backup", "export"],
  ),
  _SettingsSearchEntry("导入应用数据", 3, keywords: ["restore", "import"]),
  _SettingsSearchEntry(
    "数据同步",
    3,
    keywords: ["webdav", "backup", "sync", "cloud"],
  ),
  _SettingsSearchEntry("同步模式", 3, keywords: ["webdav", "sync"]),
  _SettingsSearchEntry(
    "每个平台保留的备份数量",
    3,
    keywords: ["webdav", "backup", "retention"],
  ),
  _SettingsSearchEntry(
    "同步本地漫画库",
    3,
    keywords: ["webdav", "sync", "library"],
  ),
  _SettingsSearchEntry(
    "同步时使用代理",
    3,
    keywords: ["webdav", "sync", "proxy"],
  ),
  _SettingsSearchEntry(
    "跳过同步项",
    3,
    keywords: ["webdav", "sync", "skip", "exclude"],
  ),
  _SettingsSearchEntry("同步日志", 3, keywords: ["webdav", "log"]),
  _SettingsSearchEntry(
    "WebDAV 漫画库",
    3,
    keywords: ["webdav", "library", "comic", "remote", "nas", "cloud"],
  ),

  // --- 0: Appearance & layout ---
  _SettingsSearchEntry("语言", 0, keywords: ["locale", "language"]),

  // --- 10: Privacy & device ---
  _SettingsSearchEntry(
    "需要授权",
    10,
    keywords: ["password", "lock", "biometric", "fingerprint", "privacy"],
    visible: () => !App.isLinux,
  ),
  _SettingsSearchEntry(
    "解锁方式",
    10,
    keywords: ["password", "lock", "biometric", "pin"],
    visible: () => !App.isLinux,
  ),
  _SettingsSearchEntry(
    "最小化到托盘",
    10,
    keywords: ["tray", "window"],
    visible: () => App.isWindows,
  ),
  _SettingsSearchEntry(
    "键盘快捷键",
    10,
    keywords: ["hotkey", "shortcut", "keyboard", "全屏"],
    visible: () => App.isDesktop,
  ),
  _SettingsSearchEntry(
    "忽略电池优化",
    10,
    keywords: ["battery", "background"],
    visible: () => App.isAndroid,
  ),

  // --- 5: Network ---
  _SettingsSearchEntry("代理", 5, keywords: ["vpn", "socks", "http"]),
  _SettingsSearchEntry("DNS覆写", 5, keywords: ["dns", "hosts", "sni"]),

  // --- 7: About ---
  _SettingsSearchEntry("检查更新", 7, keywords: ["update", "version"]),
  _SettingsSearchEntry("启动时检查更新", 7, keywords: ["update"]),
  _SettingsSearchEntry(
    "使用说明",
    7,
    keywords: ["guide", "help", "manual", "how to", "usage"],
  ),
  _SettingsSearchEntry("仓库", 7, keywords: ["github", "source"]),
  _SettingsSearchEntry("用户协议与免责声明", 7),
  _SettingsSearchEntry(
    "应用日志",
    7,
    keywords: ["log", "logs", "crash", "error", "diagnostics"],
  ),

  // --- 6: Debug ---
  _SettingsSearchEntry("重新加载配置文件", 6),
  _SettingsSearchEntry(
    "忽略证书错误",
    6,
    keywords: ["ssl", "tls"],
  ),
  _SettingsSearchEntry(
    "JS 求值器",
    6,
    keywords: ["javascript", "js", "eval"],
  ),
];

/// Returns the entries matching [query] (case-insensitive substring over the
/// localized title, the English source, the category name, and keywords).
List<_SettingsSearchEntry> _matchSettingsSearch(
  String query, {
  Iterable<_SettingsSearchEntry>? entries,
}) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return const [];
  final result = <_SettingsSearchEntry>[];
  for (final e in entries ?? _settingsSearchIndex) {
    if (e.visible != null && !e.visible!()) continue;
    if (_settingsEntryMatches(e, q)) result.add(e);
  }
  return result;
}

/// Matches [q] against the Chinese source string whose English translation is
/// [english]. PicaComic's search index uses English titles, while users search
/// in Chinese; this reverse lookup bridges the two.
bool _matchesZh(String english, String q) {
  final zh = AppTranslation.zhSource(english);
  return zh != null && zh.toLowerCase().contains(q);
}

bool _settingsEntryMatches(_SettingsSearchEntry e, String q) {
  if (e.title.toLowerCase().contains(q)) return true;
  if (e.title.tl.toLowerCase().contains(q)) return true;
  if (_matchesZh(e.title, q)) return true;
  if (_matchesZh(e.targetTitle, q)) return true;
  final section = e.section;
  if (section != null &&
      (section.toLowerCase().contains(q) ||
          section.tl.toLowerCase().contains(q) ||
          _matchesZh(section, q))) {
    return true;
  }
  final catName = categories[_picaCategory(e.category)];
  if (catName.toLowerCase().contains(q) ||
      catName.tl.toLowerCase().contains(q)) {
    return true;
  }
  for (final k in e.keywords) {
    if (k.toLowerCase().contains(q) ||
        k.tl.toLowerCase().contains(q) ||
        _matchesZh(k, q)) {
      return true;
    }
  }
  return false;
}

/// Builds the search results list shown in place of the category list while a
/// query is active. The selected entry carries its route and focus target.
Widget _buildSettingsSearchResults(
  BuildContext context,
  String query,
  void Function(_SettingsSearchEntry entry) onOpen, {
  Iterable<_SettingsSearchEntry>? entries,
}) {
  final results = _matchSettingsSearch(query, entries: entries);
  if (results.isEmpty) {
    return Center(
      child: Text("没有匹配的设置".tl, style: ts.s14),
    ).paddingTop(32);
  }
  return ListView.builder(
    padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
    itemCount: results.length,
    itemBuilder: (context, index) {
      final e = results[index];
      return ListTile(
        key: ValueKey('settings-result-${e.title}'),
        leading: Icon(icons[_picaCategory(e.category)]),
        title: Text(e.title.tl),
        subtitle: Text(e.path),
        onTap: () => onOpen(e),
      );
    },
  );
}
