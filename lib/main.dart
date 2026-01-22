import 'dart:math';
//import 'package:ecoquest/authentication/login_screen.dart';
import 'package:ecoquest/game/dye_extraction_screen.dart';
import 'package:ecoquest/game/splash_screen.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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
final ValueNotifier<int> materialsUpdateNotifier = ValueNotifier<int>(0);

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
      //home: const LoginScreen(), 
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

  bool _showGameOver = false;
  bool _showPhaseComplete = false;
  bool _showInsufficientMaterials = false;

  @override
  void initState() {
    super.initState();
    game = EcoQuestGame();
    
    // NEW: Listen to game state changes
    game.onGameOverCallback = () {
      setState(() {
        _showGameOver = true;
      });
    };
    
    game.onPhaseCompleteCallback = () {
      setState(() {
        _showPhaseComplete = true;
      });
    };
    
    game.onInsufficientMaterialsCallback = () {
      setState(() {
        _showInsufficientMaterials = true;
      });
    };
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
        body: Stack(  // NEW: Wrap entire body with Stack
          children: [
            // Original game layout
            LayoutBuilder(
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
            
            // NEW: Full-screen overlays
            if (_showGameOver)
              _buildFullScreenGameOverDialog(),
            
            if (_showPhaseComplete)
              _buildFullScreenPhaseCompleteDialog(),
            
            if (_showInsufficientMaterials)
              _buildFullScreenInsufficientMaterialsDialog(),
          ],
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

        // Main content with header and game area
        Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: _buildEnhancedHeader(),
            ),

            // Game Area - uses all remaining space
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: LayoutBuilder(
                  builder: (context, gameConstraints) {
                    // CHANGED: Better mobile aspect ratio
                    bool isMobile = gameConstraints.maxWidth < 600;
                    double boardAspectRatio = isMobile ? 0.75 : 1.0; // Taller on mobile
                    
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Materials Panel (18% of game area)
                        Expanded(
                          flex: 18,
                          child: ValueListenableBuilder<int>(
                            valueListenable: materialsUpdateNotifier,
                            builder: (context, _, __) => _buildMaterialsPanel(constraints),
                          ),
                        ),
                        
                        // Minimal padding between panels
                        const SizedBox(width: 4),
                        
                        // Game Board (82%)
                        Expanded(
                          flex: 82,
                          child: Center(
                            child: AspectRatio(
                              aspectRatio: boardAspectRatio, // CHANGED: Dynamic aspect ratio
                              child: _buildStyledGameBoard(),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMaterialsPanel(BoxConstraints parentConstraints) {
    // Material type configurations with emojis
    final materials = [
      {'type': 'leaf', 'emoji': '🍃', 'label': 'Leaves', 'color': const Color.fromARGB(255, 17, 125, 20)},
      {'type': 'bark', 'emoji': '🪵', 'label': 'Bark', 'color': const Color.fromARGB(255, 92, 29, 6)},
      {'type': 'root', 'emoji': '🫚', 'label': 'Roots', 'color': const Color.fromARGB(196, 238, 216, 19)},
      {'type': 'flower', 'emoji': '🌹', 'label': 'Flowers', 'color': const Color.fromARGB(255, 180, 13, 13)},
      {'type': 'fruit', 'emoji': '🫐', 'label': 'Fruits', 'color': const Color.fromARGB(255, 43, 22, 166)},
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        // FIXED: Calculate dimensions with safety margins
        final availableHeight = constraints.maxHeight;
        final headerHeight = (availableHeight * 0.08).clamp(40.0, 60.0);
        final topPadding = availableHeight * 0.012;
        final bottomPadding = availableHeight * 0.012;
        
        // Calculate ideal item height (for 6 items with spacing)
        final contentHeight = availableHeight - headerHeight - topPadding - bottomPadding;
        final idealItemHeight = contentHeight / 6.2; // Slightly reduce to account for spacing
        final itemSpacing = idealItemHeight * 0.08;
        
        // Responsive font sizes
        final titleFontSize = (constraints.maxWidth * 0.11).clamp(10.0, 16.0);
        final labelFontSize = (constraints.maxWidth * 0.08).clamp(8.0, 11.0);
        final countFontSize = (constraints.maxWidth * 0.13).clamp(14.0, 20.0);
        final emojiSize = (constraints.maxWidth * 0.16).clamp(14.0, 24.0);
        
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF5D4E37).withValues(alpha: 0.9),
                const Color(0xFF3E2723).withValues(alpha: 0.95),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFD4AF37),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFD4AF37).withValues(alpha: 0.3),
                blurRadius: 8,
                spreadRadius: 1,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            children: [
              // Header
              Container(
                height: headerHeight,
                padding: EdgeInsets.symmetric(
                  vertical: headerHeight * 0.15,
                  horizontal: constraints.maxWidth * 0.05,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(10),
                    topRight: Radius.circular(10),
                  ),
                ),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'COLLECTED',
                      style: GoogleFonts.exo2(
                        fontSize: titleFontSize,
                        color: const Color(0xFFD4AF37),
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),
              ),
              
              SizedBox(height: topPadding),
              
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: constraints.maxWidth * 0.04,
                  ),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      children: [
                        // 5 Material items
                        ...materials.map((material) => Padding(
                          padding: EdgeInsets.only(bottom: itemSpacing),
                          child: SizedBox(
                            height: idealItemHeight,
                            child: _buildMaterialItem(
                              emoji: material['emoji'] as String,
                              label: material['label'] as String,
                              type: material['type'] as String,
                              color: material['color'] as Color,
                              itemHeight: idealItemHeight,
                              labelFontSize: labelFontSize,
                              countFontSize: countFontSize,
                              emojiSize: emojiSize,
                              availableWidth: constraints.maxWidth,
                            ),
                          ),
                        )),
                        
                        // Total item
                        SizedBox(
                          height: idealItemHeight,
                          child: _buildTotalMaterialItem(
                            itemHeight: idealItemHeight,
                            labelFontSize: labelFontSize,
                            countFontSize: countFontSize,
                            emojiSize: emojiSize,
                            availableWidth: constraints.maxWidth,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              
              SizedBox(height: bottomPadding),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMaterialItem({
    required String emoji,
    required String label,
    required String type,
    required Color color,
    required double itemHeight,
    required double labelFontSize,
    required double countFontSize,
    required double emojiSize,
    required double availableWidth,
  }) {
    // Listen to game state to rebuild when materials change
    return StatefulBuilder(
      builder: (context, setState) {
        // Register a callback to update this widget when materials change
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {});
          }
        });
        
        return Container(
          height: itemHeight,
          padding: EdgeInsets.symmetric(
            vertical: itemHeight * 0.08,
            horizontal: availableWidth * 0.05,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF5D4E37).withValues(alpha: 0.6),
                const Color(0xFF3E2723).withValues(alpha: 0.7),
              ],
            ),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: color.withValues(alpha: 0.5),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 3,
                offset: const Offset(1, 1),
              ),
            ],
          ),
          child: Row(
            children: [
              // Emoji icon with responsive sizing
              SizedBox(
                width: emojiSize,
                height: emojiSize,
                child: Center(
                  child: Text(
                    emoji,
                    style: TextStyle(fontSize: emojiSize * 0.9),
                  ),
                ),
              ),
              SizedBox(width: availableWidth * 0.03),
              
              // Label and count - takes remaining space
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      flex: 6,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          label,
                          style: GoogleFonts.exo2(
                            fontSize: labelFontSize,
                            color: Colors.white70,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    Flexible(
                      flex: 4,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          '${game.materialsCollected[type] ?? 0}',
                          style: GoogleFonts.exo2(
                            fontSize: countFontSize,
                            color: color,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTotalMaterialItem({
    required double itemHeight,
    required double labelFontSize,
    required double countFontSize,
    required double emojiSize,
    required double availableWidth,
  }) {
    return StatefulBuilder(
      builder: (context, setState) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {});
          }
        });
        
        return Container(
          height: itemHeight,
          padding: EdgeInsets.symmetric(
            vertical: itemHeight * 0.08,
            horizontal: availableWidth * 0.05,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF2E7D32).withValues(alpha: 0.7),
                const Color(0xFF1B5E20).withValues(alpha: 0.8),
              ],
            ),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: const Color(0xFFD4AF37).withValues(alpha: 0.6),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 3,
                offset: const Offset(1, 1),
              ),
            ],
          ),
          child: Row(
            children: [
              // Icon
              SizedBox(
                width: emojiSize,
                height: emojiSize,
                child: Center(
                  child: Icon(
                    Icons.inventory_2,
                    size: emojiSize * 0.9,
                    color: const Color(0xFFD4AF37),
                  ),
                ),
              ),
              SizedBox(width: availableWidth * 0.03),
              
              // Label and count
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      flex: 6,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'TOTAL',
                          style: GoogleFonts.exo2(
                            fontSize: labelFontSize,
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                    Flexible(
                      flex: 4,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          '${game.getTotalMaterialsCollected()}',
                          style: GoogleFonts.exo2(
                            fontSize: countFontSize,
                            color: const Color(0xFFD4AF37),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
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

              // CHANGED: Hint button now with counter badge
              _buildHintButtonWithBadge(
                onTap: () {
                  if (game.hintsRemaining > 0 && !game.isProcessing) {
                    game.useHint();
                    setState(() {}); // Refresh to update badge
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

  Widget _buildHintButtonWithBadge({required VoidCallback onTap}) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        _buildStoneButton(
          icon: Icons.lightbulb, 
          color: game.hintsRemaining > 0 ? Colors.amber : Colors.grey,
          onTap: onTap,
        ),
        // Badge counter
        if (game.hintsRemaining > 0)
          Positioned(
            top: -4,
            right: -4,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              constraints: const BoxConstraints(
                minWidth: 18,
                minHeight: 18,
              ),
              child: Center(
                child: Text(
                  '${game.hintsRemaining}',
                  style: GoogleFonts.exo2(
                    fontSize: 11,
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
      ],
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
        // REMOVED: gradient background
        borderRadius: BorderRadius.circular(24),
        // REMOVED: Golden border
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Minimal padding, direct game rendering
          Padding(
            padding: const EdgeInsets.all(8), // Reduced padding
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF2D1E17).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: GameWidget(
                game: game,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMaterialChip(String emoji, int count, double scale) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 6 * scale,
        vertical: 3 * scale,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.amber.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: TextStyle(fontSize: 12 * scale)),
          SizedBox(width: 3 * scale),
          Text(
            '$count',
            style: GoogleFonts.exo2(
              fontSize: 11 * scale,
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFullScreenGameOverDialog() {
    return Positioned.fill(
      child: Material(
        color: Colors.black.withValues(alpha: 0.92),
        child: SafeArea(
          child: Center(
            child: LayoutBuilder(
              builder: (context, constraints) {
                double dialogWidth = constraints.maxWidth * 0.85;
                dialogWidth = dialogWidth.clamp(280.0, 420.0);
                
                double scale = (constraints.maxWidth / 400.0).clamp(0.7, 1.2);
                
                return SingleChildScrollView(
                  child: Container(
                    width: dialogWidth,
                    margin: const EdgeInsets.all(20),
                    padding: EdgeInsets.all(20 * scale),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF8B0000), Color(0xFFB22222)],
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
                        Icon(Icons.access_time_filled, size: 50 * scale, color: Colors.amber),
                        SizedBox(height: 12 * scale),
                        
                        Text(
                          "TIME'S UP!",
                          style: GoogleFonts.exo2(
                            fontSize: 28 * scale,
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        
                        SizedBox(height: 8 * scale),
                        
                        Text(
                          'Materials collected but forest restoration incomplete.',
                          style: GoogleFonts.exo2(
                            fontSize: 16 * scale,
                            color: Colors.white.withValues(alpha: 0.9),
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        
                        SizedBox(height: 16 * scale),
                        
                        // Display total materials collected from Materials Panel
                        Container(
                          padding: EdgeInsets.all(12 * scale),
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
                                  fontSize: 14 * scale,
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: 4 * scale),
                              Text(
                                '${game.getTotalMaterialsCollected()} units',
                                style: GoogleFonts.exo2(
                                  fontSize: 32 * scale,
                                  color: Colors.amber,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              SizedBox(height: 8 * scale),
                              // Breakdown by type
                              Wrap(
                                alignment: WrapAlignment.center,
                                spacing: 8 * scale,
                                runSpacing: 4 * scale,
                                children: [
                                  _buildMaterialChip('🍃', game.materialsCollected['leaf'] ?? 0, scale),
                                  _buildMaterialChip('🪵', game.materialsCollected['bark'] ?? 0, scale),
                                  _buildMaterialChip('🫚', game.materialsCollected['root'] ?? 0, scale),
                                  _buildMaterialChip('🌹', game.materialsCollected['flower'] ?? 0, scale),
                                  _buildMaterialChip('🫐', game.materialsCollected['fruit'] ?? 0, scale),
                                ],
                              ),
                            ],
                          ),
                        ),
                        
                        SizedBox(height: 20 * scale),
                        
                        Row(
                          children: [
                            Expanded(
                              child: _buildDialogButton(
                                icon: Icons.refresh_rounded,
                                label: 'Retry',
                                color: const Color(0xFF2E7D32),
                                scale: scale,
                                onPressed: () {
                                  setState(() => _showGameOver = false);
                                  // ADDED: Small delay to ensure dialog fully closes before restart
                                  Future.delayed(const Duration(milliseconds: 100), () {
                                    game.restartGame();
                                  });
                                },
                              ),
                            ),
                            SizedBox(width: 12 * scale),
                            Expanded(
                              child: _buildDialogButton(
                                icon: Icons.exit_to_app_rounded,
                                label: 'Exit',
                                color: const Color(0xFF6D4C41),
                                scale: scale,
                                onPressed: () async {
                                  await SystemChannels.platform.invokeMethod('SystemNavigator.pop');
                                },
                              ),
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
        ),
      ),
    );
  }

  Widget _buildFullScreenPhaseCompleteDialog() {
    return Positioned.fill(
      child: Material(
        color: Colors.black.withValues(alpha: 0.92),
        child: SafeArea(
          child: Center(
            child: LayoutBuilder(
              builder: (context, constraints) {
                double dialogWidth = constraints.maxWidth * 0.85;
                dialogWidth = dialogWidth.clamp(280.0, 420.0);
                
                double scale = (constraints.maxWidth / 400.0).clamp(0.7, 1.2);
                
                // Get total materials collected
                final totalMaterials = game.getTotalMaterialsCollected();
                
                return SingleChildScrollView(
                  child: Container(
                    width: dialogWidth,
                    margin: const EdgeInsets.all(20),
                    padding: EdgeInsets.all(20 * scale),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
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
                        Icon(Icons.park, size: 50 * scale, color: Colors.amber),
                        SizedBox(height: 12 * scale),
                        
                        Text(
                          "FOREST RESTORED!",
                          style: GoogleFonts.exo2(
                            fontSize: 28 * scale,
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        
                        SizedBox(height: 16 * scale),
                        
                        // Display total materials collected
                        Container(
                          padding: EdgeInsets.all(12 * scale),
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
                                'Total Materials Collected',
                                style: GoogleFonts.exo2(
                                  fontSize: 14 * scale,
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: 4 * scale),
                              Text(
                                '$totalMaterials units',
                                style: GoogleFonts.exo2(
                                  fontSize: 32 * scale,
                                  color: Colors.amber,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              SizedBox(height: 12 * scale),
                              // Material breakdown
                              Wrap(
                                alignment: WrapAlignment.center,
                                spacing: 8 * scale,
                                runSpacing: 6 * scale,
                                children: [
                                  _buildMaterialDetail('🍃 Leaves', game.materialsCollected['leaf'] ?? 0, scale),
                                  _buildMaterialDetail('🪵 Bark', game.materialsCollected['bark'] ?? 0, scale),
                                  _buildMaterialDetail('🫚 Roots', game.materialsCollected['root'] ?? 0, scale),
                                  _buildMaterialDetail('🌹 Flowers', game.materialsCollected['flower'] ?? 0, scale),
                                  _buildMaterialDetail('🫐 Fruits', game.materialsCollected['fruit'] ?? 0, scale),
                                ],
                              ),
                            ],
                          ),
                        ),
                        
                        SizedBox(height: 12 * scale),
                        
                        Text(
                          'All tiles restored! Ready for dye extraction.',
                          style: GoogleFonts.exo2(
                            fontSize: 14 * scale,
                            color: Colors.white.withValues(alpha: 0.9),
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        
                        SizedBox(height: 20 * scale),
                        
                        SizedBox(
                          width: double.infinity,
                          child: _buildDialogButton(
                            icon: Icons.arrow_forward_rounded,
                            label: 'Proceed to Phase 2',
                            color: Colors.amber.shade700,
                            scale: scale,
                            onPressed: () {
                              setState(() => _showPhaseComplete = false);
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => DyeExtractionScreen(
                                    game: game,
                                    levelTimeRemaining: game.getCompletionTime(), // Pass actual completion time
                                  ),
                                ),
                              );
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
        ),
      ),
    );
  }

  Widget _buildMaterialDetail(String label, int count, double scale) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 8 * scale,
        vertical: 4 * scale,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.amber.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Text(
        '$label: $count',
        style: GoogleFonts.exo2(
          fontSize: 11 * scale,
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildFullScreenInsufficientMaterialsDialog() {
    return Positioned.fill(
      child: Material(
        color: Colors.black.withValues(alpha: 0.92),
        child: SafeArea(
          child: Center(
            child: LayoutBuilder(
              builder: (context, constraints) {
                double dialogWidth = constraints.maxWidth * 0.85;
                dialogWidth = dialogWidth.clamp(280.0, 420.0);
                
                double scale = (constraints.maxWidth / 400.0).clamp(0.7, 1.2);
                
                // Get total materials collected
                final totalMaterials = game.getTotalMaterialsCollected();
                
                return SingleChildScrollView(
                  child: Container(
                    width: dialogWidth,
                    margin: const EdgeInsets.all(20),
                    padding: EdgeInsets.all(20 * scale),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE65100), Color(0xFFFF6F00)],
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
                        Icon(Icons.warning_amber_rounded, size: 50 * scale, color: Colors.white),
                        SizedBox(height: 12 * scale),
                        
                        Text(
                          "FOREST RESTORED!",
                          style: GoogleFonts.exo2(
                            fontSize: 28 * scale,
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        
                        SizedBox(height: 8 * scale),
                        
                        Text(
                          'Limited materials collected. Complete faster for more resources!',
                          style: GoogleFonts.exo2(
                            fontSize: 14 * scale,
                            color: Colors.white.withValues(alpha: 0.9),
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        
                        SizedBox(height: 16 * scale),
                        
                        Container(
                          padding: EdgeInsets.all(12 * scale),
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
                                  fontSize: 14 * scale,
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: 4 * scale),
                              Text(
                                '$totalMaterials units',
                                style: GoogleFonts.exo2(
                                  fontSize: 32 * scale,
                                  color: Colors.amber,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              SizedBox(height: 8 * scale),
                              Wrap(
                                alignment: WrapAlignment.center,
                                spacing: 8 * scale,
                                runSpacing: 4 * scale,
                                children: [
                                  _buildMaterialChip('🍃', game.materialsCollected['leaf'] ?? 0, scale),
                                  _buildMaterialChip('🪵', game.materialsCollected['bark'] ?? 0, scale),
                                  _buildMaterialChip('🫚', game.materialsCollected['root'] ?? 0, scale),
                                  _buildMaterialChip('🌹', game.materialsCollected['flower'] ?? 0, scale),
                                  _buildMaterialChip('🫐', game.materialsCollected['fruit'] ?? 0, scale),
                                ],
                              ),
                            ],
                          ),
                        ),
                        
                        SizedBox(height: 20 * scale),
                        
                        Row(
                          children: [
                            Expanded(
                              child: _buildDialogButton(
                                icon: Icons.refresh_rounded,
                                label: 'Retry',
                                color: const Color(0xFF2E7D32),
                                scale: scale,
                                onPressed: () {
                                  setState(() => _showInsufficientMaterials = false);
                                  // ADDED: Small delay to ensure dialog fully closes before restart
                                  Future.delayed(const Duration(milliseconds: 100), () {
                                    game.restartGame();
                                  });
                                },
                              ),
                            ),
                            SizedBox(width: 12 * scale),
                            Expanded(
                              child: _buildDialogButton(
                                icon: Icons.arrow_forward_rounded,
                                label: 'Continue',
                                color: Colors.amber.shade700,
                                scale: scale,
                                onPressed: () {
                                  setState(() => _showInsufficientMaterials = false);
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => DyeExtractionScreen(
                                        game: game,
                                        levelTimeRemaining: game.getCompletionTime(),
                                      ),
                                    ),
                                  );
                                },
                              ),
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
        ),
      ),
    );
  }

  Widget _buildDialogButton({
    required IconData icon,
    required String label,
    required Color color,
    required double scale,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: EdgeInsets.symmetric(vertical: 12 * scale),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 24 * scale, color: Colors.white),
          SizedBox(height: 4 * scale),
          Text(
            label,
            style: GoogleFonts.exo2(
              fontSize: 14 * scale,
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
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
          style: GoogleFonts.exo2(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Your current progress will be lost.',
          style: GoogleFonts.exo2( 
            color: Colors.white70,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'CANCEL',
              style: GoogleFonts.exo2( 
                fontSize: 16,
                color: Colors.grey,
                fontWeight: FontWeight.w600,
              ),
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
            child: Text(
              'RESTART',
              style: GoogleFonts.exo2( 
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
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
          style: GoogleFonts.exo2(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Are you sure you want to exit?',
          style: GoogleFonts.exo2(
            color: Colors.white70,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'CANCEL',
              style: GoogleFonts.exo2(
                fontSize: 16,
                color: Colors.grey,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx, true);
              
              // CHANGED: Platform-specific exit logic
              if (kIsWeb) {
                // For web: Go back to previous page or close tab
                if (Navigator.canPop(context)) {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                } else {
                  // Show message that user can close tab manually
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'You can close this browser tab to exit',
                        style: GoogleFonts.exo2(),
                      ),
                      duration: const Duration(seconds: 3),
                    ),
                  );
                }
              } else {
                // For mobile: Use system navigator
                await SystemChannels.platform.invokeMethod('SystemNavigator.pop');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              'EXIT',
              style: GoogleFonts.exo2(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
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
              
              double percentageFontSize = constraints.maxWidth * 0.07 * overlayScale;
              double scoreFontSize = constraints.maxWidth * 0.04 * overlayScale;
              
              percentageFontSize = percentageFontSize.clamp(14.0, 28.0);
              scoreFontSize = scoreFontSize.clamp(10.0, 16.0);
              
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
                  // CHANGED: High-quality image rendering
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
                      // ADDED: High quality rendering
                      filterQuality: FilterQuality.high,
                      isAntiAlias: true,
                      gaplessPlayback: true, // Smooth transitions
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
                  
                  // Weather overlay effects
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
                  
                  // Stats overlay - UPDATED position to be less obstructive
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: constraints.maxHeight * 0.16, // Moved up slightly
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
    return Center(
      child: IntrinsicWidth( // NEW: Wraps to content width
        child: Container(
          padding: EdgeInsets.symmetric(
            vertical: 8 * scale,
            horizontal: 12 * scale,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF5D4E37).withValues(alpha: 0.75), // Reduced from 0.85
                const Color(0xFF3E2723).withValues(alpha: 0.8), // Reduced from 0.9
              ],
            ),
            borderRadius: BorderRadius.circular(12 * scale),
            border: Border.all(
              color: const Color(0xFFD4AF37).withValues(alpha: 0.5), // Reduced from 0.6
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5), // Reduced from 0.6
                blurRadius: 12,
                offset: const Offset(0, 3),
              )
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '${percentage.toInt()}% Restored',
                style: GoogleFonts.exo2( // Changed from vt323
                  fontSize: percentFontSize,
                  color: const Color(0xFFD4AF37),
                  fontWeight: FontWeight.w900, // More modern
                  letterSpacing: 0.5,
                  shadows: [
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.8),
                      offset: Offset(1.5 * scale, 1.5 * scale),
                      blurRadius: 3 * scale,
                    ),
                  ],
                ),
              ),
              SizedBox(height: 4 * scale),
              Text(
                '$tiles / ${EcoQuestGame.totalTiles} | $score pts',
                style: GoogleFonts.exo2( // Changed from vt323
                  fontSize: scoreFontSize * 0.9,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                  shadows: [
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.8),
                      offset: Offset(1 * scale, 1 * scale),
                      blurRadius: 2 * scale,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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