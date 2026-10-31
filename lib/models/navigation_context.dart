/// Navigation context model for tracking user navigation flow
class NavigationContext {
  final String sourceScreen;
  final String? sourceTab;
  final String? sourceFilter;
  final Map<String, dynamic>? sourceData;
  final List<String> breadcrumbTrail;
  final String? returnRoute;
  final Map<String, dynamic>? returnArguments;

  const NavigationContext({
    required this.sourceScreen,
    this.sourceTab,
    this.sourceFilter,
    this.sourceData,
    this.breadcrumbTrail = const [],
    this.returnRoute,
    this.returnArguments,
  });

  /// Create navigation context for agenda screens
  factory NavigationContext.fromAgenda({
    required String tab,
    String? filter,
    Map<String, dynamic>? data,
  }) {
    return NavigationContext(
      sourceScreen: 'agenda',
      sourceTab: tab,
      sourceFilter: filter,
      sourceData: data,
      breadcrumbTrail: ['Agenda', _getTabDisplayName(tab)],
      returnRoute: '/main',
      returnArguments: {'initialIndex': 1}, // Agenda tab index
    );
  }

  /// Create navigation context for search screen
  factory NavigationContext.fromSearch({
    String? query,
    Map<String, dynamic>? filters,
  }) {
    return NavigationContext(
      sourceScreen: 'search',
      sourceData: {
        'query': query,
        'filters': filters,
      },
      breadcrumbTrail: ['Search', 'Results'],
      returnRoute: '/search',
    );
  }

  /// Create navigation context for focus screen
  factory NavigationContext.fromFocus({
    Map<String, dynamic>? sessionData,
  }) {
    return NavigationContext(
      sourceScreen: 'focus',
      sourceData: sessionData,
      breadcrumbTrail: ['Focus', 'Session'],
      returnRoute: '/main',
      returnArguments: {'initialIndex': 0}, // Focus tab index
    );
  }

  /// Create navigation context for notifications
  factory NavigationContext.fromNotification({
    required String notificationType,
    Map<String, dynamic>? notificationData,
  }) {
    return NavigationContext(
      sourceScreen: 'notification',
      sourceData: {
        'type': notificationType,
        'data': notificationData,
      },
      breadcrumbTrail: ['Notification'],
      returnRoute: '/main',
    );
  }

  /// Create navigation context for direct access
  factory NavigationContext.direct() {
    return const NavigationContext(
      sourceScreen: 'direct',
      breadcrumbTrail: ['Tasks'],
    );
  }

  /// Get display name for breadcrumb trail with task details
  List<String> getBreadcrumbWithTask(String taskTitle) {
    final trail = List<String>.from(breadcrumbTrail);
    trail.add(_truncateTitle(taskTitle));
    return trail;
  }

  /// Get return route with proper arguments
  String getReturnRoute() {
    return returnRoute ?? '/main';
  }

  /// Get return arguments
  Map<String, dynamic>? getReturnArguments() {
    return returnArguments;
  }

  /// Check if navigation has specific source
  bool isFromSource(String screen) {
    return sourceScreen == screen;
  }

  /// Check if navigation is from specific agenda tab
  bool isFromAgendaTab(String tab) {
    return sourceScreen == 'agenda' && sourceTab == tab;
  }

  /// Get source description for debugging
  String getSourceDescription() {
    switch (sourceScreen) {
      case 'agenda':
        return 'Agenda - ${_getTabDisplayName(sourceTab ?? 'today')}';
      case 'search':
        final query = sourceData?['query'] as String?;
        return 'Search${query != null ? ' - "$query"' : ''}';
      case 'focus':
        return 'Focus Session';
      case 'notification':
        final type = sourceData?['type'] as String?;
        return 'Notification${type != null ? ' - $type' : ''}';
      default:
        return 'Direct Access';
    }
  }

  /// Copy with new values
  NavigationContext copyWith({
    String? sourceScreen,
    String? sourceTab,
    String? sourceFilter,
    Map<String, dynamic>? sourceData,
    List<String>? breadcrumbTrail,
    String? returnRoute,
    Map<String, dynamic>? returnArguments,
  }) {
    return NavigationContext(
      sourceScreen: sourceScreen ?? this.sourceScreen,
      sourceTab: sourceTab ?? this.sourceTab,
      sourceFilter: sourceFilter ?? this.sourceFilter,
      sourceData: sourceData ?? this.sourceData,
      breadcrumbTrail: breadcrumbTrail ?? this.breadcrumbTrail,
      returnRoute: returnRoute ?? this.returnRoute,
      returnArguments: returnArguments ?? this.returnArguments,
    );
  }

  /// Convert to JSON for persistence
  Map<String, dynamic> toJson() {
    return {
      'sourceScreen': sourceScreen,
      'sourceTab': sourceTab,
      'sourceFilter': sourceFilter,
      'sourceData': sourceData,
      'breadcrumbTrail': breadcrumbTrail,
      'returnRoute': returnRoute,
      'returnArguments': returnArguments,
    };
  }

  /// Create from JSON
  factory NavigationContext.fromJson(Map<String, dynamic> json) {
    return NavigationContext(
      sourceScreen: json['sourceScreen'] ?? 'direct',
      sourceTab: json['sourceTab'],
      sourceFilter: json['sourceFilter'],
      sourceData: json['sourceData'] as Map<String, dynamic>?,
      breadcrumbTrail: List<String>.from(json['breadcrumbTrail'] ?? []),
      returnRoute: json['returnRoute'],
      returnArguments: json['returnArguments'] as Map<String, dynamic>?,
    );
  }

  // Helper methods
  static String _getTabDisplayName(String tab) {
    switch (tab.toLowerCase()) {
      case 'today':
        return 'Today';
      case 'upcoming':
        return 'Upcoming';
      case 'inprogress':
      case 'in_progress':
        return 'In Progress';
      case 'completed':
        return 'Completed';
      default:
        return tab;
    }
  }

  static String _truncateTitle(String title) {
    if (title.length <= 20) return title;
    return '${title.substring(0, 17)}...';
  }

  @override
  String toString() {
    return 'NavigationContext(source: $sourceScreen, tab: $sourceTab, trail: $breadcrumbTrail)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NavigationContext &&
        other.sourceScreen == sourceScreen &&
        other.sourceTab == sourceTab &&
        other.sourceFilter == sourceFilter &&
        other.returnRoute == returnRoute;
  }

  @override
  int get hashCode {
    return Object.hash(sourceScreen, sourceTab, sourceFilter, returnRoute);
  }
}

/// Navigation result for handling return values
class NavigationResult<T> {
  final T? data;
  final bool wasModified;
  final String? action;

  const NavigationResult({
    this.data,
    this.wasModified = false,
    this.action,
  });

  /// Create result for successful navigation
  factory NavigationResult.success({T? data, String? action}) {
    return NavigationResult(
      data: data,
      wasModified: true,
      action: action,
    );
  }

  /// Create result for cancelled navigation
  factory NavigationResult.cancelled() {
    return const NavigationResult(wasModified: false);
  }

  /// Create result with data
  factory NavigationResult.withData(T data, {String? action}) {
    return NavigationResult(
      data: data,
      wasModified: true,
      action: action,
    );
  }
}
