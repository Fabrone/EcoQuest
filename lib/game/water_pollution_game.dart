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
    
    onPhaseComplete?.call(1);
    pauseEngine();
  }
  
  void startPhase2Sorting() {
    currentPhase = 2;
    _setupSortingPhase();
  }

  void _setupSortingPhase() async {
    // Pause engine first
    pauseEngine();
    
    // Remove old phase components
    final toRemove = children.where((c) => 
      c is WasteItemComponent || 
      c is SpeedboatComponent || 
      c is RiverBackgroundComponent ||
      c is RiverParticleComponent
    ).toList();
    
    for (var child in toRemove) {
      child.removeFromParent();
    }
    
    // Small delay to ensure cleanup
    await Future.delayed(const Duration(milliseconds: 100));
    
    // Verify size is ready
    if (size.x == 0 || size.y == 0) {
      await Future.delayed(const Duration(milliseconds: 200));
    }
    
    // Add sorting facility background
    final bgComponent = SortingFacilityBackground(size: size);
    await add(bgComponent);
    
    // Create conveyor belt
    final conveyor = ConveyorBeltComponent(
      position: Vector2(0, size.y * 0.35),
      size: Vector2(size.x, size.y * 0.3),
    );
    await add(conveyor);
    
    // Spawn bins with better positioning
    final binTypes = ['plastic', 'metal', 'hazardous', 'organic'];
    bins.clear();
    
    final screenWidth = size.x;
    final binSpacing = screenWidth / (binTypes.length + 1);
    final binSize = Vector2(screenWidth * 0.15, screenWidth * 0.22);
    
    for (int i = 0; i < binTypes.length; i++) {
      final bin = BinComponent(
        binType: binTypes[i],
        position: Vector2(
          binSpacing * (i + 1) - binSize.x / 2,
          size.y - binSize.y - 30,
        ),
        size: binSize,
      );
      bins.add(bin);
      await add(bin);
    }
    
    // Ensure collected waste is available
    if (collectedWaste.isEmpty) {
      // Create sample waste for testing
      final wasteTypes = ['plastic_bottle', 'can', 'bag', 'oil_slick', 'wood'];
      for (int i = 0; i < 15; i++) {
        collectedWaste.add(
          WasteItemComponent(
            type: wasteTypes[i % wasteTypes.length],
            position: Vector2.zero(),
            size: Vector2.all(45),
          ),
        );
      }
    }
    
    // Spawn waste items on conveyor
    _spawnWasteOnConveyor();
    
    // Resume engine to start rendering
    resumeEngine();
  }

  void _spawnWasteOnConveyor() {
    final random = Random();
    int spawnedCount = 0;
    const spawnInterval = 3.0; // 3 seconds between items
    
    // Spawn first item immediately
    if (collectedWaste.isNotEmpty) {
      final firstWaste = collectedWaste[0];
      
      // Position on conveyor - START FROM LEFT EDGE (visible)
      firstWaste.position = Vector2(
        20, // Start from left side, visible
        size.y * 0.45, // Center of conveyor
      );
      firstWaste.priority = 150;
      
      // Reset any existing effects
      firstWaste.removeAll(firstWaste.children.whereType<Effect>());
      
      add(firstWaste);
      
      // Add pulsing effect to show it's draggable
      firstWaste.add(
        SequenceEffect([
          ScaleEffect.to(
            Vector2.all(1.1),
            EffectController(duration: 0.5, alternate: true, infinite: true),
          ),
        ]),
      );
      
      // Conveyor movement - slower for better gameplay
      final moveEffect = MoveEffect.to(
        Vector2(size.x + 100, firstWaste.position.y),
        EffectController(duration: 12.0), // Slower = more time to grab
        onComplete: () {
          if (firstWaste.parent != null) {
            firstWaste.removeFromParent();
            sortedIncorrectly++;
            _updateSortingStats();
          }
        },
      );
      firstWaste.add(moveEffect);
      
      spawnedCount = 1;
    }
    
    // Continue spawning remaining items
    Timer.periodic(Duration(milliseconds: (spawnInterval * 1000).toInt()), (timer) {
      if (spawnedCount >= collectedWaste.length || currentPhase != 2) {
        timer.cancel();
        return;
      }
      
      if (spawnedCount < collectedWaste.length) {
        final waste = collectedWaste[spawnedCount];
        
        // Position on conveyor entrance - START VISIBLE
        waste.position = Vector2(
          20, // Start from left side, visible
          size.y * 0.40 + (random.nextDouble() - 0.5) * 40,
        );
        
        waste.priority = 150;
        
        // Reset any existing effects
        waste.removeAll(waste.children.whereType<Effect>());
        
        add(waste);
        
        // Add pulsing effect to show it's draggable
        waste.add(
          SequenceEffect([
            ScaleEffect.to(
              Vector2.all(1.1),
              EffectController(duration: 0.5, alternate: true, infinite: true),
            ),
          ]),
        );
        
        // Conveyor movement
        final moveEffect = MoveEffect.to(
          Vector2(size.x + 100, waste.position.y),
          EffectController(duration: 12.0),
          onComplete: () {
            if (waste.parent != null) {
              waste.removeFromParent();
              sortedIncorrectly++;
              _updateSortingStats();
            }
          },
        );
        waste.add(moveEffect);
        
        spawnedCount++;
      }
    });
  }

  @override
  bool onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    
    if (currentPhase != 2) return false;
    
    // Find waste item at touch position
    final wasteItems = children.whereType<WasteItemComponent>().toList();
    
    for (final waste in wasteItems.reversed) {
      // Check if touch point is within waste bounds
      final wasteRect = Rect.fromCenter(
        center: Offset(waste.position.x, waste.position.y),
        width: waste.size.x * 1.2, // Slightly larger hit area
        height: waste.size.y * 1.2,
      );
      
      if (wasteRect.contains(event.localPosition.toOffset())) {
        currentDragged = waste;
        
        // Remove ALL movement effects while dragging
        waste.removeAll(waste.children.whereType<Effect>());
        
        // Enhanced lift effect with rotation
        waste.add(
          CombinedEffect([
            ScaleEffect.to(
              Vector2.all(1.4),
              EffectController(duration: 0.2),
            ),
            OpacityEffect.to(
              1.0,
              EffectController(duration: 0.2),
            ),
          ]),
        );
        
        // Bring to front
        waste.priority = 250;
        
        return true;
      }
    }
    
    return false;
  }

  @override
  bool onDragUpdate(DragUpdateEvent event) {
    super.onDragUpdate(event);
    
    if (currentDragged != null) {
      // Update position directly with drag delta
      currentDragged!.position += event.localDelta;
      return true;
    }
    
    return false;
  }

  @override
  bool onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    
    if (currentDragged != null) {
      bool droppedOnBin = false;
      
      // Check each bin for drop
      for (var bin in bins) {
        // Create bin drop zone
        final binRect = Rect.fromCenter(
          center: Offset(
            bin.position.x + bin.size.x / 2,
            bin.position.y + bin.size.y / 2,
          ),
          width: bin.size.x * 1.3,
          height: bin.size.y * 1.3,
        );
        
        // Check if waste center is in bin zone
        if (binRect.contains(Offset(currentDragged!.position.x, currentDragged!.position.y))) {
          submitSort(currentDragged!, bin);
          droppedOnBin = true;
          break;
        }
      }
      
      if (!droppedOnBin) {
        // Return to conveyor with animation
        currentDragged!.removeAll(currentDragged!.children.whereType<Effect>());
        
        currentDragged!.add(
          SequenceEffect([
            ScaleEffect.to(
              Vector2.all(1.0),
              EffectController(duration: 0.3),
            ),
          ]),
        );
        
        // Reset priority
        currentDragged!.priority = 150;
        
        // Add pulsing effect back
        currentDragged!.add(
          SequenceEffect([
            ScaleEffect.to(
              Vector2.all(1.1),
              EffectController(duration: 0.5, alternate: true, infinite: true),
            ),
          ]),
        );
        
        // Resume conveyor movement from current position
        final remainingDistance = size.x + 100 - currentDragged!.position.x;
        final speed = 12.0; // Same as original
        final duration = (remainingDistance / ((size.x + 100) / speed)).clamp(1.0, speed);
        
        currentDragged!.add(
          MoveEffect.to(
            Vector2(size.x + 100, currentDragged!.position.y),
            EffectController(duration: duration),
            onComplete: () {
              if (currentDragged?.parent != null) {
                currentDragged!.removeFromParent();
                sortedIncorrectly++;
                _updateSortingStats();
              }
            },
          ),
        );
      }
      
      currentDragged = null;
      return true;
    }
    
    return false;
  }

  void submitSort(WasteItemComponent waste, BinComponent bin) {
    bool correct = _isCorrectBin(waste.type, bin.binType);
    
    // Remove all effects before animating
    waste.removeAll(waste.children.whereType<Effect>());
    
    // Animate waste disappearing into bin
    waste.add(
      SequenceEffect([
        CombinedEffect([
          MoveEffect.to(
            bin.position + Vector2(bin.size.x / 2, bin.size.y * 0.4),
            EffectController(duration: 0.4, curve: Curves.easeInOut),
          ),
          ScaleEffect.to(
            Vector2.all(0.2),
            EffectController(duration: 0.4),
          ),
          RotateEffect.by(
            pi * 2,
            EffectController(duration: 0.4),
          ),
        ]),
        RemoveEffect(delay: 0.1),
      ]),
    );
    
    if (correct) {
      sortedCorrectly++;
      bin.triggerSuccessAnimation();
    } else {
      sortedIncorrectly++;
      bin.triggerErrorAnimation();
    }
    
    _updateSortingStats();
  }
      
  void _updateSortingStats() {
    int total = sortedCorrectly + sortedIncorrectly;
    int accuracy = total > 0 ? ((sortedCorrectly / total) * 100).round() : 0;
    
    onSortingUpdate?.call(accuracy, total);
    
    // Check if sorting complete
    if (total >= collectedWaste.length) {
      Future.delayed(const Duration(seconds: 2), () {
        if (accuracy >= 60) { // More forgiving threshold
          _completePhase2();
        } else {
          // Can add retry logic here
          onSortingUpdate?.call(accuracy, total);
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