import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import '../models/music_track.dart';

/// Import progress callback
typedef ImportProgressCallback = void Function(double progress, String status);

/// Import result
class ImportResult {
  final bool success;
  final List<MusicTrack> importedTracks;
  final List<String> errors;
  final int totalFiles;
  final int successfulImports;

  const ImportResult({
    required this.success,
    required this.importedTracks,
    required this.errors,
    required this.totalFiles,
    required this.successfulImports,
  });
}

/// Service for importing music files from device storage
class MusicImportService {
  static final MusicImportService _instance = MusicImportService._internal();
  factory MusicImportService() => _instance;
  MusicImportService._internal();

  /// Supported audio file extensions
  static const List<String> supportedExtensions = [
    'mp3',
    'wav',
    'm4a',
    'aac',
    'flac'
  ];

  /// Supported MIME types
  static const List<String> supportedMimeTypes = [
    'audio/mpeg',
    'audio/wav',
    'audio/mp4',
    'audio/aac',
    'audio/flac',
  ];

  /// Pick and import music files from device storage
  Future<ImportResult> importMusicFiles({
    ImportProgressCallback? onProgress,
    bool allowMultiple = true,
  }) async {
    try {
      onProgress?.call(0.0, 'Opening file picker...');

      // Pick files using file_picker
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: supportedExtensions,
        allowMultiple: allowMultiple,
        withData: false, // We'll read the file ourselves for better control
        withReadStream: false,
      );

      if (result == null || result.files.isEmpty) {
        return const ImportResult(
          success: false,
          importedTracks: [],
          errors: ['No files selected'],
          totalFiles: 0,
          successfulImports: 0,
        );
      }

      onProgress?.call(0.1, 'Processing selected files...');

      final List<MusicTrack> importedTracks = [];
      final List<String> errors = [];
      final totalFiles = result.files.length;

      for (int i = 0; i < result.files.length; i++) {
        final file = result.files[i];
        final progress = 0.1 + (i / totalFiles) * 0.8;

        onProgress?.call(progress, 'Processing ${file.name}...');

        try {
          final track = await _processFile(file);
          if (track != null) {
            importedTracks.add(track);
          } else {
            errors.add('Failed to process ${file.name}');
          }
        } catch (e) {
          errors.add('Error processing ${file.name}: $e');
          if (kDebugMode) {
            print('Error importing ${file.name}: $e');
          }
        }
      }

      onProgress?.call(0.9, 'Finalizing import...');

      // Copy files to app directory
      for (int i = 0; i < importedTracks.length; i++) {
        final track = importedTracks[i];
        try {
          final newPath =
              await _copyFileToAppDirectory(track.filePath, track.title);
          importedTracks[i] = track.copyWith(filePath: newPath);
        } catch (e) {
          errors.add('Failed to copy ${track.title}: $e');
        }
      }

      onProgress?.call(1.0, 'Import completed!');

      return ImportResult(
        success: importedTracks.isNotEmpty,
        importedTracks: importedTracks,
        errors: errors,
        totalFiles: totalFiles,
        successfulImports: importedTracks.length,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error during import: $e');
      }
      return ImportResult(
        success: false,
        importedTracks: [],
        errors: ['Import failed: $e'],
        totalFiles: 0,
        successfulImports: 0,
      );
    }
  }

  /// Process a single file and extract metadata
  Future<MusicTrack?> _processFile(PlatformFile file) async {
    if (file.path == null) return null;

    try {
      final filePath = file.path!;
      final fileExtension = path.extension(filePath).toLowerCase();

      // Validate file extension
      if (!supportedExtensions.contains(fileExtension.substring(1))) {
        throw Exception('Unsupported file format: $fileExtension');
      }

      // Validate MIME type
      final mimeType = lookupMimeType(filePath);
      if (mimeType == null || !supportedMimeTypes.contains(mimeType)) {
        if (kDebugMode) {
          print('Warning: Unknown MIME type for $filePath: $mimeType');
        }
      }

      // Extract metadata
      final metadata = await _extractMetadata(filePath);

      // Generate unique ID
      final id =
          'imported_${DateTime.now().millisecondsSinceEpoch}_${file.name.hashCode}';

      // Determine category based on metadata or filename
      final category = _determineCategory(metadata, file.name);

      return MusicTrack(
        id: id,
        title: metadata['title'] ?? _cleanFileName(file.name),
        artist: metadata['artist'] ?? 'Unknown Artist',
        description: metadata['album'] ?? 'Imported music',
        filePath: filePath,
        category: category,
        source: MusicSource.file,
        duration: metadata['duration'] != null
            ? Duration(milliseconds: metadata['duration'] as int)
            : null,
        isBuiltIn: false,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error processing file ${file.name}: $e');
      }
      return null;
    }
  }

  /// Extract metadata from audio file
  Future<Map<String, dynamic>> _extractMetadata(String filePath) async {
    try {
      // For now, we'll use basic file information
      // In a production app, you would use a proper metadata extraction library
      final file = File(filePath);
      final stat = await file.stat();

      // Try to extract basic info from filename
      final fileName = path.basenameWithoutExtension(filePath);
      final parts = fileName.split(' - ');

      String? artist;
      String? title;

      if (parts.length >= 2) {
        artist = parts[0].trim();
        title = parts.sublist(1).join(' - ').trim();
      } else {
        title = fileName;
      }

      return {
        'title': title,
        'artist': artist,
        'album': null,
        'genre': null,
        'duration': null, // Would need audio analysis for this
        'year': null,
        'trackNumber': null,
        'fileSize': stat.size,
        'lastModified': stat.modified,
      };
    } catch (e) {
      if (kDebugMode) {
        print('Failed to extract metadata from $filePath: $e');
      }
      return {};
    }
  }

  /// Determine music category based on metadata and filename
  MusicCategory _determineCategory(
      Map<String, dynamic> metadata, String fileName) {
    final genre = (metadata['genre'] as String?)?.toLowerCase() ?? '';
    final title =
        (metadata['title'] as String?)?.toLowerCase() ?? fileName.toLowerCase();
    final artist = (metadata['artist'] as String?)?.toLowerCase() ?? '';

    // Check for specific keywords
    if (genre.contains('classical') || artist.contains('classical')) {
      return MusicCategory.classical;
    }

    if (genre.contains('ambient') || title.contains('ambient')) {
      return MusicCategory.ambient;
    }

    if (genre.contains('lo-fi') ||
        genre.contains('lofi') ||
        title.contains('lofi')) {
      return MusicCategory.lofi;
    }

    if (title.contains('rain') ||
        title.contains('ocean') ||
        title.contains('forest') ||
        title.contains('nature') ||
        title.contains('bird')) {
      return MusicCategory.nature;
    }

    if (title.contains('white noise') ||
        title.contains('pink noise') ||
        title.contains('brown noise') ||
        title.contains('noise')) {
      return MusicCategory.whiteNoise;
    }

    if (title.contains('meditation') ||
        title.contains('zen') ||
        title.contains('calm')) {
      return MusicCategory.meditation;
    }

    if (title.contains('binaural') ||
        title.contains('frequency') ||
        title.contains('hz')) {
      return MusicCategory.binaural;
    }

    // Check if it's instrumental (no vocals mentioned)
    if (genre.contains('instrumental') || title.contains('instrumental')) {
      return MusicCategory.instrumental;
    }

    // Default to custom category
    return MusicCategory.custom;
  }

  /// Clean filename for display
  String _cleanFileName(String fileName) {
    // Remove extension
    final nameWithoutExt = path.basenameWithoutExtension(fileName);

    // Replace underscores and hyphens with spaces
    String cleaned = nameWithoutExt.replaceAll(RegExp(r'[_-]'), ' ');

    // Remove common prefixes/suffixes
    cleaned = cleaned.replaceAll(
        RegExp(r'^\d+[\.\-\s]*'), ''); // Remove track numbers
    cleaned = cleaned.replaceAll(
        RegExp(r'\s*\(.*\)\s*$'), ''); // Remove parentheses at end

    // Capitalize first letter of each word
    return cleaned
        .split(' ')
        .map((word) => word.isNotEmpty
            ? word[0].toUpperCase() + word.substring(1).toLowerCase()
            : word)
        .join(' ')
        .trim();
  }

  /// Copy file to app's music directory
  Future<String> _copyFileToAppDirectory(
      String sourcePath, String trackTitle) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final musicDir = Directory('${appDir.path}/music');

      // Create music directory if it doesn't exist
      if (!await musicDir.exists()) {
        await musicDir.create(recursive: true);
      }

      final sourceFile = File(sourcePath);
      final extension = path.extension(sourcePath);
      final safeFileName = _sanitizeFileName(trackTitle) + extension;
      final destinationPath = '${musicDir.path}/$safeFileName';

      // Copy file
      await sourceFile.copy(destinationPath);

      return destinationPath;
    } catch (e) {
      if (kDebugMode) {
        print('Error copying file: $e');
      }
      rethrow;
    }
  }

  /// Sanitize filename for safe storage
  String _sanitizeFileName(String fileName) {
    // Remove or replace invalid characters
    return fileName
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .toLowerCase();
  }

  /// Validate if file is a supported audio format
  bool isValidAudioFile(String filePath) {
    final extension = path.extension(filePath).toLowerCase();
    return supportedExtensions.contains(extension.substring(1));
  }

  /// Get file size in a human-readable format
  String getFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
