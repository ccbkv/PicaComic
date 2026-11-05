part of 'settings_page.dart';

/// The user's own translation languages in one place: target languages, and
/// source languages with the recognition model each one downloads, plus an
/// optional replacement text detector. Codes are fixed once added: they are
/// part of the keys translations are stored under.
class TranslationLanguagesPage extends StatefulWidget {
  const TranslationLanguagesPage({super.key});

  @override
  State<TranslationLanguagesPage> createState() =>
      _TranslationLanguagesPageState();
}

class _TranslationLanguagesPageState extends State<TranslationLanguagesPage> {
  @override
  void initState() {
    TranslationModelStore.instance.addListener(_update);
    super.initState();
  }

  @override
  void dispose() {
    TranslationModelStore.instance.removeListener(_update);
    super.dispose();
  }

  void _update() {
    if (mounted) setState(() {});
  }

  void _editTarget([CustomTargetLanguage? existing]) async {
    var saved = await showDialog<bool>(
      context: context,
      builder: (context) => _TargetLanguageEditor(existing: existing),
    );
    if (saved == true && mounted) setState(() {});
  }

  void _deleteTarget(CustomTargetLanguage language) {
    showConfirmDialog(
      context: context,
      title: "Delete".tl,
      content:
          "Remove @name? Pages already translated into it are kept and show again if the same code is added back."
              .tlParams({'name': language.name}),
      btnColor: context.colorScheme.error,
      onConfirm: () {
        TranslationTargets.remove(language.code);
        if (mounted) setState(() {});
      },
    );
  }

  void _editSource([CustomSourceLanguage? existing]) async {
    var saved = await showDialog<CustomSourceLanguage>(
      context: context,
      builder: (context) => _SourceLanguageEditor(existing: existing),
    );
    if (saved == null || !mounted) return;
    setState(() {});
    if (!saved.component.isInstalled) _confirmSource(saved);
  }

  void _deleteSource(CustomSourceLanguage language) {
    showConfirmDialog(
      context: context,
      title: "删除".tl,
      content:
          "移除 @name 及其已下载的模型？已翻译的页面会保留。."
              .tlParams({'name': language.name}),
      btnColor: context.colorScheme.error,
      onConfirm: () {
        TranslationSources.remove(language.code);
        if (mounted) setState(() {});
      },
    );
  }

  /// States the download size before fetching a user-supplied model, with a
  /// warning when it is large enough to matter on a phone.
  void _confirmDownload(String title, int size, VoidCallback onConfirm) {
    var content = size > 0
        ? "下载 @size？".tlParams({
            'size': _TranslationModelsPageState._formatSize(size),
          })
        : "服务器未提供文件大小，仍要下载吗？".tl;
    if (size > 100 << 20) {
      content +=
          "\n\n${"大模型加载更慢、占用内存更多，在手机上可能卡顿或内存不足。".tl}";
    }
    showConfirmDialog(
      context: context,
      title: title,
      content: content,
      confirmText: "下载".tl,
      onConfirm: onConfirm,
    );
  }

  void _confirmSource(CustomSourceLanguage language) => _confirmDownload(
        language.name,
        language.sizeBytes,
        () => _download(language),
      );

  void _confirmDetector(CustomDetectorModel model) => _confirmDownload(
        "文字检测模型".tl,
        model.sizeBytes,
        () => _downloadDetector(model),
      );

  void _download(CustomSourceLanguage language) {
    var component = language.component;
    TranslationModelStore.instance.download(
      component,
      verify: () => checkRecognitionModel(
        component.filePath('rec.onnx'),
        component.filePath('dict.txt'),
        language.inputHeight,
      ),
    );
  }

  void _editDetector() async {
    var saved = await showDialog<CustomDetectorModel>(
      context: context,
      builder: (context) =>
          _DetectorEditor(existing: TranslationSources.detector),
    );
    if (saved == null || !mounted) return;
    setState(() {});
    if (!saved.component.isInstalled) _confirmDetector(saved);
  }

  void _downloadDetector(CustomDetectorModel model) {
    var component = model.component;
    TranslationModelStore.instance.download(
      component,
      verify: () => checkDetectionModel(component.filePath('det.onnx')),
    );
  }

  void _resetDetector() {
    showConfirmDialog(
      context: context,
      title: "改回内置检测模型".tl,
      content: "移除自定义检测模型及其已下载的文件？".tl,
      btnColor: context.colorScheme.error,
      onConfirm: () {
        TranslationSources.setDetector(null);
        if (mounted) setState(() {});
      },
    );
  }

