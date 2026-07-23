import 'package:flutter/material.dart';

/// Design tokens — 单一真源，供组件统一引用，告别散落的魔法数。
///
/// 间距 / 圆角 / 高度 / 封面比例 等尺寸常量集中在此。颜色与字号阶由
/// [AppTheme]（M3 seed ColorScheme + iOS 文本样式）提供。
abstract final class AppSpacing {
  /// 4
  static const double xs = 4;
  /// 8
  static const double sm = 8;
  /// 12
  static const double md = 12;
  /// 16
  static const double lg = 16;
  /// 24
  static const double xl = 24;
}

abstract final class AppRadius {
  /// 8 — 封面、小卡片
  static const double sm = 8;
  /// 12 — 卡片、容器
  static const double md = 12;
  /// 16 — 大容器、对话框外层
  static const double lg = 16;
}

abstract final class AppElevation {
  static const double none = 0;
  static const double low = 1;
  static const double medium = 2;
  static const double high = 4;
}

/// 封面卡片相关令牌，供 brief / detailed / SimpleComicTile 三种视图共用，
/// 保证比例、圆角、底色一致。
abstract final class ComicCoverTokens {
  /// 封面宽高比（宽 / 高）
  static const double aspectRatio = 0.72;

  /// 封面圆角
  static const double radius = AppRadius.sm;

  /// 封面圆角（与 [radius] 同值，显式语义）
  static const BorderRadius borderRadius = BorderRadius.all(
    Radius.circular(radius),
  );
}

/// UI 密度档位。映射 ThemeData.visualDensity 与 MediaQuery.textScaler。
enum UiDensity {
  compact('compact', VisualDensity.compact, 0.9),
  standard('standard', VisualDensity.standard, 1.0),
  comfortable('comfortable', VisualDensity.comfortable, 1.1);

  final String key;
  final VisualDensity visualDensity;
  final double textScaleFactor;

  const UiDensity(this.key, this.visualDensity, this.textScaleFactor);

  static UiDensity fromKey(String? key) {
    return switch (key) {
      'compact' => UiDensity.compact,
      'comfortable' => UiDensity.comfortable,
      _ => UiDensity.standard,
    };
  }
}
