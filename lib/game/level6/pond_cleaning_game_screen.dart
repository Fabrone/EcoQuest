import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:ecoquest/game/level6/degraded_park_screen.dart';
import 'package:ecoquest/game/level6/wildlife_rescue_screen.dart';
import 'package:flame/components.dart' hide Matrix4;
import 'package:flame/game.dart' hide Matrix4;
import 'package:flutter/material.dart' hide Matrix4;
import 'package:flutter/services.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  POND CLEANING GAME  —  EcoQuest Level 6-B  ·  Standalone Water Purification
//  8 ponds across a 3× wetland world. Scan → Identify → Treat.
//  First-hint / Memory-recall · Critical alerts · Algae spread · Acid rain
//  Completes → WildlifeRescueScreen
// ══════════════════════════════════════════════════════════════════════════════

class PondCleaningResult {
  final int    pondsClean;
  final int    correctTreatments;
  final int    wrongTreatments;
  final int    ecoPoints;
  final double waterPurity;
  final int    maxCombo;
  final int    criticalSaves;
  final int    pondsSpread;
  final int    resupplyTriggered;
  final bool   meetsMinimum;
  final int    minimumPondsRequired;
  final String endReason;
  final LevelCompletionState completionState;

  const PondCleaningResult({
    required this.pondsClean,
    required this.correctTreatments,
    required this.wrongTreatments,
    required this.ecoPoints,
    required this.waterPurity,
    this.maxCombo              = 1,
    this.criticalSaves         = 0,
    this.pondsSpread           = 0,
    this.resupplyTriggered     = 0,
    this.meetsMinimum          = false,
    this.minimumPondsRequired  = 5,
    this.endReason             = 'Level completed.',
    this.completionState       = LevelCompletionState.failed,
  });

  int get accuracyPct =>
      (correctTreatments + wrongTreatments) == 0
          ? 0
          : ((correctTreatments / (correctTreatments + wrongTreatments)) * 100).round();

  String get performanceGrade {
    if (correctTreatments >= 7 && pondsClean >= 6) return 'WETLAND GUARDIAN';
    if (correctTreatments >= 5 && pondsClean >= 4) return 'AQUA ECOLOGIST';
    if (correctTreatments >= 3 && pondsClean >= 3) return 'POND STEWARD';
    return 'JUNIOR RANGER';
  }

  String get performanceSummary {
    final lines = <String>[];
    if (criticalSaves > 0)   lines.add('Saved $criticalSaves critical pond(s) from collapse');
    if (pondsSpread > 0)     lines.add('$pondsSpread pond(s) spread due to neglect');
    if (maxCombo >= 4)       lines.add('$maxCombo-action combo achieved — 3× point multiplier!');
    return lines.isEmpty
        ? 'Clean all ponds to maximise your score.'
        : lines.join('\n');
  }

  static PondCleaningResult? current;
}

enum LevelCompletionState { failed, moderate, fullCompletion }

class CriticalPondAlert {
  final PondTarget pond;
  double timeLeft;
  bool   handled;
  CriticalPondAlert({required this.pond, this.timeLeft = 12.0, this.handled = false});
}

class PondScanResult {
  final PondType type;
  final String typeName;
  final String ecoFact;
  final String correctAction;
  final String icon;
  final Color  color;
  final bool   hasEcoDiscovery;
  final String discoveryFact;

  const PondScanResult({
    required this.type,
    required this.typeName,
    required this.ecoFact,
    required this.correctAction,
    required this.icon,
    required this.color,
    this.hasEcoDiscovery = false,
    this.discoveryFact   = '',
  });

  static const _pondFacts = {
    PondType.algaeBloom: [
      'Algae blooms in Karura\'s ponds deplete oxygen — killing fish and frogs. Water hyacinths absorb excess nutrients, naturally restoring balance.',
      'A single algae bloom can double in size every two days. Early hyacinth treatment prevents full pond collapse.',
    ],
    PondType.organicWaste: [
      'Organic runoff from Nairobi\'s estates introduces high nutrient loads, fuelling bacterial growth. Targeted bacteria pellets break down waste safely.',
      'Organic pollution triggers BOD spikes — suffocating pond life. Bio-remediation bacteria restore oxygen within days.',
    ],
    PondType.chemicalPollution: [
      'Chemical contaminants from nearby industry persist in pond sediment for years. Filtration units remove up to 95% of dissolved pollutants.',
      'Heavy metals bioaccumulate in fish and birds. A single filtration cycle protects the entire food chain above the pond.',
    ],
  };

  static const _discoveryFacts = {
    PondType.algaeBloom:
      '🏺 Cultural Marker Found! The Kikuyu called clear ponds "Iria ria Kiumo" — sacred water lines. Keeping them pure was a spiritual duty to the land.',
    PondType.organicWaste:
      '🌿 Cultural Marker Found! Elders of Ondiri used "githiga" compost mounds near wetlands to filter organic runoff naturally — ancestral bio-remediation.',
    PondType.chemicalPollution:
      '⚗️ Cultural Marker Found! Early Nairobi chemists traded purified water from Karura\'s springs. Protecting chemical purity is a legacy of scientific stewardship.',
  };

  static PondScanResult forType(PondType t, {bool withDiscovery = false, int variant = 0}) {
    final facts = _pondFacts[t]!;
    final fact  = facts[variant % facts.length];
    switch (t) {
      case PondType.algaeBloom:
        return PondScanResult(
          type: t, typeName: 'Algae Bloom',
          ecoFact: fact,
          correctAction: 'Deploy 🌿 Water Hyacinths',
          icon: '🌿', color: const Color(0xFF2E7D32),
          hasEcoDiscovery: withDiscovery,
          discoveryFact: withDiscovery ? (_discoveryFacts[t] ?? '') : '',
        );
      case PondType.organicWaste:
        return PondScanResult(
          type: t, typeName: 'Organic Waste Pond',
          ecoFact: fact,
          correctAction: 'Apply 🧫 Bacteria Pellets',
          icon: '🦠', color: const Color(0xFF795548),
          hasEcoDiscovery: withDiscovery,
          discoveryFact: withDiscovery ? (_discoveryFacts[t] ?? '') : '',
        );
      case PondType.chemicalPollution:
        return PondScanResult(
          type: t, typeName: 'Chemical Pollution',
          ecoFact: fact,
          correctAction: 'Install 🔧 Filtration Unit',
          icon: '☠️', color: const Color(0xFF7B1FA2),
          hasEcoDiscovery: withDiscovery,
          discoveryFact: withDiscovery ? (_discoveryFacts[t] ?? '') : '',
        );
    }
  }
}

enum PondType      { algaeBloom, organicWaste, chemicalPollution }
enum PondTreatment { hyacinths, bacteriaPellets, filtrationUnit }

// ══════════════════════════════════════════════════════════════════════════════
//  SCREEN WRAPPER
// ══════════════════════════════════════════════════════════════════════════════
class PondCleaningGameScreen extends StatefulWidget {
  final Level5CarryOver carryOver;
  const PondCleaningGameScreen({super.key, required this.carryOver});

  @override
  State<PondCleaningGameScreen> createState() => _PondCleaningGameScreenState();
}

class _PondCleaningGameScreenState extends State<PondCleaningGameScreen> {
  late PondCleaningGame _game;

  @override
  void initState() {
    super.initState();
    _game = PondCleaningGame(
      carryOver:       widget.carryOver,
      onLevelComplete: _onDone,
    );
  }

