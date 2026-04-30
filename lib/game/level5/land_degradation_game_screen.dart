import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:ecoquest/game/level5/degraded_land_screen.dart';
import 'package:ecoquest/game/level5/soil_pollution_screen.dart';
import 'package:flame/components.dart' hide Matrix4;
import 'package:flame/game.dart' hide Matrix4;
import 'package:flutter/material.dart' hide Matrix4;
import 'package:flutter/services.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  LAND DEGRADATION GAME SCREEN  ·  EcoQuest Level 5  ·  Phase 1 & 2
//
//  PHASE 1 — LAND SURVEY (Enhanced)
//   • Proximity hover-to-scan: drone must hold within 115 px of a patch for
//     3 s to complete a full scan (wind and dust actively disrupt this)
//   • Wind zones: 3 dynamic zones with rotating force vectors that push the
//     drone off-course; direction changes every ~9 s
//   • Dust cloud obstacles: 3 drifting clouds that cut scan speed by 60 %
//     and reduce drone visibility when the drone is inside them
//   • Identification quiz: after every full scan an educational mini-challenge
//     fires — player must classify the erosion type from 3 options within 6 s
//     for a 15-point bonus and an eco-fact unlock
//   • Quick-scan fallback (SCAN tap): reveals patch with no quiz bonus
//
//  PHASE 2 — TERRAIN RESTORATION (Enhanced)
//   • Two-step restoration: every patch requires a structural fix (step 1)
//     then a biological treatment (step 2) — five tools total
//   • Tool inventory: 4 uses each; correct tool chains earn a refill use
//   • Combo multiplier: restore patches within 4 s of each other to reach
//     2×, 2.5× or 3× point multipliers; breaking the chain costs the bonus
//   • Rain event: every ~40 s a storm warning fires → 3-second countdown →
//     up to 2 step-1 patches become at-risk with a 9-second countdown timer;
//     if not treated in time they reset to step 0 and raise the erosion index
//   • Erosion surge: every ~25 s inactivity triggers an erosion spike (+10 %)
//     unless the player has restored ≥ 2 patches since the last surge (+4 %)
// ══════════════════════════════════════════════════════════════════════════════

// ── Result class passed forward to SoilPollutionScreen ───────────────────────
class LandDegradationResult {
  final int    patchesRestored;
  final int    wrongTools;
  final int    ecoPoints;
  final double erosionIndex;
  final bool   terrainStabilised;
  final int    identifiedCorrectly;
  final int    maxCombo;

  const LandDegradationResult({
    required this.patchesRestored,
    required this.wrongTools,
    required this.ecoPoints,
    required this.erosionIndex,
    required this.terrainStabilised,
    this.identifiedCorrectly = 0,
    this.maxCombo            = 1,
  });

  static LandDegradationResult? current;
}

// ── Enums ─────────────────────────────────────────────────────────────────────
enum DegradationType  { steepSlope, gully, bareLand, drySoil }
enum RestorationTool  { terrace, checkDam, coverCrop, biochar, compost }
enum RestorationStep  { none, stabilized, restored }

// ── Internal data types ───────────────────────────────────────────────────────
class WindZone {
  final Vector2 center;
  final double  radius;
  Vector2       force;
  WindZone({required this.center, required this.radius, required this.force});
}

class IdOption {
  final String label;
  final bool   correct;
  final String fact;
  const IdOption(this.label, {required this.correct, this.fact = ''});
}

// ══════════════════════════════════════════════════════════════════════════════
//  SCREEN WRAPPER
// ══════════════════════════════════════════════════════════════════════════════
class LandDegradationGameScreen extends StatefulWidget {
  final Level4CarryOver carryOver;
  const LandDegradationGameScreen({super.key, required this.carryOver});

  @override
  State<LandDegradationGameScreen> createState() =>
      _LandDegradationGameScreenState();
}

