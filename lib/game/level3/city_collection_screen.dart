import 'package:flame/components.dart' hide Matrix4;
import 'package:flame/game.dart' hide Matrix4;
import 'package:flame/collisions.dart';
import 'package:flutter/material.dart' hide Matrix4;
import 'package:flame/extensions.dart' hide Matrix4;
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:vector_math/vector_math_64.dart' show Matrix4;

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
          'controls': (context, game) =>
              ControlsOverlay(game as CityCollectionGame),
          'gameOver': (context, game) => 
              GameOverOverlay(game as CityCollectionGame), // NEW
        },
        initialActiveOverlays: const ['hud', 'controls'],
      ),
    );
  }
}

class CityCollectionGame extends FlameGame with HasCollisionDetection {
  double timeRemaining = 90;
  int ecoPoints = 0;
  int wasteCollected = 0;
  int wasteTotal = 0; // UPDATED: No limit, dynamically generated

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
  bool isLongBraking = false;
  bool hasStartedDriving = false; // NEW: Track if game has started
  double brakePressDuration = 0;
  double drivingDuration = 0;
  double currentSpeed = 0.0;
  double maxSpeed = 150.0; // UPDATED: Direct km/h representation
  
  // UPDATED: Realistic acceleration - reach 100 km/h in 18 seconds
  // Acceleration = velocity / time = 100 / 18 = 5.56 km/h per second
  double baseAcceleration = 5.56; // km/h per second
  double accelerationBoost = 2.78; // Additional boost to reach 150 km/h smoothly
  double longPressAccelerationMultiplier = 1.3; 
  double brakeDeceleration = 40.0; // km/h per second
  double hardBrakeDeceleration = 80.0; // km/h per second
  double naturalDeceleration = 15.0; // km/h per second

  static const List<String> wasteAssets = [
    'mixedwaste.png',
    'garbage.png',
    'dirty-shirt.png',
    'torn-sock.png',
    'banana.png',
    'glass-bottle.png',
    'bottle.png',
    'peel.png',
    'paper.png',
    'clothes.png',
    'tshirt.png',
  ];

  @override
  Future<void> onLoad() async {
    super.onLoad();

    await images.loadAll(wasteAssets);

    skyLayer = SkyLayer(size: size);
    add(skyLayer);

    cloudLayer = CloudLayer(size: size);
    add(cloudLayer);

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

    streetLayer = StreetLayer(size: size);
    add(streetLayer);

    truck = TruckComponent(
      position: Vector2(150, size.y - 180),
      size: Vector2(140, 80),
    );
    add(truck);

    // UPDATED: Generate unlimited waste items across extended distance
    final random = math.Random();
    
    // Generate 100 waste items spread across 20,000 pixels
    for (int i = 0; i < 100; i++) {
      final xPos = 400.0 + i * (150 + random.nextDouble() * 250);
      final randomAsset = wasteAssets[random.nextInt(wasteAssets.length)];

      final waste = WasteComponent(
        position: Vector2(xPos, size.y - 100 - random.nextDouble() * 20),
        assetPath: randomAsset,
      );
      add(waste);
      wastes.add(waste);
    }

    // UPDATED: Timer only starts when player starts driving
    add(
      TimerComponent(
        period: 1.0,
        repeat: true,
        onTick: () {
          if (hasStartedDriving) { // Only count down if game has started
            timeRemaining -= 1;
            if (timeRemaining <= 0) {
              pauseEngine();
              _showGameOverDialog();
            }
          }
        },
      ),
    );
  }