  void _onDone() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => WildlifeRescueScreen(carryOver: widget.carryOver)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GameWidget(
        game: _game,
        overlayBuilderMap: {
          'hud':             (ctx, g) => PondHud(g as PondCleaningGame),
          'controls':        (ctx, g) => PondControls(g as PondCleaningGame),
          'banner':          (ctx, g) => PondBanner(g as PondCleaningGame),
          'scanResult':      (ctx, g) => PondScanResultOverlay(g as PondCleaningGame),
          'treatmentSelect': (ctx, g) => PondTreatmentSelector(g as PondCleaningGame),
          'reactionFx':      (ctx, g) => PondReactionFx(g as PondCleaningGame),
          'criticalAlert':   (ctx, g) => CriticalPondAlertOverlay(g as PondCleaningGame),
          'acidRain':        (ctx, g) => AcidRainAlertOverlay(g as PondCleaningGame),
          'treatResupply':   (ctx, g) => TreatmentResupplyOverlay(g as PondCleaningGame),
          'results':         (ctx, g) => PondResultsOverlay(g as PondCleaningGame),
        },
        initialActiveOverlays: const ['hud', 'controls'],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  MAIN GAME CLASS
// ══════════════════════════════════════════════════════════════════════════════
class PondCleaningGame extends FlameGame
    with HasCollisionDetection, ChangeNotifier {

  final Level5CarryOver carryOver;
  final VoidCallback    onLevelComplete;
  PondCleaningGame({required this.carryOver, required this.onLevelComplete});

  static const int kMinPondsRequired = 5;

  static const double kWorldScale   = 3.0;
  static const double kEdgeFraction = 0.22;
  static const double kCameraEase   = 5.5;
  double worldW = 0, worldH = 0;
  double camX = 0, camY = 0;
  double _targetCamX = 0, _targetCamY = 0;
  double edgeHintLeft = 0, edgeHintRight = 0;
  double edgeHintTop  = 0, edgeHintBottom = 0;

  bool   gameStarted = false;
  double timeLeft    = 150.0;
  bool   levelDone   = false;

  int ecoPoints           = 0;
  int pondsFixed          = 0;
  int correctTreatments   = 0;
  int wrongTreatments     = 0;
  int maxCombo            = 1;

  double waterPurity = 10.0;
  static const double _purityGain   = 18.0;
  static const double _wrongPenalty = 6.0;

  static const double _scanRange     = 145.0;
  static const double _treatRange    = 110.0;
  static const double _scanMaxRadius = 170.0;

  late Vector2 dronePos;
  bool isUp = false, isDown = false, isLeft = false, isRight = false;
  static const double _droneSpeed = 185.0;

  bool        scanLockActive   = false;
  double      _scanLockTimer   = 0;
  static const double _scanDuration = 1.5;
  PondTarget? activeScanPond;
  PondTarget? _nearestScanPond;
  bool        scanActive       = false;
  double      scanRadius       = 0;

  bool               scanResultActive = false;
  PondScanResult?    lastScanResult;
  double             scanResultTimer  = 0;
  int                lastScanPoints   = 0;
  Vector2            scanCardPos      = Vector2.zero();

  int    scanStreak      = 0;
  double scanStreakTimer  = 0;
  int    totalScanStreak = 0;
  static const double _streakWindow = 6.0;

  final Map<PondTreatment, int> treatmentUses = {
    PondTreatment.hyacinths:       3,
    PondTreatment.bacteriaPellets: 3,
    PondTreatment.filtrationUnit:  3,
  };
  PondTreatment selectedTreatment = PondTreatment.hyacinths;
  bool get canUseSelectedTreatment => (treatmentUses[selectedTreatment] ?? 0) > 0;

  PondTarget? pendingTreatTarget;
  bool        treatmentSelectorOpen = false;

  int    _pondsSinceResupply = 0;
  int    resupplyTriggered   = 0;
  bool   resupplyActive      = false;
  double resupplyTimer       = 0;
  static const double _resupplyDisplay = 2.2;

  final List<CriticalPondAlert> criticalAlerts = [];
  double _criticalAlertTimer = 45.0;
  int    criticalSaves       = 0;

  final Map<PondTarget, double> _algaeIdleTimers = {};
  static const double _algaeSpreadAt = 30.0;
  int    pondsSpread      = 0;
  double _algaeCheckTimer = 1.0;

  double _acidRainTimer      = 50.0;
  bool   acidRainWarning     = false;
  bool   acidRainActive      = false;
  double _acidRainWarningCd  = 0;
  double _acidRainActiveCd   = 0;
  double acidRainIntensity   = 0;

  double _surgeTimer   = 28.0;
  bool   surgePending  = false;
  double surgePulse    = 0;

  final Set<PondType> _seenPondTypes = {};
  bool scanResultShowsHints  = true;
  bool treatmentShowsHints   = true;

  bool   reactionActive  = false;
  bool   reactionCorrect = false;
  bool   reactionInRange = true;
  double reactionTimer   = 0;
  String reactionMsg     = '';

  double bannerTimer = 3.5;

  String ecoGuideHint  = '';
  double ecoGuideTimer = 0;
  double _hintCooldown = 0;
  double _idleTimer    = 0;

  late PondDroneComponent drone;
  final List<PondTarget> ponds = [];
  static const int totalPonds = 8;

  @override
  Future<void> onLoad() async {
    super.onLoad();
    worldW   = size.x * kWorldScale;
    worldH   = size.y * kWorldScale;
    dronePos = Vector2(worldW * 0.50, worldH * 0.50);
    _centerCamOn(dronePos);
    _targetCamX = camX; _targetCamY = camY;

    add(WetlandRenderer(game: this));
    drone = PondDroneComponent(game: this);
    add(drone);

    _spawnPonds();
    _assignSpecialPonds();

    bannerTimer = 3.5;
    overlays.add('banner');
    add(TimerComponent(period: 1.0, repeat: true, onTick: _onSecond));
  }

  void _centerCamOn(Vector2 pos) {
    camX = (pos.x - size.x / 2).clamp(0.0, worldW - size.x);
    camY = (pos.y - size.y / 2).clamp(0.0, worldH - size.y);
  }

  Vector2 screenToWorld(Vector2 s) => Vector2(s.x + camX, s.y + camY);
  Vector2 worldToScreen(Vector2 w) => Vector2(w.x - camX, w.y - camY);
  Vector2 get droneScreen => worldToScreen(dronePos);

  void _spawnPonds() {
    const specs = [
      (PondType.algaeBloom,        0.38, 0.38),
      (PondType.algaeBloom,        0.68, 0.55),
      (PondType.organicWaste,      0.20, 0.48),
      (PondType.organicWaste,      0.82, 0.30),
      (PondType.chemicalPollution, 0.52, 0.65),
      (PondType.chemicalPollution, 0.22, 0.72),
      (PondType.algaeBloom,        0.62, 0.22),
      (PondType.organicWaste,      0.45, 0.78),
    ];
    for (int i = 0; i < specs.length; i++) {
      final (type, rx, ry) = specs[i];
      final p = PondTarget(
        game: this, type: type,
        worldX: worldW * rx, worldY: worldH * ry,
        seed: i * 23,
      );
      add(p); ponds.add(p);
    }
  }

  void _assignSpecialPonds() {
    final rng = math.Random(DateTime.now().millisecondsSinceEpoch);
    final indices = List.generate(ponds.length, (i) => i)..shuffle(rng);
    // First 2 ponds carry hidden eco-discovery markers
    ponds[indices[0]].hasDiscovery = true;
    ponds[indices[1]].hasDiscovery = true;
  }

  void _onSecond() {
    if (!gameStarted || levelDone) return;
    timeLeft -= 1;
    if (timeLeft <= 0) { timeLeft = 0; _endLevel(); }
    notifyListeners();
  }

  double get scanHoldProgress =>
      scanLockActive ? (_scanLockTimer / _scanDuration).clamp(0.0, 1.0) : 0.0;

  bool get _hasNearbyUnscannedPond =>
      ponds.any((p) => !p.isScanned && !p.isClean &&
          (p.pondPos - dronePos).length <= _scanRange);

  PondTarget? get _nearestTreatable {
    PondTarget? best; double minD = _treatRange;
    for (final p in ponds) {
      if (p.isClean) continue;
      final d = (p.pondPos - dronePos).length;
      if (d < minD) { minD = d; best = p; }
    }
    return best;
  }
  
  int comboCount = 0;
  double comboTimer = 0.0;
  static const double _comboWindow = 6.0; // Define _comboWindow with an appropriate value
  
  double comboFlashTimer = 0;
  bool showComboFlash = false;

  // ══════════════════════════════════════════════════════════════════════════
  //  POND SCAN
  // ══════════════════════════════════════════════════════════════════════════
  void triggerScan() {
    if (!gameStarted || levelDone) return;
    HapticFeedback.selectionClick();

    if (treatmentSelectorOpen) {
      reactionMsg = '💧 Apply a treatment first!';
      _triggerReaction(false, inRange: false);
      notifyListeners(); return;
    }
    if (scanLockActive) {
      reactionMsg = '🔬 Scanning pond…';
      _triggerReaction(true, inRange: true);
      notifyListeners(); return;
    }

    PondTarget? nearest; double nearestD = _scanRange;
    for (final p in ponds) {
      if (p.isScanned || p.isClean) continue;
      final d = (p.pondPos - dronePos).length;
      if (d < nearestD) { nearestD = d; nearest = p; }
    }

    if (nearest == null) {
      reactionMsg = '💧 No unscanned pond in range — fly closer';
      _triggerReaction(false, inRange: false);
      notifyListeners(); return;
    }

    activeScanPond     = nearest;
    scanLockActive     = true;
    _scanLockTimer     = 0;
    scanActive         = true; scanRadius = 0;
    reactionMsg        = '🔬 Analysing pond — stay in range!';
    _triggerReaction(true, inRange: true);
    HapticFeedback.lightImpact();
    notifyListeners();
  }

  void _completePondScan(PondTarget p) {
    if (p.isScanned) return;
    final idx = ponds.indexOf(p);
    p.isScanned   = true;
    p.scanVariant = idx;

    final hasDiscovery = p.hasDiscovery;
    final pts        = hasDiscovery ? 30 : 12;
    ecoPoints       += pts;
    lastScanPoints   = pts;
    scanCardPos      = dronePos.clone();

    final firstScan = !_seenPondTypes.contains(p.type);
    if (firstScan) _seenPondTypes.add(p.type);
    scanResultShowsHints = firstScan;
    treatmentShowsHints  = firstScan;

    lastScanResult   = PondScanResult.forType(p.type, withDiscovery: hasDiscovery, variant: idx);
    scanResultTimer  = hasDiscovery ? 5.5 : 4.0;
    scanResultActive = true;

    scanLockActive = false; _scanLockTimer = 0; activeScanPond = null;
    _handleScanStreak();
    HapticFeedback.heavyImpact();

    if (hasDiscovery) {
      // For simplicity, discovery is shown inline in scan result; no separate overlay
      overlays.add('scanResult');
    } else {
      overlays.add('scanResult');
    }

    pendingTreatTarget = p;
    notifyListeners();
  }

  void openTreatmentSelectorForPending() {
    if (pendingTreatTarget == null || treatmentSelectorOpen) return;
    treatmentSelectorOpen = true;
    overlays.remove('scanResult');
    scanResultActive = false;
    overlays.add('treatmentSelect');
    notifyListeners();
  }

  void dismissScanResult() {
    if (!scanResultActive) return;
    scanResultActive = false;
    overlays.remove('scanResult');
    if (pendingTreatTarget != null && !treatmentSelectorOpen) {
      treatmentSelectorOpen = true;
      overlays.add('treatmentSelect');
    }
    notifyListeners();
  }

  void selectTreatment(PondTreatment t) {
    selectedTreatment = t;
    notifyListeners();
    if (treatmentSelectorOpen) treatPond();
  }

  void treatPond() {
    if (!gameStarted || levelDone) return;
    if (!canUseSelectedTreatment) {
      reactionMsg = '⚠️ No ${_treatmentLabel(selectedTreatment)} uses left!';
      _triggerReaction(false, inRange: false);
      notifyListeners(); return;
    }

    final target = pendingTreatTarget ?? _nearestTreatable;
    if (target == null) {
      reactionMsg = '💧 Scan a pond first';
      _triggerReaction(false, inRange: false);
      notifyListeners(); return;
    }

    HapticFeedback.lightImpact();
    treatmentUses[selectedTreatment] = (treatmentUses[selectedTreatment] ?? 1) - 1;

    final correct = _isCorrectTreatment(target.type, selectedTreatment);

    if (correct) {
      target.clean();
      target.triggerSparkle = true;
      pondsFixed++;
      correctTreatments++;
      waterPurity = math.min(100, waterPurity + _purityGain);
      ecoPoints  += 25 * _comboMult();
      _incCombo();
      _algaeIdleTimers.remove(target);
      _dismissCriticalAlert(target, saved: true);
      reactionMsg = '💧 Pond Cleaned!  +${25 * _comboMult()} pts  🎉';
      _triggerReaction(true);
      _pondsSinceResupply++;
      if (_pondsSinceResupply >= 3) {
        _pondsSinceResupply = 0;
        _triggerResupply();
      }

      pendingTreatTarget    = null;
      treatmentSelectorOpen = false;
      overlays.remove('treatmentSelect');
    } else {
      waterPurity = math.max(0, waterPurity - _wrongPenalty);
      ecoPoints   = math.max(0, ecoPoints - 8);
      wrongTreatments++;
      _breakCombo();
      reactionMsg = '❌ Wrong treatment — try another!';
      _triggerReaction(false);
    }

    if (ponds.every((p) => p.isClean)) {
      Future.delayed(const Duration(milliseconds: 800), _endLevel);
    }
    notifyListeners();
  }

  bool _isCorrectTreatment(PondType t, PondTreatment tr) {
    switch (t) {
      case PondType.algaeBloom:        return tr == PondTreatment.hyacinths;
      case PondType.organicWaste:      return tr == PondTreatment.bacteriaPellets;
      case PondType.chemicalPollution: return tr == PondTreatment.filtrationUnit;
    }
  }

  void cancelTreatmentSelector() {
    treatmentSelectorOpen = false;
    pendingTreatTarget    = null;
    overlays.remove('treatmentSelect');
    notifyListeners();
  }

  String _treatmentLabel(PondTreatment t) {
    switch (t) {
      case PondTreatment.hyacinths:       return 'Hyacinths';
      case PondTreatment.bacteriaPellets: return 'Bacteria Pellets';
      case PondTreatment.filtrationUnit:  return 'Filtration Unit';
    }
  }

  void _triggerResupply() {
    PondTreatment lowest = PondTreatment.hyacinths; int lowestCount = 99;
    treatmentUses.forEach((t, c) {
      if (c < lowestCount) { lowestCount = c; lowest = t; }
    });
    treatmentUses[lowest] = (treatmentUses[lowest] ?? 0) + 3;
    resupplyActive = true; resupplyTimer = _resupplyDisplay;
    resupplyTriggered++;
    overlays.add('treatResupply');
    notifyListeners();
  }

  void _handleScanStreak() {
    scanStreakTimer = _streakWindow;
    scanStreak++;
    if (scanStreak >= 3) {
      final bonus     = (scanStreak - 2) * 8;
      ecoPoints      += bonus;
      totalScanStreak += bonus;
      reactionMsg     = '🎯 Scan Streak x$scanStreak!  +$bonus bonus pts';
      _triggerReaction(true);
    }
  }

  void _spawnCriticalAlert() {
    final candidates = ponds.where((p) =>
        !p.isClean &&
        criticalAlerts.every((a) => a.pond != p)).toList();
    if (candidates.isEmpty) return;
    candidates.shuffle(math.Random());
    final p = candidates.first;
    p.isCritical = true;
    criticalAlerts.add(CriticalPondAlert(pond: p, timeLeft: 12.0));
    overlays.add('criticalAlert');
    HapticFeedback.heavyImpact();
    notifyListeners();
  }

  void _dismissCriticalAlert(PondTarget p, {bool saved = false}) {
    final alert = criticalAlerts.where((a) => a.pond == p).firstOrNull;
    if (alert == null) return;
    alert.handled = true;
    p.isCritical  = false;
    if (saved) { criticalSaves++; ecoPoints += 15; }
    criticalAlerts.removeWhere((a) => a.handled);
    if (criticalAlerts.isEmpty) overlays.remove('criticalAlert');
    notifyListeners();
  }

  void _expireCriticalAlert(CriticalPondAlert alert) {
    alert.handled          = true;
    alert.pond.isCritical  = false;
    waterPurity = math.max(0, waterPurity - 12.0);
    ecoPoints   = math.max(0, ecoPoints - 15);
    criticalAlerts.removeWhere((a) => a.handled);
    if (criticalAlerts.isEmpty) overlays.remove('criticalAlert');
    reactionMsg = '⛔ Pond collapsed!  -15 pts  💀';
    _triggerReaction(false);
    notifyListeners();
  }

  void _checkAlgaeSpread() {
    for (final p in List<PondTarget>.from(ponds)) {
      if (p.type != PondType.algaeBloom) continue;
      if (p.isClean) { _algaeIdleTimers.remove(p); continue; }
      _algaeIdleTimers[p] = (_algaeIdleTimers[p] ?? 0) + 1;
      if ((_algaeIdleTimers[p] ?? 0) >= _algaeSpreadAt) {
        _algaeIdleTimers.remove(p);
        _spawnChildPond(p);
      }
    }
  }

  void _spawnChildPond(PondTarget parent) {
    if (ponds.length >= 14) return;
    final rng = math.Random();
    final nx  = (parent.hx + (rng.nextDouble() * 90 - 45)).clamp(70.0, worldW - 70);
    final ny  = (parent.hy + (rng.nextDouble() * 90 - 45)).clamp(70.0, worldH - 70);
    final child = PondTarget(
      game: this, type: PondType.algaeBloom,
      worldX: nx, worldY: ny, seed: rng.nextInt(9999), isChildPond: true,
    );
    add(child); ponds.add(child);
    pondsSpread++;
    child.isScanned = true;
    waterPurity = math.max(0, waterPurity - 8.0);
    ecoPoints   = math.max(0, ecoPoints - 8);
    reactionMsg = '⚠️ Algae spread nearby!  -8 pts';
    _triggerReaction(false);
    notifyListeners();
  }

  void _triggerAcidRainWarning() {
    acidRainWarning  = true; _acidRainWarningCd = 3.2;
    overlays.add('acidRain'); notifyListeners();
  }

  void _triggerAcidRainActive() {
    acidRainWarning = false; acidRainActive = true;
    _acidRainActiveCd = 8.0; acidRainIntensity = 1.0;
    overlays.remove('acidRain');
    waterPurity = math.max(0, waterPurity - 10.0);
    notifyListeners();
  }

  void _endAcidRain() {
    acidRainActive = false; acidRainIntensity = 0;
    notifyListeners();
  }

  int _comboMult() {
    if (comboCount >= 4) return 3;
    if (comboCount >= 2) return 2;
    return 1;
  }

  void _incCombo() {
    comboCount++; comboTimer = _comboWindow;
    if (comboCount > maxCombo) maxCombo = comboCount;
    showComboFlash = true; comboFlashTimer = 1.8;
    notifyListeners();
  }

  void _breakCombo() { comboCount = 0; comboTimer = 0; }

  void _checkHints() {
    if (_hintCooldown > 0 || ecoGuideTimer > 0) return;
    if (_idleTimer > 4.0) {
      ecoGuideHint  = '🔬 Fly near a pond and hold SCAN. Read the analysis, then pick the correct treatment!';
      ecoGuideTimer = 3.5; _hintCooldown = 12; _idleTimer = 0;
    } else if (criticalAlerts.isNotEmpty && _idleTimer > 2.5) {
      ecoGuideHint  = '⚡ Critical pond alert! Scan and treat it before the timer expires — +15 bonus pts!';
      ecoGuideTimer = 3.5; _hintCooldown = 8;
    }
    notifyListeners();
  }

  void _endLevel() {
    if (levelDone) return;
    levelDone = true;
    pauseEngine();

    final meetsMin  = pondsFixed >= kMinPondsRequired;
    final allClean  = ponds.every((p) => p.isClean);

    final LevelCompletionState completionState;
    if (allClean) {
      completionState = LevelCompletionState.fullCompletion;
    } else if (meetsMin) {
      completionState = LevelCompletionState.moderate;
    } else {
      completionState = LevelCompletionState.failed;
    }

    String endReason = '';
    if (timeLeft <= 0) {
      if (allClean) {
        endReason = '🌍 All ponds cleaned — and just in time!';
      } else if (meetsMin) {
        endReason = '⏰ Time expired — minimum $kMinPondsRequired ponds met. Well done!';
      } else {
        endReason = '⏰ Time ran out before cleaning $kMinPondsRequired ponds. Keep practising!';
      }
    } else if (allClean) {
      endReason = '🌍 All ${ponds.length} ponds fully restored! Outstanding work!';
    } else {
      endReason = 'Level ended with $pondsFixed/$kMinPondsRequired ponds cleaned.';
    }

    PondCleaningResult.current = PondCleaningResult(
      pondsClean:          pondsFixed,
      correctTreatments:   correctTreatments,
      wrongTreatments:     wrongTreatments,
      ecoPoints:           ecoPoints,
      waterPurity:         waterPurity,
      maxCombo:            maxCombo,
      criticalSaves:         criticalSaves,
      pondsSpread:           pondsSpread,
      resupplyTriggered:   resupplyTriggered,
      meetsMinimum:          meetsMin,
      minimumPondsRequired:  kMinPondsRequired,
      endReason:             endReason,
      completionState:       completionState,
    );

    overlays
      ..remove('reactionFx')
      ..remove('scanResult')
      ..remove('treatmentSelect')
      ..remove('criticalAlert')
      ..remove('acidRain')
      ..remove('treatResupply')
      ..add('results');
    notifyListeners();
  }

  void setUpKey(bool v)    { isUp    = v; if (v) { gameStarted = true; _idleTimer = 0; } }
  void setDownKey(bool v)  { isDown  = v; if (v) { gameStarted = true; _idleTimer = 0; } }
  void setLeftKey(bool v)  { isLeft  = v; if (v) { gameStarted = true; _idleTimer = 0; } }
  void setRightKey(bool v) { isRight = v; if (v) { gameStarted = true; _idleTimer = 0; } }

  void _triggerReaction(bool correct, {bool inRange = true}) {
    reactionActive  = true; reactionCorrect = correct;
    reactionInRange = inRange;
    reactionTimer   = 1.3;
    overlays.add('reactionFx');
  }

  void _updateCamera(double dt) {
    final sw = size.x; final sh = size.y;
    final edgeW = sw * kEdgeFraction;
    final edgeH = sh * kEdgeFraction;
    final sx = dronePos.x - camX;
    final sy = dronePos.y - camY;
    double tx = _targetCamX; double ty = _targetCamY;

    if (sx < edgeW) {
      tx = dronePos.x - edgeW;
    } else if (sx > sw-edgeW) {tx = dronePos.x - (sw - edgeW);}
    if (sy < edgeH) {
      ty = dronePos.y - edgeH;
    } else if (sy > sh-edgeH) {ty = dronePos.y - (sh - edgeH);}

    _targetCamX = tx.clamp(0.0, worldW - sw);
    _targetCamY = ty.clamp(0.0, worldH - sh);
    camX += (_targetCamX - camX) * kCameraEase * dt;
    camY += (_targetCamY - camY) * kCameraEase * dt;

    edgeHintLeft   = (sx < edgeW*1.5 && camX > 1)
        ? (1.0 - sx/(edgeW*1.5)).clamp(0, 1) : 0;
    edgeHintRight  = (sx > sw-edgeW*1.5 && camX < worldW-sw-1)
        ? ((sx-(sw-edgeW*1.5))/(edgeW*1.5)).clamp(0, 1) : 0;
    edgeHintTop    = (sy < edgeH*1.5 && camY > 1)
        ? (1.0 - sy/(edgeH*1.5)).clamp(0, 1) : 0;
    edgeHintBottom = (sy > sh-edgeH*1.5 && camY < worldH-sh-1)
        ? ((sy-(sh-edgeH*1.5))/(edgeH*1.5)).clamp(0, 1) : 0;
  }

  @override
  void update(double dt) {
    super.update(dt);

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
    if (ecoGuideTimer > 0) {
      ecoGuideTimer -= dt;
      if (ecoGuideTimer <= 0) ecoGuideHint = '';
    }
    if (_hintCooldown > 0) _hintCooldown -= dt;
    if (scanResultActive) {
      scanResultTimer -= dt;
      if (scanResultTimer <= 0) dismissScanResult();
    }
    if (resupplyTimer > 0) {
      resupplyTimer -= dt;
      if (resupplyTimer <= 0) { resupplyActive = false; overlays.remove('treatResupply'); }
    }
    if (scanStreakTimer > 0) {
      scanStreakTimer -= dt;
      if (scanStreakTimer <= 0) scanStreak = 0;
    }

    if (!gameStarted || levelDone) { notifyListeners(); return; }

    double vx = 0, vy = 0;
    if (isLeft)  vx -= 1; if (isRight) vx += 1;
    if (isUp)    vy -= 1; if (isDown)  vy += 1;
    final moving = vx != 0 || vy != 0;
    if (!moving) {
      _idleTimer += dt;
    } else {
      _idleTimer = 0;
    }
    if (_idleTimer > 4.5) _checkHints();

    dronePos.x = (dronePos.x + vx * _droneSpeed * dt).clamp(30, worldW - 30);
    dronePos.y = (dronePos.y + vy * _droneSpeed * dt).clamp(40, worldH - 40);
    _updateCamera(dt);

    PondTarget? np; double npD = _scanRange;
    for (final p in ponds) {
      if (p.isScanned || p.isClean) continue;
      final d = (p.pondPos - dronePos).length;
      if (d < npD) { npD = d; np = p; }
    }
    _nearestScanPond = np;

    if (scanLockActive && activeScanPond != null) {
      final lockDist = (activeScanPond!.pondPos - dronePos).length;
      if (lockDist > _scanRange * 1.15) {
        scanLockActive = false; _scanLockTimer = 0; activeScanPond = null;
        reactionMsg = '🔬 Scan cancelled — too far!';
        _triggerReaction(false, inRange: false);
      } else {
        _scanLockTimer += dt;
        if (_scanLockTimer >= _scanDuration) _completePondScan(activeScanPond!);
      }
    }

    if (comboCount > 0) { comboTimer -= dt; if (comboTimer <= 0) _breakCombo(); }
    if (comboFlashTimer > 0) {
      comboFlashTimer -= dt;
      if (comboFlashTimer <= 0) showComboFlash = false;
    }

    _criticalAlertTimer -= dt;
    if (_criticalAlertTimer <= 0 && criticalAlerts.length < 2) {
      _criticalAlertTimer = 40.0 + math.Random().nextDouble() * 20;
      _spawnCriticalAlert();
    }
    for (final alert in List<CriticalPondAlert>.from(criticalAlerts)) {
      if (!alert.handled) {
        alert.timeLeft -= dt;
        if (alert.timeLeft <= 0) _expireCriticalAlert(alert);
      }
    }

    _algaeCheckTimer -= dt;
    if (_algaeCheckTimer <= 0) { _algaeCheckTimer = 1.0; _checkAlgaeSpread(); }

    _acidRainTimer -= dt;
    if (_acidRainTimer <= 0 && !acidRainWarning && !acidRainActive) {
      _acidRainTimer = 45.0 + math.Random().nextDouble() * 20;
      _triggerAcidRainWarning();
    }
    if (acidRainWarning) {
      _acidRainWarningCd -= dt;
      if (_acidRainWarningCd <= 0) { acidRainWarning = false; _triggerAcidRainActive(); }
    }
    if (acidRainActive) {
      _acidRainActiveCd -= dt;
      acidRainIntensity = (_acidRainActiveCd / 8.0).clamp(0.0, 1.0);
      if (_acidRainActiveCd <= 0) _endAcidRain();
    }

    _surgeTimer -= dt;
    if (_surgeTimer <= 0) {
      _surgeTimer  = 22.0 + math.Random().nextDouble() * 14;
      waterPurity  = math.max(0, waterPurity - 5.0);
      ecoPoints    = math.max(0, ecoPoints - 5);
      surgePending = true; surgePulse = 1.0;
    }

    notifyListeners();
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  WETLAND BACKGROUND RENDERER
// ══════════════════════════════════════════════════════════════════════════════
class WetlandRenderer extends Component {
  final PondCleaningGame game;
  double _t = 0;

  late final List<_Reed>     _reeds;
  late final List<_MudPatch>  _mud;
  late final List<_DecoPond> _decoPonds;

  WetlandRenderer({required this.game});

  @override
  void onLoad() { _init(); }

  void _init() {
    final w = game.worldW; final h = game.worldH;
    final rng = math.Random(55);

    _decoPonds = List.generate(6, (i) => _DecoPond(
      x: w * (0.12 + rng.nextDouble() * 0.76),
      y: h * (0.25 + rng.nextDouble() * 0.55),
      rw: 60 + rng.nextDouble() * 90,
      rh: 25 + rng.nextDouble() * 35,
      seed: i * 7,
    ));

    _reeds = List.generate(28, (i) => _Reed(
      x: rng.nextDouble() * w,
      y: h * 0.25 + rng.nextDouble() * h * 0.60,
      h: 14 + rng.nextDouble() * 22,
      seed: i * 13,
    ));

    _mud = List.generate(10, (i) => _MudPatch(
      x: rng.nextDouble() * w,
      y: h * 0.30 + rng.nextDouble() * h * 0.55,
      r: 18 + rng.nextDouble() * 38, seed: i * 19,
    ));
  }

  @override
  void update(double dt) => _t += dt * 0.22;

  @override
  void render(Canvas canvas) {
    final w = game.worldW; final h = game.worldH;
    final sw = game.size.x; final sh = game.size.y;
    canvas.save();
    canvas.translate(-game.camX, -game.camY);

    _drawSky(canvas, w, h);
    _drawGround(canvas, w, h);
    _drawDecoPonds(canvas, w, h);
    _drawMud(canvas, w, h);
    _drawReeds(canvas, w, h);
    _drawFooter(canvas, w, h);

    final purity = (game.waterPurity / 100.0).clamp(0.0, 1.0);
    if (purity > 0) {
      canvas.drawRect(Rect.fromLTWH(0, 0, w, h),
          Paint()..color = const Color(0xFF69F0AE).withValues(alpha: purity * 0.05)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 35));
    }

    if (game.acidRainIntensity > 0) _drawAcidRain(canvas, w, h);
    if (game.surgePulse > 0) {
      canvas.drawRect(Rect.fromLTWH(0, 0, w, h),
          Paint()..color = const Color(0xFF7B1FA2).withValues(alpha: game.surgePulse * 0.15));
    }

    canvas.restore();
    _drawEdgeHints(canvas, sw, sh);
  }

  void _drawEdgeHints(Canvas canvas, double sw, double sh) {
    const hintColor = Color(0xFF00897B);
    void drawV(double alpha, Alignment from, Alignment to) {
      if (alpha < 0.01) return;
      canvas.drawRect(Rect.fromLTWH(0, 0, sw, sh), Paint()
        ..shader = ui.Gradient.linear(
          Offset(sw*(from.x+1)/2, sh*(from.y+1)/2),
          Offset(sw*(to.x+1)/2,   sh*(to.y+1)/2),
          [hintColor.withValues(alpha: alpha*0.38), Colors.transparent]));
    }
    drawV(game.edgeHintLeft,   Alignment.centerLeft,   Alignment.center);
    drawV(game.edgeHintRight,  Alignment.centerRight,  Alignment.center);
    drawV(game.edgeHintTop,    Alignment.topCenter,    Alignment.center);
    drawV(game.edgeHintBottom, Alignment.bottomCenter, Alignment.center);
  }

  void _drawSky(Canvas canvas, double w, double h) {
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h * 0.22),
        Paint()..shader = ui.Gradient.linear(Offset.zero, Offset(0, h*0.22),
            [const Color(0xFF060C0A), const Color(0xFF0A1410)]));
  }

  void _drawGround(Canvas canvas, double w, double h) {
    canvas.drawRect(Rect.fromLTWH(0, h * 0.22, w, h * 0.64),
        Paint()..color = const Color(0xFF060A06));
    // Marshy tint
    canvas.drawRect(Rect.fromLTWH(0, h * 0.22, w, h * 0.64),
        Paint()..color = const Color(0xFF1B5E20).withValues(alpha: 0.04));
  }

  void _drawDecoPonds(Canvas canvas, double w, double h) {
    for (final dp in _decoPonds) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(dp.x, dp.y), width: dp.rw, height: dp.rh),
        Paint()..color = const Color(0xFF0A1A14).withValues(alpha: 0.55)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }
  }

  void _drawMud(Canvas canvas, double w, double h) {
    for (final m in _mud) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(m.x, m.y), width: m.r*2, height: m.r*0.7),
        Paint()..color = const Color(0xFF1C2814).withValues(alpha: 0.50)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }
  }

  void _drawReeds(Canvas canvas, double w, double h) {
    for (final r in _reeds) {
      final rng = math.Random(r.seed);
      final sway = math.sin(_t * 1.2 + r.seed) * 3.0;
      canvas.drawLine(
        Offset(r.x, r.y),
        Offset(r.x + sway, r.y - r.h),
        Paint()..color = const Color(0xFF1A2E18).withValues(alpha: 0.55)
          ..strokeWidth = 1.8 + rng.nextDouble()
          ..strokeCap = StrokeCap.round,
      );
      // Reed head
      canvas.drawCircle(Offset(r.x + sway, r.y - r.h), 2.2,
          Paint()..color = const Color(0xFF2E4A24).withValues(alpha: 0.45));
    }
  }

  void _drawFooter(Canvas canvas, double w, double h) {
    canvas.drawRect(Rect.fromLTWH(0, h*0.86, w, h*0.14),
        Paint()..color = const Color(0xFF040804));
    canvas.drawLine(Offset(0, h*0.86), Offset(w, h*0.86),
        Paint()..color = const Color(0xFF1A2E18).withValues(alpha: 0.50)..strokeWidth = 1.5);
  }

  void _drawAcidRain(Canvas canvas, double w, double h) {
    final alpha = game.acidRainIntensity * 0.52;
    final rng   = math.Random(77);
    final paint = Paint()
      ..color = const Color(0xFFCDDC39).withValues(alpha: alpha)
      ..strokeWidth = 0.9..strokeCap = StrokeCap.round;
    for (int i = 0; i < 80; i++) {
      final rx  = rng.nextDouble() * w;
      final ry  = rng.nextDouble() * h;
      final len = 8.0 + rng.nextDouble() * 16.0;
      final phase = ((_t*4.8 + rng.nextDouble()*5.0) % 1.0);
      final y   = (ry + phase * h * 0.55) % h;
      canvas.drawLine(Offset(rx - len*0.10, y), Offset(rx + len*0.10, y + len), paint);
    }
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h),
        Paint()..color = const Color(0xFF9E9D24).withValues(alpha: game.acidRainIntensity * 0.07));
  }
}

