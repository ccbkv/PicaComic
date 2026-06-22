part of 'components.dart';

class PaneItemEntry {
  String label;

  IconData icon;

  IconData activeIcon;

  PaneItemEntry({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });
}

class PaneActionEntry {
  String label;

  IconData icon;

  VoidCallback onTap;

  PaneActionEntry({
    required this.label,
    required this.icon,
    required this.onTap,
  });
}

class NaviPane extends StatefulWidget {
  const NaviPane({
    required this.paneItems,
    required this.paneActions,
    required this.pageBuilder,
    this.initialPage = 0,
    this.onPageChanged,
    required this.observer,
    required this.navigatorKey,
    super.key,
  });

  final List<PaneItemEntry> paneItems;

  final List<PaneActionEntry> paneActions;

  final Widget Function(int page) pageBuilder;

  final void Function(int index)? onPageChanged;

  final int initialPage;

  final NaviObserver observer;

  final GlobalKey<NavigatorState> navigatorKey;

  @override
  State<NaviPane> createState() => NaviPaneState();

  static NaviPaneState of(BuildContext context) {
    return context.findAncestorStateOfType<NaviPaneState>()!;
  }
}

typedef NaviItemTapListener = void Function(int);

double bottomOverlayInsetOf(BuildContext context) {
  final state = context.findAncestorStateOfType<NaviPaneState>();
  if (state == null || !state.shouldUseLiquidGlassBottomNavigation) {
    return 0;
  }
  return state.liquidGlassBottomBarHeight;
}

