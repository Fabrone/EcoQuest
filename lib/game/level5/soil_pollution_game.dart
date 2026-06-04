import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:ecoquest/game/level5/degraded_land_screen.dart';
import 'package:flame/components.dart' hide Matrix4;
import 'package:flame/game.dart' hide Matrix4;
import 'package:flutter/material.dart' hide Matrix4;
import 'package:flutter/services.dart';

import 'package:ecoquest/game/level5/soil_pollution_models.dart';

// ── Critical contamination alert ──────────────────────────────────────────────
class CriticalContaminationAlert {
  final SoilContaminationZone zone;
  double timeLeft;
  bool   handled;

  CriticalContaminationAlert({
    required this.zone,
    this.timeLeft = 12.0,
    this.handled  = false,
  });
}

// ══════════════════════════════════════════════════════════════════════════════
//  SOIL POLLUTION RESULT
// ══════════════════════════════════════════════════════════════════════════════
class SoilPollutionResult {
  final int    zonesRemediated;
  final int    zonesPhysical;
  final int    correctTools;
  final int    wrongTools;
  final int    ecoPoints;
  final double soilHealth;
  final bool   soilGuardianBadge;
  final int    scannedZones;
  final int    maxCombo;
  // Dynamic fields
  final int    scanStreakBonus;
  final int    ecoDiscoveriesFound;
  final bool   timeBonusCollected;
  final int    criticalSaves;
  final int    zonesExpanded;
  final int    resupplyTriggered;
  // Minimum gate
  final bool   meetsMinimum;
  final int    minimumRequired;

  const SoilPollutionResult({
    required this.zonesRemediated,
    required this.zonesPhysical,
    required this.correctTools,
    required this.wrongTools,
    required this.ecoPoints,
    required this.soilHealth,
    required this.soilGuardianBadge,
    required this.scannedZones,
    this.maxCombo          = 1,
    this.scanStreakBonus    = 0,
    this.ecoDiscoveriesFound = 0,
    this.timeBonusCollected = false,
    this.criticalSaves     = 0,
    this.zonesExpanded     = 0,
    this.resupplyTriggered = 0,
    this.meetsMinimum      = false,
    this.minimumRequired   = 2,
  });

  int get totalActions  => correctTools + wrongTools;
  int get accuracyPct   => totalActions == 0
      ? 0 : ((correctTools / totalActions) * 100).round();

  /// Human-readable performance grade
  String get performanceGrade {
    if (accuracyPct >= 85 && zonesRemediated >= 7) return 'EXPERT REMEDIATOR';
    if (accuracyPct >= 70 && zonesRemediated >= 5) return 'SKILLED SOIL SCIENTIST';
    if (accuracyPct >= 50 && zonesRemediated >= 3) return 'FIELD TRAINEE';
    return 'APPRENTICE ECOLOGIST';
  }

  String get performanceSummary {
    final lines = <String>[];
    if (criticalSaves > 0) lines.add('Saved \$criticalSaves critical zone(s) before collapse');
    if (zonesExpanded > 0) lines.add('\$zonesExpanded contamination zone(s) expanded due to neglect');
    if (ecoDiscoveriesFound > 0) lines.add('Found \$ecoDiscoveriesFound hidden Eco-Discovery marker(s)');
    if (timeBonusCollected) lines.add('Time Bonus zone restored - earned +8 s');
    if (maxCombo >= 4) lines.add('\$maxCombo-streak combo achieved - 3× point multiplier!');
    if (scanStreakBonus > 0) lines.add('Scan streak bonus: +\$scanStreakBonus pts');
    return lines.isEmpty ? 'Complete all zones to maximise your score.' : lines.join('\n');
  }

  static SoilPollutionResult? current;
}

