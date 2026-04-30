import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:ecoquest/game/level5/degraded_land_screen.dart';
import 'package:ecoquest/game/level5/level5_complete_screen.dart';
import 'package:flame/components.dart' hide Matrix4;
import 'package:flame/game.dart' hide Matrix4;
import 'package:flutter/material.dart' hide Matrix4;
import 'package:flutter/services.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  SOIL POLLUTION RESULT
// ══════════════════════════════════════════════════════════════════════════════
class SoilPollutionResult {
  final int zonesRemediated;
  final int wrongTreatments;
  final int ecoPoints;
  final double soilHealthFinal;
  final bool soilGuardianBadge;

  const SoilPollutionResult({
    required this.zonesRemediated,
    required this.wrongTreatments,
    required this.ecoPoints,
    required this.soilHealthFinal,
    required this.soilGuardianBadge,
  });

  static SoilPollutionResult? current;
}

// ══════════════════════════════════════════════════════════════════════════════
//  ENUMS
// ══════════════════════════════════════════════════════════════════════════════
enum SoilPollutantType {
  oilSpill,
  acidicSoil,
  heavyMetals,
  pesticides,
  compactSoil,
}

enum RemediationAgent {
  biocharBacteria,
  limeGypsum,
  phytoPlants,
  compostWorms,
  earthworms,
}

enum ScanLayerType { topLayer, midLayer, deepLayer }

enum CalibrationResult { perfect, good, miss }

// ══════════════════════════════════════════════════════════════════════════════
//  SCREEN WRAPPER
// ══════════════════════════════════════════════════════════════════════════════
class SoilPollutionScreen extends StatefulWidget {
  final Level4CarryOver carryOver;
  const SoilPollutionScreen({super.key, required this.carryOver});

  @override
  State<SoilPollutionScreen> createState() => _SoilPollutionScreenState();
}

class _SoilPollutionScreenState extends State<SoilPollutionScreen> {
  late SoilPollutionGame _game;

  @override
  void initState() {
    super.initState();
    _game = SoilPollutionGame(
      carryOver: widget.carryOver,
      onLevelComplete: _onDone,
    );
  }

