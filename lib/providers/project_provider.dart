import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/project_model.dart';

class ProjectProvider extends ChangeNotifier {
  // --- DATABASE BOX ---
  // Make sure this matches the name in main.dart (projects_v2)
  final Box<Project> _projectBox = Hive.box<Project>('projects_v2');

  // --- CLIPBOARD MEMORY ---
  Note? _clipboardNote;

  // --- GETTERS ---
  List<Project> get projects {
    return _projectBox.values
        .where((project) => !project.isDeleted)
        .toList()
        .reversed
        .toList();
  }

  List<Project> get deletedProjects {
    return _projectBox.values.where((project) => project.isDeleted).toList();
  }

  // ==========================================
  //              PROJECT ACTIONS
  // ==========================================

  Future<void> addProject(String title, int colorValue) async {
    final newProject = Project(
      id: const Uuid().v4(),
      title: title,
      colorValue: colorValue,
      createdDate: DateTime.now(),
      status: 'active',
      isDeleted: false,
    );
    await _projectBox.add(newProject);
    notifyListeners();
  }

  Future<void> deleteProject(Project project) async {
    project.isDeleted = true;
    await project.save();
    notifyListeners();
  }

  Future<void> restoreProject(Project project) async {
    project.isDeleted = false;
    await project.save();
    notifyListeners();
  }

  Future<void> permanentlyDelete(Project project) async {
    await project.delete();
    notifyListeners();
  }

  Future<void> updateStatus(Project project, String newStatus) async {
    project.status = newStatus;
    await project.save();
    notifyListeners();
  }

  Future<void> updateProjectImage(Project project, String path) async {
    project.imagePath = path;
    await project.save();
    notifyListeners();
  }

  Future<void> updateProjectColor(Project project, int colorValue) async {
    project.colorValue = colorValue;
    project.imagePath = null;
    await project.save();
    notifyListeners();
  }

  // ==========================================
  //         NOTE / MY SPACE ACTIONS
  // ==========================================

  // 1. Add a New Note (Fixed Crash)
  Future<void> addNote(Project project, Note note) async {
    // Create a modifiable copy of the list to prevent crashes
    List<Note> newNotes = List.from(project.notes);
    newNotes.add(note);
    project.notes = newNotes;

    await project.save();
    notifyListeners();
  }

  // 2. Delete a Note
  Future<void> deleteNote(Project project, Note note) async {
    List<Note> newNotes = List.from(project.notes);
    newNotes.remove(note);
    project.notes = newNotes;

    await project.save();
    notifyListeners();
  }

  // 3. Star/Unstar
  Future<void> toggleNoteStar(Project project, Note note) async {
    note.isStarred = !note.isStarred;
    await project.save();
    notifyListeners();
  }

  // 4. Note Color
  Future<void> updateNoteColor(Project project, Note note, int color) async {
    note.colorValue = color;
    await project.save();
    notifyListeners();
  }

  // 5. Note Title
  Future<void> updateNoteTitle(Project project, Note note, String title) async {
    note.title = title;
    await project.save();
    notifyListeners();
  }

  // ==========================================
  //           BLOCK ACTIONS (The Fix)
  // ==========================================

  // 6. Add a Block (Text/Image/Audio)
  Future<void> addBlockToNote(
    Project project,
    Note note,
    NoteBlock block,
  ) async {
    // Create a modifiable copy of the blocks list
    List<NoteBlock> newBlocks = List.from(note.blocks);
    newBlocks.add(block);
    note.blocks = newBlocks;

    await project.save();
    notifyListeners();
  }

  // 7. Delete a Block
  Future<void> deleteBlock(Project project, Note note, NoteBlock block) async {
    List<NoteBlock> newBlocks = List.from(note.blocks);
    newBlocks.remove(block);
    note.blocks = newBlocks;

    await project.save();
    notifyListeners();
  }

  // ==========================================
  //           CLIPBOARD LOGIC
  // ==========================================

  void copyNoteToClipboard(Note note) {
    _clipboardNote = note;
    notifyListeners();
  }

  Future<void> pasteNoteFromClipboard(Project project) async {
    if (_clipboardNote == null) return;

    // Deep copy logic to create a true duplicate
    List<NoteBlock> newBlocks = [];
    for (var b in _clipboardNote!.blocks) {
      newBlocks.add(
        NoteBlock(
          id: const Uuid().v4(),
          type: b.type,
          content: b.content,
          style: Map.from(b.style),
        ),
      );
    }

    String baseName = _clipboardNote!.title;
    String newName = baseName;
    int counter = 1;

    while (project.notes.any((n) => n.title == newName)) {
      newName = "$baseName ($counter)";
      counter++;
    }

    final newNote = Note(
      title: newName,
      timestamp: DateTime.now(),
      colorValue: _clipboardNote!.colorValue,
      isStarred: _clipboardNote!.isStarred,
      blocks: newBlocks,
    );

    addNote(project, newNote);
  }
}
