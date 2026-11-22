import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pica_comic/components/components.dart';
import 'package:pica_comic/foundation/appdata.dart';
import 'package:pica_comic/foundation/log.dart';
import 'package:pica_comic/foundation/widget_utils.dart';
import 'package:pica_comic/utils/io.dart';
import 'package:pica_comic/utils/translations.dart';

/// Runtime logs: this run's list, followed live, or a fixed snapshot such as
/// the previous run's file.
class LogsPage extends StatefulWidget {
  const LogsPage({super.key})
      : entries = null,
        title = null;

  const LogsPage._snapshot({
    required List<LogItem> this.entries,
    required String this.title,
  });

  /// Fixed entries, oldest first. Null follows [Log.logs].
  final List<LogItem>? entries;

  final String? title;

  @override
  State<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends State<LogsPage> {
  final _scroll = ScrollController();
  final _search = TextEditingController();
  final _expanded = <LogItem>{};
  List<LogItem> _items = const [];
  List<LogItem> _visible = const [];
  Map<LogLevel?, int> _counts = const {};
  int _revision = 0;
  int _pending = 0;
  String _query = '';
  LogLevel? _level;
  String? _tag;
  Timer? _refresh;

  bool get _live => widget.entries == null;

  bool get _filtered =>
      _query.trim().isNotEmpty || _level != null || _tag != null;

  bool get _atTop => !_scroll.hasClients || _scroll.offset <= 24;

  String get _title => widget.title ?? '应用日志';

  @override
  void initState() {
    super.initState();
    _snapshot();
    if (_live) Log.changes.addListener(_onLogsChanged);
  }

  @override
  void dispose() {
    Log.changes.removeListener(_onLogsChanged);
    _refresh?.cancel();
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  void _snapshot() {
    _items = widget.entries ?? List.of(Log.logs);
    _revision = Log.changes.value;
    _pending = 0;
    _recompute();
  }

  bool _matches(LogItem item, String query, {bool anyLevel = false}) {
    if (!anyLevel && _level != null && item.level != _level) return false;
    if (_tag != null && item.title != _tag) return false;
    return query.isEmpty ||
        item.title.toLowerCase().contains(query) ||
        item.content.toLowerCase().contains(query);
  }

  void _recompute() {
    final query = _query.trim().toLowerCase();
    final visible = <LogItem>[];
    final counts = <LogLevel?, int>{null: 0};
    for (final item in _items.reversed) {
      if (!_matches(item, query, anyLevel: true)) continue;
      counts[null] = counts[null]! + 1;
      counts[item.level] = (counts[item.level] ?? 0) + 1;
      if (_level == null || item.level == _level) visible.add(item);
    }
    _visible = visible;
    _counts = counts;
  }

  // Lines arrive in bursts, so coalesce them. While the reader is down in
  // older entries the list stays put and a pill counts what is waiting.
  void _onLogsChanged() {
    _refresh ??= Timer(const Duration(milliseconds: 300), () {
      _refresh = null;
      if (!mounted) return;
      setState(() {
        if (_atTop) {
          _snapshot();
        } else {
          _pending = _countPending();
        }
      });
    });
  }

  int _countPending() {
    final logs = Log.logs;
    final from = _items.isEmpty ? 0 : logs.lastIndexOf(_items.last) + 1;
    final query = _query.trim().toLowerCase();
    return logs.skip(from).where((item) => _matches(item, query)).length;
  }

  bool _onScrollEnd(ScrollEndNotification notification) {
    if (_live && _atTop && Log.changes.value != _revision) {
      setState(_snapshot);
    }
    return false;
  }

  void _showLatest() {
    setState(_snapshot);
    if (_scroll.hasClients) {
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _updateFilter(VoidCallback change) {
    setState(() {
      change();
      _snapshot();
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _toggleTag(String tag) =>
      _updateFilter(() => _tag = _tag == tag ? null : tag);

  void _copy(String text) {
    Clipboard.setData(ClipboardData(text: text));
    context.showMessage(message: '已复制'.tl);
  }

  void _copyShown() {
    if (_visible.isEmpty) {
      context.showMessage(message: '暂无日志'.tl);
      return;
    }
    _copy(_visible.reversed.map((item) => item.toString()).join().trimRight());
  }

  // Everything, not just the filtered view: a report should be complete.
  Uint8List _exportBytes() => utf8.encode(
        Log.exportText(
          _live ? Log.logs : _items,
          title: _live ? '日志' : '上次运行的日志',
        ),
      );

  void _export() {
    Log.flush();
    saveFile(data: _exportBytes(), filename: Log.exportFileName());
  }

  void _setVerboseNetwork(bool enable) {
    appdata.settings[112] = enable ? '1' : '0';
    Log.syncVerboseNetwork(enable);
    appdata.updateSettings();
    setState(() {});
    context.showMessage(
      message: enable ? "已开始记录每个请求。这会增加耗电，用完请关闭。".tl : "现在只记录失败的请求。".tl,
    );
  }

  void _confirmClear() {
    showConfirmDialog(
      context: context,
      title: '清空日志'.tl,
      content: '仅清除此页面中的日志列表，日志文件会保留。'.tl,
      confirmText: '清空',
      btnColor: context.colorScheme.error,
      onConfirm: () {
        Log.clear();
        if (!mounted) return;
        setState(() {
          _expanded.clear();
          _snapshot();
        });
      },
    );
  }

  Future<void> _openPreviousRun() async {
    List<LogItem> items;
    try {
      items = await Log.loadPreviousSession();
    } catch (e, s) {
      Log.error('日志', e, s);
      if (mounted) context.showMessage(message: '读取日志失败'.tl);
      return;
    }
    if (!mounted) return;
    if (items.isEmpty) {
      context.showMessage(message: '没有上次运行的日志'.tl);
      return;
    }
    context.to(
      () => LogsPage._snapshot(entries: items, title: '上次运行的日志'),
    );
  }

  List<MenuEntry> _menuEntries() => [
        MenuEntry(
          icon: Icons.copy_all_outlined,
          text: '复制当前显示的日志'.tl,
          onClick: _copyShown,
        ),
        if (_live) ...[
          MenuEntry(
            icon: Icons.history,
            text: '上次运行的日志'.tl,
            onClick: _openPreviousRun,
          ),
          MenuEntry(
            icon: Icons.bug_report_outlined,
            text: '导出诊断报告'.tl,
            onClick: _export,
          ),
          MenuEntry(
            icon: Icons.network_check,
            text: Log.verboseNetwork ? '停止记录所有请求'.tl : '记录所有网络请求'.tl,
            onClick: () => _setVerboseNetwork(!Log.verboseNetwork),
          ),
          if (!Log.ignoreLimitation)
            MenuEntry(
              icon: Icons.unfold_more,
              text: '禁用长度限制'.tl,
              onClick: () {
                Log.ignoreLimitation = true;
                context.showMessage(message: '仅对本次运行有效'.tl);
              },
            ),
          MenuEntry(
            icon: Icons.delete_outline,
            text: '清空日志'.tl,
            color: context.colorScheme.error,
            onClick: _confirmClear,
          ),
        ],
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: Appbar(
        title: Text(_title.tl),
        actions: [
          IconButton(
            tooltip: '导出'.tl,
            icon: const Icon(Icons.save_alt_outlined),
            onPressed: _export,
          ),
          MenuButton(entries: _menuEntries()),
        ],
      ),
      body: Column(
        children: [
          if (_live && Log.verboseNetwork) _buildVerboseBanner(),
          _buildFilters(),
          Expanded(child: _buildList()),
        ],
      ),
    );
  }

  Widget _buildVerboseBanner() {
    final colors = context.colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      decoration: BoxDecoration(
        color: colors.tertiaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.network_check,
            size: 18,
            color: colors.onTertiaryContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '正在记录所有网络请求，这会增加耗电。'.tl,
              style: TextStyle(
                fontSize: 12,
                color: colors.onTertiaryContainer,
              ),
            ),
          ),
          TextButton(
            onPressed: () => _setVerboseNetwork(false),
            child: Text('关闭'.tl),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _LogSearchField(
            controller: _search,
            hintText: '搜索日志'.tl,
            height: 44,
            onChanged: (value) => _updateFilter(() => _query = value),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // First, so an active tag filter is never scrolled out of view.
                if (_tag case final tag?)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: InputChip(
                      avatar: const Icon(Icons.sell_outlined, size: 16),
                      label: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 160),
                        child: Text(tag, overflow: TextOverflow.ellipsis),
                      ),
                      onDeleted: () => _toggleTag(tag),
                    ),
                  ),
                for (final level in const [
                  null,
                  LogLevel.error,
                  LogLevel.warning,
                  LogLevel.info,
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _buildLevelChip(level),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelChip(LogLevel? level) {
    final label = level == null ? '全部'.tl : _logLevelLabel(level);
    return ChoiceChip(
      key: ValueKey('log-level-${level?.name ?? 'all'}'),
      showCheckmark: false,
      avatar: level == null
          ? null
          : Icon(
              _logLevelIcon(level),
              size: 16,
              color: _logLevelColor(context, level),
            ),
      label: Text('$label ${_counts[level] ?? 0}'),
      selected: _level == level,
      onSelected: (_) => _updateFilter(() => _level = level),
    );
  }

  Widget _buildList() {
    final colors = context.colorScheme;
    if (_visible.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _filtered ? Icons.search_off : Icons.receipt_long_outlined,
              size: 44,
              color: colors.outline,
            ),
            const SizedBox(height: 12),
            Text(
              (_filtered ? '没有匹配的日志' : '暂无日志').tl,
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
          ],
        ),
      );
    }
    final query = _query.trim();
    return Stack(
      children: [
        NotificationListener<ScrollEndNotification>(
          onNotification: _onScrollEnd,
          child: SmoothCustomScrollView(
            controller: _scroll,
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  0,
                  16,
                  16 + MediaQuery.paddingOf(context).bottom,
                ),
                sliver: SliverList.builder(
                  itemCount: _visible.length,
                  itemBuilder: (context, index) {
                    final item = _visible[index];
                    return _LogEntryCard(
                      item: item,
                      query: query,
                      expanded: _expanded.contains(item),
                      tagSelected: _tag == item.title,
                      onToggle: () => setState(() {
                        if (!_expanded.remove(item)) _expanded.add(item);
                      }),
                      onTagTap: () => _toggleTag(item.title),
                      onCopy: () => _copy(item.toString().trimRight()),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        if (_pending > 0)
          Positioned(
            top: 8,
            left: 0,
            right: 0,
            child: Center(
              child: Material(
                color: colors.primary,
                shape: const StadiumBorder(),
                elevation: 2,
                child: InkWell(
                  customBorder: const StadiumBorder(),
                  onTap: _showLatest,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 7,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.arrow_upward,
                          size: 16,
                          color: colors.onPrimary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '@n 条新日志'.tlParams({'n': _pending.toString()}),
                          style: TextStyle(
                            fontSize: 13,
                            color: colors.onPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

const _collapsedLogLines = 4;

class _LogEntryCard extends StatelessWidget {
  const _LogEntryCard({
    required this.item,
    required this.query,
    required this.expanded,
    required this.tagSelected,
    required this.onToggle,
    required this.onTagTap,
    required this.onCopy,
  });

  final LogItem item;
  final String query;
  final bool expanded;
  final bool tagSelected;
  final VoidCallback onToggle;
  final VoidCallback onTagTap;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final accent = _logLevelColor(context, item.level);
    final style = DefaultTextStyle.of(context).style.merge(
          TextStyle(fontSize: 13, height: 1.4, color: colors.onSurface),
        );
    final body = _highlightLogText(
      item.content,
      query,
      style,
      colors.primary.withValues(alpha: 0.28),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: item.level == LogLevel.error
            ? colors.errorContainer.withValues(alpha: 0.28)
            : colors.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: item.level == LogLevel.info
                ? colors.outlineVariant.withValues(alpha: 0.7)
                : accent.withValues(alpha: 0.55),
            width: 0.8,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Body width: card padding 12 + 4, body inset 8.
            final painter = TextPainter(
              text: body,
              maxLines: _collapsedLogLines,
              textDirection: Directionality.of(context),
              textScaler: MediaQuery.textScalerOf(context),
            )..layout(
                maxWidth: (constraints.maxWidth - 24).clamp(0, double.infinity),
              );
            final long = painter.didExceedMaxLines;
            painter.dispose();
            return InkWell(
              onTap: long ? onToggle : null,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 2, 4, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeader(context, accent, long),
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: expanded || !long
                          ? SelectableText.rich(body)
                          : Text.rich(
                              body,
                              maxLines: _collapsedLogLines,
                              overflow: TextOverflow.ellipsis,
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Color accent, bool long) {
    final colors = context.colorScheme;
    final tagRadius = BorderRadius.circular(6);
    return Row(
      children: [
        Icon(_logLevelIcon(item.level), size: 16, color: accent),
        const SizedBox(width: 8),
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: Tooltip(
                  message: (tagSelected ? '显示所有标签' : '仅显示此标签').tl,
                  child: Material(
                    color: tagSelected
                        ? colors.secondaryContainer
                        : colors.surfaceContainerHighest,
                    borderRadius: tagRadius,
                    child: InkWell(
                      borderRadius: tagRadius,
                      onTap: onTagTap,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        child: Text(
                          item.title.isEmpty ? '-' : item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: tagSelected
                                ? colors.onSecondaryContainer
                                : colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _formatLogTime(item.time),
                style: TextStyle(
                  fontSize: 12,
                  color: colors.onSurfaceVariant,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
        if (long)
          IconButton(
            tooltip: (expanded ? '折叠' : '展开').tl,
            visualDensity: VisualDensity.compact,
            iconSize: 18,
            icon: Icon(expanded ? Icons.expand_less : Icons.expand_more),
            onPressed: onToggle,
          ),
        IconButton(
          tooltip: '复制到'.tl,
          visualDensity: VisualDensity.compact,
          iconSize: 16,
          icon: const Icon(Icons.copy_rounded),
          onPressed: onCopy,
        ),
      ],
    );
  }
}

String _logLevelLabel(LogLevel level) => switch (level) {
      LogLevel.error => '错误'.tl,
      LogLevel.warning => '警告'.tl,
      LogLevel.info => '信息'.tl,
    };

IconData _logLevelIcon(LogLevel level) => switch (level) {
      LogLevel.error => Icons.error_outline,
      LogLevel.warning => Icons.warning_amber_rounded,
      LogLevel.info => Icons.info_outline,
    };

Color _logLevelColor(BuildContext context, LogLevel level) => switch (level) {
      LogLevel.error => context.colorScheme.error,
      LogLevel.warning => context.brightness == Brightness.dark
          ? Colors.amber.shade300
          : Colors.orange.shade800,
      LogLevel.info => context.colorScheme.outline,
    };

/// Clock time for today's entries, with the date otherwise.
String _formatLogTime(DateTime time) {
  String two(int value) => value.toString().padLeft(2, '0');
  final now = DateTime.now();
  final clock = '${two(time.hour)}:${two(time.minute)}:${two(time.second)}';
  if (time.year == now.year && time.month == now.month && time.day == now.day) {
    return '$clock.${time.millisecond.toString().padLeft(3, '0')}';
  }
  return '${two(time.month)}-${two(time.day)} $clock';
}

TextSpan _highlightLogText(
  String text,
  String query,
  TextStyle style,
  Color highlight,
) {
  final lower = text.toLowerCase();
  final needle = query.toLowerCase();
  // Lowercasing changes the length of a few scripts; offsets would drift.
  if (needle.isEmpty || lower.length != text.length) {
    return TextSpan(text: text, style: style);
  }
  final spans = <TextSpan>[];
  var start = 0;
  for (var i = lower.indexOf(needle);
      i >= 0;
      i = lower.indexOf(needle, start)) {
    if (i > start) spans.add(TextSpan(text: text.substring(start, i)));
    spans.add(
      TextSpan(
        text: text.substring(i, i + needle.length),
        style: TextStyle(backgroundColor: highlight),
      ),
    );
    start = i + needle.length;
  }
  if (start < text.length) spans.add(TextSpan(text: text.substring(start)));
  return TextSpan(style: style, children: spans);
}

class _LogSearchField extends StatelessWidget {
  const _LogSearchField({
    required this.controller,
    required this.hintText,
    required this.height,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String hintText;
  final double height;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(height / 2);
    return Material(
      color: context.colorScheme.surfaceContainerHigh,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: height,
        child: Row(
          children: [
            const SizedBox(width: 16),
            const Icon(Icons.search),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: hintText,
                  border: InputBorder.none,
                  isCollapsed: true,
                ),
                onChanged: onChanged,
              ),
            ),
            ListenableBuilder(
              listenable: controller,
              builder: (context, child) {
                if (controller.text.isEmpty) {
                  return const SizedBox(width: 16);
                }
                return IconButton(
                  iconSize: 20,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.clear),
                  tooltip: '清空'.tl,
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                );
              },
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}
