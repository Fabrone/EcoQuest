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
final ValueNotifier<int> levelTimeNotifier = ValueNotifier<int>(70);
final ValueNotifier<int> currentLevelNotifier = ValueNotifier<int>(1);
final ValueNotifier<bool> gameSuccessNotifier = ValueNotifier<bool>(false);
final ValueNotifier<int> plantsCollectedNotifier = ValueNotifier<int>(0);

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
    // Replaced WillPopScope with PopScope
    return PopScope(
      canPop: false, // Prevents the screen from closing automatically
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) {
          return;
        }
        // Show the exit dialog
        final shouldExit = await _showExitDialog(context);

        // If the user confirms (returns true), we manually pop the route
        if (shouldExit ?? false) {
          if (context.mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        body: LayoutBuilder(
          builder: (context, constraints) {
            bool isLandscape = constraints.maxWidth > constraints.maxHeight;
            bool isTabletOrDesktop = constraints.maxWidth >= 600;

            if (isLandscape || isTabletOrDesktop) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: constraints.maxWidth * 0.3,
                    child: const EnvironmentalProgressPanel(),
                  ),
                  Expanded(
                    child: _buildGameSectionWrapper(constraints),
                  ),
                ],
              );
            } else {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: constraints.maxHeight * 0.3,
                    child: const EnvironmentalProgressPanel(),
                  ),
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

  Widget _buildGameSectionWrapper(BoxConstraints constraints) {
    return Stack(
      children: [
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF1B5E20).withValues(alpha:0.3),
                  const Color(0xFF2D1E17).withValues(alpha:0.5),
                  const Color(0xFF4A2511).withValues(alpha:0.3),
                ],
              ),
              image: const DecorationImage(
                image: AssetImage('assets/images/tile_bg.png'), 
                fit: BoxFit.cover,
                opacity: 0.15,
              ),
            ),
            child: CustomPaint(
              painter: GridPatternPainter(),
            ),
          ),
        ),

        Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: _buildUnifiedHeader(),
            ),

            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: AspectRatio(
                    aspectRatio: 1.0, 
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

  Widget _buildUnifiedHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha:0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: ValueListenableBuilder<int>(
        valueListenable: scoreNotifier,
        builder: (context, score, _) {
          if (score > highScoreNotifier.value) updateHighScore(score);
          
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ValueListenableBuilder<int>(
                valueListenable: currentLevelNotifier,
                builder: (ctx, level, _) => _buildCompactStat('LVL', '$level', Colors.amber),
              ),
              
              _buildDivider(),

              _buildCompactStat('PTS', '$score', Colors.green),

              _buildDivider(),

              ValueListenableBuilder<int>(
                valueListenable: levelTimeNotifier,
                builder: (ctx, time, _) => _buildCompactStat(
                  'TIME', 
                  '${time}s', 
                  time <= 10 ? Colors.red : Colors.lightBlue
                ),
              ),

              _buildDivider(),

              _buildIconButton(
                icon: Icons.lightbulb, 
                color: Colors.amber, 
                onTap: () {
                  if (game.hintsRemaining > 0 && !game.isProcessing) {
                    game.useHint();
                  }
                }
              ),

              _buildIconButton(
                icon: Icons.refresh, 
                color: Colors.orange, 
                onTap: () => _showRestartDialog(context, game)
              ),

              _buildIconButton(
                icon: Icons.exit_to_app, 
                color: Colors.red, 
                onTap: () => _showExitDialog(context)
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
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.vt323(
            color: color,
            fontSize: 24,
            fontWeight: FontWeight.bold,
            height: 1.1,
          ),
        ),
      ],
    );
  }

  Widget _buildIconButton({required IconData icon, required Color color, required VoidCallback onTap}) {
    return IconButton(
      icon: Icon(icon, color: color),
      iconSize: 26,
      visualDensity: VisualDensity.compact,
      onPressed: onTap,
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 24,
      width: 1,
      color: Colors.white24,
    );
  }

  Widget _buildStyledGameBoard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha:0.25), 
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.amber.shade700,
          width: 4.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withValues(alpha:0.15),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 0),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: GameWidget(
          game: game,
          overlayBuilderMap: {
            'GameOver': (BuildContext context, EcoQuestGame game) {
              return _buildGameOverDialog(context, game);
            },
            'PhaseComplete': (BuildContext context, EcoQuestGame game) {
              return _buildPhaseCompleteDialog(context, game);
            },
            'DyeExtraction': (BuildContext context, EcoQuestGame game) {
              return DyeExtractionOverlay(game: game);
            },
          },
        ),
      ),
    );
  }

  // Phase Complete Dialog (Transition from Phase 1 to Phase 2)
  Widget _buildPhaseCompleteDialog(BuildContext context, EcoQuestGame game) {
    return Container(
      color: Colors.black.withValues(alpha:0.92),
      child: Center(
        child: Container(
          width: 400,
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.green[900]!, Colors.green[700]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.amber,
              width: 4,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.amber.withValues(alpha:0.6),
                blurRadius: 30,
                spreadRadius: 8,
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.park,
                  size: 80,
                  color: Colors.amber,
                ),
                const SizedBox(height: 16),
                
                Text(
                  "FOREST RESTORED!",
                  style: GoogleFonts.vt323(
                    fontSize: 38,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 20),
                
                ValueListenableBuilder<int>(
                  valueListenable: plantsCollectedNotifier,
                  builder: (ctx, plants, _) {
                    return Column(
                      children: [
                        Text(
                          'Plant Materials Collected',
                          style: GoogleFonts.vt323(
                            fontSize: 20,
                            color: Colors.white70,
                          ),
                        ),
                        Text(
                          '$plants units',
                          style: GoogleFonts.lobster(
                            fontSize: 38,
                            color: Colors.amber,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                
                const SizedBox(height: 20),
                
                Text(
                  'All tiles have been restored to green!\nTime to extract natural dyes.',
                  style: GoogleFonts.vt323(
                    fontSize: 18,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 24),
                
                _buildDialogButton(
                  label: 'PROCEED TO DYE EXTRACTION',
                  icon: Icons.science,
                  color: Colors.amber,
                  onPressed: () {
                    game.startPhase2();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGameOverDialog(BuildContext context, EcoQuestGame game) {
    return ValueListenableBuilder<bool>(
      valueListenable: gameSuccessNotifier,
      builder: (context, isSuccess, _) {
        return Container(
          color: Colors.black.withValues(alpha:0.92),
          child: Center(
            child: Container(
              width: 400,
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.red[900]!, Colors.red[700]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.red,
                  width: 4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withValues(alpha:0.6),
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
                      Icons.warning_amber,
                      size: 80,
                      color: Colors.red[300],
                    ),
                    const SizedBox(height: 16),
                    
                    Text(
                      "TIME'S UP!",
                      style: GoogleFonts.vt323(
                        fontSize: 42,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                    
                    const SizedBox(height: 12),
                    
                    Text(
                      'The forest could not be fully restored in time.',
                      style: GoogleFonts.vt323(
                        fontSize: 18,
                        color: Colors.white70,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    
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
                    
                    const SizedBox(height: 24),
                    
                    _buildDialogButton(
                      label: 'TRY AGAIN',
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

// Environmental Progress Panel with Forest Image Updates
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
        boxShadow: [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 10,
            offset: Offset(2, 0),
          )
        ],
      ),
      child: ValueListenableBuilder<int>(
        valueListenable: scoreNotifier,
        builder: (context, score, _) {
          // Get forest image index based on score
          int imageIndex = 0;
          if (score > 0) {
            double percentage = (score / EcoQuestGame.targetHighScore).clamp(0.0, 1.0);
            imageIndex = (percentage * 9).round();
          }
          
          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
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
                  
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'FOREST RESTORATION',
                      style: GoogleFonts.vt323(
                        fontSize: 26,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Forest Image Display
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white24, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha:0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.asset(
                        'assets/images/forest_$imageIndex.png',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.brown.shade800,
                            child: const Center(
                              child: Icon(Icons.image_not_supported, color: Colors.white54, size: 50),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  Text(
                    '${((score / EcoQuestGame.targetHighScore) * 100).clamp(0, 100).toInt()}% Restored',
                    style: GoogleFonts.vt323(
                      fontSize: 30,
                      color: Colors.amber,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  Text(
                    'Score: $score / ${EcoQuestGame.targetHighScore}',
                    style: GoogleFonts.vt323(
                      fontSize: 18,
                      color: Colors.white70,
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  Text(
                    'Match tiles to restore the forest ecosystem!',
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
      ),
    );
  }
}

// Custom Painter for Background Pattern
class GridPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha:0.03)
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

// Dye Extraction Overlay (Phase 2)
class DyeExtractionOverlay extends StatefulWidget {
  final EcoQuestGame game;
  
  const DyeExtractionOverlay({super.key, required this.game});

  @override
  State<DyeExtractionOverlay> createState() => _DyeExtractionOverlayState();
}

class _DyeExtractionOverlayState extends State<DyeExtractionOverlay> {
  int currentStep = 0;
  int dyeProduced = 0;
  double dyeValue = 0.0;
  
  final List<String> stepTitles = [
    'Collect Plant Materials',
    'Crush in Mortar',
    'Simmer in Beaker',
    'Filter the Mixture',
    'Dye Extracted!'
  ];
  
  final List<String> stepDescriptions = [
    'Tap to gather leaves, bark, roots, flowers, and fruits for dye extraction.',
    'Crush the collected materials using a mortar and pestle to break down cell walls.',
    'Heat the crushed materials in water to extract the natural pigments.',
    'Filter the mixture to separate the liquid dye from plant residue.',
    'Natural dye successfully extracted! Ready for use in customization and future levels.'
  ];
  
  final List<IconData> stepIcons = [
    Icons.spa,
    Icons.circle,
    Icons.science,
    Icons.filter_alt,
    Icons.colorize,
  ];

  @override
  void initState() {
    super.initState();
    // Calculate dye produced based on plants collected
    int plants = plantsCollectedNotifier.value;
    dyeProduced = (plants * 0.8).toInt(); // 80% conversion rate
    dyeValue = dyeProduced * 5.0; // Each unit worth 5 EcoCoins
  }

  void _nextStep() {
    if (currentStep < stepTitles.length - 1) {
      setState(() {
        currentStep++;
      });
    } else {
      // Show completion dialog
      _showCompletionDialog();
    }
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2D1E17),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.green, width: 3),
        ),
        title: Text(
          'Phase 2 Complete!',
          style: GoogleFonts.vt323(color: Colors.white, fontSize: 28),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 60),
            const SizedBox(height: 16),
            Text(
              'Dye Produced: $dyeProduced ml',
              style: GoogleFonts.vt323(color: Colors.amber, fontSize: 22),
            ),
            Text(
              'Value: ${dyeValue.toStringAsFixed(1)} EcoCoins',
              style: GoogleFonts.vt323(color: Colors.green, fontSize: 22),
            ),
            const SizedBox(height: 12),
            Text(
              'This dye can be used for avatar customization and will be carried forward to future levels!',
              style: GoogleFonts.vt323(color: Colors.white70, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              widget.game.restartGame();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text('REPLAY LEVEL', style: GoogleFonts.vt323(fontSize: 18)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
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

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha:0.95),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              // Header
              Text(
                'DYE EXTRACTION PROCESS',
                style: GoogleFonts.vt323(
                  fontSize: 32,
                  color: Colors.amber,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              
              const SizedBox(height: 8),
              
              Text(
                'Phase 2 of 2',
                style: GoogleFonts.vt323(
                  fontSize: 18,
                  color: Colors.white70,
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Progress Indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(stepTitles.length, (index) {
                  return Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: index <= currentStep 
                              ? Colors.green 
                              : Colors.grey.shade700,
                          border: Border.all(
                            color: index == currentStep 
                                ? Colors.amber 
                                : Colors.transparent,
                            width: 3,
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            index < currentStep 
                                ? Icons.check 
                                : stepIcons[index],
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                      if (index < stepTitles.length - 1)
                        Container(
                          width: 30,
                          height: 2,
                          color: index < currentStep 
                              ? Colors.green 
                              : Colors.grey.shade700,
                        ),
                    ],
                  );
                }),
              ),
              
              const SizedBox(height: 32),
              
              // Current Step Display
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.green.shade900,
                        Colors.green.shade700,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.amber, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.amber.withValues(alpha:0.3),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        stepIcons[currentStep],
                        size: 100,
                        color: Colors.amber,
                      ),
                      
                      const SizedBox(height: 24),
                      
                      Text(
                        stepTitles[currentStep],
                        style: GoogleFonts.vt323(
                          fontSize: 28,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      
                      const SizedBox(height: 16),
                      
                      Text(
                        stepDescriptions[currentStep],
                        style: GoogleFonts.vt323(
                          fontSize: 18,
                          color: Colors.white70,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      
                      const SizedBox(height: 24),
                      
                      if (currentStep == 0)
                        ValueListenableBuilder<int>(
                          valueListenable: plantsCollectedNotifier,
                          builder: (ctx, plants, _) {
                            return Text(
                              'Materials Available: $plants units',
                              style: GoogleFonts.vt323(
                                fontSize: 22,
                                color: Colors.amber,
                              ),
                            );
                          },
                        ),
                      
                      if (currentStep == 4)
                        Column(
                          children: [
                            Text(
                              'Dye Produced: $dyeProduced ml',
                              style: GoogleFonts.vt323(
                                fontSize: 24,
                                color: Colors.amber,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Estimated Value: ${dyeValue.toStringAsFixed(1)} EcoCoins',
                              style: GoogleFonts.vt323(
                                fontSize: 20,
                                color: Colors.green.shade300,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Action Button
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton.icon(
                  onPressed: _nextStep,
                  icon: Icon(
                    currentStep < stepTitles.length - 1 
                        ? Icons.arrow_forward 
                        : Icons.check_circle,
                    size: 28,
                  ),
                  label: Text(
                    currentStep < stepTitles.length - 1 
                        ? 'NEXT STEP' 
                        : 'COMPLETE',
                    style: GoogleFonts.vt323(
                      fontSize: 26,
                      letterSpacing: 2,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: currentStep < stepTitles.length - 1 
                        ? Colors.amber 
                        : Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 8,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}