import 'package:ecoquest/game/level3/sorting_facility_screen.dart';
import 'package:flame/components.dart' hide Matrix4;
import 'package:flame/game.dart' hide Matrix4;
import 'package:flutter/material.dart' hide Matrix4;
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'dart:math' as math;

// ══════════════════════════════════════════════════════════════════════
//  ENUMS
// ══════════════════════════════════════════════════════════════════════
enum GamePhase { collection, sewerRepair, transitioning }
enum WasteType  { plastic, organic, electronic, glass, general, metallic }
enum VehicleKind { saloon, matatu, bus, suv, van, motorbike }
enum LeakType { pipe, joint, crack }
enum RepairTool { pliers, plumbingTape, wrench, sealant, none }

// ══════════════════════════════════════════════════════════════════════
//  SCREEN WRAPPER
// ══════════════════════════════════════════════════════════════════════
class CityCollectionScreen extends StatefulWidget {
  const CityCollectionScreen({super.key});
  @override
  State<CityCollectionScreen> createState() => _CityCollectionScreenState();
}

class _CityCollectionScreenState extends State<CityCollectionScreen> {
  late CityCollectionGame _game;

  @override
  void initState() {
    super.initState();
    _game = CityCollectionGame(onLevelComplete: _onDone);
  }

  void _onDone() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const SortingFacilityScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GameWidget(
        game: _game,
        overlayBuilderMap: {
          'hud':                   (ctx, g) => CityHud(g as CityCollectionGame),
          'controls':              (ctx, g) => CityControls(g as CityCollectionGame),
          'phaseBanner':           (ctx, g) => CityPhaseBanner(g as CityCollectionGame),
          'collisionFlash':        (ctx, g) => const CityCollisionFlash(),
          'phaseTransition':       (ctx, g) => CityPhaseTransition(g as CityCollectionGame),
          'collectionResults':     (ctx, g) => CollectionResultsOverlay(g as CityCollectionGame),
          'sewerResults':          (ctx, g) => SewerResultsOverlay(g as CityCollectionGame),
          'gameOver':              (ctx, g) => CityGameOver(g as CityCollectionGame),
          'toolbox':               (ctx, g) => ToolboxOverlay(g as CityCollectionGame),
        },
        initialActiveOverlays: const ['hud', 'controls'],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
//  LAYOUT CONSTANTS
// ══════════════════════════════════════════════════════════════════════
const double kRoadW       = 220.0;   // 2 lanes + shoulders
const double kLaneW       = 90.0;
const int    kLanes       = 2;
const double kBlockDepth  = 500.0;
const double kSidewalkW   = 40.0;

// ══════════════════════════════════════════════════════════════════════
//  MAIN GAME CLASS
// ══════════════════════════════════════════════════════════════════════
class CityCollectionGame extends FlameGame
    with HasCollisionDetection, ChangeNotifier {

  final VoidCallback onLevelComplete;
  CityCollectionGame({required this.onLevelComplete});

  // phase
  GamePhase phase       = GamePhase.collection;
  bool      gameStarted = false;

  // timers
  double collectTime = 120.0;
  double sewerTime   = 180.0;

  // score
  int wasteCollected      = 0;
  int plasticCollected    = 0;
  int organicCollected    = 0;
  int electronicCollected = 0;
  int glassCollected      = 0;
  int generalCollected    = 0;
  int metallicCollected   = 0;
  int sewersFixed         = 0;
  static const int kTotalSewers = 6;
  int ecoPoints           = 0;
  int collectionEcoPoints = 0;   // eco-points earned in collection phase alone
  int sewerEcoPoints      = 0;   // eco-points earned in sewer phase alone
  int sewerCollisions     = 0;   // collisions during sewer phase
  int collectionCollisions= 0;   // collisions during collection phase
  int collisionCount      = 0;

  // truck physics — tuned for controllability
  double speed        = 0.0;
  double maxSpeed     = 160.0;   // reduced from 300 — much more manageable
  double maxReverse   = 60.0;
  double accel        = 80.0;    // gentler acceleration
  double brakeForce   = 180.0;   // strong braking
  double drag         = 55.0;
  double lateralRate  = 140.0;
  double truckLean    = 0.0;
  bool   isDriving    = false;
  bool   isBraking    = false;
  bool   isLeft       = false;
  bool   isRight      = false;
  bool   isReversing  = false;

  // tilt / accelerometer input (mobile)
  double tiltX        = 0.0;   // −1.0 (full left) → +1.0 (full right)

  // Truck is at 75% down screen; world scrolls upward (truck drives "up")
  late Vector2 truckPos;
  double worldScroll = 0.0;

  // child components
  late CityWorldRenderer worldRenderer;
  late TopDownTruck      truckComp;
  final List<WasteToken>    wastes   = [];
  final List<TrafficCar>    cars     = [];
  final List<SewerLeak>     sewers   = [];
  final List<SidewalkPed>   peds     = [];

  // collision flash
  bool   crashActive = false;
  double crashTimer  = 0.0;

  // transition hold
  bool   transitioning   = false;
  double transitionHold  = 0.0;

  // banner countdown
  double bannerTimer = 0.0;

  // toolbox / repair state
  bool       toolboxOpen   = false;
  RepairTool selectedTool  = RepairTool.none;

  // cargo fill (0.0 – 1.0)
  double get cargoFill => (wasteCollected / 60.0).clamp(0.0, 1.0);

  static const List<String> kWasteAssets = [
    'mixedwaste.png', 'garbage.png', 'dirty-shirt.png', 'torn-sock.png',
    'banana.png', 'glass-bottle.png', 'bottle.png', 'peel.png',
    'paper.png', 'clothes.png', 'tshirt.png',
  ];
  final math.Random _rng = math.Random();

  // helpers
  double get roadLeft  => (size.x - kRoadW) / 2;
  double get roadRight => (size.x + kRoadW) / 2;
  double laneCenter(int lane) => roadLeft + 18 + lane * kLaneW + kLaneW / 2;

  /// Truck drives upward → world scrolls in +worldScroll direction.
  /// toScreenY maps a world coordinate to screen pixels.
  /// Objects with worldY = 0 start at truckPos.y.
  /// As worldScroll increases (truck moves forward/up), objects move down screen.
  double toScreenY(double worldY) => truckPos.y + (worldY + worldScroll);

  // ════════════════════════════════════════════════════════════════════
  @override
  Future<void> onLoad() async {
    super.onLoad();
    try { await images.loadAll(kWasteAssets); } catch (_) {}

    truckPos = Vector2(size.x / 2, size.y * 0.75);

    worldRenderer = CityWorldRenderer(game: this);
    add(worldRenderer);

    truckComp = TopDownTruck(game: this);
    add(truckComp);

    _spawnWaste();
    _spawnTraffic();
    _spawnSewers();
    _spawnPeds();

    _showBanner();
    add(TimerComponent(period: 1.0, repeat: true, onTick: _onSecond));
  }

  // spawners
  void _spawnWaste() {
    final wasteConfigs = [
      // plastic
      _WasteConfig(WasteType.plastic,    '🧴', 'Plastic Bottle'),
      _WasteConfig(WasteType.plastic,    '🛍️', 'Plastic Bag'),
      _WasteConfig(WasteType.plastic,    '🥤', 'Drink Cup'),
      // organic
      _WasteConfig(WasteType.organic,    '🍌', 'Banana Peel'),
      _WasteConfig(WasteType.organic,    '👟', 'Old Shoe'),
      _WasteConfig(WasteType.organic,    '👕', 'Torn Shirt'),
      _WasteConfig(WasteType.organic,    '🧦', 'Torn Sock'),
      _WasteConfig(WasteType.organic,    '🍎', 'Rotten Food'),
      // electronic
      _WasteConfig(WasteType.electronic, '📱', 'Old Phone'),
      _WasteConfig(WasteType.electronic, '🔋', 'Battery'),
      _WasteConfig(WasteType.electronic, '💡', 'Light Bulb'),
      // glass — includes broken glass & broken bottle (drawn icons)
      _WasteConfig(WasteType.glass,      '🍶', 'Glass Bottle'),
      _WasteConfig(WasteType.glass,      '🪟', 'Broken Glass'),
      _WasteConfig(WasteType.glass,      'BROKEN_BOTTLE',  'Broken Bottle'),
      _WasteConfig(WasteType.glass,      'SHATTERED_GLASS','Shattered Glass'),
      // metallic
      _WasteConfig(WasteType.metallic,   '🥫', 'Tin Can'),
      _WasteConfig(WasteType.metallic,   '🔩', 'Metal Bolt'),
      _WasteConfig(WasteType.metallic,   '⚙️', 'Old Gear'),
      _WasteConfig(WasteType.metallic,   '🔧', 'Broken Wrench'),
      _WasteConfig(WasteType.metallic,   '🪣', 'Metal Bucket'),
      // general
      _WasteConfig(WasteType.general,    '🗑️', 'Garbage'),
      _WasteConfig(WasteType.general,    '📄', 'Paper'),
    ];

    for (int i = 0; i < 80; i++) {
      final lane   = _rng.nextInt(kLanes);
      final config = wasteConfigs[_rng.nextInt(wasteConfigs.length)];
      // Negative worldY = ahead of truck (above on screen)
      final w = WasteToken(
        worldY:    -(400.0 + i * (150 + _rng.nextDouble() * 250)),
        worldX:    laneCenter(lane) + (_rng.nextDouble() - 0.5) * 28,
        type:      config.type,
        emoji:     config.emoji,
        label:     config.label,
        game:      this,
      );
      add(w);
      wastes.add(w);
    }
  }

  void _spawnTraffic() {
    const spacing = 320.0;
    const kinds   = VehicleKind.values;

    for (int lane = 0; lane < kLanes; lane++) {
      for (int i = 0; i < 4; i++) {
        final kind = kinds[(lane * 4 + i) % kinds.length];
        final c = TrafficCar(
          lane:      lane,
          worldY:    -(spacing * (i + 1) + lane * 60.0),
          worldX:    laneCenter(lane),
          kind:      kind,
          baseSpeed: 55.0 + _rng.nextDouble() * 50,   // 55–105 px/s, slower than player max
          game:      this,
        );
        add(c);
        cars.add(c);
      }
    }
  }

  void _spawnSewers() {
    // Sewers are next to buildings, offset from road edge — not on road
    for (int i = 0; i < kTotalSewers; i++) {
      final onLeft = i.isEven;
      // Place on sidewalk/building-edge side
      final sx = onLeft
          ? roadLeft - kSidewalkW * 0.6
          : roadRight + kSidewalkW * 0.6;
      final leakKind = LeakType.values[i % LeakType.values.length];
      final s = SewerLeak(
        worldY:   -(1000.0 + i * 600),
        worldX:   sx,
        id:       i,
        leakType: leakKind,
        game:     this,
      );
      add(s);
      sewers.add(s);
    }
  }

  void _spawnPeds() {
    for (int i = 0; i < 20; i++) {
      final side = _rng.nextBool();
      final px   = side ? roadLeft - 14 : roadRight + 8;
      final p = SidewalkPed(
        worldY: -(600.0 + i * 420 + _rng.nextDouble() * 200),
        worldX: px,
        game:   this,
      );
      add(p);
      peds.add(p);
    }
  }

  void _showBanner() {
    bannerTimer = 3.5;
    overlays.add('phaseBanner');
  }

  void _onSecond() {
    if (!gameStarted) return;
    if (phase == GamePhase.collection) {
      collectTime -= 1;
      if (collectTime <= 0) {
        collectTime = 0;
        _showCollectionResults(timeExpired: true);
      }
    } else if (phase == GamePhase.sewerRepair) {
      sewerTime -= 1;
      if (sewerTime <= 0 || sewersFixed >= kTotalSewers) {
        sewerTime = math.max(sewerTime, 0);
        _showSewerResults();
      }
    }
    notifyListeners();
  }

  // ── Collection phase ends → show results screen (player must tap Continue) ──
  void _showCollectionResults({bool timeExpired = false}) {
    phase = GamePhase.transitioning;
    speed = 0;
    pauseEngine();
    collectionCollisions = collisionCount;
    collectionEcoPoints  = wasteCollected * 10 - collisionCount * 5;
    ecoPoints            = math.max(0, collectionEcoPoints);
    overlays.add('collectionResults');
    notifyListeners();
  }

  /// Called when the player taps "Continue to Sewer Repair" on the results screen.
  void continueToSewerPhase() {
    overlays.remove('collectionResults');
    resumeEngine();
    _beginTransition();
  }

  void _beginTransition() {
    phase          = GamePhase.transitioning;
    transitioning  = true;
    transitionHold = 4.5;
    speed          = 0;
    overlays.add('phaseTransition');
    notifyListeners();
  }

  void _startSewerPhase() {
    phase         = GamePhase.sewerRepair;
    transitioning = false;
    overlays.remove('phaseTransition');
    // Reset collision count to track sewer-phase collisions separately
    collisionCount = 0;
    for (int i = 0; i < sewers.length; i++) {
      sewers[i].isVisible      = true;
      sewers[i].worldY         = -(worldScroll + 500 + i * 550.0);
      sewers[i].repairProgress = 0;
      sewers[i].isRepaired     = false;
    }
    // Respawn traffic for sewer phase
    _respawnTrafficForSewerPhase();
    _showBanner();
    notifyListeners();
  }

  void _respawnTrafficForSewerPhase() {
    for (int i = 0; i < cars.length; i++) {
      final c = cars[i];
      c.crashed    = false;
      c.crashTimer = 0;
      c.worldY     = -(worldScroll + 400 + i * 280.0 + _rng.nextDouble() * 200);
      c.worldX     = laneCenter(c.lane);
    }
  }

  // ── Sewer phase ends → show sewer results screen ──
  void _showSewerResults() {
    phase = GamePhase.transitioning;
    speed = 0;
    pauseEngine();
    sewerCollisions  = collisionCount;
    sewerEcoPoints   = math.max(0, sewersFixed * 50 - collisionCount * 20);
    ecoPoints        = math.max(0, collectionEcoPoints + sewerEcoPoints);
    overlays.add('sewerResults');
    notifyListeners();
  }

  /// Called when the player taps "View Full Summary" on the sewer results screen.
  void continueToGrandFinale() {
    overlays.remove('sewerResults');
    _endLevel();
  }

  void _endLevel() {
    phase = GamePhase.transitioning;
    ecoPoints = math.max(0, collectionEcoPoints + sewerEcoPoints);
    overlays.add('gameOver');
  }

  // input
  void setDrive(bool v)    { isDriving = v; if (v && !gameStarted) gameStarted = true; }
  void setBrake(bool v)    => isBraking   = v;
  void setLeft(bool v)     => isLeft      = v;
  void setRight(bool v)    => isRight     = v;
  void setReverse(bool v)  { isReversing = v; if (v && !gameStarted) gameStarted = true; }
  void setTilt(double x)   => tiltX = x.clamp(-1.0, 1.0);
  void selectTool(RepairTool t) {
    selectedTool = t;
    toolboxOpen  = false;
    overlays.remove('toolbox');
    notifyListeners();
  }
  void openToolbox() {
    toolboxOpen = true;
    overlays.add('toolbox');
    notifyListeners();
  }
  void closeToolbox() {
    toolboxOpen = false;
    overlays.remove('toolbox');
    notifyListeners();
  }

  // ════════════════════════════════════════════════════════════════════
  @override
  void update(double dt) {
    super.update(dt);

    if (bannerTimer > 0) {
      bannerTimer -= dt;
      if (bannerTimer <= 0) overlays.remove('phaseBanner');
    }

    if (crashTimer > 0) {
      crashTimer -= dt;
      if (crashTimer <= 0) { crashActive = false; overlays.remove('collisionFlash'); }
    }

    if (transitioning) {
      transitionHold -= dt;
      if (transitionHold <= 0) _startSewerPhase();
      return;
    }
    if (!gameStarted) return;

    // ── Speed / gear ────────────────────────────────────────────────────
    if (isDriving && !isBraking && !isReversing) {
      speed = math.min(speed + accel * dt, maxSpeed);
    } else if (isReversing && !isDriving) {
      speed = math.max(speed - accel * dt, -maxReverse);
    } else if (isBraking) {
      // Braking brings speed toward zero from either direction
      if (speed > 0) {
        speed = math.max(speed - brakeForce * dt, 0);
      } else {
        speed = math.min(speed + brakeForce * dt, 0);
      }
    } else {
      // Natural drag
      if (speed > 0) {
        speed = math.max(speed - drag * dt, 0);
      } else {
        speed = math.min(speed + drag * dt, 0);
      }
    }

    // ── Steering — buttons OR tilt, both work simultaneously with drive ──
    // Tilt input: magnitude proportional to lean angle (deadzone ±0.08)
    double steerInput = 0.0;
    if (isLeft)  steerInput -= 1.0;
    if (isRight) steerInput += 1.0;
    // Tilt overrides button steer only if tilt is strong enough
    if (tiltX.abs() > 0.08 && !isLeft && !isRight) {
      steerInput = tiltX;
    }

    if (steerInput != 0.0) {
      // Allow steering even at speed (forward+steer simultaneously = lane switch)
      final leanDir  = steerInput.sign;
      truckPos.x    += lateralRate * steerInput * dt;
      truckLean      = 0.18 * leanDir;
    } else {
      truckLean *= 0.82;
    }
    truckPos.x = truckPos.x.clamp(roadLeft + 18, roadRight - 18);

    // World scrolls: positive = truck moves upward on screen
    worldScroll += speed * dt;

    if (phase == GamePhase.collection)  _checkPickups();
    _checkCarCrashes();
    if (phase == GamePhase.sewerRepair) _checkRepairs(dt);

    // recycle off-screen waste only during collection phase
    if (phase == GamePhase.collection) {
      for (var w in wastes) {
        if (!w.isCollected && toScreenY(w.worldY) > size.y + 100) {
          w.worldY = -(worldScroll + 400 + _rng.nextDouble() * 2000);
        }
      }
    }
    for (var p in peds) {
      if (toScreenY(p.worldY) > size.y + 80) {
        p.worldY = -(worldScroll + 300 + _rng.nextDouble() * 700);
      }
    }
  }

  void _checkPickups() {
    for (var w in wastes) {
      if (w.isCollected) continue;
      final sy = toScreenY(w.worldY);
      if ((w.worldX - truckPos.x).abs() < 36 && (sy - truckPos.y).abs() < 36) {
        w.isCollected = true;
        wasteCollected++;
        switch (w.type) {
          case WasteType.plastic:    plasticCollected++;    break;
          case WasteType.organic:    organicCollected++;    break;
          case WasteType.electronic: electronicCollected++; break;
          case WasteType.glass:      glassCollected++;      break;
          case WasteType.general:    generalCollected++;    break;
          case WasteType.metallic:   metallicCollected++;   break;
        }
        notifyListeners();
      }
    }
  }

  void _checkCarCrashes() {
    // Only player truck ↔ traffic car collisions; car-to-car handled by TrafficCar AI
    for (var c in cars) {
      if (c.crashed) continue;
      final sy  = toScreenY(c.worldY);
      final vhl = TrafficCar.halfLengthFor(c.kind);  // half vehicle length
      final vhw = TrafficCar.halfWidthFor(c.kind);   // half vehicle width
      if ((c.worldX - truckPos.x).abs() < (vhw + 18) &&
          (sy - truckPos.y).abs() < (vhl + 30)) {
        _triggerCrash();
        c.crashed    = true;
        c.crashTimer = 2.0;
        speed       *= 0.15;
      }
    }
  }

  void _checkRepairs(double dt) {
    for (var s in sewers) {
      if (!s.isVisible || s.isRepaired) continue;
      final sy = toScreenY(s.worldY);
      final inRange = (s.worldX - truckPos.x).abs() < 55 &&
                      (sy - truckPos.y).abs() < 55;
      final stopped = speed < 20;   // must be nearly stopped

      // Reset the selected tool the first time the truck stops near each NEW sewer,
      // so a previously-selected tool from the last sewer doesn't carry over and
      // instantly fire "wrong tool" before the player can open the toolbox.
      if (inRange && stopped && !s._truckWasHere) {
        s._truckWasHere = true;
        selectedTool = RepairTool.none;
        notifyListeners();
      }
      if (!inRange) s._truckWasHere = false;

      if (inRange && stopped) {
        final correct = _correctToolFor(s.leakType);
        s.activelyRepairing = true;
        s.wrongTool = false;

        if (selectedTool == RepairTool.none) {
          // No tool selected — no progress, show prompt
          s.activelyRepairing = false;
          s.showToolPrompt = true;
        } else if (selectedTool != correct) {
          // Wrong tool — progress RESETS back, show wrong tool feedback
          s.repairProgress = math.max(0, s.repairProgress - dt * 0.5);
          s.wrongTool = true;
          s.activelyRepairing = false;
          s.showToolPrompt = false;
        } else {
          // Correct tool — progress advances
          s.showToolPrompt = false;
          s.repairProgress += dt * 0.45;
          if (s.repairProgress >= 1.0) {
            s.isRepaired        = true;
            s.activelyRepairing = false;
            s.wrongTool         = false;
            sewersFixed++;
            ecoPoints += 50;
            notifyListeners();
            if (sewersFixed >= kTotalSewers) { _endLevel(); }
          }
        }
      } else {
        // Out of range — decay progress slowly and clear states
        s.repairProgress    = math.max(0, s.repairProgress - dt * 0.28);
        s.activelyRepairing = false;
        s.wrongTool         = false;
        s.showToolPrompt    = false;
      }
    }
  }

  RepairTool correctToolFor(LeakType t) {
    switch (t) {
      case LeakType.pipe:   return RepairTool.wrench;
      case LeakType.joint:  return RepairTool.plumbingTape;
      case LeakType.crack:  return RepairTool.sealant;
    }
  }

  // keep private alias so _checkRepairs still works
  RepairTool _correctToolFor(LeakType t) => correctToolFor(t);

  void _triggerCrash() {
    if (crashActive) return;
    crashActive    = true;
    crashTimer     = 1.8;
    collisionCount++;
    if (phase == GamePhase.collection) {
      collectTime = math.max(0, collectTime - 8);
    } else {
      sewerTime = math.max(0, sewerTime - 8);
    }
    overlays.add('collisionFlash');
    notifyListeners();
  }
}

// small data class for waste configuration
class _WasteConfig {
  final WasteType type; final String emoji, label;
  _WasteConfig(this.type, this.emoji, this.label);
}

// ══════════════════════════════════════════════════════════════════════
//  CITY WORLD RENDERER  — scrolling road, buildings, sidewalks
// ══════════════════════════════════════════════════════════════════════
class CityWorldRenderer extends Component {
  final CityCollectionGame game;
  final math.Random _rng = math.Random(42);
  final List<_Block>  _leftBlocks  = [];
  final List<_Block>  _rightBlocks = [];
  final List<_Decal>  _decals      = [];

  CityWorldRenderer({required this.game});

  @override
  Future<void> onLoad() async {
    double top = 0.0;
    while (top < 28000) {
      final h = 220.0 + _rng.nextDouble() * 280;
      _leftBlocks.add(_Block(
        isLeft: true,
        worldTop: top,
        w: 90 + _rng.nextDouble() * 50,
        h: h,
        seed: _rng.nextInt(9999),
        floors: 3 + _rng.nextInt(10),
        style: _rng.nextInt(4),
      ));
      _rightBlocks.add(_Block(
        isLeft: false,
        worldTop: top,
        w: 90 + _rng.nextDouble() * 50,
        h: h,
        seed: _rng.nextInt(9999),
        floors: 3 + _rng.nextInt(10),
        style: _rng.nextInt(4),
      ));
      top += h + 30 + _rng.nextDouble() * 60;
    }
    for (int i = 0; i < 60; i++) {
      _decals.add(_Decal(worldY: -(200.0 + i * 380), type: _rng.nextInt(3)));
    }
  }

  @override
  void render(Canvas canvas) {
    final roadL = game.roadLeft;
    final sz    = game.size;

    // Sky gradient (top part for ambience)
    final skyPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, 0), Offset(0, sz.y * 0.3),
        [const Color(0xFF1A1A2E), const Color(0xFF16213E)],
      );
    canvas.drawRect(Rect.fromLTWH(0, 0, sz.x, sz.y), skyPaint);

    // Sidewalk left
    canvas.drawRect(
      Rect.fromLTWH(roadL - kSidewalkW, 0, kSidewalkW, sz.y),
      Paint()..color = const Color(0xFF3A3A3A),
    );
    // Sidewalk right
    canvas.drawRect(
      Rect.fromLTWH(game.roadRight, 0, kSidewalkW, sz.y),
      Paint()..color = const Color(0xFF3A3A3A),
    );
    // Sidewalk kerb lines
    _drawKerbLine(canvas, roadL - kSidewalkW, sz.y);
    _drawKerbLine(canvas, game.roadRight + kSidewalkW, sz.y);

    // Road surface
    final roadPaint = Paint()..color = const Color(0xFF242424);
    canvas.drawRect(Rect.fromLTWH(roadL, 0, kRoadW, sz.y), roadPaint);

    // Road edge white lines
    canvas.drawRect(Rect.fromLTWH(roadL, 0, 3, sz.y), Paint()..color = const Color(0xCCFFFFFF));
    canvas.drawRect(Rect.fromLTWH(game.roadRight - 3, 0, 3, sz.y), Paint()..color = const Color(0xCCFFFFFF));

    // Road texture: tarmac grain
    _drawTarmacGrain(canvas, roadL, sz);

    _drawLaneDividers(canvas, roadL, sz.y);
    _drawCrosswalks(canvas, roadL);

    // Road decals
    for (var d in _decals) {
      final sy = game.toScreenY(d.worldY);
      if (sy < -40 || sy > sz.y + 40) continue;
      _drawDecal(canvas, d, roadL, sy);
    }

    // Buildings (drawn like side facades from top-down perspective)
    for (var b in _leftBlocks) {
      final sy = game.toScreenY(b.worldTop);
      if (sy < -b.h - 20 || sy > sz.y + 20) continue;
      _drawBuilding(canvas, b, roadL - kSidewalkW - b.w, sy);
    }
    for (var b in _rightBlocks) {
      final sy = game.toScreenY(b.worldTop);
      if (sy < -b.h - 20 || sy > sz.y + 20) continue;
      _drawBuilding(canvas, b, game.roadRight + kSidewalkW, sy);
    }

    // Sidewalk details (utility poles, fire hydrants)
    _drawSidewalkDetails(canvas, roadL, sz);
  }

