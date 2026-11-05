part of 'settings_page.dart';

class _TranslationScriptEditor extends StatefulWidget {
  const _TranslationScriptEditor({required this.provider});
  final LlmProvider provider;

  @override
  State<_TranslationScriptEditor> createState() =>
      _TranslationScriptEditorState();
}

class _TranslationScriptEditorState extends State<_TranslationScriptEditor> {
  late String _script;
  int _revision = 0;
  bool _testing = false;
  bool _failed = false;
  String? _result;

  @override
  void initState() {
    super.initState();
    _script = widget.provider.script.isEmpty
        ? ScriptTranslator.template
        : widget.provider.script;
  }

  void _reset() {
    showConfirmDialog(
      context: context,
      title: "Restore example".tl,
      content: "Replace the current script with the example?".tl,
      onConfirm: () => setState(() {
        _script = ScriptTranslator.template;
        _revision++;
        _result = null;
      }),
    );
  }

  Future<void> _test() async {
    final testedScript = _script;
    setState(() {
      _testing = true;
      _failed = false;
      _result = null;
    });
    try {
      final result = await ScriptTranslator.translate(
        widget.provider.copyWith(script: testedScript),
        ['Hello'],
        'en',
        'zh',
        timeout: const Duration(seconds: 30),
      );
      if (mounted && _script == testedScript) {
        setState(() => _result = result.texts.single);
      }
    } catch (e) {
      if (mounted && _script == testedScript) {
        setState(() {
          _failed = true;
          _result = e.toString();
        });
      }
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Widget _editor() {
    final colors = context.colorScheme;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Container(
            color: colors.surfaceContainerLow,
            padding: const EdgeInsets.only(left: 16, right: 4),
            child: Row(
              children: [
                Icon(Icons.code_rounded, size: 18, color: colors.primary),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'JavaScript',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  tooltip: "Restore example".tl,
                  onPressed: _testing ? null : _reset,
                  icon: const Icon(Icons.restore, size: 20),
                ),
              ],
            ),
          ),
          Expanded(
            child: TextFormField(
              key: ValueKey(_revision),
              initialValue: _script,
              expands: true,
              maxLines: null,
              minLines: null,
              keyboardType: TextInputType.multiline,
              textAlignVertical: TextAlignVertical.top,
              style: ts.s14.copyWith(fontFamily: 'monospace'),
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(12),
              ),
              onChanged: (value) => setState(() {
                _script = value;
                _result = null;
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _testPanel({required bool compact}) {
    final colors = context.colorScheme;
    final stateColor = _failed ? colors.error : colors.primary;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.science_outlined, size: 20, color: colors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Test run".tl,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              if (compact)
                FilledButton.tonal(
                  onPressed: _testing ? null : _test,
                  child: Text((_testing ? "Testing" : "Test script").tl),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            "English → Chinese · Hello".tl,
            style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
          ),
          if (!compact) ...[
            const SizedBox(height: 8),
            Text(
              "Runs the current script with your connection settings. A real API request may use your quota."
                  .tl,
              style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _testing ? null : _test,
              icon: const Icon(Icons.play_arrow_rounded, size: 20),
              label: Text((_testing ? "Testing" : "Test script").tl),
            ),
          ],
          if (_testing) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
          ],
          if (_result != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  _failed ? Icons.error_outline : Icons.check_circle_outline,
                  size: 18,
                  color: stateColor,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    (_failed ? "Test failed" : "Test passed").tl,
                    style: TextStyle(
                      color: stateColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SelectableText(_result!, style: const TextStyle(fontSize: 13)),
          ] else if (!_testing && !compact) ...[
            const SizedBox(height: 20),
            Text(
              "The translated text or an error will appear here.".tl,
              style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
            ),
          ],
          if (!compact) ...[
            const Divider(height: 32),
            Text(
              "Save the provider afterwards to apply this script.".tl,
              style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
            ),
            TextButton.icon(
              onPressed: () => _showTranslationUsageGuide(
                context,
                topic: 'script',
              ),
              icon: const Icon(Icons.menu_book_outlined, size: 18),
              label: Text("Usage guide".tl),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: Appbar(
        title: Text("Custom translation script".tl),
        actions: [
          IconButton(
            tooltip: "Usage guide".tl,
            onPressed: () =>
                _showTranslationUsageGuide(context, topic: 'script'),
            icon: const Icon(Icons.help_outline),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
              onPressed: () => Navigator.pop(context, _script),
              child: Text("Save".tl),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 900;
            final roomy = constraints.maxHeight >= 440;
            return Padding(
              padding: EdgeInsets.fromLTRB(
                wide ? 24 : 12,
                8,
                wide ? 24 : 12,
                12,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (roomy) ...[
                    Text(
                      "Connect your translation service".tl,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Customize the request and map the response. See the guide for parameters and examples."
                          .tl,
                      style: TextStyle(
                        fontSize: 13,
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Expanded(
                    child: wide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: _editor()),
                              const SizedBox(width: 16),
                              SizedBox(
                                width: 300,
                                child: SingleChildScrollView(
                                  child: _testPanel(compact: false),
                                ),
                              ),
                            ],
                          )
                        : Column(
                            children: [
                              Expanded(child: _editor()),
                              const SizedBox(height: 12),
                              ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxHeight: (constraints.maxHeight * .32)
                                      .clamp(60.0, 200.0),
                                ),
                                child: SingleChildScrollView(
                                  child: _testPanel(compact: true),
                                ),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
