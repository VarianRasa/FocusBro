import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/app_lock_service.dart';
import '../services/onboarding_service.dart';

class AppLockScreen extends StatefulWidget {
  const AppLockScreen({super.key});

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen>
    with TickerProviderStateMixin {
  final AppLockService _appLockService = AppLockService.instance;
  final TextEditingController _pinController = TextEditingController();

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  bool _isLoading = false;
  bool _obscurePin = true;
  String _enteredPin = '';
  int _failedAttempts = 0;
  static const int _maxFailedAttempts = 5;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _tryBiometricAuth();
  }

  void _setupAnimations() {
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _shakeAnimation = Tween<double>(
      begin: 0,
      end: 10,
    ).animate(CurvedAnimation(
      parent: _shakeController,
      curve: Curves.elasticIn,
    ));
  }

  Future<void> _tryBiometricAuth() async {
    if (_appLockService.lockMethod == 'biometric' &&
        _appLockService.biometricAvailable) {
      await Future.delayed(const Duration(milliseconds: 500));
      await _authenticateWithBiometric();
    }
  }

  Future<void> _authenticateWithBiometric() async {
    setState(() => _isLoading = true);

    try {
      final success = await _appLockService.authenticateWithBiometric();
      if (success && mounted) {
        await _navigateToNextScreen();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Biometric authentication failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _authenticateWithPin() async {
    if (_enteredPin.length != _appLockService.pinLength) return;

    setState(() => _isLoading = true);

    try {
      final success = await _appLockService.unlockWithPIN(_enteredPin);

      if (success && mounted) {
        await _navigateToNextScreen();
      } else {
        _handleFailedAttempt();
      }
    } catch (e) {
      _handleFailedAttempt();
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _navigateToNextScreen() async {
    if (!mounted) return;

    final shouldShowOnboarding = await OnboardingService.shouldShowOnboarding();
    if (shouldShowOnboarding) {
      Navigator.pushReplacementNamed(context, '/onboarding');
    } else {
      Navigator.pushReplacementNamed(context, '/main');
    }
  }

  void _handleFailedAttempt() {
    setState(() {
      _failedAttempts++;
      _enteredPin = '';
      _pinController.clear();
    });

    _shakeController.forward().then((_) {
      _shakeController.reverse();
    });

    HapticFeedback.vibrate();

    if (_failedAttempts >= _maxFailedAttempts) {
      _showTooManyAttemptsDialog();
    }
  }

  void _showTooManyAttemptsDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Too Many Failed Attempts'),
        content: const Text(
          'You have exceeded the maximum number of failed attempts. '
          'Please try again later or contact support.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              SystemNavigator.pop();
            },
            child: const Text('Exit App'),
          ),
        ],
      ),
    );
  }

  void _onPinDigitPressed(String digit) {
    if (_enteredPin.length < _appLockService.pinLength) {
      setState(() {
        _enteredPin += digit;
        _pinController.text = _enteredPin;
      });

      if (_enteredPin.length == _appLockService.pinLength) {
        _authenticateWithPin();
      }
    }
  }

  void _onDeletePressed() {
    if (_enteredPin.isNotEmpty) {
      setState(() {
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
        _pinController.text = _enteredPin;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final appLock = Provider.of<AppLockService>(context);
    final biometricType = appLock.getBiometricTypeString();

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.lock_outline,
                size: 64,
                color: Colors.blue,
              ),
              const SizedBox(height: 24),
              Text(
                appLock.lockMethod == 'biometric'
                    ? 'Enter your PIN or use $biometricType'
                    : 'Enter your PIN to unlock',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              // PIN input display
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  appLock.pinLength,
                  (index) => Container(
                    width: 16,
                    height: 16,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: index < _enteredPin.length
                          ? Colors.blue
                          : Colors.grey.shade300,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              // Numeric keypad
              Expanded(
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 1.5,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: 12,
                  itemBuilder: (context, index) {
                    if (index == 9) {
                      return const SizedBox.shrink(); // Empty space for 0
                    }
                    if (index == 10) {
                      return _buildKeypadButton('0');
                    }
                    if (index == 11) {
                      return _buildKeypadButton(
                        '⌫',
                        onPressed: _enteredPin.isNotEmpty
                            ? () {
                                setState(() {
                                  _enteredPin = _enteredPin.substring(
                                      0, _enteredPin.length - 1);
                                });
                              }
                            : null,
                      );
                    }
                    return _buildKeypadButton('${index + 1}');
                  },
                ),
              ),
              if (appLock.lockMethod == 'biometric' &&
                  appLock.biometricAvailable)
                Padding(
                  padding: const EdgeInsets.only(bottom: 24.0),
                  child: ElevatedButton.icon(
                    onPressed: _authenticateWithBiometric,
                    icon: const Icon(Icons.fingerprint),
                    label: Text('Use $biometricType'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKeypadButton(String digit, {VoidCallback? onPressed}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(32),
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(32),
          ),
          child: Center(
            child: Text(
              digit,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _pinController.dispose();
    super.dispose();
  }
}