  Widget _modelTrailing(ModelComponent component, VoidCallback onDownload) {
    var store = TranslationModelStore.instance;
    var state = store.stateOf(component);
    if (state.downloading) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              value: state.progress <= 0 ? null : state.progress,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: "取消".tl,
            onPressed: () => store.cancelDownload(component),
          ),
        ],
      );
    }
    if (component.isInstalled) {
      return Icon(Icons.check_circle, color: context.colorScheme.primary);
    }
    return IconButton(
      icon: const Icon(Icons.download_outlined),
      tooltip: "下载".tl,
      onPressed: onDownload,
    );
  }

  String _modelStatus(ModelComponent component, int sizeBytes) {
    var parts = <String>[
      if (sizeBytes > 0) _TranslationModelsPageState._formatSize(sizeBytes),
      component.isInstalled ? "已下载".tl : "未下载".tl,
    ];
    var error = TranslationModelStore.instance.stateOf(component).error;
    var text = parts.join(' · ');
    return error == null ? text : "$text\n${"下载失败".tl}: $error";
  }

  Widget _header(
    String title,
    String helpTopic, {
    String? addTooltip,
    VoidCallback? onAdd,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 4, 0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: context.colorScheme.primary,
                  ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: "使用说明".tl,
            onPressed: () =>
                _showTranslationUsageGuide(context, topic: helpTopic),
          ),
          if (onAdd != null)
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: addTooltip,
              onPressed: onAdd,
            ),
        ],
      ),
    );
  }

  Widget _note(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Text(
        text,
        style: ts.s12.copyWith(color: context.colorScheme.outline),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    var targets = TranslationTargets.custom;
    var sources = TranslationSources.custom;
    final detector = TranslationSources.detector;
    return Scaffold(
      body: SmoothCustomScrollView(
        slivers: [
          SliverAppbar(title: Text("自定义语言".tl)),
          _header(
            "目标语言".tl,
            'target',
            addTooltip: "添加目标语言".tl,
            onAdd: _editTarget,
          ).toSliver(),
          if (targets.isEmpty)
            _note(
              "还没有自定义语言，点击 + 添加列表中没有的语言。"
                  .tl,
            ).toSliver(),
          for (var language in targets)
            ListTile(
              title: Text(language.name),
              subtitle: Text(language.code),
              onTap: () => _editTarget(language),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: "删除".tl,
                onPressed: () => _deleteTarget(language),
              ),
            ).toSliver(),
          _header(
            "源语言".tl,
            'source',
            addTooltip: "添加源语言".tl,
            onAdd: _editSource,
          ).toSliver(),
          _note(
            "内置源语言的识别模型在「翻译模型」中下载。这里可以添加使用自备识别模型的语言。"
                .tl,
          ).toSliver(),
          for (var language in sources)
            ListTile(
              title: Text(language.name),
              subtitle: Text(
                "${language.code} · ${_modelStatus(language.component, language.sizeBytes)}",
              ),
              isThreeLine: TranslationModelStore.instance
                      .stateOf(language.component)
                      .error !=
                  null,
              onTap: () => _editSource(language),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _modelTrailing(
                    language.component,
                    () => _confirmSource(language),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: "删除".tl,
                    onPressed: () => _deleteSource(language),
                  ),
                ],
              ),
            ).toSliver(),
          _header(
            "文字检测模型".tl,
            'source',
          ).toSliver(),
          if (detector == null)
            ListTile(
              title: Text("内置（PP-OCRv4 mobile）".tl),
              subtitle: Text("点击改用自备的检测模型".tl),
              onTap: _editDetector,
            ).toSliver()
          else
            ListTile(
              title: Text(detector.url, maxLines: 2),
              subtitle: Text(
                detector.component.isInstalled
                    ? _modelStatus(detector.component, detector.sizeBytes)
                    : "${_modelStatus(detector.component, detector.sizeBytes)}\n${"下载完成前仍使用内置检测模型。".tl}",
              ),
              isThreeLine: true,
              onTap: _editDetector,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _modelTrailing(
                    detector.component,
                    () => _confirmDetector(detector),
                  ),
                  IconButton(
                    icon: const Icon(Icons.restore),
                    tooltip: "改回内置检测模型".tl,
                    onPressed: _resetDetector,
                  ),
                ],
              ),
            ).toSliver(),
          const SliverPadding(padding: EdgeInsets.only(bottom: 16)),
        ],
      ),
    );
  }
}

/// Add/rename dialog; saves on confirm and pops `true`. The code field is only
/// editable for a new entry.
class _TargetLanguageEditor extends StatefulWidget {
  const _TargetLanguageEditor({this.existing});

