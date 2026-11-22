/// Parsing for the user guide shipped as markdown under `doc/`.
///
/// The guide is authored once and read in two places: the repository page and
/// [GuidePage]. Only the small subset of markdown the guide actually uses is
/// understood here — pulling in a full markdown package for four block types is
/// not worth the dependency. Anything unrecognized degrades to a paragraph
/// rather than being dropped, so an unexpected construct still reaches the
/// reader as plain text.
library;

/// A section of the guide that a feature screen can link into.
///
/// [id] must match an `<!--anchor:id-->` marker in every guide file; a test
/// enforces that the set of markers and this enum agree exactly, so a renamed
/// heading or a dropped marker fails the build rather than silently becoming a
/// jump that goes nowhere.
enum GuideAnchor {
  translation('ai-translation'),
  translationSetup('translation-setup'),
  translationTarget('translation-target'),
  translationSource('translation-source'),
  translationScript('translation-script'),
  translationEnable('translation-enable'),
  translationReading('translation-reading'),
  translationAdjust('translation-adjust'),
  translationPerformance('translation-performance'),
  translationLimits('translation-limits'),
  cacheDirectory('cache-directory'),
  collections('collections'),
  collectionCreate('collection-create'),
  collectionLayout('collection-layout'),
  collectionEdit('collection-edit'),
  collectionLimits('collection-limits'),
  autoPageTurning('auto-page-turning'),
  eink('eink'),
  gestures('gestures');

  const GuideAnchor(this.id);

  final String id;
}

enum GuideBlockType {
  heading1,
  heading2,
  heading3,
  paragraph,
  bullet,
  numbered,

  /// A `key | value` row. The guides use tables only as two-column term/effect
  /// lists, so they render as definition rows rather than a real grid.
  tableRow,

  /// A fenced block, kept verbatim: leading spaces carry meaning (directory
  /// trees) and inline markers inside it are content, not markup.
  codeBlock,
}

enum GuideSpanStyle { plain, bold, code, link }

class GuideSpan {
  const GuideSpan(this.text, this.style);

  final String text;
  final GuideSpanStyle style;

  /// A contents entry links to the heading whose text equals [text].
  ///
  /// The link target in the markdown is GitHub's own generated heading slug,
  /// which differs per language and is not what this parser tracks. Matching on
  /// the visible text instead keeps one authored contents list working both on
  /// the repository page and here.
  bool get isLink => style == GuideSpanStyle.link;
}

class GuideBlock {
  const GuideBlock({
    required this.type,
    required this.spans,
    this.anchor,
    this.indent = 0,
    this.number = 0,
    this.trailingSpans = const [],
  });

  final GuideBlockType type;

  /// The block's content; for [GuideBlockType.tableRow] this is the first
  /// column.
  final List<GuideSpan> spans;

  /// Anchor declared by the preceding `<!--anchor:id-->` marker, used as a
  /// scroll target.
  final String? anchor;

  /// Nesting depth of a list item, in list levels.
  final int indent;

  /// Display number of a [GuideBlockType.numbered] item.
  final int number;

  /// Second column of a [GuideBlockType.tableRow]; empty for every other type.
  final List<GuideSpan> trailingSpans;

  /// The block's text with styling dropped, for tests and search.
  String get text => spans.map((s) => s.text).join();

  /// The second column's text with styling dropped.
  String get trailingText => trailingSpans.map((s) => s.text).join();
}

/// Anchors are declared as HTML comments rather than the `{#id}` heading
/// suffix: GitHub does not support that syntax and would render the braces as
/// literal text, while a comment stays invisible there and still gives this
/// parser a stable target that survives rewording a heading.
final _anchorPattern = RegExp(r'^<!--\s*anchor:\s*([a-z0-9-]+)\s*-->$');
final _numberedPattern = RegExp(r'^(\d+)\.\s+');
final _inlinePattern = RegExp(r'\*\*(.+?)\*\*|`(.+?)`|\[([^\]]+)\]\(#[^)]*\)');
final _tableDividerPattern = RegExp(r'^\|[\s|:-]+\|$');

