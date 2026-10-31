import 'package:flutter/material.dart';

class AppTheme {
  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.blue,
      brightness: Brightness.light,
    ),
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      elevation: 8,
      labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
      backgroundColor: Colors.white,
      indicatorColor: Colors.blue.withValues(alpha: 0.1),
    ),
  );

  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.blue,
      brightness: Brightness.dark,
    ),
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      elevation: 8,
      labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
      backgroundColor: Colors.grey[900],
      indicatorColor: Colors.blue.withValues(alpha: 0.1),
    ),
  );
}
