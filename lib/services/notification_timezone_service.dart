import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

class NotificationTimezoneService {
  NotificationTimezoneService._();

  static bool _isInitialized = false;

  static void initialize() {
    if (_isInitialized) return;

    timezone_data.initializeTimeZones();
    _isInitialized = true;
  }

  static timezone.TZDateTime fromLocal(DateTime dateTime) {
    initialize();
    return timezone.TZDateTime.from(dateTime, timezone.local);
  }
}
