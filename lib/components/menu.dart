part of "components.dart";

void showDesktopMenu(
    BuildContext context, Offset location, List<DesktopMenuEntry> entries) {
  Navigator.of(context).push(DesktopMenuRoute(entries, location));
}

class DesktopMenuRoute<T> extends PopupRoute<T> {
  final List<DesktopMenuEntry> entries;

  final Offset location;

  DesktopMenuRoute(this.entries, this.location);

  @override
  Color? get barrierColor => Colors.transparent;

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => "menu";

  @override
  Widget buildPage(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation) {
    const width = 196.0;
    final size = MediaQuery.of(context).size;
    var left = location.dx;
    if (left + width > size.width - 10) {
      left = size.width - width - 10;
    }
    var top = location.dy;
    var height = 16 + 32 * entries.length;
    if (top + height > size.height - 15) {
      top = size.height - height - 15;
    }
    
    if (App.isFluent) {
      return Stack(
        children: [
          Positioned(
            left: left,
            top: top,
            child: fluent.Mica(
              borderRadius: BorderRadius.circular(8),
              elevation: 4,
              child: Container(
                width: width,
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: entries.map((e) => fluent.HoverButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      e.onClick();
                    },
                    builder: (p0, state) {
                      return Container(
                        height: 32,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        color: state.isHovering
                            ? fluent.FluentTheme.of(context).menuColor.withOpacity(0.1)
                            : Colors.transparent,
                        child: Row(
                          children: [
                            if (e.icon != null) ...[
                              Icon(e.icon, size: 16),
                              const SizedBox(width: 12),
                            ],
                            Text(e.text),
                          ],
                        ),
                      );
                    },
                  )).toList(),
                ),
              ),
            ),
          )
        ],
      );
    }

    return Stack(
      children: [
        Positioned(
          left: left,
          top: top,
          child: Container(
            width: width,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
            decoration: BoxDecoration(
                color: App.colors(context).surface,
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]),
            child: Material(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: entries.map((e) => buildEntry(e, context)).toList(),
              ),
            ),
          ),
        )
      ],
    );
  }

  Widget buildEntry(DesktopMenuEntry entry, BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: () {
        Navigator.of(context).pop();
        entry.onClick();
      },
      child: SizedBox(
        height: 32,
        child: Row(
          children: [
            const SizedBox(
              width: 4,
            ),
            if (entry.icon != null)
              Icon(
                entry.icon,
                size: 18,
              ),
            const SizedBox(
              width: 4,
            ),
            Text(entry.text),
          ],
        ),
      ),
    );
  }

  @override
  Duration get transitionDuration => const Duration(milliseconds: 200);

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    return FadeTransition(
      opacity: animation.drive(Tween<double>(begin: 0, end: 1)
          .chain(CurveTween(curve: Curves.ease))),
      child: child,
    );
  }
}

class DesktopMenuEntry {
  final String text;
  final IconData? icon;
  final void Function() onClick;

  DesktopMenuEntry({required this.text, this.icon, required this.onClick});
}

void showMenuX(BuildContext context, Offset location, List<MenuEntry> entries) {
  Navigator.of(context, rootNavigator: true).push(_MenuRoute(entries, location));
}

class _MenuRoute<T> extends PopupRoute<T> {
  final List<MenuEntry> entries;

  final Offset location;

  _MenuRoute(this.entries, this.location);

  @override
  Color? get barrierColor => Colors.transparent;

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => "menu";

  double get entryHeight => App.isMobile ? 42 : 36;

  @override
  Widget buildPage(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation) {
    var width = entries.first.icon == null ? 216.0 : 242.0;
    final size = MediaQuery.of(context).size;
    var left = location.dx;
    if (left < 10) {
      left = 10;
    }
    if (left + width > size.width - 10) {
      left = size.width - width - 10;
    }
    var top = location.dy;
    var height = 16 + entryHeight * entries.length;
    if (top + height > size.height - 15) {
      top = size.height - height - 15;
    }
    return Stack(
      children: [
        Positioned(
          left: left,
          top: top,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              border: context.brightness == Brightness.dark
                  ? Border.all(color: context.colorScheme.outlineVariant)
                  : null,
              boxShadow: [
                BoxShadow(
                  color: context.colorScheme.shadow.withOpacity(0.2),
                  blurRadius: 8,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Material(
                color: context.colorScheme.surface.withOpacity(0.92),
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  width: width,
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children:
                        entries.map((e) => buildEntry(e, context)).toList(),
                  ),
                ),
              ),
            ),
          ),
        )
      ],
    );
  }

  Widget buildEntry(MenuEntry entry, BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: () {
        Navigator.of(context).pop();
        entry.onClick();
      },
      child: SizedBox(
        height: entryHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              if (entry.icon != null)
                Icon(
                  entry.icon,
                  size: 18,
                  color: entry.color,
                ),
              const SizedBox(width: 12),
              Text(
                  entry.text,
                  style: TextStyle(color: entry.color)
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Duration get transitionDuration => const Duration(milliseconds: 200);

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    return FadeTransition(
      opacity: animation.drive(Tween<double>(begin: 0, end: 1)
          .chain(CurveTween(curve: Curves.ease))),
      child: child,
    );
  }
}