  void _drawKerbLine(Canvas canvas, double x, double height) {
    canvas.drawRect(
      Rect.fromLTWH(x - 1.5, 0, 3, height),
      Paint()..color = const Color(0xFFBBBBBB),
    );
  }

  void _drawTarmacGrain(Canvas canvas, double roadL, Vector2 sz) {
    final grainPaint = Paint()..color = const Color(0x0AFFFFFF)..strokeWidth = 1;
    final rng = math.Random(7);
    for (int i = 0; i < 80; i++) {
      final x = roadL + rng.nextDouble() * kRoadW;
      final y = rng.nextDouble() * sz.y;
      canvas.drawCircle(Offset(x, y), rng.nextDouble() * 1.5, grainPaint);
    }
  }

  void _drawBuilding(Canvas canvas, _Block b, double left, double screenTop) {
    final rng  = math.Random(b.seed);
    final rect = Rect.fromLTWH(left, screenTop, b.w, b.h);

    // Building shadow (cast slightly onto road/sidewalk side)
    final shadowPaint = Paint()..color = const Color(0x44000000);
    canvas.drawRect(rect.translate(6, 8), shadowPaint);

    // Foundation / base
    canvas.drawRect(rect, Paint()..color = const Color(0xFF1A1A1A));

    // Facade colour palette (varied, realistic city hues)
    const facades = [
      Color(0xFF2C3E50), Color(0xFF8B4513), Color(0xFF4A5568),
      Color(0xFF2D3748), Color(0xFF553322), Color(0xFF1A2744),
      Color(0xFF3D4A2A), Color(0xFF4A2A44), Color(0xFF2A3A4A),
    ];
    final facadeCol = facades[rng.nextInt(facades.length)];

    // Main facade
    canvas.drawRect(
      rect.deflate(2),
      Paint()..color = facadeCol,
    );

    // Windows — realistic grid
    final winCols  = 2 + rng.nextInt(3);
    final winRows  = b.floors.clamp(2, 8);
    const padX = 8.0, padY = 12.0;
    final winW = (b.w - padX * (winCols + 1)) / winCols;
    final winH = (b.h - padY * (winRows + 1)) / winRows;

    for (int row = 0; row < winRows; row++) {
      for (int col = 0; col < winCols; col++) {
        final wx = left + padX + col * (winW + padX);
        final wy = screenTop + padY + row * (winH + padY);
        if (wx + winW > left + b.w - 4 || wy + winH > screenTop + b.h - 4) continue;

        // Window frame
        canvas.drawRect(
          Rect.fromLTWH(wx - 1, wy - 1, winW + 2, winH + 2),
          Paint()..color = const Color(0xFF0A0A0A),
        );

        // Window glass — lit or dark
        final isLit  = rng.nextDouble() > 0.35;
        final winCol = isLit
            ? (rng.nextDouble() > 0.6
                ? const Color(0xBBFFEEBB)
                : const Color(0x99AADDFF))
            : const Color(0xFF111827);
        canvas.drawRect(Rect.fromLTWH(wx, wy, winW, winH), Paint()..color = winCol);

        // Curtain / blind effect on some lit windows
        if (isLit && rng.nextDouble() > 0.6) {
          canvas.drawRect(
            Rect.fromLTWH(wx, wy, winW, winH * 0.4),
            Paint()..color = const Color(0x55FFFFFF),
          );
        }
        // Reflection gleam
        if (isLit) {
          canvas.drawRect(
            Rect.fromLTWH(wx, wy, 3, winH),
            Paint()..color = const Color(0x33FFFFFF),
          );
        }
      }
    }

    // Rooftop details based on style
    final roofY = screenTop - 6;
    switch (b.style) {
      case 0: // Flat rooftop with parapet + HVAC
        canvas.drawRect(Rect.fromLTWH(left, roofY, b.w, 8), Paint()..color = facadeCol.withValues(alpha: 0.7));
        // HVAC box
        canvas.drawRect(
          Rect.fromLTWH(left + b.w * 0.55, roofY - 8, 18, 10),
          Paint()..color = const Color(0xFF4A5568),
        );
        break;
      case 1: // Water tower
        final towerX = left + b.w * 0.3;
        // Tank
        canvas.drawOval(Rect.fromLTWH(towerX - 8, roofY - 14, 16, 12),
            Paint()..color = const Color(0xFF5C3317));
        // Legs
        final legPaint = Paint()..color = const Color(0xFF3C2816)..strokeWidth = 2;
        canvas.drawLine(Offset(towerX - 5, roofY - 6), Offset(towerX - 8, roofY + 2), legPaint);
        canvas.drawLine(Offset(towerX + 5, roofY - 6), Offset(towerX + 8, roofY + 2), legPaint);
        break;
      case 2: // Solar panels
        final sp = Paint()..color = const Color(0xFF1A3858);
        for (int s = 0; s < 4; s++) {
          canvas.drawRect(Rect.fromLTWH(left + 6 + s * 14.0, roofY - 10, 12, 8), sp);
          canvas.drawLine(Offset(left + 6 + s * 14.0 + 6, roofY - 10),
              Offset(left + 6 + s * 14.0 + 6, roofY - 2),
              Paint()..color = const Color(0xFF2A4A68)..strokeWidth = 1);
        }
        break;
      case 3: // Antenna / billboard
        canvas.drawLine(
          Offset(left + b.w * 0.5, roofY),
          Offset(left + b.w * 0.5, roofY - 20),
          Paint()..color = const Color(0xFF888888)..strokeWidth = 2,
        );
        canvas.drawRect(
          Rect.fromLTWH(left + b.w * 0.38, roofY - 26, b.w * 0.24, 8),
          Paint()..color = const Color(0xFFDD4411),
        );
        break;
    }

    // Graffiti / pollution stains on lower floors
    if (rng.nextDouble() < 0.4) {
      final graffitiPaint = Paint()
        ..color = const Color(0x55FF4400)
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke;
      canvas.drawArc(
        Rect.fromLTWH(left + 4, screenTop + b.h - 30, 20, 20),
        0, math.pi * 1.5, false, graffitiPaint,
      );
    }

    // Building outline
    canvas.drawRect(
      rect,
      Paint()
        ..color = const Color(0x22FFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // Streetlamp next to building base (on sidewalk)
    if (rng.nextDouble() < 0.5) {
      final lampX = b.isLeft ? left + b.w + 6 : left - 6;
      final lampY = screenTop + b.h + 5;
      // Pole
      canvas.drawRect(Rect.fromLTWH(lampX - 1, lampY - 22, 2, 22), Paint()..color = const Color(0xFF666666));
      // Arm
      canvas.drawLine(Offset(lampX, lampY - 22), Offset(lampX + (b.isLeft ? 8 : -8), lampY - 25),
          Paint()..color = const Color(0xFF777777)..strokeWidth = 1.5);
      // Light (orange glow)
      canvas.drawCircle(
        Offset(lampX + (b.isLeft ? 8 : -8), lampY - 25), 4,
        Paint()..color = const Color(0xFFFFAA44)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }
  }

  void _drawSidewalkDetails(Canvas canvas, double roadL, Vector2 sz) {
    final rng = math.Random(13);
    for (int i = 0; i < 30; i++) {
      final worldY = -(i * 400.0 + 200);
      final sy = game.toScreenY(worldY);
      if (sy < -20 || sy > sz.y + 20) continue;

      // Left fire hydrant
      if (rng.nextDouble() < 0.3) {
        final hx = roadL - kSidewalkW * 0.5;
        canvas.drawRect(Rect.fromLTWH(hx - 4, sy - 6, 8, 10), Paint()..color = const Color(0xFFCC2200));
        canvas.drawRect(Rect.fromLTWH(hx - 5, sy - 8, 10, 4), Paint()..color = const Color(0xFFDD3311));
      }
      // Right fire hydrant
      if (rng.nextDouble() < 0.3) {
        final hx = game.roadRight + kSidewalkW * 0.5;
        canvas.drawRect(Rect.fromLTWH(hx - 4, sy - 6, 8, 10), Paint()..color = const Color(0xFFCC2200));
        canvas.drawRect(Rect.fromLTWH(hx - 5, sy - 8, 10, 4), Paint()..color = const Color(0xFFDD3311));
      }
    }
  }

  void _drawLaneDividers(Canvas canvas, double roadL, double screenH) {
    final dash = Paint()
      ..color = const Color(0xAAEEEEEE)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    const len    = 42.0;
    const gap    = 24.0;
    const period = len + gap;

    for (int lane = 1; lane < kLanes; lane++) {
      final x      = roadL + 18 + lane * kLaneW;
      final offset = game.worldScroll % period;
      double y     = -period + offset;
      while (y < screenH + period) {
        canvas.drawLine(Offset(x, y), Offset(x, y + len), dash);
        y += period;
      }
    }
    // Centre double yellow line
    final mid    = roadL + kRoadW / 2;
    final yellow = Paint()..color = const Color(0xCCFFCC00)..strokeWidth = 2;
    double y2    = -(period) + game.worldScroll % period;
    while (y2 < screenH + period) {
      canvas.drawLine(Offset(mid - 2, y2), Offset(mid - 2, y2 + len), yellow);
      canvas.drawLine(Offset(mid + 2, y2), Offset(mid + 2, y2 + len), yellow);
      y2 += period;
    }
  }

  void _drawDecal(Canvas canvas, _Decal d, double roadL, double sy) {
    final mid = roadL + kRoadW / 2;
    final dp  = Paint()..color = const Color(0x44FFFFFF);
    switch (d.type) {
      case 0: // Forward arrow (pointing up = truck direction)
        final p = Path()
          ..moveTo(mid, sy + 18)   ..lineTo(mid + 11, sy - 10)
          ..lineTo(mid, sy - 3)    ..lineTo(mid - 11, sy - 10)
          ..close();
        canvas.drawPath(p, dp);
        break;
      case 1: // Speed-limit circle
        canvas.drawCircle(Offset(mid, sy), 16,
            Paint()..color = const Color(0x44FFFFFF)..style = PaintingStyle.stroke..strokeWidth = 2.5);
        break;
      case 2: // Hazard diamond
        final p2 = Path()
          ..moveTo(mid, sy - 14) ..lineTo(mid + 14, sy)
          ..lineTo(mid, sy + 14) ..lineTo(mid - 14, sy)
          ..close();
        canvas.drawPath(p2,
            Paint()..color = const Color(0x55FFD700)..style = PaintingStyle.stroke..strokeWidth = 2);
        break;
    }
  }

  void _drawCrosswalks(Canvas canvas, double roadL) {
    final cw = Paint()..color = const Color(0x55EEEEEE);
    for (int i = 0; i < 24; i++) {
      final sy = game.toScreenY(-(i * 640.0 + 320));
      if (sy < -26 || sy > game.size.y + 26) continue;
      for (int s = 0; s < 7; s++) {
        canvas.drawRect(Rect.fromLTWH(roadL, sy - 26 + s * 7.4, kRoadW, 4.5), cw);
      }
    }
  }
}

class _Block {
  final bool   isLeft;
  final double worldTop, w, h;
  final int    seed, floors, style;
  _Block({required this.isLeft, required this.worldTop,
    required this.w, required this.h, required this.seed,
    required this.floors, required this.style});
}
class _Decal { final double worldY; final int type;
  _Decal({required this.worldY, required this.type}); }

// ══════════════════════════════════════════════════════════════════════
//  TOP-DOWN TRUCK
//  Orange cabin at BOTTOM (rear view as truck moves upward).
//  Green cargo container fills as player collects waste.
// ══════════════════════════════════════════════════════════════════════
class TopDownTruck extends Component {
  final CityCollectionGame game;
  double _bob = 0.0;
  static const double _tw = 36.0, _th = 62.0;

  TopDownTruck({required this.game});

  @override
  void update(double dt) => _bob += dt * game.speed * 0.046;

  @override
  void render(Canvas canvas) {
    final cx   = game.truckPos.x;
    final cy   = game.truckPos.y;
    final bobY = math.sin(_bob) * (game.speed > 8 ? 1.4 : 0.0);

    canvas.save();
    canvas.translate(cx, cy + bobY);
    canvas.transform(Matrix4.rotationZ(game.truckLean).storage);

    // Drop shadow
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(-_tw/2+5, -_th/2+7, _tw, _th), const Radius.circular(8)),
      Paint()..color = const Color(0x66000000),
    );

    // Truck moves UPWARD on screen, so:
    //   TOP of sprite  = FRONT of truck  → orange cabin + headlights here
    //   BOTTOM of sprite = BACK of truck → green cargo container + tail-lights + exhaust here

    // ── Orange cabin (TOP = front, facing direction of travel = UP) ──
    const cabH   = _th * 0.38;
    const cabTop = -_th / 2;           // top edge of whole sprite

    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(-_tw/2 + 1, cabTop, _tw - 2, cabH), const Radius.circular(6)),
      Paint()..color = const Color(0xFFE65100),
    );

