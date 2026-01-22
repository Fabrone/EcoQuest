import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

class CraftingWorkshopScreen extends StatefulWidget {
  const CraftingWorkshopScreen({super.key});

  @override
  State<CraftingWorkshopScreen> createState() => _CraftingWorkshopScreenState();
}

class _CraftingWorkshopScreenState extends State<CraftingWorkshopScreen> {
  late CraftingWorkshopGame _game;

  @override
  void initState() {
    super.initState();
    _game = CraftingWorkshopGame();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GameWidget(
        game: _game,
      ),
    );
  }
}

class CraftingWorkshopGame extends FlameGame with TapCallbacks {
  int selectedIndex = 1; // Middle item selected by default
  int ecoCreativityBonus = 50;

  // Define your asset paths here - add these images to your assets/crafting/ folder
  final List<String> itemAssets = [
    'assets/crafting/tire_sandals.png',       // From rubber/tires
    'assets/crafting/glass_bottle_lamp.png',  // From glass bottles
    'assets/crafting/patchwork_jacket.png',   // From fabric/textiles
  ];

  final List<String> itemNames = [
    'Tire Sandals',
    'Glass Bottle Lamp',
    'Patchwork Jacket',
  ];

  late List<Sprite> itemSprites;
  late List<Component> staticComponents; // Components that don't change
  late NavigationButton leftArrow;
  late NavigationButton rightArrow;

  @override
  Future<void> onLoad() async {
    super.onLoad();

    staticComponents = [];

    // Workshop background (wooden shelves/workbench feel)
    final background = RectangleComponent(
      size: size,
      paint: Paint()..color = Colors.brown[900]!,
    );
    add(background);
    staticComponents.add(background);

    // Wooden shelf bar
    final shelf = RectangleComponent(
      position: Vector2(0, size.y * 0.35),
      size: Vector2(size.x, 40),
      paint: Paint()..color = Colors.orange[800]!,
    );
    add(shelf);
    staticComponents.add(shelf);

    // Title
    final title = TextComponent(
      text: 'Crafting Workshop',
      position: Vector2(size.x / 2, 40),
      anchor: Anchor.topCenter,
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 32,
          fontWeight: FontWeight.bold,
          shadows: [Shadow(color: Colors.black54, offset: Offset(2, 2), blurRadius: 4)],
        ),
      ),
    );
    add(title);
    staticComponents.add(title);

    // Tabs (Fashion, Interior, School) - Interior highlighted
    final tabY = 120.0;
    final tabWidth = size.x / 3;
    final tabHeight = 50.0;

    // Fashion tab
    final fashionTab = RectangleComponent(
      position: Vector2(0, tabY),
      size: Vector2(tabWidth, tabHeight),
      paint: Paint()..color = Colors.red[700]!,
    );
    add(fashionTab);
    staticComponents.add(fashionTab);
    
    final fashionText = TextComponent(
      text: 'Fashion',
      position: Vector2(tabWidth / 2, tabY + tabHeight / 2),
      anchor: Anchor.center,
      textRenderer: TextPaint(style: const TextStyle(color: Colors.white, fontSize: 20)),
    );
    add(fashionText);
    staticComponents.add(fashionText);

    // Interior tab (highlighted)
    final interiorTab = RectangleComponent(
      position: Vector2(tabWidth, tabY),
      size: Vector2(tabWidth, tabHeight),
      paint: Paint()..color = Colors.green[700]!,
    );
    add(interiorTab);
    staticComponents.add(interiorTab);
    
    final interiorText = TextComponent(
      text: 'Interior',
      position: Vector2(tabWidth * 1.5, tabY + tabHeight / 2),
      anchor: Anchor.center,
      textRenderer: TextPaint(style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
    );
    add(interiorText);
    staticComponents.add(interiorText);

    // School tab
    final schoolTab = RectangleComponent(
      position: Vector2(tabWidth * 2, tabY),
      size: Vector2(tabWidth, tabHeight),
      paint: Paint()..color = Colors.red[700]!,
    );
    add(schoolTab);
    staticComponents.add(schoolTab);
    
    final schoolText = TextComponent(
      text: 'School',
      position: Vector2(tabWidth * 2.5, tabY + tabHeight / 2),
      anchor: Anchor.center,
      textRenderer: TextPaint(style: const TextStyle(color: Colors.white, fontSize: 20)),
    );
    add(schoolText);
    staticComponents.add(schoolText);

    // Load item sprites
    itemSprites = [];
    for (final asset in itemAssets) {
      itemSprites.add(await loadSprite(asset));
    }

    // Navigation arrows
    leftArrow = NavigationButton(
      position: Vector2(40, size.y / 2 + 50),
      isLeft: true,
      onTap: () {
        if (selectedIndex > 0) {
          selectedIndex--;
          updateDisplayedItems();
        }
      },
    );
    add(leftArrow);
    staticComponents.add(leftArrow);

    rightArrow = NavigationButton(
      position: Vector2(size.x - 40, size.y / 2 + 50),
      isLeft: false,
      onTap: () {
        if (selectedIndex < itemSprites.length - 1) {
          selectedIndex++;
          updateDisplayedItems();
        }
      },
    );
    add(rightArrow);
    staticComponents.add(rightArrow);

    // Display items
    updateDisplayedItems();

    // Craft button at bottom
    final buttonY = size.y - 100;
    final craftButton = CraftButton(
      position: Vector2(size.x / 2 - 200, buttonY),
      size: Vector2(400, 70),
      onTap: () {
        // Here you would deduct recyclables from inventory and add points/bonus
        debugPrint('Crafted! +$ecoCreativityBonus Eco-Creativity');
      },
    );
    add(craftButton);
    staticComponents.add(craftButton);

    // Button text (separate for layering)
    final buttonText = TextComponent(
      text: 'Eco-Creativity +$ecoCreativityBonus',
      position: Vector2(size.x / 2, buttonY + 35),
      anchor: Anchor.center,
      textRenderer: TextPaint(
        style: TextStyle(color: Colors.green[800], fontSize: 28, fontWeight: FontWeight.bold),
      ),
    );
    add(buttonText);
    staticComponents.add(buttonText);
  }

  void updateDisplayedItems() {
    // Remove only dynamic components (sprites and their name texts)
    final componentsToRemove = children.where((c) => !staticComponents.contains(c)).toList();
    for (final component in componentsToRemove) {
      remove(component);
    }

    final itemY = size.y / 2 + 50;
    final baseSize = Vector2(120, 180);

    // Left item
    if (selectedIndex > 0) {
      final leftSprite = SpriteComponent(
        sprite: itemSprites[selectedIndex - 1],
        size: baseSize,
        position: Vector2(size.x / 2 - baseSize.x * 1.5, itemY),
        anchor: Anchor.center,
      );
      add(leftSprite);
      
      add(TextComponent(
        text: itemNames[selectedIndex - 1],
        position: Vector2(size.x / 2 - baseSize.x * 1.5, itemY + baseSize.y / 2 + 20),
        anchor: Anchor.center,
        textRenderer: TextPaint(style: const TextStyle(color: Colors.white, fontSize: 18)),
      ));
    }

    // Glow effect for selected (add before sprite for proper layering)
    add(CircleComponent(
      radius: baseSize.x * 0.75,
      position: Vector2(size.x / 2, itemY),
      anchor: Anchor.center,
      paint: Paint()..color = Colors.yellow.withAlpha(102), // 0.4 opacity
    ));

    // Middle selected item (larger + glow)
    final middleSprite = SpriteComponent(
      sprite: itemSprites[selectedIndex],
      size: baseSize * 1.3,
      position: Vector2(size.x / 2, itemY),
      anchor: Anchor.center,
    );
    add(middleSprite);

    add(TextComponent(
      text: itemNames[selectedIndex],
      position: Vector2(size.x / 2, itemY + baseSize.y * 1.3 / 2 + 40),
      anchor: Anchor.center,
      textRenderer: TextPaint(style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
    ));

    // Right item
    if (selectedIndex < itemSprites.length - 1) {
      final rightSprite = SpriteComponent(
        sprite: itemSprites[selectedIndex + 1],
        size: baseSize,
        position: Vector2(size.x / 2 + baseSize.x * 1.5, itemY),
        anchor: Anchor.center,
      );
      add(rightSprite);
      
      add(TextComponent(
        text: itemNames[selectedIndex + 1],
        position: Vector2(size.x / 2 + baseSize.x * 1.5, itemY + baseSize.y / 2 + 20),
        anchor: Anchor.center,
        textRenderer: TextPaint(style: const TextStyle(color: Colors.white, fontSize: 18)),
      ));
    }
  }
}

