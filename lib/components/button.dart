part of 'components.dart';

class HoverBox extends StatefulWidget {
  const HoverBox(
      {super.key, required this.child, this.borderRadius = BorderRadius.zero});

  final Widget child;

  final BorderRadius borderRadius;

  @override
  State<HoverBox> createState() => _HoverBoxState();
}

class _HoverBoxState extends State<HoverBox> {
  bool isHover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => isHover = true),
      onExit: (_) => setState(() => isHover = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
            color:
                isHover ? Theme.of(context).colorScheme.surfaceContainer : null,
            borderRadius: widget.borderRadius),
        child: widget.child,
      ),
    );
  }
}

enum ButtonType { filled, outlined, text, normal }

class Button extends StatefulWidget {
  const Button(
      {super.key,
      required this.type,
      required this.child,
      this.isLoading = false,
      this.width,
      this.height,
      this.padding,
      this.color,
      this.onPressedAt,
      this.disabled = false,
      required this.onPressed});

  const Button.filled(
      {super.key,
      required this.child,
      required this.onPressed,
      this.width,
      this.height,
      this.padding,
      this.color,
      this.onPressedAt,
      this.disabled = false,
      this.isLoading = false})
      : type = ButtonType.filled;

  const Button.outlined(
      {super.key,
      required this.child,
      required this.onPressed,
      this.width,
      this.height,
      this.padding,
      this.color,
      this.onPressedAt,
      this.disabled = false,
      this.isLoading = false})
      : type = ButtonType.outlined;

  const Button.text(
      {super.key,
      required this.child,
      required this.onPressed,
      this.width,
      this.height,
      this.padding,
      this.color,
      this.onPressedAt,
      this.disabled = false,
      this.isLoading = false})
      : type = ButtonType.text;

  const Button.normal(
      {super.key,
      required this.child,
      required this.onPressed,
      this.width,
      this.height,
      this.padding,
      this.color,
      this.onPressedAt,
      this.disabled = false,
      this.isLoading = false})
      : type = ButtonType.normal;

  static Widget icon(
      {Key? key,
      required Widget icon,
      required VoidCallback onPressed,
      double? size,
      Color? color,
      String? tooltip,
      bool isLoading = false,
      HitTestBehavior behavior = HitTestBehavior.deferToChild}) {
    return _IconButton(
      key: key,
      icon: icon,
      onPressed: onPressed,
      size: size,
      color: color,
      tooltip: tooltip,
      behavior: behavior,
      isLoading: isLoading,
    );
  }

  final ButtonType type;

  final Widget child;

  final bool isLoading;

  final void Function() onPressed;

  final void Function(Offset location)? onPressedAt;

  final double? width;

  final double? height;

  final EdgeInsets? padding;

  final Color? color;

  final bool disabled;

  @override
  State<Button> createState() => _ButtonState();
}

class _ButtonState extends State<Button> {
  bool isHover = false;

  bool isLoading = false;

  @override
  void didUpdateWidget(covariant Button oldWidget) {
    if (oldWidget.isLoading != widget.isLoading) {
      setState(() => isLoading = widget.isLoading);
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    var padding = widget.padding ??
        const EdgeInsets.symmetric(horizontal: 24, vertical: 6);
    var width = widget.width;
    if (width != null) {
      width = width - padding.horizontal;
    }
    var height = widget.height;
    if (height != null) {
      height = height - padding.vertical;
    }
    bool fixed = width != null || height != null;
    Widget child = IconTheme(
        data: IconThemeData(color: textColor),
        child: DefaultTextStyle(
          style: TextStyle(
            color: textColor,
            fontSize: 16,
          ),
          child: isLoading
              ? CircularProgressIndicator(
                  color: widget.type == ButtonType.filled
                      ? context.colorScheme.inversePrimary
                      : context.colorScheme.primary,
                  strokeWidth: 1.8,
                ).fixWidth(18).fixHeight(18)
              : widget.child,
        ));
    if (width != null || height != null) {
      child = child.toCenter();
    }
    void handlePressed() {
      if (widget.disabled) {
        return;
      }
      if (isLoading) return;
      widget.onPressed();
      if (widget.onPressedAt != null) {
        var renderBox = context.findRenderObject() as RenderBox;
        var offset = renderBox.localToGlobal(Offset.zero);
        widget.onPressedAt!(offset);
      }
    }

    Widget buildButtonBody() {
      return AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: padding,
        decoration: BoxDecoration(
          color: enableLiquidGlassUi ? glassOverlayColor : buttonColor,
          borderRadius: BorderRadius.circular(16),
          border: widget.type == ButtonType.outlined
              ? Border.all(
                  color: widget.color ?? Theme.of(context).colorScheme.outlineVariant,
                  width: 0.6,
                )
              : null,
        ),
        child: fixed
            ? SizedBox(
                width: width,
                height: height,
                child: child,
              )
            : AnimatedSize(
                duration: _fastAnimationDuration,
                child: child,
              ),
      );
    }

    return MouseRegion(
      onEnter: (_) => setState(() => isHover = true),
      onExit: (_) => setState(() => isHover = false),
      cursor: !widget.disabled ? SystemMouseCursors.click : MouseCursor.defer,
      child: enableLiquidGlassUi
          ? GlassSurface(
              borderRadius: 16,
              onTap: handlePressed,
              child: buildButtonBody(),
            )
          : GestureDetector(
              onTap: handlePressed,
              child: buildButtonBody(),
            ),
    );
  }

