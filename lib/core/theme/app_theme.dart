import 'package:flutter/material.dart';
import 'package:month_year_picker/month_year_picker.dart';

class AppTheme {
  AppTheme._();

  // Color System
  static const Color ink = Color(0xFF1E2A3B);
  static const Color primary = Color(0xFF2F6BFF);
  static const Color softBg = Color(0xFFF6F8FB);
  static const Color border = Color(0xFFE6EDF6);

  static Future<DateTime?> pickMonthYear(
    BuildContext context, {
    required DateTime initialDate,
    DateTime? firstDate,
    DateTime? lastDate,
    double textScale = 0.94,
  }) {
    return showMonthYearPicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate ?? DateTime(2020),
      lastDate: lastDate ?? DateTime(2035),
      builder: (context, child) {
        final base = Theme.of(context);
        final mq = MediaQuery.of(context);

        return Theme(
          data: base.copyWith(
            colorScheme: base.colorScheme.copyWith(
              // ✅ 헤더: 연한 블루
              primary: primary.withOpacity(0.12),
              onPrimary: ink,

              // ✅ 선택된 월(동그라미): primary (너무 쨍하면 opacity로 줄여)
              secondary: primary, // or primary.withOpacity(0.85)
              onSecondary: Colors.white,

              surface: Colors.white,
              onSurface: ink,
            ),
            dialogTheme: base.dialogTheme.copyWith(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: primary,
                textStyle: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
          child: MediaQuery(
            data: mq.copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
        );
      },
    );
  }

  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
    ).copyWith(
      primary: primary,
      surface: Colors.white,
      onSurface: ink,
    );

    final outlineNone = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    );

    final outlineFocus = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: primary, width: 1.2),
    );

    final outlineError = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Colors.redAccent, width: 1.1),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,

      scaffoldBackgroundColor: Colors.white,

      // ✅ AppBar 기본 스타일
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: ink),
        titleTextStyle: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 18,
          color: ink,
        ),
      ),

      // ✅ 텍스트 톤
      textTheme: const TextTheme(
        titleLarge: TextStyle(
          fontWeight: FontWeight.w800,
          color: ink,
        ),
        bodyMedium: TextStyle(color: ink),
        bodySmall: TextStyle(color: ink),
      ),

      // ✅ Divider
      dividerTheme: const DividerThemeData(
        color: border,
        thickness: 1,
        space: 1,
      ),

      // ✅ Card (HomeCard 느낌)
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: border),
        ),
      ),

      // ✅ ProgressIndicator
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primary,
      ),

      // ✅ SnackBar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: ink,
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),

      // ✅ TextButton (링크 버튼)
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        ),
      ),

      // ✅ ElevatedButton (주요 액션 버튼)
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          textStyle: const TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ).copyWith(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) return primary.withOpacity(0.45);
            return primary;
          }),
        ),
      ),

      // ✅ OutlinedButton (보조 액션 버튼: 취소/닫기/뒤로)
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
          side: const BorderSide(color: border, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ).copyWith(
          // disabled
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) return ink.withOpacity(0.35);
            return ink;
          }),
          side: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return BorderSide(color: border.withOpacity(0.7), width: 1);
            }
            return const BorderSide(color: border, width: 1);
          }),
        ),
      ),

      // ✅ Dialog 전체 톤
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        titleTextStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w900,
          color: ink,
        ),
        contentTextStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: ink,
          height: 1.35,
        ),
      ),

      // ✅ BottomSheet 톤 (모달/시트)
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: Colors.white,
        modalBarrierColor: Colors.black.withOpacity(0.35),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
      ),

      // ✅ Material3 dropdown menu
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          color: ink,
        ),
        menuStyle: MenuStyle(
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),

      // ✅ InputDecorationTheme: 여기로 “완전히 태워버리기”
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: softBg,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),

        hintStyle: TextStyle(
          color: Colors.black.withOpacity(0.35),
          fontWeight: FontWeight.w600,
        ),
        labelStyle: const TextStyle(
          color: ink,
          fontWeight: FontWeight.w700,
        ),
        helperStyle: TextStyle(
          color: ink.withOpacity(0.55),
          fontWeight: FontWeight.w600,
        ),

        prefixIconColor: ink.withOpacity(0.45),
        suffixIconColor: ink.withOpacity(0.45),

        border: outlineNone,
        enabledBorder: outlineNone,
        disabledBorder: outlineNone,
        focusedBorder: outlineFocus,

        errorStyle: const TextStyle(fontWeight: FontWeight.w600),
        errorBorder: outlineError,
        focusedErrorBorder: outlineError,
      ),

      // ✅ DatePicker 톤
      datePickerTheme: DatePickerThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),

        // ✅ 헤더 덜 쨍한 톤
        headerBackgroundColor: primary.withOpacity(0.12),
        headerForegroundColor: ink,

        // ✅ 선택된 날짜 숫자색 흰색 강제 (27일 안보임 해결)
        dayForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return ink;
        }),
        dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primary;
          return null;
        }),

        todayForegroundColor: WidgetStateProperty.all(primary),
        todayBackgroundColor: WidgetStateProperty.all(Colors.transparent),
      ),
    );
  }
}