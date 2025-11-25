import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'eco_quest_game.dart';

// REMOVED TileComponent - No longer needed!
// Items render directly on the background

class EcoItem extends SpriteComponent with DragCallbacks, HasGameReference<EcoQuestGame> {
  final String type;
  Point gridPosition = const Point(0, 0);
  bool isSelected = false;
  final double sizeVal;

  EcoItem({required this.type, required this.sizeVal});

  @override
  Future<void> onLoad() async {
    try {
      sprite = await game.loadSprite('$type.png');
      debugPrint("✅ Loaded sprite: $type");
    } catch (e) {
      debugPrint("❌ Failed to load image for $type: $e");
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    if (isSelected) {
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
  
  // SWIPE INPUT - Quick response
  Vector2 dragDelta = Vector2.zero();

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    dragDelta = Vector2.zero();
    game.onDragStart(this);
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    super.onDragUpdate(event);
    dragDelta += event.localDelta;
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    game.onDragEnd(dragDelta);
  }
}