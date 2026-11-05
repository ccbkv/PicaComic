part of 'settings_page.dart';

/// Management page for the user's LLM translation providers: add, edit, delete,
/// and pick which one is active. Each provider is an OpenAI-compatible endpoint
/// with its own name / URL / key / model, so the user can keep several vendors
/// (or a paid account and a LAN gateway) and switch between them without
/// re-typing settings.
class LlmProvidersPage extends StatefulWidget {
  const LlmProvidersPage({super.key});

  @override
  State<LlmProvidersPage> createState() => _LlmProvidersPageState();
}

class _LlmProvidersPageState extends State<LlmProvidersPage> {
  void _refresh() {
    if (mounted) setState(() {});
  }

  void _addProvider() async {
    var provider = await _editProvider(null);
    if (provider != null) {
      LlmProviderStore.add(provider);
      _refresh();
    }
  }

  void _editExisting(LlmProvider provider) async {
    var edited = await _editProvider(provider);
    if (edited != null) {
      LlmProviderStore.update(edited);
      _refresh();
    }
  }

  void _deleteProvider(LlmProvider provider) {
    showConfirmDialog(
      context: context,
      title: "Delete".tl,
      content: "Delete this provider?".tl,
      btnColor: context.colorScheme.error,
      onConfirm: () {
        LlmProviderStore.remove(provider.id);
        _refresh();
      },
    );
  }

  /// Opens the add/edit sheet for [existing] (null = new) and returns the
  /// resulting provider, or null if cancelled. The dialog carries its own
  /// working copy so nothing is written until the user confirms.
  Future<LlmProvider?> _editProvider(LlmProvider? existing) {
    return showDialog<LlmProvider>(
      context: context,
      builder: (context) => _LlmProviderEditor(existing: existing),
    );
  }

  @override
  Widget build(BuildContext context) {
    var providers = LlmProviderStore.providers;
    var activeId = LlmProviderStore.active?.id ?? '';
    return Scaffold(
      body: SmoothCustomScrollView(
        slivers: [
          SliverAppbar(
            title: Text("LLM 服务商".tl),
            actions: [
              IconButton(
                icon: const Icon(Icons.help_outline),
                tooltip: "使用说明".tl,
                onPressed: () =>
                    _showTranslationUsageGuide(context, topic: 'script'),
              ),
              IconButton(
                icon: const Icon(Icons.add),
                tooltip: "添加服务商".tl,
                onPressed: _addProvider,
              ),
            ],
          ),
          if (providers.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 32,
                ),
                child: Text(
                  "还没有服务商，添加一个即可开启 AI 翻译。".tl,
                  style: ts.s14.copyWith(color: context.colorScheme.outline),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          for (var provider in providers)
            _buildProviderTile(context, provider, activeId).toSliver(),
          const SliverPadding(padding: EdgeInsets.only(bottom: 16)),
        ],
      ),
    );
  }

  Widget _buildProviderTile(
    BuildContext context,
    LlmProvider provider,
    String activeId,
  ) {
    var subtitleParts = provider.isPublicFree
        ? <String>["谷歌翻译（免 Key）".tl]
        : provider.isCustomScript
            ? <String>["自定义翻译脚本".tl]
            : <String>[
                if (provider.url.isNotEmpty) provider.url,
                if (provider.model.isNotEmpty) provider.model,
              ];
    final selected = provider.id == activeId;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      color: selected
          ? context.colorScheme.primaryContainer.withValues(alpha: .3)
          : context.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected
              ? context.colorScheme.primary
              : context.colorScheme.outlineVariant,
        ),
      ),
      child: ListTile(
        leading: RadioGroup<String>(
          groupValue: activeId,
          onChanged: (v) {
            if (v == null) return;
            LlmProviderStore.setActive(v);
            _refresh();
          },
          child: Radio<String>(value: provider.id),
        ),
        title: Text(
          provider.name.isEmpty ? "未命名服务商".tl : provider.name,
        ),
        subtitle: subtitleParts.isEmpty
            ? Text("未配置".tl)
            : Text(subtitleParts.join('\n')),
        isThreeLine: subtitleParts.length > 1,
        onTap: () => _editExisting(provider),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          tooltip: "删除".tl,
          onPressed: () => _deleteProvider(provider),
        ),
      ),
    );
  }
}

