import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_localizations.dart';
import '../utils/accessibility_helper.dart';

class LanguageSelectionScreen extends StatefulWidget {
  const LanguageSelectionScreen({super.key});

  @override
  State<LanguageSelectionScreen> createState() =>
      _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen> {
  String? _selectedLanguageCode;
  SharedPreferences? _prefs;

  final Map<String, Map<String, String>> _languages = {
    'en': {
      'name': 'English',
      'nativeName': 'English',
      'flag': '🇺🇸',
    },
    'id': {
      'name': 'Indonesian',
      'nativeName': 'Bahasa Indonesia',
      'flag': '🇮🇩',
    },
    'es': {
      'name': 'Spanish',
      'nativeName': 'Español',
      'flag': '🇪🇸',
    },
    'fr': {
      'name': 'French',
      'nativeName': 'Français',
      'flag': '🇫🇷',
    },
    'de': {
      'name': 'German',
      'nativeName': 'Deutsch',
      'flag': '🇩🇪',
    },
    'it': {
      'name': 'Italian',
      'nativeName': 'Italiano',
      'flag': '🇮🇹',
    },
    'pt': {
      'name': 'Portuguese',
      'nativeName': 'Português',
      'flag': '🇧🇷',
    },
    'ja': {
      'name': 'Japanese',
      'nativeName': '日本語',
      'flag': '🇯🇵',
    },
    'ko': {
      'name': 'Korean',
      'nativeName': '한국어',
      'flag': '🇰🇷',
    },
    'zh': {
      'name': 'Chinese (Simplified)',
      'nativeName': '简体中文',
      'flag': '🇨🇳',
    },
    'ar': {
      'name': 'Arabic',
      'nativeName': 'العربية',
      'flag': '🇸🇦',
    },
  };

  @override
  void initState() {
    super.initState();
    _loadCurrentLanguage();
  }

  Future<void> _loadCurrentLanguage() async {
    _prefs = await SharedPreferences.getInstance();

    // Get current language from LanguageProvider if available
    if (mounted) {
      final languageProvider =
          Provider.of<LanguageProvider>(context, listen: false);
      setState(() {
        _selectedLanguageCode = languageProvider.currentLocale.languageCode;
      });
    } else {
      setState(() {
        _selectedLanguageCode = _prefs?.getString('language_code') ?? 'en';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n?.language ?? 'Language',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select Language',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose your preferred language for the app interface',
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),

          // Language List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _languages.length,
              itemBuilder: (context, index) {
                final languageCode = _languages.keys.elementAt(index);
                final languageInfo = _languages[languageCode]!;
                final isSelected = _selectedLanguageCode == languageCode;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AccessibilityHelper.accessibleCard(
                    semanticLabel: 'Select ${languageInfo['name']} language',
                    semanticHint: isSelected
                        ? 'Currently selected'
                        : 'Double tap to select',
                    onTap: () => _selectLanguage(languageCode),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? theme.colorScheme.primary.withOpacity(0.1)
                            : (isDark ? Colors.grey[850] : Colors.white),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? theme.colorScheme.primary
                              : (isDark
                                  ? Colors.grey[700]!
                                  : Colors.grey[200]!),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        leading: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Center(
                            child: Text(
                              languageInfo['flag']!,
                              style: const TextStyle(fontSize: 24),
                            ),
                          ),
                        ),
                        title: Text(
                          languageInfo['nativeName']!,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: isSelected
                                ? theme.colorScheme.primary
                                : (isDark ? Colors.white : Colors.black87),
                          ),
                        ),
                        subtitle: Text(
                          languageInfo['name']!,
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                        trailing: isSelected
                            ? Icon(
                                Icons.check_circle,
                                color: theme.colorScheme.primary,
                                size: 24,
                              )
                            : Icon(
                                Icons.radio_button_unchecked,
                                color: isDark
                                    ? Colors.grey[600]
                                    : Colors.grey[400],
                                size: 24,
                              ),
                        onTap: () => _selectLanguage(languageCode),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Apply Button
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            child: ElevatedButton(
              onPressed: _applyLanguageChange,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                l10n?.save ?? 'Apply Changes',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _selectLanguage(String languageCode) {
    setState(() {
      _selectedLanguageCode = languageCode;
    });
  }

  Future<void> _applyLanguageChange() async {
    if (_selectedLanguageCode == null) return;

    // Get language provider and change language
    final languageProvider =
        Provider.of<LanguageProvider>(context, listen: false);
    await languageProvider.changeLanguage(_selectedLanguageCode!);

    // Show success message
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Language changed to ${_languages[_selectedLanguageCode]!['nativeName']}',
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );

      // Navigate back
      Navigator.pop(context, _selectedLanguageCode);
    }
  }
}

/// Language provider for managing app language
class LanguageProvider extends ChangeNotifier {
  Locale _currentLocale = const Locale('en', 'US');
  SharedPreferences? _prefs;

  Locale get currentLocale => _currentLocale;

  /// Initialize language provider
  Future<void> initialize() async {
    debugPrint('LanguageProvider: Starting initialization...');
    _prefs = await SharedPreferences.getInstance();
    final languageCode = _prefs?.getString('language_code') ?? 'en';

    debugPrint('LanguageProvider: Loaded language code: $languageCode');

    // Find matching locale
    final supportedLocale = AppLocalizations.supportedLocales.firstWhere(
      (locale) => locale.languageCode == languageCode,
      orElse: () => const Locale('en', 'US'),
    );

    _currentLocale = supportedLocale;
    debugPrint(
        'LanguageProvider: Set current locale to: ${_currentLocale.languageCode}');
    notifyListeners();
    debugPrint('LanguageProvider: Initialization completed successfully');
  }

  /// Change app language
  Future<void> changeLanguage(String languageCode) async {
    final newLocale = AppLocalizations.supportedLocales.firstWhere(
      (locale) => locale.languageCode == languageCode,
      orElse: () => const Locale('en', 'US'),
    );

    if (newLocale != _currentLocale) {
      _currentLocale = newLocale;
      await _prefs?.setString('language_code', languageCode);
      notifyListeners();
    }
  }

  /// Get language name
  String getLanguageName(String languageCode) {
    const languageNames = {
      'en': 'English',
      'id': 'Bahasa Indonesia',
      'es': 'Español',
      'fr': 'Français',
      'de': 'Deutsch',
      'it': 'Italiano',
      'pt': 'Português',
      'ja': '日本語',
      'ko': '한국어',
      'zh': '简体中文',
      'ar': 'العربية',
    };

    return languageNames[languageCode] ?? 'English';
  }

  /// Check if language is RTL
  bool get isRTL => _currentLocale.languageCode == 'ar';
}
