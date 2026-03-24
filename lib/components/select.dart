part of 'components.dart';

/// Venera style Select component
class Select extends StatelessWidget {
  const Select({
    super.key,
    this.current,
    required this.values,
    this.onTap,
    this.minWidth,
    // Legacy API support
    this.initialValue,
    this.width,
    this.onChange,
    this.outline = false,
    this.disabledValues = const [],
  });

  final String? current;

  final List<String> values;

  final void Function(int index)? onTap;

  final double? minWidth;

  // Legacy API
  final int? initialValue;
  final double? width;
  final void Function(int)? onChange;
  final bool outline;
  final List<int> disabledValues;

  @override
  Widget build(BuildContext context) {
    // If using legacy API (initialValue is provided), convert to new style
    if (initialValue != null || onChange != null) {
      return _SelectWrapper(
        initialValue: initialValue,
        width: width ?? 120,
        onChange: onChange,
        values: values,
        disabledValues: disabledValues,
      );
    }

    // Venera style Select
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: context.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(4),
      ),
      child: InkWell(
        onTap: () {
          var renderBox = context.findRenderObject() as RenderBox;
          var offset = renderBox.localToGlobal(Offset.zero);
          var size = renderBox.size;
          showMenu(
            elevation: 3,
            color: context.brightness == Brightness.light
                ? const Color(0xFFF6F6F6)
                : const Color(0xFF1E1E1E),
            context: context,
            useRootNavigator: true,
            constraints: BoxConstraints(
              minWidth: size.width,
              maxWidth: size.width,
            ),
            position: RelativeRect.fromLTRB(
              offset.dx,
              offset.dy + size.height + 2,
              offset.dx + size.height + 2,
              offset.dy,
            ),
            items: values
                .map((e) => PopupMenuItem(
                      height: App.isMobile ? 46 : 40,
                      value: e,
                      child: Text(e),
                    ))
                .toList(),
          ).then((value) {
            if (value != null) {
              onTap?.call(values.indexOf(value));
            }
          });
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: minWidth != null ? (minWidth! - 32) : 0,
              ),
              child: Text(current ?? ' ', style: ts.s14),
            ),
            const SizedBox(width: 8),
            Icon(Icons.arrow_drop_down, color: context.colorScheme.primary),
          ],
        ).padding(const EdgeInsets.symmetric(horizontal: 12, vertical: 4)),
      ),
    );
  }
}

/// Wrapper to adapt legacy API to new Venera style Select
class _SelectWrapper extends StatefulWidget {
  const _SelectWrapper({
    this.initialValue,
    this.width = 120,
    this.onChange,
    required this.values,
    this.disabledValues = const [],
  });

  final int? initialValue;
  final double width;
  final void Function(int)? onChange;
  final List<String> values;
  final List<int> disabledValues;

  @override
  State<_SelectWrapper> createState() => _SelectWrapperState();
}

class _SelectWrapperState extends State<_SelectWrapper> {
  late int? value = widget.initialValue;

  @override
  void didUpdateWidget(covariant _SelectWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != oldWidget.initialValue) {
      value = widget.initialValue;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (value != null && value! >= widget.values.length) {
      value = 0;
    }
    if (value != null && value! < 0) value = null;

    // Filter out disabled values for display
    final enabledValues = <String>[];
    final enabledIndices = <int>[];
    for (int i = 0; i < widget.values.length; i++) {
      if (!widget.disabledValues.contains(i)) {
        enabledValues.add(widget.values[i]);
        enabledIndices.add(i);
      }
    }

    // Find current value index in enabled list
    int? currentIndex;
    if (value != null) {
      final enabledIndex = enabledIndices.indexOf(value!);
      if (enabledIndex >= 0) {
        currentIndex = enabledIndex;
      }
    }

    return SizedBox(
      width: widget.width,
      child: Select(
        current: currentIndex != null ? enabledValues[currentIndex] : null,
        values: enabledValues,
        minWidth: widget.width - 32,
        onTap: (index) {
          setState(() {
            value = enabledIndices[index];
          });
          widget.onChange?.call(enabledIndices[index]);
        },
      ),
    );
  }
}