  // NEW: Game over dialog method
  void _showGameOverDialog() {
    // This will be triggered when time runs out
    // The overlay system will handle showing the dialog
    overlays.add('gameOver');
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (isBraking) {
      brakePressDuration += dt;
      isLongBraking = brakePressDuration > 0.5;
      drivingDuration = 0;
    } else {
      brakePressDuration = 0;
      isLongBraking = false;
    }

    if (isDriving && !isBraking) {
      drivingDuration += dt;
      if (!hasStartedDriving) {
        hasStartedDriving = true; // Start the timer
      }
    } else if (!isDriving) {
      drivingDuration = 0;
    }

    // UPDATED: Realistic acceleration
    if (isDriving && !isBraking) {
      // Calculate acceleration based on current speed
      double speedRatio = currentSpeed / maxSpeed;
      double progressiveAcceleration = baseAcceleration + (accelerationBoost * (1.0 - speedRatio));
      
      // Apply long press multiplier after 0.3 seconds
      if (drivingDuration > 0.3) {
        double longPressFactor = math.min(drivingDuration / 2.0, 1.0);
        progressiveAcceleration *= (1.0 + (longPressAccelerationMultiplier - 1.0) * longPressFactor);
      }
      
      // Apply acceleration (now in km/h per second)
      currentSpeed = math.min(currentSpeed + progressiveAcceleration * dt, maxSpeed);
    } else if (isBraking) {
      double deceleration = isLongBraking ? hardBrakeDeceleration : brakeDeceleration;
      currentSpeed = math.max(currentSpeed - deceleration * dt, 0);
    } else {
      currentSpeed = math.max(currentSpeed - naturalDeceleration * dt, 0);
    }

    // UPDATED: Parallax scrolling using speed directly (now in km/h)
    if (currentSpeed > 0) {
      // Convert km/h to pixels per second for scrolling
      // 150 km/h should feel fast, so we use a reasonable multiplier
      final scrollAmount = (currentSpeed * 2.5) * dt;

      cloudLayer.scroll(scrollAmount * 0.15);
      farBuildings.scroll(scrollAmount * 0.35);
      midBuildings.scroll(scrollAmount * 0.65);
      nearBuildings.scroll(scrollAmount * 1.1);
      streetLayer.scroll(scrollAmount * 1.0);

      for (var waste in wastes) {
        waste.position.x -= scrollAmount;
      }
    }

    truck.updateAnimation(currentSpeed);
  }

  void collectWaste(WasteComponent waste) {
    if (!waste.isCollected) {
      waste.collect();
      wasteCollected++;
      ecoPoints += 50;
    }
  }

  // New: Start driving (called when drive pedal pressed)
  void startDriving() {
    isDriving = true;
    isBraking = false;
    if (!hasStartedDriving) {
      hasStartedDriving = true; // Start the game timer
    }
  }

  // New: Stop driving (called when drive pedal released)
  void stopDriving() {
    isDriving = false;
  }

  // New: Start braking (called when brake pedal pressed)
  void startBraking() {
    isBraking = true;
    isDriving = false;
    brakePressDuration = 0;
  }

  // New: Stop braking (called when brake pedal released)
  void stopBraking() {
    isBraking = false;
    brakePressDuration = 0;
    isLongBraking = false;
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
    final skyHeight = height * 0.65;

    final paint = Paint()
      ..shader = ui.Gradient.linear(Offset(0, 0), Offset(0, skyHeight), [
        const Color(0xFF87CEEB),
        const Color(0xFFE0F6FF),
      ]);

    canvas.drawRect(Rect.fromLTWH(0, 0, width, skyHeight), paint);
  }
}

// Animated clouds
class CloudLayer extends PositionComponent {
  List<CloudComponent> clouds = [];
  final math.Random random = math.Random();

