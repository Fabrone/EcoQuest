import 'dart:async';
import 'dart:collection';
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
  Function()? onFurrowsComplete; // Callback for furrow completion
  // Add callback for river tap
  Function(Vector2)? onRiverTapped;
  
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
  int farmsIrrigated = 0;
  int cropsMature = 0;
  int totalFarms = 3;
  int wildlifeSpawned = 0;
  bool waterRedirected = false; // Tracks if pipeline fully connects river to all farms
  List<Timer> growthTimers = []; // For crop growth stages

  TractorComponent? tractor;
  List<FurrowPath> completedFurrows = [];
  FurrowPath? currentFurrowBeingDrawn;
  bool isDrawingFurrow = false;
  Vector2? lastFurrowPoint;
  EnhancedRiverComponent? river;
  bool waterFlowing = false;
  List<WaterFlowAnimation> activeWaterFlows = [];

  List<Vector2> currentDrawnPath = [];
  bool isDrawingPipe = false;
  String? selectedIrrigationMethod;
  
  // Carry-forward resources
  int purifiedWaterAmount = 0;
  int bacteriaMultiplied = 0;
  int recycledMaterials = 0;

  // New for sorting
  List<WasteItemComponent> collectedWaste = [];
  List<BinComponent> bins = [];
  WasteItemComponent? currentDragged;

  // New for agriculture
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
    
    // Handle phase-specific resizing
    if (currentPhase == 2 && bins.isNotEmpty) {
      _repositionSortingComponents();
    } else if (currentPhase == 4) {
      _repositionAgricultureComponents(); // NEW: Handle Phase 4 resize
    }
  }

  void _repositionSortingComponents() {
    debugPrint('Repositioning sorting components for new size: ${size.x} x ${size.y}');
    
    // Recalculate bin positions with balanced distribution
    final binTypes = ['plastic', 'metal', 'hazardous', 'organic'];
    final horizontalMargin = size.x * 0.05; // 5% margin (consistent with setup)
    final availableWidth = size.x - (2 * horizontalMargin);
    final binSpacing = availableWidth * 0.03; // 3% spacing between bins
    final totalSpacing = binSpacing * (binTypes.length - 1);
    final binWidth = (availableWidth - totalSpacing) / binTypes.length;
    final binHeight = size.y * 0.22;
    final binY = size.y * 0.78;
    
    for (int i = 0; i < bins.length; i++) {
      final binCenterX = horizontalMargin + (binWidth / 2) + (i * (binWidth + binSpacing));
      bins[i].position = Vector2(binCenterX, binY);
      bins[i].size = Vector2(binWidth, binHeight);
      bins[i].anchor = Anchor.center; // Ensure anchor is set
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
    
    // FIXED BIN SETUP with balanced distribution
    bins.clear();
    final binTypes = ['plastic', 'metal', 'hazardous', 'organic'];
    
    // Calculate responsive bin dimensions with balanced spacing
    final horizontalMargin = size.x * 0.05; // 5% margin on each side (reduced from 8%)
    final availableWidth = size.x - (2 * horizontalMargin);
    final binSpacing = availableWidth * 0.03; // 3% spacing between bins
    final totalSpacing = binSpacing * (binTypes.length - 1);
    final binWidth = (availableWidth - totalSpacing) / binTypes.length;
    final binHeight = size.y * 0.22; // 22% of canvas height
    
    // Position bins with balanced distribution
    final binY = size.y * 0.78; // 78% down from top
    
    debugPrint('Bin layout: width=$binWidth, height=$binHeight, spacing=$binSpacing, margin=$horizontalMargin');
    
    for (int i = 0; i < binTypes.length; i++) {
      // Calculate center X position for each bin with balanced spacing
      // Start from left margin + half bin width, then add full bin width + spacing for each subsequent bin
      final binCenterX = horizontalMargin + (binWidth / 2) + (i * (binWidth + binSpacing));
      
      final bin = BinComponent(
        binType: binTypes[i],
        position: Vector2(binCenterX, binY),
        size: Vector2(binWidth, binHeight),
      );
      bin.anchor = Anchor.center; // Explicitly set anchor
      bins.add(bin);
      await add(bin);
      
      debugPrint('Bin ${i + 1} (${binTypes[i]}): centerX=$binCenterX, y=$binY, left=${binCenterX - binWidth/2}, right=${binCenterX + binWidth/2}');
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
    if (currentPhase == 3 && bacteriaRemaining > 0) {
      // Phase 3 treatment
      for (var tile in waterTiles) {
        if (tile.containsPoint(event.localPosition) && tile.isPolluted) {
          treatTile(tile);
          break;
        }
      }
    } else if (currentPhase == 4) {
      // Phase 4 - Handle tap for irrigation method selection
      // This will be handled by the UI dialog
    }
  }
  
  void startPhase3Treatment() {
    currentPhase = 3;
    _setupTreatmentPhase();
  }

  void _setupTreatmentPhase() async {
    // Clear previous phase components
    removeAll(children.where((c) => 
      c is BinComponent || 
      c is SortingFacilityBackground ||
      c is TreatmentFacilityBackground ||
      c is TreatmentAmbientParticle
    ));
    
    await Future.delayed(const Duration(milliseconds: 100));
    
    // Create SINGLE unified water tile
    waterTiles.clear();
    
    final startY = size.y * 0.28;
    final availableHeight = size.y - startY - 20;
    
    final unifiedTile = WaterTileComponent(
      row: 0,
      col: 0,
      position: Vector2(size.x * 0.05, startY),
      size: Vector2(size.x * 0.9, availableHeight),
      isPolluted: true,
    );
    
    unifiedTile.pollutionDensity = 1.0;
    unifiedTile.cleanProgress = 0.0;
    
    waterTiles.add(unifiedTile);
    add(unifiedTile);
    
    resumeEngine();
  }

  // Update treatTile method for tap-based treatment with mixing
  void treatTile(WaterTileComponent tile) {
    if (bacteriaRemaining <= 0 || tile.isTreating) {
      return;
    }
    
    bacteriaRemaining--;
    
    // Calculate clean progress (12 bacteria = 100% clean)
    final progressPerBacteria = 1.0 / 12.0;
    tile.cleanProgress = ((12 - bacteriaRemaining) * progressPerBacteria).clamp(0.0, 1.0);
    
    // Start treatment animation at tap point
    tile.startTreatmentAtPoint(tile.lastTapPosition ?? Vector2(tile.size.x / 2, tile.size.y / 2));
    
    // Visual feedback - camera pulse
    camera.viewfinder.add(
      SequenceEffect([
        ScaleEffect.by(
          Vector2.all(1.03),
          EffectController(duration: 0.15),
        ),
        ScaleEffect.by(
          Vector2.all(1 / 1.03),
          EffectController(duration: 0.15),
        ),
      ]),
    );

    // Update pollution meter (inversely related to clean progress)
    pollutionMeter = ((1.0 - tile.cleanProgress) * 100).clamp(0, 100);
    
    // Calculate zones treated (for UI)
    zonesTreated = (12 - bacteriaRemaining);
    
    onTreatmentUpdate?.call(zonesTreated, pollutionMeter);
    
    // Check if fully cleaned or bacteria depleted
    if (tile.cleanProgress >= 1.0 || bacteriaRemaining == 0) {
      Future.delayed(const Duration(milliseconds: 2000), () {
        _completePhase3();
      });
    }
  }
      
  void _completePhase3() {
    final cleanedPercentage = waterTiles.isNotEmpty ? waterTiles.first.cleanProgress : 0.0;
    
    // Calculate purified water based on cleanliness (max 600L at 100% clean)
    purifiedWaterAmount = (cleanedPercentage * 600).round();
    
    // Bacteria multiply based on efficiency
    final efficiencyBonus = cleanedPercentage >= 0.9 ? 3 : cleanedPercentage >= 0.7 ? 2 : 1;
    bacteriaMultiplied = bacteriaRemaining + (zonesTreated * efficiencyBonus);
    
    // Celebration effect
    _playCompletionAnimation();
    
    Future.delayed(const Duration(milliseconds: 1500), () {
      onPhaseComplete?.call(3);
      pauseEngine();
    });
  }

  // Update _playCompletionAnimation for unified tile
  void _playCompletionAnimation() {
    if (waterTiles.isEmpty) return;
    
    final tile = waterTiles.first;
    
    // Pulsing glow effect
    tile.add(
      SequenceEffect([
        ScaleEffect.to(
          Vector2.all(1.05),
          EffectController(duration: 0.3),
        ),
        ScaleEffect.to(
          Vector2.all(1.0),
          EffectController(duration: 0.3),
        ),
      ], repeatCount: 3),
    );
    
    // Sparkle effect across the entire river
    for (int i = 0; i < 20; i++) {
      Future.delayed(Duration(milliseconds: i * 100), () {
        tile.triggerSparkleEffect();
      });
    }
  }

  void startPhase4Agriculture() {
    currentPhase = 4;
    _setupAgriculturePhase();
  }

  void _setupAgriculturePhase() async {
    // Clear previous components
    removeAll(children.whereType<WaterTileComponent>());
    removeAll(children.whereType<EnhancedRiverComponent>());
    await Future.delayed(const Duration(milliseconds: 100));
    
    // Wait for proper canvas sizing
    int attempts = 0;
    while ((size.x == 0 || size.y == 0 || size.x < 100 || size.y < 100) && attempts < 20) {
      debugPrint('Canvas not ready (attempt ${attempts + 1}): ${size.x} x ${size.y}');
      await Future.delayed(const Duration(milliseconds: 100));
      attempts++;
    }
    
    if (size.x == 0 || size.y == 0) {
      debugPrint('ERROR: Canvas size invalid for Phase 4!');
      return;
    }
    
    // Add unified background
    add(UnifiedAgricultureBackground(size: size));
    
    // Create adaptive river layout
    _createAdaptiveRiverLayout();
    
    // Initialize tractor (hidden until first drag)
    final isLandscape = size.x > size.y;
    final farmCenter = isLandscape 
        ? Vector2(size.x * 0.7, size.y * 0.5)
        : Vector2(size.x * 0.5, size.y * 0.7);
    
    tractor = TractorComponent(
      position: farmCenter,
      size: Vector2(60, 60),
    );
    tractor!.visible = false; // Hidden initially
    add(tractor!);

    add(FurrowRenderComponent());
    
    debugPrint('✅ Phase 4 setup complete - Ready for furrow drawing');
    
    resumeEngine();
  }

  void _createAdaptiveRiverLayout() {
    final isLandscape = size.x > size.y;
    final isDesktop = size.x >= 1024; // Desktop/Laptop threshold
    final isTablet = size.x >= 600 && size.x < 1024;
    // final isMobile = size.x < 600;
    
    EnhancedRiverComponent river;
    
    if (isLandscape || isDesktop || isTablet) {
      // DESKTOP/TABLET LANDSCAPE: Vertical river on left (30% width)
      final riverWidth = size.x * 0.30;
      final riverHeight = size.y * 0.95;
      final riverX = 0.0;
      final riverY = size.y * 0.025;
      
      river = EnhancedRiverComponent(
        size: Vector2(riverWidth, riverHeight),
        position: Vector2(riverX, riverY),
        flowDirection: RiverFlowDirection.topToBottom,
        orientation: RiverOrientation.vertical,
      );
      
      debugPrint('🏞️ Created VERTICAL river: ${riverWidth}w x ${riverHeight}h at ($riverX, $riverY)');
    } else {
      // MOBILE PORTRAIT: Horizontal river on top (30% height)
      final riverWidth = size.x * 0.95;
      final riverHeight = size.y * 0.30;
      final riverX = size.x * 0.025;
      final riverY = 0.0;
      
      river = EnhancedRiverComponent(
        size: Vector2(riverWidth, riverHeight),
        position: Vector2(riverX, riverY),
        flowDirection: RiverFlowDirection.leftToRight,
        orientation: RiverOrientation.horizontal,
      );
      
      debugPrint('🏞️ Created HORIZONTAL river: ${riverWidth}w x ${riverHeight}h at ($riverX, $riverY)');
    }
    
    add(river);
    
  }

  void _repositionAgricultureComponents() {
    final currentRiver = children.whereType<EnhancedRiverComponent>().firstOrNull;
    if (currentRiver == null) {
      debugPrint('⚠️ No river found for repositioning');
      return;
    }
    
    river = currentRiver; // Update reference
    
    // Update river size and position based on new screen dimensions
    final isLandscape = size.x > size.y;
    
    if (isLandscape) {
      final riverWidth = size.x * 0.30;
      river!.size = Vector2(riverWidth, size.y * 0.95);
      river!.position = Vector2(0, size.y * 0.025);
      river!.orientation = RiverOrientation.vertical;
      river!.flowDirection = RiverFlowDirection.topToBottom;
    } else {
      final riverHeight = size.y * 0.30;
      river!.size = Vector2(size.x * 0.95, riverHeight);
      river!.position = Vector2(size.x * 0.025, 0);
      river!.orientation = RiverOrientation.horizontal;
      river!.flowDirection = RiverFlowDirection.leftToRight;
    }
    
    river!.generateWindingRiverPath();
    
    if (tractor != null) {
      final isLandscape = size.x > size.y;
      tractor!.position = isLandscape 
          ? Vector2(size.x * 0.7, size.y * 0.5)
          : Vector2(size.x * 0.5, size.y * 0.7);
    }
    
    debugPrint('♻️ Repositioned agriculture components for new screen size: ${size.x} x ${size.y}');
  }

  void onFarmTapDown(Vector2 position) {
    if (!isDrawingFurrow && !_isPositionInRiver(position)) {
      isDrawingFurrow = true;
      lastFurrowPoint = position.clone();
      
      // Show and position tractor at tap point
      if (tractor != null) {
        tractor!.position = position.clone();
        tractor!.visible = true;
      }
      
      // Start new furrow path
      currentFurrowBeingDrawn = FurrowPath(
        points: [position.clone()],
        isConnectedToRiver: false,
      );
      
      debugPrint('🚜 Started drawing furrow at $position');
    }
  }

  void onFarmDragUpdate(Vector2 newPosition, Vector2 delta) {
    if (!isDrawingFurrow || currentFurrowBeingDrawn == null) return;
    
    // Check if position is in farm area (not in river)
    if (_isPositionInRiver(newPosition)) return;
    
    // Only add point if moved enough distance (smooth the path)
    if (lastFurrowPoint != null) {
      final distance = (newPosition - lastFurrowPoint!).length;
      if (distance >= 15) { // Minimum 15 pixels between points
        currentFurrowBeingDrawn!.points.add(newPosition.clone());
        lastFurrowPoint = newPosition.clone();
        
        // Move tractor to follow drag
        if (tractor != null) {
          tractor!.position = newPosition.clone();
          
          // Calculate rotation based on drag direction
          if (delta.length > 0) {
            tractor!.updateRotation(delta);
          }
        }
      }
    }
  }

  void onFarmDragEnd(Vector2 endPosition) {
    if (!isDrawingFurrow || currentFurrowBeingDrawn == null) return;
    
    isDrawingFurrow = false;
    
    // Add final point
    currentFurrowBeingDrawn!.points.add(endPosition.clone());
    
    // Check if furrow connects to river
    final connectsToRiver = _checkFurrowRiverConnection(currentFurrowBeingDrawn!);
    currentFurrowBeingDrawn!.isConnectedToRiver = connectsToRiver;
    
    // Save completed furrow
    completedFurrows.add(currentFurrowBeingDrawn!);
    
    debugPrint('✅ Furrow completed: ${currentFurrowBeingDrawn!.points.length} points, connected to river: $connectsToRiver');
    
    // If connected to river, trigger water flow
    if (connectsToRiver) {
      _startWaterFlowAnimation(currentFurrowBeingDrawn!);
      onFurrowsComplete?.call(); // Trigger UI prompt
    }
    
    currentFurrowBeingDrawn = null;
    
    // Hide tractor with delay
    Future.delayed(const Duration(milliseconds: 500), () {
      if (tractor != null) {
        tractor!.visible = false;
      }
    });
  }

  bool _isPositionInRiver(Vector2 position) {
    if (river == null) return false;
    
    // Convert position to river's local coordinates
    final riverLocalPos = position - river!.position;
    return river!.containsPoint(riverLocalPos);
  }

  bool _checkFurrowRiverConnection(FurrowPath furrow) {
    if (river == null || furrow.points.isEmpty) return false;
    
    // Check if any point (especially start/end) is close to river
    final checkPoints = [
      furrow.points.first,
      furrow.points.last,
    ];
    
    for (final point in checkPoints) {
      if (_isPositionInRiver(point)) {
        furrow.riverConnectionPoint = point.clone();
        return true;
      }
      
      // Also check if very close to river (within 30 pixels)
      final riverLocalPos = point - river!.position;
      final closestRiverPoint = river!.getRiverClosestPoint(riverLocalPos);
      
      if (closestRiverPoint != null) {
        final distance = (closestRiverPoint - riverLocalPos).length;
        if (distance <= 30) {
          furrow.riverConnectionPoint = river!.position + closestRiverPoint;
          return true;
        }
      }
    }
    
    return false;
  }

  void _startWaterFlowAnimation(FurrowPath furrow) {
    if (!furrow.isConnectedToRiver || furrow.riverConnectionPoint == null) return;
    
    waterFlowing = true;
    
    final waterFlow = WaterFlowAnimation(
      furrowPath: furrow,
      startPoint: furrow.riverConnectionPoint!,
    );
    
    activeWaterFlows.add(waterFlow);
    
    debugPrint('💧 Started water flow animation through furrow');
  }

  @override
  void update(double dt) {
    super.update(dt);
    
    // Update water flow animations
    for (var waterFlow in activeWaterFlows) {
      waterFlow.update(dt);
    }
    
    // Remove completed water flows
    activeWaterFlows.removeWhere((flow) => flow.isComplete);
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
    
    if (waterEfficiency >= 85) score += 100;
    
    return score;
  }
}