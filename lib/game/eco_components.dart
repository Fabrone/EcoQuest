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
  
  // Animation state
  double _glowAnimation = 0.0;

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
  void update(double dt) {
    super.update(dt);  // ADD THIS LINE
    
    // Animate glow effect for selected items
    if (isSelected) {
      _glowAnimation += dt * 3; // Pulse speed
      if (_glowAnimation > 2 * pi) {
        _glowAnimation -= 2 * pi;
      }
    }
  }

  @override
  void render(Canvas canvas) {
    int r = gridPosition.x as int;
    int c = gridPosition.y as int;
    
    final rect = size.toRect();
    final isRestored = game.restoredTiles[r][c];
    
    // 1. Draw 3D Beveled Tile Background
    _drawBeveledTile(canvas, rect, isRestored);
    
    // 2. Draw tile surface with texture
    _drawTileSurface(canvas, rect, isRestored);
    
    // 3. Draw main sprite FIRST (without shadow to avoid darkening)
    super.render(canvas);
    
    // 4. Draw selection effects (only if selected)
    if (isSelected) {
      _drawSelectionGlow(canvas, rect);
    }
    
    // 5. Draw glossy shine (lighter version)
    _drawGlossEffect(canvas, rect, isRestored);
  }
  
  void _drawBeveledTile(Canvas canvas, Rect rect, bool isRestored) {
    final rRect = RRect.fromRectAndRadius(rect, const Radius.circular(8));
    
    // Shadow beneath tile for 3D depth
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    
    canvas.drawRRect(
      rRect.shift(const Offset(3, 3)),
      shadowPaint,
    );
    
    // Outer bevel (darker edge)
    final outerBevelPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isRestored
            ? [
                const Color(0xFF2E7D32).withValues(alpha: 0.8),
                const Color(0xFF1B5E20).withValues(alpha: 0.9),
              ]
            : [
                const Color(0xFF5D4E37).withValues(alpha: 0.8),
                const Color(0xFF3E2723).withValues(alpha: 0.9),
              ],
      ).createShader(rect);
    
    canvas.drawRRect(rRect, outerBevelPaint);
    
    // Inner highlight for beveled effect
    final innerRect = rect.deflate(3);
    final innerRRect = RRect.fromRectAndRadius(innerRect, const Radius.circular(6));
    
    final innerBevelPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isRestored
            ? [
                const Color(0xFF4CAF50).withValues(alpha: 0.6),
                const Color(0xFF2E7D32).withValues(alpha: 0.7),
              ]
            : [
                const Color(0xFF8B7355).withValues(alpha: 0.6),
                const Color(0xFF5D4E37).withValues(alpha: 0.7),
              ],
      ).createShader(innerRect);
    
    canvas.drawRRect(innerRRect, innerBevelPaint);
  }
  
  void _drawTileSurface(Canvas canvas, Rect rect, bool isRestored) {
    final innerRect = rect.deflate(4);
    final rRect = RRect.fromRectAndRadius(innerRect, const Radius.circular(6));
    
    // Base surface color with texture
    final surfacePaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.8,
        colors: isRestored
            ? [
                const Color(0xFF66BB6A).withValues(alpha: 0.5),
                const Color(0xFF2E7D32).withValues(alpha: 0.6),
              ]
            : [
                const Color(0xFFB85C38).withValues(alpha: 0.5),
                const Color(0xFF6D4C41).withValues(alpha: 0.6),
              ],
      ).createShader(innerRect);
    
    canvas.drawRRect(rRect, surfacePaint);
    
    // Add texture pattern
    if (!isRestored) {
      // Cracked earth texture for degraded tiles
      _drawCrackedTexture(canvas, innerRect);
    } else {
      // Moss/vegetation texture for restored tiles
      _drawVegetationTexture(canvas, innerRect);
    }
  }
  
  void _drawCrackedTexture(Canvas canvas, Rect rect) {
    final crackPaint = Paint()
      ..color = const Color(0xFF3E2723).withValues(alpha: 0.2) // Reduced from 0.3
      ..strokeWidth = 1.0 // Reduced from 1.5
      ..style = PaintingStyle.stroke;
    
    // Draw only 2 cracks instead of 3 for performance
    final random = Random((gridPosition.x as int) * 100 + (gridPosition.y as int));  
    for (int i = 0; i < 2; i++) {
      final path = Path();
      final startX = rect.left + rect.width * random.nextDouble();
      final startY = rect.top + rect.height * random.nextDouble();
      path.moveTo(startX, startY);
      
      final endX = rect.left + rect.width * random.nextDouble();
      final endY = rect.top + rect.height * random.nextDouble();
      path.lineTo(endX, endY);
      
      canvas.drawPath(path, crackPaint);
    }
  }

  void _drawVegetationTexture(Canvas canvas, Rect rect) {
    final mossPaint = Paint()
      ..color = const Color(0xFF1B5E20).withValues(alpha: 0.15) // Reduced from 0.2
      ..style = PaintingStyle.fill;
    
    // Draw only 3 moss spots instead of 5 for performance
    final random = Random((gridPosition.x as int) * 50 + (gridPosition.y as int));  
    for (int i = 0; i < 3; i++) {
      final x = rect.left + rect.width * random.nextDouble();
      final y = rect.top + rect.height * random.nextDouble();
      final radius = 2 + random.nextDouble() * 2; // Reduced from 3
      
      canvas.drawCircle(Offset(x, y), radius, mossPaint);
    }
  }
    
  void _drawSelectionGlow(Canvas canvas, Rect rect) {
    // Pulsing golden aura
    final glowIntensity = (sin(_glowAnimation) * 0.3 + 0.7);
    
    // Outer glow
    final outerGlowPaint = Paint()
      ..color = Colors.amber.withValues(alpha: 0.4 * glowIntensity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect.inflate(6),
        const Radius.circular(12),
      ),
      outerGlowPaint,
    );
    
    // Inner glow
    final innerGlowPaint = Paint()
      ..color = Colors.amber.withValues(alpha: 0.6 * glowIntensity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect.inflate(3),
        const Radius.circular(10),
      ),
      innerGlowPaint,
    );
    
    // Golden border
    final borderPaint = Paint()
      ..color = Colors.amber.withValues(alpha: glowIntensity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(8)),
      borderPaint,
    );
    
    // Shimmer particles
    _drawShimmerParticles(canvas, rect, glowIntensity);
  }
    
  void _drawShimmerParticles(Canvas canvas, Rect rect, double intensity) {
    final particlePaint = Paint()
      ..color = Colors.yellow.withValues(alpha: 0.8 * intensity)
      ..style = PaintingStyle.fill;
    
    for (int i = 0; i < 3; i++) {
      final angle = _glowAnimation + (i * 2 * pi / 3);
      final distance = rect.width * 0.4;
      final x = rect.center.dx + cos(angle) * distance;
      final y = rect.center.dy + sin(angle) * distance;
      
      canvas.drawCircle(Offset(x, y), 2, particlePaint);
    }
  }
  
  void _drawGlossEffect(Canvas canvas, Rect rect, bool isRestored) {
    final rRect = RRect.fromRectAndRadius(
      rect.deflate(4),
      const Radius.circular(6),
    );
    
    final glossPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.center,
        colors: [
          Colors.white.withValues(alpha: 0.15), // Reduced from 0.25
          Colors.transparent,
        ],
        stops: const [0.0, 1.0],
      ).createShader(rect);
    
    canvas.drawRRect(rRect, glossPaint);
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

