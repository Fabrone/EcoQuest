import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

class LevelCompleteScreen extends StatefulWidget {
  const LevelCompleteScreen({super.key});

  @override
  State<LevelCompleteScreen> createState() => _LevelCompleteScreenState();
}

class _LevelCompleteScreenState extends State<LevelCompleteScreen> {
  late LevelCompleteGame _game;

  @override
  void initState() {
    super.initState();
    _game = LevelCompleteGame(onContinue: () {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GameWidget(
        game: _game,
      ),
    );
  }
}

class LevelCompleteGame extends FlameGame {
  final VoidCallback onContinue;

  // Stats (can be passed in constructor for dynamic values)
  final double cleanliness = 85.0;
  final int ecoPoints = 850;
  final int blueprints = 2;
  final int itemsCrafted = 3;

  LevelCompleteGame({required this.onContinue});

  @override
  Future<void> onLoad() async {
    super.onLoad();

    // Background gradient (city skyline feel)
    add(RectangleComponent(
      size: size,
      paint: Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.blue[900]!, Colors.blue[600]!],
        ).createShader(Rect.fromLTWH(0, 0, size.x, size.y)),
    ));

    // City skyline silhouette (simple shapes)
    add(RectangleComponent(
      position: Vector2(0, size.y * 0.1),
      size: Vector2(size.x, size.y * 0.3),
      paint: Paint()..color = Colors.black54,
    ));

    // Title "Level Complete!"
    add(TextComponent(
      text: 'Level Complete!',
      position: Vector2(size.x / 2, 80),
      anchor: Anchor.topCenter,
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 40,
          fontWeight: FontWeight.bold,
          shadows: [Shadow(color: Colors.black87, offset: Offset(3, 3), blurRadius: 6)],
        ),
      ),
    ));

    // Subtitle "City Restored!"
    add(TextComponent(
      text: 'City Restored!',
      position: Vector2(size.x / 2, 140),
      anchor: Anchor.topCenter,
      textRenderer: TextPaint(
        style: TextStyle(
          color: Colors.yellow[700],
          fontSize: 32,
          fontWeight: FontWeight.bold,
        ),
      ),
    ));

    // Stats panel (semi-transparent dark box)
    final panelY = 200.0;
    final panelHeight = 220.0;
    add(RectangleComponent(
      position: Vector2(size.x / 2 - 200, panelY),
      size: Vector2(400, panelHeight),
      paint: Paint()..color = Colors.black.withAlpha(153), // 0.6 opacity
    ));

    // Cleanliness
    add(TextComponent(
      text: '✔ Cleanliness $cleanliness%',
      position: Vector2(size.x / 2 - 150, panelY + 40),
      anchor: Anchor.centerLeft,
      textRenderer: TextPaint(style: const TextStyle(color: Colors.white, fontSize: 24)),
    ));

    // Eco-Points
    add(TextComponent(
      text: '🌿 Eco-Points +$ecoPoints',
      position: Vector2(size.x / 2 - 150, panelY + 80),
      anchor: Anchor.centerLeft,
      textRenderer: TextPaint(style: const TextStyle(color: Colors.white, fontSize: 24)),
    ));

    // Blueprints
    add(TextComponent(
      text: '📐 Blueprints Found x$blueprints',
      position: Vector2(size.x / 2 - 150, panelY + 120),
      anchor: Anchor.centerLeft,
      textRenderer: TextPaint(style: const TextStyle(color: Colors.white, fontSize: 24)),
    ));

    // Items Crafted
    add(TextComponent(
      text: '🔨 Items Crafted x$itemsCrafted',
      position: Vector2(size.x / 2 - 150, panelY + 160),
      anchor: Anchor.centerLeft,
      textRenderer: TextPaint(style: const TextStyle(color: Colors.white, fontSize: 24)),
    ));

    // Badge section
    final badgeY = panelY + panelHeight + 40;
    add(CircleComponent(
      radius: 80,
      position: Vector2(size.x / 2, badgeY),
      anchor: Anchor.center,
      paint: Paint()..color = Colors.green[800]!,
    ));

    // Recycling symbol approximation
    final arrowPaint = Paint()..color = Colors.white;
    add(PolygonComponent(
      [Vector2(0, -40), Vector2(20, -20), Vector2(0, 20)],
      position: Vector2(size.x / 2 - 20, badgeY - 20),
      paint: arrowPaint,
    ));
    add(PolygonComponent(
      [Vector2(40, 0), Vector2(20, 20), Vector2(20, -20)],
      position: Vector2(size.x / 2 - 20, badgeY - 20),
      paint: arrowPaint,
    ));
    add(PolygonComponent(
      [Vector2(0, 40), Vector2(-20, 20), Vector2(-20, -20)],
      position: Vector2(size.x / 2 - 20, badgeY - 20),
      paint: arrowPaint,
    ));

    // Badge ribbon
    add(RectangleComponent(
      position: Vector2(size.x / 2 - 120, badgeY + 70),
      size: Vector2(240, 50),
      paint: Paint()..color = Colors.yellow[700]!,
    ));

    add(TextComponent(
      text: 'City Recycler Badge!',
      position: Vector2(size.x / 2, badgeY + 95),
      anchor: Anchor.center,
      textRenderer: TextPaint(
        style: TextStyle(color: Colors.green[900], fontSize: 24, fontWeight: FontWeight.bold),
      ),
    ));

    // Continue button
    final buttonY = size.y - 100;
    final continueButton = ContinueButton(
      position: Vector2(size.x / 2 - 150, buttonY),
      size: Vector2(300, 70),
      onTap: onContinue,
    );
    add(continueButton);

    add(TextComponent(
      text: 'Continue',
      position: Vector2(size.x / 2, buttonY + 35),
      anchor: Anchor.center,
      textRenderer: TextPaint(
        style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
      ),
    ));
  }
}

// Continue button component with proper TapCallbacks
class ContinueButton extends RectangleComponent with TapCallbacks {
  final VoidCallback onTap;

  ContinueButton({
    required Vector2 position,
    required Vector2 size,
    required this.onTap,
  }) : super(
          position: position,
          size: size,
          paint: Paint()..color = Colors.red[700]!,
        );

  @override
  void onTapDown(TapDownEvent event) {
    onTap();
  }
}