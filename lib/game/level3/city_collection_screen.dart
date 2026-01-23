import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/collisions.dart';
import 'package:flutter/material.dart';
import 'package:flame/extensions.dart';
import 'dart:ui' as ui;
import 'dart:math' as math;

class CityCollectionScreen extends StatefulWidget {
  const CityCollectionScreen({super.key});

  @override
  State<CityCollectionScreen> createState() => _CityCollectionScreenState();
}

class _CityCollectionScreenState extends State<CityCollectionScreen> {
  late CityCollectionGame _game;

  @override
  void initState() {
    super.initState();
    _game = CityCollectionGame();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GameWidget(
        game: _game,
        overlayBuilderMap: {
          'hud': (context, game) => HudOverlay(game as CityCollectionGame),
          'controls': (context, game) => ControlsOverlay(game as CityCollectionGame),
        },
        initialActiveOverlays: const ['hud', 'controls'],
      ),
    );
  }
}

class CityCollectionGame extends FlameGame with HasCollisionDetection {
  // Game state variables
  double timeRemaining = 270; // 4:30 in seconds
  int ecoPoints = 0;
  int wasteCollected = 0;
  int wasteTotal = 25;
  
  late SkyLayer skyLayer;
  late CloudLayer cloudLayer;
  late BuildingLayer farBuildings;
  late BuildingLayer midBuildings;
  late BuildingLayer nearBuildings;
  late StreetLayer streetLayer;
  late TruckComponent truck;

  List<WasteComponent> wastes = [];
  
  bool isDriving = false;
  bool isBraking = false;
  double currentSpeed = 0.0;
  double maxSpeed = 200.0;
  double acceleration = 100.0;
  double brakeDeceleration = 150.0;
  double naturalDeceleration = 50.0;

  @override
  Future<void> onLoad() async {
    super.onLoad();

    // Add sky
    skyLayer = SkyLayer(size: size);
    add(skyLayer);

    // Add clouds
    cloudLayer = CloudLayer(size: size);
    add(cloudLayer);

    // Add building layers with parallax
    farBuildings = BuildingLayer(
      isFar: true, 
      size: size, 
      depth: 0.3,
      buildingColor: Colors.grey[600]!,
      windowColor: Colors.yellow[700]!,
    );
    add(farBuildings);

    midBuildings = BuildingLayer(
      isFar: false, 
      size: size, 
      depth: 0.6,
      buildingColor: Colors.grey[700]!,
      windowColor: Colors.orange[300]!,
    );
    add(midBuildings);

    nearBuildings = BuildingLayer(
      isFar: false, 
      size: size, 
      depth: 1.0,
      buildingColor: Colors.grey[800]!,
      windowColor: Colors.yellow[600]!,
    );
    add(nearBuildings);

    // Add street
    streetLayer = StreetLayer(size: size);
    add(streetLayer);

    // Add truck
    truck = TruckComponent(
      position: Vector2(150, size.y - 180),
      size: Vector2(140, 80),
    );
    add(truck);

    // Generate waste items randomly along the street
    final random = math.Random();
    for (int i = 0; i < wasteTotal; i++) {
      final xPos = 400.0 + i * (150 + random.nextDouble() * 200);
      final waste = WasteComponent(
        position: Vector2(xPos, size.y - 100 - random.nextDouble() * 20),
        type: i % 4,
      );
      add(waste);
      wastes.add(waste);
    }

    // Timer for countdown
    add(TimerComponent(
      period: 1.0,
      repeat: true,
      onTick: () {
        timeRemaining -= 1;
        if (timeRemaining <= 0) {
          pauseEngine();
        }
      },
    ));
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Handle acceleration and braking
    if (isDriving && !isBraking) {
      currentSpeed = math.min(currentSpeed + acceleration * dt, maxSpeed);
    } else if (isBraking) {
      currentSpeed = math.max(currentSpeed - brakeDeceleration * dt, 0);
    } else {
      currentSpeed = math.max(currentSpeed - naturalDeceleration * dt, 0);
    }

    // Scroll world based on speed
    if (currentSpeed > 0) {
      final scrollAmount = currentSpeed * dt;
      
      // Parallax scrolling at different speeds
      cloudLayer.scroll(scrollAmount * 0.2);
      farBuildings.scroll(scrollAmount * 0.3);
      midBuildings.scroll(scrollAmount * 0.6);
      nearBuildings.scroll(scrollAmount * 1.0);
      streetLayer.scroll(scrollAmount);

      // Move waste items
      for (var waste in wastes) {
        waste.position.x -= scrollAmount;
      }
    }

    // Update truck animation
    truck.updateAnimation(currentSpeed);
  }

