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
            'InsufficientMaterials': (BuildContext context, EcoQuestGame game) {
              return _buildInsufficientMaterialsDialog(context, game);
            },
            'DyeExtraction': (BuildContext context, EcoQuestGame game) {
              return DyeExtractionOverlay(game: game);
            },
          },
        ),
      ),
    );
  }

  Widget _buildPhaseCompleteDialog(BuildContext context, EcoQuestGame game) {
    return Container(
      color: Colors.black.withValues(alpha: 0.92),
      child: Center(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Calculate responsive dimensions
            double dialogWidth = constraints.maxWidth * 0.85;
            double dialogMaxWidth = 450;
            dialogWidth = dialogWidth.clamp(280.0, dialogMaxWidth);
            
            double iconSize = constraints.maxWidth * 0.10;
            iconSize = iconSize.clamp(40.0, 70.0);
            
            double titleFontSize = constraints.maxWidth * 0.065;
            titleFontSize = titleFontSize.clamp(20.0, 36.0);
            
            double bodyFontSize = constraints.maxWidth * 0.032;
            bodyFontSize = bodyFontSize.clamp(12.0, 16.0);
            
            double valueFontSize = constraints.maxWidth * 0.065;
            valueFontSize = valueFontSize.clamp(20.0, 34.0);
            
            double buttonIconSize = constraints.maxWidth * 0.05;
            buttonIconSize = buttonIconSize.clamp(18.0, 30.0);
            
            // Dynamic spacing based on available height
            double spacing1 = constraints.maxHeight * 0.01;
            double spacing2 = constraints.maxHeight * 0.015;
            double spacing3 = constraints.maxHeight * 0.02;
            
            return SingleChildScrollView(
              child: Container(
                width: dialogWidth,
                margin: EdgeInsets.symmetric(
                  horizontal: constraints.maxWidth * 0.05,
                  vertical: constraints.maxHeight * 0.05,
                ),
                padding: EdgeInsets.all(constraints.maxWidth * 0.04),
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
                      color: Colors.amber.withValues(alpha: 0.6),
                      blurRadius: 30,
                      spreadRadius: 8,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.park,
                      size: iconSize,
                      color: Colors.amber,
                    ),
                    SizedBox(height: spacing1),
                    
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        "FOREST RESTORED!",
                        style: GoogleFonts.vt323(
                          fontSize: titleFontSize,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    
                    SizedBox(height: spacing2),
                    
                    ValueListenableBuilder<int>(
                      valueListenable: plantsCollectedNotifier,
                      builder: (ctx, plants, _) {
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Plant Materials Collected',
                              style: GoogleFonts.vt323(
                                fontSize: bodyFontSize,
                                color: Colors.white70,
                              ),
                            ),
                            SizedBox(height: spacing1 * 0.5),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                '$plants units',
                                style: GoogleFonts.lobster(
                                  fontSize: valueFontSize,
                                  color: Colors.amber,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    
                    SizedBox(height: spacing2),
                    
                    Text(
                      'All tiles restored to green!\nTime to extract natural dyes.',
                      style: GoogleFonts.vt323(
                        fontSize: bodyFontSize,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    
                    SizedBox(height: spacing3),
                    
                    // Icon-based proceed button
                    _buildIconActionButton(
                      icon: Icons.science,
                      label: 'Proceed',
                      color: Colors.amber,
                      iconSize: buttonIconSize,
                      onPressed: () {
                        game.startPhase2();
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildInsufficientMaterialsDialog(BuildContext context, EcoQuestGame game) {
    return Container(
      color: Colors.black.withValues(alpha: 0.92),
      child: Center(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Calculate responsive dimensions
            double dialogWidth = constraints.maxWidth * 0.85;
            double dialogMaxWidth = 450;
            dialogWidth = dialogWidth.clamp(280.0, dialogMaxWidth);
            
            double iconSize = constraints.maxWidth * 0.12;
            iconSize = iconSize.clamp(50.0, 80.0);
            
            double titleFontSize = constraints.maxWidth * 0.065;
            titleFontSize = titleFontSize.clamp(20.0, 36.0);
            
            double bodyFontSize = constraints.maxWidth * 0.032;
            bodyFontSize = bodyFontSize.clamp(12.0, 16.0);
            
            double scoreFontSize = constraints.maxWidth * 0.065;
            scoreFontSize = scoreFontSize.clamp(20.0, 34.0);
            
            double buttonIconSize = constraints.maxWidth * 0.05;
            buttonIconSize = buttonIconSize.clamp(18.0, 30.0);
            
            // Dynamic spacing
            double spacing1 = constraints.maxHeight * 0.01;
            double spacing2 = constraints.maxHeight * 0.015;
            double spacing3 = constraints.maxHeight * 0.02;
            
            return SingleChildScrollView(
              child: Container(
                width: dialogWidth,
                margin: EdgeInsets.symmetric(
                  horizontal: constraints.maxWidth * 0.05,
                  vertical: constraints.maxHeight * 0.05,
                ),
                padding: EdgeInsets.all(constraints.maxWidth * 0.04),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.orange[900]!, Colors.orange[700]!],
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
                      color: Colors.orange.withValues(alpha: 0.6),
                      blurRadius: 30,
                      spreadRadius: 8,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: iconSize,
                      color: Colors.amber,
                    ),
                    SizedBox(height: spacing1),
                    
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        "PLANTS TOO YOUNG!",
                        style: GoogleFonts.vt323(
                          fontSize: titleFontSize,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    
                    SizedBox(height: spacing2),
                    
                    Text(
                      'Forest restored, but plants need more time to mature for harvesting.',
                      style: GoogleFonts.vt323(
                        fontSize: bodyFontSize,
                        color: Colors.white70,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    
                    SizedBox(height: spacing2),
                    
                    ValueListenableBuilder<int>(
                      valueListenable: scoreNotifier,
                      builder: (ctx, score, _) {
                        int requiredScore = (EcoQuestGame.targetHighScore * 0.6).toInt();
                        return Column(
                          children: [
                            Text(
                              'Your Score',
                              style: GoogleFonts.vt323(
                                fontSize: bodyFontSize * 0.9,
                                color: Colors.white70,
                              ),
                            ),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                '$score / $requiredScore',
                                style: GoogleFonts.lobster(
                                  fontSize: scoreFontSize,
                                  color: Colors.amber,
                                ),
                              ),
                            ),
                            SizedBox(height: spacing1),
                            Text(
                              'Score ${requiredScore - score} more points to collect materials!',
                              style: GoogleFonts.vt323(
                                fontSize: bodyFontSize * 0.85,
                                color: Colors.white60,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        );
                      },
                    ),
                    
                    SizedBox(height: spacing3),
                    
                    // Icon-based action buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildIconActionButton(
                          icon: Icons.refresh,
                          label: 'Retry',
                          color: Colors.green,
                          iconSize: buttonIconSize,
                          onPressed: () {
                            game.restartGame();
                          },
                        ),
                        _buildIconActionButton(
                          icon: Icons.exit_to_app,
                          label: 'Exit',
                          color: Colors.red[700]!,
                          iconSize: buttonIconSize,
                          onPressed: () async {
                            await SystemChannels.platform.invokeMethod('SystemNavigator.pop');
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Calculate responsive dimensions
                double dialogWidth = constraints.maxWidth * 0.85;
                double dialogMaxWidth = 450;
                dialogWidth = dialogWidth.clamp(280.0, dialogMaxWidth);
                
                double iconSize = constraints.maxWidth * 0.12;
                iconSize = iconSize.clamp(50.0, 80.0);
                
                double titleFontSize = constraints.maxWidth * 0.08;
                titleFontSize = titleFontSize.clamp(28.0, 42.0);
                
                double bodyFontSize = constraints.maxWidth * 0.035;
                bodyFontSize = bodyFontSize.clamp(14.0, 18.0);
                
                double scoreFontSize = constraints.maxWidth * 0.075;
                scoreFontSize = scoreFontSize.clamp(24.0, 38.0);
                
                double buttonIconSize = constraints.maxWidth * 0.055;
                buttonIconSize = buttonIconSize.clamp(22.0, 32.0);
                
                return Container(
                  width: dialogWidth,
                  margin: EdgeInsets.symmetric(
                    horizontal: constraints.maxWidth * 0.05,
                    vertical: constraints.maxHeight * 0.05,
                  ),
                  padding: EdgeInsets.all(constraints.maxWidth * 0.05),
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
                        color: Colors.red.withValues(alpha: 0.6),
                        blurRadius: 30,
                        spreadRadius: 8,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.warning_amber,
                        size: iconSize,
                        color: Colors.red[300],
                      ),
                      SizedBox(height: constraints.maxHeight * 0.015),
                      
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          "TIME'S UP!",
                          style: GoogleFonts.vt323(
                            fontSize: titleFontSize,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                      
                      SizedBox(height: constraints.maxHeight * 0.01),
                      
                      Text(
                        'The forest could not be fully restored in time.',
                        style: GoogleFonts.vt323(
                          fontSize: bodyFontSize,
                          color: Colors.white70,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      
                      SizedBox(height: constraints.maxHeight * 0.015),
                      
                      ValueListenableBuilder<int>(
                        valueListenable: scoreNotifier,
                        builder: (ctx, score, _) {
                          return Column(
                            children: [
                              Text(
                                'EcoPoints Earned',
                                style: GoogleFonts.vt323(
                                  fontSize: bodyFontSize * 0.9,
                                  color: Colors.white70,
                                ),
                              ),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  '$score',
                                  style: GoogleFonts.lobster(
                                    fontSize: scoreFontSize,
                                    color: Colors.amber,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      
                      SizedBox(height: constraints.maxHeight * 0.02),
                      
                      // Icon-based action buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildIconActionButton(
                            icon: Icons.refresh,
                            label: 'Retry',
                            color: Colors.green,
                            iconSize: buttonIconSize,
                            onPressed: () {
                              game.restartGame();
                            },
                          ),
                          _buildIconActionButton(
                            icon: Icons.exit_to_app,
                            label: 'Exit',
                            color: Colors.red[700]!,
                            iconSize: buttonIconSize,
                            onPressed: () async {
                              await SystemChannels.platform.invokeMethod('SystemNavigator.pop');
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  // Helper method for icon-based action buttons
  Widget _buildIconActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required double iconSize,
    required VoidCallback onPressed,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: EdgeInsets.all(iconSize * 0.4),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                icon,
                size: iconSize,
                color: Colors.white,
              ),
            ),
          ),
        ),
        SizedBox(height: iconSize * 0.2),
        Text(
          label,
          style: GoogleFonts.vt323(
            fontSize: iconSize * 0.5,
            color: Colors.white,
            letterSpacing: 1,
          ),
        ),
      ],
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
class EnvironmentalProgressPanel extends StatefulWidget {
  const EnvironmentalProgressPanel({super.key});

  @override
  State<EnvironmentalProgressPanel> createState() => _EnvironmentalProgressPanelState();
}

// Environmental Progress Panel with Forest Image Updates
class _EnvironmentalProgressPanelState extends State<EnvironmentalProgressPanel> {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
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
          
          return LayoutBuilder(
            builder: (context, constraints) {
              // Detect if portrait/mobile layout
              bool isPortrait = constraints.maxHeight > constraints.maxWidth;
              bool isMobile = constraints.maxWidth < 600;
              
              // Scale down overlay on portrait/mobile
              double overlayScale = (isPortrait || isMobile) ? 0.65 : 1.0;
              
              // Calculate responsive font sizes with portrait scaling
              double titleFontSize = constraints.maxWidth * 0.06 * overlayScale;
              double percentageFontSize = constraints.maxWidth * 0.08 * overlayScale;
              double scoreFontSize = constraints.maxWidth * 0.045 * overlayScale;
              
              // Clamp font sizes for readability
              titleFontSize = titleFontSize.clamp(12.0, 28.0);
              percentageFontSize = percentageFontSize.clamp(16.0, 36.0);
              scoreFontSize = scoreFontSize.clamp(11.0, 20.0);
              
              // Adjust padding for portrait/mobile
              double horizontalPadding = constraints.maxWidth * (overlayScale * 0.06);
              double verticalPadding = constraints.maxHeight * (overlayScale * 0.025);
              
              return Stack(
                fit: StackFit.expand,
                children: [
                  // Background animated forest images with crossfade - FILLS ENTIRE SPACE
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 800),
                    switchInCurve: Curves.easeIn,
                    switchOutCurve: Curves.easeOut,
                    child: Image.asset(
                      'assets/images/forest_$imageIndex.png',
                      key: ValueKey<int>(imageIndex),
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.brown.shade800,
                          child: Center(
                            child: Icon(
                              Icons.image_not_supported, 
                              color: Colors.white54, 
                              size: constraints.maxWidth * 0.15,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  
                  // Floating stats overlay - SCALED DOWN ON PORTRAIT/MOBILE
                  Positioned(
                    left: constraints.maxWidth * 0.05,
                    right: constraints.maxWidth * 0.05,
                    bottom: constraints.maxHeight * 0.08,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        vertical: verticalPadding,
                        horizontal: horizontalPadding,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(12 * overlayScale),
                        border: Border.all(
                          color: Colors.amber.withValues(alpha: 0.6),
                          width: 2 * overlayScale,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 15 * overlayScale,
                            offset: Offset(0, 4 * overlayScale),
                          )
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '${((score / EcoQuestGame.targetHighScore) * 100).clamp(0, 100).toInt()}% Restored',
                              style: GoogleFonts.vt323(
                                fontSize: percentageFontSize,
                                color: Colors.amber,
                                fontWeight: FontWeight.bold,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withValues(alpha: 0.8),
                                    offset: Offset(2 * overlayScale, 2 * overlayScale),
                                    blurRadius: 4 * overlayScale,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(height: constraints.maxHeight * 0.01 * overlayScale),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'Score: $score / ${EcoQuestGame.targetHighScore}',
                              style: GoogleFonts.vt323(
                                fontSize: scoreFontSize,
                                color: Colors.white,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withValues(alpha: 0.8),
                                    offset: Offset(1 * overlayScale, 1 * overlayScale),
                                    blurRadius: 3 * overlayScale,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
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
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Get screen constraints
            double screenWidth = MediaQuery.of(context).size.width;
            double screenHeight = MediaQuery.of(context).size.height;
            
            // Calculate responsive dimensions
            double dialogWidth = screenWidth * 0.85;
            dialogWidth = dialogWidth.clamp(280.0, 450.0);
            
            double iconSize = screenWidth * 0.12;
            iconSize = iconSize.clamp(40.0, 70.0);
            
            double titleFontSize = screenWidth * 0.055;
            titleFontSize = titleFontSize.clamp(18.0, 28.0);
            
            double bodyFontSize = screenWidth * 0.035;
            bodyFontSize = bodyFontSize.clamp(12.0, 16.0);
            
            double valueFontSize = screenWidth * 0.055;
            valueFontSize = valueFontSize.clamp(16.0, 22.0);
            
            double buttonIconSize = screenWidth * 0.05;
            buttonIconSize = buttonIconSize.clamp(18.0, 28.0);
            
            // Responsive spacing
            double spacing1 = screenHeight * 0.01;
            double spacing2 = screenHeight * 0.015;
            double spacing3 = screenHeight * 0.02;
            
            return SingleChildScrollView(
              child: Container(
                width: dialogWidth,
                margin: EdgeInsets.symmetric(
                  horizontal: screenWidth * 0.05,
                  vertical: screenHeight * 0.05,
                ),
                padding: EdgeInsets.all(screenWidth * 0.05),
                decoration: BoxDecoration(
                  color: const Color(0xFF2D1E17),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.green, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withValues(alpha: 0.4),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Phase 2 Complete!',
                        style: GoogleFonts.vt323(
                          color: Colors.white,
                          fontSize: titleFontSize,
                        ),
                      ),
                    ),
                    SizedBox(height: spacing1),
                    
                    Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: iconSize,
                    ),
                    SizedBox(height: spacing1),
                    
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Dye Produced: $dyeProduced ml',
                        style: GoogleFonts.vt323(
                          color: Colors.amber,
                          fontSize: valueFontSize,
                        ),
                      ),
                    ),
                    SizedBox(height: spacing1 * 0.5),
                    
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Value: ${dyeValue.toStringAsFixed(1)} EcoCoins',
                        style: GoogleFonts.vt323(
                          color: Colors.green,
                          fontSize: valueFontSize,
                        ),
                      ),
                    ),
                    SizedBox(height: spacing2),
                    
                    Text(
                      'This dye can be used for avatar customization and will be carried forward to future levels!',
                      style: GoogleFonts.vt323(
                        color: Colors.white70,
                        fontSize: bodyFontSize,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: spacing3),
                    
                    // Icon-based action buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildCompactIconButton(
                          icon: Icons.refresh,
                          label: 'Replay',
                          color: Colors.orange,
                          iconSize: buttonIconSize,
                          onPressed: () {
                            Navigator.pop(ctx);
                            widget.game.restartGame();
                          },
                        ),
                        _buildCompactIconButton(
                          icon: Icons.exit_to_app,
                          label: 'Exit',
                          color: Colors.red,
                          iconSize: buttonIconSize,
                          onPressed: () async {
                            Navigator.pop(ctx);
                            await SystemChannels.platform.invokeMethod('SystemNavigator.pop');
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // Helper method for compact icon buttons in DyeExtractionOverlay
  Widget _buildCompactIconButton({
    required IconData icon,
    required String label,
    required Color color,
    required double iconSize,
    required VoidCallback onPressed,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: EdgeInsets.all(iconSize * 0.4),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(
                icon,
                size: iconSize,
                color: Colors.white,
              ),
            ),
          ),
        ),
        SizedBox(height: iconSize * 0.15),
        Text(
          label,
          style: GoogleFonts.vt323(
            fontSize: iconSize * 0.5,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha:0.95),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Use a fraction of the available height for top/bottom parts
            final double topHeight = constraints.maxHeight * 0.22;   // header + progress
            final double buttonHeight = 56;
            // paddings
            return Padding(
              padding: const EdgeInsets.all(12.0), // smaller global padding
              child: Column(
                children: [
                  SizedBox(
                    height: topHeight * 0.55,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FittedBox(
                          child: Text(
                            'DYE EXTRACTION PROCESS',
                            style: GoogleFonts.vt323(
                              fontSize: 28,
                              color: Colors.amber,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Phase 2 of 2',
                          style: GoogleFonts.vt323(fontSize: 16, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),

                  // ── Progress Indicator (scrollable horizontally) ─────────────
                  SizedBox(
                    height: topHeight * 0.45,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(stepTitles.length, (index) {
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: index <= currentStep ? Colors.green : Colors.grey.shade700,
                                  border: Border.all(
                                    color: index == currentStep ? Colors.amber : Colors.transparent,
                                    width: 3,
                                  ),
                                ),
                                child: Icon(
                                  index < currentStep ? Icons.check : stepIcons[index],
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              if (index < stepTitles.length - 1)
                                Container(
                                  width: 36,
                                  height: 2,
                                  color: index < currentStep ? Colors.green : Colors.grey.shade700,
                                  margin: const EdgeInsets.symmetric(horizontal: 6),
                                ),
                            ],
                          );
                        }),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ── Main Content (takes whatever is left) ─────────────────────
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.green.shade900, Colors.green.shade700],
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
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(stepIcons[currentStep], size: 72, color: Colors.amber),
                            const SizedBox(height: 16),
                            Text(
                              stepTitles[currentStep],
                              style: GoogleFonts.vt323(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              stepDescriptions[currentStep],
                              style: GoogleFonts.vt323(fontSize: 15, color: Colors.white70),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            if (currentStep == 0)
                              ValueListenableBuilder<int>(
                                valueListenable: plantsCollectedNotifier,
                                builder: (ctx, plants, _) => Text(
                                  'Materials Available: $plants units',
                                  style: GoogleFonts.vt323(fontSize: 19, color: Colors.amber),
                                ),
                              ),
                            if (currentStep == 4)
                              Column(
                                children: [
                                  Text(
                                    'Dye Produced: $dyeProduced ml',
                                    style: GoogleFonts.vt323(fontSize: 21, color: Colors.amber, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Estimated Value: ${dyeValue.toStringAsFixed(1)} EcoCoins',
                                    style: GoogleFonts.vt323(fontSize: 17, color: Colors.green.shade300),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ── Action Button (fixed height) ─────────────────────────────
                  SizedBox(
                    height: buttonHeight,
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _nextStep,
                      icon: Icon(
                        currentStep < stepTitles.length - 1 ? Icons.arrow_forward : Icons.check_circle,
                        size: 26,
                      ),
                      label: Text(
                        currentStep < stepTitles.length - 1 ? 'NEXT STEP' : 'COMPLETE',
                        style: GoogleFonts.vt323(fontSize: 22, letterSpacing: 1.5),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: currentStep < stepTitles.length - 1 ? Colors.amber : Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 8,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}