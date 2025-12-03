import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/project_model.dart';
import '../providers/project_provider.dart';
import 'note_editor_screen.dart';

class MySpaceScreen extends StatefulWidget {
  final Project project;
  const MySpaceScreen({super.key, required this.project});

  @override
  State<MySpaceScreen> createState() => _MySpaceScreenState();
}

class _MySpaceScreenState extends State<MySpaceScreen> {
  final List<String> _funnyQuotes = [
    "Make a Geography",
    "Later, do it",
    "You can see me",
    "Think Something",
    "Nothing Inside",
    "Ultimate Eating Machine",
    "Stay There",
    "There is one Substitute",
    "An ice for Every Achievement",
    "Don’t Be There",
  ];

  String _currentQuote = "Make a Geography";

  @override
  void initState() {
    super.initState();
    _currentQuote = _funnyQuotes[Random().nextInt(_funnyQuotes.length)];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,

      // 1. Header
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "My Space",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
      ),

      // 2. FAB with Quote
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.white,
        onPressed: () => _createNewEntry(context),
        icon: const Icon(Icons.add, color: Colors.black),
        label: Text(
          _currentQuote,
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      // 3. Body
      body: GestureDetector(
        onLongPress: () => _showPasteMenu(context),
        behavior: HitTestBehavior.translucent,
        child: Consumer<ProjectProvider>(
          builder: (context, provider, child) {
            List<Note> sortedNotes = List.from(widget.project.notes);

            // Sort: Starred first, then Newest
            sortedNotes.sort((a, b) {
              if (a.isStarred && !b.isStarred) return -1;
              if (!a.isStarred && b.isStarred) return 1;
              return b.timestamp.compareTo(a.timestamp);
            });

            if (sortedNotes.isEmpty) {
              return Center(
                child: Text(
                  "Nothing Inside\n(Long press to Paste)",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 16,
                  ),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.only(bottom: 100, top: 10),
              itemCount: sortedNotes.length,
              itemBuilder: (context, index) {
                return _buildMySpaceTile(
                  context,
                  sortedNotes[index],
                  index + 1,
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildMySpaceTile(BuildContext context, Note note, int index) {
    // Handle Color
    Color tileColor = Color(note.colorValue);
    if (note.colorValue == 0xFFFFFFFF || note.colorValue == 0) {
      tileColor = Colors.white.withOpacity(0.9);
    }

    // --- NEW LOGIC: Generate Preview from Blocks ---
    String previewText = "Empty Note";
    if (note.blocks.isNotEmpty) {
      // Look for the first text block
      try {
        final textBlock = note.blocks.firstWhere((b) => b.type == 'text');
        previewText = textBlock.content;
        if (previewText.isEmpty) previewText = "No text content";
      } catch (e) {
        // If no text block found, check for attachments
        final firstBlock = note.blocks.first;
        if (firstBlock.type == 'image') {
          previewText = "📷 [Image Attached]";
        } else if (firstBlock.type == 'audio')
          previewText = "🎤 [Audio Recording]";
        else if (firstBlock.type == 'file')
          previewText = "📎 [File Attached]";
      }
    }
    // ----------------------------------------------

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                NoteEditorScreen(project: widget.project, note: note),
          ),
        );
      },
      onLongPress: () => _showItemMenu(context, note),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 6),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: tileColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
        ),
        child: Row(
          children: [
            Text(
              "$index.",
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.black87,
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    note.title.isEmpty ? "Untitled Entry" : note.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    "${DateFormat("MMM dd • hh:mm a").format(note.timestamp)} • $previewText",
                    style: TextStyle(
                      color: Colors.black.withOpacity(0.6),
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (note.isStarred)
              const Icon(Icons.star, color: Colors.orange, size: 24),
          ],
        ),
      ),
    );
  }

  // --- MENUS ---

  void _showItemMenu(BuildContext context, Note note) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.copy),
            title: const Text('Copy'),
            onTap: () {
              Provider.of<ProjectProvider>(
                context,
                listen: false,
              ).copyNoteToClipboard(note);
              Navigator.pop(ctx);
            },
          ),
          ListTile(
            leading: const Icon(Icons.color_lens),
            title: const Text('Set Color'),
            onTap: () {
              Navigator.pop(ctx);
              _showColorMenu(context, note);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: const Text('Delete'),
            onTap: () {
              Navigator.pop(ctx);
              _showFunnyDelete(context, note);
            },
          ),
        ],
      ),
    );
  }

  void _showColorMenu(BuildContext context, Note note) {
    final provider = Provider.of<ProjectProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text("Choose Color"),
        children: [
          _colorOption(
            ctx,
            provider,
            note,
            const Color(0xFFDCEDC8),
            "Light Green",
          ),
          _colorOption(
            ctx,
            provider,
            note,
            const Color(0xFFFFF9C4),
            "Light Yellow",
          ),
          _colorOption(
            ctx,
            provider,
            note,
            const Color(0xFFFFCDD2),
            "Light Red",
          ),
          _colorOption(ctx, provider, note, const Color(0xFFFFFFFF), "White"),
        ],
      ),
    );
  }

  Widget _colorOption(
    BuildContext ctx,
    ProjectProvider prov,
    Note note,
    Color color,
    String name,
  ) {
    return SimpleDialogOption(
      onPressed: () {
        prov.updateNoteColor(widget.project, note, color.value);
        Navigator.pop(ctx);
      },
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey),
            ),
          ),
          const SizedBox(width: 10),
          Text(name),
        ],
      ),
    );
  }

  void _showPasteMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.paste),
            title: const Text('Paste'),
            onTap: () {
              Provider.of<ProjectProvider>(
                context,
                listen: false,
              ).pasteNoteFromClipboard(widget.project);
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  void _showFunnyDelete(BuildContext context, Note note) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Entry?"),
        content: const Text("Are you sure to make your effort go to heaven?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Keep it"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Provider.of<ProjectProvider>(
                context,
                listen: false,
              ).deleteNote(widget.project, note);
              Navigator.pop(ctx);
            },
            child: const Text("RIP", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _createNewEntry(BuildContext context) {
    // Initialize with EMPTY BLOCKS list
    final newNote = Note(
      title: "New Entry",
      timestamp: DateTime.now(),
      blocks: [],
    );

    Provider.of<ProjectProvider>(
      context,
      listen: false,
    ).addNote(widget.project, newNote);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            NoteEditorScreen(project: widget.project, note: newNote),
      ),
    );
  }
}