    // Windshield (at very top of cab = front of truck)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(-_tw/2 + 5, cabTop + 4, _tw - 10, 12), const Radius.circular(3)),
      Paint()..color = const Color(0x8855AADD),
    );
    // Windshield glare
    canvas.drawLine(
      Offset(-_tw/2 + 7, cabTop + 5),
      Offset(-_tw/2 + 11, cabTop + 14),
      Paint()..color = const Color(0x44FFFFFF)..strokeWidth = 2,
    );

    // Headlights (front = TOP of sprite)
    final hl = Paint()
      ..color = const Color(0xFFFFEE88)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.drawCircle(Offset(-_tw/2 + 6, cabTop + 3), 5, hl);
    canvas.drawCircle(Offset( _tw/2 - 6, cabTop + 3), 5, hl);

    // Cabin orange accent stripe
    canvas.drawRect(
      Rect.fromLTWH(-_tw/2 + 3, cabTop + cabH - 5, _tw - 6, 3),
      Paint()..color = const Color(0xFFFF6D00),
    );

    // ── Green cargo container (BOTTOM = rear of truck) ──
    const cargoTop = cabTop + cabH;    // starts just below cabin
    const cargoH   = _th - cabH;

    // Container shell
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(-_tw/2, cargoTop, _tw, cargoH), const Radius.circular(5)),
      Paint()..color = const Color(0xFF1B5E20),
    );

    // Fill level (waste fills upward from bottom of container)
    final fillH = cargoH * game.cargoFill;
    final fillY = cargoTop + cargoH - fillH;
    if (fillH > 0) {
      canvas.save();
      canvas.clipRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(-_tw/2 + 2, cargoTop + 2, _tw - 4, cargoH - 4),
          const Radius.circular(3)));
      canvas.drawRect(
        Rect.fromLTWH(-_tw/2 + 2, fillY, _tw - 4, fillH),
        Paint()..color = const Color(0xFF4CAF50),
      );
      // Coloured waste flecks
      final wasteFleck = Paint()..strokeWidth = 2;
      final fleckRng   = math.Random(42);
      for (int f = 0; f < (game.cargoFill * 8).round(); f++) {
        wasteFleck.color = [
          const Color(0xFF2196F3), const Color(0xFF8BC34A),
          const Color(0xFFFF9800), const Color(0xFF9E9E9E),
          const Color(0xFF00BCD4),
        ][fleckRng.nextInt(5)];
        final fx = -_tw/2 + 4 + fleckRng.nextDouble() * (_tw - 8);
        final fy = fillY + 3 + fleckRng.nextDouble() * (fillH - 6);
        canvas.drawCircle(Offset(fx, fy), 2.5, wasteFleck);
      }
      canvas.restore();
    }

    // Container divider lines
    final divP = Paint()
      ..color = const Color(0xFF0A3A00)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    for (int i = 1; i < 4; i++) {
      final lx = -_tw/2 + 2 + (_tw - 4) * i / 4;
      canvas.drawLine(Offset(lx, cargoTop + 2), Offset(lx, cargoTop + cargoH - 2), divP);
    }

    // Recycle symbol on cargo face
    final rp = Paint()..color = const Color(0x88FFFFFF)..strokeWidth = 1.6..style = PaintingStyle.stroke;
    canvas.save();
    canvas.translate(0, cargoTop + cargoH * 0.42);
    canvas.scale(0.85, 0.85);
    for (int i = 0; i < 3; i++) {
      canvas.save();
      canvas.rotate(i * 2 * math.pi / 3);
      final path = Path()
        ..moveTo(0, -7)      ..lineTo(3, -2.5)
        ..lineTo(1.6, -2.5)  ..lineTo(1.6, 3)
        ..lineTo(-1.6, 3)    ..lineTo(-1.6, -2.5)
        ..lineTo(-3, -2.5)   ..close();
      canvas.drawPath(path, rp);
      canvas.restore();
    }
    canvas.restore();

    // Tail-lights (rear = BOTTOM of sprite)
    canvas.drawRect(Rect.fromLTWH(-_tw/2 + 2, _th/2 - 6, 6, 4),
        Paint()..color = const Color(0xFFBB2222));
    canvas.drawRect(Rect.fromLTWH( _tw/2 - 8, _th/2 - 6, 6, 4),
        Paint()..color = const Color(0xFFBB2222));

    // 4 wheels (corner black ovals)
    final wp = Paint()..color = const Color(0xFF0D0D0D);
    for (final wr in [
      Rect.fromLTWH(-_tw/2 - 5, -_th/2 + 8,  7, 11),  // front-left
      Rect.fromLTWH( _tw/2 - 2, -_th/2 + 8,  7, 11),  // front-right
      Rect.fromLTWH(-_tw/2 - 5,  _th/2 - 18, 7, 11),  // rear-left
      Rect.fromLTWH( _tw/2 - 2,  _th/2 - 18, 7, 11),  // rear-right
    ]) {
      canvas.drawRRect(RRect.fromRectAndRadius(wr, const Radius.circular(3)), wp);
      canvas.drawRRect(
        RRect.fromRectAndRadius(wr.deflate(1.5), const Radius.circular(2)),
        Paint()..color = const Color(0xFF555555)..style = PaintingStyle.stroke..strokeWidth = 1,
      );
    }

    // Exhaust puffs trail behind truck (BOTTOM = rear)
    if (game.speed > 40) {
      final ep = Paint()
        ..color = const Color(0x55888888)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawCircle(Offset(-6, _th/2 + 6),  8, ep);
      canvas.drawCircle(Offset( 6, _th/2 + 10), 5, ep);
    }

    canvas.restore();
  }
}

