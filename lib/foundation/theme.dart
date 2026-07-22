import 'package:flutter/material.dart';
import 'package:venera/foundation/app.dart';

/// iOS 风格主题配置
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
  static const Color iosSecondaryLabel = Color(0x993C3C43);  // 60% 不透明度
  static const Color iosTertiaryLabel = Color(0x4D3C3C43);   // 30% 不透明度
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

  // ========== 根据设置获取主题 ==========
  static ThemeData getThemeBySettings(String colorKey, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final primaryColor = presetColors[colorKey] ?? iosBlue;

    return isDark ? _buildDarkTheme(primaryColor) : _buildLightTheme(primaryColor);
  }

  // ========== iOS 风格主题数据 ==========
  static ThemeData get lightTheme {
    return _buildLightTheme(iosBlue);
  }

  static ThemeData get darkTheme {
    return _buildDarkTheme(iosBlue);
  }

  static ThemeData _buildLightTheme(Color primary) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primary,
      scaffoldBackgroundColor: iosGroupedBackground,
      cardColor: iosCardBackground,
      dividerColor: iosSeparator,
      // 字体配置
      fontFamily: _getFontFamily(),
      fontFamilyFallback: _getFontFallback(),
      // 文本主题
      textTheme: const TextTheme(
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
      ),
      // 颜色方案
      colorScheme: ColorScheme.light(
        primary: primary,
        secondary: iosGray,
        tertiary: iosPurple,
        surface: iosCardBackground,
        background: iosGroupedBackground,
        error: iosRed,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onTertiary: Colors.white,
        onSurface: iosLabel,
        onBackground: iosLabel,
        onError: Colors.white,
        outline: iosSeparator,
        shadow: Colors.black.withOpacity(0.1),
      ),
      // AppBar 主题
      appBarTheme: const AppBarTheme(
        backgroundColor: iosGroupedBackground,
        foregroundColor: iosLabel,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: iosHeadline,
      ),
      // 卡片主题
      cardTheme: CardThemeData(
        color: iosCardBackground,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      // 列表瓦片主题
      listTileTheme: ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        titleTextStyle: iosBody,
        subtitleTextStyle: iosFootnote,
        iconColor: primary,
      ),
      // 按钮主题
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: iosBlue,
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
          backgroundColor: iosBlue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: iosBlue,
          side: BorderSide(color: iosBlue.withOpacity(0.5)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: iosBlue,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
      ),
      // 输入框主题
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: iosCardBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: iosSeparator),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: iosSeparator),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: iosBlue),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      // 对话框主题
      dialogTheme: DialogThemeData(
        backgroundColor: iosCardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        titleTextStyle: iosHeadline,
        contentTextStyle: iosBody,
      ),
      // 底部导航栏主题
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: iosCardBackground,
        selectedItemColor: iosBlue,
        unselectedItemColor: iosGray,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: iosCaption1.copyWith(color: iosBlue),
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

  static ThemeData _buildDarkTheme(Color primary) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primary,
      scaffoldBackgroundColor: Colors.black,
      cardColor: const Color(0xFF1C1C1E),
      dividerColor: const Color(0xFF38383A),
      fontFamily: _getFontFamily(),
      fontFamilyFallback: _getFontFallback(),
      textTheme: TextTheme(
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
      ),
      colorScheme: ColorScheme.dark(
        primary: primary,
        secondary: iosGray,
        tertiary: iosPurple,
        surface: const Color(0xFF1C1C1E),
        background: Colors.black,
        error: iosRed,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onTertiary: Colors.white,
        onSurface: Colors.white,
        onBackground: Colors.white,
        onError: Colors.white,
        outline: const Color(0xFF38383A),
        shadow: Colors.black.withOpacity(0.3),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: iosHeadline.copyWith(color: Colors.white),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF1C1C1E),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        titleTextStyle: iosBody.copyWith(color: Colors.white),
        subtitleTextStyle: iosFootnote.copyWith(color: Colors.white),
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
          side: BorderSide(color: primary.withOpacity(0.5)),
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
        fillColor: const Color(0xFF1C1C1E),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: const Color(0xFF38383A)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: const Color(0xFF38383A)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: primary),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        titleTextStyle: iosHeadline.copyWith(color: Colors.white),
        contentTextStyle: iosBody.copyWith(color: Colors.white),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: const Color(0xFF1C1C1E),
        selectedItemColor: primary,
        unselectedItemColor: iosGray,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: iosCaption1.copyWith(color: primary),
        unselectedLabelStyle: iosCaption1.copyWith(color: iosGray),
      ),
    );
  }
}
