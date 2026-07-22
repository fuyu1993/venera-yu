part of 'components.dart';

/// iOS 风格列表瓦片
class IosListTile extends StatelessWidget {
  const IosListTile({
    super.key,
    this.leading,
    this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.showChevron = true,
    this.leadingSize = 29,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    this.backgroundColor,
  });

  final Widget? leading;
  final Widget? title;
  final Widget? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showChevron;
  final double leadingSize;
  final EdgeInsets padding;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? CupertinoColors.systemBackground.resolveFrom(context),
        border: Border(
          bottom: BorderSide(
            color: CupertinoColors.separator.resolveFrom(context),
            width: 0.33,
          ),
        ),
      ),
      child: CupertinoListTile(
        leading: leading != null
            ? SizedBox(
                width: leadingSize,
                height: leadingSize,
                child: leading,
              )
          : null,
        title: title ?? const SizedBox.shrink(),
        subtitle: subtitle,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (trailing != null) trailing!,
            if (showChevron)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Icon(
                  CupertinoIcons.chevron_right,
                  size: 18,
                  color: CupertinoColors.tertiaryLabel.resolveFrom(context),
                ),
              ),
          ],
        ),
        onTap: onTap,
        padding: padding,
      ),
    );
  }
}

/// iOS 风格分组列表
class IosGroupedList extends StatelessWidget {
  const IosGroupedList({
    super.key,
    this.header,
    this.footer,
    required this.children,
    this.margin = const EdgeInsets.symmetric(horizontal: 16),
    this.borderRadius = 12,
  });

  final Widget? header;
  final Widget? footer;
  final List<Widget> children;
  final EdgeInsets margin;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (header != null)
            Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 8),
              child: DefaultTextStyle(
                style: TextStyle(
                  fontSize: 13,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  fontWeight: FontWeight.w400,
                ),
                child: header!,
              ),
            ),
          ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: Container(
              decoration: BoxDecoration(
                color: CupertinoColors.systemBackground.resolveFrom(context),
                borderRadius: BorderRadius.circular(borderRadius),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: _addSeparators(context, children),
              ),
            ),
          ),
          if (footer != null)
            Padding(
              padding: const EdgeInsets.only(left: 16, top: 8),
              child: DefaultTextStyle(
                style: TextStyle(
                  fontSize: 13,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
                child: footer!,
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _addSeparators(BuildContext context, List<Widget> children) {
    if (children.isEmpty) return children;
    final result = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      result.add(children[i]);
      if (i < children.length - 1) {
        result.add(
          Container(
            height: 0.33,
            margin: const EdgeInsets.only(left: 16),
            color: CupertinoColors.separator.resolveFrom(context),
          ),
        );
      }
    }
    return result;
  }
}

/// iOS 风格开关瓦片
class IosSwitchTile extends StatelessWidget {
  const IosSwitchTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return IosListTile(
      leading: leading,
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      trailing: CupertinoSwitch(
        value: value,
        onChanged: onChanged,
      ),
      showChevron: false,
    );
  }
}

/// iOS 风格选择瓦片
class IosSelectTile extends StatelessWidget {
  const IosSelectTile({
    super.key,
    required this.title,
    required this.value,
    this.leading,
    required this.onTap,
  });

  final String title;
  final String value;
  final Widget? leading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IosListTile(
      leading: leading,
      title: Text(title),
      trailing: Text(
        value,
        style: TextStyle(
          fontSize: 17,
          color: CupertinoColors.secondaryLabel.resolveFrom(context),
        ),
      ),
      onTap: onTap,
    );
  }
}
