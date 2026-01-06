import 'dart:async';
import 'dart:math';
import 'package:ecoquest/game/water_components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flame/components.dart';
import 'package:google_fonts/google_fonts.dart';
class WaterPollutionGame extends FlameGame with KeyboardEvents {
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
  WasteItemComponent? selectedWaste; // For tap-to-select interaction
  
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

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    debugPrint('Game resized to: ${size.x} x ${size.y}');
    
    // If in sorting phase, reposition components
    if (currentPhase == 2 && bins.isNotEmpty) {
      _repositionSortingComponents();
    }
  }

  void _repositionSortingComponents() {
    debugPrint('Repositioning sorting components for new size: ${size.x} x ${size.y}');
    
    // Recalculate bin positions
    final binTypes = ['plastic', 'metal', 'hazardous', 'organic'];
    final horizontalPadding = size.x * 0.05;
    final availableWidth = size.x - (2 * horizontalPadding);
    final binSpacing = availableWidth * 0.02;
    final totalSpacing = binSpacing * (binTypes.length - 1);
    final binWidth = (availableWidth - totalSpacing) / binTypes.length;
    final binHeight = size.y * 0.22;
    final binY = size.y * 0.78;
    
    for (int i = 0; i < bins.length; i++) {
      final binX = horizontalPadding + (i * (binWidth + binSpacing)) + (binWidth / 2);
      bins[i].position = Vector2(binX, binY);
      bins[i].size = Vector2(binWidth, binHeight);
    }
    
    // Reposition waste stack
    final stackCenterX = size.x * 0.5;
    final stackCenterY = size.y * 0.35;
    final itemSize = (size.x * 0.18).clamp(60.0, 150.0);
    
    final visibleWaste = children.whereType<WasteItemComponent>().toList();
    for (int i = 0; i < visibleWaste.length && i < 3; i++) {
      visibleWaste[i].position = Vector2(
        stackCenterX + (i * 3.0),
        stackCenterY - (i * 3.0),
      );
      visibleWaste[i].size = Vector2.all(itemSize);
    }
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
    if (currentPhase == 2) {
      debugPrint('WARNING: Phase 2 already started, ignoring duplicate call');
      return;
    }
    currentPhase = 2;
    _setupSortingPhase();
  }

  void _setupSortingPhase() async {
    debugPrint('=== SORTING PHASE DEBUG ===');
    
    pauseEngine();
    
    // Clear components
    final toRemove = children.toList();
    for (var child in toRemove) {
      child.removeFromParent();
    }
    
    await Future.delayed(const Duration(milliseconds: 150));
    
    // CRITICAL FIX: Wait for proper canvas sizing
    int attempts = 0;
    while ((size.x == 0 || size.y == 0 || size.x < 100 || size.y < 100) && attempts < 20) {
      debugPrint('Canvas not ready (attempt ${attempts + 1}): ${size.x} x ${size.y}');
      await Future.delayed(const Duration(milliseconds: 100));
      attempts++;
    }
    
    if (size.x == 0 || size.y == 0 || size.x < 100) {
      debugPrint('ERROR: Canvas size invalid after waiting!');
      return;
    }
    
    debugPrint('Canvas size confirmed: ${size.x} x ${size.y}');
    
    // Add background
    final bgComponent = SortingFacilityBackground(size: size);
    await add(bgComponent);
    
    // IMPROVED BIN SETUP with guaranteed spacing
    bins.clear();
    final binTypes = ['plastic', 'metal', 'hazardous', 'organic'];
    
    // Calculate responsive bin dimensions
    final horizontalPadding = size.x * 0.05; // 5% padding on each side
    final availableWidth = size.x - (2 * horizontalPadding);
    final binSpacing = availableWidth * 0.02; // 2% spacing between bins
    final totalSpacing = binSpacing * (binTypes.length - 1);
    final binWidth = (availableWidth - totalSpacing) / binTypes.length;
    final binHeight = size.y * 0.22; // 22% of canvas height
    
    // Position bins with equal spacing
    final binY = size.y * 0.78; // 78% down (leaving 22% from bottom)
    
    debugPrint('Bin layout: width=$binWidth, height=$binHeight, spacing=$binSpacing');
    
    for (int i = 0; i < binTypes.length; i++) {
      final binX = horizontalPadding + (i * (binWidth + binSpacing)) + (binWidth / 2);
      
      final bin = BinComponent(
        binType: binTypes[i],
        position: Vector2(binX, binY),
        size: Vector2(binWidth, binHeight),
      );
      bins.add(bin);
      await add(bin);
      
      debugPrint('Bin ${i + 1} (${binTypes[i]}): x=$binX, y=$binY');
    }
    
    // Setup waste stack
    if (collectedWaste.isEmpty) {
      // Generate default waste
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
    
    _createCentralizedStack();
    
    resumeEngine();
    debugPrint('=== SORTING PHASE SETUP COMPLETE ===');
  }

  void _createCentralizedStack() {
    // Position stack in safe zone (upper-middle, away from bins)
    final stackCenterX = size.x * 0.5;  // Center horizontally
    final stackCenterY = size.y * 0.35; // 35% from top (bins at 78%)
    
    // Calculate item size based on available space
    // Make items large enough to see but not overlap bins
    final maxItemSize = size.x * 0.18; // 18% of width
    final itemSize = maxItemSize.clamp(60.0, 150.0); // Min 60, max 150
    
    debugPrint('=== STACK CREATION ===');
    debugPrint('Canvas: ${size.x} x ${size.y}');
    debugPrint('Stack center: ($stackCenterX, $stackCenterY)');
    debugPrint('Item size: $itemSize');
    
    final itemsToShow = collectedWaste.length < 3 ? collectedWaste.length : 3;
    
    for (int i = 0; i < itemsToShow; i++) {
      if (i >= collectedWaste.length) break;
      
      final waste = collectedWaste[i];
      
      // Stack with slight offset
      waste.position = Vector2(
        stackCenterX + (i * 3.0),
        stackCenterY - (i * 3.0),
      );
      waste.size = Vector2.all(itemSize);
      waste.anchor = Anchor.center;
      waste.priority = 150 + (itemsToShow - i);
      
      // Remove any existing effects
      waste.removeAll(waste.children.whereType<Effect>());
      
      // Scale for depth
      waste.scale = Vector2.all(i == 0 ? 1.0 : 0.92 - (i * 0.05));
      
      add(waste);
      debugPrint('Stack item $i: pos=${waste.position}, size=${waste.size}');
    }
    
    debugPrint('=== STACK CREATION COMPLETE ===');
  }

  void showWrongBinFeedback(String wasteType, String binType) {
    debugPrint('❌ WRONG BIN: $wasteType does not belong in $binType bin');
    
    // Get the correct bin for this waste type
    final correctMappings = {
      'plastic_bottle': 'plastic',
      'bag': 'plastic',
      'can': 'metal',
      'oil_slick': 'hazardous',
      'wood': 'organic',
    };
    
    final correctBin = correctMappings[wasteType] ?? 'unknown';
    
    // Create a temporary feedback component with clear messaging
    final feedbackContainer = RectangleComponent(
      position: Vector2(size.x / 2, size.y / 2),
      size: Vector2(size.x * 0.7, 120),
      anchor: Anchor.center,
      priority: 500,
      paint: Paint()
        ..color = Colors.red.withValues(alpha: 0.95)
        ..style = PaintingStyle.fill,
    );
    
    // Add border
    feedbackContainer.add(
      RectangleComponent(
        size: feedbackContainer.size,
        paint: Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4,
      ),
    );
    
    // Main error message
    final errorText = TextComponent(
      text: '❌ WRONG BIN!',
      textRenderer: TextPaint(
        style: GoogleFonts.exo2(
          fontSize: 28,
          color: Colors.white,
          fontWeight: FontWeight.w900,
        ),
      ),
      position: Vector2(feedbackContainer.size.x / 2, 30),
      anchor: Anchor.center,
    );
    
    // Helpful hint message
    final hintText = TextComponent(
      text: '$wasteType → $correctBin bin',
      textRenderer: TextPaint(
        style: GoogleFonts.exo2(
          fontSize: 18,
          color: Colors.yellow,
          fontWeight: FontWeight.w700,
        ),
      ),
      position: Vector2(feedbackContainer.size.x / 2, 70),
      anchor: Anchor.center,
    );
    
    feedbackContainer.add(errorText);
    feedbackContainer.add(hintText);
    
    add(feedbackContainer);
    
    // Animate feedback: pulse then fade out
    feedbackContainer.add(
      SequenceEffect([
        ScaleEffect.by(
          Vector2.all(1.15),
          EffectController(duration: 0.2, alternate: true, repeatCount: 2),
        ),
        ScaleEffect.to(
          Vector2.all(1.2),
          EffectController(duration: 0.3),
        ),
        RemoveEffect(delay: 1.5), // Show for 1.5 seconds before removing
      ]),
    );
    
    // Vibration feedback (if on mobile)
    if (defaultTargetPlatform == TargetPlatform.android || 
        defaultTargetPlatform == TargetPlatform.iOS) {
      HapticFeedback.heavyImpact();
    }
    
    // Increment wrong sort counter
    sortedIncorrectly++;
    _updateSortingStats();
  }

  void _spawnNextWasteItem() {
    debugPrint('Spawning next waste item. Remaining: ${collectedWaste.length}');
    
    // Remove currently visible waste items that are not in collectedWaste anymore
    final visibleWaste = children.whereType<WasteItemComponent>().toList();
    for (var waste in visibleWaste) {
      if (!collectedWaste.contains(waste)) {
        waste.removeFromParent();
      }
    }
    
    // Recreate the stack with remaining items (STATIC)
    if (collectedWaste.isNotEmpty) {
      _createCentralizedStack();
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

  bool isCorrectBin(String wasteType, String binType) {
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

  void submitSort(WasteItemComponent waste, BinComponent bin) {
    bool correct = isCorrectBin(waste.type, bin.binType);
    
    debugPrint('${correct ? "✅" : "❌"} Sorting ${waste.type} into ${bin.binType} bin');
    
    // Remove all effects
    waste.removeAll(waste.children.whereType<Effect>());
    
    // Animate into bin
    waste.add(
      SequenceEffect([
        MoveEffect.to(
          bin.position,
          EffectController(duration: 0.4, curve: Curves.easeInQuad),
        ),
        RemoveEffect(),
      ]),
    );
    
    // Add scale effect separately
    waste.add(
      ScaleEffect.to(
        Vector2.all(0.1),
        EffectController(duration: 0.4),
      ),
    );
    
    // Add rotation effect
    waste.add(
      RotateEffect.by(
        correct ? pi : -pi,
        EffectController(duration: 0.4),
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
    
    // Spawn next item from stack
    Future.delayed(const Duration(milliseconds: 500), () {
      _spawnNextWasteItem();
    });
  }

  void onTapDown(TapDownEvent event) {
      // Only handle Phase 3 treatment - Phase 2 is handled by components
      if (currentPhase == 3 && bacteriaRemaining > 0) {
        for (var tile in waterTiles) {
          if (tile.containsPoint(event.localPosition) && tile.isPolluted) {
            treatTile(tile);
            break;
          }
        }
      }
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