class _LandDegradationGameScreenState
    extends State<LandDegradationGameScreen> {
  late LandDegradationGame _game;

  @override
  void initState() {
    super.initState();
    _game = LandDegradationGame(
      carryOver:       widget.carryOver,
      onLevelComplete: _onDone,
    );
  }

  void _onDone() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => SoilPollutionScreen(carryOver: widget.carryOver),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GameWidget(
        game: _game,
        overlayBuilderMap: {
          'hud':            (ctx, g) => LandHud(g as LandDegradationGame),
          'controls':       (ctx, g) => LandControls(g as LandDegradationGame),
          'banner':         (ctx, g) => LandPhaseBanner(g as LandDegradationGame),
          'toolSelect':     (ctx, g) => RestorationToolSelector(g as LandDegradationGame),
          'reactionFx':     (ctx, g) => LandReactionFx(g as LandDegradationGame),
          'results':        (ctx, g) => LandResultsOverlay(g as LandDegradationGame),
          'identification': (ctx, g) => IdentificationOverlay(g as LandDegradationGame),
          'weatherAlert':   (ctx, g) => WeatherAlertOverlay(g as LandDegradationGame),
        },
        initialActiveOverlays: const ['hud', 'controls'],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  MAIN GAME CLASS
// ══════════════════════════════════════════════════════════════════════════════
class LandDegradationGame extends FlameGame
    with HasCollisionDetection, ChangeNotifier {

  final Level4CarryOver carryOver;
  final VoidCallback    onLevelComplete;

  LandDegradationGame({required this.carryOver, required this.onLevelComplete});

  // ── Core ───────────────────────────────────────────────────────────────────
  int    gamePhase   = 1;
  bool   gameStarted = false;
  double timeLeft    = 135.0;
  bool   levelDone   = false;

  // ── Score ──────────────────────────────────────────────────────────────────
  int ecoPoints           = 0;
  int wrongTools          = 0;
  int restoredCount       = 0;
  int stabilizedCount     = 0;
  int scannedCount        = 0;
  int identifiedCorrectly = 0;
  int maxCombo            = 1;

  // ── Erosion ────────────────────────────────────────────────────────────────
  double erosionIndex                = 92.0;
  static const double _targetErosion = 20.0;

  // ── Ranges ─────────────────────────────────────────────────────────────────
  static const double _scanRange     = 155.0;
  static const double _hoverRange    = 115.0;
  static const double _applyRange    = 100.0;
  static const double _scanMaxRadius = 180.0;

  // ── Drone physics ──────────────────────────────────────────────────────────
  late Vector2 dronePos;
  bool isUp = false, isDown = false, isLeft = false, isRight = false;
  static const double _droneSpeed = 185.0;
  Vector2 activeWindForce = Vector2.zero();

  // ── Phase 1 · Scan system ──────────────────────────────────────────────────
  DegradedPatch? activeScanPatch;
  double         scanHoldTime   = 0.0;
  static const double _scanDuration = 3.0;
  bool   inDustCloud  = false;
  bool   scanActive   = false;
  double scanRadius   = 0;

  // ── Phase 1 · Identification challenge ────────────────────────────────────
  bool            identificationActive  = false;
  DegradedPatch?  identificationTarget;
  List<IdOption> identificationOptions = [];
  double          identificationTimer   = 0;
  static const double _idTimeout        = 6.0;
  String?         lastIdFact;

  // ── Phase 1 · Wind zones ───────────────────────────────────────────────────
  final List<WindZone> windZones       = [];
  double                _windChangeTimer = 0;
  static const double   _windPeriod     = 9.0;

  // ── Phase 1 · Dust clouds ──────────────────────────────────────────────────
  final List<DustCloudComponent> dustClouds = [];

  // ── Phase 2 · Tool inventory ───────────────────────────────────────────────
  RestorationTool selectedTool = RestorationTool.terrace;
  final Map<RestorationTool, int> toolUses = {
    RestorationTool.terrace:   4,
    RestorationTool.checkDam:  4,
    RestorationTool.coverCrop: 4,
    RestorationTool.biochar:   4,
    RestorationTool.compost:   4,
  };
  bool get canUseSelectedTool => (toolUses[selectedTool] ?? 0) > 0;

  // ── Phase 2 · Combo ────────────────────────────────────────────────────────
  int    comboCount       = 0;
  double comboTimer       = 0;
  static const double _comboWindow = 4.0;
  bool   showComboFlash   = false;
  double comboFlashTimer  = 0;

  // ── Phase 2 · Rain event ───────────────────────────────────────────────────
  double _rainTimer      = 42.0;
  bool   rainWarning     = false;
  bool   rainActive      = false;
  double _rainWarningCd  = 0;
  double _rainActiveCd   = 0;
  double weatherIntensity = 0;
  final Set<DegradedPatch> riskPatches = {};

  // ── Phase 2 · Erosion surge ────────────────────────────────────────────────
  double _surgeTimer             = 25.0;
  int    _patchesSinceLastSurge  = 0;
  bool   surgePending            = false;
  double surgePulse              = 0;

  // ── Reaction FX ───────────────────────────────────────────────────────────
  bool   reactionActive  = false;
  bool   reactionCorrect = false;
  int    reactionPhase   = 1;
  bool   reactionInRange = true;
  double reactionTimer   = 0;
  String reactionMsg     = '';

  // ── Banner ─────────────────────────────────────────────────────────────────
  double bannerTimer = 3.5;

  // ── Components ─────────────────────────────────────────────────────────────
  late RestorationDroneComponent drone;
  final List<DegradedPatch> patches = [];

  @override
  Future<void> onLoad() async {
    super.onLoad();
    dronePos = Vector2(size.x * 0.50, size.y * 0.58);

    _initWindZones();
    add(ErodedLandRenderer(game: this));
    _spawnDustClouds();
    drone = RestorationDroneComponent(game: this);
    add(drone);
    _spawnPatches();

    bannerTimer = 3.5;
    overlays.add('banner');
    add(TimerComponent(period: 1.0, repeat: true, onTick: _onSecond));
  }

  // ── Initialisation helpers ─────────────────────────────────────────────────
  void _initWindZones() {
    final rng       = math.Random(42);
    final positions = [
      Vector2(size.x * 0.22, size.y * 0.38),
      Vector2(size.x * 0.62, size.y * 0.28),
      Vector2(size.x * 0.78, size.y * 0.62),
    ];
    for (final pos in positions) {
      final angle = rng.nextDouble() * math.pi * 2;
      final mag   = 55.0 + rng.nextDouble() * 35.0;
      final zone  = WindZone(
        center: pos,
        radius: 115.0 + rng.nextDouble() * 40.0,
        force:  Vector2(math.cos(angle) * mag, math.sin(angle) * mag),
      );
      windZones.add(zone);
      add(WindZoneRenderer(zone: zone, game: this));
    }
  }

  void _spawnDustClouds() {
    final rng = math.Random(99);
    for (int i = 0; i < 3; i++) {
      final cloud = DustCloudComponent(
        game:   this,
        startX: size.x * (0.15 + rng.nextDouble() * 0.70),
        startY: size.y * (0.20 + rng.nextDouble() * 0.50),
        radius: 80.0  + rng.nextDouble() * 45.0,
        speed:  18.0  + rng.nextDouble() * 14.0,
        seed:   i * 33 + 7,
      );
      dustClouds.add(cloud);
      add(cloud);
    }
  }

  void _spawnPatches() {
    const specs = [
      (DegradationType.steepSlope, 0.14, 0.28),
      (DegradationType.steepSlope, 0.72, 0.22),
      (DegradationType.gully,      0.30, 0.55),
      (DegradationType.gully,      0.64, 0.48),
      (DegradationType.bareLand,   0.48, 0.35),
      (DegradationType.bareLand,   0.86, 0.62),
      (DegradationType.drySoil,    0.18, 0.70),
      (DegradationType.drySoil,    0.56, 0.72),
    ];
    for (int i = 0; i < specs.length; i++) {
      final (type, rx, ry) = specs[i];
      final p = DegradedPatch(
        game: this, type: type,
        worldX: size.x * rx, worldY: size.y * ry,
        seed: i * 17,
      );
      add(p);
      patches.add(p);
    }
  }

  void _onSecond() {
    if (!gameStarted || levelDone) return;
    timeLeft -= 1;
    if (timeLeft <= 0) { timeLeft = 0; _endLevel(); }
    notifyListeners();
  }

  // ── Getters ────────────────────────────────────────────────────────────────
  double get scanHoldProgress =>
      activeScanPatch != null ? (scanHoldTime / _scanDuration).clamp(0.0, 1.0) : 0.0;

  bool get _hasNearbyUnscanned =>
      patches.any((p) => !p.isScanned && (p.patchPos - dronePos).length <= _scanRange);

  bool get _hasNearbyUnrestored =>
      patches.any((p) => !p.isRestored && (p.patchPos - dronePos).length <= _applyRange);

  DegradedPatch? get _nearestActionable {
    DegradedPatch? best; double minD = _applyRange;
    for (final p in patches) {
      if (p.isRestored) continue;
      final d = (p.patchPos - dronePos).length;
      if (d < minD) { minD = d; best = p; }
    }
    return best;
  }

  // ── Phase 1: Quick scan (tap, no quiz) ────────────────────────────────────
  void triggerQuickScan() {
    if (!gameStarted || levelDone || gamePhase != 1 || identificationActive) return;
    HapticFeedback.selectionClick();
    int newly = 0;
    for (final p in patches) {
      if (p.isScanned) continue;
      if ((p.patchPos - dronePos).length <= _scanRange) {
        p.isScanned = true; scannedCount++; ecoPoints += 3; newly++;
      }
    }
    if (newly > 0) {
      scanActive = true; scanRadius = 0;
      reactionMsg = '+${newly * 3} pts  •  Quick scan — no quiz bonus';
      _triggerReaction(true);
      if (scannedCount >= patches.length) {
        Future.delayed(const Duration(milliseconds: 900), _advanceToPhase2);
      }
    } else {
      _triggerReaction(false, inRange: false);
    }
    notifyListeners();
  }

  // ── Phase 1: Full hover-scan completion ────────────────────────────────────
  void _completePatchScan(DegradedPatch p) {
    if (p.isScanned) return;
    p.isScanned = true; scannedCount++;
    scanActive  = true; scanRadius = 0;
    HapticFeedback.mediumImpact();

    identificationTarget  = p;
    identificationOptions = _buildIdOptions(p.type);
    identificationTimer   = _idTimeout;
    identificationActive  = true;
    overlays.add('identification');
    notifyListeners();
  }

  List<IdOption> _buildIdOptions(DegradationType t) {
    List<IdOption> opts;
    switch (t) {
      case DegradationType.steepSlope:
        opts = [
          const IdOption('Steep Erosion Slope (>30°)', correct: true,
              fact: 'Slopes over 30° lose topsoil up to 20× faster than flat land.'),
          const IdOption('Riverbank Undercut', correct: false),
          const IdOption('Rock Outcrop Face',  correct: false),
        ];
      case DegradationType.gully:
        opts = [
          const IdOption('Active Erosion Gully', correct: true,
              fact: 'Gullies can advance 30 m per year during Kenya\'s long rains.'),
          const IdOption('Seasonal Dry Streambed', correct: false),
          const IdOption('Wildlife Corridor Path',  correct: false),
        ];
      case DegradationType.bareLand:
        opts = [
          const IdOption('Bare / Denuded Land', correct: true,
              fact: 'Bare land can lose up to 60 tonnes of topsoil per hectare per year.'),
          const IdOption('Harvested Crop Field', correct: false),
          const IdOption('Savanna Grassland',    correct: false),
        ];
      case DegradationType.drySoil:
        opts = [
          const IdOption('Severely Desiccated Soil', correct: true,
              fact: 'Cracked dry soil has lost over 80 % of its water-holding capacity.'),
          const IdOption('Sandy Desert Surface', correct: false),
          const IdOption('Clay Hardpan Layer',   correct: false),
        ];
    }
    // Shuffle so correct answer is not always first
    final rng = math.Random();
    for (int i = opts.length - 1; i > 0; i--) {
      final j = rng.nextInt(i + 1);
      final tmp = opts[i]; opts[i] = opts[j]; opts[j] = tmp;
    }
    return opts;
  }

  void answerIdentification(int idx) {
    if (!identificationActive) return;
    final opt = identificationOptions[idx];
    if (opt.correct) {
      ecoPoints += 15; identifiedCorrectly++; lastIdFact = opt.fact;
      HapticFeedback.heavyImpact();
    } else {
      ecoPoints += 5; lastIdFact = null; // still get some points
      HapticFeedback.vibrate();
    }
    _closeIdentification();
  }

  void dismissIdentificationTimeout() {
    if (!identificationActive) return;
    _closeIdentification();
  }

  void _closeIdentification() {
    identificationActive = false;
    overlays.remove('identification');
    notifyListeners();
    if (scannedCount >= patches.length) {
      Future.delayed(const Duration(milliseconds: 700), _advanceToPhase2);
    }
  }

  void _advanceToPhase2() {
    if (levelDone) return;
    gamePhase = 2; bannerTimer = 3.0;
    overlays..add('banner')..add('toolSelect');
    notifyListeners();
  }

  // ── Phase 2: Apply tool ────────────────────────────────────────────────────
  void applyTool() {
    if (!gameStarted || levelDone || gamePhase != 2 || identificationActive) return;
    if (!canUseSelectedTool) {
      reactionMsg = '⚠️ No ${_toolLabel(selectedTool)} uses left!';
      _triggerReaction(false, inRange: false); return;
    }
    final target = _nearestActionable;
    if (target == null) {
      reactionMsg = '✈️ Move closer to a degraded patch';
      _triggerReaction(false, inRange: false); return;
    }

    HapticFeedback.lightImpact();
    toolUses[selectedTool] = (toolUses[selectedTool] ?? 1) - 1;
    final correct = _isCorrectTool(target.type, selectedTool, target.step);

    if (correct) {
      if (target.step == RestorationStep.none) {
        target.step = RestorationStep.stabilized; stabilizedCount++;
        erosionIndex = math.max(0, erosionIndex - 5.0);
        final pts    = 10 * _comboMult();
        ecoPoints   += pts; _incCombo();
        riskPatches.remove(target); target.isAtRisk = false;
        reactionMsg  = '🏗️ Step 1 done!  +$pts pts';
        _triggerReaction(true);
      } else if (target.step == RestorationStep.stabilized) {
        target.step = RestorationStep.restored; restoredCount++;
        erosionIndex = math.max(0, erosionIndex - 9.0);
        final pts    = 20 * _comboMult();
        ecoPoints   += pts; _incCombo();
        riskPatches.remove(target); target.isAtRisk = false;
        reactionMsg  = '🌿 Fully Restored!  +$pts pts';
        _triggerReaction(true);
        _patchesSinceLastSurge++;
      }
    } else {
      wrongTools++;
      erosionIndex = math.min(100, erosionIndex + 3.0);
      ecoPoints    = math.max(0, ecoPoints - 5);
      _breakCombo();
      reactionMsg  = '❌ Wrong tool for this patch';
      _triggerReaction(false);
    }

    if (erosionIndex <= _targetErosion || patches.every((p) => p.isRestored)) {
      Future.delayed(const Duration(milliseconds: 800), _endLevel);
    }
    notifyListeners();
  }

  int _comboMult() {
    if (comboCount >= 4) return 3;
    if (comboCount >= 3) return 2;
    if (comboCount >= 2) return 2;
    return 1;
  }

  void _incCombo() {
    comboCount++; comboTimer = _comboWindow;
    if (comboCount > maxCombo) maxCombo = comboCount;
    if (comboCount >= 3) {
      toolUses[selectedTool] = (toolUses[selectedTool] ?? 0) + 1;
    }
    showComboFlash = true; comboFlashTimer = 1.6;
    notifyListeners();
  }

  void _breakCombo() { comboCount = 0; comboTimer = 0; }

  bool _isCorrectTool(DegradationType type, RestorationTool tool, RestorationStep step) {
    if (step == RestorationStep.none) {
      switch (type) {
        case DegradationType.steepSlope: return tool == RestorationTool.terrace;
        case DegradationType.gully:      return tool == RestorationTool.checkDam;
        case DegradationType.bareLand:   return tool == RestorationTool.coverCrop;
        case DegradationType.drySoil:    return tool == RestorationTool.biochar;
      }
    } else {
      switch (type) {
        case DegradationType.steepSlope: return tool == RestorationTool.coverCrop;
        case DegradationType.gully:      return tool == RestorationTool.biochar;
        case DegradationType.bareLand:   return tool == RestorationTool.compost;
        case DegradationType.drySoil:    return tool == RestorationTool.compost;
      }
    }
  }

  String _toolLabel(RestorationTool t) {
    switch (t) {
      case RestorationTool.terrace:   return 'Terrace';
      case RestorationTool.checkDam:  return 'Check Dam';
      case RestorationTool.coverCrop: return 'Cover Crop';
      case RestorationTool.biochar:   return 'Biochar';
      case RestorationTool.compost:   return 'Compost';
    }
  }

  // ── Input ──────────────────────────────────────────────────────────────────
  void setUpKey(bool v)    { isUp    = v; if (v) gameStarted = true; }
  void setDownKey(bool v)  { isDown  = v; if (v) gameStarted = true; }
  void setLeftKey(bool v)  { isLeft  = v; if (v) gameStarted = true; }
  void setRightKey(bool v) { isRight = v; if (v) gameStarted = true; }
  void selectTool(RestorationTool t) { selectedTool = t; notifyListeners(); }

  // ── Reaction FX ───────────────────────────────────────────────────────────
  void _triggerReaction(bool correct, {bool inRange = true}) {
    reactionActive  = true; reactionCorrect = correct;
    reactionPhase   = gamePhase; reactionInRange = inRange;
    reactionTimer   = 1.3;
    overlays.add('reactionFx');
  }

  // ── Rain event ─────────────────────────────────────────────────────────────
  void _triggerRainWarning() {
    rainWarning = true; _rainWarningCd = 3.2;
    overlays.add('weatherAlert'); notifyListeners();
  }

  void _triggerRainActive() {
    rainWarning = false; rainActive = true;
    _rainActiveCd = 9.5; weatherIntensity = 1.0;
    overlays.remove('weatherAlert');
    riskPatches.clear();
    final step1 = patches
        .where((p) => p.step == RestorationStep.stabilized && !p.isRestored)
        .toList()..shuffle(math.Random());
    for (int i = 0; i < math.min(2, step1.length); i++) {
      step1[i].isAtRisk  = true;
      step1[i].riskTimer = 9.5;
      riskPatches.add(step1[i]);
    }
    notifyListeners();
  }

  void _endRainActive() {
    rainActive = false; weatherIntensity = 0;
    for (final p in List<DegradedPatch>.from(riskPatches)) {
      if (p.isAtRisk && !p.isRestored) {
        p.step = RestorationStep.none; p.isAtRisk = false;
        stabilizedCount = math.max(0, stabilizedCount - 1);
        erosionIndex    = math.min(100, erosionIndex + 7.0);
      }
    }
    riskPatches.clear(); notifyListeners();
  }

  // ── Erosion surge ──────────────────────────────────────────────────────────
  void _triggerSurge() {
    erosionIndex = math.min(100,
        erosionIndex + (_patchesSinceLastSurge >= 2 ? 4.0 : 10.0));
    ecoPoints = math.max(0, ecoPoints - 5);
    _patchesSinceLastSurge = 0;
    surgePending = true; surgePulse = 1.0;
    notifyListeners();
  }

  void _endLevel() {
    if (levelDone) return;
    levelDone = true; pauseEngine();
    LandDegradationResult.current = LandDegradationResult(
      patchesRestored:     restoredCount,
      wrongTools:          wrongTools,
      ecoPoints:           ecoPoints,
      erosionIndex:        erosionIndex,
      terrainStabilised:   erosionIndex <= _targetErosion,
      identifiedCorrectly: identifiedCorrectly,
      maxCombo:            maxCombo,
    );
    overlays
      ..remove('reactionFx')
      ..remove('toolSelect')
      ..remove('identification')
      ..remove('weatherAlert')
      ..add('results');
    notifyListeners();
  }

  // ── Update loop ────────────────────────────────────────────────────────────
  @override
  void update(double dt) {
    super.update(dt);

    // ── Global timers (always) ───────────────────────────────────────────
    if (bannerTimer > 0) {
      bannerTimer -= dt;
      if (bannerTimer <= 0) overlays.remove('banner');
    }
    if (reactionTimer > 0) {
      reactionTimer -= dt;
      if (reactionTimer <= 0) { reactionActive = false; overlays.remove('reactionFx'); }
    }
    if (scanActive) {
      scanRadius += dt * 220;
      if (scanRadius >= _scanMaxRadius) scanActive = false;
    }
    if (surgePulse > 0) {
      surgePulse = math.max(0, surgePulse - dt * 0.9);
      if (surgePulse == 0) surgePending = false;
    }

    if (!gameStarted || levelDone) { notifyListeners(); return; }

    // ── Drone movement with wind ─────────────────────────────────────────
    double vx = 0, vy = 0;
    if (isLeft)  vx -= 1;
    if (isRight) vx += 1;
    if (isUp)    vy -= 1;
    if (isDown)  vy += 1;

    activeWindForce = Vector2.zero();
    for (final zone in windZones) {
      final d = (zone.center - dronePos).length;
      if (d < zone.radius) {
        final str = 1.0 - (d / zone.radius);
        activeWindForce += zone.force * str;
      }
    }
    dronePos.x = (dronePos.x + (vx * _droneSpeed + activeWindForce.x) * dt)
        .clamp(30, size.x - 30);
    dronePos.y = (dronePos.y + (vy * _droneSpeed + activeWindForce.y) * dt)
        .clamp(40, size.y * 0.88);

    // ── Wind direction rotation ──────────────────────────────────────────
    _windChangeTimer += dt;
    if (_windChangeTimer >= _windPeriod) {
      _windChangeTimer = 0;
      final rng = math.Random();
      for (final zone in windZones) {
        final angle = rng.nextDouble() * math.pi * 2;
        final mag   = 45.0 + rng.nextDouble() * 55.0;
        zone.force  = Vector2(math.cos(angle) * mag, math.sin(angle) * mag);
      }
    }

    // ── Dust cloud interference ──────────────────────────────────────────
    inDustCloud = dustClouds.any(
        (dc) => (dc.cloudPos - dronePos).length < dc.radius + 18);

    // ── Phase 1: Proximity hover-scan ────────────────────────────────────
    if (gamePhase == 1 && !identificationActive) {
      // Find nearest unscanned patch within hover range
      DegradedPatch? nearest; double nearestD = _hoverRange;
      for (final p in patches) {
        if (p.isScanned) continue;
        final d = (p.patchPos - dronePos).length;
        if (d < nearestD) { nearestD = d; nearest = p; }
      }

      if (nearest != null) {
        if (activeScanPatch != nearest) {
          activeScanPatch = nearest; scanHoldTime = 0;
        }
        // Dust clouds cut scan rate by 60 %
        final rate = inDustCloud ? 0.40 : 1.0;
        scanHoldTime += dt * rate;
        if (scanHoldTime >= _scanDuration) {
          scanHoldTime = 0;
          final p = activeScanPatch!;
          activeScanPatch = null;
          _completePatchScan(p);
        }
      } else {
        // Decay progress when out of range
        if (activeScanPatch != null) {
          scanHoldTime = math.max(0, scanHoldTime - dt * 1.6);
          if (scanHoldTime == 0) activeScanPatch = null;
        }
      }
    }

    // ── Identification timer countdown ───────────────────────────────────
    if (identificationActive) {
      identificationTimer -= dt;
      if (identificationTimer <= 0) dismissIdentificationTimeout();
      notifyListeners(); return;
    }

    // ── Phase 2 timers ────────────────────────────────────────────────────
    if (gamePhase == 2) {
      // Combo window
      if (comboCount > 0) {
        comboTimer -= dt;
        if (comboTimer <= 0) _breakCombo();
      }
      if (comboFlashTimer > 0) {
        comboFlashTimer -= dt;
        if (comboFlashTimer <= 0) showComboFlash = false;
      }

      // Rain event
      _rainTimer -= dt;
      if (_rainTimer <= 0 && !rainWarning && !rainActive) {
        _rainTimer = 38.0 + math.Random().nextDouble() * 22.0;
        _triggerRainWarning();
      }
      if (rainWarning) {
        _rainWarningCd -= dt;
        if (_rainWarningCd <= 0) { rainWarning = false; _triggerRainActive(); }
      }
      if (rainActive) {
        _rainActiveCd   -= dt;
        weatherIntensity = (_rainActiveCd / 9.5).clamp(0.0, 1.0);
        if (_rainActiveCd <= 0) _endRainActive();
        // Per-patch risk countdown
        for (final p in List<DegradedPatch>.from(riskPatches)) {
          if (p.isAtRisk) {
            p.riskTimer -= dt;
            if (p.riskTimer <= 0 && !p.isRestored) {
              p.isAtRisk   = false;
              riskPatches.remove(p);
              if (p.step == RestorationStep.stabilized) {
                p.step = RestorationStep.none;
                stabilizedCount = math.max(0, stabilizedCount - 1);
                erosionIndex    = math.min(100, erosionIndex + 7.0);
              }
            }
          }
        }
      }

      // Erosion surge
      _surgeTimer -= dt;
      if (_surgeTimer <= 0) {
        _surgeTimer = 22.0 + math.Random().nextDouble() * 14.0;
        _triggerSurge();
      }
    }

    notifyListeners();
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  ERODED LAND RENDERER  (with rain streaks + surge flash)
// ══════════════════════════════════════════════════════════════════════════════
class ErodedLandRenderer extends Component {
  final LandDegradationGame game;
  double _t = 0;
  ErodedLandRenderer({required this.game});

  @override
  void update(double dt) => _t += dt * 0.25;

  @override
  void render(Canvas canvas) {
    final w = game.size.x, h = game.size.y;

    // Sky gradient
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h),
        Paint()..shader = ui.Gradient.linear(
          Offset.zero, Offset(0, h),
          [const Color(0xFF120A04),
           Color.lerp(const Color(0xFF1E1008), const Color(0xFF2A1404),
               (math.sin(_t) * 0.5 + 0.5) * 0.4)!,
           const Color(0xFF0A0602)],
          [0.0, 0.5, 1.0],
        ));

    // Erosion tint — red when high
    final er = (game.erosionIndex / 92.0).clamp(0.0, 1.0);
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h),
        Paint()
          ..color = const Color(0xFFEF5350).withValues(alpha: er * 0.05)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30));

    // Erosion surge flash
    if (game.surgePulse > 0) {
      canvas.drawRect(Rect.fromLTWH(0, 0, w, h),
          Paint()..color = const Color(0xFFFF6D00)
              .withValues(alpha: game.surgePulse * 0.18));
    }

    _drawTerrainPaths(canvas, w, h);
    _drawBarrenBlocks(canvas, w, h);
    canvas.drawRect(Rect.fromLTWH(0, h * 0.86, w, h * 0.14),
        Paint()..color = const Color(0xFF080602));

    // Rain overlay
    if (game.weatherIntensity > 0) _drawRain(canvas, w, h);
  }

  void _drawTerrainPaths(Canvas canvas, double w, double h) {
    final p = Paint()..color = const Color(0xFF0E0904)..strokeWidth = 10;
    for (final ry in [0.30, 0.55, 0.76]) {
      canvas.drawLine(Offset(0, h * ry), Offset(w, h * ry), p);
    }
    for (final rx in [0.25, 0.52, 0.78]) {
      canvas.drawLine(Offset(w * rx, 0), Offset(w * rx, h * 0.86), p);
    }
  }

  void _drawBarrenBlocks(Canvas canvas, double w, double h) {
    final rng    = math.Random(44);
    const blocks = [
      (0.02, 0.02, 0.21, 0.26), (0.27, 0.02, 0.23, 0.26),
      (0.54, 0.02, 0.22, 0.26), (0.78, 0.02, 0.20, 0.26),
      (0.02, 0.32, 0.21, 0.21), (0.27, 0.32, 0.23, 0.21),
      (0.54, 0.32, 0.22, 0.21), (0.78, 0.32, 0.20, 0.21),
      (0.02, 0.57, 0.21, 0.17),
    ];
    for (final (bx, by, bw, bh) in blocks) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(w * bx + 4, h * by + 4, w * bw - 8, h * bh - 8),
              const Radius.circular(3)),
          Paint()..color = const Color(0xFF120A04));
      _drawCracks(canvas, w * bx + 6, h * by + 6, w * bw - 12, h * bh - 12, rng);
    }
  }

  void _drawCracks(Canvas canvas, double bx, double by,
      double bw, double bh, math.Random rng) {
    final p = Paint()
      ..color = const Color(0xFF2A1804).withValues(alpha: 0.50)
      ..strokeWidth = 1.0;
    for (int i = 0; i < 5; i++) {
      final cx = bx + rng.nextDouble() * bw;
      final cy = by + rng.nextDouble() * bh;
      final len   = 8 + rng.nextDouble() * 14;
      final angle = rng.nextDouble() * math.pi;
      canvas.drawLine(Offset(cx, cy),
          Offset(cx + math.cos(angle) * len, cy + math.sin(angle) * len), p);
    }
  }

  void _drawRain(Canvas canvas, double w, double h) {
    final alpha = game.weatherIntensity * 0.55;
    final rng   = math.Random(11);
    final paint = Paint()
      ..color = const Color(0xFF90CAF9).withValues(alpha: alpha)
      ..strokeWidth = 1.0
      ..strokeCap   = StrokeCap.round;
    for (int i = 0; i < 80; i++) {
      final rx   = rng.nextDouble() * w;
      final ry   = rng.nextDouble() * h;
      final len  = 10.0 + rng.nextDouble() * 18.0;
      final phase = ((_t * 4.0 + rng.nextDouble() * 6.0) % 1.0);
      final y    = (ry + phase * h * 0.6) % h;
      canvas.drawLine(Offset(rx - len * 0.15, y),
          Offset(rx + len * 0.15, y + len), paint);
    }
    // Blue rain tint
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h),
        Paint()..color = const Color(0xFF1565C0)
            .withValues(alpha: game.weatherIntensity * 0.07));
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  RESTORATION DRONE COMPONENT
// ══════════════════════════════════════════════════════════════════════════════
class RestorationDroneComponent extends Component {
  final LandDegradationGame game;
  double _t = 0;
  RestorationDroneComponent({required this.game});

