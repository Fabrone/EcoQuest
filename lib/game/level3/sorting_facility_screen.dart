import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/collisions.dart';
import 'package:flame/extensions.dart';
import 'package:flutter/material.dart';
import 'package:flame/events.dart';
import 'dart:math' as math;

class SortingFacilityScreen extends StatefulWidget {
  const SortingFacilityScreen({super.key});

  @override
  State<SortingFacilityScreen> createState() => _SortingFacilityScreenState();
}

class _SortingFacilityScreenState extends State<SortingFacilityScreen> {
  late SortingFacilityGame _game;

  @override
  void initState() {
    super.initState();
    _game = SortingFacilityGame();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GameWidget(
        game: _game,
        overlayBuilderMap: {
          'hud': (context, game) => HudOverlay(game as SortingFacilityGame),
        },
        initialActiveOverlays: const ['hud'],
      ),
    );
  }
}

class SortingFacilityGame extends FlameGame with HasCollisionDetection, DragCallbacks {
  double timeRemaining = 105; // 01:45 in seconds
  double progress = 0.75; // 75%
  int ecoPoints = 0;

  late CityBackgroundLayer cityBackground;
  late WastePileComponent wastePile;
  late MiniMapComponent miniMap;

  List<WasteItemComponent> items = [];
  List<Bin3DComponent> bins = [];

  WasteItemComponent? _draggedItem;
  Vector2? _originalPosition;

  @override
  Future<void> onLoad() async {
    super.onLoad();

    // Sky gradient background
    add(SkyGradientComponent(size: size));

    // City skyline background
    cityBackground = CityBackgroundLayer(size: size);
    add(cityBackground);

    // River/water element
    add(RiverComponent(size: size));

    // Mini-map in top right
    miniMap = MiniMapComponent(
      position: Vector2(size.x - 160, 90),
      size: Vector2(150, 110),
    );
    add(miniMap);

    // Central waste pile area
    wastePile = WastePileComponent(
      position: Vector2(size.x / 2, size.y * 0.35),
      size: Vector2(size.x * 0.8, size.y * 0.2),
    );
    add(wastePile);

    // Create 3D bins at bottom
    createBins();

    // Generate waste items in the pile
    generateWasteItems();

    // Bottom instruction text
    add(TextComponent(
      text: 'Drag Items to the Correct Bins!',
      position: Vector2(size.x / 2, size.y - 40),
      anchor: Anchor.center,
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(
              color: Colors.black,
              offset: Offset(2, 2),
              blurRadius: 4,
            ),
          ],
        ),
      ),
    ));

    // Timer
    add(TimerComponent(
      period: 1.0,
      repeat: true,
      onTick: () {
        timeRemaining -= 1;
        progress = timeRemaining / 105;
        if (timeRemaining <= 0) {
          pauseEngine();
          // Game over logic
        }
      },
    ));
  }

  void createBins() {
    final binWidth = size.x / 4 - 15;
    final binHeight = size.y * 0.18;
    final startY = size.y * 0.68;

    bins = [
      Bin3DComponent(
        type: BinType.plastic,
        position: Vector2(10, startY),
        size: Vector2(binWidth, binHeight),
      ),
      Bin3DComponent(
        type: BinType.metal,
        position: Vector2(binWidth + 20, startY),
        size: Vector2(binWidth, binHeight),
      ),
      Bin3DComponent(
        type: BinType.organic,
        position: Vector2(2 * binWidth + 30, startY),
        size: Vector2(binWidth, binHeight),
      ),
      Bin3DComponent(
        type: BinType.eWaste,
        position: Vector2(3 * binWidth + 40, startY),
        size: Vector2(binWidth, binHeight),
      ),
    ];

    for (var bin in bins) {
      add(bin);
    }
  }

  void generateWasteItems() {
    final types = BinType.values;
    final random = math.Random();
    
    // Generate 12 varied waste items
    for (int i = 0; i < 12; i++) {
      final type = types[random.nextInt(types.length)];
      final offsetX = random.nextDouble() * (wastePile.width - 80) + 40;
      final offsetY = random.nextDouble() * (wastePile.height - 60) + 30;
      
      final item = WasteItemComponent(
        type: type,
        position: Vector2(
          wastePile.position.x - wastePile.width / 2 + offsetX,
          wastePile.position.y - wastePile.height / 2 + offsetY,
        ),
        size: Vector2(50, 50),
        index: i,
      );
      add(item);
      items.add(item);
    }
  }

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    for (var item in items.reversed) {
      if (item.containsPoint(event.canvasPosition)) {
        _draggedItem = item;
        _originalPosition = item.position.clone();
        item.priority = 100; // Bring to front
        break;
      }
    }
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    if (_draggedItem != null) {
      _draggedItem!.position += event.localDelta;
    }
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    if (_draggedItem != null) {
      bool dropped = false;
      for (var bin in bins) {
        if (_draggedItem!.toRect().overlaps(bin.toRect())) {
          sortItem(_draggedItem!, bin);
          dropped = true;
          break;
        }
      }
      if (!dropped) {
        _draggedItem!.position = _originalPosition!;
      }
      _draggedItem!.priority = 0;
      _draggedItem = null;
      _originalPosition = null;
    }
  }

  void sortItem(WasteItemComponent item, Bin3DComponent bin) {
    if (item.type == bin.type) {
      ecoPoints += 10;
      bin.flash(Colors.green);
    } else {
      ecoPoints -= 5;
      bin.flash(Colors.red);
    }
    remove(item);
    items.remove(item);
    
    if (items.isEmpty) {
      generateWasteItems();
    }
  }
}

