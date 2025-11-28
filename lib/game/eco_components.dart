import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'eco_quest_game.dart';

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
    // Draw tile background based on restoration state
    int r = gridPosition.x as int;
    int c = gridPosition.y as int;
    
    Paint tilePaint = Paint()
      ..style = PaintingStyle.fill;
    
    // Check if tile is restored (green) or degraded (brown)
    if (game.restoredTiles[r][c]) {
      // Green glassy tile
      tilePaint.color = Colors.green.withValues(alpha:0.3);
    } else {
      // Brown glassy tile
      tilePaint.color = Colors.brown.withValues(alpha:0.3);
    }
    
    // Draw rounded rectangle for glassy effect
    RRect rRect = RRect.fromRectAndRadius(
      size.toRect(),
      const Radius.circular(8),
    );
    canvas.drawRRect(rRect, tilePaint);
    
    // Add glossy shine effect
    Paint glossPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha:0.3),
          Colors.transparent,
          Colors.black.withValues(alpha:0.1),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(size.toRect());
    
    canvas.drawRRect(rRect, glossPaint);
    
    // Draw border
    Paint borderPaint = Paint()
      ..color = game.restoredTiles[r][c] 
          ? Colors.green.shade700.withValues(alpha:0.5)
          : Colors.brown.shade700.withValues(alpha:0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    
    canvas.drawRRect(rRect, borderPaint);
    
    // Draw sprite on top
    super.render(canvas);

    // Selection highlight
    if (isSelected) {
      final highlight = Paint()
        ..color = Colors.white.withValues(alpha:0.4) 
        ..style = PaintingStyle.fill;
      
      canvas.drawCircle(Offset(size.x/2, size.y/2), size.x/3, highlight);
      
      final border = Paint()
        ..color = Colors.yellow
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0;
      canvas.drawRect(size.toRect(), border);
    }
  }
  
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