  Color get buttonColor {
    if (widget.type == ButtonType.filled) {
      if (widget.disabled) {
        return context.colorScheme.primaryContainer.withOpacity(0.6);
      }
      var color = widget.color ?? context.colorScheme.primary;
      if (isHover) {
        return color.withOpacity(0.9);
      } else {
        return color;
      }
    }
    if (isHover && !widget.disabled) {
      return context.colorScheme.outline.withOpacity(0.2);
    }
    return Colors.transparent;
  }

  Color get textColor {
    if (widget.disabled) {
      return context.colorScheme.outline;
    }
    if (widget.type == ButtonType.outlined) {
      return widget.color ?? context.colorScheme.onSurface;
    }
    return widget.type == ButtonType.filled
        ? context.colorScheme.onPrimary
        : (widget.type == ButtonType.text
            ? widget.color ?? context.colorScheme.primary
            : context.colorScheme.onSurface);
  }

  Color get glassOverlayColor {
    if (widget.type == ButtonType.filled) {
      final color = widget.color ?? context.colorScheme.primary;
      return color.withValues(
        alpha: widget.disabled ? 0.28 : (isHover ? 0.70 : 0.99),
      );
    }

 
    return context.colorScheme.outline.withValues(alpha: isHover ? 0.14 : 0.08);
  }
}

class _IconButton extends StatefulWidget {
  const _IconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.size,
    this.color,
    this.tooltip,
    this.isLoading = false,
    this.behavior = HitTestBehavior.deferToChild,
  });

  final Widget icon;

  final VoidCallback onPressed;

  final double? size;

  final String? tooltip;

  final Color? color;

  final HitTestBehavior behavior;

  final bool isLoading;

  @override
  State<_IconButton> createState() => _IconButtonState();
}

class _IconButtonState extends State<_IconButton> {
  bool isHover = false;

  @override
  Widget build(BuildContext context) {
    if (App.isFluent) {
      Widget icon = widget.icon;
      if (widget.isLoading) {
        icon = const fluent.ProgressRing(strokeWidth: 2.5).fixWidth(16).fixHeight(16);
      }
      return fluent.Tooltip(
        message: widget.tooltip ?? "",
        child: fluent.IconButton(
          icon: icon,
          onPressed: widget.isLoading ? null : widget.onPressed,
          style: fluent.ButtonStyle(
            iconSize: fluent.ButtonState.all(widget.size ?? 24),
            foregroundColor: widget.color != null ? fluent.ButtonState.all(widget.color!) : null,
          ),
        ),
      );
    }
    var iconSize = widget.size ?? 24;
    Widget icon = IconTheme(
      data: IconThemeData(
        size: iconSize,
        color: widget.color ?? context.colorScheme.primary,
      ),
      child: widget.icon,
    );
    if (widget.isLoading) {
      icon = const CircularProgressIndicator(
        strokeWidth: 1.5,
      ).paddingAll(2).fixWidth(iconSize).fixHeight(iconSize);
    }
    final glassChild = Tooltip(
      message: widget.tooltip ?? "",
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        decoration: BoxDecoration(
          color: (widget.color ?? context.colorScheme.primary).withValues(
            alpha: isHover ? 0.16 : 0.10,
          ),
          borderRadius: BorderRadius.circular((iconSize + 12) / 2),
        ),
        padding: const EdgeInsets.all(6),
        child: icon,
      ),
    );
    return MouseRegion(
      onEnter: (_) => setState(() => isHover = true),
      onExit: (_) => setState(() => isHover = false),
      cursor: SystemMouseCursors.click,
      child: enableLiquidGlassUi
          ? DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.55)
                    : Colors.white.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular((iconSize + 12) / 2),
                border: Border.all(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.white.withValues(alpha: 0.25),
                  width: 0.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                        alpha: Theme.of(context).brightness == Brightness.dark ? 0.3 : 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular((iconSize + 12) / 2),
                  onTap: () {
                    if (widget.isLoading) return;
                    widget.onPressed();
                  },
                  child: glassChild,
                ),
              ),
            )
          : GestureDetector(
              behavior: widget.behavior,
              onTap: () {
                if (widget.isLoading) return;
                widget.onPressed();
              },
              child: Tooltip(
                message: widget.tooltip ?? "",
                child: Container(
                  decoration: BoxDecoration(
                    color: isHover
                        ? Theme.of(context)
                            .colorScheme
                            .outlineVariant
                            .withOpacity(0.4)
                        : null,
                    borderRadius: BorderRadius.circular((iconSize + 12) / 2),
                  ),
                  padding: const EdgeInsets.all(6),
                  child: icon,
                ),
              ),
            ),
    );
  }
}