enum BinType { plastic, metal, organic, eWaste }

// Sky gradient
class SkyGradientComponent extends PositionComponent {
  SkyGradientComponent({required Vector2 size}) : super(size: size);

  @override
  void render(Canvas canvas) {
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF4A5F7F),
          const Color(0xFF6B7F9C),
          const Color(0xFF8FA3B8),
        ],
      ).createShader(Rect.fromLTWH(0, 0, width, height));
    canvas.drawRect(Rect.fromLTWH(0, 0, width, height), paint);
  }
}

// City background with buildings
class CityBackgroundLayer extends PositionComponent {
  CityBackgroundLayer({required Vector2 size}) : super(size: size, priority: -1);

  @override
  void render(Canvas canvas) {
    final buildingColors = [
      const Color(0xFF3D4E5C),
      const Color(0xFF4A5D6E),
      const Color(0xFF556B7D),
    ];

    // Draw multiple buildings
    for (int i = 0; i < 12; i++) {
      final x = i * 80.0 - 50;
      final buildingHeight = 80.0 + (i % 4) * 30;
      final y = size.y * 0.15 - buildingHeight;
      
      // Building body
      final paint = Paint()..color = buildingColors[i % 3];
      canvas.drawRect(
        Rect.fromLTWH(x, y, 75, buildingHeight),
        paint,
      );

      // Windows
      final windowPaint = Paint()..color = const Color(0xFFFFA726).withValues(alpha:0.6);
      for (int row = 0; row < (buildingHeight / 15).floor(); row++) {
        for (int col = 0; col < 3; col++) {
          canvas.drawRect(
            Rect.fromLTWH(
              x + 10 + col * 20,
              y + 10 + row * 15,
              12,
              10,
            ),
            windowPaint,
          );
        }
      }
    }
  }
}

// River component
class RiverComponent extends PositionComponent {
  RiverComponent({required Vector2 size}) : super(size: size, priority: -1);

  @override
  void render(Canvas canvas) {
    final riverPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF1E3A5F),
          const Color(0xFF2C5282),
        ],
      ).createShader(Rect.fromLTWH(0, size.y * 0.2, size.x, 60));
    
    canvas.drawRect(
      Rect.fromLTWH(0, size.y * 0.2, size.x, 60),
      riverPaint,
    );

    // Water reflection shimmer
    final shimmerPaint = Paint()
      ..color = Colors.white.withValues(alpha:0.15)
      ..style = PaintingStyle.fill;
    
    for (int i = 0; i < 5; i++) {
      canvas.drawOval(
        Rect.fromLTWH(
          i * 150.0 + 20,
          size.y * 0.23,
          80,
          15,
        ),
        shimmerPaint,
      );
    }
  }
}

// Mini map component
class MiniMapComponent extends PositionComponent {
  MiniMapComponent({required Vector2 position, required Vector2 size})
      : super(position: position, size: size, priority: 5);

