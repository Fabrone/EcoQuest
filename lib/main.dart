import 'dart:math';
import 'package:ecoquest/game/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'package:flutter/services.dart';
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
      home: const SplashScreen(), 
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;
        final shouldExit = await _showExitDialog(context);
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
        // Enhanced parallax background
        Positioned.fill(
          child: _buildParallaxBackground(),
        ),

        Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: _buildEnhancedHeader(),
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

  Widget _buildParallaxBackground() {
    return Stack(
      children: [
        // Base gradient layer
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF1B5E20).withValues(alpha: 0.4),
                const Color(0xFF2D1E17).withValues(alpha: 0.6),
                const Color(0xFF4A2511).withValues(alpha: 0.4),
              ],
            ),
          ),
        ),
        
        // Texture overlay
        Opacity(
          opacity: 0.1,
          child: Image.asset(
            'assets/images/tile_bg.png',
            repeat: ImageRepeat.repeat,
            fit: BoxFit.none,
          ),
        ),
        
        // Ambient particles layer
        CustomPaint(
          painter: AmbientParticlesPainter(),
        ),
        
        // Grid pattern
        CustomPaint(
          painter: EnhancedGridPatternPainter(),
        ),
      ],
    );
  }

  Widget _buildEnhancedHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF5D4E37).withValues(alpha: 0.9),
            const Color(0xFF3E2723).withValues(alpha: 0.95),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFD4AF37),
          width: 3,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD4AF37).withValues(alpha: 0.3),
            blurRadius: 12,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 8,
            offset: const Offset(0, 4),
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
                builder: (ctx, level, _) => _buildStoneCompartment('LVL', '$level', Colors.amber),
              ),
              
              _buildCarvedDivider(),

              _buildStoneCompartment('PTS', '$score', const Color(0xFF4CAF50)),

              _buildCarvedDivider(),

              ValueListenableBuilder<int>(
                valueListenable: levelTimeNotifier,
                builder: (ctx, time, _) => _buildStoneCompartment(
                  'TIME', 
                  '${time}s', 
                  time <= 10 ? Colors.red : const Color(0xFF64B5F6)
                ),
              ),

              _buildCarvedDivider(),

              _buildStoneButton(
                icon: Icons.lightbulb, 
                color: Colors.amber, 
                onTap: () {
                  if (game.hintsRemaining > 0 && !game.isProcessing) {
                    game.useHint();
                  }
                }
              ),

              _buildStoneButton(
                icon: Icons.refresh, 
                color: Colors.orange, 
                onTap: () => _showRestartDialog(context, game)
              ),

              _buildStoneButton(
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

  Widget _buildStoneCompartment(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF5D4E37).withValues(alpha: 0.8),
            const Color(0xFF3E2723).withValues(alpha: 0.9),
          ],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withValues(alpha: 0.5),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 4,
            offset: const Offset(2, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.vt323(
              color: Colors.white60,
              fontSize: 12,
              height: 1,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.vt323(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              height: 1.1,
              shadows: [
                Shadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  offset: const Offset(1, 1),
                  blurRadius: 2,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoneButton({required IconData icon, required Color color, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withValues(alpha: 0.9),
                color.withValues(alpha: 0.7),
              ],
            ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: color.withValues(alpha: 0.6),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 4,
                offset: const Offset(2, 2),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }

  Widget _buildCarvedDivider() {
    return Container(
      height: 32,
      width: 2,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            const Color(0xFFD4AF37).withValues(alpha: 0.5),
            Colors.transparent,
          ],
        ),
      ),
    );
  }

  Widget _buildStyledGameBoard() {
    return Container(
      decoration: BoxDecoration(
        // Stone tablet frame
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF5D4E37),
            Color(0xFF8B7355),
            Color(0xFF5D4E37),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFD4AF37),
          width: 6.0,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD4AF37).withValues(alpha: 0.2),
            blurRadius: 30,
            spreadRadius: 4,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Inner frame decoration
          Positioned.fill(
            child: Container(
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF3E2723).withValues(alpha: 0.5),
                  width: 2,
                ),
              ),
            ),
          ),
          
          // Corner ornaments
          ..._buildCornerOrnaments(),
          
          // Game content
          Padding(
            padding: const EdgeInsets.all(16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF2D1E17).withValues(alpha: 0.3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                      spreadRadius: -2,
                    ),
                  ],
                ),
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
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildCornerOrnaments() {
    return [
      // Top-left
      Positioned(
        top: 4,
        left: 4,
        child: _buildOrnament(),
      ),
      // Top-right
      Positioned(
        top: 4,
        right: 4,
        child: Transform.rotate(
          angle: pi / 2,
          child: _buildOrnament(),
        ),
      ),
      // Bottom-left
      Positioned(
        bottom: 4,
        left: 4,
        child: Transform.rotate(
          angle: -pi / 2,
          child: _buildOrnament(),
        ),
      ),
      // Bottom-right
      Positioned(
        bottom: 4,
        right: 4,
        child: Transform.rotate(
          angle: pi,
          child: _buildOrnament(),
        ),
      ),
    ];
  }

  Widget _buildOrnament() {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        gradient: RadialGradient(
          colors: [
            const Color(0xFFD4AF37),
            const Color(0xFFCD7F32),
          ],
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD4AF37).withValues(alpha: 0.4),
            blurRadius: 8,
          ),
        ],
      ),
      child: const Icon(
        Icons.spa,
        color: Color(0xFF2E7D32),
        size: 18,
      ),
    );
  }

  Widget _buildPhaseCompleteDialog(BuildContext context, EcoQuestGame game) {
    return Container(
      color: Colors.black.withValues(alpha: 0.92),
      child: Center(
        child: LayoutBuilder(
          builder: (context, constraints) {
            double dialogWidth = constraints.maxWidth * 0.85;
            dialogWidth = dialogWidth.clamp(280.0, 420.0);
            
            double iconSize = constraints.maxWidth * 0.10;
            iconSize = iconSize.clamp(40.0, 65.0);
            
            double titleFontSize = constraints.maxWidth * 0.065;
            titleFontSize = titleFontSize.clamp(20.0, 32.0);
            
            double bodyFontSize = constraints.maxWidth * 0.035;
            bodyFontSize = bodyFontSize.clamp(12.0, 15.0);
            
            double valueFontSize = constraints.maxWidth * 0.06;
            valueFontSize = valueFontSize.clamp(18.0, 28.0);
            
            double buttonIconSize = constraints.maxWidth * 0.045;
            buttonIconSize = buttonIconSize.clamp(20.0, 28.0);
            
            double spacing = constraints.maxHeight * 0.012;
            spacing = spacing.clamp(8.0, 15.0);
            
            return SingleChildScrollView(
              child: Container(
                width: dialogWidth,
                constraints: BoxConstraints(
                  maxHeight: constraints.maxHeight * 0.85,
                ),
                margin: EdgeInsets.symmetric(
                  horizontal: constraints.maxWidth * 0.06,
                  vertical: constraints.maxHeight * 0.08,
                ),
                padding: EdgeInsets.all(constraints.maxWidth * 0.045),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF1B5E20),
                      const Color(0xFF2E7D32),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.amber, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withValues(alpha: 0.5),
                      blurRadius: 25,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.park, size: iconSize, color: Colors.amber),
                    SizedBox(height: spacing),
                    
                    Text(
                      "FOREST RESTORED!",
                      style: GoogleFonts.exo2(
                        fontSize: titleFontSize,
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    
                    SizedBox(height: spacing * 1.2),
                    
                    ValueListenableBuilder<int>(
                      valueListenable: plantsCollectedNotifier,
                      builder: (ctx, plants, _) {
                        return Container(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.amber.withValues(alpha: 0.4),
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                'Plant Materials Collected',
                                style: GoogleFonts.exo2(
                                  fontSize: bodyFontSize,
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                '$plants units',
                                style: GoogleFonts.exo2(
                                  fontSize: valueFontSize,
                                  color: Colors.amber,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    
                    SizedBox(height: spacing),
                    
                    Text(
                      'All tiles restored! Ready for dye extraction.',
                      style: GoogleFonts.exo2(
                        fontSize: bodyFontSize,
                        color: Colors.white.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    
                    SizedBox(height: spacing * 1.5),
                    
                    SizedBox(
                      width: double.infinity,
                      child: _buildCompactButton(
                        icon: Icons.arrow_forward_rounded,
                        label: 'Proceed',
                        color: Colors.amber.shade700,
                        iconSize: buttonIconSize,
                        onPressed: () {
                          game.startNextLevel();
                        },
                      ),
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
            double dialogWidth = constraints.maxWidth * 0.85;
            dialogWidth = dialogWidth.clamp(280.0, 420.0);
            
            double iconSize = constraints.maxWidth * 0.10;
            iconSize = iconSize.clamp(45.0, 65.0);
            
            double titleFontSize = constraints.maxWidth * 0.065;
            titleFontSize = titleFontSize.clamp(20.0, 32.0);
            
            double bodyFontSize = constraints.maxWidth * 0.035;
            bodyFontSize = bodyFontSize.clamp(12.0, 15.0);
            
            double scoreFontSize = constraints.maxWidth * 0.06;
            scoreFontSize = scoreFontSize.clamp(18.0, 28.0);
            
            double buttonIconSize = constraints.maxWidth * 0.045;
            buttonIconSize = buttonIconSize.clamp(20.0, 28.0);
            
            double spacing = constraints.maxHeight * 0.012;
            spacing = spacing.clamp(8.0, 15.0);
            
            return SingleChildScrollView(
              child: Container(
                width: dialogWidth,
                constraints: BoxConstraints(
                  maxHeight: constraints.maxHeight * 0.85,
                ),
                margin: EdgeInsets.symmetric(
                  horizontal: constraints.maxWidth * 0.06,
                  vertical: constraints.maxHeight * 0.08,
                ),
                padding: EdgeInsets.all(constraints.maxWidth * 0.045),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFE65100),
                      const Color(0xFFFF6F00),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.amber, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withValues(alpha: 0.5),
                      blurRadius: 25,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.warning_amber_rounded, size: iconSize, color: Colors.white),
                    SizedBox(height: spacing),
                    
                    Text(
                      "NEED MORE TIME!",
                      style: GoogleFonts.exo2(
                        fontSize: titleFontSize,
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    
                    SizedBox(height: spacing * 0.8),
                    
                    Text(
                      'Limited materials collected. Complete faster next time!',
                      style: GoogleFonts.exo2(
                        fontSize: bodyFontSize,
                        color: Colors.white.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    
                    SizedBox(height: spacing * 1.2),
                    
                    ValueListenableBuilder<int>(
                      valueListenable: plantsCollectedNotifier,
                      builder: (ctx, plants, _) {
                        return Container(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.amber.withValues(alpha: 0.4),
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                'Materials Collected',
                                style: GoogleFonts.exo2(
                                  fontSize: bodyFontSize * 0.9,
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                '$plants units',
                                style: GoogleFonts.exo2(
                                  fontSize: scoreFontSize,
                                  color: Colors.amber,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    
                    SizedBox(height: spacing * 1.5),
                    
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildCompactButton(
                              icon: Icons.refresh_rounded,
                              label: 'Retry',
                              color: const Color(0xFF2E7D32),
                              iconSize: buttonIconSize,
                              onPressed: () {
                                game.restartGame();
                              },
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: _buildCompactButton(
                              icon: Icons.exit_to_app_rounded,
                              label: 'Exit',
                              color: const Color(0xFF6D4C41),
                              iconSize: buttonIconSize,
                              onPressed: () async {
                                await SystemChannels.platform.invokeMethod('SystemNavigator.pop');
                              },
                            ),
                          ),
                        ],
                      ),
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
                // Better responsive sizing
                double dialogWidth = constraints.maxWidth * 0.88;
                dialogWidth = dialogWidth.clamp(280.0, 420.0); // Reduced max width
                
                double iconSize = constraints.maxWidth * 0.10;
                iconSize = iconSize.clamp(45.0, 65.0);
                
                double titleFontSize = constraints.maxWidth * 0.07;
                titleFontSize = titleFontSize.clamp(24.0, 36.0);
                
                double bodyFontSize = constraints.maxWidth * 0.038;
                bodyFontSize = bodyFontSize.clamp(13.0, 16.0);
                
                double scoreFontSize = constraints.maxWidth * 0.065;
                scoreFontSize = scoreFontSize.clamp(20.0, 32.0);
                
                double buttonIconSize = constraints.maxWidth * 0.045;
                buttonIconSize = buttonIconSize.clamp(20.0, 28.0);
                
                // Adaptive spacing based on screen height
                double spacing = constraints.maxHeight * 0.012;
                spacing = spacing.clamp(8.0, 15.0);
                
                return SingleChildScrollView(
                  child: Container(
                    width: dialogWidth,
                    constraints: BoxConstraints(
                      maxHeight: constraints.maxHeight * 0.85, // Prevent overflow
                    ),
                    margin: EdgeInsets.symmetric(
                      horizontal: constraints.maxWidth * 0.06,
                      vertical: constraints.maxHeight * 0.08,
                    ),
                    padding: EdgeInsets.all(constraints.maxWidth * 0.045),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF8B0000), // Dark red
                          const Color(0xFFB22222), // Firebrick red
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFFF6347), width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withValues(alpha: 0.5),
                          blurRadius: 25,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.access_time_filled, size: iconSize, color: Colors.amber),
                        SizedBox(height: spacing),
                        
                        Text(
                          "TIME'S UP!",
                          style: GoogleFonts.exo2( // Modern font
                            fontSize: titleFontSize,
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        
                        SizedBox(height: spacing * 0.8),
                        
                        Text(
                          'Forest restoration incomplete.',
                          style: GoogleFonts.exo2(
                            fontSize: bodyFontSize,
                            color: Colors.white.withValues(alpha: 0.9),
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        
                        SizedBox(height: spacing * 1.2),
                        
                        // Score display
                        ValueListenableBuilder<int>(
                          valueListenable: scoreNotifier,
                          builder: (ctx, score, _) {
                            return Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.amber.withValues(alpha: 0.4),
                                  width: 1.5,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    'EcoPoints Earned',
                                    style: GoogleFonts.exo2(
                                      fontSize: bodyFontSize * 0.85,
                                      color: Colors.white70,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    '$score',
                                    style: GoogleFonts.exo2(
                                      fontSize: scoreFontSize,
                                      color: Colors.amber,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        
                        SizedBox(height: spacing * 1.5),
                        
                        // Fixed button layout for small screens
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Expanded(
                                child: _buildCompactButton(
                                  icon: Icons.refresh_rounded,
                                  label: 'Retry',
                                  color: const Color(0xFF2E7D32),
                                  iconSize: buttonIconSize,
                                  onPressed: () {
                                    game.restartGame();
                                  },
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: _buildCompactButton(
                                  icon: Icons.exit_to_app_rounded,
                                  label: 'Exit',
                                  color: const Color(0xFF6D4C41),
                                  iconSize: buttonIconSize,
                                  onPressed: () async {
                                    await SystemChannels.platform.invokeMethod('SystemNavigator.pop');
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildCompactButton({
    required IconData icon,
    required String label,
    required Color color,
    required double iconSize,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.symmetric(
            vertical: iconSize * 0.5,
            horizontal: 8,
          ),
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: iconSize, color: Colors.white),
              SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.exo2(
                  fontSize: iconSize * 0.45,
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /*Widget _buildIconActionButton({
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
              child: Icon(icon, size: iconSize, color: Colors.white),
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
  }*/

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

// Enhanced Environmental Progress Panel with ornate frame
class EnvironmentalProgressPanel extends StatefulWidget {
  const EnvironmentalProgressPanel({super.key});

  @override
  State<EnvironmentalProgressPanel> createState() => _EnvironmentalProgressPanelState();
}

class _EnvironmentalProgressPanelState extends State<EnvironmentalProgressPanel> {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        // Ornate frame border
        border: Border.all(
          color: const Color(0xFFD4AF37),
          width: 8,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD4AF37).withValues(alpha: 0.3),
            blurRadius: 20,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ValueListenableBuilder<int>(
        valueListenable: scoreNotifier,
        builder: (context, score, _) {
          int imageIndex = 0;
          
          final gameScreen = context.findAncestorStateOfType<_GameScreenState>();
          if (gameScreen != null) {
            imageIndex = gameScreen.game.getForestImageIndex();
          }
          
          return LayoutBuilder(
            builder: (context, constraints) {
              bool isPortrait = constraints.maxHeight > constraints.maxWidth;
              bool isMobile = constraints.maxWidth < 600;
              
              double overlayScale = (isPortrait || isMobile) ? 0.7 : 1.0;
              
              double titleFontSize = constraints.maxWidth * 0.06 * overlayScale;
              double percentageFontSize = constraints.maxWidth * 0.08 * overlayScale;
              double scoreFontSize = constraints.maxWidth * 0.045 * overlayScale;
              
              titleFontSize = titleFontSize.clamp(12.0, 28.0);
              percentageFontSize = percentageFontSize.clamp(16.0, 36.0);
              scoreFontSize = scoreFontSize.clamp(11.0, 20.0);
              
              double restorationPercentage = 0.0;
              int restoredTileCount = 0;
              if (gameScreen != null) {
                restorationPercentage = gameScreen.game.getRestorationPercentage();
                for (int r = 0; r < EcoQuestGame.rows; r++) {
                  for (int c = 0; c < EcoQuestGame.cols; c++) {
                    if (gameScreen.game.restoredTiles[r][c]) {
                      restoredTileCount++;
                    }
                  }
                }
              }
              
              return Stack(
                fit: StackFit.expand,
                children: [
                  // Forest image with fade transition
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
                          color: const Color(0xFF6D4C41),
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
                  
                  // Weather overlay effects based on restoration
                  if (restorationPercentage < 30)
                    CustomPaint(
                      painter: RainEffectPainter(),
                    ),
                  
                  // Progress indicator as growing vine
                  Positioned(
                    left: constraints.maxWidth * 0.05,
                    right: constraints.maxWidth * 0.05,
                    bottom: constraints.maxHeight * 0.08,
                    child: _buildVineProgressBar(
                      restorationPercentage,
                      constraints.maxWidth,
                      overlayScale,
                    ),
                  ),
                  
                  // Stats overlay with stone tablet design
                  Positioned(
                    left: constraints.maxWidth * 0.05,
                    right: constraints.maxWidth * 0.05,
                    bottom: constraints.maxHeight * 0.15,
                    child: _buildStoneStatsOverlay(
                      restorationPercentage,
                      restoredTileCount,
                      score,
                      percentageFontSize,
                      scoreFontSize,
                      overlayScale,
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

  Widget _buildVineProgressBar(double percentage, double width, double scale) {
    return Container(
      height: 12 * scale,
      decoration: BoxDecoration(
        color: const Color(0xFF3E2723).withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(8 * scale),
        border: Border.all(
          color: const Color(0xFFD4AF37).withValues(alpha: 0.5),
          width: 2,
        ),
      ),
      child: Stack(
        children: [
          // Progress fill with vine texture
          FractionallySizedBox(
            widthFactor: percentage / 100,
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF2E7D32),
                    Color(0xFF4CAF50),
                  ],
                ),
                borderRadius: BorderRadius.circular(6 * scale),
              ),
            ),
          ),
          
          // Milestone markers
          ..._buildMilestoneMarkers(width, scale),
        ],
      ),
    );
  }

  List<Widget> _buildMilestoneMarkers(double width, double scale) {
    final milestones = [0.0, 0.25, 0.5, 0.75, 1.0];
    return milestones.map((milestone) {
      return Positioned(
        left: (width - 40 * scale) * milestone,
        top: -4 * scale,
        child: Container(
          width: 8 * scale,
          height: 20 * scale,
          decoration: BoxDecoration(
            color: const Color(0xFFD4AF37),
            borderRadius: BorderRadius.circular(4 * scale),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 4,
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  Widget _buildStoneStatsOverlay(
    double percentage,
    int tiles,
    int score,
    double percentFontSize,
    double scoreFontSize,
    double scale,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(
        vertical: 12 * scale,
        horizontal: 16 * scale,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF5D4E37).withValues(alpha: 0.85),
            const Color(0xFF3E2723).withValues(alpha: 0.9),
          ],
        ),
        borderRadius: BorderRadius.circular(12 * scale),
        border: Border.all(
          color: const Color(0xFFD4AF37).withValues(alpha: 0.6),
          width: 3,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 15,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '${percentage.toInt()}% Restored',
              style: GoogleFonts.vt323(
                fontSize: percentFontSize,
                color: const Color(0xFFD4AF37),
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.8),
                    offset: Offset(2 * scale, 2 * scale),
                    blurRadius: 4 * scale,
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 6 * scale),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'Tiles: $tiles / ${EcoQuestGame.totalTiles} | Score: $score',
              style: GoogleFonts.vt323(
                fontSize: scoreFontSize,
                color: Colors.white,
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.8),
                    offset: Offset(1 * scale, 1 * scale),
                    blurRadius: 3 * scale,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Custom Painters
class EnhancedGridPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFD4AF37).withValues(alpha: 0.05)
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

class AmbientParticlesPainter extends CustomPainter {
  final Random random = Random();
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFFD700).withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;
    
    // Draw fireflies/dust motes
    for (int i = 0; i < 20; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final radius = 1 + random.nextDouble() * 2;
      
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class RainEffectPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF64B5F6).withValues(alpha: 0.3)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    
    final random = Random(42); // Fixed seed for consistent pattern
    
    for (int i = 0; i < 50; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final length = 15 + random.nextDouble() * 10;
      
      canvas.drawLine(
        Offset(x, y),
        Offset(x + 2, y + length),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}