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

  const NoteEditorScreen({super.key, required this.project, required this.note});

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

  // Track where the user is typing to insert images correctly
  int _focusedIndex = -1;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note.title);
    
    // Audio Player Listener
    _audioPlayer.onPlayerComplete.listen((event) {
      if (mounted) {
        setState(() {
          _playingBlockId = null;
        });
      }
    });

    // Start with one empty text line if new
    if (widget.note.blocks.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _addNewTextBlock();
      });
    }
  }

  @override
  void dispose() {
    // Auto-save Title on exit
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
    Provider.of<ProjectProvider>(context, listen: false).updateNoteTitle(
      widget.project, widget.note, _titleController.text
    );
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
          onPressed: () { _saveTitle(); Navigator.pop(context); },
        ),
        title: TextField(
          controller: _titleController,
          decoration: const InputDecoration(hintText: "Title", border: InputBorder.none),
          style: const TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        actions: [
          // 1. SAVE BUTTON
          IconButton(
            icon: const Icon(Icons.save, color: Colors.blue),
            onPressed: () {
              _saveTitle();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Saved!"), duration: Duration(milliseconds: 500)));
            },
          ),
          
          // 2. STAR BUTTON
          IconButton(
            icon: Icon(widget.note.isStarred ? Icons.star : Icons.star_border, color: Colors.orange),
            onPressed: () {
               setState(() {
                 Provider.of<ProjectProvider>(context, listen: false).toggleNoteStar(widget.project, widget.note);
               });
            },
          ),
        ],
      ),

      // --- BODY ---
      body: Column(
        children: [
          Expanded(
            child: Consumer<ProjectProvider>(
              builder: (context, provider, child) {
                return GestureDetector(
                  // Tap empty space to add text at bottom
                  onTap: () => _addNewTextBlock(),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
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

          // --- CLEAN BOTTOM BAR ---
          _buildBottomBar(),
        ],
      ),
    );
  }

  // ==========================================
  //              BLOCK RENDERER
  // ==========================================

  Widget _buildBlockItem(NoteBlock block, int index) {
    if (block.type == 'text') {
      return Padding(
        padding: EdgeInsets.zero, 
        child: _renderTextBlock(block, index),
      );
    }
    // Attachments (Long Press to Delete)
    return GestureDetector(
      onLongPress: () => _showBlockOptions(block),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: _renderAttachmentBlock(block),
      ),
    );
  }

  Widget _renderTextBlock(NoteBlock block, int index) {
    var txtCtrl = TextEditingController(text: block.content);
    txtCtrl.selection = TextSelection.fromPosition(TextPosition(offset: block.content.length));
    
    return Focus(
      onFocusChange: (hasFocus) {
        if (hasFocus) {
          setState(() {
            _focusedIndex = index;
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
        // STANDARD STYLE (No formatting options)
        style: const TextStyle(
          fontSize: 16.0, 
          color: Colors.black,
          height: 1.5,
        ),
        decoration: const InputDecoration(
          border: InputBorder.none, 
          isDense: true,
          contentPadding: EdgeInsets.zero,
          hintText: "", 
        ),
      ),
    );
  }

  // --- ATTACHMENT RENDERING ---
  Widget _renderAttachmentBlock(NoteBlock block) {
    return Align(
      alignment: Alignment.centerLeft, 
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8, 
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[100], 
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: _buildAttachmentContent(block),
      ),
    );
  }

  Widget _buildAttachmentContent(NoteBlock block) {
    if (block.type == 'image') {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(File(block.content), fit: BoxFit.cover),
      );
    }
    
    if (block.type == 'audio') {
      bool isPlaying = _playingBlockId == block.id;
      return Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.blueAccent,
            child: IconButton(
              icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white),
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
          ),
          const SizedBox(width: 10),
          const Text("Voice Recording", style: TextStyle(fontWeight: FontWeight.bold)),
        ],
      );
    }

    // File
    return Row(
      children: [
        const Icon(Icons.insert_drive_file, color: Colors.redAccent, size: 30),
        const SizedBox(width: 10),
        Expanded(child: Text(block.content.split('/').last, overflow: TextOverflow.ellipsis)),
      ],
    );
  }

  // ==========================================
  //              BOTTOM TOOLBAR
  // ==========================================

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 5, offset: const Offset(0, -2))]
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 1. ATTACHMENT BUTTON
          IconButton(
            icon: const Icon(Icons.add_circle_outline, size: 32, color: Colors.black54),
            onPressed: _showAttachmentOptions,
          ),
          
          // 2. MIC BUTTON (Tap to Start / Tap to Stop)
          GestureDetector(
            onTap: _toggleRecording,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              height: 50,
              width: 50,
              decoration: BoxDecoration(
                color: _isRecording ? Colors.redAccent : Colors.blueAccent,
                shape: BoxShape.circle,
                boxShadow: _isRecording 
                  ? [const BoxShadow(color: Colors.redAccent, blurRadius: 8)] 
                  : [const BoxShadow(color: Colors.blueAccent, blurRadius: 5)],
              ),
              child: Icon(
                _isRecording ? Icons.stop : Icons.mic, 
                color: Colors.white, 
                size: 26
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

  void _addNewTextBlock() {
    final block = NoteBlock(
      id: const Uuid().v4(), type: 'text', content: "",
      // Default standard style
      style: {'fontSize': 16.0, 'color': Colors.black.value, 'isBold': false},
    );
    // Insert at end
    Provider.of<ProjectProvider>(context, listen: false).addBlockToNote(widget.project, widget.note, block);
  }

  void _addAttachmentBlock(String type, String path) {
    final block = NoteBlock(id: const Uuid().v4(), type: type, content: path);
    
    // If we are focused on a text block, insert after it
    int insertIndex = (_focusedIndex != -1 && _focusedIndex < widget.note.blocks.length)
        ? _focusedIndex + 1 
        : widget.note.blocks.length;
    
    Provider.of<ProjectProvider>(context, listen: false).insertBlock(widget.project, widget.note, insertIndex, block);
    
    // Add new text line immediately after attachment
    final textBlock = NoteBlock(
      id: const Uuid().v4(), type: 'text', content: "",
      style: {'fontSize': 16.0, 'color': Colors.black.value, 'isBold': false},
    );
    Provider.of<ProjectProvider>(context, listen: false).insertBlock(widget.project, widget.note, insertIndex + 1, textBlock);
  }

  // --- RECORDING ---
  Future<void> _toggleRecording() async {
    if (_isRecording) {
      // STOP
      // Fix: Update UI immediately to prevent double-tap
      setState(() => _isRecording = false);
      
      final path = await _audioRecorder.stop();
      if (path != null) _addAttachmentBlock('audio', path);
    } else {
      // START
      if (await _audioRecorder.hasPermission()) {
        final directory = await getApplicationDocumentsDirectory();
        final path = '${directory.path}/rec_${DateTime.now().millisecondsSinceEpoch}.m4a';
        
        // FIX: AAC for clear audio
        const config = RecordConfig(encoder: AudioEncoder.aacLc);
        await _audioRecorder.start(config, path: path);
        setState(() => _isRecording = true);
      }
    }
  }

  // --- FILES ---
  Future<void> _showAttachmentOptions() async {
    showModalBottomSheet(context: context, builder: (ctx) => Wrap(children: [
      ListTile(leading: const Icon(Icons.image), title: const Text('Image/Video'), onTap: () { Navigator.pop(ctx); _pickImage(); }),
      ListTile(leading: const Icon(Icons.insert_drive_file), title: const Text('File'), onTap: () { Navigator.pop(ctx); _pickFile(); }),
    ]));
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) _addAttachmentBlock('image', image.path);
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.single.path != null) _addAttachmentBlock('file', result.files.single.path!);
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
              Provider.of<ProjectProvider>(context, listen: false).deleteBlock(widget.project, widget.note, block);
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }
}