  void collectWaste(WasteComponent waste) {
    if (!waste.isCollected) {
      waste.collect();
      wasteCollected++;
      ecoPoints += 50;
    }
  }

  void toggleDrive() {
    isDriving = !isDriving;
    if (isDriving) {
      isBraking = false;
    }
  }

  void brake() {
    isBraking = true;
    isDriving = false;
  }

  void releaseBrake() {
    isBraking = false;
  }
}

// Sky with gradient
class SkyLayer extends PositionComponent {
  SkyLayer({required Vector2 size}) : super(size: size);

  @override
  void render(Canvas canvas) {
    final paint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, 0),
        Offset(0, height),
        [
          const Color(0xFF87CEEB), // Sky blue
          const Color(0xFFE0F6FF), // Light blue
        ],
      );
    canvas.drawRect(Rect.fromLTWH(0, 0, width, height), paint);
  }
}

// Animated clouds
class CloudLayer extends PositionComponent {
  List<CloudComponent> clouds = [];
  final math.Random random = math.Random();

  CloudLayer({required Vector2 size}) : super(size: size) {
    for (int i = 0; i < 5; i++) {
      final cloud = CloudComponent(
        position: Vector2(random.nextDouble() * size.x, 50 + random.nextDouble() * 100),
        size: Vector2(80 + random.nextDouble() * 60, 40),
      );
      add(cloud);
      clouds.add(cloud);
    }
  }

  void scroll(double dx) {
    for (var cloud in clouds) {
      cloud.position.x -= dx;
      if (cloud.position.x + cloud.width < 0) {
        cloud.position.x = size.x + random.nextDouble() * 200;
      }
    }
  }
}

class CloudComponent extends PositionComponent {
  CloudComponent({required Vector2 position, required Vector2 size})
      : super(position: position, size: size);

  @override
  void render(Canvas canvas) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..style = PaintingStyle.fill;

    // Draw cloud as overlapping circles
    canvas.drawCircle(Offset(width * 0.3, height * 0.5), height * 0.4, paint);
    canvas.drawCircle(Offset(width * 0.5, height * 0.4), height * 0.5, paint);
    canvas.drawCircle(Offset(width * 0.7, height * 0.5), height * 0.4, paint);
  }
}

// Enhanced building layer with detailed buildings
class BuildingLayer extends PositionComponent {
  final bool isFar;
  final double depth;
  final Color buildingColor;
  final Color windowColor;
  List<DetailedBuilding> buildings = [];
  final math.Random random = math.Random();

  BuildingLayer({
    required this.isFar,
    required Vector2 size,
    required this.depth,
    required this.buildingColor,
    required this.windowColor,
  }) : super(size: size) {
    final buildingCount = 15;
    for (int i = 0; i < buildingCount; i++) {
      double x = i * 220.0;
      double buildingHeight = isFar 
          ? 120 + random.nextDouble() * 80 
          : 180 + random.nextDouble() * 140;
      
      final building = DetailedBuilding(
        position: Vector2(x, size.y - buildingHeight - 60),
        size: Vector2(180, buildingHeight),
        buildingColor: buildingColor,
        windowColor: windowColor,
        hasRoof: random.nextBool(),
        windowRows: (buildingHeight / 40).floor(),
      );
      add(building);
      buildings.add(building);
    }
  }

  void scroll(double dx) {
    for (var building in buildings) {
      building.position.x -= dx;
      if (building.position.x + building.width < -200) {
        building.position.x += buildings.length * 220;
      }
    }
  }
}

// Detailed building with windows and doors
class DetailedBuilding extends PositionComponent {
  final Color buildingColor;
  final Color windowColor;
  final bool hasRoof;
  final int windowRows;

  DetailedBuilding({
    required Vector2 position,
    required Vector2 size,
    required this.buildingColor,
    required this.windowColor,
    required this.hasRoof,
    required this.windowRows,
  }) : super(position: position, size: size);