// ══════════════════════════════════════════════════════════════════════════════
//  MAIN GAME CLASS
// ══════════════════════════════════════════════════════════════════════════════
class SoilPollutionGame extends FlameGame
    with HasCollisionDetection, ChangeNotifier {

  final Level4CarryOver carryOver;
  final VoidCallback    onLevelComplete;

  SoilPollutionGame({required this.carryOver, required this.onLevelComplete});

  // ── Minimum zones required to proceed ─────────────────────────────────────
  static const int kMinZonesRequired = 2;

  // ── World / camera (3× screen) ─────────────────────────────────────────────
  static const double kWorldScale   = 3.0;
  static const double kEdgeFraction = 0.22;
  static const double kCameraEase   = 5.5;
  double worldW = 0, worldH = 0;
  double camX = 0, camY = 0;
  double _targetCamX = 0, _targetCamY = 0;
  double edgeHintLeft = 0, edgeHintRight = 0;
  double edgeHintTop  = 0, edgeHintBottom = 0;

  // ── Tool selector ──────────────────────────────────────────────────────────
  SoilContaminationZone? pendingFixTarget;
  bool toolSelectorOpen = false;

  // ── Core ───────────────────────────────────────────────────────────────────
  int    gamePhase   = 3;
  bool   gameStarted = false;
  double timeLeft    = 150.0;
  bool   levelDone   = false;

  // ── Score ──────────────────────────────────────────────────────────────────
  int ecoPoints       = 0;
  int correctTools    = 0;
  int wrongTools      = 0;
  int remediatedCount = 0;
  int physicalCount   = 0;
  int scannedCount    = 0;
  int maxCombo        = 1;

  // ── Soil health (starts low; target 75) ───────────────────────────────────
  double soilHealth                 = 8.0;
  static const double _targetHealth = 75.0;

  // ── Layer selector ─────────────────────────────────────────────────────────
  ScanLayerType selectedLayer  = ScanLayerType.topLayer;
  bool   wrongLayerActive = false;
  double wrongLayerTimer  = 0;

  // ── Ranges ─────────────────────────────────────────────────────────────────
  static const double _scanRange     = 155.0;
  static const double _hoverRange    = 110.0;
  static const double _applyRange    = 100.0;
  static const double _scanMaxRadius = 180.0;

  // ── Drone physics ──────────────────────────────────────────────────────────
  late Vector2 dronePos;
  bool isUp = false, isDown = false, isLeft = false, isRight = false;
  static const double _droneSpeed = 195.0;

  // ── Phase 3 - Scan system ──────────────────────────────────────────────────
  SoilContaminationZone? activeScanZone;
  double         scanHoldTime = 0.0;
  static const double _scanDuration = 1.5;
  bool   inChemicalHaze = false;
  bool   scanActive     = false;
  double scanRadius     = 0;
  bool   scanLockActive   = false;
  double _scanLockTimer   = 0;

  // PUBLIC - read by SoilHud to show the "zone nearby" nudge
  SoilContaminationZone? nearestScanTarget;

  // ── Phase 3 - Scan result (non-blocking) ──────────────────────────────────
  bool            scanResultActive = false;
  SoilScanResult? lastScanResult;
  double          scanResultTimer  = 0;
  SoilContaminationZone? lastScannedZone;
  int    lastScanPoints = 0;
  Vector2 scanCardPos   = Vector2.zero();

  // ── Phase 3 - Scan streak ──────────────────────────────────────────────────
  int    scanStreak      = 0;
  double scanStreakTimer  = 0;
  int    totalScanStreak = 0;
  static const double _streakWindow = 6.0;

  // ── Phase 3 - Chemical haze ────────────────────────────────────────────────
  final List<ChemicalHazeComponent> chemicalHazes = [];

  // ── Phase 3 - Leach zones ──────────────────────────────────────────────────
  final List<LeachZone> leachZones       = [];
  double                _leachChangeTimer = 0;
  static const double   _leachPeriod     = 9.0;
  double                leachIntensity   = 0;

  // ── Eco-discovery & time-bonus zones ──────────────────────────────────────
  final Set<int> ecoDiscoveryIndices  = {};
  final Set<int> discoveredEcoZones   = {};
  int?           timeBonusZoneIndex;
  bool           timeBonusCollected   = false;
  int            ecoDiscoveriesFound  = 0;
  String         lastDiscoveryFact    = '';
  double         discoveryDisplayTimer = 0;
  static const double _discoveryDisplay = 4.0;

  // ── Phase 4 - Tool inventory ───────────────────────────────────────────────
  RemediationTool selectedTool = RemediationTool.containmentBoom;
  final Map<RemediationTool, int> toolUses = {
    RemediationTool.containmentBoom: 3,
    RemediationTool.pHAmendment:     3,
    RemediationTool.soilExcavation:  3,
    RemediationTool.soilWashing:     3,
    RemediationTool.aerationTill:    3,
    RemediationTool.biocharBacteria: 3,
    RemediationTool.limeCompost:     3,
    RemediationTool.phytoPlants:     3,
    RemediationTool.compostWorms:    3,
    RemediationTool.mycorrhizae:     3,
  };
  bool get canUseSelectedTool => (toolUses[selectedTool] ?? 0) > 0;

  // ── Phase 4 - Resupply ─────────────────────────────────────────────────────
  int    _zonesSinceResupply = 0;
  int    resupplyTriggered   = 0;
  bool   resupplyActive      = false;
  double resupplyTimer       = 0;
  static const double _resupplyDisplay = 2.2;

  // ── Phase 4 - Combo ────────────────────────────────────────────────────────
  int    comboCount     = 0;
  double comboTimer     = 0;
  static const double _comboWindow = 4.5;
  bool   showComboFlash  = false;
  double comboFlashTimer = 0;

  // ── Phase 4 - Acid leaching event ──────────────────────────────────────────
  double _leachingTimer     = 45.0;
  bool   leachingWarning    = false;
  bool   leachingActive     = false;
  // PUBLIC - read by AcidLeachingAlertOverlay to show the countdown
  double leachingWarningCd  = 0;
  double _leachingActiveCd  = 0;
  double leachingIntensity  = 0;
  final Set<SoilContaminationZone> riskZones = {};

  // ── Phase 4 - Critical contamination alerts ───────────────────────────────
  final List<CriticalContaminationAlert> criticalAlerts = [];
  double _criticalAlertTimer = 48.0;
  int    criticalSaves       = 0;

  // ── Phase 4 - Zone expansion ──────────────────────────────────────────────
  final Map<SoilContaminationZone, double> _zoneSpreadTimers = {};
  static const double _spreadAt = 35.0;
  int    zonesExpanded     = 0;
  double _spreadCheckTimer = 1.0;

  // ── Phase 4 - Leach strip ─────────────────────────────────────────────────
  double _leachStripTimer = 25.0;

  // ── Phase 4 - Contamination surge ─────────────────────────────────────────
  double _surgeTimer          = 25.0;
  int    _zonesSinceLastSurge = 0;
  bool   surgePending         = false;
  double surgePulse           = 0;

  // ── Reaction FX ───────────────────────────────────────────────────────────
  bool   reactionActive  = false;
  bool   reactionCorrect = false;
  int    reactionPhase   = 3;
  bool   reactionInRange = true;
  double reactionTimer   = 0;
  String reactionMsg     = '';

  // ── Banner ─────────────────────────────────────────────────────────────────
  double bannerTimer = 3.5;

  // ── Eco-guide hint ─────────────────────────────────────────────────────────
  String ecoGuideHint  = '';
  double ecoGuideTimer = 0;
  double _hintCooldown = 0;
  double _idleTimer    = 0;

  // ── Show-once system ───────────────────────────────────────────────────────
  final Set<SoilPollutantType> _seenScanCardTypes  = {};
  final Set<String>            _seenToolHintKeys   = {};
  bool scanResultShowsHints   = true;
  bool toolSelectorShowsHints = true;

  // ── Components ─────────────────────────────────────────────────────────────
  late SoilDroneComponent drone;
  final List<SoilContaminationZone> zones = [];
  double _refillTimer = 0;
  static const double _refillInterval = 20.0;

  // ── Load ───────────────────────────────────────────────────────────────────
  @override
  Future<void> onLoad() async {
    super.onLoad();
    worldW = size.x * kWorldScale;
    worldH = size.y * kWorldScale;
    dronePos = Vector2(worldW * 0.50, worldH * 0.25);
    _centerCamOn(dronePos);
    _targetCamX = camX; _targetCamY = camY;

    _initLeachZones();
    add(SoilCrossSectionRenderer(game: this));
    add(PollutionDebrisLayer(game: this));
    _spawnChemicalHazes();
    drone = SoilDroneComponent(game: this);
    add(drone);
    _spawnZones();
    _assignSpecialZones();

    bannerTimer = 3.5;
    add(TimerComponent(period: 1.0, repeat: true, onTick: _onSecond));
  }

  void _centerCamOn(Vector2 pos) {
    camX = (pos.x - size.x / 2).clamp(0.0, worldW - size.x);
    camY = (pos.y - size.y / 2).clamp(0.0, worldH - size.y);
  }

  Vector2 screenToWorld(Vector2 s) => Vector2(s.x + camX, s.y + camY);
  Vector2 worldToScreen(Vector2 w) => Vector2(w.x - camX, w.y - camY);
  Vector2 get droneScreen => worldToScreen(dronePos);

  // ── Init helpers ───────────────────────────────────────────────────────────
  void _initLeachZones() {
    final rng = math.Random(42);
    final positions = [
      Vector2(worldW * 0.18, worldH * 0.28),
      Vector2(worldW * 0.50, worldH * 0.18),
      Vector2(worldW * 0.72, worldH * 0.42),
      Vector2(worldW * 0.30, worldH * 0.62),
      Vector2(worldW * 0.82, worldH * 0.68),
    ];
    for (final pos in positions) {
      leachZones.add(LeachZone(
        center:    pos,
        radius:    120.0 + rng.nextDouble() * 50.0,
        leachRate: 0.4   + rng.nextDouble() * 0.5,
      ));
      add(LeachZoneRenderer(zone: leachZones.last, game: this));
    }
  }

  void _spawnChemicalHazes() {
    final rng = math.Random(99);
    for (int i = 0; i < 5; i++) {
      final haze = ChemicalHazeComponent(
        game:   this,
        startX: worldW * (0.10 + rng.nextDouble() * 0.80),
        startY: worldH * (0.10 + rng.nextDouble() * 0.65),
        radius: 85.0  + rng.nextDouble() * 55.0,
        speed:  16.0  + rng.nextDouble() * 14.0,
        seed:   i * 33 + 7,
      );
      chemicalHazes.add(haze);
      add(haze);
    }
  }

  void _spawnZones() {
    const specs = [
      (SoilPollutantType.oilSpill,    ScanLayerType.topLayer,  0.38, 0.16),
      (SoilPollutantType.acidicSoil,  ScanLayerType.midLayer,  0.52, 0.46),
      (SoilPollutantType.pesticides,  ScanLayerType.midLayer,  0.46, 0.52),
      (SoilPollutantType.compactSoil, ScanLayerType.topLayer,  0.58, 0.22),
      (SoilPollutantType.oilSpill,    ScanLayerType.topLayer,  0.12, 0.18),
      (SoilPollutantType.heavyMetals, ScanLayerType.deepLayer, 0.18, 0.70),
      (SoilPollutantType.acidicSoil,  ScanLayerType.midLayer,  0.08, 0.44),
      (SoilPollutantType.compactSoil, ScanLayerType.topLayer,  0.22, 0.20),
      (SoilPollutantType.pesticides,  ScanLayerType.midLayer,  0.82, 0.48),
      (SoilPollutantType.heavyMetals, ScanLayerType.deepLayer, 0.76, 0.72),
      (SoilPollutantType.compactSoil, ScanLayerType.topLayer,  0.88, 0.24),
      (SoilPollutantType.oilSpill,    ScanLayerType.topLayer,  0.70, 0.20),
      (SoilPollutantType.heavyMetals, ScanLayerType.deepLayer, 0.44, 0.68),
      (SoilPollutantType.pesticides,  ScanLayerType.midLayer,  0.62, 0.42),
    ];
    for (int i = 0; i < specs.length; i++) {
      final (type, layer, rx, ry) = specs[i];
      final z = SoilContaminationZone(
        game:          this,
        type:          type,
        worldX:        worldW * rx,
        worldY:        worldH * ry,
        requiredLayer: layer,
        seed:          i * 23,
      );
      add(z);
      zones.add(z);
    }
  }

  void _tryRefillZones() {
    final remaining = zones.where((z) => !z.isRemediated).length;
    if (remaining < 4) {
      final rng = math.Random(
          zones.length * 13 + DateTime.now().millisecondsSinceEpoch);
      for (int i = 0; i < 5; i++) {
        final angle = rng.nextDouble() * math.pi * 2;
        final dist  = worldW * (0.20 + rng.nextDouble() * 0.25);
        final wx = (dronePos.x + math.cos(angle) * dist)
            .clamp(80.0, worldW - 80.0);
        final wy = (dronePos.y + math.sin(angle) * dist)
            .clamp(60.0, worldH * 0.82 - 60.0);
        final type  = SoilPollutantType.values[
            rng.nextInt(SoilPollutantType.values.length)];
        final layer = _layerForY(wy);
        final z = SoilContaminationZone(
          game: this, type: type, worldX: wx, worldY: wy,
          requiredLayer: layer, seed: rng.nextInt(9999),
        );
        add(z);
        zones.add(z);
      }
    }
  }

  ScanLayerType _layerForY(double wy) {
    final frac = wy / worldH;
    if (frac < 0.35) return ScanLayerType.topLayer;
    if (frac < 0.63) return ScanLayerType.midLayer;
    return ScanLayerType.deepLayer;
  }

  void _assignSpecialZones() {
    final rng = math.Random(DateTime.now().millisecondsSinceEpoch);
    final indices = List.generate(zones.length, (i) => i)..shuffle(rng);
    ecoDiscoveryIndices.add(indices[0]);
    ecoDiscoveryIndices.add(indices[1]);
    timeBonusZoneIndex = indices[2];
  }

  void _onSecond() {
    if (!gameStarted || levelDone) return;
    timeLeft -= 1;
    if (timeLeft <= 0) { timeLeft = 0; _endLevel(); }
    notifyListeners();
  }

  // ── Public getters (used by overlay widgets) ───────────────────────────────
  double get scanHoldProgress =>
      scanLockActive ? (_scanLockTimer / _scanDuration).clamp(0.0, 1.0) : 0.0;

  /// Whether any unscanned zone is within scan range. Read by SoilControls.
  bool get hasNearbyUnscanned =>
      zones.any((z) =>
          !z.isScanned && (z.zonePos - dronePos).length <= _scanRange);

  /// Whether any unremediated zone is within apply range. Read by SoilControls.
  bool get hasNearbyUnremediated =>
      zones.any((z) =>
          !z.isRemediated && (z.zonePos - dronePos).length <= _applyRange);

  /// Nearest actionable zone. Read by _RemediationSidePanel.
  SoilContaminationZone? get nearestActionable {
    SoilContaminationZone? best; double minD = _applyRange;
    for (final z in zones) {
      if (z.isRemediated) continue;
      final d = (z.zonePos - dronePos).length;
      if (d < minD) { minD = d; best = z; }
    }
    return best;
  }

  // ── Phase 3: User-triggered SCAN ──────────────────────────────────────────
  void triggerScan() {
    if (!gameStarted || levelDone || gamePhase != 3) return;
    gameStarted = true;
    HapticFeedback.selectionClick();

    if (toolSelectorOpen) {
      reactionMsg = '🔧 Select a remediation agent first!';
      _triggerReaction(false, inRange: false);
      notifyListeners();
      return;
    }

    if (scanLockActive) {
      reactionMsg = '📡 Scan in progress - hold position!';
      _triggerReaction(true, inRange: true);
      notifyListeners();
      return;
    }

    SoilContaminationZone? nearest;
    double nearestD = _scanRange;
    for (final z in zones) {
      if (z.isScanned) continue;
      final d = (z.zonePos - dronePos).length;
      if (d < nearestD) { nearestD = d; nearest = z; }
    }

    if (nearest == null) {
      scanActive = true; scanRadius = 0;
      reactionMsg = '🔬 No contamination zone in range - explore further';
      _triggerReaction(false, inRange: false);
      notifyListeners();
      return;
    }

    if (nearest.requiredLayer != selectedLayer) {
      HapticFeedback.heavyImpact();
      ecoPoints        = math.max(0, ecoPoints - 2);
      wrongLayerActive = true;
      wrongLayerTimer  = 2.0;
      overlays.add('wrongLayer');
      notifyListeners();
      return;
    }

    nearestScanTarget = nearest;
    activeScanZone    = nearest;
    scanLockActive    = true;
    _scanLockTimer    = 0;
    scanHoldTime      = 0;
    scanActive        = true;
    scanRadius        = 0;
    reactionMsg       = '📡 Scanning soil - hold position!';
    _triggerReaction(true, inRange: true);
    HapticFeedback.lightImpact();
    notifyListeners();
  }

  // ── Phase 3: Scan completion → result card + pending fix ──────────────────
  void _completeScanZone(SoilContaminationZone z) {
    if (z.isScanned) return;
    final idx          = zones.indexOf(z);
    final hasDiscovery = ecoDiscoveryIndices.contains(idx);
    z.isScanned        = true;
    scannedCount++;
    z.scanVariant      = idx;

    final pts       = hasDiscovery ? 30 : 10;
    ecoPoints      += pts;
    lastScanPoints  = pts;
    scanActive      = true;
    scanRadius      = 0;
    lastScannedZone = z;
    lastScanResult  = SoilScanResult.forType(
        z.type, withDiscovery: hasDiscovery, variant: idx);
    scanCardPos     = dronePos.clone();
    final firstScan = !_seenScanCardTypes.contains(z.type);
    if (firstScan) _seenScanCardTypes.add(z.type);
    scanResultShowsHints = firstScan;
    scanResultTimer      = hasDiscovery ? 5.5 : 4.0;
    scanResultActive     = true;
    _handleScanStreak();
    HapticFeedback.heavyImpact();

    scanLockActive = false;
    _scanLockTimer = 0;
    activeScanZone = null;

    if (hasDiscovery) {
      ecoDiscoveriesFound++;
      discoveredEcoZones.add(idx);
      lastDiscoveryFact    = lastScanResult!.discoveryFact;
      discoveryDisplayTimer = _discoveryDisplay;
      overlays.add('ecoDiscovery');
    } else {
      overlays.add('scanResult');
    }

    pendingFixTarget = z;
    notifyListeners();
  }

  void openToolSelectorForPending() {
    if (pendingFixTarget == null || toolSelectorOpen) return;
    toolSelectorOpen = true;
    overlays.remove('scanResult');
    scanResultActive = false;
    toolSelectorShowsHints = _checkAndMarkHintsSeen(
        pendingFixTarget!.type, RemediationStep.none);
    overlays.add('toolSelect');
    notifyListeners();
  }

  void _handleScanStreak() {
    scanStreakTimer = _streakWindow;
    scanStreak++;
    if (scanStreak >= 3) {
      final bonus = (scanStreak - 2) * 8;
      ecoPoints       += bonus;
      totalScanStreak += bonus;
      reactionMsg      = '🎯 Scan Streak ×$scanStreak!  +$bonus bonus pts';
      _triggerReaction(true);
    }
  }

  void dismissScanResult() {
    if (!scanResultActive) return;
    scanResultActive = false;
    overlays.remove('scanResult');
    if (pendingFixTarget != null && !toolSelectorOpen) {
      toolSelectorOpen = true;
      toolSelectorShowsHints = _checkAndMarkHintsSeen(
          pendingFixTarget!.type, RemediationStep.none);
      overlays.add('toolSelect');
    }
    notifyListeners();
    if (scannedCount >= zones.length && !toolSelectorOpen) {
      Future.delayed(const Duration(milliseconds: 400), _advanceToPhase4);
    }
  }

  void _advanceToPhase4() {
    if (levelDone) return;
    gamePhase = 4; bannerTimer = 3.0;
    overlays.add('banner');
    notifyListeners();
  }

  // ── Phase 4: Apply remediation tool ───────────────────────────────────────
  void applyTool() {
    if (!gameStarted || levelDone) return;
    if (!canUseSelectedTool) {
      reactionMsg = '⚠️ No ${_toolLabel(selectedTool)} uses left!';
      _triggerReaction(false, inRange: false);
      notifyListeners();
      return;
    }
    final target = pendingFixTarget ?? nearestActionable;
    if (target == null) {
      reactionMsg = '✈️ Move closer to a diagnosed contamination zone';
      _triggerReaction(false, inRange: false);
      notifyListeners();
      return;
    }

    HapticFeedback.lightImpact();
    toolUses[selectedTool] = (toolUses[selectedTool] ?? 1) - 1;

    final stepBeforeApply = target.step;
    final correct = isCorrectTool(target.type, selectedTool, stepBeforeApply);
    bool closeSelector = false;

    if (correct) {
      if (stepBeforeApply == RemediationStep.none) {
        target.step = RemediationStep.physical;
        physicalCount++;
        correctTools++;
        soilHealth = math.min(100, soilHealth + 4.0);
        final pts  = 10 * _comboMult();
        ecoPoints += pts; _incCombo();
        riskZones.remove(target); target.isAtRisk = false;
        _zoneSpreadTimers.remove(target);
        _dismissCriticalAlert(target, saved: true);
        reactionMsg =
            '🏗️ Physical treatment applied!  +$pts pts  -  Now add Step ② (Biological)!';
        _triggerReaction(true);
        toolSelectorShowsHints = _checkAndMarkHintsSeen(
            target.type, RemediationStep.physical);
      } else if (stepBeforeApply == RemediationStep.physical) {
        target.step = RemediationStep.remediated;
        remediatedCount++;
        correctTools++;
        soilHealth = math.min(100, soilHealth + 9.0);
        final pts  = 20 * _comboMult();
        ecoPoints += pts; _incCombo();
        riskZones.remove(target); target.isAtRisk = false;
        _dismissCriticalAlert(target, saved: true);
        reactionMsg = '🌱 Zone Fully Remediated!  +$pts pts  🎉';
        _triggerReaction(true);
        _zonesSinceLastSurge++;
        _zonesSinceResupply++;
        target.triggerSparkle = true;

        final idx = zones.indexOf(target);
        if (idx == timeBonusZoneIndex && !timeBonusCollected) {
          timeBonusCollected = true;
          timeLeft = math.min(timeLeft + 8, 150);
          reactionMsg =
              '⏱️ Time Bonus! +8 s  🌱 Fully Remediated!  +$pts pts';
          HapticFeedback.heavyImpact();
        }

        if (_zonesSinceResupply >= 4) {
          _zonesSinceResupply = 0;
          _triggerResupply();
        }
        closeSelector = true;
      }
    } else {
      wrongTools++;
      soilHealth = math.max(0, soilHealth - 3.0);
      ecoPoints  = math.max(0, ecoPoints - 5);
      _breakCombo();
      final stepNum =
          stepBeforeApply == RemediationStep.none ? '①' : '②';
      reactionMsg = '❌ Wrong agent for Step $stepNum - try another!';
      _triggerReaction(false);
    }

    if (closeSelector) {
      pendingFixTarget = null;
      toolSelectorOpen = false;
      overlays.remove('toolSelect');
      if (scannedCount >= zones.length) {
        Future.delayed(
            const Duration(milliseconds: 400), _advanceToPhase4);
      }
    }

    if (soilHealth >= _targetHealth || zones.every((z) => z.isRemediated)) {
      Future.delayed(const Duration(milliseconds: 800), _endLevel);
    }
    notifyListeners();
  }

  void cancelToolSelector() {
    toolSelectorOpen = false;
    pendingFixTarget = null;
    overlays.remove('toolSelect');
    notifyListeners();
  }

  // ── Level-complete navigation ───────────────────────────────────────────────
  /// Removes the in-game results overlay and fires the [onLevelComplete]
  /// callback, which the host screen uses to push [Level5CompleteScreen].
  ///
  /// Called by [SoilResultsOverlay] when the player taps "LEVEL COMPLETE"
  /// and [SoilPollutionResult.current.meetsMinimum] is `true`.
  ///
  /// Safe to call from a Flame overlay widget's `onPressed` handler.
  void navigateToComplete() {
    overlays.remove('results');
    onLevelComplete();
  }

  void _triggerResupply() {
    RemediationTool lowest = RemediationTool.containmentBoom;
    int lowestCount = 99;
    toolUses.forEach((t, c) {
      if (c < lowestCount) { lowestCount = c; lowest = t; }
    });
    toolUses[lowest] = (toolUses[lowest] ?? 0) + 3;
    resupplyActive = true;
    resupplyTimer  = _resupplyDisplay;
    resupplyTriggered++;
    overlays.add('resupply');
    notifyListeners();
  }

  // ── Critical contamination alerts ─────────────────────────────────────────
  void _spawnCriticalAlert() {
    final candidates = zones.where((z) =>
        !z.isRemediated &&
        criticalAlerts.every((a) => a.zone != z) &&
        !riskZones.contains(z)).toList();
    if (candidates.isEmpty) return;
    candidates.shuffle(math.Random());
    final z = candidates.first;
    z.isCritical = true;
    criticalAlerts.add(CriticalContaminationAlert(zone: z, timeLeft: 12.0));
    overlays.add('criticalAlert');
    HapticFeedback.heavyImpact();
    notifyListeners();
  }

  void _dismissCriticalAlert(SoilContaminationZone z,
      {bool saved = false}) {
    final alert =
        criticalAlerts.where((a) => a.zone == z).firstOrNull;
    if (alert == null) return;
    alert.handled = true;
    z.isCritical  = false;
    if (saved) { criticalSaves++; ecoPoints += 15; }
    criticalAlerts.removeWhere((a) => a.handled);
    if (criticalAlerts.isEmpty) overlays.remove('criticalAlert');
    notifyListeners();
  }

  void _expireCriticalAlert(CriticalContaminationAlert alert) {
    alert.handled         = true;
    alert.zone.isCritical = false;
    soilHealth = math.max(0, soilHealth - 12.0);
    ecoPoints  = math.max(0, ecoPoints - 20);
    if (alert.zone.step == RemediationStep.physical) {
      alert.zone.step = RemediationStep.none;
      physicalCount   = math.max(0, physicalCount - 1);
    }
    criticalAlerts.removeWhere((a) => a.handled);
    if (criticalAlerts.isEmpty) overlays.remove('criticalAlert');
    reactionMsg = '⛔ Contamination zone collapsed!  -20 pts';
    _triggerReaction(false);
    notifyListeners();
  }

  // ── Zone expansion ─────────────────────────────────────────────────────────
  void _checkZoneExpansion() {
    for (final z in List<SoilContaminationZone>.from(zones)) {
      if (z.type != SoilPollutantType.heavyMetals &&
          z.type != SoilPollutantType.pesticides) {
        continue;
      }
      if (z.isRemediated || z.step != RemediationStep.none) {
        _zoneSpreadTimers.remove(z); continue;
      }
      _zoneSpreadTimers[z] = (_zoneSpreadTimers[z] ?? 0) + 1;
      if ((_zoneSpreadTimers[z] ?? 0) >= _spreadAt) {
        _zoneSpreadTimers.remove(z);
        _spawnChildZone(z);
      }
    }
  }

  void _spawnChildZone(SoilContaminationZone parent) {
    if (zones.length >= 22) return;
    final rng = math.Random();
    final nx = (parent.hx + (rng.nextDouble() * 80 - 40))
        .clamp(60.0, worldW - 60.0);
    final ny = (parent.hy + (rng.nextDouble() * 60 - 30))
        .clamp(60.0, worldH * 0.85 - 60.0);
    final child = SoilContaminationZone(
      game: this, type: parent.type,
      worldX: nx, worldY: ny,
      requiredLayer: _layerForY(ny),
      seed: rng.nextInt(999), isChildZone: true,
    );
    add(child);
    zones.add(child);
    zonesExpanded++;
    child.isScanned = gamePhase == 4;
    soilHealth  = math.max(0, soilHealth - 6.0);
    ecoPoints   = math.max(0, ecoPoints - 8);
    reactionMsg = '⚠️ Contamination spread nearby!  -8 pts';
    _triggerReaction(false);
    notifyListeners();
  }

  // ── Leach strip ────────────────────────────────────────────────────────────
  void _applyLeachStrip() {
    if (leachIntensity < 0.6) return;
    final biological = zones
        .where((z) =>
            z.step == RemediationStep.physical && !z.isRemediated)
        .toList()
      ..shuffle(math.Random());
    if (biological.isEmpty) return;
    final victim         = biological.first;
    victim.step          = RemediationStep.none;
    victim.leachStripped = true;
    physicalCount        = math.max(0, physicalCount - 1);
    soilHealth           = math.max(0, soilHealth - 4.0);
    ecoPoints            = math.max(0, ecoPoints - 8);
    reactionMsg          = '💧 Leaching stripped a biological treatment!  -8 pts';
    _triggerReaction(false);
    notifyListeners();
  }

  // ── Combo helpers ──────────────────────────────────────────────────────────
  int _comboMult() {
    if (comboCount >= 4) return 3;
    if (comboCount >= 2) return 2;
    return 1;
  }

  void _incCombo() {
    comboCount++; comboTimer = _comboWindow;
    if (comboCount > maxCombo) maxCombo = comboCount;
    if (comboCount >= 3) {
      toolUses[selectedTool] = (toolUses[selectedTool] ?? 0) + 1;
    }
    showComboFlash = true; comboFlashTimer = 1.8;
    notifyListeners();
  }

  void _breakCombo() { comboCount = 0; comboTimer = 0; }

  // ── Show-once consciousness ────────────────────────────────────────────────
  bool _checkAndMarkHintsSeen(SoilPollutantType type, RemediationStep step) {
    final key = '${type.index}_${step.index}';
    if (_seenToolHintKeys.contains(key)) return false;
    _seenToolHintKeys.add(key);
    return true;
  }

  /// Returns true when [tool] is the correct choice for [type] at [step].
  /// Public so that overlay widgets can highlight the right tool card.
  bool isCorrectTool(
      SoilPollutantType type, RemediationTool tool, RemediationStep step) {
    if (step == RemediationStep.none) {
      switch (type) {
        case SoilPollutantType.oilSpill:    return tool == RemediationTool.containmentBoom;
        case SoilPollutantType.acidicSoil:  return tool == RemediationTool.pHAmendment;
        case SoilPollutantType.heavyMetals: return tool == RemediationTool.soilExcavation;
        case SoilPollutantType.pesticides:  return tool == RemediationTool.soilWashing;
        case SoilPollutantType.compactSoil: return tool == RemediationTool.aerationTill;
      }
    } else {
      switch (type) {
        case SoilPollutantType.oilSpill:    return tool == RemediationTool.biocharBacteria;
        case SoilPollutantType.acidicSoil:  return tool == RemediationTool.limeCompost;
        case SoilPollutantType.heavyMetals: return tool == RemediationTool.phytoPlants;
        case SoilPollutantType.pesticides:  return tool == RemediationTool.compostWorms;
        case SoilPollutantType.compactSoil: return tool == RemediationTool.mycorrhizae;
      }
    }
  }

  String _toolLabel(RemediationTool t) {
    switch (t) {
      case RemediationTool.containmentBoom: return 'Containment Boom';
      case RemediationTool.pHAmendment:     return 'pH Amendment';
      case RemediationTool.soilExcavation:  return 'Soil Excavation';
      case RemediationTool.soilWashing:     return 'Soil Washing';
      case RemediationTool.aerationTill:    return 'Aeration Tilling';
      case RemediationTool.biocharBacteria: return 'Biochar+Bacteria';
      case RemediationTool.limeCompost:     return 'Lime+Compost';
      case RemediationTool.phytoPlants:     return 'Phyto-Plants';
      case RemediationTool.compostWorms:    return 'Compost+Worms';
      case RemediationTool.mycorrhizae:     return 'Mycorrhizae';
    }
  }

  // ── Acid leaching event ────────────────────────────────────────────────────
  void _triggerLeachingWarning() {
    leachingWarning   = true;
    leachingWarningCd = 3.2;
    overlays.add('leachAlert');
    notifyListeners();
  }

  void _triggerLeachingActive() {
    leachingWarning = false; leachingActive = true;
    _leachingActiveCd = 9.0; leachingIntensity = 1.0;
    overlays.remove('leachAlert');
    riskZones.clear();
    final biological = zones
        .where((z) =>
            z.step == RemediationStep.physical && !z.isRemediated)
        .toList()
      ..shuffle(math.Random());
    for (int i = 0; i < math.min(2, biological.length); i++) {
      biological[i].isAtRisk  = true;
      biological[i].riskTimer = 9.0;
      riskZones.add(biological[i]);
    }
    notifyListeners();
  }

  void _endLeachingActive() {
    leachingActive = false; leachingIntensity = 0;
    for (final z in List<SoilContaminationZone>.from(riskZones)) {
      if (z.isAtRisk && !z.isRemediated) {
        z.step      = RemediationStep.none;
        z.isAtRisk  = false;
        physicalCount = math.max(0, physicalCount - 1);
        soilHealth    = math.max(0, soilHealth - 5.0);
      }
    }
    riskZones.clear();
    notifyListeners();
  }

  // ── Contamination surge ────────────────────────────────────────────────────
  void _triggerSurge() {
    soilHealth = math.max(
        0, soilHealth - (_zonesSinceLastSurge >= 2 ? 3.0 : 8.0));
    ecoPoints  = math.max(0, ecoPoints - 5);
    _zonesSinceLastSurge = 0;
    surgePending = true; surgePulse = 1.0;
    notifyListeners();
  }

  // ── Eco-guide hints ────────────────────────────────────────────────────────
  void _checkHints() {
    if (_hintCooldown > 0 || ecoGuideTimer > 0) return;
    if (gamePhase == 3 && _idleTimer > 4.5) {
      ecoGuideHint =
          '🔬 Select the scan depth matching the zone\'s layer band, fly close, then tap 📡 SCAN!';
      ecoGuideTimer = 3.5; _hintCooldown = 12; _idleTimer = 0;
    } else if (gamePhase == 4) {
      if (wrongTools >= 3 && wrongTools > correctTools) {
        ecoGuideHint =
            '💡 Step ① needs Physical tools (Boom, pH, Excavation, Wash, Till). Step ② needs Biological agents!';
        ecoGuideTimer = 3.5; _hintCooldown = 15;
      } else if (criticalAlerts.isNotEmpty && _idleTimer > 3.0) {
        ecoGuideHint =
            '⚡ Critical contamination zone! Treat it fast to earn +15 bonus pts and stop spreading!';
        ecoGuideTimer = 3.5; _hintCooldown = 8;
      }
    }
    notifyListeners();
  }

  // ── End level ──────────────────────────────────────────────────────────────
  void _endLevel() {
    if (levelDone) return;
    levelDone = true; pauseEngine();

    final meetsMin = remediatedCount >= kMinZonesRequired;

    SoilPollutionResult.current = SoilPollutionResult(
      zonesRemediated:     remediatedCount,
      zonesPhysical:       physicalCount,
      correctTools:        correctTools,
      wrongTools:          wrongTools,
      ecoPoints:           ecoPoints,
      soilHealth:          soilHealth,
      soilGuardianBadge:   soilHealth >= _targetHealth,
      scannedZones:        scannedCount,
      maxCombo:            maxCombo,
      scanStreakBonus:      totalScanStreak,
      ecoDiscoveriesFound: ecoDiscoveriesFound,
      timeBonusCollected:  timeBonusCollected,
      criticalSaves:       criticalSaves,
      zonesExpanded:       zonesExpanded,
      resupplyTriggered:   resupplyTriggered,
      meetsMinimum:        meetsMin,
      minimumRequired:     kMinZonesRequired,
    );

    // Remove every active in-game overlay before the results screen appears.
    overlays
      ..remove('reactionFx')
      ..remove('scanResult')
      ..remove('leachAlert')
      ..remove('criticalAlert')
      ..remove('ecoDiscovery')
      ..remove('resupply')
      ..remove('wrongLayer')
      ..remove('toolSelect');

    // Always open the in-game results overlay (SoilResultsOverlay).
    // • meetsMinimum == true  → SoilResultsOverlay shows "LEVEL COMPLETE ✅"
    //   button which calls game.navigateToComplete()  →  onLevelComplete()
    //   →  host screen pushes Level5CompleteScreen.
    // • meetsMinimum == false → SoilResultsOverlay shows "TRY AGAIN" only.
    overlays.add('results');
    notifyListeners();
  }

  // ── Input ──────────────────────────────────────────────────────────────────
  void setUpKey(bool v)    { isUp    = v; if (v) gameStarted = true; _idleTimer = 0; }
  void setDownKey(bool v)  { isDown  = v; if (v) gameStarted = true; _idleTimer = 0; }
  void setLeftKey(bool v)  { isLeft  = v; if (v) gameStarted = true; _idleTimer = 0; }
  void setRightKey(bool v) { isRight = v; if (v) gameStarted = true; _idleTimer = 0; }

  void selectTool(RemediationTool t) {
    selectedTool = t;
    notifyListeners();
    if (toolSelectorOpen) applyTool();
  }

  void selectLayer(ScanLayerType l) {
    selectedLayer = l;
    notifyListeners();
  }

  // ── Reaction FX ───────────────────────────────────────────────────────────
  void _triggerReaction(bool correct, {bool inRange = true}) {
    reactionActive  = true; reactionCorrect = correct;
    reactionPhase   = gamePhase; reactionInRange = inRange;
    reactionTimer   = 1.3;
    overlays.add('reactionFx');
  }

  // ── Camera follow ─────────────────────────────────────────────────────────
  void _updateCamera(double dt) {
    final sw    = size.x; final sh = size.y;
    final edgeW = sw * kEdgeFraction;
    final edgeH = sh * kEdgeFraction;
    final sx = dronePos.x - camX;
    final sy = dronePos.y - camY;
    double tx = _targetCamX; double ty = _targetCamY;
    if (sx < edgeW) {
      tx = dronePos.x - edgeW;
    } else if (sx > sw - edgeW) {tx = dronePos.x - (sw - edgeW);}
    if (sy < edgeH) {
      ty = dronePos.y - edgeH;
    } else if (sy > sh - edgeH) {ty = dronePos.y - (sh - edgeH);}
    _targetCamX = tx.clamp(0.0, worldW - sw);
    _targetCamY = ty.clamp(0.0, worldH - sh);
    camX += (_targetCamX - camX) * kCameraEase * dt;
    camY += (_targetCamY - camY) * kCameraEase * dt;
    edgeHintLeft   = (sx < edgeW * 1.5 && camX > 1)
        ? (1.0 - sx / (edgeW * 1.5)).clamp(0, 1) : 0;
    edgeHintRight  = (sx > sw - edgeW * 1.5 && camX < worldW - sw - 1)
        ? ((sx - (sw - edgeW * 1.5)) / (edgeW * 1.5)).clamp(0, 1) : 0;
    edgeHintTop    = (sy < edgeH * 1.5 && camY > 1)
        ? (1.0 - sy / (edgeH * 1.5)).clamp(0, 1) : 0;
    edgeHintBottom = (sy > sh - edgeH * 1.5 && camY < worldH - sh - 1)
        ? ((sy - (sh - edgeH * 1.5)) / (edgeH * 1.5)).clamp(0, 1) : 0;
  }

  // ── Main update loop ───────────────────────────────────────────────────────
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
        reactionActive = false; overlays.remove('reactionFx');
      }
    }
    if (scanActive) {
      scanRadius += dt * 230;
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
    if (wrongLayerTimer > 0) {
      wrongLayerTimer -= dt;
      if (wrongLayerTimer <= 0) {
        wrongLayerActive = false; overlays.remove('wrongLayer');
      }
    }
    if (scanResultActive) {
      scanResultTimer -= dt;
      if (scanResultTimer <= 0) dismissScanResult();
    }
    if (discoveryDisplayTimer > 0) {
      discoveryDisplayTimer -= dt;
      if (discoveryDisplayTimer <= 0) overlays.remove('ecoDiscovery');
    }
    if (resupplyTimer > 0) {
      resupplyTimer -= dt;
      if (resupplyTimer <= 0) {
        resupplyActive = false; overlays.remove('resupply');
      }
    }
    if (scanStreakTimer > 0) {
      scanStreakTimer -= dt;
      if (scanStreakTimer <= 0) scanStreak = 0;
    }

    if (!gameStarted || levelDone) { notifyListeners(); return; }

    // ── Drone movement ─────────────────────────────────────────────────────
    double vx = 0, vy = 0;
    if (isLeft)  vx -= 1;
    if (isRight) vx += 1;
    if (isUp)    vy -= 1;
    if (isDown)  vy += 1;
    final moving = vx != 0 || vy != 0;
    if (!moving) {
      _idleTimer += dt;
    } else {
      _idleTimer = 0;
    }
    if (_idleTimer > 4.5) _checkHints();

    // ── Leach-intensity under drone ────────────────────────────────────────
    leachIntensity = 0;
    for (final zone in leachZones) {
      final d = (zone.center - dronePos).length;
      if (d < zone.radius) {
        final str = 1.0 - (d / zone.radius);
        leachIntensity = math.max(leachIntensity, str * zone.leachRate);
      }
    }

    dronePos.x =
        (dronePos.x + vx * _droneSpeed * dt).clamp(30, worldW - 30);
    dronePos.y =
        (dronePos.y + vy * _droneSpeed * dt).clamp(40, worldH * 0.86);

    _updateCamera(dt);

    _refillTimer += dt;
    if (_refillTimer >= _refillInterval) {
      _refillTimer = 0;
      _tryRefillZones();
    }

    _leachChangeTimer += dt;
    if (_leachChangeTimer >= _leachPeriod) {
      _leachChangeTimer = 0;
      final rng = math.Random();
      for (final zone in leachZones) {
        zone.leachRate = 0.3 + rng.nextDouble() * 0.7;
      }
    }

    inChemicalHaze = chemicalHazes
        .any((h) => (h.hazePos - dronePos).length < h.radius + 18);

    // ── Phase 3: scan lock ─────────────────────────────────────────────────
    if (gamePhase == 3) {
      SoilContaminationZone? nearest; double nearestD = _scanRange;
      for (final z in zones) {
        if (z.isScanned) continue;
        final d = (z.zonePos - dronePos).length;
        if (d < nearestD) { nearestD = d; nearest = z; }
      }
      nearestScanTarget = nearest;

      if (scanLockActive && activeScanZone != null) {
        final lockDist =
            (activeScanZone!.zonePos - dronePos).length;
        if (lockDist > _scanRange * 1.15) {
          scanLockActive = false; _scanLockTimer = 0;
          activeScanZone = null;
          reactionMsg = '📡 Scan cancelled - too far!';
          _triggerReaction(false, inRange: false);
        } else {
          final rate = inChemicalHaze ? 0.45 : 1.0;
          _scanLockTimer += dt * rate;
          scanHoldTime    = _scanLockTimer;
          if (_scanLockTimer >= _scanDuration) {
            _completeScanZone(activeScanZone!);
          }
        }
      } else if (!scanLockActive) {
        activeScanZone = null;
        scanHoldTime   = 0;
      }
    }

    // ── Phase 4: events ────────────────────────────────────────────────────
    if (gamePhase == 4) {
      if (comboCount > 0) {
        comboTimer -= dt;
        if (comboTimer <= 0) _breakCombo();
      }
      if (comboFlashTimer > 0) {
        comboFlashTimer -= dt;
        if (comboFlashTimer <= 0) showComboFlash = false;
      }

      _leachingTimer -= dt;
      if (_leachingTimer <= 0 && !leachingWarning && !leachingActive) {
        _leachingTimer =
            38.0 + math.Random().nextDouble() * 22.0;
        _triggerLeachingWarning();
      }
      if (leachingWarning) {
        leachingWarningCd -= dt;
        if (leachingWarningCd <= 0) {
          leachingWarning = false; _triggerLeachingActive();
        }
      }
      if (leachingActive) {
        _leachingActiveCd -= dt;
        leachingIntensity =
            (_leachingActiveCd / 9.0).clamp(0.0, 1.0);
        if (_leachingActiveCd <= 0) _endLeachingActive();
        for (final z
            in List<SoilContaminationZone>.from(riskZones)) {
          if (z.isAtRisk) {
            z.riskTimer -= dt;
            if (z.riskTimer <= 0 && !z.isRemediated) {
              z.isAtRisk = false;
              riskZones.remove(z);
              if (z.step == RemediationStep.physical) {
                z.step    = RemediationStep.none;
                physicalCount =
                    math.max(0, physicalCount - 1);
                soilHealth =
                    math.max(0, soilHealth - 5.0);
              }
            }
          }
        }
      }

      _surgeTimer -= dt;
      if (_surgeTimer <= 0) {
        _surgeTimer =
            22.0 + math.Random().nextDouble() * 14.0;
        _triggerSurge();
      }

      _criticalAlertTimer -= dt;
      if (_criticalAlertTimer <= 0 && criticalAlerts.length < 2) {
        _criticalAlertTimer =
            42.0 + math.Random().nextDouble() * 20.0;
        _spawnCriticalAlert();
      }
      for (final alert
          in List<CriticalContaminationAlert>.from(criticalAlerts)) {
        if (!alert.handled) {
          alert.timeLeft -= dt;
          if (alert.timeLeft <= 0) _expireCriticalAlert(alert);
        }
      }

      _spreadCheckTimer -= dt;
      if (_spreadCheckTimer <= 0) {
        _spreadCheckTimer = 1.0;
        _checkZoneExpansion();
      }

      _leachStripTimer -= dt;
      if (_leachStripTimer <= 0) {
        _leachStripTimer =
            20.0 + math.Random().nextDouble() * 12.0;
        _applyLeachStrip();
      }
    }

    notifyListeners();
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  SOIL CROSS-SECTION RENDERER
// ══════════════════════════════════════════════════════════════════════════════
class SoilCrossSectionRenderer extends Component {
  final SoilPollutionGame game;
  double _t = 0;

  late final List<_ContamSeepChannel> _seepChannels;
  late final List<_RockFragment>      _rocks;
  late final List<_SoilCrackNet>      _crackNets;
  late final List<_RootFragment>      _roots;
  late final List<_MineralVein>       _veins;
  late final List<_IndustrialDebris>  _debris;
  late final List<_ChemicalMote>      _motes;

  SoilCrossSectionRenderer({required this.game});

  @override
  void onLoad() { _initTerrain(); }

  void _initTerrain() {
    final w   = game.worldW;
    final h   = game.worldH;
    final rng = math.Random(77);

    _seepChannels = [
      _ContamSeepChannel(sx: w * 0.22, sy: h * 0.08, length: h * 0.55, angle: 1.55, seed: 11),
      _ContamSeepChannel(sx: w * 0.55, sy: h * 0.06, length: h * 0.60, angle: 1.62, seed: 29),
      _ContamSeepChannel(sx: w * 0.78, sy: h * 0.10, length: h * 0.48, angle: 1.50, seed: 47),
      _ContamSeepChannel(sx: w * 0.10, sy: h * 0.12, length: h * 0.42, angle: 1.48, seed: 63),
      _ContamSeepChannel(sx: w * 0.40, sy: h * 0.06, length: h * 0.52, angle: 1.58, seed: 81),
    ];

    _rocks = List.generate(20, (i) => _RockFragment(
      x:    rng.nextDouble() * w,
      y:    h * 0.45 + rng.nextDouble() * h * 0.38,
      size: 6.0 + rng.nextDouble() * 22.0,
      seed: i * 17,
    ));

    _crackNets = List.generate(10, (i) => _SoilCrackNet(
      cx:     w * (0.06 + rng.nextDouble() * 0.88),
      cy:     h * (0.06 + rng.nextDouble() * 0.30),
      radius: 35.0 + rng.nextDouble() * 48.0,
      seed:   i * 37 + 3,
    ));

    _roots = List.generate(18, (i) => _RootFragment(
      x:     rng.nextDouble() * w,
      y:     h * 0.08 + rng.nextDouble() * h * 0.60,
      depth: 40.0 + rng.nextDouble() * 90.0,
      lean:  rng.nextDouble() * 0.8 - 0.4,
      seed:  i * 29 + 5,
    ));

    _veins = [
      _MineralVein(x: w * 0.18, y: h * 0.72, length: 80, angle: 0.3),
      _MineralVein(x: w * 0.45, y: h * 0.78, length: 65, angle: -0.2),
      _MineralVein(x: w * 0.72, y: h * 0.70, length: 90, angle: 0.5),
      _MineralVein(x: w * 0.88, y: h * 0.75, length: 55, angle: -0.4),
    ];

    _debris = List.generate(8, (i) => _IndustrialDebris(
      x:    rng.nextDouble() * w,
      y:    h * 0.06 + rng.nextDouble() * h * 0.25,
      type: i % 3,
      seed: i * 43 + 7,
    ));

    _motes = List.generate(55, (i) => _ChemicalMote(
      x:        rng.nextDouble() * w,
      y:        h * 0.05 + rng.nextDouble() * h * 0.78,
      speed:    7.0  + rng.nextDouble() * 16.0,
      drift:    rng.nextDouble() * 2 - 1,
      size:     1.0  + rng.nextDouble() * 2.8,
      seed:     i * 7 + 3,
      colorIdx: rng.nextInt(5),
    ));
  }

  @override
  void update(double dt) {
    _t += dt * 0.25;
    for (final m in _motes) {
      m.x += m.drift * dt * 10;
      m.y -= m.speed * dt * 0.35;
      if (m.y < game.worldH * 0.04) m.y = game.worldH * 0.82;
      if (m.x < 0) m.x = game.worldW;
      if (m.x > game.worldW) m.x = 0;
    }
  }

  @override
  void render(Canvas canvas) {
    final w  = game.worldW; final h  = game.worldH;
    final sw = game.size.x; final sh = game.size.y;

    canvas.save();
    canvas.translate(-game.camX, -game.camY);

    _drawContaminatedSky(canvas, w, h);
    _drawSoilLayers(canvas, w, h);
    _drawLayerLabels(canvas, w, h);
    _drawSoilCrackNetworks(canvas, w, h);
    _drawRootFragments(canvas, w, h);
    _drawSeepageChannels(canvas, w, h);
    _drawRockFragments(canvas, w, h);
    _drawMineralVeins(canvas, w, h);
    _drawIndustrialDebris(canvas, w, h);
    _drawContaminationStaining(canvas, w, h);
    _drawChemicalMotes(canvas, w, h);
    _drawGroundwaterTable(canvas, w, h);
    _drawFooterStrip(canvas, w, h);

    final hr = (game.soilHealth / 100.0).clamp(0.0, 1.0);
    if (hr > 0.15) {
      canvas.drawRect(
          Rect.fromLTWH(0, 0, w, h),
          Paint()
            ..color = const Color(0xFF1B5E20)
                .withValues(alpha: hr * 0.07)
            ..maskFilter =
                const MaskFilter.blur(BlurStyle.normal, 40));
    }

    final cr = (1.0 - game.soilHealth / 100.0).clamp(0.0, 1.0);
    canvas.drawRect(
        Rect.fromLTWH(0, 0, w, h),
        Paint()
          ..color = const Color(0xFF6D4C41)
              .withValues(alpha: cr * 0.07)
          ..maskFilter =
              const MaskFilter.blur(BlurStyle.normal, 30));

    if (game.surgePulse > 0) {
      canvas.drawRect(
          Rect.fromLTWH(0, 0, w, h),
          Paint()
            ..color = const Color(0xFF7B1FA2)
                .withValues(alpha: game.surgePulse * 0.18));
    }

    if (game.leachingIntensity > 0) _drawAcidLeaching(canvas, w, h);

    canvas.restore();
    _drawEdgeHints(canvas, sw, sh);
  }

  void _drawEdgeHints(Canvas canvas, double sw, double sh) {
    const hintColor = Color(0xFF69F0AE);
    void v(double alpha, Alignment from, Alignment to) {
      if (alpha < 0.01) return;
      canvas.drawRect(
          Rect.fromLTWH(0, 0, sw, sh),
          Paint()
            ..shader = ui.Gradient.linear(
              Offset(sw * (from.x + 1) / 2, sh * (from.y + 1) / 2),
              Offset(sw * (to.x + 1) / 2,   sh * (to.y + 1) / 2),
              [
                hintColor.withValues(alpha: alpha * 0.35),
                Colors.transparent,
              ],
            ));
    }
    v(game.edgeHintLeft,   Alignment.centerLeft,   Alignment.center);
    v(game.edgeHintRight,  Alignment.centerRight,  Alignment.center);
    v(game.edgeHintTop,    Alignment.topCenter,    Alignment.center);
    v(game.edgeHintBottom, Alignment.bottomCenter, Alignment.center);
  }

  void _drawContaminatedSky(Canvas canvas, double w, double h) {
    canvas.drawRect(
        Rect.fromLTWH(0, 0, w, h * 0.08),
        Paint()
          ..shader = ui.Gradient.linear(
            Offset.zero, Offset(0, h * 0.08),
            [const Color(0xFF1A1006), const Color(0xFF120C04)],
          ));
    canvas.drawRect(
        Rect.fromLTWH(0, h * 0.03, w, h * 0.05),
        Paint()
          ..color = const Color(0xFF558B2F).withValues(
              alpha: 0.04 + math.sin(_t * 0.6) * 0.02)
          ..maskFilter =
              const MaskFilter.blur(BlurStyle.normal, 18));
  }

  void _drawSoilLayers(Canvas canvas, double w, double h) {
    canvas.drawRect(
        Rect.fromLTWH(0, h * 0.08, w, h * 0.27),
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(0, h * 0.08), Offset(0, h * 0.35),
            [const Color(0xFF1C0E06), const Color(0xFF241408)],
          ));
    canvas.drawRect(
        Rect.fromLTWH(0, h * 0.35, w, h * 0.28),
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(0, h * 0.35), Offset(0, h * 0.63),
            [const Color(0xFF150E04), const Color(0xFF1A1206)],
          ));
    canvas.drawRect(
        Rect.fromLTWH(0, h * 0.63, w, h * 0.23),
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(0, h * 0.63), Offset(0, h * 0.86),
            [const Color(0xFF0C0A06), const Color(0xFF0A0804)],
          ));
    for (final ry in [0.35, 0.63]) {
      canvas.drawLine(
          Offset(0, h * ry), Offset(w, h * ry),
          Paint()
            ..color = const Color(0xFF3A1E08)
                .withValues(alpha: 0.55)
            ..strokeWidth = 6);
    }
  }

  void _drawLayerLabels(Canvas canvas, double w, double h) {
    final layers = [
      (0.08, '🟤  TOP LAYER - Topsoil & Organic Horizon', const Color(0xFFBCAAA4)),
      (0.35, '🟠  MID LAYER - Subsoil & B-Horizon',       const Color(0xFFFF6D00)),
      (0.63, '⬛  DEEP LAYER - C-Horizon & Bedrock',       const Color(0xFF9C64FB)),
    ];
    for (final (ry, label, color) in layers) {
      final tp = TextPainter(
        text: TextSpan(
            text: label,
            style: TextStyle(
                color: color.withValues(alpha: 0.32),
                fontSize: 8.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.9)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(8, h * ry + 7));
    }
  }

  void _drawSoilCrackNetworks(Canvas canvas, double w, double h) {
    for (final net in _crackNets) {
      final rng = math.Random(net.seed);
      final paint = Paint()
        ..color = const Color(0xFF3D2010).withValues(alpha: 0.42)
        ..strokeWidth = 0.8
        ..strokeCap = StrokeCap.round;
      final pts = List.generate(6, (i) {
        final angle =
            (i / 6) * math.pi * 2 + rng.nextDouble() * 0.5;
        final r = net.radius * (0.5 + rng.nextDouble() * 0.5);
        return Offset(
            net.cx + math.cos(angle) * r,
            net.cy + math.sin(angle) * r);
      });
      for (final pt in pts) {
        canvas.drawLine(Offset(net.cx, net.cy), pt, paint);
        for (int b = 0; b < 2; b++) {
          final mid = Offset(
              (net.cx + pt.dx) / 2 + rng.nextDouble() * 8 - 4,
              (net.cy + pt.dy) / 2 + rng.nextDouble() * 8 - 4);
          canvas.drawLine(
              mid,
              Offset(mid.dx + rng.nextDouble() * 15 - 7.5,
                  mid.dy + rng.nextDouble() * 15 - 7.5),
              paint
                ..color = const Color(0xFF3D2010)
                    .withValues(alpha: 0.22));
        }
      }
    }
  }

  void _drawRootFragments(Canvas canvas, double w, double h) {
    for (final root in _roots) {
      final rng = math.Random(root.seed);
      final paint = Paint()
        ..color = const Color(0xFF2A1808).withValues(alpha: 0.55)
        ..strokeWidth = 1.5 + rng.nextDouble() * 1.2
        ..strokeCap = StrokeCap.round;
      final ex = root.x + math.sin(root.lean) * root.depth;
      final ey = root.y + root.depth;
      canvas.drawLine(
          Offset(root.x, root.y), Offset(ex, ey), paint);
      for (int b = 0; b < 3; b++) {
        final t  = 0.25 + b * 0.25;
        final bx = root.x + math.sin(root.lean) * root.depth * t;
        final by = root.y + root.depth * t;
        final ba = root.lean +
            (rng.nextBool() ? 0.7 : -0.7) +
            rng.nextDouble() * 0.4;
        final bl = root.depth * (0.10 + rng.nextDouble() * 0.18);
        canvas.drawLine(
            Offset(bx, by),
            Offset(bx + math.cos(ba) * bl,
                by + math.sin(ba) * bl),
            paint
              ..strokeWidth =
                  0.8 + rng.nextDouble() * 0.7);
      }
    }
  }

  void _drawSeepageChannels(Canvas canvas, double w, double h) {
    for (final ch in _seepChannels) {
      final rng  = math.Random(ch.seed);
      final path = Path();
      path.moveTo(ch.sx, ch.sy);
      double cx = ch.sx, cy = ch.sy;
      for (int s = 0; s < 10; s++) {
        final nx = cx +
            math.cos(ch.angle + math.sin(s * 1.3) * 0.3) *
                ch.length / 10;
        final ny = cy +
            math.sin(ch.angle + math.cos(s * 0.9) * 0.2) *
                ch.length / 10;
        path.lineTo(nx, ny);
        cx = nx; cy = ny;
      }
      final seepColor = ch.seed % 3 == 0
          ? const Color(0xFF6D4C41)
          : ch.seed % 3 == 1
              ? const Color(0xFF4A148C)
              : const Color(0xFF1B5E20);
      canvas.drawPath(
          path,
          Paint()
            ..color = seepColor.withValues(alpha: 0.35)
            ..strokeWidth = 1.6 + rng.nextDouble() * 2.2
            ..strokeCap = StrokeCap.round
            ..style = PaintingStyle.stroke);
    }
  }

  void _drawRockFragments(Canvas canvas, double w, double h) {
    for (final rock in _rocks) {
      final rng = math.Random(rock.seed);
      final cx = rock.x; final cy = rock.y; final s = rock.size;
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset(cx + s * 0.2, cy + s * 0.4),
              width: s * 1.8, height: s * 0.6),
          Paint()
            ..color = Colors.black.withValues(alpha: 0.22)
            ..maskFilter =
                const MaskFilter.blur(BlurStyle.normal, 4));
      final path  = Path();
      final sides = 5 + rng.nextInt(3);
      for (int i = 0; i < sides; i++) {
        final angle =
            (i / sides) * math.pi * 2 - math.pi / 2;
        final r  = s * (0.6 + rng.nextDouble() * 0.4);
        final px = cx + math.cos(angle) * r;
        final py = cy + math.sin(angle) * r * 0.65;
        i == 0 ? path.moveTo(px, py) : path.lineTo(px, py);
      }
      path.close();
      canvas.drawPath(
          path,
          Paint()
            ..color = Color.lerp(
                const Color(0xFF2C1E0A),
                const Color(0xFF3A2810),
                rng.nextDouble())!);
    }
  }

  void _drawMineralVeins(Canvas canvas, double w, double h) {
    for (final vein in _veins) {
      final path = Path();
      path.moveTo(vein.x, vein.y);
      path.lineTo(vein.x + math.cos(vein.angle) * vein.length,
          vein.y + math.sin(vein.angle) * vein.length);
      canvas.drawPath(
          path,
          Paint()
            ..color = const Color(0xFF7B1FA2)
                .withValues(alpha: 0.18)
            ..strokeWidth = 2.2
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round);
    }
  }

  void _drawIndustrialDebris(Canvas canvas, double w, double h) {
    for (final d in _debris) {
      final rng = math.Random(d.seed);
      switch (d.type) {
        case 0:
          canvas.drawOval(
              Rect.fromCenter(
                  center: Offset(d.x, d.y),
                  width: 14, height: 20),
              Paint()
                ..color = const Color(0xFF2A1008)
                    .withValues(alpha: 0.55)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 2.0);
          canvas.drawLine(
              Offset(d.x - 7, d.y), Offset(d.x + 7, d.y),
              Paint()
                ..color = const Color(0xFF2A1008)
                    .withValues(alpha: 0.38)
                ..strokeWidth = 1.0);
        case 1:
          canvas.drawLine(
              Offset(d.x - 12, d.y), Offset(d.x + 12, d.y),
              Paint()
                ..color = const Color(0xFF3A2010)
                    .withValues(alpha: 0.48)
                ..strokeWidth = 4.0
                ..strokeCap = StrokeCap.round);
        default:
          canvas.drawCircle(
              Offset(d.x, d.y),
              7.0 + rng.nextDouble() * 6,
              Paint()
                ..color = const Color(0xFF424242)
                    .withValues(alpha: 0.30)
                ..maskFilter =
                    const MaskFilter.blur(BlurStyle.normal, 8));
      }
    }
  }

  void _drawContaminationStaining(
      Canvas canvas, double w, double h) {
    final rng   = math.Random(55);
    final paint = Paint()
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 200; i++) {
      final x     = rng.nextDouble() * w;
      final y     = rng.nextDouble() * h * 0.82;
      final alpha = 0.04 + rng.nextDouble() * 0.10;
      final stainColor = [
        const Color(0xFF424242), const Color(0xFFCDDC39),
        const Color(0xFF7B1FA2), const Color(0xFFFF6D00),
        const Color(0xFFBCAAA4),
      ][rng.nextInt(5)];
      paint.color = stainColor.withValues(alpha: alpha);
      canvas.drawCircle(
          Offset(x, y),
          0.8 + rng.nextDouble() * 2.2,
          paint);
    }
  }

  void _drawChemicalMotes(Canvas canvas, double w, double h) {
    final paint = Paint();
    final moteColors = [
      const Color(0xFF424242), const Color(0xFFCDDC39),
      const Color(0xFF7B1FA2), const Color(0xFFFF6D00),
      const Color(0xFFBCAAA4),
    ];
    for (final m in _motes) {
      final alpha = 0.03 +
          math.sin(_t * m.seed * 0.3 + m.x * 0.01) * 0.025;
      paint.color = moteColors[m.colorIdx]
          .withValues(alpha: alpha.clamp(0.01, 0.07));
      canvas.drawCircle(Offset(m.x, m.y), m.size, paint);
    }
  }

  void _drawGroundwaterTable(Canvas canvas, double w, double h) {
    final shimmer = 0.03 + math.sin(_t * 1.2) * 0.015;
    canvas.drawRect(
        Rect.fromLTWH(0, h * 0.78, w, 4),
        Paint()
          ..color = const Color(0xFF29B6F6)
              .withValues(alpha: shimmer)
          ..maskFilter =
              const MaskFilter.blur(BlurStyle.normal, 4));
    final tp = TextPainter(
      text: TextSpan(
          text: '💧  Groundwater Table',
          style: TextStyle(
              color: const Color(0xFF29B6F6)
                  .withValues(alpha: 0.22),
              fontSize: 7.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(8, h * 0.782));
  }

  void _drawFooterStrip(Canvas canvas, double w, double h) {
    canvas.drawRect(Rect.fromLTWH(0, h * 0.86, w, h * 0.14),
        Paint()..color = const Color(0xFF060402));
    canvas.drawLine(
        Offset(0, h * 0.86), Offset(w, h * 0.86),
        Paint()
          ..color = const Color(0xFF3A1E08)
              .withValues(alpha: 0.50)
          ..strokeWidth = 1.5);
  }

  void _drawAcidLeaching(Canvas canvas, double w, double h) {
    final alpha = game.leachingIntensity * 0.48;
    final rng   = math.Random(11);
    final paint = Paint()
      ..color = const Color(0xFFCDDC39).withValues(alpha: alpha)
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 80; i++) {
      final rx  = rng.nextDouble() * w;
      final ry  = rng.nextDouble() * h;
      final len = 8.0 + rng.nextDouble() * 16.0;
      final phase =
          ((_t * 4.0 + rng.nextDouble() * 6.0) % 1.0);
      final y = (ry + phase * h * 0.5) % h;
      canvas.drawLine(
          Offset(rx - len * 0.1, y),
          Offset(rx + len * 0.1, y + len),
          paint);
    }
    canvas.drawRect(
        Rect.fromLTWH(0, 0, w, h),
        Paint()
          ..color = const Color(0xFF827717).withValues(
              alpha: game.leachingIntensity * 0.07));
  }
}

