import 'package:flutter/material.dart';
import 'package:venera/components/components.dart';

import 'app_page_route.dart';

/// Minimum interval between two page-push navigations. Rapid repeated taps
/// (e.g. double-tapping a comic cover or a history item) would otherwise push
/// the same page twice, which previously caused issues such as opening the
/// reader twice or replaying a stale remote entry. Any [to] / [toReplacement]
/// call within this window after a successful push is ignored.
const Duration _navDebounceWindow = Duration(milliseconds: 350);

DateTime? _lastNavPushAt;

/// Returns `true` if a navigation is allowed now. Implements a leading-edge
/// debounce: the first push in a burst is allowed and records its timestamp;
/// subsequent pushes within [_navDebounceWindow] are rejected (and do NOT
/// reset the timer, so the burst cannot silently block later legitimate taps).
bool _canNavigate() {
  final now = DateTime.now();
  if (_lastNavPushAt != null &&
      now.difference(_lastNavPushAt!) < _navDebounceWindow) {
    return false;
  }
  _lastNavPushAt = now;
  return true;
}

extension Navigation on BuildContext {
  void pop<T>([T? result]) {
    if(mounted) {
      Navigator.of(this).pop(result);
    }
  }

  bool canPop() {
    return Navigator.of(this).canPop();
  }

  Future<T?> to<T>(Widget Function() builder,) {
    if (!_canNavigate()) {
      return Future<T?>.value(null);
    }
    return Navigator.of(this).push<T>(AppPageRoute(
        builder: (context) => builder()));
  }

  Future<void> toReplacement<T>(Widget Function() builder) {
    if (!_canNavigate()) {
      return Future<void>.value();
    }
    return Navigator.of(this).pushReplacement(AppPageRoute(
        builder: (context) => builder()));
  }

  double get width => MediaQuery.of(this).size.width;

  double get height => MediaQuery.of(this).size.height;

  EdgeInsets get padding => MediaQuery.of(this).padding;

  EdgeInsets get viewInsets => MediaQuery.of(this).viewInsets;

  ColorScheme get colorScheme => Theme.of(this).colorScheme;

  Brightness get brightness => Theme.of(this).brightness;

  bool get isDarkMode => brightness == Brightness.dark;

  void showMessage({required String message}) {
    showToast(message: message, context: this);
  }

  Color useBackgroundColor(MaterialColor color) {
    return color[brightness == Brightness.light ? 100 : 800]!;
  }

  Color useTextColor(MaterialColor color) {
    return color[brightness == Brightness.light ? 800 : 100]!;
  }
}
