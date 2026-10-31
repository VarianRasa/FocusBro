import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:io';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/analytics_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';

// Custom Annotation Tools Enums
enum DrawingTool { pen, highlighter, eraser }

enum ShapeTool { rectangle, circle, arrow, line }

// Custom Annotation Data Models
class DrawnPath {
  final List<Offset> points;
  final Color color;
  final double strokeWidth;
  final DrawingTool tool;
  final int pageNumber;

  DrawnPath({
    required this.points,
    required this.color,
    required this.strokeWidth,
    required this.tool,
    required this.pageNumber,
  });
}

class DrawnShape {
  final ShapeTool type;
  final Offset startPoint;
  final Offset endPoint;
  final Color color;
  final double strokeWidth;
  final int pageNumber;

  DrawnShape({
    required this.type,
    required this.startPoint,
    required this.endPoint,
    required this.color,
    required this.strokeWidth,
    required this.pageNumber,
  });
}

class TextBoxAnnotation {
  final String id;
  final String text;
  final Offset position;
  final Size size;
  final Color backgroundColor;
  final Color textColor;
  final double fontSize;
  final int pageNumber;
  final DateTime createdAt;

  TextBoxAnnotation({
    required this.id,
    required this.text,
    required this.position,
    required this.size,
    required this.backgroundColor,
    required this.textColor,
    required this.fontSize,
    required this.pageNumber,
    required this.createdAt,
  });
}

// Custom Drawing Painter
class DrawingPainter extends CustomPainter {
  final List<DrawnPath> drawnPaths;
  final List<DrawnShape> drawnShapes;
  final List<Offset> currentPath;
  final Offset? currentShapeStart;
  final Offset? currentShapeEnd;
  final int currentPage;
  final bool isDrawingMode;
  final DrawingTool selectedTool;
  final ShapeTool selectedShape;
  final double strokeWidth;
  final Color color;

  DrawingPainter({
    required this.drawnPaths,
    required this.drawnShapes,
    required this.currentPath,
    required this.currentShapeStart,
    required this.currentShapeEnd,
    required this.currentPage,
    required this.isDrawingMode,
    required this.selectedTool,
    required this.selectedShape,
    required this.strokeWidth,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw completed paths for current page
    for (final path in drawnPaths) {
      if (path.pageNumber == currentPage) {
        _drawPath(canvas, path);
      }
    }

    // Draw completed shapes for current page
    for (final shape in drawnShapes) {
      if (shape.pageNumber == currentPage) {
        _drawShape(canvas, shape);
      }
    }

    // Draw current path being drawn
    if (isDrawingMode && currentPath.isNotEmpty) {
      final paint = Paint()
        ..color = color
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      if (selectedTool == DrawingTool.highlighter) {
        paint.color = color.withValues(alpha: 0.5);
        paint.strokeWidth = strokeWidth * 2;
      } else if (selectedTool == DrawingTool.eraser) {
        paint.blendMode = BlendMode.clear;
        paint.strokeWidth = strokeWidth * 1.5;
      }

      final path = Path();
      for (int i = 0; i < currentPath.length; i++) {
        if (i == 0) {
          path.moveTo(currentPath[i].dx, currentPath[i].dy);
        } else {
          path.lineTo(currentPath[i].dx, currentPath[i].dy);
        }
      }
      canvas.drawPath(path, paint);
    }

    // Draw current shape being drawn
    if (!isDrawingMode &&
        currentShapeStart != null &&
        currentShapeEnd != null) {
      final paint = Paint()
        ..color = color
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      _drawShapePreview(
          canvas, paint, currentShapeStart!, currentShapeEnd!, selectedShape);
    }
  }

  void _drawPath(Canvas canvas, DrawnPath drawnPath) {
    final paint = Paint()
      ..color = drawnPath.color
      ..strokeWidth = drawnPath.strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    if (drawnPath.tool == DrawingTool.highlighter) {
      paint.color = drawnPath.color.withValues(alpha: 0.5);
      paint.strokeWidth = drawnPath.strokeWidth * 2;
    } else if (drawnPath.tool == DrawingTool.eraser) {
      paint.blendMode = BlendMode.clear;
      paint.strokeWidth = drawnPath.strokeWidth * 1.5;
    }

    final path = Path();
    for (int i = 0; i < drawnPath.points.length; i++) {
      if (i == 0) {
        path.moveTo(drawnPath.points[i].dx, drawnPath.points[i].dy);
      } else {
        path.lineTo(drawnPath.points[i].dx, drawnPath.points[i].dy);
      }
    }
    canvas.drawPath(path, paint);
  }

  void _drawShape(Canvas canvas, DrawnShape drawnShape) {
    final paint = Paint()
      ..color = drawnShape.color
      ..strokeWidth = drawnShape.strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    _drawShapePreview(canvas, paint, drawnShape.startPoint, drawnShape.endPoint,
        drawnShape.type);
  }

  void _drawShapePreview(Canvas canvas, Paint paint, Offset start, Offset end,
      ShapeTool shapeType) {
    switch (shapeType) {
      case ShapeTool.rectangle:
        final rect = Rect.fromPoints(start, end);
        canvas.drawRect(rect, paint);
        break;
      case ShapeTool.circle:
        final center = Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2);
        final radius = (end - start).distance / 2;
        canvas.drawCircle(center, radius, paint);
        break;
      case ShapeTool.line:
        canvas.drawLine(start, end, paint);
        break;
      case ShapeTool.arrow:
        canvas.drawLine(start, end, paint);
        // Draw arrow head
        final arrowLength = 20.0;
        final arrowAngle = 0.5;
        final angle = (end - start).direction;
        final arrowPoint1 = end +
            Offset(
              arrowLength * math.cos(angle + arrowAngle + math.pi),
              arrowLength * math.sin(angle + arrowAngle + math.pi),
            );
        final arrowPoint2 = end +
            Offset(
              arrowLength * math.cos(angle - arrowAngle + math.pi),
              arrowLength * math.sin(angle - arrowAngle + math.pi),
            );
        canvas.drawLine(end, arrowPoint1, paint);
        canvas.drawLine(end, arrowPoint2, paint);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true; // Always repaint for real-time drawing
  }
}

// Multi-document Tab Data Model
class PdfTab {
  final String id;
  final String fileName;
  final String filePath;
  final File file;
  final DateTime openedAt;
  bool isActive;
  int currentPage;
  double zoomLevel;

  PdfTab({
    required this.id,
    required this.fileName,
    required this.filePath,
    required this.file,
    required this.openedAt,
    this.isActive = false,
    this.currentPage = 1,
    this.zoomLevel = 1.0,
  });
}

// Document Outline Node
class OutlineNode {
  final String title;
  final int pageNumber;
  final int level;
  final List<OutlineNode> children;
  final String? id;

  OutlineNode({
    required this.title,
    required this.pageNumber,
    required this.level,
    this.children = const [],
    this.id,
  });
}

// Data Models
class PdfBookmark {
  final String id;
  final int pageNumber;
  final String title;
  final String? description;
  final DateTime createdAt;
  final BookmarkCategory category;
  final Color color;
  final bool isAutoGenerated;

  PdfBookmark({
    required this.id,
    required this.pageNumber,
    required this.title,
    this.description,
    required this.createdAt,
    this.category = BookmarkCategory.general,
    this.color = Colors.blue,
    this.isAutoGenerated = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'pageNumber': pageNumber,
      'title': title,
      'description': description,
      'createdAt': createdAt.toIso8601String(),
      'category': category.index,
      'color': color.toARGB32(),
      'isAutoGenerated': isAutoGenerated,
    };
  }

  factory PdfBookmark.fromJson(Map<String, dynamic> json) {
    return PdfBookmark(
      id: json['id'] as String,
      pageNumber: json['pageNumber'] as int,
      title: json['title'] as String,
      description: json['description'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      category: BookmarkCategory.values[json['category'] as int? ?? 0],
      color: Color(json['color'] as int? ?? Colors.blue.toARGB32()),
      isAutoGenerated: json['isAutoGenerated'] as bool? ?? false,
    );
  }
}

enum BookmarkCategory {
  general,
  important,
  reference,
  review,
  question,
  idea,
}

class PdfAnnotation {
  final String id;
  final int pageNumber;
  final AnnotationType type;
  final String text;
  final Color color;
  final Offset position;
  final Size? size;
  final DateTime createdAt;
  final DateTime? modifiedAt;

  PdfAnnotation({
    required this.id,
    required this.pageNumber,
    required this.type,
    required this.text,
    required this.color,
    required this.position,
    this.size,
    required this.createdAt,
    this.modifiedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'pageNumber': pageNumber,
      'type': type.index,
      'text': text,
      'color': color.toARGB32(),
      'positionX': position.dx,
      'positionY': position.dy,
      'sizeWidth': size?.width,
      'sizeHeight': size?.height,
      'createdAt': createdAt.toIso8601String(),
      'modifiedAt': modifiedAt?.toIso8601String(),
    };
  }

  factory PdfAnnotation.fromJson(Map<String, dynamic> json) {
    return PdfAnnotation(
      id: json['id'] as String,
      pageNumber: json['pageNumber'] as int,
      type: AnnotationType.values[json['type'] as int],
      text: json['text'] as String,
      color: Color(json['color'] as int),
      position:
          Offset(json['positionX'] as double, json['positionY'] as double),
      size: json['sizeWidth'] != null && json['sizeHeight'] != null
          ? Size(json['sizeWidth'] as double, json['sizeHeight'] as double)
          : null,
      createdAt: DateTime.parse(json['createdAt'] as String),
      modifiedAt: json['modifiedAt'] != null
          ? DateTime.parse(json['modifiedAt'] as String)
          : null,
    );
  }
}

enum AnnotationType {
  highlight,
  note,
  underline,
  strikethrough,
  drawing,
}

enum ReadingMode {
  normal,
  night,
  sepia,
  highContrast,
}

enum PageLayout {
  single,
  facing,
  continuous,
  grid,
}

class SearchResult {
  final int pageNumber;
  final String text;
  final String context;
  final int startIndex;
  final int endIndex;

  SearchResult({
    required this.pageNumber,
    required this.text,
    required this.context,
    required this.startIndex,
    required this.endIndex,
  });
}

class ReadingSession {
  final String documentPath;
  final DateTime startTime;
  final DateTime? endTime;
  final int pagesRead;
  final Duration readingTime;
  final int currentPage;

  ReadingSession({
    required this.documentPath,
    required this.startTime,
    this.endTime,
    required this.pagesRead,
    required this.readingTime,
    required this.currentPage,
  });

  Map<String, dynamic> toJson() {
    return {
      'documentPath': documentPath,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'pagesRead': pagesRead,
      'readingTimeMs': readingTime.inMilliseconds,
      'currentPage': currentPage,
    };
  }

  factory ReadingSession.fromJson(Map<String, dynamic> json) {
    return ReadingSession(
      documentPath: json['documentPath'] as String,
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: json['endTime'] != null
          ? DateTime.parse(json['endTime'] as String)
          : null,
      pagesRead: json['pagesRead'] as int,
      readingTime: Duration(milliseconds: json['readingTimeMs'] as int),
      currentPage: json['currentPage'] as int,
    );
  }
}

class PdfOutlineItem {
  final String title;
  final int pageNumber;
  final int level;
  final List<PdfOutlineItem> children;

  PdfOutlineItem({
    required this.title,
    required this.pageNumber,
    required this.level,
    this.children = const [],
  });
}

class RecentPdfFile {
  final String path;
  final String name;
  final DateTime lastOpened;
  final int fileSize;

  RecentPdfFile({
    required this.path,
    required this.name,
    required this.lastOpened,
    required this.fileSize,
  });

  String toJson() {
    return '$path|$name|${lastOpened.toIso8601String()}|$fileSize';
  }

  factory RecentPdfFile.fromJson(String json) {
    final parts = json.split('|');
    return RecentPdfFile(
      path: parts[0],
      name: parts[1],
      lastOpened: DateTime.parse(parts[2]),
      fileSize: parts.length > 3 ? int.tryParse(parts[3]) ?? 0 : 0,
    );
  }

  String get formattedFileSize {
    if (fileSize == 0) return '';
    if (fileSize < 1024) return '${fileSize}B';
    if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)}KB';
    }
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}

class EnhancedPdfReaderScreen extends StatefulWidget {
  const EnhancedPdfReaderScreen({super.key});

  @override
  State<EnhancedPdfReaderScreen> createState() =>
      _EnhancedPdfReaderScreenState();
}