  CloudLayer({required Vector2 size}) : super(size: size) {
    for (int i = 0; i < 5; i++) {
      final cloud = CloudComponent(
        position: Vector2(
          random.nextDouble() * size.x,
          50 + random.nextDouble() * 100,
        ),
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

    canvas.drawCircle(Offset(width * 0.3, height * 0.5), height * 0.4, paint);
    canvas.drawCircle(Offset(width * 0.5, height * 0.4), height * 0.5, paint);
    canvas.drawCircle(Offset(width * 0.7, height * 0.5), height * 0.4, paint);
  }
}

// Building layer with parallax
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
    final roadTop = size.y - 120;

    for (int i = 0; i < buildingCount; i++) {
      double x = i * 220.0;
      double buildingHeight = isFar
          ? 120 + random.nextDouble() * 80
          : 180 + random.nextDouble() * 140;

      final buildingY = roadTop - buildingHeight - 20;

      final building = DetailedBuilding(
        position: Vector2(x, buildingY),
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
    final bodyPaint = Paint()..color = buildingColor;
    canvas.drawRect(Rect.fromLTWH(0, 0, width, height), bodyPaint);

    final outlinePaint = Paint()
      ..color = buildingColor.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRect(Rect.fromLTWH(0, 0, width, height), outlinePaint);

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

    final doorPaint = Paint()..color = const Color(0xFF654321);
    canvas.drawRect(
      Rect.fromLTWH(width / 2 - 15, height - 40, 30, 40),
      doorPaint,
    );

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
  List<double> markingPositions = [];
  double scrollOffset = 0;

  StreetLayer({required Vector2 size}) : super(size: size) {
    for (int i = 0; i < 50; i++) {
      markingPositions.add(i * 100.0);
    }
  }

  void scroll(double dx) {
    scrollOffset += dx;
    if (scrollOffset > 100) {
      scrollOffset -= 100;
    }
  }

  @override
  void render(Canvas canvas) {
    final roadPaint = Paint()..color = const Color(0xFF404040);
    canvas.drawRect(Rect.fromLTWH(0, height - 120, width, 120), roadPaint);

    final markingPaint = Paint()..color = Colors.white;
    for (var baseX in markingPositions) {
      final x = baseX - scrollOffset;
      if (x > -100 && x < width + 100) {
        canvas.drawRect(Rect.fromLTWH(x, height - 60, 60, 4), markingPaint);
      }
    }
  }
}

// Truck component
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

    // Container (green)
    final containerPaint = Paint()..color = const Color(0xFF2D5016);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 5, width * 0.65, height * 0.8),
        const Radius.circular(5),
      ),
      containerPaint,
    );

    final topHighlight = Paint()..color = const Color(0xFF3A6B1E);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 5, width * 0.65, height * 0.15),
        const Radius.circular(5),
      ),
      topHighlight,
    );

    final dividerPaint = Paint()
      ..color = const Color(0xFF1E3A0F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    canvas.drawLine(
      Offset(width * 0.2, 5),
      Offset(width * 0.2, height * 0.85),
      dividerPaint,
    );
    canvas.drawLine(
      Offset(width * 0.4, 5),
      Offset(width * 0.4, height * 0.85),
      dividerPaint,
    );

    final barPaint = Paint()..color = const Color(0xFF1E3A0F);
    for (int i = 1; i < 4; i++) {
      canvas.drawRect(
        Rect.fromLTWH(0, 5 + (height * 0.8 / 4) * i, width * 0.65, 3),
        barPaint,
      );
    }

    // Recycling symbol
    final recyclePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final recycleSymbolX = width * 0.32;
    final recycleSymbolY = height * 0.45;
    final arrowSize = 12.0;

    for (int i = 0; i < 3; i++) {
      canvas.save();
      canvas.translate(recycleSymbolX, recycleSymbolY);
      canvas.rotate(i * 2 * math.pi / 3);

      final arrowPath = Path()
        ..moveTo(0, -arrowSize)
        ..lineTo(arrowSize * 0.4, -arrowSize * 0.3)
        ..lineTo(arrowSize * 0.2, -arrowSize * 0.3)
        ..lineTo(arrowSize * 0.2, arrowSize * 0.5)
        ..lineTo(-arrowSize * 0.2, arrowSize * 0.5)
        ..lineTo(-arrowSize * 0.2, -arrowSize * 0.3)
        ..lineTo(-arrowSize * 0.4, -arrowSize * 0.3)
        ..close();

      canvas.drawPath(arrowPath, recyclePaint);
      canvas.restore();
    }

    final latchPaint = Paint()..color = Colors.grey[800]!;
    canvas.drawRect(
      Rect.fromLTWH(width * 0.62, height * 0.4, 8, height * 0.3),
      latchPaint,
    );

    // Cabin (orange)
    final cabinX = width * 0.65;
    final cabinWidth = width * 0.35;
    final cabinY = 15.0;
    final cabinHeight = height * 0.7;

    final cabinPaint = Paint()..color = const Color(0xFFFF6B35);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cabinX, cabinY, cabinWidth, cabinHeight),
        const Radius.circular(5),
      ),
      cabinPaint,
    );

    final roofPaint = Paint()..color = const Color(0xFFE55A2B);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cabinX, cabinY, cabinWidth, cabinHeight * 0.25),
        const Radius.circular(5),
      ),
      roofPaint,
    );

    final sideWindowPaint = Paint()..color = const Color(0xFF5BA3D0);
    final windowX = cabinX + cabinWidth * 0.4;
    final windowY = cabinY + cabinHeight * 0.2;
    final windowWidth = cabinWidth * 0.5;
    final windowHeight = cabinHeight * 0.45;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(windowX, windowY, windowWidth, windowHeight),
        const Radius.circular(3),
      ),
      sideWindowPaint,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(windowX, windowY, windowWidth, windowHeight),
        const Radius.circular(3),
      ),
      Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Wheels
    final wheelRadius = 18.0;

    canvas.save();
    canvas.translate(cabinX + cabinWidth * 0.5, height * 0.9);
    canvas.rotate(wheelRotation);
    _drawWheel(canvas, wheelRadius);
    canvas.restore();

    canvas.save();
    canvas.translate(width * 0.25, height * 0.9);
    canvas.rotate(wheelRotation);
    _drawWheel(canvas, wheelRadius);
    canvas.restore();

    // Headlights
    final headlightPaint = Paint()..color = Colors.yellow[300]!;
    final headlightGlow = Paint()
      ..color = Colors.yellow[300]!.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    canvas.drawCircle(
      Offset(cabinX + cabinWidth - 2, cabinY + cabinHeight * 0.5),
      7,
      headlightGlow,
    );
    canvas.drawCircle(
      Offset(cabinX + cabinWidth - 2, cabinY + cabinHeight * 0.5),
      4,
      headlightPaint,
    );

    final tailLightPaint = Paint()..color = Colors.red[700]!;
    canvas.drawCircle(Offset(3, height * 0.4), 3, tailLightPaint);

    canvas.restore();
  }

  void _drawWheel(Canvas canvas, double radius) {
    final tirePaint = Paint()..color = Colors.black;
    canvas.drawCircle(Offset.zero, radius, tirePaint);

    final sidewallPaint = Paint()
      ..color = Colors.grey[900]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(Offset.zero, radius * 0.85, sidewallPaint);

    final rimPaint = Paint()..color = Colors.grey[600]!;
    canvas.drawCircle(Offset.zero, radius * 0.6, rimPaint);

    final spokePaint = Paint()
      ..color = Colors.grey[800]!
      ..strokeWidth = 2;

    for (int i = 0; i < 5; i++) {
      final angle = (i * math.pi * 2 / 5);
      canvas.drawLine(
        Offset.zero,
        Offset(math.cos(angle) * radius * 0.6, math.sin(angle) * radius * 0.6),
        spokePaint,
      );
    }

    final hubPaint = Paint()..color = Colors.grey[700]!;
    canvas.drawCircle(Offset.zero, radius * 0.2, hubPaint);

    final shinePaint = Paint()..color = Colors.grey[400]!;
    canvas.drawCircle(Offset(-2, -2), radius * 0.1, shinePaint);
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);
    if (other is WasteComponent && !other.isCollected) {
      game.collectWaste(other);
    }
  }
}

