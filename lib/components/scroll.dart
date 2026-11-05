part of 'components.dart';

class SmoothCustomScrollView extends StatelessWidget {
  const SmoothCustomScrollView(
      {super.key, required this.slivers, this.controller});

  final ScrollController? controller;

  final List<Widget> slivers;

  @override
  Widget build(BuildContext context) {
    return SmoothScrollProvider(
      controller: controller,
      builder: (context, controller, physics) {
        return CustomScrollView(
          controller: controller,
          physics: physics,
          slivers: slivers,
        );
      },
    );
  }
}

class SmoothScrollProvider extends StatefulWidget {
  const SmoothScrollProvider(
      {super.key, this.controller, required this.builder});

  final ScrollController? controller;

  final Widget Function(BuildContext, ScrollController, ScrollPhysics) builder;

  static bool get isMouseScroll => _SmoothScrollProviderState._isMouseScroll;

  @override
  State<SmoothScrollProvider> createState() => _SmoothScrollProviderState();
}

class _SmoothScrollProviderState extends State<SmoothScrollProvider> {
  late final ScrollController _controller;

  double? _futurePosition;

  static bool _isMouseScroll = App.isDesktop;

  @override
  void initState() {
    _controller = widget.controller ?? ScrollController();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    if (App.isMacOS) {
      return widget.builder(
        context,
        _controller,
        const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      );
    }
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) {
        if (_isMouseScroll) {
          setState(() {
            _isMouseScroll = false;
          });
        }
      },
      onPointerSignal: (pointerSignal) {
        if (pointerSignal is PointerScrollEvent) {
          if (pointerSignal.kind == PointerDeviceKind.mouse &&
              !_isMouseScroll) {
            setState(() {
              _isMouseScroll = true;
            });
          }
          if (!_isMouseScroll) return;
          var currentLocation = _controller.position.pixels;
          _futurePosition ??= currentLocation;
          double k = (_futurePosition! - currentLocation).abs() / 1600 + 1;
          _futurePosition = _futurePosition! + pointerSignal.scrollDelta.dy * k;
          _futurePosition = _futurePosition!.clamp(
              _controller.position.minScrollExtent,
              _controller.position.maxScrollExtent);
          _controller.animateTo(_futurePosition!,
              duration: _fastAnimationDuration, curve: Curves.linear);
        }
      },
      child: widget.builder(
        context,
        _controller,
        _isMouseScroll
            ? const NeverScrollableScrollPhysics()
            : const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics()),
      ),
    );
  }
}

class AppScrollBar extends StatefulWidget {
  const AppScrollBar({
    super.key,
    required this.controller,
    required this.child,
    this.topPadding = 0,
  });

  final ScrollController controller;

  final Widget child;

  final double topPadding;

  @override
  State<AppScrollBar> createState() => _AppScrollBarState();
}

class _AppScrollBarState extends State<AppScrollBar> {
  late final ScrollController _scrollController;

  double minExtent = 0;
  double maxExtent = 0;
  double position = 0;

  double viewHeight = 0;

  final _scrollIndicatorSize = App.isDesktop ? 36.0 : 54.0;

  late final VerticalDragGestureRecognizer _dragGestureRecognizer;

  bool _isVisible = false;
  Timer? _hideTimer;
  DateTime _lastActivityAt = DateTime.now();
  static const _hideDuration = Duration(seconds: 2);

  /// Repaint signal for the thumb. The scroll listener fires on every scrolled
  /// frame; poking this rebuilds only the thumb subtree instead of setState on
  /// the whole scrollbar (which re-ran the LayoutBuilder and Stack each frame).
  final _thumbSignal = _RepaintSignal();

  @override
  void initState() {
    super.initState();
    _scrollController = widget.controller;
    _scrollController.addListener(onChanged);
    Future.microtask(onChanged);
    _dragGestureRecognizer = VerticalDragGestureRecognizer()
      ..onUpdate = onUpdate
      ..onStart = (_) {
        _showScrollbar(holdOpen: true);
      }
      ..onEnd = (_) {
        _scheduleHide();
      };
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _scrollController.removeListener(onChanged);
    _dragGestureRecognizer.dispose();
    _thumbSignal.dispose();
    super.dispose();
  }

  /// [holdOpen] cancels the pending auto-hide, for hover/drag interactions
  /// that must keep the thumb visible until they end.
  void _showScrollbar({bool holdOpen = false}) {
    if (!_isVisible && mounted) {
      setState(() {
        _isVisible = true;
      });
    }
    if (holdOpen) {
      _hideTimer?.cancel();
      _hideTimer = null;
    }
  }

