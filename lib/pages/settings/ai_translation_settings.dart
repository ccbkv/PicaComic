part of 'settings_page.dart';

class AiTranslationSettingsPage extends StatefulWidget {
  const AiTranslationSettingsPage({
    super.key,
    this.onChanged,
    this.comicId,
    this.comicSource,
    this.chapterId,
    this.embedded = false,
  });

  final void Function(String key)? onChanged;
  final String? comicId;
  final String? comicSource;
  final String? chapterId;
  final bool embedded;

  @override
  State<AiTranslationSettingsPage> createState() =>
      _AiTranslationSettingsPageState();
}

class _AiTranslationSettingsPageState extends State<AiTranslationSettingsPage> {
  late bool _translationAdvanced;

  @override
  void initState() {
    super.initState();
    _translationAdvanced = TranslationPerformanceConfig.current ==
        TranslationPerformancePreset.custom;
  }

  TranslationConfig _effectiveTranslationConfig() {
    var comicId = widget.comicId;
    if (comicId == null) return TranslationConfig.global;
    return TranslationConfig.of(comicId, widget.comicSource);
  }

  String _effectiveSourceLang() => _effectiveTranslationConfig().sourceLang;

  String _effectiveTargetLang() => _effectiveTranslationConfig().targetLang;

  Map<String, String> _targetLanguageOptions() {
    var options = {
      for (var e in TranslationTargets.builtIn.entries) e.key: e.value.label.tl,
      for (var e in TranslationTargets.custom) e.code: e.name,
    };
    var current = _effectiveTargetLang();
    options.putIfAbsent(current, () => current);
    return options;
  }

  Map<String, String> _sourceLanguageOptions() {
    var options = {
      'auto': '自动检测'.tl,
      for (var e in TranslationSources.builtIn.entries) e.key: e.value.tl,
      for (var e in TranslationSources.custom) e.code: e.name,
    };
    var current = _effectiveSourceLang();
    options.putIfAbsent(current, () => current);
    return options;
  }

  int _customLanguageCount() =>
      TranslationSources.custom.length + TranslationTargets.custom.length;

  String _activeProviderSubtitle() {
    var active = LlmProviderStore.active;
    if (active == null) return '未配置'.tl;
    var label = active.name.isNotEmpty
        ? active.name
        : active.isPublicFree
            ? '谷歌翻译（免 Key）'.tl
            : active.url.isNotEmpty
                ? active.url
                : '未命名服务商'.tl;
    var count = LlmProviderStore.providers.length;
    if (count > 1) {
      label +=
          ' (${'共 @count 个'.tlParams({'count': count.toString()})})';
    }
    return label;
  }

  void _showTranslationHelp() => _showTranslationUsageGuide(context);