  @override
  void update(double dt) => _t += dt;

  @override
  void render(Canvas canvas) {
    final cx = game.dronePos.x;
    final cy = game.dronePos.y + math.sin(_t * 3.0) * 2.5;

    // Scan pulse ring
    if (game.scanActive) {
      final alpha = (1.0 - game.scanRadius / LandDegradationGame._scanMaxRadius) * 0.30;
      canvas.drawCircle(Offset(cx, cy), game.scanRadius,
          Paint()
            ..color = const Color(0xFFFFB300).withValues(alpha: alpha)
            ..style = PaintingStyle.stroke..strokeWidth = 2.5);
    }

    // Range indicator
    final rangeColor = game.gamePhase == 1
        ? const Color(0xFFFFB300) : const Color(0xFF69F0AE);
    final rangeR = game.gamePhase == 1
        ? LandDegradationGame._scanRange : LandDegradationGame._applyRange;
    canvas.drawCircle(Offset(cx, cy), rangeR,
        Paint()
          ..color = rangeColor.withValues(alpha: 0.06)
          ..style = PaintingStyle.stroke..strokeWidth = 1.2);

    // Hover range indicator (phase 1 only)
    if (game.gamePhase == 1) {
      // Dashed hover-range circle drawn manually as arc segments
      final dashPaint = Paint()
        ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..strokeCap = StrokeCap.round;
      const double r = LandDegradationGame._hoverRange;
      const int    segments = 28;
      const double dashFrac = 0.55;
      for (int seg = 0; seg < segments; seg++) {
        final startAngle = (seg / segments) * math.pi * 2 + _t * 0.6;
        final sweep      = (math.pi * 2 / segments) * dashFrac;
        canvas.drawArc(
          Rect.fromCenter(center: Offset(cx, cy), width: r * 2, height: r * 2),
          startAngle, sweep, false, dashPaint,
        );
      }
    }

    // Dust-cloud tint on drone
    if (game.inDustCloud) {
      canvas.drawCircle(Offset(cx, cy), 40,
          Paint()..color = const Color(0xFFBCAAA4).withValues(alpha: 0.20)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18));
    }