class NaviPaneState extends State<NaviPane>
    with SingleTickerProviderStateMixin {
  late int _currentPage = widget.initialPage;

  int get currentPage => _currentPage;

  set currentPage(int value) {
    if (value == _currentPage) return;
    _currentPage = value;
    widget.onPageChanged?.call(value);
  }

  void Function()? mainViewUpdateHandler;

  late AnimationController controller;

  final _naviItemTapListeners = <NaviItemTapListener>[];

  void addNaviItemTapListener(NaviItemTapListener listener) {
    _naviItemTapListeners.add(listener);
  }

  void removeNaviItemTapListener(NaviItemTapListener listener) {
    _naviItemTapListeners.remove(listener);
  }

  static const _kBottomBarHeight = 58.0;

  static const _kFoldedSideBarWidth = 72.0;

  static const _kSideBarWidth = 224.0;

  static const _kTopBarHeight = 48.0;

  static const _kDesktopSidebarHysteresis = 48.0;

  bool get enableLiquidGlassBottomBar =>
      appdata.settings.length > 103 &&
      appdata.settings[103] == "1";

  bool get shouldUseBottomNavigationLayout =>
      MediaQuery.of(context).size.width <= changePoint;

  bool get shouldUseLiquidGlassBottomNavigation =>
      enableLiquidGlassBottomBar && shouldUseBottomNavigationLayout;

  double get bottomBarHeight =>
      _kBottomBarHeight + MediaQuery.of(context).padding.bottom;

  double get liquidGlassBottomBarHeight {
    final bottomPadding =
        math.max(MediaQuery.of(context).viewPadding.bottom, 10.0);
    return 56 + 14 * 2 + bottomPadding;
  }

  double get visibleSideBarWidth =>
      _kFoldedSideBarWidth * ((controller.value - 1.0).clamp(0.0, 1.0)) +
      (_kSideBarWidth - _kFoldedSideBarWidth) *
          ((controller.value - 2.0).clamp(0.0, 1.0));

  void onNavigatorStateChange() {
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    } else {
      if (mounted) setState(() {});
    }
    onRebuild(context);
  }

  void updatePage(int index) {
    for (var listener in _naviItemTapListeners) {
      listener(index);
    }
    if (widget.observer.routes.length > 1) {
      widget.navigatorKey.currentState!.popUntil((route) => route.isFirst);
    }
    if (currentPage == index) {
      return;
    }
    setState(() {
      currentPage = index;
    });
    mainViewUpdateHandler?.call();
  }

  @override
  void initState() {
    controller = AnimationController(
      duration: const Duration(milliseconds: 250),
      lowerBound: 0,
      upperBound: 3,
      vsync: this,
    );
    widget.observer.addListener(onNavigatorStateChange);
    super.initState();
  }

  @override
  void dispose() {
    controller.dispose();
    widget.observer.removeListener(onNavigatorStateChange);
    super.dispose();
  }

  bool _hasResolvedLayoutTarget = false;

  double targetFormContext(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width <= changePoint) {
      return 0;
    }

    if (!_hasResolvedLayoutTarget) {
      return width > changePoint2 ? 3 : 2;
    }

    final currentTarget = animationTarget ?? controller.value;
    final prefersExpandedSidebar = currentTarget >= 2.5;
    if (prefersExpandedSidebar) {
      return width < changePoint2 - _kDesktopSidebarHysteresis ? 2 : 3;
    }
    return width > changePoint2 + _kDesktopSidebarHysteresis ? 3 : 2;
  }

  double? animationTarget;

  bool _isCompactLayoutTarget(double target) => target < 2;

  void onRebuild(BuildContext context) {
    double target = targetFormContext(context);
    if (controller.value != target || animationTarget != target) {
      final currentTarget = animationTarget ?? controller.value;
      final crossesLayoutMode =
          _isCompactLayoutTarget(currentTarget) !=
          _isCompactLayoutTarget(target);
      if (controller.isAnimating) {
        if (animationTarget == target) {
          return;
        } else {
          controller.stop();
        }
      }
      if (crossesLayoutMode) {
        controller.value = target;
      } else {
        controller.animateTo(target, curve: Curves.easeOutCubic);
      }
      animationTarget = target;
      _hasResolvedLayoutTarget = true;
    }
  }

  String _getTitle() {
    if (widget.observer.routes.length > 1) {
      var route = widget.observer.routes.last;
      if (route is AppPageRoute) {
        if (route.label == 'DownloadPage') return '已下载'.tl;
        if (route.label == 'ImageFavoritesPage') return '图片收藏'.tl;
        if (route.label == 'HistoryPage') return '历史记录'.tl;
        if (route.label == 'ComicSourceSettings') return '漫画源'.tl;
      }
      if (route.settings.name == '/SettingsPage') return '设置'.tl;
    } else if (currentPage == 0) {
      return '我的'.tl;
    }
    return widget.paneItems[currentPage].label;
  }

  @override
  Widget build(BuildContext context) {
    if (App.isFluent) {
      return fluent.NavigationView(
        appBar: fluent.NavigationAppBar(
          title: Text(_getTitle()),
          automaticallyImplyLeading: false,
          leading: widget.observer.routes.length > 1
              ? fluent.IconButton(
                  icon: const Icon(fluent.FluentIcons.back),
                  onPressed: () {
                    widget.navigatorKey.currentState!.pop();
                  },
                )
              : null,
          actions: ValueListenableBuilder(
            valueListenable: App.mainAppbarActions,
            builder: (context, value, child) {
              return Padding(
                padding: const EdgeInsets.only(right: 12.0),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: value ?? const SizedBox(),
                  ),
                ),
              );
            },
          ),
        ),
        pane: fluent.NavigationPane(
          selected: currentPage,
          onChanged: (index) {
            updatePage(index);
          },
          displayMode: fluent.PaneDisplayMode.auto,
          items: List.generate(widget.paneItems.length, (index) {
            var entry = widget.paneItems[index];
            return fluent.PaneItem(
              icon: Icon(entry.icon),
              title: Text(entry.label),
              body: const SizedBox.shrink(),
              onTap: () {
                updatePage(index);
              },
            );
          }),
          footerItems: widget.paneActions.map((e) {
            return fluent.PaneItemAction(
              icon: Icon(e.icon),
              title: Text(e.label),
              onTap: e.onTap,
            );
          }).toList(),
        ),
        transitionBuilder: (child, animation) {
          return buildMainView();
        },
      );
    }
    final mq = MediaQuery.of(context);
    final sideInsets = (App.isMobile && mq.orientation == Orientation.landscape)
        ? EdgeInsets.only(
            left: math.max(mq.viewPadding.left, mq.systemGestureInsets.left),
            right: math.max(mq.viewPadding.right, mq.systemGestureInsets.right),
          )
        : EdgeInsets.zero;
    onRebuild(context);
    bool internalCanPop = widget.observer.routes.length > 1;
    bool rootCanPop = Navigator.of(context).canPop();
    return PopScope(
      canPop: !internalCanPop && !rootCanPop,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          return;
        }
        if (internalCanPop) {
          App.mainNavigatorKey!.currentState!.maybePop();
        } else if (rootCanPop) {
          SystemNavigator.pop();
        }
      },
      child: _NaviPopScope(
        action: () {
          if (App.mainNavigatorKey!.currentState!.canPop()) {
            App.mainNavigatorKey!.currentState!.maybePop();
          } else {
            SystemNavigator.pop();
          }
        },
        popGesture: App.isIOS && context.width >= changePoint,
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            final value = controller.value;
            Widget content = Stack(
              children: [
                Positioned.fill(
                  child: buildMainView(),
                ),
                Positioned(
                  left:
                      _kFoldedSideBarWidth * ((value - 2.0).clamp(-1.0, 0.0)),
                  top: 0,
                  bottom: 0,
                  child: RepaintBoundary(
                    child: buildLeft(
                      useLiquidSelection: enableLiquidGlassBottomBar,
                    ),
                  ),
                ),
              ],
            );
            if (sideInsets != EdgeInsets.zero) {
              content = Padding(
                padding: sideInsets,
                child: content,
              );
            }
            return content;
          },
        ),
      ),
    );
  }

  Widget buildMainView() {
    final theme = Theme.of(context);
    return HeroControllerScope(
      controller: MaterialApp.createMaterialHeroController(),
      child: NavigatorPopHandler(
        onPopWithResult: (result) {
          widget.navigatorKey.currentState?.maybePop(result);
        },
        child: RouteDisplayInsets(
          padding: EdgeInsets.only(left: visibleSideBarWidth),
          child: Theme(
            data: theme.copyWith(
              pageTransitionsTheme: _buildInsetPageTransitionsTheme(theme),
            ),
            child: Navigator(
              observers: [widget.observer],
              key: widget.navigatorKey,
              onGenerateRoute: (settings) => AppPageRoute(
                preventRebuild: false,
                builder: (context) {
                  return _NaviMainView(state: this);
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  PageTransitionsTheme _buildInsetPageTransitionsTheme(ThemeData baseTheme) {
    final builders = <TargetPlatform, PageTransitionsBuilder>{};
    for (final platform in TargetPlatform.values) {
      builders[platform] = _InsetPageTransitionsBuilder(
        baseBuilder:
            baseTheme.pageTransitionsTheme.builders[platform] ??
            const ZoomPageTransitionsBuilder(),
        insetBuilder: () =>
            shouldUseBottomNavigationLayout ? 0 : visibleSideBarWidth,
      );
    }
    return PageTransitionsTheme(builders: builders);
  }

  Widget buildMainViewContent() {
    return widget.pageBuilder(currentPage);
  }

  Widget buildTop() {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final content = SizedBox(
      height: _kTopBarHeight,
      width: double.infinity,
      child: Row(
        children: [
          Text(
            widget.paneItems[currentPage].label,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          for (var action in widget.paneActions)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: _GlassPaneActionButton(entry: action),
            ),
        ],
      ),
    );

    if (enableLiquidGlassBottomBar) {
      return GlassContainer(
        height: _kTopBarHeight,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        useOwnLayer: true,
        quality: GlassQuality.minimal,
        shape: const LiquidRoundedSuperellipse(borderRadius: 24),
        settings: LiquidGlassSettings(
          blur: 18,
          glassColor: isDark
              ? scheme.surfaceContainerHighest.withValues(alpha: 0.28)
              : Colors.white.withValues(alpha: 0.18),
          ambientStrength: isDark ? 0.34 : 0.46,
          saturation: 1.14,
          thickness: 18,
        ),
        child: content,
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.86),
      ),
      height: _kTopBarHeight,
      width: double.infinity,
      padding: const EdgeInsets.only(left: 16, right: 16),
      child: content,
    );
  }

  Widget buildBottom() {
    if (enableLiquidGlassBottomBar) {
      final theme = Theme.of(context);
      final primary = theme.colorScheme.primary;
      final isDark = theme.brightness == Brightness.dark;
      final tabs = [
        ...widget.paneItems.map(
          (e) => GlassBottomBarTab(
            label: e.label,
            icon: Icon(e.icon),
            activeIcon: Icon(e.activeIcon),
          ),
        ),
      ];
      final bottomPadding =
          math.max(MediaQuery.of(context).viewPadding.bottom, 10.0);
      final baseGlassColor = isDark
          ? const Color.fromRGBO(255, 255, 255, 0.10)
          : const Color.fromRGBO(255, 255, 255, 0.08);
      return Padding(
        padding: EdgeInsets.fromLTRB(12, 0, 12, bottomPadding),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 488),
            child: GlassBottomBar(
              quality: GlassQuality.minimal,
              interactionBehavior: GlassInteractionBehavior.full,
              selectedIconColor: primary,
              unselectedIconColor:
                  theme.colorScheme.onSurface.withValues(alpha: 0.76),
              iconSize: 28,
              labelFontSize: 10,
              iconLabelSpacing: 0,
              settings: LiquidGlassSettings(
                blur: 3,
                glassColor: baseGlassColor,
                ambientStrength: 0,
                saturation: 1.2,
                thickness: 30,
                chromaticAberration: .01,
                lightAngle: GlassDefaults.lightAngle,
                lightIntensity: .5,
                refractiveIndex: 1.2,
                specularSharpness: GlassSpecularSharpness.medium,
              ),
              verticalPadding: 12,
              barHeight: 60,
              selectedIndex: currentPage,
              onTabSelected: (index) {
                updatePage(index);
              },
              tabs: tabs,
            ),
          ),
        ),
      );
    }
    return Material(
      textStyle: Theme.of(context).textTheme.labelSmall,
      elevation: 0,
      child: Container(
        height: _kBottomBarHeight,
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: List<Widget>.generate(widget.paneItems.length, (index) {
            return Expanded(
              child: _SingleBottomNaviWidget(
                enabled: currentPage == index,
                entry: widget.paneItems[index],
                onTap: () {
                  updatePage(index);
                },
                key: ValueKey(index),
              ),
            );
          }),
        ),
      ),
    );
  }

  List<PaneActionEntry> _wideBottomActions() {
    final hasSearchAction =
        widget.paneActions.any((action) => action.icon == Icons.search);
    return [
      if (!hasSearchAction)
        PaneActionEntry(
          label: "搜索".tl,
          icon: Icons.search,
          onTap: () {
            final navContext = widget.navigatorKey.currentContext;
            if (navContext == null) {
              return;
            }
            App.to(navContext, () => PreSearchPage());
          },
        ),
      ...widget.paneActions,
    ];
  }

  Widget buildLeft({required bool useLiquidSelection}) {
    final value = controller.value;
    const paddingHorizontal = 12.0;
    return Material(
      child: Container(
        width: _kFoldedSideBarWidth +
            (_kSideBarWidth - _kFoldedSideBarWidth) * ((value - 2).clamp(0, 1)),
        height: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: paddingHorizontal),
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
              width: 1.0,
            ),
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: 16),
            SizedBox(height: MediaQuery.of(context).padding.top),
            ...List<Widget>.generate(
              widget.paneItems.length,
              (index) => _SideNaviWidget(
                enabled: currentPage == index,
                entry: widget.paneItems[index],
                showTitle: value == 3,
                useLiquidSelection: useLiquidSelection,
                onTap: () {
                  updatePage(index);
                },
                key: ValueKey(index),
              ),
            ),
            const Spacer(),
            ...List<Widget>.generate(
              widget.paneActions.length,
              (index) => _PaneActionWidget(
                entry: widget.paneActions[index],
                showTitle: value == 3,
                key: ValueKey(index + widget.paneItems.length),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _SideNaviWidget extends StatefulWidget {
  const _SideNaviWidget({
    required this.enabled,
    required this.entry,
    required this.onTap,
    required this.showTitle,
    required this.useLiquidSelection,
    super.key,
  });

  final bool enabled;

  final PaneItemEntry entry;

  final VoidCallback onTap;

  final bool showTitle;

  final bool useLiquidSelection;

  @override
  State<_SideNaviWidget> createState() => _SideNaviWidgetState();
}

class _SideNaviWidgetState extends State<_SideNaviWidget> {
  bool _pressed = false;

  double _itemHeight() {
    if (widget.useLiquidSelection) {
      return widget.showTitle ? 42 : 40;
    }
    return 38;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final itemHeight = _itemHeight();
    final active = widget.enabled || (widget.useLiquidSelection && _pressed);
    final restingIndicatorColor = colorScheme.primary.withValues(alpha: 0.05);
    final pressedGlassColor = isDark
        ? colorScheme.primary.withValues(alpha: 0.28)
        : colorScheme.primary.withValues(alpha: 0.20);
    final activeColor =
        widget.useLiquidSelection && active ? colorScheme.primary : null;
    final icon = Icon(
      active ? widget.entry.activeIcon : widget.entry.icon,
      color: activeColor,
    );
    final label = Text(
      widget.entry.label,
      style: activeColor == null ? null : TextStyle(color: activeColor),
    );

    Widget child = widget.showTitle
        ? Row(
            children: [icon, const SizedBox(width: 12), label],
          )
        : Align(alignment: Alignment.centerLeft, child: icon);

    if (widget.useLiquidSelection) {
      final scaledChild = AnimatedScale(
        duration: _fastAnimationDuration,
        curve: Curves.easeOutCubic,
        scale: _pressed ? 1.08 : 1.0,
        child: child,
      );

      return GlassButton.custom(
        onTap: widget.onTap,
        width: double.infinity,
        height: itemHeight,
        shape: const LiquidRoundedSuperellipse(borderRadius: 20),
        settings: LiquidGlassSettings(
          blur: 0,
          glassColor: _pressed
              ? pressedGlassColor
              : (widget.enabled
                  ? colorScheme.primary.withValues(alpha: isDark ? 0.18 : 0.12)
                  : (isDark
                      ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.18)
                      : Colors.white.withValues(alpha: 0.12))),
          saturation: 1.18,
          ambientStrength: widget.enabled ? 0.50 : 0.38,
          thickness: widget.enabled ? 24 : 18,
        ),
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) => setState(() => _pressed = true),
          onPointerUp: (_) => setState(() => _pressed = false),
          onPointerCancel: (_) => setState(() => _pressed = false),
          child: AnimatedContainer(
            duration: _fastAnimationDuration,
            width: double.infinity,
            height: itemHeight,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: widget.enabled ? restingIndicatorColor : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: scaledChild,
          ),
        ),
      ).paddingVertical(4);
    }

    Widget surface = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      height: itemHeight,
      decoration: BoxDecoration(
        color: widget.enabled ? colorScheme.primaryContainer : null,
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: widget.onTap,
      child: surface,
    ).paddingVertical(4);
  }
}

class _PaneActionWidget extends StatelessWidget {
  const _PaneActionWidget({
    required this.entry,
    required this.showTitle,
    super.key,
  });

  final PaneActionEntry entry;

  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    final icon = Icon(entry.icon);
    final itemHeight = showTitle ? 42.0 : 40.0;
    final enableLiquidGlassUi =
        appdata.settings.length > 103 && appdata.settings[103] == "1";
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final child = showTitle
        ? Row(
            children: [icon, const SizedBox(width: 12), Text(entry.label)],
          )
        : Align(alignment: Alignment.centerLeft, child: icon);

    if (enableLiquidGlassUi) {
      return GlassButton.custom(
        onTap: entry.onTap,
        width: double.infinity,
        height: itemHeight,
        shape: const LiquidRoundedSuperellipse(borderRadius: 18),
        settings: LiquidGlassSettings(
          blur: 0,
          glassColor: isDark
              ? scheme.surfaceContainerHighest.withValues(alpha: 0.20)
              : Colors.white.withValues(alpha: 0.14),
          ambientStrength: isDark ? 0.34 : 0.46,
          saturation: 1.12,
          thickness: 18,
        ),
        child: SizedBox(
          height: itemHeight,
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: child,
          ),
        ),
      ).paddingVertical(4);
    }

    return InkWell(
      onTap: entry.onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        height: itemHeight,
        child: child,
      ),
    ).paddingVertical(4);
  }
}

