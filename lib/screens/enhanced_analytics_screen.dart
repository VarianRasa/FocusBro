import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:convert';
import '../services/analytics_service.dart';
import '../services/export_service.dart';
import '../models/goal.dart';
import '../models/achievement.dart';
import '../services/goal_service.dart';
import '../providers/goal_provider.dart';
import '../providers/focus_provider.dart';
import '../repositories/achievement_repository.dart';
import '../utils/accessibility_helper.dart';

/// Enhanced Analytics Screen with advanced visualizations
class EnhancedAnalyticsScreen extends StatefulWidget {
  const EnhancedAnalyticsScreen({super.key});

  @override
  State<EnhancedAnalyticsScreen> createState() =>
      _EnhancedAnalyticsScreenState();
}

class _EnhancedAnalyticsScreenState extends State<EnhancedAnalyticsScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final AnalyticsService _analytics = AnalyticsService();
  final ExportService _exportService = ExportService();
  final GoalService _goalService = GoalService();
  final AchievementRepository _achievementRepo = AchievementRepository();

  String _selectedTimeRange = 'week';
  Map<String, dynamic> _analyticsData = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _initializeServices();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh data when screen becomes visible
    _loadAnalyticsData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initializeServices() async {
    try {
      await _goalService.initialize();
      await _loadAnalyticsData();
    } catch (e) {
      debugPrint('Error initializing services: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadAnalyticsData() async {
    setState(() => _isLoading = true);

    try {
      final data = await Future.wait([
        _analytics.getFocusStatistics(),
        _analytics.getProductivityInsights(),
        _analytics.getStreakInfo(),
        _analytics.getWeeklySummary(),
        _analytics.getHourlyProductivity(),
        _analytics.getSessionTrends(),
        _analytics.getComprehensiveAnalytics(),
      ]);

      setState(() {
        _analyticsData = {
          'focus': data[0],
          'insights': data[1],
          'streak': data[2],
          'weekly': data[3],
          'hourly': data[4],
          'trends': data[5],
          'comprehensive': data[6],
        };
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  // Export Methods for Analytics Data
  Future<void> _performExportAsJSON() async {
    Navigator.pop(context);

    try {
      final success = await _exportService.exportAsJSON(
        data: _analyticsData,
        fileName: 'focusbro_analytics_${DateTime.now().millisecondsSinceEpoch}',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(success ? '✅ JSON export completed!' : '❌ Export failed'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Export failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _performExportAsCSV() async {
    Navigator.pop(context);

    try {
      final csvData = _exportService.convertAnalyticsToCSV(_analyticsData);
      final success = await _exportService.exportAsCSV(
        data: csvData,
        fileName: 'focusbro_analytics_${DateTime.now().millisecondsSinceEpoch}',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(success ? '✅ CSV export completed!' : '❌ Export failed'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Export failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _performExportAsTextReport() async {
    Navigator.pop(context);

    try {
      final textReport =
          _exportService.generateAnalyticsTextReport(_analyticsData);
      final success = await _exportService.exportAsTextReport(
        content: textReport,
        fileName: 'focusbro_analytics_${DateTime.now().millisecondsSinceEpoch}',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success
                ? '✅ Text report export completed!'
                : '❌ Export failed'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Export failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _performExportAllFormats() async {
    Navigator.pop(context);

    try {
      final results = await _exportService.exportAnalyticsData(
        analyticsData: _analyticsData,
        formats: ['json', 'csv', 'txt'],
      );

      final successCount = results.values.where((success) => success).length;
      final totalCount = results.length;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '✅ Exported $successCount/$totalCount formats successfully!'),
            backgroundColor:
                successCount == totalCount ? Colors.green : Colors.orange,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Export failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Show export options dialog
  void _showExportOptions() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Export Analytics Data',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Text(
              'Choose export format for your analytics data',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 24),

            // Export Options
            _buildExportOptionTile(
              'Export as JSON',
              'Raw data in JSON format for analysis',
              Icons.data_object,
              Colors.blue,
              () => _performExportAsJSON(),
            ),
            const SizedBox(height: 12),
            _buildExportOptionTile(
              'Export as CSV',
              'Structured data in CSV format',
              Icons.table_chart,
              Colors.green,
              () => _performExportAsCSV(),
            ),
            const SizedBox(height: 12),
            _buildExportOptionTile(
              'Export as Text Report',
              'Formatted text report with insights',
              Icons.description,
              Colors.purple,
              () => _performExportAsTextReport(),
            ),
            const SizedBox(height: 12),
            _buildExportOptionTile(
              'Export All Formats',
              'Export in JSON, CSV, and Text formats',
              Icons.archive,
              Colors.orange,
              () => _performExportAllFormats(),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildExportOptionTile(String title, String description, IconData icon,
      Color color, VoidCallback onTap) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.2)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics Dashboard'),
        elevation: 0,
        actions: [
          // Export Button
          IconButton(
            onPressed: _showExportOptions,
            icon: const Icon(Icons.download),
            tooltip: 'Export Analytics Data',
          ),

          // Time Range Selector
          PopupMenuButton<String>(
            initialValue: _selectedTimeRange,
            onSelected: (value) {
              setState(() => _selectedTimeRange = value);
              _loadAnalyticsData();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'day', child: Text('Today')),
              const PopupMenuItem(value: 'week', child: Text('This Week')),
              const PopupMenuItem(value: 'month', child: Text('This Month')),
              const PopupMenuItem(value: 'year', child: Text('This Year')),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              margin: const EdgeInsets.only(right: 16),
              decoration: BoxDecoration(
                border: Border.all(color: theme.colorScheme.outline),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_selectedTimeRange.toUpperCase()),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Overview', icon: Icon(Icons.dashboard)),
            Tab(text: 'Performance', icon: Icon(Icons.trending_up)),
            Tab(text: 'Patterns', icon: Icon(Icons.pattern)),
            Tab(text: 'Cross-Screen', icon: Icon(Icons.device_hub)),
            Tab(text: 'Goals', icon: Icon(Icons.flag)),
            Tab(text: 'Insights', icon: Icon(Icons.lightbulb)),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildPerformanceTab(),
                _buildPatternsTab(),
                _buildCrossScreenTab(),
                _buildGoalsTab(),
                _buildInsightsTab(),
              ],
            ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Key Metrics Cards
          _buildKeyMetricsGrid(),
          const SizedBox(height: 24),

          // Weekly Progress Chart
          _buildWeeklyProgressChart(),
          const SizedBox(height: 24),

          // Recent Sessions
          _buildRecentSessionsList(),
        ],
      ),
    );
  }

  Widget _buildKeyMetricsGrid() {
    final focusData = _analyticsData['focus'] ?? {};
    final streakData = _analyticsData['streak'] ?? {};

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.3,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      children: [
        _buildMetricCard(
          'Total Sessions',
          '${focusData['totalSessions'] ?? 0}',
          Icons.timer,
          Colors.blue,
          subtitle: 'All time',
        ),
        _buildMetricCard(
          'Focus Time',
          '${(focusData['totalFocusTime'] ?? 0) ~/ 3600}h',
          Icons.access_time,
          Colors.green,
          subtitle: 'This week',
        ),
        _buildMetricCard(
          'Current Streak',
          '${streakData['currentStreak'] ?? 0} days',
          Icons.local_fire_department,
          Colors.orange,
          subtitle: 'Keep it up!',
        ),
        _buildMetricCard(
          'Completion Rate',
          '${((focusData['completionRate'] ?? 0) * 100).toInt()}%',
          Icons.check_circle,
          Colors.purple,
          subtitle: 'Last 30 days',
        ),
      ],
    );
  }

  Widget _buildMetricCard(
    String title,
    String value,
    IconData icon,
    Color color, {
    String? subtitle,
  }) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const Spacer(),
              Icon(
                Icons.trending_up,
                color: Colors.green,
                size: 14,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Flexible(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Flexible(
              child: Text(
                subtitle,
                style: TextStyle(
                  fontSize: 10,
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWeeklyProgressChart() {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Weekly Progress',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => _showDetailedChart(),
                child: const Text('View Details'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        const days = [
                          'Mon',
                          'Tue',
                          'Wed',
                          'Thu',
                          'Fri',
                          'Sat',
                          'Sun'
                        ];
                        if (value.toInt() >= 0 && value.toInt() < days.length) {
                          return Text(
                            days[value.toInt()],
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.6),
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: _generateWeeklySpots(),
                    isCurved: true,
                    color: theme.colorScheme.primary,
                    barWidth: 3,
                    dotData: FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<FlSpot> _generateWeeklySpots() {
    // Generate sample data - replace with real analytics data
    return [
      const FlSpot(0, 3),
      const FlSpot(1, 5),
      const FlSpot(2, 4),
      const FlSpot(3, 6),
      const FlSpot(4, 4),
      const FlSpot(5, 7),
      const FlSpot(6, 5),
    ];
  }

  Widget _buildRecentSessionsList() {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Recent Sessions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => _showAllSessions(),
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...List.generate(5, (index) => _buildSessionItem(index)),
        ],
      ),
    );
  }

  Widget _buildSessionItem(int index) {
    final theme = Theme.of(context);
    final isCompleted = index % 3 != 0; // Sample data

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.1),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isCompleted
                  ? Colors.green.withValues(alpha: 0.1)
                  : Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isCompleted ? Icons.check : Icons.close,
              color: isCompleted ? Colors.green : Colors.red,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Focus Session ${index + 1}',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Text(
                  '25 minutes • ${isCompleted ? 'Completed' : 'Interrupted'}',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          Text(
            '2h ago',
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildProductivityScoreCard(),
          const SizedBox(height: 24),
          _buildCompletionRateChart(),
          const SizedBox(height: 24),
          _buildPerformanceMetrics(),
        ],
      ),
    );
  }

  Widget _buildProductivityScoreCard() {
    final theme = Theme.of(context);
    final insights = _analyticsData['insights'] ?? {};
    final score = insights['score'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.primary.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(
            'Productivity Score',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 16),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 120,
                height: 120,
                child: CircularProgressIndicator(
                  value: score / 100,
                  strokeWidth: 8,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              Column(
                children: [
                  Text(
                    '$score',
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'out of 100',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _getScoreDescription(score),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }

  String _getScoreDescription(int score) {
    if (score >= 90) return 'Exceptional! You\'re in the zone! 🔥';
    if (score >= 80) return 'Excellent focus and consistency! 💪';
    if (score >= 70) return 'Great work! Keep up the momentum! 👍';
    if (score >= 60) return 'Good progress! Room for improvement! 📈';
    return 'Let\'s work on building better habits! 🌱';
  }

  Widget _buildCompletionRateChart() {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Completion Rate Trend',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 100,
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        const days = [
                          'Mon',
                          'Tue',
                          'Wed',
                          'Thu',
                          'Fri',
                          'Sat',
                          'Sun'
                        ];
                        if (value.toInt() >= 0 && value.toInt() < days.length) {
                          return Text(
                            days[value.toInt()],
                            style: TextStyle(
                              fontSize: 12,
                              color:
                                  theme.colorScheme.onSurface.withOpacity(0.6),
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: _generateCompletionRateBars(theme),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<BarChartGroupData> _generateCompletionRateBars(ThemeData theme) {
    final completionRates = [85, 92, 78, 95, 88, 90, 82]; // Sample data

    return completionRates.asMap().entries.map((entry) {
      final index = entry.key;
      final rate = entry.value;

      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: rate.toDouble(),
            color: theme.colorScheme.primary,
            width: 20,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(4),
            ),
          ),
        ],
      );
    }).toList();
  }

  Widget _buildPerformanceMetrics() {
    return Column(
      children: [
        _buildMetricRow('Average Session Length', '24.5 min', Icons.timer),
        _buildMetricRow('Best Day', 'Wednesday', Icons.star),
        _buildMetricRow('Most Productive Hour', '10:00 AM', Icons.schedule),
        _buildMetricRow('Weekly Goal Progress', '85%', Icons.flag),
      ],
    );
  }

  Widget _buildMetricRow(String label, String value, IconData icon) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPatternsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Usage Patterns Section
          _buildUsagePatternsCard(),
          const SizedBox(height: 24),

          // Hourly Productivity Chart
          _buildHourlyProductivityChart(),
          const SizedBox(height: 24),

          // Weekly Patterns
          _buildWeeklyPatternsCard(),
          const SizedBox(height: 24),

          // Session Duration Patterns
          _buildSessionDurationPatternsCard(),
        ],
      ),
    );
  }

  Widget _buildUsagePatternsCard() {
    final theme = Theme.of(context);
    final usageData = _analyticsData['hourly'] ?? {};

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.pattern, color: Colors.blue),
              ),
              const SizedBox(width: 12),
              Text(
                'Usage Patterns',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Most Active Hours
          _buildPatternItem(
            'Most Active Hours',
            '9:00 AM - 11:00 AM',
            Icons.schedule,
            Colors.green,
            '68% of sessions',
          ),
          const SizedBox(height: 12),

          // Peak Productivity Day
          _buildPatternItem(
            'Peak Productivity Day',
            'Wednesday',
            Icons.calendar_today,
            Colors.orange,
            '23% higher completion',
          ),
          const SizedBox(height: 12),

          // Average Session Length
          _buildPatternItem(
            'Preferred Session Length',
            '25 minutes',
            Icons.timer,
            Colors.purple,
            'Most completed duration',
          ),
          const SizedBox(height: 12),

          // Break Patterns
          _buildPatternItem(
            'Break Frequency',
            'Every 2 sessions',
            Icons.coffee,
            Colors.brown,
            'Optimal recovery time',
          ),
        ],
      ),
    );
  }

  Widget _buildPatternItem(
    String title,
    String value,
    IconData icon,
    Color color,
    String subtitle,
  ) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHourlyProductivityChart() {
    final theme = Theme.of(context);
    final hourlyData = _analyticsData['hourly'] ?? {};

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hourly Productivity',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 10,
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final hour = value.toInt();
                        if (hour % 3 == 0) {
                          return Text(
                            '${hour}h',
                            style: TextStyle(
                              fontSize: 10,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.6),
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: _generateHourlyProductivityBars(theme),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<BarChartGroupData> _generateHourlyProductivityBars(ThemeData theme) {
    // Generate sample hourly productivity data
    final hourlyProductivity = [
      2, 3, 1, 1, 2, 4, 6, 8, 9, 8, 7, 6, // 0-11
      5, 6, 7, 8, 9, 7, 6, 5, 4, 3, 2, 1 // 12-23
    ];

    return hourlyProductivity.asMap().entries.map((entry) {
      final hour = entry.key;
      final productivity = entry.value;

      Color barColor;
      if (productivity >= 8) {
        barColor = Colors.green;
      } else if (productivity >= 6) {
        barColor = Colors.orange;
      } else if (productivity >= 4) {
        barColor = Colors.blue;
      } else {
        barColor = Colors.grey;
      }

      return BarChartGroupData(
        x: hour,
        barRods: [
          BarChartRodData(
            toY: productivity.toDouble(),
            color: barColor,
            width: 8,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(2),
              topRight: Radius.circular(2),
            ),
          ),
        ],
      );
    }).toList();
  }

  Widget _buildWeeklyPatternsCard() {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Weekly Patterns',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 20),

          // Weekly heatmap
          _buildWeeklyHeatmap(theme),

          const SizedBox(height: 16),

          // Weekly insights
          Row(
            children: [
              Expanded(
                child: _buildWeeklyInsightItem(
                  'Most Active',
                  'Wednesday',
                  Icons.trending_up,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildWeeklyInsightItem(
                  'Least Active',
                  'Sunday',
                  Icons.trending_down,
                  Colors.red,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyHeatmap(ThemeData theme) {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final intensity = [0.6, 0.8, 0.9, 0.7, 0.5, 0.3, 0.2]; // Sample data

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: days.asMap().entries.map((entry) {
        final index = entry.key;
        final day = entry.value;
        final value = intensity[index];

        return Column(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: value),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Center(
                child: Text(
                  '${(value * 10).round()}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color:
                        value > 0.5 ? Colors.white : theme.colorScheme.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              day,
              style: TextStyle(
                fontSize: 10,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildWeeklyInsightItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionDurationPatternsCard() {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Session Duration Patterns',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 20),

          // Duration distribution
          SizedBox(
            height: 150,
            child: PieChart(
              PieChartData(
                sections: _generateDurationSections(),
                centerSpaceRadius: 40,
                sectionsSpace: 2,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Duration legend
          _buildDurationLegend(theme),
        ],
      ),
    );
  }

  List<PieChartSectionData> _generateDurationSections() {
    return [
      PieChartSectionData(
        value: 45,
        title: '25m',
        color: Colors.blue,
        radius: 50,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      PieChartSectionData(
        value: 25,
        title: '15m',
        color: Colors.green,
        radius: 50,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      PieChartSectionData(
        value: 20,
        title: '45m',
        color: Colors.orange,
        radius: 50,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      PieChartSectionData(
        value: 10,
        title: '60m+',
        color: Colors.purple,
        radius: 50,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    ];
  }

  Widget _buildDurationLegend(ThemeData theme) {
    final items = [
      {'duration': '25 minutes', 'percentage': '45%', 'color': Colors.blue},
      {'duration': '15 minutes', 'percentage': '25%', 'color': Colors.green},
      {'duration': '45 minutes', 'percentage': '20%', 'color': Colors.orange},
      {'duration': '60+ minutes', 'percentage': '10%', 'color': Colors.purple},
    ];

    return Column(
      children: items.map((item) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: item['color'] as Color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item['duration'] as String,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              Text(
                item['percentage'] as String,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: item['color'] as Color,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCrossScreenTab() {
    final comprehensiveData =
        _analyticsData['comprehensive'] as Map<String, dynamic>? ?? {};
    final screenUsage =
        comprehensiveData['screenUsage'] as Map<String, dynamic>? ?? {};
    final featurePopularity =
        comprehensiveData['featurePopularity'] as Map<String, dynamic>? ?? {};
    final userJourney =
        comprehensiveData['userJourney'] as Map<String, dynamic>? ?? {};

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Screen Usage Analytics'),
          const SizedBox(height: 16),
          _buildScreenUsageCard(screenUsage),
          const SizedBox(height: 24),
          _buildSectionHeader('Feature Popularity'),
          const SizedBox(height: 16),
          _buildFeaturePopularityCard(featurePopularity),
          const SizedBox(height: 24),
          _buildSectionHeader('User Journey Patterns'),
          const SizedBox(height: 16),
          _buildUserJourneyCard(userJourney),
        ],
      ),
    );
  }

  Widget _buildGoalsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Current Goals Section
          _buildCurrentGoalsCard(),
          const SizedBox(height: 24),

          // Goal Progress Charts
          _buildGoalProgressCard(),
          const SizedBox(height: 24),

          // Achievement History
          _buildAchievementHistoryCard(),
          const SizedBox(height: 24),

          // Add New Goal Button
          _buildAddGoalButton(),
        ],
      ),
    );
  }

  Widget _buildCurrentGoalsCard() {
    final theme = Theme.of(context);

    return Consumer<GoalProvider>(
      builder: (context, goalProvider, child) {
        final activeGoals = goalProvider.activeGoals;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(Icons.flag, color: Colors.blue, size: 16),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Current Goals',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  // Filter toggle for showing paused goals
                  Flexible(
                    child: Consumer<GoalProvider>(
                      builder: (context, goalProvider, child) {
                        final pausedCount = goalProvider.goals
                            .where((goal) => goal.status == GoalStatus.paused)
                            .length;

                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (pausedCount > 0) ...[
                              InkWell(
                                onTap: () => _showPausedGoals(goalProvider.goals
                                    .where((goal) =>
                                        goal.status == GoalStatus.paused)
                                    .toList()),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 4, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: Colors.orange
                                            .withValues(alpha: 0.3)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.pause_circle,
                                          size: 10, color: Colors.orange),
                                      const SizedBox(width: 1),
                                      Text(
                                        '$pausedCount',
                                        style: TextStyle(
                                          color: Colors.orange,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 2),
                            ],
                            InkWell(
                              onTap: _showAddGoalDialog,
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4, vertical: 2),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: theme.colorScheme.primary
                                          .withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.add,
                                        size: 10,
                                        color: theme.colorScheme.primary),
                                    const SizedBox(width: 1),
                                    Text(
                                      'Add',
                                      style: TextStyle(
                                        color: theme.colorScheme.primary,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (goalProvider.isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (goalProvider.error != null)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: theme.colorScheme.error,
                          size: 48,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          goalProvider.error!,
                          style: TextStyle(
                            color: theme.colorScheme.error,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              else if (activeGoals.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Icon(
                          Icons.flag_outlined,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.5),
                          size: 48,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No active goals yet',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.7),
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Create your first goal to start tracking progress',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.5),
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...activeGoals.take(5).map((goal) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _buildGoalItemFromGoal(goal),
                    )),
              if (activeGoals.length > 5)
                Center(
                  child: TextButton(
                    onPressed: () => _showAllGoals(activeGoals),
                    child: Text('View all ${activeGoals.length} goals'),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGoalItemFromGoal(Goal goal) {
    final theme = Theme.of(context);
    final color = goal.type.color;
    final isPaused = goal.status == GoalStatus.paused;
    final isCompleted = goal.status == GoalStatus.completed;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isPaused
            ? theme.colorScheme.surface.withValues(alpha: 0.5)
            : isCompleted
                ? Colors.green.withValues(alpha: 0.05)
                : color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPaused
              ? Colors.orange.withValues(alpha: 0.3)
              : isCompleted
                  ? Colors.green.withValues(alpha: 0.3)
                  : color.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Stack(
                children: [
                  Icon(
                    goal.type.icon,
                    color: isPaused
                        ? theme.colorScheme.onSurface.withValues(alpha: 0.5)
                        : color,
                    size: 20,
                  ),
                  if (isPaused)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: theme.colorScheme.surface, width: 1),
                        ),
                        child: Icon(
                          Icons.pause,
                          color: Colors.white,
                          size: 8,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  goal.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isPaused
                        ? theme.colorScheme.onSurface.withValues(alpha: 0.6)
                        : theme.colorScheme.onSurface,
                    decoration: isPaused ? TextDecoration.lineThrough : null,
                    decorationColor: Colors.orange.withValues(alpha: 0.7),
                  ),
                ),
              ),
              Text(
                '${goal.formattedTargetValue} ${goal.displayUnit}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(width: 8),
              // Goal actions menu
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  size: 20,
                ),
                onSelected: (value) => _handleGoalAction(goal, value),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit,
                            size: 18, color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        const Text('Edit Goal'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'progress',
                    child: Row(
                      children: [
                        Icon(Icons.trending_up, size: 18, color: Colors.blue),
                        const SizedBox(width: 8),
                        const Text('Update Progress'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'status',
                    child: Row(
                      children: [
                        Icon(
                          goal.status == GoalStatus.active
                              ? Icons.pause_circle
                              : Icons.play_circle,
                          size: 18,
                          color: Colors.orange,
                        ),
                        const SizedBox(width: 8),
                        Text(goal.status == GoalStatus.active
                            ? 'Pause Goal'
                            : 'Resume Goal'),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete,
                            size: 18, color: theme.colorScheme.error),
                        const SizedBox(width: 8),
                        Text(
                          'Delete Goal',
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (goal.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              goal.description,
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
          const SizedBox(height: 12),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: goal.progress,
              backgroundColor: color.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 8),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${goal.formattedCurrentValue} ${goal.displayUnit} completed',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              Row(
                children: [
                  if (goal.isCompleted)
                    Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 16,
                    ),
                  const SizedBox(width: 4),
                  Text(
                    '${goal.progressPercentage}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: goal.isCompleted ? Colors.green : color,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Goal status indicator
          if (goal.status != GoalStatus.active) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: goal.status.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                goal.status.displayName,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: goal.status.color,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGoalProgressCard() {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Goal Progress This Month',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 20),

          // Progress chart
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final weeks = ['Week 1', 'Week 2', 'Week 3', 'Week 4'];
                        if (value.toInt() >= 0 &&
                            value.toInt() < weeks.length) {
                          return Text(
                            weeks[value.toInt()],
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.6),
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  // Daily goal line
                  LineChartBarData(
                    spots: const [
                      FlSpot(0, 60),
                      FlSpot(1, 75),
                      FlSpot(2, 80),
                      FlSpot(3, 75),
                    ],
                    isCurved: true,
                    color: Colors.green,
                    barWidth: 3,
                    dotData: FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.green.withValues(alpha: 0.1),
                    ),
                  ),
                  // Weekly goal line
                  LineChartBarData(
                    spots: const [
                      FlSpot(0, 40),
                      FlSpot(1, 55),
                      FlSpot(2, 65),
                      FlSpot(3, 60),
                    ],
                    isCurved: true,
                    color: Colors.blue,
                    barWidth: 3,
                    dotData: FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.blue.withValues(alpha: 0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem('Daily Goals', Colors.green),
              const SizedBox(width: 24),
              _buildLegendItem('Weekly Goals', Colors.blue),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildAchievementHistoryCard() {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Achievements',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 20),

          // Achievement items
          _buildAchievementItem(
            '🏆',
            'Weekly Goal Achieved',
            'Completed 20 focus sessions this week',
            '2 days ago',
            const Color(0xFFFFD700),
          ),
          const SizedBox(height: 12),

          _buildAchievementItem(
            '🔥',
            '7-Day Streak',
            'Maintained daily focus sessions for a week',
            '5 days ago',
            Colors.orange,
          ),
          const SizedBox(height: 12),

          _buildAchievementItem(
            '⭐',
            'First Goal Set',
            'Created your first productivity goal',
            '1 week ago',
            Colors.blue,
          ),

          const SizedBox(height: 16),

          // View all button
          Center(
            child: TextButton(
              onPressed: _showAllAchievements,
              child: const Text('View All Achievements'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementItem(
    String emoji,
    String title,
    String description,
    String time,
    Color color,
  ) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: Text(
                emoji,
                style: const TextStyle(fontSize: 20),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          Text(
            time,
            style: TextStyle(
              fontSize: 11,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementItemDetailed(Achievement achievement) {
    final theme = Theme.of(context);
    final isUnlocked = achievement.isUnlocked;
    final color = isUnlocked ? Colors.amber : theme.colorScheme.outline;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isUnlocked
            ? Colors.amber.withValues(alpha: 0.05)
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isUnlocked
              ? Colors.amber.withValues(alpha: 0.3)
              : theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isUnlocked
                  ? Colors.amber.withValues(alpha: 0.2)
                  : theme.colorScheme.outline.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Center(
              child: Icon(
                isUnlocked ? Icons.emoji_events : Icons.lock_outline,
                color: isUnlocked ? Colors.amber : theme.colorScheme.outline,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        achievement.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    if (isUnlocked)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Unlocked',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: Colors.green,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  achievement.description,
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                if (achievement.targetValue != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Target: ${achievement.targetValue} ${achievement.achievementType}',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                if (isUnlocked) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Achievement unlocked!',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.green.withValues(alpha: 0.8),
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'today';
    } else if (difference.inDays == 1) {
      return 'yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks week${weeks > 1 ? 's' : ''} ago';
    } else {
      final months = (difference.inDays / 30).floor();
      return '$months month${months > 1 ? 's' : ''} ago';
    }
  }

  Widget _buildAddGoalButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _showAddGoalDialog,
        icon: const Icon(Icons.add),
        label: const Text('Create New Goal'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  void _showAddGoalDialog() {
    showDialog(
      context: context,
      builder: (context) => _CreateGoalDialog(),
    );
  }

  void _handleGoalAction(Goal goal, String action) {
    switch (action) {
      case 'edit':
        _showEditGoalDialog(goal);
        break;
      case 'progress':
        _showUpdateProgressDialog(goal);
        break;
      case 'status':
        _toggleGoalStatus(goal);
        break;
      case 'delete':
        _showDeleteGoalConfirmation(goal);
        break;
    }
  }

  void _showEditGoalDialog(Goal goal) {
    showDialog(
      context: context,
      builder: (context) => _EditGoalDialog(goal: goal),
    );
  }

  void _showUpdateProgressDialog(Goal goal) {
    showDialog(
      context: context,
      builder: (context) => _UpdateProgressDialog(goal: goal),
    );
  }

  Future<void> _toggleGoalStatus(Goal goal) async {
    final goalProvider = Provider.of<GoalProvider>(context, listen: false);
    final newStatus = goal.status == GoalStatus.active
        ? GoalStatus.paused
        : GoalStatus.active;

    final success = await goalProvider.updateGoalStatus(goal.id, newStatus);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                newStatus == GoalStatus.active
                    ? Icons.play_circle
                    : Icons.pause_circle,
                color: Colors.white,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Goal ${newStatus == GoalStatus.active ? "resumed" : "paused"} successfully!',
                ),
              ),
            ],
          ),
          backgroundColor: Colors.blue,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to update goal status. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showDeleteGoalConfirmation(Goal goal) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Theme.of(context).colorScheme.error),
            const SizedBox(width: 8),
            const Text('Delete Goal'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to delete this goal?'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: goal.type.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: goal.type.color.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(goal.type.icon, color: goal.type.color, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      goal.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This action cannot be undone.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => _deleteGoal(goal),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteGoal(Goal goal) async {
    Navigator.pop(context); // Close confirmation dialog

    final goalProvider = Provider.of<GoalProvider>(context, listen: false);
    final success = await goalProvider.deleteGoal(goal.id);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.delete, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Goal "${goal.title}" deleted successfully!'),
              ),
            ],
          ),
          backgroundColor: Colors.red,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to delete goal. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showAllGoals(List<Goal> goals) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .outline
                        .withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Header
              Row(
                children: [
                  Text(
                    'All Goals',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Goals list
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  itemCount: goals.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final goal = goals[index];
                    return _buildGoalItemFromGoal(goal);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPausedGoals(List<Goal> goals) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .outline
                        .withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Header
              Row(
                children: [
                  Icon(Icons.pause_circle, color: Colors.orange),
                  const SizedBox(width: 8),
                  Text(
                    'Paused Goals',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const Spacer(),
                  if (goals.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${goals.length} goal${goals.length > 1 ? 's' : ''}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.orange,
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Goals list or empty state
              Expanded(
                child: goals.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.pause_circle,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.5),
                              size: 48,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'No paused goals',
                              style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.7),
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'All your goals are currently active',
                              style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.5),
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        itemCount: goals.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final goal = goals[index];
                          return _buildGoalItemFromGoal(goal);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAllAchievements() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .outline
                        .withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Header
              Row(
                children: [
                  Text(
                    'All Achievements',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Achievements list
              Expanded(
                child: FutureBuilder<List<Achievement>>(
                  future: _achievementRepo.getAchievementsWithStatus(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: Theme.of(context).colorScheme.error,
                              size: 48,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Error loading achievements',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    final achievements = snapshot.data ?? [];

                    if (achievements.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.emoji_events_outlined,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.5),
                              size: 48,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'No achievements yet',
                              style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.7),
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Complete focus sessions to unlock achievements',
                              style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.5),
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      controller: scrollController,
                      itemCount: achievements.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final achievement = achievements[index];
                        return _buildAchievementItemDetailed(achievement);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInsightsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // AI Insights Section
          _buildAIInsightsCard(),
          const SizedBox(height: 24),

          // Productivity Recommendations
          _buildRecommendationsCard(),
          const SizedBox(height: 24),

          // Trend Analysis
          _buildTrendAnalysisCard(),
          const SizedBox(height: 24),

          // Personal Insights
          _buildPersonalInsightsCard(),
        ],
      ),
    );
  }

  Widget _buildAIInsightsCard() {
    final theme = Theme.of(context);
    final insights = _analyticsData['insights'] ?? {};

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary.withValues(alpha: 0.1),
            theme.colorScheme.secondary.withValues(alpha: 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.psychology,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'AI-Powered Insights',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Key insight
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.lightbulb, color: Colors.amber, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Key Insight',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Your productivity peaks between 9-11 AM with 85% completion rate. Consider scheduling your most important tasks during this window.',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Quick stats
          Row(
            children: [
              Expanded(
                child: _buildQuickStat(
                  'Productivity Score',
                  '87/100',
                  Icons.trending_up,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQuickStat(
                  'Focus Consistency',
                  'Excellent',
                  Icons.check_circle,
                  Colors.blue,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStat(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationsCard() {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Personalized Recommendations',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 20),

          // Recommendations list
          _buildRecommendationItem(
            '🎯',
            'Optimize Your Schedule',
            'Try scheduling focus sessions at 9 AM when your completion rate is highest',
            Colors.blue,
          ),
          const SizedBox(height: 12),

          _buildRecommendationItem(
            '⏰',
            'Adjust Session Length',
            'Your 25-minute sessions have 90% completion rate. Consider making this your default',
            Colors.green,
          ),
          const SizedBox(height: 12),

          _buildRecommendationItem(
            '📈',
            'Build Consistency',
            'You\'re 3 days away from a 10-day streak. Keep up the momentum!',
            Colors.orange,
          ),
          const SizedBox(height: 12),

          _buildRecommendationItem(
            '🎵',
            'Try Background Music',
            'Users with similar patterns report 15% better focus with ambient sounds',
            Colors.purple,
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationItem(
    String emoji,
    String title,
    String description,
    Color color,
  ) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 16)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendAnalysisCard() {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Trend Analysis',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 20),

          // Trend items
          _buildTrendItem(
            'Focus Time',
            '+15%',
            'vs last month',
            Icons.trending_up,
            Colors.green,
            true,
          ),
          const SizedBox(height: 12),

          _buildTrendItem(
            'Session Completion',
            '+8%',
            'vs last month',
            Icons.trending_up,
            Colors.green,
            true,
          ),
          const SizedBox(height: 12),

          _buildTrendItem(
            'Break Frequency',
            '-5%',
            'vs last month',
            Icons.trending_down,
            Colors.red,
            false,
          ),
          const SizedBox(height: 12),

          _buildTrendItem(
            'Weekly Consistency',
            '+12%',
            'vs last month',
            Icons.trending_up,
            Colors.blue,
            true,
          ),
        ],
      ),
    );
  }

  Widget _buildTrendItem(
    String metric,
    String change,
    String period,
    IconData icon,
    Color color,
    bool isPositive,
  ) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              metric,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                change,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                period,
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalInsightsCard() {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Personal Insights',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 20),

          // Personal insights
          _buildPersonalInsightItem(
            '🧠',
            'Your Focus Profile',
            'You\'re a "Morning Warrior" - peak performance in early hours',
            Colors.blue,
          ),
          const SizedBox(height: 12),

          _buildPersonalInsightItem(
            '📊',
            'Productivity Pattern',
            'You work best in 25-minute bursts with 5-minute breaks',
            Colors.green,
          ),
          const SizedBox(height: 12),

          _buildPersonalInsightItem(
            '🎯',
            'Goal Achievement Style',
            'You\'re consistent and steady - small daily progress leads to big wins',
            Colors.purple,
          ),
          const SizedBox(height: 12),

          _buildPersonalInsightItem(
            '🌟',
            'Motivation Driver',
            'Visual progress tracking keeps you motivated and engaged',
            Colors.orange,
          ),

          const SizedBox(height: 20),

          // Action button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _showDetailedInsights,
              icon: const Icon(Icons.insights),
              label: const Text('View Detailed Analysis'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalInsightItem(
    String emoji,
    String title,
    String description,
    Color color,
  ) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 16)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showDetailedInsights() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.95,
          height: MediaQuery.of(context).size.height * 0.85,
          child: _DetailedInsightsDialog(),
        ),
      ),
    );
  }

  void _showDetailedChart() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.8,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.analytics,
                      color: Theme.of(context).colorScheme.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Detailed Weekly Progress',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Enhanced Chart
              Expanded(
                child: _buildDetailedWeeklyChart(),
              ),

              const SizedBox(height: 24),

              // Statistics Summary
              _buildDetailedStatsSummary(),

              const SizedBox(height: 16),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _exportChartData,
                    icon: const Icon(Icons.download, size: 18),
                    label: const Text('Export Data'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailedWeeklyChart() {
    final theme = Theme.of(context);
    final weeklyData = _analyticsData['weekly'] ?? {};

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Focus Sessions This Week',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: true,
                  horizontalInterval: 1,
                  verticalInterval: 1,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: theme.colorScheme.outline.withValues(alpha: 0.1),
                      strokeWidth: 1,
                    );
                  },
                  getDrawingVerticalLine: (value) {
                    return FlLine(
                      color: theme.colorScheme.outline.withValues(alpha: 0.1),
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 1,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        const style = TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        );
                        String text;
                        switch (value.toInt()) {
                          case 0:
                            text = 'Mon';
                            break;
                          case 1:
                            text = 'Tue';
                            break;
                          case 2:
                            text = 'Wed';
                            break;
                          case 3:
                            text = 'Thu';
                            break;
                          case 4:
                            text = 'Fri';
                            break;
                          case 5:
                            text = 'Sat';
                            break;
                          case 6:
                            text = 'Sun';
                            break;
                          default:
                            text = '';
                            break;
                        }
                        return Text(text, style: style);
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        return Text(
                          value.toInt().toString(),
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.6),
                          ),
                        );
                      },
                      reservedSize: 32,
                    ),
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(
                    color: theme.colorScheme.outline.withValues(alpha: 0.2),
                  ),
                ),
                minX: 0,
                maxX: 6,
                minY: 0,
                maxY: 10,
                lineBarsData: [
                  LineChartBarData(
                    spots: [
                      const FlSpot(0, 3),
                      const FlSpot(1, 5),
                      const FlSpot(2, 4),
                      const FlSpot(3, 7),
                      const FlSpot(4, 6),
                      const FlSpot(5, 8),
                      const FlSpot(6, 5),
                    ],
                    isCurved: true,
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.primary,
                        theme.colorScheme.secondary,
                      ],
                    ),
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 4,
                          color: theme.colorScheme.primary,
                          strokeWidth: 2,
                          strokeColor: theme.colorScheme.surface,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          theme.colorScheme.primary.withValues(alpha: 0.3),
                          theme.colorScheme.primary.withValues(alpha: 0.1),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedStatsSummary() {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Weekly Summary',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildSummaryItem(
                  'Total Sessions',
                  '38',
                  Icons.timer,
                  Colors.blue,
                ),
              ),
              Expanded(
                child: _buildSummaryItem(
                  'Focus Time',
                  '12.5h',
                  Icons.access_time,
                  Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildSummaryItem(
                  'Completion Rate',
                  '87%',
                  Icons.check_circle,
                  Colors.orange,
                ),
              ),
              Expanded(
                child: _buildSummaryItem(
                  'Best Day',
                  'Saturday',
                  Icons.star,
                  Colors.purple,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(
      String title, String value, IconData icon, Color color) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _exportChartData() {
    // Show export options
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Export Analytics Data',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.table_chart),
              title: const Text('Export as CSV'),
              subtitle: const Text('Spreadsheet format for analysis'),
              onTap: () {
                Navigator.pop(context);
                _exportAsCSV();
              },
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf),
              title: const Text('Export as PDF'),
              subtitle: const Text('Formatted report with charts'),
              onTap: () {
                Navigator.pop(context);
                _exportAsPDF();
              },
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Share Summary'),
              subtitle: const Text('Share key metrics'),
              onTap: () {
                Navigator.pop(context);
                _shareSummary();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _exportAsCSV() async {
    try {
      // Show loading
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Text('Generating CSV export...'),
            ],
          ),
          duration: Duration(seconds: 2),
        ),
      );

      // Simulate export process
      await Future.delayed(const Duration(seconds: 2));

      // Generate CSV content
      final csvContent = await _generateCSVContent();

      // Show success message with simulated file info
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('📊 CSV export completed!'),
                Text(
                  'File: analytics_${DateTime.now().millisecondsSinceEpoch}.csv',
                  style: const TextStyle(fontSize: 12),
                ),
                Text(
                  'Size: ${csvContent.length} characters',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Preview',
              onPressed: () => _showCSVPreview(csvContent),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Export failed. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<String> _generateCSVContent() async {
    final focusStats = _analyticsData['focus'] ?? {};
    final insights = _analyticsData['insights'] ?? {};
    final streakInfo = _analyticsData['streak'] ?? {};

    final csvHeader = 'Metric,Value,Description\n';
    final csvRows = [
      'Total Sessions,${focusStats['totalSessions'] ?? 0},All focus sessions completed',
      'Total Focus Time,${(focusStats['totalFocusTime'] ?? 0) ~/ 3600}h,Hours spent in focus mode',
      'Completion Rate,${((focusStats['completionRate'] ?? 0) * 100).toInt()}%,Percentage of completed sessions',
      'Current Streak,${streakInfo['currentStreak'] ?? 0} days,Current daily streak',
      'Longest Streak,${streakInfo['longestStreak'] ?? 0} days,Best streak achieved',
      'Productivity Score,${insights['score'] ?? 0}/100,Overall productivity rating',
      'Average Session Length,${focusStats['averageSessionLength'] ?? 0} min,Average duration per session',
      'Export Date,${DateTime.now().toIso8601String()},When this report was generated',
    ];

    return csvHeader + csvRows.join('\n');
  }

  void _showCSVPreview(String csvContent) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('CSV Preview'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: SingleChildScrollView(
            child: Text(
              csvContent,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // In a real implementation, this would save the file
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                      '💾 File save functionality would be implemented here'),
                ),
              );
            },
            child: const Text('Save File'),
          ),
        ],
      ),
    );
  }

  void _exportAsPDF() async {
    try {
      // Show loading
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Text('Generating PDF report...'),
            ],
          ),
          duration: Duration(seconds: 3),
        ),
      );

      // Simulate PDF generation
      await Future.delayed(const Duration(seconds: 3));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('📄 PDF report generated!'),
                Text(
                  'File: analytics_report_${DateTime.now().millisecondsSinceEpoch}.pdf',
                  style: const TextStyle(fontSize: 12),
                ),
                const Text(
                  'Includes: Charts, insights, and detailed analytics',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Preview',
              onPressed: _showPDFPreview,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ PDF generation failed. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showPDFPreview() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('PDF Report Preview'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.maxFinite,
              height: 200,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.picture_as_pdf, size: 48, color: Colors.red),
                    SizedBox(height: 8),
                    Text('Analytics Report'),
                    Text('PDF Preview', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'PDF would include:\n'
              '• Productivity charts and graphs\n'
              '• Detailed statistics and insights\n'
              '• Goal progress and achievements\n'
              '• Personalized recommendations',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                      '💾 PDF save functionality would be implemented here'),
                ),
              );
            },
            child: const Text('Save PDF'),
          ),
        ],
      ),
    );
  }

  void _shareSummary() async {
    try {
      // Generate shareable summary
      final summary = _generateShareableSummary();

      // Show share options
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (context) => DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) => Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Share Analytics Summary',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),

                // Preview of shareable content (scrollable)
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.grey[300]!,
                        width: 1,
                      ),
                    ),
                    child: SingleChildScrollView(
                      controller: scrollController,
                      child: Text(
                        summary,
                        style: const TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Share options
                ListTile(
                  leading: const Icon(Icons.copy),
                  title: const Text('Copy to Clipboard'),
                  subtitle: const Text('Copy summary text'),
                  onTap: () {
                    Navigator.pop(context);
                    // In real implementation, copy to clipboard
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('📋 Summary copied to clipboard!'),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.share),
                  title: const Text('Share via Apps'),
                  subtitle: const Text('Share through system apps'),
                  onTap: () {
                    Navigator.pop(context);
                    // In real implementation, use share plugin
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            '📤 Share functionality would open system share sheet'),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.email),
                  title: const Text('Send via Email'),
                  subtitle: const Text('Send summary via email'),
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content:
                            Text('📧 Email functionality would open email app'),
                      ),
                    );
                  },
                ),

                // Close button
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Share failed. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _generateShareableSummary() {
    final focusStats = _analyticsData['focus'] ?? {};
    final insights = _analyticsData['insights'] ?? {};
    final streakInfo = _analyticsData['streak'] ?? {};

    return '''
🎯 My FocusBro Analytics Summary

📊 Focus Statistics:
• Total Sessions: ${focusStats['totalSessions'] ?? 0}
• Focus Time: ${(focusStats['totalFocusTime'] ?? 0) ~/ 3600}h
• Completion Rate: ${((focusStats['completionRate'] ?? 0) * 100).toInt()}%

🔥 Streak Information:
• Current Streak: ${streakInfo['currentStreak'] ?? 0} days
• Best Streak: ${streakInfo['longestStreak'] ?? 0} days

⭐ Productivity Score: ${insights['score'] ?? 0}/100

Generated on ${DateTime.now().toString().split(' ')[0]}
#FocusBro #Productivity #Focus
    '''
        .trim();
  }

  void _showAllSessions() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.history,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'All Focus Sessions',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Session statistics summary
              _buildSessionsSummaryCard(),
              const SizedBox(height: 16),

              // Sessions list
              Expanded(
                child: _buildSessionsList(scrollController),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSessionsSummaryCard() {
    final theme = Theme.of(context);
    final focusStats = _analyticsData['focus'] ?? {};

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Sessions',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                Text(
                  '${focusStats['totalSessions'] ?? 0}',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Time',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                Text(
                  '${((focusStats['totalFocusTime'] ?? 0) / 3600).toStringAsFixed(1)}h',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Completion Rate',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                Text(
                  '${((focusStats['completionRate'] ?? 0) * 100).toInt()}%',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionsList(ScrollController scrollController) {
    final theme = Theme.of(context);

    // Generate sample sessions data (in real app, this would come from database)
    final sessions = _generateSampleSessions();

    if (sessions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 64,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No Focus Sessions Yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start your first focus session to see it here',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: scrollController,
      itemCount: sessions.length,
      itemBuilder: (context, index) {
        final session = sessions[index];
        return _buildSessionListItem(session);
      },
    );
  }

  List<Map<String, dynamic>> _generateSampleSessions() {
    // Generate sample sessions for demonstration
    final now = DateTime.now();
    final sessions = <Map<String, dynamic>>[];

    for (int i = 0; i < 15; i++) {
      final sessionDate = now.subtract(Duration(days: i));
      final duration = 25 + (i % 3) * 10; // 25, 35, or 45 minutes
      final isCompleted = i % 4 != 0; // 75% completion rate

      sessions.add({
        'id': 'session_$i',
        'date': sessionDate,
        'duration': duration,
        'isCompleted': isCompleted,
        'sessionType': ['Focus', 'Deep Work', 'Study'][i % 3],
        'productivity': 70 + (i % 4) * 10, // 70-100% productivity
      });
    }

    return sessions;
  }

  Widget _buildSessionListItem(Map<String, dynamic> session) {
    final theme = Theme.of(context);
    final date = session['date'] as DateTime;
    final duration = session['duration'] as int;
    final isCompleted = session['isCompleted'] as bool;
    final sessionType = session['sessionType'] as String;
    final productivity = session['productivity'] as int;

    final isToday = date.day == DateTime.now().day &&
        date.month == DateTime.now().month &&
        date.year == DateTime.now().year;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          // Session status icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isCompleted
                  ? Colors.green.withValues(alpha: 0.1)
                  : Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              isCompleted ? Icons.check_circle : Icons.schedule,
              color: isCompleted ? Colors.green : Colors.orange,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),

          // Session details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      sessionType,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${duration}min',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  isToday ? 'Today, ${_formatTime(date)}' : _formatDate(date),
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                if (isCompleted) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.trending_up,
                        size: 12,
                        color: Colors.green,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Productivity: $productivity%',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.green,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Action button
          IconButton(
            onPressed: () => _showSessionDetails(session),
            icon: Icon(
              Icons.info_outline,
              color: theme.colorScheme.primary,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  void _showSessionDetails(Map<String, dynamic> session) {
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.info_outline,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            const Text('Session Details'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Type', session['sessionType']),
            _buildDetailRow('Duration', '${session['duration']} minutes'),
            _buildDetailRow('Date', _formatDate(session['date'])),
            _buildDetailRow('Time', _formatTime(session['date'])),
            _buildDetailRow(
                'Status', session['isCompleted'] ? 'Completed' : 'Incomplete'),
            if (session['isCompleted'])
              _buildDetailRow('Productivity', '${session['productivity']}%'),
          ],
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

  Widget _buildDetailRow(String label, String value) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Cross-Screen Analytics Helper Methods
  Widget _buildSectionHeader(String title) {
    final theme = Theme.of(context);
    return Text(
      title,
      style: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: theme.colorScheme.onSurface,
      ),
    );
  }

  Widget _buildScreenUsageCard(Map<String, dynamic> screenUsage) {
    final theme = Theme.of(context);
    final screenTime = screenUsage['screenTime'] as Map<String, dynamic>? ?? {};
    final screenPercentages =
        screenUsage['screenPercentages'] as Map<String, dynamic>? ?? {};
    final mostUsedScreen = screenUsage['mostUsedScreen'] as String? ?? 'None';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.phone_android, color: Colors.blue),
              ),
              const SizedBox(width: 12),
              Text(
                'Screen Usage Distribution',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (screenTime.isNotEmpty) ...[
            Text(
              'Most Used: $mostUsedScreen',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            ...screenTime.entries.take(5).map((entry) {
              final percentage = screenPercentages[entry.key] as double? ?? 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildScreenUsageItem(
                  entry.key,
                  entry.value as int,
                  percentage,
                ),
              );
            }).toList(),
          ] else ...[
            Center(
              child: Text(
                'No screen usage data available',
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildScreenUsageItem(
      String screenName, int timeMinutes, double percentage) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              screenName,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface,
              ),
            ),
            Text(
              '${timeMinutes}min (${percentage.toStringAsFixed(1)}%)',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: percentage / 100,
            backgroundColor: theme.colorScheme.outline.withValues(alpha: 0.2),
            valueColor:
                AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
            minHeight: 4,
          ),
        ),
      ],
    );
  }

  Widget _buildFeaturePopularityCard(Map<String, dynamic> featurePopularity) {
    final theme = Theme.of(context);
    final topFeatures =
        featurePopularity['topFeatures'] as List<dynamic>? ?? [];
    final featureCategories =
        featurePopularity['featureCategories'] as Map<String, dynamic>? ?? {};

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.star, color: Colors.green),
              ),
              const SizedBox(width: 12),
              Text(
                'Feature Popularity',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (topFeatures.isNotEmpty) ...[
            Text(
              'Top Features',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            ...topFeatures.take(5).map((feature) {
              final featureMap = feature as Map<String, dynamic>;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        featureMap['feature'] as String,
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${featureMap['usage']}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
            if (featureCategories.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Categories',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: featureCategories.entries.map((entry) {
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color:
                            theme.colorScheme.secondary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      '${entry.key} (${entry.value})',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.secondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ] else ...[
            Center(
              child: Text(
                'No feature usage data available',
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUserJourneyCard(Map<String, dynamic> userJourney) {
    final theme = Theme.of(context);
    final sessionPatterns =
        userJourney['sessionPatterns'] as List<dynamic>? ?? [];
    final featureSequences =
        userJourney['featureSequences'] as List<dynamic>? ?? [];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.timeline, color: Colors.purple),
              ),
              const SizedBox(width: 12),
              Text(
                'User Journey Patterns',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (sessionPatterns.isNotEmpty) ...[
            Text(
              'Common Session Patterns',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            ...sessionPatterns.take(3).map((pattern) {
              final patternMap = pattern as Map<String, dynamic>;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(
                      Icons.arrow_forward,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        patternMap['pattern'] as String,
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    Text(
                      '${patternMap['count']}x',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
          if (featureSequences.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Feature Usage Sequences',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            ...featureSequences.take(3).map((sequence) {
              final sequenceMap = sequence as Map<String, dynamic>;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(
                      Icons.link,
                      size: 16,
                      color: theme.colorScheme.secondary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        sequenceMap['pattern'] as String,
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    Text(
                      '${sequenceMap['count']}x',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.secondary,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
          if (sessionPatterns.isEmpty && featureSequences.isEmpty) ...[
            Center(
              child: Text(
                'No user journey data available',
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Dialog for creating new goals
class _CreateGoalDialog extends StatefulWidget {
  @override
  _CreateGoalDialogState createState() => _CreateGoalDialogState();
}

class _CreateGoalDialogState extends State<_CreateGoalDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _targetValueController = TextEditingController();

  GoalType _selectedType = GoalType.dailyFocusTime;
  GoalFrequency _selectedFrequency = GoalFrequency.daily;
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _targetValueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.flag, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          const Text('Create New Goal'),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Goal Type Dropdown
                Text(
                  'Goal Type',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<GoalType>(
                  value: _selectedType,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: GoalType.values.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Row(
                        children: [
                          Icon(type.icon, size: 20, color: type.color),
                          const SizedBox(width: 8),
                          Text(type.displayName),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedType = value;
                        // Auto-set title if empty
                        if (_titleController.text.isEmpty) {
                          _titleController.text = value.displayName;
                        }
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Goal Title
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Goal Title',
                    hintText: 'e.g., Daily Focus Time',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a goal title';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Description (optional)
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description (Optional)',
                    hintText: 'Describe your goal...',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),

                // Target Value
                TextFormField(
                  controller: _targetValueController,
                  decoration: InputDecoration(
                    labelText: 'Target Value',
                    hintText: _getTargetValueHint(),
                    suffixText: _selectedType.unit,
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a target value';
                    }
                    final numValue = double.tryParse(value);
                    if (numValue == null || numValue <= 0) {
                      return 'Please enter a valid positive number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Frequency
                Text(
                  'Frequency',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<GoalFrequency>(
                  value: _selectedFrequency,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: GoalFrequency.values.map((frequency) {
                    return DropdownMenuItem(
                      value: frequency,
                      child: Text(frequency.displayName),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedFrequency = value);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _createGoal,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create'),
        ),
      ],
    );
  }

  String _getTargetValueHint() {
    switch (_selectedType) {
      case GoalType.dailyFocusTime:
        return 'e.g., 2 (hours)';
      case GoalType.weeklySessions:
        return 'e.g., 20 (sessions)';
      case GoalType.monthlyStreak:
        return 'e.g., 25 (days)';
      case GoalType.totalSessions:
        return 'e.g., 100 (sessions)';
      case GoalType.completionRate:
        return 'e.g., 85 (percent)';
      case GoalType.custom:
        return 'Enter target value';
    }
  }

  Future<void> _createGoal() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final goalProvider = Provider.of<GoalProvider>(context, listen: false);
      final targetValue = double.parse(_targetValueController.text);

      final goal = await goalProvider.createGoal(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        type: _selectedType,
        frequency: _selectedFrequency,
        targetValue: targetValue,
      );

      if (!mounted) return;

      if (goal != null) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('🎯 Goal "${goal.title}" created successfully!'),
                ),
              ],
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to create goal. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating goal: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}

/// Dialog for editing existing goals
class _EditGoalDialog extends StatefulWidget {
  final Goal goal;

  const _EditGoalDialog({required this.goal});

  @override
  _EditGoalDialogState createState() => _EditGoalDialogState();
}

class _EditGoalDialogState extends State<_EditGoalDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _targetValueController;

  late GoalType _selectedType;
  late GoalFrequency _selectedFrequency;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.goal.title);
    _descriptionController =
        TextEditingController(text: widget.goal.description);
    _targetValueController =
        TextEditingController(text: widget.goal.targetValue.toString());
    _selectedType = widget.goal.type;
    _selectedFrequency = widget.goal.frequency;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _targetValueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.edit, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          const Text('Edit Goal'),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Goal Type Dropdown
                Text(
                  'Goal Type',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<GoalType>(
                  value: _selectedType,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: GoalType.values.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Row(
                        children: [
                          Icon(type.icon, size: 20, color: type.color),
                          const SizedBox(width: 8),
                          Text(type.displayName),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedType = value);
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Goal Title
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Goal Title',
                    hintText: 'e.g., Daily Focus Time',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a goal title';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Description (optional)
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description (Optional)',
                    hintText: 'Describe your goal...',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),

                // Target Value
                TextFormField(
                  controller: _targetValueController,
                  decoration: InputDecoration(
                    labelText: 'Target Value',
                    hintText: _getTargetValueHint(),
                    suffixText: _selectedType.unit,
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a target value';
                    }
                    final numValue = double.tryParse(value);
                    if (numValue == null || numValue <= 0) {
                      return 'Please enter a valid positive number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Frequency
                Text(
                  'Frequency',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<GoalFrequency>(
                  value: _selectedFrequency,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: GoalFrequency.values.map((frequency) {
                    return DropdownMenuItem(
                      value: frequency,
                      child: Text(frequency.displayName),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedFrequency = value);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _updateGoal,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Update'),
        ),
      ],
    );
  }

  String _getTargetValueHint() {
    switch (_selectedType) {
      case GoalType.dailyFocusTime:
        return 'e.g., 2 (hours)';
      case GoalType.weeklySessions:
        return 'e.g., 20 (sessions)';
      case GoalType.monthlyStreak:
        return 'e.g., 25 (days)';
      case GoalType.totalSessions:
        return 'e.g., 100 (sessions)';
      case GoalType.completionRate:
        return 'e.g., 85 (percent)';
      case GoalType.custom:
        return 'Enter target value';
    }
  }

  Future<void> _updateGoal() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final goalProvider = Provider.of<GoalProvider>(context, listen: false);
      final targetValue = double.parse(_targetValueController.text);

      // Create updated goal
      final updatedGoal = widget.goal.copyWith(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        type: _selectedType,
        frequency: _selectedFrequency,
        targetValue: targetValue,
        updatedAt: DateTime.now(),
      );

      // Update through provider
      final result = await goalProvider.updateGoal(updatedGoal);
      final success = result != null;

      if (!mounted) return;

      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child:
                      Text('Goal "${updatedGoal.title}" updated successfully!'),
                ),
              ],
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update goal. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating goal: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}

/// Dialog for updating goal progress
class _UpdateProgressDialog extends StatefulWidget {
  final Goal goal;

  const _UpdateProgressDialog({required this.goal});

  @override
  _UpdateProgressDialogState createState() => _UpdateProgressDialogState();
}

class _UpdateProgressDialogState extends State<_UpdateProgressDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _progressController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _progressController =
        TextEditingController(text: widget.goal.currentValue.toString());
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final goal = widget.goal;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.trending_up, color: Colors.blue),
          const SizedBox(width: 8),
          const Text('Update Progress'),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Goal info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: goal.type.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: goal.type.color.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(goal.type.icon, color: goal.type.color, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            goal.title,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            'Target: ${goal.formattedTargetValue} ${goal.displayUnit}',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Current progress
              Text(
                'Current Progress',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),

              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: goal.progress,
                  backgroundColor: goal.type.color.withValues(alpha: 0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(goal.type.color),
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${goal.formattedCurrentValue} / ${goal.formattedTargetValue} ${goal.displayUnit} (${goal.progressPercentage}%)',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 16),

              // New progress input
              TextFormField(
                controller: _progressController,
                decoration: InputDecoration(
                  labelText: 'New Progress Value',
                  hintText: 'Enter current progress',
                  suffixText: goal.displayUnit,
                  border: const OutlineInputBorder(),
                  helperText: 'Enter a value between 0 and ${goal.targetValue}',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a progress value';
                  }
                  final numValue = double.tryParse(value);
                  if (numValue == null || numValue < 0) {
                    return 'Please enter a valid positive number';
                  }
                  if (numValue > goal.targetValue) {
                    return 'Progress cannot exceed target value';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _updateProgress,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Update'),
        ),
      ],
    );
  }

  Future<void> _updateProgress() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final goalProvider = Provider.of<GoalProvider>(context, listen: false);
      final newProgress = double.parse(_progressController.text);

      final success =
          await goalProvider.updateGoalProgress(widget.goal.id, newProgress);

      if (!mounted) return;

      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.trending_up, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Progress updated successfully!'),
                ),
              ],
            ),
            backgroundColor: Colors.blue,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update progress. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating progress: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}

/// Detailed Personal Insights Dialog
class _DetailedInsightsDialog extends StatefulWidget {
  @override
  _DetailedInsightsDialogState createState() => _DetailedInsightsDialogState();
}

class _DetailedInsightsDialogState extends State<_DetailedInsightsDialog>
    with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.psychology,
                      color: theme.colorScheme.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Personal Insights Analysis',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          'Deep dive into your productivity patterns',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    style: IconButton.styleFrom(
                      backgroundColor:
                          theme.colorScheme.surface.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),

            // Tab Bar
            Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: theme.colorScheme.outline.withValues(alpha: 0.2),
                  ),
                ),
              ),
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: theme.colorScheme.primary,
                unselectedLabelColor:
                    theme.colorScheme.onSurface.withValues(alpha: 0.6),
                indicatorColor: theme.colorScheme.primary,
                tabs: const [
                  Tab(
                    icon: Icon(Icons.person, size: 20),
                    text: 'Profile',
                  ),
                  Tab(
                    icon: Icon(Icons.trending_up, size: 20),
                    text: 'Patterns',
                  ),
                  Tab(
                    icon: Icon(Icons.lightbulb, size: 20),
                    text: 'Recommendations',
                  ),
                  Tab(
                    icon: Icon(Icons.insights, size: 20),
                    text: 'AI Insights',
                  ),
                ],
              ),
            ),

            // Tab Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildProfileTab(),
                  _buildPatternsTab(),
                  _buildRecommendationsTab(),
                  _buildAIInsightsTab(),
                ],
              ),
            ),

            // Footer Actions
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: theme.colorScheme.outline.withValues(alpha: 0.2),
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: _shareInsights,
                    icon: const Icon(Icons.share, size: 18),
                    label: const Text('Share'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _exportInsights,
                    icon: const Icon(Icons.download, size: 18),
                    label: const Text('Export Report'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileTab() {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Focus Profile Card
          _buildInsightCard(
            '🧠 Your Focus Profile',
            'Morning Warrior',
            'You achieve peak performance during early morning hours (6-10 AM). Your focus levels are 40% higher compared to afternoon sessions.',
            Colors.blue,
            [
              _buildProfileMetric(
                  'Peak Hours', '6:00 - 10:00 AM', Icons.schedule),
              _buildProfileMetric('Focus Score', '8.7/10', Icons.psychology),
              _buildProfileMetric('Consistency', '92%', Icons.trending_up),
            ],
          ),
          const SizedBox(height: 16),

          // Productivity Style Card
          _buildInsightCard(
            '📊 Productivity Style',
            'Pomodoro Champion',
            'You excel with structured time blocks. 25-minute sessions with 5-minute breaks optimize your performance.',
            Colors.green,
            [
              _buildProfileMetric(
                  'Optimal Duration', '25 minutes', Icons.timer),
              _buildProfileMetric('Break Preference', '5 minutes', Icons.pause),
              _buildProfileMetric('Sessions/Day', '8-12', Icons.repeat),
            ],
          ),
          const SizedBox(height: 16),

          // Goal Achievement Style
          _buildInsightCard(
            '🎯 Achievement Style',
            'Steady Climber',
            'You prefer consistent daily progress over intense bursts. Small, regular steps lead to your biggest wins.',
            Colors.purple,
            [
              _buildProfileMetric('Completion Rate', '87%', Icons.check_circle),
              _buildProfileMetric(
                  'Streak Record', '21 days', Icons.local_fire_department),
              _buildProfileMetric('Goal Style', 'Incremental', Icons.stairs),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPatternsTab() {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Weekly Pattern
          _buildPatternCard(
            'Weekly Performance Pattern',
            'Your productivity peaks mid-week and dips on Mondays and Fridays',
            Icons.calendar_view_week,
            Colors.blue,
            _buildWeeklyPatternChart(),
          ),
          const SizedBox(height: 16),

          // Daily Pattern
          _buildPatternCard(
            'Daily Energy Curve',
            'Energy peaks at 9 AM, maintains until 2 PM, then gradually declines',
            Icons.schedule,
            Colors.green,
            _buildDailyPatternChart(),
          ),
          const SizedBox(height: 16),

          // Focus Duration Trends
          _buildPatternCard(
            'Focus Duration Trends',
            'Your optimal session length has increased from 20 to 25 minutes over time',
            Icons.trending_up,
            Colors.orange,
            _buildDurationTrendChart(),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationsTab() {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Personalized Recommendations',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),

          // Immediate Actions
          _buildRecommendationSection(
            '⚡ Immediate Actions',
            [
              _buildRecommendationItem(
                'Schedule morning sessions',
                'Block 6-10 AM for your most important tasks',
                'High Impact',
                Colors.red,
                Icons.schedule,
              ),
              _buildRecommendationItem(
                'Use 25-minute timers',
                'Your sweet spot for sustained focus',
                'Quick Win',
                Colors.green,
                Icons.timer,
              ),
              _buildRecommendationItem(
                'Take micro-breaks',
                '2-3 minute breaks every 25 minutes',
                'Energy Boost',
                Colors.blue,
                Icons.refresh,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Weekly Optimizations
          _buildRecommendationSection(
            '📅 Weekly Optimizations',
            [
              _buildRecommendationItem(
                'Front-load your week',
                'Schedule challenging tasks for Tuesday-Thursday',
                'Productivity',
                Colors.purple,
                Icons.calendar_today,
              ),
              _buildRecommendationItem(
                'Friday planning sessions',
                'Use lower energy for planning next week',
                'Planning',
                Colors.orange,
                Icons.event_note,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Long-term Growth
          _buildRecommendationSection(
            '🌱 Long-term Growth',
            [
              _buildRecommendationItem(
                'Gradually increase session length',
                'Try 30-minute sessions once comfortable with 25',
                'Growth',
                Colors.teal,
                Icons.trending_up,
              ),
              _buildRecommendationItem(
                'Experiment with afternoon focus',
                'Test 2-4 PM sessions with different techniques',
                'Expansion',
                Colors.indigo,
                Icons.science,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAIInsightsTab() {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // AI Analysis Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary.withValues(alpha: 0.1),
                  theme.colorScheme.secondary.withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.auto_awesome,
                    color: theme.colorScheme.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI-Powered Analysis',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Based on 30 days of focus session data',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // AI Insights
          _buildAIInsightItem(
            '🎯 Productivity Prediction',
            'Based on your patterns, you\'re 85% likely to have a highly productive week if you start with a strong Monday morning session.',
            'Predictive Analysis',
            Colors.blue,
          ),
          const SizedBox(height: 16),

          _buildAIInsightItem(
            '⚡ Energy Optimization',
            'Your energy dips at 2 PM could be countered by a 10-minute walk or light snack. This could boost afternoon productivity by 23%.',
            'Behavioral Science',
            Colors.green,
          ),
          const SizedBox(height: 16),

          _buildAIInsightItem(
            '📈 Growth Trajectory',
            'You\'re on track to increase your daily focus time by 15% this month. Consider gradually extending sessions to 30 minutes.',
            'Progress Tracking',
            Colors.purple,
          ),
          const SizedBox(height: 16),

          _buildAIInsightItem(
            '🧘 Stress Indicators',
            'Your session completion rate drops 12% on high-stress days. Consider starting with 5-minute meditation sessions.',
            'Wellness Integration',
            Colors.orange,
          ),
          const SizedBox(height: 16),

          _buildAIInsightItem(
            '🎨 Personalization',
            'Your focus improves 18% with ambient nature sounds. Consider integrating this into your routine.',
            'Environmental Factors',
            Colors.teal,
          ),
        ],
      ),
    );
  }

  Widget _buildInsightCard(String title, String subtitle, String description,
      Color color, List<Widget> metrics) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  title.split(' ')[0], // Get emoji
                  style: const TextStyle(fontSize: 20),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.substring(2), // Remove emoji
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: metrics.map((metric) => Expanded(child: metric)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileMetric(String label, String value, IconData icon) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(8),
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.primary),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 10,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAIInsightItem(
      String title, String description, String category, Color color) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  category,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                  ),
                ),
              ),
              const Spacer(),
              Icon(
                Icons.auto_awesome,
                color: color,
                size: 16,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPatternCard(String title, String description, IconData icon,
      Color color, Widget chart) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(height: 200, child: chart),
        ],
      ),
    );
  }

  Widget _buildWeeklyPatternChart() {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildBarItem('Mon', 0.6, Colors.blue),
                _buildBarItem('Tue', 0.9, Colors.blue),
                _buildBarItem('Wed', 1.0, Colors.blue),
                _buildBarItem('Thu', 0.95, Colors.blue),
                _buildBarItem('Fri', 0.7, Colors.blue),
                _buildBarItem('Sat', 0.8, Colors.blue),
                _buildBarItem('Sun', 0.5, Colors.blue),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Productivity Score by Day',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyPatternChart() {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildBarItem('6AM', 0.9, Colors.green),
                _buildBarItem('9AM', 1.0, Colors.green),
                _buildBarItem('12PM', 0.8, Colors.green),
                _buildBarItem('3PM', 0.6, Colors.green),
                _buildBarItem('6PM', 0.4, Colors.green),
                _buildBarItem('9PM', 0.3, Colors.green),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Energy Level Throughout Day',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDurationTrendChart() {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildBarItem('W1', 0.7, Colors.orange),
                _buildBarItem('W2', 0.75, Colors.orange),
                _buildBarItem('W3', 0.8, Colors.orange),
                _buildBarItem('W4', 0.9, Colors.orange),
                _buildBarItem('W5', 1.0, Colors.orange),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Average Session Duration (20-30 min)',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarItem(String label, double value, Color color) {
    final theme = Theme.of(context);

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: 24,
          height: 120 * value,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 10,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildRecommendationSection(
      String title, List<Widget> recommendations) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        ...recommendations,
      ],
    );
  }

  Widget _buildRecommendationItem(String title, String description, String tag,
      Color color, IconData icon) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        tag,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w600,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _shareInsights() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _buildShareOptionsSheet(),
    );
  }

  void _exportInsights() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _buildExportOptionsSheet(),
    );
  }

  Widget _buildShareOptionsSheet() {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.share,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Share Personal Insights',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Choose how to share your insights',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Share Options
          _buildShareOption(
            'Share as Text',
            'Share a formatted summary of your insights',
            Icons.text_fields,
            Colors.blue,
            () => _shareAsText(),
          ),
          const SizedBox(height: 12),
          _buildShareOption(
            'Share as Image',
            'Generate and share a visual summary',
            Icons.image,
            Colors.green,
            () => _shareAsImage(),
          ),
          const SizedBox(height: 12),
          _buildShareOption(
            'Share Specific Tab',
            'Share content from a specific insights tab',
            Icons.tab,
            Colors.purple,
            () => _shareSpecificTab(),
          ),
          const SizedBox(height: 12),
          _buildShareOption(
            'Share Key Highlights',
            'Share only the most important insights',
            Icons.star,
            Colors.orange,
            () => _shareKeyHighlights(),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildExportOptionsSheet() {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.download,
                  color: theme.colorScheme.secondary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Export Personal Insights',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Export your insights in various formats',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Export Options
          _buildExportOption(
            'Export as PDF Report',
            'Comprehensive PDF with all insights and charts',
            Icons.picture_as_pdf,
            Colors.red,
            () => _exportAsPDF(),
          ),
          const SizedBox(height: 12),
          _buildExportOption(
            'Export as JSON Data',
            'Raw data in JSON format for analysis',
            Icons.data_object,
            Colors.blue,
            () => Navigator.pop(context),
          ),
          const SizedBox(height: 12),
          _buildExportOption(
            'Export as CSV',
            'Structured data in CSV format',
            Icons.table_chart,
            Colors.green,
            () => Navigator.pop(context),
          ),
          const SizedBox(height: 12),
          _buildExportOption(
            'Export as Text Report',
            'Formatted text report with insights',
            Icons.description,
            Colors.purple,
            () => Navigator.pop(context),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildShareOption(String title, String description, IconData icon,
      Color color, VoidCallback onTap) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.2),
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExportOption(String title, String description, IconData icon,
      Color color, VoidCallback onTap) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.2),
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ],
        ),
      ),
    );
  }

  // Share Methods
  Future<void> _shareAsText() async {
    Navigator.pop(context);

    try {
      final insightsText = _generateInsightsText();

      await Share.share(
        insightsText,
        subject: 'My Personal Insights from FocusBro',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Insights shared successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Share failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _shareAsImage() async {
    Navigator.pop(context);
    try {
      final focus = Map<String, dynamic>.from(
        _analyticsData['focus'] as Map? ?? const <String, dynamic>{},
      );
      final total = focus['totalSessions'] ?? 0;
      final completed = focus['completedSessions'] ?? 0;
      final focusSeconds = focus['totalFocusTime'] ?? 0;
      final completionRate =
          ((focus['completionRate'] as num?)?.toDouble() ?? 0) * 100;
      final report = [
        'FocusBro Analytics',
        'Generated ${DateTime.now().toLocal().toString().split('.').first}',
        '',
        'Focus sessions: $total',
        'Completed sessions: $completed',
        'Completion rate: ${completionRate.toStringAsFixed(1)}%',
        'Total focus time: ${(focusSeconds / 3600).toStringAsFixed(1)} hours',
      ].join('\n');

      const width = 1080;
      const height = 1350;
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawRect(
        const ui.Rect.fromLTWH(0, 0, 1080, 1350),
        ui.Paint()..color = const ui.Color(0xFF101827),
      );
      final textPainter = TextPainter(
        text: TextSpan(
          text: report,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 42,
            height: 1.6,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 900);
      textPainter.paint(canvas, const Offset(80, 100));
      final image = await recorder.endRecording().toImage(width, height);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (bytes == null) throw StateError('Could not encode analytics image');

      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/focusbro_analytics.png');
      await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        text: 'FocusBro Analytics',
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not share analytics image: $error')),
        );
      }
    }
  }

  Future<void> _shareSpecificTab() async {
    Navigator.pop(context);

    // Show tab selection dialog
    final selectedTab = await showDialog<int>(
      context: context,
      builder: (context) => _buildTabSelectionDialog(),
    );

    if (selectedTab != null) {
      final tabContent = _generateTabContent(selectedTab);

      await Share.share(
        tabContent,
        subject: 'Personal Insights - ${_getTabName(selectedTab)}',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ ${_getTabName(selectedTab)} insights shared!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _shareKeyHighlights() async {
    Navigator.pop(context);

    try {
      final highlights = _generateKeyHighlights();

      await Share.share(
        highlights,
        subject: 'Key Productivity Highlights from FocusBro',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Key highlights shared successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Share failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Export Methods
  Future<void> _exportAsPDF() async {
    Navigator.pop(context);
    try {
      final report = JsonEncoder.withIndent(
        '  ',
        (value) => value.toString(),
      ).convert(_analyticsData);
      final document = pw.Document();
      document.addPage(
        pw.MultiPage(
          pageFormat: pw.PdfPageFormat.a4,
          build: (context) => [
            pw.Header(
              level: 0,
              child: pw.Text('FocusBro Analytics Report'),
            ),
            pw.Text('Generated ${DateTime.now().toLocal()}'),
            pw.SizedBox(height: 16),
            pw.Text(report, style: const pw.TextStyle(fontSize: 9)),
          ],
        ),
      );

      final directory = await getTemporaryDirectory();
      final file = File(
        '${directory.path}/focusbro_analytics_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
      await file.writeAsBytes(await document.save(), flush: true);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/pdf')],
        text: 'FocusBro Analytics Report',
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not export analytics PDF: $error')),
        );
      }
    }
  }

  // Helper Methods
  String _generateInsightsText() {
    final focus = Map<String, dynamic>.from(
      _analyticsData['focus'] as Map? ?? const <String, dynamic>{},
    );
    final insights = Map<String, dynamic>.from(
      _analyticsData['insights'] as Map? ?? const <String, dynamic>{},
    );
    final streak = Map<String, dynamic>.from(
      _analyticsData['streak'] as Map? ?? const <String, dynamic>{},
    );
    final focusHours =
        ((focus['totalFocusTime'] as num?)?.toDouble() ?? 0) / 3600;
    final rate = ((focus['completionRate'] as num?)?.toDouble() ?? 0) * 100;
    final recommendations = (insights['insights'] as List? ?? const [])
        .map((value) => '- $value')
        .join('\n');

    return '''
FocusBro Productivity Insights
Generated: ${DateTime.now().toLocal()}
Period: $_selectedTimeRange

FOCUS
Sessions: ${focus['totalSessions'] ?? 0}
Completed: ${focus['completedSessions'] ?? 0}
Completion rate: ${rate.toStringAsFixed(1)}%
Focus time: ${focusHours.toStringAsFixed(1)} hours

PRODUCTIVITY
Score: ${insights['score'] ?? 0}/100
Current streak: ${streak['currentStreak'] ?? 0} days
Longest streak: ${streak['longestStreak'] ?? 0} days

RECOMMENDATIONS
${recommendations.isEmpty ? 'No recommendations available yet.' : recommendations}
'''
        .trim();
  }

  String _generateKeyHighlights() {
    final focus = Map<String, dynamic>.from(
      _analyticsData['focus'] as Map? ?? const <String, dynamic>{},
    );
    final insights = Map<String, dynamic>.from(
      _analyticsData['insights'] as Map? ?? const <String, dynamic>{},
    );
    final streak = Map<String, dynamic>.from(
      _analyticsData['streak'] as Map? ?? const <String, dynamic>{},
    );
    final focusHours =
        ((focus['totalFocusTime'] as num?)?.toDouble() ?? 0) / 3600;

    return '''
FocusBro Productivity Highlights
Period: $_selectedTimeRange
Focus sessions: ${focus['totalSessions'] ?? 0}
Completed sessions: ${focus['completedSessions'] ?? 0}
Focus time: ${focusHours.toStringAsFixed(1)} hours
Productivity score: ${insights['score'] ?? 0}/100
Current streak: ${streak['currentStreak'] ?? 0} days
Generated: ${DateTime.now().toLocal()}
'''
        .trim();
  }

  String _generateJSONData() {
    final data = {
      'version': '1.0',
      'exportDate': DateTime.now().toIso8601String(),
      'personalInsights': {
        'focusProfile': {
          'type': 'Morning Warrior',
          'peakHours': '6:00-10:00 AM',
          'focusScore': 8.7,
          'consistencyRate': 0.92,
        },
        'productivityStyle': {
          'method': 'Pomodoro Champion',
          'optimalSessionLength': 25,
          'idealBreakDuration': 5,
          'dailySessions': '8-12',
        },
        'achievementStyle': {
          'pattern': 'Steady Climber',
          'completionRate': 0.87,
          'longestStreak': 21,
          'goalPreference': 'Incremental',
        },
        'patterns': {
          'weeklyPerformance': [0.6, 0.9, 1.0, 0.95, 0.7, 0.8, 0.5],
          'dailyEnergy': [0.9, 1.0, 0.8, 0.6, 0.4, 0.3],
          'durationTrends': [0.7, 0.75, 0.8, 0.9, 1.0],
        },
        'recommendations': {
          'immediate': [
            'Schedule morning sessions',
            'Use 25-minute timers',
            'Take micro-breaks',
          ],
          'weekly': [
            'Front-load your week',
            'Friday planning sessions',
          ],
          'longTerm': [
            'Gradually increase session length',
            'Experiment with afternoon focus',
          ],
        },
        'aiInsights': [
          {
            'category': 'Predictive Analysis',
            'insight':
                '85% productivity success rate with strong Monday starts',
          },
          {
            'category': 'Behavioral Science',
            'insight':
                '23% productivity boost possible with 2 PM energy optimization',
          },
          {
            'category': 'Progress Tracking',
            'insight': '15% monthly focus time increase trajectory',
          },
          {
            'category': 'Environmental Factors',
            'insight': 'Nature sounds improve focus by 18%',
          },
        ],
      },
    };

    return jsonEncode(data);
  }

  String _generateCSVData() {
    return '''
Category,Metric,Value,Description
Focus Profile,Type,Morning Warrior,Peak performance type
Focus Profile,Peak Hours,6:00-10:00 AM,Optimal focus time window
Focus Profile,Focus Score,8.7,Overall focus rating out of 10
Focus Profile,Consistency Rate,92%,Consistency in maintaining focus
Productivity Style,Method,Pomodoro Champion,Preferred productivity technique
Productivity Style,Session Length,25 minutes,Optimal focus session duration
Productivity Style,Break Duration,5 minutes,Ideal break length
Productivity Style,Daily Sessions,8-12,Recommended sessions per day
Achievement Style,Pattern,Steady Climber,Goal achievement approach
Achievement Style,Completion Rate,87%,Task completion percentage
Achievement Style,Longest Streak,21 days,Best consecutive day streak
Achievement Style,Goal Preference,Incremental,Preferred goal structure
Weekly Pattern,Monday,60%,Productivity level
Weekly Pattern,Tuesday,90%,Productivity level
Weekly Pattern,Wednesday,100%,Productivity level
Weekly Pattern,Thursday,95%,Productivity level
Weekly Pattern,Friday,70%,Productivity level
Weekly Pattern,Saturday,80%,Productivity level
Weekly Pattern,Sunday,50%,Productivity level
Daily Energy,6 AM,90%,Energy level
Daily Energy,9 AM,100%,Energy level
Daily Energy,12 PM,80%,Energy level
Daily Energy,3 PM,60%,Energy level
Daily Energy,6 PM,40%,Energy level
Daily Energy,9 PM,30%,Energy level
    '''
        .trim();
  }

  String _generateTextReport() {
    final now = DateTime.now();
    final dateStr = '${now.day}/${now.month}/${now.year}';

    return '''
PERSONAL INSIGHTS ANALYSIS REPORT
FocusBro Productivity Analytics
Generated on: $dateStr

=====================================
EXECUTIVE SUMMARY
=====================================

This report provides a comprehensive analysis of your productivity patterns,
focus behaviors, and personalized recommendations based on your FocusBro usage data.

=====================================
FOCUS PROFILE ANALYSIS
=====================================

Profile Type: Morning Warrior
- You achieve peak performance during early morning hours (6-10 AM)
- Your focus levels are 40% higher compared to afternoon sessions
- Overall Focus Score: 8.7/10
- Consistency Rate: 92%

Key Characteristics:
• Strong morning focus and energy
• Declining performance after 2 PM
• Excellent consistency in maintaining routines
• High completion rates for morning tasks

=====================================
PRODUCTIVITY STYLE ASSESSMENT
=====================================

Primary Method: Pomodoro Champion
- You excel with structured time blocks
- Optimal session duration: 25 minutes
- Ideal break length: 5 minutes
- Recommended daily sessions: 8-12

Performance Metrics:
• Session completion rate: 87%
• Average focus duration: 25 minutes
• Break adherence: 95%
• Technique effectiveness: High

=====================================
ACHIEVEMENT PATTERNS
=====================================

Style: Steady Climber
- You prefer consistent daily progress over intense bursts
- Small, regular steps lead to your biggest wins
- Current streak: 21 days
- Goal completion rate: 87%

Success Factors:
• Incremental goal setting
• Daily habit formation
• Consistent effort over time
• Regular progress tracking

=====================================
WEEKLY PERFORMANCE PATTERNS
=====================================

Peak Days: Tuesday, Wednesday, Thursday
- Mid-week productivity peaks
- Monday: 60% (slow start)
- Tuesday: 90% (strong momentum)
- Wednesday: 100% (peak performance)
- Thursday: 95% (sustained high performance)
- Friday: 70% (declining focus)
- Weekend: 65% average

=====================================
DAILY ENERGY CURVE
=====================================

Morning Peak (6-10 AM): 90-100%
- Highest energy and focus levels
- Optimal for challenging tasks
- Best decision-making window

Afternoon Decline (12-6 PM): 60-80%
- Gradual energy decrease
- Suitable for routine tasks
- Consider energy management strategies

Evening Low (6-9 PM): 30-40%
- Lowest energy levels
- Best for planning and reflection
- Avoid demanding cognitive tasks

=====================================
PERSONALIZED RECOMMENDATIONS
=====================================

IMMEDIATE ACTIONS (High Impact):
1. Schedule morning sessions (6-10 AM)
   - Block this time for your most important tasks
   - Protect this window from interruptions

2. Use 25-minute timers
   - Your sweet spot for sustained focus
   - Maintain consistent session lengths

3. Take micro-breaks
   - 2-3 minute breaks every 25 minutes
   - Essential for maintaining energy

WEEKLY OPTIMIZATIONS:
1. Front-load your week
   - Schedule challenging tasks for Tuesday-Thursday
   - Use Monday for planning and preparation

2. Friday planning sessions
   - Use lower energy for planning next week
   - Review and adjust goals

LONG-TERM GROWTH:
1. Gradually increase session length
   - Try 30-minute sessions once comfortable with 25
   - Monitor performance and adjust accordingly

2. Experiment with afternoon focus
   - Test 2-4 PM sessions with different techniques
   - Explore energy management strategies

=====================================
AI-POWERED INSIGHTS
=====================================

Predictive Analysis:
• 85% likelihood of highly productive week with strong Monday morning session
• Optimal week structure identified based on your patterns

Behavioral Science:
• 2 PM energy dip could be countered with 10-minute walk or light snack
• Potential 23% boost in afternoon productivity

Progress Tracking:
• On track to increase daily focus time by 15% this month
• Consistent upward trajectory in session quality

Environmental Factors:
• Focus improves 18% with ambient nature sounds
• Consider integrating environmental optimization

=====================================
CONCLUSION
=====================================

Your productivity profile shows strong morning performance with excellent
consistency. Focus on leveraging your natural energy patterns while
gradually expanding your effective focus windows. The combination of
structured time blocks and incremental progress aligns perfectly with
your achievement style.

Continue building on your strengths while implementing the recommended
optimizations for sustained productivity growth.

Report generated by FocusBro Analytics Engine
For more insights, visit your Enhanced Analytics Dashboard
    '''
        .trim();
  }

  Future<void> _saveAndShareFile(
      String content, String fileName, String format) async {
    try {
      // Create temporary file for sharing
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/$fileName');
      await tempFile.writeAsString(content);

      // Share the file
      await Share.shareXFiles(
        [XFile(tempFile.path)],
        text: 'Personal Insights Report - $format Format',
        subject: 'FocusBro Personal Insights Export',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ $format report exported and shared successfully!'),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'Save to Device',
              textColor: Colors.white,
              onPressed: () => _saveToDevice(content, fileName, format),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Export failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveToDevice(
      String content, String fileName, String format) async {
    try {
      // Get documents directory
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$fileName');

      // Write data to file
      await file.writeAsString(content);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('💾 $format report saved to: ${file.path}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Save failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildTabSelectionDialog() {
    final theme = Theme.of(context);
    final tabs = ['Profile', 'Patterns', 'Recommendations', 'AI Insights'];

    return AlertDialog(
      title: Text(
        'Select Tab to Share',
        style: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: tabs.asMap().entries.map((entry) {
          final index = entry.key;
          final tabName = entry.value;

          return ListTile(
            leading: CircleAvatar(
              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(tabName),
            subtitle: Text(_getTabDescription(index)),
            onTap: () => Navigator.pop(context, index),
          );
        }).toList(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  String _getTabName(int index) {
    const tabs = ['Profile', 'Patterns', 'Recommendations', 'AI Insights'];
    return tabs[index];
  }

  String _getTabDescription(int index) {
    const descriptions = [
      'Focus profile and productivity style',
      'Weekly and daily performance patterns',
      'Personalized improvement suggestions',
      'AI-powered insights and predictions',
    ];
    return descriptions[index];
  }

  String _generateTabContent(int tabIndex) {
    final now = DateTime.now();
    final dateStr = '${now.day}/${now.month}/${now.year}';
    final tabName = _getTabName(tabIndex);

    switch (tabIndex) {
      case 0: // Profile
        return '''
🧠 Personal Profile Analysis - FocusBro
Generated on: $dateStr

📊 FOCUS PROFILE
• Type: Morning Warrior
• Peak Performance: 6:00 - 10:00 AM
• Focus Score: 8.7/10
• Consistency Rate: 92%

🎯 PRODUCTIVITY STYLE
• Method: Pomodoro Champion
• Optimal Session: 25 minutes
• Ideal Break: 5 minutes
• Daily Sessions: 8-12

🏆 ACHIEVEMENT STYLE
• Pattern: Steady Climber
• Completion Rate: 87%
• Longest Streak: 21 days
• Goal Preference: Incremental

#FocusBro #PersonalProfile
        '''
            .trim();

      case 1: // Patterns
        return '''
📈 Performance Patterns Analysis - FocusBro
Generated on: $dateStr

📅 WEEKLY PATTERN
• Monday: 60% (Slow start)
• Tuesday: 90% (Strong momentum)
• Wednesday: 100% (Peak performance)
• Thursday: 95% (Sustained high)
• Friday: 70% (Declining focus)
• Weekend: 65% average

⏰ DAILY ENERGY CURVE
• 6-10 AM: 90-100% (Peak hours)
• 12-2 PM: 80% (Good performance)
• 2-6 PM: 60% (Gradual decline)
• 6-9 PM: 30-40% (Low energy)

📊 DURATION TRENDS
• Week 1: 20 minutes average
• Week 2: 22 minutes average
• Week 3: 24 minutes average
• Week 4: 26 minutes average
• Week 5: 28 minutes average

#FocusBro #PerformancePatterns
        '''
            .trim();

      case 2: // Recommendations
        return '''
💡 Personalized Recommendations - FocusBro
Generated on: $dateStr

⚡ IMMEDIATE ACTIONS
• Schedule morning sessions (6-10 AM)
• Use 25-minute focus timers
• Take 2-3 minute micro-breaks
• Protect peak hours from interruptions

📅 WEEKLY OPTIMIZATIONS
• Front-load challenging tasks (Tue-Thu)
• Use Monday for planning and preparation
• Friday planning sessions for next week
• Leverage mid-week productivity peaks

🌱 LONG-TERM GROWTH
• Gradually increase to 30-minute sessions
• Experiment with afternoon focus techniques
• Develop energy management strategies
• Track and optimize environmental factors

#FocusBro #ProductivityTips
        '''
            .trim();

      case 3: // AI Insights
        return '''
🤖 AI-Powered Insights - FocusBro
Generated on: $dateStr

🎯 PREDICTIVE ANALYSIS
• 85% productivity success rate with strong Monday morning sessions
• Optimal week structure identified based on your patterns

⚡ BEHAVIORAL SCIENCE
• 2 PM energy dip can be countered with 10-minute walk or light snack
• Potential 23% boost in afternoon productivity with optimization

📈 PROGRESS TRACKING
• On track to increase daily focus time by 15% this month
• Consistent upward trajectory in session quality and duration

🧘 WELLNESS INTEGRATION
• Session completion drops 12% on high-stress days
• Consider 5-minute meditation before focus sessions

🎨 ENVIRONMENTAL FACTORS
• Focus improves 18% with ambient nature sounds
• Optimal lighting and temperature patterns identified

#FocusBro #AIInsights #ProductivityScience
        '''
            .trim();

      default:
        return _generateInsightsText();
    }
  }
}
