import 'package:hive/hive.dart';

part 'project_model.g.dart';

@HiveType(typeId: 0)
class Project extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  int colorValue;

  @HiveField(3)
  String status;

  @HiveField(4)
  bool isDeleted;

  @HiveField(5)
  DateTime createdDate;

  @HiveField(6)
  List<Note> notes;

  @HiveField(7)
  String? imagePath;

  Project({
    required this.id,
    required this.title,
    required this.colorValue,
    required this.createdDate,
    this.status = 'active',
    this.isDeleted = false,
    this.notes = const [],
    this.imagePath,
  });
}

@HiveType(typeId: 1)
class Note extends HiveObject {
  @HiveField(0)
  String title;

  @HiveField(1)
  DateTime timestamp;

  @HiveField(2)
  bool isStarred;

  @HiveField(3)
  int colorValue;

  @HiveField(4)
  List<NoteBlock> blocks; // The new structure

  Note({
    this.title = "Untitled Entry",
    required this.timestamp,
    this.isStarred = false,
    this.colorValue = 0xFFFFFFFF,
    List<NoteBlock>? blocks,
  }) : blocks = blocks ?? [];
}

@HiveType(typeId: 2)
class NoteBlock extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String type; // "text", "image", "audio", "file"

  @HiveField(2)
  String content; // Text or File Path

  @HiveField(3)
  Map<dynamic, dynamic> style; // Font size, color, etc.

  NoteBlock({
    required this.id,
    required this.type,
    required this.content,
    Map<dynamic, dynamic>? style,
  }) : style = style ?? {};
}
