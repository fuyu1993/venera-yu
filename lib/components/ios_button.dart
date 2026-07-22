part of 'components.dart';

/// iOS 风格按钮样式
enum IosButtonStyle {
  filled,    // 实心填充
  bordered,  // 边框
  plain,     // 纯文本
  tinted,    // 淡色填充
}

/// iOS 风格按钮大小
enum IosButtonSize {
  small(padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6), minSize: 32, borderRadius: 6, fontSize: 13),
  medium(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10), minSize: 44, borderRadius: 8, fontSize: 15),
  large(padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14), minSize: 50, borderRadius: 10, fontSize: 17);

  const IosButtonSize({
    required this.padding,
    required this.minSize,
    required this.borderRadius,
    required this.fontSize,
  });

  final EdgeInsets padding;
  final double minSize;
  final double borderRadius;
  final double fontSize;
}

/// iOS 风格按钮
class IosButton extends StatelessWidget {
  const IosButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.style = IosButtonStyle.filled,
    this.size = IosButtonSize.medium,
    this.isLoading = false,
    this.isDestructive = false,
    this.expand = false,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final IosButtonStyle style;
  final IosButtonSize size;
  final bool isLoading;
  final bool isDestructive;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final color = _getColor(context);
    final textColor = _getTextColor(context);

    Widget button;

    switch (style) {
      case IosButtonStyle.filled:
        button = CupertinoButton.filled(
          onPressed: isLoading ? null : onPressed,
          padding: size.padding,
          minSize: size.minSize,
          borderRadius: BorderRadius.circular(size.borderRadius),
          child: _buildChild(color: textColor),
        );
      case IosButtonStyle.bordered:
        button = CupertinoButton(
          onPressed: isLoading ? null : onPressed,
          padding: size.padding,
          minSize: size.minSize,
          borderRadius: BorderRadius.circular(size.borderRadius),
          color: color,
          child: _buildChild(color: textColor),
        );
      case IosButtonStyle.plain:
        button = CupertinoButton(
          onPressed: isLoading ? null : onPressed,
          padding: size.padding,
          minSize: size.minSize,
          borderRadius: BorderRadius.circular(size.borderRadius),
          color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
          child: _buildChild(color: textColor),
        );
      case IosButtonStyle.tinted:
        button = CupertinoButton(
          onPressed: isLoading ? null : onPressed,
          padding: size.padding,
          minSize: size.minSize,
          borderRadius: BorderRadius.circular(size.borderRadius),
          color: color.withOpacity(0.15),
          child: _buildChild(color: color),
        );
    }

    if (expand) {
      return SizedBox(width: double.infinity, child: button);
    }
    return button;
  }

  Widget _buildChild({Color? color}) {
    if (isLoading) {
      return SizedBox(
        width: 16,
        height: 16,
        child: CupertinoActivityIndicator(color: color),
      );
    }
    return DefaultTextStyle(
      style: TextStyle(
        fontSize: size.fontSize,
        fontWeight: FontWeight.w600,
        color: color,
      ),
      child: child,
    );
  }

  Color _getColor(BuildContext context) {
    if (isDestructive) {
      return CupertinoColors.systemRed.resolveFrom(context);
    }
    return CupertinoColors.systemBlue.resolveFrom(context);
  }

  Color _getTextColor(BuildContext context) {
    if (isDestructive) {
      return Colors.white;
    }
    switch (style) {
      case IosButtonStyle.filled:
      case IosButtonStyle.bordered:
        return Colors.white;
      case IosButtonStyle.plain:
      case IosButtonStyle.tinted:
        return CupertinoColors.systemBlue.resolveFrom(context);
    }
  }
}

/// iOS 风格图标按钮
class IosIconButton extends StatelessWidget {
  const IosIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.size = 44,
    this.iconSize = 22,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final double iconSize;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      minSize: size,
      borderRadius: BorderRadius.circular(size / 2),
      color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
      child: Icon(
        icon,
        size: iconSize,
        color: CupertinoColors.systemBlue.resolveFrom(context),
      ),
    );
  }
}

/// iOS 风格文本按钮
class IosTextButton extends StatelessWidget {
  const IosTextButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.isDestructive = false,
    this.isLoading = false,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final bool isDestructive;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      onPressed: isLoading ? null : onPressed,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: isLoading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CupertinoActivityIndicator(),
            )
          : DefaultTextStyle(
              style: TextStyle(
                fontSize: 17,
                color: isDestructive
                    ? CupertinoColors.systemRed.resolveFrom(context)
                    : CupertinoColors.systemBlue.resolveFrom(context),
              ),
              child: child,
            ),
    );
  }
}
