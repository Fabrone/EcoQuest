import 'dart:math';
import 'package:ecoquest/main.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/game.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/material.dart';
import 'eco_components.dart';

class EcoQuestGame extends FlameGame {
    
  // Configuration
  static const int rows = 6;
  static const int cols = 6;
  
  // Dynamic sizing logic
  double tileSize = 0; 
  double boardWidth = 0;
  double boardHeight = 0;
  double startX = 0;
  double startY = 0;

  // State Management
  List<List<EcoItem?>> gridItems = List.generate(rows, (_) => List.generate(cols, (_) => null));
  EcoItem? selectedItem;
  bool isProcessing = false;

  // NEW: Track when 60% restoration was achieved
  int? sixtyPercentAchievedTime;
  static const int totalTiles = rows * cols; // 36 tiles
  static final int sixtyPercentTiles = (totalTiles * 0.6).ceil();

  // Level Management
  int currentLevel = 1;
  
  // Phase Management - NEW
  int currentPhase = 1; // 1 = Restoration, 2 = Dye Extraction
  int plantsCollected = 0;
  
  // Forest Restoration Images
  List<String> forestImages = [
    'forest_0.png', 'forest_1.png', 'forest_2.png', 'forest_3.png', 'forest_4.png',
    'forest_5.png', 'forest_6.png', 'forest_7.png', 'forest_8.png', 'forest_9.png'
  ];
  
  // Temporary high score for image progression
  static const int targetHighScore = 2000;
  
  // Track tile restoration state
  List<List<bool>> restoredTiles = List.generate(rows, (_) => List.generate(cols, (_) => false));
  
  // Utilities State
  int hintsRemaining = 5;

  // Timer State
  late TimerComponent _timerComponent;

  final List<String> level1ItemTypes = ['rain', 'hummingbird', 'summer', 'rose', 'man'];

  @override
  Color backgroundColor() => const Color(0x00000000);

  @override
  Future<void> onLoad() async {
    super.onLoad();

    _updateLayout(size);

    // Audio
    await FlameAudio.audioCache.load('bubble-pop.mp3');

    debugPrint("🗃️ Building Level $currentLevel - Phase $currentPhase...");
    _buildTutorialGrid();
    
    // Timer setup
    _setupTimer();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _updateLayout(size);
    _repositionActiveItems();
  }

  void _updateLayout(Vector2 gameSize) {
    double availableSize = min(gameSize.x, gameSize.y);
    double padding = 16.0; 
    
    tileSize = (availableSize - (padding * 2)) / cols;
    boardWidth = cols * tileSize;
    boardHeight = rows * tileSize;
    
    startX = (gameSize.x - boardWidth) / 2;
    startY = (gameSize.y - boardHeight) / 2;
  }

