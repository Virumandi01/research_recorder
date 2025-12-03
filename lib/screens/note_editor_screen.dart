import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import '../models/project_model.dart';
import '../providers/project_provider.dart';

class NoteEditorScreen extends StatefulWidget {
  final Project project;
  final Note note;

  const NoteEditorScreen({
    super.key,
    required this.project,
    required this.note,
  });

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  late TextEditingController _titleController;

  // Audio Tools
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isRecording = false;
  String? _playingBlockId;

  // TRACKING CURRENT STYLE (For the NEXT thing you type)
  double _nextFontSize = 16.0;
  Color _nextColor = Colors.black;
  bool _nextBold = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note.title);

    _audioPlayer.onPlayerComplete.listen((event) {
      setState(() {
        _playingBlockId = null;
      });
    });

    // If empty, start with one clean text block
    if (widget.note.blocks.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _addNewTextBlock();
      });
    }
  }

  @override
  void dispose() {
    if (_titleController.text != widget.note.title) {
      widget.note.title = _titleController.text;
      widget.note.save();
    }
    _titleController.dispose();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _saveTitle() {
    Provider.of<ProjectProvider>(
      context,
      listen: false,
    ).updateNoteTitle(widget.project, widget.note, _titleController.text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      // --- HEADER ---
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            _saveTitle();
            Navigator.pop(context);
          },
        ),
        title: TextField(
          controller: _titleController,
          decoration: const InputDecoration(
            hintText: "Title",
            border: InputBorder.none,
          ),
          style: const TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              _saveTitle();
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text("Saved!")));
            },
            icon: const Icon(Icons.save, color: Colors.blue),
            label: const Text(
              "Save",
              style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 10),
        ],
      ),

      // --- BODY (Continuous Document) ---
      body: Column(
        children: [
          Expanded(
            child: Consumer<ProjectProvider>(
              builder: (context, provider, child) {
                return GestureDetector(
                  onTap: () {
                    // Tapping empty space adds a new line at the end
                    _addNewTextBlock();
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    itemCount: widget.note.blocks.length,
                    itemBuilder: (context, index) {
                      final block = widget.note.blocks[index];
                      return _buildBlockItem(block, index);
                    },
                  ),
                );
              },
            ),
          ),

          // --- BOTTOM TASK BAR ---
          _buildBottomBar(),
        ],
      ),
    );
  }

  // ==========================================
  //              BLOCK RENDERING
  // ==========================================

  Widget _buildBlockItem(NoteBlock block, int index) {
    if (block.type == 'text') {
      return _renderTextBlock(block);
    }

    // Attachments
    return GestureDetector(
      onLongPress: () => _showBlockOptions(block),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0), // Minimal gap
        child: _renderAttachmentBlock(block),
      ),
    );
  }

  Widget _renderTextBlock(NoteBlock block) {
    var txtCtrl = TextEditingController(text: block.content);
    txtCtrl.selection = TextSelection.fromPosition(
      TextPosition(offset: block.content.length),
    );

    return Focus(
      onFocusChange: (hasFocus) {
        if (hasFocus) {
          // When user clicks a block, update the "Next Style" to match that block
          // so if they type, it continues in that style.
          setState(() {
            _nextFontSize = (block.style['fontSize'] ?? 16.0).toDouble();
            _nextColor = Color(block.style['color'] ?? Colors.black.value);
            _nextBold = block.style['isBold'] ?? false;
          });
        }
      },
      child: TextField(
        controller: txtCtrl,
        onChanged: (val) {
          block.content = val;
        },
        maxLines: null,
        keyboardType: TextInputType.multiline,
        // STYLE IS LOCKED TO THE BLOCK (Fixes the "Whole Paragraph Change" bug)
        style: TextStyle(
          fontSize: (block.style['fontSize'] ?? 16.0).toDouble(),
          color: Color(block.style['color'] ?? Colors.black.value),
          fontWeight: (block.style['isBold'] ?? false)
              ? FontWeight.bold
              : FontWeight.normal,
          height: 1.5, // Nice line spacing
        ),
        decoration: const InputDecoration(
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.zero, // No gaps
          hintText: "",
        ),
      ),
    );
  }

  Widget _renderAttachmentBlock(NoteBlock block) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.7,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: _buildAttachmentContent(block),
      ),
    );
  }

  Widget _buildAttachmentContent(NoteBlock block) {
    if (block.type == 'image') {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.file(File(block.content), fit: BoxFit.cover),
      );
    }

    if (block.type == 'audio') {
      bool isPlaying = _playingBlockId == block.id;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPlaying ? Icons.graphic_eq : Icons.mic,
            color: Colors.blueAccent,
            size: 24,
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              "Audio Note",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
          IconButton(
            icon: Icon(
              isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
              size: 35,
              color: Colors.blue,
            ),
            onPressed: () async {
              if (isPlaying) {
                await _audioPlayer.pause();
                setState(() => _playingBlockId = null);
              } else {
                await _audioPlayer.stop();
                await _audioPlayer.play(DeviceFileSource(block.content));
                setState(() => _playingBlockId = block.id);
              }
            },
          ),
        ],
      );
    }

    // File
    return Row(
      children: [
        const Icon(Icons.insert_drive_file, color: Colors.redAccent, size: 30),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            block.content.split('/').last,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // ==========================================
  //              BOTTOM BAR
  // ==========================================

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 5,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // BOLD (Toggle)
          IconButton(
            icon: Icon(
              Icons.format_bold,
              color: _nextBold ? Colors.blue : Colors.black,
            ),
            onPressed: _toggleBold, // Creates new block
          ),

          // SIZE (3 Options)
          IconButton(
            icon: const Icon(Icons.text_fields),
            onPressed: _showSimpleSizeDialog,
          ),

          // COLOR (4 Options)
          IconButton(
            icon: Icon(Icons.format_color_text, color: _nextColor),
            onPressed: _showSimpleColorDialog,
          ),

          Container(width: 1, height: 24, color: Colors.grey),

          // ATTACHMENT
          IconButton(
            icon: const Icon(Icons.attach_file),
            onPressed: _showAttachmentOptions,
          ),

          // MIC
          GestureDetector(
            onTap: _toggleRecording,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isRecording ? Colors.red : Colors.blueAccent,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isRecording ? Icons.stop : Icons.mic,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  //              LOGIC & ACTIONS
  // ==========================================

  // This function creates a NEW Text Block with the CURRENT settings
  void _addNewTextBlock() {
    final block = NoteBlock(
      id: const Uuid().v4(),
      type: 'text',
      content: "",
      style: {
        'fontSize': _nextFontSize,
        'color': _nextColor.value,
        'isBold': _nextBold,
      },
    );
    Provider.of<ProjectProvider>(
      context,
      listen: false,
    ).addBlockToNote(widget.project, widget.note, block);
  }

  void _addAttachmentBlock(String type, String path) {
    final block = NoteBlock(id: const Uuid().v4(), type: type, content: path);
    Provider.of<ProjectProvider>(
      context,
      listen: false,
    ).addBlockToNote(widget.project, widget.note, block);

    // IMPORTANT: Add a text block immediately after attachment so user can keep typing
    _addNewTextBlock();
  }

  // --- FORMATTING LOGIC (FIXED) ---
  // When you change style, we create a NEW block for the new style.
  // This prevents changing the old text!

  void _toggleBold() {
    setState(() => _nextBold = !_nextBold);
    _addNewTextBlock(); // Start new typing area with new bold setting
  }

  void _showSimpleSizeDialog() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Wrap(
        children: [
          ListTile(
            title: const Text("Small"),
            onTap: () {
              _applySize(12.0);
              Navigator.pop(ctx);
            },
          ),
          ListTile(
            title: const Text("Normal"),
            onTap: () {
              _applySize(16.0);
              Navigator.pop(ctx);
            },
          ),
          ListTile(
            title: const Text("Large"),
            onTap: () {
              _applySize(24.0);
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  void _applySize(double size) {
    setState(() => _nextFontSize = size);
    _addNewTextBlock();
  }

  void _showSimpleColorDialog() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _colorBtn(Colors.black, ctx),
            _colorBtn(Colors.red, ctx),
            _colorBtn(Colors.blue, ctx),
            _colorBtn(Colors.green, ctx),
          ],
        ),
      ),
    );
  }

  Widget _colorBtn(Color c, BuildContext ctx) {
    return GestureDetector(
      onTap: () {
        setState(() => _nextColor = c);
        Navigator.pop(ctx);
        _addNewTextBlock(); // Start new typing area with new color
      },
      child: CircleAvatar(backgroundColor: c, radius: 20),
    );
  }

  // --- ATTACHMENT LOGIC ---

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      final path = await _audioRecorder.stop();
      setState(() => _isRecording = false);
      if (path != null) _addAttachmentBlock('audio', path);
    } else {
      if (await _audioRecorder.hasPermission()) {
        final directory = await getApplicationDocumentsDirectory();
        final path =
            '${directory.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
        await _audioRecorder.start(const RecordConfig(), path: path);
        setState(() => _isRecording = true);
      }
    }
  }

  Future<void> _showAttachmentOptions() async {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.image),
            title: const Text('Image/Video'),
            onTap: () {
              Navigator.pop(ctx);
              _pickImage();
            },
          ),
          ListTile(
            leading: const Icon(Icons.insert_drive_file),
            title: const Text('File'),
            onTap: () {
              Navigator.pop(ctx);
              _pickFile();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) _addAttachmentBlock('image', image.path);
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.single.path != null) {
      _addAttachmentBlock('file', result.files.single.path!);
    }
  }

  void _showBlockOptions(NoteBlock block) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: const Text('Delete Attachment'),
            onTap: () {
              Provider.of<ProjectProvider>(
                context,
                listen: false,
              ).deleteBlock(widget.project, widget.note, block);
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }
}