// ── Terrain data classes ──────────────────────────────────────────────────────
class _ContamSeepChannel {
  final double sx, sy, length, angle; final int seed;
  const _ContamSeepChannel({
    required this.sx, required this.sy,
    required this.length, required this.angle, required this.seed,
  });
}

class _RockFragment {
  final double x, y, size; final int seed;
  const _RockFragment({
    required this.x, required this.y,
    required this.size, required this.seed,
  });
}

class _SoilCrackNet {
  final double cx, cy, radius; final int seed;
  const _SoilCrackNet({
    required this.cx, required this.cy,
    required this.radius, required this.seed,
  });
}

class _RootFragment {
  final double x, y, depth, lean; final int seed;
  const _RootFragment({
    required this.x, required this.y,
    required this.depth, required this.lean, required this.seed,
  });
}

class _MineralVein {
  final double x, y, length, angle;
  const _MineralVein({
    required this.x, required this.y,
    required this.length, required this.angle,
  });
}

class _IndustrialDebris {
  final double x, y; final int type, seed;
  const _IndustrialDebris({
    required this.x, required this.y,
    required this.type, required this.seed,
  });
}

class _ChemicalMote {
  double x, y;
  final double speed, drift, size, seed;
  final int    colorIdx;
  _ChemicalMote({
    required this.x, required this.y,
    required this.speed, required this.drift,
    required this.size, required int seed,
    required this.colorIdx,
  }) : seed = seed.toDouble();
}

