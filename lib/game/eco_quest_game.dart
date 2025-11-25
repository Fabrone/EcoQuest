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

  // State Management - NO TILES, only items
  late List<List<EcoItem?>> gridItems;
  EcoItem? selectedItem;
  bool isProcessing = false;
  
  // Utilities State
  int hintsRemaining = 3;
  int undoRemaining = 3;
  
  // Undo State - Store complete swap information
  int? undoRow1, undoCol1, undoRow2, undoCol2;
  String? undoType1, undoType2;

  final List<String> level1ItemTypes = ['pinnate_leaf', 'leaf_design', 'blue_butterfly', 'red_flower', 'yellow_flower'];

  @override
  Future<void> onLoad() async {
    super.onLoad();
    debugPrint("🎮 GAME LOADING STARTED");

    // Dynamic Sizing - Board takes 3/5 of screen height
    double availableHeight = size.y * 0.6; // 60% of screen = 3/5
    double maxW = size.x / cols;
    double maxH = availableHeight / rows;
    tileSize = min(maxW, maxH) * 0.95;

    boardWidth = cols * tileSize;
    boardHeight = rows * tileSize;
    startX = (size.x - boardWidth) / 2;
    startY = (size.y - boardHeight) / 2;

    debugPrint("📐 Screen: $size, TileSize: $tileSize, Board: $boardWidth x $boardHeight");

    // Background
    try {
      final bgSprite = await loadSprite('tile_bg.png');
      add(SpriteComponent()
        ..sprite = bgSprite
        ..size = size
        ..anchor = Anchor.topLeft
        ..priority = -1); // Background lowest priority
      debugPrint("✅ Background loaded successfully");
    } catch (e) {
      debugPrint("⚠️ Background image not found, using fallback");
      add(RectangleComponent(
        size: size, 
        paint: Paint()..color = const Color(0xFF2D1E17),
        priority: -1
      )); 
    }

    // Audio
    await FlameAudio.audioCache.load('bubble-pop.mp3');
    debugPrint("🔊 Audio loaded");

    // Init Data - NO TILES ARRAY
    gridItems = List.generate(rows, (_) => List.generate(cols, (_) => null));

    // Build Board - ITEMS ONLY
    debugPrint("🏗️ Building game grid...");
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        Vector2 pos = Vector2(startX + c * tileSize, startY + r * tileSize);

        String type;
        do {
          type = level1ItemTypes[Random().nextInt(level1ItemTypes.length)];
        } while (_causesMatch(r, c, type));

        final item = EcoItem(type: type, sizeVal: tileSize)
          ..position = pos.clone()
          ..size = Vector2(tileSize, tileSize)
          ..gridPosition = Point(r, c)
          ..priority = 1; // Items on top
        
        gridItems[r][c] = item;
        add(item);
      }
    }

    debugPrint("✅ Grid built: $rows x $cols with ${level1ItemTypes.length} item types");
    overlays.add('HUD');
    debugPrint("🎮 GAME LOADING COMPLETE");
  }

  bool _causesMatch(int r, int c, String type) {
    if (c >= 2 && gridItems[r][c - 1]?.type == type && gridItems[r][c - 2]?.type == type) return true;
    if (r >= 2 && gridItems[r - 1][c]?.type == type && gridItems[r - 2][c]?.type == type) return true;
    return false;
  }

  // INPUT HANDLING
  void onDragStart(EcoItem draggedItem) {
    if (isProcessing) {
      debugPrint("⏸️ Drag ignored: Game is processing");
      return;
    }
    selectedItem = draggedItem;
    draggedItem.isSelected = true;
    debugPrint("👆 Drag started on: ${draggedItem.type} at (${draggedItem.gridPosition.x},${draggedItem.gridPosition.y})");
  }
  
  void onDragEnd(Vector2 dragDelta) {
    if (isProcessing || selectedItem == null) return;

    EcoItem first = selectedItem!;
    first.isSelected = false;

    double dx = dragDelta.x;
    double dy = dragDelta.y;
    int r2 = first.gridPosition.x as int;
    int c2 = first.gridPosition.y as int;

    // Reduced threshold for quicker response
    if (dx.abs() > tileSize * 0.15 || dy.abs() > tileSize * 0.15) {
      if (dx.abs() > dy.abs()) {
        c2 += (dx > 0 ? 1 : -1);
        debugPrint("➡️ Swipe ${dx > 0 ? 'RIGHT' : 'LEFT'}");
      } else {
        r2 += (dy > 0 ? 1 : -1);
        debugPrint("⬇️ Swipe ${dy > 0 ? 'DOWN' : 'UP'}");
      }
    } else {
      debugPrint("❌ Drag too short, cancelled");
      selectedItem = null;
      return;
    }

    if (r2 < 0 || r2 >= rows || c2 < 0 || c2 >= cols) {
      debugPrint("🚫 Swipe out of bounds");
      selectedItem = null;
      return;
    }

    EcoItem? second = gridItems[r2][c2];
    if (second != null) {
      debugPrint("🔄 Attempting swap: (${first.gridPosition.x},${first.gridPosition.y}) <-> ($r2,$c2)");
      _swapItems(first, second);
    }
    selectedItem = null;
  }
  
  // CORE GAME LOGIC
  Future<void> _swapItems(EcoItem item1, EcoItem item2) async {
    isProcessing = true;
    debugPrint("⚡ SWAP START: ${item1.type} <-> ${item2.type}");

    final pos1 = item1.position.clone();
    final pos2 = item2.position.clone();

    // Faster swap animation
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
      debugPrint("✅ MATCH FOUND: ${matches.length} items matched");
      
      // Store undo information
      undoRow1 = p1.x as int;
      undoCol1 = p1.y as int;
      undoRow2 = p2.x as int;
      undoCol2 = p2.y as int;
      undoType1 = item1.type;
      undoType2 = item2.type;
      
      debugPrint("💾 Undo saved: ($undoRow1,$undoCol1)-($undoRow2,$undoCol2) | Types: $undoType1 <-> $undoType2");
      
      await _processMatches(matches);
    } else {
      debugPrint("❌ No match - Reverting swap");
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
    
    // Horizontal matches
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

    // Vertical matches
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
    
    if (matchSet.isNotEmpty) {
      debugPrint("🔍 Found ${matchSet.length} items in matches");
    }
    
    return matchSet.toList();
  }

  Future<void> _processMatches(List<EcoItem> matches) async {
    debugPrint("💥 PROCESSING MATCHES: ${matches.length} items");
    
    FlameAudio.play('bubble-pop.mp3');
    int points = matches.length * 10;
    scoreNotifier.value += points;
    debugPrint("🎯 Score +$points → Total: ${scoreNotifier.value}");
    
    // Crash animation - NO COLOR CHANGES
    for (var item in matches) {
      int r = item.gridPosition.x as int;
      int c = item.gridPosition.y as int;
      
      debugPrint("   💨 Removing ${item.type} at ($r,$c)");
      
      item.add(ScaleEffect.to(Vector2.all(0.0), EffectController(duration: 0.2)));
      item.add(OpacityEffect.fadeOut(EffectController(duration: 0.2)));
      
      gridItems[r][c] = null;
    }
    
    await Future.delayed(const Duration(milliseconds: 250));
    for (var item in matches) {
      item.removeFromParent();
    }
    debugPrint("🗑️ ${matches.length} items removed from game tree");

    await _applyGravity();
    await _spawnNewItems();

    // Check for chain reactions
    List<EcoItem> newMatches = _findMatches();
    if (newMatches.isNotEmpty) {
      debugPrint("⚡ CHAIN REACTION! Found ${newMatches.length} new matches");
      await Future.delayed(const Duration(milliseconds: 300));
      await _processMatches(newMatches);
    } else {
      debugPrint("✅ Match processing complete");
      isProcessing = false;
    }
  }

  Future<void> _applyGravity() async {
    debugPrint("🌍 Applying gravity...");
    bool moved = false;
    int totalMoves = 0;
    
    for (int c = 0; c < cols; c++) {
      for (int r = rows - 2; r >= 0; r--) {
        if (gridItems[r][c] != null && gridItems[r + 1][c] == null) {
          int fallDist = 0;
          for (int rFall = r + 1; rFall < rows; rFall++) {
            if (gridItems[rFall][c] == null) {
              fallDist++;
            } else {
              break;
            }
          }

          if (fallDist > 0) {
            moved = true;
            totalMoves++;
            EcoItem item = gridItems[r][c]!;
            
            gridItems[r + fallDist][c] = item;
            gridItems[r][c] = null;
            
            item.gridPosition = Point(r + fallDist, c);
            Vector2 newPos = Vector2(startX + c * tileSize, startY + (r + fallDist) * tileSize);
            item.add(MoveToEffect(newPos, EffectController(duration: 0.15 * fallDist)));
            
            debugPrint("   ⬇️ ${item.type} falls from row $r to ${r + fallDist}");
          }
        }
      }
    }
    
    if (moved) {
      debugPrint("✅ Gravity complete: $totalMoves items fell");
      await Future.delayed(const Duration(milliseconds: 150));
    } else {
      debugPrint("   No gravity needed");
    }
  }

  Future<void> _spawnNewItems() async {
    debugPrint("🌱 Spawning new items...");
    int spawned = 0;
    
    for (int c = 0; c < cols; c++) {
      for (int r = 0; r < rows; r++) {
        if (gridItems[r][c] == null) {
          spawned++;
          String newType = level1ItemTypes[Random().nextInt(level1ItemTypes.length)];
          
          Vector2 spawnPos = Vector2(startX + c * tileSize, startY - tileSize);

          EcoItem newItem = EcoItem(type: newType, sizeVal: tileSize)
            ..position = spawnPos
            ..size = Vector2(tileSize, tileSize)
            ..gridPosition = Point(r, c)
            ..priority = 1;
          
          gridItems[r][c] = newItem;
          add(newItem);

          Vector2 targetPos = Vector2(startX + c * tileSize, startY + r * tileSize);
          newItem.add(MoveToEffect(targetPos, EffectController(duration: 0.5, curve: Curves.easeIn)));
          
          debugPrint("   ✨ Spawned $newType at ($r,$c)");
        }
      }
    }
    
    debugPrint("✅ Spawned $spawned new items");
    await Future.delayed(const Duration(milliseconds: 500));
  }
  
  // HINT LOGIC
  void useHint() {
    if (isProcessing || hintsRemaining <= 0) return;
    
    debugPrint("💡 HINT: Scanning grid for possible matches...");
    
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        EcoItem? current = gridItems[r][c];
        if (current == null) continue;

        for (var dir in [Vector2(0, 1), Vector2(1, 0)]) {
          int r2 = r + dir.x.toInt();
          int c2 = c + dir.y.toInt();

          if (r2 >= rows || c2 >= cols) continue;
          
          EcoItem? neighbor = gridItems[r2][c2];
          if (neighbor == null) continue;

          // Temporary swap
          gridItems[r][c] = neighbor;
          gridItems[r2][c2] = current;

          if (_findMatches().isNotEmpty) {
            debugPrint("✅ HINT FOUND: ${current.type} at ($r,$c) <-> ${neighbor.type} at ($r2,$c2)");
            
            // Highlight items
            final yellowColor = Colors.yellow.withValues(alpha: 0.6);
            final controller = EffectController(duration: 0.3, repeatCount: 3, reverseDuration: 0.3);
            
            current.add(ColorEffect(yellowColor, controller));
            neighbor.add(ColorEffect(yellowColor, controller));
            
            // Revert temporary swap
            gridItems[r][c] = current;
            gridItems[r2][c2] = neighbor;
            
            hintsRemaining--;
            debugPrint("💡 Hints remaining: $hintsRemaining");
            
            overlays.remove('HUD');
            overlays.add('HUD');
            return;
          }

          // Revert temporary swap
          gridItems[r][c] = current;
          gridItems[r2][c2] = neighbor;
        }
      }
    }
    
    debugPrint("❌ HINT: No matches found on board");
  }

  // UNDO LOGIC
  Future<void> undoLastSwap() async {
    if (isProcessing || undoRemaining <= 0) return;
    
    if (undoRow1 == null || undoCol1 == null || undoRow2 == null || undoCol2 == null) {
      debugPrint("❌ UNDO: No move to undo");
      return;
    }
    
    debugPrint("↩️ UNDO: Reversing last swap ($undoRow1,$undoCol1) <-> ($undoRow2,$undoCol2)");
    isProcessing = true;
    undoRemaining--;
    
    // Find items at their current positions (after swap they moved)
    EcoItem? item1 = gridItems[undoRow2!][undoCol2!];
    EcoItem? item2 = gridItems[undoRow1!][undoCol1!];
    
    if (item1 == null || item2 == null) {
      debugPrint("❌ UNDO FAILED: Items are null (may have been matched)");
      isProcessing = false;
      return;
    }
    
    if (item1.type != undoType1 || item2.type != undoType2) {
      debugPrint("❌ UNDO FAILED: Items changed (${item1.type} vs $undoType1, ${item2.type} vs $undoType2)");
      isProcessing = false;
      return;
    }
    
    // Swap back to original positions
    final pos1Original = Vector2(startX + undoCol1! * tileSize, startY + undoRow1! * tileSize);
    final pos2Original = Vector2(startX + undoCol2! * tileSize, startY + undoRow2! * tileSize);

    item1.add(MoveToEffect(pos1Original, EffectController(duration: 0.15)));
    item2.add(MoveToEffect(pos2Original, EffectController(duration: 0.15)));
    
    await Future.delayed(const Duration(milliseconds: 160));

    gridItems[undoRow1!][undoCol1!] = item1;
    gridItems[undoRow2!][undoCol2!] = item2;
    
    item1.gridPosition = Point(undoRow1!, undoCol1!);
    item2.gridPosition = Point(undoRow2!, undoCol2!);
    
    debugPrint("✅ UNDO COMPLETE: ${item1.type} and ${item2.type} restored");
    
    // Clear undo state
    undoRow1 = null;
    undoCol1 = null;
    undoRow2 = null;
    undoCol2 = null;
    undoType1 = null;
    undoType2 = null;
    
    debugPrint("↩️ Undo uses remaining: $undoRemaining");

    overlays.remove('HUD');
    overlays.add('HUD');
    isProcessing = false;
  }
}