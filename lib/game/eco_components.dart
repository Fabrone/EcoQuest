import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'eco_quest_game.dart';

class TileComponent extends PositionComponent {
  Point gridPosition = const Point(0, 0);
  bool isRestored = false;
  final double sizeVal;

  TileComponent({this.sizeVal = 64.0});

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    
    final paint = Paint()
      ..color = isRestored ? const Color(0xFF388E3C) : const Color(0xFF5D4037)
      ..style = PaintingStyle.fill;
    
    // FIXED: withOpacity -> withValues
    final border = Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    Rect rect = size.toRect();
    canvas.drawRect(rect, paint);
    canvas.drawRect(rect, border);
  }

  void restoreNature() {
    isRestored = true;
  }
}

// FIXED: HasGameRef -> HasGameReference
class EcoItem extends SpriteComponent with TapCallbacks, HasGameReference<EcoQuestGame> {
  final String type;
  Point gridPosition = const Point(0, 0);
  bool isSelected = false;
  final double sizeVal;

  EcoItem({required this.type, required this.sizeVal});

  @override
  Future<void> onLoad() async {
    try {
      // FIXED: gameRef -> game
      sprite = await game.loadSprite('$type.png');
    } catch (e) {
      debugPrint("Failed to load image for $type: $e");
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    if (isSelected) {
      // FIXED: withOpacity -> withValues
      final highlight = Paint()
        ..color = Colors.white.withValues(alpha: 0.4) 
        ..style = PaintingStyle.fill;
      
      canvas.drawCircle(Offset(size.x/2, size.y/2), size.x/3, highlight);
      
      final border = Paint()
        ..color = Colors.yellow
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0;
      canvas.drawRect(size.toRect(), border);
    }
  }

  @override
  void onTapUp(TapUpEvent event) {
    // FIXED: gameRef -> game
    game.onTileTapped(this);
  }
}