class _GlassPaneActionButton extends StatelessWidget {
  const _GlassPaneActionButton({
    required this.entry,
  });

  final PaneActionEntry entry;

  @override
  Widget build(BuildContext context) {
    final enableLiquidGlassUi =
        appdata.settings.length > 103 && appdata.settings[103] == "1";
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!enableLiquidGlassUi) {
      return Tooltip(
        message: entry.label,
        child: IconButton(
          icon: Icon(entry.icon),
          onPressed: entry.onTap,
        ),
      );
    }

    return Tooltip(
      message: entry.label,
      child: GlassButton.custom(
        onTap: entry.onTap,
        width: 40,
        height: 40,
        shape: const LiquidRoundedSuperellipse(borderRadius: 18),
        settings: LiquidGlassSettings(
          blur: 0,
          glassColor: isDark
              ? scheme.surfaceContainerHighest.withValues(alpha: 0.24)
              : Colors.white.withValues(alpha: 0.16),
          ambientStrength: isDark ? 0.34 : 0.46,
          saturation: 1.12,
          thickness: 18,
        ),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(entry.icon),
        ),
      ),
    );
  }
}

class _SingleBottomNaviWidget extends StatefulWidget {
  const _SingleBottomNaviWidget({
    required this.enabled,
    required this.entry,
    required this.onTap,
    super.key,
  });

