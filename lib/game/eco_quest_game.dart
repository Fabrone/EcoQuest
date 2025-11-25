import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/game.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/material.dart';
import '../main.dart';
import 'eco_components.dart';

class EcoQuestGame extends FlameGame {
  
  // Configuration
  static const int rows = 4;
  static const int cols = 4;
  
  // Dynamic sizing logic
  late double tileSize; 
  late double boardWidth;
  late double boardHeight;
  late double startX;
  late double startY;

  // State Management
  late List<List<EcoItem?>> gridItems;
  EcoItem? selectedItem;
  bool isProcessing = false;
  
  // Utilities State
  int hintsRemaining = 5; 
  int undoRemaining = 3;
  
  // Undo State
  int? undoRow1, undoCol1, undoRow2, undoCol2;
  String? undoType1, undoType2;

  final List<String> level1ItemTypes = ['pinnate_leaf', 'leaf_design', 'blue_butterfly', 'red_flower', 'yellow_flower'];

  @override
  Future<void> onLoad() async {
    super.onLoad();

    // Dynamic Sizing
    double availableHeight = size.y * 0.6; 
    double maxW = size.x / cols;
    double maxH = availableHeight / rows;
    tileSize = min(maxW, maxH) * 0.95;

    boardWidth = cols * tileSize;
    boardHeight = rows * tileSize;
    startX = (size.x - boardWidth) / 2;
    startY = (size.y - boardHeight) / 2;

    // Background
    try {
      final bgSprite = await loadSprite('tile_bg.png');
      add(SpriteComponent()
        ..sprite = bgSprite
        ..size = size
        ..anchor = Anchor.topLeft
        ..priority = -1);
    } catch (e) {
      add(RectangleComponent(
        size: size, 
        paint: Paint()..color = const Color(0xFF2D1E17),
        priority: -1
      )); 
    }

    // Audio
    await FlameAudio.audioCache.load('bubble-pop.mp3');

    // Init Data
    gridItems = List.generate(rows, (_) => List.generate(cols, (_) => null));

    // --- LEVEL 1 PREDEFINED LOGIC ---
    // Instead of random, we build a specific tutorial grid first.
    debugPrint("🏗️ Building Predefined Level 1...");
    _buildTutorialGrid();

    overlays.add('HUD');
  }

