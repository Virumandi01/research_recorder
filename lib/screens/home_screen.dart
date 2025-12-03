import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'project_detail_screen.dart';
import '../providers/project_provider.dart';
import '../widgets/project_tile.dart'; // Imports kAppColors automatically

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ProjectProvider>(
      builder: (context, provider, child) {
        final projects = provider.projects;

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            children: [
              // 1. The Grid Content
              Padding(
                padding: const EdgeInsets.only(top: 85, left: 15, right: 15),
                child: projects.isEmpty
                    ? const Center(
                        child: Text(
                          "No Research Yet.\nStart by clicking +",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white, fontSize: 18),
                        ),
                      )
                    : GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 200, // Max width of a tile
                              childAspectRatio:
                                  0.85, // Slightly taller than wide
                              crossAxisSpacing: 15,
                              mainAxisSpacing: 15,
                            ),
                        itemCount: projects.length,
                        itemBuilder: (context, index) {
                          return ProjectTile(
                            project: projects[index],
                            onTap: () {
                              Navigator.push(
                                    context,
                                    PageRouteBuilder(
                                      opaque: true, // <--- THIS IS THE KEY FIX
                                      pageBuilder: (_, __, ___) => MySpaceScreen(project: projects[index]),
                                      transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                        return FadeTransition(
                                          opacity: animation,
                                          child: child,
                                        );
                                      },
                                      transitionDuration: const Duration(milliseconds: 300),
                                    ),
                                  );
                              // Placeholder for next step (Opening the Project)
                            },
                          );
                        },
                      ),
              ),

              // 2. The Compact Glass Header
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 15.0, sigmaY: 15.0),
                    child: Container(
                      height: 75,
                      padding: const EdgeInsets.fromLTRB(20, 35, 20, 10),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.white.withOpacity(0.1),
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Left: HUDY
                          Row(
                            children: [
                              const Text(
                                "HUDY",
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () {},
                                child: const Icon(
                                  Icons.keyboard_arrow_down,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                          // Right: Research Recorder
                          const Text(
                            "Research Recorder",
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // 3. Floating Action Button
          floatingActionButton: FloatingActionButton(
            backgroundColor: Colors.blueAccent,
            onPressed: () => _showAddProjectDialog(context),
            child: const Icon(Icons.add, color: Colors.white),
          ),
        );
      },
    );
  }

  // --- Helper Function ---
  // --- FAIL-SAFE DIALOG (Fixed Colors) ---
  void _showAddProjectDialog(BuildContext context) {
    final titleController = TextEditingController();
    Color selectedColor = Colors.blue; // Default

    // The only 4 allowed colors
    final List<Color> colors = [
      Colors.red, 
      Colors.blue, 
      Colors.green, 
      Colors.white
    ];

    showDialog(
      context: context,
      builder: (ctx) {
        // StatefulBuilder allows the dialog to update when you pick a color
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              title: const Text("🚀 New Experiment"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: titleController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: "Topic Name",    // Below this line if needed add a hintText:
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text("Pick a Color:", style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    
                    // NEW: Simple Row of 4 Colors
                    Wrap(
                      spacing: 15, 
                      children: colors.map((color) {
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              selectedColor = color;
                            });
                          },
                          child: Container(
                            width: 45,
                            height: 45,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                // Add border if selected OR if the color is white (visibility)
                                color: selectedColor == color ? Colors.black : Colors.grey.shade300, 
                                width: selectedColor == color ? 3 : 1
                              ),
                            ),
                            child: selectedColor == color 
                              // Checkmark logic (Black check on white bg, White check on others)
                              ? Icon(Icons.check, color: color == Colors.white ? Colors.black : Colors.white) 
                              : null,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                  onPressed: () {
                    if (titleController.text.isNotEmpty) {
                      Provider.of<ProjectProvider>(context, listen: false)
                          .addProject(titleController.text, selectedColor.value);
                      Navigator.pop(ctx);
                    }
                  },
                  child: const Text("Create", style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
