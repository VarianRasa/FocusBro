import 'dart:io';

const Object _voiceNoteUnset = Object();

/// Voice Note model for storing voice recording data
class VoiceNote {
  final String id;
  final String title;
  final String? transcription;
  final String audioFilePath;
  final Duration duration;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String category;
  final bool isFavorite;
  final bool isPinned;
  final List<String> tags;
  final double? transcriptionConfidence;
  final String? audioFormat;
  final int? sampleRate;
  final int? bitRate;

  const VoiceNote({
    required this.id,
    required this.title,
    this.transcription,
    required this.audioFilePath,
    required this.duration,
    required this.createdAt,
    required this.updatedAt,
    this.category = 'Voice Notes',
    this.isFavorite = false,
    this.isPinned = false,
    this.tags = const [],
    this.transcriptionConfidence,
    this.audioFormat,
    this.sampleRate,
    this.bitRate,
  });

  /// Create a copy with updated values
  VoiceNote copyWith({
    String? id,
    String? title,
    Object? transcription = _voiceNoteUnset,
    String? audioFilePath,
    Duration? duration,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? category,
    bool? isFavorite,
    bool? isPinned,
    List<String>? tags,
    Object? transcriptionConfidence = _voiceNoteUnset,
    Object? audioFormat = _voiceNoteUnset,
    Object? sampleRate = _voiceNoteUnset,
    Object? bitRate = _voiceNoteUnset,
  }) {
    return VoiceNote(
      id: id ?? this.id,
      title: title ?? this.title,
      transcription: identical(transcription, _voiceNoteUnset)
          ? this.transcription
          : transcription as String?,
      audioFilePath: audioFilePath ?? this.audioFilePath,
      duration: duration ?? this.duration,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      category: category ?? this.category,
      isFavorite: isFavorite ?? this.isFavorite,
      isPinned: isPinned ?? this.isPinned,
      tags: tags ?? this.tags,
      transcriptionConfidence:
          identical(transcriptionConfidence, _voiceNoteUnset)
              ? this.transcriptionConfidence
              : transcriptionConfidence as double?,
      audioFormat: identical(audioFormat, _voiceNoteUnset)
          ? this.audioFormat
          : audioFormat as String?,
      sampleRate: identical(sampleRate, _voiceNoteUnset)
          ? this.sampleRate
          : sampleRate as int?,
      bitRate:
          identical(bitRate, _voiceNoteUnset) ? this.bitRate : bitRate as int?,
    );
  }

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'transcription': transcription,
      'audioFilePath': audioFilePath,
      'duration': duration.inMilliseconds,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'category': category,
      'isFavorite': isFavorite,
      'isPinned': isPinned,
      'tags': tags,
      'transcriptionConfidence': transcriptionConfidence,
      'audioFormat': audioFormat,
      'sampleRate': sampleRate,
      'bitRate': bitRate,
    };
  }

  /// Create from JSON
  factory VoiceNote.fromJson(Map<String, dynamic> json) {
    return VoiceNote(
      id: json['id'],
      title: json['title'],
      transcription: json['transcription'],
      audioFilePath: json['audioFilePath'],
      duration: Duration(milliseconds: json['duration'] ?? 0),
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      category: json['category'] ?? 'Voice Notes',
      isFavorite: json['isFavorite'] ?? false,
      isPinned: json['isPinned'] ?? false,
      tags: List<String>.from(json['tags'] ?? []),
      transcriptionConfidence: json['transcriptionConfidence']?.toDouble(),
      audioFormat: json['audioFormat'],
      sampleRate: json['sampleRate'],
      bitRate: json['bitRate'],
    );
  }

  /// Check if audio file exists
  bool get audioFileExists {
    return File(audioFilePath).existsSync();
  }

  /// Get file size in bytes
  int get fileSizeBytes {
    try {
      return File(audioFilePath).lengthSync();
    } catch (e) {
      return 0;
    }
  }

  /// Get formatted file size
  String get formattedFileSize {
    final bytes = fileSizeBytes;
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  /// Get formatted duration
  String get formattedDuration {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Get formatted creation date
  String get formattedCreatedAt {
    return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
  }

  /// Check if transcription is available
  bool get hasTranscription {
    return transcription != null && transcription!.isNotEmpty;
  }

  /// Get transcription quality indicator
  String get transcriptionQuality {
    if (!hasTranscription) return 'No transcription';
    if (transcriptionConfidence == null) return 'Unknown quality';

    final confidence = transcriptionConfidence!;
    if (confidence >= 0.9) return 'High quality';
    if (confidence >= 0.7) return 'Good quality';
    if (confidence >= 0.5) return 'Fair quality';
    return 'Low quality';
  }

  @override
  String toString() {
    return 'VoiceNote(id: $id, title: $title, duration: $formattedDuration, hasTranscription: $hasTranscription)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VoiceNote && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
