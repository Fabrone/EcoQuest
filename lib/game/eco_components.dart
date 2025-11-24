import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'eco_quest_game.dart';

class TileComponent extends PositionComponent with HasGameRef<EcoQuestGame> {
  Point gridPosition = const Point(0, 0);
  bool isGold = false;

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    // Draw the tile background
    // If you have sprites: sprite?.render(canvas, ...);
    // Using Paint for prototype clarity
    final paint = Paint()
      ..color = isGold ? const Color(0xFFFFD700) : const Color(0xFF5D4037) // Gold vs Dirt
      ..style = PaintingStyle.fill;
    
    final border = Paint()
      ..color = Colors.black26
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // Draw a rect
    canvas.drawRect(size.toRect(), paint);
    canvas.drawRect(size.toRect(), border);
  }

  void turnGold() {
    isGold = true;
  }
}

class EcoItem extends SpriteComponent with TapCallbacks, HasGameRef<EcoQuestGame> {
  final String type;
  Point gridPosition = const Point(0, 0);
  bool isSelected = false;

  EcoItem({required this.type});

  @override
  Future<void> onLoad() async {
    // Try to load sprite. If asset missing, it will fail gracefully or show error.
    // Ensure 'assets/images/$type.png' exists.
    try {
      sprite = await gameRef.loadSprite('$type.png');
    } catch (e) {
      // Fallback if image is missing: Draw a colored circle
      print("Missing asset for $type");
    }
  }

  @override
  void render(Canvas canvas) {
    if (sprite == null) {
      // Fallback rendering if no sprite found
      final paint = Paint()..color = _getColorFromType(type);
      canvas.drawCircle(Offset(size.x/2, size.y/2), size.x/3, paint);
    } else {
      super.render(canvas);
    }

    // Selection Indicator
    if (isSelected) {
      final highlight = Paint()
        ..color = Colors.white.withOpacity(0.5)
        ..style = PaintingStyle.fill;
      canvas.drawRect(size.toRect(), highlight);
    }
  }

  @override
  void onTapUp(TapUpEvent event) {
    gameRef.onItemSelected(this);
  }

  Color _getColorFromType(String type) {
    switch (type) {
      case 'green_leaf': return Colors.green;
      case 'sun': return Colors.orange;
      case 'cloud': return Colors.blueAccent;
      case 'flower': return Colors.pink;
      case 'seed': return Colors.brown;
      default: return Colors.teal;
    }
  }
}