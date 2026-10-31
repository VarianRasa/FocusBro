import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Custom theme data structure
class CustomTheme {
  final String id;
  final String name;
  final Color primaryColor;
  final Color secondaryColor;
  final Color backgroundColor;
  final Color surfaceColor;
  final Brightness brightness;
  final bool isBuiltIn;

  const CustomTheme({
    required this.id,
    required this.name,
    required this.primaryColor,
    required this.secondaryColor,
    required this.backgroundColor,
    required this.surfaceColor,
    required this.brightness,
    this.isBuiltIn = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'primaryColor': primaryColor.toARGB32(),
        'secondaryColor': secondaryColor.toARGB32(),
        'backgroundColor': backgroundColor.toARGB32(),
        'surfaceColor': surfaceColor.toARGB32(),
        'brightness': brightness.name,
        'isBuiltIn': isBuiltIn,
      };

  factory CustomTheme.fromJson(Map<String, dynamic> json) => CustomTheme(
        id: json['id'],
        name: json['name'],
        primaryColor: Color(json['primaryColor']),
        secondaryColor: Color(json['secondaryColor']),
        backgroundColor: Color(json['backgroundColor']),
        surfaceColor: Color(json['surfaceColor']),
        brightness:
            Brightness.values.firstWhere((b) => b.name == json['brightness']),
        isBuiltIn: json['isBuiltIn'] ?? false,
      );

  ThemeData toThemeData() {
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: brightness,
        secondary: secondaryColor,
        surface: surfaceColor,
      ).copyWith(
        surface: backgroundColor, // Use backgroundColor for surface
      ),
    );
  }
}

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  String _selectedCustomThemeId = 'default';
  List<CustomTheme> _customThemes = [];
  SharedPreferences? _prefs;

  // Accessibility features
  double _fontScale = 1.0;
  bool _highContrast = false;
  bool _reduceAnimations = false;

  ThemeProvider() {
    _loadThemeMode();
    _loadCustomThemes();
    _loadAccessibilitySettings();
  }

  ThemeMode get themeMode => _themeMode;
  String get selectedCustomThemeId => _selectedCustomThemeId;
  List<CustomTheme> get customThemes => _customThemes;
  CustomTheme? get selectedCustomTheme {
    try {
      return _customThemes.where((t) => t.id == _selectedCustomThemeId).first;
    } catch (e) {
      return null;
    }
  }

  bool get isDarkMode => _themeMode == ThemeMode.dark;
  bool get isLightMode => _themeMode == ThemeMode.light;
  bool get isSystemMode => _themeMode == ThemeMode.system;

  // Accessibility getters
  double get fontScale => _fontScale;
  bool get highContrast => _highContrast;
  bool get reduceAnimations => _reduceAnimations;

  Future<void> _loadThemeMode() async {
    _prefs = await SharedPreferences.getInstance();
    final savedThemeMode = _prefs?.getString('themeMode') ?? 'system';

    switch (savedThemeMode) {
      case 'light':
        _themeMode = ThemeMode.light;
        break;
      case 'dark':
        _themeMode = ThemeMode.dark;
        break;
      case 'system':
      default:
        _themeMode = ThemeMode.system;
        break;
    }
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;

    _themeMode = mode;

    // Save to preferences
    _prefs ??= await SharedPreferences.getInstance();
    String modeString;
    switch (mode) {
      case ThemeMode.light:
        modeString = 'light';
        break;
      case ThemeMode.dark:
        modeString = 'dark';
        break;
      case ThemeMode.system:
        modeString = 'system';
        break;
    }

    await _prefs!.setString('themeMode', modeString);
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    ThemeMode newMode;
    switch (_themeMode) {
      case ThemeMode.light:
        newMode = ThemeMode.dark;
        break;
      case ThemeMode.dark:
        newMode = ThemeMode.system;
        break;
      case ThemeMode.system:
        newMode = ThemeMode.light;
        break;
    }
    await setThemeMode(newMode);
  }

  String get currentThemeName {
    switch (_themeMode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System';
    }
  }

  /// Load custom themes from storage
  Future<void> _loadCustomThemes() async {
    _prefs ??= await SharedPreferences.getInstance();

    // Initialize with built-in themes
    _customThemes = [
      const CustomTheme(
        id: 'default',
        name: 'Default',
        primaryColor: Colors.blue,
        secondaryColor: Colors.blueAccent,
        backgroundColor: Colors.white,
        surfaceColor: Colors.grey,
        brightness: Brightness.light,
        isBuiltIn: true,
      ),
      const CustomTheme(
        id: 'ocean',
        name: 'Ocean Blue',
        primaryColor: Colors.teal,
        secondaryColor: Colors.cyan,
        backgroundColor: Color(0xFFE0F2F1),
        surfaceColor: Color(0xFFB2DFDB),
        brightness: Brightness.light,
        isBuiltIn: true,
      ),
      const CustomTheme(
        id: 'sunset',
        name: 'Sunset Orange',
        primaryColor: Colors.deepOrange,
        secondaryColor: Colors.orange,
        backgroundColor: Color(0xFFFFF3E0),
        surfaceColor: Color(0xFFFFCC80),
        brightness: Brightness.light,
        isBuiltIn: true,
      ),
      const CustomTheme(
        id: 'forest',
        name: 'Forest Green',
        primaryColor: Colors.green,
        secondaryColor: Colors.lightGreen,
        backgroundColor: Color(0xFFE8F5E8),
        surfaceColor: Color(0xFFC8E6C9),
        brightness: Brightness.light,
        isBuiltIn: true,
      ),
      const CustomTheme(
        id: 'midnight',
        name: 'Midnight Dark',
        primaryColor: Colors.indigo,
        secondaryColor: Colors.indigoAccent,
        backgroundColor: Color(0xFF121212),
        surfaceColor: Color(0xFF1E1E1E),
        brightness: Brightness.dark,
        isBuiltIn: true,
      ),
    ];

    // Load custom themes from storage
    final customThemesJson = _prefs?.getStringList('custom_themes') ?? [];
    for (final themeJson in customThemesJson) {
      try {
        final theme = CustomTheme.fromJson(jsonDecode(themeJson));
        _customThemes.add(theme);
      } catch (e) {
        // Skip invalid themes
      }
    }

    // Load selected theme - use 'none' as default to use system theme
    _selectedCustomThemeId =
        _prefs?.getString('selected_custom_theme') ?? 'none';

    notifyListeners();
  }

  /// Save custom themes to storage
  Future<void> _saveCustomThemes() async {
    _prefs ??= await SharedPreferences.getInstance();

    // Save only user-created themes (not built-in)
    final userThemes = _customThemes.where((t) => !t.isBuiltIn).toList();
    final themesJson = userThemes.map((t) => jsonEncode(t.toJson())).toList();

    await _prefs!.setStringList('custom_themes', themesJson);
    await _prefs!.setString('selected_custom_theme', _selectedCustomThemeId);
  }

  /// Create a new custom theme
  Future<void> createCustomTheme(CustomTheme theme) async {
    _customThemes.add(theme);
    await _saveCustomThemes();
    notifyListeners();
  }

  /// Delete a custom theme
  Future<void> deleteCustomTheme(String themeId) async {
    if (_customThemes.any((t) => t.id == themeId && t.isBuiltIn)) {
      throw Exception('Cannot delete built-in theme');
    }

    _customThemes.removeWhere((t) => t.id == themeId);

    // If deleted theme was selected, switch to no custom theme
    if (_selectedCustomThemeId == themeId) {
      _selectedCustomThemeId = 'none';
    }

    await _saveCustomThemes();
    notifyListeners();
  }

  /// Select a custom theme
  Future<void> selectCustomTheme(String themeId) async {
    if (themeId != 'none' && !_customThemes.any((t) => t.id == themeId)) {
      throw Exception('Theme not found');
    }

    _selectedCustomThemeId = themeId;
    await _saveCustomThemes();
    notifyListeners();
  }

  /// Get theme data for the selected custom theme
  ThemeData? get customThemeData => selectedCustomTheme?.toThemeData();

  /// Load accessibility settings
  Future<void> _loadAccessibilitySettings() async {
    _prefs ??= await SharedPreferences.getInstance();

    _fontScale = _prefs!.getDouble('font_scale') ?? 1.0;
    _highContrast = _prefs!.getBool('high_contrast') ?? false;
    _reduceAnimations = _prefs!.getBool('reduce_animations') ?? false;

    notifyListeners();
  }

  /// Save accessibility settings
  Future<void> _saveAccessibilitySettings() async {
    _prefs ??= await SharedPreferences.getInstance();

    await _prefs!.setDouble('font_scale', _fontScale);
    await _prefs!.setBool('high_contrast', _highContrast);
    await _prefs!.setBool('reduce_animations', _reduceAnimations);
  }

  /// Set font scale
  Future<void> setFontScale(double scale) async {
    if (_fontScale == scale) return;

    _fontScale = scale.clamp(0.8, 1.5);
    await _saveAccessibilitySettings();
    notifyListeners();
  }

  /// Set high contrast mode
  Future<void> setHighContrast(bool enabled) async {
    if (_highContrast == enabled) return;

    _highContrast = enabled;
    await _saveAccessibilitySettings();
    notifyListeners();
  }

  /// Set reduce animations
  Future<void> setReduceAnimations(bool enabled) async {
    if (_reduceAnimations == enabled) return;

    _reduceAnimations = enabled;
    await _saveAccessibilitySettings();
    notifyListeners();
  }

  /// Get theme data with accessibility modifications
  ThemeData getThemeData(Brightness brightness) {
    // Start with custom theme or default
    ThemeData baseTheme;

    if (_selectedCustomThemeId != 'none' && selectedCustomTheme != null) {
      // Use custom theme but apply the correct brightness
      final customTheme = selectedCustomTheme!;
      baseTheme = ThemeData(
        useMaterial3: true,
        brightness: brightness,
        colorScheme: ColorScheme.fromSeed(
          seedColor: customTheme.primaryColor,
          brightness: brightness,
        ),
      );
    } else {
      // Use default Material Design 3 theme
      baseTheme = ThemeData(
        useMaterial3: true,
        brightness: brightness,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: brightness,
        ),
      );
    }

    // Apply accessibility modifications
    return baseTheme.copyWith(
      // Apply font scaling only if not default scale
      textTheme: _fontScale != 1.0
          ? _applyFontScaleToTextTheme(baseTheme.textTheme)
          : baseTheme.textTheme,
      primaryTextTheme: _fontScale != 1.0
          ? _applyFontScaleToTextTheme(baseTheme.primaryTextTheme)
          : baseTheme.primaryTextTheme,

      // Apply high contrast if enabled
      colorScheme: _highContrast
          ? _getHighContrastColorScheme(baseTheme.colorScheme)
          : baseTheme.colorScheme,

      // Apply animation settings
      pageTransitionsTheme: _reduceAnimations
          ? const PageTransitionsTheme(
              builders: {
                TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
                TargetPlatform.iOS: FadeUpwardsPageTransitionsBuilder(),
              },
            )
          : baseTheme.pageTransitionsTheme,
    );
  }

  /// Apply font scale to text theme safely
  TextTheme _applyFontScaleToTextTheme(TextTheme textTheme) {
    return TextTheme(
      displayLarge: textTheme.displayLarge?.copyWith(
        fontSize: (textTheme.displayLarge?.fontSize ?? 57) * _fontScale,
      ),
      displayMedium: textTheme.displayMedium?.copyWith(
        fontSize: (textTheme.displayMedium?.fontSize ?? 45) * _fontScale,
      ),
      displaySmall: textTheme.displaySmall?.copyWith(
        fontSize: (textTheme.displaySmall?.fontSize ?? 36) * _fontScale,
      ),
      headlineLarge: textTheme.headlineLarge?.copyWith(
        fontSize: (textTheme.headlineLarge?.fontSize ?? 32) * _fontScale,
      ),
      headlineMedium: textTheme.headlineMedium?.copyWith(
        fontSize: (textTheme.headlineMedium?.fontSize ?? 28) * _fontScale,
      ),
      headlineSmall: textTheme.headlineSmall?.copyWith(
        fontSize: (textTheme.headlineSmall?.fontSize ?? 24) * _fontScale,
      ),
      titleLarge: textTheme.titleLarge?.copyWith(
        fontSize: (textTheme.titleLarge?.fontSize ?? 22) * _fontScale,
      ),
      titleMedium: textTheme.titleMedium?.copyWith(
        fontSize: (textTheme.titleMedium?.fontSize ?? 16) * _fontScale,
      ),
      titleSmall: textTheme.titleSmall?.copyWith(
        fontSize: (textTheme.titleSmall?.fontSize ?? 14) * _fontScale,
      ),
      bodyLarge: textTheme.bodyLarge?.copyWith(
        fontSize: (textTheme.bodyLarge?.fontSize ?? 16) * _fontScale,
      ),
      bodyMedium: textTheme.bodyMedium?.copyWith(
        fontSize: (textTheme.bodyMedium?.fontSize ?? 14) * _fontScale,
      ),
      bodySmall: textTheme.bodySmall?.copyWith(
        fontSize: (textTheme.bodySmall?.fontSize ?? 12) * _fontScale,
      ),
      labelLarge: textTheme.labelLarge?.copyWith(
        fontSize: (textTheme.labelLarge?.fontSize ?? 14) * _fontScale,
      ),
      labelMedium: textTheme.labelMedium?.copyWith(
        fontSize: (textTheme.labelMedium?.fontSize ?? 12) * _fontScale,
      ),
      labelSmall: textTheme.labelSmall?.copyWith(
        fontSize: (textTheme.labelSmall?.fontSize ?? 11) * _fontScale,
      ),
    );
  }

  /// Get high contrast color scheme
  ColorScheme _getHighContrastColorScheme(ColorScheme original) {
    if (original.brightness == Brightness.light) {
      return original.copyWith(
        primary: Colors.black,
        onPrimary: Colors.white,
        secondary: Colors.black87,
        onSecondary: Colors.white,
        surface: Colors.white,
        onSurface: Colors.black,
        outline: Colors.black,
      );
    } else {
      return original.copyWith(
        primary: Colors.white,
        onPrimary: Colors.black,
        secondary: Colors.white70,
        onSecondary: Colors.black,
        surface: Colors.black,
        onSurface: Colors.white,
        outline: Colors.white,
      );
    }
  }
}