  /// Refreshes the auto-hide deadline. A single timer re-checks the deadline
  /// when it fires, instead of being cancelled and re-created on every scroll
  /// tick.
  void _scheduleHide() {
    _lastActivityAt = DateTime.now();
    _hideTimer ??= Timer(_hideDuration, _onHideTimeout);
  }

  void _onHideTimeout() {
    _hideTimer = null;
    if (!mounted) return;
    final idle = DateTime.now().difference(_lastActivityAt);
    if (idle < _hideDuration) {
      _hideTimer = Timer(_hideDuration - idle, _onHideTimeout);
      return;
    }
    if (_isVisible) {
      setState(() {
        _isVisible = false;
      });
    }
  }

  void onUpdate(DragUpdateDetails details) {
    if (maxExtent - minExtent <= 0 ||
        viewHeight == 0 ||
        details.primaryDelta == null) {
      return;
    }
    var offset = details.primaryDelta!;
    var positionOffset =
        offset / (viewHeight - _scrollIndicatorSize) * (maxExtent - minExtent);
    _scrollController.jumpTo(
      (position + positionOffset).clamp(minExtent, maxExtent),
    );
  }

  void onChanged() {
    if (_scrollController.positions.isEmpty) return;
    var position = _scrollController.position;

    if (position.minScrollExtent == minExtent &&
        position.maxScrollExtent == maxExtent &&
        position.pixels == this.position) {
      return;
    }
    minExtent = position.minScrollExtent;
    maxExtent = position.maxScrollExtent;
    this.position = position.pixels;

    _thumbSignal.notify();
    _showScrollbar();
    _scheduleHide();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constrains) {
        var height = constrains.maxHeight - widget.topPadding;
        viewHeight = height;
        return Stack(
          children: [
            Positioned.fill(child: widget.child),
            ListenableBuilder(
              listenable: _thumbSignal,
              builder: (context, _) {
                var scrollHeight = (maxExtent - minExtent);
                var top = scrollHeight == 0
                    ? 0.0
                    : (position - minExtent) /
                          scrollHeight *
                          (height - _scrollIndicatorSize);
                return Positioned(
                  top: top + widget.topPadding,
                  right: 0,
                  child: AnimatedOpacity(
                    opacity: _isVisible ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      onEnter: (_) => _showScrollbar(holdOpen: true),
                      onExit: (_) => _scheduleHide(),
                      child: Listener(
                        behavior: HitTestBehavior.translucent,
                        onPointerDown: (event) {
                          // A faded-out thumb still hit-tests, so without this
                          // it would fight page gestures (reorder handles,
                          // swipe actions) for drags near the right edge.
                          if (!_isVisible) return;
                          _dragGestureRecognizer.addPointer(event);
                        },
                        child: SizedBox(
                          width: _scrollIndicatorSize / 2,
                          height: _scrollIndicatorSize,
                          child: CustomPaint(
                            painter: _ScrollIndicatorPainter(
                              backgroundColor: context.colorScheme.surface,
                              shadowColor: context.colorScheme.shadow,
                            ),
                            child: Column(
                              children: [
                                const Spacer(),
                                Icon(Icons.arrow_drop_up, size: 18),
                                Icon(Icons.arrow_drop_down, size: 18),
                                const Spacer(),
                              ],
                            ).paddingLeft(4),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

/// A [ChangeNotifier] whose only job is exposing [notifyListeners] as a
/// public repaint signal for a scoped [ListenableBuilder].
class _RepaintSignal extends ChangeNotifier {
  void notify() => notifyListeners();
}

class _ScrollIndicatorPainter extends CustomPainter {
  final Color backgroundColor;

  final Color shadowColor;

  const _ScrollIndicatorPainter({
    required this.backgroundColor,
    required this.shadowColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    var path = Path()
      ..moveTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..arcToPoint(Offset(size.width, 0), radius: Radius.circular(size.width));
    canvas.drawShadow(path, shadowColor, 2, true);
    var backgroundPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;
    path = Path()
      ..moveTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..arcToPoint(Offset(size.width, 0), radius: Radius.circular(size.width));
    canvas.drawPath(path, backgroundPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is! _ScrollIndicatorPainter ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.shadowColor != shadowColor;
  }
}

/// A [SelectableText] that never scrolls independently, even when content
/// overflows. It should always be placed inside a parent scrollable widget
/// (e.g. CustomScrollView / ListView) so the text scrolls with the page.
Widget Function(BuildContext, EditableTextState)?
    _defaultSelectionContextMenuBuilder(
  Widget Function(BuildContext, EditableTextState)? builder,
) {
  if (builder != null) {
    return builder;
  }
  return (context, editableTextState) {
    return AdaptiveTextSelectionToolbar.editableText(
      editableTextState: editableTextState,
    );
  };
}

class NonScrollableSelectableText extends StatelessWidget {
  const NonScrollableSelectableText(
    this.data, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.showCursor = false,
    this.autofocus = false,
    this.cursorWidth = 2.0,
    this.cursorHeight,
    this.cursorRadius,
    this.cursorColor,
    this.selectionHeightStyle = ui.BoxHeightStyle.tight,
    this.selectionWidthStyle = ui.BoxWidthStyle.tight,
    this.dragStartBehavior = DragStartBehavior.start,
    this.toolbarOptions,
    this.dataIsRequired = true,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.onSelectionChanged,
    this.contextMenuBuilder,
  });

  final String data;
  final TextStyle? style;
  final StrutStyle? strutStyle;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final bool showCursor;
  final bool autofocus;
  final double cursorWidth;
  final double? cursorHeight;
  final Radius? cursorRadius;
  final Color? cursorColor;
  final ui.BoxHeightStyle selectionHeightStyle;
  final ui.BoxWidthStyle selectionWidthStyle;
  final DragStartBehavior dragStartBehavior;
  final ToolbarOptions? toolbarOptions;
  final bool dataIsRequired;
  final int? maxLines;
  final String? semanticsLabel;
  final TextWidthBasis? textWidthBasis;
  final SelectionChangedCallback? onSelectionChanged;
  final Widget Function(BuildContext, EditableTextState)? contextMenuBuilder;

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(
        scrollbars: false,
        physics: const NeverScrollableScrollPhysics(),
      ),
      child: SelectableText(
        data,
        style: style,
        strutStyle: strutStyle,
        textAlign: textAlign,
        textDirection: textDirection,
        showCursor: showCursor,
        autofocus: autofocus,
        cursorWidth: cursorWidth,
        cursorHeight: cursorHeight,
        cursorRadius: cursorRadius,
        cursorColor: cursorColor,
        selectionHeightStyle: selectionHeightStyle,
        selectionWidthStyle: selectionWidthStyle,
        dragStartBehavior: dragStartBehavior,
        toolbarOptions: toolbarOptions,
        maxLines: maxLines,
        semanticsLabel: semanticsLabel,
        textWidthBasis: textWidthBasis,
        onSelectionChanged: onSelectionChanged,
        contextMenuBuilder:
            _defaultSelectionContextMenuBuilder(contextMenuBuilder),
      ),
    );
  }
}

/// A [SelectableText.rich] that never scrolls independently.
class NonScrollableSelectableRichText extends StatelessWidget {
  const NonScrollableSelectableRichText(
    this.textSpan, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.showCursor = false,
    this.autofocus = false,
    this.cursorWidth = 2.0,
    this.cursorHeight,
    this.cursorRadius,
    this.cursorColor,
    this.selectionHeightStyle = ui.BoxHeightStyle.tight,
    this.selectionWidthStyle = ui.BoxWidthStyle.tight,
    this.dragStartBehavior = DragStartBehavior.start,
    this.toolbarOptions,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.onSelectionChanged,
    this.contextMenuBuilder,
  });

  final TextSpan textSpan;
  final TextStyle? style;
  final StrutStyle? strutStyle;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final bool showCursor;
  final bool autofocus;
  final double cursorWidth;
  final double? cursorHeight;
  final Radius? cursorRadius;
  final Color? cursorColor;
  final ui.BoxHeightStyle selectionHeightStyle;
  final ui.BoxWidthStyle selectionWidthStyle;
  final DragStartBehavior dragStartBehavior;
  final ToolbarOptions? toolbarOptions;
  final int? maxLines;
  final String? semanticsLabel;
  final TextWidthBasis? textWidthBasis;
  final SelectionChangedCallback? onSelectionChanged;
  final Widget Function(BuildContext, EditableTextState)? contextMenuBuilder;

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(
        scrollbars: false,
        physics: const NeverScrollableScrollPhysics(),
      ),
      child: SelectableText.rich(
        textSpan,
        style: style,
        strutStyle: strutStyle,
        textAlign: textAlign,
        textDirection: textDirection,
        showCursor: showCursor,
        autofocus: autofocus,
        cursorWidth: cursorWidth,
        cursorHeight: cursorHeight,
        cursorRadius: cursorRadius,
        cursorColor: cursorColor,
        selectionHeightStyle: selectionHeightStyle,
        selectionWidthStyle: selectionWidthStyle,
        dragStartBehavior: dragStartBehavior,
        toolbarOptions: toolbarOptions,
        maxLines: maxLines,
        semanticsLabel: semanticsLabel,
        textWidthBasis: textWidthBasis,
        onSelectionChanged: onSelectionChanged,
        contextMenuBuilder:
            _defaultSelectionContextMenuBuilder(contextMenuBuilder),
      ),
    );
  }
}