// ══════════════════════════════════════════════════════════════════════════════
//  POLLUTION DEBRIS LAYER
// ══════════════════════════════════════════════════════════════════════════════
class PollutionDebrisLayer extends Component {
  final SoilPollutionGame game;
  double _t = 0;
  late final List<_SoilDebrisItem> _items;

  PollutionDebrisLayer({required this.game});

  @override
  void onLoad() {
    final rng = math.Random(123);
    final w = game.worldW; final h = game.worldH;
    _items = List.generate(10, (i) => _SoilDebrisItem(
      x:    rng.nextDouble() * w,
      y:    h * 0.08 + rng.nextDouble() * h * 0.45,
      type: rng.nextInt(3),
      seed: i * 31 + 5,
    ));
  }

  @override
  void update(double dt) => _t += dt;

  @override
  void render(Canvas canvas) {
    canvas.save();
    canvas.translate(-game.camX, -game.camY);
    for (final item in _items) {
      final rng   = math.Random(item.seed);
      final alpha =
          0.22 + math.sin(_t * 0.3 + item.x * 0.01) * 0.08;
      if (item.type == 0) {
        canvas.drawCircle(
            Offset(item.x, item.y),
            5.0 + rng.nextDouble() * 4,
            Paint()
              ..color = const Color(0xFF424242)
                  .withValues(alpha: alpha)
              ..maskFilter =
                  const MaskFilter.blur(BlurStyle.normal, 4));
      } else if (item.type == 1) {
        canvas.drawLine(
            Offset(item.x - 8, item.y),
            Offset(item.x + 8, item.y),
            Paint()
              ..color = const Color(0xFF3A2010)
                  .withValues(alpha: alpha * 0.8)
              ..strokeWidth = 2.5
              ..strokeCap = StrokeCap.round);
      } else {
        canvas.drawOval(
            Rect.fromCenter(
                center: Offset(item.x, item.y),
                width: 12, height: 6),
            Paint()
              ..color = const Color(0xFF6D4C41)
                  .withValues(alpha: alpha * 0.6)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.2);
      }
    }
    canvas.restore();
  }
}

class _SoilDebrisItem {
  final double x, y; final int type, seed;
  const _SoilDebrisItem({
    required this.x, required this.y,
    required this.type, required this.seed,
  });
}

// ══════════════════════════════════════════════════════════════════════════════
//  SOIL DRONE COMPONENT
// ══════════════════════════════════════════════════════════════════════════════
class SoilDroneComponent extends Component {
  final SoilPollutionGame game;
  double _t = 0;

