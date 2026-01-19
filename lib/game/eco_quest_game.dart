import 'dart:math';
import 'package:ecoquest/game/eco_components.dart';
import 'package:ecoquest/main.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/game.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/material.dart';

class EcoQuestGame extends FlameGame {
  static const int rows = 6;
  static const int cols = 6;

  VoidCallback? onGameOverCallback;
  VoidCallback? onPhaseCompleteCallback;
  VoidCallback? onInsufficientMaterialsCallback;

  int _completionTime = 0;
  int getCompletionTime() => _completionTime;

  double tileSize = 0; 
  double boardWidth = 0;
  double boardHeight = 0;
  double startX = 0;
  double startY = 0;
  // Add this field near the top with other class variables (around line 25)
  bool _hasStartedPlaying = false;

  List<List<EcoItem?>> gridItems = List.generate(rows, (_) => List.generate(cols, (_) => null));
  List<List<TileBackground?>> tileBackgrounds = List.generate(rows, (_) => List.generate(cols, (_) => null));
  
  EcoItem? selectedItem;
  bool isProcessing = false;

  int? sixtyPercentAchievedTime;
  static const int totalTiles = rows * cols;
  static final int sixtyPercentTiles = (totalTiles * 0.6).ceil();

  int currentLevel = 1;
  int currentPhase = 1;
  int plantsCollected = 0;
  
  List<String> forestImages = [
    'forest_0.png', 'forest_1.png', 'forest_2.png', 'forest_3.png', 'forest_4.png',
    'forest_5.png', 'forest_6.png', 'forest_7.png', 'forest_8.png', 'forest_9.png'
  ];
  
  static const int targetHighScore = 2000;
  List<List<bool>> restoredTiles = List.generate(rows, (_) => List.generate(cols, (_) => false));
  int hintsRemaining = 5;
  late TimerComponent _timerComponent;
  final List<String> level1ItemTypes = ['leaf', 'bark', 'root', 'flower', 'fruit'];

  @override
  Color backgroundColor() => const Color(0x00000000);

  @override
  Future<void> onLoad() async {
    super.onLoad();
    _updateLayout(size);
    await FlameAudio.audioCache.load('bubble-pop.mp3');
    _initializeTileBackgrounds();
    _buildTutorialGrid();
    _setupTimer();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _updateLayout(size);
    _repositionTileBackgrounds();
    _repositionActiveItems();
    _updateItemSizes(); // NEW: Update sprite sizes on resize
  }

  Map<String, int> materialsCollected = {
    'leaf': 0,
    'bark': 0,
    'root': 0,
    'flower': 0,
    'fruit': 0,
  };