// ══════════════════════════════════════════════════════════════════════
//  WASTE TOKEN — Scattered on road with realistic icons
// ══════════════════════════════════════════════════════════════════════
class WasteToken extends Component {
  double worldY, worldX;
  final WasteType type;
  final String    emoji, label;
  final CityCollectionGame game;
  bool    isCollected = false;
  double  _pulse      = 0.0;
  static const double _sz = 26.0;

  WasteToken({required this.worldY, required this.worldX,
    required this.type, required this.emoji, required this.label,
    required this.game});

  Color get _col {
    switch (type) {
      case WasteType.plastic:    return const Color(0xFF2196F3);
      case WasteType.organic:    return const Color(0xFF4CAF50);
      case WasteType.electronic: return const Color(0xFFF97316);
      case WasteType.glass:      return const Color(0xFF00BCD4);
      case WasteType.general:    return const Color(0xFF9E9E9E);
      case WasteType.metallic:   return const Color(0xFFB0BEC5);
    }
  }

  @override void update(double dt) => _pulse += dt * 3.2;

  @override
  void render(Canvas canvas) {
    if (isCollected) return;
    // Waste items are not shown during sewer repair phase
    if (game.phase == GamePhase.sewerRepair) return;
    final sy = game.toScreenY(worldY);
    if (sy < -44 || sy > game.size.y + 44) return;

    final glow = 0.22 + math.sin(_pulse) * 0.12;

    // Shadow beneath item
    canvas.drawOval(
      Rect.fromLTWH(worldX - _sz * 0.4, sy + _sz * 0.3, _sz * 0.8, _sz * 0.3),
      Paint()..color = const Color(0x44000000),
    );

    // Glow halo
    canvas.drawCircle(
      Offset(worldX, sy), _sz * 0.7,
      Paint()..color = _col.withValues(alpha: glow)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // Type colour ring
    canvas.drawCircle(Offset(worldX, sy), _sz * 0.48,
        Paint()..color = _col.withValues(alpha: 0.85));
    canvas.drawCircle(Offset(worldX, sy), _sz * 0.48,
        Paint()..color = Colors.white.withValues(alpha: 0.2)
            ..style = PaintingStyle.stroke..strokeWidth = 1.5);

    // Custom drawn icons for glass items, otherwise use emoji
    if (emoji == 'BROKEN_BOTTLE') {
      _drawBrokenBottleIcon(canvas, worldX, sy);
    } else if (emoji == 'SHATTERED_GLASS') {
      _drawShatteredGlassIcon(canvas, worldX, sy);
    } else {
      // Emoji drawn as text
      final tp = TextPainter(
        text: TextSpan(text: emoji, style: const TextStyle(fontSize: 14)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(worldX - tp.width / 2, sy - tp.height / 2));
    }

    // Small type indicator dot top-right
    canvas.drawCircle(Offset(worldX + _sz * 0.34, sy - _sz * 0.34), 3.5,
        Paint()..color = _col);
  }

  /// Draws a broken glass bottle icon (top-down view, cyan shards).
  void _drawBrokenBottleIcon(Canvas canvas, double cx, double cy) {
    final p = Paint()
      ..color = const Color(0xFF80DEEA)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final pFill = Paint()..color = const Color(0x5500BCD4);
    // Bottle body (broken lower half)
    final body = Path()
      ..moveTo(cx - 4, cy - 8)
      ..lineTo(cx - 5, cy + 2)
      ..lineTo(cx - 2, cy + 8)
      ..lineTo(cx + 3, cy + 7)
      ..lineTo(cx + 5, cy + 1)
      ..lineTo(cx + 4, cy - 7)
      ..close();
    canvas.drawPath(body, pFill);
    canvas.drawPath(body, p);
    // Neck stump
    canvas.drawLine(Offset(cx - 2, cy - 8), Offset(cx - 1, cy - 11), p);
    canvas.drawLine(Offset(cx + 2, cy - 7), Offset(cx + 1, cy - 11), p);
    // Crack lines
    final cP = Paint()..color = const Color(0xBBE0F7FA)..strokeWidth = 1..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(cx, cy - 4), Offset(cx - 3, cy + 2), cP);
    canvas.drawLine(Offset(cx, cy - 4), Offset(cx + 4, cy + 3), cP);
    canvas.drawLine(Offset(cx + 4, cy + 3), Offset(cx + 2, cy + 7), cP);
    // Glass shard fragments (small triangles scattered)
    final shard = Paint()..color = const Color(0xAA80DEEA);
    for (final off in [
      Offset(cx - 7, cy + 5), Offset(cx + 7, cy + 4), Offset(cx - 5, cy - 2)
    ]) {
      final sh = Path()
        ..moveTo(off.dx, off.dy - 3)
        ..lineTo(off.dx - 2.5, off.dy + 3)
        ..lineTo(off.dx + 2.5, off.dy + 2)
        ..close();
      canvas.drawPath(sh, shard);
      canvas.drawPath(sh, Paint()..color = const Color(0x8800BCD4)
          ..style = PaintingStyle.stroke..strokeWidth = 0.8);
    }
  }

  /// Draws shattered glass pane (flat on road, star-burst crack pattern).
  void _drawShatteredGlassIcon(Canvas canvas, double cx, double cy) {
    final glassBase = Paint()..color = const Color(0x3300E5FF);
    final glassEdge = Paint()..color = const Color(0xFF80DEEA)
        ..strokeWidth = 1.2..style = PaintingStyle.stroke;
    final crackP = Paint()..color = const Color(0xBBE0F7FA)
        ..strokeWidth = 1..strokeCap = StrokeCap.round;

    // Irregular glass pane outline
    final pane = Path()
      ..moveTo(cx - 9, cy - 7)
      ..lineTo(cx + 5, cy - 9)
      ..lineTo(cx + 9, cy - 2)
      ..lineTo(cx + 7, cy + 8)
      ..lineTo(cx - 4, cy + 9)
      ..lineTo(cx - 9, cy + 3)
      ..close();
    canvas.drawPath(pane, glassBase);
    canvas.drawPath(pane, glassEdge);

    // Star-burst cracks radiating from impact point
    final impact = Offset(cx + 1, cy);
    final rays = [
      Offset(cx - 8, cy - 5), Offset(cx + 4, cy - 8), Offset(cx + 8, cy + 2),
      Offset(cx + 5, cy + 7), Offset(cx - 3, cy + 8), Offset(cx - 8, cy + 2),
    ];
    for (final ray in rays) {
      canvas.drawLine(impact, ray, crackP);
    }
    // Secondary crack branches
    canvas.drawLine(Offset(cx - 3, cy - 3), Offset(cx - 7, cy - 1), crackP);
    canvas.drawLine(Offset(cx + 4, cy - 2), Offset(cx + 7, cy - 6), crackP);
    canvas.drawLine(Offset(cx + 2, cy + 4), Offset(cx - 2, cy + 7), crackP);

    // Small detached shards
    final shardP = Paint()..color = const Color(0x8840C4FF);
    for (final off in [Offset(cx - 11, cy - 4), Offset(cx + 10, cy + 4)]) {
      final sh = Path()
        ..moveTo(off.dx, off.dy - 2.5)
        ..lineTo(off.dx - 2, off.dy + 3)
        ..lineTo(off.dx + 3, off.dy + 1)
        ..close();
      canvas.drawPath(sh, shardP);
    }
  }
}

// ══════════════════════════════════════════════════════════════════════
//  TRAFFIC CAR — Emoji-based, one-way same-direction AI
//  Features: car-following, truck awareness, lane changing, no car-car collisions
// ══════════════════════════════════════════════════════════════════════
class TrafficCar extends Component {
  int    lane;
  double worldY;
  double worldX;   // smoothly interpolates to laneCenter(lane)
  final VehicleKind kind;
  final double      baseSpeed;
  final CityCollectionGame game;

  double _curSpeed     = 0;
  double _targetLaneX  = 0;
  bool   crashed       = false;
  double crashTimer    = 0.0;
  bool   _changingLane = false;
  double _laneChangeT  = 0.0;   // 0→1 over lane change duration
  double _prevLaneX    = 0;

  // Per-vehicle emoji & size spec
  static const Map<VehicleKind, _VSpec> _specs = {
    VehicleKind.saloon:   _VSpec('🚗', 34.0, 52.0),
    VehicleKind.matatu:   _VSpec('🚐', 36.0, 62.0),
    VehicleKind.bus:      _VSpec('🚌', 40.0, 80.0),
    VehicleKind.suv:      _VSpec('🚙', 36.0, 56.0),
    VehicleKind.van:      _VSpec('🚚', 38.0, 64.0),
    VehicleKind.motorbike:_VSpec('🏍️', 18.0, 34.0),
  };

  static double halfLengthFor(VehicleKind k) => (_specs[k]?.h ?? 52) / 2;
  static double halfWidthFor(VehicleKind k)  => (_specs[k]?.w ?? 34) / 2;

  TrafficCar({
    required this.lane,
    required this.worldY,
    required this.worldX,
    required this.kind,
    required this.baseSpeed,
    required this.game,
  }) {
    _curSpeed    = baseSpeed;
    _targetLaneX = worldX;
    _prevLaneX   = worldX;
  }

  double get _vehLength => _specs[kind]!.h;
  double get _vehWidth  => _specs[kind]!.w;

  // Safe following gap = 1.5× own length
  double get _safeGap => _vehLength * 1.5 + 20;

  @override
  void update(double dt) {
    if (crashed) {
      crashTimer -= dt;
      // Vehicle stays stopped and visible while crashed; respawn after timer
      _curSpeed = 0;
      if (crashTimer <= 0) {
        crashed = false;
        // Respawn well ahead of truck after crash recovery
        worldY   = -(game.worldScroll + 600 + game._rng.nextDouble() * 400);
        worldX   = game.laneCenter(lane);
        _curSpeed = baseSpeed;
      }
      return;
    }

    // ── 1. Find leader in same lane (car directly ahead) ──────────────
    TrafficCar? leader;
    double leaderGap = double.infinity;
    for (final other in game.cars) {
      if (other == this || other.crashed || other.lane != lane) continue;
      // "Ahead" means lower worldY (further from 0 in negative direction) than this car
      final gap = worldY - other.worldY;   // positive = other is ahead
      if (gap > 0 && gap < leaderGap) {
        leaderGap = gap;
        leader    = other;
      }
    }

    // ── 2. Check if truck is ahead in same lane ────────────────────────
    final truckSy      = game.truckPos.y;
    final thisSy       = game.toScreenY(worldY);
    final truckInLane  = (game.truckPos.x - worldX).abs() < _vehWidth + 10;
    final truckAhead   = truckInLane && thisSy > truckSy;  // truck is above us on screen = ahead
    final truckGap     = thisSy - truckSy;                 // pixels between us and truck on screen

    // ── 3. Determine desired speed (IDM-lite) ─────────────────────────
    double desiredSpeed = baseSpeed;

    // Slow for leader car
    if (leader != null && leaderGap < _safeGap * 2.5) {
      final ratio = (leaderGap - _vehLength) / (_safeGap * 2.5);
      desiredSpeed = math.min(desiredSpeed, leader._curSpeed * ratio.clamp(0.0, 1.0));
    }

    // Slow for truck
    if (truckAhead && truckGap < _safeGap * 3) {
      final truckEffectiveSpeed = game.speed;
      final ratio = (truckGap - _vehLength * 0.5) / (_safeGap * 3);
      desiredSpeed = math.min(desiredSpeed, truckEffectiveSpeed + (desiredSpeed - truckEffectiveSpeed) * ratio.clamp(0.0, 1.0));
    }

    // Full stop if about to collide with leader
    if (leader != null && leaderGap < _vehLength + 12) {
      desiredSpeed = 0;
    }
    if (truckAhead && truckGap < _vehLength * 0.8 + 10) {
      desiredSpeed = 0;
    }

    // ── 4. Smooth speed approach ───────────────────────────────────────
    const accel = 120.0, decel = 200.0;
    if (_curSpeed < desiredSpeed) {
      _curSpeed = math.min(_curSpeed + accel * dt, desiredSpeed);
    } else {
      _curSpeed = math.max(_curSpeed - decel * dt, desiredSpeed.clamp(0, double.infinity));
    }

    // ── 5. Lane change logic ──────────────────────────────────────────
    // Try to change lane if: blocked by slow leader or truck is in our lane ahead
    if (!_changingLane) {
      final blocked = (leader != null && leaderGap < _safeGap * 1.5 && leader._curSpeed < baseSpeed * 0.6)
                   || (truckAhead && truckGap < _safeGap * 2 && game.speed < baseSpeed * 0.5);
      if (blocked) {
        _tryChangeLane();
      }
    }

    // ── 6. Smooth lane-change lateral movement ─────────────────────────
    if (_changingLane) {
      _laneChangeT += dt / 1.2;  // takes 1.2s to complete lane change
      if (_laneChangeT >= 1.0) {
        _laneChangeT = 1.0;
        _changingLane = false;
        worldX = _targetLaneX;
      } else {
        // Smooth cubic ease
        final t = _laneChangeT;
        final ease = t * t * (3 - 2 * t);
        worldX = _prevLaneX + (_targetLaneX - _prevLaneX) * ease;
      }
    } else {
      worldX = _targetLaneX;
    }

    // ── 7. Move forward (same direction as truck = negative worldY direction) ──
    // worldScroll increases as truck moves. For a car to stay at constant screen
    // position relative to world, its worldY must decrease as worldScroll increases.
    // Moving forward = decreasing worldY at own speed.
    worldY -= _curSpeed * dt;

    // ── 8. Respawn when passed far behind (off bottom of screen) ──────
    final sy = game.toScreenY(worldY);
    if (sy > game.size.y + 200) {
      // Teleport ahead of the screen, far in front of truck
      worldY    = -(game.worldScroll + 500 + game._rng.nextDouble() * 800);
      worldX    = game.laneCenter(lane);
      _targetLaneX = worldX;
      _curSpeed = baseSpeed;
      _changingLane = false;
    }
  }

  void _tryChangeLane() {
    // Prefer lane to right, then left
    for (final targetLane in [lane + 1, lane - 1]) {
      if (targetLane < 0 || targetLane >= kLanes) continue;
      if (_laneIsClear(targetLane)) {
        _prevLaneX   = worldX;
        lane         = targetLane;
        _targetLaneX = game.laneCenter(targetLane);
        _changingLane = true;
        _laneChangeT  = 0.0;
        return;
      }
    }
  }