  void _testTranslation() async {
    if (!LlmTranslator.isConfigured) {
      context.showMessage(message: '请先添加一个翻译服务'.tl);
      return;
    }
    var controller = showLoadingDialog(
      context,
      message: '正在测试翻译'.tl,
      allowCancel: false,
    );
    String? result;
    String? error;
    try {
      var res = await LlmTranslator.translateBatch(
        const ['こんにちは', 'ありがとう'],
        _effectiveTargetLang(),
      );
      result = res.texts.where((t) => t.isNotEmpty).join(' / ');
      if (result.isEmpty) {
        error = '模型返回了空结果'.tl;
        result = null;
      }
    } catch (e) {
      error = e.toString();
    }
    controller.close();
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => ContentDialog(
        title: error == null
            ? '翻译成功'.tl
            : '翻译失败'.tl,
        content: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(error ?? 'こんにちは / ありがとう →\n$result', style: ts.s14),
        ),
        actions: [
          FilledButton(
            onPressed: () => context.pop(),
            child: Text('确定'.tl),
          ),
        ],
      ),
    );
  }

  void _setTranslationPreset(String value) {
    var preset = TranslationPerformanceConfig.fromSetting(value);
    TranslationPerformanceConfig.apply(preset);
    setState(() {
      _translationAdvanced = preset == TranslationPerformancePreset.custom;
    });
  }

  void _markTranslationCustom(String key) {
    TranslationPerformanceConfig.markCustom(save: false);
    setState(() {});
    widget.onChanged?.call(key);
  }

  Future<void> _open(Widget page) async {
    await context.to(() => page);
    if (mounted) setState(() {});
  }

  Widget _translationGroup() {
    return _TranslationExpansionTile(
      expansionKey: const PageStorageKey('readerTranslationGroup'),
      initiallyExpanded: true,
      icon: Icons.translate,
      title: 'AI 翻译（实验性）'.tl,
      children: [
        _TranslationCallbackSetting(
          title: 'AI 翻译怎么用'.tl,
          subtitle: '配置与使用说明'.tl,
          actionTitle: '帮助'.tl,
          callback: _showTranslationHelp,
        ),
        if (widget.comicId != null && widget.comicSource != null)
          ListTile(
            title: Text('阅读时翻译页面'.tl),
            subtitle: Text(
              '仅对本漫画生效。页面翻译完成前先显示原图。'
                  .tl,
            ),
            trailing: Switch(
              value: ImageTranslationService.isEnabledForComic(
                widget.comicId!,
                widget.comicSource!,
              ),
              onChanged: (value) {
                ImageTranslationService.setEnabledForComic(
                  widget.comicId!,
                  widget.comicSource!,
                  value,
                );
                appdata.saveData();
                setState(() {});
                widget.onChanged?.call('enableImageTranslation');
              },
            ),
          )
        else
          ListTile(
            title: Text('阅读时翻译页面'.tl),
            subtitle: Text(
              '请在漫画详情页或阅读器设置中对具体漫画开启。'
                  .tl,
            ),
            enabled: false,
          ),
        _TranslationCallbackSetting(
          title: 'LLM 服务商'.tl,
          subtitle: _activeProviderSubtitle(),
          actionTitle: '管理'.tl,
          callback: () => _open(const LlmProvidersPage()),
        ),
        _TranslationCallbackSetting(
          title: '翻译提示词'.tl,
          subtitle: LlmPromptStore.isCustom ? '自定义'.tl : '内置'.tl,
          actionTitle: '编辑'.tl,
          callback: () => _open(const TranslationPromptPage()),
        ),
        _TranslationCallbackSetting(
          title: '测试翻译'.tl,
          subtitle: '用一句样例检测端点是否可用'.tl,
          actionTitle: '测试'.tl,
          callback: _testTranslation,
        ),
        _TranslationSelectSetting(
          title: '源语言'.tl,
          settingKey: TranslationConfig.sourceKeyName,
          optionTranslation: _sourceLanguageOptions(),
          comicId: widget.comicId,
          comicSource: widget.comicSource,
          onChanged: () {
            setState(() {});
            widget.onChanged?.call('imageTranslationSource');
          },
        ),
        _TranslationSelectSetting(
          title: '目标语言'.tl,
          settingKey: TranslationConfig.targetKeyName,
          optionTranslation: _targetLanguageOptions(),
          comicId: widget.comicId,
          comicSource: widget.comicSource,
          onChanged: () {
            setState(() {});
            widget.onChanged?.call('imageTranslationTarget');
          },
        ),
        _TranslationCallbackSetting(
          title: '自定义语言'.tl,
          subtitle: _customLanguageCount() == 0
              ? '添加列表中没有的源语言或目标语言'.tl
              : '已添加 @count 个'.tlParams({
                  'count': _customLanguageCount().toString(),
                }),
          actionTitle: '管理'.tl,
          callback: () => _open(const TranslationLanguagesPage()),
        ),
        _TranslationSelectSetting(
          title: '性能模式'.tl,
          settingKey: TranslationPerformanceConfig.settingKey,
          optionTranslation: {
            'saver': '省电（低内存）'.tl,
            'balanced': '均衡（推荐）'.tl,
            'fast': '极速（耗电更多）'.tl,
            'custom': '自定义'.tl,
          },
          onChanged: () => _setTranslationPreset(
            '${appdata.translationSettings[TranslationPerformanceConfig.settingKey]}',
          ),
        ),
        ListTile(
          leading: const Icon(Icons.tune),
          title: Text('高级设置'.tl),
          trailing: Icon(
            _translationAdvanced ? Icons.expand_less : Icons.expand_more,
          ),
          onTap: () => setState(() {
            _translationAdvanced = !_translationAdvanced;
          }),
        ),
        if (_translationAdvanced) ...[
          _TranslationSelectSetting(
            title: '文字消除'.tl,
            settingKey: TranslationConfig.inpaintKeyName,
            help:
                '嵌字前如何消除原文。智能消除会重建背景，气泡上不再有大方块；色块遮盖是旧的纯色方块。'
                    .tl,
            optionTranslation: {
              'smart': '智能消除'.tl,
              'patch': '色块遮盖'.tl,
            },
            comicId: widget.comicId,
            comicSource: widget.comicSource,
            onChanged: () {
              setState(() {});
              widget.onChanged?.call('imageTranslationInpaintMode');
            },
          ),
          _TranslationSliderSetting(
            title: '预翻译每次请求合并页数'.tl,
            settingsIndex: 'imageTranslationPreBatchPages',
            interval: 1,
            min: 1,
            max: App.isDesktop ? 20 : 8,
            onChanged: () =>
                _markTranslationCustom('imageTranslationPreBatchPages'),
          ),
          _TranslationSliderSetting(
            title: 'OCR 并行数（0 = 自动）'.tl,
            settingsIndex: 'imageTranslationOcrWorkers',
            interval: 1,
            min: 0,
            max: App.isDesktop ? 6 : 2,
            onChanged: () =>
                _markTranslationCustom('imageTranslationOcrWorkers'),
          ),
          _TranslationSliderSetting(
            title: '图片下载并发数'.tl,
            settingsIndex: 'imageTranslationImageConcurrency',
            interval: 1,
            min: 1,
            max: App.isDesktop ? 6 : 3,
            onChanged: () =>
                _markTranslationCustom('imageTranslationImageConcurrency'),
          ),
          _TranslationSliderSetting(
            title: '翻译请求并发数'.tl,
            settingsIndex: 'imageTranslationLlmConcurrency',
            interval: 1,
            min: 1,
            max: App.isDesktop ? 4 : 3,
            onChanged: () =>
                _markTranslationCustom('imageTranslationLlmConcurrency'),
          ),
        ],
        _TranslationCallbackSetting(
          title: '翻译模型'.tl,
          subtitle: TranslationModels.isReadyFor(_effectiveSourceLang())
              ? '模型已就绪'.tl
              : '模型未下载'.tl,
          actionTitle: '管理'.tl,
          callback: () => _open(
            TranslationModelsPage(sourceLang: _effectiveSourceLang()),
          ),
        ),
        _TranslationCallbackSetting(
          title: '清除翻译结果'.tl,
          subtitle:
              '删除所有已存储的翻译文本与渲染图。每部漫画学习到的语言与术语表会保留。'
                  .tl,
          actionTitle: '清除'.tl,
          callback: () => showConfirmDialog(
            context: context,
            title: '清除翻译结果'.tl,
            content:
                '删除所有已存储的翻译文本与渲染图。重新翻译这些页面会再次消耗 API 用量。'
                    .tl,
            btnColor: context.colorScheme.error,
            onConfirm: () async {
              await ImageTranslationService.instance.clearAllTranslationCache();
              PreTranslationTaskManager.instance.clearAllChapterStatus();
              if (!mounted) return;
              context.showMessage(message: '翻译结果已清除'.tl);
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final group = _translationGroup();
    if (widget.embedded) return group;
    return Material(
      child: SmoothCustomScrollView(
        slivers: [
          SliverAppbar(title: Text('AI 翻译'.tl)),
          group.toSliver(),
        ],
      ),
    );
  }
}

void _showTranslationUsageGuide(BuildContext context, {String? topic}) {
  Widget section(String title, String body) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: ts.bold.s14),
        const SizedBox(height: 4),
        Text(body, style: ts.s14),
        const SizedBox(height: 16),
      ],
    );
  }

  showDialog(
    context: context,
    builder: (context) => ContentDialog(
      title: 'AI 翻译帮助'.tl,
      content: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            section(
              '它能做什么'.tl,
              '识别漫画页面中的文字，并把译文直接叠加到图片上，保留原画。文字的查找和识别都在本机完成，识别出的文本再交给 AI 模型翻译。'
                  .tl,
            ),
            section(
              '首次配置'.tl,
              '1. 打开「LLM 服务商」添加一个。选「谷歌翻译」即用它的免费接口，什么都不用填；选「AI 模型」则填写 API 地址、API Key 和模型，任何兼容 OpenAI 的服务都可以。可添加多个并随时切换。\n2. 点「测试翻译」确认能正常返回。\n3. 打开「翻译模型」，下载对应源语言的模型（本机文字识别需要）。'
                  .tl,
            ),
            section(
              '如何使用'.tl,
              '翻译按漫画单独开启，而非全局开启，因为它会消耗你的 API 额度。打开一部漫画，开启「阅读时翻译页面」，翻页时即会自动翻译。想提前翻译，可在漫画菜单里用「预翻译」。'
                  .tl,
            ),
            section(
              '目标语言'.tl,
              '列表里没有想要的语言？打开「自定义语言」，点「目标语言」右侧的「+」，填写名称（AI 模型按它翻译，如 ไทย）和代码（谷歌翻译与脚本使用，如 th），之后即可在「目标语言」中选择。删除后已翻译的页面会保留。'
                  .tl,
            ),
            section(
              '小提示'.tl,
              '翻译结果会被保存，每页只翻译一次。想释放空间可用「清除翻译结果」。不确定源语言时，保持「自动检测」即可。'
                  .tl,
            ),
          ],
        ),
      ),
      actions: [
        Button.filled(onPressed: context.pop, child: Text('OK'.tl)),
      ],
    ),
  );
}

