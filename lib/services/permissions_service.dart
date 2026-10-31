import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

class PermissionsService extends ChangeNotifier {
  static PermissionsService? _instance;
  static PermissionsService get instance =>
      _instance ??= PermissionsService._();

  PermissionsService._();

  // Private variables
  bool _isInitialized = false;
  Map<Permission, PermissionStatus> _permissionStatuses = {};
  DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  // Getters
  bool get isInitialized => _isInitialized;
  Map<Permission, PermissionStatus> get permissionStatuses =>
      _permissionStatuses;

  /// Initialize the permissions service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      debugPrint('PermissionsService: Starting initialization...');

      await _checkAllPermissions();

      _isInitialized = true;
      debugPrint('PermissionsService: Initialization completed successfully');
      notifyListeners();
    } catch (e) {
      debugPrint('PermissionsService: Initialization failed: $e');
    }
  }

  /// Check all relevant permissions
  Future<void> _checkAllPermissions() async {
    final permissions = _getRelevantPermissions();

    for (final permission in permissions) {
      try {
        final status = await permission.status;
        _permissionStatuses[permission] = status;
      } catch (e) {
        debugPrint(
            'PermissionsService: Error checking ${permission.toString()}: $e');
        _permissionStatuses[permission] = PermissionStatus.denied;
      }
    }
  }

  /// Get list of relevant permissions for the app
  List<Permission> _getRelevantPermissions() {
    final permissions = <Permission>[];

    // Common permissions
    permissions.addAll([
      Permission.storage,
      Permission.notification,
      Permission.audio,
      Permission.microphone,
    ]);

    // Android specific permissions
    if (Platform.isAndroid) {
      permissions.addAll([
        Permission.accessNotificationPolicy,
        Permission.systemAlertWindow,
        Permission.manageExternalStorage,
        Permission.requestInstallPackages,
        Permission.scheduleExactAlarm,
      ]);
    }

    // iOS specific permissions
    if (Platform.isIOS) {
      permissions.addAll([
        Permission.appTrackingTransparency,
        Permission.criticalAlerts,
      ]);
    }

    return permissions;
  }

  /// Request a specific permission
  Future<PermissionStatus> requestPermission(Permission permission) async {
    try {
      debugPrint('PermissionsService: Requesting ${permission.toString()}');

      final status = await permission.request();
      _permissionStatuses[permission] = status;

      notifyListeners();
      debugPrint(
          'PermissionsService: ${permission.toString()} status: ${status.toString()}');

      return status;
    } catch (e) {
      debugPrint(
          'PermissionsService: Error requesting ${permission.toString()}: $e');
      return PermissionStatus.denied;
    }
  }

  /// Request multiple permissions
  Future<Map<Permission, PermissionStatus>> requestMultiplePermissions(
    List<Permission> permissions,
  ) async {
    try {
      debugPrint(
          'PermissionsService: Requesting multiple permissions: ${permissions.length}');

      final statuses = await permissions.request();
      _permissionStatuses.addAll(statuses);

      notifyListeners();
      return statuses;
    } catch (e) {
      debugPrint(
          'PermissionsService: Error requesting multiple permissions: $e');
      return {};
    }
  }

  /// Check if permission is granted
  bool isPermissionGranted(Permission permission) {
    final status = _permissionStatuses[permission];
    return status == PermissionStatus.granted;
  }

  /// Check if permission is permanently denied
  bool isPermissionPermanentlyDenied(Permission permission) {
    final status = _permissionStatuses[permission];
    return status == PermissionStatus.permanentlyDenied;
  }

  /// Open app settings
  Future<bool> openAppSettings() async {
    try {
      return await openAppSettings();
    } catch (e) {
      debugPrint('PermissionsService: Error opening app settings: $e');
      return false;
    }
  }

  /// Get permission display name
  String getPermissionDisplayName(Permission permission) {
    switch (permission) {
      case Permission.storage:
        return 'Storage';
      case Permission.notification:
        return 'Notifications';
      case Permission.audio:
        return 'Audio Recording';
      case Permission.microphone:
        return 'Microphone';
      case Permission.accessNotificationPolicy:
        return 'Do Not Disturb Access';
      case Permission.systemAlertWindow:
        return 'Display Over Other Apps';
      case Permission.manageExternalStorage:
        return 'Manage External Storage';
      case Permission.requestInstallPackages:
        return 'Install Unknown Apps';
      case Permission.scheduleExactAlarm:
        return 'Schedule Exact Alarms';
      case Permission.appTrackingTransparency:
        return 'App Tracking';
      case Permission.criticalAlerts:
        return 'Critical Alerts';
      default:
        return permission.toString().split('.').last;
    }
  }

  /// Get permission description
  String getPermissionDescription(Permission permission) {
    switch (permission) {
      case Permission.storage:
        return 'Access device storage for backup and file operations';
      case Permission.notification:
        return 'Show notifications for focus sessions and reminders';
      case Permission.audio:
        return 'Record audio for voice commands and notes';
      case Permission.microphone:
        return 'Access microphone for voice features';
      case Permission.accessNotificationPolicy:
        return 'Control Do Not Disturb mode during focus sessions';
      case Permission.systemAlertWindow:
        return 'Display focus mode overlay and blocking screens';
      case Permission.manageExternalStorage:
        return 'Manage files and backups on external storage';
      case Permission.requestInstallPackages:
        return 'Install app updates and plugins';
      case Permission.scheduleExactAlarm:
        return 'Schedule precise focus session reminders';
      case Permission.appTrackingTransparency:
        return 'Track app usage for analytics (optional)';
      case Permission.criticalAlerts:
        return 'Show important focus session alerts';
      default:
        return 'Required for app functionality';
    }
  }

  /// Get permission status color
  Color getPermissionStatusColor(Permission permission) {
    final status = _permissionStatuses[permission];
    switch (status) {
      case PermissionStatus.granted:
        return Colors.green;
      case PermissionStatus.denied:
        return Colors.orange;
      case PermissionStatus.permanentlyDenied:
        return Colors.red;
      case PermissionStatus.restricted:
        return Colors.grey;
      case PermissionStatus.limited:
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  /// Get permission status text
  String getPermissionStatusText(Permission permission) {
    final status = _permissionStatuses[permission];
    switch (status) {
      case PermissionStatus.granted:
        return 'Granted';
      case PermissionStatus.denied:
        return 'Denied';
      case PermissionStatus.permanentlyDenied:
        return 'Permanently Denied';
      case PermissionStatus.restricted:
        return 'Restricted';
      case PermissionStatus.limited:
        return 'Limited';
      default:
        return 'Unknown';
    }
  }

  /// Get permission status icon
  IconData getPermissionStatusIcon(Permission permission) {
    final status = _permissionStatuses[permission];
    switch (status) {
      case PermissionStatus.granted:
        return Icons.check_circle;
      case PermissionStatus.denied:
        return Icons.warning;
      case PermissionStatus.permanentlyDenied:
        return Icons.block;
      case PermissionStatus.restricted:
        return Icons.lock;
      case PermissionStatus.limited:
        return Icons.info;
      default:
        return Icons.help;
    }
  }

  /// Check if permission is critical for app functionality
  bool isPermissionCritical(Permission permission) {
    const criticalPermissions = [
      Permission.storage,
      Permission.notification,
    ];
    return criticalPermissions.contains(permission);
  }

  /// Get device info
  Future<Map<String, String>> getDeviceInfo() async {
    try {
      final info = <String, String>{};

      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        info['Platform'] = 'Android';
        info['Version'] = androidInfo.version.release;
        info['SDK'] = androidInfo.version.sdkInt.toString();
        info['Model'] = androidInfo.model;
        info['Manufacturer'] = androidInfo.manufacturer;
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        info['Platform'] = 'iOS';
        info['Version'] = iosInfo.systemVersion;
        info['Model'] = iosInfo.model;
        info['Name'] = iosInfo.name;
      }

      return info;
    } catch (e) {
      debugPrint('PermissionsService: Error getting device info: $e');
      return {'Error': 'Unable to get device info'};
    }
  }

  /// Refresh all permission statuses
  Future<void> refreshPermissions() async {
    await _checkAllPermissions();
    notifyListeners();
  }

  /// Get permissions summary
  PermissionsSummary getPermissionsSummary() {
    int granted = 0;
    int denied = 0;
    int permanentlyDenied = 0;
    int total = _permissionStatuses.length;

    for (final status in _permissionStatuses.values) {
      switch (status) {
        case PermissionStatus.granted:
          granted++;
          break;
        case PermissionStatus.denied:
          denied++;
          break;
        case PermissionStatus.permanentlyDenied:
          permanentlyDenied++;
          break;
        default:
          break;
      }
    }

    return PermissionsSummary(
      total: total,
      granted: granted,
      denied: denied,
      permanentlyDenied: permanentlyDenied,
    );
  }

  /// Dispose resources
  @override
  void dispose() {
    debugPrint('PermissionsService: Disposing...');
    super.dispose();
  }
}

/// Permissions summary data class
class PermissionsSummary {
  final int total;
  final int granted;
  final int denied;
  final int permanentlyDenied;

  PermissionsSummary({
    required this.total,
    required this.granted,
    required this.denied,
    required this.permanentlyDenied,
  });

  double get grantedPercentage => total > 0 ? (granted / total) * 100 : 0;
  bool get allGranted => granted == total;
  bool get hasIssues => denied > 0 || permanentlyDenied > 0;
}