class _DecoPond { final double x, y, rw, rh; final int seed; const _DecoPond({required this.x, required this.y, required this.rw, required this.rh, required this.seed}); }
class _Reed     { final double x, y, h;       final int seed; const _Reed({required this.x, required this.y, required this.h, required this.seed}); }
class _MudPatch { final double x, y, r;       final int seed; const _MudPatch({required this.x, required this.y, required this.r, required this.seed}); }

// ══════════════════════════════════════════════════════════════════════════════
//  DRONE
// ══════════════════════════════════════════════════════════════════════════════
class PondDroneComponent extends Component {
  final PondCleaningGame game;
  double _t = 0;
  PondDroneComponent({required this.game});

  @override
  void update(double dt) => _t += dt;

  @override
  void render(Canvas canvas) {
    canvas.save();
    canvas.translate(-game.camX, -game.camY);
    _renderWorld(canvas);
    canvas.restore();
  }

  void _renderWorld(Canvas canvas) {
    final cx = game.dronePos.x;
    final cy = game.dronePos.y + math.sin(_t * 3.0) * 2.5;

    if (game.scanActive) {
      final alpha = (1.0 - game.scanRadius / PondCleaningGame._scanMaxRadius) * 0.30;
      canvas.drawCircle(Offset(cx, cy), game.scanRadius,
          Paint()..color = const Color(0xFF00897B).withValues(alpha: alpha)
            ..style = PaintingStyle.stroke..strokeWidth = 2.5);
    }

    final rangeColor = const Color(0xFF00897B);
    canvas.drawCircle(Offset(cx, cy), PondCleaningGame._scanRange,
        Paint()..color = rangeColor.withValues(alpha: 0.058)
          ..style = PaintingStyle.stroke..strokeWidth = 1.2);

    final progress = game.scanHoldProgress;
    if (progress > 0) {
      canvas.drawCircle(Offset(cx, cy), 14 + progress * 7,
          Paint()..color = const Color(0xFF00897B).withValues(alpha: progress * 0.28)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    }

    canvas.save();
    canvas.translate(cx, cy);

    canvas.drawOval(Rect.fromCenter(center: const Offset(0, 14), width: 38, height: 9),
        Paint()..color = Colors.black.withValues(alpha: 0.28));

    final armP = Paint()..color = const Color(0xFF1A2E18)..strokeWidth = 3.0..strokeCap = StrokeCap.round;
    for (final (dx, dy) in [(-1,-1),(1,-1),(-1,1),(1,1)]) {
      canvas.drawLine(Offset(dx*8.0, dy*8.0), Offset(dx*22.0, dy*22.0), armP);
    }

    final propPaint = Paint()
      ..color = const Color(0xFF69F0AE).withValues(alpha: 0.58)
      ..strokeWidth = 1.8..strokeCap = StrokeCap.round;
    for (final (px, py) in [(-22.0,-22.0),(22.0,-22.0),(-22.0,22.0),(22.0,22.0)]) {
      canvas.save(); canvas.translate(px, py); canvas.rotate(_t * 13);
      canvas.drawLine(const Offset(-8,0), const Offset(8,0), propPaint);
      canvas.drawLine(const Offset(0,-8), const Offset(0,8), propPaint);
      canvas.restore();
    }

    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(-13, -9, 26, 18), const Radius.circular(6)),
        Paint()..color = const Color(0xFF142810));