  SoilDroneComponent({required this.game});

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
      final alpha =
          (1.0 - game.scanRadius / SoilPollutionGame._scanMaxRadius) *
              0.30;
      canvas.drawCircle(
          Offset(cx, cy),
          game.scanRadius,
          Paint()
            ..color = const Color(0xFFFFB300)
                .withValues(alpha: alpha)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5);
    }

    final rangeColor = game.gamePhase == 3
        ? const Color(0xFFFFB300) : const Color(0xFF69F0AE);
    final rangeR = game.gamePhase == 3
        ? SoilPollutionGame._scanRange
        : SoilPollutionGame._applyRange;
    canvas.drawCircle(
        Offset(cx, cy),
        rangeR,
        Paint()
          ..color = rangeColor.withValues(alpha: 0.065)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2);

    if (game.gamePhase == 3) {
      final dashPaint = Paint()
        ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..strokeCap = StrokeCap.round;
      const double r       = SoilPollutionGame._hoverRange;
      const int    segments = 28;
      const double dashFrac = 0.55;
      for (int seg = 0; seg < segments; seg++) {
        final startAngle =
            (seg / segments) * math.pi * 2 + _t * 0.65;
        final sweep =
            (math.pi * 2 / segments) * dashFrac;
        canvas.drawArc(
            Rect.fromCenter(
                center: Offset(cx, cy),
                width: r * 2, height: r * 2),
            startAngle, sweep, false, dashPaint);
      }
    }

    if (game.gamePhase == 3 && game.activeScanZone != null) {
      final prog = game.scanHoldProgress;
      canvas.drawCircle(
          Offset(cx, cy),
          12 + prog * 8,
          Paint()
            ..color = const Color(0xFFFFB300)
                .withValues(alpha: prog * 0.30)
            ..maskFilter =
                const MaskFilter.blur(BlurStyle.normal, 8));
    }

    if (game.inChemicalHaze) {
      canvas.drawCircle(
          Offset(cx, cy), 42,
          Paint()
            ..color = const Color(0xFF558B2F)
                .withValues(alpha: 0.20)
            ..maskFilter =
                const MaskFilter.blur(BlurStyle.normal, 18));
    }

    if (game.leachIntensity > 0.4) {
      canvas.drawCircle(
          Offset(cx, cy),
          38 + math.sin(_t * 5) * 4,
          Paint()
            ..color = const Color(0xFFCDDC39)
                .withValues(alpha: game.leachIntensity * 0.18)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0);
    }

    canvas.save();
    canvas.translate(cx, cy);

    // Shadow
    canvas.drawOval(
        Rect.fromCenter(
            center: const Offset(0, 15),
            width: 38, height: 9),
        Paint()..color = Colors.black.withValues(alpha: 0.28));

    // Arms
    final armP = Paint()
      ..color = const Color(0xFF3A2810)
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;
    for (final (dx, dy) in [(-1, -1), (1, -1), (-1, 1), (1, 1)]) {
      canvas.drawLine(
          Offset(dx * 8.0, dy * 8.0),
          Offset(dx * 22.0, dy * 22.0),
          armP);
    }

    // Propellers
    for (final (px, py) in [
      (-22.0, -22.0), (22.0, -22.0),
      (-22.0,  22.0), (22.0,  22.0),
    ]) {
      canvas.save();
      canvas.translate(px, py);
      canvas.rotate(_t * 13);
      final pP = Paint()
        ..color = const Color(0xFFFFB300).withValues(alpha: 0.55)
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(const Offset(-8, 0), const Offset(8, 0), pP);
      canvas.drawLine(const Offset(0, -8), const Offset(0, 8), pP);
      canvas.restore();
    }

    // Body
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(-13, -9, 26, 18),
            const Radius.circular(5)),
        Paint()..color = const Color(0xFF2A1C0A));

    // Core glow
    final glowColor = game.gamePhase == 3
        ? const Color(0xFFFFB300) : const Color(0xFF69F0AE);
    final glowBright = game.gamePhase == 3 && game.activeScanZone != null
        ? 0.95 : 0.72 + math.sin(_t * 4) * 0.22;
    canvas.drawCircle(
        Offset.zero, 7.0,
        Paint()
          ..color = glowColor.withValues(alpha: glowBright)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7));
    canvas.drawCircle(
        Offset.zero, 3.5,
        Paint()..color = Colors.white.withValues(alpha: 0.95));

    // Phase icon
    final tp = TextPainter(
      text: TextSpan(
          text: game.gamePhase == 3 ? '🔬' : '🌱',
          style: const TextStyle(fontSize: 8)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(-tp.width / 2, 12 - tp.height / 2));

    canvas.restore();
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  SOIL CONTAMINATION ZONE COMPONENT
// ══════════════════════════════════════════════════════════════════════════════
class SoilContaminationZone extends Component {
  final SoilPollutionGame game;
  final SoilPollutantType type;
  final ScanLayerType     requiredLayer;
  final bool              isChildZone;
  double hx, hy;
  final int seed;
  int scanVariant = 0;

  bool            isScanned     = false;
  RemediationStep step          = RemediationStep.none;
  bool            isAtRisk      = false;
  double          riskTimer     = 0;
  bool            isCritical    = false;
  bool            leachStripped = false;
  bool            triggerSparkle = false;
  double          sparkleTimer  = 0;
  double          _t            = 0;

  bool get isRemediated => step == RemediationStep.remediated;
  bool get isPhysical   => step == RemediationStep.physical;

  SoilContaminationZone({
    required this.game,
    required this.type,
    required double worldX,
    required double worldY,
    required this.requiredLayer,
    required this.seed,
    this.isChildZone = false,
  })  : hx = worldX,
        hy = worldY;

  Vector2 get zonePos => Vector2(hx, hy);

  static const _specs = {
    SoilPollutantType.oilSpill:    ('🛢️', 'Oil\nSpill',      Color(0xFF424242), 'HIGH'),
    SoilPollutantType.acidicSoil:  ('⚗️', 'Acidic\nSoil',    Color(0xFFCDDC39), 'MED'),
    SoilPollutantType.heavyMetals: ('⚙️', 'Heavy\nMetals',   Color(0xFF7B1FA2), 'SEVERE'),
    SoilPollutantType.pesticides:  ('🧪', 'Pesticide\nZone', Color(0xFFFF6D00), 'MED'),
    SoilPollutantType.compactSoil: ('🪨', 'Compact\nSoil',   Color(0xFFBCAAA4), 'LOW'),
  };

  @override
  void update(double dt) {
    _t += dt;
    if (leachStripped && _t > 4.0) leachStripped = false;
    if (triggerSparkle) { sparkleTimer = 2.0; triggerSparkle = false; }
    if (sparkleTimer > 0) sparkleTimer = math.max(0, sparkleTimer - dt);
  }

  @override
  void render(Canvas canvas) {
    canvas.save();
    canvas.translate(-game.camX, -game.camY);
    _renderWorld(canvas);
    canvas.restore();
  }

  void _renderWorld(Canvas canvas) {
    final spec  = _specs[type]!;
    final color = spec.$3;
    final pulse = 0.65 + math.sin(_t * 2.8) * 0.22;

    if (step == RemediationStep.remediated) {
      _drawRemediated(canvas); return;
    }

    _drawPollutantArt(canvas, color, pulse);
    if (sparkleTimer > 0) {
      _drawSparkle(canvas, const Color(0xFF69F0AE), sparkleTimer / 2.0);
    }

    if (game.gamePhase == 3 && game.activeScanZone == this) {
      _drawScanProgress(canvas, game.scanHoldProgress);
    }

    if (isCritical) {
      final urgency = math.sin(_t * 8).abs();
      final alert   = game.criticalAlerts.firstWhere(
          (a) => a.zone == this,
          orElse: () =>
              CriticalContaminationAlert(zone: this, timeLeft: 0));
      canvas.drawCircle(
          Offset(hx, hy),
          46 + urgency * 10,
          Paint()
            ..color = Colors.red
                .withValues(alpha: 0.20 + urgency * 0.14)
            ..maskFilter =
                const MaskFilter.blur(BlurStyle.normal, 10));
      canvas.drawCircle(
          Offset(hx, hy), 34,
          Paint()
            ..color = Colors.red.withValues(alpha: 0.72)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5);
      final tp = TextPainter(
        text: TextSpan(
            text: '⚡ ${alert.timeLeft.ceil()}s',
            style: const TextStyle(
                color: Colors.red,
                fontSize: 10,
                fontWeight: FontWeight.w900)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(hx - tp.width / 2, hy - 68));
    }

    if (leachStripped) {
      canvas.drawCircle(
          Offset(hx, hy), 38,
          Paint()
            ..color = const Color(0xFFCDDC39)
                .withValues(alpha: 0.20)
            ..maskFilter =
                const MaskFilter.blur(BlurStyle.normal, 10));
    }

    if (isAtRisk) {
      final urgency = math.sin(_t * 6).abs();
      canvas.drawCircle(
          Offset(hx, hy),
          44 + urgency * 8,
          Paint()
            ..color = const Color(0xFF29B6F6)
                .withValues(alpha: 0.16 + urgency * 0.10)
            ..maskFilter =
                const MaskFilter.blur(BlurStyle.normal, 10));
    }

    if (isScanned) {
      final idx = game.zones.indexOf(this);
      if (idx == game.timeBonusZoneIndex &&
          !game.timeBonusCollected) {
        canvas.drawCircle(
            Offset(hx + 22, hy - 22), 9,
            Paint()
              ..color = const Color(0xFFFFD700)
                  .withValues(alpha: 0.78)
              ..maskFilter =
                  const MaskFilter.blur(BlurStyle.normal, 4));
        final tp = TextPainter(
          text: const TextSpan(
              text: '⏱', style: TextStyle(fontSize: 10)),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas,
            Offset(hx + 22 - tp.width / 2, hy - 22 - tp.height / 2));
      }
      if (game.ecoDiscoveryIndices.contains(idx) &&
          !game.discoveredEcoZones.contains(idx)) {
        final shimmer =
            0.28 + math.sin(_t * 3.5) * 0.22;
        canvas.drawCircle(
            Offset(hx - 22, hy - 22), 6,
            Paint()
              ..color = const Color(0xFFE040FB)
                  .withValues(alpha: shimmer)
              ..maskFilter =
                  const MaskFilter.blur(BlurStyle.normal, 4));
      }
    }

    if (isScanned) {
      canvas.drawCircle(
          Offset(hx, hy),
          36 * pulse,
          Paint()
            ..color = color
                .withValues(alpha: 0.08 + pulse * 0.04)
            ..maskFilter =
                const MaskFilter.blur(BlurStyle.normal, 12));
      final ringColor = step == RemediationStep.physical
          ? const Color(0xFF29B6F6) : color;
      canvas.drawCircle(Offset(hx, hy), 32,
          Paint()
            ..color = ringColor.withValues(alpha: 0.12));
      canvas.drawCircle(
          Offset(hx, hy), 32,
          Paint()
            ..color = ringColor.withValues(alpha: 0.70)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.2);
      final badge =
          step == RemediationStep.physical ? 'STEP 2 ▶' : 'STEP 1 ▶';
      final badgeP = TextPainter(
        text: TextSpan(
            text: badge,
            style: TextStyle(
                color: ringColor,
                fontSize: 7.5,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.6)),
        textDirection: TextDirection.ltr,
      )..layout();
      badgeP.paint(canvas,
          Offset(hx - badgeP.width / 2, hy + 20));
      final labelP = TextPainter(
        text: TextSpan(
            text: spec.$2,
            style: TextStyle(
                color: color,
                fontSize: 8,
                fontWeight: FontWeight.w700,
                height: 1.2)),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout(maxWidth: 72);
      labelP.paint(canvas,
          Offset(hx - labelP.width / 2, hy - 52));
      if (isChildZone) {
        final tp = TextPainter(
          text: const TextSpan(
              text: '⚠️ Spread',
              style: TextStyle(
                  color: Color(0xFFFF6D00),
                  fontSize: 8,
                  fontWeight: FontWeight.bold)),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas,
            Offset(hx - tp.width / 2, hy - 62));
      }
      if (isAtRisk) {
        final tp = TextPainter(
          text: TextSpan(
              text: '💧 ${riskTimer.ceil()}s',
              style: const TextStyle(
                  color: Color(0xFF29B6F6),
                  fontSize: 9,
                  fontWeight: FontWeight.bold)),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas,
            Offset(hx - tp.width / 2, hy - 62));
      }
    } else {
      // Unscanned mystery zone
      canvas.drawCircle(
          Offset(hx, hy),
          30 * pulse,
          Paint()
            ..color = const Color(0xFFBCAAA4)
                .withValues(alpha: 0.07)
            ..maskFilter =
                const MaskFilter.blur(BlurStyle.normal, 9));
      canvas.drawCircle(Offset(hx, hy), 24,
          Paint()
            ..color = const Color(0xFFBCAAA4)
                .withValues(alpha: 0.10));
      canvas.drawCircle(
          Offset(hx, hy), 24,
          Paint()
            ..color = const Color(0xFFBCAAA4)
                .withValues(alpha: 0.55)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.8);
      final sA = 0.12 + math.sin(_t * 3.8) * 0.08;
      for (int i = -2; i <= 2; i++) {
        canvas.drawLine(
            Offset(hx - 16, hy + i * 4.5),
            Offset(hx + 16, hy + i * 4.5),
            Paint()
              ..color = const Color(0xFFBCAAA4)
                  .withValues(alpha: sA)
              ..strokeWidth = 0.7);
      }
      final layerHint = requiredLayer == ScanLayerType.topLayer
          ? '🟤'
          : requiredLayer == ScanLayerType.midLayer
              ? '🟠'
              : '⬛';
      final qp = TextPainter(
        text: TextSpan(
            text: '? $layerHint',
            style: const TextStyle(
                color: Color(0xFFBCAAA4),
                fontSize: 12,
                fontWeight: FontWeight.bold)),
        textDirection: TextDirection.ltr,
      )..layout();
      qp.paint(canvas,
          Offset(hx - qp.width / 2, hy - qp.height / 2));
    }
  }

  void _drawPollutantArt(
      Canvas canvas, Color color, double pulse) {
    final rng = math.Random(seed);
    switch (type) {
      case SoilPollutantType.oilSpill:
        _drawOilArt(canvas, rng, color);
      case SoilPollutantType.acidicSoil:
        _drawAcidArt(canvas, rng, color, pulse);
      case SoilPollutantType.heavyMetals:
        _drawMetalArt(canvas, rng, color);
      case SoilPollutantType.pesticides:
        _drawPesticideArt(canvas, rng, color, pulse);
      case SoilPollutantType.compactSoil:
        _drawCompactArt(canvas, rng, color);
    }
  }

  void _drawOilArt(
      Canvas canvas, math.Random rng, Color color) {
    canvas.drawCircle(
        Offset(hx, hy), 22,
        Paint()
          ..color = const Color(0xFF1A1A1A).withValues(alpha: 0.72)
          ..maskFilter =
              const MaskFilter.blur(BlurStyle.normal, 4));
    for (int i = 0; i < 5; i++) {
      final angle = (i / 5) * math.pi * 2;
      canvas.drawLine(
          Offset(hx, hy),
          Offset(
              hx + math.cos(angle) *
                  (14 + rng.nextDouble() * 8),
              hy + math.sin(angle) *
                  (14 + rng.nextDouble() * 8)),
          Paint()
            ..color = const Color(0xFF212121)
                .withValues(alpha: 0.65)
            ..strokeWidth = 3.5);
    }
    canvas.drawCircle(Offset(hx, hy), 8,
        Paint()
          ..color = const Color(0xFF424242)
              .withValues(alpha: 0.90));
  }

  void _drawAcidArt(
      Canvas canvas, math.Random rng, Color color, double pulse) {
    canvas.drawCircle(
        Offset(hx, hy), 24,
        Paint()
          ..color = const Color(0xFF827717).withValues(alpha: 0.30)
          ..maskFilter =
              const MaskFilter.blur(BlurStyle.normal, 8));
    for (int c = 0; c < 7; c++) {
      final angle = (c / 7) * math.pi * 2;
      final len   = 10 + rng.nextDouble() * 12;
      canvas.drawLine(
          Offset(hx, hy),
          Offset(hx + math.cos(angle) * len,
              hy + math.sin(angle) * len),
          Paint()
            ..color = const Color(0xFFCDDC39)
                .withValues(alpha: 0.50)
            ..strokeWidth = 1.2
            ..strokeCap = StrokeCap.round);
    }
    canvas.drawCircle(
        Offset(hx, hy),
        6 + pulse * 2,
        Paint()
          ..color = const Color(0xFFCDDC39)
              .withValues(alpha: 0.60)
          ..maskFilter =
              const MaskFilter.blur(BlurStyle.normal, 4));
  }

  void _drawMetalArt(
      Canvas canvas, math.Random rng, Color color) {
    final hex = Path();
    for (int i = 0; i < 6; i++) {
      final a  = i * math.pi / 3;
      final px = hx + math.cos(a) * 20;
      final py = hy + math.sin(a) * 20;
      i == 0 ? hex.moveTo(px, py) : hex.lineTo(px, py);
    }
    hex.close();
    canvas.drawPath(hex,
        Paint()
          ..color = const Color(0xFF4A148C)
              .withValues(alpha: 0.55));
    canvas.drawPath(
        hex,
        Paint()
          ..color = const Color(0xFF7B1FA2)
              .withValues(alpha: 0.85)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0);
    canvas.drawCircle(Offset(hx, hy), 8,
        Paint()
          ..color = const Color(0xFF9C27B0)
              .withValues(alpha: 0.80));
  }

  void _drawPesticideArt(
      Canvas canvas, math.Random rng, Color color, double pulse) {
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(hx, hy + 4),
            width: 56, height: 28),
        Paint()
          ..color = const Color(0xFFBF360C)
              .withValues(alpha: 0.38));
    for (int s = 0; s < 6; s++) {
      final sx = hx - 20 + s * 9.0;
      canvas.drawLine(
          Offset(sx, hy - 8),
          Offset(sx + rng.nextDouble() * 6 - 3, hy + 12),
          Paint()
            ..color = const Color(0xFFFF6D00)
                .withValues(alpha: 0.45)
            ..strokeWidth = 1.8
            ..strokeCap = StrokeCap.round);
    }
    canvas.drawCircle(
        Offset(hx, hy),
        7 + pulse * 2,
        Paint()
          ..color = const Color(0xFFFF6D00)
              .withValues(alpha: 0.55)
          ..maskFilter =
              const MaskFilter.blur(BlurStyle.normal, 5));
  }

  void _drawCompactArt(
      Canvas canvas, math.Random rng, Color color) {
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(hx, hy + 4),
            width: 60, height: 24),
        Paint()
          ..color = const Color(0xFF3E2723)
              .withValues(alpha: 0.52));
    for (int s = 0; s < 6; s++) {
      canvas.drawLine(
          Offset(hx - 22, hy - 6 + s * 4.5),
          Offset(hx + 22 + rng.nextDouble() * 6,
              hy - 6 + s * 4.5 + rng.nextDouble() * 2),
          Paint()
            ..color = const Color(0xFF5D4037)
                .withValues(alpha: 0.30)
            ..strokeWidth = 0.9);
    }
    for (int c = 0; c < 4; c++) {
      final angle = rng.nextDouble() * math.pi * 2;
      canvas.drawLine(
          Offset(hx, hy),
          Offset(hx + math.cos(angle) * 12,
              hy + math.sin(angle) * 10),
          Paint()
            ..color = const Color(0xFF4E342E)
                .withValues(alpha: 0.48)
            ..strokeWidth = 1.4
            ..strokeCap = StrokeCap.round);
    }
  }

  void _drawScanProgress(Canvas canvas, double progress) {
    const startAngle = -math.pi / 2;
    const full       = math.pi * 2;
    final beamAngle  = startAngle + full * progress;
    canvas.drawArc(
        Rect.fromCenter(
            center: Offset(hx, hy),
            width: 84, height: 84),
        beamAngle - 0.5, 0.5, false,
        Paint()
          ..color = const Color(0xFFFFB300)
              .withValues(alpha: 0.18)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10.0);
    canvas.drawLine(
        Offset(hx, hy),
        Offset(hx + math.cos(beamAngle) * 42,
            hy + math.sin(beamAngle) * 42),
        Paint()
          ..color = const Color(0xFFFFB300)
              .withValues(alpha: 0.30)
          ..strokeWidth = 2.0);
    canvas.drawCircle(
        Offset(hx, hy), 42,
        Paint()
          ..color = const Color(0xFFFFFFFF)
              .withValues(alpha: 0.07)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4.0);
    if (progress > 0) {
      canvas.drawArc(
          Rect.fromCenter(
              center: Offset(hx, hy),
              width: 84, height: 84),
          startAngle, full * progress, false,
          Paint()
            ..color = const Color(0xFFFFB300)
                .withValues(alpha: 0.88)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4.0
            ..strokeCap = StrokeCap.round);
    }
    final pct = (progress * 100).toInt();
    final tp  = TextPainter(
      text: TextSpan(
          text: '$pct%',
          style: const TextStyle(
              color: Color(0xFFFFB300),
              fontSize: 9,
              fontWeight: FontWeight.bold)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(hx - tp.width / 2, hy - 62));
    final al = TextPainter(
      text: TextSpan(
          text: game.inChemicalHaze ? '☣️ Slowed' : '📡 Scanning…',
          style: TextStyle(
              color: game.inChemicalHaze
                  ? const Color(0xFF558B2F)
                  : const Color(0xFFFFB300),
              fontSize: 8.5,
              fontWeight: FontWeight.w700)),
      textDirection: TextDirection.ltr,
    )..layout();
    al.paint(canvas, Offset(hx - al.width / 2, hy + 48));
  }

  void _drawSparkle(
      Canvas canvas, Color color, double progress) {
    final rng = math.Random(seed + 999);
    for (int i = 0; i < 12; i++) {
      final angle = (i / 12) * math.pi * 2;
      final r     = progress * 55.0;
      canvas.drawCircle(
          Offset(hx + math.cos(angle) * r,
              hy + math.sin(angle) * r),
          2.2 + rng.nextDouble() * 2.8,
          Paint()
            ..color = color.withValues(
                alpha: (progress * 0.85).clamp(0, 1)));
    }
  }

  void _drawRemediated(Canvas canvas) {
    if (sparkleTimer > 0) {
      _drawSparkle(
          canvas, const Color(0xFF69F0AE), sparkleTimer / 2.0);
    }
    canvas.drawCircle(Offset(hx, hy), 32,
        Paint()
          ..color = const Color(0xFF69F0AE)
              .withValues(alpha: 0.15));
    canvas.drawCircle(
        Offset(hx, hy), 32,
        Paint()
          ..color = const Color(0xFF69F0AE)
              .withValues(alpha: 0.62)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2);
    for (int i = 0; i < 7; i++) {
      final angle = (i / 7) * math.pi * 2;
      canvas.drawLine(
          Offset(hx + math.cos(angle) * 14,
              hy + math.sin(angle) * 14),
          Offset(hx + math.cos(angle) * 14,
              hy + math.sin(angle) * 14 - 6),
          Paint()
            ..color = const Color(0xFF4CAF50)
                .withValues(alpha: 0.68)
            ..strokeWidth = 2.0
            ..strokeCap = StrokeCap.round);
    }
    final tp = TextPainter(
      text: const TextSpan(
          text: '🌱', style: TextStyle(fontSize: 15)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas,
        Offset(hx - tp.width / 2, hy - tp.height / 2));
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  CHEMICAL HAZE COMPONENT
// ══════════════════════════════════════════════════════════════════════════════
class ChemicalHazeComponent extends Component {
  final SoilPollutionGame game;
  Vector2 hazePos;
  final double radius, speed;
  double _dx, _dy, _t = 0;

  ChemicalHazeComponent({
    required this.game,
    required double startX,
    required double startY,
    required this.radius,
    required this.speed,
    required int seed,
  })  : hazePos = Vector2(startX, startY),
        _dx     = math.cos(seed.toDouble()) * 1.0,
        _dy     = math.sin(seed.toDouble()) * 1.0;

  @override
  void update(double dt) {
    _t += dt;
    hazePos.x += _dx * speed * dt;
    hazePos.y += _dy * speed * dt;
    if (hazePos.x < radius) {
      hazePos.x = radius; _dx = _dx.abs();
    }
    if (hazePos.x > game.worldW - radius) {
      hazePos.x = game.worldW - radius; _dx = -_dx.abs();
    }
    if (hazePos.y < radius) {
      hazePos.y = radius; _dy = _dy.abs();
    }
    if (hazePos.y > game.worldH * 0.84 - radius) {
      hazePos.y = game.worldH * 0.84 - radius; _dy = -_dy.abs();
    }
    final angle =
        math.atan2(_dy, _dx) + math.sin(_t * 0.35) * 0.015;
    _dx = math.cos(angle); _dy = math.sin(angle);
  }

  @override
  void render(Canvas canvas) {
    canvas.save();
    canvas.translate(-game.camX, -game.camY);
    final inside = (hazePos - game.dronePos).length < radius + 20;
    final alpha  = inside ? 0.38 : 0.20;
    for (final (r, a) in [
      (radius * 1.4, 0.07),
      (radius,       0.14),
      (radius * 0.6, 0.08),
    ]) {
      canvas.drawCircle(
          Offset(hazePos.x, hazePos.y), r,
          Paint()
            ..color = const Color(0xFF558B2F)
                .withValues(alpha: a + alpha * 0.28)
            ..maskFilter =
                const MaskFilter.blur(BlurStyle.normal, 22));
    }
    if (inside && game.gamePhase == 3) {
      final tp = TextPainter(
        text: const TextSpan(
            text: '☣️  Scan slowed',
            style: TextStyle(
                color: Color(0xFF558B2F),
                fontSize: 9.5,
                fontWeight: FontWeight.w700)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas,
          Offset(hazePos.x - tp.width / 2, hazePos.y - 24));
    }
    canvas.restore();
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  LEACH ZONE RENDERER
// ══════════════════════════════════════════════════════════════════════════════
class LeachZoneRenderer extends Component {
  final LeachZone         zone;
  final SoilPollutionGame game;
  double _t = 0;

  LeachZoneRenderer({required this.zone, required this.game});

  @override
  void update(double dt) => _t += dt;

  @override
  void render(Canvas canvas) {
    if (game.gamePhase != 3) return;
    canvas.save();
    canvas.translate(-game.camX, -game.camY);
    final cx     = zone.center.x;
    final cy     = zone.center.y;
    final r      = zone.radius;
    final inZone = (zone.center - game.dronePos).length < r;
    final alpha  = inZone ? 0.28 : 0.12;

    canvas.drawCircle(
        Offset(cx, cy), r,
        Paint()
          ..color = const Color(0xFF29B6F6)
              .withValues(alpha: alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);

    for (int i = 0; i < 5; i++) {
      final a  = (i / 5) * math.pi * 2 + _t * 0.8;
      final ox = cx + math.cos(a) * r * 0.50;
      final oy = cy + math.sin(a) * r * 0.50;
      final ey = oy + 18;
      canvas.drawLine(
          Offset(ox, oy), Offset(ox, ey),
          Paint()
            ..color = const Color(0xFF29B6F6)
                .withValues(alpha: alpha + 0.08)
            ..strokeWidth = 1.8
            ..strokeCap = StrokeCap.round);
      canvas.drawLine(
          Offset(ox, ey), Offset(ox - 5, ey - 7),
          Paint()
            ..color = const Color(0xFF29B6F6)
                .withValues(alpha: alpha)
            ..strokeWidth = 1.4
            ..strokeCap = StrokeCap.round);
      canvas.drawLine(
          Offset(ox, ey), Offset(ox + 5, ey - 7),
          Paint()
            ..color = const Color(0xFF29B6F6)
                .withValues(alpha: alpha)
            ..strokeWidth = 1.4
            ..strokeCap = StrokeCap.round);
    }

    if (inZone) {
      final label = zone.leachRate > 0.7
          ? '💧 High Leach - Strips biological step!'
          : '💧 Leaching';
      final tp = TextPainter(
        text: TextSpan(
            text: label,
            style: const TextStyle(
                color: Color(0xFF29B6F6),
                fontSize: 9.5,
                fontWeight: FontWeight.bold)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(cx - tp.width / 2, cy - r - 18));
    }
    canvas.restore();
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  SCREEN WRAPPER
// ══════════════════════════════════════════════════════════════════════════════
class SoilPollutionGameScreen extends StatefulWidget {
  final Level4CarryOver carryOver;
  final VoidCallback? onLevelComplete;
  const SoilPollutionGameScreen({super.key, required this.carryOver, this.onLevelComplete});

  @override
  State<SoilPollutionGameScreen> createState() => _SoilPollutionGameScreenState();
}

class _SoilPollutionGameScreenState extends State<SoilPollutionGameScreen> {
  late SoilPollutionGame _game;

  @override
  void initState() {
    super.initState();
    _game = SoilPollutionGame(
      carryOver:       widget.carryOver,
      onLevelComplete: _onDone,
    );
  }

  void _onDone() {
    if (!mounted) return;
    if (widget.onLevelComplete != null) {
      widget.onLevelComplete!();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GameWidget(
        game: _game,
        overlayBuilderMap: {
          'hud':             (ctx, g) => SoilHud(g as SoilPollutionGame),
          'controls':        (ctx, g) => SoilControls(g as SoilPollutionGame),
          'banner':          (ctx, g) => SoilPhaseBanner(g as SoilPollutionGame),
          'reactionFx':      (ctx, g) => SoilReactionFx(g as SoilPollutionGame),
          'results':         (ctx, g) => SoilResultsOverlay(g as SoilPollutionGame),
          'scanResult':      (ctx, g) => SoilScanResultOverlay(g as SoilPollutionGame),
          'toolSelect':      (ctx, g) => SoilToolSelector(g as SoilPollutionGame),
          'leachAlert':      (ctx, g) => AcidLeachingAlertOverlay(g as SoilPollutionGame),
          'criticalAlert':   (ctx, g) => CriticalContaminationAlertOverlay(g as SoilPollutionGame),
          'ecoDiscovery':    (ctx, g) => EcoDiscoveryOverlay(g as SoilPollutionGame),
          'resupply':        (ctx, g) => ResupplyOverlay(g as SoilPollutionGame),
          'wrongLayer':      (ctx, g) => WrongLayerOverlay(g as SoilPollutionGame),
        },
        initialActiveOverlays: const ['hud', 'controls'],
      ),
    );
  }
}


// ══════════════════════════════════════════════════════════════════════════════
//  HUD
// ══════════════════════════════════════════════════════════════════════════════
class SoilHud extends StatelessWidget {
  final SoilPollutionGame game;
  const SoilHud(this.game, {super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: game,
      builder: (_, __) {
        final warn         = game.timeLeft < 20;
        final healthRatio  = (game.soilHealth / 100.0).clamp(0.0, 1.0);
        final healthColor  = game.soilHealth >= 75
            ? const Color(0xFF69F0AE)
            : game.soilHealth >= 40 ? const Color(0xFFFFB300) : const Color(0xFFEF5350);
        final totalZones   = game.zones.length;

        return SafeArea(child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch, children: [

            // Phase tag
            Align(alignment: Alignment.topCenter, child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
              decoration: BoxDecoration(
                color: game.gamePhase == 3
                    ? const Color(0xFFFFB300).withValues(alpha: 0.90)
                    : const Color(0xFF69F0AE).withValues(alpha: 0.90),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(
                    color: (game.gamePhase == 3
                        ? const Color(0xFFFFB300) : const Color(0xFF69F0AE))
                        .withValues(alpha: 0.38), blurRadius: 12)],
              ),
              child: Text(
                game.gamePhase == 3
                    ? '🔬  PHASE 3 - SOIL DIAGNOSIS'
                    : '🌱  PHASE 4 - SOIL REMEDIATION',
                style: const TextStyle(color: Colors.white,
                    fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1.1),
              ),
            )),
            const SizedBox(height: 8),

            // Stats row
            Row(children: [
              _SHTile(Icons.timer_rounded, '${game.timeLeft.toInt()}s', 'TIME',
                  warn ? Colors.red : Colors.white),
              const SizedBox(width: 5),
              _SHTile(Icons.radar_rounded,
                  '${game.scannedCount}/$totalZones',
                  'SCANNED',
                  const Color(0xFFFFB300)),
              const SizedBox(width: 5),
              _SHTile(Icons.restore_rounded,
                  '${game.remediatedCount}/${SoilPollutionGame.kMinZonesRequired}+',
                  'REMEDIATED',
                  game.remediatedCount >= SoilPollutionGame.kMinZonesRequired
                      ? const Color(0xFF69F0AE)
                      : Colors.white70),
              const SizedBox(width: 5),
              _SHTile(Icons.terrain_rounded, '${game.soilHealth.toStringAsFixed(0)}%',
                  'SOIL HEALTH', healthColor),
            ]),
            const SizedBox(height: 5),

            // Phase 3: scan progress bar
            if (game.gamePhase == 3 && game.scanLockActive) ...[
              Row(children: [
                const Text('🔒', style: TextStyle(fontSize: 12)),
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
                Text(game.inChemicalHaze ? '☣️ Slowed' : 'Locking…',
                    style: TextStyle(
                        color: game.inChemicalHaze ? const Color(0xFF558B2F) : const Color(0xFFFFB300),
                        fontSize: 9, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 4),
            ],

            // Phase 3: nudge when zone nearby but not scanning
            if (game.gamePhase == 3 && !game.scanLockActive &&
                game.nearestScanTarget != null && !game.toolSelectorOpen && !game.scanResultActive) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFB300).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFFB300).withValues(alpha: 0.35)),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('🔬', style: TextStyle(fontSize: 10)),
                  SizedBox(width: 5),
                  Text('Contamination zone nearby - tap SCAN!',
                      style: TextStyle(color: Color(0xFFFFB300),
                          fontSize: 9, fontWeight: FontWeight.w700)),
                ]),
              ),
            ],

            // Phase 3: scan streak indicator
            if (game.gamePhase == 3 && game.scanStreak >= 2)
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

            // Phase 4: soil health bar + combo
            if (game.gamePhase == 4) ...[
              Row(children: [
                const Text('🧪', style: TextStyle(fontSize: 13)),
                const SizedBox(width: 5),
                Expanded(child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: healthRatio,
                    backgroundColor: Colors.white12,
                    valueColor: AlwaysStoppedAnimation(healthColor),
                    minHeight: 7,
                  ),
                )),
                const SizedBox(width: 6),
                RichText(text: TextSpan(children: [
                  TextSpan(text: '${game.soilHealth.toStringAsFixed(0)}%',
                      style: TextStyle(color: healthColor, fontSize: 10, fontWeight: FontWeight.bold)),
                  const TextSpan(text: ' / 75%',
                      style: TextStyle(color: Color(0xFF69F0AE), fontSize: 8)),
                ])),
              ]),
              const SizedBox(height: 4),

              // Critical alert count
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
                      '${game.criticalAlerts.length} CRITICAL ZONE${game.criticalAlerts.length > 1 ? 'S' : ''}!  Treat before they collapse!',
                      style: const TextStyle(color: Colors.red, fontSize: 8.5, fontWeight: FontWeight.w900),
                    ),
                  ]),
                ),

              if (game.comboCount > 0)
                Align(
                  alignment: Alignment.centerRight,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
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
            ],

            // Eco-guide hint
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

class _SHTile extends StatelessWidget {
  final IconData icon;
  final String val, label;
  final Color color;
  const _SHTile(this.icon, this.val, this.label, this.color);

  @override
  Widget build(BuildContext context) => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
    decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12)),
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
  void dispose() { _fk.dispose(); super.dispose(); }

  void _onKey(KeyEvent e) {
    final pressed  = e is KeyDownEvent || e is KeyRepeatEvent;
    final released = e is KeyUpEvent;
    final k        = e.logicalKey;

    void up(bool v) { setState(() => _up = v); widget.game.setUpKey(v); }
    void dn(bool v) { setState(() => _dn = v); widget.game.setDownKey(v); }
    void lt(bool v) { setState(() => _lt = v); widget.game.setLeftKey(v); }
    void rt(bool v) { setState(() => _rt = v); widget.game.setRightKey(v); }

    if (k == LogicalKeyboardKey.keyW || k == LogicalKeyboardKey.arrowUp)    { if (pressed) up(true); if (released) up(false); }
    if (k == LogicalKeyboardKey.keyS || k == LogicalKeyboardKey.arrowDown)  { if (pressed) dn(true); if (released) dn(false); }
    if (k == LogicalKeyboardKey.keyA || k == LogicalKeyboardKey.arrowLeft)  { if (pressed) lt(true); if (released) lt(false); }
    if (k == LogicalKeyboardKey.keyD || k == LogicalKeyboardKey.arrowRight) { if (pressed) rt(true); if (released) rt(false); }
    if (k == LogicalKeyboardKey.space && pressed) {
      if (widget.game.gamePhase == 3) {
        widget.game.triggerScan();
      } else {
        widget.game.applyTool();
      }
    }
    if (pressed) {
      if (k == LogicalKeyboardKey.digit1) widget.game.selectTool(RemediationTool.containmentBoom);
      if (k == LogicalKeyboardKey.digit2) widget.game.selectTool(RemediationTool.pHAmendment);
      if (k == LogicalKeyboardKey.digit3) widget.game.selectTool(RemediationTool.soilExcavation);
      if (k == LogicalKeyboardKey.digit4) widget.game.selectTool(RemediationTool.soilWashing);
      if (k == LogicalKeyboardKey.digit5) widget.game.selectTool(RemediationTool.aerationTill);
      if (k == LogicalKeyboardKey.digit6) widget.game.selectTool(RemediationTool.biocharBacteria);
      if (k == LogicalKeyboardKey.digit7) widget.game.selectTool(RemediationTool.limeCompost);
      if (k == LogicalKeyboardKey.digit8) widget.game.selectTool(RemediationTool.phytoPlants);
      if (k == LogicalKeyboardKey.digit9) widget.game.selectTool(RemediationTool.compostWorms);
      if (k == LogicalKeyboardKey.digit0) widget.game.selectTool(RemediationTool.mycorrhizae);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.game,
      builder: (_, __) {
        final phase  = widget.game.gamePhase;
        final canAct = phase == 3
            ? widget.game.hasNearbyUnscanned
            : widget.game.hasNearbyUnremediated;
        final actColor = phase == 3 ? const Color(0xFFFFB300) : const Color(0xFF69F0AE);

        return KeyboardListener(
          focusNode: _fk,
          onKeyEvent: _onKey,
          child: Stack(children: [

            // D-pad
            Align(alignment: Alignment.bottomLeft, child: SafeArea(child: Padding(
              padding: const EdgeInsets.only(bottom: 16, left: 12),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                _SDPad('⬆', _up, Colors.cyanAccent,
                    onDown: () { setState(() => _up = true);  widget.game.setUpKey(true); },
                    onUp:   () { setState(() => _up = false); widget.game.setUpKey(false); }),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  _SDPad('◀', _lt, Colors.cyanAccent,
                      onDown: () { setState(() => _lt = true);  widget.game.setLeftKey(true); },
                      onUp:   () { setState(() => _lt = false); widget.game.setLeftKey(false); }),
                  const SizedBox(width: 4),
                  _SDPad('⬇', _dn, Colors.cyanAccent,
                      onDown: () { setState(() => _dn = true);  widget.game.setDownKey(true); },
                      onUp:   () { setState(() => _dn = false); widget.game.setDownKey(false); }),
                  const SizedBox(width: 4),
                  _SDPad('▶', _rt, Colors.cyanAccent,
                      onDown: () { setState(() => _rt = true);  widget.game.setRightKey(true); },
                      onUp:   () { setState(() => _rt = false); widget.game.setRightKey(false); }),
                ]),
              ]),
            ))),

            // Phase 4: right-side tool panel
            if (phase == 4)
              Align(
                alignment: Alignment.centerRight,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _RemediationSidePanel(game: widget.game),
                  ),
                ),
              ),

            // Phase 3: layer selector
            if (phase == 3)
              Align(
                alignment: Alignment.centerLeft,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: _LayerSelectorPanel(game: widget.game),
                  ),
                ),
              ),

            // Action button (bottom-right)
            Align(alignment: Alignment.bottomRight, child: SafeArea(child: Padding(
              padding: const EdgeInsets.only(bottom: 20, right: 14),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                if (phase == 3 && widget.game.activeScanZone != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.70),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFFB300).withValues(alpha: 0.42)),
                    ),
                    child: Text(
                      widget.game.inChemicalHaze ? '☣️ Haze slowing scan!' : '🔒 Scanning - stay in range!',
                      style: const TextStyle(color: Color(0xFFFFB300), fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ),
                if (phase == 3 && widget.game.toolSelectorOpen)
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF69F0AE).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF69F0AE).withValues(alpha: 0.42)),
                    ),
                    child: const Text(
                      '🔧 Select remediation tool!',
                      style: TextStyle(color: Color(0xFF69F0AE), fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ),
                GestureDetector(
                  onTap: () {
                    if (phase == 3) {
                      widget.game.triggerScan();
                    } else {
                      widget.game.applyTool();
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    width: 70, height: 70,
                    decoration: BoxDecoration(
                      color: canAct ? actColor.withValues(alpha: 0.22) : Colors.black.withValues(alpha: 0.60),
                      shape: BoxShape.circle,
                      border: Border.all(color: canAct ? actColor : Colors.white24, width: canAct ? 2.5 : 1.5),
                      boxShadow: canAct ? [BoxShadow(color: actColor.withValues(alpha: 0.42), blurRadius: 16)] : [],
                    ),
                    child: Center(child: Text(
                      phase == 3
                          ? (widget.game.scanLockActive ? '''🔒
LOCK
ING…''' : '''🔬
SCAN''')
                          : '''✅
APPLY''',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: canAct ? actColor : Colors.white30,
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

class _SDPad extends StatelessWidget {
  final String label;
  final bool   isActive;
  final Color  color;
  final VoidCallback onDown, onUp;
  const _SDPad(this.label, this.isActive, this.color, {required this.onDown, required this.onUp});

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
        boxShadow: isActive ? [BoxShadow(color: color.withValues(alpha: 0.42), blurRadius: 10)] : [],
      ),
      child: Center(child: Text(label,
          style: TextStyle(color: isActive ? color : Colors.white60,
              fontSize: 16, fontWeight: FontWeight.bold))),
    ),
  );
}


// ══════════════════════════════════════════════════════════════════════════════
//  LAYER SELECTOR PANEL  -  Phase 3 depth selector
// ══════════════════════════════════════════════════════════════════════════════
class _LayerSelectorPanel extends StatelessWidget {
  final SoilPollutionGame game;
  const _LayerSelectorPanel({required this.game});

  static const _layers = [
    (ScanLayerType.topLayer,  '🟤', 'TOP',    '0–35 cm',    Color(0xFFBCAAA4)),
    (ScanLayerType.midLayer,  '🟠', 'MID',    '35–63 cm',   Color(0xFFFF6D00)),
    (ScanLayerType.deepLayer, '⬛', 'DEEP',   '63+ cm',     Color(0xFF9C64FB)),
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: game,
      builder: (_, __) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: _layers.map((spec) {
            final (layer, emoji, label, depth, color) = spec;
            final selected = game.selectedLayer == layer;

            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                game.selectLayer(layer);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                margin: const EdgeInsets.only(bottom: 5),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                constraints: const BoxConstraints(minWidth: 90, maxWidth: 110),
                decoration: BoxDecoration(
                  color: selected
                      ? color.withValues(alpha: 0.25)
                      : Colors.black.withValues(alpha: 0.62),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected ? color : Colors.white.withValues(alpha: 0.12),
                    width: selected ? 1.8 : 1.1,
                  ),
                  boxShadow: selected
                      ? [BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 10)]
                      : [],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 6),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(label,
                            style: TextStyle(
                              color: selected ? color : Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 10.5,
                            )),
                        Text(depth,
                            style: TextStyle(
                              color: color.withValues(alpha: 0.68),
                              fontSize: 8,
                            )),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}


// ══════════════════════════════════════════════════════════════════════════════
//  RIGHT-SIDE TOOL PANEL  -  Phase 4 persistent remediation tool selector
// ══════════════════════════════════════════════════════════════════════════════
class _RemediationSidePanel extends StatelessWidget {
  final SoilPollutionGame game;
  const _RemediationSidePanel({required this.game});

  static const _tools = [
    (RemediationTool.containmentBoom, '🛢️', 'Containment', 'Oil Spill (Step 1)',     Color(0xFF424242)),
    (RemediationTool.pHAmendment,     '⚗️', 'pH Amendment', 'Acidic Soil (Step 1)',   Color(0xFFCDDC39)),
    (RemediationTool.soilExcavation,  '⚙️', 'Excavation',   'Heavy Metals (Step 1)',  Color(0xFF7B1FA2)),
    (RemediationTool.soilWashing,     '🧪', 'Soil Washing', 'Pesticides (Step 1)',    Color(0xFFFF6D00)),
    (RemediationTool.aerationTill,    '🪨', 'Aeration',     'Compact Soil (Step 1)',  Color(0xFFBCAAA4)),
    (RemediationTool.biocharBacteria, '⬛', 'Biochar+Bact.', 'Oil Spill ②',            Color(0xFF69F0AE)),
    (RemediationTool.limeCompost,     '🌿', 'Lime+Compost', 'Acidic Soil ②',          Color(0xFF8BC34A)),
    (RemediationTool.phytoPlants,       '🌱', 'Phyto-Plants', 'Heavy Metals ②',         Color(0xFF4CAF50)),
    (RemediationTool.compostWorms,    '🪱', 'Compost+Worms', 'Pesticides ②',          Color(0xFF795548)),
    (RemediationTool.mycorrhizae,     '🍄', 'Mycorrhizae',  'Compact Soil ②',         Color(0xFF9C27B0)),
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: game,
      builder: (_, __) {
        final target  = game.nearestActionable;
        final step    = target?.step ?? RemediationStep.none;

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: _tools.map((spec) {
            final (tool, emoji, label, hint, color) = spec;
            final uses     = game.toolUses[tool] ?? 0;
            final isEmpty  = uses == 0;
            final selected = game.selectedTool == tool;
            final correct  = target != null && game.isCorrectTool(target.type, tool, step);

            final borderColor = isEmpty
                ? Colors.white12
                : selected
                    ? color
                    : correct
                        ? color.withValues(alpha: 0.60)
                        : Colors.white.withValues(alpha: 0.12);

            final bgColor = isEmpty
                ? Colors.black.withValues(alpha: 0.55)
                : selected
                    ? color.withValues(alpha: 0.25)
                    : correct
                        ? color.withValues(alpha: 0.10)
                        : Colors.black.withValues(alpha: 0.62);

            return GestureDetector(
              onTap: isEmpty ? null : () {
                HapticFeedback.selectionClick();
                game.selectTool(tool);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                constraints: const BoxConstraints(minWidth: 130, maxWidth: 150),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: borderColor,
                    width: (selected || correct) ? 1.8 : 1.1,
                  ),
                  boxShadow: selected
                      ? [BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 10)]
                      : correct && !isEmpty
                          ? [BoxShadow(color: color.withValues(alpha: 0.20), blurRadius: 6)]
                          : [],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 26, height: 26,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isEmpty
                            ? Colors.white.withValues(alpha: 0.04)
                            : color.withValues(alpha: 0.18),
                        border: Border.all(
                          color: isEmpty ? Colors.white12 : color.withValues(alpha: 0.45),
                        ),
                      ),
                      child: Center(
                        child: Text(emoji, style: const TextStyle(fontSize: 12)),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            label,
                            style: TextStyle(
                              color: isEmpty
                                  ? Colors.white24
                                  : selected ? color : Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 9.5,
                            ),
                          ),
                          Text(
                            hint,
                            style: TextStyle(
                              color: isEmpty
                                  ? Colors.white12
                                  : color.withValues(alpha: 0.68),
                              fontSize: 7.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: isEmpty
                                ? Colors.redAccent.withValues(alpha: 0.14)
                                : color.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(
                              color: isEmpty
                                  ? Colors.redAccent.withValues(alpha: 0.42)
                                  : color.withValues(alpha: 0.38),
                            ),
                          ),
                          child: Text(
                            isEmpty ? 'OUT' : '×\$uses',
                            style: TextStyle(
                              color: isEmpty ? Colors.redAccent : color,
                              fontSize: 7.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (correct && !isEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            '✓',
                            style: TextStyle(
                              color: color,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
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
class SoilPhaseBanner extends StatelessWidget {
  final SoilPollutionGame game;
  const SoilPhaseBanner(this.game, {super.key});

  @override
  Widget build(BuildContext context) {
    final phase3 = game.gamePhase == 3;
    final accent = phase3 ? const Color(0xFFFFB300) : const Color(0xFF69F0AE);
    return IgnorePointer(child: Center(child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: phase3
            ? [const Color(0xFF1A1000), const Color(0xFF2E1800)]
            : [const Color(0xFF001A0A), const Color(0xFF003018)]),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 24)],
        border: Border.all(color: accent.withValues(alpha: 0.55), width: 1.5),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(phase3 ? 'PHASE 3' : 'PHASE 4',
            style: const TextStyle(color: Colors.white54, fontSize: 13, letterSpacing: 2.5)),
        const SizedBox(height: 4),
        Text(phase3 ? '🔬  Soil Diagnosis' : '🌱  Soil Remediation',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22)),
        const SizedBox(height: 6),
        Text(
          phase3
              ? '''Select the correct soil layer, fly close to a contamination zone, then tap 🔬 SCAN.
Read the identified pollutant, then tap FIX IT to remediate!
Chemical haze slows scans - Leach zones affect drone movement.'''
              : '''Apply the correct two-step remediation per zone.
Watch for critical alerts, contamination spread & acid leaching!''',
          textAlign: TextAlign.center,
          style: TextStyle(color: accent.withValues(alpha: 0.85), fontSize: 11.5),
        ),
      ]),
    )));
  }
}


// ══════════════════════════════════════════════════════════════════════════════
//  TOOL SELECTOR OVERLAY
// ══════════════════════════════════════════════════════════════════════════════
class SoilToolSelector extends StatelessWidget {
  final SoilPollutionGame game;
  const SoilToolSelector(this.game, {super.key});

  static const _tools = [
    (RemediationTool.containmentBoom, '🛢️', 'Containment Boom', 'Oil Spill - Step ① Physical',    Color(0xFF424242)),
    (RemediationTool.pHAmendment,     '⚗️', 'pH Amendment',     'Acidic Soil - Step ① Physical',  Color(0xFFCDDC39)),
    (RemediationTool.soilExcavation,  '⚙️', 'Soil Excavation',  'Heavy Metals - Step ① Physical', Color(0xFF7B1FA2)),
    (RemediationTool.soilWashing,     '🧪', 'Soil Washing',     'Pesticides - Step ① Physical',   Color(0xFFFF6D00)),
    (RemediationTool.aerationTill,    '🪨', 'Aeration Tilling', 'Compact Soil - Step ① Physical', Color(0xFFBCAAA4)),
    (RemediationTool.biocharBacteria, '⬛', 'Biochar+Bacteria', 'Oil Spill ②  •  Biological',       Color(0xFF69F0AE)),
    (RemediationTool.limeCompost,     '🌿', 'Lime+Compost',     'Acidic Soil ②  •  Biological',   Color(0xFF8BC34A)),
    (RemediationTool.phytoPlants,       '🌱', 'Phyto-Plants',     'Heavy Metals ②  •  Biological',  Color(0xFF4CAF50)),
    (RemediationTool.compostWorms,    '🪱', 'Compost+Worms',    'Pesticides ②  •  Biological',    Color(0xFF795548)),
    (RemediationTool.mycorrhizae,     '🍄', 'Mycorrhizae',      'Compact Soil ②  •  Biological',  Color(0xFF9C27B0)),
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: game,
      builder: (_, __) {
        final target = game.pendingFixTarget;
        if (target == null) return const SizedBox.shrink();

        final step      = target.step;
        final typeName  = _pollutantTypeName(target.type);
        final isStep2   = step == RemediationStep.physical;
        final stepLabel = isStep2 ? '② Biological step - finish remediation' : '① Physical step - initial treatment';
        final accent    = isStep2 ? const Color(0xFF69F0AE) : const Color(0xFFFF6D00);
        final showHints = game.toolSelectorShowsHints;

        return Container(
          color: Colors.black.withValues(alpha: 0.62),
          child: Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF0A1A08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: accent.withValues(alpha: 0.55), width: 1.5),
                boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 20)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(children: [
                    Text(_pollutantTypeIcon(target.type), style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(typeName,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(stepLabel,
                          style: TextStyle(color: accent, fontSize: 10.5, fontWeight: FontWeight.w700)),
                    ])),
                    GestureDetector(
                      onTap: game.cancelToolSelector,
                      child: Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isStep2
                              ? accent.withValues(alpha: 0.12)
                              : Colors.white.withValues(alpha: 0.08),
                          border: Border.all(
                              color: isStep2
                                  ? accent.withValues(alpha: 0.55)
                                  : Colors.white24),
                        ),
                        child: Center(child: Text(
                          isStep2 ? '⚠️' : '✕',
                          style: TextStyle(
                              color: isStep2 ? accent : Colors.white60,
                              fontSize: isStep2 ? 13 : 14,
                              fontWeight: FontWeight.bold),
                        )),
                      ),
                    ),
                  ]),

                  if (isStep2) ...[
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: accent.withValues(alpha: 0.45)),
                      ),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text('🌱', style: TextStyle(fontSize: 12)),
                        const SizedBox(width: 6),
                        Text('Step ① applied - complete Step ② to fully remediate this zone',
                            style: TextStyle(color: accent, fontSize: 9, fontWeight: FontWeight.w800)),
                      ]),
                    ),
                  ],

                  const SizedBox(height: 4),

                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: accent.withValues(alpha: 0.35)),
                    ),
                    child: showHints
                        ? Text(
                            'Issue: ${game.lastScanResult?.typeName ?? typeName}  •  ${game.lastScanResult?.severity ?? ''}',
                            style: TextStyle(color: accent, fontSize: 9.5, fontWeight: FontWeight.w700))
                        : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            const Text('🧠', style: TextStyle(fontSize: 11)),
                            const SizedBox(width: 5),
                            Text('Recall from memory - no hints this time!',
                                style: TextStyle(color: accent, fontSize: 9.5, fontWeight: FontWeight.w700)),
                          ]),
                  ),
                  const SizedBox(height: 10),
                  Text('Select the correct remediation tool:',
                      style: const TextStyle(color: Colors.white54, fontSize: 10.5)),
                  const SizedBox(height: 14),

                  Wrap(
                    spacing: 8, runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: _tools.map((spec) {
                      final (tool, emoji, label, hint, color) = spec;
                      final uses    = game.toolUses[tool] ?? 0;
                      final isEmpty = uses == 0;
                      final correct = showHints && game.isCorrectTool(target.type, tool, step);
                      final selColor = correct ? color : Colors.white24;

                      return GestureDetector(
                        onTap: isEmpty ? null : () {
                          HapticFeedback.selectionClick();
                          game.selectTool(tool);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 130),
                          width: 115,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                          decoration: BoxDecoration(
                            color: isEmpty
                                ? Colors.black.withValues(alpha: 0.55)
                                : correct
                                    ? color.withValues(alpha: 0.20)
                                    : Colors.black.withValues(alpha: 0.62),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isEmpty ? Colors.white12 : selColor.withValues(alpha: correct ? 0.80 : 0.22),
                              width: correct ? 2.0 : 1.2,
                            ),
                            boxShadow: correct && !isEmpty
                                ? [BoxShadow(color: color.withValues(alpha: 0.30), blurRadius: 10)]
                                : [],
                          ),
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            Text(emoji, style: TextStyle(fontSize: 22,
                                color: isEmpty ? const Color(0xFF444444) : null)),
                            const SizedBox(height: 4),
                            Text(label,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: isEmpty ? Colors.white24 : correct ? color : Colors.white70,
                                  fontWeight: FontWeight.w800, fontSize: 10.5,
                                )),
                            if (showHints)
                              Text(hint,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: isEmpty ? Colors.white12 : color.withValues(alpha: 0.68),
                                    fontSize: 8,
                                  ))
                            else
                              Text('- apply from memory -',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.white24, fontSize: 7.5)),
                            const SizedBox(height: 3),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: isEmpty
                                    ? Colors.redAccent.withValues(alpha: 0.14)
                                    : color.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                isEmpty ? 'OUT' : '×\$uses',
                                style: TextStyle(
                                  color: isEmpty ? Colors.redAccent : color,
                                  fontSize: 7.5, fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ]),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _pollutantTypeIcon(SoilPollutantType t) {
    switch (t) {
      case SoilPollutantType.oilSpill:    return '🛢️';
      case SoilPollutantType.acidicSoil:  return '⚗️';
      case SoilPollutantType.heavyMetals: return '⚙️';
      case SoilPollutantType.pesticides:  return '🧪';
      case SoilPollutantType.compactSoil: return '🪨';
    }
  }

  String _pollutantTypeName(SoilPollutantType t) {
    switch (t) {
      case SoilPollutantType.oilSpill:    return 'Oil Spill';
      case SoilPollutantType.acidicSoil:  return 'Acidic Soil';
      case SoilPollutantType.heavyMetals: return 'Heavy Metals';
      case SoilPollutantType.pesticides:  return 'Pesticide Zone';
      case SoilPollutantType.compactSoil: return 'Compacted Soil';
    }
  }
}


