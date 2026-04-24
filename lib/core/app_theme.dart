import 'package:flutter/material.dart';

class AppTheme {
  // Light Theme Palette
  static const Color scaffoldBackgroundColorLight = Color(0xFFF9FAFB);
  static const Color textColorLight = Color(0xFF111827);
  static const Color dividerColorLight = Color(0xFFE5E7EB);
  static const Color primaryColorLight = Color(0xFF4F46E5);
  static const Color cardColorLight = Color(0xFFFFFFFF);

  // Dark Theme Palette
  static const Color scaffoldBackgroundColorDark = Color(0xFF0B0F1A);
  static const Color textColorDark = Color(0xFFF1F5F9);
  static const Color dividerColorDark = Color(0xFF1E293B);
  static const Color primaryColorDark = Color(0xFF818CF8);
  static const Color cardColorDark = Color(0xFF1A1B1D);
  static const Color inputBackgroundColorDark = Color(0xFF242628);

  // Fallback fonts for multi-platform Chinese support
  static const List<String> fontFamilyFallback = [
    'SF Pro Text',
    'Segoe WPC',
    'Segoe UI',
    'Microsoft YaHei',
    'sans-serif',
    'PingFang SC',
    'Heiti SC',
    'WenQuanYi Micro Hei',
  ];

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      fontFamily: 'Inter',
      fontFamilyFallback: fontFamilyFallback,
      primaryColor: primaryColorDark,
      scaffoldBackgroundColor: scaffoldBackgroundColorDark,
      canvasColor: cardColorDark,
      cardTheme: const CardThemeData(
        color: cardColorDark,
        elevation: 0,
        margin: EdgeInsets.zero,
      ),
      splashFactory: NoSplash.splashFactory,
      hoverColor: primaryColorDark.withValues(alpha: 0.05),
      scrollbarTheme: ScrollbarThemeData(
        thickness: WidgetStateProperty.all(6),
        radius: const Radius.circular(10),
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.dragged)) {
            return const Color(0xFF5C5C5D);
          }
          if (states.contains(WidgetState.hovered)) {
            return const Color(0xFF4E4E4F);
          }
          return const Color(0xFF404041);
        }),
        thumbVisibility: WidgetStateProperty.all(false),
      ),
      colorScheme: const ColorScheme.dark(
        primary: primaryColorDark,
        secondary: primaryColorDark,
        surface: cardColorDark,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: scaffoldBackgroundColorDark,
        elevation: 0,
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: textColorDark),
        bodyMedium: TextStyle(color: textColorDark),
        titleMedium: TextStyle(color: textColorDark),
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: textColorDark,
      ),
      dividerColor: dividerColorDark,
      dividerTheme: const DividerThemeData(
          thickness: 1, space: 1, color: dividerColorDark),
      popupMenuTheme: PopupMenuThemeData(
        color: const Color(0xFF202123),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: const BorderSide(color: Color(0xFF313236), width: 1),
        ),
        textStyle: const TextStyle(
            fontSize: 12, fontWeight: FontWeight.normal, color: textColorDark),
        labelTextStyle: WidgetStateProperty.all(const TextStyle(
            fontSize: 12, fontWeight: FontWeight.normal, color: textColorDark)),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: const Color(0xFF202123),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0xFF313236), width: 1),
        ),
        textStyle: const TextStyle(color: textColorDark, fontSize: 12),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFF202123),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Color(0xFF313236), width: 1),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          overlayColor: WidgetStateProperty.all(Colors.transparent),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputBackgroundColorDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: const BorderSide(color: dividerColorDark, width: 1.0),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: const BorderSide(color: dividerColorDark, width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: const BorderSide(color: primaryColorDark, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: primaryColorDark,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
        ),
      ),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      fontFamily: 'Inter',
      fontFamilyFallback: fontFamilyFallback,
      primaryColor: primaryColorLight,
      scaffoldBackgroundColor: scaffoldBackgroundColorLight,
      canvasColor: cardColorLight,
      cardTheme: const CardThemeData(
        color: cardColorLight,
        elevation: 0,
        margin: EdgeInsets.zero,
      ),
      splashFactory: NoSplash.splashFactory,
      hoverColor: primaryColorLight.withValues(alpha: 0.05),
      scrollbarTheme: ScrollbarThemeData(
        thickness: WidgetStateProperty.all(6),
        radius: const Radius.circular(10),
        thumbColor: WidgetStateProperty.all(const Color(0xFFE5E7EB)),
        thumbVisibility: WidgetStateProperty.all(false),
      ),
      colorScheme: const ColorScheme.light(
        primary: primaryColorLight,
        secondary: primaryColorLight,
        surface: cardColorLight,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: scaffoldBackgroundColorLight,
        elevation: 0,
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: textColorLight),
        bodyMedium: TextStyle(color: textColorLight),
        titleMedium: TextStyle(color: textColorLight),
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: textColorLight,
      ),
      dividerColor: dividerColorLight,
      dividerTheme: const DividerThemeData(
          thickness: 1, space: 1, color: dividerColorLight),
      popupMenuTheme: PopupMenuThemeData(
        color: cardColorLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: const BorderSide(color: Color(0xFFE9EDF1), width: 1),
        ),
        textStyle: const TextStyle(
            fontSize: 12, fontWeight: FontWeight.normal, color: textColorLight),
        labelTextStyle: WidgetStateProperty.all(const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.normal,
            color: textColorLight)),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: cardColorLight,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0xFFE9EDF1), width: 1),
        ),
        textStyle: const TextStyle(color: textColorLight, fontSize: 12),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: cardColorLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Color(0xFFE9EDF1), width: 1),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          overlayColor: WidgetStateProperty.all(Colors.transparent),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: const BorderSide(color: dividerColorLight, width: 1.0),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: const BorderSide(color: dividerColorLight, width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: const BorderSide(color: primaryColorLight, width: 1.0),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: primaryColorLight,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
        ),
      ),
    );
  }
}
