import 'dart:async';
import 'dart:collection';
import 'dart:math';
import 'package:ecoquest/game/water_components.dart';
import 'package:ecoquest/game/rowing_components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flame/components.dart';
import 'package:google_fonts/google_fonts.dart';

// ── Urban pipe-network tile ────────────────────────────────────────────────
class UrbanTile {
  /// 'reservoir'|'house'|'straight'|'corner'|'t_junction'|'obstacle'|'empty'
  String type;
  /// 0..3  (multiples of 90°)
  int rotation;
  bool isConnected = false;
  bool isLeaking   = false;
  double pressure  = 0.0;

  UrbanTile({required this.type, this.rotation = 0, this.isLeaking = false});

  // ── Directional open-ends ──────────────────────────────────────────────
  // Directions:  0 = up  |  1 = right  |  2 = down  |  3 = left
  // BFS will only flow A→B if A.openEnds contains the outgoing direction
  // AND B.openEnds contains the opposite (incoming) direction.
  List<int> get openEnds {
    switch (type) {
      case 'reservoir':
      case 'house':
        return [0, 1, 2, 3]; // accept flow from any direction
      case 'straight':
        // rotation 0/2 = horizontal (left+right), rotation 1/3 = vertical (up+down)
        return rotation % 2 == 0 ? [1, 3] : [0, 2];
      case 'corner':
        // 0=right+down  1=down+left  2=left+up  3=up+right
        const e = [[1,2],[2,3],[3,0],[0,1]];
        return e[rotation % 4];
      case 't_junction':
        // 0=right+down+left  1=up+down+left  2=up+right+left  3=up+right+down
        const e = [[1,2,3],[0,2,3],[0,1,3],[0,1,2]];
        return e[rotation % 4];
      default:
        return []; // obstacle, empty
    }
  }
}

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
  // ── Phase 1 — Rowing Collection (NEW FIELDS) ─────────────────────────────
  RowingBoatComponent? rowingBoat; // replaces SpeedboatComponent? speedboat
  List<FloatingWasteComponent> floatingWaste = [];
  List<CrocodileComponent> crocodiles = [];
  List<WhirlpoolComponent> whirlpools = [];
  List<LogJamComponent> logJams = [];
  int totalSpawnedWaste = 0; // exact count of spawned items this session

  // Timer
  double collectionTimeRemaining = 180.0; // 3-minute session
  static const double collectionTimerMax = 180.0;
  bool timerRunning = false;
  bool timeUp = false;
  bool playerHasStarted = false; // true once player first moves/casts net

  // Score / challenge tracking
  int sessionScore = 0;
  int obstaclesAvoided = 0;
  int obstaclesHit = 0;
  double boatHealth = 150.0; // increased — gives player more room to survive multi-hazard encounters
  int crocodileAttackCount = 0; // tracks croc hits; boat sinks at exactly 9 attacks

  // Callbacks (add alongside existing callbacks)
  Function(String obstacle, double damage)? _onObstacleHitExternal;
  Function(double timeLeft)? onTimerTick;
  Function(int score, double health, int collected)? onCollectionUpdate;
  /// Fired when the boat is sunk after 9 crocodile attacks. Screen should show retry.
  Function()? onPhase1Failed;

  /// Fired when the 3-minute timer lapses before all waste is collected.
  /// Player keeps what they collected and proceeds to Phase 2 — NOT a retry.
  Function(int collected, int total)? onPhase1TimeUp;

  /// Fired when Phase 1 ends — either all waste collected OR timer lapsed.
  /// Game pauses here. Screen shows a results panel and the player must tap
  /// "PROCEED TO SORTING" which calls [proceedFromPhase1].
  Function()? onPhase1Complete;

  /// External obstacle-hit callback. Internally always routes through
  /// [_handleObstacleHit] which updates health, HUD, and flashes danger text.
  set onObstacleHit(Function(String, double)? cb) {
    _onObstacleHitExternal = cb;
  }

  /// Called by [RowingBoatComponent] when net is deployed or retracted.
  /// Passes (isDeployed, cooldownFraction 0..1).
  Function(bool isDeployed, double cooldownFraction)? onNetStateChanged;

  // Phase 2 - Sorting
  int sortedCorrectly = 0;
  int sortedIncorrectly = 0;
  WasteItemComponent? selectedWaste; // For tap-to-select interaction
  bool sortingTimerStarted = false;
  double sortingTimeLeft = 90.0;
  bool sortingTimerRunning = false;
  Function(double timeLeft)? onSortingTick;
  Function(int correct, int wrong, int unsorted)? onSortingTimeUp;
  /// Fired when the player finishes sorting every item before the timer runs out.
  /// Screen shows a results panel — user must tap "Proceed to Treatment" via [proceedFromSorting].
  Function(int correct, int wrong, double timeRemaining)? onSortingComplete;

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
  bool waterRedirected =
      false; // Tracks if pipeline fully connects river to all farms
  List<Timer> growthTimers = []; // For crop growth stages

  // Phase 4 — new crop & irrigation system
  String? selectedCrop;       // 'vegetables' | 'maize' | 'rice'
  String? irrigationMethod;   // 'furrow' | 'pipe'
  double farmGreenProgress = 0.0; // 0.0 brown → 1.0 full green
  int connectedChannels = 0;  // furrows or pipes connected to river
  bool phase4Complete = false;
  double phase4Timer = 0.0;   // countdown after crops grow
  static const double phase4Duration = 90.0; // seconds to irrigate
  double irrigationTimeLeft = phase4Duration;
  bool irrigationTimerRunning = false;
  // Harvest result
  String harvestResult = '';  // 'bountiful' | 'average' | 'poor'
  String educationalTip = '';
  // Callbacks
  Function(double greenProgress, int connected)? onFarmUpdate;
  Function(String result, String tip)? onHarvestComplete;
  Function(double timeLeft)? onIrrigationTick;
  // Pipe network (parallel to furrow network)
  List<FurrowPath> pipePaths = [];
  Map<String, FurrowPath> pipeNetwork = {};
  FurrowPath? currentPipeBeingDrawn;
  bool isDrawingPipe2 = false; // renamed to avoid conflict with existing isDrawingPipe

  TractorComponent? tractor;
  List<FurrowPath> completedFurrows = [];
  FurrowPath? currentFurrowBeingDrawn;
  bool isDrawingFurrow = false;
  Vector2? lastFurrowPoint;
  EnhancedRiverComponent? river;
  bool waterFlowing = false;
  List<dynamic> activeWaterFlows = [];
  Map<String, FurrowPath> furrowNetwork = {}; // Track all furrows by ID
  String? activeFurrowId; // Currently drawing furrow
  bool isPausedDrawing = false;

  List<Vector2> currentDrawnPath = [];
  bool isDrawingPipe = false;
  String? selectedIrrigationMethod;

  // ── Application selection (chosen after Phase 3) ──────────────────────
  // 'agriculture' | 'urban' | 'industrial' | 'environmental'
  String? selectedApplication;

  // Urban water supply phase state
  int urbanHouseholdsConnected = 0;
  int urbanTotalHouseholds = 5;
  int urbanPipesLaid = 0;
  double urbanProgress = 0.0;
  bool urbanPhaseComplete = false;
  String urbanResult = ''; // 'excellent'|'good'|'partial'|'poor'|'failed'
  Function(int households, double progress)? onUrbanUpdate;
  Function(String result)? onUrbanComplete;
  Function(double timeLeft)? onUrbanTick;
  double urbanTimeLeft = 90.0;
  bool urbanTimerRunning = false;   // false until player's first tap
  bool urbanTimerStarted = false;   // latched true on first tap

  // Challenge tracking
  int urbanTotalBursts = 0;         // cumulative burst events spawned
  int urbanBurstsFixed = 0;         // bursts player patched
  int urbanActiveBursts = 0;        // bursts currently unresolved
  double urbanAveragePressure = 0.0;// avg pressure across connected houses
  double urbanTimeTaken = 0.0;      // elapsed seconds when phase ends
  int urbanSupplyScore = 0;         // 0-100 composite quality score

  // Callbacks
  Function()? onUrbanTimerStart;    // fired the moment the timer begins

  // Urban pipe-puzzle grid
  List<List<UrbanTile>> urbanGrid = [];
  final Random _rng = Random();
  double _urbanBurstAccumulator = 0.0; // seconds since last burst check

  // Industrial phase state
  int industrialSystemsUpgraded = 0;
  int industrialTotalSystems = 4;
  double industrialEfficiency = 0.0;
  bool industrialPhaseComplete = false;
  String industrialResult = '';
  Function(int systems, double efficiency)? onIndustrialUpdate;
  Function(String result)? onIndustrialComplete;
  Function(double timeLeft)? onIndustrialTick;
  double industrialTimeLeft = 90.0;
  bool industrialTimerRunning = false;

  // Environmental restoration phase state
  int habitatsRestored = 0;
  int totalHabitats = 5;
  double ecosystemHealth = 0.0;
  bool environmentalPhaseComplete = false;
  String environmentalResult = '';
  Function(int habitats, double health)? onEnvironmentalUpdate;
  Function(String result)? onEnvironmentalComplete;
  Function(double timeLeft)? onEnvironmentalTick;
  double environmentalTimeLeft = 90.0;
  bool environmentalTimerRunning = false;

  // Carry-forward resources
  int purifiedWaterAmount = 0;
  int bacteriaMultiplied = 0;
  int recycledMaterials = 0;
  // Phase 4 carry-forward
  int harvestYield = 0;     // kg of crop produced
  int fishCount = 0;        // fish if water sufficiently clean
  // Sorting breakdown for recycling
  int recycledPlastic = 0;
  int recycledMetal = 0;
  int recycledOrganic = 0;
  int recycledHazardous = 0;

  // New for sorting
  List<WasteItemComponent> collectedWaste = [];
  List<BinComponent> bins = [];
  WasteItemComponent? currentDragged;

  // New for agriculture
  bool pipelineConnected = false;

  WaterPollutionGame({required this.bacteriaCultures})
    : bacteriaRemaining = bacteriaCultures;

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
    if (currentPhase == 1) {
      // Route to rowing boat (new system)
      if (rowingBoat != null) {
        final handled = rowingBoat!.onKeyEvent(event, keysPressed);
        return handled ? KeyEventResult.handled : KeyEventResult.ignored;
      }
      // Fallback: legacy speedboat
      if (speedboat != null) {
        final handled = speedboat!.onKeyEvent(event, keysPressed);
        return handled ? KeyEventResult.handled : KeyEventResult.ignored;
      }
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
    debugPrint(
      'Repositioning sorting components for new size: ${size.x} x ${size.y}',
    );

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
      final binCenterX =
          horizontalMargin + (binWidth / 2) + (i * (binWidth + binSpacing));
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
    _setupRowingCollectionPhase();
  }

  void _setupRowingCollectionPhase() async {
    // Reset state
    floatingWaste.clear();
    crocodiles.clear();
    whirlpools.clear();
    logJams.clear();
    wasteItems.clear();
    collectedWaste.clear();
    wasteCollectedCount = 0;
    totalSpawnedWaste = 0;
    sessionScore = 0;
    obstaclesAvoided = 0;
    obstaclesHit = 0;
    boatHealth = 150.0;
    crocodileAttackCount = 0;
    collectionTimeRemaining = collectionTimerMax;
    timerRunning = false;
    timeUp = false;
    playerHasStarted = false;

    // Remove existing children
    final toRemove = children.toList();
    for (final c in toRemove) {
      c.removeFromParent();
    }
    await Future.delayed(const Duration(milliseconds: 100));

    // Wait for canvas
    int attempts = 0;
    while ((size.x == 0 || size.y == 0) && attempts < 20) {
      await Future.delayed(const Duration(milliseconds: 100));
      attempts++;
    }

    // ── River background ──────────────────────────────────────────────────
    await add(EnhancedRiverBackground(gameSize: size));

    // ── Rapid current zones (left and right channels) ─────────────────────
    await _spawnCurrentZones();

    // ── Wake renderer (behind boat) ───────────────────────────────────────
    await add(BoatWakeRenderer());

    // ── Rowing boat (starts bottom-centre) ────────────────────────────────
    rowingBoat = RowingBoatComponent(
      position: Vector2(size.x / 2, size.y - 140),
      size: Vector2(52, 78),
    );
    await add(rowingBoat!);

    // ── Obstacles: crocodiles ─────────────────────────────────────────────
    await _spawnCrocodiles();

    // ── Obstacles: whirlpools ─────────────────────────────────────────────
    await _spawnWhirlpools();

    // ── Passive river debris (logs — collectible organic waste, NOT obstacles) ─
    await _spawnRiverLogs();

    // ── Floating waste ────────────────────────────────────────────────────
    await _spawnAllFloatingWaste();

    // ── River ambient particles ───────────────────────────────────────────
    _spawnRiverParticles();

    // Timer starts only on first player input (see notifyPlayerStarted())
    timerRunning = false;
    resumeEngine();
  }

  Future<void> _spawnCurrentZones() async {
    // Two diagonal current bands across the river
    final zones = [
      RapidsCurrentZone(
        position: Vector2(size.x * 0.25, size.y * 0.35),
        size: Vector2(size.x * 0.22, size.y * 0.20),
        currentForce: Vector2(40, 80),
      ),
      RapidsCurrentZone(
        position: Vector2(size.x * 0.72, size.y * 0.6),
        size: Vector2(size.x * 0.22, size.y * 0.20),
        currentForce: Vector2(-35, 70),
      ),
    ];
    for (final z in zones) {
      await add(z);
    }
  }

  Future<void> _spawnCrocodiles() async {
    final rng = Random();
    // 3 crocodiles at different river sections
    final spawnY = [size.y * 0.2, size.y * 0.45, size.y * 0.68];
    for (int i = 0; i < 3; i++) {
      final croc = CrocodileComponent(
        position: Vector2(
          size.x * 0.15 + rng.nextDouble() * size.x * 0.7,
          spawnY[i],
        ),
        size: Vector2(70, 52),
      );
      crocodiles.add(croc);
      await add(croc);
    }
  }

  Future<void> _spawnWhirlpools() async {
    final rng = Random();
    for (int i = 0; i < 2; i++) {
      final wp = WhirlpoolComponent(
        position: Vector2(
          size.x * 0.2 + rng.nextDouble() * size.x * 0.6,
          size.y * 0.25 + rng.nextDouble() * size.y * 0.5,
        ),
        radius: 50 + rng.nextDouble() * 30,
      );
      whirlpools.add(wp);
      await add(wp);
    }
  }

  /// Spawns a small number of passive log clusters that drift downstream.
  /// These are collectible organic waste items, NOT collision obstacles.
  Future<void> _spawnRiverLogs() async {
    final rng = Random();
    // Only 3 log clusters — scenic debris, not a gauntlet
    for (int i = 0; i < 3; i++) {
      final lj = LogJamComponent(
        position: Vector2(
          size.x * 0.12 + rng.nextDouble() * size.x * 0.76,
          size.y * 0.1 + rng.nextDouble() * size.y * 0.8,
        ),
        size: Vector2(80, 45),
        logCount: 2 + rng.nextInt(2), // 2-3 logs per cluster — lighter visual
      );
      logJams.add(lj);
      await add(lj);
    }
  }

  Future<void> _spawnAllFloatingWaste() async {
    final rng = Random();
    final types = WasteType.values;
    // 50 total waste items in varied clusters
    const clusters = 10;

    for (int cluster = 0; cluster < clusters; cluster++) {
      final clusterX = size.x * 0.1 + rng.nextDouble() * size.x * 0.8;
      final clusterY = 60 + rng.nextDouble() * (size.y - 120);

      final itemsInCluster = 4 + rng.nextInt(3);
      for (int i = 0; i < itemsInCluster; i++) {
        final wt = types[rng.nextInt(types.length)];
        final fx = (clusterX + (rng.nextDouble() - 0.5) * 100)
            .clamp(30, size.x - 30)
            .toDouble();
        final fy = (clusterY + (rng.nextDouble() - 0.5) * 80)
            .clamp(30, size.y - 80)
            .toDouble();

        final waste = FloatingWasteComponent(
          wasteType: wt,
          position: Vector2(fx, fy),
        );
        floatingWaste.add(waste);
        totalSpawnedWaste++;
        await add(waste);
      }
    }
  }

  /// Called by [RowingBoatComponent] the first time the player moves or casts.
  /// Starts the countdown timer.
  void notifyPlayerStarted() {
    if (playerHasStarted || currentPhase != 1) return;
    playerHasStarted = true;
    timerRunning = true;
    onTimerTick?.call(collectionTimeRemaining);
  }

  void _spawnRiverParticles() {
    for (int i = 0; i < 25; i++) {
      add(RiverParticleComponent(
        position: Vector2(
          Random().nextDouble() * size.x,
          Random().nextDouble() * size.y,
        ),
      ));
    }
  }

  void collectFloatingWaste(FloatingWasteComponent waste) {
    if (waste.collected) return;
    waste.collected = true;
    floatingWaste.remove(waste);

    // Convert to WasteItemComponent for the sorting phase
    collectedWaste.add(WasteItemComponent(
      type: waste.wasteType.gameKey,
      position: Vector2.zero(),
      size: Vector2.all(50),
    ));
    wasteCollectedCount++;
    sessionScore += waste.wasteType.points;

    // Start timer on first collection if player hasn't moved yet
    notifyPlayerStarted();

    // Splash effect
    final netPos = rowingBoat?.netWorldCenter ?? waste.position.clone();
    add(CollectSplashEffect(
      position: netPos,
      color: waste.wasteType.color,
      points: waste.wasteType.points,
    ));

    waste.removeFromParent();

    onWasteCollected?.call(wasteCollectedCount);
    onCollectionUpdate?.call(sessionScore, boatHealth, wasteCollectedCount);

    // Completion: player must collect EVERY spawned waste item (100%)
    final target = totalSpawnedWaste > 0 ? totalSpawnedWaste : totalWasteToCollect;
    if (wasteCollectedCount >= target) {
      _completePhase1Enhanced();
    }
  }

  /// Called by [LogJamComponent] when the player's net sweeps over a log cluster.
  /// Logs count as organic waste — they add to the collection score and total.
  void collectLogAsWaste(LogJamComponent log) {
    logJams.remove(log);
    // Treat each log cluster as one organic waste item
    collectedWaste.add(WasteItemComponent(
      type: 'wood',
      position: Vector2.zero(),
      size: Vector2.all(50),
    ));
    wasteCollectedCount++;
    sessionScore += WasteType.organicWaste.points;
    notifyPlayerStarted();

    final netPos = rowingBoat?.netWorldCenter ?? log.position.clone();
    add(CollectSplashEffect(
      position: netPos,
      color: WasteType.organicWaste.color,
      points: WasteType.organicWaste.points,
    ));

    log.removeFromParent();
    onWasteCollected?.call(wasteCollectedCount);
    onCollectionUpdate?.call(sessionScore, boatHealth, wasteCollectedCount);

    final target = totalSpawnedWaste > 0 ? totalSpawnedWaste : totalWasteToCollect;
    if (wasteCollectedCount >= target) {
      _completePhase1Enhanced();
    }
  }

  void _handleObstacleHit(String type, double damage) {
    if (!playerHasStarted) return;

    // ── Crocodile: normalise damage, count hits, force sink at 9 ──────────
    if (type == 'crocodile') {
      crocodileAttackCount++;
      const double crocDamagePerHit = 150.0 / 9; // ≈17 HP — 9 equal steps
      damage = crocDamagePerHit;
      if (crocodileAttackCount >= 9) {
        boatHealth = 0.0; // Force immediate sink on 9th attack
      } else {
        boatHealth = (boatHealth - crocDamagePerHit).clamp(0.0, 150.0);
      }
    } else {
      boatHealth = (boatHealth - damage).clamp(0.0, 150.0);
    }

    obstaclesHit++;

    final dangerMsg = {
      'crocodile': '🐊 Croc Attack $crocodileAttackCount/9! −${damage.round()} HP',
      'whirlpool': '🌀 Caught in Whirlpool!',
      'logjam':    '🪵 Log Jam! −${damage.round()} HP',
    }[type] ?? '⚠ Obstacle Hit!';

    if (rowingBoat != null) {
      add(DangerFlashComponent(
        position: rowingBoat!.position.clone(),
        message: dangerMsg,
      ));
    }

    _onObstacleHitExternal?.call(type, damage);
    onCollectionUpdate?.call(sessionScore, boatHealth, wasteCollectedCount);

    if (boatHealth <= 0) {
      // Boat sunk after 9 croc attacks — must retry, cannot proceed to sorting
      timerRunning = false;
      pauseEngine();
      onPhase1Failed?.call();
    }
  }

  /// Called by obstacle components (crocodile, whirlpool, logjam).
  void reportObstacleHit(String type, double damage) =>
      _handleObstacleHit(type, damage);

  void _completePhase1Enhanced() {
    timerRunning = false;

    // Time bonus (only when completed before timer ran out)
    if (!timeUp && collectionTimeRemaining > 0) {
      sessionScore += (collectionTimeRemaining * 0.5).round();
    }
    // Health bonus
    sessionScore += (boatHealth * 0.3).round();

    recycledMaterials = (wasteCollectedCount * 0.5).round();

    // Do NOT call onPhaseComplete here — game pauses and waits for the player
    // to read the results panel and tap "Proceed to Sorting".
    // The screen button calls proceedFromPhase1() which then fires onPhaseComplete(1).
    pauseEngine();
    onPhase1Complete?.call();
  }

  /// Called by the screen's "PROCEED TO SORTING" button after showing results.
  void proceedFromPhase1() {
    onPhaseComplete?.call(1);
  }

  /*void _setupRiverBackground() {
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
  }*/

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
    while ((size.x == 0 || size.y == 0 || size.x < 100 || size.y < 100) &&
        attempts < 20) {
      debugPrint(
        'Canvas not ready (attempt ${attempts + 1}): ${size.x} x ${size.y}',
      );
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
    final horizontalMargin =
        size.x * 0.05; // 5% margin on each side (reduced from 8%)
    final availableWidth = size.x - (2 * horizontalMargin);
    final binSpacing = availableWidth * 0.03; // 3% spacing between bins
    final totalSpacing = binSpacing * (binTypes.length - 1);
    final binWidth = (availableWidth - totalSpacing) / binTypes.length;
    final binHeight = size.y * 0.22; // 22% of canvas height

    // Position bins with balanced distribution
    final binY = size.y * 0.78; // 78% down from top

    debugPrint(
      'Bin layout: width=$binWidth, height=$binHeight, spacing=$binSpacing, margin=$horizontalMargin',
    );

    for (int i = 0; i < binTypes.length; i++) {
      // Calculate center X position for each bin with balanced spacing
      // Start from left margin + half bin width, then add full bin width + spacing for each subsequent bin
      final binCenterX =
          horizontalMargin + (binWidth / 2) + (i * (binWidth + binSpacing));

      final bin = BinComponent(
        binType: binTypes[i],
        position: Vector2(binCenterX, binY),
        size: Vector2(binWidth, binHeight),
      );
      bin.anchor = Anchor.center; // Explicitly set anchor
      bins.add(bin);
      await add(bin);

      debugPrint(
        'Bin ${i + 1} (${binTypes[i]}): centerX=$binCenterX, y=$binY, left=${binCenterX - binWidth / 2}, right=${binCenterX + binWidth / 2}',
      );
    }

    // Setup waste stack — use actual WasteType definitions from rowing_components
    if (collectedWaste.isEmpty) {
      // Fallback: generate a varied set using all WasteType values so Phase 2
      // always reflects the same item types the player could collect in Phase 1.
      final allTypes = WasteType.values;
      for (int i = 0; i < 20; i++) {
        final wt = allTypes[i % allTypes.length];
        collectedWaste.add(
          WasteItemComponent(
            type: wt.gameKey,
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
    final stackCenterX = size.x * 0.5; // Center horizontally
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
      'metal_scrap': 'metal',
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
        ScaleEffect.to(Vector2.all(1.2), EffectController(duration: 0.3)),
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

    // Start sorting timer on first sort action
    if (!sortingTimerStarted && total >= 1) {
      sortingTimerStarted = true;
      sortingTimerRunning = true;
    }

    onSortingUpdate?.call(accuracy, total);

    // Get original collected count (before any sorting)
    final totalToSort =
        sortedCorrectly + sortedIncorrectly + collectedWaste.length;

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
    // Mappings cover all 6 WasteType gameKeys defined in rowing_components.dart:
    //   plasticBottle → 'plastic_bottle'  → plastic
    //   metalCan      → 'can'             → metal
    //   plasticBag    → 'bag'             → plastic
    //   oilSlick      → 'oil_slick'       → hazardous
    //   organicWaste  → 'wood'            → organic
    //   metalScrap    → 'metal_scrap'     → metal
    final correctMappings = {
      'plastic_bottle': 'plastic',
      'bag': 'plastic',
      'can': 'metal',
      'metal_scrap': 'metal',
      'oil_slick': 'hazardous',
      'wood': 'organic',
    };

    return correctMappings[wasteType] == binType;
  }

  void _completePhase2() {
    sortingTimerRunning = false;
    // Notify screen to show results panel — user must tap "Proceed to Treatment".
    // Actual phase advance happens when screen calls proceedFromSorting().
    onSortingComplete?.call(sortedCorrectly, sortedIncorrectly, sortingTimeLeft);
  }

  /// Called by the screen's "PROCEED TO TREATMENT" button from either the
  /// time-up panel or the full-completion panel.
  /// Unsorted items remaining in [collectedWaste] are discarded here — only
  /// correctly sorted items (tracked via recycledPlastic/Metal/Organic/Hazardous)
  /// carry forward to Phase 3 and beyond.
  void proceedFromSorting() {
    // Remove every WasteItemComponent that is still attached to the game tree
    // (the unsorted stack items were add()ed as live children in _createCentralizedStack
    // and _spawnNextWasteItem — clearing the list alone does not detach them from render).
    removeAll(children.whereType<WasteItemComponent>().toList());

    // Also clear data so nothing carries forward to Phase 3+
    collectedWaste.clear();
    selectedWaste = null;
    currentDragged = null;

    onPhaseComplete?.call(2);
  }

  void submitSort(WasteItemComponent waste, BinComponent bin) {
    bool correct = isCorrectBin(waste.type, bin.binType);

    debugPrint(
      '${correct ? "✅" : "❌"} Sorting ${waste.type} into ${bin.binType} bin',
    );

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
      ScaleEffect.to(Vector2.all(0.1), EffectController(duration: 0.4)),
    );

    // Add rotation effect
    waste.add(
      RotateEffect.by(correct ? pi : -pi, EffectController(duration: 0.4)),
    );

    if (correct) {
      sortedCorrectly++;
      bin.triggerSuccessAnimation();
      // Track breakdown by bin type
      switch (bin.binType) {
        case 'plastic':   recycledPlastic++;   break;
        case 'metal':     recycledMetal++;     break;
        case 'organic':   recycledOrganic++;   break;
        case 'hazardous': recycledHazardous++; break;
      }
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
    // Clear previous phase components — explicitly includes WasteItemComponent
    // so any stack items not yet detached by proceedFromSorting() are guaranteed gone.
    removeAll(
      children.where(
        (c) =>
            c is WasteItemComponent ||
            c is BinComponent ||
            c is SortingFacilityBackground ||
            c is TreatmentFacilityBackground ||
            c is TreatmentAmbientParticle,
      ),
    );

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
    tile.cleanProgress = ((12 - bacteriaRemaining) * progressPerBacteria).clamp(
      0.0,
      1.0,
    );

    // Start treatment animation at tap point
    tile.startTreatmentAtPoint(
      tile.lastTapPosition ?? Vector2(tile.size.x / 2, tile.size.y / 2),
    );

    // Visual feedback - camera pulse
    camera.viewfinder.add(
      SequenceEffect([
        ScaleEffect.by(Vector2.all(1.03), EffectController(duration: 0.15)),
        ScaleEffect.by(Vector2.all(1 / 1.03), EffectController(duration: 0.15)),
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
    final cleanedPercentage = waterTiles.isNotEmpty
        ? waterTiles.first.cleanProgress
        : 0.0;

    // Calculate purified water based on cleanliness (max 600L at 100% clean)
    purifiedWaterAmount = (cleanedPercentage * 600).round();

    // Bacteria multiply based on efficiency
    final efficiencyBonus = cleanedPercentage >= 0.9
        ? 3
        : cleanedPercentage >= 0.7
        ? 2
        : 1;
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
        ScaleEffect.to(Vector2.all(1.05), EffectController(duration: 0.3)),
        ScaleEffect.to(Vector2.all(1.0), EffectController(duration: 0.3)),
      ], repeatCount: 3),
    );

    // Sparkle effect across the entire river
    for (int i = 0; i < 20; i++) {
      Future.delayed(Duration(milliseconds: i * 100), () {
        tile.triggerSparkleEffect();
      });
    }
  }

  void startUrbanPhase() {
    currentPhase = 5;
    urbanHouseholdsConnected = 0;
    urbanPipesLaid = 0;
    urbanProgress = 0.0;
    urbanPhaseComplete = false;
    urbanResult = '';
    urbanTimeLeft = 90.0;
    urbanTimerRunning = false;
    urbanTimerStarted = false;
    urbanTotalBursts = 0;
    urbanBurstsFixed = 0;
    urbanActiveBursts = 0;
    urbanAveragePressure = 0.0;
    urbanTimeTaken = 0.0;
    urbanSupplyScore = 0;
    _urbanBurstAccumulator = 0.0;

    removeAll(children.whereType<WaterTileComponent>());
    removeAll(children.whereType<EnhancedRiverComponent>());
    removeAll(children.whereType<FurrowRenderComponent>());

    // ── 6×6 pipe-puzzle grid ─────────────────────────────────────────────
    const gs = 6; // grid size
    urbanTotalHouseholds = 5;
    urbanGrid = List.generate(
        gs, (r) => List.generate(gs, (c) => UrbanTile(type: 'empty')));

    // Fixed reservoir at top-left
    urbanGrid[0][0] = UrbanTile(type: 'reservoir');

    // ── Place 5 households in far zone (r+c >= 5) ───────────────────────
    final houseCells = <String>{};
    int placed = 0;
    int attempts = 0;
    while (placed < 5 && attempts < 500) {
      attempts++;
      final r = _rng.nextInt(gs);
      final c = _rng.nextInt(gs);
      if (urbanGrid[r][c].type != 'empty') continue;
      if (r + c < 5) continue; // keep houses far from reservoir
      urbanGrid[r][c] = UrbanTile(type: 'house');
      houseCells.add('$r,$c');
      placed++;
    }

    // ── Place 7 terrain obstacles (force non-trivial routing) ────────────
    // Rules: not in row 0, not in col 0, not adjacent to any house
    int obs = 0;
    attempts = 0;
    while (obs < 7 && attempts < 400) {
      attempts++;
      final r = 1 + _rng.nextInt(gs - 1); // rows 1..5
      final c = 1 + _rng.nextInt(gs - 1); // cols 1..5
      if (urbanGrid[r][c].type != 'empty') continue;
      // Don't block cells adjacent to a house
      bool nearHouse = false;
      for (final hp in houseCells) {
        final parts = hp.split(',');
        final hr = int.parse(parts[0]);
        final hc = int.parse(parts[1]);
        if ((r - hr).abs() <= 1 && (c - hc).abs() <= 1) {
          nearHouse = true;
          break;
        }
      }
      if (nearHouse) continue;
      urbanGrid[r][c] = UrbanTile(type: 'obstacle');
      obs++;
    }

    _calculateUrbanFlow();
    resumeEngine();
  }

  /// Starts the timer without placing any pipe — called by the overlay "Begin" button.
  void activateUrbanTimer() {
    if (urbanTimerStarted || urbanPhaseComplete) return;
    urbanTimerStarted = true;
    urbanTimerRunning = true;
    onUrbanTimerStart?.call();
  }

  // ── Tile-tap handler ────────────────────────────────────────────────────
  void handleUrbanTileTap(int r, int c) {
    if (urbanPhaseComplete) return;

    if (!urbanTimerStarted) {
      urbanTimerStarted = true;
      urbanTimerRunning = true;
      onUrbanTimerStart?.call();
    }

    final tile = urbanGrid[r][c];

    // Fix a burst first — highest priority
    if (tile.isLeaking) {
      tile.isLeaking = false;
      urbanBurstsFixed++;
      urbanActiveBursts = (urbanActiveBursts - 1).clamp(0, 999);
      _calculateUrbanFlow();
      return;
    }

    // Immutable tiles
    if (tile.type == 'obstacle' ||
        tile.type == 'reservoir' ||
        tile.type == 'house') {
      return;
    }

    // Track before state for pipe count
    final bool wasEmpty = tile.type == 'empty';

    // ── Tile cycle: empty → straight(H→V) → corner(×4) → t_junction(×4) → empty
    if (tile.type == 'empty') {
      tile.type = 'straight';
      tile.rotation = 0; // horizontal
    } else if (tile.type == 'straight') {
      if (tile.rotation == 0) {
        tile.rotation = 1; // flip to vertical
      } else {
        tile.type = 'corner';
        tile.rotation = 0;
      }
    } else if (tile.type == 'corner') {
      tile.rotation = (tile.rotation + 1) % 4;
      if (tile.rotation == 0) {
        tile.type = 't_junction';
        tile.rotation = 0;
      }
    } else if (tile.type == 't_junction') {
      tile.rotation = (tile.rotation + 1) % 4;
      if (tile.rotation == 0) {
        tile.type = 'empty';
      }
    }

    // Track pipe count (only non-empty tiles count as laid pipes)
    final bool isNowEmpty = tile.type == 'empty';
    if (wasEmpty && !isNowEmpty) urbanPipesLaid++;
    if (!wasEmpty && isNowEmpty) urbanPipesLaid = (urbanPipesLaid - 1).clamp(0, 999);

    _calculateUrbanFlow();
  }

  // ── Direction-aware BFS pressure/flow calculation ──────────────────────
  // Directions: 0=up  1=right  2=down  3=left
  static const _dr = [-1, 0, 1, 0];
  static const _dc = [ 0, 1, 0,-1];

  void _calculateUrbanFlow() {
    const gs = 6;

    // Reset all tiles
    for (var row in urbanGrid) {
      for (var t in row) {
        t.isConnected = false;
        t.pressure    = 0.0;
      }
    }

    // BFS from reservoir [0,0]
    urbanGrid[0][0].isConnected = true;
    urbanGrid[0][0].pressure    = 100.0;
    final queue = <List<int>>[[0, 0]];

    while (queue.isNotEmpty) {
      final pos  = queue.removeAt(0);
      final r    = pos[0];
      final c    = pos[1];
      final curr = urbanGrid[r][c];

      for (int dir = 0; dir < 4; dir++) {
        // Current tile must open toward this direction
        if (!curr.openEnds.contains(dir)) continue;

        final nr = r + _dr[dir];
        final nc = c + _dc[dir];
        if (nr < 0 || nr >= gs || nc < 0 || nc >= gs) continue;

        final next = urbanGrid[nr][nc];
        if (next.isConnected) continue;

        // Neighbour tile must open back toward current tile
        final incoming = (dir + 2) % 4;
        if (!next.openEnds.contains(incoming)) continue;

        // Pressure loss: bursting pipe bleeds heavily
        final drop = next.isLeaking ? 32.0 : 6.0;
        next.pressure = (curr.pressure - drop).clamp(0.0, 100.0);

        if (next.pressure > 10) {
          next.isConnected = true;
          queue.add([nr, nc]);
        }
      }
    }

    // Tally households with sufficient pressure
    int connectedHouses = 0;
    double totalP = 0.0;
    for (var row in urbanGrid) {
      for (var t in row) {
        if (t.type == 'house' && t.isConnected && t.pressure > 30) {
          connectedHouses++;
          totalP += t.pressure;
        }
      }
    }

    urbanHouseholdsConnected = connectedHouses;
    urbanAveragePressure =
        connectedHouses > 0 ? totalP / connectedHouses : 0.0;
    urbanProgress = (connectedHouses / urbanTotalHouseholds).clamp(0.0, 1.0);
    onUrbanUpdate?.call(urbanHouseholdsConnected, urbanProgress);

    // Complete only when all houses connected AND no unresolved bursts
    if (connectedHouses == urbanTotalHouseholds &&
        urbanActiveBursts == 0 &&
        urbanTimerStarted) {
      _completeUrbanPhase();
    }
  }

  // ── Dynamic burst interval (shrinks as network grows) ──────────────────
  double get _dynamicBurstInterval {
    if (urbanPipesLaid < 3)  return 999.0; // no bursts until network started
    if (urbanPipesLaid < 6)  return 3.5;
    if (urbanPipesLaid < 10) return 2.2;
    return 1.4;
  }

  double get _dynamicBurstChance {
    if (urbanPipesLaid < 3) return 0.0;
    return (0.20 + urbanPipesLaid * 0.025).clamp(0.0, 0.55);
  }

  // ── Burst spawner ───────────────────────────────────────────────────────
  void _spawnUrbanBurst() {
    if (_rng.nextDouble() >= _dynamicBurstChance) return;

    // Prefer CONNECTED pipes — bursts on active flow are most disruptive
    final connected = <List<int>>[];
    final any       = <List<int>>[];
    const gs = 6;
    for (int r = 0; r < gs; r++) {
      for (int c = 0; c < gs; c++) {
        final t = urbanGrid[r][c];
        if ((t.type == 'straight' || t.type == 'corner' || t.type == 't_junction')
            && !t.isLeaking) {
          any.add([r, c]);
          if (t.isConnected) connected.add([r, c]);
        }
      }
    }

    final pool = connected.isNotEmpty ? connected : any;
    if (pool.isEmpty) return;

    final pick = pool[_rng.nextInt(pool.length)];
    urbanGrid[pick[0]][pick[1]].isLeaking = true;
    urbanTotalBursts++;
    urbanActiveBursts++;
    _calculateUrbanFlow();
  }

  // connectUrbanHousehold removed — connection is now detected automatically
  // by _calculateUrbanFlow() via BFS on every tile tap.

  void _completeUrbanPhase() {
    if (urbanPhaseComplete) return;
    urbanPhaseComplete = true;
    urbanTimerRunning = false;
    urbanTimeTaken = 90.0 - urbanTimeLeft; // seconds elapsed

    // ── Supply-quality scoring (0‥100) ────────────────────────────────
    // Component 1: household coverage (50 pts)
    final coveragePts = (urbanHouseholdsConnected / 5.0 * 50).round();

    // Component 2: average pressure of supplied houses (30 pts)
    final pressurePts = (urbanAveragePressure / 100.0 * 30).round();

    // Component 3: burst management (20 pts — lose 4 per unresolved burst)
    final burstPenalty = (urbanActiveBursts * 4).clamp(0, 20);
    final burstPts = 20 - burstPenalty;

    urbanSupplyScore = (coveragePts + pressurePts + burstPts).clamp(0, 100);

    // ── Result tier ───────────────────────────────────────────────────
    if (urbanHouseholdsConnected == 5 &&
        urbanActiveBursts == 0 &&
        urbanAveragePressure >= 65) {
      urbanResult = 'excellent';
    } else if (urbanHouseholdsConnected >= 4 && urbanActiveBursts <= 1) {
      urbanResult = 'good';
    } else if (urbanHouseholdsConnected >= 3) {
      urbanResult = 'partial';
    } else if (urbanHouseholdsConnected >= 1) {
      urbanResult = 'poor';
    } else {
      urbanResult = 'failed';
    }

    onUrbanComplete?.call(urbanResult);
    pauseEngine();
  }

  void startIndustrialPhase() {
    currentPhase = 6; // Industrial
    industrialSystemsUpgraded = 0;
    industrialEfficiency = 0.0;
    industrialPhaseComplete = false;
    industrialResult = '';
    industrialTimeLeft = 90.0;
    industrialTimerRunning = false;
    _setupIndustrialPhase();
  }

  void _setupIndustrialPhase() async {
    removeAll(children.whereType<WaterTileComponent>());
    removeAll(children.whereType<EnhancedRiverComponent>());
    removeAll(children.whereType<FurrowRenderComponent>());
    await Future.delayed(const Duration(milliseconds: 100));
    resumeEngine();
  }

  void upgradeIndustrialSystem(int systemIndex) {
    if (industrialPhaseComplete) return;
    industrialSystemsUpgraded++;
    industrialEfficiency = (industrialSystemsUpgraded / industrialTotalSystems).clamp(0.0, 1.0);
    if (!industrialTimerRunning) industrialTimerRunning = true;
    onIndustrialUpdate?.call(industrialSystemsUpgraded, industrialEfficiency);
    if (industrialSystemsUpgraded >= industrialTotalSystems) {
      _completeIndustrialPhase();
    }
  }

  void _completeIndustrialPhase() {
    if (industrialPhaseComplete) return;
    industrialPhaseComplete = true;
    industrialTimerRunning = false;
    industrialResult = industrialEfficiency >= 1.0 ? 'optimized'
        : industrialEfficiency >= 0.5 ? 'improved' : 'partial';
    onIndustrialComplete?.call(industrialResult);
    pauseEngine();
  }

  void startEnvironmentalPhase() {
    currentPhase = 7; // Environmental
    habitatsRestored = 0;
    ecosystemHealth = 0.0;
    environmentalPhaseComplete = false;
    environmentalResult = '';
    environmentalTimeLeft = 90.0;
    environmentalTimerRunning = false;
    _setupEnvironmentalPhase();
  }

  void _setupEnvironmentalPhase() async {
    removeAll(children.whereType<WaterTileComponent>());
    removeAll(children.whereType<EnhancedRiverComponent>());
    removeAll(children.whereType<FurrowRenderComponent>());
    await Future.delayed(const Duration(milliseconds: 100));
    resumeEngine();
  }

  void restoreHabitat(int habitatIndex) {
    if (environmentalPhaseComplete) return;
    habitatsRestored++;
    ecosystemHealth = (habitatsRestored / totalHabitats).clamp(0.0, 1.0);
    if (!environmentalTimerRunning) environmentalTimerRunning = true;
    onEnvironmentalUpdate?.call(habitatsRestored, ecosystemHealth);
    if (habitatsRestored >= totalHabitats) {
      _completeEnvironmentalPhase();
    }
  }

  void _completeEnvironmentalPhase() {
    if (environmentalPhaseComplete) return;
    environmentalPhaseComplete = true;
    environmentalTimerRunning = false;
    environmentalResult = ecosystemHealth >= 1.0 ? 'thriving'
        : ecosystemHealth >= 0.6 ? 'recovering' : 'degraded';
    onEnvironmentalComplete?.call(environmentalResult);
    pauseEngine();
  }

  void _updateUrbanTimer(double dt) {
    if (currentPhase != 5 || !urbanTimerRunning || urbanPhaseComplete) return;

    urbanTimeLeft = (urbanTimeLeft - dt).clamp(0, 90.0);
    onUrbanTick?.call(urbanTimeLeft);

    // Burst interval shrinks as more pipes are laid
    _urbanBurstAccumulator += dt;
    if (_urbanBurstAccumulator >= _dynamicBurstInterval &&
        urbanGrid.isNotEmpty) {
      _urbanBurstAccumulator = 0.0;
      _spawnUrbanBurst();
    }

    if (urbanTimeLeft <= 0) _completeUrbanPhase();
  }

  void _updateIndustrialTimer(double dt) {
    if (currentPhase != 6 || !industrialTimerRunning || industrialPhaseComplete) return;
    industrialTimeLeft = (industrialTimeLeft - dt).clamp(0, 90.0);
    onIndustrialTick?.call(industrialTimeLeft);
    if (industrialTimeLeft <= 0) _completeIndustrialPhase();
  }

  void _updateEnvironmentalTimer(double dt) {
    if (currentPhase != 7 || !environmentalTimerRunning || environmentalPhaseComplete) return;
    environmentalTimeLeft = (environmentalTimeLeft - dt).clamp(0, 90.0);
    onEnvironmentalTick?.call(environmentalTimeLeft);
    if (environmentalTimeLeft <= 0) _completeEnvironmentalPhase();
  }

  void startPhase4Agriculture() {
    currentPhase = 4;
    // Reset all phase 4 state
    selectedCrop = null;
    irrigationMethod = null;
    farmGreenProgress = 0.0;
    connectedChannels = 0;
    phase4Complete = false;
    phase4Timer = 0.0;
    irrigationTimeLeft = phase4Duration;
    irrigationTimerRunning = false;
    harvestResult = '';
    educationalTip = '';
    completedFurrows.clear();
    furrowNetwork.clear();
    pipePaths.clear();
    pipeNetwork.clear();
    currentFurrowBeingDrawn = null;
    currentPipeBeingDrawn = null;
    activeWaterFlows.clear();
    isDrawingFurrow = false;
    isDrawingPipe2 = false;
    tractor = null;
    _setupAgriculturePhase();
  }

  void _setupAgriculturePhase() async {
    // Clear previous components
    removeAll(children.whereType<WaterTileComponent>());
    removeAll(children.whereType<EnhancedRiverComponent>());
    removeAll(children.whereType<UnifiedAgricultureBackground>());
    removeAll(children.whereType<FurrowRenderComponent>());
    removeAll(children.whereType<CropComponent>());
    await Future.delayed(const Duration(milliseconds: 100));

    int attempts = 0;
    while ((size.x == 0 || size.y == 0 || size.x < 100 || size.y < 100) &&
        attempts < 20) {
      await Future.delayed(const Duration(milliseconds: 100));
      attempts++;
    }

    if (size.x == 0 || size.y == 0) {
      debugPrint('ERROR: Canvas size invalid for Phase 4!');
      return;
    }

    // Background
    add(ModernAgricultureBackground(size: size));

    // River — max 25% of longer dimension
    _createAdaptiveRiverLayout();

    // Furrow/pipe render component
    add(FurrowRenderComponent());

    debugPrint('✅ Phase 4 setup complete');
    resumeEngine();
  }

  /// Returns the farm play area rect (everything outside the river strip)
  Rect _getFarmRect() {
    final isPortrait = size.y > size.x;
    final riverFraction = 0.25;
    if (isPortrait) {
      // River on top
      final riverH = size.y * riverFraction;
      return Rect.fromLTWH(0, riverH, size.x, size.y - riverH);
    } else {
      // River on left
      final riverW = size.x * riverFraction;
      return Rect.fromLTWH(riverW, 0, size.x - riverW, size.y);
    }
  }

  void _createAdaptiveRiverLayout() {
    // River occupies ≤25% of the LONGER screen dimension.
    // Portrait / mobile  → horizontal strip across the top  (25% of height)
    // Landscape / desktop→ vertical strip on the left       (25% of width)
    final isPortrait = size.y > size.x;
    EnhancedRiverComponent newRiver;

    if (isPortrait) {
      // Mobile portrait: top horizontal river
      final riverH = size.y * 0.25;
      newRiver = EnhancedRiverComponent(
        size: Vector2(size.x, riverH),
        position: Vector2.zero(),
        flowDirection: RiverFlowDirection.leftToRight,
        orientation: RiverOrientation.horizontal,
      );
    } else {
      // Landscape / desktop / tablet: left vertical river
      final riverW = size.x * 0.25;
      newRiver = EnhancedRiverComponent(
        size: Vector2(riverW, size.y),
        position: Vector2.zero(),
        flowDirection: RiverFlowDirection.topToBottom,
        orientation: RiverOrientation.vertical,
      );
    }

    river = newRiver;
    add(newRiver);
    debugPrint('🏞️ River: ${newRiver.size} at ${newRiver.position} (portrait=$isPortrait)');
  }

  void _repositionAgricultureComponents() {
    final currentRiver = children.whereType<EnhancedRiverComponent>().firstOrNull;
    if (currentRiver == null) return;
    river = currentRiver;

    final isPortrait = size.y > size.x;
    if (isPortrait) {
      river!.size = Vector2(size.x, size.y * 0.25);
      river!.position = Vector2.zero();
      river!.orientation = RiverOrientation.horizontal;
      river!.flowDirection = RiverFlowDirection.leftToRight;
    } else {
      river!.size = Vector2(size.x * 0.25, size.y);
      river!.position = Vector2.zero();
      river!.orientation = RiverOrientation.vertical;
      river!.flowDirection = RiverFlowDirection.topToBottom;
    }
    river!.generateWindingRiverPath();

  }

  void onFarmTapDown(Vector2 position) {
    if (irrigationMethod == 'pipe') {
      // Start drawing a pipe path
      if (!isDrawingPipe2) {
        isDrawingPipe2 = true;
        lastFurrowPoint = position.clone();
        final isNearRiver = _isPositionNearRiver(position, threshold: 50.0);
        currentPipeBeingDrawn = FurrowPath(
          id: 'pipe_${DateTime.now().millisecondsSinceEpoch}',
          points: [position.clone()],
          isConnectedToRiver: isNearRiver,
        );
        if (isNearRiver) {
          final cp = _getClosestRiverPoint(position);
          if (cp != null) currentPipeBeingDrawn!.riverConnectionPoint = cp;
        }
      }
      return;
    }

    // Default: furrow mode
    if (!isDrawingFurrow) {
      isDrawingFurrow = true;
      lastFurrowPoint = position.clone();
      activeFurrowId = 'furrow_${DateTime.now().millisecondsSinceEpoch}';

      final isNearRiver = _isPositionNearRiver(position, threshold: 40.0);
      currentFurrowBeingDrawn = FurrowPath(
        id: activeFurrowId!,
        points: [position.clone()],
        isConnectedToRiver: isNearRiver,
      );
      if (isNearRiver) {
        final closestRiverPoint = _getClosestRiverPoint(position);
        if (closestRiverPoint != null) {
          currentFurrowBeingDrawn!.riverConnectionPoint = closestRiverPoint;
        }
      }
    }
  }

  bool _isPositionNearRiver(Vector2 position, {double threshold = 50.0}) {
    if (river == null) return false;

    // Convert position to river's local coordinates
    final riverLocalPos = position - river!.position;

    // Check if point is within reasonable bounds
    if (riverLocalPos.x < -threshold ||
        riverLocalPos.x > river!.size.x + threshold ||
        riverLocalPos.y < -threshold ||
        riverLocalPos.y > river!.size.y + threshold) {
      return false;
    }

    // Get closest point on river path
    final closestPoint = river!.getRiverClosestPoint(riverLocalPos);
    if (closestPoint == null) return false;

    final distanceToPath = (closestPoint - riverLocalPos).length;

    // IMPROVED: Check if within connection zone
    // Connection zone = outer edge of river + threshold
    final connectionZoneRadius = (river!.riverWidth * 0.5) + threshold;

    final isNear = distanceToPath <= connectionZoneRadius;

    if (isNear) {
      debugPrint(
        '🎯 Position $position is ${distanceToPath.toStringAsFixed(1)}px from river path (threshold: $connectionZoneRadius)',
      );
    }

    return isNear;
  }

  Vector2? _getClosestRiverPoint(Vector2 position) {
    if (river == null) return null;

    // Convert position to river's local coordinates
    final riverLocalPos = position - river!.position;

    // Get closest point on river centerline
    final closestLocalPoint = river!.getRiverClosestPoint(riverLocalPos);

    if (closestLocalPoint != null) {
      // Calculate direction from river center to position
      final directionFromCenter = (riverLocalPos - closestLocalPoint)
          .normalized();

      // Place connection point at edge of river (not center)
      // Use 45% of river width (slightly inside the visible edge)
      final connectionOffset = directionFromCenter * (river!.riverWidth * 0.45);
      final edgePoint = closestLocalPoint + connectionOffset;

      // Convert back to world coordinates
      return river!.position + edgePoint;
    }

    return null;
  }

  bool _wouldCrossRiver(Vector2? start, Vector2 end) {
    if (river == null || start == null) return false;

    // CRITICAL FIX: Only prevent actual river crossing, not edge touching

    // Check if BOTH points are clearly inside core water
    final startInCore = _isPositionInRiver(start);
    final endInCore = _isPositionInRiver(end);

    // If both are in core water, definitely crossing
    if (startInCore && endInCore) {
      return true;
    }

    // If one is in core and one is far outside, might be crossing
    if (startInCore || endInCore) {
      final distanceStartToEnd = (end - start).length;

      // If points are very close (< 15px), allow it (edge touching)
      if (distanceStartToEnd < 15) {
        return false;
      }

      // Check if the line segment between them crosses river center
      final crossesCenter = _lineSegmentCrossesRiverCore(start, end);
      return crossesCenter;
    }

    // Neither point is in core water, check if line passes through river
    return _lineSegmentCrossesRiverCore(start, end);
  }

  bool _lineSegmentCrossesRiverCore(Vector2 start, Vector2 end) {
    if (river == null) return false;

    // Sample points along the line segment
    final steps = 8;
    for (int i = 0; i <= steps; i++) {
      final t = i / steps;
      final samplePoint = start + (end - start) * t;

      // Check if this sample point is in river core
      if (_isPositionInRiver(samplePoint)) {
        // Additional check: is this point far from both start and end?
        final distToStart = (samplePoint - start).length;
        final distToEnd = (samplePoint - end).length;

        // If sample point is at least 20px from both endpoints, it's crossing
        if (distToStart > 20 && distToEnd > 20) {
          return true;
        }
      }
    }

    return false;
  }

  double _getDistanceToRiverEdge(Vector2 position) {
    if (river == null) return double.infinity;

    // Convert position to river's local coordinates
    final riverLocalPos = position - river!.position;

    // Get closest point on river path centerline
    final closestPoint = river!.getRiverClosestPoint(riverLocalPos);

    if (closestPoint != null) {
      final distanceToCenter = (closestPoint - riverLocalPos).length;

      // Calculate distance to actual edge (not center)
      // Edge is at riverWidth * 0.5 from center
      final riverEdgeRadius = river!.riverWidth * 0.5;
      final distanceToEdge = (distanceToCenter - riverEdgeRadius).abs();

      return distanceToEdge;
    }

    return double.infinity;
  }

  void onFarmDragUpdate(Vector2 newPosition, Vector2 delta) {
    // ── Pipe mode ─────────────────────────────────────────────────────────
    if (irrigationMethod == 'pipe' && isDrawingPipe2 && currentPipeBeingDrawn != null) {
      if (lastFurrowPoint != null) {
        final dist = (newPosition - lastFurrowPoint!).length;
        if (dist >= 10) {
          currentPipeBeingDrawn!.points.add(newPosition.clone());
          lastFurrowPoint = newPosition.clone();
          if (!currentPipeBeingDrawn!.isConnectedToRiver) {
            if (_isPositionNearRiver(newPosition, threshold: 60.0)) {
              final cp = _getClosestRiverPoint(newPosition);
              if (cp != null) {
                currentPipeBeingDrawn!.isConnectedToRiver = true;
                currentPipeBeingDrawn!.riverConnectionPoint = cp;
              }
            }
          }
        }
      }
      return;
    }

    // ── Furrow mode ───────────────────────────────────────────────────────
    if (!isDrawingFurrow || currentFurrowBeingDrawn == null) return;

    if (lastFurrowPoint != null && _wouldCrossRiver(lastFurrowPoint, newPosition)) return;
    if (_isPositionInRiver(newPosition) && _getDistanceToRiverEdge(newPosition) < -30) return;

    if (lastFurrowPoint != null) {
      final distance = (newPosition - lastFurrowPoint!).length;
      if (distance >= 10) {
        currentFurrowBeingDrawn!.points.add(newPosition.clone());
        lastFurrowPoint = newPosition.clone();
        if (!currentFurrowBeingDrawn!.isConnectedToRiver) {
          if (_isPositionNearRiver(newPosition, threshold: 60.0)) {
            final cp = _getClosestRiverPoint(newPosition);
            if (cp != null) {
              currentFurrowBeingDrawn!.isConnectedToRiver = true;
              currentFurrowBeingDrawn!.riverConnectionPoint = cp;
            }
          }
        }
      }
    }
  }

  void onFarmDragEnd(Vector2 endPosition) {
    // ── Handle pipe drawing end ───────────────────────────────────────────
    if (isDrawingPipe2 && currentPipeBeingDrawn != null) {
      isDrawingPipe2 = false;
      currentPipeBeingDrawn!.points.add(endPosition.clone());
      _finalisePipePath(currentPipeBeingDrawn!);
      currentPipeBeingDrawn = null;
      return;
    }

    if (!isDrawingFurrow || currentFurrowBeingDrawn == null) return;
    isDrawingFurrow = false;

    // Add final point
    currentFurrowBeingDrawn!.points.add(endPosition.clone());

    if (!currentFurrowBeingDrawn!.isConnectedToRiver) {
      final startPoint = currentFurrowBeingDrawn!.points.first;
      final startNearRiver = _isPositionNearRiver(startPoint, threshold: 60.0);
      final endNearRiver = _isPositionNearRiver(endPosition, threshold: 60.0);

      if (startNearRiver) {
        final closestPoint = _getClosestRiverPoint(startPoint);
        if (closestPoint != null) {
          currentFurrowBeingDrawn!.isConnectedToRiver = true;
          currentFurrowBeingDrawn!.riverConnectionPoint = closestPoint;
        }
      } else if (endNearRiver) {
        final closestPoint = _getClosestRiverPoint(endPosition);
        if (closestPoint != null) {
          currentFurrowBeingDrawn!.isConnectedToRiver = true;
          currentFurrowBeingDrawn!.riverConnectionPoint = closestPoint;
        }
      }
    }

    _detectFurrowInterconnections(currentFurrowBeingDrawn!);
    completedFurrows.add(currentFurrowBeingDrawn!);
    furrowNetwork[currentFurrowBeingDrawn!.id] = currentFurrowBeingDrawn!;

    if (currentFurrowBeingDrawn!.isConnectedToRiver) {
      _startContinuousWaterFlow(currentFurrowBeingDrawn!);
      onFurrowsComplete?.call();
      _onChannelConnected();
    }

    currentFurrowBeingDrawn = null;
    activeFurrowId = null;


  }

  void _updateSortingTimer(double dt) {
    if (currentPhase != 2 || !sortingTimerRunning) return;
    sortingTimeLeft = (sortingTimeLeft - dt).clamp(0, 90.0);
    onSortingTick?.call(sortingTimeLeft);
    if (sortingTimeLeft <= 0) {
      sortingTimerRunning = false;
      final unsorted = collectedWaste.length;
      // Notify screen — it shows a time-up panel with a "Proceed" button.
      // Player must tap, which calls proceedFromSorting(). No auto-advance.
      onSortingTimeUp?.call(sortedCorrectly, sortedIncorrectly, unsorted);
    }
  }

  // ── Pipe path finalisation ──────────────────────────────────────────────
  void _finalisePipePath(FurrowPath pipe) {
    if (pipe.points.length < 2) return;
    if (!pipe.isConnectedToRiver) {
      final start = pipe.points.first;
      final end   = pipe.points.last;
      for (final pt in [start, end]) {
        if (_isPositionNearRiver(pt, threshold: 60.0)) {
          final cp = _getClosestRiverPoint(pt);
          if (cp != null) {
            pipe.isConnectedToRiver = true;
            pipe.riverConnectionPoint = cp;
            break;
          }
        }
      }
    }
    pipePaths.add(pipe);
    pipeNetwork[pipe.id] = pipe;
    if (pipe.isConnectedToRiver) {
      _startContinuousWaterFlow(pipe);
      _onChannelConnected();
    }
  }

  // ── Called whenever a furrow or pipe connects to the river ─────────────
  void _onChannelConnected() {
    connectedChannels++;
    if (!irrigationTimerRunning) {
      irrigationTimerRunning = true;
    }
    _spawnCropsIfNeeded();
    _updateFarmGreenProgress();
    onFarmUpdate?.call(farmGreenProgress, connectedChannels);
  }

  void _updateFarmGreenProgress() {
    // Progress increases with each connected channel
    // Maximum channels for full green depends on crop
    final maxChannels = _maxChannelsForCrop();
    farmGreenProgress = (connectedChannels / maxChannels).clamp(0.0, 1.0);
    // Update background
    children.whereType<ModernAgricultureBackground>().forEach((bg) {
      bg.greenProgress = farmGreenProgress;
    });
    // Update crop growth stages
    children.whereType<CropComponent>().forEach((crop) {
      crop.growthStage = (farmGreenProgress * 3).floor().clamp(0, 3);
    });
  }

  int _maxChannelsForCrop() {
    switch (selectedCrop) {
      case 'rice':        return 5; // Many channels
      case 'maize':       return 3; // Few channels
      case 'vegetables':  return 2; // Drip — pipes count more
      default:            return 3;
    }
  }

  void _spawnCropsIfNeeded() {
    if (children.whereType<CropComponent>().isNotEmpty) return;
    if (selectedCrop == null) return;

    final farmRect = _getFarmRect();
    // Determine grid density by crop type
    final cols = selectedCrop == 'maize' ? 5 : selectedCrop == 'rice' ? 8 : 6;
    final rows = selectedCrop == 'maize' ? 3 : selectedCrop == 'rice' ? 5 : 4;

    // Margins so crops never touch the river edge or screen edge
    const double marginH = 24.0;
    const double marginV = 28.0;
    final usableW = farmRect.width  - marginH * 2;
    final usableH = farmRect.height - marginV * 2;
    final colStep = usableW / (cols - 1);
    final rowStep = usableH / (rows - 1);

    // Collect all current channel points for exclusion check
    final List<Vector2> channelPts = [
      ...completedFurrows.expand((f) => f.points),
      ...pipePaths.expand((p) => p.points),
    ];

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final baseX = farmRect.left + marginH + c * colStep;
        final baseY = farmRect.top  + marginV + r * rowStep;

        // Skip if too close to any channel (within 20px)
        bool tooClose = channelPts.any((pt) =>
            (pt.x - baseX).abs() < 20 && (pt.y - baseY).abs() < 20);
        if (tooClose) continue;

        add(CropComponent(
          cropType: selectedCrop!,
          position: Vector2(baseX, baseY),
          size: Vector2(28, 36),
        ));
      }
    }
  }

  // ── Irrigation timer update ─────────────────────────────────────────────
  void _updateIrrigationTimer(double dt) {
    if (currentPhase != 4 || !irrigationTimerRunning || phase4Complete) return;
    irrigationTimeLeft = (irrigationTimeLeft - dt).clamp(0, phase4Duration);
    onIrrigationTick?.call(irrigationTimeLeft);
    if (irrigationTimeLeft <= 0) {
      _evaluateHarvest();
    }
  }

  // ── Harvest evaluation ──────────────────────────────────────────────────
  void _evaluateHarvest() {
    if (phase4Complete) return;
    phase4Complete = true;
    irrigationTimerRunning = false;

    final method = irrigationMethod ?? 'furrow';
    final crop   = selectedCrop   ?? 'maize';

    // Correct pairings:
    //  vegetables → pipe (drip)
    //  maize      → furrow (tunnel, few channels)
    //  rice       → furrow (flood, many channels)
    bool methodCorrect;
    bool channelCountCorrect;

    if (crop == 'vegetables') {
      methodCorrect      = method == 'pipe';
      channelCountCorrect = connectedChannels >= 2;
    } else if (crop == 'maize') {
      methodCorrect      = method == 'furrow';
      channelCountCorrect = connectedChannels >= 2 && connectedChannels <= 5;
    } else { // rice
      methodCorrect      = method == 'furrow';
      channelCountCorrect = connectedChannels >= 4;
    }

    if (methodCorrect && channelCountCorrect) {
      harvestResult  = 'bountiful';
      waterEfficiency = 90 + Random().nextInt(10);
    } else if (methodCorrect || channelCountCorrect) {
      harvestResult  = 'average';
      waterEfficiency = 55 + Random().nextInt(20);
    } else {
      harvestResult  = 'poor';
      waterEfficiency = 20 + Random().nextInt(20);
    }

    educationalTip = _buildEducationalTip(crop, method, methodCorrect, channelCountCorrect);

    // Calculate harvest yield
    harvestYield = harvestResult == 'bountiful' ? 80 + Random().nextInt(40)
        : harvestResult == 'average' ? 30 + Random().nextInt(30)
        : 5 + Random().nextInt(15);

    // Fish if water was sufficiently purified (>70% clean)
    final cleanPct = purifiedWaterAmount / 600.0;
    fishCount = cleanPct >= 0.7 ? 3 + Random().nextInt(5) : 0;

    // Final crop growth flash
    children.whereType<CropComponent>().forEach((c) => c.growthStage = 3);
    children.whereType<ModernAgricultureBackground>().forEach((bg) => bg.greenProgress = 1.0);

    onHarvestComplete?.call(harvestResult, educationalTip);
    // Phase 4 completion is now user-triggered via the Continue button
    pauseEngine();
  }

  String _buildEducationalTip(String crop, String method, bool methodOk, bool countOk) {
    if (crop == 'vegetables') {
      if (methodOk && countOk)  return '💧 Drip irrigation delivers water directly to vegetable roots, cutting water use by up to 50% and boosting yields significantly!';
      if (!methodOk && method == 'furrow') return '🌿 Vegetables have shallow roots. Furrow irrigation wastes water through run-off. Drip pipes deliver water precisely where needed.';
      return '🌿 Try connecting more drip pipes to ensure every plant gets water.';
    }
    if (crop == 'maize') {
      if (methodOk && countOk)  return '🌽 Tunnel furrows channel water efficiently between maize rows, keeping roots moist without waterlogging the soil!';
      if (!methodOk && method == 'pipe') return '🌽 Maize grows in rows and benefits from furrow (tunnel) irrigation — water flows between rows reaching all roots evenly.';
      if (countOk && !methodOk) return '🌽 Good channel count, but maize prefers furrow irrigation over pipes for even root distribution.';
      return '🌽 Maize needs 2–5 furrow channels to get water to all rows. Try adding more connected furrows.';
    }
    // rice
    if (methodOk && countOk)    return '🌾 Flood irrigation through many furrows recreates the waterlogged paddy conditions rice needs to thrive and prevents weeds!';
    if (!methodOk && method == 'pipe') return '🌾 Rice needs flooded fields to grow well. Drip pipes cannot saturate the soil enough — dig many furrows for flood irrigation.';
    if (methodOk && !countOk)   return '🌾 Rice paddies need a lot of water. Dig more furrows (at least 4–5) so the whole field floods evenly.';
    return '🌾 Rice thrives in flooded soil — use furrow irrigation and dig many channels to achieve proper flooding.';
  }

  void _detectFurrowInterconnections(FurrowPath newFurrow) {
    const connectionThreshold =
        25.0; // INCREASED from 20.0 to 25.0 for easier connection

    for (var existingFurrow in completedFurrows) {
      // Skip if already connected
      if (newFurrow.connectedFurrowIds.contains(existingFurrow.id)) continue;

      // Check if any point in new furrow is close to any point in existing furrow
      bool foundConnection = false;
      Vector2? intersectionPoint;

      for (var newPoint in newFurrow.points) {
        if (foundConnection) break;

        for (var existingPoint in existingFurrow.points) {
          final distance = (newPoint - existingPoint).length;

          if (distance < connectionThreshold) {
            // Found intersection!
            newFurrow.connectedFurrowIds.add(existingFurrow.id);
            existingFurrow.connectedFurrowIds.add(newFurrow.id);

            // Store intersection point (average of the two close points)
            intersectionPoint = (newPoint + existingPoint) / 2;
            newFurrow.intersectionPoints.add(intersectionPoint);
            existingFurrow.intersectionPoints.add(intersectionPoint);

            debugPrint(
              '🔗 Furrow ${newFurrow.id} connected to ${existingFurrow.id} at $intersectionPoint',
            );

            // CORRECTED: If existing furrow has water, propagate FROM the intersection point
            if (existingFurrow.hasWater && !newFurrow.hasWater) {
              _propagateWaterToConnectedFurrow(newFurrow, intersectionPoint);
            }

            foundConnection = true;
            break;
          }
        }
      }
    }
  }

  bool _isPositionInRiver(Vector2 position) {
    if (river == null) return false;

    // Convert position to river's local coordinates
    final riverLocalPos = position - river!.position;

    // Check if point is within river component bounds
    if (riverLocalPos.x < 0 ||
        riverLocalPos.x > river!.size.x ||
        riverLocalPos.y < 0 ||
        riverLocalPos.y > river!.size.y) {
      return false;
    }

    // Get closest point on river path
    final closestPoint = river!.getRiverClosestPoint(riverLocalPos);
    if (closestPoint == null) return false;

    final distanceToPath = (closestPoint - riverLocalPos).length;

    // CRITICAL FIX: Only consider "in river" if within CORE water area
    // Use 60% of river width (not full width which includes banks/edges)
    final coreWaterRadius = river!.riverWidth * 0.6;

    return distanceToPath < coreWaterRadius;
  }

  void _startContinuousWaterFlow(FurrowPath furrow) {
    if (!furrow.isConnectedToRiver || furrow.riverConnectionPoint == null) {
      return;
    }

    waterFlowing = true;
    furrow.hasWater = true;

    // CREATE: Continuous water flow that loops
    final waterFlow = ContinuousWaterFlowAnimation(
      furrowPath: furrow,
      startPoint: furrow.riverConnectionPoint!,
      gameSize: size,
    );

    activeWaterFlows.add(waterFlow);

    debugPrint('💧 Started CONTINUOUS water flow through furrow ${furrow.id}');

    // Propagate water to connected furrows
    _propagateWaterToConnectedFurrows(furrow);
  }

  void _propagateWaterToConnectedFurrows(FurrowPath sourceFurrow) {
    for (var connectedId in sourceFurrow.connectedFurrowIds) {
      final connectedFurrow = furrowNetwork[connectedId];

      if (connectedFurrow != null && !connectedFurrow.hasWater) {
        // Find the intersection point to use as start point for water flow
        Vector2? intersectionPoint;
        for (var point in sourceFurrow.intersectionPoints) {
          if (connectedFurrow.intersectionPoints.any(
            (p) => (p - point).length < 5,
          )) {
            intersectionPoint = point;
            break;
          }
        }

        if (intersectionPoint != null) {
          _propagateWaterToConnectedFurrow(connectedFurrow, intersectionPoint);
        }
      }
    }
  }

  void _propagateWaterToConnectedFurrow(FurrowPath furrow, Vector2 startPoint) {
    furrow.hasWater = true;

    // Create water flow starting from intersection point
    final waterFlow = ContinuousWaterFlowAnimation(
      furrowPath: furrow,
      startPoint:
          startPoint, // This is the intersection point - water flows FROM here
      gameSize: size,
      isPropagated: true,
    );

    activeWaterFlows.add(waterFlow);

    debugPrint(
      '🌊 Water propagated to connected furrow ${furrow.id} from intersection at $startPoint',
    );

    // Recursively propagate to furrows connected to this one
    Future.delayed(const Duration(milliseconds: 800), () {
      // CHANGED: Increased delay from 500ms to 800ms
      _propagateWaterToConnectedFurrows(furrow);
    });
  }

  // ADD: New method to support pausing and resuming furrow drawing
  void resumeFurrowDrawing(FurrowPath existingFurrow) {
    if (isDrawingFurrow) return; // Already drawing

    isDrawingFurrow = true;
    currentFurrowBeingDrawn = existingFurrow;
    activeFurrowId = existingFurrow.id;
    lastFurrowPoint = existingFurrow.points.last.clone();

    debugPrint('▶️ Resumed drawing furrow ${existingFurrow.id}');
  }

  @override
  void update(double dt) {
    super.update(dt);
    _updatePhase1Timer(dt);
    _updateSortingTimer(dt);
    _updateIrrigationTimer(dt);
    _updateUrbanTimer(dt);
    _updateIndustrialTimer(dt);
    _updateEnvironmentalTimer(dt);

    for (var waterFlow in activeWaterFlows) {
      if (waterFlow is ContinuousWaterFlowAnimation) {
        waterFlow.update(dt);
      }
    }

    activeWaterFlows.removeWhere((flow) {
      if (flow is ContinuousWaterFlowAnimation) return false;
      return flow.isComplete == true;
    });
  }

  void _updatePhase1Timer(double dt) {
    if (currentPhase != 1 || !timerRunning || timeUp || !playerHasStarted) return;

    collectionTimeRemaining -= dt;
    onTimerTick?.call(collectionTimeRemaining.clamp(0.0, collectionTimerMax));

    if (collectionTimeRemaining <= 0) {
      timeUp = true;
      timerRunning = false;
      // Timer lapsed — player keeps collected waste and proceeds to sorting.
      // onPhase1TimeUp shows a brief transitional message on screen.
      onPhase1TimeUp?.call(
        wasteCollectedCount,
        totalSpawnedWaste > 0 ? totalSpawnedWaste : totalWasteToCollect,
      );
      _completePhase1Enhanced();
    }
  }

  /// Restart Phase 1 from scratch (called when player hits Retry after sinking or time-up).
  void retryPhase1() {
    startPhase1();
  }

  int calculateFinalScore() {
    int score = 0;

    // Collection bonus
    score += wasteCollectedCount * 5;

    // Sorting accuracy bonus
    int accuracy = sortedIncorrectly > 0
        ? ((sortedCorrectly / (sortedCorrectly + sortedIncorrectly)) * 100)
              .round()
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