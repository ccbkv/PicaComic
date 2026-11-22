import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pica_comic/components/components.dart';
import 'package:pica_comic/foundation/app.dart';
import 'package:pica_comic/foundation/guide_document.dart';
import 'package:pica_comic/utils/opencc.dart';
import 'package:pica_comic/utils/translations.dart';

import '../utils/extensions.dart';

export 'package:pica_comic/foundation/guide_document.dart' show GuideAnchor;

/// In-app reader for the user guide.
///
/// The guide ships as a markdown asset (see [guide_document.dart]) so the copy
/// on the repository page and this one can never drift apart.
///
/// [anchor] scrolls to a section on open, so a feature's own screen can link
/// straight into its part of the guide.
class GuidePage extends StatefulWidget {
  const GuidePage({super.key, this.anchor, this.assetPath, this.title});

  final GuideAnchor? anchor;

  /// Markdown asset to read instead of the localized user guide.
  final String? assetPath;

  /// Appbar title; defaults to the guide's own.
  final String? title;

  /// Opens the guide, optionally at one section.
  static void open(BuildContext context, {GuideAnchor? anchor}) {
    context.to(() => GuidePage(anchor: anchor));
  }

  /// Opens another markdown doc shipped under `doc/`. Bundling them keeps the
  /// in-app help readable offline and independent of the repository staying up.
  static void openDocument(
    BuildContext context, {
    required String assetPath,
    required String title,
  }) {
    context.to(() => GuidePage(assetPath: assetPath, title: title));
  }

  @override
  State<GuidePage> createState() => _GuidePageState();
}

class _GuidePageState extends State<GuidePage> {
  List<GuideBlock>? blocks;

  bool failed = false;

  /// Keys of the anchored headings, so [_jumpToAnchor] can bring one on screen.
  final _anchorKeys = <String, GlobalKey>{};

  /// Keys of every heading by its text, so a contents entry can scroll to it.
  final _headingKeys = <String, GlobalKey>{};

  /// Keep separate keys when headings share the same text.
  final _headingBlockKeys = <GuideBlock, GlobalKey>{};

