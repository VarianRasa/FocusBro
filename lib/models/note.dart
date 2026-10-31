import 'base_model.dart';

class Note extends BaseModelWithTimestamps {
  final String id;
  final String title;
  final String content;
  final String category;
  final bool isFavorite;
  final bool isPinned;
  final List<String> tags;

  Note({
    required this.id,
    required this.title,
    required this.content,
    required this.category,
    this.isFavorite = false,
    this.isPinned = false,
    this.tags = const [],
    required DateTime createdAt,
    required DateTime updatedAt,
  }) : super(createdAt: createdAt, updatedAt: updatedAt);

  @override
  String get tableName => 'notes';

  @override
  String get primaryKey => 'id';

  @override
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'category': category,
      'is_favorite': isFavorite ? 1 : 0,
      'is_pinned': isPinned ? 1 : 0,
      'tags': tags.join(','), // Store tags as comma-separated string
      ...baseToMap(),
    };
  }

  factory Note.fromMap(Map<String, dynamic> map) {
    // Parse tags from comma-separated string
    final tagsString = map['tags'] as String? ?? '';
    final tags = tagsString.isEmpty
        ? <String>[]
        : tagsString
            .split(',')
            .map((tag) => tag.trim())
            .where((tag) => tag.isNotEmpty)
            .toList();

    return Note(
      id: map['id'],
      title: map['title'],
      content: map['content'],
      category: map['category'],
      isFavorite: map['is_favorite'] == 1,
      isPinned: map['is_pinned'] == 1,
      tags: tags,
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
    );
  }

  Note copyWith({
    String? id,
    String? title,
    String? content,
    String? category,
    bool? isFavorite,
    bool? isPinned,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Note(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      category: category ?? this.category,
      isFavorite: isFavorite ?? this.isFavorite,
      isPinned: isPinned ?? this.isPinned,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class NoteAttachment extends BaseModel {
  final int? id;
  final String noteId;
  final String filePath;
  final String fileName;
  final String? fileType;
  final int? fileSize;
  final DateTime createdAt;

  NoteAttachment({
    this.id,
    required this.noteId,
    required this.filePath,
    required this.fileName,
    this.fileType,
    this.fileSize,
    required this.createdAt,
  });

  @override
  String get tableName => 'note_attachments';

  @override
  Map<String, dynamic> toMap() {
    final map = {
      'note_id': noteId,
      'file_path': filePath,
      'file_name': fileName,
      'file_type': fileType,
      'file_size': fileSize,
      'created_at': createdAt.toIso8601String(),
    };

    if (id != null) {
      map['id'] = id;
    }

    return map;
  }

  factory NoteAttachment.fromMap(Map<String, dynamic> map) {
    return NoteAttachment(
      id: map['id'],
      noteId: map['note_id'],
      filePath: map['file_path'],
      fileName: map['file_name'],
      fileType: map['file_type'],
      fileSize: map['file_size'],
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  NoteAttachment copyWith({
    int? id,
    String? noteId,
    String? filePath,
    String? fileName,
    String? fileType,
    int? fileSize,
    DateTime? createdAt,
  }) {
    return NoteAttachment(
      id: id ?? this.id,
      noteId: noteId ?? this.noteId,
      filePath: filePath ?? this.filePath,
      fileName: fileName ?? this.fileName,
      fileType: fileType ?? this.fileType,
      fileSize: fileSize ?? this.fileSize,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class NoteTemplate {
  final String id;
  final String name;
  final String title;
  final String content;
  final String category;
  final String description;
  final List<String> tags;
  final bool isBuiltIn;
  final bool isFavorite;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? createdBy;

  NoteTemplate({
    required this.id,
    required this.name,
    required this.title,
    required this.content,
    required this.category,
    this.description = '',
    this.tags = const [],
    this.isBuiltIn = false,
    this.isFavorite = false,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy,
  });

  /// Create a copy with updated values
  NoteTemplate copyWith({
    String? id,
    String? name,
    String? title,
    String? content,
    String? category,
    String? description,
    List<String>? tags,
    bool? isBuiltIn,
    bool? isFavorite,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
  }) {
    return NoteTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      title: title ?? this.title,
      content: content ?? this.content,
      category: category ?? this.category,
      description: description ?? this.description,
      tags: tags ?? this.tags,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
      isFavorite: isFavorite ?? this.isFavorite,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'title': title,
      'content': content,
      'category': category,
      'description': description,
      'tags': tags,
      'isBuiltIn': isBuiltIn,
      'isFavorite': isFavorite,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'createdBy': createdBy,
    };
  }

  /// Create from JSON
  factory NoteTemplate.fromJson(Map<String, dynamic> json) {
    return NoteTemplate(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      category: json['category'] ?? 'Other',
      description: json['description'] ?? '',
      tags: List<String>.from(json['tags'] ?? []),
      isBuiltIn: json['isBuiltIn'] ?? false,
      isFavorite: json['isFavorite'] ?? false,
      createdAt:
          DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      updatedAt:
          DateTime.parse(json['updatedAt'] ?? DateTime.now().toIso8601String()),
      createdBy: json['createdBy'],
    );
  }

  Map<String, dynamic> toMap() {
    return toJson();
  }

  factory NoteTemplate.fromMap(Map<String, dynamic> map) {
    return NoteTemplate.fromJson(map);
  }

  /// Create template from existing note
  factory NoteTemplate.fromNote({
    required Note note,
    required String templateName,
    String? description,
    List<String>? tags,
  }) {
    final now = DateTime.now();
    return NoteTemplate(
      id: 'template_${now.millisecondsSinceEpoch}',
      name: templateName,
      title: note.title,
      content: note.content,
      category: note.category,
      description: description ?? 'Template created from note: ${note.title}',
      tags: tags ?? note.tags,
      isBuiltIn: false,
      isFavorite: false,
      createdAt: now,
      updatedAt: now,
      createdBy: 'user',
    );
  }

  /// Get formatted creation date
  String get formattedCreatedAt {
    return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
  }

  /// Get template type display
  String get typeDisplay {
    return isBuiltIn ? 'Built-in' : 'Custom';
  }

  /// Check if template can be edited
  bool get canEdit {
    return !isBuiltIn;
  }

  /// Check if template can be deleted
  bool get canDelete {
    return !isBuiltIn;
  }

  @override
  String toString() {
    return 'NoteTemplate(id: $id, name: $name, category: $category, isBuiltIn: $isBuiltIn)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NoteTemplate && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