  void _repositionActiveItems() {
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        EcoItem? item = gridItems[r][c];
        if (item != null) {
          Vector2 newPos = Vector2(startX + c * tileSize, startY + r * tileSize);
          item.position = newPos;
          item.size = Vector2(tileSize, tileSize);
        }
      }
    }
  }

  void _setupTimer() {
    levelTimeNotifier.value = 210; // 210 seconds (3:30)
    
    children.whereType<TimerComponent>().forEach((tc) => tc.removeFromParent());
    
    _timerComponent = TimerComponent(
      period: 1.0, 
      repeat: true,
      onTick: _onTimerTick,
    );
    add(_timerComponent);
    resumeEngine();
  }
  
  void _onTimerTick() {
    if (levelTimeNotifier.value > 0) {
      levelTimeNotifier.value--;
    } else {
      _triggerGameOver(false);
    }
  }

  void _triggerGameOver(bool success) {
    pauseEngine(); 
    
    if (!_timerComponent.timer.finished) {
      _timerComponent.timer.stop();
    }

    gameSuccessNotifier.value = success;

    if (!overlays.isActive('GameOver')) {
      overlays.add('GameOver');
    }
  }
    
  // UPDATED: Check level completion based on tile restoration
  void checkLevelCompletion() {
    // Count restored tiles
    int restoredCount = 0;
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (restoredTiles[r][c]) {
          restoredCount++;
        }
      }
    }
    
    double restorationPercentage = (restoredCount / totalTiles) * 100;
    
    // Track when 60% is achieved (for time bonus calculation)
    if (restorationPercentage >= 60.0 && sixtyPercentAchievedTime == null) {
      sixtyPercentAchievedTime = levelTimeNotifier.value;
      debugPrint("🌱 60% restoration achieved at ${sixtyPercentAchievedTime}s remaining");
    }
    
    // Check if ALL tiles are restored (100%)
    bool allRestored = (restoredCount == totalTiles);
    
    if (allRestored) {
      // Calculate materials based on new logic
      plantsCollected = _calculateMaterialsCollected(restoredCount, restorationPercentage);
      
      if (plantsCollected > 0) {
        plantsCollectedNotifier.value = plantsCollected;
        _triggerPhaseTransition();
      } else {
        // Edge case: should not happen with new logic, but keep as fallback
        plantsCollectedNotifier.value = 0;
        _triggerPhaseTransition();
      }
    }
  }

  // NEW: Calculate materials based on tiles, score, and time
  int _calculateMaterialsCollected(int restoredCount, double restorationPercentage) {
    // Base materials from tile restoration (minimum guaranteed)
    // At 60% (22 tiles): 10 units
    // At 100% (36 tiles): 30 units base
    double baseMaterials = 10 + ((restoredCount - sixtyPercentTiles) / (totalTiles - sixtyPercentTiles)) * 20;
    baseMaterials = baseMaterials.clamp(10.0, 30.0);
    
    // Score multiplier (adds quality bonus)
    // Score range: 0-3000+ typical, normalize to 0.0-2.0 multiplier
    double scoreMultiplier = 1.0 + (scoreNotifier.value / 2000).clamp(0.0, 1.0);
    
    // Time bonus (rewards speed after 60% threshold)
    double timeBonus = 0.0;
    if (sixtyPercentAchievedTime != null) {
      // Calculate time taken for remaining 40%
      int timeForFinalForty = sixtyPercentAchievedTime! - levelTimeNotifier.value;
      int maxTimeForFinalForty = sixtyPercentAchievedTime!; // All remaining time
      
      // Faster completion = higher bonus (0 to +30 materials)
      // If completed instantly: full +30 bonus
      // If used all time: no bonus
      if (maxTimeForFinalForty > 0) {
        double speedRatio = 1.0 - (timeForFinalForty / maxTimeForFinalForty);
        speedRatio = speedRatio.clamp(0.0, 1.0);
        timeBonus = speedRatio * 30;
      }
      
      debugPrint("⏱️ Time for final 40%: ${timeForFinalForty}s, Bonus: ${timeBonus.toStringAsFixed(1)} materials");
    }
    
    // Calculate total materials
    double totalMaterials = (baseMaterials * scoreMultiplier) + timeBonus;
    
    // Clamp to reasonable range (10-60 units)
    int finalMaterials = totalMaterials.round().clamp(10, 60);
    
    debugPrint("""
    📊 Material Calculation:
       - Base (tiles): ${baseMaterials.toStringAsFixed(1)}
       - Score multiplier: ${scoreMultiplier.toStringAsFixed(2)}x
       - Time bonus: +${timeBonus.toStringAsFixed(1)}
       - TOTAL: $finalMaterials units
    """);
    
    return finalMaterials;
  }

  void _triggerPhaseTransition() {
    pauseEngine();
    
    if (!_timerComponent.timer.finished) {
      _timerComponent.timer.stop();
    }
    
    // Store plants collected
    plantsCollectedNotifier.value = plantsCollected;
    
    // Check if player collected materials (score >= 60% threshold)
    if (plantsCollected > 0) {
      // SUCCESS: All tiles green + materials collected
      if (!overlays.isActive('PhaseComplete')) {
        overlays.add('PhaseComplete');
      }
    } else {
      // FAILURE: All tiles green but plants too immature
      if (!overlays.isActive('InsufficientMaterials')) {
        overlays.add('InsufficientMaterials');
      }
    }
  }
  
  void startPhase2() {
    currentPhase = 2;
    overlays.remove('PhaseComplete');
    
    if (!overlays.isActive('DyeExtraction')) {
      overlays.add('DyeExtraction');
    }
  }
  
  // UPDATED: Reset game state including new time tracking
  void restartGame() {
    scoreNotifier.value = 0;
    hintsRemaining = 5;
    isProcessing = false;
    currentPhase = 1;
    plantsCollected = 0;
    plantsCollectedNotifier.value = 0;
    sixtyPercentAchievedTime = null; // Reset time tracking
    
    // Reset tile restoration state
    restoredTiles = List.generate(rows, (_) => List.generate(cols, (_) => false));
    
    final items = children.whereType<EcoItem>().toList();
    for(var i in items) {
      i.removeFromParent();
    }
    
    gridItems = List.generate(rows, (_) => List.generate(cols, (_) => null));

    if (currentLevel == 1) {
      _buildTutorialGrid();
    } else {
      _buildShuffledGrid();
    }
    
    _setupTimer(); 
    
    overlays.remove('GameOver');
    overlays.remove('PhaseComplete');
    overlays.remove('InsufficientMaterials');
    overlays.remove('DyeExtraction');
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
    sixtyPercentAchievedTime = null; // Reset time tracking
    
    restoredTiles = List.generate(rows, (_) => List.generate(cols, (_) => false));
    
    final items = children.whereType<EcoItem>().toList();
    for(var i in items) {
      i.removeFromParent();
    }
    
    gridItems = List.generate(rows, (_) => List.generate(cols, (_) => null));

    _buildShuffledGrid();
    _setupTimer(); 
    
    overlays.remove('GameOver');
    overlays.remove('PhaseComplete');
    overlays.remove('InsufficientMaterials');
    overlays.remove('DyeExtraction');
    
    scoreNotifier.value = 0;
    
    debugPrint("🎮 Starting Level $currentLevel");
  }

  void _buildTutorialGrid() {
    // 6x6 tutorial grid with balanced distribution
    List<List<String>> fixedMap = [
      ['rain', 'rain', 'summer', 'rain', 'rose', 'man'],
      ['rose', 'man', 'hummingbird', 'rose', 'summer', 'hummingbird'],
      ['hummingbird', 'rain', 'summer', 'man', 'rain', 'rose'],
      ['man', 'rose', 'rain', 'hummingbird', 'man', 'summer'],
      ['summer', 'hummingbird', 'rose', 'summer', 'hummingbird', 'rain'],
      ['rain', 'man', 'man', 'rain', 'rose', 'hummingbird'],
    ];

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        _spawnItemAt(r, c, fixedMap[r][c], animate: false);
      }
    }
  }

  void _buildShuffledGrid() {
    // Create a list of all item types with balanced distribution
    List<String> allItemTypes = [];
    
    // Calculate how many of each type we need for a 6x6 grid (36 tiles)
    int tilesPerType = (rows * cols) ~/ level1ItemTypes.length; // 36 / 5 = 7 tiles per type
    int remainder = (rows * cols) % level1ItemTypes.length; // 36 % 5 = 1 extra tile
    
    // Add tiles for each type
    for (int i = 0; i < level1ItemTypes.length; i++) {
      int count = tilesPerType;
      // Distribute remainder tiles
      if (i < remainder) count++;
      
      for (int j = 0; j < count; j++) {
        allItemTypes.add(level1ItemTypes[i]);
      }
    }
    
    // Shuffle the list
    allItemTypes.shuffle();
    
    // Create a temporary grid to check for immediate matches
    List<List<String>> tempGrid = List.generate(rows, (_) => List.generate(cols, (_) => ''));
    
    // Place items in grid, ensuring no immediate matches
    int itemIndex = 0;
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        // Try to place an item that doesn't create immediate match
        bool placed = false;
        int attempts = 0;
        
        while (!placed && attempts < allItemTypes.length) {
          String candidateType = allItemTypes[itemIndex % allItemTypes.length];
          
          // Check if this creates a horizontal match
          bool horizontalMatch = false;
          if (c >= 2 && tempGrid[r][c-1] == candidateType && tempGrid[r][c-2] == candidateType) {
            horizontalMatch = true;
          }
          
          // Check if this creates a vertical match
          bool verticalMatch = false;
          if (r >= 2 && tempGrid[r-1][c] == candidateType && tempGrid[r-2][c] == candidateType) {
            verticalMatch = true;
          }
          
          if (!horizontalMatch && !verticalMatch) {
            tempGrid[r][c] = candidateType;
            _spawnItemAt(r, c, candidateType, animate: false);
            placed = true;
          }
          
          itemIndex++;
          attempts++;
        }
        
        // Fallback: if we couldn't place without match, place anyway
        if (!placed) {
          String fallbackType = allItemTypes[itemIndex % allItemTypes.length];
          tempGrid[r][c] = fallbackType;
          _spawnItemAt(r, c, fallbackType, animate: false);
          itemIndex++;
        }
      }
    }
    
    debugPrint("🎲 Shuffled grid built for Level $currentLevel");
  }

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
      await _processMatches(matches);
    } else {
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
        EcoItem? i1 = gridItems[r][c];
        EcoItem? i2 = gridItems[r][c+1];
        EcoItem? i3 = gridItems[r][c+2];
        if (i1 != null && i2 != null && i3 != null && i1.type == i2.type && i2.type == i3.type) {
            matchSet.addAll([i1, i2, i3]);
        }
      }
    }

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
      
      // Mark tile as restored (turn green)
      restoredTiles[r][c] = true;
      
      gridItems[r][c] = null;
    }
    
    await Future.delayed(const Duration(milliseconds: 250));
    
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
      if (!_hasPossibleMoves()) {
        if (levelTimeNotifier.value > 0) {
            debugPrint("⛔ No moves left! Auto-Shuffling...");
            await _shuffleBoard();
        } else {
            _triggerGameOver(false);
        }
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

  // UPDATED: Restoration percentage now based on tiles, not score
  double getRestorationPercentage() {
    int restoredCount = 0;
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (restoredTiles[r][c]) {
          restoredCount++;
        }
      }
    }
    return (restoredCount / totalTiles) * 100;
  }

  int getForestImageIndex() {
    int restoredCount = 0;
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (restoredTiles[r][c]) {
          restoredCount++;
        }
      }
    }
    
    double percentage = (restoredCount / totalTiles).clamp(0.0, 1.0);
    int index = (percentage * 9).round();
    return index;
  }
}