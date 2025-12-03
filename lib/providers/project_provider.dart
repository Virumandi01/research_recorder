import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/project_model.dart';

class ProjectProvider extends ChangeNotifier {
  // --- DATABASE BOX ---
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
    return _projectBox.values
        .where((project) => project.isDeleted)
        .toList();
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
  //         NOTE ACTIONS
  // ==========================================

  Future<void> addNote(Project project, Note note) async {
    List<Note> newNotes = List.from(project.notes);
    newNotes.add(note);
    project.notes = newNotes;
    await project.save();
    notifyListeners();
  }

  Future<void> deleteNote(Project project, Note note) async {
    List<Note> newNotes = List.from(project.notes);
    newNotes.remove(note);
    project.notes = newNotes;
    await project.save();
    notifyListeners();
  }

  Future<void> toggleNoteStar(Project project, Note note) async {
    note.isStarred = !note.isStarred;
    await project.save();
    notifyListeners();
  }

  Future<void> updateNoteColor(Project project, Note note, int color) async {
    note.colorValue = color;
    await project.save();
    notifyListeners();
  }

  Future<void> updateNoteTitle(Project project, Note note, String title) async {
    note.title = title;
    await project.save();
    notifyListeners();
  }

  // ==========================================
  //           BLOCK ACTIONS (THE ENGINE)
  // ==========================================

  Future<void> addBlockToNote(Project project, Note note, NoteBlock block) async {
    List<NoteBlock> newBlocks = List.from(note.blocks);
    newBlocks.add(block);
    note.blocks = newBlocks;
    await project.save();
    notifyListeners();
  }

  // --- THIS IS THE CODE YOU ASKED FOR ---
  Future<void> insertBlock(Project project, Note note, int index, NoteBlock block) async {
    // Create a modifiable copy
    List<NoteBlock> newBlocks = List.from(note.blocks);
    
    // Check bounds to prevent crash
    if (index >= newBlocks.length) {
      newBlocks.add(block);
    } else {
      newBlocks.insert(index, block);
    }
    
    note.blocks = newBlocks;
    await project.save();
    notifyListeners();
  }
  // --------------------------------------

  Future<void> deleteBlock(Project project, Note note, NoteBlock block) async {
    List<NoteBlock> newBlocks = List.from(note.blocks);
    newBlocks.remove(block);
    note.blocks = newBlocks;
    await project.save();
    notifyListeners();
  }

  // Required for Text Customization (Bold/Color)
  Future<void> updateBlockStyle(Project project, NoteBlock block, Map<dynamic, dynamic> newStyle) async {
    block.style = newStyle;
    await project.save(); 
    notifyListeners();
  }

  // Required for splitting text in the middle
  Future<void> splitTextBlock(Project project, Note note, int index, String textBefore, String textAfter, Map<dynamic, dynamic> newStyle) async {
    List<NoteBlock> newBlocks = List.from(note.blocks);

    newBlocks[index].content = textBefore;
    
    final newStyledBlock = NoteBlock(
      id: const Uuid().v4(), 
      type: 'text', 
      content: "", 
      style: newStyle
    );

    final afterBlock = NoteBlock(
      id: const Uuid().v4(), 
      type: 'text', 
      content: textAfter, 
      style: Map.from(newBlocks[index].style)
    );

    if (textAfter.isNotEmpty) {
      newBlocks.insert(index + 1, afterBlock);
    }
    newBlocks.insert(index + 1, newStyledBlock);
    
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