  /// One recognizer per contents entry, kept for the page's lifetime: a
  /// recognizer built inline would leak on every rebuild.
  final _linkRecognizers = <String, TapGestureRecognizer>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (var recognizer in _linkRecognizers.values) {
      recognizer.dispose();
    }
    super.dispose();
  }

  /// Chinese locales read the Chinese guide; everything else falls back to
  /// English. An explicit [GuidePage.assetPath] overrides both.
  String _assetPath() {
    var override = widget.assetPath;
    if (override != null) return override;
    return App.locale.languageCode == 'zh'
        ? 'doc/guide.zh.md'
        : 'doc/guide.en.md';
  }

  void _load() async {
    try {
      var text = await rootBundle.loadString(_assetPath());
      var parsed = parseGuideMarkdown(text);
      if (!mounted) return;
      setState(() {
        blocks = parsed;
        for (var block in parsed) {
          var id = block.anchor;
          if (id != null) {
            _anchorKeys[id] = GlobalKey();
          }
          if (_isHeading(block)) {
            // Shared with the anchor key when a heading has both, so one
            // element never carries two GlobalKeys.
            var key = id == null ? GlobalKey() : _anchorKeys[id]!;
            _headingBlockKeys[block] = key;
            _headingKeys[_localize(block.text)] = key;
          }
        }
      });
      _jumpToAnchor();
    } catch (e) {
      if (!mounted) return;
      setState(() => failed = true);
    }
  }

  static bool _isHeading(GuideBlock block) {
    return block.type == GuideBlockType.heading1 ||
        block.type == GuideBlockType.heading2 ||
        block.type == GuideBlockType.heading3;
  }

  void _jumpToAnchor() {
    var id = widget.anchor?.id;
    if (id == null) return;
    // After the first layout the target has a render object to scroll to.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollTo(_anchorKeys[id]);
    });
  }

  void _scrollTo(GlobalKey? key) {
    var target = key?.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 300),
      alignment: 0.05,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: Appbar(title: Text(widget.title ?? "Guide".tl)),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (failed) {
      return Center(child: Text("Failed to load the guide".tl));
    }
    var content = blocks;
    if (content == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return SmoothCustomScrollView(
      slivers: [
        // One eagerly laid-out column rather than a lazy list: a sliver list
        // only builds what is near the viewport, so an anchored heading further
        // down has no render object and [Scrollable.ensureVisible] would find
        // nothing to scroll to. The guide is a few screens of static text, so
        // laying it out at once costs little and makes the jump reliable. It
        // also lets one selection span the whole document.
        SelectionArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [for (var block in content) _buildBlock(block)],
          ),
        ).toSliver(),
        SliverPadding(
          padding: EdgeInsets.only(bottom: context.padding.bottom + 24),
        ),
      ],
    );
  }

  Widget _buildBlock(GuideBlock block) {
    var key = _headingBlockKeys[block];
    return switch (block.type) {
      GuideBlockType.heading1 => _buildHeading(block, key, ts.bold.s24, 20, 8),
      GuideBlockType.heading2 => _buildSectionHeading(block, key),
      GuideBlockType.heading3 => _buildHeading(block, key, ts.bold.s16, 16, 4),
      GuideBlockType.paragraph => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: _buildRichText(block.spans, ts.s14),
      ),
      GuideBlockType.bullet => _buildListItem(block, "•"),
      GuideBlockType.numbered => _buildListItem(block, "${block.number}."),
      GuideBlockType.tableRow => _buildTableRow(block),
      GuideBlockType.codeBlock => _buildCodeBlock(block),
    };
  }

  /// Fenced blocks keep their own whitespace, so they render monospaced and
  /// scroll sideways rather than wrapping — a wrapped directory tree is
  /// unreadable.
  Widget _buildCodeBlock(GuideBlock block) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerHighest.toOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Text(
          block.text,
          style: ts.s12.copyWith(fontFamily: 'monospace', height: 1.45),
        ),
      ),
    );
  }

  /// A table row renders as term over description: the guides use tables only
  /// as two-column lists, and a real grid would not fit a phone's width.
  Widget _buildTableRow(GuideBlock block) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 3, 16, 3),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildRichText(block.spans, ts.bold.s14),
          if (block.trailingSpans.isNotEmpty) ...[
            const SizedBox(height: 2),
            _buildRichText(
              block.trailingSpans,
              ts.s12.withColor(context.colorScheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeading(
    GuideBlock block,
    Key? key,
    TextStyle style,
    double topPadding,
    double bottomPadding,
  ) {
    return Padding(
      key: key,
      padding: EdgeInsets.fromLTRB(16, topPadding, 16, bottomPadding),
      child: _buildRichText(block.spans, style),
    );
  }

  /// Section headings carry a rule so long sections stay easy to tell apart
  /// while scrolling.
  Widget _buildSectionHeading(GuideBlock block, Key? key) {
    return Padding(
      key: key,
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildRichText(
            block.spans,
            ts.bold.s20.withColor(context.colorScheme.primary),
          ),
          const SizedBox(height: 6),
          Divider(
            height: 1,
            thickness: 1,
            color: context.colorScheme.outlineVariant.toOpacity(0.6),
          ),
        ],
      ),
    );
  }

  Widget _buildListItem(GuideBlock block, String marker) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16 + block.indent * 20, 3, 16, 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 22,
            child: Text(
              marker,
              style: ts.s14.withColor(context.colorScheme.outline),
            ),
          ),
          Expanded(child: _buildRichText(block.spans, ts.s14)),
        ],
      ),
    );
  }

  /// Plain [Text.rich], not [SelectableText]: the whole document sits inside one
  /// [SelectionArea], which nested selectable widgets would fight with.
  Widget _buildRichText(List<GuideSpan> spans, TextStyle base) {
    return Text.rich(
      TextSpan(
        children: [
          for (var span in spans)
            if (span.isLink)
              _buildLinkSpan(span, base)
            else
              TextSpan(
                text: _localize(span.text),
                style: switch (span.style) {
                  GuideSpanStyle.bold => base.bold,
                  GuideSpanStyle.code => base.copyWith(
                    fontFamily: 'monospace',
                    backgroundColor: context.colorScheme.surfaceContainerHighest,
                  ),
                  _ => base,
                },
              ),
        ],
      ),
      style: base.copyWith(height: 1.55),
    );
  }

  InlineSpan _buildLinkSpan(GuideSpan span, TextStyle base) {
    var label = _localize(span.text);
    var target = _headingKeys[label];
    // An entry pointing at a heading that no longer exists stays readable as
    // plain text instead of becoming a dead tap.
    if (target == null) {
      return TextSpan(text: label, style: base);
    }
    var recognizer = _linkRecognizers.putIfAbsent(
      label,
      () => TapGestureRecognizer()..onTap = () => _scrollTo(target),
    );
    return TextSpan(
      text: label,
      style: base.copyWith(color: context.colorScheme.primary),
      recognizer: recognizer,
    );
  }

  /// The Chinese guide is written in Simplified Chinese; a Traditional Chinese
  /// reader gets it converted rather than a second copy to keep in step.
  String _localize(String text) {
    if (App.locale.languageCode == 'zh' && App.locale.countryCode == 'TW') {
      return OpenCC.simplifiedToTraditional(text);
    }
    return text;
  }
}
