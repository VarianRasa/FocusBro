import 'package:flutter_test/flutter_test.dart';
import 'package:focusbro/providers/focus_provider.dart';

void main() {
  group('Focus Mode Synchronization Verification', () {
    test('FocusProvider should have setFocusModeState method', () {
      final provider = FocusProvider();

      // Initially should be false
      expect(provider.isFocusModeEnabled, false);

      // Set to true using new method
      provider.setFocusModeState(true);
      expect(provider.isFocusModeEnabled, true);

      // Set to false using new method
      provider.setFocusModeState(false);
      expect(provider.isFocusModeEnabled, false);

      // Should not change if same value
      provider.setFocusModeState(false);
      expect(provider.isFocusModeEnabled, false);

      print('✅ FocusProvider.setFocusModeState method works correctly');
    });

    test('setFocusModeState should only notify listeners when state changes',
        () {
      final provider = FocusProvider();
      int notificationCount = 0;

      provider.addListener(() {
        notificationCount++;
      });

      // Initial state is false, setting to false should not notify
      provider.setFocusModeState(false);
      expect(notificationCount, 0);

      // Setting to true should notify
      provider.setFocusModeState(true);
      expect(notificationCount, 1);

      // Setting to true again should not notify
      provider.setFocusModeState(true);
      expect(notificationCount, 1);

      // Setting to false should notify
      provider.setFocusModeState(false);
      expect(notificationCount, 2);

      print('✅ setFocusModeState only notifies when state actually changes');
    });

    test('toggleFocusMode should still work as before', () {
      final provider = FocusProvider();

      // Initially should be false
      expect(provider.isFocusModeEnabled, false);

      // Toggle should change to true
      provider.toggleFocusMode();
      expect(provider.isFocusModeEnabled, true);

      // Toggle again should change to false
      provider.toggleFocusMode();
      expect(provider.isFocusModeEnabled, false);

      print('✅ toggleFocusMode still works correctly');
    });

    test('Both methods should work together correctly', () {
      final provider = FocusProvider();

      // Start with false
      expect(provider.isFocusModeEnabled, false);

      // Use setFocusModeState to enable
      provider.setFocusModeState(true);
      expect(provider.isFocusModeEnabled, true);

      // Use toggle to disable
      provider.toggleFocusMode();
      expect(provider.isFocusModeEnabled, false);

      // Use toggle to enable
      provider.toggleFocusMode();
      expect(provider.isFocusModeEnabled, true);

      // Use setFocusModeState to disable
      provider.setFocusModeState(false);
      expect(provider.isFocusModeEnabled, false);

      print(
          '✅ Both setFocusModeState and toggleFocusMode work together correctly');
    });
  });
}