    // Wind deflection visual (small arrow)
    final wf = game.activeWindForce;
    if (wf.length > 10) {
      final ang  = math.atan2(wf.y, wf.x);
      final arrowLen = math.min(wf.length * 0.35, 28.0);
      final ex = cx + math.cos(ang) * arrowLen;
      final ey = cy + math.sin(ang) * arrowLen;
      canvas.drawLine(Offset(cx, cy), Offset(ex, ey),
          Paint()..color = const Color(0xFF80CBC4).withValues(alpha: 0.65)
            ..strokeWidth = 2.0..strokeCap = StrokeCap.round);
    }

    canvas.save();
    canvas.translate(cx, cy);

    // Shadow
    canvas.drawOval(
        Rect.fromCenter(center: const Offset(0, 14), width: 38, height: 9),
        Paint()..color = Colors.black.withValues(alpha: 0.28));

    // Arms
    final armP = Paint()
      ..color = const Color(0xFF3A2810)..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;
    for (final (dx, dy) in [(-1, -1), (1, -1), (-1, 1), (1, 1)]) {
      canvas.drawLine(Offset(dx * 8, dy * 8), Offset(dx * 22, dy * 22), armP);
    }

    // Propellers (spin faster if moving)
    final propPaint = Paint()
      ..color = const Color(0xFFFFB300).withValues(alpha: 0.55)
      ..strokeWidth = 1.8..strokeCap = StrokeCap.round;
    const propPositions = [(-22.0, -22.0), (22.0, -22.0), (-22.0, 22.0), (22.0, 22.0)];
    for (final (px, py) in propPositions) {
      canvas.save();
      canvas.translate(px, py);
      canvas.rotate(_t * 12);
      canvas.drawLine(const Offset(-8, 0), const Offset(8, 0), propPaint);
      canvas.drawLine(const Offset(0, -8), const Offset(0, 8), propPaint);
      canvas.restore();
    }