  void _onDone() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => Level5CompleteScreen(carryOver: widget.carryOver),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GameWidget(
        game: _game,
        overlayBuilderMap: {
          'hud': (ctx, g) => SoilHud(g as SoilPollutionGame),
          'controls': (ctx, g) => SoilControls(g as SoilPollutionGame),
          'banner': (ctx, g) => SoilPhaseBanner(g as SoilPollutionGame),
          'agentSelect': (ctx, g) =>
              RemediationAgentSelector(g as SoilPollutionGame),
          'reactionFx': (ctx, g) => SoilReactionFx(g as SoilPollutionGame),
          'results': (ctx, g) => SoilResultsOverlay(g as SoilPollutionGame),
          'calibration': (ctx, g) =>
              ScanCalibrationOverlay(g as SoilPollutionGame),
          'mcq': (ctx, g) => PollutantMCQOverlay(g as SoilPollutionGame),
          'comboFlash': (ctx, g) => ComboFlashOverlay(g as SoilPollutionGame),
          'jamAlert': (ctx, g) => JamAlertOverlay(g as SoilPollutionGame),
          'layerWrong': (ctx, g) => WrongLayerOverlay(g as SoilPollutionGame),
        },
        initialActiveOverlays: const ['hud', 'controls'],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  MAIN GAME CLASS
// ══════════════════════════════════════════════════════════════════════════════
class SoilPollutionGame extends FlameGame
    with HasCollisionDetection, ChangeNotifier {
  final Level4CarryOver carryOver;
  final VoidCallback onLevelComplete;
  final math.Random _rng = math.Random();

  SoilPollutionGame({required this.carryOver, required this.onLevelComplete});

  // ── Core state ─────────────────────────────────────────────────────────────
  int gamePhase = 3; // 3 = diagnose, 4 = remediate
  bool gameStarted = false;
  double timeLeft = 145.0; // extra time to accommodate new mechanics
  bool levelDone = false;

  // ── Score ──────────────────────────────────────────────────────────────────
  int ecoPoints = 0;
  int wrongTreatments = 0;
  int remediatedCount = 0;
  int diagnosedCount = 0;

  // ── Soil health ────────────────────────────────────────────────────────────
  double soilHealth = 12.0;
  static const double _targetHealth = 80.0;
  static const double _fixGain = 9.0;
  static const double _wrongPenalty = 5.0;

  // ── Range constants ────────────────────────────────────────────────────────
  static const double _scanRange = 155.0;
  static const double _applyRange = 100.0;

  // ── Drone ──────────────────────────────────────────────────────────────────
  late Vector2 dronePos;
  bool isUp = false, isDown = false, isLeft = false, isRight = false;
  static const double _droneSpeed = 185.0;
  bool droneLockedByMinigame = false;

  // ── Phase 3 — enhanced state ───────────────────────────────────────────────
  // Layer selector
  ScanLayerType selectedLayer = ScanLayerType.topLayer;

  // Combo system
  int comboCount = 0;
  double comboMultiplier = 1.0;

  // Scanner jam (interference nodes)
  bool scannerJammed = false;
  double jamTimer = 0.0;

  // Calibration mini-game
  bool calibrationActive = false;
  SoilZone? pendingZone;
  double calibSweetSpotStart = 0.25;
  double calibSweetSpotWidth = 0.22;

  // MCQ state
  bool mcqActive = false;
  List<SoilPollutantType> mcqChoices = [];

  // Combo flash
  bool comboFlashActive = false;
  double comboFlashTimer = 0.0;
  int comboFlashCount = 0;

  // Wrong-layer flash
  bool wrongLayerActive = false;
  double wrongLayerTimer = 0.0;

  // ── Phase 4 — agent selection ──────────────────────────────────────────────
  RemediationAgent selectedAgent = RemediationAgent.biocharBacteria;

  // ── Reaction FX ────────────────────────────────────────────────────────────
  bool reactionActive = false;
  bool reactionCorrect = false;
  int reactionPhase = 3;
  bool reactionInRange = true;
  double reactionTimer = 0;

  // ── Phase banner ───────────────────────────────────────────────────────────
  double bannerTimer = 3.5;

  // ── Scan ring animation ────────────────────────────────────────────────────
  bool scanActive = false;
  double scanRadius = 0;
  static const double _scanMaxRadius = 180.0;

  // ── Components ─────────────────────────────────────────────────────────────
  late SoilDroneComponent drone;
  final List<SoilZone> zones = [];
  final List<InterferenceNode> interferenceNodes = [];

  // ──────────────────────────────────────────────────────────────────────────
  @override
  Future<void> onLoad() async {
    super.onLoad();
    dronePos = Vector2(size.x * 0.50, size.y * 0.55);

    add(SoilLayerRenderer(game: this));
    drone = SoilDroneComponent(game: this);
    add(drone);

    _spawnZones();
    _spawnInterferenceNodes();

    bannerTimer = 3.5;
    overlays.add('banner');
    add(TimerComponent(period: 1.0, repeat: true, onTick: _onSecond));
  }

  // ── Zone spawning — positions align with visual soil bands ────────────────
  //   Top band  : ry 0.10–0.30  → topLayer
  //   Mid band  : ry 0.38–0.58  → midLayer
  //   Deep band : ry 0.65–0.78  → deepLayer
  void _spawnZones() {
    final specs = [
      // (type,                           rx,   ry,   layer,                      drift)
      (SoilPollutantType.oilSpill, 0.14, 0.22, ScanLayerType.topLayer, true),
      (SoilPollutantType.oilSpill, 0.72, 0.18, ScanLayerType.topLayer, false),
      (SoilPollutantType.acidicSoil, 0.34, 0.50, ScanLayerType.midLayer, false),
      (SoilPollutantType.acidicSoil, 0.60, 0.44, ScanLayerType.midLayer, false),
      (
        SoilPollutantType.heavyMetals,
        0.46,
        0.70,
        ScanLayerType.deepLayer,
        false,
      ),
      (SoilPollutantType.pesticides, 0.84, 0.55, ScanLayerType.midLayer, true),
      (
        SoilPollutantType.compactSoil,
        0.22,
        0.27,
        ScanLayerType.topLayer,
        false,
      ),
      (
        SoilPollutantType.compactSoil,
        0.66,
        0.29,
        ScanLayerType.topLayer,
        false,
      ),
      (SoilPollutantType.pesticides, 0.82, 0.40, ScanLayerType.midLayer, false),
      (
        SoilPollutantType.heavyMetals,
        0.10,
        0.74,
        ScanLayerType.deepLayer,
        false,
      ),
    ];
    for (int i = 0; i < specs.length; i++) {
      final (type, rx, ry, layer, drift) = specs[i];
      final z = SoilZone(
        game: this,
        type: type,
        worldX: size.x * rx,
        worldY: size.y * ry,
        requiredLayer: layer,
        isDrifting: drift,
        seed: i * 23,
      );
      add(z);
      zones.add(z);
    }
  }

  void _spawnInterferenceNodes() {
    // Strategic positions — block efficient direct paths between zones
    const nodeSpecs = [
      (0.42, 0.35), // centre of field — disrupts mid crossing
      (0.68, 0.62), // south-east quadrant
      (0.26, 0.48), // west side mid-height
    ];
    for (final (rx, ry) in nodeSpecs) {
      final node = InterferenceNode(
        game: this,
        worldX: size.x * rx,
        worldY: size.y * ry,
      );
      add(node);
      interferenceNodes.add(node);
    }
  }

  // ── Timer tick ─────────────────────────────────────────────────────────────
  void _onSecond() {
    if (!gameStarted || levelDone) return;
    timeLeft -= 1;
    if (timeLeft <= 0) {
      timeLeft = 0;
      _endLevel();
    }
    notifyListeners();
  }

  // ── Proximity helpers ──────────────────────────────────────────────────────
  bool get _hasNearbyUndiagnosed => zones.any(
    (z) => !z.isDiagnosed && (z.zonePos - dronePos).length <= _scanRange,
  );

  bool get _hasNearbyUnremediated => zones.any(
    (z) => !z.isRemediated && (z.zonePos - dronePos).length <= _applyRange,
  );

  SoilZone? get _nearestUndiagnosed {
    SoilZone? target;
    double best = _scanRange;
    for (final z in zones) {
      if (z.isDiagnosed) continue;
      final d = (z.zonePos - dronePos).length;
      if (d < best) {
        best = d;
        target = z;
      }
    }
    return target;
  }

  SoilZone? get _nearestUnremediated {
    SoilZone? target;
    double best = _applyRange;
    for (final z in zones) {
      if (z.isRemediated) continue;
      final d = (z.zonePos - dronePos).length;
      if (d < best) {
        best = d;
        target = z;
      }
    }
    return target;
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  PHASE 3 — ENHANCED DIAGNOSIS FLOW
  //  Step 1: Layer selection (visual cue from zone y-position)
  //  Step 2: Calibration mini-game (timing skill — hit the green arc)
  //  Step 3: Pollutant MCQ (knowledge test — identify the contaminant)
  //  Rewards: base pts + layer bonus + calibration bonus + MCQ bonus × combo
  // ══════════════════════════════════════════════════════════════════════════
  void diagnoseZone() {
    if (!gameStarted || levelDone || gamePhase != 3) return;
    if (calibrationActive || mcqActive) return;

    if (scannerJammed) {
      HapticFeedback.heavyImpact();
      return; // must move away from interference node first
    }

    gameStarted = true;

    final target = _nearestUndiagnosed;
    if (target == null) {
      _triggerReaction(false, inRange: false);
      return;
    }

    // ── Layer depth check ────────────────────────────────────────────────
    if (target.requiredLayer != selectedLayer) {
      HapticFeedback.heavyImpact();
      ecoPoints = math.max(0, ecoPoints - 2);
      wrongLayerActive = true;
      wrongLayerTimer = 2.0;
      overlays.add('layerWrong');
      notifyListeners();
      return;
    }

    // ── Correct layer — start calibration ────────────────────────────────
    HapticFeedback.selectionClick();
    pendingZone = target;
    calibrationActive = true;
    // Sweet-spot narrows as combo grows (challenge scales with skill)
    calibSweetSpotStart = _rng.nextDouble() * 0.70;
    calibSweetSpotWidth = math.max(0.08, 0.22 - comboCount * 0.012);
    droneLockedByMinigame = true;
    scanActive = true;
    scanRadius = 0;
    overlays.add('calibration');
    notifyListeners();
  }

  // Called by ScanCalibrationOverlay after player taps LOCK
  void onCalibrationDone(CalibrationResult result) {
    if (!calibrationActive || levelDone) return;
    calibrationActive = false;
    overlays.remove('calibration');

    if (result == CalibrationResult.miss) {
      // Miss: break combo, no MCQ, slight haptic penalty
      HapticFeedback.heavyImpact();
      comboCount = 0;
      comboMultiplier = 1.0;
      pendingZone = null;
      droneLockedByMinigame = false;
      _triggerReaction(false, inRange: true);
      notifyListeners();
      return;
    }

    // Perfect or Good — store calibration bonus on zone, then show MCQ
    pendingZone!._calibBonus = result == CalibrationResult.perfect ? 5 : 0;
    mcqChoices = _generateMcqChoices(pendingZone!.type);
    mcqActive = true;
    overlays.add('mcq');
    notifyListeners();
  }

  // Called by PollutantMCQOverlay when player picks an answer
  void onMcqAnswer(SoilPollutantType chosen) {
    if (!mcqActive || pendingZone == null || levelDone) return;
    mcqActive = false;
    overlays.remove('mcq');

    final zone = pendingZone!;
    final correct = chosen == zone.type;

    zone.reveal();
    diagnosedCount++;

    // ── Point calculation ────────────────────────────────────────────────
    int pts = 5; // base diagnosis
    pts += 3; // correct-layer bonus (already validated)
    pts += zone._calibBonus; // calibration skill bonus (0 or 5)
    if (correct) {
      pts += 8; // correct MCQ identification
      comboCount++;
      comboMultiplier = math.min(2.0, 1.0 + comboCount * 0.15);
    } else {
      pts = math.max(0, pts - 3); // wrong ID penalty
      comboCount = 0;
      comboMultiplier = 1.0;
    }
    pts = (pts * comboMultiplier).round();
    ecoPoints += pts;

    // Combo flash at 3+
    if (correct && comboCount >= 3) {
      comboFlashActive = true;
      comboFlashTimer = 1.8;
      comboFlashCount = comboCount;
      overlays.add('comboFlash');
    }

    pendingZone = null;
    droneLockedByMinigame = false;
    _triggerReaction(correct);

    if (diagnosedCount >= zones.length) {
      Future.delayed(const Duration(milliseconds: 900), _advanceToPhase4);
    }
    notifyListeners();
  }

  // Called when MCQ timer expires (zone still diagnosed but minimal reward)
  void onMcqTimeout() {
    if (!mcqActive || pendingZone == null || levelDone) return;
    mcqActive = false;
    overlays.remove('mcq');

    pendingZone!.reveal();
    diagnosedCount++;
    ecoPoints += 2; // bare minimum for finding the zone
    comboCount = 0;
    comboMultiplier = 1.0;

    pendingZone = null;
    droneLockedByMinigame = false;

    if (diagnosedCount >= zones.length) {
      Future.delayed(const Duration(milliseconds: 900), _advanceToPhase4);
    }
    notifyListeners();
  }

  List<SoilPollutantType> _generateMcqChoices(SoilPollutantType correct) {
    final others = SoilPollutantType.values.where((t) => t != correct).toList()
      ..shuffle(_rng);
    return ([correct, ...others.take(2)]..shuffle(_rng));
  }

  void _advanceToPhase4() {
    if (levelDone) return;
    gamePhase = 4;
    bannerTimer = 3.0;
    calibrationActive = false;
    mcqActive = false;
    droneLockedByMinigame = false;
    pendingZone = null;
    overlays
      ..remove('calibration')
      ..remove('mcq')
      ..remove('jamAlert')
      ..remove('layerWrong')
      ..remove('comboFlash')
      ..add('banner')
      ..add('agentSelect');
    notifyListeners();
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  PHASE 4 — BIOREMEDIATION (unchanged core logic)
  // ══════════════════════════════════════════════════════════════════════════
  void applyAgent() {
    if (!gameStarted || levelDone || gamePhase != 4) return;
    final target = _nearestUnremediated;
    if (target == null) {
      _triggerReaction(false, inRange: false);
      return;
    }

    HapticFeedback.lightImpact();
    final correct = _isCorrectAgent(target.type, selectedAgent);
    if (correct) {
      target.remediate();
      remediatedCount++;
      soilHealth = math.min(100, soilHealth + _fixGain);
      ecoPoints += 20;
      _triggerReaction(true);
    } else {
      wrongTreatments++;
      soilHealth = math.max(0, soilHealth - _wrongPenalty);
      ecoPoints = math.max(0, ecoPoints - 10);
      _triggerReaction(false);
    }

    final allDone = zones.every((z) => z.isRemediated);
    if (soilHealth >= _targetHealth || allDone) {
      Future.delayed(const Duration(milliseconds: 800), _endLevel);
    }
    notifyListeners();
  }

  bool _isCorrectAgent(SoilPollutantType t, RemediationAgent agent) {
    switch (t) {
      case SoilPollutantType.oilSpill:
        return agent == RemediationAgent.biocharBacteria;
      case SoilPollutantType.acidicSoil:
        return agent == RemediationAgent.limeGypsum;
      case SoilPollutantType.heavyMetals:
        return agent == RemediationAgent.phytoPlants;
      case SoilPollutantType.pesticides:
        return agent == RemediationAgent.compostWorms;
      case SoilPollutantType.compactSoil:
        return agent == RemediationAgent.earthworms;
    }
  }

  void selectAgent(RemediationAgent a) {
    selectedAgent = a;
    notifyListeners();
  }

  void selectLayer(ScanLayerType l) {
    selectedLayer = l;
    notifyListeners();
  }

  // ── Drone input ────────────────────────────────────────────────────────────
  void setUpKey(bool v) {
    isUp = v;
    if (v) gameStarted = true;
  }

  void setDownKey(bool v) {
    isDown = v;
    if (v) gameStarted = true;
  }

  void setLeftKey(bool v) {
    isLeft = v;
    if (v) gameStarted = true;
  }

  void setRightKey(bool v) {
    isRight = v;
    if (v) gameStarted = true;
  }

  // ── Interference jam ───────────────────────────────────────────────────────
  void triggerJam() {
    if (scannerJammed) return;
    scannerJammed = true;
    jamTimer = 1.8;
    HapticFeedback.heavyImpact();
    overlays.add('jamAlert');
    notifyListeners();
  }

  // ── Reaction FX ────────────────────────────────────────────────────────────
  void _triggerReaction(bool correct, {bool inRange = true}) {
    reactionActive = true;
    reactionCorrect = correct;
    reactionPhase = gamePhase;
    reactionInRange = inRange;
    reactionTimer = 1.2;
    overlays.add('reactionFx');
  }

  // ── End level ──────────────────────────────────────────────────────────────
  void _endLevel() {
    if (levelDone) return;
    levelDone = true;
    pauseEngine();

    SoilPollutionResult.current = SoilPollutionResult(
      zonesRemediated: remediatedCount,
      wrongTreatments: wrongTreatments,
      ecoPoints: ecoPoints,
      soilHealthFinal: soilHealth,
      soilGuardianBadge: soilHealth >= _targetHealth,
    );

    overlays
      ..remove('reactionFx')
      ..remove('agentSelect')
      ..remove('comboFlash')
      ..remove('jamAlert')
      ..remove('layerWrong')
      ..remove('calibration')
      ..remove('mcq')
      ..add('results');
    notifyListeners();
  }

  // ── Game loop update ───────────────────────────────────────────────────────
  @override
  void update(double dt) {
    super.update(dt);

    if (bannerTimer > 0) {
      bannerTimer -= dt;
      if (bannerTimer <= 0) overlays.remove('banner');
    }
    if (reactionTimer > 0) {
      reactionTimer -= dt;
      if (reactionTimer <= 0) {
        reactionActive = false;
        overlays.remove('reactionFx');
      }
    }
    if (scanActive) {
      scanRadius += dt * 220;
      if (scanRadius >= _scanMaxRadius) scanActive = false;
      notifyListeners();
    }
    if (jamTimer > 0) {
      jamTimer -= dt;
      if (jamTimer <= 0) {
        scannerJammed = false;
        overlays.remove('jamAlert');
        notifyListeners();
      }
    }
    if (comboFlashTimer > 0) {
      comboFlashTimer -= dt;
      if (comboFlashTimer <= 0) {
        comboFlashActive = false;
        overlays.remove('comboFlash');
        notifyListeners();
      }
    }
    if (wrongLayerTimer > 0) {
      wrongLayerTimer -= dt;
      if (wrongLayerTimer <= 0) {
        wrongLayerActive = false;
        overlays.remove('layerWrong');
        notifyListeners();
      }
    }

    if (!gameStarted || levelDone) return;

    // Drone movement — locked during calibration / MCQ mini-games
    if (!droneLockedByMinigame) {
      double vx = 0, vy = 0;
      if (isLeft) vx -= 1;
      if (isRight) vx += 1;
      if (isUp) vy -= 1;
      if (isDown) vy += 1;
      dronePos.x = (dronePos.x + vx * _droneSpeed * dt).clamp(30, size.x - 30);
      dronePos.y = (dronePos.y + vy * _droneSpeed * dt).clamp(
        40,
        size.y * 0.88,
      );
    }

    // Interference node proximity check (phase 3, not during a mini-game)
    if (gamePhase == 3 && !scannerJammed && !droneLockedByMinigame) {
      for (final node in interferenceNodes) {
        if ((node.nodePos - dronePos).length <= InterferenceNode.jamRadius) {
          triggerJam();
          break;
        }
      }
    }

    notifyListeners();
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  SOIL LAYER RENDERER  — cross-section soil profile with labelled bands
// ════════════════════════════════════════════════════════════════════════════
class SoilLayerRenderer extends Component {
  final SoilPollutionGame game;
  double _t = 0;
  SoilLayerRenderer({required this.game});

  @override
  void update(double dt) => _t += dt * 0.25;

  @override
  void render(Canvas canvas) {
    final w = game.size.x;
    final h = game.size.y;

    // Dark backdrop
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(0, h),
          [
            const Color(0xFF0E0A04),
            Color.lerp(
              const Color(0xFF181006),
              const Color(0xFF1A1208),
              (math.sin(_t) * 0.5 + 0.5) * 0.4,
            )!,
            const Color(0xFF0C0804),
          ],
          [0.0, 0.5, 1.0],
        ),
    );

    // Health-based green overlay
    final hr = (game.soilHealth / 100.0).clamp(0.0, 1.0);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()
        ..color = const Color(0xFF69F0AE).withValues(alpha: hr * 0.04)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30),
    );

    // ── Three labelled soil bands ─────────────────────────────────────────
    _drawBand(
      canvas,
      w,
      h,
      0.00,
      0.35,
      const Color(0xFF1A0E06),
      '🟤  TOP LAYER',
      const Color(0xFFBCAAA4),
    );
    _drawBand(
      canvas,
      w,
      h,
      0.35,
      0.63,
      const Color(0xFF110E04),
      '🟠  MID LAYER',
      const Color(0xFFFF6D00),
    );
    _drawBand(
      canvas,
      w,
      h,
      0.63,
      0.86,
      const Color(0xFF090704),
      '⬛  DEEP LAYER',
      const Color(0xFF7B1FA2),
    );

    // Grid lines
    _drawFieldGrid(canvas, w, h);

    // Ground floor strip
    canvas.drawRect(
      Rect.fromLTWH(0, h * 0.86, w, h * 0.14),
      Paint()..color = const Color(0xFF080402),
    );
  }

  void _drawBand(
    Canvas canvas,
    double w,
    double h,
    double yt,
    double yb,
    Color fill,
    String label,
    Color labelColor,
  ) {
    // Fill
    canvas.drawRect(
      Rect.fromLTWH(0, h * yt, w, h * (yb - yt)),
      Paint()..color = fill,
    );
    // Left edge line
    canvas.drawLine(
      Offset(0, h * yb),
      Offset(w, h * yb),
      Paint()
        ..color = labelColor.withValues(alpha: 0.18)
        ..strokeWidth = 1.0,
    );
    // Band label (left-side, small)
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: labelColor.withValues(alpha: 0.35),
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(8, h * yt + 6));
  }

  void _drawFieldGrid(Canvas canvas, double w, double h) {
    final linePaint = Paint()
      ..color = const Color(0xFF1A1004).withValues(alpha: 0.6)
      ..strokeWidth = 6;
    for (final ry in [0.35, 0.63]) {
      canvas.drawLine(Offset(0, h * ry), Offset(w, h * ry), linePaint);
    }
    for (final rx in [0.28, 0.55, 0.78]) {
      canvas.drawLine(
        Offset(w * rx, 0),
        Offset(w * rx, h * 0.86),
        linePaint
          ..color = const Color(0xFF1A1004).withValues(alpha: 0.35)
          ..strokeWidth = 4,
      );
    }
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  INTERFERENCE NODE COMPONENT — jams scanner when drone gets too close
// ════════════════════════════════════════════════════════════════════════════
class InterferenceNode extends Component {
  final SoilPollutionGame game;
  final double nx, ny;
  double _t = 0;

  static const double jamRadius = 62.0;

  InterferenceNode({
    required this.game,
    required double worldX,
    required double worldY,
  }) : nx = worldX,
       ny = worldY;

  Vector2 get nodePos => Vector2(nx, ny);

  @override
  void update(double dt) => _t += dt;

  @override
  void render(Canvas canvas) {
    if (game.gamePhase != 3) return; // only relevant in diagnosis phase

    final pulse = 0.55 + math.sin(_t * 3.8) * 0.45;

    // Jam-radius danger zone
    canvas.drawCircle(
      Offset(nx, ny),
      jamRadius,
      Paint()
        ..color = const Color(0xFFEF5350).withValues(alpha: 0.04 + pulse * 0.06)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );
    canvas.drawCircle(
      Offset(nx, ny),
      jamRadius,
      Paint()
        ..color = const Color(0xFFEF5350).withValues(alpha: 0.28 + pulse * 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8,
    );

    // Rotating hexagon core
    canvas.save();
    canvas.translate(nx, ny);
    canvas.rotate(_t * 0.9);

    final hexPath = Path();
    for (int i = 0; i < 6; i++) {
      final a = i * math.pi / 3;
      final x = math.cos(a) * 15.0;
      final y = math.sin(a) * 15.0;
      if (i == 0) {
        hexPath.moveTo(x, y);
      } else {
        hexPath.lineTo(x, y);
      }
    }
    hexPath.close();

    canvas.drawPath(
      hexPath,
      Paint()
        ..color = const Color(0xFFEF5350).withValues(alpha: 0.22 + pulse * 0.14)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      hexPath,
      Paint()
        ..color = const Color(0xFFEF5350).withValues(alpha: 0.80 + pulse * 0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
    canvas.restore();

    // ⚡ icon
    final tp = TextPainter(
      text: TextSpan(
        text: '⚡',
        style: TextStyle(
          fontSize: 11,
          color: const Color(0xFFEF5350).withValues(alpha: 0.8 + pulse * 0.2),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(nx - tp.width / 2, ny - tp.height / 2));

    // "JAMMER" label
    final lp = TextPainter(
      text: TextSpan(
        text: 'JAMMER',
        style: TextStyle(
          color: const Color(0xFFEF5350).withValues(alpha: 0.55),
          fontSize: 6.5,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    lp.paint(canvas, Offset(nx - lp.width / 2, ny + 18));
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  SOIL DRONE COMPONENT — enhanced with jam + lock visual effects
// ════════════════════════════════════════════════════════════════════════════
class SoilDroneComponent extends Component {
  final SoilPollutionGame game;
  double _t = 0;
  SoilDroneComponent({required this.game});

  @override
  void update(double dt) => _t += dt;

  @override
  void render(Canvas canvas) {
    final cx = game.dronePos.x;
    final cy = game.dronePos.y + math.sin(_t * 3.0) * 2.5;

    // Outward scan ring animation
    if (game.scanActive) {
      final alpha =
          (1.0 - game.scanRadius / SoilPollutionGame._scanMaxRadius) * 0.30;
      canvas.drawCircle(
        Offset(cx, cy),
        game.scanRadius,
        Paint()
          ..color = const Color(0xFFFFB300).withValues(alpha: alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
    }

    // Jam effect — red pulsing ring when jammed
    if (game.scannerJammed) {
      canvas.drawCircle(
        Offset(cx, cy),
        34,
        Paint()
          ..color = const Color(
            0xFFEF5350,
          ).withValues(alpha: 0.30 + math.sin(_t * 18) * 0.20)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }

    // Lock ring — teal ring during calibration / MCQ
    if (game.droneLockedByMinigame) {
      canvas.drawCircle(
        Offset(cx, cy),
        30,
        Paint()
          ..color = const Color(
            0xFF29B6F6,
          ).withValues(alpha: 0.35 + math.sin(_t * 6) * 0.15)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0,
      );
    }

    // Detection range circle
    final rangeColor = game.gamePhase == 3
        ? const Color(0xFFFFB300)
        : const Color(0xFF69F0AE);
    final rangeR = game.gamePhase == 3
        ? SoilPollutionGame._scanRange
        : SoilPollutionGame._applyRange;
    canvas.drawCircle(
      Offset(cx, cy),
      rangeR,
      Paint()
        ..color = rangeColor.withValues(alpha: 0.06)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    canvas.save();
    canvas.translate(cx, cy);

    // Shadow
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, 14), width: 38, height: 9),
      Paint()..color = Colors.black.withValues(alpha: 0.28),
    );

    // Arms
    final armPaint = Paint()
      ..color = const Color(0xFF3A2810)
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;
    for (final (dx, dy) in [(-1, -1), (1, -1), (-1, 1), (1, 1)]) {
      canvas.drawLine(
        Offset(dx * 8.0, dy * 8.0),
        Offset(dx * 22.0, dy * 22.0),
        armPaint,
      );
    }

    // Propellers
    final propPaint = Paint()
      ..color = const Color(0xFFFFB300).withValues(alpha: 0.55)
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    for (final (px, py) in [
      (-22.0, -22.0),
      (22.0, -22.0),
      (-22.0, 22.0),
      (22.0, 22.0),
    ]) {
      canvas.drawLine(Offset(px - 8, py), Offset(px + 8, py), propPaint);
      canvas.drawLine(Offset(px, py - 8), Offset(px, py + 8), propPaint);
    }

    // Body
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-13, -10, 26, 20),
        const Radius.circular(6),
      ),
      Paint()..color = const Color(0xFF2A1C0A),
    );

    // Core glow — colour changes by state
    final glowColor = game.scannerJammed
        ? const Color(0xFFEF5350)
        : game.droneLockedByMinigame
        ? const Color(0xFF29B6F6)
        : game.gamePhase == 3
        ? const Color(0xFFFFB300)
        : const Color(0xFF69F0AE);

    canvas.drawCircle(
      Offset.zero,
      7,
      Paint()
        ..color = glowColor.withValues(alpha: 0.75 + math.sin(_t * 4) * 0.20)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawCircle(
      Offset.zero,
      3.5,
      Paint()..color = Colors.white.withValues(alpha: 0.95),
    );

    // Mode icon
    final modeIcon = game.scannerJammed
        ? '⚡'
        : game.droneLockedByMinigame
        ? '🔒'
        : game.gamePhase == 3
        ? '🔬'
        : '🌱';
    final tp = TextPainter(
      text: TextSpan(text: modeIcon, style: const TextStyle(fontSize: 8)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(-tp.width / 2, 13 - tp.height / 2));

    canvas.restore();
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  SOIL ZONE COMPONENT — enhanced with layer, drifting, calibration bonus
// ════════════════════════════════════════════════════════════════════════════
class SoilZone extends Component {
  final SoilPollutionGame game;
  final SoilPollutantType type;
  final ScanLayerType requiredLayer;
  final bool isDrifting;
  final int seed;

  double hx, hy;
  final double _baseX;

  bool isDiagnosed = false;
  bool isRemediated = false;

  double _t = 0;
  double _driftPhase = 0;
  int _calibBonus = 0; // set by game during calibration; library-private

  static const double _driftAmp = 32.0;
  static const double _driftFreq = 0.50;

  SoilZone({
    required this.game,
    required this.type,
    required double worldX,
    required double worldY,
    required this.requiredLayer,
    required this.isDrifting,
    required this.seed,
  }) : hx = worldX,
       hy = worldY,
       _baseX = worldX;

  Vector2 get zonePos => Vector2(hx, hy);

  void reveal() => isDiagnosed = true;
  void remediate() {
    isRemediated = true;
    isDiagnosed = true;
  }

  // ── Visual specs ────────────────────────────────────────────────────────
  static const _specs = {
    SoilPollutantType.oilSpill: (
      '🛢️',
      'Oil\nSpill',
      Color(0xFF424242),
      '85%',
      'Top Layer',
    ),
    SoilPollutantType.acidicSoil: (
      '⚗️',
      'Acidic\nSoil',
      Color(0xFFCE93D8),
      '78%',
      'Mid Layer',
    ),
    SoilPollutantType.heavyMetals: (
      '⚙️',
      'Heavy\nMetals',
      Color(0xFF7B1FA2),
      '90%',
      'Deep Layer',
    ),
    SoilPollutantType.pesticides: (
      '🧪',
      'Pesticide\nZone',
      Color(0xFFFF6D00),
      '72%',
      'Mid Layer',
    ),
    SoilPollutantType.compactSoil: (
      '🪨',
      'Compact\nSoil',
      Color(0xFFBCAAA4),
      '65%',
      'Top Layer',
    ),
  };

  @override
  void update(double dt) {
    _t += dt;
    // Drifting zones move horizontally within their layer band (no vertical)
    if (isDrifting && !isDiagnosed) {
      _driftPhase += dt * _driftFreq;
      hx = (_baseX + math.sin(_driftPhase) * _driftAmp).clamp(
        40.0,
        game.size.x - 40.0,
      );
      // hy stays fixed so zone stays in its visual layer band
    }
  }

  @override
  void render(Canvas canvas) {
    if (isRemediated) {
      _drawRemediated(canvas);
      return;
    }

    final spec = _specs[type]!;
    final color = spec.$3;
    final pulse = 0.65 + math.sin(_t * 2.8) * 0.22;

    if (isDrifting && !isDiagnosed) _drawDriftIndicator(canvas, color, pulse);

    if (isDiagnosed) {
      _drawDiagnosed(canvas, spec, color, pulse);
    } else {
      _drawUnknown(canvas, pulse);
    }
  }

  void _drawDriftIndicator(Canvas canvas, Color color, double pulse) {
    // Orbiting arc showing the zone is moving
    canvas.drawArc(
      Rect.fromCenter(center: Offset(hx, hy), width: 58, height: 58),
      _t * 1.6,
      math.pi * 1.3,
      false,
      Paint()
        ..color = const Color(0xFFFFB300).withValues(alpha: 0.45 + pulse * 0.2)
        ..strokeWidth = 1.8
        ..style = PaintingStyle.stroke,
    );
    // Small arrow tip
    final arrowAngle = _t * 1.6 + math.pi * 1.3;
    final ax = hx + math.cos(arrowAngle) * 29;
    final ay = hy + math.sin(arrowAngle) * 29;
    canvas.drawCircle(
      Offset(ax, ay),
      3,
      Paint()..color = const Color(0xFFFFB300).withValues(alpha: 0.7),
    );
  }

  void _drawDiagnosed(
    Canvas canvas,
    (String, String, Color, String, String) spec,
    Color color,
    double pulse,
  ) {
    canvas.drawCircle(
      Offset(hx, hy),
      36 * pulse,
      Paint()
        ..color = color.withValues(alpha: 0.07 + pulse * 0.05)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
    canvas.drawCircle(
      Offset(hx, hy),
      28,
      Paint()..color = color.withValues(alpha: 0.15),
    );
    canvas.drawCircle(
      Offset(hx, hy),
      28,
      Paint()
        ..color = color.withValues(alpha: 0.70)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2,
    );

    // Emoji icon
    final ep = TextPainter(
      text: TextSpan(text: spec.$1, style: const TextStyle(fontSize: 14)),
      textDirection: TextDirection.ltr,
    )..layout();
    ep.paint(canvas, Offset(hx - ep.width / 2, hy - ep.height / 2 - 6));

    // Contamination level
    final dp = TextPainter(
      text: TextSpan(
        text: spec.$4,
        style: TextStyle(
          color: color,
          fontSize: 8.5,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    dp.paint(canvas, Offset(hx - dp.width / 2, hy + 14));

    // Layer badge
    final lp = TextPainter(
      text: TextSpan(
        text: spec.$5,
        style: TextStyle(
          color: color.withValues(alpha: 0.75),
          fontSize: 7,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    lp.paint(canvas, Offset(hx - lp.width / 2, hy + 24));
  }

  void _drawUnknown(Canvas canvas, double pulse) {
    canvas.drawCircle(
      Offset(hx, hy),
      30 * pulse,
      Paint()
        ..color = const Color(0xFFBCAAA4).withValues(alpha: 0.07)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
    );
    canvas.drawCircle(
      Offset(hx, hy),
      22,
      Paint()..color = const Color(0xFFBCAAA4).withValues(alpha: 0.10),
    );
    canvas.drawCircle(
      Offset(hx, hy),
      22,
      Paint()
        ..color = const Color(0xFFBCAAA4).withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8,
    );
    final qp = TextPainter(
      text: const TextSpan(
        text: '?',
        style: TextStyle(
          color: Color(0xFFBCAAA4),
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    qp.paint(canvas, Offset(hx - qp.width / 2, hy - qp.height / 2));
  }

  void _drawRemediated(Canvas canvas) {
    canvas.drawCircle(
      Offset(hx, hy),
      22,
      Paint()..color = const Color(0xFF69F0AE).withValues(alpha: 0.14),
    );
    canvas.drawCircle(
      Offset(hx, hy),
      22,
      Paint()
        ..color = const Color(0xFF69F0AE).withValues(alpha: 0.60)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );
    final tp = TextPainter(
      text: const TextSpan(text: '🌱', style: TextStyle(fontSize: 13)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(hx - tp.width / 2, hy - tp.height / 2));
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  CALIBRATION DIAL PAINTER
// ════════════════════════════════════════════════════════════════════════════
class CalibrationDialPainter extends CustomPainter {
  final double needlePos; // 0.0–1.0 fraction of full circle
  final double sweetStart; // 0.0–1.0
  final double sweetWidth; // fraction of circle
  final bool locked;
  final CalibrationResult? result;

  const CalibrationDialPainter({
    required this.needlePos,
    required this.sweetStart,
    required this.sweetWidth,
    required this.locked,
    this.result,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.40;
    const startAngle = -math.pi / 2; // 12 o'clock

    // ── Danger track (full circle, red tint) ─────────────────────────────
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      math.pi * 2,
      false,
      Paint()
        ..color = const Color(0xFFEF5350).withValues(alpha: 0.22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 20
        ..strokeCap = StrokeCap.butt,
    );

    // ── Sweet-spot arc (green) ────────────────────────────────────────────
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle + sweetStart * math.pi * 2,
      sweetWidth * math.pi * 2,
      false,
      Paint()
        ..color = const Color(0xFF69F0AE).withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 20
        ..strokeCap = StrokeCap.round,
    );

    // Perfect-centre tick mark
    final midAngle = startAngle + (sweetStart + sweetWidth / 2) * math.pi * 2;
    final tickInner = Offset(
      center.dx + math.cos(midAngle) * (radius - 12),
      center.dy + math.sin(midAngle) * (radius - 12),
    );
    final tickOuter = Offset(
      center.dx + math.cos(midAngle) * (radius + 12),
      center.dy + math.sin(midAngle) * (radius + 12),
    );
    canvas.drawLine(
      tickInner,
      tickOuter,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.9)
        ..strokeWidth = 2.5,
    );

    // ── Tick marks ────────────────────────────────────────────────────────
    for (int i = 0; i < 12; i++) {
      final angle = startAngle + i / 12 * math.pi * 2;
      canvas.drawLine(
        Offset(
          center.dx + math.cos(angle) * (radius - 28),
          center.dy + math.sin(angle) * (radius - 28),
        ),
        Offset(
          center.dx + math.cos(angle) * (radius - 18),
          center.dy + math.sin(angle) * (radius - 18),
        ),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.25)
          ..strokeWidth = 1.5,
      );
    }

    // ── Inner decoration circle ────────────────────────────────────────────
    canvas.drawCircle(
      center,
      radius * 0.52,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.04)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    // ── Needle ────────────────────────────────────────────────────────────
    final needleAngle = startAngle + needlePos * math.pi * 2;
    final needleTip = Offset(
      center.dx + math.cos(needleAngle) * (radius + 6),
      center.dy + math.sin(needleAngle) * (radius + 6),
    );
    final needleColor = locked
        ? (result == CalibrationResult.miss
              ? Colors.redAccent
              : const Color(0xFF69F0AE))
        : const Color(0xFFFFB300);

    canvas.drawLine(
      center,
      needleTip,
      Paint()
        ..color = needleColor
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(center, 9, Paint()..color = needleColor);
    canvas.drawCircle(
      center,
      4.5,
      Paint()..color = Colors.white.withValues(alpha: 0.9),
    );
  }

  @override
  bool shouldRepaint(CalibrationDialPainter old) =>
      old.needlePos != needlePos ||
      old.locked != locked ||
      old.result != result;
}

// ════════════════════════════════════════════════════════════════════════════
//  SCAN CALIBRATION OVERLAY
//  The needle spins around the dial. Player taps LOCK when it hits the
//  green sweet-spot arc. Perfect centre = +5 pts; anywhere in green = Good;
//  outside green = Miss + combo reset.
// ════════════════════════════════════════════════════════════════════════════
class ScanCalibrationOverlay extends StatefulWidget {
  final SoilPollutionGame game;
  const ScanCalibrationOverlay(this.game, {super.key});

  @override
  State<ScanCalibrationOverlay> createState() => _ScanCalibrationState();
}

class _ScanCalibrationState extends State<ScanCalibrationOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _needleCtrl;
  bool _hasActed = false;
  double _lockedPos = 0;
  CalibrationResult? _result;

  static const double _spinDuration = 2.6; // seconds per rotation

  @override
  void initState() {
    super.initState();
    _needleCtrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (_spinDuration * 1000).toInt()),
    )..repeat();
  }

  @override
  void dispose() {
    _needleCtrl.dispose();
    super.dispose();
  }

  CalibrationResult _computeResult(double pos) {
    final sweetStart = widget.game.calibSweetSpotStart;
    final sweetWidth = widget.game.calibSweetSpotWidth;
    final halfWidth = sweetWidth / 2;
    final midPoint = sweetStart + halfWidth;
    final dist = (pos - midPoint).abs();

    if (dist < halfWidth * 0.30) return CalibrationResult.perfect;
    if (dist < halfWidth) return CalibrationResult.good;
    return CalibrationResult.miss;
  }

  void _onLock() {
    if (_hasActed) return;
    _hasActed = true;
    _lockedPos = _needleCtrl.value;
    _result = _computeResult(_lockedPos);
    _needleCtrl.stop();
    HapticFeedback.selectionClick();
    setState(() {});

    Future.delayed(const Duration(milliseconds: 550), () {
      if (mounted) widget.game.onCalibrationDone(_result!);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.game.calibrationActive) return const SizedBox.shrink();
    final accentColor = const Color(0xFFFFB300);

    return GestureDetector(
      // Tap anywhere to lock (more mobile-friendly than just the button)
      onTap: _hasActed ? null : _onLock,
      child: Container(
        color: Colors.black.withValues(alpha: 0.86),
        child: Center(
          child: Container(
            width: 320,
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 26),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0D1A10), Color(0xFF1A2E18)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: accentColor.withValues(alpha: 0.65),
                width: 1.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.22),
                  blurRadius: 28,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('🔬 ', style: TextStyle(fontSize: 18)),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'SCANNER CALIBRATION',
                          style: TextStyle(
                            color: Color(0xFFFFB300),
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            letterSpacing: 1.5,
                          ),
                        ),
                        Text(
                          'Combo ×${widget.game.comboMultiplier.toStringAsFixed(1)}  |  Sweet spot: ${(widget.game.calibSweetSpotWidth * 100).toStringAsFixed(0)}° wide',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 9.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'Tap LOCK when the needle reaches the 🟢 green zone!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 16),

                // Spinning dial
                AnimatedBuilder(
                  animation: _needleCtrl,
                  builder: (_, __) => CustomPaint(
                    size: const Size(200, 200),
                    painter: CalibrationDialPainter(
                      needlePos: _hasActed ? _lockedPos : _needleCtrl.value,
                      sweetStart: widget.game.calibSweetSpotStart,
                      sweetWidth: widget.game.calibSweetSpotWidth,
                      locked: _hasActed,
                      result: _result,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Lock button / result
                if (!_hasActed) _buildLockButton() else _buildResultBadge(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLockButton() => GestureDetector(
    onTap: _onLock,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFB300).withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFB300), width: 2.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFB300).withValues(alpha: 0.45),
            blurRadius: 18,
          ),
        ],
      ),
      child: const Text(
        '🔒  LOCK SCAN',
        style: TextStyle(
          color: Color(0xFFFFB300),
          fontWeight: FontWeight.w900,
          fontSize: 17,
          letterSpacing: 1.8,
        ),
      ),
    ),
  );

  Widget _buildResultBadge() {
    final color = _result == CalibrationResult.miss
        ? Colors.redAccent
        : const Color(0xFF69F0AE);
    final label = switch (_result!) {
      CalibrationResult.perfect => '⭐  PERFECT LOCK!  +5 pts bonus',
      CalibrationResult.good => '✅  GOOD LOCK!  Proceeding…',
      CalibrationResult.miss => '❌  MISSED!  Combo reset.',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  POLLUTANT MCQ OVERLAY
//  After a successful calibration, player has 4.5 s to identify the
//  contaminant from 3 choices. Correct = +8 pts; Wrong/timeout = −3 / +2.
// ════════════════════════════════════════════════════════════════════════════
class PollutantMCQOverlay extends StatefulWidget {
  final SoilPollutionGame game;
  const PollutantMCQOverlay(this.game, {super.key});

  @override
  State<PollutantMCQOverlay> createState() => _PollutantMCQState();
}

class _PollutantMCQState extends State<PollutantMCQOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _timerCtrl;
  bool _answered = false;
  SoilPollutantType? _chosen;

  static const double _mcqDuration = 4.5;

  @override
  void initState() {
    super.initState();
    _timerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4500),
    )..forward();
    _timerCtrl.addStatusListener((s) {
      if (s == AnimationStatus.completed && !_answered) _onTimeout();
    });
  }

  @override
  void dispose() {
    _timerCtrl.dispose();
    super.dispose();
  }

  void _onChoose(SoilPollutantType type) {
    if (_answered) return;
    _answered = true;
    _chosen = type;
    _timerCtrl.stop();
    HapticFeedback.selectionClick();
    setState(() {});
    Future.delayed(const Duration(milliseconds: 650), () {
      if (mounted) widget.game.onMcqAnswer(type);
    });
  }

  void _onTimeout() {
    if (_answered || !widget.game.mcqActive) return;
    _answered = true;
    setState(() {});
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) widget.game.onMcqTimeout();
    });
  }

  // ── Choice specs ──────────────────────────────────────────────────────────
  static const _choiceLabels = {
    SoilPollutantType.oilSpill: (
      '🛢️',
      'Oil Spill',
      'Hydrocarbon contamination',
    ),
    SoilPollutantType.acidicSoil: (
      '⚗️',
      'Acidic Soil',
      'Low pH chemical residue',
    ),
    SoilPollutantType.heavyMetals: (
      '⚙️',
      'Heavy Metals',
      'Industrial metal toxins',
    ),
    SoilPollutantType.pesticides: (
      '🧪',
      'Pesticides',
      'Agricultural chemical runoff',
    ),
    SoilPollutantType.compactSoil: (
      '🪨',
      'Compact Soil',
      'Crushed subsoil structure',
    ),
  };

  @override
  Widget build(BuildContext context) {
    if (!widget.game.mcqActive || widget.game.pendingZone == null) {
      return const SizedBox.shrink();
    }

    final correct = widget.game.pendingZone!.type;
    final choices = widget.game.mcqChoices;

    return Container(
      color: Colors.black.withValues(alpha: 0.82),
      child: Center(
        child: Container(
          width: 340,
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0D1520), Color(0xFF0E2035)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: const Color(0xFF29B6F6).withValues(alpha: 0.55),
              width: 1.8,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF29B6F6).withValues(alpha: 0.18),
                blurRadius: 28,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '🧪  POLLUTANT IDENTIFICATION',
                style: TextStyle(
                  color: Color(0xFF29B6F6),
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'What type of contamination did the scanner detect?',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 12),

              // ── Countdown timer ─────────────────────────────────────────
              AnimatedBuilder(
                animation: _timerCtrl,
                builder: (_, __) {
                  final remaining = 1.0 - _timerCtrl.value;
                  final timerColor = remaining > 0.55
                      ? const Color(0xFF69F0AE)
                      : remaining > 0.25
                      ? const Color(0xFFFFB300)
                      : Colors.redAccent;
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: remaining,
                          backgroundColor: Colors.white12,
                          valueColor: AlwaysStoppedAnimation(timerColor),
                          minHeight: 7,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${(_mcqDuration * remaining).toStringAsFixed(1)} s',
                        style: TextStyle(
                          color: timerColor,
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 14),

              // ── Answer choices ──────────────────────────────────────────
              ...choices.map((t) => _buildChoice(t, correct)),

              // Timeout message
              if (_answered && _chosen == null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.orangeAccent.withValues(alpha: 0.5),
                      ),
                    ),
                    child: const Text(
                      '⏱️  TIME\'S UP! Zone recorded with minimal score.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.orangeAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChoice(SoilPollutantType type, SoilPollutantType correct) {
    final (emoji, name, desc) = _choiceLabels[type]!;

    Color borderColor = Colors.white12;
    Color fillColor = Colors.white.withValues(alpha: 0.06);
    String prefix = '';

    if (_answered) {
      if (type == correct) {
        borderColor = const Color(0xFF69F0AE);
        fillColor = const Color(0xFF69F0AE).withValues(alpha: 0.14);
        prefix = '✅  ';
      } else if (type == _chosen && type != correct) {
        borderColor = Colors.redAccent;
        fillColor = Colors.redAccent.withValues(alpha: 0.13);
        prefix = '❌  ';
      }
    }

    return GestureDetector(
      onTap: _answered ? null : () => _onChoose(type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: fillColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 1.6),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$prefix$name',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    desc,
                    style: const TextStyle(color: Colors.white54, fontSize: 10),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  COMBO FLASH OVERLAY
// ════════════════════════════════════════════════════════════════════════════
class ComboFlashOverlay extends StatelessWidget {
  final SoilPollutionGame game;
  const ComboFlashOverlay(this.game, {super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: const Alignment(0.0, -0.45),
        child: AnimatedBuilder(
          animation: game,
          builder: (_, __) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFFFB300).withValues(alpha: 0.15),
                  const Color(0xFF69F0AE).withValues(alpha: 0.12),
                ],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: const Color(0xFFFFB300).withValues(alpha: 0.85),
                width: 2.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFB300).withValues(alpha: 0.45),
                  blurRadius: 24,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '🔥  ${game.comboFlashCount}×  COMBO!',
                  style: const TextStyle(
                    color: Color(0xFFFFB300),
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                    letterSpacing: 1.8,
                  ),
                ),
                Text(
                  '×${game.comboMultiplier.toStringAsFixed(1)} point multiplier active',
                  style: const TextStyle(
                    color: Color(0xFF69F0AE),
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  JAM ALERT OVERLAY
// ════════════════════════════════════════════════════════════════════════════
class JamAlertOverlay extends StatelessWidget {
  final SoilPollutionGame game;
  const JamAlertOverlay(this.game, {super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          // Red border flash
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.redAccent, width: 9),
            ),
          ),
          Align(
            alignment: const Alignment(0.0, -0.50),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF2A0A0A).withValues(alpha: 0.96),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.redAccent, width: 2.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withValues(alpha: 0.40),
                    blurRadius: 20,
                  ),
                ],
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '⚡  SCANNER JAMMED!',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      letterSpacing: 1.2,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Move away from the ⚡ interference node!',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  WRONG LAYER OVERLAY
// ════════════════════════════════════════════════════════════════════════════
class WrongLayerOverlay extends StatelessWidget {
  final SoilPollutionGame game;
  const WrongLayerOverlay(this.game, {super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: const Alignment(0.0, -0.35),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E0C00).withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFFF6D00), width: 1.8),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF6D00).withValues(alpha: 0.38),
                blurRadius: 18,
              ),
            ],
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '🔬  WRONG SCAN DEPTH!  −2 pts',
                style: TextStyle(
                  color: Color(0xFFFF6D00),
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  letterSpacing: 0.8,
                ),
              ),
              SizedBox(height: 5),
              Text(
                'Observe the zone\'s position in the soil bands\n'
                '🟤 Top  ·  🟠 Mid  ·  ⬛ Deep',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  SOIL HUD — enhanced with layer selector and combo indicator (Phase 3)
// ════════════════════════════════════════════════════════════════════════════
class SoilHud extends StatelessWidget {
  final SoilPollutionGame game;
  const SoilHud(this.game, {super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: game,
      builder: (_, __) {
        final warn = game.timeLeft < 20;
        final healthRatio = (game.soilHealth / 100.0).clamp(0.0, 1.0);
        final healthColor = game.soilHealth >= 80
            ? const Color(0xFF69F0AE)
            : game.soilHealth >= 50
            ? const Color(0xFFFFB300)
            : const Color(0xFFEF5350);

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Phase badge
                Align(
                  alignment: Alignment.topCenter,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: game.gamePhase == 3
                          ? const Color(0xFFFFB300).withValues(alpha: 0.88)
                          : const Color(0xFF69F0AE).withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color:
                              (game.gamePhase == 3
                                      ? const Color(0xFFFFB300)
                                      : const Color(0xFF69F0AE))
                                  .withValues(alpha: 0.35),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Text(
                      game.gamePhase == 3
                          ? '🔬  PHASE 3 — SOIL DIAGNOSIS'
                          : '🌱  PHASE 4 — BIOREMEDIATION',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Stats row
                Row(
                  children: [
                    _SHTile(
                      Icons.timer_rounded,
                      '${game.timeLeft.toInt()}s',
                      'TIME',
                      warn ? Colors.red : Colors.white,
                    ),
                    const SizedBox(width: 6),
                    _SHTile(
                      Icons.biotech_rounded,
                      game.gamePhase == 3
                          ? '${game.diagnosedCount}/10'
                          : '${game.remediatedCount}/10',
                      game.gamePhase == 3 ? 'DIAGNOSED' : 'TREATED',
                      const Color(0xFFFFB300),
                    ),
                    const SizedBox(width: 6),
                    _SHTile(
                      Icons.eco_rounded,
                      '${game.ecoPoints}',
                      'ECO-PTS',
                      Colors.limeAccent,
                    ),
                    const SizedBox(width: 6),
                    _SHTile(
                      Icons.grass_rounded,
                      '${game.soilHealth.toStringAsFixed(0)}%',
                      'HEALTH',
                      healthColor,
                    ),
                  ],
                ),
                const SizedBox(height: 5),

                // Soil health bar
                Row(
                  children: [
                    const Text('🌱', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: LinearProgressIndicator(
                          value: healthRatio,
                          backgroundColor: Colors.white12,
                          valueColor: AlwaysStoppedAnimation(healthColor),
                          minHeight: 8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: '${game.soilHealth.toStringAsFixed(0)}%',
                            style: TextStyle(
                              color: healthColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const TextSpan(
                            text: ' / 80%',
                            style: TextStyle(
                              color: Color(0xFF69F0AE),
                              fontSize: 8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // ── Phase 3 extras: layer selector + combo row ──────────────
                if (game.gamePhase == 3) ...[
                  const SizedBox(height: 8),
                  _buildLayerSelector(),
                  if (game.comboCount >= 2) ...[
                    const SizedBox(height: 4),
                    _buildComboIndicator(),
                  ],
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLayerSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'SCAN DEPTH',
          style: TextStyle(
            color: Colors.white38,
            fontSize: 8.5,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 8),
        _LayerBtn(
          ScanLayerType.topLayer,
          '🟤 TOP',
          const Color(0xFFBCAAA4),
          game,
        ),
        const SizedBox(width: 4),
        _LayerBtn(
          ScanLayerType.midLayer,
          '🟠 MID',
          const Color(0xFFFF6D00),
          game,
        ),
        const SizedBox(width: 4),
        _LayerBtn(
          ScanLayerType.deepLayer,
          '⬛ DEEP',
          const Color(0xFF9C64FB),
          game,
        ),
      ],
    );
  }

  Widget _buildComboIndicator() {
    final comboColor = game.comboCount >= 5
        ? Colors.redAccent
        : game.comboCount >= 3
        ? const Color(0xFFFFB300)
        : const Color(0xFF69F0AE);
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        decoration: BoxDecoration(
          color: comboColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: comboColor.withValues(alpha: 0.5),
            width: 1.2,
          ),
        ),
        child: Text(
          '🔥 ${game.comboCount}× COMBO   ×${game.comboMultiplier.toStringAsFixed(1)} pts',
          style: TextStyle(
            color: comboColor,
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }
}

// ── Layer selector button (embedded in HUD) ─────────────────────────────────
class _LayerBtn extends StatelessWidget {
  final ScanLayerType layer;
  final String label;
  final Color color;
  final SoilPollutionGame game;
  const _LayerBtn(this.layer, this.label, this.color, this.game);

  @override
  Widget build(BuildContext context) {
    final selected = game.selectedLayer == layer;
    return GestureDetector(
      onTap: () => game.selectLayer(layer),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.22)
              : Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: selected ? color : Colors.white24,
            width: selected ? 1.8 : 1.0,
          ),
          boxShadow: selected
              ? [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 8)]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? color : Colors.white60,
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

class _SHTile extends StatelessWidget {
  final IconData icon;
  final String val, label;
  final Color color;
  const _SHTile(this.icon, this.val, this.label, this.color);

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          Text(
            val,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 8,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    ),
  );
}

// ════════════════════════════════════════════════════════════════════════════
//  SOIL CONTROLS — enhanced with jammed / locked state feedback
// ════════════════════════════════════════════════════════════════════════════
class SoilControls extends StatefulWidget {
  final SoilPollutionGame game;
  const SoilControls(this.game, {super.key});
  @override
  State<SoilControls> createState() => _SoilControlsState();
}

class _SoilControlsState extends State<SoilControls> {
  bool _up = false, _dn = false, _lt = false, _rt = false;
  late FocusNode _fk;

  @override
  void initState() {
    super.initState();
    _fk = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fk.requestFocus());
  }

  @override
  void dispose() {
    _fk.dispose();
    super.dispose();
  }

  void _onKey(KeyEvent e) {
    final pressed = e is KeyDownEvent || e is KeyRepeatEvent;
    final released = e is KeyUpEvent;
    final k = e.logicalKey;

    void up(bool v) {
      setState(() => _up = v);
      widget.game.setUpKey(v);
    }

    void dn(bool v) {
      setState(() => _dn = v);
      widget.game.setDownKey(v);
    }

    void lt(bool v) {
      setState(() => _lt = v);
      widget.game.setLeftKey(v);
    }

    void rt(bool v) {
      setState(() => _rt = v);
      widget.game.setRightKey(v);
    }

    if (k == LogicalKeyboardKey.keyW || k == LogicalKeyboardKey.arrowUp) {
      if (pressed) up(true);
      if (released) up(false);
    }
    if (k == LogicalKeyboardKey.keyS || k == LogicalKeyboardKey.arrowDown) {
      if (pressed) dn(true);
      if (released) dn(false);
    }
    if (k == LogicalKeyboardKey.keyA || k == LogicalKeyboardKey.arrowLeft) {
      if (pressed) lt(true);
      if (released) lt(false);
    }
    if (k == LogicalKeyboardKey.keyD || k == LogicalKeyboardKey.arrowRight) {
      if (pressed) rt(true);
      if (released) rt(false);
    }

    if (k == LogicalKeyboardKey.space && pressed) {
      if (widget.game.gamePhase == 3) {
        widget.game.diagnoseZone();
      } else {
        widget.game.applyAgent();
      }
    }

    // Layer shortcuts (keyboard, phase 3)
    if (widget.game.gamePhase == 3) {
      if (k == LogicalKeyboardKey.digit1 && pressed) {
        widget.game.selectLayer(ScanLayerType.topLayer);
      }
      if (k == LogicalKeyboardKey.digit2 && pressed) {
        widget.game.selectLayer(ScanLayerType.midLayer);
      }
      if (k == LogicalKeyboardKey.digit3 && pressed) {
        widget.game.selectLayer(ScanLayerType.deepLayer);
      }
    }

    // Remediation agent shortcuts (keyboard, phase 4)
    if (widget.game.gamePhase == 4) {
      if (k == LogicalKeyboardKey.digit1 && pressed) {
        widget.game.selectAgent(RemediationAgent.biocharBacteria);
      }
      if (k == LogicalKeyboardKey.digit2 && pressed) {
        widget.game.selectAgent(RemediationAgent.limeGypsum);
      }
      if (k == LogicalKeyboardKey.digit3 && pressed) {
        widget.game.selectAgent(RemediationAgent.phytoPlants);
      }
      if (k == LogicalKeyboardKey.digit4 && pressed) {
        widget.game.selectAgent(RemediationAgent.compostWorms);
      }
      if (k == LogicalKeyboardKey.digit5 && pressed) {
        widget.game.selectAgent(RemediationAgent.earthworms);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.game,
      builder: (_, __) {
        final phase = widget.game.gamePhase;
        final jammed = widget.game.scannerJammed;
        final busy = widget.game.calibrationActive || widget.game.mcqActive;

        final canAct = phase == 3
            ? (widget.game._hasNearbyUndiagnosed && !jammed && !busy)
            : widget.game._hasNearbyUnremediated;

        final actColor = phase == 3
            ? const Color(0xFFFFB300)
            : const Color(0xFF69F0AE);

        // Action button label reflects current state
        final String actLabel;
        if (phase == 3) {
          if (jammed) {
            actLabel = '⚡\nJAMMED';
          } else if (busy) {
            actLabel = '🔒\nBUSY';
          } else {
            actLabel = '🔬\nSCAN';
          }
        } else {
          actLabel = '🌱\nAPPLY';
        }

        return KeyboardListener(
          focusNode: _fk,
          onKeyEvent: _onKey,
          child: Stack(
            children: [
              // D-pad (bottom-left)
              Align(
                alignment: Alignment.bottomLeft,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16, left: 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _SPad(
                          '⬆',
                          _up,
                          Colors.cyanAccent,
                          onDown: () {
                            setState(() => _up = true);
                            widget.game.setUpKey(true);
                          },
                          onUp: () {
                            setState(() => _up = false);
                            widget.game.setUpKey(false);
                          },
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _SPad(
                              '◀',
                              _lt,
                              Colors.cyanAccent,
                              onDown: () {
                                setState(() => _lt = true);
                                widget.game.setLeftKey(true);
                              },
                              onUp: () {
                                setState(() => _lt = false);
                                widget.game.setLeftKey(false);
                              },
                            ),
                            const SizedBox(width: 4),
                            _SPad(
                              '⬇',
                              _dn,
                              Colors.cyanAccent,
                              onDown: () {
                                setState(() => _dn = true);
                                widget.game.setDownKey(true);
                              },
                              onUp: () {
                                setState(() => _dn = false);
                                widget.game.setDownKey(false);
                              },
                            ),
                            const SizedBox(width: 4),
                            _SPad(
                              '▶',
                              _rt,
                              Colors.cyanAccent,
                              onDown: () {
                                setState(() => _rt = true);
                                widget.game.setRightKey(true);
                              },
                              onUp: () {
                                setState(() => _rt = false);
                                widget.game.setRightKey(false);
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Action button (bottom-right)
              Align(
                alignment: Alignment.bottomRight,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 20, right: 14),
                    child: GestureDetector(
                      onTap: () {
                        if (phase == 3) {
                          widget.game.diagnoseZone();
                        } else {
                          widget.game.applyAgent();
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 140),
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          color: canAct
                              ? actColor.withValues(alpha: 0.22)
                              : Colors.black.withValues(alpha: 0.60),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: canAct ? actColor : Colors.white24,
                            width: canAct ? 2.5 : 1.5,
                          ),
                          boxShadow: canAct
                              ? [
                                  BoxShadow(
                                    color: actColor.withValues(alpha: 0.40),
                                    blurRadius: 14,
                                  ),
                                ]
                              : [],
                        ),
                        child: Center(
                          child: Text(
                            actLabel,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: canAct ? actColor : Colors.white30,
                              fontWeight: FontWeight.w900,
                              fontSize: 9,
                              letterSpacing: 0.4,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SPad extends StatelessWidget {
  final String label;
  final bool isActive;
  final Color color;
  final VoidCallback onDown, onUp;
  const _SPad(
    this.label,
    this.isActive,
    this.color, {
    required this.onDown,
    required this.onUp,
  });

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (_) => onDown(),
    onPointerUp: (_) => onUp(),
    onPointerCancel: (_) => onUp(),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 70),
      width: 52,
      height: 52,
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: isActive
            ? color.withValues(alpha: 0.30)
            : Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isActive ? color : Colors.white24,
          width: 1.8,
        ),
        boxShadow: isActive
            ? [BoxShadow(color: color.withValues(alpha: 0.40), blurRadius: 10)]
            : [],
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? color : Colors.white60,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    ),
  );
}

// ════════════════════════════════════════════════════════════════════════════
//  PHASE BANNER
// ════════════════════════════════════════════════════════════════════════════
class SoilPhaseBanner extends StatelessWidget {
  final SoilPollutionGame game;
  const SoilPhaseBanner(this.game, {super.key});

  @override
  Widget build(BuildContext context) {
    final phase3 = game.gamePhase == 3;
    final accent = phase3 ? const Color(0xFFFFB300) : const Color(0xFF69F0AE);

    return IgnorePointer(
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: phase3
                  ? [const Color(0xFF1A1000), const Color(0xFF2E1800)]
                  : [const Color(0xFF001A0A), const Color(0xFF003018)],
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 24)],
            border: Border.all(
              color: accent.withValues(alpha: 0.55),
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                phase3 ? 'PHASE 3' : 'PHASE 4',
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 13,
                  letterSpacing: 2.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                phase3 ? '🔬  Soil Diagnosis' : '🌱  Bioremediation',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                phase3
                    ? 'Select the 🟤🟠⬛ scan depth, fly near each "?" zone,\n'
                          'then tap 🔬 SCAN → calibrate → identify the pollutant!\n'
                          'Avoid ⚡ jammers. Chase 🔶 drifting zones for bonus pts.'
                    : 'Select the correct remedy and tap 🌱 APPLY\n'
                          'when near each diagnosed polluted zone.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  REMEDIATION AGENT SELECTOR  (Phase 4 only — unchanged)
// ════════════════════════════════════════════════════════════════════════════
class RemediationAgentSelector extends StatelessWidget {
  final SoilPollutionGame game;
  const RemediationAgentSelector(this.game, {super.key});

  static const _agents = [
    (
      RemediationAgent.biocharBacteria,
      '🛢️',
      'Biochar+\nBacteria',
      Color(0xFF424242),
      'Oil Spill',
    ),
    (
      RemediationAgent.limeGypsum,
      '🪨',
      'Lime /\nGypsum',
      Color(0xFFCE93D8),
      'Acidic',
    ),
    (
      RemediationAgent.phytoPlants,
      '🌻',
      'Phyto-\nPlants',
      Color(0xFF7B1FA2),
      'Heavy Metals',
    ),
    (
      RemediationAgent.compostWorms,
      '🌿',
      'Compost+\nWorms',
      Color(0xFFFF6D00),
      'Pesticides',
    ),
    (
      RemediationAgent.earthworms,
      '🪱',
      'Earth-\nworms',
      Color(0xFFBCAAA4),
      'Compact',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: game,
      builder: (_, __) {
        final mobile = MediaQuery.of(context).size.width < 600;
        return Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 80, left: 8, right: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.78),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'SELECT REMEDIATION AGENT',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: mobile ? 7.5 : 9,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: _agents.map((a) {
                        final (agent, emoji, label, color, target) = a;
                        final sel = game.selectedAgent == agent;
                        return GestureDetector(
                          onTap: () => game.selectAgent(agent),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 140),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            padding: EdgeInsets.symmetric(
                              horizontal: mobile ? 7 : 10,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: sel
                                  ? color.withValues(alpha: 0.22)
                                  : Colors.white.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: sel ? color : Colors.white12,
                                width: sel ? 2.0 : 1.0,
                              ),
                              boxShadow: sel
                                  ? [
                                      BoxShadow(
                                        color: color.withValues(alpha: 0.35),
                                        blurRadius: 10,
                                      ),
                                    ]
                                  : [],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  emoji,
                                  style: TextStyle(fontSize: mobile ? 16 : 20),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  label,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: sel ? color : Colors.white70,
                                    fontWeight: FontWeight.w900,
                                    fontSize: mobile ? 7 : 8,
                                    height: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  target,
                                  style: TextStyle(
                                    color: sel
                                        ? color.withValues(alpha: 0.75)
                                        : Colors.white38,
                                    fontSize: 6.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  SOIL REACTION FLASH
// ════════════════════════════════════════════════════════════════════════════
class SoilReactionFx extends StatelessWidget {
  final SoilPollutionGame game;
  const SoilReactionFx(this.game, {super.key});

  @override
  Widget build(BuildContext context) {
    final ok = game.reactionCorrect;
    final phase3 = game.reactionPhase == 3;
    final inRange = game.reactionInRange;

    final String title;
    final String sub;
    if (!inRange) {
      title = '🔬  OUT OF RANGE!';
      sub = 'Move the drone closer to a contaminated zone';
    } else if (phase3 && ok) {
      title = '🔬  POLLUTANT DETECTED!';
      sub = 'Layer ✓  ·  Calibration bonus applied  ·  MCQ scored';
    } else if (!phase3 && ok) {
      title = '🌱  SOIL HEALING!';
      sub = '+20 Eco-Points  ·  Soil health rises';
    } else if (phase3 && !ok) {
      title = '❌  CALIBRATION MISSED!';
      sub = 'Combo reset  ·  Move drone and try again';
    } else {
      title = '❌  WRONG TREATMENT!';
      sub = '−10 Eco-Points  ·  Soil health drops';
    }

    final accent = (ok || !inRange)
        ? const Color(0xFF69F0AE)
        : const Color(0xFFEF5350);

    return IgnorePointer(
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: accent, width: 10),
              gradient: RadialGradient(
                colors: [Colors.transparent, accent.withValues(alpha: 0.12)],
                radius: 1.5,
              ),
            ),
          ),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
              decoration: BoxDecoration(
                color: ok
                    ? const Color(0xFF0A2E10).withValues(alpha: 0.95)
                    : const Color(0xFF2E0A0A).withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black54,
                    blurRadius: 14,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    sub,
                    style: TextStyle(
                      color: accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  SOIL RESULTS OVERLAY
// ════════════════════════════════════════════════════════════════════════════
class SoilResultsOverlay extends StatelessWidget {
  final SoilPollutionGame game;
  const SoilResultsOverlay(this.game, {super.key});

  @override
  Widget build(BuildContext context) {
    final result = SoilPollutionResult.current!;
    final guardian = result.soilGuardianBadge;
    final hFinal = result.soilHealthFinal.toStringAsFixed(0);

    return Container(
      color: Colors.black.withValues(alpha: 0.94),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Column(
            children: [
              // Hero card
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: guardian
                        ? [const Color(0xFF001A0A), const Color(0xFF003018)]
                        : [const Color(0xFF1A1000), const Color(0xFF2A1800)],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: const [
                    BoxShadow(color: Colors.black54, blurRadius: 16),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      guardian ? '🌻' : '🌱',
                      style: const TextStyle(fontSize: 52),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      guardian ? 'Soil Fully Regenerated!' : 'Phase Complete',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Phase 3 & 4 — Soil Pollution Results',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    if (guardian) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF69F0AE,
                          ).withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(
                              0xFF69F0AE,
                            ).withValues(alpha: 0.40),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('🏅', style: TextStyle(fontSize: 14)),
                            SizedBox(width: 6),
                            Text(
                              'Soil Guardian Badge Unlocked!',
                              style: TextStyle(
                                color: Color(0xFF69F0AE),
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 16),

              _SRCard(
                children: [
                  _SRBig(
                    '🌱',
                    '$hFinal%',
                    'Soil Health',
                    guardian
                        ? const Color(0xFF69F0AE)
                        : const Color(0xFFFFB300),
                  ),
                  _SRBig(
                    '✅',
                    '${result.zonesRemediated}',
                    'Treated',
                    Colors.limeAccent,
                  ),
                  _SRBig(
                    '❌',
                    '${result.wrongTreatments}',
                    'Wrong',
                    Colors.redAccent,
                  ),
                  _SRBig('⭐', '${result.ecoPoints}', 'Eco-Pts', Colors.amber),
                ],
              ),

              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A1A08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Bioremediation Applied',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _SRRow(
                      '🛢️',
                      'Oil Spills',
                      '🌑 Biochar + bacteria cultures',
                    ),
                    _SRRow('⚗️', 'Acidic Soil', '🪨 Lime / gypsum neutralised'),
                    _SRRow(
                      '⚙️',
                      'Heavy Metals',
                      '🌻 Phyto-plants absorbed metals',
                    ),
                    _SRRow('🧪', 'Pesticides', '🌿 Compost + worms decomposed'),
                    _SRRow(
                      '🪨',
                      'Compact Soil',
                      '🪱 Earthworms restored aeration',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    game.resumeEngine();
                    game.onLevelComplete();
                  },
                  icon: const Icon(Icons.emoji_events_rounded),
                  label: const Text(
                    'Complete Level 5  →',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF69F0AE),
                    foregroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 8,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Small result widgets ─────────────────────────────────────────────────────
class _SRCard extends StatelessWidget {
  final List<Widget> children;
  const _SRCard({required this.children});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    decoration: BoxDecoration(
      color: const Color(0xFF0A1A08),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white12),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: children,
    ),
  );
}

class _SRBig extends StatelessWidget {
  final String emoji, value, label;
  final Color color;
  const _SRBig(this.emoji, this.value, this.label, this.color);
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(emoji, style: const TextStyle(fontSize: 20)),
      const SizedBox(height: 4),
      Text(
        value,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
      const SizedBox(height: 2),
      Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white54, fontSize: 9),
      ),
    ],
  );
}

class _SRRow extends StatelessWidget {
  final String emoji, label, action;
  const _SRRow(this.emoji, this.label, this.action);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 15)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          action,
          style: const TextStyle(color: Color(0xFF69F0AE), fontSize: 10),
        ),
      ],
    ),
  );
}