  final CustomTargetLanguage? existing;

  @override
  State<_TargetLanguageEditor> createState() => _TargetLanguageEditorState();
}

class _TargetLanguageEditorState extends State<_TargetLanguageEditor> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _code = TextEditingController(text: widget.existing?.code ?? '');

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  void _submit() {
    var name = _name.text.trim();
    if (name.isEmpty) {
      context.showMessage(message: "请输入语言名称".tl);
      return;
    }
    var code = widget.existing?.code;
    if (code == null) {
      code = TranslationTargets.normalizeCode(_code.text);
      if (code == null) {
        context.showMessage(message: "请输入有效的语言代码".tl);
        return;
      }
      if (TranslationTargets.isTaken(code)) {
        context.showMessage(message: "该语言已在列表中".tl);
        return;
      }
    }
    TranslationTargets.save(CustomTargetLanguage(code: code, name: name));
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    var editing = widget.existing != null;
    return ContentDialog(
      title: editing ? "编辑语言".tl : "添加语言".tl,
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 420),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _name,
                autofocus: true,
                inputFormatters: [LengthLimitingTextInputFormatter(40)],
                decoration: InputDecoration(
                  labelText: "语言名称".tl,
                  hintText: "例如 ไทย、Bahasa Indonesia".tl,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _code,
                enabled: !editing,
                decoration: InputDecoration(
                  labelText: "语言代码".tl,
                  hintText: "例如 th、id、pt-BR".tl,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                (editing
                        ? "代码不能修改：已翻译的页面按代码保存。"
                        : "AI 模型按名称翻译，建议用该语言自己的写法；代码传给谷歌翻译和翻译脚本，按所用服务支持的代码填写。")
                    .tl,
                style: ts.s12.copyWith(color: context.colorScheme.outline),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => context.pop(), child: Text("取消".tl)),
        Button.filled(onPressed: _submit, child: Text("保存".tl)),
      ],
    );
  }
}

const _rapidOcrBase =
    'https://www.modelscope.cn/models/RapidAI/RapidOCR/resolve/master';

/// Recognition models known to load and match their dictionary. Name and code
/// stay the user's to fill in.
const _recognitionPresets = [
  ('Latin script (French, German, Spanish...)', 'latin', 7.9),
  ('Cyrillic (Russian, Ukrainian...)', 'cyrillic', 8.1),
  ('Thai', 'th', 7.9),
];

const _detectorPresets = [
  ('PP-OCRv5 mobile', 'onnx/PP-OCRv5/det/ch_PP-OCRv5_det_mobile.onnx', 4.8),
  ('PP-OCRv6 small', 'onnx/PP-OCRv6/det/PP-OCRv6_det_small.onnx', 9.9),
];

/// Add/edit dialog for a source language; probes the download size on save
/// and pops the saved entry.
class _SourceLanguageEditor extends StatefulWidget {
  const _SourceLanguageEditor({this.existing});

  final CustomSourceLanguage? existing;

  @override
  State<_SourceLanguageEditor> createState() => _SourceLanguageEditorState();
}

