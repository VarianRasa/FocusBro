const Object _musicValueUnset = Object();

/// Model representing a music track for background music
class MusicTrack {
  final String id;
  final String title;
  final String artist;
  final String? description;
  final String filePath; // Asset path or file path
  final MusicCategory category;
  final MusicSource source;
  final Duration? duration;
  final String? thumbnailPath;
  final bool isBuiltIn;

  const MusicTrack({
    required this.id,
    required this.title,
    required this.artist,
    this.description,
    required this.filePath,
    required this.category,
    required this.source,
    this.duration,
    this.thumbnailPath,
    this.isBuiltIn = false,
  });

  factory MusicTrack.fromJson(Map<String, dynamic> json) {
    return MusicTrack(
      id: json['id'] as String,
      title: json['title'] as String,
      artist: json['artist'] as String,
      description: json['description'] as String?,
      filePath: json['filePath'] as String,
      category: MusicCategory.values.firstWhere(
        (e) => e.name == json['category'],
        orElse: () => MusicCategory.ambient,
      ),
      source: MusicSource.values.firstWhere(
        (e) => e.name == json['source'],
        orElse: () => MusicSource.asset,
      ),
      duration: json['duration'] != null
          ? Duration(milliseconds: json['duration'] as int)
          : null,
      thumbnailPath: json['thumbnailPath'] as String?,
      isBuiltIn: json['isBuiltIn'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'description': description,
      'filePath': filePath,
      'category': category.name,
      'source': source.name,
      'duration': duration?.inMilliseconds,
      'thumbnailPath': thumbnailPath,
      'isBuiltIn': isBuiltIn,
    };
  }

  MusicTrack copyWith({
    String? id,
    String? title,
    String? artist,
    String? description,
    String? filePath,
    MusicCategory? category,
    MusicSource? source,
    Duration? duration,
    String? thumbnailPath,
    bool? isBuiltIn,
  }) {
    return MusicTrack(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      description: description ?? this.description,
      filePath: filePath ?? this.filePath,
      category: category ?? this.category,
      source: source ?? this.source,
      duration: duration ?? this.duration,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MusicTrack && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'MusicTrack(id: $id, title: $title, artist: $artist, category: $category)';
  }
}

/// Categories for organizing music tracks
enum MusicCategory {
  nature('Nature Sounds', 'Sounds from nature like rain, forest, ocean'),
  whiteNoise('White Noise', 'Various noise types for concentration'),
  instrumental('Instrumental', 'Music without vocals for focus'),
  binaural('Binaural Beats', 'Frequency-based sounds for brain entrainment'),
  ambient('Ambient', 'Atmospheric and ambient music'),
  lofi('Lo-Fi', 'Low-fidelity hip-hop and chill beats'),
  classical('Classical', 'Classical music for concentration'),
  meditation('Meditation', 'Calming sounds for meditation and relaxation'),
  work('Work Focus', 'Optimized for work and productivity'),
  study('Study', 'Perfect for studying and learning'),
  break_('Break Time', 'Relaxing music for breaks'),
  custom('Custom', 'User-added custom tracks');

  const MusicCategory(this.displayName, this.description);

  final String displayName;
  final String description;
}

/// Source of the music track
enum MusicSource {
  asset('Built-in Asset'),
  file('Local File'),
  url('Online Stream');

  const MusicSource(this.displayName);

  final String displayName;
}

/// Playlist model for organizing tracks
class MusicPlaylist {
  final String id;
  final String name;
  final String? description;
  final List<String> trackIds;
  final MusicCategory? category;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isBuiltIn;

  const MusicPlaylist({
    required this.id,
    required this.name,
    this.description,
    required this.trackIds,
    this.category,
    required this.createdAt,
    required this.updatedAt,
    this.isBuiltIn = false,
  });

  factory MusicPlaylist.fromJson(Map<String, dynamic> json) {
    return MusicPlaylist(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      trackIds: List<String>.from(json['trackIds'] as List),
      category: json['category'] != null
          ? MusicCategory.values.firstWhere(
              (e) => e.name == json['category'],
              orElse: () => MusicCategory.custom,
            )
          : null,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      isBuiltIn: json['isBuiltIn'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'trackIds': trackIds,
      'category': category?.name,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isBuiltIn': isBuiltIn,
    };
  }

  MusicPlaylist copyWith({
    String? id,
    String? name,
    Object? description = _musicValueUnset,
    List<String>? trackIds,
    Object? category = _musicValueUnset,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isBuiltIn,
  }) {
    return MusicPlaylist(
      id: id ?? this.id,
      name: name ?? this.name,
      description: identical(description, _musicValueUnset)
          ? this.description
          : description as String?,
      trackIds: trackIds ?? this.trackIds,
      category: identical(category, _musicValueUnset)
          ? this.category
          : category as MusicCategory?,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MusicPlaylist && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Player state for music playback
enum PlayerState { stopped, playing, paused, loading, error }

/// Playback mode for music player
enum PlaybackMode {
  normal('Normal', 'Play tracks in order'),
  repeat('Repeat', 'Repeat current track'),
  repeatAll('Repeat All', 'Repeat entire playlist'),
  shuffle('Shuffle', 'Play tracks in random order');

  const PlaybackMode(this.displayName, this.description);

  final String displayName;
  final String description;
}