// Navigation arrow button
class NavigationButton extends PositionComponent with TapCallbacks {
  final bool isLeft;
  final VoidCallback onTap;

  NavigationButton({
    required Vector2 position,
    required this.isLeft,
    required this.onTap,
  }) : super(position: position, size: Vector2(60, 60), anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    super.onLoad();
    
    // Arrow background circle
    add(CircleComponent(
      radius: 30,
      paint: Paint()..color = Colors.white.withAlpha(77), // 0.3 opacity
      anchor: Anchor.center,
    ));

    // Arrow triangle
    final arrowPoints = isLeft
        ? [Vector2(10, 0), Vector2(-10, -15), Vector2(-10, 15)]
        : [Vector2(-10, 0), Vector2(10, -15), Vector2(10, 15)];
    
    add(PolygonComponent(
      arrowPoints,
      paint: Paint()..color = Colors.white,
      anchor: Anchor.center,
    ));
  }

  @override
  void onTapDown(TapDownEvent event) {
    onTap();
  }
}

// Custom craft button with proper TapCallbacks
class CraftButton extends RectangleComponent with TapCallbacks {
  final VoidCallback onTap;

  CraftButton({required Vector2 position, required Vector2 size, required this.onTap})
      : super(
          position: position,
          size: size,
          paint: Paint()..color = Colors.yellow[700]!,
        );

  @override
  void onTapDown(TapDownEvent event) {
    onTap();
  }
}