  void _updateItemSizes() {
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        EcoItem? item = gridItems[r][c];
        if (item != null) {
          // Update sprite size to match new tile size
          final spriteScale = 0.80;
          item.size = Vector2.all(tileSize * spriteScale);
          item.sizeVal = tileSize; // Update stored size value
        }
      }
    }
  }

  void _updateLayout(Vector2 gameSize) {
    double availableSize = min(gameSize.x, gameSize.y);
    double padding = 8.0; 
    tileSize = (availableSize - (padding * 2)) / cols;
    boardWidth = cols * tileSize;
    boardHeight = rows * tileSize;
    startX = (gameSize.x - boardWidth) / 2;
    startY = (gameSize.y - boardHeight) / 2;
  }

  void _initializeTileBackgrounds() {
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        Vector2 pos = Vector2(startX + c * tileSize, startY + r * tileSize);
        final tileBg = TileBackground(row: r, col: c, sizeVal: tileSize)
          ..position = pos
          ..size = Vector2(tileSize, tileSize)
          ..priority = 0;
        tileBackgrounds[r][c] = tileBg;
        add(tileBg);
      }
    }
  }

  void _repositionTileBackgrounds() {
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        TileBackground? tileBg = tileBackgrounds[r][c];
        if (tileBg != null) {
          tileBg.position = Vector2(startX + c * tileSize, startY + r * tileSize);
          tileBg.size = Vector2(tileSize, tileSize);
        }
      }
    }
  }

  void _repositionActiveItems() {
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        EcoItem? item = gridItems[r][c];
        if (item != null) {
          // FIXED: Position at tile center consistently
          final centerX = startX + (c * tileSize) + (tileSize / 2);
          final centerY = startY + (r * tileSize) + (tileSize / 2);
          item.position = Vector2(centerX, centerY);
        }
      }
    }
  }

  void _setupTimer() {
    levelTimeNotifier.value = 210;
    children.whereType<TimerComponent>().forEach((tc) => tc.removeFromParent());
    _timerComponent = TimerComponent(period: 1.0, repeat: true, onTick: _onTimerTick);
    add(_timerComponent);
    
    // CHANGED: Only pause the TIMER, not the entire engine
    _timerComponent.timer.pause();
    // REMOVED: pauseEngine(); - This was preventing sprites from loading!
  }
    
  void _onTimerTick() {
    // Only tick if player has started playing
    if (!_hasStartedPlaying) return;
    
    if (levelTimeNotifier.value > 0) {
      levelTimeNotifier.value--;
    } else {
      _triggerGameOver(false);
    }
  }

  void _triggerGameOver(bool success) {
    pauseEngine(); 
    if (!_timerComponent.timer.finished) _timerComponent.timer.stop();
    gameSuccessNotifier.value = success;
    
    onGameOverCallback?.call();
  }
    
  void checkLevelCompletion() {
    int restoredCount = restoredTiles.expand((row) => row).where((tile) => tile).length;
    double restorationPercentage = (restoredCount / totalTiles) * 100;
    
    if (restorationPercentage >= 60.0 && sixtyPercentAchievedTime == null) {
      sixtyPercentAchievedTime = levelTimeNotifier.value;
    }
    
    if (restoredCount == totalTiles) {
      // CHANGED: Capture completion time BEFORE calculating materials
      int completionTime = levelTimeNotifier.value;
      
      plantsCollected = _calculateMaterialsCollected(restoredCount, restorationPercentage);
      plantsCollectedNotifier.value = plantsCollected;
      
      // CHANGED: Pass completion time to phase transition
      _triggerPhaseTransition(completionTime);
    }
  }

  int _calculateMaterialsCollected(int restoredCount, double restorationPercentage) {
    double baseMaterials = 10 + ((restoredCount - sixtyPercentTiles) / (totalTiles - sixtyPercentTiles)) * 20;
    baseMaterials = baseMaterials.clamp(10.0, 30.0);
    double scoreMultiplier = 1.0 + (scoreNotifier.value / 2000).clamp(0.0, 1.0);
    double timeBonus = 0.0;
    if (sixtyPercentAchievedTime != null) {
      int timeForFinalForty = sixtyPercentAchievedTime! - levelTimeNotifier.value;
      if (sixtyPercentAchievedTime! > 0) {
        double speedRatio = (1.0 - (timeForFinalForty / sixtyPercentAchievedTime!)).clamp(0.0, 1.0);
        timeBonus = speedRatio * 30;
      }
    }
    return ((baseMaterials * scoreMultiplier) + timeBonus).round().clamp(10, 60);
  }

  void _triggerPhaseTransition(int completionTime) {
    pauseEngine();
    if (!_timerComponent.timer.finished) _timerComponent.timer.stop();
    
    if (plantsCollected > 0) {
      // CHANGED: Pass completion time via callback parameter
      onPhaseCompleteCallback?.call();
      // Store completion time for DyeExtractionScreen access
      _completionTime = completionTime;
    } else {
      onInsufficientMaterialsCallback?.call();
      _completionTime = completionTime;
    }
  }
  
  void startPhase2() {
    currentPhase = 2;
    overlays.remove('PhaseComplete');
    pauseEngine();
  }
            
  void restartGame() {
    scoreNotifier.value = 0;
    hintsRemaining = 5;
    isProcessing = false;
    currentPhase = 1;
    plantsCollected = 0;
    plantsCollectedNotifier.value = 0;
    sixtyPercentAchievedTime = null;
    restoredTiles = List.generate(rows, (_) => List.generate(cols, (_) => false));
    
    // ADDED: Reset first move tracker
    _hasStartedPlaying = false;
    
    // Reset materials collection
    materialsCollected = {
      'leaf': 0,
      'bark': 0,
      'root': 0,
      'flower': 0,
      'fruit': 0,
    };
    
    // Notify UI
    materialsUpdateNotifier.value++;
    
    // CHANGED: More thorough cleanup of sprites
    // First, remove all items from the grid
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final item = gridItems[r][c];
        if (item != null) {
          item.removeFromParent();
          gridItems[r][c] = null;
        }
      }
    }
    
    // Then remove any orphaned EcoItem components
    final orphanedItems = children.whereType<EcoItem>().toList();
    for (var item in orphanedItems) {
      item.removeFromParent();
    }
    
    // Update tile backgrounds
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        tileBackgrounds[r][c]?.updateRestorationState(false);
      }
    }
    
    // Remove effects
    children.whereType<MatchExplosionEffect>().forEach((e) => e.removeFromParent());
    children.whereType<TileRestorationEffect>().forEach((e) => e.removeFromParent());
    
    // ADDED: Force a layout update before rebuilding grid
    _updateLayout(size);
    _repositionTileBackgrounds();
    
    // Now rebuild the grid
    if (currentLevel == 1) {
      _buildTutorialGrid();
    } else {
      _buildShuffledGrid();
    }
    
    // Setup timer (will be paused until first move)
    _setupTimer();
    
    currentLevelNotifier.value = currentLevel;
  }

  void startNextLevel() {
    currentLevel++;
    currentLevelNotifier.value = currentLevel;
    isProcessing = false;
    currentPhase = 1;
    plantsCollected = 0;
    plantsCollectedNotifier.value = 0;
    hintsRemaining = 5;
    sixtyPercentAchievedTime = null;
    restoredTiles = List.generate(rows, (_) => List.generate(cols, (_) => false));
    
    // ADDED: Reset first move tracker
    _hasStartedPlaying = false;
    
    // Reset materials collection
    materialsCollected = {
      'leaf': 0,
      'bark': 0,
      'root': 0,
      'flower': 0,
      'fruit': 0,
    };
    
    // Notify UI
    materialsUpdateNotifier.value++;
    
    // CHANGED: More thorough cleanup
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final item = gridItems[r][c];
        if (item != null) {
          item.removeFromParent();
          gridItems[r][c] = null;
        }
      }
    }
    
    final orphanedItems = children.whereType<EcoItem>().toList();
    for (var item in orphanedItems) {
      item.removeFromParent();
    }
    
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        tileBackgrounds[r][c]?.updateRestorationState(false);
      }
    }
    
    children.whereType<MatchExplosionEffect>().forEach((e) => e.removeFromParent());
    children.whereType<TileRestorationEffect>().forEach((e) => e.removeFromParent());
    
    // ADDED: Force layout update
    _updateLayout(size);
    _repositionTileBackgrounds();
    
    _buildShuffledGrid();
    _setupTimer();
    
    scoreNotifier.value = 0;
  }

  // 7. NEW: Method to get materials collected (for Phase 2 transition)
  Map<String, int> getMaterialsCollected() {
    return Map.from(materialsCollected);
  }

  // 8. NEW: Method to get total materials count
  int getTotalMaterialsCollected() {
    return materialsCollected.values.fold(0, (sum, count) => sum + count);
  }

  void _buildTutorialGrid() {
    List<List<String>> fixedMap = [
      ['leaf', 'leaf', 'root', 'leaf', 'flower', 'fruit'],
      ['flower', 'fruit', 'bark', 'flower', 'root', 'bark'],
      ['bark', 'leaf', 'root', 'fruit', 'leaf', 'flower'],
      ['fruit', 'flower', 'leaf', 'bark', 'fruit', 'root'],
      ['root', 'bark', 'flower', 'root', 'bark', 'leaf'],
      ['leaf', 'fruit', 'fruit', 'leaf', 'flower', 'bark'],
    ];
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        _spawnItemAt(r, c, fixedMap[r][c], animate: false);
      }
    }
  }

  void _buildShuffledGrid() {
    List<String> allItemTypes = [];
    int tilesPerType = (rows * cols) ~/ level1ItemTypes.length;
    int remainder = (rows * cols) % level1ItemTypes.length;
    for (int i = 0; i < level1ItemTypes.length; i++) {
      int count = tilesPerType + (i < remainder ? 1 : 0);
      for (int j = 0; j < count; j++) {
        allItemTypes.add(level1ItemTypes[i]);
      }
    }
    allItemTypes.shuffle();
    List<List<String>> tempGrid = List.generate(rows, (_) => List.generate(cols, (_) => ''));
    int itemIndex = 0;
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        bool placed = false;
        int attempts = 0;
        while (!placed && attempts < allItemTypes.length) {
          String candidateType = allItemTypes[itemIndex % allItemTypes.length];
          bool horizontalMatch = c >= 2 && tempGrid[r][c-1] == candidateType && tempGrid[r][c-2] == candidateType;
          bool verticalMatch = r >= 2 && tempGrid[r-1][c] == candidateType && tempGrid[r-2][c] == candidateType;
          if (!horizontalMatch && !verticalMatch) {
            tempGrid[r][c] = candidateType;
            _spawnItemAt(r, c, candidateType, animate: false);
            placed = true;
          }
          itemIndex++;
          attempts++;
        }
        if (!placed) {
          tempGrid[r][c] = allItemTypes[itemIndex % allItemTypes.length];
          _spawnItemAt(r, c, allItemTypes[itemIndex % allItemTypes.length], animate: false);
          itemIndex++;
        }
      }
    }
  }

  void _spawnItemAt(int r, int c, String type, {bool animate = true}) {
    // FIXED: Calculate center position for sprites consistently
    final centerX = startX + (c * tileSize) + (tileSize / 2);
    final centerY = startY + (r * tileSize) + (tileSize / 2);
    
    Vector2 finalPos = Vector2(centerX, centerY);
    Vector2 spawnPos = animate 
        ? Vector2(centerX, startY - tileSize) // Start above, but same X
        : finalPos;
    
    final item = EcoItem(type: type, sizeVal: tileSize)
      ..position = spawnPos
      ..gridPosition = Point(r, c)
      ..priority = 1;
      
    gridItems[r][c] = item;
    add(item);
    
    if (animate) {
      item.add(MoveToEffect(
        finalPos, 
        EffectController(duration: 0.4, curve: Curves.bounceOut)
      ));
    }
  }

  void onDragStart(EcoItem draggedItem) {
    if (isProcessing) return;
    selectedItem = draggedItem;
    draggedItem.isSelected = true;
  }
  
  void onDragEnd(Vector2 dragDelta) {
    if (isProcessing || selectedItem == null) return;
    EcoItem first = selectedItem!;
    first.isSelected = false;
    int r2 = first.gridPosition.x as int;
    int c2 = first.gridPosition.y as int;
    if (dragDelta.x.abs() > tileSize * 0.1 || dragDelta.y.abs() > tileSize * 0.1) {
      if (dragDelta.x.abs() > dragDelta.y.abs()) {
        c2 += (dragDelta.x > 0 ? 1 : -1);
      } else {
        r2 += (dragDelta.y > 0 ? 1 : -1);
      }
    } else {
      selectedItem = null;
      return;
    }
    if (r2 >= 0 && r2 < rows && c2 >= 0 && c2 < cols) {
      EcoItem? second = gridItems[r2][c2];
      if (second != null) _swapItems(first, second);
    }
    selectedItem = null;
  }
      
  Future<void> _swapItems(EcoItem item1, EcoItem item2) async {
    isProcessing = true;
    
    // ADDED: Start timer on first swap
    if (!_hasStartedPlaying) {
      _hasStartedPlaying = true;
      _timerComponent.timer.resume();
      resumeEngine();
    }
    
    // FIXED: Get current center positions
    final pos1 = item1.position.clone();
    final pos2 = item2.position.clone();
    
    // Animate swap
    item1.add(MoveToEffect(pos2, EffectController(duration: 0.15)));
    item2.add(MoveToEffect(pos1, EffectController(duration: 0.15)));
    await Future.delayed(const Duration(milliseconds: 160));
    
    // Update grid positions
    Point p1 = item1.gridPosition;
    Point p2 = item2.gridPosition;
    gridItems[p1.x as int][p1.y as int] = item2;
    gridItems[p2.x as int][p2.y as int] = item1;
    item1.gridPosition = p2;
    item2.gridPosition = p1;
    
    // Check for matches
    List<EcoItem> matches = _findMatches();
    if (matches.isNotEmpty) {
      await _processMatches(matches);
    } else {
      // Swap back if no matches
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
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols - 2; c++) {
        EcoItem? i1 = gridItems[r][c], i2 = gridItems[r][c+1], i3 = gridItems[r][c+2];
        if (i1 != null && i2 != null && i3 != null && i1.type == i2.type && i2.type == i3.type) {
          matchSet.addAll([i1, i2, i3]);
        }
      }
    }
    for (int c = 0; c < cols; c++) {
      for (int r = 0; r < rows - 2; r++) {
        EcoItem? i1 = gridItems[r][c], i2 = gridItems[r+1][c], i3 = gridItems[r+2][c];
        if (i1 != null && i2 != null && i3 != null && i1.type == i2.type && i2.type == i3.type) {
          matchSet.addAll([i1, i2, i3]);
        }
      }
    }
    return matchSet.toList();
  }

  Future<void> _processMatches(List<EcoItem> matches) async {
    FlameAudio.play('bubble-pop.mp3');
    
    // Calculate points
    scoreNotifier.value += matches.length * 10;
    
    // NEW: Group matches by type to properly count materials
    Map<String, int> matchesByType = {};
    for (var item in matches) {
      matchesByType[item.type] = (matchesByType[item.type] ?? 0) + 1;
    }
        
    // Award materials based on match size PER TYPE
    for (var entry in matchesByType.entries) {
      String materialType = entry.key;
      int count = entry.value;
      
      if (count == 3) {
        // Standard 3-match → +1 material
        materialsCollected[materialType] = (materialsCollected[materialType] ?? 0) + 1;
      } else if (count == 4) {
        // L/T-shape match (4 items) → +3 materials
        materialsCollected[materialType] = (materialsCollected[materialType] ?? 0) + 3;
      } else if (count == 5) {
        // 5-in-row → +5 materials
        materialsCollected[materialType] = (materialsCollected[materialType] ?? 0) + 5;
      } else if (count >= 6) {
        // Cross match (6+) → +10 to this material type
        materialsCollected[materialType] = (materialsCollected[materialType] ?? 0) + 10;
        
        // BONUS: +2 to ALL other material types
        for (var type in level1ItemTypes) {
          if (type != materialType) {
            materialsCollected[type] = (materialsCollected[type] ?? 0) + 2;
          }
        }
      }
    }
    
    materialsUpdateNotifier.value++;
    
    for (var item in matches) {
      int r = item.gridPosition.x as int, c = item.gridPosition.y as int;
      add(MatchExplosionEffect(
        position: item.position.clone() + Vector2(tileSize / 2, tileSize / 2),
        itemType: item.type,
      ));
      item.add(SequenceEffect([ScaleEffect.to(Vector2.zero(), EffectController(duration: 0.3))]));
      restoredTiles[r][c] = true;
      tileBackgrounds[r][c]?.updateRestorationState(true);
      add(TileRestorationEffect(row: r, col: c));
      gridItems[r][c] = null;
    }
    await Future.delayed(const Duration(milliseconds: 350));
    for (var item in matches) {
      item.removeFromParent();
    }
    await _applyGravity();
    await _spawnNewItems();
    checkLevelCompletion();
    List<EcoItem> newMatches = _findMatches();
    if (newMatches.isNotEmpty) {
      await Future.delayed(const Duration(milliseconds: 300));
      await _processMatches(newMatches);
    } else {
      if (!_hasPossibleMoves() && levelTimeNotifier.value > 0) {
        await _shuffleBoard();
      } else if (!_hasPossibleMoves()) {
        _triggerGameOver(false);
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
            
            // FIXED: Move to center of destination tile
            final centerX = startX + (c * tileSize) + (tileSize / 2);
            final centerY = startY + ((r + fallDist) * tileSize) + (tileSize / 2);
            
            item.add(MoveToEffect(
              Vector2(centerX, centerY),
              EffectController(duration: 0.15 * fallDist)
            ));
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
          _spawnItemAt(r, c, level1ItemTypes[Random().nextInt(level1ItemTypes.length)], animate: true);
        }
      }
    }
    await Future.delayed(const Duration(milliseconds: 400));
  }

  bool _hasPossibleMoves() {
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        EcoItem? current = gridItems[r][c];
        if (current == null) continue;
        for (var n in [Point(r + 1, c), Point(r, c + 1)]) {
          if (n.x < rows && n.y < cols) {
            EcoItem? other = gridItems[n.x][n.y];
            if (other != null) {
              gridItems[r][c] = other;
              gridItems[n.x][n.y] = current;
              bool hasMatch = _findMatches().isNotEmpty;
              gridItems[r][c] = current;
              gridItems[n.x][n.y] = other;
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
    List<EcoItem> allItems = gridItems.expand((list) => list).whereType<EcoItem>().toList();
    
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
    
    // FIXED: Animate to center positions
    for (var item in allItems) {
      int r = item.gridPosition.x as int;
      int c = item.gridPosition.y as int;
      
      final centerX = startX + (c * tileSize) + (tileSize / 2);
      final centerY = startY + (r * tileSize) + (tileSize / 2);
      
      item.add(MoveToEffect(
        Vector2(centerX, centerY),
        EffectController(duration: 0.5, curve: Curves.easeInOut)
      ));
    }
    
    await Future.delayed(const Duration(milliseconds: 550));
    isProcessing = false;
  }

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
          for (var n in [Point(r + 1, c), Point(r, c + 1)]) {
            if (n.x < rows && n.y < cols) {
              EcoItem? other = gridItems[n.x][n.y];
              if (other != null) {
                gridItems[r][c] = other;
                gridItems[n.x][n.y] = current;
                bool matchFound = _findMatches().isNotEmpty;
                gridItems[r][c] = current;
                gridItems[n.x][n.y] = other;
                if (matchFound) {
                  current.add(_getBlinkEffect());
                  other.add(_getBlinkEffect());
                  hintsRemaining--;
                  return;
                }
              }
            }
          }
        }
      }
    }
  }

  double getRestorationPercentage() {
    int restoredCount = restoredTiles.expand((row) => row).where((tile) => tile).length;
    return (restoredCount / totalTiles) * 100;
  }

  int getForestImageIndex() {
    int restoredCount = restoredTiles.expand((row) => row).where((tile) => tile).length;
    double percentage = (restoredCount / totalTiles).clamp(0.0, 1.0);
    return (percentage * 9).round();
  }
}