/// Legacy Select implementation for backward compatibility
class _LegacySelect extends StatefulWidget {
  const _LegacySelect({
    this.initialValue,
    this.width = 120,
    this.onChange,
    required this.values,
    this.disabledValues = const [],
    this.outline = false,
  });

  final int? initialValue;
  final double width;
  final void Function(int)? onChange;
  final List<String> values;
  final List<int> disabledValues;
  final bool outline;

  @override
  State<_LegacySelect> createState() => _LegacySelectState();
}

class _LegacySelectState extends State<_LegacySelect> {
  late int? value = widget.initialValue;
  bool isHover = false;

  @override
  void didUpdateWidget(covariant _LegacySelect oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != oldWidget.initialValue) {
      value = widget.initialValue;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (value != null && value! >= widget.values.length) {
      value = 0;
    }
    if (value != null && value! < 0) value = null;

    if (App.isFluent) {
      return SizedBox(
        width: widget.width,
        height: 38,
        child: fluent.ComboBox<int>(
          value: value,
          items: List.generate(widget.values.length, (index) {
            return fluent.ComboBoxItem<int>(
              value: index,
              enabled: !widget.disabledValues.contains(index),
              child: Text(widget.values[index]),
            );
          }),
          onChanged: (i) {
            if (i != null) {
              setState(() {
                value = i;
                widget.onChange?.call(i);
              });
            }
          },
          placeholder: Text(value != null ? widget.values[value!] : ""),
        ),
      );
    }

    return MouseRegion(
      onEnter: (_) => setState(() => isHover = true),
      onExit: (_) => setState(() => isHover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          if (widget.values.isEmpty) {
            return;
          }
          final renderBox = context.findRenderObject() as RenderBox;
          var offset = renderBox.localToGlobal(Offset.zero);
          var size = MediaQuery.of(context).size;
          showMenu<int>(
              context: App.globalContext!,
              initialValue: value,
              position: RelativeRect.fromLTRB(offset.dx, offset.dy,
                  offset.dx + widget.width, size.height - offset.dy),
              constraints: BoxConstraints(
                maxWidth: widget.width,
                minWidth: widget.width,
              ),
              color: context.colorScheme.surfaceContainerLowest,
              items: [
                for (int i = 0; i < widget.values.length; i++)
                  if (!widget.disabledValues.contains(i))
                    PopupMenuItem(
                      value: i,
                      height: App.isDesktop ? 38 : 42,
                      onTap: () {
                        setState(() {
                          value = i;
                          widget.onChange?.call(i);
                        });
                      },
                      child: Text(widget.values[i]),
                    )
              ]);
        },
        child: AnimatedContainer(
          duration: _fastAnimationDuration,
          decoration: BoxDecoration(
            color: _getColor(),
            borderRadius: BorderRadius.circular(widget.outline ? 4 : 8),
            border: widget.outline
                ? Border.all(
                    color: context.colorScheme.outline,
                    width: 1,
                  )
                : null,
          ),
          width: widget.width,
          height: 38,
          child: Row(
            children: [
              const SizedBox(
                width: 12,
              ),
              Expanded(
                child: Text(
                  value == null ? "" : widget.values[value!],
                  overflow: TextOverflow.fade,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              const Icon(Icons.arrow_drop_down_sharp),
              const SizedBox(
                width: 4,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getColor() {
    if (widget.outline) {
      return isHover
          ? context.colorScheme.outline.withOpacity(0.1)
          : Colors.transparent;
    } else {
      var color = context.colorScheme.surfaceContainerHigh;
      if (isHover) {
        color = color.withOpacity(0.8);
      }
      return color;
    }
  }
}

class FilterChipFixedWidth extends StatefulWidget {
  const FilterChipFixedWidth(
      {required this.label,
      required this.selected,
      required this.onSelected,
      super.key});

  final Widget label;

  final bool selected;

  final void Function(bool) onSelected;

  @override
  State<FilterChipFixedWidth> createState() => _FilterChipFixedWidthState();
}

class _FilterChipFixedWidthState extends State<FilterChipFixedWidth> {
  get selected => widget.selected;

  double? labelWidth;

  double? labelHeight;

  var key = GlobalKey();

  @override
  void initState() {
    Future.microtask(measureSize);
    super.initState();
  }

  void measureSize() {
    final RenderBox renderBox =
        key.currentContext!.findRenderObject() as RenderBox;
    labelWidth = renderBox.size.width;
    labelHeight = renderBox.size.height;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      textStyle: Theme.of(context).textTheme.labelLarge,
      child: InkWell(
        onTap: () => widget.onSelected(true),
        borderRadius: const BorderRadius.all(Radius.circular(8)),
        child: AnimatedContainer(
          duration: _fastAnimationDuration,
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).colorScheme.outline),
            borderRadius: const BorderRadius.all(Radius.circular(8)),
            color: selected
                ? Theme.of(context).colorScheme.primaryContainer
                : null,
          ),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: labelWidth == null ? firstBuild() : buildContent(),
        ),
      ),
    );
  }

  Widget firstBuild() {
    return Center(
      child: SizedBox(
        key: key,
        child: widget.label,
      ),
    );
  }

  Widget buildContent() {
    const iconSize = 18.0;
    const gap = 4.0;
    return SizedBox(
      width: iconSize + labelWidth! + gap,
      height: math.max(iconSize, labelHeight!),
      child: Stack(
        children: [
          AnimatedPositioned(
            duration: _fastAnimationDuration,
            left: selected ? (iconSize + gap) : (iconSize + gap) / 2,
            child: widget.label,
          ),
          if (selected)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              right: labelWidth! + gap,
              child: AnimatedCheckIcon(size: iconSize).toCenter(),
            )
        ],
      ),
    );
  }
}

class AnimatedCheckWidget extends AnimatedWidget {
  const AnimatedCheckWidget({
    super.key,
    required Animation<double> animation,
    this.size,
  }) : super(listenable: animation);

  final double? size;

  @override
  Widget build(BuildContext context) {
    var iconSize = size ?? IconTheme.of(context).size ?? 25;
    final animation = listenable as Animation<double>;
    return SizedBox(
      width: iconSize,
      height: iconSize,
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: animation.value,
          child: ClipRRect(
            child: Icon(
              Icons.check,
              size: iconSize,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      ),
    );
  }
}

class AnimatedCheckIcon extends StatefulWidget {
  const AnimatedCheckIcon({this.size, super.key});

  final double? size;

  @override
  State<AnimatedCheckIcon> createState() => _AnimatedCheckIconState();
}

class _AnimatedCheckIconState extends State<AnimatedCheckIcon>
    with SingleTickerProviderStateMixin {
  late Animation<double> animation;
  late AnimationController controller;

  @override
  void initState() {
    controller = AnimationController(
      vsync: this,
      duration: _fastAnimationDuration,
    );
    animation = Tween<double>(begin: 0, end: 1).animate(controller)
      ..addListener(() {
        setState(() {});
      });
    controller.forward();
    super.initState();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedCheckWidget(
      animation: animation,
      size: widget.size,
    );
  }
}

class OptionChip extends StatelessWidget {
  const OptionChip(
      {super.key,
      required this.text,
      required this.isSelected,
      required this.onTap});

  final String text;

  final bool isSelected;

  final void Function() onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: _fastAnimationDuration,
      decoration: BoxDecoration(
        color: isSelected
            ? context.colorScheme.secondaryContainer
            : context.colorScheme.surface,
        border: isSelected
            ? Border.all(color: context.colorScheme.secondaryContainer)
            : Border.all(color: context.colorScheme.outline),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Text(text),
          ),
        ),
      ),
    );
  }
}
