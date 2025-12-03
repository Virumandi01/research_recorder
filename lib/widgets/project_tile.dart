import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:image_picker/image_picker.dart';
import '../models/project_model.dart';
import '../providers/project_provider.dart';

// --- SHARED COLOR LIST (So Create and Edit screens match) ---
const List<Color> kAppColors = [
  Color(0xFF2196F3), // Blue
  Color(0xFFF44336), // Red
  Color(0xFF4CAF50), // Green
  Color(0xFFFF9800), // Orange
  Color(0xFF9C27B0), // Purple
  Color(0xFF009688), // Teal
  Color(0xFFE91E63), // Pink
  Color(0xFF3F51B5), // Indigo
  Color(0xFF795548), // Brown
  Color(0xFF607D8B), // Blue Grey
  Color(0xFFFFEB3B), // Yellow
  Color(0xFF00BCD4), // Cyan
  Color(0xFF8BC34A), // Light Green
  Color(0xFF673AB7), // Deep Purple
  Color(0xFF333333), // Dark Grey
];

class ProjectTile extends StatelessWidget {
  final Project project;
  final VoidCallback onTap;

  const ProjectTile({super.key, required this.project, required this.onTap});

  // Helper: Calculate text contrast
  Color getTextColor(Color backgroundColor) {
    if (project.imagePath != null) {
      return Colors.white; // Always white if image is set
    }
    return backgroundColor.computeLuminance() > 0.5
        ? Colors.black
        : Colors.white;
  }

  Color getStatusColor(String status) {
    switch (status) {
      case 'done':
        return const Color(0xFF00E676); // Green Accent
      case 'alive':
        return const Color(0xFFFFEA00); // Yellow Accent
      case 'dead':
        return const Color(0xFFFF1744); // Red Accent
      default:
        return Colors.white;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = Color(project.colorValue);
    final textColor = getTextColor(bgColor);
    final hasImage = project.imagePath != null && project.imagePath!.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      // Long Press to Merge (Visual indication for now)
      onLongPress: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("🚧 Merging Folders coming soon!")),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: hasImage ? null : bgColor,
          borderRadius: BorderRadius.circular(
            12,
          ), // Tighter rounding like Game Pass
          image: hasImage
              ? DecorationImage(
                  image: FileImage(File(project.imagePath!)),
                  fit: BoxFit.cover,
                  // FIX 2: Reduced opacity to 0.2 so image is clearer
                  colorFilter: ColorFilter.mode(
                    Colors.black.withOpacity(0.2),
                    BlendMode.darken,
                  ),
                )
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 6,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            // 1. Status Dot (Top Left)
            Positioned(
              top: 10,
              left: 10,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: getStatusColor(project.status),
                  border: Border.all(color: Colors.white, width: 1.5),
                  boxShadow: const [
                    BoxShadow(blurRadius: 5, color: Colors.black26),
                  ],
                ),
              ),
            ),

            // 2. Three Dots Menu (Top Right)
            Positioned(
              top: 0,
              right: 0,
              child: PopupMenuButton<String>(
                icon: Icon(Icons.more_horiz, color: textColor),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onSelected: (value) => _handleMenuOption(context, value),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'status',
                    child: Text("📊 Current Stage"),
                  ),
                  const PopupMenuItem(
                    value: 'color',
                    child: Text("🎨 Change Color"),
                  ),
                  const PopupMenuItem(
                    value: 'image',
                    child: Text("🖼️ Set Cover Image"),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text("💀 Delete (RIP)"),
                  ),
                ],
              ),
            ),

            // 3. Text Content (Bottom)
            Positioned(
              bottom: 12,
              left: 12,
              right: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    project.title,
                    style: TextStyle(
                      fontSize: 16, // Smaller, professional font
                      fontWeight: FontWeight.bold,
                      color: textColor,
                      shadows: hasImage
                          ? [const Shadow(blurRadius: 4, color: Colors.black)]
                          : [],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Created: ${project.createdDate.day}/${project.createdDate.month}",
                    style: TextStyle(
                      fontSize: 10,
                      color: textColor.withOpacity(0.8),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleMenuOption(BuildContext context, String value) async {
    final provider = Provider.of<ProjectProvider>(context, listen: false);

    if (value == 'delete') {
      _showFunnyDeleteDialog(context, provider);
    } else if (value == 'color') {
      _showColorPicker(context, provider);
    } else if (value == 'status') {
      _showStatusDialog(context, provider);
    } else if (value == 'image') {
      _pickImage(context, provider);
    }
  }

  // --- Logic Functions ---

  Future<void> _pickImage(
    BuildContext context,
    ProjectProvider provider,
  ) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      provider.updateProjectImage(project, image.path);
    }
  }

  void _showFunnyDeleteDialog(BuildContext context, ProjectProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text("💀 Are you sure?"),
        content: const Text(
          "Are you sure you want to send your effort to heaven? 🪦",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("🚫 No, Save it!"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              provider.deleteProject(project);
              Navigator.pop(ctx);
            },
            child: const Text("⚰️ Yes, RIP"),
          ),
        ],
      ),
    );
  }

  void _showColorPicker(BuildContext context, ProjectProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("🎨 Pick a Color"),
        content: SingleChildScrollView(
          child: BlockPicker(
            pickerColor: Color(project.colorValue),
            availableColors:
                kAppColors, // FIX 3: Uses the shared consistent list
            onColorChanged: (color) {
              // FIX 4: Actually calls the database update now!
              provider.updateProjectColor(project, color.value);
              Navigator.pop(ctx);
            },
          ),
        ),
      ),
    );
  }

  void _showStatusDialog(BuildContext context, ProjectProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text("📊 Current Stage"),
        children: [
          SimpleDialogOption(
            onPressed: () {
              provider.updateStatus(project, 'alive');
              Navigator.pop(ctx);
            },
            child: const Text("🟡 Still Alive"),
          ),
          SimpleDialogOption(
            onPressed: () {
              provider.updateStatus(project, 'done');
              Navigator.pop(ctx);
            },
            child: const Text("🟢 Done"),
          ),
          SimpleDialogOption(
            onPressed: () {
              provider.updateStatus(project, 'dead');
              Navigator.pop(ctx);
            },
            child: const Text("🔴 Dead"),
          ),
        ],
      ),
    );
  }
}