// ══════════════════════════════════════════════════════════════════════════════
//  SCAN RESULT OVERLAY  - compact floating mini-card, NON-BLOCKING
// ══════════════════════════════════════════════════════════════════════════════
class SoilScanResultOverlay extends StatefulWidget {
  final SoilPollutionGame game;
  const SoilScanResultOverlay(this.game, {super.key});
  @override
  State<SoilScanResultOverlay> createState() => _SoilScanResultOverlayState();
}

class _SoilScanResultOverlayState extends State<SoilScanResultOverlay>
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

        final rawTimer = widget.game.scanResultTimer;
        final displayDuration = result.hasEcoDiscovery ? 5.5 : 4.0;
        final progress = (rawTimer / displayDuration).clamp(0.0, 1.0);
        final pts = widget.game.lastScanPoints;

        return Center(
          child: ScaleTransition(
            scale: _scale,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 18),
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
              constraints: const BoxConstraints(maxWidth: 340),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF0A0A14),
                    result.color.withValues(alpha: 0.12),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
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
                  SizedBox(
                    width: 22, height: 22,
                    child: CustomPaint(painter: _ArcCountdownPainter(progress, result.color)),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('SOIL SCAN COMPLETE',
                        style: TextStyle(color: Colors.white54, fontSize: 9,
                            fontWeight: FontWeight.w900, letterSpacing: 1.8)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFB300).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFFFB300).withValues(alpha: 0.42)),
                    ),
                    child: Text('+\$pts pts${pts >= 30 ? ' 🌟' : ''}',
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
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: result.color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(result.severity,
                              style: TextStyle(color: result.color.withValues(alpha: 0.90),
                                  fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                        ),
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
                          const Text('REQUIRED TREATMENT',
                              style: TextStyle(color: Colors.white38, fontSize: 7.5,
                                  fontWeight: FontWeight.w900, letterSpacing: 1.3)),
                          const SizedBox(height: 6),
                          _TreatmentRow(step: '①', text: result.step1Tool, color: const Color(0xFFEF5350)),
                          const SizedBox(height: 4),
                          _TreatmentRow(step: '②', text: result.step2Tool, color: const Color(0xFF69F0AE)),
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
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          const Text('🧠 YOU KNOW THIS ONE',
                              style: TextStyle(color: Color(0xFF69F0AE), fontSize: 9.5,
                                  fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                          const SizedBox(height: 5),
                          const Text(
                            '''You have diagnosed this pollutant before.
Apply the two-step remediation from memory!''',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white54, fontSize: 9.5, height: 1.4),
                          ),
                        ]),
                      ),
                const SizedBox(height: 14),

                GestureDetector(
                  onTap: () => widget.game.openToolSelectorForPending(),
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
                      Text('FIX IT  →  SELECT TOOL',
                          style: TextStyle(color: result.color, fontSize: 13,
                              fontWeight: FontWeight.w900, letterSpacing: 0.8)),
                    ]),
                  ),
                ),
                const SizedBox(height: 6),
                const Text('or wait - auto-opens in a moment',
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

class _TreatmentRow extends StatelessWidget {
  final String step, text;
  final Color  color;
  const _TreatmentRow({required this.step, required this.text, required this.color});

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(width: 16, height: 16, alignment: Alignment.center,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle,
            border: Border.all(color: color.withValues(alpha: 0.50))),
        child: Text(step, style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.bold)),
      ),
      const SizedBox(width: 6),
      Expanded(child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 9, height: 1.3))),
    ],
  );
}

