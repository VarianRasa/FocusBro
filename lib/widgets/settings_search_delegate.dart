import 'package:flutter/material.dart';
import 'settings_tile.dart';

class SettingsSearchDelegate extends SearchDelegate<String> {
  final Map<String, dynamic> settings;
  final Function(String) onSettingTap;

  SettingsSearchDelegate({
    required this.settings,
    required this.onSettingTap,
  });

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        onPressed: () {
          query = '';
        },
        icon: const Icon(Icons.clear),
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      onPressed: () {
        close(context, '');
      },
      icon: const Icon(Icons.arrow_back),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults();
  }

  Widget _buildSearchResults() {
    if (query.isEmpty) {
      return const Center(
        child: Text('Search for settings...'),
      );
    }

    final filteredSettings = settings.entries
        .where((entry) =>
            entry.key.toLowerCase().contains(query.toLowerCase()) ||
            _getSettingDisplayName(entry.key)
                .toLowerCase()
                .contains(query.toLowerCase()))
        .toList();

    if (filteredSettings.isEmpty) {
      return const Center(
        child: Text('No settings found'),
      );
    }

    return ListView.builder(
      itemCount: filteredSettings.length,
      itemBuilder: (context, index) {
        final setting = filteredSettings[index];
        return SettingsTile(
          icon: _getSettingIcon(setting.key),
          title: _getSettingDisplayName(setting.key),
          subtitle: _getSettingDescription(setting.key),
          trailing: Container(
            constraints: const BoxConstraints(maxWidth: 80),
            child: _getSettingValueWidget(setting.value),
          ),
          onTap: () {
            close(context, setting.key);
            onSettingTap(setting.key);
          },
        );
      },
    );
  }

  IconData _getSettingIcon(String key) {
    switch (key) {
      case 'auto_save_enabled':
        return Icons.auto_awesome;
      case 'default_view':
        return Icons.home;
      case 'show_onboarding':
        return Icons.help_outline;
      case 'font_scale':
        return Icons.text_fields;
      case 'high_contrast':
        return Icons.contrast;
      case 'reduce_animations':
        return Icons.animation;
      case 'analytics_enabled':
        return Icons.analytics;
      case 'crash_reporting':
        return Icons.bug_report;
      case 'data_collection':
        return Icons.data_usage;
      case 'debug_mode':
        return Icons.developer_mode;
      case 'performance_monitoring':
        return Icons.speed;
      case 'theme_mode':
        return Icons.palette;
      case 'work_duration':
      case 'break_duration':
      case 'total_sessions':
        return Icons.timer;
      case 'music_enabled':
        return Icons.music_note;
      case 'voice_enabled':
        return Icons.mic;
      case 'focus_mode_enabled':
        return Icons.do_not_disturb;
      default:
        return Icons.settings;
    }
  }

  String _getSettingDisplayName(String key) {
    switch (key) {
      case 'auto_save_enabled':
        return 'Auto-save';
      case 'default_view':
        return 'Default View';
      case 'show_onboarding':
        return 'Show Onboarding';
      case 'font_scale':
        return 'Font Size';
      case 'high_contrast':
        return 'High Contrast';
      case 'reduce_animations':
        return 'Reduce Animations';
      case 'analytics_enabled':
        return 'Analytics';
      case 'crash_reporting':
        return 'Crash Reporting';
      case 'data_collection':
        return 'Data Collection';
      case 'debug_mode':
        return 'Debug Mode';
      case 'performance_monitoring':
        return 'Performance Monitoring';
      default:
        return key
            .replaceAll('_', ' ')
            .split(' ')
            .map((word) => word.isNotEmpty
                ? word[0].toUpperCase() + word.substring(1)
                : '')
            .join(' ');
    }
  }

  String _getSettingDescription(String key) {
    switch (key) {
      case 'auto_save_enabled':
        return 'Automatically save notes and tasks';
      case 'default_view':
        return 'Choose your preferred starting screen';
      case 'show_onboarding':
        return 'Display help tips for new features';
      case 'font_scale':
        return 'Adjust text size for better readability';
      case 'high_contrast':
        return 'Increase contrast for better visibility';
      case 'reduce_animations':
        return 'Minimize motion for accessibility';
      case 'analytics_enabled':
        return 'Help improve the app with usage data';
      case 'crash_reporting':
        return 'Send crash reports to developers';
      case 'data_collection':
        return 'Allow collection of usage statistics';
      case 'debug_mode':
        return 'Enable advanced debugging features';
      case 'performance_monitoring':
        return 'Monitor app performance metrics';
      default:
        return 'Setting configuration';
    }
  }

  Widget _getSettingValueWidget(dynamic value) {
    if (value is bool) {
      return Icon(
        value ? Icons.check_circle : Icons.cancel,
        color: value ? Colors.green : Colors.grey,
        size: 20,
      );
    } else if (value is String) {
      return Text(
        value,
        style: const TextStyle(
          fontSize: 12,
          color: Colors.grey,
        ),
      );
    } else if (value is num) {
      return Text(
        value.toString(),
        style: const TextStyle(
          fontSize: 12,
          color: Colors.grey,
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