    // Body
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(-13, -10, 26, 20), const Radius.circular(6)),
        Paint()..color = const Color(0xFF2A1C0A));

    // Sensor glow
    final glowColor = game.gamePhase == 1
        ? const Color(0xFFFFB300) : const Color(0xFF69F0AE);
    canvas.drawCircle(Offset.zero, 7,
        Paint()
          ..color = glowColor.withValues(alpha: 0.75 + math.sin(_t * 4) * 0.20)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    canvas.drawCircle(Offset.zero, 3.5,
        Paint()..color = Colors.white.withValues(alpha: 0.95));

    // Phase icon
    final tp = TextPainter(
      text: TextSpan(
          text: game.gamePhase == 1 ? '🛰️' : '🪨',
          style: const TextStyle(fontSize: 8)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(-tp.width / 2, 13 - tp.height / 2));

    canvas.restore();
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  DEGRADED PATCH COMPONENT  (two-step restoration + risk timer)
// ══════════════════════════════════════════════════════════════════════════════
class DegradedPatch extends Component {
  final LandDegradationGame game;
  final DegradationType type;
  double hx, hy;
  final int seed;

  bool           isScanned = false;
  RestorationStep step      = RestorationStep.none;
  bool           isAtRisk   = false;
  double         riskTimer  = 0;
  double         _t         = 0;

  bool get isRestored   => step == RestorationStep.restored;
  bool get isStabilized => step == RestorationStep.stabilized;

  DegradedPatch({
    required this.game, required this.type,
    required double worldX, required double worldY,
    required this.seed,
  }) : hx = worldX, hy = worldY;

  Vector2 get patchPos => Vector2(hx, hy);

  static const _specs = {
    DegradationType.steepSlope: ('🏔️', 'Steep\nSlope',   Color(0xFFEF5350), 'High'),
    DegradationType.gully:      ('🕳️', 'Erosion\nGully', Color(0xFFFF6D00), 'Severe'),
    DegradationType.bareLand:   ('🌾', 'Bare\nLand',     Color(0xFFFFB300), 'Med'),
    DegradationType.drySoil:    ('🪨', 'Dry\nSoil',      Color(0xFFBCAAA4), 'Low'),
  };

  // Step-1 completion emoji per type
  static const _step1Emoji = {
    DegradationType.steepSlope: '🏗️',
    DegradationType.gully:      '🧱',
    DegradationType.bareLand:   '🌱',
    DegradationType.drySoil:    '⬛',
  };

  @override
  void update(double dt) => _t += dt;

  @override
  void render(Canvas canvas) {
    final spec  = _specs[type]!;
    final color = spec.$3;
    final pulse = 0.65 + math.sin(_t * 2.8) * 0.22;

    if (step == RestorationStep.restored) {
      _drawRestored(canvas); return;
    }

    // Scan progress ring (phase 1, active scan)
    if (game.gamePhase == 1 && game.activeScanPatch == this) {
      _drawScanProgress(canvas, game.scanHoldProgress);
    }

    // At-risk rain animation
    if (isAtRisk) {
      final urgency = math.sin(_t * 6).abs();
      canvas.drawCircle(Offset(hx, hy), 40 + urgency * 8,
          Paint()..color = const Color(0xFFFF9800).withValues(alpha: 0.18 + urgency * 0.12)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
    }

    if (isScanned) {
      // Outer glow
      canvas.drawCircle(Offset(hx, hy), 36 * pulse,
          Paint()..color = color.withValues(alpha: 0.07 + pulse * 0.05)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12));

      // Step indicator ring
      final ringColor = step == RestorationStep.stabilized
          ? const Color(0xFF29B6F6) : color;
      canvas.drawCircle(Offset(hx, hy), 28,
          Paint()..color = ringColor.withValues(alpha: 0.15));
      canvas.drawCircle(Offset(hx, hy), 28,
          Paint()..color = ringColor.withValues(alpha: 0.70)
            ..style = PaintingStyle.stroke..strokeWidth = 2.2);

      // Main emoji
      final ep = TextPainter(
        text: TextSpan(
            text: step == RestorationStep.stabilized
                ? _step1Emoji[type]! : spec.$1,
            style: const TextStyle(fontSize: 14)),
        textDirection: TextDirection.ltr,
      )..layout();
      ep.paint(canvas, Offset(hx - ep.width / 2, hy - ep.height / 2 - 7));

      // Step badge
      final badge = step == RestorationStep.stabilized ? 'Step 2' : 'Step 1';
      final dp = TextPainter(
        text: TextSpan(text: badge,
            style: TextStyle(color: ringColor, fontSize: 8.5,
                fontWeight: FontWeight.bold)),
        textDirection: TextDirection.ltr,
      )..layout();
      dp.paint(canvas, Offset(hx - dp.width / 2, hy + 14));

      // Risk countdown
      if (isAtRisk) {
        final tp = TextPainter(
          text: TextSpan(text: '⛈️ ${riskTimer.ceil()}s',
              style: const TextStyle(color: Color(0xFFFF9800),
                  fontSize: 9, fontWeight: FontWeight.bold)),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(hx - tp.width / 2, hy - 46));
      }
    } else {
      // Unknown — pulsing amber ring
      canvas.drawCircle(Offset(hx, hy), 30 * pulse,
          Paint()..color = const Color(0xFFBCAAA4).withValues(alpha: 0.07)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9));
      canvas.drawCircle(Offset(hx, hy), 22,
          Paint()..color = const Color(0xFFBCAAA4).withValues(alpha: 0.10));
      canvas.drawCircle(Offset(hx, hy), 22,
          Paint()..color = const Color(0xFFBCAAA4).withValues(alpha: 0.55)
            ..style = PaintingStyle.stroke..strokeWidth = 1.8);
      final qp = TextPainter(
        text: const TextSpan(text: '?',
            style: TextStyle(color: Color(0xFFBCAAA4),
                fontSize: 14, fontWeight: FontWeight.bold)),
        textDirection: TextDirection.ltr,
      )..layout();
      qp.paint(canvas, Offset(hx - qp.width / 2, hy - qp.height / 2));
    }
  }

  void _drawScanProgress(Canvas canvas, double progress) {
    const startAngle = -math.pi / 2;
    const full       = math.pi * 2;

    // Background ring
    canvas.drawCircle(Offset(hx, hy), 38,
        Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: 0.08)
          ..style = PaintingStyle.stroke..strokeWidth = 4.0);

    // Progress arc
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCenter(center: Offset(hx, hy), width: 76, height: 76),
        startAngle, full * progress, false,
        Paint()
          ..color = const Color(0xFFFFB300).withValues(alpha: 0.85)
          ..style = PaintingStyle.stroke..strokeWidth = 4.0
          ..strokeCap = StrokeCap.round,
      );
    }

    // Scan label
    if (progress < 0.99) {
      final pct = (progress * 100).toInt();
      final tp  = TextPainter(
        text: TextSpan(text: '$pct%',
            style: const TextStyle(color: Color(0xFFFFB300),
                fontSize: 9, fontWeight: FontWeight.bold)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(hx - tp.width / 2, hy - 52));
    }
  }

  void _drawRestored(Canvas canvas) {
    canvas.drawCircle(Offset(hx, hy), 22,
        Paint()..color = const Color(0xFF69F0AE).withValues(alpha: 0.14));
    canvas.drawCircle(Offset(hx, hy), 22,
        Paint()..color = const Color(0xFF69F0AE).withValues(alpha: 0.60)
          ..style = PaintingStyle.stroke..strokeWidth = 2.0);
    final tp = TextPainter(
      text: const TextSpan(text: '🌿', style: TextStyle(fontSize: 13)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(hx - tp.width / 2, hy - tp.height / 2));
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  DUST CLOUD COMPONENT  (phase 1 obstacle)
// ══════════════════════════════════════════════════════════════════════════════
class DustCloudComponent extends Component {
  final LandDegradationGame game;
  Vector2 cloudPos;
  final double radius;
  final double speed;
  double _dx, _dy;
  double _t = 0;

  DustCloudComponent({
    required this.game,
    required double startX,
    required double startY,
    required this.radius,
    required this.speed,
    required int seed,
  })  : cloudPos = Vector2(startX, startY),
        _dx      = math.cos(seed.toDouble()) * 1.0,
        _dy      = math.sin(seed.toDouble()) * 1.0;

  @override
  void update(double dt) {
    _t += dt;
    cloudPos.x += _dx * speed * dt;
    cloudPos.y += _dy * speed * dt;

    // Bounce off screen edges
    if (cloudPos.x < radius)             { cloudPos.x = radius;             _dx =  _dx.abs(); }
    if (cloudPos.x > game.size.x - radius) { cloudPos.x = game.size.x - radius; _dx = -_dx.abs(); }
    if (cloudPos.y < radius)             { cloudPos.y = radius;             _dy =  _dy.abs(); }
    if (cloudPos.y > game.size.y * 0.85 - radius) {
      cloudPos.y = game.size.y * 0.85 - radius;  _dy = -_dy.abs();
    }

    // Slow drift rotation
    final angle = math.atan2(_dy, _dx) + math.sin(_t * 0.4) * 0.015;
    _dx = math.cos(angle); _dy = math.sin(angle);
  }

  @override
  void render(Canvas canvas) {
    final droneDist = (cloudPos - game.dronePos).length;
    final inside    = droneDist < radius + 18;
    final alpha     = inside ? 0.38 : 0.22;

    // Layered dust blob
    for (final (r, a) in [(radius * 1.4, 0.08), (radius, 0.14), (radius * 0.65, 0.08)]) {
      canvas.drawCircle(Offset(cloudPos.x, cloudPos.y), r,
          Paint()..color = const Color(0xFFBCAAA4).withValues(alpha: a + alpha * 0.3)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22));
    }

    // Interference icon when drone is inside
    if (inside && game.gamePhase == 1) {
      final tp = TextPainter(
        text: const TextSpan(text: '🌫️  Scan slowed',
            style: TextStyle(color: Color(0xFFBCAAA4),
                fontSize: 9, fontWeight: FontWeight.w700)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(cloudPos.x - tp.width / 2, cloudPos.y - 22));
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  WIND ZONE RENDERER  (visual indicator of wind zones)
// ══════════════════════════════════════════════════════════════════════════════
class WindZoneRenderer extends Component {
  final WindZone           zone;
  final LandDegradationGame game;
  double _t = 0;
  WindZoneRenderer({required this.zone, required this.game});

  @override
  void update(double dt) => _t += dt;

  @override
  void render(Canvas canvas) {
    final cx = zone.center.x, cy = zone.center.y;
    final r  = zone.radius;
    final angle = math.atan2(zone.force.y, zone.force.x);

    // Only visible in phase 1
    if (game.gamePhase != 1) return;

    final inZone = (zone.center - game.dronePos).length < r;
    final alpha  = inZone ? 0.28 : 0.14;

    // Boundary ring (dashed)
    final ringPaint = Paint()
      ..color = const Color(0xFF80CBC4).withValues(alpha: alpha)
      ..style = PaintingStyle.stroke..strokeWidth = 1.5;
    canvas.drawCircle(Offset(cx, cy), r, ringPaint);

    // Rotating wind arrows
    for (int i = 0; i < 4; i++) {
      final a     = angle + (i / 4) * math.pi * 2 + _t * 1.2;
      final ox    = cx + math.cos(a) * r * 0.52;
      final oy    = cy + math.sin(a) * r * 0.52;
      final ex    = ox + math.cos(angle) * 18;
      final ey    = oy + math.sin(angle) * 18;
      canvas.drawLine(Offset(ox, oy), Offset(ex, ey),
          Paint()..color = const Color(0xFF80CBC4).withValues(alpha: alpha + 0.08)
            ..strokeWidth = 2.0..strokeCap = StrokeCap.round);
      // Arrowhead
      final ha = math.pi * 0.75;
      canvas.drawLine(Offset(ex, ey),
          Offset(ex + math.cos(angle + ha) * 7, ey + math.sin(angle + ha) * 7),
          Paint()..color = const Color(0xFF80CBC4).withValues(alpha: alpha)
            ..strokeWidth = 1.5..strokeCap = StrokeCap.round);
      canvas.drawLine(Offset(ex, ey),
          Offset(ex + math.cos(angle - ha) * 7, ey + math.sin(angle - ha) * 7),
          Paint()..color = const Color(0xFF80CBC4).withValues(alpha: alpha)
            ..strokeWidth = 1.5..strokeCap = StrokeCap.round);
    }

    // Wind label when drone is inside
    if (inZone) {
      final strength = zone.force.length;
      final label    = strength > 75 ? '💨 Strong Wind' : '💨 Wind';
      final tp = TextPainter(
        text: TextSpan(text: label,
            style: const TextStyle(color: Color(0xFF80CBC4),
                fontSize: 9.5, fontWeight: FontWeight.bold)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(cx - tp.width / 2, cy - r - 16));
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  HUD
// ══════════════════════════════════════════════════════════════════════════════
class LandHud extends StatelessWidget {
  final LandDegradationGame game;
  const LandHud(this.game, {super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: game,
      builder: (_, __) {
        final warn         = game.timeLeft < 20;
        final erosionRatio = (game.erosionIndex / 100.0).clamp(0.0, 1.0);
        final erosionColor = game.erosionIndex < 20
            ? const Color(0xFF69F0AE)
            : game.erosionIndex < 50
                ? const Color(0xFFFFB300)
                : const Color(0xFFEF5350);

        return SafeArea(child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch, children: [

            // Phase pill
            Align(alignment: Alignment.topCenter, child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
              decoration: BoxDecoration(
                color: game.gamePhase == 1
                    ? const Color(0xFFFFB300).withValues(alpha: 0.88)
                    : const Color(0xFF69F0AE).withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(
                    color: (game.gamePhase == 1
                        ? const Color(0xFFFFB300) : const Color(0xFF69F0AE))
                        .withValues(alpha: 0.35),
                    blurRadius: 10)],
              ),
              child: Text(
                game.gamePhase == 1
                    ? '🛰️  PHASE 1 — LAND SURVEY'
                    : '🪨  PHASE 2 — TERRAIN RESTORATION',
                style: const TextStyle(color: Colors.white,
                    fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1.1),
              ),
            )),
            const SizedBox(height: 8),

            // Stats row
            Row(children: [
              _LHTile(Icons.timer_rounded, '${game.timeLeft.toInt()}s', 'TIME',
                  warn ? Colors.red : Colors.white),
              const SizedBox(width: 5),
              _LHTile(Icons.radar_rounded,
                  game.gamePhase == 1
                      ? '${game.scannedCount}/8'
                      : '${game.restoredCount}/8',
                  game.gamePhase == 1 ? 'SCANNED' : 'RESTORED',
                  const Color(0xFFFFB300)),
              const SizedBox(width: 5),
              _LHTile(Icons.eco_rounded, '${game.ecoPoints}', 'ECO-PTS',
                  Colors.limeAccent),
              const SizedBox(width: 5),
              _LHTile(Icons.terrain_rounded,
                  '${game.erosionIndex.toStringAsFixed(0)}%', 'EROSION',
                  erosionColor),
            ]),
            const SizedBox(height: 5),

            // Phase 1: scan progress bar
            if (game.gamePhase == 1 && game.activeScanPatch != null) ...[
              Row(children: [
                const Text('🛰️', style: TextStyle(fontSize: 12)),
                const SizedBox(width: 5),
                Expanded(child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: game.scanHoldProgress,
                    backgroundColor: Colors.white12,
                    valueColor: const AlwaysStoppedAnimation(Color(0xFFFFB300)),
                    minHeight: 7,
                  ),
                )),
                const SizedBox(width: 6),
                Text(game.inDustCloud ? '🌫️ Slowed' : 'Scanning…',
                    style: TextStyle(
                        color: game.inDustCloud
                            ? const Color(0xFFBCAAA4) : const Color(0xFFFFB300),
                        fontSize: 9, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 4),
            ],

            // Phase 2: erosion + combo bar
            if (game.gamePhase == 2) ...[
              Row(children: [
                const Text('🏜️', style: TextStyle(fontSize: 13)),
                const SizedBox(width: 5),
                Expanded(child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: 1.0 - erosionRatio,
                    backgroundColor: Colors.white12,
                    valueColor: AlwaysStoppedAnimation(erosionColor),
                    minHeight: 7,
                  ),
                )),
                const SizedBox(width: 6),
                RichText(text: TextSpan(children: [
                  TextSpan(text: '${game.erosionIndex.toStringAsFixed(0)}%',
                      style: TextStyle(color: erosionColor, fontSize: 10,
                          fontWeight: FontWeight.bold)),
                  const TextSpan(text: ' / 20%',
                      style: TextStyle(color: Color(0xFF69F0AE), fontSize: 8)),
                ])),
              ]),
              const SizedBox(height: 4),

              // Combo pill
              if (game.comboCount > 0)
                Align(
                  alignment: Alignment.centerRight,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6D00).withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFF6D00)
                          .withValues(alpha: 0.60)),
                    ),
                    child: Text(
                      '🔥 ${game.comboCount}× Combo  '
                      '(${game.comboTimer.toStringAsFixed(1)}s)',
                      style: const TextStyle(color: Color(0xFFFF6D00),
                          fontSize: 9, fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
            ],
          ]),
        ));
      },
    );
  }
}

class _LHTile extends StatelessWidget {
  final IconData icon;
  final String val, label;
  final Color color;
  const _LHTile(this.icon, this.val, this.label, this.color);

  @override
  Widget build(BuildContext context) => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
    decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12)),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: color, size: 13),
      Text(val, style: TextStyle(color: color,
          fontWeight: FontWeight.bold, fontSize: 12)),
      Text(label, style: const TextStyle(color: Colors.white54,
          fontSize: 7, letterSpacing: 0.7)),
    ]),
  ));
}

