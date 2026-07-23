import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:venera/foundation/app.dart';
import 'package:venera/foundation/app_page_route.dart';
import 'package:venera/foundation/appdata.dart';

const String _kUiStyleCupertino = 'cupertino';
const String _kUiStyleMaterial = 'material';

/// 当前是否应使用 Cupertino 风格。
///
/// 优先级：
/// 1. 用户显式设置 `uiStyle == 'cupertino'` 或 `'material'`；
/// 2. 系统平台为 iOS / macOS 时默认使用 Cupertino；
/// 3. 其它平台默认使用 Material。
bool isCupertinoStyle() {
  final style = appdata.settings['uiStyle'] as String?;
  if (style == _kUiStyleCupertino) return true;
  if (style == _kUiStyleMaterial) return false;
  return App.isIOS || App.isMacOS;
}

/// 当前是否应使用 Material 风格。
bool isMaterialStyle() => !isCupertinoStyle();

/// 平台自适应页面路由。
///
/// iOS / macOS / 显式 Cupertino 模式下返回 [CupertinoPageRoute]，
/// 其它平台返回项目自定义的 [AppPageRoute]（保留预测返回与转场）。
Route<T> adaptivePageRoute<T>({
  required WidgetBuilder builder,
  RouteSettings? settings,
  bool fullscreenDialog = false,
  bool maintainState = true,
}) {
  if (isCupertinoStyle()) {
    return CupertinoPageRoute<T>(
      builder: builder,
      settings: settings,
      fullscreenDialog: fullscreenDialog,
      maintainState: maintainState,
    );
  }
  return AppPageRoute<T>(
    builder: builder,
    settings: settings,
    fullscreenDialog: fullscreenDialog,
    maintainState: maintainState,
  );
}

/// 由当前 Material [ColorScheme] 推导 Cupertino 主题数据，
/// 保证 iOS 风格页面与 Material 主题色一致。
CupertinoThemeData buildCupertinoTheme(
  ColorScheme scheme,
  Brightness brightness,
) {
  return CupertinoThemeData(
    brightness: brightness,
    primaryColor: scheme.primary,
    primaryContrastingColor: scheme.onPrimary,
    barBackgroundColor: scheme.surface,
    scaffoldBackgroundColor: scheme.surface,
    textTheme: CupertinoTextThemeData(
      primaryColor: scheme.primary,
      textStyle: TextStyle(
        color: scheme.onSurface,
        fontSize: 17,
        letterSpacing: -0.41,
      ),
      navTitleTextStyle: TextStyle(
        color: scheme.onSurface,
        fontSize: 17,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.41,
      ),
      navLargeTitleTextStyle: TextStyle(
        color: scheme.onSurface,
        fontSize: 34,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.37,
      ),
      pickerTextStyle: TextStyle(
        color: scheme.onSurface,
        fontSize: 17,
      ),
      dateTimePickerTextStyle: TextStyle(
        color: scheme.onSurface,
        fontSize: 17,
      ),
    ),
  );
}

/// 按平台选择图标。
IconData adaptiveIcon(IconData material, IconData cupertino) =>
    isCupertinoStyle() ? cupertino : material;

/// 自适应脚手架：Cupertino 下使用 [CupertinoPageScaffold]，
/// 其它平台使用 [Scaffold]。
class AdaptiveScaffold extends StatelessWidget {
  const AdaptiveScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.bottomNavigationBar,
    this.backgroundColor,
    this.resizeToAvoidBottomInset,
  });

  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? bottomNavigationBar;
  final Color? backgroundColor;
  final bool? resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) {
    if (isCupertinoStyle()) {
      return CupertinoPageScaffold(
        navigationBar: appBar is ObstructingPreferredSizeWidget
            ? appBar as ObstructingPreferredSizeWidget
            : null,
        backgroundColor:
            backgroundColor ?? CupertinoColors.systemBackground.resolveFrom(context),
        resizeToAvoidBottomInset: resizeToAvoidBottomInset ?? true,
        child: SafeArea(
          bottom: bottomNavigationBar == null,
          child: body,
        ),
      );
    }
    return Scaffold(
      appBar: appBar,
      body: body,
      bottomNavigationBar: bottomNavigationBar,
      backgroundColor: backgroundColor,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
    );
  }
}

