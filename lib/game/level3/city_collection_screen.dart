import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/palette.dart';
import 'package:flame/collisions.dart';
import 'package:flutter/material.dart';
import 'package:flame/extensions.dart';

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
  int ecoPoints = 1250;
  int wasteCollected = 8;
  int wasteTotal = 20;
  int sewerRepairs = 1;
  int sewerTotal = 3;
  int drainsCleared = 0;
  int drainsTotal = 2;

  late SkyLayer skyLayer;
  late BuildingLayer farBuildings;
  late BuildingLayer nearBuildings;
  late StreetLayer streetLayer;
  late TruckComponent truck;

  List<WasteComponent> wastes = [];
  List<DrainComponent> drains = [];
  List<SewerComponent> sewers = [];

  bool isDriving = false;
  bool isBoosting = false;
  double scrollSpeed = 50.0; // Reduced for better control

  @override
  Future<void> onLoad() async {
    super.onLoad();

    // Add layers
    skyLayer = SkyLayer(size: size);
    add(skyLayer);

    farBuildings = BuildingLayer(isFar: true, size: size);
    add(farBuildings);

    nearBuildings = BuildingLayer(isFar: false, size: size);
    add(nearBuildings);

    streetLayer = StreetLayer(size: size);
    add(streetLayer);

    // Add truck
    truck = TruckComponent(position: Vector2(100, size.y - 120), size: Vector2(120, 60));
    add(truck);

    // Generate wastes, drains, sewers
    for (int i = 0; i < wasteTotal; i++) {
      final waste = WasteComponent(position: Vector2(300 + i * 200, size.y - 80));
      add(waste);
      wastes.add(waste);
    }
    for (int i = 0; i < drainsTotal; i++) {
      final drain = DrainComponent(position: Vector2(500 + i * 400, size.y - 70));
      add(drain);
      drains.add(drain);
    }
    for (int i = 0; i < sewerTotal; i++) {
      final sewer = SewerComponent(position: Vector2(400 + i * 300, size.y - 90));
      add(sewer);
      sewers.add(sewer);
    }

    // Timer for time remaining
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

    if (isDriving) {
      final speed = isBoosting ? scrollSpeed * 2 : scrollSpeed;
      // Scroll layers at different speeds for parallax
      farBuildings.scroll(speed * dt * 0.5); // Slow for far
      nearBuildings.scroll(speed * dt * 0.8); // Faster for near
      streetLayer.scroll(speed * dt); // Fastest for ground

      // Move interactables separately to avoid type issues
      for (var waste in wastes) {
        waste.position.x -= speed * dt;
      }
      for (var drain in drains) {
        drain.position.x -= speed * dt;
      }
      for (var sewer in sewers) {
        sewer.position.x -= speed * dt;
      }
    }
  }

  void collectWaste(WasteComponent waste) {
    if (wasteCollected < wasteTotal) {
      remove(waste);
      wastes.remove(waste);
      wasteCollected++;
      ecoPoints += 50;
    }
  }

  void clearDrain(DrainComponent drain) {
    if (drainsCleared < drainsTotal && truck.isNear(drain)) {
      drain.clear();
      drainsCleared++;
      ecoPoints += 100;
    }
  }

  void repairSewer(SewerComponent sewer) {
    if (sewerRepairs < sewerTotal && truck.isNear(sewer)) {
      sewer.repair();
      sewerRepairs++;
      ecoPoints += 150;
    }
  }
}

// Layer classes using shapes
class SkyLayer extends PositionComponent {
  SkyLayer({required Vector2 size}) : super(size: size);

  @override
  void render(Canvas canvas) {
    final paint = Paint()..shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Colors.blue[300]!, Colors.blue[100]!],
    ).createShader(Rect.fromLTWH(0, 0, width, height));
    canvas.drawRect(Rect.fromLTWH(0, 0, width, height), paint);
  }
}

class BuildingLayer extends PositionComponent {
  final bool isFar;
  List<RectangleComponent> buildings = [];

  BuildingLayer({required this.isFar, required Vector2 size}) : super(size: size) {
    // Generate buildings
    for (int i = 0; i < 10; i++) {
      double x = i * 200;
      double height = isFar ? 100 + (i % 3) * 20 : 150 + (i % 4) * 30;
      final building = RectangleComponent(
        position: Vector2(x, size.y - height - 50),
        size: Vector2(150, height),
        paint: Paint()..color = isFar ? Colors.grey[600]! : Colors.grey[800]!,
      );
      add(building);
      buildings.add(building);
    }
  }

  void scroll(double dx) {
    for (var building in buildings) {
      building.position.x -= dx;
      if (building.position.x + building.size.x < 0) {
        building.position.x += 10 * 200; // Loop back
      }
    }
  }
}

class StreetLayer extends PositionComponent {
  List<RectangleComponent> dirtPatches = [];

  StreetLayer({required Vector2 size}) : super(size: size) {
    // Street base
    add(RectangleComponent(
      position: Vector2(0, size.y - 50),
      size: Vector2(size.x * 2, 50), // Extended for scrolling
      paint: Paint()..color = Colors.grey[700]!,
    ));

    // Add dirt patches that can be "cleaned"
    for (int i = 0; i < 20; i++) {
      final dirt = RectangleComponent(
        position: Vector2(100 + i * 150, size.y - 40),
        size: Vector2(50, 20),
        paint: Paint()..color = Colors.brown,
      );
      add(dirt);
      dirtPatches.add(dirt);
    }
  }

  void scroll(double dx) {
    for (var child in children) {
      if (child is PositionComponent) {
        child.position.x -= dx;
        if (child.position.x + child.width < 0) {
          child.position.x += size.x * 2; // Loop
        }
      }
    }
  }

