import 'package:flex_seed_scheme/flex_seed_scheme.dart';
import 'package:flutter/material.dart';
import 'package:venera/foundation/app.dart';
import 'package:venera/foundation/appdata.dart';
import 'package:venera/foundation/design_tokens.dart';

/// 主题配置。合并后的单一真源：
/// - 颜色由 M3 seed（[SeedColorScheme.fromSeeds]）派生，支持 9 预设色与系统动态取色；
/// - 组件样式（字体/卡片/按钮/输入/对话框/导航）保留 iOS 风格；
/// - 暗色支持 AMOLED 纯黑档位；
/// - UI 密度由 [UiDensity] 设置项驱动。
class AppTheme {
  // ========== 主题色 ==========
  static const Color iosBlue = Color(0xFF3B82F6);
  static const Color iosGreen = Color(0xFF10B981);
  static const Color iosRed = Color(0xFFEF4444);
  static const Color iosOrange = Color(0xFFF59E0B);
  static const Color iosYellow = Color(0xFFEAB308);
  static const Color iosPurple = Color(0xFF8B5CF6);
  static const Color iosTeal = Color(0xFF14B8A6);
  static const Color iosPink = Color(0xFFEC4899);
  static const Color iosIndigo = Color(0xFF6366F1);

  // iOS 灰色系
  static const Color iosGray = Color(0xFF8E8E93);
  static const Color iosGray2 = Color(0xFFAEAEB2);
  static const Color iosGray3 = Color(0xFFC7C7CC);
  static const Color iosGray4 = Color(0xFFD1D1D6);
  static const Color iosGray5 = Color(0xFFE5E5EA);
  static const Color iosGray6 = Color(0xFFF2F2F7);

  // iOS 背景色
  static const Color iosBackground = Color(0xFFF2F2F7);
  static const Color iosGroupedBackground = Color(0xFFF2F2F7);
  static const Color iosCardBackground = Color(0xFFFFFFFF);

  // iOS 文字颜色（使用半透明色，更符合 iOS 风格）
  static const Color iosLabel = Color(0xFF000000);
  static const Color iosSecondaryLabel = Color(0x993C3C43); // 60% 不透明度
  static const Color iosTertiaryLabel = Color(0x4D3C3C43); // 30% 不透明度
  static const Color iosQuaternaryLabel = Color(0x2E3C3C43); // 18% 不透明度

  // iOS 分隔线
  static const Color iosSeparator = Color(0xFFC6C6C8);
  static const Color iosOpaqueSeparator = Color(0xFFC6C6C8);

  // ========== iOS 风格文本样式 ==========
  static const TextStyle iosLargeTitle = TextStyle(
    fontSize: 34,
    fontWeight: FontWeight.bold,
    letterSpacing: 0.37,
    color: iosLabel,
  );