class _ArcCountdownPainter extends CustomPainter {
  final double progress;
  final Color  color;
  const _ArcCountdownPainter(this.progress, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2; final cy = size.height / 2;
    final r  = math.min(cx, cy) - 1.5;
    canvas.drawCircle(Offset(cx, cy), r,
        Paint()..color = Colors.white12..style = PaintingStyle.stroke..strokeWidth = 2.0);
    canvas.drawArc(Rect.fromCenter(center: Offset(cx, cy), width: r * 2, height: r * 2),
        -math.pi / 2, math.pi * 2 * progress, false,
        Paint()..color = color.withValues(alpha: 0.80)
          ..style = PaintingStyle.stroke..strokeWidth = 2.5..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(_ArcCountdownPainter old) => old.progress != progress;
}


// ══════════════════════════════════════════════════════════════════════════════
//  REACTION FLASH
// ══════════════════════════════════════════════════════════════════════════════
class SoilReactionFx extends StatelessWidget {
  final SoilPollutionGame game;
  const SoilReactionFx(this.game, {super.key});

  @override
  Widget build(BuildContext context) {
    final ok      = game.reactionCorrect;
    final inRange = game.reactionInRange;
    final msg     = game.reactionMsg.isNotEmpty
        ? game.reactionMsg
        : (!inRange ? '🔬  Out of Range - move closer'
            : ok ? '✅  Success!' : '❌  Wrong approach');
    final accent = (ok && inRange) ? const Color(0xFF69F0AE) : const Color(0xFFEF5350);

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
            boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 14, spreadRadius: 2)]),
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
  }
}


