import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_localizations.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final int _totalPages = 6;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_onboarding', true);

    if (mounted) {
      Navigator.pushReplacementNamed(context, '/main');
    }
  }

  Future<void> _skipOnboarding() async {
    await _completeOnboarding();
  }

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _skipOnboarding,
                    child: Text(
                      l10n?.skip ?? 'Skip',
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Page content
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                children: [
                  _buildWelcomePage(l10n, theme, colorScheme, size),
                  _buildFeaturePage(
                    l10n?.onboardingFocusTitle ?? 'Focus Timer',
                    l10n?.onboardingFocusDescription ??
                        'Use the Pomodoro technique to boost your productivity with customizable work and break sessions.',
                    Icons.timer,
                    colorScheme.primary,
                    theme,
                    colorScheme,
                    size,
                  ),
                  _buildFeaturePage(
                    l10n?.onboardingTasksTitle ?? 'Task Management',
                    l10n?.onboardingTasksDescription ??
                        'Organize your tasks with priorities, categories, and due dates to stay on top of your work.',
                    Icons.task_alt,
                    Colors.green,
                    theme,
                    colorScheme,
                    size,
                  ),
                  _buildFeaturePage(
                    l10n?.onboardingNotesTitle ?? 'Smart Notes',
                    l10n?.onboardingNotesDescription ??
                        'Take notes with rich formatting, tags, and voice recordings to capture your ideas.',
                    Icons.note_alt,
                    Colors.orange,
                    theme,
                    colorScheme,
                    size,
                  ),
                  _buildFeaturePage(
                    l10n?.onboardingPdfTitle ?? 'PDF Reader',
                    l10n?.onboardingPdfDescription ??
                        'Read and annotate PDFs with advanced search, bookmarks, and highlighting features.',
                    Icons.picture_as_pdf,
                    Colors.red,
                    theme,
                    colorScheme,
                    size,
                  ),
                  _buildFeaturePage(
                    l10n?.onboardingSettingsTitle ?? 'Personalization',
                    l10n?.onboardingSettingsDescription ??
                        'Customize themes, sounds, and preferences to make FocusBro work perfectly for you.',
                    Icons.settings,
                    Colors.purple,
                    theme,
                    colorScheme,
                    size,
                  ),
                ],
              ),
            ),

            // Page indicators and navigation
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  // Page indicators
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _totalPages,
                      (index) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _currentPage == index ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _currentPage == index
                              ? colorScheme.primary
                              : colorScheme.onSurfaceVariant.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Navigation buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Previous button
                      if (_currentPage > 0)
                        TextButton.icon(
                          onPressed: _previousPage,
                          icon: const Icon(Icons.arrow_back),
                          label: Text(l10n?.previous ?? 'Previous'),
                        )
                      else
                        const SizedBox(width: 100),

                      // Next/Finish button
                      ElevatedButton.icon(
                        onPressed: _nextPage,
                        icon: Icon(_currentPage == _totalPages - 1
                            ? Icons.check
                            : Icons.arrow_forward),
                        label: Text(_currentPage == _totalPages - 1
                            ? (l10n?.finish ?? 'Finish')
                            : (l10n?.next ?? 'Next')),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomePage(
    AppLocalizations? l10n,
    ThemeData theme,
    ColorScheme colorScheme,
    Size size,
  ) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Logo
          Container(
            width: size.width * 0.3,
            height: size.width * 0.3,
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.psychology,
              size: size.width * 0.15,
              color: colorScheme.primary,
            ),
          ),

          const SizedBox(height: 32),

          // Welcome title
          Text(
            l10n?.welcomeToFocusBro ?? 'Welcome to FocusBro',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 16),

          // Subtitle
          Text(
            l10n?.onboardingSubtitle ?? 'Your productivity companion',
            style: theme.textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 48),

          // Get started button
          ElevatedButton(
            onPressed: _nextPage,
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(
                horizontal: 32,
                vertical: 16,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            child: Text(
              l10n?.getStarted ?? 'Get Started',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturePage(
    String title,
    String description,
    IconData icon,
    Color iconColor,
    ThemeData theme,
    ColorScheme colorScheme,
    Size size,
  ) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Feature icon
          Container(
            width: size.width * 0.25,
            height: size.width * 0.25,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: size.width * 0.12,
              color: iconColor,
            ),
          ),

          const SizedBox(height: 32),

          // Feature title
          Text(
            title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 16),

          // Feature description
          Text(
            description,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