  final bool enabled;

  final PaneItemEntry entry;

  final VoidCallback onTap;

  @override
  State<_SingleBottomNaviWidget> createState() =>
      _SingleBottomNaviWidgetState();
}

class _SingleBottomNaviWidgetState extends State<_SingleBottomNaviWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController controller;

  bool isHovering = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _SingleBottomNaviWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled != widget.enabled) {
      if (widget.enabled) {
        controller.forward(from: 0);
      } else {
        controller.reverse(from: 1);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      value: widget.enabled ? 1 : 0,
      vsync: this,
      duration: _fastAnimationDuration,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: CurvedAnimation(parent: controller, curve: Curves.ease),
      builder: (context, child) {
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (details) => setState(() => isHovering = true),
          onExit: (details) => setState(() => isHovering = false),
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: widget.onTap,
            child: buildContent(),
          ),
        );
      },
    );
  }

  Widget buildContent() {
    final value = controller.value;
    final colorScheme = Theme.of(context).colorScheme;
    final icon = Icon(
      widget.enabled ? widget.entry.activeIcon : widget.entry.icon,
    );
    return Center(
      child: Container(
        width: 64,
        height: 28,
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.all(Radius.circular(32)),
          color: isHovering ? colorScheme.surfaceContainer : Colors.transparent,
        ),
        child: Center(
          child: Container(
            width: 32 + value * 32,
            height: 28,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.all(Radius.circular(32)),
              color: value != 0
                  ? colorScheme.secondaryContainer
                  : Colors.transparent,
            ),
            child: Center(child: icon),
          ),
        ),
      ),
    );
  }
}

