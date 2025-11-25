import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart'; 
import 'firebase_options.dart'; 
import 'game/eco_quest_game.dart';

// Global Notifiers
final ValueNotifier<int> scoreNotifier = ValueNotifier<int>(0);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const EcoQuestApp());
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
  void dispose() {
    super.dispose();
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
          return ValueListenableBuilder(
            valueListenable: scoreNotifier,
            builder: (context, _, child) {
              return SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Score Board
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: Text(
                              'Eco Points: ${scoreNotifier.value}',
                              style: GoogleFonts.vt323(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          
                          // HINT Button
                          ElevatedButton.icon(
                            onPressed: game.isProcessing ? null : () {
                              if (game.hintsRemaining > 0) {
                                game.useHint();
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("No hints remaining!"),
                                    duration: Duration(seconds: 1),
                                  ),
                                );
                              }
                            },
                            icon: Icon(
                              Icons.lightbulb_outline,
                              color: game.hintsRemaining > 0 ? Colors.yellow : Colors.grey,
                            ),
                            label: Text("HINT (${game.hintsRemaining})"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green[800],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      // UNDO Button
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
                          label: Text(
                            "Undo (${game.undoRemaining})",
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
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