    final glowBright = progress > 0 ? 0.95 : 0.75 + math.sin(_t*4)*0.20;
    canvas.drawCircle(Offset.zero, 7,
        Paint()..color = const Color(0xFF00897B).withValues(alpha: glowBright)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    canvas.drawCircle(Offset.zero, 3.5, Paint()..color = Colors.white.withValues(alpha: 0.95));

    final tp = TextPainter(
      text: const TextSpan(text: '💧', style: TextStyle(fontSize: 8)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(-tp.width/2, 12 - tp.height/2));

    canvas.restore();
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  POND TARGET COMPONENT
// ══════════════════════════════════════════════════════════════════════════════
class PondTarget extends Component {
  final PondCleaningGame game;
  final PondType type;
  double hx, hy;
  final int  seed;
  final bool isChildPond;
  bool   isScanned      = false;
  bool   isClean        = false;
  bool   isCritical     = false;
  bool   triggerSparkle = false;
  double sparkleTimer   = 0;
  int    scanVariant    = 0;
  bool   hasDiscovery   = false;
  double _t             = 0;

  PondTarget({required this.game, required this.type,
      required double worldX, required double worldY,
      required this.seed, this.isChildPond = false})
      : hx = worldX, hy = worldY;

  Vector2 get pondPos => Vector2(hx, hy);
  void clean() => isClean = true;

  static const _specs = {
    PondType.algaeBloom:        ('🌿', 'Algae\nBloom',   Color(0xFF2E7D32), '💧Hyacinths'),
    PondType.organicWaste:      ('🦠', 'Organic\nWaste', Color(0xFF795548), '🧫Bacteria'),
    PondType.chemicalPollution: ('☠️', 'Chemical',       Color(0xFF7B1FA2), '🔧Filter'),
  };

  @override
  void update(double dt) {
    _t += dt;
    if (triggerSparkle) { sparkleTimer = 1.8; triggerSparkle = false; }
    if (sparkleTimer > 0) sparkleTimer = math.max(0, sparkleTimer - dt);
  }

  @override
  void render(Canvas canvas) {
    canvas.save();
    canvas.translate(-game.camX, -game.camY);
    if (isClean) {
      _drawClean(canvas);
    } else {
      _drawPolluted(canvas);
    }
    canvas.restore();
  }

  void _drawPolluted(Canvas canvas) {
    final spec  = _specs[type]!;
    final color = spec.$3;
    final pulse = 0.65 + math.sin(_t * 2.6) * 0.22;

    if (!isScanned) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(hx, hy), width: 68, height: 30),
        Paint()..color = const Color(0xFF1A2820).withValues(alpha: 0.40),
      );
      canvas.drawOval(
        Rect.fromCenter(center: Offset(hx, hy), width: 68, height: 30),
        Paint()..color = const Color(0xFF00897B).withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke..strokeWidth = 1.8,
      );
      final qp = TextPainter(
        text: const TextSpan(text: '?',
            style: TextStyle(color: Color(0xFF80CBC4), fontSize: 14, fontWeight: FontWeight.bold)),
        textDirection: TextDirection.ltr,
      )..layout();
      qp.paint(canvas, Offset(hx - qp.width/2, hy - qp.height/2 - 4));
      if (game.activeScanPond == this) _drawScanProgress(canvas, game.scanHoldProgress);
    } else {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(hx, hy), width: 68, height: 30),
        Paint()..color = color.withValues(alpha: 0.13 + pulse*0.05),
      );
      canvas.drawOval(
        Rect.fromCenter(center: Offset(hx, hy), width: 68, height: 30),
        Paint()..color = color.withValues(alpha: 0.62)
          ..style = PaintingStyle.stroke..strokeWidth = 2.0,
      );
      final ep = TextPainter(
        text: TextSpan(text: spec.$1, style: const TextStyle(fontSize: 15)),
        textDirection: TextDirection.ltr,
      )..layout();
      ep.paint(canvas, Offset(hx - ep.width/2, hy - ep.height/2 - 4));

