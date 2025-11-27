import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flame/game.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'game/eco_quest_game.dart';

// Global Notifiers
final ValueNotifier<int> scoreNotifier = ValueNotifier<int>(0);
final ValueNotifier<int> highScoreNotifier = ValueNotifier<int>(0);
final ValueNotifier<int> levelTimeNotifier = ValueNotifier<int>(120);
final ValueNotifier<int> currentLevelNotifier = ValueNotifier<int>(1);
final ValueNotifier<bool> gameSuccessNotifier = ValueNotifier<bool>(false);

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
    return WillPopScope(
      onWillPop: () async {
        final shouldExit = await _showExitDialog(context);
        return shouldExit ?? false;
      },
      child: Scaffold(
        body: LayoutBuilder(
          builder: (context, constraints) {
            bool isLandscape = constraints.maxWidth > constraints.maxHeight;
            bool isTabletOrDesktop = constraints.maxWidth >= 600;

            // Strict 30% / 70% Split
            if (isLandscape || isTabletOrDesktop) {
              return Row(
                children: [
                  // 30% Left: Progress
                  SizedBox(
                    width: constraints.maxWidth * 0.3,
                    child: const EnvironmentalProgressPanel(),
                  ),
                  // 70% Right: Game Area
                  Expanded(
                    child: _buildGameSectionWrapper(constraints),
                  ),
                ],
              );
            } else {
              return Column(
                children: [
                  // 30% Top: Progress
                  SizedBox(
                    height: constraints.maxHeight * 0.3,
                    child: const EnvironmentalProgressPanel(),
                  ),
                  // 70% Bottom: Game Area
                  Expanded(
                    child: _buildGameSectionWrapper(constraints),
                  ),
                ],
              );
            }
          },
        ),
      ),
    );
  }

  // Wrapper for the 70% section (Background + Content)
  Widget _buildGameSectionWrapper(BoxConstraints constraints) {
    return Stack(
      children: [
        // 1. Unified Background for the 70% section
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF1B5E20).withValues(alpha: 0.3),
                  const Color(0xFF2D1E17).withValues(alpha: 0.5),
                  const Color(0xFF4A2511).withValues(alpha: 0.3),
                ],
              ),
              image: const DecorationImage(
                // Assuming you might have a subtle background texture
                // If not, this gradient + custom painter acts as the background
                image: AssetImage('assets/images/tile_bg.png'), 
                fit: BoxFit.cover,
                opacity: 0.2,
              ),
            ),
            child: CustomPaint(
              painter: GridPatternPainter(),
            ),
          ),
        ),

        // 2. Content (Header + Board)
        Column(
          children: [
            // Top Section (approx 20% visual weight, but auto-sized)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
              child: _buildUnifiedHeader(),
            ),

            // Game Board Section (Fills remaining space, centered)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: AspectRatio(
                    aspectRatio: 1.0, // Force square for 4x4 grid
                    child: _buildStyledGameBoard(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // The 6 items: Level, EcoPoints, Time, Hint, Restart, Exit
  Widget _buildUnifiedHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: ValueListenableBuilder<int>(
        valueListenable: scoreNotifier,
        builder: (context, score, _) {
          if (score > highScoreNotifier.value) updateHighScore(score);
          
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // 1. Level
              ValueListenableBuilder<int>(
                valueListenable: currentLevelNotifier,
                builder: (ctx, level, _) => _buildCompactStat('LVL', '$level', Colors.amber),
              ),
              
              _buildDivider(),

              // 2. Points
              _buildCompactStat('PTS', '$score', Colors.green),

              _buildDivider(),

              // 3. Time
              ValueListenableBuilder<int>(
                valueListenable: levelTimeNotifier,
                builder: (ctx, time, _) => _buildCompactStat(
                  'TIME', 
                  '${time}s', 
                  time <= 10 ? Colors.red : Colors.lightBlue
                ),
              ),

              _buildDivider(),

              // 4. Hint
              IconButton(
                icon: const Icon(Icons.lightbulb, color: Colors.amber),
                iconSize: 24,
                tooltip: 'Hint',
                onPressed: () {
                  if (game.hintsRemaining > 0 && !game.isProcessing) {
                    game.useHint();
                  }
                },
              ),

              // 5. Restart
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.orange),
                iconSize: 24,
                tooltip: 'Restart',
                onPressed: () => _showRestartDialog(context, game),
              ),

              // 6. Exit
              IconButton(
                icon: const Icon(Icons.exit_to_app, color: Colors.red),
                iconSize: 24,
                tooltip: 'Exit',
                onPressed: () => _showExitDialog(context),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCompactStat(String label, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: GoogleFonts.vt323(
            color: Colors.white60,
            fontSize: 14,
            height: 1,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.vt323(
            color: color,
            fontSize: 22,
            fontWeight: FontWeight.bold,
            height: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 24,
      width: 1,
      color: Colors.white24,
    );
  }

  // The Game Board with the specific card styling
  Widget _buildStyledGameBoard() {
    return Container(
      decoration: BoxDecoration(
        // Transparent BG inside because parent has the image/gradient
        color: Colors.black.withValues(alpha: 0.3), 
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.amber.shade700,
          width: 4, // Prominent border
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withValues(alpha: 0.2),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 0),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: GameWidget(
          game: game,
          overlayBuilderMap: {
            'GameOver': (BuildContext context, EcoQuestGame game) {
              return _buildGameOverDialog(context, game);
            },
          },
        ),
      ),
    );
  }

  Widget _buildGameOverDialog(BuildContext context, EcoQuestGame game) {
    return ValueListenableBuilder<bool>(
      valueListenable: gameSuccessNotifier,
      builder: (context, isSuccess, _) {
        return Container(
          color: Colors.black.withValues(alpha: 0.92),
          child: Center(
            child: Container(
              width: 400,
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isSuccess
                      ? [Colors.green[900]!, Colors.green[700]!]
                      : [Colors.red[900]!, Colors.red[700]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isSuccess ? Colors.amber : Colors.red,
                  width: 4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isSuccess ? Colors.amber : Colors.red).withValues(alpha: 0.6),
                    blurRadius: 30,
                    spreadRadius: 8,
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isSuccess ? Icons.eco : Icons.warning_amber,
                      size: 80,
                      color: isSuccess ? Colors.amber : Colors.red[300],
                    ),
                    const SizedBox(height: 16),
                    
                    Text(
                      isSuccess ? "LEVEL COMPLETE!" : "TIME'S UP!",
                      style: GoogleFonts.vt323(
                        fontSize: 42,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                    
                    const SizedBox(height: 12),
                    
                    if (isSuccess) _buildStarRating(),
                    
                    const SizedBox(height: 16),
                    
                    ValueListenableBuilder<int>(
                      valueListenable: scoreNotifier,
                      builder: (ctx, score, _) {
                        return Column(
                          children: [
                            Text(
                              'EcoPoints Earned',
                              style: GoogleFonts.vt323(
                                fontSize: 20,
                                color: Colors.white70,
                              ),
                            ),
                            Text(
                              '$score',
                              style: GoogleFonts.lobster(
                                fontSize: 38,
                                color: Colors.amber,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    
                    const SizedBox(height: 8),
                    
                    ValueListenableBuilder<int>(
                      valueListenable: highScoreNotifier,
                      builder: (ctx, best, _) {
                        return Text(
                          'Best: $best',
                          style: GoogleFonts.vt323(
                            fontSize: 18,
                            color: Colors.white60,
                          ),
                        );
                      },
                    ),
                    
                    const SizedBox(height: 24),
                    
                    if (isSuccess) ...[
                      ValueListenableBuilder<int>(
                        valueListenable: currentLevelNotifier,
                        builder: (ctx, level, _) {
                          if (level < 6) {
                            return _buildDialogButton(
                              label: 'NEXT LEVEL',
                              icon: Icons.arrow_forward,
                              color: Colors.amber,
                              onPressed: () {
                                game.proceedToNextLevel();
                              },
                            );
                          } else {
                            return Text(
                              '🎉 ALL LEVELS COMPLETED! 🎉',
                              style: GoogleFonts.vt323(
                                fontSize: 24,
                                color: Colors.amber,
                              ),
                              textAlign: TextAlign.center,
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                    
                    _buildDialogButton(
                      label: isSuccess ? 'REPLAY LEVEL' : 'TRY AGAIN',
                      icon: Icons.refresh,
                      color: Colors.green,
                      onPressed: () {
                        game.restartGame();
                      },
                    ),
                    
                    const SizedBox(height: 12),
                    
                    _buildDialogButton(
                      label: 'EXIT GAME',
                      icon: Icons.exit_to_app,
                      color: Colors.red[700]!,
                      onPressed: () async {
                        await SystemChannels.platform.invokeMethod('SystemNavigator.pop');
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStarRating() {
    return ValueListenableBuilder<int>(
      valueListenable: scoreNotifier,
      builder: (context, score, _) {
        return ValueListenableBuilder<int>(
          valueListenable: currentLevelNotifier,
          builder: (context, level, _) {
            int target = EcoQuestGame.levelTargets[level] ?? 1000;
            int stars = 1;
            
            if (score >= target * 1.5) {
              stars = 3;
            } else if (score >= target * 1.2) {
              stars = 2;
            }
            
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (index) {
                return Icon(
                  index < stars ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                  size: 40,
                );
              }),
            );
          },
        );
      },
    );
  }

  Widget _buildDialogButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 24),
        label: Text(
          label,
          style: GoogleFonts.vt323(fontSize: 22, letterSpacing: 1.5),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 8,
        ),
      ),
    );
  }

  void _showRestartDialog(BuildContext context, EcoQuestGame game) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2D1E17),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.orange, width: 3),
        ),
        title: Text(
          'Restart Level?',
          style: GoogleFonts.vt323(color: Colors.white, fontSize: 28),
        ),
        content: Text(
          'Your current progress will be lost.',
          style: GoogleFonts.vt323(color: Colors.white70, fontSize: 18),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'CANCEL',
              style: GoogleFonts.vt323(fontSize: 18, color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              game.restartGame();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text('RESTART', style: GoogleFonts.vt323(fontSize: 18)),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showExitDialog(BuildContext context) async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2D1E17),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.red, width: 3),
        ),
        title: Text(
          'Exit Game?',
          style: GoogleFonts.vt323(color: Colors.white, fontSize: 28),
        ),
        content: Text(
          'Are you sure you want to exit?',
          style: GoogleFonts.vt323(color: Colors.white70, fontSize: 18),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'CANCEL',
              style: GoogleFonts.vt323(fontSize: 18, color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx, true);
              await SystemChannels.platform.invokeMethod('SystemNavigator.pop');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text('EXIT', style: GoogleFonts.vt323(fontSize: 18)),
          ),
        ],
      ),
    );
  }
}

// Environmental Progress Panel
class EnvironmentalProgressPanel extends StatelessWidget {
  const EnvironmentalProgressPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1B5E20), Color(0xFF4CAF50)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: ValueListenableBuilder<int>(
        valueListenable: scoreNotifier,
        builder: (context, score, _) {
          return ValueListenableBuilder<int>(
            valueListenable: currentLevelNotifier,
            builder: (context, level, _) {
              int target = EcoQuestGame.levelTargets[level] ?? 1000;
              double progress = (score / target).clamp(0.0, 1.0);
              
              return SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.landscape,
                        size: 60,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 16),
                      
                      Text(
                        'LAND RESTORATION',
                        style: GoogleFonts.vt323(
                          fontSize: 26,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      _buildProgressStage(
                        'Barren Land',
                        Icons.landscape_outlined,
                        progress >= 0.0,
                        Colors.brown,
                      ),
                      _buildProgressStage(
                        'Sprouts Growing',
                        Icons.eco,
                        progress >= 0.25,
                        Colors.lightGreen,
                      ),
                      _buildProgressStage(
                        'Trees Emerging',
                        Icons.park,
                        progress >= 0.5,
                        Colors.green,
                      ),
                      _buildProgressStage(
                        'Wildlife Returning',
                        Icons.pets,
                        progress >= 0.75,
                        Colors.green[700]!,
                      ),
                      _buildProgressStage(
                        'Thriving Ecosystem',
                        Icons.forest,
                        progress >= 1.0,
                        Colors.green[900]!,
                      ),
                      
                      const SizedBox(height: 20),
                      
                      Text(
                        '${(progress * 100).toInt()}% Restored',
                        style: GoogleFonts.vt323(
                          fontSize: 30,
                          color: Colors.amber,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      
                      const SizedBox(height: 12),
                      
                      Text(
                        'Every match helps restore the environment!',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.vt323(
                          fontSize: 16,
                          color: Colors.white70,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildProgressStage(
    String label,
    IconData icon,
    bool isActive,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            icon,
            color: isActive ? color : Colors.grey[600],
            size: 32,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.vt323(
                fontSize: 18,
                color: isActive ? Colors.white : Colors.grey[400],
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          if (isActive)
            const Icon(Icons.check_circle, color: Colors.amber, size: 24),
        ],
      ),
    );
  }
}

// Custom Painter for Background Pattern
class GridPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.03)
      ..strokeWidth = 1.0;

    const spacing = 40.0;
    
    for (double i = 0; i < size.width; i += spacing) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i, size.height),
        paint,
      );
    }
    
    for (double i = 0; i < size.height; i += spacing) {
      canvas.drawLine(
        Offset(0, i),
        Offset(size.width, i),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}