// Particle effect component for match explosions
class MatchExplosionEffect extends Component with HasGameReference<EcoQuestGame> {
  final Vector2 position;
  final String itemType;
  final List<Particle> particles = [];
  double lifetime = 0.0;
  static const double maxLifetime = 1.0;
  
  MatchExplosionEffect({required this.position, required this.itemType});
  
  @override
  Future<void> onLoad() async {
    super.onLoad();
    
    // Create particles based on item type
    final random = Random();
    for (int i = 0; i < 15; i++) {
      final angle = random.nextDouble() * 2 * pi;
      final speed = 50 + random.nextDouble() * 100;
      final velocity = Vector2(cos(angle), sin(angle)) * speed;
      
      particles.add(Particle(
        position: position.clone(),
        velocity: velocity,
        color: _getParticleColor(),
        size: 3 + random.nextDouble() * 4,
      ));
    }
  }
  
  Color _getParticleColor() {
    switch (itemType) {
      case 'rain':
        return const Color(0xFF64B5F6); // Blue
      case 'hummingbird':
        return const Color(0xFFFF6F00); // Orange
      case 'summer':
        return const Color(0xFFFDD835); // Yellow
      case 'rose':
        return const Color(0xFFEC407A); // Pink
      case 'man':
        return const Color(0xFF8D6E63); // Brown
      default:
        return const Color(0xFF4CAF50); // Green
    }
  }
  
