part of 'settings_page.dart';

/// Management page for offline translation model files: download (with
/// progress and mirror fallback), delete, and choice of download endpoint.
class TranslationModelsPage extends StatefulWidget {
  const TranslationModelsPage({super.key, this.sourceLang});

  /// Source language whose OCR models are marked "required", or null to use the
  /// global setting. Passed by the reader's per-comic settings so the page marks
  /// the models that comic actually needs, not the ones the global default does.
  final String? sourceLang;

  @override
  State<TranslationModelsPage> createState() => _TranslationModelsPageState();
}

class _TranslationModelsPageState extends State<TranslationModelsPage> {
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

  static String _componentName(String id) {
    return switch (id) {
      'text_detector' => "文本检测".tl,
      'ocr_ja' => "日语识别（漫画专用）".tl,
      'ocr_zh_v5' => "中文识别（简体 + 繁体）".tl,
      'ocr_zh' => "中文 / 拉丁字母识别".tl,
      'ocr_en' => "英语识别".tl,
      'ocr_ko' => "韩语识别".tl,
      _ => id,
    };
  }

  static String _formatSize(int bytes) {
    if (bytes >= 1 << 30) {
      return "${(bytes / (1 << 30)).toStringAsFixed(2)} GB";
    }
    if (bytes >= 1 << 20) {
      return "${(bytes / (1 << 20)).toStringAsFixed(1)} MB";
    }
    return "${(bytes / (1 << 10)).toStringAsFixed(0)} KB";
  }

  @override
  Widget build(BuildContext context) {
    var requiredIds = TranslationModels.requiredFor(
      widget.sourceLang ?? TranslationConfig.global.sourceLang,
    ).map((c) => c.id).toSet();
    return Scaffold(
      body: SmoothCustomScrollView(
        slivers: [
          SliverAppbar(title: Text("翻译模型".tl)),
          SelectSetting(
            leading: const Icon(Icons.cloud_download_outlined),
            title: "模型下载源".tl,
            values: const ["HuggingFace", "hf-mirror.com"],
            initialValue:
                TranslationModelStore.hfEndpoint == 'https://hf-mirror.com'
                ? 1
                : 0,
            onChanged: (index) {
              appdata.translationSettings['imageTranslationHfEndpoint'] = index == 1
                  ? 'https://hf-mirror.com'
                  : 'https://huggingface.co';
              appdata.saveData();
              setState(() {});
            },
          ).toSliver(),
          ListTile(
            title: Text("模型占用空间".tl),
            subtitle: Text(
              _formatSize(TranslationModelStore.instance.installedSizeBytes),
            ),
          ).toSliver(),
          _buildSectionHeader(context, "文本检测".tl).toSliver(),
          for (var component in TranslationModels.all)
            if (component.id == 'text_detector')
              _buildComponent(context, component, requiredIds).toSliver(),
          _buildSectionHeader(context, "文本识别".tl).toSliver(),
          for (var component in TranslationModels.all)
            if (component.id != 'text_detector')
              _buildComponent(context, component, requiredIds).toSliver(),
          const SliverPadding(padding: EdgeInsets.only(bottom: 16)),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: context.colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildComponent(
    BuildContext context,
    ModelComponent component,
    Set<String> requiredIds,
  ) {
    var store = TranslationModelStore.instance;
    var state = store.stateOf(component);
    var installed = component.isInstalled;
    Widget trailing;
    if (state.downloading) {
      trailing = Row(
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
          const SizedBox(width: 8),
          Text("${(state.progress * 100).toStringAsFixed(0)}%"),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => store.cancelDownload(component),
          ),
        ],
      );
    } else if (installed) {
      trailing = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, color: context.colorScheme.primary),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              showConfirmDialog(
                context: context,
                title: "删除".tl,
                content: "删除已下载的模型文件？".tl,
                btnColor: context.colorScheme.error,
                onConfirm: () {
                  store.delete(component);
                },
              );
            },
          ),
        ],
      );
    } else {
      trailing = Button.filled(
        onPressed: () => store.download(component),
        child: Text("下载".tl),
      ).fixHeight(32);
    }
    String subtitle = _formatSize(component.approxSizeBytes);
    if (requiredIds.contains(component.id) && !installed) {
      subtitle += " · ${"当前设置需要".tl}";
    }
    if (state.error != null) {
      subtitle += "\n${"下载失败".tl}: ${state.error}";
    }
    return ListTile(
      title: Text(_componentName(component.id)),
      subtitle: Text(subtitle),
      isThreeLine: state.error != null,
      trailing: trailing,
    );
  }
}