// ══════════════════════════════════════════════════════════════════════════════
//  CONTROLS
// ══════════════════════════════════════════════════════════════════════════════
class LandControls extends StatefulWidget {
  final LandDegradationGame game;
  const LandControls(this.game, {super.key});
  @override
  State<LandControls> createState() => _LandControlsState();
}

class _LandControlsState extends State<LandControls> {
  bool _up = false, _dn = false, _lt = false, _rt = false;
  late FocusNode _fk;

  @override
  void initState() {
    super.initState();
    _fk = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fk.requestFocus());
  }

  @override
  void dispose() { _fk.dispose(); super.dispose(); }

  void _onKey(KeyEvent e) {
    final pressed  = e is KeyDownEvent || e is KeyRepeatEvent;
    final released = e is KeyUpEvent;
    final k        = e.logicalKey;

    void up(bool v) { setState(() => _up = v); widget.game.setUpKey(v); }
    void dn(bool v) { setState(() => _dn = v); widget.game.setDownKey(v); }
    void lt(bool v) { setState(() => _lt = v); widget.game.setLeftKey(v); }
    void rt(bool v) { setState(() => _rt = v); widget.game.setRightKey(v); }

    if (k == LogicalKeyboardKey.keyW || k == LogicalKeyboardKey.arrowUp)
      { if (pressed) up(true); if (released) up(false); }
    if (k == LogicalKeyboardKey.keyS || k == LogicalKeyboardKey.arrowDown)
      { if (pressed) dn(true); if (released) dn(false); }
    if (k == LogicalKeyboardKey.keyA || k == LogicalKeyboardKey.arrowLeft)
      { if (pressed) lt(true); if (released) lt(false); }
    if (k == LogicalKeyboardKey.keyD || k == LogicalKeyboardKey.arrowRight)
      { if (pressed) rt(true); if (released) rt(false); }

    if (k == LogicalKeyboardKey.space && pressed) {
      if (widget.game.gamePhase == 1) {
        widget.game.triggerQuickScan();
      } else {
        widget.game.applyTool();
      }
    }
    if (pressed) {
      if (k == LogicalKeyboardKey.digit1) widget.game.selectTool(RestorationTool.terrace);
      if (k == LogicalKeyboardKey.digit2) widget.game.selectTool(RestorationTool.checkDam);
      if (k == LogicalKeyboardKey.digit3) widget.game.selectTool(RestorationTool.coverCrop);
      if (k == LogicalKeyboardKey.digit4) widget.game.selectTool(RestorationTool.biochar);
      if (k == LogicalKeyboardKey.digit5) widget.game.selectTool(RestorationTool.compost);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.game,
      builder: (_, __) {
        final phase  = widget.game.gamePhase;
        final canAct = phase == 1
            ? widget.game._hasNearbyUnscanned
            : widget.game._hasNearbyUnrestored;
        final actColor = phase == 1
            ? const Color(0xFFFFB300) : const Color(0xFF69F0AE);

        return KeyboardListener(
          focusNode: _fk,
          onKeyEvent: _onKey,
          child: Stack(children: [

            // D-pad (bottom-left)
            Align(
              alignment: Alignment.bottomLeft,
              child: SafeArea(child: Padding(
                padding: const EdgeInsets.only(bottom: 16, left: 12),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  _LDPad('⬆', _up, Colors.cyanAccent,
                      onDown: () { setState(() => _up = true);  widget.game.setUpKey(true); },
                      onUp:   () { setState(() => _up = false); widget.game.setUpKey(false); }),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    _LDPad('◀', _lt, Colors.cyanAccent,
                        onDown: () { setState(() => _lt = true);  widget.game.setLeftKey(true); },
                        onUp:   () { setState(() => _lt = false); widget.game.setLeftKey(false); }),
                    const SizedBox(width: 4),
                    _LDPad('⬇', _dn, Colors.cyanAccent,
                        onDown: () { setState(() => _dn = true);  widget.game.setDownKey(true); },
                        onUp:   () { setState(() => _dn = false); widget.game.setDownKey(false); }),
                    const SizedBox(width: 4),
                    _LDPad('▶', _rt, Colors.cyanAccent,
                        onDown: () { setState(() => _rt = true);  widget.game.setRightKey(true); },
                        onUp:   () { setState(() => _rt = false); widget.game.setRightKey(false); }),
                  ]),
                ]),
              )),
            ),

            // Action button (bottom-right)
            Align(
              alignment: Alignment.bottomRight,
              child: SafeArea(child: Padding(
                padding: const EdgeInsets.only(bottom: 20, right: 14),
                child: Column(mainAxisSize: MainAxisSize.min, children: [

                  // Phase 1 hint
                  if (phase == 1 && widget.game.activeScanPatch != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.70),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFFB300).withValues(alpha: 0.40)),
                      ),
                      child: Text(
                        widget.game.inDustCloud
                            ? '🌫️ Move out of dust!'
                            : '🛰️ Hold position…',
                        style: const TextStyle(color: Color(0xFFFFB300),
                            fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),

                  // Main action button
                  GestureDetector(
                    onTap: () {
                      if (phase == 1) { widget.game.triggerQuickScan(); }
                      else { widget.game.applyTool(); }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 140),
                      width: 68, height: 68,
                      decoration: BoxDecoration(
                        color: canAct
                            ? actColor.withValues(alpha: 0.22)
                            : Colors.black.withValues(alpha: 0.60),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: canAct ? actColor : Colors.white24,
                            width: canAct ? 2.5 : 1.5),
                        boxShadow: canAct
                            ? [BoxShadow(color: actColor.withValues(alpha: 0.40),
                                blurRadius: 14)]
                            : [],
                      ),
                      child: Center(child: Text(
                        phase == 1 ? '🛰️\nQUICK\nSCAN' : '🪨\nAPPLY',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: canAct ? actColor : Colors.white30,
                            fontWeight: FontWeight.w900,
                            fontSize: 8, letterSpacing: 0.3, height: 1.3),
                      )),
                    ),
                  ),
                ]),
              )),
            ),
          ]),
        );
      },
    );
  }
}

