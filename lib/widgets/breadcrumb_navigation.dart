import 'package:flutter/material.dart';
import '../models/navigation_context.dart';
import '../utils/navigation_helper.dart';

/// Breadcrumb navigation widget for showing navigation trail
class BreadcrumbNavigation extends StatelessWidget {
  final List<String> trail;
  final NavigationContext? navigationContext;
  final Function(int index)? onNavigate;
  final bool showBackButton;
  final String? customBackLabel;
  final VoidCallback? onBack;

  const BreadcrumbNavigation({
    super.key,
    required this.trail,
    this.navigationContext,
    this.onNavigate,
    this.showBackButton = true,
    this.customBackLabel,
    this.onBack,
  });

  /// Create breadcrumb from navigation context
  factory BreadcrumbNavigation.fromContext({
    required NavigationContext navigationContext,
    String? currentPageTitle,
    Function(int index)? onNavigate,
    bool showBackButton = true,
    VoidCallback? onBack,
  }) {
    List<String> trail = List.from(navigationContext.breadcrumbTrail);
    if (currentPageTitle != null) {
      trail.add(currentPageTitle);
    }

    return BreadcrumbNavigation(
      trail: trail,
      navigationContext: navigationContext,
      onNavigate: onNavigate,
      showBackButton: showBackButton,
      onBack: onBack,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (trail.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          // Back button
          if (showBackButton) ...[
            _buildBackButton(context, theme, colorScheme),
            const SizedBox(width: 8),
          ],

          // Breadcrumb trail
          Expanded(
            child: _buildBreadcrumbTrail(context, theme, colorScheme),
          ),
        ],
      ),
    );
  }

  Widget _buildBackButton(
      BuildContext context, ThemeData theme, ColorScheme colorScheme) {
    return InkWell(
      onTap: () {
        if (onBack != null) {
          onBack!();
        } else {
          NavigationHelper.navigateBack(
            context: context,
            navigationContext: navigationContext,
          );
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.arrow_back_ios,
              size: 16,
              color: colorScheme.primary,
            ),
            const SizedBox(width: 4),
            Text(
              customBackLabel ?? 'Back',
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBreadcrumbTrail(
      BuildContext context, ThemeData theme, ColorScheme colorScheme) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (int i = 0; i < trail.length; i++) ...[
            _buildBreadcrumbItem(
              context: context,
              theme: theme,
              colorScheme: colorScheme,
              text: trail[i],
              index: i,
              isLast: i == trail.length - 1,
              isClickable: i < trail.length - 1 && onNavigate != null,
            ),
            if (i < trail.length - 1) _buildSeparator(colorScheme),
          ],
        ],
      ),
    );
  }

  Widget _buildBreadcrumbItem({
    required BuildContext context,
    required ThemeData theme,
    required ColorScheme colorScheme,
    required String text,
    required int index,
    required bool isLast,
    required bool isClickable,
  }) {
    final textStyle = theme.textTheme.labelMedium?.copyWith(
      color: isLast
          ? colorScheme.onSurface
          : isClickable
              ? colorScheme.primary
              : colorScheme.onSurfaceVariant,
      fontWeight: isLast ? FontWeight.w600 : FontWeight.w400,
    );

    if (isClickable) {
      return InkWell(
        onTap: () => onNavigate!(index),
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Text(text, style: textStyle),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Text(text, style: textStyle),
    );
  }

  Widget _buildSeparator(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Icon(
        Icons.chevron_right,
        size: 16,
        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
      ),
    );
  }
}

/// Compact breadcrumb navigation for smaller spaces
class CompactBreadcrumbNavigation extends StatelessWidget {
  final List<String> trail;
  final NavigationContext? navigationContext;
  final VoidCallback? onBack;
  final int maxItems;

  const CompactBreadcrumbNavigation({
    super.key,
    required this.trail,
    this.navigationContext,
    this.onBack,
    this.maxItems = 2,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (trail.isEmpty) {
      return const SizedBox.shrink();
    }

    // Show only last few items
    final displayTrail = trail.length > maxItems
        ? ['...', ...trail.skip(trail.length - maxItems + 1)]
        : trail;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Back button
        InkWell(
          onTap: () {
            if (onBack != null) {
              onBack!();
            } else {
              NavigationHelper.navigateBack(
                context: context,
                navigationContext: navigationContext,
              );
            }
          },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(8),
            child: Icon(
              Icons.arrow_back,
              size: 20,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 8),

        // Compact trail
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int i = 0; i < displayTrail.length; i++) ...[
                Flexible(
                  child: Text(
                    displayTrail[i],
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: i == displayTrail.length - 1
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: i == displayTrail.length - 1
                          ? colorScheme.onSurface
                          : colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (i < displayTrail.length - 1) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right,
                    size: 16,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 4),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Smart breadcrumb that adapts to available space
class AdaptiveBreadcrumbNavigation extends StatelessWidget {
  final List<String> trail;
  final NavigationContext? navigationContext;
  final Function(int index)? onNavigate;
  final VoidCallback? onBack;

  const AdaptiveBreadcrumbNavigation({
    super.key,
    required this.trail,
    this.navigationContext,
    this.onNavigate,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Use compact version for narrow screens
        if (constraints.maxWidth < 400) {
          return CompactBreadcrumbNavigation(
            trail: trail,
            navigationContext: navigationContext,
            onBack: onBack,
            maxItems: 2,
          );
        }

        // Use full version for wider screens
        return BreadcrumbNavigation(
          trail: trail,
          navigationContext: navigationContext,
          onNavigate: onNavigate,
          onBack: onBack,
        );
      },
    );
  }
}

/// Breadcrumb navigation with source context display
class ContextualBreadcrumbNavigation extends StatelessWidget {
  final NavigationContext navigationContext;
  final String currentPageTitle;
  final Function(int index)? onNavigate;
  final VoidCallback? onBack;

  const ContextualBreadcrumbNavigation({
    super.key,
    required this.navigationContext,
    required this.currentPageTitle,
    this.onNavigate,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Source context
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Text(
            'From: ${navigationContext.getSourceDescription()}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
        ),

        // Main breadcrumb
        BreadcrumbNavigation.fromContext(
          navigationContext: navigationContext,
          currentPageTitle: currentPageTitle,
          onNavigate: onNavigate,
          onBack: onBack,
        ),
      ],
    );
  }
}