class _SourceLanguageEditorState extends State<_SourceLanguageEditor> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _code = TextEditingController(text: widget.existing?.code ?? '');
  late final _model = TextEditingController(
    text: widget.existing?.modelUrl ?? '',
  );
  late final _dict = TextEditingController(
    text: widget.existing?.dictUrl ?? '',
  );
  late var _height = widget.existing?.inputHeight ?? 48;
  var _checking = false;

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    _model.dispose();
    _dict.dispose();
    super.dispose();
  }

  void _applyPreset(String key) {
    setState(() {
      _model.text =
          '$_rapidOcrBase/onnx/PP-OCRv5/rec/${key}_PP-OCRv5_rec_mobile.onnx';
      _dict.text =
          '$_rapidOcrBase/paddle/PP-OCRv5/rec/${key}_PP-OCRv5_rec_mobile/ppocrv5_${key}_dict.txt';
      _height = 48;
    });
  }

  Future<void> _submit() async {
    var name = _name.text.trim();
    if (name.isEmpty) {
      context.showMessage(message: "请输入语言名称".tl);
      return;
    }
    var code = widget.existing?.code;
    if (code == null) {
      code = TranslationTargets.normalizeCode(_code.text);
      if (code == null) {
        context.showMessage(message: "请输入有效的语言代码".tl);
        return;
      }
      if (TranslationSources.isTaken(code)) {
        context.showMessage(message: "该语言已在列表中".tl);
        return;
      }
    }
    var model = _model.text.trim();
    var dict = _dict.text.trim();
    if (!TranslationSources.isValidUrl(model) ||
        !TranslationSources.isValidUrl(dict)) {
      context.showMessage(message: "请为两个文件填写 http(s) 链接".tl);
      return;
    }
    setState(() => _checking = true);
    var store = TranslationModelStore.instance;
    var sizes = await Future.wait([
      store.probeSize(model),
      store.probeSize(dict),
    ]);
    if (!mounted) return;
    var language = CustomSourceLanguage(
      code: code,
      name: name,
      modelUrl: model,
      dictUrl: dict,
      inputHeight: _height,
      sizeBytes: sizes.contains(null) ? 0 : sizes[0]! + sizes[1]!,
    );
    TranslationSources.save(language);
    Navigator.of(context).pop(language);
  }

  @override
  Widget build(BuildContext context) {
    var editing = widget.existing != null;
    InputDecoration field(String label, [String? hint]) => InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
        );
    return ContentDialog(
      title: editing ? "编辑源语言".tl : "添加源语言".tl,
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 560),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _name,
                autofocus: true,
                inputFormatters: [LengthLimitingTextInputFormatter(40)],
                decoration: field("语言名称".tl, "例如 Français、ไทย".tl),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _code,
                enabled: !editing,
                decoration: field("语言代码".tl, "例如 fr、ru、th".tl),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text("填入已验证的模型：".tl, style: ts.s12),
                  for (var p in _recognitionPresets)
                    ActionChip(
                      label: Text("${p.$1.tl} · ${p.$3} MB"),
                      onPressed: () => _applyPreset(p.$2),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _model,
                decoration: field("识别模型链接（.onnx）".tl),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _dict,
                decoration: field("字符字典链接（.txt）".tl),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: Text("输入高度".tl)),
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 48, label: Text('48')),
                      ButtonSegment(value: 32, label: Text('32')),
                    ],
                    selected: {_height},
                    onSelectionChanged: (v) =>
                        setState(() => _height = v.first),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                "支持：ONNX 格式的 PP-OCR 文字识别模型，以及训练时配套的字符字典。Paddle、MNN、PyTorch 格式和其他类型的模型不可用。PP-OCRv3 及之后的版本输入高度为 48，更早的为 32。下载后会检查模型，不符合要求会自动删除。模型越大越准确，但加载更慢、占用内存更多。"
                    .tl,
                style: ts.s12.copyWith(color: context.colorScheme.outline),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => context.pop(), child: Text("取消".tl)),
        Button.filled(
          isLoading: _checking,
          onPressed: _submit,
          child: Text("保存".tl),
        ),
      ],
    );
  }
}

/// Dialog for the custom text detection model link.
class _DetectorEditor extends StatefulWidget {
  const _DetectorEditor({this.existing});

  final CustomDetectorModel? existing;

  @override
  State<_DetectorEditor> createState() => _DetectorEditorState();
}

class _DetectorEditorState extends State<_DetectorEditor> {
  late final _url = TextEditingController(text: widget.existing?.url ?? '');
  var _checking = false;

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    var url = _url.text.trim();
    if (!TranslationSources.isValidUrl(url)) {
      context.showMessage(message: "请填写 http(s) 链接".tl);
      return;
    }
    setState(() => _checking = true);
    var size = await TranslationModelStore.instance.probeSize(url);
    if (!mounted) return;
    var model = CustomDetectorModel(url: url, sizeBytes: size ?? 0);
    TranslationSources.setDetector(model);
    Navigator.of(context).pop(model);
  }

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      title: "文字检测模型".tl,
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 460),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text("填入已验证的模型：".tl, style: ts.s12),
                  for (var p in _detectorPresets)
                    ActionChip(
                      label: Text("${p.$1} · ${p.$3} MB"),
                      onPressed: () =>
                          setState(() => _url.text = '$_rapidOcrBase/${p.$2}'),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _url,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: "检测模型链接（.onnx）".tl,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "支持：ONNX 格式的 PP-OCR 文字检测模型（DBNet）。它会替换所有语言使用的内置检测模型。检测模型越大，越能找到小字和艺术字，但每页都会变慢。"
                    .tl,
                style: ts.s12.copyWith(color: context.colorScheme.outline),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => context.pop(), child: Text("取消".tl)),
        Button.filled(
          isLoading: _checking,
          onPressed: _submit,
          child: Text("保存".tl),
        ),
      ],
    );
  }
}