/// Add/edit dialog for a single [LlmProvider]. Holds a local working copy of
/// the four editable fields and returns a fully-formed provider (preserving the
/// original id when editing) on confirm.
class _LlmProviderEditor extends StatefulWidget {
  const _LlmProviderEditor({this.existing});

  final LlmProvider? existing;

  @override
  State<_LlmProviderEditor> createState() => _LlmProviderEditorState();
}

class _LlmProviderEditorState extends State<_LlmProviderEditor> {
  late final TextEditingController _name;
  late final TextEditingController _url;
  late final TextEditingController _key;
  late String _model;
  late LlmProviderKind _kind;
  late String _script;
  bool _showKey = false;

  @override
  void initState() {
    super.initState();
    var e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _url = TextEditingController(text: e?.url ?? '');
    _key = TextEditingController(text: e?.key ?? '');
    _model = e?.model ?? '';
    _kind = e?.kind ?? LlmProviderKind.openai;
    _script = e?.script ?? '';
  }

  @override
  void dispose() {
    _name.dispose();
    _url.dispose();
    _key.dispose();
    super.dispose();
  }

  /// Lets the user pick the model for the values being edited: fetch this
  /// endpoint's `/models` list and choose one, or type it by hand. Uses the URL
  /// and key currently in the fields, not the active provider's, so the list
  /// matches what is being configured.
  void _chooseModel() async {
    var url = _url.text.trim();
    if (url.isNotEmpty) {
      var controller = showLoadingDialog(
        context,
        message: "加载中".tl,
        allowCancel: false,
        barrierDismissible: false,
      );
      List<String>? models;
      try {
        models = await LlmTranslator.fetchModels(
          url: url,
          key: _key.text.trim(),
        );
      } catch (_) {
        models = null;
      }
      controller.close();
      if (!mounted) return;
      if (models != null && models.isNotEmpty) {
        _showModelPicker(models);
        return;
      }
      context.showMessage(message: "获取模型列表失败".tl);
    }
    _enterModelManually();
  }

  void _enterModelManually() {
    showInputDialog(
      context: context,
      title: "LLM 模型".tl,
      initialValue: _model,
      onConfirm: (value) {
        setState(() => _model = value.trim());
        return null;
      },
    );
  }

