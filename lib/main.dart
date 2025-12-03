import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'providers/project_provider.dart';
import 'models/project_model.dart';
import 'screens/home_screen.dart';

void main() async {
  // 1. Initialize the Flutter Engine
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Initialize the Database (Hive)
  await Hive.initFlutter();

  // 3. Register the "Blueprints"
  Hive.registerAdapter(ProjectAdapter());
  Hive.registerAdapter(NoteAdapter());

  // --- THIS IS THE NEW LINE YOU NEEDED ---
  Hive.registerAdapter(NoteBlockAdapter());
  // --------------------------------------

  // 4. Open the "Boxes" (The storage units)
  await Hive.openBox<Project>('projects_v2');
  await Hive.openBox('settings');

  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => ProjectProvider())],
      child: const HudyApp(),
    ),
  );
}

class HudyApp extends StatelessWidget {
  const HudyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hudy Research Recorder',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        scaffoldBackgroundColor: Colors.transparent, // Transparent pages
        fontFamily: 'Roboto',
      ),
      // The "builder" allows us to put the image BEHIND the entire app
      builder: (context, child) {
        return Stack(
          children: [
            // 1. The Background Image (Always stays put)
            Positioned.fill(
              child: Image.asset(
                "assets/images/background.jpg",
                fit: BoxFit.cover,
              ),
            ),
            // 2. The App Pages
            child!,
          ],
        );
      },
      home: const LoadingScreen(),
    );
  }
}

// --- The Loading Screen ---
class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  @override
  void initState() {
    super.initState();
    // Wait 3 seconds, then go to the Home Screen
    Future.delayed(const Duration(seconds: 3), () {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // The Logo
            const Icon(Icons.science_outlined, size: 80, color: Colors.blue),
            const SizedBox(height: 20),
            const Text(
              "HUDY",
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                letterSpacing: 3.0,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              "Research Recorder",
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 50),
            const CircularProgressIndicator(color: Colors.blue),
          ],
        ),
      ),
    );
  }
}