  @override
  void render(Canvas canvas) {
    // Map background
    final bgPaint = Paint()
      ..color = const Color(0xFF2C3E50)
      ..style = PaintingStyle.fill;
    
    final borderPaint = Paint()
      ..color = const Color(0xFF34495E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, width, height),
        const Radius.circular(8),
      ),
      bgPaint,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, width, height),
        const Radius.circular(8),
      ),
      borderPaint,
    );

    // Draw simplified map elements
    // Roads
    final roadPaint = Paint()..color = const Color(0xFF95A5A6);
    canvas.drawRect(Rect.fromLTWH(20, 40, 110, 8), roadPaint);
    canvas.drawRect(Rect.fromLTWH(60, 10, 8, 85), roadPaint);

    // Location markers
    final markerPaint = Paint()..color = const Color(0xFFE74C3C);
    canvas.drawCircle(const Offset(65, 45), 8, markerPaint);
    
    final checkPaint = Paint()..color = const Color(0xFF27AE60);
    canvas.drawCircle(const Offset(30, 70), 6, checkPaint);
    canvas.drawCircle(const Offset(100, 25), 6, checkPaint);

    // Current location indicator
    final currentPaint = Paint()
      ..color = const Color(0xFFF39C12)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(65, 45), 4, currentPaint);
  }
}

// Waste pile area
class WastePileComponent extends PositionComponent {
  WastePileComponent({required Vector2 position, required Vector2 size})
      : super(position: position, size: size, anchor: Anchor.center, priority: 0);

  @override
  void render(Canvas canvas) {
    // Conveyor belt / platform
    final platformPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF8D6E63),
          const Color(0xFF6D4C41),
          const Color(0xFF5D4037),
        ],
      ).createShader(Rect.fromLTWH(-width / 2, -height / 2, width, height));

    // Platform with rounded edges
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-width / 2, -height / 2, width, height),
        const Radius.circular(12),
      ),
      platformPaint,
    );

    // Platform border/edge
    final borderPaint = Paint()
      ..color = const Color(0xFF4E342E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-width / 2, -height / 2, width, height),
        const Radius.circular(12),
      ),
      borderPaint,
    );

    // Conveyor belt lines
    final linePaint = Paint()
      ..color = const Color(0xFF3E2723)
      ..strokeWidth = 2;

    for (int i = 0; i < 8; i++) {
      canvas.drawLine(
        Offset(-width / 2 + i * (width / 8), -height / 2),
        Offset(-width / 2 + i * (width / 8), height / 2),
        linePaint,
      );
    }
  }
}

// 3D Bin component with depth and shadow
class Bin3DComponent extends PositionComponent with CollisionCallbacks {
  final BinType type;
  Color? flashColor;
  double flashOpacity = 0.0;

