import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusbro/providers/focus_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const audioGlobalChannel = MethodChannel('xyz.luan/audioplayers.global');

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(audioGlobalChannel, (_) async => null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(audioGlobalChannel, null);
  });

  Future<FocusProvider> createProvider() async {
    final provider = FocusProvider();
    await provider.focusModeService.setAutoEnableOnFocusStart(false);
    await provider.setNotificationSoundsEnabled(false);
    await provider.setSoundEffectsEnabled(false);
    return provider;
  }

  testWidgets('timer starts pauses resumes and resets', (tester) async {
    final provider = await createProvider();
    provider.setWorkDuration(60);

    provider.toggleTimer();
    expect(provider.isRunning, isTrue);

    await tester.pump(const Duration(seconds: 2));
    expect(provider.timeLeft, 58);

    provider.toggleTimer();
    expect(provider.isRunning, isFalse);
    await tester.pump(const Duration(seconds: 2));
    expect(provider.timeLeft, 58);

    provider.toggleTimer();
    await tester.pump(const Duration(seconds: 1));
    expect(provider.timeLeft, 57);

    provider.resetTimer();
    expect(provider.isRunning, isFalse);
    expect(provider.isWorkTime, isTrue);
    expect(provider.timeLeft, 60);
    expect(provider.completedSessions, 0);
  });

  testWidgets('skipping the final session cancels the running timer',
      (tester) async {
    final provider = await createProvider();
    provider.setWorkDuration(60);
    provider.setTotalSessions(1);

    provider.toggleTimer();
    provider.skipSession();

    expect(provider.isAllSessionsComplete, isTrue);
    expect(provider.isRunning, isFalse);
    expect(provider.timeLeft, 60);

    await tester.pump(const Duration(seconds: 2));

    expect(provider.timeLeft, 60);
    expect(provider.completedWorkSessionEvents, 0);
  });

  testWidgets('session completes when the countdown reaches zero',
      (tester) async {
    final provider = await createProvider();
    provider.setWorkDuration(1);
    provider.setBreakDuration(5);
    provider.setTotalSessions(2);

    provider.toggleTimer();
    await tester.pump(const Duration(seconds: 1));

    expect(provider.isRunning, isFalse);
    expect(provider.completedSessions, 1);
    expect(provider.completedWorkSessionEvents, 1);
    expect(provider.isWorkTime, isFalse);
    expect(provider.timeLeft, 5);
  });
}