  @override
  void render(Canvas canvas) {
    // Building body
    final bodyPaint = Paint()..color = buildingColor;
    canvas.drawRect(Rect.fromLTWH(0, 0, width, height), bodyPaint);

    // Outline
    final outlinePaint = Paint()
      ..color = buildingColor.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRect(Rect.fromLTWH(0, 0, width, height), outlinePaint);

    // Windows
    final windowPaint = Paint()..color = windowColor;
    final windowWidth = 15.0;
    final windowHeight = 20.0;
    final windowSpacingX = 30.0;
    final windowSpacingY = 35.0;
    final startX = 15.0;
    final startY = 15.0;

    for (int row = 0; row < windowRows; row++) {
      for (int col = 0; col < 4; col++) {
        final x = startX + col * windowSpacingX;
        final y = startY + row * windowSpacingY;
        if (y + windowHeight < height - 30) {
          canvas.drawRect(
            Rect.fromLTWH(x, y, windowWidth, windowHeight),
            windowPaint,
          );
        }
      }
    }

    // Door at bottom
    final doorPaint = Paint()..color = const Color(0xFF654321);
    canvas.drawRect(
      Rect.fromLTWH(width / 2 - 15, height - 40, 30, 40),
      doorPaint,
    );

    // Roof
    if (hasRoof) {
      final roofPaint = Paint()..color = const Color(0xFF8B4513);
      final roofPath = Path()
        ..moveTo(0, 0)
        ..lineTo(width / 2, -20)
        ..lineTo(width, 0)
        ..close();
      canvas.drawPath(roofPath, roofPaint);
    }
  }
}

// Street with road markings
class StreetLayer extends PositionComponent {
  List<RoadMarking> roadMarkings = [];

  StreetLayer({required Vector2 size}) : super(size: size) {
    // Road base
    add(RectangleComponent(
      position: Vector2(0, size.y - 120),
      size: Vector2(size.x * 3, 120),
      paint: Paint()..color = const Color(0xFF404040),
    ));

    // Sidewalk
    add(RectangleComponent(
      position: Vector2(0, size.y - 130),
      size: Vector2(size.x * 3, 10),
      paint: Paint()..color = const Color(0xFF808080),
    ));

    // Road markings
    for (int i = 0; i < 30; i++) {
      final marking = RoadMarking(
        position: Vector2(i * 100.0, size.y - 60),
      );
      add(marking);
      roadMarkings.add(marking);
    }
  }

  void scroll(double dx) {
    for (var child in children) {
      if (child is PositionComponent) {
        child.position.x -= dx;
        if (child.position.x < -200) {
          child.position.x += size.x * 3;
        }
      }
    }
  }
}

class RoadMarking extends PositionComponent {
  RoadMarking({required Vector2 position})
      : super(position: position, size: Vector2(60, 4));

  @override
  void render(Canvas canvas) {
    final paint = Paint()..color = Colors.white;
    canvas.drawRect(Rect.fromLTWH(0, 0, width, height), paint);
  }
}

// Realistic truck component
class TruckComponent extends PositionComponent
    with HasGameReference<CityCollectionGame>, CollisionCallbacks {
  double wheelRotation = 0;
  double bobOffset = 0;

  TruckComponent({required Vector2 position, required Vector2 size})
      : super(position: position, size: size) {
    add(RectangleHitbox());
  }

  void updateAnimation(double speed) {
    if (speed > 0) {
      wheelRotation += speed * 0.01;
      bobOffset = math.sin(wheelRotation) * 2;
    }
  }

  @override
  void render(Canvas canvas) {
    canvas.save();
    canvas.translate(0, bobOffset);

    // Truck body - main cabin
    final cabinPaint = Paint()..color = const Color(0xFFFF6B35); // Orange
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 15, width * 0.35, height * 0.7),
        const Radius.circular(5),
      ),
      cabinPaint,
    );

    // Windshield
    final windshieldPaint = Paint()..color = const Color(0xFF87CEEB);
    canvas.drawRect(
      Rect.fromLTWH(width * 0.25, 20, width * 0.08, height * 0.4),
      windshieldPaint,
    );

    // Truck bed/container
    final containerPaint = Paint()..color = const Color(0xFF2D5016); // Dark green
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(width * 0.35, 5, width * 0.65, height * 0.8),
        const Radius.circular(5),
      ),
      containerPaint,
    );

    // Container details
    final detailPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawLine(
      Offset(width * 0.5, 5),
      Offset(width * 0.5, height * 0.85),
      detailPaint,
    );
    canvas.drawLine(
      Offset(width * 0.7, 5),
      Offset(width * 0.7, height * 0.85),
      detailPaint,
    );

    // Wheels
    final wheelRadius = 18.0;
    
    // Front wheel
    canvas.save();
    canvas.translate(width * 0.2, height * 0.9);
    canvas.rotate(wheelRotation);
    _drawWheel(canvas, wheelRadius);
    canvas.restore();

    // Back wheel
    canvas.save();
    canvas.translate(width * 0.75, height * 0.9);
    canvas.rotate(wheelRotation);
    _drawWheel(canvas, wheelRadius);
    canvas.restore();

    // Headlights
    final headlightPaint = Paint()..color = Colors.yellow[300]!;
    canvas.drawCircle(Offset(width * 0.02, height * 0.5), 4, headlightPaint);

    canvas.restore();
  }

  void _drawWheel(Canvas canvas, double radius) {
    final tirePaint = Paint()..color = Colors.black;
    final rimPaint = Paint()..color = Colors.grey[600]!;
    
    canvas.drawCircle(Offset.zero, radius, tirePaint);
    canvas.drawCircle(Offset.zero, radius * 0.6, rimPaint);
    
    for (int i = 0; i < 5; i++) {
      final angle = (i * math.pi * 2 / 5);
      canvas.drawLine(
        Offset.zero,
        Offset(math.cos(angle) * radius * 0.6, math.sin(angle) * radius * 0.6),
        Paint()
          ..color = Colors.grey[800]!
          ..strokeWidth = 2,
      );
    }
  }

  bool isNear(PositionComponent other) {
    return position.distanceTo(other.position) < 150;
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);
    if (other is WasteComponent && !other.isCollected) {
      game.collectWaste(other);
    }
  }
}

