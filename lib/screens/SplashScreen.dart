import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/onboarding_service.dart';
import '../services/app_lock_service.dart';
import '../screens/app_lock_screen.dart';
import 'package:flutter/services.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _progressController;
  late Animation<double> _logoScaleAnimation;
  late Animation<double> _logoOpacityAnimation;
  late Animation<double> _progressAnimation;

  String _loadingText = 'Initializing FocusBro...';
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeAndDetermineInitialRoute();
    });
  }

  void _setupAnimations() {
    // Logo animation controller
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    // Progress animation controller
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    // Logo scale animation
    _logoScaleAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoController,
      curve: Curves.elasticOut,
    ));

    // Logo opacity animation
    _logoOpacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoController,
      curve: Curves.easeIn,
    ));

    // Progress animation
    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeInOut,
    ));

    // Start logo animation
    _logoController.forward();
  }

  Future<void> _initializeAndDetermineInitialRoute() async {
    // Start progress animation
    _progressController.forward();

    // Step 1: Wait for providers to be ready (ensure AppLockService is initialized here)
    await _updateProgress(0.2, 'Loading providers...');
    // AppLockService is initialized via AppInitializationService in main.dart
    // so it should be ready by now if MyApp is wrapped in MultiProvider

    await Future.delayed(const Duration(milliseconds: 300));

    // Step 2: Initialize onboarding service
    await _updateProgress(0.5, 'Initializing services...');
    await OnboardingService.instance.initialize();
    await Future.delayed(const Duration(milliseconds: 300));

    // Step 3: Check onboarding status
    await _updateProgress(0.8, 'Checking user preferences...');
    final shouldShowOnboarding = await OnboardingService.shouldShowOnboarding();
    await Future.delayed(const Duration(milliseconds: 300));

    // Step 4: Complete initialization
    await _updateProgress(1.0, 'Ready to focus!');
    await Future.delayed(const Duration(milliseconds: 500));

    // Determine the initial route based on app lock and onboarding status
    if (mounted) {
      final appLock = Provider.of<AppLockService>(context, listen: false);
      if (appLock.isAppLockEnabled && appLock.isLocked) {
        // Navigate to AppLockScreen, which will then handle
        // navigation to main/onboarding upon unlock.
        Navigator.pushReplacementNamed(context, '/appLock');
      } else if (shouldShowOnboarding) {
        Navigator.pushReplacementNamed(context, '/onboarding');
      } else {
        Navigator.pushReplacementNamed(context, '/main');
      }
    }
  }

  Future<void> _updateProgress(double progress, String text) async {
    if (mounted) {
      setState(() {
        _progress = progress;
        _loadingText = text;
      });
    }
    await Future.delayed(const Duration(milliseconds: 100));
  }

  @override
  void dispose() {
    _logoController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colorScheme.primary.withAlpha(25),
              colorScheme.surface,
              colorScheme.secondary.withAlpha(12),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top spacer
              const Spacer(flex: 2),

              // Animated Logo
              AnimatedBuilder(
                animation: _logoController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _logoScaleAnimation.value,
                    child: Opacity(
                      opacity: _logoOpacityAnimation.value,
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: colorScheme.primary.withAlpha(50),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Image.asset(
                          'assets/focusBroLogoName.png',
                          width: size.width * 0.6,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 40),

              // App Title
              Text(
                'FocusBro',
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                  letterSpacing: 1.2,
                ),
              ),

              const SizedBox(height: 8),

              // Subtitle
              Text(
                'Your Productivity Companion',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  letterSpacing: 0.5,
                ),
              ),

              const Spacer(flex: 1),

              // Loading Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  children: [
                    // Loading Text
                    Text(
                      _loadingText,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 20),

                    // Progress Bar
                    Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: AnimatedBuilder(
                        animation: _progressAnimation,
                        builder: (context, child) {
                          return LinearProgressIndicator(
                            value: _progress * _progressAnimation.value,
                            backgroundColor: Colors.transparent,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              colorScheme.primary,
                            ),
                            borderRadius: BorderRadius.circular(2),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Progress Percentage
                    Text(
                      '${(_progress * 100).toInt()}%',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(flex: 1),

              // Footer
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Text(
                  'Focus • Achieve • Succeed',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
