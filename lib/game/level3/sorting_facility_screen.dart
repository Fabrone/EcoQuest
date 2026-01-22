import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/collisions.dart';
import 'package:flame/extensions.dart';
import 'package:flutter/material.dart';
import 'package:flame/events.dart';

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
  int ecoPoints = 0; // Can link to previous screen if needed

  late SkyLayer skyLayer;
  late CityBackground cityBackground;
  late RiverComponent river;
  late ShelfComponent shelf;
  late MiniMapComponent miniMap;

  List<WasteItemComponent> items = [];
  List<BinComponent> bins = [];

  WasteItemComponent? _draggedItem;
  Vector2? _originalPosition;

  @override
  Future<void> onLoad() async {
    super.onLoad();

    // Background
    skyLayer = SkyLayer(size: size);
    add(skyLayer);

    cityBackground = CityBackground(size: size);
    add(cityBackground);

    river = RiverComponent(size: size);
    add(river);

    // Mini-map (approximated with shapes)
    miniMap = MiniMapComponent(position: Vector2(size.x - 150, 50), size: Vector2(140, 100));
    add(miniMap);

    // Shelf for items
    shelf = ShelfComponent(position: Vector2(0, size.y * 0.35), size: Vector2(size.x, 20));
    add(shelf);

    // Bins
    final binWidth = size.x / 4 - 20;
    bins = [
      BinComponent(type: BinType.plastic, position: Vector2(10, size.y * 0.55), size: Vector2(binWidth, 100)),
      BinComponent(type: BinType.metal, position: Vector2(binWidth + 30, size.y * 0.55), size: Vector2(binWidth, 100)),
      BinComponent(type: BinType.organic, position: Vector2(2 * binWidth + 50, size.y * 0.55), size: Vector2(binWidth, 100)),
      BinComponent(type: BinType.eWaste, position: Vector2(3 * binWidth + 70, size.y * 0.55), size: Vector2(binWidth, 100)),
    ];
    for (var bin in bins) {
      add(bin);
    }

    // Generate waste items on shelf
    generateItems();

    // Instruction text
    add(TextComponent(
      text: 'Drag Items to the Correct Bins!',
      position: Vector2(size.x / 2, size.y - 50),
      anchor: Anchor.center,
      textRenderer: TextPaint(style: const TextStyle(color: Colors.white, fontSize: 20)),
    ));

    // Timer
    add(TimerComponent(
      period: 1.0,
      repeat: true,
      onTick: () {
        timeRemaining -= 1;
        progress = timeRemaining / 105; // Update progress based on time
        if (timeRemaining <= 0) {
          pauseEngine();
          // Game over logic
        }
      },
    ));
  }

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    // Loop in reverse to pick topmost item
    for (var item in items.reversed) {
      if (item.containsPoint(event.canvasPosition)) {
        _draggedItem = item;
        _originalPosition = item.position.clone();
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
      _draggedItem = null;
      _originalPosition = null;
    }
  }

  void generateItems() {
    // Generate random items (e.g., 10 items)
    final types = BinType.values;
    for (int i = 0; i < 10; i++) {
      final type = types[i % types.length];
      final item = WasteItemComponent(
        type: type,
        position: Vector2(50 + i * 80, size.y * 0.3),
        size: Vector2(40, 40),
      );
      add(item);
      items.add(item);
    }
  }

  void sortItem(WasteItemComponent item, BinComponent bin) {
    if (item.type == bin.type) {
      ecoPoints += 10; // Correct
    } else {
      ecoPoints -= 5; // Incorrect
    }
    remove(item);
    items.remove(item);
    if (items.isEmpty) {
      generateItems(); // New batch
    }
  }
}

enum BinType { plastic, metal, organic, eWaste }

// Background components
class SkyLayer extends PositionComponent {
  SkyLayer({required Vector2 size}) : super(size: size);

  @override
  void render(Canvas canvas) {
    final paint = Paint()..shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Colors.blueGrey[300]!, Colors.blueGrey[100]!],
    ).createShader(Rect.fromLTWH(0, 0, width, height));
    canvas.drawRect(Rect.fromLTWH(0, 0, width, height), paint);
  }
}

class CityBackground extends PositionComponent {
  CityBackground({required Vector2 size}) : super(size: size) {
    // Simple buildings
    for (int i = 0; i < 8; i++) {
      add(RectangleComponent(
        position: Vector2(i * 100, size.y * 0.2 - (i % 3) * 20),
        size: Vector2(80, 100 + (i % 4) * 20),
        paint: Paint()..color = Colors.grey[700]!,
      ));
    }
  }
}

