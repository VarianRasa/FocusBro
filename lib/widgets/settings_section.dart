import 'package:flutter/material.dart';

class SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final EdgeInsetsGeometry? padding;
  final bool showDivider;

  const SettingsSection({
    super.key,
    required this.title,
    required this.children,
    this.padding,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: padding ??
              EdgeInsets.fromLTRB(isTablet ? 24 : 16, isTablet ? 20 : 16,
                  isTablet ? 24 : 16, 8),
          child: Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.primary,
              fontSize: isTablet ? 16 : 14,
            ),
          ),
        ),
        Card(
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: colorScheme.outline.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Column(
              children: _buildChildrenWithDividers(),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildChildrenWithDividers() {
    if (children.isEmpty) return [];

    final List<Widget> result = [];

    for (int i = 0; i < children.length; i++) {
      result.add(children[i]);

      // Add divider between items (except after the last item)
      if (showDivider && i < children.length - 1) {
        result.add(
          Divider(
            height: 1,
            thickness: 1,
            indent: 56, // Space for icon
            endIndent: 16,
          ),
        );
      }
    }

    return result;
  }
}