      final lp = TextPainter(
        text: TextSpan(text: spec.$4,
            style: TextStyle(color: color, fontSize: 7.5, fontWeight: FontWeight.bold)),
        textDirection: TextDirection.ltr,
      )..layout();
      lp.paint(canvas, Offset(hx - lp.width/2, hy + 14));

      if (isChildPond) {
        final cp = TextPainter(
          text: const TextSpan(text: '⚠️ Spread',
              style: TextStyle(color: Color(0xFFFF6D00), fontSize: 8, fontWeight: FontWeight.bold)),
          textDirection: TextDirection.ltr,
        )..layout();
        cp.paint(canvas, Offset(hx - cp.width/2, hy - 44));
      }

      if (isCritical) {
        final urgency = math.sin(_t * 8).abs();
        final alert = game.criticalAlerts.firstWhere((a) => a.pond == this,
            orElse: () => CriticalPondAlert(pond: this, timeLeft: 0));
        canvas.drawCircle(Offset(hx, hy), 46 + urgency*10,
            Paint()..color = Colors.red.withValues(alpha: 0.20 + urgency*0.14)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
        canvas.drawCircle(Offset(hx, hy), 36,
            Paint()..color = Colors.red.withValues(alpha: 0.75)
              ..style = PaintingStyle.stroke..strokeWidth = 2.6);
        final tp = TextPainter(
          text: TextSpan(text: '⚡ ${alert.timeLeft.ceil()}s',
              style: const TextStyle(color: Colors.red, fontSize: 9.5, fontWeight: FontWeight.w900)),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(hx - tp.width/2, hy - 56));
      }
    }
  }

  void _drawClean(Canvas canvas) {
    if (sparkleTimer > 0) {
      for (int i = 0; i < 12; i++) {
        final angle = (i/12)*math.pi*2;
        final r = sparkleTimer/1.8 * 55;
        canvas.drawCircle(
          Offset(hx + math.cos(angle)*r, hy + math.sin(angle)*r), 2.5,
          Paint()..color = const Color(0xFF69F0AE)
              .withValues(alpha: (sparkleTimer/1.8).clamp(0,1)),
        );
      }
    }
    canvas.drawOval(Rect.fromCenter(center: Offset(hx, hy), width: 68, height: 30),
        Paint()..color = const Color(0xFF00897B).withValues(alpha: 0.22));
    canvas.drawOval(Rect.fromCenter(center: Offset(hx, hy), width: 68, height: 30),
        Paint()..color = const Color(0xFF69F0AE).withValues(alpha: 0.60)
          ..style = PaintingStyle.stroke..strokeWidth = 2.0);
    for (int i = 0; i < 6; i++) {
      final angle = (i/6)*math.pi*2;
      canvas.drawLine(
        Offset(hx + math.cos(angle)*16, hy + math.sin(angle)*7 + 6),
        Offset(hx + math.cos(angle)*16, hy + math.sin(angle)*7),
        Paint()..color = const Color(0xFF4CAF50).withValues(alpha: 0.65)
          ..strokeWidth = 2.0..strokeCap = StrokeCap.round);
    }
    final tp = TextPainter(
      text: const TextSpan(text: '💧', style: TextStyle(fontSize: 15)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(hx - tp.width/2, hy - tp.height/2 - 4));
  }

  void _drawScanProgress(Canvas canvas, double progress) {
    const start = -math.pi / 2;
    const full  = math.pi * 2;
    final beam  = start + full * progress;
    canvas.drawArc(
      Rect.fromCenter(center: Offset(hx, hy), width: 88, height: 40),
      beam - 0.5, 0.5, false,
      Paint()..color = const Color(0xFF00897B).withValues(alpha: 0.18)
        ..style = PaintingStyle.stroke..strokeWidth = 9.0);
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCenter(center: Offset(hx, hy), width: 88, height: 40),
        start, full * progress, false,
        Paint()..color = const Color(0xFF00897B).withValues(alpha: 0.90)
          ..style = PaintingStyle.stroke..strokeWidth = 3.5..strokeCap = StrokeCap.round);
    }
    final pct = (progress * 100).toInt();
    final pctP = TextPainter(
      text: TextSpan(text: '$pct%',
          style: const TextStyle(color: Color(0xFF69F0AE), fontSize: 9, fontWeight: FontWeight.bold)),
      textDirection: TextDirection.ltr,
    )..layout();
    pctP.paint(canvas, Offset(hx - pctP.width/2, hy - 38));
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  HUD
// ══════════════════════════════════════════════════════════════════════════════
class PondHud extends StatelessWidget {
  final PondCleaningGame game;
  const PondHud(this.game, {super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: game,
      builder: (_, __) {
        final warn        = game.timeLeft < 20;
        final purityRatio = (game.waterPurity / 100.0).clamp(0.0, 1.0);
        final purityColor = game.waterPurity >= 80
            ? const Color(0xFF69F0AE)
            : game.waterPurity >= 50 ? const Color(0xFF00897B) : const Color(0xFFEF5350);

        return SafeArea(child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch, children: [

            Align(alignment: Alignment.topCenter, child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF00897B).withValues(alpha: 0.90),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(
                    color: const Color(0xFF00897B).withValues(alpha: 0.35), blurRadius: 10)],
              ),
              child: const Text(
                '💧  WATER PURIFICATION',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900,
                    fontSize: 12, letterSpacing: 1.1),
              ),
            )),
            const SizedBox(height: 8),

            Row(children: [
              _PTile(Icons.timer_rounded, '${game.timeLeft.toInt()}s', 'TIME',
                  warn ? Colors.red : Colors.white),
              const SizedBox(width: 5),
              _PTile(Icons.radar_rounded,
                  '${game.ponds.where((p) => p.isScanned).length}/${PondCleaningGame.totalPonds}',
                  'SCANNED', const Color(0xFFFFB300)),
              const SizedBox(width: 5),
              _PTile(Icons.check_circle_rounded,
                  '${game.pondsFixed}/${PondCleaningGame.kMinPondsRequired}+',
                  'CLEANED',
                  game.pondsFixed >= PondCleaningGame.kMinPondsRequired
                      ? const Color(0xFF69F0AE) : Colors.white70),
              const SizedBox(width: 5),
              _PTile(Icons.eco_rounded, '${game.ecoPoints}', 'ECO-PTS', Colors.limeAccent),
            ]),
            const SizedBox(height: 5),

            if (game.scanLockActive) ...[
              Row(children: [
                const Text('🔬', style: TextStyle(fontSize: 12)),
                const SizedBox(width: 5),
                Expanded(child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: game.scanHoldProgress,
                    backgroundColor: Colors.white12,
                    valueColor: const AlwaysStoppedAnimation(Color(0xFF00897B)),
                    minHeight: 7,
                  ),
                )),
                const SizedBox(width: 6),
                const Text('Analysing…', style: TextStyle(
                    color: Color(0xFF00897B), fontSize: 9, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 4),
            ],

            if (!game.scanLockActive && game._nearestScanPond != null &&
                !game.treatmentSelectorOpen && !game.scanResultActive) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF00897B).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF00897B).withValues(alpha: 0.35)),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('🔬', style: TextStyle(fontSize: 10)),
                  SizedBox(width: 5),
                  Text('Polluted pond nearby — hold SCAN!',
                      style: TextStyle(color: Color(0xFF00897B), fontSize: 9, fontWeight: FontWeight.w700)),
                ]),
              ),
            ],

            if (game.scanStreak >= 2)
              Align(alignment: Alignment.centerRight,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE040FB).withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE040FB).withValues(alpha: 0.55)),
                  ),
                  child: Text('🎯 Streak x${game.scanStreak}!',
                      style: const TextStyle(color: Color(0xFFE040FB),
                          fontSize: 9, fontWeight: FontWeight.w900)),
                ),
              ),

            Row(children: [
              const Text('💧', style: TextStyle(fontSize: 13)),
              const SizedBox(width: 5),
              Expanded(child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: purityRatio,
                  backgroundColor: Colors.white12,
                  valueColor: AlwaysStoppedAnimation(purityColor),
                  minHeight: 7,
                ),
              )),
              const SizedBox(width: 6),
              RichText(text: TextSpan(children: [
                TextSpan(text: '${game.waterPurity.toStringAsFixed(0)}%',
                    style: TextStyle(color: purityColor, fontSize: 10, fontWeight: FontWeight.bold)),
                const TextSpan(text: ' / 100%',
                    style: TextStyle(color: Color(0xFF69F0AE), fontSize: 8)),
              ])),
            ]),
            const SizedBox(height: 4),

            if (game.criticalAlerts.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.60)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Text('⚡', style: TextStyle(fontSize: 10)),
                  const SizedBox(width: 5),
                  Text(
                    '${game.criticalAlerts.length} CRITICAL POND${game.criticalAlerts.length > 1 ? "S" : ""}!  Treat before collapse!',
                    style: const TextStyle(color: Colors.red, fontSize: 8.5, fontWeight: FontWeight.w900),
                  ),
                ]),
              ),

            if (game.comboCount > 0)
              Align(alignment: Alignment.centerRight,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6D00).withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFF6D00).withValues(alpha: 0.60)),
                  ),
                  child: Text(
                    '🔥 ${game.comboCount}× Combo  (${game.comboTimer.toStringAsFixed(1)}s)',
                    style: const TextStyle(color: Color(0xFFFF6D00),
                        fontSize: 9, fontWeight: FontWeight.w900),
                  ),
                ),
              ),

            if (game.ecoGuideHint.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 5),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(children: [
                  const Text('🌍', style: TextStyle(fontSize: 12)),
                  const SizedBox(width: 6),
                  Expanded(child: Text(game.ecoGuideHint,
                      style: const TextStyle(color: Colors.white70, fontSize: 9.5))),
                ]),
              ),
          ]),
        ));
      },
    );
  }
}

