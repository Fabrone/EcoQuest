import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame_audio/flame_audio.dart';
import 'eco_components.dart';

class EcoQuestGame extends FlameGame with HasGameRef {
  // Grid Configuration
  static const int rows = 8;
  static const int cols = 8;
  final double tileSize = 64.0; // Size of each tile in pixels
  
  // Game State
  late List<List<TileComponent>> gridTiles;
  late List<List<EcoItem?>> gridItems;
  
  // Selection Logic
  EcoItem? selectedItem;
  bool isProcessing = false; // Lock input while animations play
  int score = 0;

  // Eco-friendly asset list
  final List<String> itemTypes = [
    'pinnate_leaf', 'leaf_design', 'blue_butterfly', 'red_flower', 'yellow_flower', 'pink_flower', 'flower_red', 'clouds', 'sun', 
    'green_tree', 'flower_simple', 'rainy', 'bird' 
  ];

  @override
  Future<void> onLoad() async {
    super.onLoad();
    
    // Center the camera/world
    camera.viewfinder.anchor = Anchor.topLeft;

    // Initialize Data Structures
    gridTiles = List.generate(rows, (_) => List.generate(cols, (_) => TileComponent()));
    gridItems = List.generate(rows, (_) => List.generate(cols, (_) => null));

    // Build the Board
    await _buildBoard();
  }

  Future<void> _buildBoard() async {
    // Calculate offset to center the grid in the 3/4 view
    double boardWidth = cols * tileSize;
    double boardHeight = rows * tileSize;
    double startX = (size.x - boardWidth) / 2;
    double startY = (size.y - boardHeight) / 2;

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        // 1. Create Background Tile
        final tile = TileComponent()
          ..position = Vector2(startX + c * tileSize, startY + r * tileSize)
          ..size = Vector2(tileSize, tileSize)
          ..gridPosition = Point(r, c);
        
        gridTiles[r][c] = tile;
        add(tile);

        // 2. Create Eco Item (Ensure no initial matches)
        String type;
        do {
          type = itemTypes[Random().nextInt(itemTypes.length)];
        } while (_hasMatchAt(r, c, type));

        final item = EcoItem(type: type)
          ..position = Vector2(startX + c * tileSize, startY + r * tileSize)
          ..size = Vector2(tileSize, tileSize)
          ..gridPosition = Point(r, c);
        
        gridItems[r][c] = item;
        add(item);
      }
    }
  }

  // Initial board generation check to prevent pre-existing matches
  bool _hasMatchAt(int r, int c, String type) {
    if (c >= 2 && gridItems[r][c - 1]?.type == type && gridItems[r][c - 2]?.type == type) return true;
    if (r >= 2 && gridItems[r - 1][c]?.type == type && gridItems[r - 2][c]?.type == type) return true;
    return false;
  }

  // Input Handling
  void onItemSelected(EcoItem item) {
    if (isProcessing) return;

    if (selectedItem == null) {
      // Select first item
      selectedItem = item;
      item.isSelected = true;
    } else {
      // Select second item
      EcoItem first = selectedItem!;
      EcoItem second = item;
      
      first.isSelected = false;
      selectedItem = null;

      if (first == second) return; // Tapped same item twice

      // Check adjacency
      if ((first.gridPosition.x - second.gridPosition.x).abs() + 
          (first.gridPosition.y - second.gridPosition.y).abs() == 1) {
        _swapAndCheck(first, second);
      }
    }
  }

  Future<void> _swapAndCheck(EcoItem item1, EcoItem item2) async {
    isProcessing = true;

    // 1. Visually Swap
    final pos1 = item1.position.clone();
    final pos2 = item2.position.clone();
    
    // Using Flame Effects for smooth animation
    // Note: In a real app, use MoveEffect.to. For prototype, we swap positions instantly or use simple lerp
    item1.position = pos2;
    item2.position = pos1;

    // 2. Swap in Data Structure
    final p1 = item1.gridPosition;
    final p2 = item2.gridPosition;

    gridItems[p1.x as int][p1.y as int] = item2;
    gridItems[p2.x as int][p2.y as int] = item1;

    item1.gridPosition = p2;
    item2.gridPosition = p1;

    // 3. Check Matches
    List<EcoItem> matches = _findMatches();

    if (matches.isNotEmpty) {
      await _processMatches(matches);
    } else {
      // No match? Swap back (Illegal move)
      await Future.delayed(const Duration(milliseconds: 200));
      item1.position = pos1;
      item2.position = pos2;
      
      // Revert data
      gridItems[p1.x as int][p1.y as int] = item1;
      gridItems[p2.x as int][p2.y as int] = item2;
      
      item1.gridPosition = p1;
      item2.gridPosition = p2;
      isProcessing = false;
    }
  }

  List<EcoItem> _findMatches() {
    Set<EcoItem> matchedItems = {};

    // Horizontal
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols - 2; c++) {
        EcoItem? t1 = gridItems[r][c];
        EcoItem? t2 = gridItems[r][c+1];
        EcoItem? t3 = gridItems[r][c+2];
        
        if (t1 != null && t2 != null && t3 != null) {
          if (t1.type == t2.type && t2.type == t3.type) {
            matchedItems.addAll([t1, t2, t3]);
          }
        }
      }
    }

    // Vertical
    for (int c = 0; c < cols; c++) {
      for (int r = 0; r < rows - 2; r++) {
        EcoItem? t1 = gridItems[r][c];
        EcoItem? t2 = gridItems[r+1][c];
        EcoItem? t3 = gridItems[r+2][c];

        if (t1 != null && t2 != null && t3 != null) {
          if (t1.type == t2.type && t2.type == t3.type) {
            matchedItems.addAll([t1, t2, t3]);
          }
        }
      }
    }
    return matchedItems.toList();
  }

  Future<void> _processMatches(List<EcoItem> matches) async {
    // Play Sound
    FlameAudio.play('burst.mp3');

    // 1. Remove items and Update Backgrounds
    for (var item in matches) {
      // Turn tile gold (Jewel Quest mechanic)
      gridTiles[item.gridPosition.x as int][item.gridPosition.y as int].turnGold();
      
      // "Burst" animation (Scale down to 0 then remove)
      // For prototype, we just remove from parent
      gridItems[item.gridPosition.x as int][item.gridPosition.y as int] = null;
      remove(item);
      score += 10; // Add score
    }

    // 2. Drop down logic (Simplified for prototype: spawn new immediately in place)
    // To do real gravity, you iterate columns from bottom up.
    // Here we just refill empty slots for Level 1 simplicity.
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (gridItems[r][c] == null) {
             final newItem = EcoItem(type: itemTypes[Random().nextInt(itemTypes.length)])
              ..position = gridTiles[r][c].position.clone()
              ..size = Vector2(tileSize, tileSize)
              ..gridPosition = Point(r, c);
            
            gridItems[r][c] = newItem;
            add(newItem);
        }
      }
    }
    
    // Check for chain reactions (Cascades)
    List<EcoItem> newMatches = _findMatches();
    if (newMatches.isNotEmpty) {
      await Future.delayed(const Duration(milliseconds: 300));
      await _processMatches(newMatches);
    } else {
      isProcessing = false;
    }
  }
}