  bool _laneIsClear(int targetLane) {
    final targetX = game.laneCenter(targetLane);
    // Check no other car is too close in target lane
    for (final other in game.cars) {
      if (other == this || other.crashed) continue;
      if (other.lane != targetLane) continue;
      final gap = (other.worldY - worldY).abs();
      if (gap < _safeGap * 2.0) return false;
    }
    // Check truck is not in target lane
    if ((game.truckPos.x - targetX).abs() < _vehWidth + 15) return false;
    return true;
  }

  @override
  void render(Canvas canvas) {
    final sy = game.toScreenY(worldY);
    if (sy < -80 || sy > game.size.y + 80) return;

    final spec = _specs[kind]!;

    // Shadow ellipse beneath vehicle
    canvas.drawOval(
      Rect.fromLTWH(worldX - spec.w * 0.42, sy + spec.h * 0.35,
          spec.w * 0.85, spec.h * 0.18),
      Paint()..color = const Color(0x44000000),
    );

    // If crashed: show hazard overlay and tint, but still draw the vehicle
    if (crashed) {
      // Draw top-down vehicle shape tinted red/orange for crash
      _drawTopDownShape(canvas, spec, sy, crashed: true);
      // Crash sparks / smoke effect
      final sparkPaint = Paint()
        ..color = const Color(0xCCFF6600)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(Offset(worldX, sy), spec.w * 0.55, sparkPaint);
      // Hazard X symbol
      final xPaint = Paint()
        ..color = Colors.red
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      final r = spec.w * 0.28;
      canvas.drawLine(Offset(worldX - r, sy - r), Offset(worldX + r, sy + r), xPaint);
      canvas.drawLine(Offset(worldX + r, sy - r), Offset(worldX - r, sy + r), xPaint);
      return;
    }

    _drawTopDownShape(canvas, spec, sy, crashed: false);

    // Brake lights: red glow at rear (bottom = positive sy direction) when slowing
    if (_curSpeed < baseSpeed * 0.6) {
      final brakePaint = Paint()
        ..color = const Color(0xAAFF1111)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
      canvas.drawCircle(Offset(worldX - spec.w * 0.3, sy + spec.h * 0.38), 4, brakePaint);
      canvas.drawCircle(Offset(worldX + spec.w * 0.3, sy + spec.h * 0.38), 4, brakePaint);
    }
  }

  /// Draws a top-down (bird's-eye) vehicle shape facing upward (direction of travel).
  /// The vehicle travels upward on screen (negative worldY direction).
  void _drawTopDownShape(Canvas canvas, _VSpec spec, double sy, {required bool crashed}) {
    final w = spec.w;
    final h = spec.h;
    final cx = worldX;

    // Base body colour per vehicle kind
    Color bodyColor;
    Color roofColor;
    Color glassColor;
    switch (kind) {
      case VehicleKind.saloon:
        bodyColor = crashed ? const Color(0xFF8B0000) : const Color(0xFF1565C0);
        roofColor = crashed ? const Color(0xFF5A0000) : const Color(0xFF0D47A1);
        glassColor = const Color(0x884FC3F7);
        break;
      case VehicleKind.matatu:
        bodyColor = crashed ? const Color(0xFF8B0000) : const Color(0xFFF9A825);
        roofColor = crashed ? const Color(0xFF5A0000) : const Color(0xFFF57F17);
        glassColor = const Color(0x88B3E5FC);
        break;
      case VehicleKind.bus:
        bodyColor = crashed ? const Color(0xFF8B0000) : const Color(0xFF2E7D32);
        roofColor = crashed ? const Color(0xFF5A0000) : const Color(0xFF1B5E20);
        glassColor = const Color(0x8881D4FA);
        break;
      case VehicleKind.suv:
        bodyColor = crashed ? const Color(0xFF8B0000) : const Color(0xFF4A148C);
        roofColor = crashed ? const Color(0xFF5A0000) : const Color(0xFF311B92);
        glassColor = const Color(0x88CE93D8);
        break;
      case VehicleKind.van:
        bodyColor = crashed ? const Color(0xFF8B0000) : const Color(0xFF37474F);
        roofColor = crashed ? const Color(0xFF5A0000) : const Color(0xFF263238);
        glassColor = const Color(0x88B0BEC5);
        break;
      case VehicleKind.motorbike:
        bodyColor = crashed ? const Color(0xFF8B0000) : const Color(0xFFBF360C);
        roofColor = crashed ? const Color(0xFF5A0000) : const Color(0xFFE64A19);
        glassColor = const Color(0x88FFCC80);
        break;
    }

    canvas.save();
    canvas.translate(cx, sy);

    // Vehicle is moving UPWARD on screen. Top of the drawn rect = FRONT of car.
    final rect = Rect.fromLTWH(-w / 2, -h / 2, w, h);

    // ── Main body ──────────────────────────────────────────────────────
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(w * 0.2)),
      Paint()..color = bodyColor,
    );

    if (kind == VehicleKind.motorbike) {
      // Motorbike: simple oval body + rider circle
      canvas.drawOval(Rect.fromLTWH(-w * 0.35, -h * 0.45, w * 0.7, h * 0.9),
          Paint()..color = bodyColor);
      // Rider helmet (top = front)
      canvas.drawCircle(Offset(0, -h * 0.22), w * 0.28,
          Paint()..color = roofColor);
      // Handlebars
      canvas.drawLine(
        Offset(-w * 0.45, -h * 0.35), Offset(w * 0.45, -h * 0.35),
        Paint()..color = const Color(0xFF888888)..strokeWidth = 2.5..strokeCap = StrokeCap.round,
      );
      // Wheels (front = top, rear = bottom)
      final wp = Paint()..color = const Color(0xFF111111);
      canvas.drawRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(-w * 0.22, -h * 0.48, w * 0.44, h * 0.15), Radius.circular(3)), wp);
      canvas.drawRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(-w * 0.22, h * 0.33, w * 0.44, h * 0.15), Radius.circular(3)), wp);
    } else {
      // ── Roof panel (slightly smaller, centred) ───────────────────────
      final roofInset = kind == VehicleKind.bus || kind == VehicleKind.van ? 0.12 : 0.18;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(-w * (0.5 - roofInset), -h * 0.32,
              w * (1 - roofInset * 2), h * 0.55),
          Radius.circular(w * 0.12),
        ),
        Paint()..color = roofColor,
      );

      // ── Windshield (front = TOP of sprite, top half of roof) ─────────
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(-w * 0.28, -h * 0.44, w * 0.56, h * 0.14),
          const Radius.circular(3),
        ),
        Paint()..color = glassColor,
      );
      // Windshield glare
      canvas.drawLine(
        Offset(-w * 0.18, -h * 0.43), Offset(-w * 0.08, -h * 0.32),
        Paint()..color = const Color(0x55FFFFFF)..strokeWidth = 1.8..strokeCap = StrokeCap.round,
      );

      // ── Rear window (bottom = back of car) ───────────────────────────
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(-w * 0.24, h * 0.29, w * 0.48, h * 0.10),
          const Radius.circular(2),
        ),
        Paint()..color = glassColor,
      );

      // ── Headlights (FRONT = TOP) ─────────────────────────────────────
      final hlPaint = Paint()
        ..color = const Color(0xFFFFEE88)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawCircle(Offset(-w * 0.3, -h * 0.46), w * 0.10, hlPaint);
      canvas.drawCircle(Offset( w * 0.3, -h * 0.46), w * 0.10, hlPaint);

      // ── Tail-lights (REAR = BOTTOM) ───────────────────────────────────
      final tlPaint = Paint()..color = const Color(0xCCBB1111);
      canvas.drawRect(Rect.fromLTWH(-w * 0.45, h * 0.40, w * 0.18, h * 0.06), tlPaint);
      canvas.drawRect(Rect.fromLTWH( w * 0.27, h * 0.40, w * 0.18, h * 0.06), tlPaint);

      // ── Wheels (4 corners) ────────────────────────────────────────────
      final wp = Paint()..color = const Color(0xFF111111);
      final wheelW = w * 0.18;
      final wheelH = h * 0.14;
      for (final wr in [
        Rect.fromLTWH(-w * 0.52, -h * 0.44, wheelW, wheelH),  // front-left
        Rect.fromLTWH( w * 0.34, -h * 0.44, wheelW, wheelH),  // front-right
        Rect.fromLTWH(-w * 0.52,  h * 0.30, wheelW, wheelH),  // rear-left
        Rect.fromLTWH( w * 0.34,  h * 0.30, wheelW, wheelH),  // rear-right
      ]) {
        canvas.drawRRect(RRect.fromRectAndRadius(wr, const Radius.circular(2)), wp);
        // Rim highlight
        canvas.drawRRect(RRect.fromRectAndRadius(wr.deflate(1.5),
            const Radius.circular(1)),
            Paint()..color = const Color(0xFF555555)..style = PaintingStyle.stroke..strokeWidth = 1);
      }

      // ── Bus / van extra detail: side windows ─────────────────────────
      if (kind == VehicleKind.bus || kind == VehicleKind.matatu || kind == VehicleKind.van) {
        final winPaint = Paint()..color = glassColor;
        final numWins  = kind == VehicleKind.bus ? 3 : 2;
        for (int i = 0; i < numWins; i++) {
          final wy = -h * 0.18 + i * (h * 0.18);
          canvas.drawRRect(RRect.fromRectAndRadius(
              Rect.fromLTWH(-w * 0.46, wy, w * 0.12, h * 0.13), const Radius.circular(2)), winPaint);
          canvas.drawRRect(RRect.fromRectAndRadius(
              Rect.fromLTWH( w * 0.34, wy, w * 0.12, h * 0.13), const Radius.circular(2)), winPaint);
        }
      }
    }

    canvas.restore();
  }
}

class _VSpec {
  final String emoji;
  final double w, h;  // visual bounding box width & height
  const _VSpec(this.emoji, this.w, this.h);
}

// ══════════════════════════════════════════════════════════════════════
//  SEWER LEAK — Positioned next to buildings, off-road
//  Each has a leak type requiring specific tools
// ══════════════════════════════════════════════════════════════════════
class SewerLeak extends Component {
  double worldY, worldX;
  final int      id;
  final LeakType leakType;
  final CityCollectionGame game;
  bool   isVisible         = false;
  bool   isRepaired        = false;
  bool   activelyRepairing = false;
  bool   wrongTool         = false;
  bool   showToolPrompt    = false;
  double repairProgress    = 0.0;
  double _pulse            = 0.0;
  /// Tracks whether the truck has already arrived at this sewer in its
  /// current stop, so we only auto-clear the selected tool once per visit.
  bool   _truckWasHere     = false;

  SewerLeak({required this.worldY, required this.worldX,
    required this.id, required this.leakType, required this.game});

  @override void update(double dt) { if (!isRepaired) _pulse += dt * 3.5; }

  String get _leakEmoji {
    switch (leakType) {
      case LeakType.pipe:   return '🔩';
      case LeakType.joint:  return '🔗';
      case LeakType.crack:  return '💧';
    }
  }

  String get _leakLabel {
    switch (leakType) {
      case LeakType.pipe:   return 'Pipe\nLoose';
      case LeakType.joint:  return 'Joint\nLeak';
      case LeakType.crack:  return 'Crack\nLeak';
    }
  }

  Color get _leakColor {
    switch (leakType) {
      case LeakType.pipe:   return const Color(0xFF9C27B0);
      case LeakType.joint:  return const Color(0xFF2196F3);
      case LeakType.crack:  return const Color(0xFF4CAF50);
    }
  }