class _LDPad extends StatelessWidget {
  final String label;
  final bool isActive;
  final Color color;
  final VoidCallback onDown, onUp;
  const _LDPad(this.label, this.isActive, this.color,
      {required this.onDown, required this.onUp});

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (_) => onDown(),
    onPointerUp:   (_) => onUp(),
    onPointerCancel: (_) => onUp(),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 70),
      width: 52, height: 52,
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: isActive ? color.withValues(alpha: 0.30) : Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isActive ? color : Colors.white24, width: 1.8),
        boxShadow: isActive
            ? [BoxShadow(color: color.withValues(alpha: 0.40), blurRadius: 10)] : [],
      ),
      child: Center(child: Text(label,
          style: TextStyle(color: isActive ? color : Colors.white60,
              fontSize: 16, fontWeight: FontWeight.bold))),
    ),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
//  PHASE BANNER
// ══════════════════════════════════════════════════════════════════════════════
class LandPhaseBanner extends StatelessWidget {
  final LandDegradationGame game;
  const LandPhaseBanner(this.game, {super.key});

  @override
  Widget build(BuildContext context) {
    final phase1 = game.gamePhase == 1;
    final accent = phase1 ? const Color(0xFFFFB300) : const Color(0xFF69F0AE);

    return IgnorePointer(child: Center(child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: phase1
            ? [const Color(0xFF1A1000), const Color(0xFF2E1800)]
            : [const Color(0xFF001A0A), const Color(0xFF003018)]),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 24)],
        border: Border.all(color: accent.withValues(alpha: 0.55), width: 1.5),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(phase1 ? 'PHASE 1' : 'PHASE 2',
            style: const TextStyle(color: Colors.white54,
                fontSize: 13, letterSpacing: 2.5)),
        const SizedBox(height: 4),
        Text(phase1 ? '🛰️  Land Survey' : '🪨  Terrain Restoration',
            style: const TextStyle(color: Colors.white,
                fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text(
          phase1
              ? 'Hover within the dashed circle to auto-scan.\nFight wind & avoid dust clouds!'
              : 'Two steps per patch: Structural → Biological.\nWatch for rain events & surges!',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ]),
    )));
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  RESTORATION TOOL SELECTOR  (Phase 2 — 5 tools with inventory + step hints)
// ══════════════════════════════════════════════════════════════════════════════
class RestorationToolSelector extends StatelessWidget {
  final LandDegradationGame game;
  const RestorationToolSelector(this.game, {super.key});

  // (tool, emoji, label, color, step, targets)
  static const _tools = [
    (RestorationTool.terrace,   '🏔️', 'Terrace',    Color(0xFFEF5350), '①', 'Steep Slope'),
    (RestorationTool.checkDam,  '🧱', 'Check Dam',  Color(0xFFFF6D00), '①', 'Gully'),
    (RestorationTool.coverCrop, '🌱', 'Cover Crop', Color(0xFFFFB300), '①②', 'Bare Land / Slope'),
    (RestorationTool.biochar,   '⬛', 'Biochar',    Color(0xFFBCAAA4), '①②', 'Dry Soil / Gully'),
    (RestorationTool.compost,   '🌿', 'Compost',    Color(0xFF69F0AE), '②', 'Bare / Dry Soil'),
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: game,
      builder: (_, __) {
        final mobile = MediaQuery.of(context).size.width < 600;
        return Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(child: Padding(
            padding: const EdgeInsets.only(bottom: 84, left: 10, right: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.82),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('SELECT RESTORATION TOOL',
                    style: TextStyle(color: Colors.white54, fontSize: 8,
                        letterSpacing: 1.4, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Row(mainAxisAlignment: MainAxisAlignment.center,
                    children: _tools.map((t) {
                  final (tool, emoji, label, color, step, target) = t;
                  final sel  = game.selectedTool == tool;
                  final uses = game.toolUses[tool] ?? 0;
                  final out  = uses == 0;

                  return GestureDetector(
                    onTap: () { if (!out) game.selectTool(tool); },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 140),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      padding: EdgeInsets.symmetric(
                          horizontal: mobile ? 7 : 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: out
                            ? Colors.white.withValues(alpha: 0.03)
                            : sel
                                ? color.withValues(alpha: 0.22)
                                : Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(
                            color: out
                                ? Colors.white.withValues(alpha: 0.10)
                                : sel ? color : Colors.white12,
                            width: sel ? 2.0 : 1.0),
                        boxShadow: sel
                            ? [BoxShadow(color: color.withValues(alpha: 0.35),
                                blurRadius: 10)]
                            : [],
                      ),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(emoji, style: TextStyle(
                            fontSize: mobile ? 17 : 21,
                            color: out ? null : null)),
                        const SizedBox(height: 2),
                        Text(label, textAlign: TextAlign.center,
                            style: TextStyle(
                              color: out
                                  ? Colors.white24
                                  : sel ? color : Colors.white70,
                              fontWeight: FontWeight.w900,
                              fontSize: mobile ? 7 : 8.5, height: 1.1,
                            )),
                        const SizedBox(height: 1),
                        Text(step, style: TextStyle(
                            color: out ? Colors.white12
                                : color.withValues(alpha: 0.75),
                            fontSize: 8, fontWeight: FontWeight.bold)),
                        Text(out ? '✗' : '×$uses',
                            style: TextStyle(
                              color: out ? Colors.redAccent
                                  : sel ? color : Colors.white38,
                              fontSize: 8,
                            )),
                      ]),
                    ),
                  );
                }).toList()),

                const SizedBox(height: 6),
                // Step legend
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  _legendDot(const Color(0xFFEF5350), '① Structural'),
                  const SizedBox(width: 12),
                  _legendDot(const Color(0xFF69F0AE), '② Biological'),
                ]),
              ]),
            ),
          )),
        );
      },
    );
  }

  Widget _legendDot(Color c, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(width: 7, height: 7,
          decoration: BoxDecoration(shape: BoxShape.circle, color: c)),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(color: c.withValues(alpha: 0.80),
          fontSize: 8, fontWeight: FontWeight.w600)),
    ],
  );
}

// ══════════════════════════════════════════════════════════════════════════════
//  IDENTIFICATION OVERLAY  (Phase 1 post-scan quiz)
// ══════════════════════════════════════════════════════════════════════════════
class IdentificationOverlay extends StatefulWidget {
  final LandDegradationGame game;
  const IdentificationOverlay(this.game, {super.key});
  @override
  State<IdentificationOverlay> createState() => _IdentificationOverlayState();
}

