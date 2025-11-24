import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'package:google_fonts/google_fonts.dart';
import 'game/eco_quest_game.dart';

void main() {
  runApp(const EcoQuestApp());
}

// Global Score Notifier
final ValueNotifier<int> scoreNotifier = ValueNotifier<int>(0);

class EcoQuestApp extends StatelessWidget {
  const EcoQuestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.green,
        scaffoldBackgroundColor: const Color(0xFF2D1E17), // Dark earth background
      ),
      home: const GameScreen(),
    );
  }
}

class GameScreen extends StatelessWidget {
  const GameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // LayoutBuilder allows us to check constraints for responsiveness
      body: LayoutBuilder(
        builder: (context, constraints) {
          // If width is less than 600px, assume Mobile (Portrait/Small)
          bool isMobile = constraints.maxWidth < 600;

          if (isMobile) {
            // MOBILE LAYOUT: Column (Garden Top, Game Bottom)
            return Column(
              children: [
                const SizedBox(
                  height: 120, // Fixed height for header on mobile
                  child: AnimatedGardenPanel(isCompact: true),
                ),
                Expanded(
                  child: _buildGameWidget(),
                ),
              ],
            );
          } else {
            // DESKTOP/TABLET LAYOUT: Row (Garden Left, Game Right)
            return Row(
              children: [
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
                    child: const AnimatedGardenPanel(isCompact: false),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: _buildGameWidget(),
                ),
              ],
            );
          }
        },
      ),
    );
  }

  Widget _buildGameWidget() {
    return GameWidget(
      game: EcoQuestGame(),
      overlayBuilderMap: {
        'HUD': (BuildContext context, EcoQuestGame game) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(10.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Score Board
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      // FIXED: withOpacity -> withValues
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: ValueListenableBuilder<int>(
                      valueListenable: scoreNotifier,
                      builder: (context, value, child) {
                        return Text(
                          'Eco Points: $value',
                          style: GoogleFonts.vt323(
                            color: Colors.white,
                            fontSize: 24, // Slightly smaller for safety
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      },
                    ),
                  ),
                  // Hint Button
                  ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Hint: Look for patterns of 3!"),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                    icon: const Icon(Icons.lightbulb, color: Colors.yellow, size: 20),
                    label: const Text("HINT"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[800],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      },
    );
  }
}

class AnimatedGardenPanel extends StatelessWidget {
  final bool isCompact;
  const AnimatedGardenPanel({super.key, required this.isCompact});

  @override
  Widget build(BuildContext context) {
    // If compact (Mobile top bar), simplify the design
    if (isCompact) {
      return Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE0F7FA), Color(0xFF81C784)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.eco, size: 40, color: Colors.green),
            const SizedBox(width: 10),
            Text(
              "EcoQuest",
              style: GoogleFonts.lobster(fontSize: 28, color: Colors.green[900]),
            ),
          ],
        ),
      );
    }

    // Full Sidebar Design
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.eco, size: 80, color: Colors.green),
        const SizedBox(height: 20),
        Text(
          "Nature's\nBalance",
          textAlign: TextAlign.center,
          style: GoogleFonts.lobster(
            fontSize: 32,
            color: Colors.green[900],
          ),
        ),
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            "Restore the dry earth to lush green fields by matching nature's gifts.",
            textAlign: TextAlign.center,
            style: TextStyle(fontStyle: FontStyle.italic),
          ),
        )
      ],
    );
  }
}