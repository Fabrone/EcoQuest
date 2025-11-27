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
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          bool isLandscape = constraints.maxWidth > constraints.maxHeight;
          bool isTabletOrDesktop = constraints.maxWidth >= 600;

          if (isLandscape || isTabletOrDesktop) {
            // Landscape or Tablet/Desktop: Side panel (30% left)
            return Row(
              children: [
                SizedBox(
                  width: constraints.maxWidth * 0.3,
                  child: const EnvironmentalProgressPanel(),
                ),
                Expanded(
                  child: _buildGameWidget(),
                ),
              ],
            );
          } else {
            // Portrait Mobile: Top panel (30% top)
            return Column(
              children: [
                SizedBox(
                  height: constraints.maxHeight * 0.3,
                  child: const EnvironmentalProgressPanel(),
                ),
                Expanded(
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
          return _buildHUD(context, game);
        },
        'GameOver': (BuildContext context, EcoQuestGame game) {
          return _buildGameOverDialog(context, game);
        },
      },
    );
  }

  Widget _buildHUD(BuildContext context, EcoQuestGame game) {
    return ValueListenableBuilder<int>(
      valueListenable: scoreNotifier,
      builder: (context, currentScore, child) {
        if (currentScore > highScoreNotifier.value) {
          updateHighScore(currentScore);
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                // Top Row: Level, Score, Timer
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Level Indicator
                    ValueListenableBuilder<int>(
                      valueListenable: currentLevelNotifier,
                      builder: (ctx, level, _) {
                        return _buildStatCard(
                          icon: Icons.stars,
                          label: 'LEVEL',
                          value: '$level',
                          color: Colors.amber,
                        );
                      },
                    ),
                    
                    // Score Card
                    _buildStatCard(
                      icon: Icons.eco,
                      label: 'ECOPOINTS',
                      value: '$currentScore',
                      color: Colors.green,
                    ),
                    
                    // Timer
                    ValueListenableBuilder<int>(
                      valueListenable: levelTimeNotifier,
                      builder: (ctx, time, _) {
                        final color = time <= 10 ? Colors.red : Colors.blue;
                        return _buildStatCard(
                          icon: Icons.timer,
                          label: 'TIME',
                          value: '${time}s',
                          color: color,
                        );
                      },
                    ),
                  ],
                ),
                
                const SizedBox(height: 10),
                
                // Action Buttons Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _buildActionButton(
                      icon: Icons.lightbulb_outline,
                      label: 'HINT (${game.hintsRemaining})',
                      onPressed: game.hintsRemaining > 0 && !game.isProcessing
                          ? () => game.useHint()
                          : null,
                      color: Colors.amber,
                    ),
                    const SizedBox(width: 8),
                    _buildActionButton(
                      icon: Icons.refresh,
                      label: 'RESTART',
                      onPressed: () => _showRestartDialog(context, game),
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    _buildActionButton(
                      icon: Icons.close,
                      label: 'EXIT',
                      onPressed: () => _showExitDialog(context),
                      color: Colors.red,
                    ),
                  ],
                ),
                
                const Spacer(),
                
                // Target Score Indicator
                ValueListenableBuilder<int>(
                  valueListenable: currentLevelNotifier,
                  builder: (ctx, level, _) {
                    int target = EcoQuestGame.levelTargets[level] ?? 1000;
                    double progress = (currentScore / target).clamp(0.0, 1.0);
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green, width: 2),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Target: $target EcoPoints',
                            style: GoogleFonts.vt323(
                              color: Colors.white,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: progress,
                            backgroundColor: Colors.grey[800],
                            valueColor: AlwaysStoppedAnimation<Color>(
                              progress >= 1.0 ? Colors.amber : Colors.green,
                            ),
                            minHeight: 8,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha:0.7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.vt323(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.vt323(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    required Color color,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(
        label,
        style: GoogleFonts.vt323(fontSize: 14),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: onPressed != null ? color : Colors.grey,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Widget _buildGameOverDialog(BuildContext context, EcoQuestGame game) {
    return ValueListenableBuilder<bool>(
      valueListenable: gameSuccessNotifier,
      builder: (context, isSuccess, _) {
        return Container(
          color: Colors.black87,
          child: Center(
            child: Container(
              width: 400,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isSuccess
                      ? [Colors.green[900]!, Colors.green[700]!]
                      : [Colors.red[900]!, Colors.red[700]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSuccess ? Colors.amber : Colors.red,
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isSuccess ? Colors.amber : Colors.red).withValues(alpha:0.5),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Success/Failure Icon
                  Icon(
                    isSuccess ? Icons.eco : Icons.warning_amber,
                    size: 80,
                    color: isSuccess ? Colors.amber : Colors.red[300],
                  ),
                  const SizedBox(height: 16),
                  
                  // Title
                  Text(
                    isSuccess ? "LEVEL COMPLETE!" : "TIME'S UP!",
                    style: GoogleFonts.vt323(
                      fontSize: 42,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Stars for success
                  if (isSuccess) _buildStarRating(),
                  
                  const SizedBox(height: 16),
                  
                  // Score Display
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
                              fontSize: 36,
                              color: Colors.amber,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // High Score
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
                  
                  // Action Buttons
                  if (isSuccess) ...[
                    // Next Level Button
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
                  
                  // Retry/Restart Button
                  _buildDialogButton(
                    label: isSuccess ? 'REPLAY LEVEL' : 'TRY AGAIN',
                    icon: Icons.refresh,
                    color: Colors.green,
                    onPressed: () {
                      game.restartGame();
                    },
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Exit Button
                  _buildDialogButton(
                    label: 'EXIT GAME',
                    icon: Icons.exit_to_app,
                    color: Colors.red[700]!,
                    onPressed: () {
                      SystemNavigator.pop();
                    },
                  ),
                ],
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
          style: GoogleFonts.vt323(fontSize: 22),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  void _showRestartDialog(BuildContext context, EcoQuestGame game) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2D1E17),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
          side: const BorderSide(color: Colors.orange, width: 2),
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
            child: Text('CANCEL', style: GoogleFonts.vt323(fontSize: 18)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              game.restartGame();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: Text('RESTART', style: GoogleFonts.vt323(fontSize: 18)),
          ),
        ],
      ),
    );
  }

  void _showExitDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2D1E17),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
          side: const BorderSide(color: Colors.red, width: 2),
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
            onPressed: () => Navigator.pop(ctx),
            child: Text('CANCEL', style: GoogleFonts.vt323(fontSize: 18)),
          ),
          ElevatedButton(
            onPressed: () {
              SystemNavigator.pop();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
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
              
              return Column(
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
                      fontSize: 24,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Progress visualization
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
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
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  Text(
                    '${(progress * 100).toInt()}% Restored',
                    style: GoogleFonts.vt323(
                      fontSize: 28,
                      color: Colors.amber,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      'Every match helps restore the environment!',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.vt323(
                        fontSize: 16,
                        color: Colors.white70,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
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
            size: 30,
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