class _IdentificationOverlayState extends State<IdentificationOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  int? _selectedIdx;
  bool _revealed = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 400))..forward();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  void _pick(int idx) {
    if (_revealed) return;
    setState(() { _selectedIdx = idx; _revealed = true; });
    Future.delayed(const Duration(milliseconds: 820), () {
      widget.game.answerIdentification(idx);
    });
  }

  @override
  Widget build(BuildContext context) {
    final opts   = widget.game.identificationOptions;
    final mobile = MediaQuery.of(context).size.width < 600;
    final tLeft  = widget.game.identificationTimer;
    final prog   = (tLeft / LandDegradationGame._idTimeout).clamp(0.0, 1.0);

    return AnimatedBuilder(
      animation: widget.game,
      builder: (_, __) => Container(
        color: Colors.black.withValues(alpha: 0.78),
        alignment: Alignment.center,
        child: FadeTransition(
          opacity: _ctrl,
          child: Container(
            margin: EdgeInsets.symmetric(
                horizontal: mobile ? 18 : 80, vertical: 20),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1A1200), Color(0xFF2A1E00)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFFFB300).withValues(alpha: 0.50)),
              boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 28)],
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [

              // Header
              const Text('🔍  IDENTIFY THE TERRAIN',
                  style: TextStyle(color: Color(0xFFFFB300), fontSize: 13,
                      fontWeight: FontWeight.w900, letterSpacing: 1.4)),
              const SizedBox(height: 4),
              const Text('Classify the scanned degradation to earn bonus eco-points',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54, fontSize: 11)),
              const SizedBox(height: 14),

              // Countdown bar
              Stack(children: [
                ClipRRect(borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: prog,
                    backgroundColor: Colors.white12,
                    valueColor: AlwaysStoppedAnimation(
                        prog > 0.5 ? const Color(0xFFFFB300)
                            : prog > 0.25 ? Colors.orange : Colors.red),
                    minHeight: 6,
                  ),
                ),
              ]),
              Align(alignment: Alignment.centerRight,
                child: Padding(padding: const EdgeInsets.only(top: 3),
                  child: Text('${tLeft.ceil()}s',
                      style: const TextStyle(color: Colors.white38, fontSize: 9)))),
              const SizedBox(height: 14),

              // Options
              ...opts.asMap().entries.map((e) {
                final idx = e.key; final opt = e.value;
                Color? bg; Color? border;
                if (_revealed) {
                  if (opt.correct) { bg = const Color(0xFF1A4A20); border = const Color(0xFF69F0AE); }
                  else if (idx == _selectedIdx) { bg = const Color(0xFF4A1A1A); border = const Color(0xFFEF5350); }
                }
                return GestureDetector(
                  onTap: () => _pick(idx),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    decoration: BoxDecoration(
                      color: bg ?? Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(
                          color: border ?? Colors.white.withValues(alpha: 0.16)),
                    ),
                    child: Row(children: [
                      Container(
                        width: 24, height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: border?.withValues(alpha: 0.18) ?? Colors.white12,
                          border: Border.all(color: border ?? Colors.white24),
                        ),
                        child: Center(child: Text(String.fromCharCode(65 + idx),
                            style: TextStyle(
                                color: border ?? Colors.white54,
                                fontWeight: FontWeight.bold, fontSize: 11))),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(opt.label,
                          style: TextStyle(
                            color: border != null ? Colors.white : Colors.white70,
                            fontSize: 12, fontWeight: FontWeight.w600,
                          ))),
                      if (_revealed && opt.correct)
                        const Text('✅', style: TextStyle(fontSize: 14)),
                      if (_revealed && !opt.correct && idx == _selectedIdx)
                        const Text('❌', style: TextStyle(fontSize: 14)),
                    ]),
                  ),
                );
              }),

              // Eco-fact reveal
              if (_revealed && widget.game.identificationOptions
                  .any((o) => o.correct && o.fact.isNotEmpty)) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF69F0AE).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF69F0AE)
                        .withValues(alpha: 0.30)),
                  ),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    const Text('🌍  ', style: TextStyle(fontSize: 14)),
                    Expanded(child: Text(
                      widget.game.identificationOptions
                          .firstWhere((o) => o.correct).fact,
                      style: const TextStyle(color: Color(0xFF69F0AE),
                          fontSize: 11, height: 1.4),
                    )),
                  ]),
                ),
              ],

              // Points hint
              if (!_revealed) ...[
                const SizedBox(height: 12),
                const Text('+15 pts for correct  •  +5 pts for any answer',
                    style: TextStyle(color: Colors.white30, fontSize: 10)),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  WEATHER ALERT OVERLAY  (rain countdown warning)
// ══════════════════════════════════════════════════════════════════════════════
class WeatherAlertOverlay extends StatelessWidget {
  final LandDegradationGame game;
  const WeatherAlertOverlay(this.game, {super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: game,
      builder: (_, __) {
        final cd = game._rainWarningCd;
        return IgnorePointer(
          child: Align(
            alignment: Alignment.topCenter,
            child: SafeArea(child: Container(
              margin: const EdgeInsets.only(top: 60),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF0D1B2A).withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF29B6F6)
                    .withValues(alpha: 0.70), width: 1.5),
                boxShadow: [BoxShadow(
                    color: const Color(0xFF29B6F6).withValues(alpha: 0.25),
                    blurRadius: 20)],
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Text('⛈️', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Column(mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('RAIN EVENT INCOMING',
                      style: TextStyle(color: Color(0xFF29B6F6), fontSize: 11,
                          fontWeight: FontWeight.w900, letterSpacing: 1.4)),
                  const SizedBox(height: 2),
                  Text(
                    'Structurally stabilised patches (Step 1) will be at risk.\n'
                    'Apply Step 2 treatments before they reset!',
                    style: const TextStyle(color: Colors.white60, fontSize: 10),
                  ),
                ]),
                const SizedBox(width: 12),
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF29B6F6).withValues(alpha: 0.12),
                    border: Border.all(color: const Color(0xFF29B6F6)
                        .withValues(alpha: 0.50)),
                  ),
                  child: Center(child: Text('${cd.ceil()}',
                      style: const TextStyle(color: Color(0xFF29B6F6),
                          fontWeight: FontWeight.bold, fontSize: 16))),
                ),
              ]),
            )),
          ),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  REACTION FLASH
// ══════════════════════════════════════════════════════════════════════════════
class LandReactionFx extends StatelessWidget {
  final LandDegradationGame game;
  const LandReactionFx(this.game, {super.key});

  @override
  Widget build(BuildContext context) {
    final ok      = game.reactionCorrect;
    final inRange = game.reactionInRange;
    final msg     = game.reactionMsg.isNotEmpty
        ? game.reactionMsg
        : (!inRange
            ? '🛰️  Out of Range — move closer'
            : ok ? '✅  Success!' : '❌  Wrong approach');

    final accent = (ok && inRange)
        ? const Color(0xFF69F0AE) : const Color(0xFFEF5350);

    return IgnorePointer(child: Stack(children: [
      Container(decoration: BoxDecoration(
        border: Border.all(color: accent, width: 8),
        gradient: RadialGradient(colors: [
          Colors.transparent,
          accent.withValues(alpha: 0.12),
        ], radius: 1.5),
      )),
      Center(child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 11),
        decoration: BoxDecoration(
            color: ok
                ? const Color(0xFF0A2A10).withValues(alpha: 0.94)
                : const Color(0xFF2A0A0A).withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [BoxShadow(color: Colors.black54,
                blurRadius: 14, spreadRadius: 2)]),
        child: Text(msg, textAlign: TextAlign.center,
            style: TextStyle(color: accent,
                fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 0.5)),
      )),

      // Combo flash
      if (game.showComboFlash && game.comboCount >= 2)
        Positioned(
          top: MediaQuery.of(context).size.height * 0.30,
          left: 0, right: 0,
          child: Center(child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFFFF6D00).withValues(alpha: 0.90),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: const Color(0xFFFF6D00).withValues(alpha: 0.40),
                  blurRadius: 16)],
            ),
            child: Text(
              game.comboCount >= 4 ? '🔥🔥🔥  ${game.comboCount}× COMBO!  3× POINTS!'
                  : game.comboCount == 3 ? '🔥🔥  ${game.comboCount}× COMBO!  2× POINTS!'
                  : '🔥  ${game.comboCount}× COMBO!  2× POINTS!',
              style: const TextStyle(color: Colors.white,
                  fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.6),
            ),
          )),
        ),
    ]));
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  RESULTS OVERLAY
// ══════════════════════════════════════════════════════════════════════════════
class LandResultsOverlay extends StatelessWidget {
  final LandDegradationGame game;
  const LandResultsOverlay(this.game, {super.key});

  @override
  Widget build(BuildContext context) {
    final result      = LandDegradationResult.current!;
    final stabilised  = result.terrainStabilised;
    final stars       = result.identifiedCorrectly >= 6
        ? '★★★' : result.identifiedCorrectly >= 3 ? '★★☆' : '★☆☆';

    return Container(
      color: Colors.black.withValues(alpha: 0.94),
      child: SafeArea(child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Column(children: [

          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: stabilised
                  ? [const Color(0xFF001A0A), const Color(0xFF003018)]
                  : [const Color(0xFF1A1000), const Color(0xFF2A1800)]),
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 16)],
            ),
            child: Column(children: [
              Text(stabilised ? '🌿' : '🏜️',
                  style: const TextStyle(fontSize: 52)),
              const SizedBox(height: 8),
              Text(stabilised ? 'Terrain Stabilised!' : 'Phase Complete',
                  style: const TextStyle(color: Colors.white, fontSize: 22,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text('Phase 1 & 2 — Land Degradation Results',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 8),
              Text(stars, style: const TextStyle(
                  color: Color(0xFFFFB300), fontSize: 28, letterSpacing: 6)),
              if (stabilised) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF69F0AE).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF69F0AE)
                        .withValues(alpha: 0.40)),
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('🏅', style: TextStyle(fontSize: 14)),
                    SizedBox(width: 6),
                    Text('Terrain Stabiliser Badge Unlocked!',
                        style: TextStyle(color: Color(0xFF69F0AE),
                            fontWeight: FontWeight.w800, fontSize: 12)),
                  ]),
                ),
              ],
            ]),
          ),

          const SizedBox(height: 16),

          // Score stats
          _LRCard(children: [
            _LRBig('🏜️', '${result.erosionIndex.toStringAsFixed(0)}%',
                'Erosion', stabilised ? const Color(0xFF69F0AE) : const Color(0xFFFFB300)),
            _LRBig('🌿', '${result.patchesRestored}', 'Restored', Colors.limeAccent),
            _LRBig('🔥', '${result.maxCombo}×',      'Max Combo', const Color(0xFFFF6D00)),
            _LRBig('⭐', '${result.ecoPoints}',       'Eco-Pts',   Colors.amber),
          ]),

          const SizedBox(height: 10),
          _LRCard(children: [
            _LRBig('🔬', '${result.identifiedCorrectly}/8', 'Identified', const Color(0xFF29B6F6)),
            _LRBig('❌', '${result.wrongTools}', 'Wrong Tools', Colors.redAccent),
          ]),

          const SizedBox(height: 12),

          // Restoration steps summary
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0A1A08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(children: [
              const Text('Two-Step Restoration Applied',
                  style: TextStyle(color: Colors.white70, fontSize: 12,
                      fontWeight: FontWeight.bold, letterSpacing: 1)),
              const SizedBox(height: 12),
              _LRRow('🏗️', 'Steep Slopes',   '① Terraces  →  ② Cover Crops'),
              _LRRow('🧱', 'Erosion Gullies','① Check Dams  →  ② Biochar'),
              _LRRow('🌱', 'Bare Land',      '① Cover Crops  →  ② Compost'),
              _LRRow('⬛', 'Dry Soil',       '① Biochar  →  ② Compost'),
            ]),
          ),

          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                game.resumeEngine();
                game.onLevelComplete();
              },
              icon: const Icon(Icons.biotech_rounded),
              label: const Text('Continue to Soil Remediation  →',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold,
                      letterSpacing: 0.8)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF69F0AE),
                foregroundColor: Colors.black87,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 8,
              ),
            ),
          ),
        ]),
      )),
    );
  }
}

class _LRCard extends StatelessWidget {
  final List<Widget> children;
  const _LRCard({required this.children});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    decoration: BoxDecoration(color: const Color(0xFF0A1A08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12)),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: children),
  );
}

class _LRBig extends StatelessWidget {
  final String emoji, value, label;
  final Color  color;
  const _LRBig(this.emoji, this.value, this.label, this.color);
  @override
  Widget build(BuildContext context) =>
      Column(mainAxisSize: MainAxisSize.min, children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color,
            fontWeight: FontWeight.bold, fontSize: 18)),
        const SizedBox(height: 2),
        Text(label, textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white54, fontSize: 9)),
      ]);
}

class _LRRow extends StatelessWidget {
  final String emoji, label, action;
  const _LRRow(this.emoji, this.label, this.action);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(children: [
      Text(emoji, style: const TextStyle(fontSize: 15)),
      const SizedBox(width: 8),
      Expanded(child: Text(label,
          style: const TextStyle(color: Colors.white,
              fontSize: 12, fontWeight: FontWeight.w600))),
      Text(action,
          style: const TextStyle(color: Color(0xFF69F0AE), fontSize: 10)),
    ]),
  );
}