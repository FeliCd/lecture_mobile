import 'motion.dart';
import 'package:flutter/material.dart';

abstract final class CampusSpace {
  static const xs = 4.0, sm = 8.0, md = 12.0, lg = 16.0, xl = 24.0, page = 20.0;
}

abstract final class CampusRadius {
  static const control = 8.0, card = 12.0, sheet = 16.0;
}

abstract final class CampusColors {
  static const brand = Color(0xFFF37021),
      action = Color(0xFFB54708),
      white = Colors.white,
      ink = Color(0xFF172033),
      border = Color(0xFFE6E9F4),
      canvas = Color(0xFFF9F9FF),
      soft = Color(0xFFF1F3FF),
      blue = Color(0xFF0F6B93);
  static Color status(String s, bool dark) => switch (s) {
    'present' => dark ? const Color(0xFF74D89A) : const Color(0xFF15803D),
    'late' => dark ? const Color(0xFFFFD27A) : const Color(0xFF98600B),
    'absent' => dark ? const Color(0xFFFF8E85) : const Color(0xFFB42318),
    'excused' => dark ? const Color(0xFF8ED8F3) : const Color(0xFF0F6B93),
    _ => dark ? const Color(0xFFB6C0CE) : const Color(0xFF667085),
  };
}

ThemeData campusTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final s =
      ColorScheme.fromSeed(
        seedColor: CampusColors.brand,
        brightness: brightness,
      ).copyWith(
        primary: dark ? const Color(0xFFFFB181) : CampusColors.action,
        onPrimary: dark ? const Color(0xFF24150D) : CampusColors.white,
        primaryContainer: dark
            ? const Color(0xFF543020)
            : const Color(0xFFFFE7D5),
        onPrimaryContainer: dark
            ? const Color(0xFFFFE3D0)
            : const Color(0xFF7C2E05),
        secondary: dark ? const Color(0xFFAFC6ED) : const Color(0xFF334E76),
        tertiary: dark ? const Color(0xFF8ED8C2) : const Color(0xFF167D64),
        surface: dark ? const Color(0xFF1B2535) : CampusColors.white,
        surfaceContainerLow: dark ? const Color(0xFF202D42) : CampusColors.soft,
        surfaceContainer: dark
            ? const Color(0xFF26344B)
            : const Color(0xFFE9EDFF),
        surfaceContainerHigh: dark
            ? const Color(0xFF2D3A50)
            : const Color(0xFFE1E8FF),
        surfaceContainerHighest: dark
            ? const Color(0xFF34425A)
            : const Color(0xFFD9E2FC),
        onSurface: dark ? const Color(0xFFEDF2FA) : CampusColors.ink,
        onSurfaceVariant: dark
            ? const Color(0xFFAEBBD0)
            : const Color(0xFF667085),
        outline: dark ? const Color(0xFF43526B) : const Color(0xFFCBD4E1),
        outlineVariant: dark ? const Color(0xFF2D3A50) : CampusColors.border,
      );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: s,
    fontFamily: 'Be Vietnam Pro',
  );
  return base.copyWith(
    visualDensity: VisualDensity.standard,
    pageTransitionsTheme: PageTransitionsTheme(
      builders: {
        ...base.pageTransitionsTheme.builders,
        TargetPlatform.android: const CampusPageTransitions(),
        TargetPlatform.windows: const CampusPageTransitions(),
        TargetPlatform.linux: const CampusPageTransitions(),
      },
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(CampusRadius.sheet),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: s.surface,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(CampusRadius.sheet),
        ),
      ),
    ),
    scaffoldBackgroundColor: dark
        ? const Color(0xFF111A29)
        : CampusColors.canvas,
    textTheme: base.textTheme.copyWith(
      headlineMedium: base.textTheme.headlineMedium?.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
      titleLarge: base.textTheme.titleLarge?.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
      titleMedium: base.textTheme.titleMedium?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      titleSmall: base.textTheme.titleSmall?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: dark ? const Color(0xFF111A29) : CampusColors.canvas,
      foregroundColor: s.onSurface,
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleSpacing: 20,
      toolbarHeight: 68,
      titleTextStyle: base.textTheme.titleLarge?.copyWith(
        color: s.onSurface,
        fontSize: 20,
        fontWeight: FontWeight.w800,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: s.surface,
      surfaceTintColor: Colors.transparent,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(CampusRadius.card),
        side: BorderSide(color: s.outlineVariant),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: s.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      prefixIconColor: s.onSurfaceVariant,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(CampusRadius.control),
        borderSide: BorderSide(color: s.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(CampusRadius.control),
        borderSide: BorderSide(color: s.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(CampusRadius.control),
        borderSide: BorderSide(color: s.primary, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CampusRadius.control),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CampusRadius.control),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CampusRadius.control),
        ),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: dark ? const Color(0xFF111A29) : CampusColors.canvas,
      indicatorColor: s.primaryContainer,
      elevation: 0,
      height: 72,
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
          color: states.contains(WidgetState.selected)
              ? s.primary
              : s.onSurfaceVariant,
        ),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      side: BorderSide(color: s.outlineVariant),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      selectedColor: s.primaryContainer,
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        side: WidgetStatePropertyAll(BorderSide(color: s.outlineVariant)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? s.primaryContainer
              : s.surface,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? s.primary
              : s.onSurfaceVariant,
        ),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: s.outlineVariant,
      thickness: 1,
      space: 24,
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: s.primary,
      unselectedLabelColor: s.onSurfaceVariant,
      indicatorColor: s.primary,
      dividerColor: s.outlineVariant,
      labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
    ),
  );
}