// Detailed waste items
class WasteComponent extends PositionComponent with CollisionCallbacks {
  final int type;
  bool isCollected = false;

  WasteComponent({required Vector2 position, required this.type})
      : super(position: position, size: Vector2(35, 35)) {
    add(CircleHitbox(radius: 17.5));
  }

  void collect() {
    if (!isCollected) {
      isCollected = true;
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    if (isCollected) return;

    switch (type) {
      case 0: // Trash bag
        _drawTrashBag(canvas);
        break;
      case 1: // Bottle
        _drawBottle(canvas);
        break;
      case 2: // Can
        _drawCan(canvas);
        break;
      case 3: // Paper
        _drawPaper(canvas);
        break;
    }
  }

  void _drawTrashBag(Canvas canvas) {
    final paint = Paint()..color = Colors.black;
    canvas.drawOval(Rect.fromLTWH(5, 10, 25, 25), paint);
    
    final tiePaint = Paint()
      ..color = Colors.grey[700]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawLine(Offset(17.5, 10), Offset(17.5, 5), tiePaint);
  }

  void _drawBottle(Canvas canvas) {
    final paint = Paint()..color = const Color(0xFF2E7D32);
    canvas.drawRect(Rect.fromLTWH(12, 10, 10, 20), paint);
    canvas.drawRect(Rect.fromLTWH(14, 5, 6, 5), paint);
    
    final capPaint = Paint()..color = Colors.red;
    canvas.drawCircle(Offset(17, 5), 3, capPaint);
  }

  void _drawCan(Canvas canvas) {
    final paint = Paint()..color = const Color(0xFFC0C0C0);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(10, 12, 15, 18),
        const Radius.circular(2),
      ),
      paint,
    );
  }

  void _drawPaper(Canvas canvas) {
    final paint = Paint()..color = Colors.white;
    canvas.drawRect(Rect.fromLTWH(8, 8, 20, 20), paint);
    
    final linePaint = Paint()
      ..color = Colors.grey
      ..strokeWidth = 1;
    for (int i = 0; i < 5; i++) {
      canvas.drawLine(
        Offset(10, 12 + i * 4),
        Offset(26, 12 + i * 4),
        linePaint,
      );
    }
  }
}

// Enhanced HUD
class HudOverlay extends StatelessWidget {
  final CityCollectionGame game;

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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue[900]!, Colors.blue[700]!],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.timer, color: Colors.white, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      formatTime(game.timeRemaining),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Icon(Icons.eco, color: Colors.greenAccent, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      '${game.ecoPoints}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.delete, color: Colors.orange, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Waste Collected: ${game.wasteCollected}/${game.wasteTotal}',
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: game.wasteCollected / game.wasteTotal,
                  backgroundColor: Colors.grey[700],
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.speed, color: Colors.blue, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Speed: ${(game.currentSpeed / game.maxSpeed * 100).toInt()}%',
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Enhanced controls
class ControlsOverlay extends StatelessWidget {
  final CityCollectionGame game;

  const ControlsOverlay(this.game, {super.key});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildControlButton(
              icon: Icons.play_arrow,
              label: 'Drive',
              color: Colors.green,
              onPressed: () => game.toggleDrive(),
            ),
            const SizedBox(width: 16),
            _buildControlButton(
              icon: Icons.stop,
              label: 'Brake',
              color: Colors.red,
              onPressed: () => game.brake(),
              onReleased: () => game.releaseBrake(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
    VoidCallback? onReleased,
  }) {
    return GestureDetector(
      onTapDown: (_) => onPressed(),
      onTapUp: (_) => onReleased?.call(),
      onTapCancel: () => onReleased?.call(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.4),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 32),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}