  @override
  void update(double dt) {
    super.update(dt);
    lifetime += dt;
    
    if (lifetime >= maxLifetime) {
      removeFromParent();
      return;
    }
    
    for (var particle in particles) {
      particle.update(dt);
    }
  }
  
  @override
  void render(Canvas canvas) {
    super.render(canvas);
    
    final alpha = 1.0 - (lifetime / maxLifetime);
    for (var particle in particles) {
      particle.render(canvas, alpha);
    }
  }
}

class Particle {
  Vector2 position;
  Vector2 velocity;
  Color color;
  double size;
  
  Particle({
    required this.position,
    required this.velocity,
    required this.color,
    required this.size,
  });
  
  void update(double dt) {
    position += velocity * dt;
    velocity *= 0.95; // Friction
    velocity += Vector2(0, 100) * dt; // Gravity
  }
  
  void render(Canvas canvas, double alpha) {
    final paint = Paint()
      ..color = color.withValues(alpha: alpha)
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(position.toOffset(), size, paint);
  }
}

// Restoration animation component
class TileRestorationEffect extends Component with HasGameReference<EcoQuestGame> {
  final int row;
  final int col;
  double progress = 0.0;
  static const double animationDuration = 0.5;
  
  TileRestorationEffect({required this.row, required this.col});
  
  @override
  void update(double dt) {
    super.update(dt);
    progress += dt / animationDuration;
    
    if (progress >= 1.0) {
      removeFromParent();
    }
  }
  
  @override
  void render(Canvas canvas) {
    super.render(canvas);
    
    if (game.gridItems[row][col] == null) return;
    
    final item = game.gridItems[row][col]!;
    final rect = Rect.fromLTWH(
      item.position.x,
      item.position.y,
      item.size.x,
      item.size.y,
    );
    
    // Draw growing vines from corners
    _drawGrowingVines(canvas, rect, progress);
    
    // Draw blooming flowers
    _drawBloomingFlowers(canvas, rect, progress);
    
    // Draw green particles
    _drawGreenParticles(canvas, rect, progress);
  }
  
  void _drawGrowingVines(Canvas canvas, Rect rect, double progress) {
    final vinePaint = Paint()
      ..color = const Color(0xFF2E7D32).withValues(alpha: 0.8)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    
    // Vine from top-left corner
    final vineLength = rect.width * 0.4 * progress;
    final path = Path();
    path.moveTo(rect.left, rect.top);
    path.quadraticBezierTo(
      rect.left + vineLength * 0.5,
      rect.top + vineLength * 0.3,
      rect.left + vineLength,
      rect.top + vineLength,
    );
    
    canvas.drawPath(path, vinePaint);
  }
  
  void _drawBloomingFlowers(Canvas canvas, Rect rect, double progress) {
    if (progress < 0.5) return;
    
    final flowerProgress = (progress - 0.5) * 2;
    final flowerPaint = Paint()
      ..color = Colors.pink.withValues(alpha: 0.7 * flowerProgress)
      ..style = PaintingStyle.fill;
    
    // Small flower in center
    final flowerSize = 4 * flowerProgress;
    canvas.drawCircle(rect.center, flowerSize, flowerPaint);
  }
  
  void _drawGreenParticles(Canvas canvas, Rect rect, double progress) {
    final particlePaint = Paint()
      ..color = const Color(0xFF4CAF50).withValues(alpha: 0.6 * (1 - progress))
      ..style = PaintingStyle.fill;
    
    for (int i = 0; i < 8; i++) {
      final angle = (i / 8) * 2 * pi;
      final distance = rect.width * 0.3 * progress;
      final x = rect.center.dx + cos(angle) * distance;
      final y = rect.center.dy + sin(angle) * distance;
      
      canvas.drawCircle(Offset(x, y), 2, particlePaint);
    }
  }
}