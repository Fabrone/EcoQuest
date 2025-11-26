import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For SystemNavigator
import 'package:flame/game.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'game/eco_quest_game.dart';

// Global Notifiers
final ValueNotifier<int> scoreNotifier = ValueNotifier<int>(0);
final ValueNotifier<int> highScoreNotifier = ValueNotifier<int>(0);
final ValueNotifier<int> levelTimeNotifier = ValueNotifier<int>(120); // Initial time set to 120 seconds

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await _loadHighScore();
  runApp(const EcoQuestApp());
}

Future<void> _loadHighScore() async {
  final prefs = await SharedPreferences.getInstance();
  highScoreNotifier.value = prefs.getInt('high_score') ?? 0;
}

Future<void> updateHighScore(int newScore) async {
  if (newScore > highScoreNotifier.value) {
    highScoreNotifier.value = newScore;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('high_score', newScore);
  }
}

class EcoQuestApp extends StatelessWidget {
  const EcoQuestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.green,
        scaffoldBackgroundColor: const Color(0xFF2D1E17),
      ),
      home: const GameScreen(),
    );
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final EcoQuestGame game;

  @override
  void initState() {
    super.initState();
    game = EcoQuestGame();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          bool isMobile = constraints.maxWidth < 600;

          if (isMobile) {
            return Column(
              children: [
                const SizedBox(
                  height: 100,
                  child: AnimatedGardenPanel(isCompact: true),
                ),
                Expanded(
                  child: _buildGameWidget(),
                ),
              ],
            );
          } else {
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
      game: game,
      overlayBuilderMap: {
        'HUD': (BuildContext context, EcoQuestGame game) {
          return ValueListenableBuilder<int>(
            valueListenable: scoreNotifier,
            builder: (context, currentScore, child) {
              if (currentScore > highScoreNotifier.value) {
                updateHighScore(currentScore);
              }

              return SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // --- SCORE & TIME BOARD ---
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Column(
                          children: [
                            ValueListenableBuilder<int>(
                              valueListenable: highScoreNotifier,
                              builder: (ctx, best, _) {
                                return Text(
                                  'BEST: $best',
                                  style: GoogleFonts.vt323(color: Colors.yellow, fontSize: 18),
                                );
                              }
                            ),
                            Text(
                              'SCORE: $currentScore',
                              style: GoogleFonts.vt323(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            // --- TIME REMAINING ---
                            ValueListenableBuilder<int>(
                              valueListenable: levelTimeNotifier,
                              builder: (ctx, time, _) {
                                final color = time <= 10 ? Colors.red : Colors.lightBlueAccent;
                                return Text(
                                  'TIME: ${time.toString().padLeft(2, '0')}s',
                                  style: GoogleFonts.vt323(color: color, fontSize: 24),
                                );
                              }
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // --- HINT BUTTON ---
                      ElevatedButton.icon(
                        onPressed: game.isProcessing ? null : () {
                           game.useHint();
                        },
                        icon: Icon(
                          Icons.lightbulb_outline,
                          color: game.hintsRemaining > 0 ? Colors.yellow : Colors.grey,
                        ),
                        label: Text("HINT (${game.hintsRemaining})"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[800],
                          foregroundColor: Colors.white,
                        ),
                      ),
                      
                      const Spacer(),
                      
                      // --- UNDO BUTTON ---
                      Padding(
                        padding: const EdgeInsets.only(bottom: 20.0, right: 10.0),
                        child: FloatingActionButton.extended(
                          heroTag: "undoBtn",
                          onPressed: (game.isProcessing || game.undoRemaining <= 0) ? null : () {
                            game.undoLastSwap();
                          },
                          backgroundColor: (game.undoRemaining > 0) ? Colors.orange[700] : Colors.grey,
                          foregroundColor: Colors.white,
                          icon: const Icon(Icons.undo, size: 24),
                          label: Text("Undo (${game.undoRemaining})"),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        
        // --- GAME OVER OVERLAY (for time running out) ---
        'GameOver': (BuildContext context, EcoQuestGame game) {
          return Container(
            color: Colors.black87,
            child: Center(
              child: Container(
                width: 300,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF2D1E17),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.red, width: 3),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("TIME'S UP!", style: GoogleFonts.vt323(fontSize: 40, color: Colors.red)),
                    const SizedBox(height: 10),
                    Text("Score: ${scoreNotifier.value}", style: GoogleFonts.lobster(fontSize: 24, color: Colors.white)),
                    const SizedBox(height: 20),
                    
                    // Replay Button
                    ElevatedButton(
                      onPressed: () {
                        game.restartGame();
                        game.overlays.remove('GameOver');
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                      child: const Text("Replay Level", style: TextStyle(color: Colors.white)),
                    ),
                    const SizedBox(height: 10),
                    
                    // Exit Button
                    TextButton(
                      onPressed: () {
                         SystemNavigator.pop();
                      },
                      child: const Text("Exit Application", style: TextStyle(color: Colors.white54)),
                    ),
                  ],
                ),
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