class _InsetPageTransitionsBuilder extends PageTransitionsBuilder {
  const _InsetPageTransitionsBuilder({
    required this.baseBuilder,
    required this.insetBuilder,
  });

  final PageTransitionsBuilder baseBuilder;
  final double Function() insetBuilder;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final inset = route.isFirst ? 0.0 : insetBuilder();
    final insetChild = inset <= 0
        ? child
        : Padding(
            padding: EdgeInsets.only(left: inset),
            child: child,
          );
    return baseBuilder.buildTransitions(
      route,
      context,
      animation,
      secondaryAnimation,
      insetChild,
    );
  }
}

class NaviObserver extends NavigatorObserver implements Listenable {
  var routes = Queue<Route>();

  int get pageCount {
    int count = 0;
    for (var route in routes) {
      if (route is AppPageRoute) {
        count++;
      }
    }
    return count;
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    routes.removeLast();
    notifyListeners();
  }

  @override
  void didPush(Route route, Route? previousRoute) {
    routes.addLast(route);
    notifyListeners();
  }

  @override
  void didRemove(Route route, Route? previousRoute) {
    routes.remove(route);
    notifyListeners();
  }

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
    routes.remove(oldRoute);
    if (newRoute != null) {
      routes.add(newRoute);
    }
    notifyListeners();
  }

  List<VoidCallback> listeners = [];

  @override
  void addListener(VoidCallback listener) {
    listeners.add(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    listeners.remove(listener);
  }

  void notifyListeners() {
    for (var listener in listeners) {
      listener();
    }
  }
}