/// Parses the guide's markdown subset: ATX headings with an optional
/// `{#anchor}`, `-` bullets (nested by two-space indent), `1.` numbered items,
/// fenced code blocks and paragraphs, with `**bold**` and `` `code` `` inline.
List<GuideBlock> parseGuideMarkdown(String markdown) {
  var blocks = <GuideBlock>[];
  // Set by an anchor comment and consumed by the next block, so the marker sits
  // on its own line above the heading it names.
  String? pendingAnchor;

  void add(GuideBlock block) {
    blocks.add(block);
    pendingAnchor = null;
  }

  // Lines collected inside an open fence; null while outside one.
  List<String>? fenced;

  // Emits the collected fence body, dropping blank lines at either end so the
  // rendered block has no empty first/last row. An entirely blank fence yields
  // no block at all.
  void flushFence() {
    var lines = fenced!;
    fenced = null;
    while (lines.isNotEmpty && lines.first.trim().isEmpty) {
      lines.removeAt(0);
    }
    while (lines.isNotEmpty && lines.last.trim().isEmpty) {
      lines.removeLast();
    }
    if (lines.isEmpty) return;
    add(
      GuideBlock(
        type: GuideBlockType.codeBlock,
        spans: [GuideSpan(lines.join('\n'), GuideSpanStyle.plain)],
      ),
    );
  }

  for (var raw in markdown.replaceAll('\r\n', '\n').split('\n')) {
    // Fences are handled before indent stripping below: inside one, leading
    // spaces are content (directory trees) rather than list nesting.
    if (raw.trimLeft().startsWith('```')) {
      if (fenced == null) {
        fenced = [];
      } else {
        flushFence();
      }
      continue;
    }
    // A local copy promotes to non-null; `fenced` itself cannot, because
    // [flushFence] captures and reassigns it.
    var open = fenced;
    if (open != null) {
      open.add(raw);
      continue;
    }

    var indent = 0;
    var line = raw;
    // Two spaces per nesting level; a tab counts as one level.
    while (line.startsWith('  ') || line.startsWith('\t')) {
      indent++;
      line = line.startsWith('\t') ? line.substring(1) : line.substring(2);
    }
    line = line.trim();
    if (line.isEmpty) continue;

    var anchorMatch = _anchorPattern.firstMatch(line);
    if (anchorMatch != null) {
      pendingAnchor = anchorMatch.group(1);
      continue;
    }
    // Any other HTML comment is markup for the repository page only.
    if (line.startsWith('<!--')) continue;

    if (line.startsWith('#')) {
      var level = 0;
      while (level < line.length && line[level] == '#') {
        level++;
      }
      add(
        GuideBlock(
          type: switch (level) {
            1 => GuideBlockType.heading1,
            2 => GuideBlockType.heading2,
            _ => GuideBlockType.heading3,
          },
          spans: parseGuideInline(line.substring(level).trim()),
          anchor: pendingAnchor,
        ),
      );
      continue;
    }

    // Tables: the header separator carries no content, and the header row is
    // dropped too — a two-column term/effect list reads fine without it.
    if (line.startsWith('|')) {
      if (_tableDividerPattern.hasMatch(line)) {
        // Retroactively drop the header row this separator belongs to.
        if (blocks.isNotEmpty && blocks.last.type == GuideBlockType.tableRow) {
          blocks.removeLast();
        }
        continue;
      }
      var cells = line
          .split('|')
          .map((c) => c.trim())
          .toList();
      // A leading and trailing '|' produce empty outer entries.
      if (cells.isNotEmpty && cells.first.isEmpty) cells.removeAt(0);
      if (cells.isNotEmpty && cells.last.isEmpty) cells.removeLast();
      if (cells.isNotEmpty) {
        add(
          GuideBlock(
            type: GuideBlockType.tableRow,
            spans: parseGuideInline(cells.first),
            trailingSpans: parseGuideInline(cells.skip(1).join(' · ')),
          ),
        );
        continue;
      }
    }

    if (line.startsWith('- ')) {
      add(
        GuideBlock(
          type: GuideBlockType.bullet,
          spans: parseGuideInline(line.substring(2).trim()),
          indent: indent,
        ),
      );
      continue;
    }

    var numbered = _numberedPattern.firstMatch(line);
    if (numbered != null) {
      add(
        GuideBlock(
          type: GuideBlockType.numbered,
          spans: parseGuideInline(line.substring(numbered.end).trim()),
          indent: indent,
          number: int.parse(numbered.group(1)!),
        ),
      );
      continue;
    }

    add(
      GuideBlock(
        type: GuideBlockType.paragraph,
        spans: parseGuideInline(line),
      ),
    );
  }
  // A fence left open at the end of the file still reaches the reader.
  if (fenced != null) flushFence();
  return blocks;
}

List<GuideSpan> parseGuideInline(String text) {
  var spans = <GuideSpan>[];
  var cursor = 0;
  for (var match in _inlinePattern.allMatches(text)) {
    if (match.start > cursor) {
      spans.add(
        GuideSpan(text.substring(cursor, match.start), GuideSpanStyle.plain),
      );
    }
    var bold = match.group(1);
    var code = match.group(2);
    if (bold != null) {
      spans.add(GuideSpan(bold, GuideSpanStyle.bold));
    } else if (code != null) {
      spans.add(GuideSpan(code, GuideSpanStyle.code));
    } else {
      spans.add(GuideSpan(match.group(3)!, GuideSpanStyle.link));
    }
    cursor = match.end;
  }
  if (cursor < text.length) {
    spans.add(GuideSpan(text.substring(cursor), GuideSpanStyle.plain));
  }
  return spans;
}