  static const TextStyle iosTitle1 = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.36,
    color: iosLabel,
  );

  static const TextStyle iosTitle2 = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.35,
    color: iosLabel,
  );

  static const TextStyle iosTitle3 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.38,
    color: iosLabel,
  );

  static const TextStyle iosHeadline = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.41,
    color: iosLabel,
  );

  static const TextStyle iosBody = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.41,
    color: iosLabel,
  );

  static const TextStyle iosCallout = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.32,
    color: iosLabel,
  );

  static const TextStyle iosSubheadline = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.24,
    color: iosLabel,
  );

  static const TextStyle iosFootnote = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.08,
    color: iosLabel,
  );

  static const TextStyle iosCaption1 = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.0,
    color: iosLabel,
  );

  static const TextStyle iosCaption2 = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.07,
    color: iosLabel,
  );

  // ========== 预设主题颜色 ==========
  static const Map<String, Color> presetColors = {
    'system': iosBlue,
    'red': Color(0xFFEF4444),
    'pink': Color(0xFFEC4899),
    'purple': Color(0xFF8B5CF6),
    'green': Color(0xFF10B981),
    'orange': Color(0xFFF59E0B),
    'blue': Color(0xFF3B82F6),
    'yellow': Color(0xFFEAB308),
    'cyan': Color(0xFF14B8A6),
    'indigo': Color(0xFF6366F1),
  };

  // ========== 根据设置获取主题（合并后单一入口） ==========
  /// 颜色由 M3 seed 派生；当 [colorKey]=='system' 且提供动态色时使用系统动态色。
  /// [dynamicPrimary/Secondary/Tertiary] 来自 DynamicColorBuilder，仅 system 模式生效。
  static ThemeData getThemeBySettings(
    String colorKey,
    Brightness brightness, {
    Color? dynamicPrimary,
    Color? dynamicSecondary,
    Color? dynamicTertiary,
  }) {
    final isDark = brightness == Brightness.dark;
    final bool useDynamic = colorKey == 'system' && dynamicPrimary != null;
    final Color primary =
        useDynamic ? dynamicPrimary : (presetColors[colorKey] ?? iosBlue);
    final Color secondary =
        useDynamic && dynamicSecondary != null ? dynamicSecondary : primary;
    final Color tertiary =
        useDynamic && dynamicTertiary != null ? dynamicTertiary : iosPurple;
    final amoled = isDark && appdata.settings['amoledDark'] == true;
    final density =
        UiDensity.fromKey(appdata.settings['uiDensity'] as String?);
    return _buildTheme(
      primary: primary,
      secondary: secondary,
      tertiary: tertiary,
      brightness: brightness,
      amoled: amoled,
      density: density,
    );
  }

  static ThemeData _buildTheme({
    required Color primary,
    required Color secondary,
    required Color tertiary,
    required Brightness brightness,
    required bool amoled,
    required UiDensity density,
  }) {
    final isDark = brightness == Brightness.dark;
    var scheme = SeedColorScheme.fromSeeds(
      primaryKey: primary,
      secondaryKey: secondary,
      tertiaryKey: tertiary,
      brightness: brightness,
      tones: FlexTones.vividBackground(brightness),
    );
    if (amoled) {
      scheme = scheme.copyWith(
        surface: Colors.black,
        surfaceContainerLowest: Colors.black,
        surfaceContainerLow: const Color(0xFF050505),
        surfaceContainer: const Color(0xFF0A0A0A),
        surfaceContainerHigh: const Color(0xFF0F0F0F),
        surfaceContainerHighest: const Color(0xFF141414),
      );
    }
    final cardColor = isDark
        ? (amoled ? const Color(0xFF0A0A0A) : const Color(0xFF1C1C1E))
        : iosCardBackground;
    final scaffoldBg = isDark ? Colors.black : iosGroupedBackground;
    final onColor = isDark ? Colors.white : iosLabel;
    final dividerColor = isDark ? const Color(0xFF38383A) : iosSeparator;

    final textTheme = isDark
        ? TextTheme(
            displayLarge: iosLargeTitle.copyWith(color: Colors.white),
            displayMedium: iosTitle1.copyWith(color: Colors.white),
            displaySmall: iosTitle2.copyWith(color: Colors.white),
            headlineLarge: iosTitle2.copyWith(color: Colors.white),
            headlineMedium: iosTitle3.copyWith(color: Colors.white),
            headlineSmall: iosHeadline.copyWith(color: Colors.white),
            titleLarge: iosHeadline.copyWith(color: Colors.white),
            titleMedium: iosSubheadline.copyWith(color: Colors.white),
            titleSmall: iosFootnote.copyWith(color: Colors.white),
            bodyLarge: iosBody.copyWith(color: Colors.white),
            bodyMedium: iosCallout.copyWith(color: Colors.white),
            bodySmall: iosFootnote.copyWith(color: Colors.white),
            labelLarge: iosSubheadline.copyWith(color: Colors.white),
            labelMedium: iosFootnote.copyWith(color: Colors.white),
            labelSmall: iosCaption1.copyWith(color: Colors.white),
          )
        : const TextTheme(
            displayLarge: iosLargeTitle,
            displayMedium: iosTitle1,
            displaySmall: iosTitle2,
            headlineLarge: iosTitle2,
            headlineMedium: iosTitle3,
            headlineSmall: iosHeadline,
            titleLarge: iosHeadline,
            titleMedium: iosSubheadline,
            titleSmall: iosFootnote,
            bodyLarge: iosBody,
            bodyMedium: iosCallout,
            bodySmall: iosFootnote,
            labelLarge: iosSubheadline,
            labelMedium: iosFootnote,
            labelSmall: iosCaption1,
          );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      visualDensity: density.visualDensity,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffoldBg,
      cardColor: cardColor,
      dividerColor: scheme.outlineVariant,
      fontFamily: _getFontFamily(),
      fontFamilyFallback: _getFontFallback(),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: scaffoldBg,
        foregroundColor: onColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: iosHeadline.copyWith(color: onColor),
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        titleTextStyle: iosBody.copyWith(color: onColor),
        subtitleTextStyle: iosFootnote.copyWith(color: onColor),
        iconColor: primary,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          textStyle: iosSubheadline.copyWith(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: BorderSide(color: primary.withValues(alpha: 0.5)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: dividerColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: dividerColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: primary),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        titleTextStyle: iosHeadline.copyWith(color: onColor),
        contentTextStyle: iosBody.copyWith(color: onColor),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: cardColor,
        selectedItemColor: primary,
        unselectedItemColor: iosGray,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: iosCaption1.copyWith(color: primary),
        unselectedLabelStyle: iosCaption1.copyWith(color: iosGray),
      ),
    );
  }

  // ========== 字体配置 ==========
  static String? _getFontFamily() {
    if (App.isLinux || App.isWindows) {
      return 'Noto Sans CJK';
    }
    return null; // iOS/macOS 使用系统字体
  }

  static List<String> _getFontFallback() {
    if (App.isLinux || App.isWindows) {
      return [
        'Segoe UI',
        'Noto Sans SC',
        'Noto Sans TC',
        'Noto Sans',
        'Microsoft YaHei',
        'PingFang SC',
        'Arial',
        'sans-serif',
      ];
    }
    return ['PingFang SC', 'Helvetica Neue', 'Arial'];
  }

  // 兼容旧引用
  static ThemeData get lightTheme =>
      getThemeBySettings('blue', Brightness.light);
  static ThemeData get darkTheme => getThemeBySettings('blue', Brightness.dark);
}