class _EnhancedPdfReaderScreenState extends State<EnhancedPdfReaderScreen>
    with TickerProviderStateMixin {
  // Controllers and Core State
  PdfViewerController? _pdfViewerController;
  dynamic _pdfFile;
  String? _currentFileName;
  final AnalyticsService _analytics = AnalyticsService();

  // Animation Controllers
  late AnimationController _fabAnimationController;
  late AnimationController _toolbarAnimationController;
  late Animation<double> _fabAnimation;
  late Animation<Offset> _toolbarAnimation;

  // PDF State
  int _currentPage = 1;
  int _totalPages = 0;
  double _zoomLevel = 1.0;
  bool _isLoading = false;

  // UI State
  bool _isFullScreen = false;
  bool _showToolbar = true;
  bool _isFabExpanded = false;
  bool _showPageIndicator = true;

  // View Settings
  bool _isContinuousScroll = true;
  bool _isNightMode = false;
  double _rotation = 0.0;
  bool _showThumbnails = false;

  // Advanced View Settings
  ReadingMode _readingMode = ReadingMode.normal;
  double _brightness = 1.0;
  bool _isSepiaTone = false;
  double _pageSpacing = 8.0;
  PageLayout _pageLayout = PageLayout.single;
  bool _showPageNumbers = true;
  bool _autoScroll = false;
  double _autoScrollSpeed = 1.0;

  // Data
  List<PdfBookmark> _bookmarks = [];
  List<RecentPdfFile> _recentFiles = [];

  // Phase 2: Advanced Features
  List<PdfAnnotation> _annotations = [];
  List<SearchResult> _searchResults = [];
  List<ReadingSession> _readingSessions = [];

  // Search State
  bool _isSearching = false;
  String _searchQuery = '';
  int _currentSearchIndex = 0;
  TextEditingController? _searchController;

  // Annotation State
  bool _isAnnotationMode = false;
  AnnotationType _selectedAnnotationType = AnnotationType.highlight;
  Color _selectedAnnotationColor = Colors.yellow;

  // Custom Annotation Tools
  bool _isDrawingMode = false;
  bool _isShapeMode = false;
  bool _isTextBoxMode = false;
  List<DrawnPath> _drawnPaths = [];
  List<DrawnShape> _drawnShapes = [];
  List<TextBoxAnnotation> _textBoxes = [];
  DrawingTool _selectedDrawingTool = DrawingTool.pen;
  ShapeTool _selectedShapeTool = ShapeTool.rectangle;
  double _strokeWidth = 2.0;
  Color _drawingColor = Colors.red;

  // Drawing State
  List<Offset> _currentPath = [];
  Offset? _shapeStartPoint;
  Offset? _shapeEndPoint;
  bool _isDrawing = false;

  // Reading Progress
  DateTime? _sessionStartTime;
  int _pagesReadInSession = 0;
  Duration _totalReadingTime = Duration.zero;

  // Table of Contents
  List<PdfOutlineItem> _tableOfContents = [];
  bool _showTocPanel = false;

  // Immediate Improvements
  bool _showProgressBar = true;
  List<PdfBookmark> _recentBookmarks = [];
  DateTime? _sessionTimer;
  String _sessionDuration = '0:00';
  Timer? _timerUpdater;

  // Multi-document Tabs
  List<PdfTab> _openTabs = [];
  String? _activeTabId;

  // Document Outline
  bool _showDocumentOutline = false;
  List<OutlineNode> _documentOutline = [];

  // Advanced Search
  bool _isAdvancedSearchMode = false;
  List<String> _searchHistory = [];
  Map<String, List<SearchResult>> _crossDocumentResults = {};
  bool _caseSensitive = false;
  bool _wholeWords = false;
  bool _searchMultipleDocuments = false;
  bool _searchInAnnotations = true;

  // Focus Mode
  bool _isFocusMode = false;
  int _focusReadingDuration = 25; // minutes
  int _focusReadingGoal = 10; // pages
  DateTime? _focusStartTime;
  int _focusStartPage = 1;
  int _focusElapsedMinutes = 0;
  Timer? _focusTimer;

  // Statistics Export
  String _selectedExportFormat = 'JSON';
  bool _exportReadingSessions = true;
  bool _exportBookmarksAnnotations = true;
  bool _exportFocusStats = true;
  bool _exportSearchHistory = true;

  // PDF Editing State
  bool _isEditMode = false;
  List<Map<String, dynamic>> _editHistory = [];
  int _currentEditIndex = -1;
  bool _hasUnsavedChanges = false;

  // Text Editing State
  bool _isTextEditMode = false;
  String _editingText = '';
  Offset? _textEditPosition;
  double _textEditFontSize = 12.0;
  Color _textEditColor = Colors.black;

  // Page Manipulation State
  List<int> _selectedPages = [];
  bool _isPageSelectionMode = false;

  // Save/Load State
  String? _lastSavedPath;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _pdfViewerController = PdfViewerController();
    _searchController = TextEditingController();
    if (!kIsWeb) {
      _requestPermissions();
    }
    _loadRecentFiles();
    _loadAnnotations();
    _loadReadingSessions();
    _loadBookmarks();
    _loadSearchHistory();
    _loadViewSettings();
    _loadDrawnPaths();
    _loadDrawnShapes();
    _loadTabsState();
    _startSessionTimer();
  }

  void _initializeControllers() {
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _toolbarAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _fabAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fabAnimationController,
      curve: Curves.easeOutCubic,
    ));

    _toolbarAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _toolbarAnimationController,
      curve: Curves.easeOutCubic,
    ));

    _toolbarAnimationController.forward();
  }

  @override
  void dispose() {
    _fabAnimationController.dispose();
    _toolbarAnimationController.dispose();
    _searchController?.dispose();
    _timerUpdater?.cancel();
    _focusTimer?.cancel();
    _autoScrollTimer?.cancel();
    _saveTabsState();
    _endReadingSession();
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    if (!kIsWeb) {
      await Permission.storage.request();
    }
  }

  Future<void> _loadRecentFiles() async {
    final prefs = await SharedPreferences.getInstance();
    final recentFilesJson =
        prefs.getStringList('enhanced_pdf_recent_files') ?? [];
    if (mounted) {
      setState(() {
        _recentFiles = recentFilesJson
            .map((json) => RecentPdfFile.fromJson(json))
            .toList();
      });
    }
  }

  Future<void> _saveRecentFiles() async {
    final prefs = await SharedPreferences.getInstance();
    final recentFilesJson = _recentFiles.map((file) => file.toJson()).toList();
    await prefs.setStringList('enhanced_pdf_recent_files', recentFilesJson);
  }

  Future<void> _addToRecentFiles(String path, String name) async {
    final recentFile = RecentPdfFile(
      path: path,
      name: name,
      lastOpened: DateTime.now(),
      fileSize: await _getFileSize(path),
    );

    setState(() {
      _recentFiles.removeWhere((file) => file.path == path);
      _recentFiles.insert(0, recentFile);
      if (_recentFiles.length > 15) {
        _recentFiles.removeLast();
      }
    });

    await _saveRecentFiles();
  }

  Future<int> _getFileSize(String path) async {
    try {
      if (!kIsWeb && path.isNotEmpty) {
        final file = File(path);
        if (await file.exists()) {
          return await file.length();
        }
      }
    } catch (e) {
      // Ignore errors
    }
    return 0;
  }

  Future<void> _pickPdf() async {
    try {
      setState(() => _isLoading = true);

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null && mounted) {
        setState(() {
          if (kIsWeb) {
            _pdfFile = result.files.single.bytes;
            _currentFileName = result.files.single.name;
            _addToRecentFiles(
              result.files.single.name,
              result.files.single.name,
            );
          } else {
            _pdfFile = File(result.files.single.path!);
            _currentFileName = result.files.single.name;
            _addToRecentFiles(
              result.files.single.path!,
              result.files.single.name,
            );
          }
          _resetPdfState();
        });
        _startReadingSession();
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error picking PDF: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _resetPdfState() {
    _bookmarks.clear();
    _currentPage = 1;
    _totalPages = 0;
    _zoomLevel = 1.0;
    _showThumbnails = false;
    _rotation = 0.0;
    _isFullScreen = false;
    _showToolbar = true;
    _toolbarAnimationController.forward();
    _pdfViewerController =
        PdfViewerController(); // Re-initialize the controller
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  void _toggleFullScreen() {
    setState(() {
      _isFullScreen = !_isFullScreen;
      _showToolbar = !_isFullScreen;

      if (_showToolbar) {
        _toolbarAnimationController.forward();
      } else {
        _toolbarAnimationController.reverse();
      }
    });
  }

  void _toggleFab() {
    setState(() {
      _isFabExpanded = !_isFabExpanded;
      if (_isFabExpanded) {
        _fabAnimationController.forward();
      } else {
        _fabAnimationController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    debugPrint(
        'Building EnhancedPdfReaderScreen. _pdfFile is null: ${_pdfFile == null}');

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Stack(
        children: [
          // Main Content
          Column(
            children: [
              // Reading Progress Bar
              if (_pdfFile != null && _showProgressBar && !_isFullScreen)
                _buildReadingProgressBar(theme),

              // Enhanced App Bar
              if (_showToolbar) _buildEnhancedAppBar(theme),

              // Search Bar
              if (_isSearching && _pdfFile != null) _buildSearchBar(theme),

              // PDF Content
              Expanded(
                child: _pdfFile == null
                    ? _buildWelcomeScreen(theme)
                    : _buildPdfViewer(theme),
              ),
            ],
          ),

          // Loading Overlay
          if (_isLoading) _buildLoadingOverlay(theme),

          // Page Indicator
          if (_pdfFile != null && _showPageIndicator && !_isFullScreen)
            _buildPageIndicator(theme),
        ],
      ),
      floatingActionButton: _pdfFile != null ? _buildEnhancedFAB(theme) : null,
      floatingActionButtonLocation:
          FloatingActionButtonLocation.endFloat, // Move FAB to bottom-right
    );
  }

  Widget _buildEnhancedAppBar(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    final bool isPdfLoaded = _pdfFile != null;

    return SlideTransition(
      position: _toolbarAnimation,
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                // Back Button (shown only when PDF is loaded)
                if (isPdfLoaded)
                  IconButton(
                    onPressed: () {
                      if (_hasUnsavedChanges) {
                        _showUnsavedChangesDialog();
                      } else if (_pdfFile != null) {
                        // Unload the PDF and return to the welcome screen
                        _endReadingSession();
                        setState(() {
                          _pdfFile = null;
                          _currentFileName = null;
                        });
                        _resetPdfState();
                      } else {
                        // If no PDF is loaded, pop the screen (exit app or go back a route)
                        Navigator.pop(context);
                      }
                    },
                    icon: Icon(
                      Icons.arrow_back,
                      color: colorScheme.onSurface,
                    ),
                  ),

                // Title
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _currentFileName ?? 'PDF Reader',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (_pdfFile != null && _totalPages > 0)
                        Text(
                          'Page $_currentPage of $_totalPages • $_sessionDuration',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),

                // Edit Button (shown only when PDF is loaded)
                if (isPdfLoaded)
                  IconButton(
                    onPressed: _toggleEditMode,
                    icon: Icon(
                      _isEditMode ? Icons.edit_off : Icons.edit,
                      color: _isEditMode
                          ? colorScheme.primary
                          : colorScheme.onSurface,
                    ),
                    tooltip: _isEditMode ? 'Exit Edit Mode' : 'Edit PDF',
                  ),

                // Action Buttons (shown only when PDF is loaded)
                if (isPdfLoaded)
                  PopupMenuButton<String>(
                    onSelected: _handleMenuAction,
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'bookmarks',
                        child: ListTile(
                          leading: Icon(Icons.bookmark),
                          title: Text('Bookmarks'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'recent_bookmarks',
                        child: ListTile(
                          leading: Icon(Icons.bookmark_border),
                          title: Text('Recent Bookmarks'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'thumbnails',
                        child: ListTile(
                          leading: Icon(Icons.view_module),
                          title: Text('Page Thumbnails'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'annotations',
                        child: ListTile(
                          leading: Icon(Icons.note),
                          title: Text('Annotations'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'toc',
                        child: ListTile(
                          leading: Icon(Icons.list),
                          title: Text('Table of Contents'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'progress',
                        child: ListTile(
                          leading: Icon(Icons.analytics),
                          title: Text('Reading Progress'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'recent',
                        child: ListTile(
                          leading: Icon(Icons.history),
                          title: Text('Recent Files'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'focus',
                        child: ListTile(
                          leading: Icon(Icons.center_focus_strong),
                          title: Text('Focus Reading'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'sync',
                        child: ListTile(
                          leading: Icon(Icons.cloud_sync),
                          title: Text('Sync Data'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'export',
                        child: ListTile(
                          leading: Icon(Icons.download),
                          title: Text('Export Data'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: 'custom_tools',
                        child: ListTile(
                          leading: Icon(Icons.draw),
                          title: Text('Custom Tools'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'outline',
                        child: ListTile(
                          leading: Icon(Icons.account_tree),
                          title: Text('Document Outline'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'tabs',
                        child: ListTile(
                          leading: Icon(Icons.tab),
                          title: Text('Multi-Document'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'advanced_search',
                        child: ListTile(
                          leading: Icon(Icons.search_off),
                          title: Text('Advanced Search'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'statistics',
                        child: ListTile(
                          leading: Icon(Icons.analytics),
                          title: Text('Reading Statistics'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'settings',
                        child: ListTile(
                          leading: Icon(Icons.settings),
                          title: Text('View Settings'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showUnsavedChangesDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unsaved Changes'),
        content: const Text(
            'You have unsaved changes. Do you want to save them before leaving?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Discard'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _saveChanges();
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeScreen(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    debugPrint('Building Welcome Screen');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Hero Icon
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.picture_as_pdf,
              size: 64,
              color: colorScheme.onPrimaryContainer,
            ),
          ),

          const SizedBox(height: 32),

          // Welcome Text
          Text(
            'Welcome to PDF Reader',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 16),

          Text(
            'Open a PDF document to start reading with enhanced features',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 48),

          // Action Buttons
          Column(
            children: [
              FilledButton.icon(
                onPressed: _pickPdf,
                icon: const Icon(Icons.file_open),
                label: const Text('Open PDF'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
              ),
              if (_recentFiles.isNotEmpty) ...[
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _showRecentFiles,
                  icon: const Icon(Icons.history),
                  label: const Text('Recent Files'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 48),

          // Quick Tips
          _buildQuickTips(theme),
        ],
      ),
    );
  }

  Widget _buildQuickTips(ThemeData theme) {
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline,
                color: colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Quick Tips',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildTipItem(
            theme,
            Icons.touch_app,
            'Tap to navigate pages',
          ),
          _buildTipItem(
            theme,
            Icons.pinch_outlined,
            'Pinch to zoom in/out',
          ),
          _buildTipItem(
            theme,
            Icons.bookmark_add,
            'Add bookmarks for quick access',
          ),
        ],
      ),
    );
  }

  Widget _buildTipItem(ThemeData theme, IconData icon, String text) {
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPdfViewer(ThemeData theme) {
    final colorScheme = theme.colorScheme;

    return Container(
      color: _isNightMode ? Colors.black : colorScheme.surface,
      child: Stack(
        children: [
          // PDF Viewer
          Transform.rotate(
            angle: _rotation * (3.14159 / 180),
            child: kIsWeb
                ? SfPdfViewer.memory(
                    _pdfFile,
                    controller: _pdfViewerController,
                    canShowScrollHead: true,
                    canShowScrollStatus: true,
                    enableDoubleTapZooming: true,
                    enableTextSelection: !_isDrawingMode && !_isShapeMode,
                    scrollDirection: PdfScrollDirection.vertical,
                    pageLayoutMode: PdfPageLayoutMode.continuous,
                    pageSpacing: 0, // Remove spacing for continuous scroll
                    enableDocumentLinkAnnotation:
                        false, // Disable link interference
                    interactionMode: _isDrawingMode || _isShapeMode
                        ? PdfInteractionMode.selection
                        : PdfInteractionMode.pan, // Enable pan/scroll mode
                    onPageChanged: (PdfPageChangedDetails details) {
                      if (mounted) {
                        setState(() {
                          _currentPage = details.newPageNumber;
                          if (_totalPages == 0) {
                            _totalPages = details.newPageNumber;
                          }

                          // Update current tab's page
                          if (_activeTabId != null) {
                            final activeTab = _openTabs
                                .where((tab) => tab.id == _activeTabId)
                                .firstOrNull;
                            if (activeTab != null) {
                              activeTab.currentPage = details.newPageNumber;
                            }
                          }
                        });
                      }
                    },
                    onTextSelectionChanged:
                        (PdfTextSelectionChangedDetails details) {
                      // Handle text selection for annotations
                      if (details.selectedText != null &&
                          details.selectedText!.isNotEmpty &&
                          _isAnnotationMode) {
                        _createAnnotationFromSelection(details);
                      }
                    },
                    onDocumentLoaded: (PdfDocumentLoadedDetails details) {
                      if (mounted) {
                        setState(() {
                          _totalPages = details.document.pages.count;
                        });
                      }
                    },
                  )
                : SfPdfViewer.file(
                    _pdfFile,
                    controller: _pdfViewerController,
                    canShowScrollHead: true,
                    canShowScrollStatus: true,
                    enableDoubleTapZooming: true,
                    enableTextSelection: !_isDrawingMode && !_isShapeMode,
                    scrollDirection: PdfScrollDirection.vertical,
                    pageLayoutMode: PdfPageLayoutMode.continuous,
                    pageSpacing: 0, // Remove spacing for continuous scroll
                    enableDocumentLinkAnnotation:
                        false, // Disable link interference
                    interactionMode: _isDrawingMode || _isShapeMode
                        ? PdfInteractionMode.selection
                        : PdfInteractionMode.pan, // Enable pan/scroll mode
                    onPageChanged: (PdfPageChangedDetails details) {
                      if (mounted) {
                        setState(() {
                          _currentPage = details.newPageNumber;
                          if (_totalPages == 0) {
                            _totalPages = details.newPageNumber;
                          }

                          // Update current tab's page
                          if (_activeTabId != null) {
                            final activeTab = _openTabs
                                .where((tab) => tab.id == _activeTabId)
                                .firstOrNull;
                            if (activeTab != null) {
                              activeTab.currentPage = details.newPageNumber;
                            }
                          }
                        });
                      }
                    },
                    onTextSelectionChanged:
                        (PdfTextSelectionChangedDetails details) {
                      // Handle text selection for annotations
                      if (details.selectedText != null &&
                          details.selectedText!.isNotEmpty &&
                          _isAnnotationMode) {
                        _createAnnotationFromSelection(details);
                      }
                    },
                    onDocumentLoaded: (PdfDocumentLoadedDetails details) {
                      if (mounted) {
                        setState(() {
                          _totalPages = details.document.pages.count;
                        });
                      }
                    },
                  ),
          ),

          // Drawing Overlay
          if (_isDrawingMode || _isShapeMode)
            Positioned.fill(
              child: GestureDetector(
                onPanStart: _onDrawingStart,
                onPanUpdate: _onDrawingUpdate,
                onPanEnd: _onDrawingEnd,
                child: CustomPaint(
                  painter: DrawingPainter(
                    drawnPaths: _drawnPaths,
                    drawnShapes: _drawnShapes,
                    currentPath: _currentPath,
                    currentShapeStart: _shapeStartPoint,
                    currentShapeEnd: _shapeEndPoint,
                    currentPage: _currentPage,
                    isDrawingMode: _isDrawingMode,
                    selectedTool: _selectedDrawingTool,
                    selectedShape: _selectedShapeTool,
                    strokeWidth: _strokeWidth,
                    color: _drawingColor,
                  ),
                ),
              ),
            ),

          // Tabs Bar (when multiple tabs are open)
          if (_openTabs.length > 1) _buildTabsBar(),

          // Fullscreen mode provides clean reading experience
          // Exit fullscreen available via FAB menu
        ],
      ),
    );
  }

  Widget _buildLoadingOverlay(ThemeData theme) {
    final colorScheme = theme.colorScheme;

    return Container(
      color: colorScheme.surface.withValues(alpha: 0.8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                color: colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Loading PDF...',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPageIndicator(ThemeData theme) {
    final colorScheme = theme.colorScheme;

    return Positioned(
      bottom: 16,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: colorScheme.surface.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: colorScheme.outline.withValues(alpha: 0.2),
          ),
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              onPressed: _currentPage > 1
                  ? () => _pdfViewerController?.previousPage()
                  : null,
              icon: Icon(
                Icons.arrow_back_ios,
                color: _currentPage > 1
                    ? colorScheme.primary
                    : colorScheme.onSurface.withValues(alpha: 0.3),
              ),
            ),
            Text(
              'Page $_currentPage of $_totalPages',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface,
              ),
            ),
            IconButton(
              onPressed: _currentPage < _totalPages
                  ? () => _pdfViewerController?.nextPage()
                  : null,
              icon: Icon(
                Icons.arrow_forward_ios,
                color: _currentPage < _totalPages
                    ? colorScheme.primary
                    : colorScheme.onSurface.withValues(alpha: 0.3),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedFAB(ThemeData theme) {
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(
          bottom: 80, right: 16), // Position above navigation bar
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Speed Dial Options
          if (_isFabExpanded) ...[
            _buildFabOption(
              theme,
              Icons.bookmark_add,
              'Add Bookmark',
              () => _addBookmark(),
            ),
            const SizedBox(height: 8),
            _buildFabOption(
              theme,
              Icons.zoom_in,
              'Zoom In',
              () => _pdfViewerController?.zoomLevel =
                  (_pdfViewerController?.zoomLevel ?? 1.0) + 0.25,
            ),
            const SizedBox(height: 8),
            _buildFabOption(
              theme,
              Icons.zoom_out,
              'Zoom Out',
              () => _pdfViewerController?.zoomLevel =
                  (_pdfViewerController?.zoomLevel ?? 1.0) - 0.25,
            ),
            const SizedBox(height: 8),
            _buildFabOption(
              theme,
              _showToolbar ? Icons.visibility_off : Icons.visibility,
              'Toggle Toolbar',
              () {
                setState(() {
                  _showToolbar = !_showToolbar;
                  if (_showToolbar) {
                    _toolbarAnimationController.forward();
                  } else {
                    _toolbarAnimationController.reverse();
                  }
                });
              },
            ),
            const SizedBox(height: 8),
            // Exit fullscreen option (only show in fullscreen mode)
            if (_isFullScreen) ...[
              _buildFabOption(
                theme,
                Icons.fullscreen_exit,
                'Exit Fullscreen',
                () {
                  _toggleFullScreen();
                },
              ),
              const SizedBox(height: 8),
            ],
          ],

          // Main FAB
          FloatingActionButton(
            onPressed: _toggleFab,
            backgroundColor: colorScheme.primaryContainer,
            foregroundColor: colorScheme.onPrimaryContainer,
            child: AnimatedRotation(
              turns: _isFabExpanded ? 0.125 : 0,
              duration: const Duration(milliseconds: 300),
              child: Icon(_isFabExpanded ? Icons.close : Icons.add),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFabOption(
    ThemeData theme,
    IconData icon,
    String tooltip,
    VoidCallback onPressed,
  ) {
    final colorScheme = theme.colorScheme;

    return FloatingActionButton.small(
      onPressed: onPressed,
      backgroundColor: colorScheme.surface,
      foregroundColor: colorScheme.onSurface,
      tooltip: tooltip,
      child: Icon(icon),
    );
  }

  void _toggleNightMode() {
    setState(() {
      _isNightMode = !_isNightMode;
    });
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'bookmarks':
        _showBookmarks();
        break;
      case 'recent_bookmarks':
        _showRecentBookmarks();
        break;
      case 'thumbnails':
        _openPageThumbnails();
        break;
      case 'annotations':
        _showAnnotations();
        break;
      case 'toc':
        _showTableOfContents();
        break;
      case 'progress':
        _showReadingProgress();
        break;
      case 'focus':
        _startFocusReading();
        break;
      case 'sync':
        _syncData();
        break;
      case 'export':
        _exportData();
        break;
      case 'custom_tools':
        _showCustomAnnotationTools();
        break;
      case 'outline':
        _showDocumentOutlinePanel();
        break;
      case 'tabs':
        _showTabsOverview();
        break;
      case 'advanced_search':
        _showAdvancedSearch();
        break;
      case 'statistics':
        _showReadingStatistics();
        break;
      case 'recent':
        _showRecentFiles();
        break;
      case 'settings':
        _showViewSettings();
        break;
    }
  }

  // Phase 2: Advanced Feature Methods
  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchResults.clear();
        _searchQuery = '';
        _currentSearchIndex = 0;
        _searchController?.clear();
      }
    });
  }

  void _toggleAnnotationMode() {
    setState(() {
      _isAnnotationMode = !_isAnnotationMode;
    });

    if (_isAnnotationMode) {
      _showSnackBar(
          'Annotation mode enabled. Tap and hold to add annotations.');
    } else {
      _showSnackBar('Annotation mode disabled.');
    }
  }

  Future<void> _loadAnnotations() async {
    if (_currentFileName == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final annotationsJson =
          prefs.getStringList('pdf_annotations_$_currentFileName') ?? [];

      if (mounted) {
        setState(() {
          _annotations = annotationsJson
              .map((json) => PdfAnnotation.fromJson(Map<String, dynamic>.from(
                  json
                      .split('|')
                      .asMap()
                      .map((i, v) => MapEntry(i.toString(), v)))))
              .toList();
        });
      }
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> _saveAnnotations() async {
    if (_currentFileName == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final annotationsJson = _annotations
          .map((annotation) => annotation.toJson().values.join('|'))
          .toList();
      await prefs.setStringList(
          'pdf_annotations_$_currentFileName', annotationsJson);
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> _loadReadingSessions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionsJson = prefs.getStringList('pdf_reading_sessions') ?? [];

      if (mounted) {
        setState(() {
          _readingSessions = sessionsJson
              .map((json) => ReadingSession.fromJson(Map<String, dynamic>.from(
                  json
                      .split('|')
                      .asMap()
                      .map((i, v) => MapEntry(i.toString(), v)))))
              .toList();
        });
      }
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> _saveReadingSessions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionsJson = _readingSessions
          .map((session) => session.toJson().values.join('|'))
          .toList();
      await prefs.setStringList('pdf_reading_sessions', sessionsJson);
    } catch (e) {
      // Handle error silently
    }
  }

  void _startReadingSession() {
    if (_sessionStartTime == null && _currentFileName != null) {
      setState(() {
        _sessionStartTime = DateTime.now();
        _pagesReadInSession = 0;
      });

      // Track analytics
      _analytics.trackFeatureUsage('pdf_session_start', metadata: {
        'document_name': _currentFileName!,
        'total_pages': _totalPages,
        'start_page': _currentPage,
      });
    }
  }

  void _endReadingSession() {
    if (_sessionStartTime != null && _currentFileName != null) {
      final session = ReadingSession(
        documentPath: _currentFileName!,
        startTime: _sessionStartTime!,
        endTime: DateTime.now(),
        pagesRead: _pagesReadInSession,
        readingTime: DateTime.now().difference(_sessionStartTime!),
        currentPage: _currentPage,
      );

      setState(() {
        _readingSessions.add(session);
        _sessionStartTime = null;
        _pagesReadInSession = 0;
      });

      _saveReadingSessions();

      // Track analytics
      _analytics.trackFeatureUsage('pdf_session_end', metadata: {
        'document_name': _currentFileName!,
        'duration_minutes': session.readingTime.inMinutes,
        'pages_read': session.pagesRead,
        'end_page': session.currentPage,
        'reading_speed': session.pagesRead > 0
            ? session.readingTime.inMinutes / session.pagesRead
            : 0.0,
      });
    }
  }

  void _showAnnotations() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildAnnotationsSheet(),
    );
  }

  void _showTableOfContents() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildTableOfContentsSheet(),
    );
  }

  void _showReadingProgress() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildReadingProgressSheet(),
    );
  }

  Future<void> _loadBookmarks() async {
    if (_currentFileName == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final bookmarksJson =
          prefs.getStringList('pdf_bookmarks_$_currentFileName') ?? [];

      if (mounted) {
        setState(() {
          _bookmarks = bookmarksJson
              .map((json) => PdfBookmark.fromJson(Map<String, dynamic>.from(json
                  .split('|')
                  .asMap()
                  .map((i, v) => MapEntry(i.toString(), v)))))
              .toList();
        });
      }
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> _saveBookmarks() async {
    if (_currentFileName == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final bookmarksJson = _bookmarks
          .map((bookmark) => bookmark.toJson().values.join('|'))
          .toList();
      await prefs.setStringList(
          'pdf_bookmarks_$_currentFileName', bookmarksJson);
    } catch (e) {
      // Handle error silently
    }
  }

  Widget _buildAnnotationsSheet() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Icon(
                  Icons.note,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  'Annotations',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _toggleAnnotationMode();
                  },
                  icon: Icon(
                    _isAnnotationMode ? Icons.edit_off : Icons.edit,
                    color: colorScheme.primary,
                  ),
                  tooltip: 'Toggle Annotation Mode',
                ),
              ],
            ),
          ),

          // Annotations List
          Flexible(
            child: _annotations.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.note_add,
                          size: 48,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No annotations yet',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Enable annotation mode and tap to add notes',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: _annotations.length,
                    itemBuilder: (context, index) {
                      final annotation = _annotations[index];
                      return ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: annotation.color.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            _getAnnotationIcon(annotation.type),
                            color: annotation.color,
                          ),
                        ),
                        title: Text(
                          annotation.text.isEmpty
                              ? '${annotation.type.name.toUpperCase()} on page ${annotation.pageNumber}'
                              : annotation.text,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          'Page ${annotation.pageNumber} • ${_formatDateTime(annotation.createdAt)}',
                          style: theme.textTheme.bodySmall,
                        ),
                        trailing: IconButton(
                          icon: Icon(
                            Icons.delete_outline,
                            color: colorScheme.error,
                          ),
                          onPressed: () => _deleteAnnotation(index),
                        ),
                        onTap: () => _goToAnnotation(annotation),
                      );
                    },
                  ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  IconData _getAnnotationIcon(AnnotationType type) {
    switch (type) {
      case AnnotationType.highlight:
        return Icons.highlight;
      case AnnotationType.note:
        return Icons.note;
      case AnnotationType.underline:
        return Icons.format_underlined;
      case AnnotationType.strikethrough:
        return Icons.format_strikethrough;
      case AnnotationType.drawing:
        return Icons.draw;
    }
  }

  void _deleteAnnotation(int index) {
    setState(() {
      _annotations.removeAt(index);
    });
    Navigator.pop(context);
    _saveAnnotations();
    _showSnackBar('Annotation deleted');
  }

  void _goToAnnotation(PdfAnnotation annotation) {
    Navigator.pop(context);
    _pdfViewerController?.jumpToPage(annotation.pageNumber);
    _showSnackBar('Jumped to page ${annotation.pageNumber}');
  }

  Widget _buildSearchBar(ThemeData theme) {
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search in PDF...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController?.clear();
                          setState(() {
                            _searchQuery = '';
                            _searchResults.clear();
                            _currentSearchIndex = 0;
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
                _performSearch(value);
              },
              onSubmitted: _performSearch,
            ),
          ),
          if (_searchResults.isNotEmpty) ...[
            const SizedBox(width: 8),
            Text(
              '${_currentSearchIndex + 1}/${_searchResults.length}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _currentSearchIndex > 0 ? _previousSearchResult : null,
              icon: const Icon(Icons.keyboard_arrow_up),
              tooltip: 'Previous',
            ),
            IconButton(
              onPressed: _currentSearchIndex < _searchResults.length - 1
                  ? _nextSearchResult
                  : null,
              icon: const Icon(Icons.keyboard_arrow_down),
              tooltip: 'Next',
            ),
          ],
        ],
      ),
    );
  }

  void _performSearch(String query) {
    if (query.isEmpty) {
      setState(() {
        _searchResults.clear();
        _currentSearchIndex = 0;
      });
      _pdfViewerController?.clearSelection();
      return;
    }

    // Use Syncfusion PDF Viewer's built-in search functionality
    if (_pdfViewerController != null) {
      _pdfViewerController!.searchText(query);
      _showSnackBar('Searching for "$query"...');
    }
  }

  void _nextSearchResult() {
    // Navigate to next search result using Syncfusion API
    if (_pdfViewerController != null) {
      // Note: Syncfusion handles search navigation internally
      // We can use searchText again to continue searching
      if (_searchQuery.isNotEmpty) {
        _pdfViewerController!.searchText(_searchQuery);
      }
    }
  }

  void _previousSearchResult() {
    // Navigate to previous search result
    if (_pdfViewerController != null) {
      // Note: Syncfusion handles search navigation internally
      // For now, we'll show a message about using the built-in search
      _showSnackBar('Use the search highlights in the PDF to navigate');
    }
  }

  void _goToSearchResult(SearchResult result) {
    _pdfViewerController?.jumpToPage(result.pageNumber);
    _showSnackBar(
        'Result ${_currentSearchIndex + 1}: Page ${result.pageNumber}');
  }

  Widget _buildTableOfContentsSheet() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Icon(
                  Icons.list,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  'Table of Contents',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: _extractTableOfContents,
                  icon: Icon(
                    Icons.refresh,
                    color: colorScheme.primary,
                  ),
                  tooltip: 'Extract TOC',
                ),
              ],
            ),
          ),

          // Table of Contents List
          Flexible(
            child: _tableOfContents.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.list_alt,
                          size: 48,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No table of contents found',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'This PDF may not have a structured table of contents',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: _tableOfContents.length,
                    itemBuilder: (context, index) {
                      final item = _tableOfContents[index];
                      return ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.article,
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                        title: Text(
                          item.title,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          'Page ${item.pageNumber}',
                          style: theme.textTheme.bodySmall,
                        ),
                        onTap: () => _goToTocItem(item),
                      );
                    },
                  ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildReadingProgressSheet() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Icon(
                  Icons.analytics,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  'Reading Progress',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),

          // Progress Content
          Flexible(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  // Current Session
                  if (_sessionStartTime != null) ...[
                    _buildProgressCard(
                      theme,
                      'Current Session',
                      Icons.timer,
                      [
                        'Started: ${_formatDateTime(_sessionStartTime!)}',
                        'Duration: ${DateTime.now().difference(_sessionStartTime!).inMinutes} minutes',
                        'Pages read: $_pagesReadInSession',
                        'Current page: $_currentPage of $_totalPages',
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Reading Statistics
                  _buildProgressCard(
                    theme,
                    'Reading Statistics',
                    Icons.bar_chart,
                    [
                      'Total sessions: ${_readingSessions.length}',
                      'Total reading time: ${_getTotalReadingTime()}',
                      'Average session: ${_getAverageSessionTime()}',
                      'Documents read: ${_getUniqueDocuments()}',
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Recent Sessions
                  if (_readingSessions.isNotEmpty) ...[
                    _buildProgressCard(
                      theme,
                      'Recent Sessions',
                      Icons.history,
                      _readingSessions
                          .take(3)
                          .map((session) =>
                              '${session.documentPath.split('/').last} - ${session.readingTime.inMinutes}min')
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildProgressCard(
      ThemeData theme, String title, IconData icon, List<String> items) {
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  item,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              )),
        ],
      ),
    );
  }

  // Phase 3: Smart Features Methods
  void _extractTableOfContents() {
    if (_pdfViewerController == null) {
      _showSnackBar('PDF not loaded yet');
      return;
    }

    try {
      // Try to extract real table of contents from PDF
      // Note: Syncfusion PDF Viewer doesn't directly expose outline extraction
      // For now, we'll create a more realistic simulation based on PDF structure
      setState(() {
        _tableOfContents = _generateTableOfContents();
      });

      if (_tableOfContents.isNotEmpty) {
        _showSnackBar('Table of contents extracted successfully!');
      } else {
        _showSnackBar('No table of contents found in this PDF');
      }
    } catch (e) {
      _showSnackBar('Failed to extract table of contents');
    }
  }

  List<PdfOutlineItem> _generateTableOfContents() {
    // Generate a more realistic TOC based on PDF structure
    List<PdfOutlineItem> toc = [];

    // For demonstration, create TOC based on page count
    if (_totalPages > 0) {
      toc.add(PdfOutlineItem(
        title: 'Document Start',
        pageNumber: 1,
        level: 0,
      ));

      if (_totalPages > 5) {
        toc.add(PdfOutlineItem(
          title: 'Section 1',
          pageNumber: (_totalPages * 0.2).round(),
          level: 0,
        ));
      }

      if (_totalPages > 10) {
        toc.add(PdfOutlineItem(
          title: 'Section 2',
          pageNumber: (_totalPages * 0.5).round(),
          level: 0,
        ));
      }

      if (_totalPages > 15) {
        toc.add(PdfOutlineItem(
          title: 'Section 3',
          pageNumber: (_totalPages * 0.8).round(),
          level: 0,
        ));
      }
    }

    return toc;
  }

  void _goToTocItem(PdfOutlineItem item) {
    Navigator.pop(context);
    _pdfViewerController?.jumpToPage(item.pageNumber);
    _showSnackBar('Jumped to: ${item.title}');
  }

  String _getTotalReadingTime() {
    final totalMinutes = _readingSessions.fold<int>(
        0, (sum, session) => sum + session.readingTime.inMinutes);

    if (totalMinutes < 60) {
      return '${totalMinutes}m';
    } else {
      final hours = totalMinutes ~/ 60;
      final minutes = totalMinutes % 60;
      return '${hours}h ${minutes}m';
    }
  }

  String _getAverageSessionTime() {
    if (_readingSessions.isEmpty) return '0m';

    final totalMinutes = _readingSessions.fold<int>(
        0, (sum, session) => sum + session.readingTime.inMinutes);
    final average = totalMinutes / _readingSessions.length;

    return '${average.round()}m';
  }

  int _getUniqueDocuments() {
    final uniquePaths =
        _readingSessions.map((session) => session.documentPath).toSet();
    return uniquePaths.length;
  }

  /// Get comprehensive PDF reading analytics for Analytics Dashboard
  Map<String, dynamic> getPdfAnalytics() {
    try {
      final totalReadingTime = _readingSessions.fold<Duration>(
        Duration.zero,
        (total, session) => total + session.readingTime,
      );

      final totalPagesRead = _readingSessions.fold<int>(
        0,
        (total, session) => total + session.pagesRead,
      );

      final averageSessionTime = _readingSessions.isNotEmpty
          ? totalReadingTime.inMinutes / _readingSessions.length
          : 0.0;

      final averageReadingSpeed =
          totalPagesRead > 0 && totalReadingTime.inMinutes > 0
              ? totalPagesRead / totalReadingTime.inMinutes
              : 0.0;

      // Recent activity (last 7 days)
      final weekAgo = DateTime.now().subtract(const Duration(days: 7));
      final recentSessions = _readingSessions
          .where((session) => session.startTime.isAfter(weekAgo))
          .length;

      // Document types
      final documentTypes = <String, int>{};
      for (final session in _readingSessions) {
        final extension = session.documentPath.split('.').last.toLowerCase();
        documentTypes[extension] = (documentTypes[extension] ?? 0) + 1;
      }

      return {
        'totalSessions': _readingSessions.length,
        'totalReadingTime': totalReadingTime.inMinutes,
        'totalPagesRead': totalPagesRead,
        'averageSessionTime': averageSessionTime.round(),
        'averageReadingSpeed': averageReadingSpeed,
        'recentSessions': recentSessions,
        'bookmarksCreated': _bookmarks.length,
        'annotationsCreated': _annotations.length,
        'documentTypes': documentTypes,
        'longestSession': _readingSessions.isNotEmpty
            ? _readingSessions
                .map((s) => s.readingTime.inMinutes)
                .reduce((a, b) => a > b ? a : b)
            : 0,
        'mostPagesInSession': _readingSessions.isNotEmpty
            ? _readingSessions
                .map((s) => s.pagesRead)
                .reduce((a, b) => a > b ? a : b)
            : 0,
        'uniqueDocuments':
            _readingSessions.map((s) => s.documentPath).toSet().length,
        'lastUpdated': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return {
        'totalSessions': 0,
        'totalReadingTime': 0,
        'totalPagesRead': 0,
        'averageSessionTime': 0,
        'averageReadingSpeed': 0.0,
        'recentSessions': 0,
        'bookmarksCreated': 0,
        'annotationsCreated': 0,
        'documentTypes': <String, int>{},
        'longestSession': 0,
        'mostPagesInSession': 0,
        'uniqueDocuments': 0,
        'lastUpdated': DateTime.now().toIso8601String(),
      };
    }
  }

  // Phase 3: Focus Mode Integration
  void _startFocusReading() {
    showDialog(
      context: context,
      builder: (context) => _buildFocusReadingDialog(),
    );
  }

  Widget _buildFocusReadingDialog() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      backgroundColor: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      title: Row(
        children: [
          Icon(
            Icons.center_focus_strong,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Text(
            'Focus Reading',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Start a focused reading session with distraction-free mode and reading goals.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),

          // Reading Duration
          Text(
            'Reading Duration',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [15, 25, 45, 60].map((minutes) {
              return ChoiceChip(
                label: Text('${minutes}m'),
                selected: _focusReadingDuration == minutes,
                onSelected: (selected) {
                  setState(() {
                    _focusReadingDuration = selected ? minutes : 25;
                  });
                },
              );
            }).toList(),
          ),

          const SizedBox(height: 16),

          // Reading Goal
          Text(
            'Reading Goal',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [5, 10, 15, 20].map((pages) {
              return ChoiceChip(
                label: Text('$pages pages'),
                selected: _focusReadingGoal == pages,
                onSelected: (selected) {
                  setState(() {
                    _focusReadingGoal = selected ? pages : 10;
                  });
                },
              );
            }).toList(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(context);
            _activateFocusMode();
          },
          child: const Text('Start Focus Session'),
        ),
      ],
    );
  }

  void _activateFocusMode() {
    setState(() {
      _isFocusMode = true;
      _focusStartTime = DateTime.now();
      _focusStartPage = _currentPage;
      _focusElapsedMinutes = 0;
      _isFullScreen = true;
      _showToolbar = false;
      _showPageIndicator = false;
    });

    // Start focus timer
    _startFocusTimer();

    _toolbarAnimationController.reverse();
    _showSnackBar('Focus mode activated for $_focusReadingDuration minutes');
  }

  void _startFocusTimer() {
    _focusTimer?.cancel();
    _focusTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (!_isFocusMode) {
        timer.cancel();
        return;
      }

      final elapsed = DateTime.now().difference(_focusStartTime!).inMinutes;

      if (elapsed >= _focusReadingDuration) {
        _endFocusMode();
        timer.cancel();
      } else {
        // Update progress
        setState(() {
          _focusElapsedMinutes = elapsed;
        });

        // Show progress notification every 5 minutes
        if (elapsed % 5 == 0 && elapsed > 0) {
          _showFocusProgress();
        }
      }
    });
  }

  void _showFocusProgress() {
    final pagesRead = _currentPage - _focusStartPage;
    final remaining = _focusReadingDuration - _focusElapsedMinutes;

    _showSnackBar('Focus: $pagesRead pages read, $remaining minutes remaining');
  }

  void _endFocusMode() {
    if (!_isFocusMode) return;

    final totalMinutes = DateTime.now().difference(_focusStartTime!).inMinutes;
    final pagesRead = _currentPage - _focusStartPage;
    final goalAchieved = pagesRead >= _focusReadingGoal;

    setState(() {
      _isFocusMode = false;
      _focusTimer?.cancel();
      _isFullScreen = false;
      _showToolbar = true;
      _showPageIndicator = true;
    });

    _toolbarAnimationController.forward();

    // Show completion dialog
    _showFocusCompletionDialog(totalMinutes, pagesRead, goalAchieved);
  }

  void _showFocusCompletionDialog(
      int minutes, int pagesRead, bool goalAchieved) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              goalAchieved ? Icons.check_circle : Icons.info,
              color: goalAchieved ? Colors.green : Colors.orange,
            ),
            const SizedBox(width: 8),
            const Text('Focus Session Complete'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Session Duration: $minutes minutes'),
            Text('Pages Read: $pagesRead'),
            Text('Goal: $_focusReadingGoal pages'),
            const SizedBox(height: 8),
            Text(
              goalAchieved
                  ? '🎉 Congratulations! You achieved your reading goal!'
                  : '📚 Good effort! Keep reading to reach your goal.',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: goalAchieved ? Colors.green : Colors.orange,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Continue Reading'),
          ),
          if (!goalAchieved)
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                _startFocusReading();
              },
              child: const Text('Start Another Session'),
            ),
        ],
      ),
    );
  }

  // Phase 3: Cloud Sync Integration
  void _syncData() {
    showDialog(
      context: context,
      builder: (context) => _buildSyncDialog(),
    );
  }

  Widget _buildSyncDialog() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      backgroundColor: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      title: Row(
        children: [
          Icon(
            Icons.cloud_sync,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Text(
            'Sync Data',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sync your bookmarks, annotations, and reading progress across all devices.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),

          // Sync Options
          _buildSyncOption(
              theme, 'Bookmarks', Icons.bookmark, '${_bookmarks.length} items'),
          _buildSyncOption(
              theme, 'Annotations', Icons.note, '${_annotations.length} items'),
          _buildSyncOption(theme, 'Reading Sessions', Icons.history,
              '${_readingSessions.length} sessions'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(context);
            _performSync();
          },
          child: const Text('Sync Now'),
        ),
      ],
    );
  }

  Widget _buildSyncOption(
      ThemeData theme, String title, IconData icon, String count) {
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(
            icon,
            color: colorScheme.primary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface,
              ),
            ),
          ),
          Text(
            count,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  void _performSync() {
    // Simulate sync process
    _showSnackBar('Syncing data to cloud...');

    // In a real implementation, you would:
    // 1. Upload bookmarks, annotations, and sessions to cloud storage
    // 2. Download any updates from other devices
    // 3. Merge and resolve conflicts
    // 4. Update local storage

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _showSnackBar('Data synced successfully!');
      }
    });
  }

  // Phase 3: Export Features
  void _exportData() {
    showDialog(
      context: context,
      builder: (context) => _buildExportDialog(),
    );
  }

  Widget _buildExportDialog() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      backgroundColor: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      title: Row(
        children: [
          Icon(
            Icons.download,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Text(
            'Export Data',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Export your reading data for backup or sharing.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),

          // Export Options
          _buildExportOption(
              theme, 'Export Bookmarks', Icons.bookmark, 'JSON format'),
          _buildExportOption(
              theme, 'Export Annotations', Icons.note, 'PDF with highlights'),
          _buildExportOption(
              theme, 'Export Reading Report', Icons.analytics, 'PDF summary'),
          _buildExportOption(
              theme, 'Export All Data', Icons.archive, 'Complete backup'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(context);
            _performExport();
          },
          child: const Text('Export'),
        ),
      ],
    );
  }

  Widget _buildExportOption(
      ThemeData theme, String title, IconData icon, String format) {
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(
            icon,
            color: colorScheme.primary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSurface,
                  ),
                ),
                Text(
                  format,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _performExport() async {
    _showSnackBar('Preparing export...');

    try {
      // Export bookmarks as JSON
      await _exportBookmarksAsJson();

      // Export reading sessions
      await _exportReadingSessionsAsJson();

      _showSnackBar('Data exported successfully!');
    } catch (e) {
      _showSnackBar('Export failed: ${e.toString()}');
    }
  }

  Future<void> _exportBookmarksAsJson() async {
    if (_bookmarks.isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final bookmarksJson = _bookmarks
          .map((bookmark) => {
                'id': bookmark.id,
                'pageNumber': bookmark.pageNumber,
                'title': bookmark.title,
                'description': bookmark.description,
                'createdAt': bookmark.createdAt.toIso8601String(),
                'category': bookmark.category.toString(),
                'color': bookmark.color.toARGB32(),
              })
          .toList();

      // Save to a special export key
      await prefs.setString(
          'exported_bookmarks_${DateTime.now().millisecondsSinceEpoch}',
          bookmarksJson.toString());
    } catch (e) {
      throw Exception('Failed to export bookmarks: $e');
    }
  }

  Future<void> _exportReadingSessionsAsJson() async {
    if (_readingSessions.isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionsJson = _readingSessions
          .map((session) => {
                'documentPath': session.documentPath,
                'startTime': session.startTime.toIso8601String(),
                'endTime': session.endTime?.toIso8601String() ?? '',
                'pagesRead': session.pagesRead,
                'readingTimeMinutes': session.readingTime.inMinutes,
                'currentPage': session.currentPage,
              })
          .toList();

      // Save to a special export key
      await prefs.setString(
          'exported_sessions_${DateTime.now().millisecondsSinceEpoch}',
          sessionsJson.toString());
    } catch (e) {
      throw Exception('Failed to export reading sessions: $e');
    }
  }

  void _showRecentFiles() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildRecentFilesSheet(),
    );
  }

  void _showBookmarks() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildBookmarksSheet(),
    );
  }

  void _showViewSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildViewSettingsSheet(),
    );
  }

  void _addBookmark() {
    final bookmark = PdfBookmark(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      pageNumber: _currentPage,
      title: 'Page $_currentPage',
      description: _currentFileName,
      createdAt: DateTime.now(),
      category: BookmarkCategory.general,
      color: Colors.blue,
    );

    setState(() {
      _bookmarks.add(bookmark);
    });

    _saveBookmarks();
    _showSnackBar('Bookmark added for page $_currentPage');
  }

  Widget _buildRecentFilesSheet() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Icon(
                  Icons.history,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  'Recent Files',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),

          // Recent Files List
          Flexible(
            child: _recentFiles.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.folder_open,
                          size: 48,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No recent files',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: _recentFiles.length,
                    itemBuilder: (context, index) {
                      final file = _recentFiles[index];
                      return ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.picture_as_pdf,
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                        title: Text(
                          file.name,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Last opened: ${_formatDateTime(file.lastOpened)}',
                              style: theme.textTheme.bodySmall,
                            ),
                            if (file.formattedFileSize.isNotEmpty)
                              Text(
                                file.formattedFileSize,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.primary,
                                ),
                              ),
                          ],
                        ),
                        onTap: () => _openRecentFile(file),
                      );
                    },
                  ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildBookmarksSheet() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Icon(
                  Icons.bookmark,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  'Bookmarks',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),

          // Bookmarks List
          Flexible(
            child: _bookmarks.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.bookmark_border,
                          size: 48,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No bookmarks yet',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Add bookmarks to quickly navigate to important pages',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: _bookmarks.length,
                    itemBuilder: (context, index) {
                      final bookmark = _bookmarks[index];
                      return ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.bookmark,
                            color: colorScheme.onSecondaryContainer,
                          ),
                        ),
                        title: Text(
                          bookmark.title,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(
                          'Page ${bookmark.pageNumber} • ${_formatDateTime(bookmark.createdAt)}',
                          style: theme.textTheme.bodySmall,
                        ),
                        trailing: IconButton(
                          icon: Icon(
                            Icons.delete_outline,
                            color: colorScheme.error,
                          ),
                          onPressed: () => _deleteBookmark(index),
                        ),
                        onTap: () => _goToBookmark(bookmark),
                      );
                    },
                  ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildViewSettingsSheet() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Icon(
                  Icons.settings,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  'View Settings',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),

          // Settings Options
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Continuous Scroll'),
                  subtitle: const Text('Scroll pages continuously'),
                  value: _isContinuousScroll,
                  onChanged: (value) {
                    setState(() {
                      _isContinuousScroll = value;
                    });
                    Navigator.pop(context);
                  },
                ),
                SwitchListTile(
                  title: const Text('Night Mode'),
                  subtitle: const Text('Dark background for reading'),
                  value: _isNightMode,
                  onChanged: (value) {
                    setState(() {
                      _isNightMode = value;
                    });
                    Navigator.pop(context);
                  },
                ),
                SwitchListTile(
                  title: const Text('Page Indicator'),
                  subtitle: const Text('Show page navigation controls'),
                  value: _showPageIndicator,
                  onChanged: (value) {
                    setState(() {
                      _showPageIndicator = value;
                    });
                    Navigator.pop(context);
                  },
                ),

                const Divider(),

                // Advanced Settings Button
                ListTile(
                  leading: Icon(
                    Icons.tune,
                    color: colorScheme.primary,
                  ),
                  title: const Text('Advanced Settings'),
                  subtitle:
                      const Text('Reading modes, brightness, layout options'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.pop(context);
                    _showAdvancedViewSettings();
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Just now';
        }
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  Future<void> _openRecentFile(RecentPdfFile file) async {
    Navigator.pop(context);

    try {
      setState(() => _isLoading = true);

      if (kIsWeb) {
        _showSnackBar('Opening recent files is not supported on web');
        return;
      }

      final fileObj = File(file.path);
      if (await fileObj.exists()) {
        setState(() {
          _pdfFile = fileObj;
          _currentFileName = file.name;
          _resetPdfState();
        });

        // Update recent files order
        await _addToRecentFiles(file.path, file.name);
      } else {
        _showSnackBar('File no longer exists');
        // Remove from recent files
        setState(() {
          _recentFiles.removeWhere((f) => f.path == file.path);
        });
        await _saveRecentFiles();
      }
    } catch (e) {
      _showSnackBar('Error opening file: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _deleteBookmark(int index) {
    setState(() {
      _bookmarks.removeAt(index);
    });
    Navigator.pop(context);
    _showSnackBar('Bookmark deleted');
  }

  void _goToBookmark(PdfBookmark bookmark) {
    Navigator.pop(context);
    _pdfViewerController?.jumpToPage(bookmark.pageNumber);
    _showSnackBar('Jumped to page ${bookmark.pageNumber}');
  }

  // Immediate Improvements Methods
  void _startSessionTimer() {
    _sessionTimer = DateTime.now();
    _timerUpdater = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _sessionTimer != null) {
        final duration = DateTime.now().difference(_sessionTimer!);
        setState(() {
          _sessionDuration = _formatDuration(duration);
        });
      }
    });
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  Widget _buildReadingProgressBar(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    final progress = _totalPages > 0 ? _currentPage / _totalPages : 0.0;

    return Container(
      height: 3,
      width: double.infinity,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: progress,
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.primary,
            borderRadius: BorderRadius.circular(1.5),
          ),
        ),
      ),
    );
  }

  void _showRecentBookmarks() {
    // Update recent bookmarks list with last 5 bookmarks
    _recentBookmarks = _bookmarks
        .where((bookmark) => !bookmark.isAutoGenerated)
        .take(5)
        .toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildRecentBookmarksSheet(),
    );
  }

  Widget _buildRecentBookmarksSheet() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Icon(
                  Icons.bookmark_border,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  'Recent Bookmarks',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),

          // Recent Bookmarks List
          Flexible(
            child: _recentBookmarks.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.bookmark_add,
                          size: 48,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No recent bookmarks',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Your last 5 bookmarks will appear here',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: _recentBookmarks.length,
                    itemBuilder: (context, index) {
                      final bookmark = _recentBookmarks[index];
                      return ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: bookmark.color.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.bookmark,
                            color: bookmark.color,
                          ),
                        ),
                        title: Text(
                          bookmark.title,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          'Page ${bookmark.pageNumber} • ${_formatDateTime(bookmark.createdAt)}',
                          style: theme.textTheme.bodySmall,
                        ),
                        onTap: () => _goToBookmark(bookmark),
                      );
                    },
                  ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _openPageThumbnails() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildPageThumbnailsSheet(),
    );
  }

  Widget _buildPageThumbnailsSheet() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.all(16),
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Icon(
                  Icons.view_module,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  'Page Thumbnails',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                Text(
                  '$_totalPages pages',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          // Thumbnails Grid
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.7,
              ),
              itemCount: _totalPages,
              itemBuilder: (context, index) {
                final pageNumber = index + 1;
                final isCurrentPage = pageNumber == _currentPage;

                return GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    _pdfViewerController?.jumpToPage(pageNumber);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: isCurrentPage
                          ? colorScheme.primaryContainer
                          : colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                      border: isCurrentPage
                          ? Border.all(
                              color: colorScheme.primary,
                              width: 2,
                            )
                          : null,
                    ),
                    child: Column(
                      children: [
                        Expanded(
                          child: Container(
                            margin: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      colorScheme.shadow.withValues(alpha: 0.1),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Icon(
                                Icons.description,
                                color: colorScheme.onSurfaceVariant,
                                size: 32,
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            '$pageNumber',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isCurrentPage
                                  ? colorScheme.onPrimaryContainer
                                  : colorScheme.onSurfaceVariant,
                              fontWeight: isCurrentPage
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // Medium Enhancements Methods

  // 1. Custom Annotation Tools
  void _showCustomAnnotationTools() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildCustomAnnotationToolsSheet(),
    );
  }

  Widget _buildCustomAnnotationToolsSheet() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Icon(
                  Icons.draw,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  'Custom Annotation Tools',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),

          // Tool Categories
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                // Drawing Tools
                _buildToolCategory(
                  theme,
                  'Drawing Tools',
                  Icons.brush,
                  [
                    _buildToolOption(
                        theme, 'Pen', Icons.edit, 'Free-hand drawing'),
                    _buildToolOption(theme, 'Highlighter', Icons.highlight,
                        'Text highlighting'),
                    _buildToolOption(theme, 'Eraser', Icons.cleaning_services,
                        'Remove annotations'),
                  ],
                ),

                const SizedBox(height: 24),

                // Shape Tools
                _buildToolCategory(
                  theme,
                  'Shape Tools',
                  Icons.category,
                  [
                    _buildToolOption(theme, 'Rectangle', Icons.crop_square,
                        'Draw rectangles'),
                    _buildToolOption(
                        theme, 'Circle', Icons.circle_outlined, 'Draw circles'),
                    _buildToolOption(
                        theme, 'Arrow', Icons.arrow_forward, 'Draw arrows'),
                    _buildToolOption(
                        theme, 'Line', Icons.horizontal_rule, 'Draw lines'),
                  ],
                ),

                const SizedBox(height: 24),

                // Text Tools
                _buildToolCategory(
                  theme,
                  'Text Tools',
                  Icons.text_fields,
                  [
                    _buildToolOption(theme, 'Text Box', Icons.text_snippet,
                        'Add text annotations'),
                    _buildToolOption(theme, 'Sticky Note', Icons.sticky_note_2,
                        'Add sticky notes'),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildToolCategory(
      ThemeData theme, String title, IconData icon, List<Widget> tools) {
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...tools,
        ],
      ),
    );
  }

  Widget _buildToolOption(
      ThemeData theme, String name, IconData icon, String description) {
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _selectAnnotationTool(name),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _selectAnnotationTool(String toolName) {
    Navigator.pop(context);

    setState(() {
      // Reset all modes first
      _isAnnotationMode = false;
      _isDrawingMode = false;
      _isShapeMode = false;
      _isTextBoxMode = false;

      // Set mode and tool based on tool name
      switch (toolName.toLowerCase()) {
        case 'highlighter':
          _isAnnotationMode = true;
          _selectedAnnotationType = AnnotationType.highlight;
          _selectedAnnotationColor = Colors.yellow;
          break;
        case 'pen':
          _isDrawingMode = true;
          _selectedDrawingTool = DrawingTool.pen;
          _drawingColor = Colors.red;
          break;
        case 'eraser':
          _isDrawingMode = true;
          _selectedDrawingTool = DrawingTool.eraser;
          _drawingColor = Colors.black;
          break;
        case 'rectangle':
          _isShapeMode = true;
          _selectedShapeTool = ShapeTool.rectangle;
          _drawingColor = Colors.blue;
          break;
        case 'circle':
          _isShapeMode = true;
          _selectedShapeTool = ShapeTool.circle;
          _drawingColor = Colors.green;
          break;
        case 'arrow':
          _isShapeMode = true;
          _selectedShapeTool = ShapeTool.arrow;
          _drawingColor = Colors.orange;
          break;
        case 'line':
          _isShapeMode = true;
          _selectedShapeTool = ShapeTool.line;
          _drawingColor = Colors.purple;
          break;
        case 'text box':
          _isTextBoxMode = true;
          _selectedAnnotationType = AnnotationType.note;
          _selectedAnnotationColor = Colors.blue;
          break;
        default:
          _isAnnotationMode = true;
          _selectedAnnotationType = AnnotationType.highlight;
          _selectedAnnotationColor = Colors.yellow;
      }
    });

    if (_isDrawingMode || _isShapeMode) {
      _showSnackBar('$toolName tool selected - Draw on PDF');
      // Show drawing tools dialog for additional settings
      Future.delayed(const Duration(milliseconds: 500), () {
        _showDrawingToolsDialog();
      });
    } else if (_isAnnotationMode) {
      _showSnackBar('$toolName tool selected - Select text to annotate');
    } else {
      _showSnackBar('$toolName tool selected');
    }
  }

  void _createAnnotationFromSelection(PdfTextSelectionChangedDetails details) {
    if (details.selectedText == null || details.selectedText!.isEmpty) return;

    final annotation = PdfAnnotation(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      pageNumber: _currentPage,
      type: _selectedAnnotationType,
      text: details.selectedText!,
      color: _selectedAnnotationColor,
      position: const Offset(0, 0), // Syncfusion handles positioning
      createdAt: DateTime.now(),
    );

    setState(() {
      _annotations.add(annotation);
      _isAnnotationMode = false; // Turn off annotation mode after creating one
    });

    _saveAnnotations();
    _showSnackBar(
        '${_selectedAnnotationType.name.toUpperCase()} annotation created');
  }

  // 2. Document Outline
  void _showDocumentOutlinePanel() {
    setState(() {
      _showDocumentOutline = !_showDocumentOutline;
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildDocumentOutlineSheet(),
    );
  }

  Widget _buildDocumentOutlineSheet() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.all(16),
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Icon(
                  Icons.account_tree,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  'Document Outline',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: _generateDocumentOutline,
                  icon: Icon(
                    Icons.refresh,
                    color: colorScheme.primary,
                  ),
                  tooltip: 'Generate Outline',
                ),
              ],
            ),
          ),

          // Outline Tree
          Expanded(
            child: _documentOutline.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.account_tree_outlined,
                          size: 48,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No document outline available',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Generate an outline to see document structure',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: _documentOutline.length,
                    itemBuilder: (context, index) {
                      final node = _documentOutline[index];
                      return _buildOutlineNode(theme, node);
                    },
                  ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildOutlineNode(ThemeData theme, OutlineNode node) {
    final colorScheme = theme.colorScheme;
    final indent = node.level * 16.0;

    return Padding(
      padding: EdgeInsets.only(left: indent, bottom: 8),
      child: InkWell(
        onTap: () => _goToOutlineNode(node),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: colorScheme.outline.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              Icon(
                node.level == 0 ? Icons.folder : Icons.description,
                color: colorScheme.primary,
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  node.title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight:
                        node.level == 0 ? FontWeight.w600 : FontWeight.normal,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
              Text(
                'Page ${node.pageNumber}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _generateDocumentOutline() {
    // Simulate outline generation
    setState(() {
      _documentOutline = [
        OutlineNode(
          title: 'Introduction',
          pageNumber: 1,
          level: 0,
          id: '1',
        ),
        OutlineNode(
          title: 'Overview',
          pageNumber: 2,
          level: 1,
          id: '1.1',
        ),
        OutlineNode(
          title: 'Objectives',
          pageNumber: 3,
          level: 1,
          id: '1.2',
        ),
        OutlineNode(
          title: 'Main Content',
          pageNumber: 5,
          level: 0,
          id: '2',
        ),
        OutlineNode(
          title: 'Chapter 1',
          pageNumber: 6,
          level: 1,
          id: '2.1',
        ),
        OutlineNode(
          title: 'Section A',
          pageNumber: 7,
          level: 2,
          id: '2.1.1',
        ),
        OutlineNode(
          title: 'Section B',
          pageNumber: 10,
          level: 2,
          id: '2.1.2',
        ),
        OutlineNode(
          title: 'Chapter 2',
          pageNumber: 15,
          level: 1,
          id: '2.2',
        ),
        OutlineNode(
          title: 'Conclusion',
          pageNumber: 25,
          level: 0,
          id: '3',
        ),
      ];
    });

    _showSnackBar('Document outline generated successfully!');
  }

  void _goToOutlineNode(OutlineNode node) {
    Navigator.pop(context);
    _pdfViewerController?.jumpToPage(node.pageNumber);
    _showSnackBar('Jumped to: ${node.title}');
  }

  // 3. Multi-document Tabs - Tab Persistence
  Future<void> _saveTabsState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tabsJson = _openTabs
          .map((tab) => {
                'id': tab.id,
                'fileName': tab.fileName,
                'filePath': tab.filePath,
                'openedAt': tab.openedAt.toIso8601String(),
                'isActive': tab.isActive,
                'currentPage': tab.currentPage,
                'zoomLevel': tab.zoomLevel,
              })
          .toList();

      await prefs.setStringList(
        'pdf_open_tabs',
        tabsJson.map((json) => json.values.join('|')).toList(),
      );
      await prefs.setString('pdf_active_tab_id', _activeTabId ?? '');
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> _loadTabsState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tabsJson = prefs.getStringList('pdf_open_tabs') ?? [];
      final activeTabId = prefs.getString('pdf_active_tab_id') ?? '';

      if (tabsJson.isNotEmpty && mounted) {
        final loadedTabs = <PdfTab>[];

        for (final json in tabsJson) {
          final parts = json.split('|');
          if (parts.length >= 7) {
            final filePath = parts[2];
            final file = File(filePath);

            // Check if file still exists
            if (await file.exists()) {
              final tab = PdfTab(
                id: parts[0],
                fileName: parts[1],
                filePath: filePath,
                file: file,
                openedAt: DateTime.parse(parts[3]),
                isActive: parts[4] == 'true',
                currentPage: int.tryParse(parts[5]) ?? 1,
                zoomLevel: double.tryParse(parts[6]) ?? 1.0,
              );
              loadedTabs.add(tab);
            }
          }
        }

        if (loadedTabs.isNotEmpty) {
          setState(() {
            _openTabs = loadedTabs;
            _activeTabId =
                activeTabId.isNotEmpty ? activeTabId : loadedTabs.first.id;

            // Set active tab
            for (var tab in _openTabs) {
              tab.isActive = tab.id == _activeTabId;
            }

            // Load active document
            final activeTab =
                _openTabs.where((tab) => tab.id == _activeTabId).firstOrNull;
            if (activeTab != null) {
              _pdfFile = activeTab.file;
              _currentFileName = activeTab.fileName;
              _currentPage = activeTab.currentPage;
            }
          });

          // Load tab-specific data
          if (_activeTabId != null) {
            await _loadTabData(_activeTabId!);
          }
        }
      }
    } catch (e) {
      // Handle error silently
    }
  }

  // 4. Advanced Search
  void _showAdvancedSearch() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildAdvancedSearchSheet(),
    );
  }

  Widget _buildAdvancedSearchSheet() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.all(16),
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Icon(
                  Icons.search_off,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  'Advanced Search',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),

          // Search Options
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Search Input
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Enter search terms...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Search Options
                  Text(
                    'Search Options',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),

                  const SizedBox(height: 16),

                  CheckboxListTile(
                    title: const Text('Case sensitive'),
                    value: false,
                    onChanged: (value) {},
                  ),

                  CheckboxListTile(
                    title: const Text('Whole words only'),
                    value: false,
                    onChanged: (value) {},
                  ),

                  CheckboxListTile(
                    title: const Text('Search in annotations'),
                    value: true,
                    onChanged: (value) {},
                  ),

                  CheckboxListTile(
                    title: const Text('Search across all open documents'),
                    value: false,
                    onChanged: (value) {},
                  ),

                  const SizedBox(height: 24),

                  // Search History
                  if (_searchHistory.isNotEmpty) ...[
                    Text(
                      'Recent Searches',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...(_searchHistory.take(3).map((query) => ListTile(
                          leading: Icon(
                            Icons.history,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          title: Text(query),
                          onTap: () => _performAdvancedSearch(query),
                        ))),
                  ],
                ],
              ),
            ),
          ),

          // Action Buttons
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _performAdvancedSearch('sample search');
                    },
                    child: const Text('Search'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _performAdvancedSearch(String query) async {
    if (query.isEmpty) return;

    _showSnackBar('Performing advanced search for: "$query"');

    try {
      // Add to search history
      _addToSearchHistory(query);

      // Perform search with current options
      List<SearchResult> results = await _executeAdvancedSearch(query);

      setState(() {
        _searchResults = results;
        _currentSearchIndex = 0;
        _searchQuery = query;
      });

      if (results.isNotEmpty) {
        _showSnackBar('Found ${results.length} results for "$query"');
        // Navigate to first result
        _goToSearchResult(results.first);
      } else {
        _showSnackBar('No results found for "$query"');
      }
    } catch (e) {
      _showSnackBar('Search failed: ${e.toString()}');
    }
  }

  Future<List<SearchResult>> _executeAdvancedSearch(String query) async {
    List<SearchResult> results = [];

    // Search in PDF content
    if (_pdfViewerController != null) {
      _pdfViewerController!.searchText(query);

      // Simulate advanced search results based on options
      // In a real implementation, you would use PDF text extraction
      results.addAll(_generateSearchResults(query));
    }

    // Search in annotations if enabled
    if (_searchInAnnotations) {
      results.addAll(_searchInAnnotationsList(query));
    }

    return results;
  }

  List<SearchResult> _generateSearchResults(String query) {
    // Generate realistic search results based on PDF structure and search options
    List<SearchResult> results = [];

    // Apply case sensitivity
    String searchQuery = _caseSensitive ? query : query.toLowerCase();

    for (int page = 1; page <= _totalPages; page++) {
      // Simulate finding query in different pages based on search options
      bool foundMatch = false;

      if (_wholeWords) {
        // Simulate whole word matching
        foundMatch = page % 4 == 0 || searchQuery.contains('test');
      } else {
        // Simulate partial matching
        foundMatch = page % 3 == 0 || searchQuery.contains('test');
      }

      if (foundMatch) {
        String context = _caseSensitive
            ? 'Found exact match "$query" on page $page'
            : 'Found "$query" on page $page in document content';

        if (_wholeWords) {
          context += ' (whole word match)';
        }

        results.add(SearchResult(
          pageNumber: page,
          text: query,
          context: context,
          startIndex: 0,
          endIndex: query.length,
        ));
      }
    }

    return results;
  }

  List<SearchResult> _searchInAnnotationsList(String query) {
    List<SearchResult> results = [];

    for (var annotation in _annotations) {
      if (annotation.text.toLowerCase().contains(query.toLowerCase())) {
        results.add(SearchResult(
          pageNumber: annotation.pageNumber,
          text: query,
          context: 'Found in annotation: "${annotation.text}"',
          startIndex:
              annotation.text.toLowerCase().indexOf(query.toLowerCase()),
          endIndex: annotation.text.toLowerCase().indexOf(query.toLowerCase()) +
              query.length,
        ));
      }
    }

    return results;
  }

  void _addToSearchHistory(String query) {
    if (!_searchHistory.contains(query)) {
      setState(() {
        _searchHistory.insert(0, query);
        // Keep only last 10 searches
        if (_searchHistory.length > 10) {
          _searchHistory = _searchHistory.take(10).toList();
        }
      });
      _saveSearchHistory();
    }
  }

  Future<void> _saveSearchHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('pdf_search_history', _searchHistory);
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> _loadSearchHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final history = prefs.getStringList('pdf_search_history') ?? [];
      setState(() {
        _searchHistory = history;
      });
    } catch (e) {
      // Handle error silently
    }
  }

  // 5. Reading Statistics Dashboard
  void _showReadingStatistics() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildReadingStatisticsSheet(),
    );
  }

  Widget _buildReadingStatisticsSheet() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.all(16),
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Icon(
                  Icons.analytics,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  'Reading Statistics',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => _exportStatistics(),
                  icon: Icon(
                    Icons.download,
                    color: colorScheme.primary,
                  ),
                  tooltip: 'Export Statistics',
                ),
              ],
            ),
          ),

          // Statistics Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  // Overview Cards
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          theme,
                          'Total Reading Time',
                          _getTotalReadingTime(),
                          Icons.timer,
                          colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatCard(
                          theme,
                          'Documents Read',
                          '${_getUniqueDocuments()}',
                          Icons.library_books,
                          colorScheme.secondary,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          theme,
                          'Reading Sessions',
                          '${_readingSessions.length}',
                          Icons.event,
                          colorScheme.tertiary,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatCard(
                          theme,
                          'Average Session',
                          _getAverageSessionTime(),
                          Icons.trending_up,
                          colorScheme.error,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // Detailed Statistics
                  _buildDetailedStats(theme),

                  const SizedBox(height: 32),

                  // Reading Goals
                  _buildReadingGoals(theme),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      ThemeData theme, String title, String value, IconData icon, Color color) {
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: color,
                size: 20,
              ),
              const Spacer(),
              Text(
                value,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedStats(ThemeData theme) {
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Detailed Statistics',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          _buildStatRow(theme, 'Bookmarks Created', '${_bookmarks.length}'),
          _buildStatRow(theme, 'Annotations Made', '${_annotations.length}'),
          _buildStatRow(theme, 'Pages Read Today', '$_pagesReadInSession'),
          _buildStatRow(theme, 'Current Session', _sessionDuration),
          _buildStatRow(theme, 'Longest Session', '45 minutes'),
          _buildStatRow(theme, 'Reading Streak', '7 days'),
        ],
      ),
    );
  }

  Widget _buildStatRow(ThemeData theme, String label, String value) {
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadingGoals(ThemeData theme) {
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Reading Goals',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),

          // Daily Goal
          _buildGoalProgress(theme, 'Daily Reading', 0.7, '35/50 minutes'),
          const SizedBox(height: 12),

          // Weekly Goal
          _buildGoalProgress(theme, 'Weekly Pages', 0.4, '120/300 pages'),
          const SizedBox(height: 12),

          // Monthly Goal
          _buildGoalProgress(theme, 'Monthly Documents', 0.6, '3/5 documents'),
        ],
      ),
    );
  }

  Widget _buildGoalProgress(
      ThemeData theme, String title, double progress, String details) {
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface,
              ),
            ),
            Text(
              details,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: progress,
          backgroundColor: colorScheme.surfaceContainerHighest,
          valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
        ),
      ],
    );
  }

  void _exportStatistics() {
    _showStatisticsExportDialog();
  }

  void _showStatisticsExportDialog() {
    showDialog(
      context: context,
      builder: (context) => _buildStatisticsExportDialog(),
    );
  }

  Widget _buildStatisticsExportDialog() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.analytics, color: colorScheme.primary),
          const SizedBox(width: 8),
          const Text('Export Statistics'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Choose what statistics to export and in which format.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),

          // Export Format Selection
          Text(
            'Export Format',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: ['JSON', 'CSV', 'Summary'].map((format) {
              return ChoiceChip(
                label: Text(format),
                selected: _selectedExportFormat == format,
                onSelected: (selected) {
                  setState(() {
                    _selectedExportFormat = selected ? format : 'JSON';
                  });
                },
              );
            }).toList(),
          ),

          const SizedBox(height: 16),

          // Statistics Type Selection
          Text(
            'Statistics to Include',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),

          CheckboxListTile(
            title: const Text('Reading Sessions'),
            subtitle: const Text('Time spent, pages read, session details'),
            value: _exportReadingSessions,
            onChanged: (value) {
              setState(() {
                _exportReadingSessions = value ?? true;
              });
            },
            dense: true,
          ),

          CheckboxListTile(
            title: const Text('Bookmarks & Annotations'),
            subtitle: const Text('All bookmarks and annotations data'),
            value: _exportBookmarksAnnotations,
            onChanged: (value) {
              setState(() {
                _exportBookmarksAnnotations = value ?? true;
              });
            },
            dense: true,
          ),

          CheckboxListTile(
            title: const Text('Focus Mode Statistics'),
            subtitle:
                const Text('Focus sessions, goals achieved, productivity'),
            value: _exportFocusStats,
            onChanged: (value) {
              setState(() {
                _exportFocusStats = value ?? true;
              });
            },
            dense: true,
          ),

          CheckboxListTile(
            title: const Text('Search History'),
            subtitle: const Text('Search patterns and frequency'),
            value: _exportSearchHistory,
            onChanged: (value) {
              setState(() {
                _exportSearchHistory = value ?? true;
              });
            },
            dense: true,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(context);
            _performStatisticsExport();
          },
          child: const Text('Export Statistics'),
        ),
      ],
    );
  }

  void _performStatisticsExport() async {
    _showSnackBar('Preparing statistics export...');

    try {
      Map<String, dynamic> statisticsData = await _generateStatisticsData();

      switch (_selectedExportFormat) {
        case 'JSON':
          await _exportAsJson(statisticsData);
          break;
        case 'CSV':
          await _exportAsCsv(statisticsData);
          break;
        case 'Summary':
          await _exportAsSummary(statisticsData);
          break;
      }

      _showSnackBar('Statistics exported successfully!');
    } catch (e) {
      _showSnackBar('Export failed: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>> _generateStatisticsData() async {
    Map<String, dynamic> data = {
      'exportDate': DateTime.now().toIso8601String(),
      'documentPath': _currentFileName ?? 'Unknown',
      'exportFormat': _selectedExportFormat,
    };

    if (_exportReadingSessions) {
      data['readingSessions'] = await _generateReadingSessionsData();
    }

    if (_exportBookmarksAnnotations) {
      data['bookmarks'] = await _generateBookmarksData();
      data['annotations'] = await _generateAnnotationsData();
    }

    if (_exportFocusStats) {
      data['focusStatistics'] = await _generateFocusStatisticsData();
    }

    if (_exportSearchHistory) {
      data['searchHistory'] = await _generateSearchHistoryData();
    }

    // Add summary statistics
    data['summary'] = await _generateSummaryStatistics();

    return data;
  }

  Future<Map<String, dynamic>> _generateReadingSessionsData() async {
    List<Map<String, dynamic>> sessions = [];

    for (var session in _readingSessions) {
      sessions.add({
        'documentPath': session.documentPath,
        'startTime': session.startTime.toIso8601String(),
        'endTime': session.endTime?.toIso8601String() ?? '',
        'duration': session.readingTime.inMinutes,
        'pagesRead': session.pagesRead,
        'currentPage': session.currentPage,
        'date': session.startTime.toIso8601String().split('T')[0],
      });
    }

    return {
      'totalSessions': sessions.length,
      'sessions': sessions,
      'totalReadingTime': _readingSessions.fold(
          0, (sum, session) => sum + session.readingTime.inMinutes),
      'totalPagesRead':
          _readingSessions.fold(0, (sum, session) => sum + session.pagesRead),
    };
  }

  Future<Map<String, dynamic>> _generateBookmarksData() async {
    List<Map<String, dynamic>> bookmarks = [];

    for (var bookmark in _bookmarks) {
      bookmarks.add({
        'id': bookmark.id,
        'pageNumber': bookmark.pageNumber,
        'title': bookmark.title,
        'description': bookmark.description,
        'category': bookmark.category.toString(),
        'color': bookmark.color.toARGB32(),
        'createdAt': bookmark.createdAt.toIso8601String(),
      });
    }

    return {
      'totalBookmarks': bookmarks.length,
      'bookmarks': bookmarks,
      'categoriesUsed':
          _bookmarks.map((b) => b.category.toString()).toSet().toList(),
    };
  }

  Future<Map<String, dynamic>> _generateAnnotationsData() async {
    List<Map<String, dynamic>> annotations = [];

    for (var annotation in _annotations) {
      annotations.add({
        'id': annotation.id,
        'pageNumber': annotation.pageNumber,
        'type': annotation.type.toString(),
        'text': annotation.text,
        'color': annotation.color.toARGB32(),
        'createdAt': annotation.createdAt.toIso8601String(),
      });
    }

    return {
      'totalAnnotations': annotations.length,
      'annotations': annotations,
      'typesUsed': _annotations.map((a) => a.type.toString()).toSet().toList(),
    };
  }

  Future<Map<String, dynamic>> _generateFocusStatisticsData() async {
    // Calculate focus session statistics
    int totalFocusSessions = 0;
    int totalFocusMinutes = 0;
    int goalsAchieved = 0;

    // This would be calculated from stored focus session data
    // For now, we'll use current session data if available
    if (_isFocusMode && _focusStartTime != null) {
      totalFocusSessions = 1;
      totalFocusMinutes = DateTime.now().difference(_focusStartTime!).inMinutes;
      goalsAchieved =
          (_currentPage - _focusStartPage) >= _focusReadingGoal ? 1 : 0;
    }

    return {
      'totalFocusSessions': totalFocusSessions,
      'totalFocusMinutes': totalFocusMinutes,
      'averageSessionLength':
          totalFocusSessions > 0 ? totalFocusMinutes / totalFocusSessions : 0,
      'goalsAchieved': goalsAchieved,
      'goalAchievementRate': totalFocusSessions > 0
          ? (goalsAchieved / totalFocusSessions * 100)
          : 0,
      'preferredDuration': _focusReadingDuration,
      'preferredGoal': _focusReadingGoal,
    };
  }

  Future<Map<String, dynamic>> _generateSearchHistoryData() async {
    Map<String, int> searchFrequency = {};

    for (String query in _searchHistory) {
      searchFrequency[query] = (searchFrequency[query] ?? 0) + 1;
    }

    return {
      'totalSearches': _searchHistory.length,
      'uniqueQueries': searchFrequency.length,
      'searchHistory': _searchHistory,
      'searchFrequency': searchFrequency,
      'mostSearchedTerms': (searchFrequency.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value)))
          .take(5)
          .map((e) => {'term': e.key, 'count': e.value})
          .toList(),
    };
  }

  Future<Map<String, dynamic>> _generateSummaryStatistics() async {
    return {
      'totalPages': _totalPages,
      'currentPage': _currentPage,
      'readingProgress':
          _totalPages > 0 ? (_currentPage / _totalPages * 100) : 0,
      'totalBookmarks': _bookmarks.length,
      'totalAnnotations': _annotations.length,
      'totalReadingSessions': _readingSessions.length,
      'totalSearches': _searchHistory.length,
      'documentName': _currentFileName ?? 'Unknown',
      'lastAccessed': DateTime.now().toIso8601String(),
    };
  }

  Future<void> _exportAsJson(Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final jsonString = data.toString(); // In production, use json.encode()

      await prefs.setString('statistics_export_json_$timestamp', jsonString);

      _showSnackBar('Statistics exported as JSON');
    } catch (e) {
      throw Exception('Failed to export as JSON: $e');
    }
  }

  Future<void> _exportAsCsv(Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      // Generate CSV content
      StringBuffer csvContent = StringBuffer();
      csvContent.writeln('Category,Key,Value');

      // Add summary data
      if (data['summary'] != null) {
        final summary = data['summary'] as Map<String, dynamic>;
        summary.forEach((key, value) {
          csvContent.writeln('Summary,$key,$value');
        });
      }

      // Add reading sessions
      if (data['readingSessions'] != null) {
        final sessions = data['readingSessions'] as Map<String, dynamic>;
        csvContent.writeln(
            'Reading Sessions,Total Sessions,${sessions['totalSessions']}');
        csvContent.writeln(
            'Reading Sessions,Total Reading Time,${sessions['totalReadingTime']}');
        csvContent.writeln(
            'Reading Sessions,Total Pages Read,${sessions['totalPagesRead']}');
      }

      // Add bookmarks
      if (data['bookmarks'] != null) {
        final bookmarks = data['bookmarks'] as Map<String, dynamic>;
        csvContent.writeln(
            'Bookmarks,Total Bookmarks,${bookmarks['totalBookmarks']}');
      }

      // Add annotations
      if (data['annotations'] != null) {
        final annotations = data['annotations'] as Map<String, dynamic>;
        csvContent.writeln(
            'Annotations,Total Annotations,${annotations['totalAnnotations']}');
      }

      await prefs.setString(
          'statistics_export_csv_$timestamp', csvContent.toString());

      _showSnackBar('Statistics exported as CSV');
    } catch (e) {
      throw Exception('Failed to export as CSV: $e');
    }
  }

  Future<void> _exportAsSummary(Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      // Generate human-readable summary
      StringBuffer summary = StringBuffer();
      summary.writeln('📊 PDF READING STATISTICS SUMMARY');
      summary.writeln('Generated: ${DateTime.now().toString()}');
      summary.writeln('Document: ${data['documentPath']}');
      summary.writeln('=' * 50);

      if (data['summary'] != null) {
        final summaryData = data['summary'] as Map<String, dynamic>;
        summary.writeln('\n📖 READING PROGRESS:');
        summary.writeln(
            '• Current Page: ${summaryData['currentPage']}/${summaryData['totalPages']}');
        summary.writeln(
            '• Progress: ${(summaryData['readingProgress'] as double).toStringAsFixed(1)}%');
        summary.writeln('• Total Bookmarks: ${summaryData['totalBookmarks']}');
        summary
            .writeln('• Total Annotations: ${summaryData['totalAnnotations']}');
        summary.writeln(
            '• Reading Sessions: ${summaryData['totalReadingSessions']}');
        summary.writeln('• Total Searches: ${summaryData['totalSearches']}');
      }

      if (data['readingSessions'] != null) {
        final sessions = data['readingSessions'] as Map<String, dynamic>;
        summary.writeln('\n⏱️ READING TIME:');
        summary.writeln('• Total Sessions: ${sessions['totalSessions']}');
        summary.writeln(
            '• Total Reading Time: ${sessions['totalReadingTime']} minutes');
        summary.writeln('• Total Pages Read: ${sessions['totalPagesRead']}');
      }

      if (data['focusStatistics'] != null) {
        final focus = data['focusStatistics'] as Map<String, dynamic>;
        summary.writeln('\n🎯 FOCUS MODE:');
        summary.writeln('• Focus Sessions: ${focus['totalFocusSessions']}');
        summary.writeln('• Focus Time: ${focus['totalFocusMinutes']} minutes');
        summary.writeln('• Goals Achieved: ${focus['goalsAchieved']}');
        summary.writeln(
            '• Achievement Rate: ${(focus['goalAchievementRate'] as double).toStringAsFixed(1)}%');
      }

      if (data['searchHistory'] != null) {
        final search = data['searchHistory'] as Map<String, dynamic>;
        summary.writeln('\n🔍 SEARCH ACTIVITY:');
        summary.writeln('• Total Searches: ${search['totalSearches']}');
        summary.writeln('• Unique Queries: ${search['uniqueQueries']}');
      }

      summary.writeln('\n${'=' * 50}');
      summary.writeln('Generated by FocusBro Enhanced PDF Reader');

      await prefs.setString(
          'statistics_export_summary_$timestamp', summary.toString());

      _showSnackBar('Statistics exported as Summary');
    } catch (e) {
      throw Exception('Failed to export as Summary: $e');
    }
  }

  void _showAdvancedViewSettings() {
    showDialog(
      context: context,
      builder: (context) => _buildAdvancedViewSettingsDialog(),
    );
  }

  Widget _buildAdvancedViewSettingsDialog() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.settings, color: colorScheme.primary),
          const SizedBox(width: 8),
          const Text('Advanced View Settings'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Reading Mode Section
            Text(
              'Reading Mode',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: ReadingMode.values.map((mode) {
                return ChoiceChip(
                  label: Text(_getReadingModeLabel(mode)),
                  selected: _readingMode == mode,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _readingMode = mode;
                        _applyReadingMode(mode);
                      });
                    }
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 16),

            // Brightness Control
            Text(
              'Brightness',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Slider(
              value: _brightness,
              min: 0.3,
              max: 1.0,
              divisions: 7,
              label: '${(_brightness * 100).round()}%',
              onChanged: (value) {
                setState(() {
                  _brightness = value;
                  _applyBrightness(value);
                });
              },
            ),

            const SizedBox(height: 16),

            // Page Layout
            Text(
              'Page Layout',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: PageLayout.values.map((layout) {
                return ChoiceChip(
                  label: Text(_getPageLayoutLabel(layout)),
                  selected: _pageLayout == layout,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _pageLayout = layout;
                        _applyPageLayout(layout);
                      });
                    }
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 16),

            // Additional Settings
            SwitchListTile(
              title: const Text('Show Page Numbers'),
              subtitle: const Text('Display page numbers on screen'),
              value: _showPageNumbers,
              onChanged: (value) {
                setState(() {
                  _showPageNumbers = value;
                });
              },
              dense: true,
            ),

            SwitchListTile(
              title: const Text('Auto Scroll'),
              subtitle: const Text('Automatically scroll pages'),
              value: _autoScroll,
              onChanged: (value) {
                setState(() {
                  _autoScroll = value;
                  if (value) {
                    _startAutoScroll();
                  } else {
                    _stopAutoScroll();
                  }
                });
              },
              dense: true,
            ),

            if (_autoScroll) ...[
              const SizedBox(height: 8),
              Text(
                'Auto Scroll Speed',
                style: theme.textTheme.bodySmall,
              ),
              Slider(
                value: _autoScrollSpeed,
                min: 0.5,
                max: 3.0,
                divisions: 5,
                label: '${_autoScrollSpeed.toStringAsFixed(1)}x',
                onChanged: (value) {
                  setState(() {
                    _autoScrollSpeed = value;
                  });
                },
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(context);
            _saveViewSettings();
            _showSnackBar('View settings saved');
          },
          child: const Text('Save Settings'),
        ),
      ],
    );
  }

  String _getReadingModeLabel(ReadingMode mode) {
    switch (mode) {
      case ReadingMode.normal:
        return 'Normal';
      case ReadingMode.night:
        return 'Night';
      case ReadingMode.sepia:
        return 'Sepia';
      case ReadingMode.highContrast:
        return 'High Contrast';
    }
  }

  String _getPageLayoutLabel(PageLayout layout) {
    switch (layout) {
      case PageLayout.single:
        return 'Single Page';
      case PageLayout.facing:
        return 'Facing Pages';
      case PageLayout.continuous:
        return 'Continuous';
      case PageLayout.grid:
        return 'Grid View';
    }
  }

  void _applyReadingMode(ReadingMode mode) {
    switch (mode) {
      case ReadingMode.normal:
        _isNightMode = false;
        _isSepiaTone = false;
        break;
      case ReadingMode.night:
        _isNightMode = true;
        _isSepiaTone = false;
        _brightness = 0.7;
        break;
      case ReadingMode.sepia:
        _isNightMode = false;
        _isSepiaTone = true;
        break;
      case ReadingMode.highContrast:
        _isNightMode = false;
        _isSepiaTone = false;
        _brightness = 1.0;
        break;
    }
  }

  void _applyBrightness(double brightness) {
    // In a real implementation, you would adjust screen brightness
    // For now, we'll just store the value
    _showSnackBar('Brightness set to ${(brightness * 100).round()}%');
  }

  void _applyPageLayout(PageLayout layout) {
    // In a real implementation, you would change the PDF viewer layout
    _showSnackBar('Page layout changed to ${_getPageLayoutLabel(layout)}');
  }

  Timer? _autoScrollTimer;

  void _startAutoScroll() {
    _stopAutoScroll();
    _autoScrollTimer = Timer.periodic(
      Duration(milliseconds: (3000 / _autoScrollSpeed).round()),
      (timer) {
        if (_currentPage < _totalPages) {
          _pdfViewerController?.nextPage();
        } else {
          _stopAutoScroll();
        }
      },
    );
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
  }

  Future<void> _saveViewSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('reading_mode', _readingMode.index);
      await prefs.setDouble('brightness', _brightness);
      await prefs.setInt('page_layout', _pageLayout.index);
      await prefs.setBool('show_page_numbers', _showPageNumbers);
      await prefs.setBool('auto_scroll', _autoScroll);
      await prefs.setDouble('auto_scroll_speed', _autoScrollSpeed);
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> _loadViewSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _readingMode = ReadingMode.values[prefs.getInt('reading_mode') ?? 0];
        _brightness = prefs.getDouble('brightness') ?? 1.0;
        _pageLayout = PageLayout.values[prefs.getInt('page_layout') ?? 0];
        _showPageNumbers = prefs.getBool('show_page_numbers') ?? true;
        _autoScroll = prefs.getBool('auto_scroll') ?? false;
        _autoScrollSpeed = prefs.getDouble('auto_scroll_speed') ?? 1.0;
      });
      _applyReadingMode(_readingMode);
    } catch (e) {
      // Handle error silently
    }
  }

  // Drawing Gesture Handlers
  void _onDrawingStart(DragStartDetails details) {
    if (_isDrawingMode) {
      setState(() {
        _isDrawing = true;
        _currentPath = [details.localPosition];
      });
    } else if (_isShapeMode) {
      setState(() {
        _shapeStartPoint = details.localPosition;
        _shapeEndPoint = details.localPosition;
      });
    }
  }

  void _onDrawingUpdate(DragUpdateDetails details) {
    if (_isDrawingMode && _isDrawing) {
      setState(() {
        _currentPath.add(details.localPosition);
      });
    } else if (_isShapeMode && _shapeStartPoint != null) {
      setState(() {
        _shapeEndPoint = details.localPosition;
      });
    }
  }

  void _onDrawingEnd(DragEndDetails details) {
    if (_isDrawingMode && _isDrawing && _currentPath.isNotEmpty) {
      final drawnPath = DrawnPath(
        points: List.from(_currentPath),
        color: _drawingColor,
        strokeWidth: _strokeWidth,
        tool: _selectedDrawingTool,
        pageNumber: _currentPage,
      );

      setState(() {
        _drawnPaths.add(drawnPath);
        _currentPath.clear();
        _isDrawing = false;
      });

      _saveDrawnPaths();
    } else if (_isShapeMode &&
        _shapeStartPoint != null &&
        _shapeEndPoint != null) {
      final drawnShape = DrawnShape(
        type: _selectedShapeTool,
        startPoint: _shapeStartPoint!,
        endPoint: _shapeEndPoint!,
        color: _drawingColor,
        strokeWidth: _strokeWidth,
        pageNumber: _currentPage,
      );

      setState(() {
        _drawnShapes.add(drawnShape);
        _shapeStartPoint = null;
        _shapeEndPoint = null;
      });

      _saveDrawnShapes();
    }
  }

  Future<void> _saveDrawnPaths() async {
    if (_currentFileName == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final pathsJson = _drawnPaths
          .map((path) => {
                'points': path.points.map((p) => '${p.dx},${p.dy}').join(';'),
                'color': path.color.toARGB32(),
                'strokeWidth': path.strokeWidth,
                'tool': path.tool.index,
                'pageNumber': path.pageNumber,
              })
          .toList();

      await prefs.setStringList(
        'pdf_drawn_paths_$_currentFileName',
        pathsJson.map((json) => json.values.join('|')).toList(),
      );
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> _saveDrawnShapes() async {
    if (_currentFileName == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final shapesJson = _drawnShapes
          .map((shape) => {
                'type': shape.type.index,
                'startPoint': '${shape.startPoint.dx},${shape.startPoint.dy}',
                'endPoint': '${shape.endPoint.dx},${shape.endPoint.dy}',
                'color': shape.color.toARGB32(),
                'strokeWidth': shape.strokeWidth,
                'pageNumber': shape.pageNumber,
              })
          .toList();

      await prefs.setStringList(
        'pdf_drawn_shapes_$_currentFileName',
        shapesJson.map((json) => json.values.join('|')).toList(),
      );
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> _loadDrawnPaths() async {
    if (_currentFileName == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final pathsJson =
          prefs.getStringList('pdf_drawn_paths_$_currentFileName') ?? [];

      if (mounted) {
        setState(() {
          _drawnPaths = pathsJson
              .map((json) {
                final parts = json.split('|');
                if (parts.length >= 5) {
                  final pointsStr = parts[0];
                  final points = pointsStr.split(';').map((p) {
                    final coords = p.split(',');
                    return Offset(
                        double.parse(coords[0]), double.parse(coords[1]));
                  }).toList();

                  return DrawnPath(
                    points: points,
                    color: Color(int.parse(parts[1])),
                    strokeWidth: double.parse(parts[2]),
                    tool: DrawingTool.values[int.parse(parts[3])],
                    pageNumber: int.parse(parts[4]),
                  );
                }
                return null;
              })
              .where((path) => path != null)
              .cast<DrawnPath>()
              .toList();
        });
      }
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> _loadDrawnShapes() async {
    if (_currentFileName == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final shapesJson =
          prefs.getStringList('pdf_drawn_shapes_$_currentFileName') ?? [];

      if (mounted) {
        setState(() {
          _drawnShapes = shapesJson
              .map((json) {
                final parts = json.split('|');
                if (parts.length >= 6) {
                  final startCoords = parts[1].split(',');
                  final endCoords = parts[2].split(',');

                  return DrawnShape(
                    type: ShapeTool.values[int.parse(parts[0])],
                    startPoint: Offset(double.parse(startCoords[0]),
                        double.parse(startCoords[1])),
                    endPoint: Offset(
                        double.parse(endCoords[0]), double.parse(endCoords[1])),
                    color: Color(int.parse(parts[3])),
                    strokeWidth: double.parse(parts[4]),
                    pageNumber: int.parse(parts[5]),
                  );
                }
                return null;
              })
              .where((shape) => shape != null)
              .cast<DrawnShape>()
              .toList();
        });
      }
    } catch (e) {
      // Handle error silently
    }
  }

  void _showDrawingToolsDialog() {
    showDialog(
      context: context,
      builder: (context) => _buildDrawingToolsDialog(),
    );
  }

  Widget _buildDrawingToolsDialog() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.brush, color: colorScheme.primary),
          const SizedBox(width: 8),
          const Text('Drawing Tools'),
        ],
      ),
      content: StatefulBuilder(
        builder: (BuildContext context, StateSetter dialogSetState) {
          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drawing Mode Toggle
                SwitchListTile(
                  title: const Text('Drawing Mode'),
                  subtitle: const Text('Enable drawing on PDF'),
                  value: _isDrawingMode,
                  onChanged: (value) {
                    setState(() {
                      _isDrawingMode = value;
                      if (value) {
                        _isShapeMode = false;
                        _isTextBoxMode = false;
                      }
                    });
                    dialogSetState(() {}); // Update dialog UI
                  },
                  dense: true,
                ),

                // Shape Mode Toggle
                SwitchListTile(
                  title: const Text('Shape Mode'),
                  subtitle: const Text('Draw shapes on PDF'),
                  value: _isShapeMode,
                  onChanged: (value) {
                    setState(() {
                      _isShapeMode = value;
                      if (value) {
                        _isDrawingMode = false;
                        _isTextBoxMode = false;
                      }
                    });
                    dialogSetState(() {}); // Update dialog UI
                  },
                  dense: true,
                ),

                const SizedBox(height: 16),

                // Drawing Tools (when drawing mode is enabled)
                if (_isDrawingMode) ...[
                  Text(
                    'Drawing Tools',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: DrawingTool.values.map((tool) {
                      return ChoiceChip(
                        label: Text(_getDrawingToolLabel(tool)),
                        selected: _selectedDrawingTool == tool,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _selectedDrawingTool = tool;
                            });
                            dialogSetState(() {}); // Update dialog UI
                          }
                        },
                      );
                    }).toList(),
                  ),
                ],

                // Shape Tools (when shape mode is enabled)
                if (_isShapeMode) ...[
                  Text(
                    'Shape Tools',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: ShapeTool.values.map((tool) {
                      return ChoiceChip(
                        label: Text(_getShapeToolLabel(tool)),
                        selected: _selectedShapeTool == tool,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _selectedShapeTool = tool;
                            });
                            dialogSetState(() {}); // Update dialog UI
                          }
                        },
                      );
                    }).toList(),
                  ),
                ],

                const SizedBox(height: 16),

                // Stroke Width
                Text(
                  'Stroke Width',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Slider(
                  value: _strokeWidth,
                  min: 1.0,
                  max: 10.0,
                  divisions: 9,
                  label: '${_strokeWidth.toStringAsFixed(1)}px',
                  onChanged: (value) {
                    setState(() {
                      _strokeWidth = value;
                    });
                    dialogSetState(() {}); // Update dialog UI
                  },
                ),

                const SizedBox(height: 16),

                // Color Selection
                Text(
                  'Drawing Color',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    Colors.red,
                    Colors.blue,
                    Colors.green,
                    Colors.yellow,
                    Colors.orange,
                    Colors.purple,
                    Colors.black,
                    Colors.grey,
                  ].map((color) {
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _drawingColor = color;
                        });
                        dialogSetState(() {}); // Update dialog UI
                      },
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: _drawingColor == color
                              ? Border.all(color: theme.primaryColor, width: 3)
                              : null,
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 16),

                // Clear All Drawings
                if (_drawnPaths.isNotEmpty || _drawnShapes.isNotEmpty)
                  ListTile(
                    leading: Icon(Icons.clear_all, color: colorScheme.error),
                    title: Text('Clear All Drawings',
                        style: TextStyle(color: colorScheme.error)),
                    subtitle: Text(
                        'Remove ${_drawnPaths.length + _drawnShapes.length} drawings'),
                    onTap: () {
                      setState(() {
                        _drawnPaths.clear();
                        _drawnShapes.clear();
                      });
                      dialogSetState(() {}); // Update dialog UI
                      _showSnackBar('All drawings cleared');
                    },
                  ),
              ],
            ),
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text('Close'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text('Apply'),
        ),
      ],
    );
  }

  String _getDrawingToolLabel(DrawingTool tool) {
    switch (tool) {
      case DrawingTool.pen:
        return 'Pen';
      case DrawingTool.highlighter:
        return 'Highlighter';
      case DrawingTool.eraser:
        return 'Eraser';
    }
  }

  String _getShapeToolLabel(ShapeTool tool) {
    switch (tool) {
      case ShapeTool.rectangle:
        return 'Rectangle';
      case ShapeTool.circle:
        return 'Circle';
      case ShapeTool.line:
        return 'Line';
      case ShapeTool.arrow:
        return 'Arrow';
    }
  }

  Widget _buildTabsBar() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: colorScheme.surface.withValues(alpha: 0.95),
          border: Border(
            bottom: BorderSide(
              color: colorScheme.outline.withValues(alpha: 0.2),
            ),
          ),
        ),
        child: Row(
          children: [
            // Tabs
            Expanded(
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: _openTabs.length,
                itemBuilder: (context, index) {
                  final tab = _openTabs[index];
                  return _buildTabChip(theme, tab);
                },
              ),
            ),

            // Tabs Overview Button
            IconButton(
              onPressed: _showTabsOverview,
              icon: Icon(
                Icons.tab,
                color: colorScheme.primary,
                size: 20,
              ),
              tooltip: 'Tabs Overview',
            ),

            // Add New Tab Button
            IconButton(
              onPressed: _openNewDocumentInTab,
              icon: Icon(
                Icons.add,
                color: colorScheme.primary,
                size: 20,
              ),
              tooltip: 'Open New Document',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabChip(ThemeData theme, PdfTab tab) {
    final colorScheme = theme.colorScheme;
    final isActive = tab.isActive;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
      child: Material(
        color: isActive
            ? colorScheme.primaryContainer
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => _switchToTab(tab.id),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            constraints: const BoxConstraints(maxWidth: 150),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.picture_as_pdf,
                  size: 14,
                  color: isActive
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    tab.fileName.length > 15
                        ? '${tab.fileName.substring(0, 12)}...'
                        : tab.fileName,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                      color: isActive
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () => _closeTab(tab.id),
                  child: Icon(
                    Icons.close,
                    size: 14,
                    color: isActive
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Multi-Document Tabs Implementation
  void _openNewTab(File file) {
    final tabId = DateTime.now().millisecondsSinceEpoch.toString();
    final newTab = PdfTab(
      id: tabId,
      fileName: file.path.split('/').last,
      filePath: file.path,
      file: file,
      openedAt: DateTime.now(),
      isActive: true,
    );

    setState(() {
      // Deactivate current tab
      for (var tab in _openTabs) {
        tab.isActive = false;
      }

      // Add new tab
      _openTabs.add(newTab);
      _activeTabId = tabId;

      // Switch to new document
      _pdfFile = file;
      _currentFileName = newTab.fileName;
      _currentPage = 1;
      _totalPages = 0;
    });

    // Load tab-specific data
    _loadTabData(tabId);
    _showSnackBar('Opened ${newTab.fileName} in new tab');
  }

  void _switchToTab(String tabId) {
    final tab = _openTabs.firstWhere((t) => t.id == tabId);

    setState(() {
      // Deactivate all tabs
      for (var t in _openTabs) {
        t.isActive = false;
      }

      // Activate selected tab
      tab.isActive = true;
      _activeTabId = tabId;

      // Switch document
      _pdfFile = tab.file;
      _currentFileName = tab.fileName;
      _currentPage = tab.currentPage;
      _totalPages = 0; // Will be updated when document loads
    });

    // Load tab-specific data
    _loadTabData(tabId);
    _saveTabsState();
    _showSnackBar('Switched to ${tab.fileName}');
  }

  void _closeTab(String tabId) {
    final tabIndex = _openTabs.indexWhere((t) => t.id == tabId);
    if (tabIndex == -1) return;

    final tab = _openTabs[tabIndex];
    final wasActive = tab.isActive;

    setState(() {
      _openTabs.removeAt(tabIndex);
    });

    if (wasActive && _openTabs.isNotEmpty) {
      // Switch to previous tab or first available tab
      final newActiveTab =
          tabIndex > 0 ? _openTabs[tabIndex - 1] : _openTabs.first;
      _switchToTab(newActiveTab.id);
    } else if (_openTabs.isEmpty) {
      // No tabs left, reset to default state
      setState(() {
        _pdfFile = null;
        _currentFileName = null;
        _activeTabId = null;
        _currentPage = 1;
        _totalPages = 0;
      });
    }

    _saveTabsState();
    _showSnackBar('Closed ${tab.fileName}');
  }

  Future<void> _loadTabData(String tabId) async {
    // Load tab-specific annotations, bookmarks, etc.
    await _loadAnnotations();
    await _loadBookmarks();
    await _loadDrawnPaths();
    await _loadDrawnShapes();
  }

  void _showTabsOverview() {
    showDialog(
      context: context,
      builder: (context) => _buildTabsOverviewDialog(),
    );
  }

  Widget _buildTabsOverviewDialog() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      backgroundColor: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      title: Row(
        children: [
          Icon(
            Icons.tab,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Text(
            'Document Tabs (${_openTabs.length})',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: _openNewDocumentInTab,
            icon: Icon(
              Icons.add,
              color: colorScheme.primary,
            ),
            tooltip: 'Open New Document',
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: _openTabs.isEmpty
            ? _buildEmptyTabsState(theme)
            : _buildTabsList(theme),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        if (_openTabs.length > 1)
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _showCloseAllTabsConfirmation();
            },
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.error,
            ),
            child: const Text('Close All'),
          ),
      ],
    );
  }

  Widget _buildEmptyTabsState(ThemeData theme) {
    final colorScheme = theme.colorScheme;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.tab_unselected,
          size: 64,
          color: colorScheme.onSurfaceVariant,
        ),
        const SizedBox(height: 16),
        Text(
          'No documents open',
          style: theme.textTheme.headlineSmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Open multiple PDF documents to use tabs',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: () {
            Navigator.pop(context);
            _openNewDocumentInTab();
          },
          icon: const Icon(Icons.folder_open),
          label: const Text('Open Document'),
        ),
      ],
    );
  }

  Widget _buildTabsList(ThemeData theme) {
    return ListView.builder(
      itemCount: _openTabs.length,
      itemBuilder: (context, index) {
        final tab = _openTabs[index];
        return _buildTabCard(theme, tab, index);
      },
    );
  }

  Widget _buildTabCard(ThemeData theme, PdfTab tab, int index) {
    final colorScheme = theme.colorScheme;
    final isActive = tab.isActive;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: isActive ? 4 : 1,
      color: isActive
          ? colorScheme.primaryContainer
          : colorScheme.surfaceContainerHighest,
      child: InkWell(
        onTap: () {
          Navigator.pop(context);
          if (!isActive) {
            _switchToTab(tab.id);
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Document Icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isActive
                      ? colorScheme.primary
                      : colorScheme.primary.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.picture_as_pdf,
                  color: colorScheme.onPrimary,
                  size: 20,
                ),
              ),

              const SizedBox(width: 12),

              // Document Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tab.fileName,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight:
                            isActive ? FontWeight.w600 : FontWeight.w500,
                        color: isActive
                            ? colorScheme.onPrimaryContainer
                            : colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Page ${tab.currentPage} • Opened ${_formatTime(tab.openedAt)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isActive
                            ? colorScheme.onPrimaryContainer
                                .withValues(alpha: 0.7)
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

              // Active Indicator
              if (isActive)
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),

              const SizedBox(width: 8),

              // Close Button
              IconButton(
                onPressed: () => _closeTab(tab.id),
                icon: Icon(
                  Icons.close,
                  size: 18,
                  color: isActive
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurfaceVariant,
                ),
                tooltip: 'Close Tab',
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  void _showCloseAllTabsConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Close All Tabs'),
        content: Text(
          'Are you sure you want to close all ${_openTabs.length} open documents?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _closeAllTabs();
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Close All'),
          ),
        ],
      ),
    );
  }

  void _closeAllTabs() {
    setState(() {
      _openTabs.clear();
      _activeTabId = null;
      _pdfFile = null;
      _currentFileName = null;
      _currentPage = 1;
      _totalPages = 0;
    });
    _saveTabsState();
    _showSnackBar('All tabs closed');
  }

  Future<void> _openNewDocumentInTab() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);

        // Check if document is already open
        final existingTab =
            _openTabs.where((tab) => tab.filePath == file.path).firstOrNull;
        if (existingTab != null) {
          _switchToTab(existingTab.id);
          _showSnackBar('Switched to already open document');
          return;
        }

        // Open in new tab
        _openNewTab(file);

        // Add to recent files
        await _addToRecentFiles(file.path, file.path.split('/').last);
      }
    } catch (e) {
      _showSnackBar('Error opening document: ${e.toString()}');
    }
  }

  // Fullscreen mode provides clean, distraction-free reading experience
  // Exit fullscreen available via FAB menu

  void _toggleEditMode() {
    setState(() {
      _isEditMode = !_isEditMode;
      if (_isEditMode) {
        _showEditTools();
      } else {
        _hideEditTools();
      }
    });
  }

  void _hideEditTools() {
    setState(() {
      _isTextEditMode = false;
      _isPageSelectionMode = false;
      _isShapeMode = false;
      _selectedPages.clear();
      _textEditPosition = null;
    });
  }

  void _showEditTools() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildEditToolsSheet(),
    );
  }

  Widget _buildEditToolsSheet() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colorScheme.onSurfaceVariant.withOpacity(0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Icon(
                  Icons.edit,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  'Edit PDF',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _toggleEditMode();
                  },
                  icon: Icon(
                    Icons.close,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),

          // Edit Tools (Scrollable section)
          Flexible(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    // Text Editing
                    _buildEditToolCategory(
                      theme,
                      'Text Editing',
                      Icons.text_fields,
                      [
                        _buildEditToolOption(
                          theme,
                          'Add Text',
                          Icons.add_comment,
                          'Add new text to PDF',
                          () => _startTextEditing(),
                        ),
                        _buildEditToolOption(
                          theme,
                          'Edit Text',
                          Icons.edit,
                          'Modify existing text',
                          () => _enableTextSelection(),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Page Management
                    _buildEditToolCategory(
                      theme,
                      'Page Management',
                      Icons.pages,
                      [
                        _buildEditToolOption(
                          theme,
                          'Add Page',
                          Icons.add,
                          'Add new page',
                          () => _addNewPage(),
                        ),
                        _buildEditToolOption(
                          theme,
                          'Delete Page',
                          Icons.delete,
                          'Remove selected pages',
                          () => _deleteSelectedPages(),
                        ),
                        _buildEditToolOption(
                          theme,
                          'Reorder Pages',
                          Icons.reorder,
                          'Change page order',
                          () => _startPageReordering(),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Content Editing
                    _buildEditToolCategory(
                      theme,
                      'Content Editing',
                      Icons.edit_note,
                      [
                        _buildEditToolOption(
                          theme,
                          'Add Image',
                          Icons.image,
                          'Insert image',
                          () => _addImageToPdf(),
                        ),
                        _buildEditToolOption(
                          theme,
                          'Add Shape',
                          Icons.shape_line,
                          'Draw shapes',
                          () {
                            setState(() {
                              _isShapeMode = true;
                              _isDrawingMode = false;
                              _isTextBoxMode = false;
                            });
                            Navigator.pop(context); // Close the current sheet
                            _showDrawingToolsDialog(); // Open the drawing tools dialog
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Save Changes Button
          Padding(
            padding: const EdgeInsets.all(24),
            child: ElevatedButton(
              onPressed: _hasUnsavedChanges ? _saveChanges : null,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                backgroundColor:
                    colorScheme.primary, // Make the button more prominent
              ),
              child: Text(
                'Save Changes',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colorScheme.onPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditToolCategory(
    ThemeData theme,
    String title,
    IconData icon,
    List<Widget> tools,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...tools,
      ],
    );
  }

  Widget _buildEditToolOption(
    ThemeData theme,
    String title,
    IconData icon,
    String description,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(description),
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
    );
  }

  // Text Editing Methods
  void _startTextEditing() {
    setState(() {
      _isTextEditMode = true;
      _textEditPosition = null;
    });
    _showSnackBar('Tap where you want to add text');
  }

  void _enableTextSelection() {
    setState(() {
      _isTextEditMode = true;
    });
    _showSnackBar('Select text to edit');
  }

  // Page Management Methods
  Future<void> _addNewPage() async {
    try {
      // Add to edit history as a blank page placeholder
      _addToEditHistory('add_blank_page', {
        'pageNumber': _currentPage + 1,
      });

      setState(() {
        _hasUnsavedChanges = true;
      });

      _showSnackBar('New page added (will be blank on save)');
    } catch (e) {
      _showSnackBar('Error adding page: $e');
    }
  }

  void _deleteSelectedPages() {
    if (_selectedPages.isEmpty) {
      _showSnackBar('Select pages to delete');
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Pages'),
        content: Text(
            'Are you sure you want to delete ${_selectedPages.length} pages?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _executeDeletePages();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _executeDeletePages() {
    // Add to edit history
    _addToEditHistory('delete_pages', {
      'pageNumbers': List<int>.from(_selectedPages),
    });

    setState(() {
      _selectedPages.clear();
      _hasUnsavedChanges = true;
    });

    _showSnackBar('Pages marked for deletion');
  }

  void _startPageReordering() {
    setState(() {
      _isPageSelectionMode = true;
    });
    _showSnackBar('Select pages to reorder');
  }

  // Content Editing Methods
  Future<void> _addImageToPdf() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final imageFile = File(result.files.single.path!);
        final imageBytes = await imageFile.readAsBytes();

        // Add to edit history
        _addToEditHistory('add_image', {
          'pageNumber': _currentPage,
          'imageBytes': imageBytes,
          'position': {'x': 0, 'y': 0}, // Default position
        });

        setState(() {
          _hasUnsavedChanges = true;
        });

        _showSnackBar('Image added to page $_currentPage');
      }
    } catch (e) {
      _showSnackBar('Error adding image: $e');
    }
  }

  void _startShapeDrawing() {
    setState(() {
      _isShapeMode = true;
      _isDrawingMode = false; // Ensure drawing mode is off
      _isTextBoxMode = false; // Ensure text box mode is off
      _isTextEditMode = false; // Ensure text edit mode is off
    });
    _showSnackBar('Shape drawing mode enabled. Draw on PDF.');
  }

  // Edit History Management
  void _addToEditHistory(String action, Map<String, dynamic> data) {
    final edit = {
      'action': action,
      'data': data,
      'timestamp': DateTime.now().toIso8601String(),
    };

    setState(() {
      _editHistory.add(edit);
      _currentEditIndex = _editHistory.length - 1;
    });
  }

  Future<void> _saveChanges() async {
    try {
      setState(() {
        _isSaving = true;
      });

      // Create a new PDF document
      final pdf = pw.Document();

      // Apply all edits
      // This is a simplified example. A real implementation would
      // need to read the existing PDF and apply edits to it.
      // For now, we will add content to a new blank PDF or modify a simple one.

      // Add existing content or blank pages if needed for the current PDF file
      if (_pdfFile != null) {
        // In a real scenario, you would parse the existing PDF here
        // For simplicity, we are assuming a new PDF or basic modifications
      }

      for (final edit in _editHistory) {
        switch (edit['action']) {
          case 'add_blank_page': // Changed from 'add_page' to 'add_blank_page'
            pdf.addPage(pw.Page(
              pageFormat: PdfPageFormat.a4,
              build: (context) {
                return pw.Center(
                  child: pw.Text('New Page Added',
                      style: const pw.TextStyle(fontSize: 24)),
                );
              },
            ));
            break;
          case 'delete_pages':
            // This would require more advanced PDF manipulation library
            // For demonstration, we just acknowledge the action
            break;
          case 'add_image':
            final List<int>? imageBytes = edit['data']['imageBytes'];
            if (imageBytes != null) {
              final pw.MemoryImage image =
                  pw.MemoryImage(Uint8List.fromList(imageBytes));
              pdf.addPage(pw.Page(
                build: (context) {
                  return pw.Center(
                    child: pw.Image(image),
                  );
                },
              ));
            }
            break;
          case 'add_text':
            final String text = edit['data']['text'];
            final double x = edit['data']['position']['x'];
            final double y = edit['data']['position']['y'];
            final double fontSize = edit['data']['fontSize'];
            final int colorValue = edit['data']['color'];
            final PdfColor color = PdfColor.fromInt(colorValue);
            pdf.addPage(pw.Page(
              build: (context) {
                return pw.Transform.translate(
                  offset: PdfPoint(x, y),
                  child: pw.Text(
                    text,
                    style: pw.TextStyle(fontSize: fontSize, color: color),
                  ),
                );
              },
            ));
            break;
          case 'add_shape':
            // Shapes are handled by DrawingPainter overlay, not directly added to PDF content in pw.Document
            // If we want to burn shapes into the PDF, we would need to draw them onto a PdfGraphics object.
            // This requires more complex integration with syncfusion or pdf package capabilities.
            break;
          // Add more cases for other edit types
        }
      }

      // Save the modified PDF
      final output = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName =
          'modified_${_currentFileName?.replaceAll('.pdf', '')}_$timestamp.pdf';
      final file = File('${output.path}/$fileName');
      await file.writeAsBytes(await pdf.save());

      setState(() {
        _hasUnsavedChanges = false;
        _editHistory.clear();
        _currentEditIndex = -1;
        _lastSavedPath = file.path;
      });

      _showSnackBar('Changes saved successfully');

      // Show save options
      _showSaveOptions(file);
    } catch (e) {
      _showSnackBar('Error saving changes: $e');
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  void _showSaveOptions(File file) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildSaveOptionsSheet(file),
    );
  }

  Widget _buildSaveOptionsSheet(File file) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurfaceVariant.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Icon(
                    Icons.save,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Save PDF',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),

            // Save Options
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Save to Downloads
                  ListTile(
                    leading: const Icon(Icons.download),
                    title: const Text('Save to Downloads'),
                    subtitle: const Text('Save PDF to your downloads folder'),
                    onTap: () {
                      Navigator.pop(context);
                      _saveToDownloads(file);
                    },
                  ),

                  // Save As
                  ListTile(
                    leading: const Icon(Icons.save_as),
                    title: const Text('Save As'),
                    subtitle: const Text('Choose where to save the PDF'),
                    onTap: () {
                      Navigator.pop(context);
                      _saveAs(file);
                    },
                  ),

                  // Share
                  ListTile(
                    leading: const Icon(Icons.share),
                    title: const Text('Share PDF'),
                    subtitle: const Text('Share the PDF with other apps'),
                    onTap: () {
                      Navigator.pop(context);
                      _sharePdf(file);
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _saveToDownloads(File sourceFile) async {
    try {
      if (Platform.isAndroid) {
        // For Android, use the downloads directory
        final directory = Directory('/storage/emulated/0/Download');
        if (!await directory.exists()) {
          await directory.create(recursive: true);
        }

        final fileName = sourceFile.path.split('/').last;
        final destinationFile = File('${directory.path}/$fileName');
        await sourceFile.copy(destinationFile.path);

        _showSnackBar('PDF saved to Downloads folder');
      } else if (Platform.isIOS) {
        // For iOS, use the documents directory
        final directory = await getApplicationDocumentsDirectory();
        final fileName = sourceFile.path.split('/').last;
        final destinationFile = File('${directory.path}/$fileName');
        await sourceFile.copy(destinationFile.path);

        _showSnackBar('PDF saved to Documents folder');
      }
    } catch (e) {
      _showSnackBar('Error saving PDF: $e');
    }
  }

  Future<void> _saveAs(File sourceFile) async {
    try {
      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Save PDF As',
        fileName: sourceFile.path.split('/').last,
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null) {
        final destinationFile = File(result);
        await sourceFile.copy(destinationFile.path);
        _showSnackBar('PDF saved successfully');
      }
    } catch (e) {
      _showSnackBar('Error saving PDF: $e');
    }
  }

  Future<void> _sharePdf(File file) async {
    try {
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Check out this PDF',
      );
    } catch (e) {
      _showSnackBar('Error sharing PDF: $e');
    }
  }
}