/// 自适应应用栏。
///
/// Material 下返回 [AppBar]，Cupertino 下返回 [CupertinoNavigationBar]。
/// 注意：Cupertino 导航栏高度与 Material 不同，建议仅在 [AdaptiveScaffold.appBar]
/// 或 [CupertinoPageScaffold.navigationBar] 中使用。
class AdaptiveAppBar extends StatelessWidget implements PreferredSizeWidget {
  const AdaptiveAppBar({
    super.key,
    required this.title,
    this.leading,
    this.actions,
    this.backgroundColor,
    this.centerTitle,
    this.previousPageTitle,
    this.largeTitle = false,
  });

  final Widget title;
  final Widget? leading;
  final List<Widget>? actions;
  final Color? backgroundColor;
  final bool? centerTitle;
  final String? previousPageTitle;
  final bool largeTitle;

  @override
  Size get preferredSize => Size.fromHeight(isCupertinoStyle() ? 44 : 56);

  @override
  Widget build(BuildContext context) {
    if (isCupertinoStyle()) {
      final trailing =
          actions != null && actions!.isNotEmpty ? Row(mainAxisSize: MainAxisSize.min, children: actions!) : null;
      final bg = backgroundColor ??
          CupertinoColors.systemBackground.resolveFrom(context).withValues(alpha: 0.9);
      if (largeTitle) {
        return CupertinoNavigationBar.large(
          largeTitle: title,
          leading: leading,
          trailing: trailing,
          previousPageTitle: previousPageTitle,
          backgroundColor: bg,
          border: Border(
            bottom: BorderSide(
              color: CupertinoColors.separator.resolveFrom(context),
              width: 0.33,
            ),
          ),
        );
      }
      return CupertinoNavigationBar(
        middle: title,
        leading: leading,
        trailing: trailing,
        previousPageTitle: previousPageTitle,
        backgroundColor: bg,
        border: Border(
          bottom: BorderSide(
            color: CupertinoColors.separator.resolveFrom(context),
            width: 0.33,
          ),
        ),
      );
    }
    return AppBar(
      title: title,
      leading: leading,
      actions: actions,
      backgroundColor: backgroundColor,
      centerTitle: centerTitle,
    );
  }
}

/// 自适应列表瓦片。
class AdaptiveListTile extends StatelessWidget {
  const AdaptiveListTile({
    super.key,
    this.leading,
    this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.contentPadding,
  });

  final Widget? leading;
  final Widget? title;
  final Widget? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final EdgeInsets? contentPadding;

  @override
  Widget build(BuildContext context) {
    if (isCupertinoStyle()) {
      return CupertinoListTile(
        leading: leading,
        title: title ?? const SizedBox.shrink(),
        subtitle: subtitle,
        trailing: trailing,
        onTap: onTap,
        padding: contentPadding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      );
    }
    return ListTile(
      leading: leading,
      title: title,
      subtitle: subtitle,
      trailing: trailing,
      onTap: onTap,
      contentPadding: contentPadding,
    );
  }
}

/// 自适应搜索框。
///
/// Cupertino 下使用 [CupertinoSearchTextField]；Material 下使用 [TextField]
/// 并应用 Material 搜索样式。
class AdaptiveSearchBar extends StatelessWidget {
  const AdaptiveSearchBar({
    super.key,
    this.controller,
    this.focusNode,
    this.placeholder,
    this.onChanged,
    this.onSubmitted,
    this.padding,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? placeholder;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    if (isCupertinoStyle()) {
      return CupertinoSearchTextField(
        controller: controller,
        focusNode: focusNode,
        placeholder: placeholder,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        padding: padding ?? const EdgeInsets.all(8),
      );
    }
    return TextField(
      controller: controller,
      focusNode: focusNode,
      decoration: InputDecoration(
        hintText: placeholder,
        prefixIcon: const Icon(Icons.search),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        filled: true,
      ),
      onChanged: onChanged,
      onSubmitted: onSubmitted,
    );
  }
}