class _TranslationCallbackSetting extends StatelessWidget {
  const _TranslationCallbackSetting({
    required this.title,
    required this.callback,
    required this.actionTitle,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final VoidCallback callback;
  final String actionTitle;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: TextButton(onPressed: callback, child: Text(actionTitle)),
      onTap: callback,
    );
  }
}

class _TranslationExpansionTile extends StatelessWidget {
  const _TranslationExpansionTile({
    this.expansionKey,
    required this.title,
    required this.icon,
    required this.children,
    this.initiallyExpanded = false,
  });

  final Key? expansionKey;
  final String title;
  final IconData icon;
  final List<Widget> children;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      key: expansionKey,
      initiallyExpanded: initiallyExpanded,
      tilePadding: const EdgeInsets.symmetric(horizontal: 16),
      childrenPadding: const EdgeInsets.only(bottom: 8),
      leading: Icon(icon),
      title: Text(title, style: ts.bold.s18),
      children: children,
    );
  }
}

class _TranslationSelectSetting extends StatefulWidget {
  const _TranslationSelectSetting({
    required this.title,
    required this.settingKey,
    required this.optionTranslation,
    this.onChanged,
    this.help,
    this.comicId,
    this.comicSource,
  });

  final String title;
  final String settingKey;
  final Map<String, String> optionTranslation;
  final VoidCallback? onChanged;
  final String? help;
  final String? comicId;
  final String? comicSource;