class RiverComponent extends PositionComponent {
  RiverComponent({required Vector2 size}) : super(size: size) {
    add(RectangleComponent(
      position: Vector2(0, size.y * 0.25),
      size: Vector2(size.x, 50),
      paint: Paint()..color = Colors.blue[800]!,
    ));
  }
}

class MiniMapComponent extends PositionComponent {
  MiniMapComponent({required Vector2 position, required Vector2 size}) : super(position: position, size: size) {
    // Approximate mini-map with shapes
    add(RectangleComponent(
      size: size,
      paint: Paint()..color = Colors.blue[900]!,
    ));
    // Pins and paths
    add(CircleComponent(radius: 5, position: Vector2(20, 20), paint: Paint()..color = Colors.red));
    add(RectangleComponent(position: Vector2(30, 30), size: Vector2(50, 5), paint: Paint()..color = Colors.green));
    // etc.
  }
}

class ShelfComponent extends PositionComponent {
  ShelfComponent({required Vector2 position, required Vector2 size}) : super(position: position, size: size) {
    add(RectangleComponent(
      size: size,
      paint: Paint()..color = Colors.orange[800]!,
    ));
  }
}

class BinComponent extends PositionComponent with CollisionCallbacks {
  final BinType type;

  BinComponent({required this.type, required Vector2 position, required Vector2 size}) : super(position: position, size: size) {
    Color color;
    String label;
    switch (type) {
      case BinType.plastic:
        color = Colors.blue;
        label = 'Plastic';
        break;
      case BinType.metal:
        color = Colors.grey;
        label = 'Metal';
        break;
      case BinType.organic:
        color = Colors.green;
        label = 'Organic';
        break;
      case BinType.eWaste:
        color = Colors.brown;
        label = 'E-Waste';
        break;
    }

    // Bin body
    add(RectangleComponent(
      size: size,
      paint: Paint()..color = color,
    ));

    // Recycling symbol approximation (three arrows)
    final arrowPaint = Paint()..color = Colors.white;
    add(PolygonComponent(
      [Vector2(20, 20), Vector2(40, 20), Vector2(30, 40)],
      position: Vector2(size.x / 2 - 20, size.y / 2 - 20),
      paint: arrowPaint,
    ));
    add(PolygonComponent(
      [Vector2(40, 40), Vector2(40, 60), Vector2(20, 50)],
      position: Vector2(size.x / 2 - 20, size.y / 2 - 20),
      paint: arrowPaint,
    ));
    add(PolygonComponent(
      [Vector2(20, 60), Vector2(0, 60), Vector2(10, 40)],
      position: Vector2(size.x / 2 - 20, size.y / 2 - 20),
      paint: arrowPaint,
    ));

    // Label (using overlay or text)
    add(TextComponent(
      text: label,
      position: Vector2(-10, -30), // Above bin
      textRenderer: TextPaint(style: const TextStyle(color: Colors.white, fontSize: 18)),
    ));

    add(RectangleHitbox(size: size));
  }
}

class WasteItemComponent extends PositionComponent {
  final BinType type;

  WasteItemComponent({required this.type, required Vector2 position, required Vector2 size}) : super(position: position, size: size) {
    Color color;
    switch (type) {
      case BinType.plastic:
        color = Colors.blue[300]!;
        break;
      case BinType.metal:
        color = Colors.grey[400]!;
        break;
      case BinType.organic:
        color = Colors.green[300]!;
        break;
      case BinType.eWaste:
        color = Colors.orange[300]!;
        break;
    }
    // Represent item as a shape (e.g., crumpled paper or bottle approx with circle/rect)
    add(CircleComponent(radius: 20, paint: Paint()..color = color));

    add(RectangleHitbox(size: size));
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
          const Text(
            'Sorting & Recycling Facility',
            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          ),
          Container(
            padding: const EdgeInsets.all(8.0),
            color: Colors.teal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Sort Timer ${formatTime(game.timeRemaining)}', style: const TextStyle(color: Colors.white, fontSize: 18)),
                Container(
                  width: 100,
                  height: 10,
                  color: Colors.black,
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: game.progress,
                    child: Container(color: Colors.yellow),
                  ),
                ),
                Text('${(game.progress * 100).toInt()}%', style: const TextStyle(color: Colors.yellow, fontSize: 18)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}