  void cleanNearby(Vector2 position) {
    // Clean dirt near position (e.g., when collecting waste)
    dirtPatches.removeWhere((dirt) {
      if (dirt.position.distanceTo(position) < 100) {
        remove(dirt);
        return true;
      }
      return false;
    });
  }
}

// Truck using shapes
class TruckComponent extends PositionComponent with HasGameReference<CityCollectionGame>, CollisionCallbacks {
  TruckComponent({required Vector2 position, required Vector2 size}) : super(position: position, size: size) {
    // Body
    add(RectangleComponent(
      position: Vector2(0, 0),
      size: Vector2(size.x * 0.6, size.y),
      paint: Paint()..color = Colors.orange,
    ));
    // Back (green)
    add(RectangleComponent(
      position: Vector2(size.x * 0.6, 0),
      size: Vector2(size.x * 0.4, size.y),
      paint: Paint()..color = Colors.green[800]!,
    ));
    // Wheels
    add(CircleComponent(
      radius: 15,
      position: Vector2(20, size.y),
      paint: BasicPalette.black.paint(),
    ));
    add(CircleComponent(
      radius: 15,
      position: Vector2(size.x - 20, size.y),
      paint: BasicPalette.black.paint(),
    ));

    add(RectangleHitbox.relative(Vector2.all(1.0), parentSize: size));
  }

  bool isNear(PositionComponent other) {
    return position.distanceTo(other.position) < 100;
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);
    if (other is WasteComponent) {
      game.collectWaste(other);
      game.streetLayer.cleanNearby(other.position);
    }
  }
}

// Waste as shape
class WasteComponent extends PositionComponent {
  WasteComponent({required Vector2 position}) : super(position: position, size: Vector2(30, 30)) {
    add(CircleComponent(
      radius: 15,
      paint: Paint()..color = Colors.brown,
    ));
    add(RectangleHitbox.relative(Vector2.all(1.0), parentSize: size));
  }
}

// Drain as shape
class DrainComponent extends PositionComponent {
  bool isCleared = false;
  late RectangleComponent baseRect;

  DrainComponent({required Vector2 position}) : super(position: position, size: Vector2(40, 20)) {
    baseRect = RectangleComponent(
      size: size,
      paint: Paint()..color = Colors.black,
    );
    add(baseRect);
    // Dirt overlay
    add(RectangleComponent(
      size: Vector2(40, 10),
      paint: Paint()..color = Colors.brown[800]!,
      priority: 1,
    ));
  }

  void clear() {
    if (!isCleared) {
      isCleared = true;
      children.last.removeFromParent(); // Remove dirt
      baseRect.paint.color = Colors.grey; // Change to clean
    }
  }
}

// Sewer as shape
class SewerComponent extends PositionComponent {
  bool isRepaired = false;

  SewerComponent({required Vector2 position}) : super(position: position, size: Vector2(60, 20)) {
    // Broken pipe: two parts with gap
    add(RectangleComponent(
      position: Vector2(0, 0),
      size: Vector2(25, 20),
      paint: Paint()..color = Colors.brown[900]!,
    ));
    add(RectangleComponent(
      position: Vector2(35, 0),
      size: Vector2(25, 20),
      paint: Paint()..color = Colors.brown[900]!,
    ));
  }

  void repair() {
    if (!isRepaired) {
      isRepaired = true;
      // Add middle part to fix
      add(RectangleComponent(
        position: Vector2(25, 0),
        size: Vector2(10, 20),
        paint: Paint()..color = Colors.brown[900]!,
      ));
    }
  }
}

// HUD and Controls remain the same as previous
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
            padding: const EdgeInsets.all(8.0),
            color: Color.fromRGBO(0, 0, 255, 0.7),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Time ${formatTime(game.timeRemaining)}', style: const TextStyle(color: Colors.white, fontSize: 18)),
                Row(
                  children: [
                    const Icon(Icons.eco, color: Colors.white, size: 20), // Using built-in icon for eco-points
                    const SizedBox(width: 4),
                    Text('Eco-Points ${game.ecoPoints}', style: const TextStyle(color: Colors.white, fontSize: 18)),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTask('Waste Collected', '${game.wasteCollected}/${game.wasteTotal}'),
                _buildTask('Sewer Repairs', '${game.sewerRepairs}/${game.sewerTotal}'),
                _buildTask('Drains Cleared', '${game.drainsCleared}/${game.drainsTotal}'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTask(String label, String progress) {
    return Row(
      children: [
        const Icon(Icons.check, color: Colors.green),
        const SizedBox(width: 8),
        Text('$label $progress', style: const TextStyle(color: Colors.white, fontSize: 16)),
      ],
    );
  }
}

class ControlsOverlay extends StatelessWidget {
  final CityCollectionGame game;

  const ControlsOverlay(this.game, {super.key});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton(
              onPressed: () {
                game.isDriving = !game.isDriving;
              },
              child: const Text('Drive'),
            ),
            ElevatedButton(
              onPressed: () {
                for (var drain in game.drains) {
                  if (game.truck.isNear(drain) && !drain.isCleared) {
                    game.clearDrain(drain);
                    break;
                  }
                }
              },
              child: const Text('Scoop'),
            ),
            ElevatedButton(
              onPressed: () {
                for (var sewer in game.sewers) {
                  if (game.truck.isNear(sewer) && !sewer.isRepaired) {
                    game.repairSewer(sewer);
                    break;
                  }
                }
              },
              child: const Text('Repair'),
            ),
            ElevatedButton(
              onPressed: () {
                game.isBoosting = true;
                Future.delayed(const Duration(seconds: 5), () => game.isBoosting = false);
              },
              child: const Text('Boost'),
            ),
          ],
        ),
      ),
    );
  }
}