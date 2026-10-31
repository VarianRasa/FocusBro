import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_localizations.dart';

class HelpTipWidget extends StatefulWidget {
  final String tipId;
  final String title;
  final String description;
  final Widget child;
  final Alignment alignment;
  final EdgeInsets margin;
  final bool showOnFirstVisit;

  const HelpTipWidget({
    super.key,
    required this.tipId,
    required this.title,
    required this.description,
    required this.child,
    this.alignment = Alignment.topCenter,
    this.margin = const EdgeInsets.all(8.0),
    this.showOnFirstVisit = true,
  });

  @override
  State<HelpTipWidget> createState() => _HelpTipWidgetState();
}

class _HelpTipWidgetState extends State<HelpTipWidget> {
  bool _showTip = false;
  bool _helpTipsEnabled = true;
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    _checkAndShowTip();
  }

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  Future<void> _checkAndShowTip() async {
    final prefs = await SharedPreferences.getInstance();

    // Check if help tips are enabled
    _helpTipsEnabled = prefs.getBool('show_onboarding') ?? true;

    if (!_helpTipsEnabled) return;

    // Check if this tip has been shown before
    final hasSeenTip = prefs.getBool('tip_seen_${widget.tipId}') ?? false;

    if (widget.showOnFirstVisit && !hasSeenTip) {
      // Show tip after a short delay
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        _showHelpTip();
      }
    }
  }

  void _showHelpTip() {
    if (!_helpTipsEnabled || _overlayEntry != null) return;

    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);

    setState(() {
      _showTip = true;
    });
  }

  void _hideHelpTip() async {
    _removeOverlay();

    // Mark this tip as seen
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('tip_seen_${widget.tipId}', true);

    setState(() {
      _showTip = false;
    });
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  OverlayEntry _createOverlayEntry() {
    final renderBox = context.findRenderObject() as RenderBox?;
    final size = renderBox?.size ?? Size.zero;
    final offset = renderBox?.localToGlobal(Offset.zero) ?? Offset.zero;

    return OverlayEntry(
      builder: (context) => _HelpTipOverlay(
        targetOffset: offset,
        targetSize: size,
        title: widget.title,
        description: widget.description,
        alignment: widget.alignment,
        margin: widget.margin,
        onDismiss: _hideHelpTip,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: () {
        if (_helpTipsEnabled && !_showTip) {
          _showHelpTip();
        }
      },
      child: widget.child,
    );
  }
}

class _HelpTipOverlay extends StatefulWidget {
  final Offset targetOffset;
  final Size targetSize;
  final String title;
  final String description;
  final Alignment alignment;
  final EdgeInsets margin;
  final VoidCallback onDismiss;

  const _HelpTipOverlay({
    required this.targetOffset,
    required this.targetSize,
    required this.title,
    required this.description,
    required this.alignment,
    required this.margin,
    required this.onDismiss,
  });

  @override
  State<_HelpTipOverlay> createState() => _HelpTipOverlayState();
}

class _HelpTipOverlayState extends State<_HelpTipOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));

    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenSize = MediaQuery.of(context).size;

    // Calculate tip position
    double tipLeft = widget.targetOffset.dx;
    double tipTop = widget.targetOffset.dy + widget.targetSize.height + 8;

    // Adjust position if tip would go off screen
    if (tipLeft + 280 > screenSize.width) {
      tipLeft = screenSize.width - 280 - 16;
    }
    if (tipLeft < 16) {
      tipLeft = 16;
    }
    if (tipTop + 120 > screenSize.height) {
      tipTop = widget.targetOffset.dy - 120 - 8;
    }

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Stack(
          children: [
            // Backdrop
            GestureDetector(
              onTap: widget.onDismiss,
              child: Container(
                width: screenSize.width,
                height: screenSize.height,
                color: Colors.black.withOpacity(0.3 * _opacityAnimation.value),
              ),
            ),

            // Target highlight
            Positioned(
              left: widget.targetOffset.dx - 4,
              top: widget.targetOffset.dy - 4,
              child: Container(
                width: widget.targetSize.width + 8,
                height: widget.targetSize.height + 8,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: colorScheme.primary
                        .withOpacity(_opacityAnimation.value),
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),

            // Tip card
            Positioned(
              left: tipLeft,
              top: tipTop,
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: Opacity(
                  opacity: _opacityAnimation.value,
                  child: Container(
                    width: 280,
                    margin: widget.margin,
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withOpacity(0.1),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(12),
                              topRight: Radius.circular(12),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.lightbulb_outline,
                                color: colorScheme.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${l10n?.helpTip ?? 'Tip'}: ${widget.title}',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Content
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.description,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  height: 1.4,
                                ),
                              ),

                              const SizedBox(height: 16),

                              // Action button
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: widget.onDismiss,
                                  child: Text(
                                    l10n?.gotIt ?? 'Got it',
                                    style: TextStyle(
                                      color: colorScheme.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
