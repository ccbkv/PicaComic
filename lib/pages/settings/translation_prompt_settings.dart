part of 'settings_page.dart';

/// Editor for the translation system prompt. Users shorten it to cut the tokens
/// every request spends, or reword it to change how the model translates; Reset
/// puts the built-in text back.
class TranslationPromptPage extends StatefulWidget {
  const TranslationPromptPage({super.key});

  @override
  State<TranslationPromptPage> createState() => _TranslationPromptPageState();
}

class _TranslationPromptPageState extends State<TranslationPromptPage> {
  late final TextEditingController _controller;

  /// What was on disk when the page opened, to tell an edit from a no-op.
  late final String _initial;

  @override
  void initState() {
    super.initState();
    _initial = LlmPromptStore.template;
    _controller = TextEditingController(text: _initial);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _changed => _controller.text.trim() != _initial.trim();

  bool get _isBlank => _controller.text.trim().isEmpty;

  void _save() {
    LlmPromptStore.save(_controller.text);
    if (!mounted) return;
    context.showMessage(message: "Translation prompt saved".tl);
    context.pop();
  }

  /// Puts the built-in text in the field without persisting: like any other
  /// edit here, it only takes effect on Save, so Cancel still backs out.
  void _reset() {
    showConfirmDialog(
      context: context,
      title: "重置".tl,
      content: "恢复成内置的翻译提示词？".tl,
      onConfirm: () =>
          setState(() => _controller.text = LlmPromptStore.builtIn),
    );
  }

  /// Reference for writing a replacement prompt: the one placeholder, the shape
  /// the page's text arrives in, and the reply shape the parser needs. The last
  /// is the part worth spelling out — a shortened prompt that drops the output
  /// contract still gets billed, then fails to parse.
  void _showFormatHelp() {
    // No intrinsic width of its own: ContentDialog measures content through
    // IntrinsicWidth, which an infinite-width child cannot answer.
    Widget code(String text) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: context.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(text, style: ts.s12.copyWith(fontFamily: 'monospace')),
      );
    }

    Widget section(String title, List<Widget> children) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: ts.bold.s14),
          const SizedBox(height: 4),
          ...children,
          const SizedBox(height: 16),
        ],
      );
    }

    Widget body(String text) => Text(text, style: ts.s14);

    // Sample values are localized; only the field names are literal.
    var src = "原文".tl;
    var dst = "译文".tl;

    showDialog(
      context: context,
      builder: (context) => ContentDialog(
        title: "提示词格式".tl,
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 520),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                section("占位符".tl, [
                  body(
                    "\$target 会被替换成你选择的目标语言名称。这是唯一的占位符。"
                        .tl,
                  ),
                ]),
                section("发送的内容".tl, [
                  body(
                    "你写的内容作为 system 消息发送。本页识别出的文字另外作为 user 消息发送："
                        .tl,
                  ),
                  code(
                    '{"glossary":{"$src":"$dst"},\n'
                    ' "lines":[{"id":0,"text":"$src"}]}',
                  ),
                  body(
                    "glossary 是该漫画已确定的译名，没有时不会出现。"
                        .tl,
                  ),
                ]),
                section("需要返回的内容".tl, [
                  code(
                    '{"lines":[{"id":0,"text":"$dst"}],\n'
                    ' "names":{"$src":"$dst"}}',
                  ),
                  body(
                    "lines 必须有：每个输入 id 对应一条，且恰好出现一次。没有它的回复无法解析，这一页保持原文，但请求照样计费。"
                        .tl,
                  ),
                  const SizedBox(height: 8),
                  body(
                    "names 可以不要。去掉能同时缩短提示词和回复，但人名在不同页之间就不再一致。"
                        .tl,
                  ),
                ]),
              ],
            ),
          ),
        ),
        actions: [Button.filled(onPressed: context.pop, child: Text("确定".tl))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: Appbar(
        title: Text("翻译提示词".tl),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: "提示词格式".tl,
            onPressed: _showFormatHelp,
          ),
          TextButton(onPressed: _reset, child: Text("重置".tl)),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Text(
              "每次请求都会随译文一起发给 AI 模型。改短可以减少用量，代价是译文质量和人名前后一致性下降。\$target 要保留，运行时会替换成目标语言。"
                  .tl,
              style: ts.s14.copyWith(color: context.colorScheme.outline),
            ),
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: context.colorScheme.outlineVariant),
              ),
              child: TextField(
                controller: _controller,
                expands: true,
                maxLines: null,
                minLines: null,
                keyboardType: TextInputType.multiline,
                textAlignVertical: TextAlignVertical.top,
                style: ts.s14,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: "翻译提示词".tl,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ),
          if (!_isBlank &&
              !LlmPromptStore.hasTargetPlaceholder(_controller.text))
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 18,
                    color: context.colorScheme.error,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      "缺少 \$target，模型不知道要翻译成哪种语言。"
                          .tl,
                      style: ts.s12.copyWith(color: context.colorScheme.error),
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              12 + context.padding.bottom,
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => context.pop(),
                    child: Text("取消".tl),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _changed ? _save : null,
                    child: Text("保存".tl),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