class AdaptiveSwitch extends StatelessWidget {
  const AdaptiveSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    if (App.isFluent) {
      return fluent.ToggleSwitch(
        checked: value,
        onChanged: onChanged,
      );
    }
    if (enableLiquidGlassUi) {
      return GlassSwitch(
        value: value,
        onChanged: onChanged,
      );
    }
    return Switch(
      value: value,
      onChanged: onChanged,
    );
  }
}

class StatefulSwitch extends StatefulWidget {
  const StatefulSwitch(
      {required this.initialValue, required this.onChanged, super.key});

  final bool initialValue;

  final void Function(bool) onChanged;

  @override
  State<StatefulSwitch> createState() => _StatefulSwitchState();
}

class _StatefulSwitchState extends State<StatefulSwitch> {
  late bool value;

  @override
  void initState() {
    value = widget.initialValue;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    if (App.isFluent) {
      return fluent.ToggleSwitch(
        checked: value,
        onChanged: (b) {
          setState(() {
            value = b;
            widget.onChanged(b);
          });
        },
      );
    }
    if (enableLiquidGlassUi) {
      return GlassSwitch(
        value: value,
        onChanged: (b) {
          setState(() {
            value = b;
            widget.onChanged(b);
          });
        },
      );
    }
    return Switch(
        value: value,
        onChanged: (b) {
          setState(() {
            value = b;
            widget.onChanged(b);
          });
        });
  }
}

class MenuButton extends StatelessWidget {
  const MenuButton({
    super.key,
    required this.entries,
    this.icon,
  });

  final List<MenuEntry> entries;

  final Icon? icon;

  @override
  Widget build(BuildContext context) {
    if (enableLiquidGlassUi) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final scheme = Theme.of(context).colorScheme;
      return GlassMenu(
        autoAdjustToScreen: true,
        menuWidth: 220,
        settings: LiquidGlassSettings(
          blur: 18,
          glassColor: isDark
              ? scheme.surfaceContainerHighest.withValues(alpha: 0.24)
              : Colors.white.withValues(alpha: 0.16),
          ambientStrength: isDark ? 0.34 : 0.48,
          saturation: 1.14,
          thickness: 18,
        ),
        items: entries
            .map((e) => GlassMenuItem(
                  title: e.text,
                  icon: e.icon != null ? Icon(e.icon) : null,
                  onTap: e.onClick,
                  titleStyle:
                      e.color != null ? TextStyle(color: e.color) : null,
                  iconColor: e.color,
                ))
            .toList(),
        triggerBuilder: (ctx, toggle) => Tooltip(
          message: "更多".tl,
          child: Button.icon(
            icon: icon ?? const Icon(Icons.more_horiz),
            onPressed: toggle,
          ),
        ),
      );
    }
    return Tooltip(
      message: "更多".tl,
      child: Button.icon(
        icon: icon ?? const Icon(Icons.more_horiz),
        onPressed: () {
          final renderBox = context.findRenderObject() as RenderBox;
          final offset = renderBox.localToGlobal(Offset.zero);
          showMenuX(context, offset, entries);
        },
      ),
    );
  }
}

class MenuEntry {
  final String text;
  final IconData? icon;
  final Color? color;
  final void Function() onClick;

  MenuEntry({required this.text, this.icon, this.color, required this.onClick});
}