  Bin3DComponent({
    required this.type,
    required Vector2 position,
    required Vector2 size,
  }) : super(position: position, size: size, priority: 1);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(RectangleHitbox(size: size));
  }

  void flash(Color color) {
    flashColor = color;
    flashOpacity = 0.8;
    
    add(TimerComponent(
      period: 0.1,
      repeat: true,
      removeOnFinish: true,
      onTick: () {
        flashOpacity -= 0.1;
        if (flashOpacity <= 0) {
          flashColor = null;
        }
      },
    ));
  }

  @override
  void render(Canvas canvas) {
    Color baseColor;
    String label;
    
    switch (type) {
      case BinType.plastic:
        baseColor = const Color(0xFF2196F3);
        label = 'Plastic';
        break;
      case BinType.metal:
        baseColor = const Color(0xFF9E9E9E);
        label = 'Metal';
        break;
      case BinType.organic:
        baseColor = const Color(0xFF4CAF50);
        label = 'Organic';
        break;
      case BinType.eWaste:
        baseColor = const Color(0xFF8D6E63);
        label = 'E-Waste';
        break;
    }

    // Shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha:0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(8, height * 0.85, width - 8, 10),
        const Radius.circular(4),
      ),
      shadowPaint,
    );

    // Bin front face (main body)
    final frontPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          baseColor,
          baseColor.withValues(alpha:0.7),
          baseColor.withValues(alpha:0.5),
        ],
      ).createShader(Rect.fromLTWH(0, height * 0.25, width, height * 0.75));

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, height * 0.25, width, height * 0.75),
        const Radius.circular(8),
      ),
      frontPaint,
    );

    // Bin lid (top)
    final lidPaint = Paint()
      ..color = baseColor.withValues(alpha:0.9);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-5, height * 0.15, width + 10, height * 0.15),
        const Radius.circular(6),
      ),
      lidPaint,
    );

    // Lid depth/shadow
    final lidShadowPaint = Paint()
      ..color = Colors.black.withValues(alpha:0.3);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, height * 0.24, width, 8),
        const Radius.circular(4),
      ),
      lidShadowPaint,
    );

    // Recycling symbol
    drawRecyclingSymbol(canvas, baseColor);

    // Border/outline
    final borderPaint = Paint()
      ..color = baseColor.withValues(alpha:0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, height * 0.25, width, height * 0.75),
        const Radius.circular(8),
      ),
      borderPaint,
    );

    // Flash effect
    if (flashColor != null && flashOpacity > 0) {
      final flashPaint = Paint()
        ..color = flashColor!.withValues(alpha:flashOpacity)
        ..style = PaintingStyle.fill;
      
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, height * 0.25, width, height * 0.75),
          const Radius.circular(8),
        ),
        flashPaint,
      );
    }

    // Label text
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: Colors.white,
          fontSize: width * 0.18,
          fontWeight: FontWeight.bold,
          shadows: const [
            Shadow(
              color: Colors.black,
              offset: Offset(1, 1),
              blurRadius: 3,
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        (width - textPainter.width) / 2,
        height * 0.05,
      ),
    );
  }

  void drawRecyclingSymbol(Canvas canvas, Color binColor) {
    final symbolPaint = Paint()
      ..color = Colors.white.withValues(alpha:0.9)
      ..style = PaintingStyle.fill;

    final centerX = width / 2;
    final centerY = height * 0.6;
    final radius = width * 0.15;

    // Three arrows forming triangle
    for (int i = 0; i < 3; i++) {
      final angle = (i * 120 - 90) * math.pi / 180;
      final arrowPath = Path();
      
      final startX = centerX + math.cos(angle) * radius;
      final startY = centerY + math.sin(angle) * radius;
      
      arrowPath.moveTo(startX, startY);
      arrowPath.lineTo(
        startX + math.cos(angle + 0.3) * radius * 0.6,
        startY + math.sin(angle + 0.3) * radius * 0.6,
      );
      arrowPath.lineTo(
        startX + math.cos(angle - 0.3) * radius * 0.6,
        startY + math.sin(angle - 0.3) * radius * 0.6,
      );
      arrowPath.close();

      canvas.drawPath(arrowPath, symbolPaint);
      
      // Arrow body
      final bodyPath = Path();
      bodyPath.moveTo(startX, startY);
      bodyPath.arcToPoint(
        Offset(
          centerX + math.cos(angle + 2.094) * radius,
          centerY + math.sin(angle + 2.094) * radius,
        ),
        radius: Radius.circular(radius),
      );
      
      canvas.drawPath(
        bodyPath,
        Paint()
          ..color = Colors.white.withValues(alpha:0.9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = width * 0.05,
      );
    }
  }
}

// Waste item component with varied shapes
class WasteItemComponent extends PositionComponent {
  final BinType type;
  final int index;

