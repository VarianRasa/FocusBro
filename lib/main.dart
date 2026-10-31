import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:focusbro/services/firebase_emulator_config.dart';
import 'package:focusbro/services/cloud_sync_service.dart';
import 'package:focusbro/screens/enhanced_focus_screen.dart';
import 'package:focusbro/screens/enhanced_agenda_screen.dart';
import 'package:focusbro/screens/enhanced_notes_screen.dart';
import 'package:focusbro/screens/SplashScreen.dart';
import 'package:focusbro/screens/enhanced_pdf_reader_screen.dart';
import 'package:focusbro/screens/enhanced_settings_screen.dart';
import 'package:focusbro/services/app_lock_service.dart';
import 'package:focusbro/screens/app_lock_screen.dart';
// Cleaned up legacy imports - all screens now use enhanced versions
// Future features will be added when implemented:
// import 'package:focusbro/services/advanced_notification_service.dart';
// import 'package:focusbro/services/voice_command_service.dart';
import 'package:focusbro/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:focusbro/screens/language_selection_screen.dart';
import 'package:focusbro/screens/onboarding_screen.dart';
import 'package:focusbro/services/onboarding_service.dart';
import 'package:focusbro/theme/theme_provider.dart';
import 'package:focusbro/utils/cache_manager.dart';
import 'package:focusbro/providers/focus_provider.dart';
import 'package:focusbro/providers/task_provider.dart';
import 'package:focusbro/providers/note_provider.dart';
import 'package:focusbro/providers/goal_provider.dart';
import 'package:focusbro/services/app_initialization_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await FirebaseEmulatorConfig.initialize();
  } catch (error) {
    debugPrint(
      'Main: Firebase bootstrap failed; continuing with local features: $error',
    );
  }

  // Initialize cache manager for better performance
  await CacheManager().initialize();

  // Initialize database and perform migrations
  final appInitService = AppInitializationService();
  await appInitService.initialize();

  // Preload common data for better performance
  await CacheManager().preloadCommonData();

  // Initialize providers
  final themeProvider = ThemeProvider();
  final languageProvider = LanguageProvider();
  final focusProvider = FocusProvider();
  final taskProvider = TaskProvider();
  final noteProvider = NoteProvider();
  final goalProvider = GoalProvider();
  final appLockService = AppLockService.instance;

  // Wait for providers to initialize with enhanced error handling
  try {
    debugPrint('Main: Initializing LanguageProvider...');
    await languageProvider.initialize();
    debugPrint('Main: LanguageProvider initialized successfully');

    debugPrint('Main: Initializing FocusProvider...');
    await focusProvider.initialize();
    debugPrint('Main: FocusProvider initialized successfully');

    debugPrint('Main: Initializing TaskProvider...');
    await taskProvider.initialize();
    debugPrint('Main: TaskProvider initialized successfully');

    debugPrint('Main: Initializing NoteProvider...');
    try {
      await noteProvider.initialize();
      debugPrint('Main: NoteProvider initialized successfully');
    } catch (e) {
      debugPrint('Main: NoteProvider initialization failed: $e');
      // Continue with app initialization even if NoteProvider fails
    }

    debugPrint('Main: Initializing GoalProvider...');
    try {
      await goalProvider.initialize();
      debugPrint('Main: GoalProvider initialized successfully');
    } catch (e) {
      debugPrint('Main: GoalProvider initialization failed: $e');
      // Continue with app initialization even if GoalProvider fails
    }

    debugPrint('Main: Initializing AppLockService...');
    try {
      await appLockService.initialize();
      debugPrint('Main: AppLockService initialized successfully');
    } catch (e) {
      debugPrint('Main: AppLockService initialization failed: $e');
      // Continue with app initialization even if AppLockService fails
    }

    debugPrint('Main: All providers initialized successfully');
  } catch (e) {
    debugPrint('Main: Provider initialization failed: $e');
    // Continue with app startup even if initialization fails
    // The providers will attempt to retry initialization
  }

  try {
    await CloudSyncService().initialize();
  } catch (error) {
    debugPrint(
      'Main: Cloud sync initialization failed; local features remain available: $error',
    );
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider.value(value: languageProvider),
        ChangeNotifierProvider.value(value: focusProvider),
        ChangeNotifierProvider.value(value: taskProvider),
        ChangeNotifierProvider.value(value: noteProvider),
        ChangeNotifierProvider.value(value: goalProvider),
        ChangeNotifierProvider.value(value: appLockService),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<ThemeProvider, LanguageProvider>(
      builder: (context, themeProvider, languageProvider, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'FocusBro',
          theme: themeProvider.getThemeData(Brightness.light),
          darkTheme: themeProvider.getThemeData(Brightness.dark),
          themeMode: themeProvider.themeMode,

          // Localization configuration
          locale: languageProvider.currentLocale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,

          initialRoute: '/',
          routes: {
            '/': (context) => const SplashScreen(),
            '/onboarding': (context) => const OnboardingScreen(),
            '/main': (context) => const MainScreen(),
            '/appLock': (context) => const AppLockScreen(),
          },
        );
      },
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  bool _isInitialized = false;

  final List<Widget> _screens = [
    const EnhancedFocusScreen(),
    const EnhancedAgendaScreen(),
    const EnhancedNotesScreen(),
    const EnhancedPdfReaderScreen(),
    const EnhancedSettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    // Small delay to ensure providers are fully initialized
    await Future.delayed(const Duration(milliseconds: 100));

    // Load default view setting and set initial screen
    await _loadDefaultView();

    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
    }
  }

  Future<void> _loadDefaultView() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final defaultView = prefs.getString('default_view') ?? 'focus';

      debugPrint('MainScreen: Loading default view setting: $defaultView');

      int initialIndex = 0; // Default to Focus screen

      switch (defaultView) {
        case 'focus':
          initialIndex = 0;
          break;
        case 'agenda':
          initialIndex = 1;
          break;
        case 'notes':
          initialIndex = 2;
          break;
        case 'pdf':
          initialIndex = 3;
          break;
        default:
          initialIndex = 0; // Fallback to Focus
      }

      debugPrint(
          'MainScreen: Setting initial screen index to: $initialIndex (${_getScreenName(initialIndex)})');

      if (mounted) {
        setState(() {
          _selectedIndex = initialIndex;
        });
      }
    } catch (e) {
      // If there's an error loading preferences, default to Focus screen
      debugPrint('Error loading default view: $e');
    }
  }

  String _getScreenName(int index) {
    switch (index) {
      case 0:
        return 'Focus';
      case 1:
        return 'Agenda';
      case 2:
        return 'Notes';
      case 3:
        return 'PDF Reader';
      case 4:
        return 'Settings';
      default:
        return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!_isInitialized) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        elevation: 0,
        height: 65,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          NavigationDestination(
            icon: Icon(
              Icons.timer_outlined,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
            selectedIcon: Icon(
              Icons.timer,
              color: Theme.of(context).colorScheme.primary,
            ),
            label: 'Focus',
          ),
          NavigationDestination(
            icon: Icon(
              Icons.calendar_today_outlined,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
            selectedIcon: Icon(
              Icons.calendar_today,
              color: Theme.of(context).colorScheme.primary,
            ),
            label: 'Agenda',
          ),
          NavigationDestination(
            icon: Icon(
              Icons.note_outlined,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
            selectedIcon: Icon(
              Icons.note,
              color: Theme.of(context).colorScheme.primary,
            ),
            label: 'Notes',
          ),
          NavigationDestination(
            icon: Icon(
              Icons.picture_as_pdf_outlined,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
            selectedIcon: Icon(
              Icons.picture_as_pdf,
              color: Theme.of(context).colorScheme.primary,
            ),
            label: 'PDF',
          ),
          NavigationDestination(
            icon: Icon(
              Icons.settings_outlined,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
            selectedIcon: Icon(
              Icons.settings,
              color: Theme.of(context).colorScheme.primary,
            ),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