class _PTile extends StatelessWidget {
  final IconData icon;
  final String val, label;
  final Color color;
  const _PTile(this.icon, this.val, this.label, this.color);

  @override
  Widget build(BuildContext context) => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
    decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white12)),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: color, size: 13),
      Text(val, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
      Text(label, style: const TextStyle(color: Colors.white54, fontSize: 7, letterSpacing: 0.7)),
    ]),
  ));
}

// ══════════════════════════════════════════════════════════════════════════════
//  CONTROLS
// ══════════════════════════════════════════════════════════════════════════════
class PondControls extends StatefulWidget {
  final PondCleaningGame game;
  const PondControls(this.game, {super.key});
  @override
  State<PondControls> createState() => _PondControlsState();
}

class _PondControlsState extends State<PondControls> {
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
      widget.game.triggerScan();
    }
    if (pressed) {
      if (k == LogicalKeyboardKey.digit1) widget.game.selectTreatment(PondTreatment.hyacinths);
      if (k == LogicalKeyboardKey.digit2) widget.game.selectTreatment(PondTreatment.bacteriaPellets);
      if (k == LogicalKeyboardKey.digit3) widget.game.selectTreatment(PondTreatment.filtrationUnit);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.game,
      builder: (_, __) {
        final scanning = widget.game.scanLockActive;
        final canScan  = widget.game._hasNearbyUnscannedPond;
        const actColor = Color(0xFF00897B);

        return KeyboardListener(
          focusNode: _fk,
          onKeyEvent: _onKey,
          child: Stack(children: [
            Align(alignment: Alignment.bottomLeft, child: SafeArea(child: Padding(
              padding: const EdgeInsets.only(bottom: 16, left: 12),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                _PDPad('⬆', _up, Colors.cyanAccent,
                    onDown: () { setState(() => _up = true);  widget.game.setUpKey(true); },
                    onUp:   () { setState(() => _up = false); widget.game.setUpKey(false); }),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  _PDPad('◀', _lt, Colors.cyanAccent,
                      onDown: () { setState(() => _lt = true);  widget.game.setLeftKey(true); },
                      onUp:   () { setState(() => _lt = false); widget.game.setLeftKey(false); }),
                  const SizedBox(width: 4),
                  _PDPad('⬇', _dn, Colors.cyanAccent,
                      onDown: () { setState(() => _dn = true);  widget.game.setDownKey(true); },
                      onUp:   () { setState(() => _dn = false); widget.game.setDownKey(false); }),
                  const SizedBox(width: 4),
                  _PDPad('▶', _rt, Colors.cyanAccent,
                      onDown: () { setState(() => _rt = true);  widget.game.setRightKey(true); },
                      onUp:   () { setState(() => _rt = false); widget.game.setRightKey(false); }),
                ]),
              ]),
            ))),

            // Right-side treatment panel
            Align(alignment: Alignment.centerRight,
              child: SafeArea(child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _PondTreatmentSidePanel(game: widget.game),
              )),
            ),

            // Scan action button (bottom-right)
            Align(alignment: Alignment.bottomRight, child: SafeArea(child: Padding(
              padding: const EdgeInsets.only(bottom: 20, right: 14),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                if (scanning)
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.70),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: actColor.withValues(alpha: 0.42)),
                    ),
                    child: Text(
                      '🔬 Scanning pond — stay in range!',
                      style: TextStyle(color: actColor, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ),
                GestureDetector(
                  onTap: () => widget.game.triggerScan(),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    width: 70, height: 70,
                    decoration: BoxDecoration(
                      color: canScan ? actColor.withValues(alpha: 0.22)
                                     : Colors.black.withValues(alpha: 0.60),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: canScan ? actColor : Colors.white24,
                          width: canScan ? 2.5 : 1.5),
                      boxShadow: canScan
                          ? [BoxShadow(color: actColor.withValues(alpha: 0.42), blurRadius: 16)]
                          : [],
                    ),
                    child: Center(child: Text(
                      scanning ? '🔬\nANA\nLYSE' : '🔬\nSCAN',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: canScan ? actColor : Colors.white30,
                          fontWeight: FontWeight.w900, fontSize: 8, letterSpacing: 0.3, height: 1.3),
                    )),
                  ),
                ),
              ]),
            ))),
          ]),
        );
      },
    );
  }
}

class _PDPad extends StatelessWidget {
  final String label; final bool isActive; final Color color;
  final VoidCallback onDown, onUp;
  const _PDPad(this.label, this.isActive, this.color, {required this.onDown, required this.onUp});

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (_) => onDown(), onPointerUp: (_) => onUp(), onPointerCancel: (_) => onUp(),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 70),
      width: 52, height: 52, margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: isActive ? color.withValues(alpha: 0.30) : Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isActive ? color : Colors.white24, width: 1.8),
        boxShadow: isActive ? [BoxShadow(color: color.withValues(alpha: 0.40), blurRadius: 10)] : [],
      ),
      child: Center(child: Text(label, style: TextStyle(
          color: isActive ? color : Colors.white60, fontSize: 16, fontWeight: FontWeight.bold))),
    ),
  );
}

// ── Right-side treatment panel ────────────────────────────────────────────────
class _PondTreatmentSidePanel extends StatelessWidget {
  final PondCleaningGame game;
  const _PondTreatmentSidePanel({required this.game});

  static const _treatments = [
    (PondTreatment.hyacinths,       '🌿', 'Hyacinths',  'Algae Bloom',        Color(0xFF2E7D32)),
    (PondTreatment.bacteriaPellets, '🧫', 'Bacteria',   'Organic Waste',      Color(0xFF795548)),
    (PondTreatment.filtrationUnit,  '🔧', 'Filtration', 'Chemical Pollution', Color(0xFF7B1FA2)),
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: game,
      builder: (_, __) {
        final target = game.pendingTreatTarget;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: _treatments.map((spec) {
            final (tr, emoji, label, hint, color) = spec;
            final uses    = game.treatmentUses[tr] ?? 0;
            final isEmpty = uses == 0;
            final selected = game.selectedTreatment == tr;
            final correct  = target != null && game._isCorrectTreatment(target.type, tr);

            final borderColor = isEmpty ? Colors.white12
                : selected ? color
                : correct  ? color.withValues(alpha: 0.60)
                : Colors.white.withValues(alpha: 0.12);
            final bgColor = isEmpty ? Colors.black.withValues(alpha: 0.55)
                : selected ? color.withValues(alpha: 0.25)
                : correct  ? color.withValues(alpha: 0.10)
                : Colors.black.withValues(alpha: 0.62);

            return GestureDetector(
              onTap: isEmpty ? null : () {
                HapticFeedback.selectionClick();
                game.selectTreatment(tr);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                margin: const EdgeInsets.only(bottom: 5),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                constraints: const BoxConstraints(minWidth: 118, maxWidth: 138),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: borderColor, width: (selected||correct) ? 1.8 : 1.1),
                  boxShadow: selected
                      ? [BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 10)]
                      : correct && !isEmpty
                          ? [BoxShadow(color: color.withValues(alpha: 0.20), blurRadius: 6)]
                          : [],
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(shape: BoxShape.circle,
                        color: isEmpty ? Colors.white.withValues(alpha: 0.04) : color.withValues(alpha: 0.18),
                        border: Border.all(color: isEmpty ? Colors.white12 : color.withValues(alpha: 0.45))),
                    child: Center(child: Text(emoji, style: const TextStyle(fontSize: 13))),
                  ),
                  const SizedBox(width: 6),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min, children: [
                    Text(label, style: TextStyle(
                        color: isEmpty ? Colors.white24 : selected ? color : Colors.white,
                        fontWeight: FontWeight.w800, fontSize: 10.5)),
                    Text(hint, style: TextStyle(
                        color: isEmpty ? Colors.white12 : color.withValues(alpha: 0.68), fontSize: 8)),
                  ])),
                  const SizedBox(width: 5),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: isEmpty ? Colors.redAccent.withValues(alpha: 0.14) : color.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                            color: isEmpty ? Colors.redAccent.withValues(alpha: 0.42) : color.withValues(alpha: 0.38)),
                      ),
                      child: Text(isEmpty ? 'OUT' : '×$uses',
                          style: TextStyle(color: isEmpty ? Colors.redAccent : color,
                              fontSize: 7.5, fontWeight: FontWeight.bold)),
                    ),
                    if (correct && !isEmpty) ...[
                      const SizedBox(height: 2),
                      Text('✓', style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
                    ],
                  ]),
                ]),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  PHASE BANNER
// ══════════════════════════════════════════════════════════════════════════════
class PondBanner extends StatelessWidget {
  final PondCleaningGame game;
  const PondBanner(this.game, {super.key});

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF00897B);
    return IgnorePointer(child: Center(child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF001A14), Color(0xFF003028)]),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 24)],
        border: Border.all(color: accent.withValues(alpha: 0.55), width: 1.5),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('PHASE 2',
            style: TextStyle(color: Colors.white54, fontSize: 13, letterSpacing: 2.5)),
        const SizedBox(height: 4),
        const Text('💧  Water Purification',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22)),
        const SizedBox(height: 6),
        Text(
          'Fly near a polluted pond then hold 🔬 SCAN.\n'
          'Read the analysis, then tap TREAT IT!\n'
          'Watch for critical alerts and algae spread!\n'
          '8 ponds to restore — keep water purity high!',
          textAlign: TextAlign.center,
          style: TextStyle(color: accent.withValues(alpha: 0.85), fontSize: 11.5),
        ),
      ]),
    )));
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  SCAN RESULT OVERLAY
// ══════════════════════════════════════════════════════════════════════════════
class PondScanResultOverlay extends StatefulWidget {
  final PondCleaningGame game;
  const PondScanResultOverlay(this.game, {super.key});
  @override
  State<PondScanResultOverlay> createState() => _PondScanResultOverlayState();
}

