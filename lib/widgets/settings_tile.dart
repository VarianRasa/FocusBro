import 'package:flutter/material.dart';

class SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool enabled;
  final EdgeInsetsGeometry? contentPadding;

  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.enabled = true,
    this.contentPadding,
  });

  // Factory constructor for switch tiles
  factory SettingsTile.switchTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool enabled = true,
    EdgeInsetsGeometry? contentPadding,
  }) {
    return SettingsTile(
      icon: icon,
      title: title,
      subtitle: subtitle,
      enabled: enabled,
      contentPadding: contentPadding,
      trailing: Transform.scale(
        scale: 0.8,
        child: Switch(
          value: value,
          onChanged: enabled ? onChanged : null,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }

  // Factory constructor for navigation tiles
  factory SettingsTile.navigation({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    bool enabled = true,
    EdgeInsetsGeometry? contentPadding,
  }) {
    return SettingsTile(
      icon: icon,
      title: title,
      subtitle: subtitle,
      enabled: enabled,
      contentPadding: contentPadding,
      onTap: onTap,
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;

    // Calculate responsive padding and sizes
    final horizontalPadding = screenWidth < 360 ? 12.0 : 16.0;
    final iconSize = screenWidth < 360 ? 36.0 : 40.0;
    final iconInnerSize = screenWidth < 360 ? 18.0 : 20.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          constraints: BoxConstraints(
            minHeight: 56,
            maxWidth: screenWidth,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: 8,
          ),
          child: Row(
            children: [
              // Leading icon container
              Container(
                width: iconSize,
                height: iconSize,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: enabled
                      ? colorScheme.primaryContainer.withValues(alpha: 0.3)
                      : colorScheme.onSurface.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  size: iconInnerSize,
                  color: enabled
                      ? colorScheme.primary
                      : colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ),

              // Title and subtitle - takes available space
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: enabled
                            ? colorScheme.onSurface
                            : colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: enabled
                              ? colorScheme.onSurfaceVariant
                              : colorScheme.onSurface.withValues(alpha: 0.4),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),

              // Trailing widget with proper constraints
              if (trailing != null)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  constraints: BoxConstraints(
                    maxWidth: _getTrailingMaxWidth(trailing!, screenWidth),
                  ),
                  child: trailing!,
                ),
            ],
          ),
        ),
      ),
    );
  }

  double _getTrailingMaxWidth(Widget trailing, double screenWidth) {
    // Determine appropriate max width based on trailing widget type and screen size
    final baseWidth = screenWidth * 0.3; // Max 30% of screen width

    if (trailing is Switch || trailing is Transform) {
      return (screenWidth < 360 ? 40.0 : 48.0).clamp(40.0, baseWidth);
    } else if (trailing is DropdownButton) {
      return (screenWidth < 360 ? 80.0 : 100.0).clamp(80.0, baseWidth);
    } else if (trailing is Slider) {
      return (screenWidth < 360 ? 100.0 : 120.0).clamp(100.0, baseWidth);
    } else if (trailing is Icon) {
      return 24.0;
    } else {
      // Default constraint for other widgets
      return (screenWidth < 360 ? 60.0 : 80.0).clamp(60.0, baseWidth);
    }
  }
}