  // --- PREDEFINED LEVEL GENERATION ---
  void _buildTutorialGrid() {
    // This map ensures an easy first move:
    // Row 0: [Leaf, Leaf, Butterfly, Leaf] -> Swap Butterfly & Leaf to match 3
    List<List<String>> fixedMap = [
      ['pinnate_leaf', 'pinnate_leaf', 'blue_butterfly', 'pinnate_leaf'],
      ['red_flower', 'yellow_flower', 'leaf_design', 'red_flower'],
      ['leaf_design', 'pinnate_leaf', 'blue_butterfly', 'yellow_flower'],
      ['yellow_flower', 'red_flower', 'pinnate_leaf', 'leaf_design'],
    ];

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        _spawnItemAt(r, c, fixedMap[r][c], animate: false);
      }
    }
  }

  // Helper to spawn items
  void _spawnItemAt(int r, int c, String type, {bool animate = true}) {
    Vector2 finalPos = Vector2(startX + c * tileSize, startY + r * tileSize);
    Vector2 spawnPos = animate ? Vector2(startX + c * tileSize, startY - tileSize) : finalPos;

    final item = EcoItem(type: type, sizeVal: tileSize)
      ..position = spawnPos
      ..size = Vector2(tileSize, tileSize)
      ..gridPosition = Point(r, c)
      ..priority = 1;
    
    gridItems[r][c] = item;
    add(item);

    if (animate) {
      item.add(MoveToEffect(finalPos, EffectController(duration: 0.4, curve: Curves.bounceOut)));
    }
  }

  // --- INPUT HANDLING ---
  void onDragStart(EcoItem draggedItem) {
    if (isProcessing) return;
    selectedItem = draggedItem;
    draggedItem.isSelected = true;
  }
  
  void onDragEnd(Vector2 dragDelta) {
    if (isProcessing || selectedItem == null) return;

    EcoItem first = selectedItem!;
    first.isSelected = false;

    double dx = dragDelta.x;
    double dy = dragDelta.y;
    int r2 = first.gridPosition.x as int;
    int c2 = first.gridPosition.y as int;

    if (dx.abs() > tileSize * 0.1 || dy.abs() > tileSize * 0.1) {
      if (dx.abs() > dy.abs()) {
        c2 += (dx > 0 ? 1 : -1);
      } else {
        r2 += (dy > 0 ? 1 : -1);
      }
    } else {
      selectedItem = null;
      return;
    }

    if (r2 >= 0 && r2 < rows && c2 >= 0 && c2 < cols) {
      EcoItem? second = gridItems[r2][c2];
      if (second != null) {
        _swapItems(first, second);
      }
    }
    selectedItem = null;
  }
  
  // --- CORE GAME LOGIC ---
  Future<void> _swapItems(EcoItem item1, EcoItem item2) async {
    isProcessing = true;

    final pos1 = item1.position.clone();
    final pos2 = item2.position.clone();

    item1.add(MoveToEffect(pos2, EffectController(duration: 0.15)));
    item2.add(MoveToEffect(pos1, EffectController(duration: 0.15)));
    
    await Future.delayed(const Duration(milliseconds: 160));

    Point p1 = item1.gridPosition;
    Point p2 = item2.gridPosition;

    gridItems[p1.x as int][p1.y as int] = item2;
    gridItems[p2.x as int][p2.y as int] = item1;

    item1.gridPosition = p2;
    item2.gridPosition = p1;

    List<EcoItem> matches = _findMatches();
    
    if (matches.isNotEmpty) {
      // Save Undo
      undoRow1 = p1.x as int; undoCol1 = p1.y as int;
      undoRow2 = p2.x as int; undoCol2 = p2.y as int;
      undoType1 = item1.type; undoType2 = item2.type;
      
      await _processMatches(matches);
    } else {
      // Revert
      item1.add(MoveToEffect(pos1, EffectController(duration: 0.15)));
      item2.add(MoveToEffect(pos2, EffectController(duration: 0.15)));
      
      await Future.delayed(const Duration(milliseconds: 160));
      
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
        if (i1 != null && i2 != null && i3 != null && i1.type == i2.type && i2.type == i3.type) {
            matchSet.addAll([i1, i2, i3]);
        }
      }
    }

    // Vertical
    for (int c = 0; c < cols; c++) {
      for (int r = 0; r < rows - 2; r++) {
        EcoItem? i1 = gridItems[r][c];
        EcoItem? i2 = gridItems[r+1][c];
        EcoItem? i3 = gridItems[r+2][c];
        if (i1 != null && i2 != null && i3 != null && i1.type == i2.type && i2.type == i3.type) {
            matchSet.addAll([i1, i2, i3]);
        }
      }
    }
    return matchSet.toList();
  }

  Future<void> _processMatches(List<EcoItem> matches) async {
    FlameAudio.play('bubble-pop.mp3');
    int points = matches.length * 10;
    scoreNotifier.value += points;
    
    for (var item in matches) {
      int r = item.gridPosition.x as int;
      int c = item.gridPosition.y as int;
      item.add(ScaleEffect.to(Vector2.zero(), EffectController(duration: 0.2)));
      gridItems[r][c] = null;
    }
    
    await Future.delayed(const Duration(milliseconds: 250));
    
    // FIX: Added curly braces for loop
    for (var item in matches) {
      item.removeFromParent();
    }

    await _applyGravity();
    await _spawnNewItems();

    List<EcoItem> newMatches = _findMatches();
    if (newMatches.isNotEmpty) {
      await Future.delayed(const Duration(milliseconds: 300));
      await _processMatches(newMatches);
    } else {
      // Auto-shuffle if stuck
      if (!_hasPossibleMoves()) {
        debugPrint("⛔ No moves left! Shuffling...");
        await _shuffleBoard();
      }
      isProcessing = false;
    }
  }

  Future<void> _applyGravity() async {
    bool moved = false;
    for (int c = 0; c < cols; c++) {
      for (int r = rows - 2; r >= 0; r--) {
        if (gridItems[r][c] != null && gridItems[r + 1][c] == null) {
          int fallDist = 0;
          for (int rFall = r + 1; rFall < rows; rFall++) {
            // FIX: Added curly braces for if/else
            if (gridItems[rFall][c] == null) {
              fallDist++;
            } else {
              break;
            }
          }

          if (fallDist > 0) {
            moved = true;
            EcoItem item = gridItems[r][c]!;
            
            gridItems[r + fallDist][c] = item;
            gridItems[r][c] = null;
            
            item.gridPosition = Point(r + fallDist, c);
            Vector2 newPos = Vector2(startX + c * tileSize, startY + (r + fallDist) * tileSize);
            item.add(MoveToEffect(newPos, EffectController(duration: 0.15 * fallDist)));
          }
        }
      }
    }
    if (moved) await Future.delayed(const Duration(milliseconds: 150));
  }

  Future<void> _spawnNewItems() async {
    for (int c = 0; c < cols; c++) {
      for (int r = 0; r < rows; r++) {
        if (gridItems[r][c] == null) {
          String newType = level1ItemTypes[Random().nextInt(level1ItemTypes.length)];
          _spawnItemAt(r, c, newType, animate: true);
        }
      }
    }
    await Future.delayed(const Duration(milliseconds: 400));
  }

  // --- SMART HELPERS ---

  bool _hasPossibleMoves() {
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        EcoItem? current = gridItems[r][c];
        if (current == null) continue;

        List<Point> neighbors = [Point(r + 1, c), Point(r, c + 1)];
        for (var n in neighbors) {
          if (n.x < rows && n.y < cols) {
            EcoItem? other = gridItems[n.x as int][n.y as int];
            if (other != null) {
              gridItems[r][c] = other;
              gridItems[n.x as int][n.y as int] = current;
              
              bool hasMatch = _findMatches().isNotEmpty;
              
              gridItems[r][c] = current;
              gridItems[n.x as int][n.y as int] = other;
              
              if (hasMatch) return true;
            }
          }
        }
      }
    }
    return false;
  }

  Future<void> _shuffleBoard() async {
     isProcessing = true;
     List<EcoItem> allItems = [];
     for(var list in gridItems) {
       for(var item in list) {
         if(item != null) allItems.add(item);
       }
     }
     
     do {
       allItems.shuffle();
       int index = 0;
       for (int r = 0; r < rows; r++) {
         for (int c = 0; c < cols; c++) {
           gridItems[r][c] = allItems[index];
           allItems[index].gridPosition = Point(r, c);
           index++;
         }
       }
     } while (!_hasPossibleMoves() || _findMatches().isNotEmpty);

     for (var item in allItems) {
       int r = item.gridPosition.x as int;
       int c = item.gridPosition.y as int;
       Vector2 targetPos = Vector2(startX + c * tileSize, startY + r * tileSize);
       item.add(MoveToEffect(targetPos, EffectController(duration: 0.5, curve: Curves.easeInOut)));
     }
     
     await Future.delayed(const Duration(milliseconds: 550));
     isProcessing = false;
  }

  // Helper for Hints
  SequenceEffect _getBlinkEffect() {
    return SequenceEffect([
      ScaleEffect.by(Vector2.all(1.2), EffectController(duration: 0.2)),
      ScaleEffect.by(Vector2.all(1/1.2), EffectController(duration: 0.2)),
    ], infinite: false, repeatCount: 3);
  }

  void useHint() {
    if (isProcessing) return;
    
    if (hintsRemaining > 0 && !_hasPossibleMoves()) {
       _shuffleBoard();
       return;
    }

    if (hintsRemaining > 0) {
      for (int r = 0; r < rows; r++) {
        for (int c = 0; c < cols; c++) {
          EcoItem? current = gridItems[r][c];
          if (current == null) continue;

          List<Point> neighbors = [Point(r + 1, c), Point(r, c + 1)];
          for (var n in neighbors) {
            if (n.x < rows && n.y < cols) {
              EcoItem? other = gridItems[n.x as int][n.y as int];
              if (other != null) {
                gridItems[r][c] = other;
                gridItems[n.x as int][n.y as int] = current;
                
                bool matchFound = _findMatches().isNotEmpty;
                
                gridItems[r][c] = current;
                gridItems[n.x as int][n.y as int] = other;

                if (matchFound) {
                  // FIX: Use helper method instead of clone()
                  current.add(_getBlinkEffect());
                  other.add(_getBlinkEffect());
                  
                  hintsRemaining--;
                  overlays.remove('HUD');
                  overlays.add('HUD');
                  return;
                }
              }
            }
          }
        }
      }
    }
  }

  Future<void> undoLastSwap() async {
    if (isProcessing || undoRemaining <= 0 || undoRow1 == null) return;
    isProcessing = true;
    undoRemaining--;
    
    EcoItem? i1 = gridItems[undoRow2!][undoCol2!];
    EcoItem? i2 = gridItems[undoRow1!][undoCol1!];

    if (i1 != null && i2 != null) {
       final pos1 = Vector2(startX + undoCol1! * tileSize, startY + undoRow1! * tileSize);
       final pos2 = Vector2(startX + undoCol2! * tileSize, startY + undoRow2! * tileSize);

       i1.add(MoveToEffect(pos1, EffectController(duration: 0.2)));
       i2.add(MoveToEffect(pos2, EffectController(duration: 0.2)));
       
       await Future.delayed(const Duration(milliseconds: 200));
       
       gridItems[undoRow1!][undoCol1!] = i1;
       gridItems[undoRow2!][undoCol2!] = i2;
       i1.gridPosition = Point(undoRow1!, undoCol1!);
       i2.gridPosition = Point(undoRow2!, undoCol2!);
    }

    overlays.remove('HUD');
    overlays.add('HUD');
    isProcessing = false;
  }
}