class _PondScanResultOverlayState extends State<PondScanResultOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _scale;

  @override
  void initState() {
    super.initState();
    _ctrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 340))..forward();
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.game,
      builder: (_, __) {
        final result = widget.game.lastScanResult;
        if (result == null) return const SizedBox.shrink();

        final displayDuration = result.hasEcoDiscovery ? 5.5 : 4.0;
        final progress = (widget.game.scanResultTimer / displayDuration).clamp(0.0, 1.0);
        final pts      = widget.game.lastScanPoints;

        return Center(
          child: ScaleTransition(
            scale: _scale,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 18),
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
              constraints: const BoxConstraints(maxWidth: 340),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xFF0A0A14), result.color.withValues(alpha: 0.12)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: result.color.withValues(alpha: 0.70), width: 2.0),
                boxShadow: [
                  BoxShadow(color: result.color.withValues(alpha: 0.28), blurRadius: 28),
                  const BoxShadow(color: Colors.black54, blurRadius: 18),
                ],
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [

                Row(children: [
                  SizedBox(width: 22, height: 22,
                    child: CustomPaint(painter: _ArcCountdownPainter(progress, result.color)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(
                    'POND ANALYSED',
                    style: const TextStyle(color: Colors.white54, fontSize: 9,
                        fontWeight: FontWeight.w900, letterSpacing: 1.8),
                  )),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFB300).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFFFB300).withValues(alpha: 0.42)),
                    ),
                    child: Text('+$pts pts${pts >= 30 ? " 🌟" : ""}',
                        style: const TextStyle(color: Color(0xFFFFB300),
                            fontSize: 9, fontWeight: FontWeight.bold)),
                  ),
                ]),
                const SizedBox(height: 12),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: result.color.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: result.color.withValues(alpha: 0.55), width: 1.8),
                    boxShadow: [BoxShadow(color: result.color.withValues(alpha: 0.18), blurRadius: 10)],
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Text(result.icon, style: const TextStyle(fontSize: 28)),
                      const SizedBox(width: 10),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('ISSUE IDENTIFIED',
                            style: TextStyle(color: result.color.withValues(alpha: 0.75),
                                fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                        const SizedBox(height: 2),
                        Text(result.typeName,
                            style: TextStyle(color: result.color, fontSize: 16,
                                fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                      ])),
                    ]),
                    const SizedBox(height: 8),
                    Text(result.ecoFact,
                        style: const TextStyle(color: Colors.white70, fontSize: 10, height: 1.5)),
                  ]),
                ),
                const SizedBox(height: 10),

                widget.game.scanResultShowsHints
                    ? Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('RECOMMENDED ACTION',
                              style: TextStyle(color: Colors.white38, fontSize: 7.5,
                                  fontWeight: FontWeight.w900, letterSpacing: 1.3)),
                          const SizedBox(height: 6),
                          Row(children: [
                            Container(width: 16, height: 16, alignment: Alignment.center,
                              decoration: BoxDecoration(color: result.color.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: result.color.withValues(alpha: 0.50))),
                              child: Text('✓', style: TextStyle(color: result.color,
                                  fontSize: 8, fontWeight: FontWeight.bold))),
                            const SizedBox(width: 6),
                            Expanded(child: Text(result.correctAction,
                                style: const TextStyle(color: Colors.white70, fontSize: 9.5, height: 1.3))),
                          ]),
                        ]),
                      )
                    : Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF69F0AE).withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF69F0AE).withValues(alpha: 0.35)),
                        ),
                        child: const Column(mainAxisSize: MainAxisSize.min, children: [
                          Text('🧠 YOU KNOW THIS ONE',
                              style: TextStyle(color: Color(0xFF69F0AE), fontSize: 9.5,
                                  fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                          SizedBox(height: 5),
                          Text('You\'ve handled this type before.\nApply the correct treatment from memory!',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white54, fontSize: 9.5, height: 1.4)),
                        ]),
                      ),
                const SizedBox(height: 10),

                if (result.hasEcoDiscovery) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE040FB).withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE040FB).withValues(alpha: 0.40)),
                    ),
                    child: Text(result.discoveryFact,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xFFE040FB), fontSize: 10, height: 1.5)),
                  ),
                  const SizedBox(height: 10),
                ],

                GestureDetector(
                  onTap: () => widget.game.openTreatmentSelectorForPending(),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: result.color.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: result.color, width: 2.0),
                      boxShadow: [BoxShadow(color: result.color.withValues(alpha: 0.38), blurRadius: 14)],
                    ),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(result.icon, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      Text('TREAT IT  →  SELECT TREATMENT',
                          style: TextStyle(color: result.color, fontSize: 13,
                              fontWeight: FontWeight.w900, letterSpacing: 0.8)),
                    ]),
                  ),
                ),
                const SizedBox(height: 6),
                const Text('or wait — auto-opens in a moment',
                    style: TextStyle(color: Colors.white24, fontSize: 8),
                    textAlign: TextAlign.center),
              ]),
            ),
          ),
        );
      },
    );
  }
}

class _ArcCountdownPainter extends CustomPainter {
  final double progress;
  final Color  color;
  const _ArcCountdownPainter(this.progress, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width/2; final cy = size.height/2;
    final r  = math.min(cx, cy) - 1.5;
    canvas.drawCircle(Offset(cx, cy), r,
        Paint()..color = Colors.white12..style = PaintingStyle.stroke..strokeWidth = 2.0);
    canvas.drawArc(Rect.fromCenter(center: Offset(cx, cy), width: r*2, height: r*2),
        -math.pi/2, math.pi*2*progress, false,
        Paint()..color = color.withValues(alpha: 0.80)
          ..style = PaintingStyle.stroke..strokeWidth = 2.5..strokeCap = StrokeCap.round);
  }
  @override bool shouldRepaint(_ArcCountdownPainter old) => old.progress != progress;
}

// ══════════════════════════════════════════════════════════════════════════════
//  POND TREATMENT SELECTOR
// ══════════════════════════════════════════════════════════════════════════════
class PondTreatmentSelector extends StatelessWidget {
  final PondCleaningGame game;
  const PondTreatmentSelector(this.game, {super.key});

  static const _treatments = [
    (PondTreatment.hyacinths,       '🌿', 'Water\nHyacinths',  'Algae Bloom',        Color(0xFF2E7D32)),
    (PondTreatment.bacteriaPellets, '🧫', 'Bacteria\nPellets', 'Organic Waste',      Color(0xFF795548)),
    (PondTreatment.filtrationUnit,  '🔧', 'Filtration\nUnit',  'Chemical Pollution', Color(0xFF7B1FA2)),
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: game,
      builder: (_, __) {
        final target = game.pendingTreatTarget;
        if (target == null || !game.treatmentSelectorOpen) return const SizedBox.shrink();

        final showHints = game.treatmentShowsHints;
        final (typeIcon, typeName, accent) = _pondMeta(target.type);

        return Container(
          color: Colors.black.withValues(alpha: 0.62),
          child: Center(child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF080E06),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: accent.withValues(alpha: 0.55), width: 1.5),
              boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 20)],
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Text(typeIcon, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(typeName, style: const TextStyle(color: Colors.white,
                      fontWeight: FontWeight.bold, fontSize: 16)),
                  Text('Select the correct water treatment:',
                      style: TextStyle(color: accent, fontSize: 10, fontWeight: FontWeight.w700)),
                ])),
                GestureDetector(
                  onTap: game.cancelTreatmentSelector,
                  child: Container(width: 32, height: 32,
                      decoration: BoxDecoration(shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.08),
                          border: Border.all(color: Colors.white24)),
                      child: const Center(child: Text('✕',
                          style: TextStyle(color: Colors.white60, fontSize: 14)))),
                ),
              ]),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: accent.withValues(alpha: 0.35)),
                ),
                child: showHints
                    ? Text('Pond: $typeName',
                        style: TextStyle(color: accent, fontSize: 9.5, fontWeight: FontWeight.w700))
                    : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Text('🧠', style: TextStyle(fontSize: 11)),
                        const SizedBox(width: 5),
                        Text('Recall from memory — no hints this time!',
                            style: TextStyle(color: accent, fontSize: 9.5, fontWeight: FontWeight.w700)),
                      ]),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8, runSpacing: 8,
                alignment: WrapAlignment.center,
                children: _treatments.map((spec) {
                  final (tr, emoji, label, hint, color) = spec;
                  final uses    = game.treatmentUses[tr] ?? 0;
                  final isEmpty = uses == 0;
                  final correct = showHints && game._isCorrectTreatment(target.type, tr);

                  return GestureDetector(
                    onTap: isEmpty ? null : () {
                      HapticFeedback.selectionClick();
                      game.selectTreatment(tr);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 130),
                      width: 112,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                      decoration: BoxDecoration(
                        color: isEmpty ? Colors.black.withValues(alpha: 0.55)
                            : correct ? color.withValues(alpha: 0.22)
                            : Colors.black.withValues(alpha: 0.62),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isEmpty ? Colors.white12
                              : correct ? color.withValues(alpha: 0.85)
                              : Colors.white.withValues(alpha: 0.18),
                          width: correct ? 2.0 : 1.2,
                        ),
                        boxShadow: correct && !isEmpty
                            ? [BoxShadow(color: color.withValues(alpha: 0.32), blurRadius: 12)]
                            : [],
                      ),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(emoji, style: TextStyle(fontSize: 22,
                            color: isEmpty ? const Color(0xFF444444) : null)),
                        const SizedBox(height: 4),
                        Text(label, textAlign: TextAlign.center,
                            style: TextStyle(
                                color: isEmpty ? Colors.white24 : correct ? color : Colors.white70,
                                fontWeight: FontWeight.w800, fontSize: 10.5)),
                        showHints
                            ? Text(hint, textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: isEmpty ? Colors.white12 : color.withValues(alpha: 0.68),
                                    fontSize: 8))
                            : const Text('— recall from memory —', textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white24, fontSize: 7.5)),
                        const SizedBox(height: 3),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: isEmpty ? Colors.redAccent.withValues(alpha: 0.14) : color.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(isEmpty ? 'OUT' : '×$uses',
                              style: TextStyle(
                                  color: isEmpty ? Colors.redAccent : color,
                                  fontSize: 7.5, fontWeight: FontWeight.bold)),
                        ),
                      ]),
                    ),
                  );
                }).toList(),
              ),
            ]),
          )),
        );
      },
    );
  }

  (String, String, Color) _pondMeta(PondType t) {
    switch (t) {
      case PondType.algaeBloom:        return ('🌿', 'Algae Bloom',         const Color(0xFF2E7D32));
      case PondType.organicWaste:      return ('🦠', 'Organic Waste Pond',  const Color(0xFF795548));
      case PondType.chemicalPollution: return ('☠️', 'Chemical Pollution',  const Color(0xFF7B1FA2));
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  REACTION FLASH
// ══════════════════════════════════════════════════════════════════════════════
class PondReactionFx extends StatelessWidget {
  final PondCleaningGame game;
  const PondReactionFx(this.game, {super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: game,
      builder: (_, __) {
        final ok      = game.reactionCorrect;
        final inRange = game.reactionInRange;
        final msg     = game.reactionMsg.isNotEmpty
            ? game.reactionMsg
            : (!inRange ? '🛰️  Out of range — fly closer'
                : ok ? '✅  Done!' : '❌  Wrong approach');
        final accent  = (ok && inRange)
            ? const Color(0xFF69F0AE) : const Color(0xFFEF5350);

        return IgnorePointer(child: Stack(children: [
          Container(decoration: BoxDecoration(
            border: Border.all(color: accent, width: 8),
            gradient: RadialGradient(
                colors: [Colors.transparent, accent.withValues(alpha: 0.12)], radius: 1.5),
          )),
          Center(child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 11),
            decoration: BoxDecoration(
              color: ok ? const Color(0xFF0A2A10).withValues(alpha: 0.94)
                        : const Color(0xFF2A0A0A).withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 14, spreadRadius: 2)],
            ),
            child: Text(msg, textAlign: TextAlign.center,
                style: TextStyle(color: accent, fontWeight: FontWeight.bold,
                    fontSize: 15, letterSpacing: 0.5)),
          )),
          if (game.showComboFlash && game.comboCount >= 2)
            Positioned(
              top: MediaQuery.of(context).size.height * 0.30,
              left: 0, right: 0,
              child: Center(child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6D00).withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: const Color(0xFFFF6D00).withValues(alpha: 0.42), blurRadius: 18)],
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
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  CRITICAL POND ALERT OVERLAY
// ══════════════════════════════════════════════════════════════════════════════
class CriticalPondAlertOverlay extends StatelessWidget {
  final PondCleaningGame game;
  const CriticalPondAlertOverlay(this.game, {super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: game,
      builder: (_, __) {
        if (game.criticalAlerts.isEmpty) return const SizedBox.shrink();
        final alert = game.criticalAlerts.first;

        return IgnorePointer(child: Align(
          alignment: Alignment.topCenter,
          child: SafeArea(child: Container(
            margin: const EdgeInsets.only(top: 55),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1A0000).withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.withValues(alpha: 0.75), width: 1.5),
              boxShadow: [BoxShadow(color: Colors.red.withValues(alpha: 0.28), blurRadius: 22)],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Text('⚡', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Column(mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('CRITICAL POND — TREAT NOW!',
                    style: TextStyle(color: Colors.red, fontSize: 10,
                        fontWeight: FontWeight.w900, letterSpacing: 1.3)),
                const SizedBox(height: 2),
                const Text(
                  'A pond is on the verge of collapse.\nTreat it to save +15 pts — or lose -15!',
                  style: TextStyle(color: Colors.white60, fontSize: 9.5),
                ),
              ]),
              const SizedBox(width: 10),
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.red.withValues(alpha: 0.14),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.55))),
                child: Center(child: Text('${alert.timeLeft.ceil()}',
                    style: const TextStyle(color: Colors.red,
                        fontWeight: FontWeight.bold, fontSize: 16))),
              ),
            ]),
          )),
        ));
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  ACID RAIN ALERT OVERLAY
// ══════════════════════════════════════════════════════════════════════════════
class AcidRainAlertOverlay extends StatelessWidget {
  final PondCleaningGame game;
  const AcidRainAlertOverlay(this.game, {super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: game,
      builder: (_, __) {
        if (!game.acidRainWarning) return const SizedBox.shrink();

        return IgnorePointer(child: Align(
          alignment: Alignment.topCenter,
          child: SafeArea(child: Container(
            margin: const EdgeInsets.only(top: 55),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A00).withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFCDDC39).withValues(alpha: 0.75), width: 1.5),
              boxShadow: [BoxShadow(
                  color: const Color(0xFFCDDC39).withValues(alpha: 0.22), blurRadius: 20)],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Text('🌧️', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Column(mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('ACID RAIN INCOMING!',
                    style: TextStyle(color: Color(0xFFCDDC39), fontSize: 10,
                        fontWeight: FontWeight.w900, letterSpacing: 1.3)),
                const SizedBox(height: 2),
                Text(
                  'Purity will drop by 10%.\nTreat ponds quickly — impact in ${game._acidRainWarningCd.ceil()}s!',
                  style: const TextStyle(color: Colors.white60, fontSize: 9.5),
                ),
              ]),
              const SizedBox(width: 10),
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFCDDC39).withValues(alpha: 0.14),
                    border: Border.all(color: const Color(0xFFCDDC39).withValues(alpha: 0.50))),
                child: Center(child: Text('${game._acidRainWarningCd.ceil()}',
                    style: const TextStyle(color: Color(0xFFCDDC39),
                        fontWeight: FontWeight.bold, fontSize: 16))),
              ),
            ]),
          )),
        ));
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  TREATMENT RESUPPLY OVERLAY
// ══════════════════════════════════════════════════════════════════════════════
class TreatmentResupplyOverlay extends StatelessWidget {
  final PondCleaningGame game;
  const TreatmentResupplyOverlay(this.game, {super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(child: Align(
      alignment: Alignment.topCenter,
      child: SafeArea(child: Container(
        margin: const EdgeInsets.only(top: 60),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF001A0A).withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF69F0AE).withValues(alpha: 0.70), width: 1.5),
          boxShadow: [BoxShadow(
              color: const Color(0xFF69F0AE).withValues(alpha: 0.25), blurRadius: 22)],
        ),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Text('📦', style: TextStyle(fontSize: 22)),
          SizedBox(width: 10),
          Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('TREATMENT RESUPPLY EARNED!',
                style: TextStyle(color: Color(0xFF69F0AE), fontSize: 11,
                    fontWeight: FontWeight.w900, letterSpacing: 1.3)),
            SizedBox(height: 2),
            Text('Low-stock treatment refilled with +3 uses.\nKeep cleaning ponds to earn more!',
                style: TextStyle(color: Colors.white60, fontSize: 10)),
          ]),
        ]),
      )),
    ));
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  RESULTS OVERLAY
// ══════════════════════════════════════════════════════════════════════════════
class PondResultsOverlay extends StatelessWidget {
  final PondCleaningGame game;
  const PondResultsOverlay(this.game, {super.key});

