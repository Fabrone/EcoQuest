import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/game.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/material.dart';
import '../main.dart';
import 'eco_components.dart';

// FIXED: Removed HasGameRef, using standard mixins if needed, 
// but HasGameReference is applied on the Components side. 
class EcoQuestGame extends FlameGame {
  
  // Configuration
  static const int rows = 8;
  static const int cols = 8;
  
  // Dynamic sizing logic
  late double tileSize; 
  late double boardWidth;
  late double boardHeight;
  late double startX;
  late double startY;

  // State
  late List<List<TileComponent>> gridTiles;
  late List<List<EcoItem?>> gridItems;
  EcoItem? selectedItem;
  bool isProcessing = false;

  final List<String> itemTypes = [
     'pinnate_leaf', 'leaf_design', 'blue_butterfly', 'red_flower', 'yellow_flower', 'pink_flower', 'flower_red', 'clouds', 'sun', 
    'green_tree', 'flower_simple', 'rainy', 'bird'
  ];

  @override
  Future<void> onLoad() async {
    super.onLoad();
    debugPrint("--- GAME LOADING STARTED ---");

    // 1. Dynamic Sizing Calculation (Responsive Fit)
    // We calculate the maximum possible tile size that allows the grid to fit
    // within the screen width OR height, leaving a small margin.
    double maxW = size.x / cols;
    double maxH = size.y / rows;
    tileSize = min(maxW, maxH) * 0.95; // 95% to leave a small margin

    boardWidth = cols * tileSize;
    boardHeight = rows * tileSize;
    startX = (size.x - boardWidth) / 2;
    startY = (size.y - boardHeight) / 2;

    debugPrint("Screen: $size, TileSize: $tileSize");

    // 2. Add Background
    try {
      final bgSprite = await loadSprite('tile_bg.png');
      add(SpriteComponent()
        ..sprite = bgSprite
        ..size = size
        ..anchor = Anchor.topLeft);
    } catch (e) {
      // Fallback
      add(RectangleComponent(size: size, paint: Paint()..color = const Color(0xFF2D1E17))); 
    }

    // 3. Audio
    await FlameAudio.audioCache.load('bubble-pop.mp3');

    // 4. Init Data
    gridTiles = List.generate(rows, (_) => List.generate(cols, (_) => TileComponent()));
    gridItems = List.generate(rows, (_) => List.generate(cols, (_) => null));

    // 5. Build Board
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        Vector2 pos = Vector2(startX + c * tileSize, startY + r * tileSize);

        // Create Tile
        final tile = TileComponent(sizeVal: tileSize)
          ..position = pos
          ..size = Vector2(tileSize, tileSize)
          ..gridPosition = Point(r, c);
        gridTiles[r][c] = tile;
        add(tile);

        // Create Item
        String type;
        do {
          type = itemTypes[Random().nextInt(itemTypes.length)];
        } while (_causesMatch(r, c, type));

        final item = EcoItem(type: type, sizeVal: tileSize)
          ..position = pos.clone()
          ..size = Vector2(tileSize, tileSize)
          ..gridPosition = Point(r, c);
        
        gridItems[r][c] = item;
        add(item);
      }
    }

    overlays.add('HUD');
  }

  bool _causesMatch(int r, int c, String type) {
    if (c >= 2 && gridItems[r][c - 1]?.type == type && gridItems[r][c - 2]?.type == type) return true;
    if (r >= 2 && gridItems[r - 1][c]?.type == type && gridItems[r - 2][c]?.type == type) return true;
    return false;
  }

  // --- GAMEPLAY LOGIC ---

  void onTileTapped(EcoItem tappedItem) {
    if (isProcessing) return;

    if (selectedItem == null) {
      selectedItem = tappedItem;
      tappedItem.isSelected = true;
      FlameAudio.play('bubble-pop.mp3', volume: 0.2);
    } else {
      EcoItem first = selectedItem!;
      EcoItem second = tappedItem;
      
      first.isSelected = false;
      selectedItem = null;

      if (first == second) return;

      int rDiff = (first.gridPosition.x - second.gridPosition.x).abs() as int;
      int cDiff = (first.gridPosition.y - second.gridPosition.y).abs() as int;

      if (rDiff + cDiff == 1) {
        _swapItems(first, second);
      }
    }
  }

  Future<void> _swapItems(EcoItem item1, EcoItem item2) async {
    isProcessing = true;

    final pos1 = item1.position.clone();
    final pos2 = item2.position.clone();

    // Visual Swap
    item1.add(MoveToEffect(pos2, EffectController(duration: 0.2)));
    item2.add(MoveToEffect(pos1, EffectController(duration: 0.2)));
    
    await Future.delayed(const Duration(milliseconds: 220));

    // Logical Swap
    Point p1 = item1.gridPosition;
    Point p2 = item2.gridPosition;

    gridItems[p1.x as int][p1.y as int] = item2;
    gridItems[p2.x as int][p2.y as int] = item1;

    item1.gridPosition = p2;
    item2.gridPosition = p1;

    // Check Matches
    List<EcoItem> matches = _findMatches();
    
    if (matches.isNotEmpty) {
      await _processMatches(matches);
    } else {
      // Revert if no match
      item1.add(MoveToEffect(pos1, EffectController(duration: 0.2)));
      item2.add(MoveToEffect(pos2, EffectController(duration: 0.2)));
      
      gridItems[p1.x as int][p1.y as int] = item1;
      gridItems[p2.x as int][p2.y as int] = item2;
      item1.gridPosition = p1;
      item2.gridPosition = p2;
      
      isProcessing = false;
    }
  }

  List<EcoItem> _findMatches() {
    Set<EcoItem> matchSet = {};
    
    // Horizontal
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols - 2; c++) {
        EcoItem? i1 = gridItems[r][c];
        EcoItem? i2 = gridItems[r][c+1];
        EcoItem? i3 = gridItems[r][c+2];
        
        if (i1 != null && i2 != null && i3 != null) {
          if (i1.type == i2.type && i2.type == i3.type) {
            matchSet.addAll([i1, i2, i3]);
          }
        }
      }
    }

    // Vertical
    for (int c = 0; c < cols; c++) {
      for (int r = 0; r < rows - 2; r++) {
        EcoItem? i1 = gridItems[r][c];
        EcoItem? i2 = gridItems[r+1][c];
        EcoItem? i3 = gridItems[r+2][c];
        
        if (i1 != null && i2 != null && i3 != null) {
          if (i1.type == i2.type && i2.type == i3.type) {
            matchSet.addAll([i1, i2, i3]);
          }
        }
      }
    }
    return matchSet.toList();
  }

  Future<void> _processMatches(List<EcoItem> matches) async {
    FlameAudio.play('bubble-pop.mp3');
    scoreNotifier.value += (matches.length * 10);
    
    for (var item in matches) {
      int r = item.gridPosition.x as int;
      int c = item.gridPosition.y as int;
      
      gridTiles[r][c].restoreNature();
      
      gridItems[r][c] = null;
      item.removeFromParent();
    }

    await Future.delayed(const Duration(milliseconds: 100));

    // Spawn new items
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (gridItems[r][c] == null) {
          String newType = itemTypes[Random().nextInt(itemTypes.length)];
          EcoItem newItem = EcoItem(type: newType, sizeVal: tileSize)
            ..position = gridTiles[r][c].position.clone()
            ..size = Vector2(tileSize, tileSize)
            ..gridPosition = Point(r, c);
          
          newItem.scale = Vector2.zero();
          newItem.add(ScaleEffect.to(Vector2.all(1.0), EffectController(duration: 0.3, curve: Curves.elasticOut)));
          
          gridItems[r][c] = newItem;
          add(newItem);
        }
      }
    }

    List<EcoItem> newMatches = _findMatches();
    if (newMatches.isNotEmpty) {
      await Future.delayed(const Duration(milliseconds: 300));
      await _processMatches(newMatches);
    } else {
      isProcessing = false;
    }
  }
}