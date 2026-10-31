import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/focus_provider.dart';
import '../services/focus_mode_service.dart';

/// Focus Mode Status Indicator Widget
/// Shows current focus mode status and provides quick toggle functionality
class FocusModeIndicator extends StatelessWidget {
  final bool showLabel;
  final bool showQuickToggle;
  final EdgeInsets? padding;

  const FocusModeIndicator({
    super.key,
    this.showLabel = true,
    this.showQuickToggle = true,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<FocusProvider>(
      builder: (context, focusProvider, child) {
        final focusModeService = focusProvider.focusModeService;
        final theme = Theme.of(context);

        if (!focusModeService.isInitialized) {
          return const SizedBox.shrink();
        }

        final isActive = focusModeService.isFocusModeActive;
        final activeFeatures = focusModeService.getActiveFeatures();

        return Container(
          padding:
              padding ?? const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Focus Mode Status Icon
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isActive
                      ? theme.colorScheme.primary.withValues(alpha: 0.1)
                      : theme.colorScheme.surfaceVariant.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isActive
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outline.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Icon(
                  isActive ? Icons.do_not_disturb : Icons.do_not_disturb_off,
                  size: 16,
                  color: isActive
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),

              if (showLabel) ...[
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isActive ? 'Focus Mode' : 'Focus Off',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isActive
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (isActive && activeFeatures.isNotEmpty)
                      Text(
                        activeFeatures.length == 1
                            ? activeFeatures.first
                            : '${activeFeatures.length} features',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 10,
                        ),
                      ),
                  ],
                ),
              ],

              if (showQuickToggle) ...[
                const SizedBox(width: 8),
                // Quick Toggle Button
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _toggleFocusMode(context, focusModeService),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color:
                              theme.colorScheme.outline.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isActive ? Icons.toggle_on : Icons.toggle_off,
                            size: 16,
                            color: isActive
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isActive ? 'ON' : 'OFF',
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: isActive
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _toggleFocusMode(
      BuildContext context, FocusModeService focusModeService) async {
    try {
      if (focusModeService.isFocusModeActive) {
        await focusModeService.disableFocusMode();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Focus mode disabled'),
              backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        // Check if features are available before enabling
        final available = await focusModeService.areFocusFeaturesAvailable();
        if (!available) {
          if (context.mounted) {
            _showSetupDialog(context, focusModeService);
          }
          return;
        }

        final success = await focusModeService.enableFocusMode();
        if (context.mounted) {
          if (success) {
            final activeFeatures = focusModeService.getActiveFeatures();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Focus mode enabled${activeFeatures.isNotEmpty ? ': ${activeFeatures.join(', ')}' : ''}',
                ),
                backgroundColor: Theme.of(context).colorScheme.primary,
                duration: const Duration(seconds: 3),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Failed to enable focus mode'),
                backgroundColor: Theme.of(context).colorScheme.error,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _showSetupDialog(
      BuildContext context, FocusModeService focusModeService) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Focus Mode Setup'),
        content: const Text(
          'Focus mode requires additional permissions to work properly. '
          'Would you like to set up focus mode features now?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await focusModeService.openFocusModeSettings();
            },
            child: const Text('Setup'),
          ),
        ],
      ),
    );
  }
}