// Waste component using PNG assets
class WasteComponent extends SpriteComponent
    with CollisionCallbacks, HasGameReference<CityCollectionGame> {
  final String assetPath;
  bool isCollected = false;

  WasteComponent({required Vector2 position, required this.assetPath})
    : super(position: position, size: Vector2(40, 40));

  @override
  Future<void> onLoad() async {
    super.onLoad();

    // Load the sprite from the asset path
    sprite = Sprite(game.images.fromCache(assetPath));

    // Add collision detection
    add(CircleHitbox(radius: 20));
  }

  void collect() {
    if (!isCollected) {
      isCollected = true;
      removeFromParent();
    }
  }
}

// Recycling bin component
/*class BinComponent extends PositionComponent {
  BinComponent({required Vector2 position})
    : super(position: position, size: Vector2(50, 60));

  @override
  void render(Canvas canvas) {
    // Bin body (green)
    final binPaint = Paint()..color = const Color(0xFF2D5016);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(5, 10, 40, 50),
        const Radius.circular(3),
      ),
      binPaint,
    );

    // Bin lid
    final lidPaint = Paint()..color = const Color(0xFF3A6B1E);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 5, 50, 8),
        const Radius.circular(2),
      ),
      lidPaint,
    );

    // Lid handle
    final handlePaint = Paint()
      ..color = const Color(0xFF1E3A0F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawArc(
      Rect.fromLTWH(15, 0, 20, 10),
      0,
      -math.pi,
      false,
      handlePaint,
    );

    // Recycling symbol on bin
    final recyclePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final symbolX = 25.0;
    final symbolY = 35.0;
    final arrowSize = 8.0;

    for (int i = 0; i < 3; i++) {
      canvas.save();
      canvas.translate(symbolX, symbolY);
      canvas.rotate(i * 2 * math.pi / 3);

      final arrowPath = Path()
        ..moveTo(0, -arrowSize)
        ..lineTo(arrowSize * 0.4, -arrowSize * 0.3)
        ..lineTo(arrowSize * 0.2, -arrowSize * 0.3)
        ..lineTo(arrowSize * 0.2, arrowSize * 0.5)
        ..lineTo(-arrowSize * 0.2, arrowSize * 0.5)
        ..lineTo(-arrowSize * 0.2, -arrowSize * 0.3)
        ..lineTo(-arrowSize * 0.4, -arrowSize * 0.3)
        ..close();

      canvas.drawPath(arrowPath, recyclePaint);
      canvas.restore();
    }
  }
}*/

