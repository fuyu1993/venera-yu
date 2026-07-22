part of 'components.dart';

/// iOS 风格导航栏
class IosNavigationBar extends StatelessWidget implements ObstructingPreferredSizeWidget {
  const IosNavigationBar({
    super.key,
    this.title,
    this.leading,
    this.trailing,
    this.largeTitle = false,
    this.previousTitle,
    this.backgroundColor,
    this.actions = const [],
  });

  final String? title;
  final Widget? leading;
  final Widget? trailing;
  final bool largeTitle;
  final String? previousTitle;
  final Color? backgroundColor;
  final List<Widget> actions;

  @override
  Size get preferredSize => Size.fromHeight(largeTitle ? 96 : 44);

  @override
  bool shouldFullyObstruct(BuildContext context) => true;

  @override
  Widget build(BuildContext context) {
    final bgColor = backgroundColor ??
        CupertinoColors.systemBackground.resolveFrom(context).withOpacity(0.9);

    if (largeTitle) {
      return CupertinoNavigationBar.large(
        largeTitle: Text(
          title ?? '',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: leading,
        trailing: trailing ?? (actions.isNotEmpty ? Row(mainAxisSize: MainAxisSize.min, children: actions) : null),
        previousPageTitle: previousTitle,
        backgroundColor: bgColor,
        border: Border(
          bottom: BorderSide(
            color: CupertinoColors.separator.resolveFrom(context),
            width: 0.33,
          ),
        ),
      );
    }

    return CupertinoNavigationBar(
      middle: title != null
          ? Text(
              title!,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            )
          : null,
      leading: leading,
      trailing: trailing ?? (actions.isNotEmpty ? Row(mainAxisSize: MainAxisSize.min, children: actions) : null),
      previousPageTitle: previousTitle,
      backgroundColor: bgColor,
      border: Border(
        bottom: BorderSide(
          color: CupertinoColors.separator.resolveFrom(context),
          width: 0.33,
        ),
      ),
    );
  }
}

/// iOS 风格页面脚手架
class IosPageScaffold extends StatelessWidget {
  const IosPageScaffold({
    super.key,
    required this.title,
    required this.child,
    this.largeTitle = false,
    this.leading,
    this.trailing,
    this.actions = const [],
    this.previousTitle,
    this.backgroundColor,
    this.scrollController,
  });

  final String title;
  final Widget child;
  final bool largeTitle;
  final Widget? leading;
  final Widget? trailing;
  final List<Widget> actions;
  final String? previousTitle;
  final Color? backgroundColor;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: IosNavigationBar(
        title: title,
        largeTitle: largeTitle,
        leading: leading,
        trailing: trailing,
        actions: actions,
        previousTitle: previousTitle,
        backgroundColor: backgroundColor,
      ),
      backgroundColor: backgroundColor ?? CupertinoColors.systemGroupedBackground.resolveFrom(context),
      child: SafeArea(
        child: scrollController != null
            ? child
            : ListView(
                controller: scrollController,
                children: [child],
              ),
      ),
    );
  }
}
