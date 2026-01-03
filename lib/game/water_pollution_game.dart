import 'dart:async';
import 'dart:math';
import 'package:ecoquest/game/water_components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class WaterPollutionGame extends FlameGame with TapCallbacks, DragCallbacks, KeyboardEvents {
  final int bacteriaCultures;
  
  // Callbacks for UI updates
  Function(int)? onWasteCollected;
  Function(int)? onPhaseComplete;
  Function(int, int)? onSortingUpdate;
  Function(int, double)? onTreatmentUpdate;
  Function(int, int)? onAgricultureUpdate;
  
  // Game state
  int currentPhase = 1; // 1=Collection, 2=Sorting, 3=Treatment, 4=Agriculture
  
  // Phase 1 - Collection
  SpeedboatComponent? speedboat;
  List<WasteItemComponent> wasteItems = [];
  int wasteCollectedCount = 0;
  static const int totalWasteToCollect = 50;
  
  // Phase 2 - Sorting
  int sortedCorrectly = 0;
  int sortedIncorrectly = 0;
  
  // Phase 3 - Treatment
  List<WaterTileComponent> waterTiles = [];
  int bacteriaRemaining;
  int zonesTreated = 0;
  double pollutionMeter = 100.0;
  
  // Phase 4 - Agriculture
  int waterEfficiency = 0;
  List<FarmZoneComponent> farmZones = [];
  
  // Carry-forward resources
  int purifiedWaterAmount = 0;
  int bacteriaMultiplied = 0;
  int recycledMaterials = 0;

  // New for sorting
  List<WasteItemComponent> collectedWaste = [];
  List<BinComponent> bins = [];
  WasteItemComponent? currentDragged;

  // New for agriculture
  List<PipeComponent> pipeGrid = [];
  bool pipelineConnected = false;

  WaterPollutionGame({required this.bacteriaCultures}) : bacteriaRemaining = bacteriaCultures;
  
  @override
  Color backgroundColor() => const Color(0x00000000);
  
  @override
  Future<void> onLoad() async {
    await super.onLoad();
    priority = 0;
  }

  @override
  KeyEventResult onKeyEvent(
    KeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    // Pass keyboard events to speedboat if it exists
    if (speedboat != null && currentPhase == 1) {
      final handled = speedboat!.onKeyEvent(event, keysPressed);
      return handled ? KeyEventResult.handled : KeyEventResult.ignored;
    }
    return KeyEventResult.ignored;
  }

  void startPhase1() {
    currentPhase = 1;
    _setupCollectionPhase();
  }
    
  void _setupCollectionPhase() async {
    wasteItems.clear();
    
    final childrenToRemove = children.toList();
    for (var child in childrenToRemove) {
      child.removeFromParent();
    }
    
    await Future.delayed(const Duration(milliseconds: 100));
    
    if (size.x == 0 || size.y == 0) {
      await Future.delayed(const Duration(milliseconds: 200));
    }
    
    // Add realistic river background
    _setupRiverBackground();
    
    // Create speedboat
    speedboat = SpeedboatComponent(
      position: Vector2(size.x / 2, size.y - 120),
      size: Vector2(70, 50), // Slightly larger for better visibility
    );
    await add(speedboat!);
    
    // Spawn waste items with better distribution
    _spawnWasteItems();
    
    // Enhanced river effects
    _setupRiverCurrent();
    _setupRiverParticles();
    
    resumeEngine();
  }
    
  void _setupRiverBackground() {
    // Create animated river background component
    final riverBg = RiverBackgroundComponent(size: size);
    add(riverBg);
  }

  void _setupRiverParticles() {
    // Add floating particles for river ambience
    for (int i = 0; i < 30; i++) {
      final particle = RiverParticleComponent(
        position: Vector2(
          Random().nextDouble() * size.x,
          Random().nextDouble() * size.y,
        ),
      );
      add(particle);
    }
  }

  void _spawnWasteItems() {
    final random = Random();
    final wasteTypes = ['plastic_bottle', 'can', 'bag', 'oil_slick', 'wood'];
    
    // More organic distribution in clusters
    final clusters = 8;
    for (int cluster = 0; cluster < clusters; cluster++) {
      final clusterX = (size.x / (clusters + 1)) * (cluster + 1);
      final clusterY = (size.y / 3) + random.nextDouble() * (size.y / 2);
      
      // 5-7 items per cluster
      final itemsInCluster = 5 + random.nextInt(3);
      
      for (int i = 0; i < itemsInCluster; i++) {
        final type = wasteTypes[random.nextInt(wasteTypes.length)];
        
        // Spread items around cluster center
        final offsetX = (random.nextDouble() - 0.5) * 120;
        final offsetY = (random.nextDouble() - 0.5) * 100;
        
        final baseSize = type == 'oil_slick' ? 55.0 : 40.0;
        final sizeVariation = random.nextDouble() * 15;
        
        final waste = WasteItemComponent(
          type: type,
          position: Vector2(
            (clusterX + offsetX).clamp(50, size.x - 50),
            (clusterY + offsetY).clamp(50, size.y - 150),
          ),
          size: Vector2.all(baseSize + sizeVariation),
        );
        
        wasteItems.add(waste);
        add(waste);
      }
    }
  }
    
  void _setupRiverCurrent() {
    final random = Random();
    
    for (var waste in wasteItems) {
      // Varied drift speeds based on item type
      double driftSpeed = 1.0;
      switch (waste.type) {
        case 'oil_slick':
          driftSpeed = 0.5; // Slower, spreads on surface
          break;
        case 'bag':
          driftSpeed = 1.5; // Faster, lighter
          break;
        case 'wood':
          driftSpeed = 0.8; // Moderate
          break;
        default:
          driftSpeed = 1.0;
      }
      
      // Main downward current
      waste.add(
        MoveEffect.by(
          Vector2(0, 120 * driftSpeed),
          EffectController(
            duration: 12 / driftSpeed + random.nextDouble() * 8,
            infinite: true,
          ),
        ),
      );
      
      // Horizontal drift
      waste.add(
        MoveEffect.by(
          Vector2((random.nextDouble() - 0.5) * 40, 0),
          EffectController(
            duration: 4 + random.nextDouble() * 3,
            infinite: true,
            alternate: true,
          ),
        ),
      );
      
      // Occasional swirl effect
      if (random.nextBool()) {
        waste.add(
          MoveEffect.by(
            Vector2(
              (random.nextDouble() - 0.5) * 60,
              (random.nextDouble() - 0.5) * 40,
            ),
            EffectController(
              duration: 6 + random.nextDouble() * 4,
              infinite: true,
              curve: Curves.easeInOutSine,
              alternate: true,
            ),
          ),
        );
      }
    }
  }
  
  void collectWaste(WasteItemComponent waste) {
    if (wasteItems.contains(waste)) {
      wasteItems.remove(waste);
      collectedWaste.add(waste);
      waste.removeFromParent();
      wasteCollectedCount++;
      
      onWasteCollected?.call(wasteCollectedCount);
      
      // Check if collection phase complete
      if (wasteCollectedCount >= (totalWasteToCollect * 0.8)) {
        _completePhase1();
      }
    }
  }
    
  void _completePhase1() {
    // Calculate recycled materials based on collection
    recycledMaterials = (wasteCollectedCount * 0.5).round();
    
    // Store collected waste for sorting phase
    if (collectedWaste.isEmpty) {
      // Transfer remaining waste items to collected waste
      collectedWaste.addAll(wasteItems);
    }
    
    onPhaseComplete?.call(1);
    pauseEngine();
  }
  
  void startPhase2Sorting() {
    currentPhase = 2;
    _setupSortingPhase();
  }

  void _setupSortingPhase() async {
    print('=== SORTING PHASE DEBUG ===');
    print('Starting sorting phase setup');
    print('Current phase: $currentPhase');
    print('Collected waste count: ${collectedWaste.length}');
    
    pauseEngine();
    
    // Clear all previous components
    final toRemove = children.toList();
    print('Removing ${toRemove.length} previous components');
    for (var child in toRemove) {
      child.removeFromParent();
    }
    
    await Future.delayed(const Duration(milliseconds: 150));
    
    // Add sorting facility background
    final bgComponent = SortingFacilityBackground(size: size);
    await add(bgComponent);
    print('Added background component');
    
    // Setup bins with better spacing and sizing
    bins.clear();
    final binTypes = ['plastic', 'metal', 'hazardous', 'organic'];
    final binWidth = size.x * 0.18;
    final binHeight = binWidth * 1.3;
    final totalBinWidth = binWidth * binTypes.length;
    final spacing = (size.x - totalBinWidth) / (binTypes.length + 1);
    
    print('Creating ${binTypes.length} bins');
    for (int i = 0; i < binTypes.length; i++) {
      final bin = BinComponent(
        binType: binTypes[i],
        position: Vector2(
          spacing + (binWidth + spacing) * i,
          size.y - binHeight - 40,
        ),
        size: Vector2(binWidth, binHeight),
      );
      bins.add(bin);
      await add(bin);
    }
    print('Bins added: ${bins.length}');
    
    // Ensure we have waste to sort
    if (collectedWaste.isEmpty) {
      print('WARNING: No collected waste found, generating default waste');
      final wasteTypes = ['plastic_bottle', 'can', 'bag', 'oil_slick', 'wood'];
      for (int i = 0; i < 20; i++) {
        collectedWaste.add(
          WasteItemComponent(
            type: wasteTypes[i % wasteTypes.length],
            position: Vector2.zero(),
            size: Vector2.all(50),
          ),
        );
      }
    }
    
    print('Total waste items to sort: ${collectedWaste.length}');
    
    // Start spawning items in a grid layout
    _spawnWasteInGrid();
    
    print('Resuming engine');
    resumeEngine();
    print('=== SORTING PHASE SETUP COMPLETE ===');
  }

  void _spawnWasteInGrid() {
    // Place items in a visible grid for easy dragging
    final itemsPerRow = 4;
    final itemSize = size.x * 0.15;
    final spacing = (size.x - (itemsPerRow * itemSize)) / (itemsPerRow + 1);
    final startY = size.y * 0.15;
    
    for (int i = 0; i < collectedWaste.length && i < 12; i++) {
      final waste = collectedWaste[i];
      final row = i ~/ itemsPerRow;
      final col = i % itemsPerRow;
      
      waste.position = Vector2(
        spacing + (itemSize + spacing) * col + itemSize / 2,
        startY + row * (itemSize + spacing * 1.5) + itemSize / 2,
      );
      waste.size = Vector2.all(itemSize * 0.8);
      waste.priority = 150;
      
      // Remove any existing effects
      waste.removeAll(waste.children.whereType<Effect>());
      
      // Add idle pulse to show it's draggable
      waste.add(
        SequenceEffect([
          ScaleEffect.by(
            Vector2.all(0.1),
            EffectController(duration: 0.8, alternate: true, infinite: true),
          ),
        ]),
      );
      
      add(waste);
    }
  }

  @override
  bool onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    
    if (currentPhase != 2) return false;
    
    // Find waste items currently visible
    final wasteItems = children.whereType<WasteItemComponent>().toList();
    
    // Check from top priority (front) to back
    for (final waste in wasteItems.reversed) {
      final distanceToCenter = (waste.position - event.localPosition).length;
      
      // Check if touch is within waste bounds (using radius check for better UX)
      if (distanceToCenter < waste.size.x * 0.8) {
        currentDragged = waste;
        
        // Stop all animations
        waste.removeAll(waste.children.whereType<Effect>());
        
        // Lift effect
        waste.add(
          ScaleEffect.to(
            Vector2.all(1.3),
            EffectController(duration: 0.15),
          ),
        );
        
        waste.priority = 300;
        return true;
      }
    }
    
    return false;
  }

  @override
  bool onDragUpdate(DragUpdateEvent event) {
    super.onDragUpdate(event);
    
    if (currentDragged != null) {
      // Smooth position update using canvasPosition
      currentDragged!.position += event.localDelta;
      
      // Visual feedback - no opacity changes needed, just position tracking
      return true;
    }
    
    return false;
  }

  @override
  bool onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    
    if (currentDragged != null) {
      bool sortedSuccessfully = false;
      
      // Check all bins for valid drop
      for (var bin in bins) {
        if (bin.containsDrop(currentDragged!)) {
          submitSort(currentDragged!, bin);
          sortedSuccessfully = true;
          break;
        }
      }
      
      if (!sortedSuccessfully) {
        // Return to original position with bounce animation
        currentDragged!.removeAll(currentDragged!.children.whereType<Effect>());
        
        currentDragged!.add(
          SequenceEffect([
            ScaleEffect.to(
              Vector2.all(1.0),
              EffectController(duration: 0.2, curve: Curves.elasticOut),
            ),
          ]),
        );
        
        // Restore idle animation
        currentDragged!.add(
          SequenceEffect([
            ScaleEffect.by(
              Vector2.all(0.1),
              EffectController(duration: 0.8, alternate: true, infinite: true),
            ),
          ]),
        );
        
        currentDragged!.priority = 150;
      }
      
      currentDragged = null;
      return true;
    }
    
    return false;
  }

  void submitSort(WasteItemComponent waste, BinComponent bin) {
    bool correct = _isCorrectBin(waste.type, bin.binType);
    
    // Remove all effects
    waste.removeAll(waste.children.whereType<Effect>());
    
    // Animate into bin using SequenceEffect with MoveEffect, ScaleEffect, and RotateEffect
    waste.add(
      SequenceEffect([
        MoveEffect.to(
          bin.position + Vector2(bin.size.x / 2, bin.size.y * 0.4),
          EffectController(duration: 0.3, curve: Curves.easeInQuad),
        ),
        RemoveEffect(),
      ]),
    );
    
    // Add scale effect separately
    waste.add(
      ScaleEffect.to(
        Vector2.all(0.1),
        EffectController(duration: 0.3),
      ),
    );
    
    // Add rotation effect
    waste.add(
      RotateEffect.by(
        correct ? pi : -pi,
        EffectController(duration: 0.3),
      ),
    );
    
    if (correct) {
      sortedCorrectly++;
      bin.triggerSuccessAnimation();
    } else {
      sortedIncorrectly++;
      bin.triggerErrorAnimation();
    }
    
    // Remove from collected waste list
    collectedWaste.remove(waste);
    
    _updateSortingStats();
    
    // Spawn next item if available
    _spawnNextWasteItem();
  }

  void _spawnNextWasteItem() {
    // Count currently visible items
    final visibleWaste = children.whereType<WasteItemComponent>().length;
    
    // Keep 8-12 items visible at a time
    if (visibleWaste < 8 && collectedWaste.isNotEmpty) {
      // Find next unsorted item
      for (var waste in collectedWaste) {
        if (waste.parent == null) {
          // Position in available grid slot
          final existingItems = children.whereType<WasteItemComponent>().toList();
          final itemsPerRow = 4;
          final itemSize = size.x * 0.15;
          final spacing = (size.x - (itemsPerRow * itemSize)) / (itemsPerRow + 1);
          final startY = size.y * 0.15;
          
          final index = existingItems.length;
          final row = index ~/ itemsPerRow;
          final col = index % itemsPerRow;
          
          waste.position = Vector2(
            spacing + (itemSize + spacing) * col + itemSize / 2,
            startY + row * (itemSize + spacing * 1.5) + itemSize / 2,
          );
          waste.size = Vector2.all(itemSize * 0.8);
          waste.priority = 150;
          
          waste.removeAll(waste.children.whereType<Effect>());
          
          // Spawn animation
          waste.scale = Vector2.all(0.1);
          waste.add(
            SequenceEffect([
              ScaleEffect.to(
                Vector2.all(1.0),
                EffectController(duration: 0.4, curve: Curves.elasticOut),
              ),
              ScaleEffect.by(
                Vector2.all(0.1),
                EffectController(duration: 0.8, alternate: true, infinite: true),
              ),
            ]),
          );
          
          add(waste);
          break;
        }
      }
    }
  }

  void _updateSortingStats() {
    int total = sortedCorrectly + sortedIncorrectly;
    int accuracy = total > 0 ? ((sortedCorrectly / total) * 100).round() : 0;
    
    onSortingUpdate?.call(accuracy, total);
    
    // Get original collected count (before any sorting)
    final totalToSort = sortedCorrectly + sortedIncorrectly + collectedWaste.length;
    
    // Check if ALL items have been sorted
    if (total >= totalToSort && collectedWaste.isEmpty) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (accuracy >= 50) {
          _completePhase2();
        } else {
          // Show retry message or auto-complete with penalty
          _completePhase2();
        }
      });
    }
  }

  bool _isCorrectBin(String wasteType, String binType) {
    final correctMappings = {
      'plastic_bottle': 'plastic',
      'bag': 'plastic',
      'can': 'metal',
      'oil_slick': 'hazardous',
      'wood': 'organic',
    };
    
    return correctMappings[wasteType] == binType;
  }
  
  void _completePhase2() {
    onPhaseComplete?.call(2);
  }
  
  void startPhase3Treatment() {
    currentPhase = 3;
    _setupTreatmentPhase();
  }
  
  void _setupTreatmentPhase() {
    // Create grid of water tiles (6x6)
    const int rows = 6;
    const int cols = 6;
    final tileSize = min(size.x, size.y) / cols;
    final startX = (size.x - (cols * tileSize)) / 2;
    final startY = (size.y - (rows * tileSize)) / 2;
    
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final tile = WaterTileComponent(
          row: r,
          col: c,
          position: Vector2(startX + c * tileSize, startY + r * tileSize),
          size: Vector2(tileSize, tileSize),
          isPolluted: Random().nextDouble() < 0.6, // 60% polluted
        );
        
        waterTiles.add(tile);
        add(tile);
      }
    }
    
    resumeEngine();
  }

  @override
  void onTapDown(TapDownEvent event) {
    super.onTapDown(event);
    
    if (currentPhase == 3 && bacteriaRemaining > 0) {
      // Check if clicked on polluted tile
      for (var tile in waterTiles) {
        if (tile.containsPoint(event.localPosition) && tile.isPolluted) {
          treatTile(tile);
          break;
        }
      }
    }
  }
  
  // Made public so WaterTileComponent can call it
  void treatTile(WaterTileComponent tile) {
    if (bacteriaRemaining <= 0) return;
    
    bacteriaRemaining--;
    tile.startTreatment();
    
    // Wait for treatment animation
    Future.delayed(const Duration(seconds: 2), () {
      tile.completeTreatment();
      zonesTreated++;
      pollutionMeter = max(0, pollutionMeter - (100 / waterTiles.length));
      
      onTreatmentUpdate?.call(zonesTreated, pollutionMeter);
      
      // Check if all zones treated
      final pollutedTiles = waterTiles.where((t) => t.isPolluted).length;
      if (zonesTreated >= pollutedTiles) {
        _completePhase3();
      }
    });
  }
  
  void _completePhase3() {
    // Calculate purified water amount
    purifiedWaterAmount = (zonesTreated * 50).round(); // 50L per zone
    
    // Bacteria multiply in clean water
    bacteriaMultiplied = bacteriaRemaining + (zonesTreated * 2);
    
    onPhaseComplete?.call(3);
    pauseEngine();
  }
  
  void startPhase4Agriculture() {
    currentPhase = 4;
    _setupAgriculturePhase();
  }
  
  void _setupAgriculturePhase() {
    // Clear previous
    removeAll(children.whereType<WaterTileComponent>());

    // Add farm zones
    final farmSize = Vector2(size.x * 0.25, size.y * 0.3);
    farmZones = [];
    for (int i = 0; i < 3; i++) {
      final farm = FarmZoneComponent(
        position: Vector2(
          (size.x / 4) * (i + 0.5),
          size.y * 0.6,
        ),
        size: farmSize,
      );
      
      farmZones.add(farm);
      add(farm);
    }

    // Add pipe grid (e.g., 5x5 grid)
    const gridRows = 5;
    const gridCols = 5;
    final pipeSize = Vector2(50, 50);
    final startGridX = (size.x - (gridCols * pipeSize.x)) / 2;
    final startGridY = 50; // Top area for pipes
    pipeGrid = [];
    for (int r = 0; r < gridRows; r++) {
      for (int c = 0; c < gridCols; c++) {
        final pipeType = Random().nextBool() ? 'straight' : 'corner';
        final pipe = PipeComponent(
          position: Vector2(startGridX + c * pipeSize.x, startGridY + r * pipeSize.y),
          pipeType: pipeType,
          size: pipeSize,
        );
        add(pipe);
        pipeGrid.add(pipe);
      }
    }
    resumeEngine();
  }
  
  void checkPipelineConnection() {
    // Simple logic: check if all pipes are rotated correctly
    int correct = pipeGrid.where((p) => p.rotationState % 2 == 0).length;
    bool connected = correct > pipeGrid.length / 2;
    if (connected) {
      pipelineConnected = true;
    }
  }
  
  void irrigateFarm(FarmZoneComponent farm, String method) {
    farm.irrigate(method);
    
    // Calculate efficiency
    waterEfficiency = _calculateWaterEfficiency();
    
    int irrigated = farmZones.where((f) => f.isIrrigated).length;
    int mature = farmZones.where((f) => f.cropsMature).length;
    
    onAgricultureUpdate?.call(irrigated, mature);
    
    // Check if all farms complete
    if (irrigated >= 3 && mature >= 2) {
      _completePhase4();
    }
    // Spawn wildlife on success
    add(WildlifeComponent(
      position: Vector2(Random().nextDouble() * size.x, Random().nextDouble() * size.y), 
      size: Vector2(32, 32)
    ));
  }
  
  int _calculateWaterEfficiency() {
    int totalEfficiency = 0;
    for (var farm in farmZones) {
      if (farm.method == 'drip') {
        totalEfficiency += 90;
      } else if (farm.method == 'contour') {
        totalEfficiency += 85;
      }
    }
    return farmZones.isNotEmpty ? (totalEfficiency / farmZones.length).round() : 0;
  }
  
  void _completePhase4() {
    onPhaseComplete?.call(4);
    pauseEngine();
  }
  
  int calculateFinalScore() {
    int score = 0;
    
    // Collection bonus
    score += wasteCollectedCount * 5;
    
    // Sorting accuracy bonus
    int accuracy = sortedIncorrectly > 0 
      ? ((sortedCorrectly / (sortedCorrectly + sortedIncorrectly)) * 100).round()
      : 100;
    if (accuracy >= 90) {
      score += 100;
    } else if (accuracy >= 85) {
      score += 50;
    }
    
    // Treatment bonus
    score += zonesTreated * 20;
    if (pollutionMeter == 0) score += 150;
    
    // Agriculture bonus
    score += farmZones.where((f) => f.cropsMature).length * 30;
    if (waterEfficiency >= 85) score += 100;
    
    return score;
  }
}