  @override
  State<_TranslationSelectSetting> createState() =>
      _TranslationSelectSettingState();
}

class _TranslationSelectSettingState extends State<_TranslationSelectSetting> {
  dynamic get _value {
    var value = widget.comicId != null
        ? appdata.getTranslationReaderSetting(
            widget.comicId,
            widget.comicSource,
            widget.settingKey,
          )
        : appdata.translationSettings[widget.settingKey];
    if (value is String && value.isNotEmpty) return value;
    return switch (widget.settingKey) {
      TranslationConfig.sourceKeyName => 'auto',
      TranslationConfig.targetKeyName => 'zh',
      TranslationConfig.inpaintKeyName => 'smart',
      TranslationPerformanceConfig.settingKey => 'balanced',
      _ => value,
    };
  }

  void _apply(String value) {
    setState(() {
      appdata.setTranslationReaderSetting(
        widget.comicId,
        widget.comicSource,
        widget.settingKey,
        value,
      );
    });
    widget.onChanged?.call();
  }

  Widget _title() {
    return Row(
      children: [
        Expanded(child: Text(widget.title)),
        const SizedBox(width: 4),
        if (widget.help != null)
          Button.icon(
            size: 18,
            icon: const Icon(Icons.help_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => ContentDialog(
                  title: '帮助'.tl,
                  content: Text(widget.help!)
                      .paddingHorizontal(16)
                      .fixWidth(double.infinity),
                  actions: [
                    Button.filled(
                      onPressed: context.pop,
                      child: Text('确定'.tl),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    var options = widget.optionTranslation;
    var value = _value;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 450) {
          return ListTile(
            title: _title(),
            subtitle: Text(options[value] ?? '无'.tl),
            trailing: const Icon(Icons.arrow_drop_down),
            onTap: () {
              var renderBox = context.findRenderObject() as RenderBox;
              var offset = renderBox.localToGlobal(Offset.zero);
              var rect = offset & renderBox.size;
              showMenu<String>(
                elevation: 3,
                color: context.brightness == Brightness.light
                    ? const Color(0xFFF6F6F6)
                    : const Color(0xFF1E1E1E),
                context: context,
                position: RelativeRect.fromRect(
                  rect,
                  Offset.zero & MediaQuery.of(context).size,
                ),
                items: options.keys
                    .map(
                      (key) => PopupMenuItem(
                        value: key,
                        height: App.isMobile ? 46 : 40,
                        child: Text(options[key]!),
                      ),
                    )
                    .toList(),
              ).then((value) {
                if (value != null) _apply(value);
              });
            },
          );
        }
        return ListTile(
          title: _title(),
          trailing: components.Select(
            current: options[value],
            values: options.values.toList(),
            minWidth: 64,
            onTap: (index) => _apply(options.keys.elementAt(index)),
          ),
        );
      },
    );
  }
}

class _TranslationSliderSetting extends StatefulWidget {
  const _TranslationSliderSetting({
    required this.title,
    required this.settingsIndex,
    required this.interval,
    required this.min,
    required this.max,
    this.onChanged,
  });

  final String title;
  final String settingsIndex;
  final double interval;
  final double min;
  final double max;
  final VoidCallback? onChanged;

  @override
  State<_TranslationSliderSetting> createState() =>
      _TranslationSliderSettingState();
}

class _TranslationSliderSettingState extends State<_TranslationSliderSetting> {
  bool _needsSave = false;

  void _save() {
    if (!_needsSave) return;
    _needsSave = false;
    appdata.saveData();
  }

  @override
  void dispose() {
    _save();
    super.dispose();
  }

  double _fallback() {
    var values = TranslationPerformanceConfig.effective;
    return switch (widget.settingsIndex) {
      'imageTranslationPreBatchPages' => values.batchPages.toDouble(),
      'imageTranslationOcrWorkers' => values.ocrWorkers.toDouble(),
      'imageTranslationImageConcurrency' => values.imageConcurrency.toDouble(),
      'imageTranslationLlmConcurrency' => values.llmConcurrency.toDouble(),
      _ => widget.min,
    };
  }

  @override
  Widget build(BuildContext context) {
    var raw = appdata.translationSettings[widget.settingsIndex];
    var value = (raw is num ? raw.toDouble() : _fallback())
        .clamp(widget.min, widget.max)
        .toDouble();
    return ListTile(
      title: Text(widget.title),
      trailing: Text(value.toInt().toString(), style: ts.s12),
      subtitle: Slider(
        value: value,
        onChanged: (value) {
          final steps = ((value - widget.min) / widget.interval).round();
          final snapped = double.parse(
            (widget.min + steps * widget.interval)
                .clamp(widget.min, widget.max)
                .toStringAsFixed(4),
          );
          final num stored =
              snapped == snapped.roundToDouble() ? snapped.toInt() : snapped;
          setState(() {
            _needsSave = true;
            appdata.translationSettings[widget.settingsIndex] = stored;
          });
          widget.onChanged?.call();
        },
        onChangeEnd: (_) => _save(),
        divisions: ((widget.max - widget.min) / widget.interval).toInt(),
        min: widget.min,
        max: widget.max,
      ),
    );
  }
}