class _NaviPopScope extends StatelessWidget {
  const _NaviPopScope({
    required this.child,
    this.popGesture = false,
    required this.action,
  });

  final Widget child;
  final bool popGesture;
  final VoidCallback action;

  static bool panStartAtEdge = false;

  @override
  Widget build(BuildContext context) {
    Widget res = child;
    if (popGesture) {
      res = GestureDetector(
        onPanStart: (details) {
          if (details.globalPosition.dx < 64) {
            panStartAtEdge = true;
          }
        },
        onPanEnd: (details) {
          if (details.velocity.pixelsPerSecond.dx < 0 ||
              details.velocity.pixelsPerSecond.dx > 0) {
            if (panStartAtEdge) {
              action();
            }
          }
          panStartAtEdge = false;
        },
        child: res,
      );
    }
    return res;
  }
}

class _NaviMainView extends StatefulWidget {
  const _NaviMainView({required this.state});

  final NaviPaneState state;

  @override
  State<_NaviMainView> createState() => _NaviMainViewState();
}

class _NaviMainViewState extends State<_NaviMainView> {
  NaviPaneState get state => widget.state;

  @override
  void initState() {
    state.mainViewUpdateHandler = () {
      setState(() {});
    };
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    if (App.isFluent) {
      return state.buildMainViewContent();
    }
    return AnimatedBuilder(
      animation: state.controller,
      builder: (context, _) {
        var shouldShowAppBar = state.controller.value < 2;
        var useLiquidGlassBottomBar = state.shouldUseLiquidGlassBottomNavigation;
        final mainContent = AnimatedSwitcher(
          duration: _fastAnimationDuration,
          child: state.buildMainViewContent(),
        );
        // Calculate left padding to account for the sidebar.
        // The Navigator now covers the full screen so that its Overlay
        // (used by GlassMenu) also covers the full screen. The content
        // must be padded to avoid overlapping with the sidebar.
        final leftPadding = state.visibleSideBarWidth;
        return Padding(
          padding: EdgeInsets.only(left: leftPadding),
          child: Scaffold(
          backgroundColor:
              useLiquidGlassBottomBar ? Colors.transparent : null,
          extendBody: useLiquidGlassBottomBar,
          appBar: shouldShowAppBar
              ? AppBar(
                  elevation: 0,
                  scrolledUnderElevation: 0,
                  toolbarHeight: NaviPaneState._kTopBarHeight,
                  titleSpacing: 16,
                  backgroundColor:
                      Theme.of(context).colorScheme.surface.withValues(
                            alpha: useLiquidGlassBottomBar ? 0.96 : 0.86,
                          ),
                  title: Text(
                    state.widget.paneItems[state.currentPage].label,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  actions: [
                    for (var action in state.widget.paneActions)
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: _GlassPaneActionButton(
                          entry: action,
                        ),
                      ),
                    const SizedBox(width: 8),
                  ],
                )
              : null,
          body: Stack(
                  children: [
                    Positioned.fill(child: mainContent),
                    if (useLiquidGlassBottomBar && shouldShowAppBar)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: state.buildBottom(),
                      ),
                  ],
                ),
          bottomNavigationBar: shouldShowAppBar && !useLiquidGlassBottomBar
              ? SafeArea(top: false, bottom: true, child: state.buildBottom())
              : null,
          ),
        );
      },
    );
  }
}