  @override
  Widget build(BuildContext context) {
    final r        = PondCleaningResult.current!;
    final meetsMin = r.meetsMinimum;
    final purity   = r.waterPurity;
    final stars    = r.correctTreatments >= 7 && r.pondsClean >= 6 ? '★★★'
                   : r.correctTreatments >= 4  && r.pondsClean >= 3 ? '★★☆'
                   : '★☆☆';
    final headerEmoji = meetsMin ? '💧' : '☠️';
    final headerText  = meetsMin ? 'Wetland Restored!' : 'Mission Incomplete';
    final accent      = meetsMin ? const Color(0xFF69F0AE) : const Color(0xFFEF5350);

    return Container(
      color: Colors.black.withValues(alpha: 0.94),
      child: SafeArea(child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(children: [

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: meetsMin
                  ? [const Color(0xFF001A0A), const Color(0xFF003018)]
                  : [const Color(0xFF1A0000), const Color(0xFF2A0000)]),
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 16)],
            ),
            child: Column(children: [
              Text(headerEmoji, style: const TextStyle(fontSize: 50)),
              const SizedBox(height: 6),
              Text(headerText,
                  style: const TextStyle(color: Colors.white,
                      fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(r.performanceGrade,
                  style: TextStyle(color: accent, fontSize: 13,
                      fontWeight: FontWeight.w700, letterSpacing: 1.0)),
              const SizedBox(height: 4),
              const Text('Phase 2 — Water Purification Results',
                  style: TextStyle(color: Colors.white54, fontSize: 12)),
              const SizedBox(height: 8),
              Text(stars, style: const TextStyle(
                  color: Color(0xFFFFB300), fontSize: 28, letterSpacing: 6)),
              if (meetsMin) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF69F0AE).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF69F0AE).withValues(alpha: 0.42)),
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('🏅', style: TextStyle(fontSize: 14)),
                    SizedBox(width: 6),
                    Text('Wetland Guardian Badge Unlocked!',
                        style: TextStyle(color: Color(0xFF69F0AE),
                            fontWeight: FontWeight.w800, fontSize: 11.5)),
                  ]),
                ),
              ],
            ]),
          ),
          const SizedBox(height: 14),

          _PRCard(children: [
            _PRBig('💧', '${r.pondsClean}/${game.ponds.isEmpty ? PondCleaningGame.totalPonds : game.ponds.length}',
                'Ponds\nCleaned', const Color(0xFF00897B)),
            _PRBig('🎯', '${r.accuracyPct}%', 'Treatment\nAccuracy',
                r.accuracyPct >= 80 ? const Color(0xFF69F0AE)
                    : r.accuracyPct >= 50 ? const Color(0xFFFFB300) : Colors.redAccent),
            _PRBig('🔥', '${r.maxCombo}×', 'Max\nCombo', const Color(0xFFFF6D00)),
          ]),
          const SizedBox(height: 8),

          _PRCard(children: [
            _PRBig('💦', '${purity.toStringAsFixed(0)}%', 'Water\nPurity',
                purity >= 80 ? const Color(0xFF69F0AE)
                    : purity >= 50 ? const Color(0xFF00897B) : Colors.redAccent),
            _PRBig('⭐', '${r.ecoPoints}', 'Eco\nPoints', Colors.amber),
            _PRBig('⚡', '${r.criticalSaves}', 'Crits\nSaved', Colors.redAccent),
          ]),
          const SizedBox(height: 8),

          _PRCard(children: [
            if (r.pondsSpread > 0)
              _PRBig('⚠️', '${r.pondsSpread}', 'Ponds\nSpread', Colors.orange)
            else
              _PRBig('✅', '0', 'Ponds\nSpread', const Color(0xFF69F0AE)),
            if (r.resupplyTriggered > 0)
              _PRBig('📦', '${r.resupplyTriggered}×', 'Resupply\nEarned', const Color(0xFF8BC34A))
            else
              _PRBig('📦', '0', 'Resupply\nEarned', Colors.white38),
          ]),

          if (r.performanceSummary.isNotEmpty && r.performanceSummary !=
              'Clean all ponds to maximise your score.') ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0A0A12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(children: [
                const Text('YOUR PERFORMANCE',
                    style: TextStyle(color: Colors.white54, fontSize: 10,
                        fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                const SizedBox(height: 8),
                Text(r.performanceSummary,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 11, height: 1.6)),
              ]),
            ),
          ],
          const SizedBox(height: 10),

          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: const Color(0xFF0A1A08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(children: [
              const Text('Treatment Reference',
                  style: TextStyle(color: Colors.white70, fontSize: 12,
                      fontWeight: FontWeight.bold, letterSpacing: 1)),
              const SizedBox(height: 10),
              _PRRow('🌿', 'Algae Bloom',         '💧 Water Hyacinths'),
              _PRRow('🦠', 'Organic Waste Pond', '🧫 Bacteria Pellets'),
              _PRRow('☠️', 'Chemical Pollution', '🔧 Filtration Unit'),
            ]),
          ),
          const SizedBox(height: 10),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0A1A08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white24),
            ),
            child: Column(children: [
              const Text('LEVEL SUMMARY',
                  style: TextStyle(color: Colors.white54, fontSize: 10,
                      fontWeight: FontWeight.w900, letterSpacing: 1.2)),
              const SizedBox(height: 8),
              Text(r.endReason,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 11.5, height: 1.5)),
            ]),
          ),
          const SizedBox(height: 18),

          SizedBox(
            width: double.infinity,
            child: meetsMin
                ? ElevatedButton.icon(
                    onPressed: () {
                      game.resumeEngine();
                      game.onLevelComplete();
                    },
                    icon: const Icon(Icons.pets_rounded),
                    label: const Text('Continue to Wildlife Rescue  →',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.7)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF69F0AE),
                      foregroundColor: Colors.black87,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 8,
                    ),
                  )
                : Column(children: [
                    ElevatedButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.replay_rounded),
                      label: Text(
                        'Replay  — Clean ${r.minimumPondsRequired - r.pondsClean} More Pond(s)',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEF5350),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        minimumSize: const Size(double.infinity, 0),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 8,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFB300).withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFFB300).withValues(alpha: 0.35)),
                      ),
                      child: Text(
                        '💡 Fly near a pond and hold SCAN (1.5 s).\n'
                        'Read the analysis, pick the correct treatment.\n'
                        'Minimum ${r.minimumPondsRequired} cleaned ponds needed to advance.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xFFFFB300), fontSize: 11, height: 1.5),
                      ),
                    ),
                  ]),
          ),
        ]),
      )),
    );
  }
}

class _PRCard extends StatelessWidget {
  final List<Widget> children;
  const _PRCard({required this.children});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
    decoration: BoxDecoration(
        color: const Color(0xFF0A1A08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12)),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: children),
  );
}

class _PRBig extends StatelessWidget {
  final String emoji, value, label;
  final Color  color;
  const _PRBig(this.emoji, this.value, this.label, this.color);
  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
    Text(emoji, style: const TextStyle(fontSize: 20)),
    const SizedBox(height: 3),
    Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 17)),
    const SizedBox(height: 2),
    Text(label, textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white54, fontSize: 8.5)),
  ]);
}

class _PRRow extends StatelessWidget {
  final String emoji, label, action;
  const _PRRow(this.emoji, this.label, this.action);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4.5),
    child: Row(children: [
      Text(emoji, style: const TextStyle(fontSize: 14)),
      const SizedBox(width: 8),
      Expanded(child: Text(label,
          style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600))),
      Text(action, style: const TextStyle(color: Color(0xFF69F0AE), fontSize: 9.5)),
    ]),
  );
}