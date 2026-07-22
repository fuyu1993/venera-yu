part of 'components.dart';

const _fastAnimationDuration = Duration(milliseconds: 160);

/// Shared decoration for home page cards: a subtle filled background with
/// a light theme-color border and soft shadow for depth.
BoxDecoration homeCardDecoration(BuildContext context) {
  final colorScheme = Theme.of(context).colorScheme;
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return BoxDecoration(
    color: isDark ? colorScheme.surfaceContainerHigh : colorScheme.surface,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(
      color: colorScheme.primary.withValues(alpha: isDark ? 0.2 : 0.05),
      width: 1,
    ),
    boxShadow: [
      BoxShadow(
        color: colorScheme.shadow.withValues(alpha: isDark ? 0.12 : 0.08),
        blurRadius: 20,
        offset: const Offset(0, 6),
      ),
      BoxShadow(
        color: colorScheme.shadow.withValues(alpha: isDark ? 0.06 : 0.03),
        blurRadius: 6,
        offset: const Offset(0, 2),
      ),
    ],
  );
}

/// A small theme-colored chip/tag used across the app (comic sources, tags,
/// badges, counts). Renders with a light tint of the user's selected theme
/// color as background and the theme color itself as text.
class TagChip extends StatelessWidget {
  const TagChip({
    super.key,
    required this.label,
    this.onTap,
    this.maxLines = 1,
    this.maxWidth,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    this.radius = 12,
  });

  final String label;
  final VoidCallback? onTap;
  final int maxLines;
  final double? maxWidth;
  final EdgeInsets padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Theme color background with contrasting text.
    final bg = colorScheme.primary;
    final fg = isDark ? Colors.black : Colors.white;

    Widget content = Text(
      label,
      style: ts.s12.copyWith(color: fg),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
    );

    if (maxWidth != null) {
      content = ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth!),
        child: content,
      );
    }

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: onTap != null
          ? InkWell(
              borderRadius: BorderRadius.circular(radius),
              onTap: onTap,
              child: content,
            )
          : content,
    );
  }
}