  @override
  void render(Canvas canvas) {
    if (!isVisible) return;
    final sy = game.toScreenY(worldY);
    if (sy < -80 || sy > game.size.y + 80) return;
    final cx = worldX;

    if (isRepaired) {
      // Repaired badge
      canvas.drawCircle(Offset(cx, sy), 18, Paint()..color = const Color(0xFF1B5E20));
      canvas.drawCircle(Offset(cx, sy), 18,
          Paint()..color = const Color(0xFF4CAF50)..style = PaintingStyle.stroke..strokeWidth = 2.5);
      final tp = Paint()..color = const Color(0xFF4CAF50)..strokeWidth = 2.5
          ..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
      canvas.drawPath(Path()..moveTo(cx-7, sy)..lineTo(cx-2, sy+6)..lineTo(cx+8, sy-6), tp);
      // "Fixed" label
      final label = TextPainter(
        text: const TextSpan(text: '✓ Fixed', style: TextStyle(color: Color(0xFF4CAF50), fontSize: 9, fontWeight: FontWeight.bold)),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(canvas, Offset(cx - label.width/2, sy + 22));
      return;
    }

    // Pulsing leak glow
    final a = 0.20 + math.sin(_pulse) * 0.18;
    canvas.drawCircle(Offset(cx, sy), 38,
        Paint()..color = _leakColor.withValues(alpha: a)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));

    // Sewage puddle (dirty brown-green)
    canvas.drawOval(
      Rect.fromLTWH(cx - 22, sy - 10, 44, 22),
      Paint()..color = const Color(0xAA4A7C3F),
    );
    // Sewage ripple
    canvas.drawOval(
      Rect.fromLTWH(cx - 22, sy - 10, 44, 22),
      Paint()..color = const Color(0xFF2E5C22)..style = PaintingStyle.stroke..strokeWidth = 1,
    );

    // Pipe visual (horizontal bar next to building)
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(cx - 16, sy - 6, 32, 12), const Radius.circular(4)),
      Paint()..color = const Color(0xFF546E7A),
    );
    // Pipe bolts
    canvas.drawCircle(Offset(cx - 10, sy), 3, Paint()..color = const Color(0xFF90A4AE));
    canvas.drawCircle(Offset(cx + 10, sy), 3, Paint()..color = const Color(0xFF90A4AE));

    // Crack / leak drip effect
    final drip = Paint()
      ..color = _leakColor.withValues(alpha: 0.7 + math.sin(_pulse * 2) * 0.3)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(cx, sy + 6), Offset(cx - 3, sy + 14 + math.sin(_pulse) * 3), drip);
    canvas.drawLine(Offset(cx + 5, sy + 8), Offset(cx + 3, sy + 16 + math.cos(_pulse) * 2), drip);

    // Leak type indicator
    final emoji = TextPainter(
      text: TextSpan(text: _leakEmoji, style: const TextStyle(fontSize: 11)),
      textDirection: TextDirection.ltr,
    )..layout();
    emoji.paint(canvas, Offset(cx - emoji.width/2, sy - 24));

    // Leak label
    final label = TextPainter(
      text: TextSpan(text: _leakLabel,
          style: TextStyle(color: _leakColor, fontSize: 8, fontWeight: FontWeight.bold, height: 1.1)),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: 40);
    label.paint(canvas, Offset(cx - 20, sy - 44));

    // Repair progress bar (always shown when player is in range)
    final dist = ((game.truckPos.x - cx).abs() + (game.toScreenY(worldY) - game.truckPos.y).abs());
    final inRange = dist < 80;

    if (inRange || repairProgress > 0) {
      // Background track
      canvas.drawRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(cx - 34, sy - 56, 68, 11), const Radius.circular(4)),
          Paint()..color = const Color(0xAA000000));

      // Fill colour: green=correct, red=wrong, grey=no tool
      final barColor = wrongTool
          ? const Color(0xFFEF5350)
          : (repairProgress > 0 ? const Color(0xFF4CAF50) : const Color(0xFF607D8B));

      if (repairProgress > 0) {
        canvas.drawRRect(RRect.fromRectAndRadius(
            Rect.fromLTWH(cx - 34, sy - 56, 68 * repairProgress, 11), const Radius.circular(4)),
            Paint()..color = barColor);
      }

      // Border
      canvas.drawRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(cx - 34, sy - 56, 68, 11), const Radius.circular(4)),
          Paint()..color = Colors.white24..style = PaintingStyle.stroke..strokeWidth = 1);

      // Active correct-tool spark
      if (activelyRepairing) {
        canvas.drawCircle(Offset(cx, sy - 3), 7,
            Paint()..color = const Color(0xFFFFD700)
                ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
      }
    }

    // Feedback banners when truck is nearby
    if (inRange && !isRepaired) {
      String bannerText;
      Color  bannerBg;

      if (wrongTool) {
        // Wrong tool — red warning
        final correct = game.correctToolFor(leakType);
        final correctName = switch (correct) {
          RepairTool.wrench       => 'Wrench 🔩',
          RepairTool.plumbingTape => 'P-Tape 📏',
          RepairTool.sealant      => 'Sealant 🧴',
          RepairTool.pliers       => 'Pliers 🔧',
          RepairTool.none         => 'a tool',
        };
        bannerText = '❌ Wrong tool! Need $correctName';
        bannerBg   = const Color(0xCCB71C1C);
      } else if (showToolPrompt) {
        // No tool selected
        bannerText = '🧰 Open toolbox & select a tool!';
        bannerBg   = const Color(0xCC4A3A00);
      } else if (game.speed >= 20) {
        // Moving too fast
        bannerText = '⬇ Stop the truck to repair!';
        bannerBg   = const Color(0xCCE65100);
      } else {
        // In range, stopped, correct/no tool feedback
        bannerText = activelyRepairing ? '🔧 Repairing…' : '⬇ Stop & select tool to repair';
        bannerBg   = const Color(0xCC1A3A1A);
      }

      final banner = TextPainter(
        text: TextSpan(text: bannerText,
            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
        textDirection: TextDirection.ltr,
      )..layout();
      final bx = cx - banner.width / 2 - 6;
      canvas.drawRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(bx, sy - 74, banner.width + 12, 16),
          const Radius.circular(5)), Paint()..color = bannerBg);
      banner.paint(canvas, Offset(cx - banner.width / 2, sy - 73));
    }
  }
}

// ══════════════════════════════════════════════════════════════════════
//  SIDEWALK PEDESTRIAN
// ══════════════════════════════════════════════════════════════════════
class SidewalkPed extends Component {
  double worldY, worldX;
  final CityCollectionGame game;
  bool   isFleeing = false;
  double _walk     = 0.0;
  final int _skinTone;
  final int _shirtColor;

  SidewalkPed({required this.worldY, required this.worldX, required this.game})
      : _skinTone = math.Random().nextInt(4),
        _shirtColor = math.Random().nextInt(6);

  @override void update(double dt) {
    if (!isFleeing) { _walk += dt * 2.2; worldY += dt * 18; }
    else { _walk += dt * 6; }
  }

  @override
  void render(Canvas canvas) {
    final sy = game.toScreenY(worldY);
    if (sy < -42 || sy > game.size.y + 42) return;
    final wx = worldX + math.sin(_walk) * 2.5;

    const skins  = [Color(0xFFE8C882), Color(0xFFB07850), Color(0xFF7A4A2A), Color(0xFF3E2010)];
    const shirts = [Color(0xFF1565C0), Color(0xFFC62828), Color(0xFF2E7D32),
                    Color(0xFFAD1457), Color(0xFF6A1B9A), Color(0xFF37474F)];

    if (isFleeing) {
      final ep = Paint()..color = const Color(0xAAFF6633)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      canvas.drawCircle(Offset(wx, sy), 7, ep);
      return;
    }

    // Shadow
    canvas.drawOval(Rect.fromLTWH(wx-5, sy+12, 10, 4), Paint()..color = const Color(0x33000000));
    // Head
    canvas.drawCircle(Offset(wx, sy), 6, Paint()..color = skins[_skinTone]);
    // Hair
    canvas.drawArc(Rect.fromLTWH(wx-6, sy-6, 12, 8), math.pi, math.pi,
        true, Paint()..color = const Color(0xFF2A1A0A));
    // Body/shirt
    canvas.drawRect(Rect.fromLTWH(wx-4, sy+5, 8, 9), Paint()..color = shirts[_shirtColor]);
    // Animated legs
    final lo = math.sin(_walk * 3) * 3.5;
    final lp = Paint()..color = const Color(0xFF1A1A2E)..strokeWidth = 2.5;
    canvas.drawLine(Offset(wx-2, sy+13), Offset(wx-2+lo, sy+21), lp);
    canvas.drawLine(Offset(wx+2, sy+13), Offset(wx+2-lo, sy+21), lp);
    // Shoes
    canvas.drawOval(Rect.fromLTWH(wx-4+lo, sy+20, 6, 3), Paint()..color = const Color(0xFF111111));
    canvas.drawOval(Rect.fromLTWH(wx-2-lo, sy+20, 6, 3), Paint()..color = const Color(0xFF111111));
  }
}

// ══════════════════════════════════════════════════════════════════════
//  HUD
// ══════════════════════════════════════════════════════════════════════
class CityHud extends StatelessWidget {
  final CityCollectionGame game;
  const CityHud(this.game, {super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: game,
      builder: (_, __) {
        final isCol      = game.phase == GamePhase.collection;
        final timeLeft   = isCol ? game.collectTime : game.sewerTime;
        final phaseColor = isCol ? const Color(0xFF4CAF50) : const Color(0xFF2196F3);
        final kmh        = (game.speed * 3.6 / 10).clamp(0.0, 999.0).toInt();

        return SafeArea(child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Phase pill
              Align(
                alignment: Alignment.topCenter,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 5),
                  decoration: BoxDecoration(
                    color: phaseColor.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: phaseColor.withValues(alpha: 0.4), blurRadius: 10)],
                  ),
                  child: Text(
                    isCol ? '🗑️  PHASE 1 — COLLECT WASTE' : '🔧  PHASE 2 — REPAIR SEWERS',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900,
                        fontSize: 13, letterSpacing: 1.2),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Stats row
              Row(children: [
                _HudTile(Icons.timer_rounded, '${timeLeft.toInt()}s', 'TIME',
                    timeLeft < 20 ? Colors.red : Colors.white),
                const SizedBox(width: 6),
                if (isCol)
                  _HudTile(Icons.delete_rounded, '${game.wasteCollected}', 'WASTE', Colors.greenAccent)
                else
                  _HudTile(Icons.plumbing_rounded,
                      '${game.sewersFixed}/${CityCollectionGame.kTotalSewers}', 'SEWERS', Colors.cyanAccent),
                const SizedBox(width: 6),
                _HudTile(Icons.eco_rounded, '${game.ecoPoints}', 'ECO-PTS', Colors.limeAccent),
                const SizedBox(width: 6),
                _HudTile(Icons.speed_rounded, '$kmh', 'KM/H',
                    kmh > 80 ? Colors.orange : Colors.white70),
              ]),
              // Cargo fill bar
              if (isCol) ...[
                const SizedBox(height: 6),
                Row(children: [
                  const Text('🚛', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 6),
                  Expanded(child: ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: LinearProgressIndicator(
                      value: game.cargoFill,
                      backgroundColor: Colors.white12,
                      valueColor: AlwaysStoppedAnimation(game.cargoFill > 0.8
                          ? Colors.orange : Colors.greenAccent),
                      minHeight: 8,
                    ),
                  )),
                  const SizedBox(width: 6),
                  Text('${(game.cargoFill * 100).round()}%',
                      style: const TextStyle(color: Colors.white70, fontSize: 10)),
                ]),
                const SizedBox(height: 4),
                // Waste type badges
                Row(children: [
                  _TypeBadge('🧴', game.plasticCollected,    const Color(0xFF2196F3)),
                  _TypeBadge('🍌', game.organicCollected,    const Color(0xFF4CAF50)),
                  _TypeBadge('📱', game.electronicCollected, const Color(0xFFF97316)),
                  _TypeBadge('🍶', game.glassCollected,      const Color(0xFF00BCD4)),
                  _TypeBadge('🔩', game.metallicCollected,   const Color(0xFFB0BEC5)),
                  _TypeBadge('🗑️', game.generalCollected,   const Color(0xFF9E9E9E)),
                ]),
              ],
              // Sewer phase: selected tool indicator
              if (!isCol) ...[
                const SizedBox(height: 6),
                Row(children: [
                  _ToolIndicator(game.selectedTool),
                  const SizedBox(width: 8),
                  if (game.speed > 18) Expanded(child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.88),
                        borderRadius: BorderRadius.circular(10)),
                    child: const Text('⚠️ Stop the truck to repair sewers',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                  )),
                ]),
              ],
            ],
          ),
        ));
      },
    );
  }
}

class _HudTile extends StatelessWidget {
  final IconData icon; final String val, label; final Color color;
  const _HudTile(this.icon, this.val, this.label, this.color);
  @override
  Widget build(BuildContext context) => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
    decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12)),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: color, size: 15),
      Text(val, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
      Text(label, style: const TextStyle(color: Colors.white54, fontSize: 8, letterSpacing: 0.8)),
    ]),
  ));
}

class _TypeBadge extends StatelessWidget {
  final String emoji; final int count; final Color color;
  const _TypeBadge(this.emoji, this.count, this.color);
  @override
  Widget build(BuildContext context) => Expanded(child: Container(
    margin: const EdgeInsets.only(right: 3),
    padding: const EdgeInsets.symmetric(vertical: 3),
    decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: color.withValues(alpha: 0.4))),
    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(emoji, style: const TextStyle(fontSize: 10)),
      const SizedBox(width: 3),
      Text('$count', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11)),
    ]),
  ));
}

class _ToolIndicator extends StatelessWidget {
  final RepairTool tool;
  const _ToolIndicator(this.tool);
  @override
  Widget build(BuildContext context) {
    final (emoji, name) = switch (tool) {
      RepairTool.pliers       => ('🔧', 'Pliers'),
      RepairTool.plumbingTape => ('📏', 'P-Tape'),
      RepairTool.wrench       => ('🔩', 'Wrench'),
      RepairTool.sealant      => ('🧴', 'Sealant'),
      RepairTool.none         => ('❓', 'No Tool'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white24)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(emoji, style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 5),
        Text(name, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
//  TOOLBOX OVERLAY — shown when player opens toolbox during sewer phase
// ══════════════════════════════════════════════════════════════════════
class ToolboxOverlay extends StatelessWidget {
  final CityCollectionGame game;
  const ToolboxOverlay(this.game, {super.key});

  @override
  Widget build(BuildContext context) {
    const tools = [
      (RepairTool.wrench,       '🔩', 'Wrench',       'Tightens loose pipes\n(Pipe leaks)', Color(0xFF7B1FA2)),
      (RepairTool.plumbingTape, '📏', 'Plumbing Tape','Seals joint leaks\n(Joint leaks)',   Color(0xFF1565C0)),
      (RepairTool.sealant,      '🧴', 'Pipe Sealant', 'Fills cracks & gaps\n(Crack leaks)', Color(0xFF2E7D32)),
      (RepairTool.pliers,       '🔧', 'Pliers',       'Grips & bends pipes\n(General use)', Color(0xFF827717)),
    ];

    return GestureDetector(
      onTap: game.closeToolbox,
      child: Container(
        color: Colors.black.withValues(alpha: 0.6),
        child: Center(
          child: GestureDetector(
            onTap: () {}, // Prevent backdrop tap from propagating
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [Color(0xFF1A1A2E), Color(0xFF16213E)]),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.6), width: 2),
                boxShadow: [BoxShadow(color: Colors.orange.withValues(alpha: 0.3), blurRadius: 20)],
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Row(children: [
                  const Text('🧰', style: TextStyle(fontSize: 28)),
                  const SizedBox(width: 10),
                  const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('TOOLBOX', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900,
                        fontSize: 18, letterSpacing: 2)),
                    Text('Select the right tool for each leak type',
                        style: TextStyle(color: Colors.white54, fontSize: 11)),
                  ])),
                  IconButton(onPressed: game.closeToolbox,
                      icon: const Icon(Icons.close, color: Colors.white54)),
                ]),
                const SizedBox(height: 16),
                // Tool legend
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10)),
                  child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Leak Types Guide:', style: TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold)),
                    SizedBox(height: 4),
                    Text('🔩 Pipe Loose → Use Wrench',     style: TextStyle(color: Colors.white70, fontSize: 10)),
                    Text('🔗 Joint Leak → Use Plumbing Tape', style: TextStyle(color: Colors.white70, fontSize: 10)),
                    Text('💧 Crack Leak → Use Pipe Sealant', style: TextStyle(color: Colors.white70, fontSize: 10)),
                  ]),
                ),
                const SizedBox(height: 14),
                ...tools.map((t) {
                  final (tool, emoji, name, desc, color) = t;
                  final isSelected = game.selectedTool == tool;
                  return GestureDetector(
                    onTap: () => game.selectTool(tool),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected ? color.withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? color : Colors.white12, width: isSelected ? 2 : 1),
                      ),
                      child: Row(children: [
                        Text(emoji, style: const TextStyle(fontSize: 24)),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(name, style: TextStyle(color: isSelected ? color : Colors.white,
                              fontWeight: FontWeight.bold, fontSize: 14)),
                          Text(desc, style: const TextStyle(color: Colors.white54, fontSize: 10, height: 1.2)),
                        ])),
                        if (isSelected) Icon(Icons.check_circle, color: color, size: 20),
                      ]),
                    ),
                  );
                }),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
//  CONTROLS OVERLAY
//  Mobile : touch buttons (multi-touch via Listener) + accelerometer tilt
//  Desktop: Arrow keys / WASD / Space  (all simultaneously supported)
// ══════════════════════════════════════════════════════════════════════
class CityControls extends StatefulWidget {
  final CityCollectionGame game;
  const CityControls(this.game, {super.key});
  @override State<CityControls> createState() => _CityControlsState();
}