  void _showModelPicker(List<String> models) {
    var query = '';
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            var pickerHeight = (MediaQuery.sizeOf(context).height * 0.55)
                .clamp(260.0, 420.0)
                .toDouble();
            var filtered = query.isEmpty
                ? models
                : models
                    .where(
                      (model) =>
                          model.toLowerCase().contains(query.toLowerCase()),
                    )
                    .toList();
            return ContentDialog(
              title: "选择模型".tl,
              content: SizedBox(
                width: 460,
                height: pickerHeight,
                child: Column(
                  children: [
                    TextField(
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search),
                        hintText: "搜索模型".tl,
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        setDialogState(() => query = value.trim());
                      },
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          var model = filtered[index];
                          return ListTile(
                            title: Text(
                              model,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: model == _model
                                ? Icon(
                                    Icons.check,
                                    color: context.colorScheme.primary,
                                  )
                                : null,
                            onTap: () {
                              context.pop();
                              setState(() => _model = model);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    context.pop();
                    _enterModelManually();
                  },
                  child: Text("手动输入".tl),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirm() {
    var existing = widget.existing;
    if (_kind == LlmProviderKind.customScript) {
      if (_script.trim().isEmpty) {
        context.showMessage(message: "请先添加翻译脚本".tl);
        return;
      }
      Navigator.of(context).pop(
        LlmProvider(
          id: existing?.id ?? const Uuid().v4(),
          name: _name.text.trim(),
          url: _url.text.trim(),
          key: _key.text.trim(),
          model: _model.trim(),
          kind: _kind,
          script: _script,
        ),
      );
      return;
    }
    // The keyless service takes no endpoint, key or model: skip the validation
    // that only applies to a user-supplied endpoint and store empty fields.
    if (_kind == LlmProviderKind.publicFree) {
      Navigator.of(context).pop(
        LlmProvider(
          id: existing?.id ?? const Uuid().v4(),
          name: _name.text.trim().isEmpty
              ? "谷歌翻译（免 Key）".tl
              : _name.text.trim(),
          url: '',
          key: '',
          model: '',
          kind: LlmProviderKind.publicFree,
          script: _script,
        ),
      );
      return;
    }
    var url = _url.text.trim();
    if (!LlmTranslator.isValidBaseUrl(url)) {
      context.showMessage(message: "请输入有效的 API 地址".tl);
      return;
    }
    if (_model.trim().isEmpty) {
      context.showMessage(message: "请选择或填写模型".tl);
      return;
    }
    var provider = LlmProvider(
      id: existing?.id ?? const Uuid().v4(),
      name: _name.text.trim(),
      url: url,
      key: _key.text.trim(),
      model: _model.trim(),
      kind: LlmProviderKind.openai,
      script: _script,
    );
    Navigator.of(context).pop(provider);
  }

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      title: widget.existing == null ? "添加服务商".tl : "编辑服务商".tl,
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 540),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("服务类型".tl, style: ts.s14),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final kind in LlmProviderKind.values)
                    ChoiceChip(
                      label: Text(switch (kind) {
                        LlmProviderKind.openai => "AI 模型".tl,
                        LlmProviderKind.publicFree =>
                          "谷歌翻译（免 Key）".tl,
                        LlmProviderKind.customScript =>
                          "自定义翻译脚本".tl,
                      }),
                      selected: _kind == kind,
                      onSelected: (_) => setState(() => _kind = kind),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _name,
                decoration: InputDecoration(
                  labelText: "名称".tl,
                  hintText: _kind == LlmProviderKind.publicFree
                      ? "可不填".tl
                      : "例如 OpenAI、本地网关".tl,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              if (_kind == LlmProviderKind.publicFree)
                Text(
                  "使用谷歌翻译的免费接口，不需要账号和 Key，什么都不用填。效果不如 AI 模型：每句话单独翻译，不同页之间的用词和人名可能不一致。该接口非官方开放，可能被限流或随时失效。."
                      .tl,
                  style: ts.s14.copyWith(color: context.colorScheme.outline),
                )
              else ...[
                if (_kind == LlmProviderKind.customScript) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: context.colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.code,
                              size: 20,
                              color: context.colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                (_script.trim().isEmpty
                                        ? "尚未添加脚本"
                                        : "已添加脚本")
                                    .tl,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "脚本接收原文和语言信息并返回译文。网址、密钥和模型是可选的脚本参数。脚本仅保存在本机。"
                              .tl,
                          style: TextStyle(
                            fontSize: 13,
                            color: context.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Wrap(
                          spacing: 8,
                          children: [
                            TextButton.icon(
                              icon: const Icon(Icons.code),
                              label: Text("编辑翻译脚本".tl),
                              onPressed: () async {
                                final script =
                                    await Navigator.of(context).push<String>(
                                  MaterialPageRoute(
                                    builder: (_) => _TranslationScriptEditor(
                                      provider: LlmProvider(
                                        id: widget.existing?.id ?? '',
                                        name: _name.text,
                                        url: _url.text.trim(),
                                        key: _key.text.trim(),
                                        model: _model,
                                        kind: LlmProviderKind.customScript,
                                        script: _script,
                                      ),
                                    ),
                                  ),
                                );
                                if (script != null && mounted) {
                                  setState(() => _script = script);
                                }
                              },
                            ),
                            TextButton.icon(
                              onPressed: () => _showTranslationUsageGuide(
                                context,
                                topic: 'script',
                              ),
                              icon: const Icon(
                                Icons.menu_book_outlined,
                                size: 18,
                              ),
                              label: Text("使用说明".tl),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                TextField(
                  controller: _url,
                  decoration: InputDecoration(
                    labelText: "LLM API 地址".tl,
                    hintText: 'https://example.com/v1',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _key,
                  obscureText: !_showKey,
                  decoration: InputDecoration(
                    labelText: "LLM API 密钥".tl,
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      tooltip: _showKey ? "隐藏".tl : "显示".tl,
                      icon: Icon(
                        _showKey ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () => setState(() => _showKey = !_showKey),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text("LLM 模型".tl),
                  subtitle: Text(_model.isEmpty ? "未配置".tl : _model),
                  trailing: Button.filled(
                    onPressed: _kind == LlmProviderKind.customScript
                        ? _enterModelManually
                        : _chooseModel,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.cloud_download_outlined, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          (_kind == LlmProviderKind.customScript
                                  ? "手动输入"
                                  : "获取模型")
                              .tl,
                        ),
                      ],
                    ),
                  ).fixHeight(36),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _enterModelManually,
                    child: Text("手动填写模型".tl),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => context.pop(), child: Text("取消".tl)),
        Button.filled(onPressed: _confirm, child: Text("保存".tl)),
      ],
    );
  }
}
