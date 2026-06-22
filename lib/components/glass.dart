part of 'components.dart';

bool get enableLiquidGlassUi =>
    appdata.settings.length > 103 && appdata.settings[103] == "1";

class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.margin,
    this.padding,
    this.borderRadius = 20,
    this.onTap,
    this.height,
    this.width,
    this.useOwnLayer = true,
    this.quality = GlassQuality.minimal,
    this.blur,
  });

  final Widget child;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final VoidCallback? onTap;
  final double? height;
  final double? width;
  final bool useOwnLayer;
  final GlassQuality quality;
  final double? blur;

  @override
  Widget build(BuildContext context) {
    final content = SizedBox(
      width: width,
      height: height,
      child: padding == null ? child : Padding(padding: padding!, child: child),
    );

    Widget surface;
    if (enableLiquidGlassUi) {
      final scheme = Theme.of(context).colorScheme;
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final effectiveBlur = blur ?? 18;
      final effectiveGlassColor = effectiveBlur == 0
          ? (isDark
              ? scheme.surfaceContainerHighest.withValues(alpha: 0.92)
              : scheme.surface.withValues(alpha: 0.95))
          : (isDark
              ? scheme.surfaceContainerHighest.withValues(alpha: 0.24)
              : Colors.white.withValues(alpha: 0.16));
      surface = GlassContainer(
        width: width,
        height: height,
        useOwnLayer: useOwnLayer,
        quality: quality,
        shape: LiquidRoundedSuperellipse(borderRadius: borderRadius),
        settings: LiquidGlassSettings(
          blur: effectiveBlur,
          glassColor: effectiveGlassColor,
          ambientStrength: isDark ? 0.34 : 0.48,
          saturation: 1.14,
          thickness: 18,
        ),
        child: Material(
          color: Colors.transparent,
          child: onTap == null
              ? content
              : InkWell(
                  borderRadius: BorderRadius.circular(borderRadius),
                  onTap: onTap,
                  child: content,
                ),
        ),
      );
    } else {
      surface = Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(borderRadius),
        child: InkWell(
          borderRadius: BorderRadius.circular(borderRadius),
          onTap: onTap,
          child: content,
        ),
      );
    }

    if (margin != null) {
      return Padding(
        padding: margin!,
        child: surface,
      );
    }
    return surface;
  }
}

class GlassChipTag extends StatelessWidget {
  const GlassChipTag({
    super.key,
    required this.label,
    this.tint,
    this.useOwnLayer = true,
    this.blur,
  });

  final String label;
  final Color? tint;
  final bool useOwnLayer;
  final double? blur;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = tint ?? scheme.primary;
    final effectiveBlur = blur ?? 10;

    if (enableLiquidGlassUi) {
      final effectiveGlassColor = effectiveBlur == 0
          ? color.withValues(alpha: isDark ? 0.30 : 0.18)
          : color.withValues(alpha: isDark ? 0.24 : 0.14);
      return GlassContainer(
        height: 26,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        useOwnLayer: useOwnLayer,
        quality: GlassQuality.minimal,
        shape: const LiquidRoundedSuperellipse(borderRadius: 14),
        settings: LiquidGlassSettings(
          blur: effectiveBlur,
          glassColor: effectiveGlassColor,
          ambientStrength: 0.42,
          saturation: 1.16,
          thickness: 18,
        ),
        child: Align(
          alignment: Alignment.center,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }

    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: const TextStyle(fontSize: 12),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class GlassIconActionButton extends StatelessWidget {
  const GlassIconActionButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.size = 40,
    this.useOwnLayer = false,
    this.blur,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  final double size;
  final bool useOwnLayer;
  final double? blur;

  @override
  Widget build(BuildContext context) {
    Widget child;
    if (enableLiquidGlassUi) {
      final scheme = Theme.of(context).colorScheme;
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final effectiveBlur = blur ?? 12;
      final effectiveGlassColor = effectiveBlur == 0
          ? (isDark
              ? scheme.surfaceContainerHighest.withValues(alpha: 0.92)
              : scheme.surface.withValues(alpha: 0.95))
          : (isDark
              ? scheme.surfaceContainerHighest.withValues(alpha: 0.55)
              : Colors.white.withValues(alpha: 0.5));
      // 使用半透明色 + 阴影模拟玻璃质感, 无模糊开销
      child = DecoratedBox(
        decoration: BoxDecoration(
          color: effectiveGlassColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.white.withValues(alpha: 0.25),
            width: 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
              blurRadius: 6,
              spreadRadius: 0,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: SizedBox(
          width: size,
          height: size,
          child: Center(child: Icon(icon)),
        ),
      );
      child = InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: child,
      );
    } else {
      child = IconButton(
        icon: Icon(icon),
        onPressed: onTap,
      );
    }

    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: child);
    }
    return child;
  }
}