class _CityControlsState extends State<CityControls> {
  bool _acc = false, _brk = false, _left = false, _right = false, _rev = false;
  late FocusNode _focusNode;

  // ── Tilt / accelerometer ─────────────────────────────────────────────
  // Step 1: Add to pubspec.yaml:   sensors_plus: ^4.0.2
  // Step 2: Add import at top:     import 'package:sensors_plus/sensors_plus.dart';
  // Step 3: Uncomment the lines marked [TILT] below.
  // Everything else (setTilt, tiltX, steering blend) is already wired in.

  // ignore: prefer_final_fields  — mutated by accelerometer stream when sensors_plus is enabled
  double _tiltDisplay = 0.0;
  // [TILT] StreamSubscription<AccelerometerEvent>? _accelSub;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
    _startTilt();
  }

  void _startTilt() {
    // [TILT] Uncomment block below after adding sensors_plus:
    // try {
    //   _accelSub = accelerometerEventStream(
    //     samplingPeriod: const Duration(milliseconds: 16),
    //   ).listen((AccelerometerEvent e) {
    //     // Portrait: tilt right → e.x goes negative on most devices, so negate
    //     final raw  = -(e.x / 7.0).clamp(-1.0, 1.0);
    //     final dead = raw.abs() < 0.10 ? 0.0 : raw;  // ±10% deadzone
    //     widget.game.setTilt(dead);
    //     if (mounted) setState(() => _tiltDisplay = dead);
    //   });
    // } catch (_) { /* sensor unavailable on desktop/web — silently skip */ }
  }

  @override
  void dispose() {
    // [TILT] _accelSub?.cancel();
    widget.game.setTilt(0.0);
    _focusNode.dispose();
    super.dispose();
  }

  // ── Keyboard handler — Arrow keys + WASD + Space, all simultaneous ──
  void _handleKey(KeyEvent event) {
    final pressed  = event is KeyDownEvent || event is KeyRepeatEvent;
    final released = event is KeyUpEvent;

    void drive(bool v)   { setState(() => _acc = v); widget.game.setDrive(v); }
    void brake(bool v)   { setState(() => _brk = v); widget.game.setBrake(v); }
    void steerL(bool v)  { setState(() => _left = v); widget.game.setLeft(v); }
    void steerR(bool v)  { setState(() => _right = v); widget.game.setRight(v); }
    void reverse(bool v) { setState(() => _rev = v); widget.game.setReverse(v); }

    final k = event.logicalKey;

    // Forward: W or ArrowUp
    if (k == LogicalKeyboardKey.keyW || k == LogicalKeyboardKey.arrowUp) {
      if (pressed) drive(true); if (released) drive(false);
    }
    // Brake: S or ArrowDown or Space
    if (k == LogicalKeyboardKey.keyS || k == LogicalKeyboardKey.arrowDown ||
        k == LogicalKeyboardKey.space) {
      if (pressed) brake(true); if (released) brake(false);
    }
    // Steer left: A or ArrowLeft
    if (k == LogicalKeyboardKey.keyA || k == LogicalKeyboardKey.arrowLeft) {
      if (pressed) steerL(true); if (released) steerL(false);
    }
    // Steer right: D or ArrowRight
    if (k == LogicalKeyboardKey.keyD || k == LogicalKeyboardKey.arrowRight) {
      if (pressed) steerR(true); if (released) steerR(false);
    }
    // Reverse: R
    if (k == LogicalKeyboardKey.keyR) {
      if (pressed) reverse(true); if (released) reverse(false);
    }
    // Toolbox: T
    if (k == LogicalKeyboardKey.keyT && pressed) {
      if (widget.game.phase == GamePhase.sewerRepair) widget.game.openToolbox();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 600;

    return KeyboardListener(
      focusNode: _focusNode,
      onKeyEvent: _handleKey,
      child: Stack(children: [

        // ── Mobile touch controls (bottom strip) ──────────────────────
        Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10, left: 10, right: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [

                  // LEFT cluster: steer left + steer right
                  Column(mainAxisSize: MainAxisSize.min, children: [
                    Row(children: [
                      _GameBtn(
                        label: '◀', color: Colors.cyanAccent, isActive: _left,
                        onDown: () { setState(() => _left = true);  widget.game.setLeft(true);  },
                        onUp:   () { setState(() => _left = false); widget.game.setLeft(false); },
                      ),
                      const SizedBox(width: 6),
                      _GameBtn(
                        label: '▶', color: Colors.cyanAccent, isActive: _right,
                        onDown: () { setState(() => _right = true);  widget.game.setRight(true);  },
                        onUp:   () { setState(() => _right = false); widget.game.setRight(false); },
                      ),
                    ]),
                    const SizedBox(height: 4),
                    _GameBtn(
                      label: '⬇ REV', color: Colors.purpleAccent, isActive: _rev,
                      small: true,
                      onDown: () { setState(() => _rev = true);  widget.game.setReverse(true);  },
                      onUp:   () { setState(() => _rev = false); widget.game.setReverse(false); },
                    ),
                  ]),

                  // CENTRE: context info + toolbox
                  Column(mainAxisSize: MainAxisSize.min, children: [
                    if (widget.game.phase == GamePhase.sewerRepair)
                      GestureDetector(
                        onTap: widget.game.openToolbox,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [BoxShadow(color: Colors.orange.withValues(alpha: 0.4), blurRadius: 10)],
                          ),
                          child: const Row(mainAxisSize: MainAxisSize.min, children: [
                            Text('🧰', style: TextStyle(fontSize: 18)),
                            SizedBox(width: 5),
                            Text('TOOLBOX', style: TextStyle(color: Colors.white,
                                fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1)),
                          ]),
                        ),
                      ),
                    const SizedBox(height: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(8)),
                      child: AnimatedBuilder(animation: widget.game, builder: (_, __) => Text(
                        widget.game.phase == GamePhase.sewerRepair
                            ? 'Stop near 🔩 to repair'
                            : '📱 Tilt to steer',
                        style: const TextStyle(color: Colors.white60, fontSize: 9),
                      )),
                    ),
                    const SizedBox(height: 4),
                    // Tilt indicator bar — shows live tilt direction
                    if (!isDesktop) _TiltBar(tilt: _tiltDisplay),
                  ]),

                  // RIGHT cluster: drive + brake
                  Column(mainAxisSize: MainAxisSize.min, children: [
                    _GameBtn(
                      label: '⬆ GO', color: Colors.green, isActive: _acc,
                      onDown: () { setState(() => _acc = true);  widget.game.setDrive(true);  },
                      onUp:   () { setState(() => _acc = false); widget.game.setDrive(false); },
                    ),
                    const SizedBox(height: 6),
                    _GameBtn(
                      label: '■ BRK', color: Colors.redAccent, isActive: _brk,
                      onDown: () { setState(() => _brk = true);  widget.game.setBrake(true);  },
                      onUp:   () { setState(() => _brk = false); widget.game.setBrake(false); },
                    ),
                  ]),
                ],
              ),
            ),
          ),
        ),

        // ── Desktop keyboard reference panel (top-right) ──────────────
        if (isDesktop) Positioned(
          right: 12, top: 80,
          child: _DesktopKeyGuide(acc: _acc, brk: _brk, left: _left, right: _right, rev: _rev),
        ),
      ]),
    );
  }
}

// ── Reusable hold-button (works with simultaneous multi-touch) ─────────
class _GameBtn extends StatelessWidget {
  final String label;
  final Color  color;
  final bool   isActive;
  final bool   small;
  final VoidCallback onDown, onUp;

  const _GameBtn({
    required this.label,
    required this.color,
    required this.isActive,
    required this.onDown,
    required this.onUp,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    final size = small ? 52.0 : 64.0;
    return Listener(
      onPointerDown:   (_) => onDown(),
      onPointerUp:     (_) => onUp(),
      onPointerCancel: (_) => onUp(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 70),
        width: size, height: size,
        transform: Matrix4.identity()..setTranslationRaw(0, isActive ? 3.0 : 0, 0),
        decoration: BoxDecoration(
          color: isActive
              ? color.withValues(alpha: 0.38)
              : Colors.black.withValues(alpha: 0.68),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: isActive ? color : Colors.white24, width: 2),
          boxShadow: isActive
              ? [BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 12, spreadRadius: 1)]
              : [const BoxShadow(color: Colors.black45, blurRadius: 6, offset: Offset(0, 3))],
        ),
        child: Center(
          child: Text(label,
            style: TextStyle(
              color: isActive ? color : Colors.white70,
              fontSize: small ? 10 : 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Desktop keyboard guide widget ──────────────────────────────────────
class _DesktopKeyGuide extends StatelessWidget {
  final bool acc, brk, left, right, rev;
  const _DesktopKeyGuide({required this.acc, required this.brk,
      required this.left, required this.right, required this.rev});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('⌨ CONTROLS', style: TextStyle(
            color: Colors.white54, fontSize: 9, letterSpacing: 1.5, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),

        // WASD pad
        Column(mainAxisSize: MainAxisSize.min, children: [
          _Key('W / ↑', 'Drive', active: acc),
          const SizedBox(height: 3),
          Row(mainAxisSize: MainAxisSize.min, children: [
            _Key('A / ←', 'Left',  active: left),
            const SizedBox(width: 3),
            _Key('S / ↓', 'Brake', active: brk),
            const SizedBox(width: 3),
            _Key('D / →', 'Right', active: right),
          ]),
          const SizedBox(height: 3),
          _Key('R',       'Reverse', active: rev, accent: Colors.purpleAccent),
          const SizedBox(height: 3),
          _Key('Space',   'Brake',   active: brk, wide: true),
          const SizedBox(height: 3),
          _Key('T',       'Toolbox', active: false, accent: Colors.orange),
        ]),

        const SizedBox(height: 8),
        const Text('Hold W+A or W+D\nfor lane switching',
            style: TextStyle(color: Colors.white38, fontSize: 8, height: 1.4)),
      ]),
    );
  }
}

class _Key extends StatelessWidget {
  final String keys, action;
  final bool   active, wide;
  final Color  accent;
  const _Key(this.keys, this.action, {
    required this.active,
    this.wide  = false,
    this.accent = Colors.cyanAccent,
  });
  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 60),
    width: wide ? 112 : null,
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
    decoration: BoxDecoration(
      color: active ? accent.withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(5),
      border: Border.all(color: active ? accent : Colors.white12),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text(keys,   style: TextStyle(color: active ? accent : Colors.white70,
          fontSize: 9, fontWeight: FontWeight.bold)),
      const SizedBox(width: 4),
      Text(action, style: const TextStyle(color: Colors.white38, fontSize: 8)),
    ]),
  );
}

// ── Tilt indicator bar ─────────────────────────────────────────────────
// Shows the live tilt value (−1…+1) as a small horizontal bar.
// Centre = no tilt, left/right fill shows steering direction.
class _TiltBar extends StatelessWidget {
  final double tilt;   // −1.0 … +1.0
  const _TiltBar({required this.tilt});

  @override
  Widget build(BuildContext context) {
    const w = 90.0, h = 10.0;
    final clamped = tilt.clamp(-1.0, 1.0);
    final fillW   = (clamped.abs() * (w / 2)).clamp(0.0, w / 2);
    final fillX   = clamped >= 0 ? w / 2 : w / 2 - fillW;
    final color   = tilt.abs() > 0.6 ? Colors.orangeAccent : Colors.cyanAccent;

    return Column(mainAxisSize: MainAxisSize.min, children: [
      const Text('tilt steer', style: TextStyle(color: Colors.white24, fontSize: 7)),
      const SizedBox(height: 2),
      SizedBox(width: w, height: h,
        child: Stack(children: [
          // Track
          Container(
            width: w, height: h,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.white12),
            ),
          ),
          // Centre line
          Positioned(left: w / 2 - 1, top: 0, child: Container(width: 2, height: h,
              color: Colors.white24)),
          // Fill
          Positioned(left: fillX, top: 1, child: Container(
            width: fillW, height: h - 2,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(3),
            ),
          )),
        ]),
      ),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════════
//  PHASE BANNER
// ══════════════════════════════════════════════════════════════════════
class CityPhaseBanner extends StatelessWidget {
  final CityCollectionGame game;
  const CityPhaseBanner(this.game, {super.key});
  @override
  Widget build(BuildContext context) {
    final isCol = game.phase != GamePhase.sewerRepair;
    return IgnorePointer(child: Center(child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: isCol
            ? [const Color(0xFF1B5E20), const Color(0xFF2E7D32)]
            : [const Color(0xFF0D47A1), const Color(0xFF1565C0)]),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 24)],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(isCol ? 'PHASE 1' : 'PHASE 2',
            style: const TextStyle(color: Colors.white54, fontSize: 13, letterSpacing: 2.5)),
        const SizedBox(height: 4),
        Text(isCol ? '🗑️  Waste Collection' : '🔧  Sewer Repair',
            style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text(
          isCol
              ? 'Drive over waste items to collect them\nWatch out for oncoming traffic!'
              : 'Stop near glowing sewers beside buildings\nUse the right tool from your toolbox!',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
      ]),
    )));
  }
}

// ══════════════════════════════════════════════════════════════════════
//  COLLISION FLASH
// ══════════════════════════════════════════════════════════════════════
class CityCollisionFlash extends StatelessWidget {
  const CityCollisionFlash({super.key});
  @override
  Widget build(BuildContext context) => IgnorePointer(child: Stack(children: [
    Container(decoration: BoxDecoration(
      border: Border.all(color: Colors.red, width: 14),
      gradient: const RadialGradient(
          colors: [Colors.transparent, Color(0x88FF0000)], radius: 1.5),
    )),
    Center(child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
      decoration: BoxDecoration(
          color: Colors.red[900]!.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 16, spreadRadius: 4)]),
      child: const Text('💥  COLLISION!  −25 pts  −8s',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold,
              fontSize: 20, letterSpacing: 1)),
    )),
  ]));
}

// ══════════════════════════════════════════════════════════════════════
//  COLLECTION RESULTS OVERLAY — shown after collection phase ends
//  Player must tap "Continue" to proceed to sewer repair.
// ══════════════════════════════════════════════════════════════════════
class CollectionResultsOverlay extends StatelessWidget {
  final CityCollectionGame game;
  final bool timeExpired;
  const CollectionResultsOverlay(this.game, {this.timeExpired = false, super.key});