  WasteItemComponent({
    required this.type,
    required Vector2 position,
    required Vector2 size,
    required this.index,
  }) : super(position: position, size: size, anchor: Anchor.center, priority: 2);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(RectangleHitbox(size: size));
  }

  @override
  void render(Canvas canvas) {
    Color itemColor;
    
    switch (type) {
      case BinType.plastic:
        itemColor = const Color(0xFF64B5F6);
        _drawBottle(canvas, itemColor);
        break;
      case BinType.metal:
        itemColor = const Color(0xFFBDBDBD);
        _drawCan(canvas, itemColor);
        break;
      case BinType.organic:
        itemColor = const Color(0xFF81C784);
        _drawFoodWaste(canvas, itemColor);
        break;
      case BinType.eWaste:
        itemColor = const Color(0xFFFFB74D);
        _drawElectronic(canvas, itemColor);
        break;
    }

    // Shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha:0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    
    canvas.drawOval(
      Rect.fromLTWH(-width * 0.4, height * 0.3, width * 0.8, height * 0.2),
      shadowPaint,
    );
  }

  void _drawBottle(Canvas canvas, Color color) {
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [color, color.withValues(alpha:0.6)],
      ).createShader(Rect.fromLTWH(-width / 2, -height / 2, width, height));

    // Bottle body
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-width * 0.3, -height * 0.2, width * 0.6, height * 0.6),
        const Radius.circular(8),
      ),
      paint,
    );

    // Bottle neck
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-width * 0.15, -height * 0.4, width * 0.3, height * 0.25),
        const Radius.circular(4),
      ),
      paint,
    );

    // Highlight
    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha:0.5);
    canvas.drawOval(
      Rect.fromLTWH(-width * 0.15, -height * 0.15, width * 0.2, height * 0.3),
      highlightPaint,
    );
  }

  void _drawCan(Canvas canvas, Color color) {
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color, color.withValues(alpha:0.7)],
      ).createShader(Rect.fromLTWH(-width / 2, -height / 2, width, height));

    // Can body
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-width * 0.35, -height * 0.3, width * 0.7, height * 0.7),
        const Radius.circular(6),
      ),
      paint,
    );

    // Can top
    canvas.drawOval(
      Rect.fromLTWH(-width * 0.35, -height * 0.35, width * 0.7, height * 0.15),
      paint,
    );

    // Metallic shine
    final shinePaint = Paint()
      ..color = Colors.white.withValues(alpha:0.6);
    canvas.drawRect(
      Rect.fromLTWH(-width * 0.25, -height * 0.1, width * 0.1, height * 0.3),
      shinePaint,
    );
  }

  void _drawFoodWaste(Canvas canvas, Color color) {
    final paint = Paint()..color = color;

    // Irregular organic shape
    final path = Path();
    path.moveTo(-width * 0.3, 0);
    path.quadraticBezierTo(-width * 0.2, -height * 0.3, 0, -height * 0.25);
    path.quadraticBezierTo(width * 0.25, -height * 0.3, width * 0.3, -height * 0.1);
    path.quadraticBezierTo(width * 0.35, height * 0.1, width * 0.2, height * 0.3);
    path.quadraticBezierTo(0, height * 0.35, -width * 0.2, height * 0.25);
    path.quadraticBezierTo(-width * 0.35, height * 0.1, -width * 0.3, 0);
    path.close();

    canvas.drawPath(path, paint);

    // Texture spots
    final spotPaint = Paint()..color = color.withValues(alpha:0.5);
    canvas.drawCircle(Offset(-width * 0.1, -height * 0.1), width * 0.08, spotPaint);
    canvas.drawCircle(Offset(width * 0.1, height * 0.05), width * 0.06, spotPaint);
  }

  void _drawElectronic(Canvas canvas, Color color) {
    final paint = Paint()..color = color;

    // Device body
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-width * 0.35, -height * 0.3, width * 0.7, height * 0.65),
        const Radius.circular(4),
      ),
      paint,
    );

    // Screen
    final screenPaint = Paint()..color = const Color(0xFF263238);
    canvas.drawRect(
      Rect.fromLTWH(-width * 0.25, -height * 0.2, width * 0.5, height * 0.35),
      screenPaint,
    );

    // Button
    final buttonPaint = Paint()..color = Colors.grey[700]!;
    canvas.drawCircle(const Offset(0, 0.2 * 25), width * 0.08, buttonPaint);
  }
}

// HUD Overlay
class HudOverlay extends StatelessWidget {
  final SortingFacilityGame game;

  const HudOverlay(this.game, {super.key});

  String formatTime(double seconds) {
    int min = (seconds / 60).floor();
    int sec = (seconds % 60).floor();
    return '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF00695C),
                  const Color(0xFF00897B),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha:0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                const Text(
                  'Sorting & Recycling Facility',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF004D40),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF00897B),
                      width: 2,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.timer,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Sort Timer ${formatTime(game.timeRemaining)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        width: 120,
                        height: 20,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha:0.3),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.white.withValues(alpha:0.3),
                            width: 1,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(9),
                          child: Stack(
                            children: [
                              FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: game.progress.clamp(0.0, 1.0),
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: game.progress > 0.5
                                          ? [
                                              const Color(0xFFFDD835),
                                              const Color(0xFFFBC02D),
                                            ]
                                          : game.progress > 0.25
                                              ? [
                                                  const Color(0xFFFFB300),
                                                  const Color(0xFFF57C00),
                                                ]
                                              : [
                                                  const Color(0xFFE53935),
                                                  const Color(0xFFC62828),
                                                ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Text(
                        '${(game.progress * 100).toInt()}%',
                        style: TextStyle(
                          color: game.progress > 0.5
                              ? const Color(0xFFFDD835)
                              : game.progress > 0.25
                                  ? const Color(0xFFFFB300)
                                  : const Color(0xFFE53935),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}