class HudOverlay extends StatefulWidget {
  final CityCollectionGame game;

  const HudOverlay(this.game, {super.key});

  @override
  State<HudOverlay> createState() => _HudOverlayState();
}

class _HudOverlayState extends State<HudOverlay> {
  @override
  void initState() {
    super.initState();
    // Rebuild the HUD every frame to reflect game state changes
    widget.game.add(
      TimerComponent(
        period: 0.05, // Update 20 times per second for smooth speedometer
        repeat: true,
        onTick: () {
          if (mounted) {
            setState(() {});
          }
        },
      ),
    );
  }

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
                // Timer
                Row(
                  children: [
                    const Icon(Icons.timer, color: Colors.white, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      formatTime(widget.game.timeRemaining),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                // Speedometer
                _buildSpeedometer(),
                // Eco Points
                Row(
                  children: [
                    const Icon(Icons.eco, color: Colors.greenAccent, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      '${widget.game.ecoPoints}',
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
                      'Waste Collected: ${widget.game.wasteCollected}/${widget.game.wasteTotal}',
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

  Widget _buildSpeedometer() {
    // Speed is now directly in km/h
    final speedKmh = widget.game.currentSpeed.toInt();
    final speedPercentage = speedKmh / 150; 
      
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.4),
          width: 2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 65,
            height: 65,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: 1.0,
                  strokeWidth: 6,
                  backgroundColor: Colors.grey[800],
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[800]!),
                ),
                CircularProgressIndicator(
                  value: speedPercentage,
                  strokeWidth: 6,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    speedKmh < 50
                        ? Colors.green
                        : speedKmh < 100
                            ? Colors.orange
                            : Colors.red,
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$speedKmh',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        height: 1.0,
                      ),
                    ),
                    Text(
                      'km/h',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 9,
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.game.isDriving)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      widget.game.drivingDuration > 0.3 ? Icons.fast_forward : Icons.arrow_upward,
                      color: widget.game.drivingDuration > 0.3 ? Colors.lightGreenAccent : Colors.green,
                      size: 14,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      widget.game.drivingDuration > 0.3 ? 'BOOST' : 'ACC',
                      style: TextStyle(
                        color: widget.game.drivingDuration > 0.3 ? Colors.lightGreenAccent : Colors.green,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              if (widget.game.isBraking)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.arrow_downward,
                      color: widget.game.isLongBraking ? Colors.red : Colors.orange,
                      size: 14,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      widget.game.isLongBraking ? 'HARD' : 'BRK',
                      style: TextStyle(
                        color: widget.game.isLongBraking ? Colors.red : Colors.orange,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              if (!widget.game.isDriving && !widget.game.isBraking && widget.game.currentSpeed > 0)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.trending_down,
                      color: Colors.blue,
                      size: 14,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      'COAST',
                      style: TextStyle(
                        color: Colors.blue,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class ControlsOverlay extends StatefulWidget {
  final CityCollectionGame game;

  const ControlsOverlay(this.game, {super.key});

  @override
  State<ControlsOverlay> createState() => _ControlsOverlayState();
}

class _ControlsOverlayState extends State<ControlsOverlay> {
  bool isAcceleratorPressed = false;
  bool isBrakePressed = false;

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
            _buildPedalButton(
              assetPath: 'assets/images/brake.png',
              label: 'Brake',
              isPressed: isBrakePressed,
              onPressed: () {
                setState(() => isBrakePressed = true);
                widget.game.startBraking();
              },
              onReleased: () {
                setState(() => isBrakePressed = false);
                widget.game.stopBraking();
              },
            ),
            const SizedBox(width: 24),
            _buildPedalButton(
              assetPath: 'assets/images/accelerator.png',
              label: 'Drive',
              isPressed: isAcceleratorPressed,
              onPressed: () {
                setState(() => isAcceleratorPressed = true);
                widget.game.startDriving();
              },
              onReleased: () {
                setState(() => isAcceleratorPressed = false);
                widget.game.stopDriving();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPedalButton({
    required String assetPath,
    required String label,
    required bool isPressed,
    required VoidCallback onPressed,
    required VoidCallback onReleased,
  }) {
    return GestureDetector(
      onTapDown: (_) => onPressed(),
      onTapUp: (_) => onReleased(),
      onTapCancel: () => onReleased(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        padding: const EdgeInsets.all(8), // UPDATED: Reduced from 12
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isPressed
                ? Colors.white.withValues(alpha: 0.8)
                : Colors.white.withValues(alpha: 0.3),
            width: 2,
          ),
          boxShadow: isPressed
              ? [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.3),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        transform: Matrix4.identity()..setTranslationRaw(0.0, isPressed ? 4.0 : 0.0, 0.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              assetPath,
              width: 40, // UPDATED: Reduced from 80 (half size)
              height: 40, // UPDATED: Reduced from 80 (half size)
              fit: BoxFit.contain,
              color: isPressed
                  ? Colors.white.withValues(alpha: 1.0)
                  : Colors.white.withValues(alpha: 0.85),
              colorBlendMode: BlendMode.modulate,
            ),
            const SizedBox(height: 6), // UPDATED: Reduced from 8
            Text(
              label,
              style: TextStyle(
                color: isPressed
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.9),
                fontSize: 14, // UPDATED: Reduced from 16
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class GameOverOverlay extends StatelessWidget {
  final CityCollectionGame game;

  const GameOverOverlay(this.game, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.85),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.blue[900]!,
                Colors.blue[700]!,
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.timer_off,
                size: 80,
                color: Colors.orange,
              ),
              const SizedBox(height: 16),
              const Text(
                'TIME\'S UP!',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.eco, color: Colors.greenAccent, size: 28),
                        const SizedBox(width: 12),
                        Text(
                          '${game.ecoPoints} Points',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.greenAccent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.delete, color: Colors.orange, size: 24),
                        const SizedBox(width: 12),
                        Text(
                          '${game.wasteCollected} Waste Collected',
                          style: const TextStyle(
                            fontSize: 20,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 48,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'FINISH',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}