  @override
  Widget build(BuildContext context) {
    final g = game;
    final total = g.wasteCollected;
    final pts   = g.collectionEcoPoints;

    return Container(
      color: Colors.black.withValues(alpha: 0.94),
      child: SafeArea(child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: timeExpired
                    ? [const Color(0xFF7B1FA2), const Color(0xFF4A148C)]
                    : [const Color(0xFF1B5E20), const Color(0xFF388E3C)],
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 16)],
            ),
            child: Column(children: [
              Icon(timeExpired ? Icons.timer_off_rounded : Icons.check_circle_rounded,
                  color: Colors.white, size: 52),
              const SizedBox(height: 8),
              Text(
                timeExpired ? '⏰  Time\'s Up!' : '✅  Collection Complete!',
                style: const TextStyle(color: Colors.white, fontSize: 22,
                    fontWeight: FontWeight.bold, letterSpacing: 1),
              ),
              const SizedBox(height: 4),
              Text('Phase 1 — Waste Collection Results',
                  style: const TextStyle(color: Colors.white70, fontSize: 13)),
            ]),
          ),

          const SizedBox(height: 16),

          // Total waste & points
          _ResultCard(children: [
            _BigStat('🗑️', '$total', 'Total Items Collected',       Colors.greenAccent),
            _BigStat('⭐', '${math.max(0, pts)}', 'Collection Eco-Points', Colors.amber),
            _BigStat('💥', '${g.collectionCollisions}', 'Collisions',     Colors.redAccent),
          ]),

          const SizedBox(height: 12),

          // Per-category breakdown
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1B2A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Waste Breakdown by Category',
                    style: TextStyle(color: Colors.white70, fontSize: 12,
                        fontWeight: FontWeight.bold, letterSpacing: 1)),
                const SizedBox(height: 12),
                _WasteRow('🧴', 'Plastic',       g.plasticCollected,    const Color(0xFF2196F3)),
                _WasteRow('🍌', 'Organic',       g.organicCollected,    const Color(0xFF4CAF50)),
                _WasteRow('📱', 'E-Waste',       g.electronicCollected, const Color(0xFFF97316)),
                _WasteRow('🍶', 'Glass / Broken',g.glassCollected,      const Color(0xFF00BCD4)),
                _WasteRow('🔩', 'Metallic',      g.metallicCollected,   const Color(0xFFB0BEC5)),
                _WasteRow('🗑️', 'General',      g.generalCollected,    const Color(0xFF9E9E9E)),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Continue button
          SizedBox(width: double.infinity, child: ElevatedButton.icon(
            onPressed: () => game.continueToSewerPhase(),
            icon: const Icon(Icons.plumbing_rounded),
            label: const Text('Continue to Sewer Repair  →',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 8,
            ),
          )),
          const SizedBox(height: 8),
          const Text('🔩 Pipe = Wrench  |  🔗 Joint = Tape  |  💧 Crack = Sealant',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.w600)),
        ]),
      )),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
//  SEWER RESULTS OVERLAY — shown after sewer repair phase ends
// ══════════════════════════════════════════════════════════════════════
class SewerResultsOverlay extends StatelessWidget {
  final CityCollectionGame game;
  const SewerResultsOverlay(this.game, {super.key});

  @override
  Widget build(BuildContext context) {
    final g   = game;
    final pct = (g.sewersFixed / CityCollectionGame.kTotalSewers * 100).round();

    return Container(
      color: Colors.black.withValues(alpha: 0.94),
      child: SafeArea(child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF0D47A1), Color(0xFF1565C0)]),
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 16)],
            ),
            child: Column(children: [
              const Icon(Icons.plumbing_rounded, color: Colors.cyanAccent, size: 52),
              const SizedBox(height: 8),
              const Text('🔧  Sewer Repair Complete!',
                  style: TextStyle(color: Colors.white, fontSize: 22,
                      fontWeight: FontWeight.bold, letterSpacing: 1)),
              const SizedBox(height: 4),
              const Text('Phase 2 — Repair Results',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
            ]),
          ),

          const SizedBox(height: 16),

          _ResultCard(children: [
            _BigStat('🔧', '${g.sewersFixed}/${CityCollectionGame.kTotalSewers}',
                'Sewers Repaired', Colors.cyanAccent),
            _BigStat('📊', '$pct%',  'Completion Rate',          Colors.limeAccent),
            _BigStat('⭐', '${math.max(0, g.sewerEcoPoints)}',
                'Sewer Eco-Points', Colors.amber),
            _BigStat('💥', '${g.sewerCollisions}', 'Collisions', Colors.redAccent),
          ]),

          const SizedBox(height: 12),

          // Sewer breakdown
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1B2A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Sewer Repairs by Type',
                  style: TextStyle(color: Colors.white70, fontSize: 12,
                      fontWeight: FontWeight.bold, letterSpacing: 1)),
              const SizedBox(height: 12),
              for (final s in g.sewers)
                _SewerRow(s),
            ]),
          ),

          const SizedBox(height: 20),

          SizedBox(width: double.infinity, child: ElevatedButton.icon(
            onPressed: () => game.continueToGrandFinale(),
            icon: const Icon(Icons.emoji_events_rounded),
            label: const Text('View Full Summary  →',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF388E3C), foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 8,
            ),
          )),
        ]),
      )),
    );
  }
}

class _SewerRow extends StatelessWidget {
  final SewerLeak sewer;
  const _SewerRow(this.sewer);

  @override
  Widget build(BuildContext context) {
    final name  = switch (sewer.leakType) {
      LeakType.pipe  => '🔩 Pipe Leak',
      LeakType.joint => '🔗 Joint Leak',
      LeakType.crack => '💧 Crack Leak',
    };
    final color  = sewer.isRepaired ? Colors.greenAccent : Colors.redAccent;
    final status = sewer.isRepaired ? '✅ Fixed' : '❌ Not Fixed';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Text('Sewer ${sewer.id + 1}',
            style: const TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(width: 8),
        Expanded(child: Text(name,
            style: const TextStyle(color: Colors.white, fontSize: 12))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.5)),
          ),
          child: Text(status, style: TextStyle(color: color,
              fontSize: 10, fontWeight: FontWeight.bold)),
        ),
      ]),
    );
  }
}

// ── Shared result card ──────────────────────────────────────────────────
class _ResultCard extends StatelessWidget {
  final List<Widget> children;
  const _ResultCard({required this.children});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    decoration: BoxDecoration(
      color: const Color(0xFF0D1B2A),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white12),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: children,
    ),
  );
}

class _BigStat extends StatelessWidget {
  final String emoji, value, label; final Color color;
  const _BigStat(this.emoji, this.value, this.label, this.color);
  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
    Text(emoji, style: const TextStyle(fontSize: 22)),
    const SizedBox(height: 4),
    Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 20)),
    const SizedBox(height: 2),
    Text(label, style: const TextStyle(color: Colors.white54, fontSize: 9),
        textAlign: TextAlign.center),
  ]);
}

class _WasteRow extends StatelessWidget {
  final String emoji, label; final int count; final Color color;
  const _WasteRow(this.emoji, this.label, this.count, this.color);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [
      Text(emoji, style: const TextStyle(fontSize: 16)),
      const SizedBox(width: 8),
      Expanded(child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13))),
      Container(
        width: 120,
        height: 8,
        decoration: BoxDecoration(
          color: Colors.white12,
          borderRadius: BorderRadius.circular(4),
        ),
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: count == 0 ? 0.0 : (count / 30.0).clamp(0.05, 1.0),
          child: Container(
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
          ),
        ),
      ),
      const SizedBox(width: 8),
      SizedBox(width: 28, child: Text('$count',
          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13),
          textAlign: TextAlign.right)),
    ]),
  );
}

// ══════════════════════════════════════════════════════════════════════
//  BRIEF PHASE TRANSITION LOADER (auto counts down to sewer phase)
// ══════════════════════════════════════════════════════════════════════
class CityPhaseTransition extends StatelessWidget {
  final CityCollectionGame game;
  const CityPhaseTransition(this.game, {super.key});
  @override
  Widget build(BuildContext context) => Container(
    color: Colors.black.withValues(alpha: 0.92),
    child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.plumbing_rounded, color: Color(0xFF2196F3), size: 64),
      const SizedBox(height: 16),
      const Text('Preparing Sewer Repair Phase…',
          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      const Text('Stop fully near glowing sewers beside buildings.\nSelect the right tool from your 🧰 toolbox!',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70, fontSize: 13)),
      const SizedBox(height: 8),
      const Text('🔩 Pipe = Wrench  |  🔗 Joint = Tape  |  💧 Crack = Sealant',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.w600)),
      const SizedBox(height: 28),
      const CircularProgressIndicator(color: Colors.cyanAccent),
    ])),
  );
}

// ══════════════════════════════════════════════════════════════════════
//  GRAND FINALE — combined totals from both phases
// ══════════════════════════════════════════════════════════════════════
class CityGameOver extends StatelessWidget {
  final CityCollectionGame game;
  const CityGameOver(this.game, {super.key});

  @override
  Widget build(BuildContext context) {
    final g         = game;
    final totalPts  = g.ecoPoints;
    final colPts    = math.max(0, g.collectionEcoPoints);
    final sewPts    = math.max(0, g.sewerEcoPoints);
    final totalCol  = g.collectionCollisions + g.sewerCollisions;

    return Container(
      color: Colors.black.withValues(alpha: 0.95),
      child: SafeArea(child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Column(children: [

          // ── Trophy header ────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFFFD700), width: 2),
              boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 24, spreadRadius: 4)],
            ),
            child: Column(children: [
              const Icon(Icons.emoji_events_rounded, color: Colors.amber, size: 64),
              const SizedBox(height: 10),
              const Text('🏙️  CITY MISSION COMPLETE!',
                  style: TextStyle(color: Colors.white, fontSize: 22,
                      fontWeight: FontWeight.bold, letterSpacing: 1.5)),
              const SizedBox(height: 4),
              Text('City cleaned & sewers repaired!',
                  style: TextStyle(color: Colors.green[300], fontSize: 13)),
            ]),
          ),

          const SizedBox(height: 14),

          // ── Grand total eco-points highlight ────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)]),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.limeAccent.withValues(alpha: 0.5), width: 1.5),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.eco_rounded, color: Colors.limeAccent, size: 32),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('TOTAL ECO-POINTS',
                    style: TextStyle(color: Colors.white60, fontSize: 11, letterSpacing: 1.5)),
                Text('$totalPts pts',
                    style: const TextStyle(color: Colors.limeAccent,
                        fontSize: 32, fontWeight: FontWeight.bold)),
              ]),
            ]),
          ),

          const SizedBox(height: 12),

          // ── Phase-by-phase points breakdown ─────────────────────────
          Row(children: [
            _PhaseCard(
              icon: Icons.delete_rounded,
              color: const Color(0xFF2E7D32),
              title: 'Phase 1\nCollection',
              stats: [
                _PStat('🗑️', '${g.wasteCollected}', 'items'),
                _PStat('💥', '${g.collectionCollisions}', 'crashes'),
                _PStat('⭐', '$colPts', 'pts'),
              ],
            ),
            const SizedBox(width: 10),
            _PhaseCard(
              icon: Icons.plumbing_rounded,
              color: const Color(0xFF0D47A1),
              title: 'Phase 2\nSewer Repair',
              stats: [
                _PStat('🔧', '${g.sewersFixed}/${CityCollectionGame.kTotalSewers}', 'sewers'),
                _PStat('💥', '${g.sewerCollisions}', 'crashes'),
                _PStat('⭐', '$sewPts', 'pts'),
              ],
            ),
          ]),

          const SizedBox(height: 12),

          // ── Waste collection full breakdown ──────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1B2A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Waste Collected by Category',
                  style: TextStyle(color: Colors.white70, fontSize: 12,
                      fontWeight: FontWeight.bold, letterSpacing: 1)),
              const SizedBox(height: 10),
              _WasteRow('🧴', 'Plastic',        g.plasticCollected,    const Color(0xFF2196F3)),
              _WasteRow('🍌', 'Organic',        g.organicCollected,    const Color(0xFF4CAF50)),
              _WasteRow('📱', 'E-Waste',        g.electronicCollected, const Color(0xFFF97316)),
              _WasteRow('🍶', 'Glass / Broken', g.glassCollected,      const Color(0xFF00BCD4)),
              _WasteRow('🔩', 'Metallic',       g.metallicCollected,   const Color(0xFFB0BEC5)),
              _WasteRow('🗑️', 'General',       g.generalCollected,    const Color(0xFF9E9E9E)),
            ]),
          ),

          const SizedBox(height: 12),

          // ── Overall stats row ─────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1B2A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(children: [
              _ResultRow(Icons.delete_rounded,    'Total Waste Collected',
                  '${g.wasteCollected}',                              Colors.greenAccent),
              _ResultRow(Icons.plumbing_rounded,  'Sewers Repaired',
                  '${g.sewersFixed}/${CityCollectionGame.kTotalSewers}', Colors.cyanAccent),
              _ResultRow(Icons.warning_rounded,   'Total Collisions',
                  '$totalCol',                                        Colors.orangeAccent),
              _ResultRow(Icons.eco_rounded,       'Total Eco-Points',
                  '$totalPts',                                        Colors.limeAccent),
            ]),
          ),

          const SizedBox(height: 20),

          // ── Proceed button ────────────────────────────────────────────
          SizedBox(width: double.infinity, child: ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const SortingFacilityScreen())),
            icon: const Icon(Icons.arrow_forward_rounded),
            label: const Text('PROCEED TO SORTING FACILITY',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 1)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50), foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 8, shadowColor: const Color(0xFF4CAF50),
            ),
          )),
          const SizedBox(height: 8),
        ]),
      )),
    );
  }
}

class _PhaseCard extends StatelessWidget {
  final IconData icon; final Color color;
  final String title; final List<_PStat> stats;
  const _PhaseCard({required this.icon, required this.color,
      required this.title, required this.stats});
  @override
  Widget build(BuildContext context) => Expanded(child: Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.6), color.withValues(alpha: 0.3)],
          begin: Alignment.topLeft, end: Alignment.bottomRight),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: color.withValues(alpha: 0.5)),
    ),
    child: Column(children: [
      Icon(icon, color: Colors.white, size: 22),
      const SizedBox(height: 4),
      Text(title, style: const TextStyle(color: Colors.white, fontSize: 11,
          fontWeight: FontWeight.bold), textAlign: TextAlign.center),
      const SizedBox(height: 8),
      for (final s in stats) ...[
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(s.emoji, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          Text(s.value, style: const TextStyle(color: Colors.white,
              fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(width: 3),
          Text(s.unit, style: const TextStyle(color: Colors.white54, fontSize: 9)),
        ]),
        const SizedBox(height: 2),
      ],
    ]),
  ));
}

class _PStat {
  final String emoji, value, unit;
  const _PStat(this.emoji, this.value, this.unit);
}

class _ResultRow extends StatelessWidget {
  final IconData icon; final String label, val; final Color color;
  const _ResultRow(this.icon, this.label, this.val, this.color);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(children: [
      Icon(icon, color: color, size: 18), const SizedBox(width: 10),
      Expanded(child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14))),
      Text(val, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15)),
    ]));
}