// ══════════════════════════════════════════════════════════════════════════════
//  CRITICAL ALERT OVERLAY
// ══════════════════════════════════════════════════════════════════════════════
class CriticalContaminationAlertOverlay extends StatelessWidget {
  final SoilPollutionGame game;
  const CriticalContaminationAlertOverlay(this.game, {super.key});

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
              color: const Color(0xFF1A0000).withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.withValues(alpha: 0.75), width: 1.5),
              boxShadow: [BoxShadow(color: Colors.red.withValues(alpha: 0.25), blurRadius: 20)],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Text('⚡', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Column(mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('CRITICAL ZONE - TREAT NOW!',
                    style: TextStyle(color: Colors.red, fontSize: 10,
                        fontWeight: FontWeight.w900, letterSpacing: 1.3)),
                const SizedBox(height: 2),
                const Text(
                  '''A contamination zone is on the verge of collapse.
Treat it to save +15 pts - or lose -20!''',
                  style: TextStyle(color: Colors.white60, fontSize: 9.5),
                ),
              ]),
              const SizedBox(width: 10),
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(shape: BoxShape.circle,
                    color: Colors.red.withValues(alpha: 0.14),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.55))),
                child: Center(child: Text(alert.timeLeft.ceil().toString(),
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
//  ECO-DISCOVERY OVERLAY
// ══════════════════════════════════════════════════════════════════════════════
class EcoDiscoveryOverlay extends StatefulWidget {
  final SoilPollutionGame game;
  const EcoDiscoveryOverlay(this.game, {super.key});
  @override
  State<EcoDiscoveryOverlay> createState() => _EcoDiscoveryOverlayState();
}

class _EcoDiscoveryOverlayState extends State<EcoDiscoveryOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _scale;

  @override
  void initState() {
    super.initState();
    _ctrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 380))..forward();
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(child: Center(child: ScaleTransition(
      scale: _scale,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 30),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF1A0A2E), Color(0xFF2A0A1A)]),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE040FB).withValues(alpha: 0.70), width: 2.0),
          boxShadow: [BoxShadow(color: const Color(0xFFE040FB).withValues(alpha: 0.30), blurRadius: 30)],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('✨ ECO-DISCOVERY FOUND! ✨',
              style: TextStyle(color: Color(0xFFE040FB), fontSize: 12,
                  fontWeight: FontWeight.w900, letterSpacing: 1.5)),
          const SizedBox(height: 10),
          Text(widget.game.lastDiscoveryFact,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.6)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFE040FB).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE040FB).withValues(alpha: 0.45)),
            ),
            child: const Text('+30 Eco-Points  •  Cultural Heritage Bonus!',
                style: TextStyle(color: Color(0xFFE040FB), fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ]),
      ),
    )));
  }
}


// ══════════════════════════════════════════════════════════════════════════════
//  RESUPPLY OVERLAY
// ══════════════════════════════════════════════════════════════════════════════
class ResupplyOverlay extends StatelessWidget {
  final SoilPollutionGame game;
  const ResupplyOverlay(this.game, {super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(child: Align(
      alignment: Alignment.topCenter,
      child: SafeArea(child: Container(
        margin: const EdgeInsets.only(top: 60),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF0D1A06).withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF8BC34A).withValues(alpha: 0.70), width: 1.5),
          boxShadow: [BoxShadow(color: const Color(0xFF8BC34A).withValues(alpha: 0.25), blurRadius: 20)],
        ),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Text('📦', style: TextStyle(fontSize: 22)),
          SizedBox(width: 10),
          Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('TOOL RESUPPLY EARNED!',
                style: TextStyle(color: Color(0xFF8BC34A), fontSize: 11,
                    fontWeight: FontWeight.w900, letterSpacing: 1.3)),
            SizedBox(height: 2),
            Text('''Low-stock tool refilled with +3 uses.
Keep remediating to earn more!''',
                style: TextStyle(color: Colors.white60, fontSize: 10)),
          ]),
        ]),
      )),
    ));
  }
}


// ══════════════════════════════════════════════════════════════════════════════
//  WRONG LAYER OVERLAY
// ══════════════════════════════════════════════════════════════════════════════
class WrongLayerOverlay extends StatelessWidget {
  final SoilPollutionGame game;
  const WrongLayerOverlay(this.game, {super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: game,
      builder: (_, __) {
        if (!game.wrongLayerActive) return const SizedBox.shrink();
        return IgnorePointer(child: Center(child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF2A0A0A).withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFFF6D00).withValues(alpha: 0.70), width: 1.5),
            boxShadow: [BoxShadow(color: const Color(0xFFFF6D00).withValues(alpha: 0.25), blurRadius: 20)],
          ),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Text('⚠️', style: TextStyle(fontSize: 20)),
            SizedBox(width: 8),
            Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('WRONG SCAN LAYER',
                  style: TextStyle(color: Color(0xFFFF6D00), fontSize: 11,
                      fontWeight: FontWeight.w900, letterSpacing: 1.3)),
              SizedBox(height: 2),
              Text(
                '''The contamination is in a different soil layer.
Switch layer selector and try again!''',
                style: TextStyle(color: Colors.white60, fontSize: 10),
              ),
            ]),
          ]),
        )));
      },
    );
  }
}


// ══════════════════════════════════════════════════════════════════════════════
//  ACID LEACHING ALERT OVERLAY
// ══════════════════════════════════════════════════════════════════════════════
class AcidLeachingAlertOverlay extends StatelessWidget {
  final SoilPollutionGame game;
  const AcidLeachingAlertOverlay(this.game, {super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: game,
      builder: (_, __) {
        final cd = game.leachingWarningCd;
        return IgnorePointer(child: Align(
          alignment: Alignment.topCenter,
          child: SafeArea(child: Container(
            margin: const EdgeInsets.only(top: 62),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1B2A).withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFCDDC39).withValues(alpha: 0.72), width: 1.5),
              boxShadow: [BoxShadow(color: const Color(0xFFCDDC39).withValues(alpha: 0.28), blurRadius: 22)],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Text('💧', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              const Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('ACID LEACHING INCOMING',
                    style: TextStyle(color: Color(0xFFCDDC39), fontSize: 11,
                        fontWeight: FontWeight.w900, letterSpacing: 1.4)),
                SizedBox(height: 2),
                Text(
                  '''Step-1 physical treatments are at risk of being stripped.
Apply Step 2 before leaching hits!''',
                  style: TextStyle(color: Colors.white60, fontSize: 10),
                ),
              ]),
              const SizedBox(width: 12),
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(shape: BoxShape.circle,
                    color: const Color(0xFFCDDC39).withValues(alpha: 0.12),
                    border: Border.all(color: const Color(0xFFCDDC39).withValues(alpha: 0.52))),
                child: Center(child: Text(cd.ceil().toString(),
                    style: const TextStyle(color: Color(0xFFCDDC39),
                        fontWeight: FontWeight.bold, fontSize: 15))),
              ),
            ]),
          )),
        ));
      },
    );
  }
}


// ══════════════════════════════════════════════════════════════════════════════
//  RESULTS OVERLAY  - fully dynamic
// ══════════════════════════════════════════════════════════════════════════════
class SoilResultsOverlay extends StatelessWidget {
  final SoilPollutionGame game;
  const SoilResultsOverlay(this.game, {super.key});

  @override
  Widget build(BuildContext context) {
    final r          = SoilPollutionResult.current!;
    final guardian   = r.soilGuardianBadge;
    final meetsMin   = r.meetsMinimum;
    final totalZones = game.zones.length;
    final remediated = r.zonesRemediated;
    final stars      = remediated >= totalZones - 1 ? '★★★'
                     : remediated >= (totalZones * 0.6).ceil() ? '★★☆'
                     : '★☆☆';

    return Container(
      color: Colors.black.withValues(alpha: 0.94),
      child: SafeArea(child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(children: [

          // Header card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: guardian
                  ? [const Color(0xFF001A0A), const Color(0xFF003018)]
                  : [const Color(0xFF1A1000), const Color(0xFF2A1800)]),
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 16)],
            ),
            child: Column(children: [
              Text(guardian ? '🌱' : '⚗️', style: const TextStyle(fontSize: 50)),
              const SizedBox(height: 6),
              Text(guardian ? 'Soil Health Restored!' : 'Phase Complete',
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(r.performanceGrade,
                  style: TextStyle(
                    color: guardian ? const Color(0xFF69F0AE) : const Color(0xFFFFB300),
                    fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 1.0,
                  )),
              const SizedBox(height: 4),
              const Text('Phase 3 & 4 - Soil Pollution Results',
                  style: TextStyle(color: Colors.white54, fontSize: 12)),
              const SizedBox(height: 8),
              Text(stars, style: const TextStyle(
                  color: Color(0xFFFFB300), fontSize: 28, letterSpacing: 6)),
              if (guardian) ...[
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
                    Text('Soil Guardian Badge Unlocked!',
                        style: TextStyle(color: Color(0xFF69F0AE),
                            fontWeight: FontWeight.w800, fontSize: 11.5)),
                  ]),
                ),
              ],
            ]),
          ),

          const SizedBox(height: 14),

          // Remediation progress
          _SRCard(children: [
            _SRBig('🌱', '$remediated/$totalZones', 'Remediated',  Colors.limeAccent),
            _SRBig('🏗️', '${r.zonesPhysical}/$totalZones', 'Step 1',    const Color(0xFF29B6F6)),
            _SRBig('🔬', '${r.scannedZones}/$totalZones',    'Scanned',   const Color(0xFFFFB300)),
          ]),

          const SizedBox(height: 8),

          // Tool accuracy
          _SRCard(children: [
            _SRBig('✅', r.correctTools.toString(),  'Correct',  const Color(0xFF69F0AE)),
            _SRBig('❌', r.wrongTools.toString(),    'Wrong',    Colors.redAccent),
            _SRBig('🎯', '${r.accuracyPct}%',  'Accuracy', r.accuracyPct >= 70
                ? const Color(0xFF69F0AE)
                : r.accuracyPct >= 40 ? const Color(0xFFFFB300) : Colors.redAccent),
            _SRBig('🔥', '${r.maxCombo}×',     'Max Combo', const Color(0xFFFF6D00)),
          ]),

          const SizedBox(height: 8),

          // Soil health & points
          _SRCard(children: [
            _SRBig('🧪', '${r.soilHealth.toStringAsFixed(0)}%', 'Soil Health',
                guardian ? const Color(0xFF69F0AE) : const Color(0xFFFFB300)),
            _SRBig('⭐', r.ecoPoints.toString(), 'Eco-Points', Colors.amber),
            if (r.scanStreakBonus > 0)
              _SRBig('🎯', '+${r.scanStreakBonus}', 'Streak Pts', const Color(0xFFE040FB)),
          ]),

          const SizedBox(height: 8),

          // Dynamic bonus events
          _SRCard(children: [
            _SRBig('⚡', r.criticalSaves.toString(), 'Crits Saved', Colors.redAccent),
            _SRBig('🌍', '${r.ecoDiscoveriesFound}/2', 'Discoveries', const Color(0xFFE040FB)),
            _SRBig('⏱️', r.timeBonusCollected ? 'YES' : 'NO', 'Time Bonus',
                r.timeBonusCollected ? const Color(0xFFFFD700) : Colors.white38),
            if (r.zonesExpanded > 0)
              _SRBig('⚠️', r.zonesExpanded.toString(), '''Zones
Expanded''', Colors.orange),
          ]),

          const SizedBox(height: 10),

          // Performance summary
          if (r.performanceSummary.isNotEmpty)
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

          const SizedBox(height: 10),

          // Two-step reference guide
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: const Color(0xFF0A1A08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(children: [
              const Text('Two-Step Remediation Applied',
                  style: TextStyle(color: Colors.white70, fontSize: 12,
                      fontWeight: FontWeight.bold, letterSpacing: 1)),
              const SizedBox(height: 10),
              _SRRow('🛢️', 'Oil Spills',         '① Containment Boom  →  ② Biochar+Bacteria'),
              _SRRow('⚗️', 'Acidic Soil',        '① pH Amendment      →  ② Lime+Compost'),
              _SRRow('⚙️', 'Heavy Metals',       '① Soil Excavation   →  ② Phyto-Plants'),
              _SRRow('🧪', 'Pesticides',         '① Soil Washing      →  ② Compost+Worms'),
              _SRRow('🪨', 'Compacted Soil',     '① Aeration Tilling  →  ② Mycorrhizae'),
              if (r.resupplyTriggered > 0) ...[
                const Divider(color: Colors.white12, height: 16),
                Row(children: [
                  const Text('📦', style: TextStyle(fontSize: 13)),
                  const SizedBox(width: 8),
                  Text('Tool Resupply earned ${r.resupplyTriggered}×',
                      style: const TextStyle(color: Color(0xFF8BC34A), fontSize: 11)),
                ]),
              ],
            ]),
          ),

          const SizedBox(height: 18),

          // Primary action
          SizedBox(
            width: double.infinity,
            child: meetsMin
                ? ElevatedButton.icon(
                    onPressed: () {
                      game.resumeEngine();
                      game.navigateToComplete();
                    },
                    icon: const Icon(Icons.check_circle_rounded),
                    label: const Text('LEVEL COMPLETE  →',
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
                        'Replay  - Remediate ' '${r.minimumRequired - r.zonesRemediated} More Zone(s)',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5),
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
                        '''💡 Tip: Select the correct soil layer, fly near a contamination zone and tap SCAN.
Read the identified pollutant, tap FIX IT, then pick the right tool.
Minimum ${r.minimumRequired} fully remediated zones needed to advance.''',
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

class _SRCard extends StatelessWidget {
  final List<Widget> children;
  const _SRCard({required this.children});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
    decoration: BoxDecoration(color: const Color(0xFF0A1A08),
        borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white12)),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: children),
  );
}

class _SRBig extends StatelessWidget {
  final String emoji, value, label;
  final Color  color;
  const _SRBig(this.emoji, this.value, this.label, this.color);
  @override
  Widget build(BuildContext context) =>
      Column(mainAxisSize: MainAxisSize.min, children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 3),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 17)),
        const SizedBox(height: 2),
        Text(label, textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white54, fontSize: 8.5)),
      ]);
}

class _SRRow extends StatelessWidget {
  final String emoji, label, action;
  const _SRRow(this.emoji, this.label, this.action);
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