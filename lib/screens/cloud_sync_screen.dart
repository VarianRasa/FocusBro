import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import '../services/cloud_sync_service.dart';
import '../utils/error_handler.dart';
import '../utils/accessibility_helper.dart';

class CloudSyncScreen extends StatefulWidget {
  const CloudSyncScreen({super.key, this.cloudSync});

  final CloudSyncService? cloudSync;

  @override
  State<CloudSyncScreen> createState() => _CloudSyncScreenState();
}

class _CloudSyncScreenState extends State<CloudSyncScreen> {
  late final CloudSyncService _cloudSync;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _isRegistrationMode = false;
  SyncStatus _currentStatus = SyncStatus.idle;
  StreamSubscription<SyncStatus>? _statusSubscription;

  @override
  void initState() {
    super.initState();
    _cloudSync = widget.cloudSync ?? CloudSyncService();
    _initializeSync();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    unawaited(_statusSubscription?.cancel());
    super.dispose();
  }

  Future<void> _initializeSync() async {
    await _cloudSync.initialize();
    if (!mounted) return;

    _statusSubscription = _cloudSync.syncStatusStream.listen((status) {
      if (mounted) {
        setState(() {
          _currentStatus = status;
        });

        if (status.isError) {
          ErrorHandler.showError(context, _cloudSync.currentStatusMessage);
        }
      }
    });

    setState(() {
      _currentStatus = _cloudSync.currentStatus;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Cloud Sync',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Card
            _buildStatusCard(isDark),
            const SizedBox(height: 24),

            // Authentication Section
            if (!_cloudSync.isAuthenticated) ...[
              _buildSignInCard(isDark),
              const SizedBox(height: 24),
            ],

            // Sync Controls
            if (_cloudSync.isAuthenticated) ...[
              _buildSyncControlsCard(isDark),
              const SizedBox(height: 24),
            ],

            // Sync Settings
            _buildSyncSettingsCard(isDark),
            const SizedBox(height: 24),

            // Data Management
            _buildDataManagementCard(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(bool isDark) {
    final statusColor = _getStatusColor(_currentStatus);
    final statusIcon = _getStatusIcon(_currentStatus);
    final statusMessage = _cloudSync.currentStatusMessage;

    return AccessibilityHelper.accessibleCard(
      semanticLabel: 'Sync status: $statusMessage',
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: statusColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: statusColor.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Sync Status',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
                if (_currentStatus.isLoading)
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    statusMessage,
                    style: TextStyle(
                      fontSize: 16,
                      color: isDark ? Colors.grey[300] : Colors.grey[700],
                    ),
                  ),
                ),
              ],
            ),
            if (_cloudSync.lastSyncTime != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 16,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Last successful record sync: ${_formatLastSyncTime()}',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
            if (_currentStatus == SyncStatus.syncing &&
                _cloudSync.currentProgress.progress != null) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: _cloudSync.currentProgress.progress,
              ),
              const SizedBox(height: 6),
              Text(
                '${_cloudSync.currentProgress.completedRecords} of '
                '${_cloudSync.currentProgress.totalRecords} records',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSignInCard(bool isDark) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.cloud_upload,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  _isRegistrationMode ? 'Create Account' : 'Sign In to Sync',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              _isRegistrationMode
                  ? 'Create an account with your email and password.'
                  : 'Sign in with your email and password to manage your account.',
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 20),

            // Email Field
            AccessibilityHelper.accessibleTextField(
              controller: _emailController,
              label: 'Email',
              hint: 'Enter your email address',
              semanticHint: 'Email address for cloud sync account',
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),

            // Password Field
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: 'Password',
                hintText: 'Enter your password',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword
                      ? Icons.visibility
                      : Icons.visibility_off),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
              ),
              obscureText: _obscurePassword,
            ),
            const SizedBox(height: 20),

            // Sign In Button
            SizedBox(
              width: double.infinity,
              child: AccessibilityHelper.accessibleButton(
                semanticLabel: _isRegistrationMode
                    ? 'Create a FocusBro account'
                    : 'Sign in to cloud sync',
                semanticHint:
                    'Authentication does not start data synchronization',
                onPressed: _isLoading ? () {} : _submitCredentials,
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(_isRegistrationMode ? 'Create Account' : 'Sign In'),
              ),
            ),
            Center(
              child: TextButton(
                onPressed: _isLoading
                    ? null
                    : () {
                        setState(() {
                          _isRegistrationMode = !_isRegistrationMode;
                        });
                      },
                child: Text(
                  _isRegistrationMode
                      ? 'Already have an account? Sign in'
                      : 'Create an account',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncControlsCard(bool isDark) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.sync,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Account',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Signed in as ${_cloudSync.currentUserEmail ?? _cloudSync.currentUserUid ?? 'your account'}.',
              style: TextStyle(
                color: isDark ? Colors.grey[300] : Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Task records and queued changes can sync. Other data categories '
              'are not yet fully synchronized.',
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _cloudSync.isSyncing ? null : _syncNow,
                icon: Icon(
                  _currentStatus == SyncStatus.error
                      ? Icons.refresh
                      : Icons.sync,
                ),
                label: Text(
                  _currentStatus == SyncStatus.error
                      ? 'Retry Sync'
                      : 'Sync Now',
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            if (_cloudSync.currentProgress.conflictCount > 0) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: _reviewConflicts,
                  icon: const Icon(Icons.rule),
                  label: Text(
                    'Review ${_cloudSync.currentProgress.conflictCount} '
                    'conflict(s)',
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _signOut,
                icon: const Icon(Icons.logout),
                label: const Text('Sign Out'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncSettingsCard(bool isDark) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.settings,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Sync Settings',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Sync starts after sign-in, app startup or resume, and network '
              'restoration. Only integrated record types are synchronized.',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataManagementCard(bool isDark) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.storage,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Data Management',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Account export is unavailable until its scope and destination '
              'are approved. Account-wide deletion requires a separately '
              'approved server-side purge. Files remain local.',
              style: TextStyle(
                color: isDark ? Colors.grey[300] : Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(SyncStatus status) {
    switch (status) {
      case SyncStatus.synced:
        return Colors.green;
      case SyncStatus.authenticated:
      case SyncStatus.syncing:
      case SyncStatus.authenticating:
        return Colors.blue;
      case SyncStatus.partial:
        return Colors.orange;
      case SyncStatus.error:
        return Colors.red;
      case SyncStatus.unavailable:
        return Colors.grey;
      case SyncStatus.offline:
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(SyncStatus status) {
    switch (status) {
      case SyncStatus.synced:
        return Icons.cloud_done;
      case SyncStatus.authenticated:
        return Icons.account_circle;
      case SyncStatus.syncing:
        return Icons.cloud_sync;
      case SyncStatus.partial:
        return Icons.cloud_queue;
      case SyncStatus.authenticating:
        return Icons.login;
      case SyncStatus.error:
        return Icons.cloud_off;
      case SyncStatus.unavailable:
        return Icons.cloud_off;
      case SyncStatus.offline:
        return Icons.wifi_off;
      default:
        return Icons.cloud;
    }
  }

  String _formatLastSyncTime() {
    final lastSync = _cloudSync.lastSyncTime;
    if (lastSync == null) return 'Never';

    final now = DateTime.now();
    final difference = now.difference(lastSync);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours} hours ago';
    } else {
      return '${difference.inDays} days ago';
    }
  }

  Future<void> _submitCredentials() async {
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.isEmpty) {
      ErrorHandler.showWarning(context, 'Please enter both email and password');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final registering = _isRegistrationMode;
      final success = registering
          ? await _cloudSync.register(
              _emailController.text.trim(),
              _passwordController.text,
            )
          : await _cloudSync.signIn(
              _emailController.text.trim(),
              _passwordController.text,
            );

      if (!mounted) return;
      if (success) {
        _emailController.clear();
        _passwordController.clear();
        ErrorHandler.showSuccess(
          context,
          registering
              ? 'Account created. Sync is starting.'
              : 'Signed in. Sync is starting.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text(
            'Are you sure you want to sign out? Your data will remain on this device but won\'t sync to the cloud.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _cloudSync.signOut();
    }
  }

  Future<void> _syncNow() async {
    await _cloudSync.forceSyncNow();
  }

  Future<void> _reviewConflicts() async {
    final conflicts = await _cloudSync.getSyncConflicts();
    if (!mounted || conflicts.isEmpty) return;

    const encoder = JsonEncoder.withIndent('  ');
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sync conflicts'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final conflict in conflicts) ...[
                  Text(
                    '${conflict.entityType}: ${conflict.entityId}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  const Text('On this device'),
                  SelectableText(encoder.convert(conflict.localVersion)),
                  const SizedBox(height: 8),
                  const Text('In cloud'),
                  SelectableText(encoder.convert(conflict.remoteVersion)),
                  const Divider(height: 24),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
