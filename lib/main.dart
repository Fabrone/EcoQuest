import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'package:google_fonts/google_fonts.dart';
import 'game/eco_quest_game.dart';

void main() {
  runApp(const EcoQuestApp());
}

class EcoQuestApp extends StatelessWidget {
  const EcoQuestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.green),
      home: const GameScreen(),
    );
  }
}

class GameScreen extends StatelessWidget {
  const GameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // --- LEFT QUARTER: Animated Garden Environment ---
          Expanded(
            flex: 1,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFE0F7FA), Color(0xFF81C784)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: const AnimatedGardenPanel(),
            ),
          ),
          // --- RIGHT 3/QUARTERS: The Flame Game Grid ---
          Expanded(
            flex: 3,
            child: GameWidget(
              game: EcoQuestGame(),
              backgroundBuilder: (context) => Container(
                color: const Color(0xFF3E2723), // Dark Earthy background for game area
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// A simple Flutter widget to simulate the "Lively Essence"
class AnimatedGardenPanel extends StatefulWidget {
  const AnimatedGardenPanel({super.key});

  @override
  State<AnimatedGardenPanel> createState() => _AnimatedGardenPanelState();
}

class _AnimatedGardenPanelState extends State<AnimatedGardenPanel>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // Infinite bobbing animation for a butterfly/element
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "EcoQuest",
          style: GoogleFonts.vt323(
            fontSize: 40,
            fontWeight: FontWeight.bold,
            color: Colors.green[900],
          ),
        ),
        const SizedBox(height: 20),
        // Animated Butterfly Placeholder
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, _controller.value * 20),
              child: const Icon(Icons.flutter_dash, size: 80, color: Colors.pinkAccent),
            );
          },
        ),
        const SizedBox(height: 20),
        const Text("Level 1", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const Padding(
          padding: EdgeInsets.all(8.0),
          child: Text(
            "Match 3 items to restore the land!",
            textAlign: TextAlign.center,
            style: TextStyle(fontStyle: FontStyle.italic),
          ),
        ),
      ],
    );
  }
}