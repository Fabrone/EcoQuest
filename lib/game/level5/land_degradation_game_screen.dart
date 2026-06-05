import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:ecoquest/game/level5/degraded_land_screen.dart';
import 'package:ecoquest/game/level5/soil_pollution_game.dart';
import 'package:flame/components.dart' hide Matrix4;
import 'package:flame/game.dart' hide Matrix4;
import 'package:flutter/material.dart' hide Matrix4;
import 'package:flutter/services.dart';

class LandDegradationResult {
  final int    patchesRestored;
  final int    patchesStabilized;
  final int    correctTools;
  final int    wrongTools;
  final int    ecoPoints;
  final double erosionIndex;
  final bool   terrainStabilised;
  final int    scannedPatches;
  final int    maxCombo;
  final int    scanStreakBonus;
  final int    ecoDiscoveriesFound;
  final bool   timeBonusCollected;
  final int    criticalSaves;
  final int    gulliesExpanded;
  final int    resupplyTriggered;
  final bool   meetsMinimum;
  final int    minimumRequired;

  // NEW: Clear explanation of why level ended
  final String endReason;

  // Completion state — set by _endLevel, read by banner + results overlay
  final LevelCompletionState completionState;

  const LandDegradationResult({
    required this.patchesRestored,
    required this.patchesStabilized,
    required this.correctTools,
    required this.wrongTools,
    required this.ecoPoints,
    required this.erosionIndex,
    required this.terrainStabilised,
    required this.scannedPatches,
    this.maxCombo          = 1,
    this.scanStreakBonus    = 0,
    this.ecoDiscoveriesFound = 0,
    this.timeBonusCollected = false,
    this.criticalSaves     = 0,
    this.gulliesExpanded   = 0,
    this.resupplyTriggered = 0,
    this.meetsMinimum      = false,
    this.minimumRequired   = 9,
    this.endReason         = 'Level completed.',
    this.completionState   = LevelCompletionState.failed,
  });

  int get totalActions  => correctTools + wrongTools;
  int get accuracyPct   => totalActions == 0
      ? 0 : ((correctTools / totalActions) * 100).round();

  /// Human-readable performance grade
  String get performanceGrade {
    if (accuracyPct >= 85 && patchesRestored >= 7) return 'EXPERT RESTORER';
    if (accuracyPct >= 70 && patchesRestored >= 5) return 'SKILLED CONSERVATIONIST';
    if (accuracyPct >= 50 && patchesRestored >= 3) return 'FIELD TRAINEE';
    return 'APPRENTICE ECOLOGIST';
  }

  String get performanceSummary {
    final lines = <String>[];
    if (criticalSaves > 0) lines.add('Saved $criticalSaves critical zone(s) before collapse');
    if (gulliesExpanded > 0) lines.add('$gulliesExpanded gull${gulliesExpanded == 1 ? "y" : "ies"} expanded due to neglect');
    if (ecoDiscoveriesFound > 0) lines.add('Found $ecoDiscoveriesFound hidden Eco-Discovery marker(s)');
    if (timeBonusCollected) lines.add('Time Bonus patch restored — earned +8 s');
    if (maxCombo >= 4) lines.add('$maxCombo-streak combo achieved — 3× point multiplier!');
    if (scanStreakBonus > 0) lines.add('Scan streak bonus: +$scanStreakBonus pts');
    return lines.isEmpty ? 'Complete all patches to maximise your score.' : lines.join('\n');
  }

  static LandDegradationResult? current;
}

// ── Enums ─────────────────────────────────────────────────────────────────────
enum DegradationType  { steepSlope, gully, bareLand, drySoil }
enum RestorationTool  { terrace, checkDam, coverCrop, biochar, compost }
enum RestorationStep  { none, stabilized, restored }

enum LevelCompletionState { failed, moderate, fullCompletion }

// ── Critical alert event ──────────────────────────────────────────────────────
class CriticalAlert {
  final DegradedPatch patch;
  double timeLeft;
  bool   handled;
  CriticalAlert({required this.patch, this.timeLeft = 12.0, this.handled = false});
}

// ── Terrain scan result (auto-detected, no quiz) ──────────────────────────────
class TerrainScanResult {
  final DegradationType type;
  final String typeName, severity, ecoFact, step1Tool, step2Tool, icon;
  final Color  color;
  final bool   hasEcoDiscovery;
  final String discoveryFact;

  const TerrainScanResult({
    required this.type,
    required this.typeName,
    required this.severity,
    required this.ecoFact,
    required this.step1Tool,
    required this.step2Tool,
    required this.icon,
    required this.color,
    this.hasEcoDiscovery = false,
    this.discoveryFact   = '',
  });

  static TerrainScanResult forType(
    DegradationType t, {
    bool withDiscovery = false,
    int variant = 0,
  }) {
    // Multiple eco-fact variants per type so repeated scans feel fresh
    const steepFacts = [
      'Slopes above 30° lose topsoil up to 20× faster than flat land. Terracing cuts runoff velocity by 70%.',
      'In Kiambu\'s highlands, a single rainstorm on a bare 30° slope can strip 5 mm of topsoil in minutes.',
    ];
    const gullyFacts = [
      'Gullies in Kenya\'s highlands advance up to 30 m per year during the long rains season.',
      'An untreated gully doubles in width within one rainy season, cutting off farmland from water channels.',
    ];
    const bareFacts = [
      'Bare land loses up to 60 tonnes of topsoil per hectare each year through wind and water erosion.',
      'Without cover, UV radiation breaks down soil organic matter — destroying moisture retention capacity.',
    ];
    const dryFacts = [
      'Cracked soil has lost over 80% of its water-holding capacity. Biochar can restore this in 2–3 seasons.',
      'The hardpan layer visible in cracked Kiambu soils can stop root penetration down to 30 cm.',
    ];

    const discoveryFacts = {
      DegradationType.steepSlope:
        '🏺 Cultural Marker Found! The Kikuyu practised "Miriga Mieru" — sacred ridge-line terracing — to honour the land and prevent erosion on Kiambu\'s hills.',
      DegradationType.gully:
        '🌿 Cultural Marker Found! Gikambura elders used "Iria ria Kiumo" (sacred stream lines) to channel runoff safely — an early form of gully management.',
      DegradationType.bareLand:
        '🌾 Cultural Marker Found! The Gikambura community planted "Mukinduri" trees along bare hillsides for erosion control — their roots still visible in this area.',
      DegradationType.drySoil:
        '🪶 Cultural Marker Found! Elders of Rwithigiti buried "Githuri" (clay pots of organic material) in dry soil to feed the land — an ancestral biochar technique.',
    };

    final idx = variant % 2;
    switch (t) {
      case DegradationType.steepSlope:
        return TerrainScanResult(
          type: t, typeName: 'Steep Erosion Slope',
          severity: 'HIGH  •  >30° gradient',
          ecoFact: steepFacts[idx],
          step1Tool: 'Terracing  →  Reduces slope gradient & runoff',
          step2Tool: 'Cover Crops  →  Root systems bind exposed soil',
          icon: '⛰️', color: const Color(0xFFEF5350),
          hasEcoDiscovery: withDiscovery,
          discoveryFact: discoveryFacts[t]!,
        );
      case DegradationType.gully:
        return TerrainScanResult(
          type: t, typeName: 'Active Erosion Gully',
          severity: 'SEVERE  •  Active channelling',
          ecoFact: gullyFacts[idx],
          step1Tool: 'Check Dams  →  Arrest gully advance & trap sediment',
          step2Tool: 'Biochar  →  Restores soil structure in gully floor',
          icon: '🕳️', color: const Color(0xFFFF6D00),
          hasEcoDiscovery: withDiscovery,
          discoveryFact: discoveryFacts[t]!,
        );
      case DegradationType.bareLand:
        return TerrainScanResult(
          type: t, typeName: 'Bare / Denuded Land',
          severity: 'MEDIUM  •  Full topsoil exposure',
          ecoFact: bareFacts[idx],
          step1Tool: 'Cover Crops  →  Fast-growing canopy shields soil surface',
          step2Tool: 'Compost  →  Rebuilds organic matter & water retention',
          icon: '🌾', color: const Color(0xFFFFB300),
          hasEcoDiscovery: withDiscovery,
          discoveryFact: discoveryFacts[t]!,
        );
      case DegradationType.drySoil:
        return TerrainScanResult(
          type: t, typeName: 'Severely Desiccated Soil',
          severity: 'LOW–MED  •  Cracked hardpan',
          ecoFact: dryFacts[idx],
          step1Tool: 'Biochar  →  Opens soil pores & locks moisture',
          step2Tool: 'Compost  →  Re-introduces microbial life',
          icon: '🪨', color: const Color(0xFFBCAAA4),
          hasEcoDiscovery: withDiscovery,
          discoveryFact: discoveryFacts[t]!,
        );
    }
  }
}

// ── Wind zone data ─────────────────────────────────────────────────────────────
class WindZone {
  final Vector2 center;
  final double  radius;
  Vector2       force;
  WindZone({required this.center, required this.radius, required this.force});
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
        builder: (_) => SoilPollutionGameScreen(carryOver: widget.carryOver),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GameWidget(
        game: _game,
        overlayBuilderMap: {
          'hud':             (ctx, g) => LandHud(g as LandDegradationGame),
          'controls':        (ctx, g) => LandControls(g as LandDegradationGame),
          'banner':          (ctx, g) => LandPhaseBanner(g as LandDegradationGame),
          'reactionFx':      (ctx, g) => LandReactionFx(g as LandDegradationGame),
          'results':         (ctx, g) => LandResultsOverlay(g as LandDegradationGame),
          'completionBanner': (ctx, g) => LandCompletionBanner(g as LandDegradationGame),
          'scanResult':      (ctx, g) => ScanResultOverlay(g as LandDegradationGame),
          'toolSelect':      (ctx, g) => LandToolSelector(g as LandDegradationGame),
          'weatherAlert':    (ctx, g) => WeatherAlertOverlay(g as LandDegradationGame),
          'criticalAlert':   (ctx, g) => CriticalAlertOverlay(g as LandDegradationGame),
          'ecoDiscovery':    (ctx, g) => EcoDiscoveryOverlay(g as LandDegradationGame),
          'resupply':        (ctx, g) => ResupplyOverlay(g as LandDegradationGame),
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

  // ── Minimum patches required to proceed ───────────────────────────────────
  static const int kMinPatchesRequired = 9;

  // ── World / camera system (world = 3× screen) ─────────────────────────────
  static const double kWorldScale    = 3.0;
  static const double kEdgeFraction  = 0.22;
  static const double kCameraEase    = 5.5;
  double worldW = 0, worldH = 0;
  double camX = 0, camY = 0;
  // _targetCamX/_targetCamY are kept as fields so _updateCamera() can lerp smoothly
  double _targetCamX = 0, _targetCamY = 0;
  double edgeHintLeft = 0, edgeHintRight = 0;
  double edgeHintTop  = 0, edgeHintBottom = 0;

  // ── Immediate tool selector (opens right after scan) ─────────────────────
  DegradedPatch? pendingFixTarget;
  bool toolSelectorOpen = false;

  // ── Core ───────────────────────────────────────────────────────────────────
  int    gamePhase   = 1;
  bool   gameStarted = false;
  double timeLeft    = 150.0;   // slight extra for richer challenge set
  bool   levelDone   = false;

  // ── Score ──────────────────────────────────────────────────────────────────
  int ecoPoints        = 0;
  int correctTools     = 0;
  int wrongTools       = 0;
  int restoredCount    = 0;
  int stabilizedCount  = 0;
  int scannedCount     = 0;
  int maxCombo         = 1;

  // ── Erosion ────────────────────────────────────────────────────────────────
  double erosionIndex                = 92.0;
  static const double _targetErosion = 20.0;

  // ── Ranges ─────────────────────────────────────────────────────────────────
  static const double _scanRange     = 155.0;
  static const double _hoverRange    = 110.0;
  static const double _applyRange    = 100.0;
  static const double _scanMaxRadius = 180.0;

  // ── Drone physics ──────────────────────────────────────────────────────────
  late Vector2 dronePos;
  bool isUp = false, isDown = false, isLeft = false, isRight = false;
  static const double _droneSpeed = 195.0;
  Vector2 activeWindForce = Vector2.zero();

  // ── Phase 1 · Scan system ──────────────────────────────────────────────────
  DegradedPatch? activeScanPatch;
  double         scanHoldTime    = 0.0;
  static const double _scanDuration = 1.5;
  bool   inDustCloud  = false;
  bool   scanActive   = false;
  double scanRadius   = 0;

  // ── Phase 1 · User-triggered scan (mirrors sonarPing in noise screen) ─────
  bool   scanTriggered    = false;   // set true when player taps SCAN button
  bool   scanLockActive   = false;   // true while the 1.5s hold-scan is running
  double _scanLockTimer   = 0;       // counts up to _scanDuration
  // Nearest unscanned patch within scan range (updated each frame)
  DegradedPatch? _nearestScanTarget;

  // ── Phase 1 · Scan result (non-blocking mini-card) ────────────────────────
  bool               scanResultActive = false;
  TerrainScanResult? lastScanResult;
  double             scanResultTimer  = 0;
  static const double _scanResultDisplay = 1.8;  // ← was 2.5 s; now 1.8 s
  DegradedPatch?     lastScannedPatch;
  int                lastScanPoints   = 0;   // dynamic — differs by scan type
  // Position of the floating mini-card (set to drone position on scan)
  Vector2            scanCardPos      = Vector2.zero();

  // ── Phase 1 · Scan streak bonus ───────────────────────────────────────────
  int    scanStreak       = 0;
  double scanStreakTimer   = 0;
  int    totalScanStreak  = 0;   // accumulated bonus for results
  static const double _streakWindow = 6.0;

  // ── Phase 1 · Wind zones ───────────────────────────────────────────────────
  final List<WindZone> windZones       = [];
  double                _windChangeTimer = 0;
  static const double   _windPeriod     = 9.0;
  double                windIntensity   = 0;   // 0–1 for wind strip checks

  // ── Phase 1 · Dust clouds ──────────────────────────────────────────────────
  final List<DustCloudComponent> dustClouds = [];

  // ── Eco-discovery & time-bonus patches ────────────────────────────────────
  final Set<int> ecoDiscoveryIndices  = {};   // patch indices with hidden markers
  final Set<int> discoveredEcoPatches = {};   // indices already revealed by full hover
  int?           timeBonusPatchIndex;
  bool           timeBonusCollected   = false;
  int            ecoDiscoveriesFound  = 0;
  String         lastDiscoveryFact    = '';
  double         discoveryDisplayTimer = 0;
  static const double _discoveryDisplay = 4.0;

  // ── Phase 2 · Tool inventory ───────────────────────────────────────────────
  RestorationTool selectedTool = RestorationTool.terrace;
  bool toolDialogRequested = false;
  final Map<RestorationTool, int> toolUses = {
    RestorationTool.terrace:   3,   // ← was 4; now 3 (challenging)
    RestorationTool.checkDam:  3,
    RestorationTool.coverCrop: 3,
    RestorationTool.biochar:   3,
    RestorationTool.compost:   3,
  };
  bool get canUseSelectedTool => (toolUses[selectedTool] ?? 0) > 0;

  // ── Phase 2 · Tool resupply ────────────────────────────────────────────────
  int    _patchesSinceResupply = 0;
  int    resupplyTriggered     = 0;
  bool   resupplyActive        = false;
  double resupplyTimer         = 0;
  static const double _resupplyDisplay = 2.2;

  // ── Phase 2 · Combo ────────────────────────────────────────────────────────
  int    comboCount       = 0;
  double comboTimer       = 0;
  static const double _comboWindow = 4.5;
  bool   showComboFlash   = false;
  double comboFlashTimer  = 0;

  // ── Phase 2 · Rain event ───────────────────────────────────────────────────
  double _rainTimer      = 45.0;
  bool   rainWarning     = false;
  bool   rainActive      = false;
  double _rainWarningCd  = 0;
  double _rainActiveCd   = 0;
  double weatherIntensity = 0;
  final Set<DegradedPatch> riskPatches = {};

  // ── Phase 2 · Critical alert events ───────────────────────────────────────
  final List<CriticalAlert> criticalAlerts = [];
  double _criticalAlertTimer = 48.0;
  int    criticalSaves       = 0;

  // ── Phase 2 · Gully expansion ──────────────────────────────────────────────
  final Map<DegradedPatch, double> _gullyIdleTimers = {};
  static const double _gullyExpandAt = 35.0;
  int    gulliesExpanded  = 0;
  double _gullyCheckTimer = 1.0;   // polls every 1 s for expansion candidates

  // ── Phase 2 · Wind strip ───────────────────────────────────────────────────
  double _windStripTimer = 25.0;

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

  // ── Eco-guide hint ─────────────────────────────────────────────────────────
  String  ecoGuideHint       = '';
  double  ecoGuideTimer      = 0;
  double  _hintCooldown      = 0;
  double  _idleTimer         = 0;

  // ── "Show-once" consciousness system ────────────────────────────────
  final Set<DegradationType> _seenScanCardTypes = {};
  final Set<String>          _seenToolHintKeys  = {};
  bool scanResultShowsHints  = true;   // drives ScanResultOverlay treatment guide
  bool toolSelectorShowsHints = true;  // drives LandToolSelector correct-tool highlight

  // ── Components ─────────────────────────────────────────────────────────────
  late RestorationDroneComponent drone;
  final List<DegradedPatch>      patches = [];
  // Patch refill timer — spawns new patches when player has explored most of current set
  double _refillTimer    = 0;
  static const double _refillInterval = 20.0;

  @override
  Future<void> onLoad() async {
    super.onLoad();
    worldW = size.x * kWorldScale;
    worldH = size.y * kWorldScale;
    dronePos = Vector2(worldW * 0.50, worldH * 0.50);
    _centerCamOn(dronePos);
    _targetCamX = camX; _targetCamY = camY;

    _initWindZones();
    add(ErodedLandRenderer(game: this));
    add(DeadVegetationLayer(game: this));
    _spawnDustClouds();
    drone = RestorationDroneComponent(game: this);
    add(drone);
    _spawnPatches();
    _assignSpecialPatches();

    bannerTimer = 3.5;
    overlays.add('banner');
    add(TimerComponent(period: 1.0, repeat: true, onTick: _onSecond));
  }

  void _centerCamOn(Vector2 pos) {
    camX = (pos.x - size.x / 2).clamp(0.0, worldW - size.x);
    camY = (pos.y - size.y / 2).clamp(0.0, worldH - size.y);
  }

  // Screen ↔ world helpers
  Vector2 screenToWorld(Vector2 s) => Vector2(s.x + camX, s.y + camY);
  Vector2 worldToScreen(Vector2 w) => Vector2(w.x - camX, w.y - camY);
  Vector2 get droneScreen => worldToScreen(dronePos);

  // ── Init helpers ───────────────────────────────────────────────────────────
  void _initWindZones() {
    final rng = math.Random(42);
    // Spread across the 3× world
    final positions = [
      Vector2(worldW * 0.18, worldH * 0.28),
      Vector2(worldW * 0.50, worldH * 0.18),
      Vector2(worldW * 0.72, worldH * 0.42),
      Vector2(worldW * 0.30, worldH * 0.62),
      Vector2(worldW * 0.82, worldH * 0.68),
    ];
    for (final pos in positions) {
      final angle = rng.nextDouble() * math.pi * 2;
      final mag   = 45.0 + rng.nextDouble() * 35.0;
      windZones.add(WindZone(
        center: pos,
        radius: 130.0 + rng.nextDouble() * 50.0,
        force:  Vector2(math.cos(angle) * mag, math.sin(angle) * mag),
      ));
      add(WindZoneRenderer(zone: windZones.last, game: this));
    }
  }

  void _spawnDustClouds() {
    final rng = math.Random(99);
    for (int i = 0; i < 5; i++) {
      final cloud = DustCloudComponent(
        game:   this,
        startX: worldW * (0.10 + rng.nextDouble() * 0.80),
        startY: worldH * (0.15 + rng.nextDouble() * 0.65),
        radius: 90.0  + rng.nextDouble() * 55.0,
        speed:  18.0  + rng.nextDouble() * 14.0,
        seed:   i * 33 + 7,
      );
      dustClouds.add(cloud);
      add(cloud);
    }
  }

  void _spawnPatches() {
    // 16 patches spread across the 3× world — player must explore to find them all
    const specs = [
      // Near-centre cluster (visible at start)
      (DegradationType.steepSlope, 0.38, 0.38),
      (DegradationType.gully,      0.52, 0.44),
      (DegradationType.bareLand,   0.46, 0.52),
      (DegradationType.drySoil,    0.58, 0.36),
      // Far left
      (DegradationType.steepSlope, 0.12, 0.28),
      (DegradationType.gully,      0.18, 0.58),
      (DegradationType.bareLand,   0.08, 0.72),
      (DegradationType.drySoil,    0.22, 0.42),
      // Far right
      (DegradationType.steepSlope, 0.82, 0.22),
      (DegradationType.gully,      0.76, 0.55),
      (DegradationType.bareLand,   0.88, 0.68),
      (DegradationType.drySoil,    0.70, 0.38),
      // Top / bottom extremes
      (DegradationType.steepSlope, 0.44, 0.14),
      (DegradationType.gully,      0.62, 0.76),
      (DegradationType.bareLand,   0.28, 0.80),
      (DegradationType.drySoil,    0.56, 0.18),
    ];
    for (int i = 0; i < specs.length; i++) {
      final (type, rx, ry) = specs[i];
      final p = DegradedPatch(
        game: this, type: type,
        worldX: worldW * rx, worldY: worldH * ry,
        seed: i * 17,
      );
      add(p);
      patches.add(p);
    }
  }

  // Spawn a fresh batch when the player has explored most existing patches
  void _tryRefillPatches() {
    final remaining = patches.where((p) => !p.isRestored).length;
    if (remaining < 4) {
      final rng = math.Random(patches.length * 13 + DateTime.now().millisecondsSinceEpoch);
      for (int i = 0; i < 6; i++) {
        final angle = rng.nextDouble() * math.pi * 2;
        final dist  = worldW * (0.20 + rng.nextDouble() * 0.25);
        final wx    = (dronePos.x + math.cos(angle) * dist).clamp(80.0, worldW - 80.0);
        final wy    = (dronePos.y + math.sin(angle) * dist).clamp(80.0, worldH - 80.0);
        final type  = DegradationType.values[rng.nextInt(DegradationType.values.length)];
        final p = DegradedPatch(game: this, type: type, worldX: wx, worldY: wy, seed: rng.nextInt(9999));
        add(p);
        patches.add(p);
      }
    }
  }

  void _assignSpecialPatches() {
    final rng = math.Random(DateTime.now().millisecondsSinceEpoch);
    // Pick 2 random distinct patches for eco-discovery
    final indices = List.generate(patches.length, (i) => i)..shuffle(rng);
    ecoDiscoveryIndices.add(indices[0]);
    ecoDiscoveryIndices.add(indices[1]);
    // Pick 1 for time bonus (not same as discoveries)
    timeBonusPatchIndex = indices[2];
  }

  void _onSecond() {
    if (!gameStarted || levelDone) return;
    timeLeft -= 1;
    if (timeLeft <= 0) { timeLeft = 0; _endLevel(); }
    notifyListeners();
  }

  // ── Getters ────────────────────────────────────────────────────────────────
  double get scanHoldProgress =>
      scanLockActive ? (_scanLockTimer / _scanDuration).clamp(0.0, 1.0) : 0.0;

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

  // ── Phase 1: User-triggered SCAN (mirrors sonarPing in NoisePollutionGame)
  void triggerScan() {
    if (!gameStarted || levelDone || gamePhase != 1) return;
    gameStarted = true;
    HapticFeedback.selectionClick();

    // If tool selector is open, pinging should not dismiss it
    if (toolSelectorOpen) {
      reactionMsg = '🔧 Select a tool from the panel first!';
      _triggerReaction(false, inRange: false);
      notifyListeners();
      return;
    }

    // If scan lock already active, do nothing (let it complete)
    if (scanLockActive) {
      reactionMsg = '📡 Scanning in progress…';
      _triggerReaction(true, inRange: true);
      notifyListeners();
      return;
    }

    // Find nearest unscanned patch in range
    DegradedPatch? nearest;
    double nearestD = _scanRange;
    for (final p in patches) {
      if (p.isScanned) continue;
      final d = (p.patchPos - dronePos).length;
      if (d < nearestD) { nearestD = d; nearest = p; }
    }

    if (nearest == null) {
      scanActive = true; scanRadius = 0;
      reactionMsg = '🛰️ No degraded zone in range — fly closer';
      _triggerReaction(false, inRange: false);
      notifyListeners();
      return;
    }

    // Begin 1.5s lock-scan on this patch
    _nearestScanTarget = nearest;
    activeScanPatch = nearest;
    scanLockActive = true;
    _scanLockTimer = 0;
    scanHoldTime = 0;
    scanActive = true; scanRadius = 0;
    reactionMsg = '📡 Scanning terrain — hold position!';
    _triggerReaction(true, inRange: true);
    HapticFeedback.lightImpact();
    notifyListeners();
  }

  // ── Phase 1: Quick scan (instant, fewer pts) — tap again while locked ─────
  void triggerQuickScan() {
    if (!gameStarted || levelDone || gamePhase != 1) return;
    HapticFeedback.selectionClick();
    int newly = 0;
    DegradedPatch? lastP;
    for (final p in patches) {
      if (p.isScanned) continue;
      if ((p.patchPos - dronePos).length <= _scanRange) {
        p.isScanned = true; 
        scannedCount++;
        const pts = 3;
        ecoPoints += pts; 
        newly++; 
        lastP = p;
        p.scanVariant = newly;
        lastScanPoints = pts;
      }
    }
    if (newly > 0) {
      scanActive = true; 
      scanRadius = 0;
      _handleScanStreak();
      if (lastP != null) {
        lastScannedPatch = lastP;
        lastScanResult   = TerrainScanResult.forType(
            lastP.type, withDiscovery: false, variant: lastP.scanVariant);
        scanCardPos      = dronePos.clone();
        scanResultTimer  = _scanResultDisplay;
        scanResultActive = true;
        overlays.add('scanResult');
      }
      reactionMsg = '+${newly * 3} pts  •  Quick scan complete';
      _triggerReaction(true);

      // FIXED: Only advance based on restorations, not scan count
      if (restoredCount >= kMinPatchesRequired) {
        Future.delayed(const Duration(milliseconds: 900), _advanceToPhase2);
      }
    } else {
      reactionMsg = '✈️ No unscanned patch in range';
      _triggerReaction(false, inRange: false);
    }
    notifyListeners();
  }

  // ── Phase 1: Full scan completion
  void _completePatchScan(DegradedPatch p) {
    if (p.isScanned) return;
    final idx            = patches.indexOf(p);
    final hasDiscovery   = ecoDiscoveryIndices.contains(idx);
    p.isScanned          = true;
    scannedCount++;
    p.scanVariant        = idx;

    final pts            = hasDiscovery ? 30 : 10;
    ecoPoints           += pts;
    lastScanPoints       = pts;
    scanActive           = true;
    scanRadius           = 0;
    lastScannedPatch     = p;
    lastScanResult       = TerrainScanResult.forType(
        p.type, withDiscovery: hasDiscovery, variant: idx);
    scanCardPos          = dronePos.clone();
    final firstScan = !_seenScanCardTypes.contains(p.type);
    if (firstScan) _seenScanCardTypes.add(p.type);
    scanResultShowsHints = firstScan;
    // Longer display so player can read and understand the identified issue
    scanResultTimer      = hasDiscovery ? 5.5 : 4.0;
    scanResultActive     = true;
    _handleScanStreak();
    HapticFeedback.heavyImpact();

    // Reset lock state
    scanLockActive  = false;
    _scanLockTimer  = 0;
    activeScanPatch = null;

    if (hasDiscovery) {
      ecoDiscoveriesFound++;
      discoveredEcoPatches.add(idx);
      lastDiscoveryFact    = lastScanResult!.discoveryFact;
      discoveryDisplayTimer = _discoveryDisplay;
      overlays.add('ecoDiscovery');
    } else {
      overlays.add('scanResult');
    }

    pendingFixTarget = p;
    notifyListeners();

    // Check for Phase 2 advancement only after sufficient restorations
    if (restoredCount >= kMinPatchesRequired) {
      Future.delayed(const Duration(milliseconds: 600), _advanceToPhase2);
    }
  }

  // ── Called when player taps "FIX IT" on scan result card ─────────────────
  void openToolSelectorForPending() {
    if (pendingFixTarget == null || toolSelectorOpen) return;
    toolSelectorOpen = true;
    overlays.remove('scanResult');
    scanResultActive = false;
    // First time for this type → show correct-tool highlight; else no hints
    toolSelectorShowsHints = _checkAndMarkHintsSeen(
        pendingFixTarget!.type, RestorationStep.none);
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
      reactionMsg      = '🎯 Scan Streak x$scanStreak!  +$bonus bonus pts';
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
          pendingFixTarget!.type, RestorationStep.none);
      overlays.add('toolSelect');
    }

    notifyListeners();

    // Only try to advance if we hit the restoration threshold
    if (restoredCount >= kMinPatchesRequired) {
      Future.delayed(const Duration(milliseconds: 400), _advanceToPhase2);
    }
  }

  void _advanceToPhase2() {
    if (levelDone || gamePhase >= 2) return;

    // Only advance to Phase 2 after minimum restorations
    if (restoredCount >= kMinPatchesRequired) {
      gamePhase = 2;
      bannerTimer = 3.0;
      overlays.add('banner');
      notifyListeners();
    }
  }

  // ── Phase 2: Apply tool ────────────────────────────────────────────────────
  void applyTool() {
    if (!gameStarted || levelDone) return;
    if (!canUseSelectedTool) {
      reactionMsg = '⚠️ No ${_toolLabel(selectedTool)} uses left!';
      _triggerReaction(false, inRange: false);
      notifyListeners();
      return;
    }
    // Use pending target (just-scanned) or nearest unrestored within range
    final target = pendingFixTarget ?? _nearestActionable;
    if (target == null) {
      reactionMsg = '✈️ Move closer to a scanned patch';
      _triggerReaction(false, inRange: false);
      notifyListeners();
      return;
    }

    HapticFeedback.lightImpact();
    toolUses[selectedTool] = (toolUses[selectedTool] ?? 1) - 1;

    final stepBeforeApply = target.step; // capture before mutation
    final correct = _isCorrectTool(target.type, selectedTool, stepBeforeApply);

    bool closeSelector = false;

    if (correct) {
      if (stepBeforeApply == RestorationStep.none) {
        // ── Step 1 correctly applied ─────────────────────────────────────────
        target.step = RestorationStep.stabilized; stabilizedCount++;
        correctTools++;
        erosionIndex = math.max(0, erosionIndex - 5.0);
        final pts    = 10 * _comboMult();
        ecoPoints   += pts; _incCombo();
        riskPatches.remove(target); target.isAtRisk = false;
        _gullyIdleTimers.remove(target);
        _dismissCriticalAlert(target, saved: true);
        reactionMsg  = '🏗️ Step ① done!  +$pts pts  —  Now apply Step ② (Biological)!';
        _triggerReaction(true);
        // Transition to Step 2 inside the same selector:
        // decide whether to show hints for step 2 (first time only)
        toolSelectorShowsHints = _checkAndMarkHintsSeen(
            target.type, RestorationStep.stabilized);
        // selector stays open (closeSelector = false)

      } else if (stepBeforeApply == RestorationStep.stabilized) {
        // ── Step 2 correctly applied → patch fully restored ──────────────────
        target.step = RestorationStep.restored; restoredCount++;
        correctTools++;
        erosionIndex = math.max(0, erosionIndex - 9.0);
        final pts    = 20 * _comboMult();
        ecoPoints   += pts; _incCombo();
        riskPatches.remove(target); target.isAtRisk = false;
        _dismissCriticalAlert(target, saved: true);
        reactionMsg  = '🌿 Patch Fully Restored!  +$pts pts  🎉';
        _triggerReaction(true);
        _patchesSinceLastSurge++;
        _patchesSinceResupply++;
        target.triggerSparkle = true;

        // Time bonus patch
        final idx = patches.indexOf(target);
        if (idx == timeBonusPatchIndex && !timeBonusCollected) {
          timeBonusCollected = true;
          timeLeft = math.min(timeLeft + 8, 150);
          reactionMsg = '⏱️ Time Bonus! +8 s  🌿 Fully Restored!  +$pts pts';
          HapticFeedback.heavyImpact();
        }

        // Tool resupply check
        if (_patchesSinceResupply >= 4) {
          _patchesSinceResupply = 0;
          _triggerResupply();
        }

        closeSelector = true; // both steps done → close now
      }
    } else {
      // ── Wrong tool → penalise, keep selector open to retry same step ────────
      wrongTools++;
      erosionIndex = math.min(100, erosionIndex + 3.0);
      ecoPoints    = math.max(0, ecoPoints - 5);
      _breakCombo();
      final stepNum = stepBeforeApply == RestorationStep.none ? '①' : '②';
      reactionMsg  = '❌ Wrong tool for Step $stepNum — try another!';
      _triggerReaction(false);
      // selector stays open (closeSelector = false)
    }

    if (closeSelector) {
      pendingFixTarget = null;
      toolSelectorOpen = false;
      overlays.remove('toolSelect');
      
      if (restoredCount >= kMinPatchesRequired) {
        Future.delayed(const Duration(milliseconds: 400), _advanceToPhase2);
      }
    }

    // ── Full-completion trigger (applyTool path) ───────────────────────────
    // Only stop here when every patch is fully restored (16/16).
    // • Time-expiry      → _onSecond()
    // • Tool-depletion   → Phase-2 update block
    // • Minimum reached  → does NOT end the level; player keeps playing freely
    if (patches.every((p) => p.isRestored)) {
      Future.delayed(const Duration(milliseconds: 600), _endLevel);
    }
    notifyListeners();
  }

  // ── Cancel tool selector (e.g. player taps ✕) ─────────────────────────────
  void cancelToolSelector() {
    toolSelectorOpen = false;
    pendingFixTarget = null;
    overlays.remove('toolSelect');
    notifyListeners();
  }

  void _triggerResupply() {
    // Find tool with fewest uses and top it up
    RestorationTool lowest = RestorationTool.terrace;
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

  // ── Critical alerts ────────────────────────────────────────────────────────
  void _spawnCriticalAlert() {
    // Pick a random unrestored, non-already-alert patch
    final candidates = patches.where((p) =>
        !p.isRestored &&
        criticalAlerts.every((a) => a.patch != p) &&
        !riskPatches.contains(p)).toList();
    if (candidates.isEmpty) return;
    candidates.shuffle(math.Random());
    final p = candidates.first;
    p.isCritical = true;
    final alert = CriticalAlert(patch: p, timeLeft: 12.0);
    criticalAlerts.add(alert);
    overlays.add('criticalAlert');
    HapticFeedback.heavyImpact();
    notifyListeners();
  }

  void _dismissCriticalAlert(DegradedPatch p, {bool saved = false}) {
    final alert = criticalAlerts.where((a) => a.patch == p).firstOrNull;
    if (alert == null) return;
    alert.handled = true;
    p.isCritical  = false;
    if (saved) { criticalSaves++; ecoPoints += 15; }
    criticalAlerts.removeWhere((a) => a.handled);
    if (criticalAlerts.isEmpty) overlays.remove('criticalAlert');
    notifyListeners();
  }

  void _expireCriticalAlert(CriticalAlert alert) {
    alert.handled         = true;
    alert.patch.isCritical = false;
    // Penalise: big erosion surge + points deduction
    erosionIndex = math.min(100, erosionIndex + 15.0);
    ecoPoints    = math.max(0, ecoPoints - 20);
    // Revert stabilised patch back to none (punishing neglect)
    if (alert.patch.step == RestorationStep.stabilized) {
      alert.patch.step = RestorationStep.none;
      stabilizedCount  = math.max(0, stabilizedCount - 1);
    }
    criticalAlerts.removeWhere((a) => a.handled);
    if (criticalAlerts.isEmpty) overlays.remove('criticalAlert');
    reactionMsg = '⛔ Critical zone collapsed!  -20 pts';
    _triggerReaction(false);
    notifyListeners();
  }

  // ── Gully expansion ────────────────────────────────────────────────────────
  void _checkGullyExpansion() {
    for (final p in List<DegradedPatch>.from(patches)) {
      if (p.type != DegradationType.gully) continue;
      if (p.isRestored || p.step != RestorationStep.none) {
        _gullyIdleTimers.remove(p); continue;
      }
      _gullyIdleTimers[p] = (_gullyIdleTimers[p] ?? 0) + 1;
      if ((_gullyIdleTimers[p] ?? 0) >= _gullyExpandAt) {
        _gullyIdleTimers.remove(p);
        _spawnChildGully(p);
      }
    }
  }

  void _spawnChildGully(DegradedPatch parent) {
    if (patches.length >= 24) return; // cap to avoid overflow
    final rng = math.Random();
    final nx  = (parent.hx + (rng.nextDouble() * 80 - 40))
        .clamp(60.0, worldW - 60);
    final ny  = (parent.hy + (rng.nextDouble() * 80 - 40))
        .clamp(60.0, worldH * 0.85 - 60);
    final child = DegradedPatch(
      game:   this, type: DegradationType.gully,
      worldX: nx,   worldY: ny,
      seed:   rng.nextInt(999),
      isChildPatch: true,
    );
    add(child);
    patches.add(child);
    gulliesExpanded++;
    child.isScanned = gamePhase == 2; // auto-scanned if already in phase 2
    erosionIndex = math.min(100, erosionIndex + 8.0);
    ecoPoints    = math.max(0, ecoPoints - 8);
    reactionMsg  = '⚠️ Gully expanded nearby!  -8 pts';
    _triggerReaction(false);
    notifyListeners();
  }

  // ── Wind strip ─────────────────────────────────────────────────────────────
  void _applyWindStrip() {
    // Only during high-wind phases
    if (windIntensity < 0.65) return;
    final bare = patches
        .where((p) => (p.type == DegradationType.bareLand ||
                       p.type == DegradationType.drySoil) &&
                       p.step == RestorationStep.stabilized &&
                       !p.isRestored)
        .toList()..shuffle(math.Random());
    if (bare.isEmpty) return;
    final victim = bare.first;
    victim.step      = RestorationStep.none;
    victim.windStripped = true;
    stabilizedCount  = math.max(0, stabilizedCount - 1);
    erosionIndex     = math.min(100, erosionIndex + 6.0);
    ecoPoints        = math.max(0, ecoPoints - 10);
    reactionMsg      = '🌬️ Wind stripped a bare patch!  -10 pts';
    _triggerReaction(false);
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
    if (comboCount >= 3) toolUses[selectedTool] = (toolUses[selectedTool] ?? 0) + 1;
    showComboFlash = true; comboFlashTimer = 1.8;
    notifyListeners();
  }

  void _breakCombo() { comboCount = 0; comboTimer = 0; }

  // ── Consciousness helpers ──────────────────────────────────────────────────
  bool _checkAndMarkHintsSeen(DegradationType type, RestorationStep step) {
    final key = '${type.index}_${step.index}';
    if (_seenToolHintKeys.contains(key)) return false;
    _seenToolHintKeys.add(key);
    return true;
  }

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

  // ── Eco-guide hints ────────────────────────────────────────────────────────
  void _checkHints() {
    if (_hintCooldown > 0 || ecoGuideTimer > 0) return;
    if (gamePhase == 1 && _idleTimer > 4.5) {
      ecoGuideHint = '🛰️ Fly close to a degraded zone then tap SCAN. Read the issue, then tap FIX IT!';
      ecoGuideTimer = 3.5; _hintCooldown = 12; _idleTimer = 0;
    } else if (gamePhase == 2) {
      if (wrongTools >= 3 && wrongTools > correctTools) {
        ecoGuideHint = '💡 Check the patch badge — STEP 1 needs structural tools; STEP 2 needs biological ones!';
        ecoGuideTimer = 3.5; _hintCooldown = 15;
      } else if (criticalAlerts.isNotEmpty && _idleTimer > 3.0) {
        ecoGuideHint = '⚡ Critical zone alert! Treat it fast to earn +15 bonus pts and avoid collapse!';
        ecoGuideTimer = 3.5; _hintCooldown = 8;
      }
    }
    notifyListeners();
  }

  void _endLevel() {
    if (levelDone) return;
    levelDone = true;
    pauseEngine();

    final meetsMin    = restoredCount >= kMinPatchesRequired;
    final allRestored = patches.every((p) => p.isRestored);

    // ── Completion state (drives banner visuals + CTA) ─────────────────────
    final LevelCompletionState completionState;
    if (allRestored) {
      completionState = LevelCompletionState.fullCompletion;
    } else if (meetsMin) {
      completionState = LevelCompletionState.moderate;
    } else {
      completionState = LevelCompletionState.failed;
    }

    // ── End reason (shown in LEVEL SUMMARY card on results screen) ─────────
    String endReason = '';
    if (timeLeft <= 0) {
      if (allRestored) {
        endReason = '🌍 All patches restored — and just in time!';
      } else if (meetsMin) {
        endReason = '⏰ Time expired — minimum $kMinPatchesRequired restorations met. '
            'Well done!';
      } else {
        endReason = '⏰ Time ran out before restoring $kMinPatchesRequired patches. '
            'Keep practising!';
      }
    } else if (allRestored) {
      endReason = '🌍 All ${patches.length} degradation patches fully restored! '
          'Outstanding work!';
    } else if (toolUses.values.every((uses) => uses == 0)) {
      endReason = meetsMin
          ? '🛠️ Tools depleted — minimum restorations achieved! Continue to the next stage.'
          : '🛠️ All tools depleted before reaching the $kMinPatchesRequired-patch minimum.';
    } else {
      endReason = meetsMin
          ? '✅ Minimum $kMinPatchesRequired restorations achieved — level complete!'
          : 'Level ended with $restoredCount/$kMinPatchesRequired patches restored.';
    }

    LandDegradationResult.current = LandDegradationResult(
      patchesRestored:     restoredCount,
      patchesStabilized:   stabilizedCount,
      correctTools:        correctTools,
      wrongTools:          wrongTools,
      ecoPoints:           ecoPoints,
      erosionIndex:        erosionIndex,
      terrainStabilised:   erosionIndex <= _targetErosion,
      scannedPatches:      scannedCount,
      maxCombo:            maxCombo,
      scanStreakBonus:      totalScanStreak,
      ecoDiscoveriesFound: ecoDiscoveriesFound,
      timeBonusCollected:  timeBonusCollected,
      criticalSaves:       criticalSaves,
      gulliesExpanded:     gulliesExpanded,
      resupplyTriggered:   resupplyTriggered,
      meetsMinimum:        meetsMin,
      minimumRequired:     kMinPatchesRequired,
      endReason:           endReason,
      completionState:     completionState,
    );

    overlays
      ..remove('reactionFx')
      ..remove('scanResult')
      ..remove('weatherAlert')
      ..remove('criticalAlert')
      ..remove('ecoDiscovery')
      ..remove('resupply')
      ..add('completionBanner');   // banner auto-switches to 'results' after 2.6 s

    notifyListeners();
  }

  // ── Input ──────────────────────────────────────────────────────────────────
  void setUpKey(bool v)    { isUp    = v; if (v) gameStarted = true; _idleTimer = 0; }
  void setDownKey(bool v)  { isDown  = v; if (v) gameStarted = true; _idleTimer = 0; }
  void setLeftKey(bool v)  { isLeft  = v; if (v) gameStarted = true; _idleTimer = 0; }
  void setRightKey(bool v) { isRight = v; if (v) gameStarted = true; _idleTimer = 0; }
  void selectTool(RestorationTool t) {
    selectedTool = t;
    notifyListeners();
    // Immediately apply after selection when tool selector is open
    if (toolSelectorOpen) applyTool();
  }
  void requestToolDialog() {
    if (gamePhase != 2 || levelDone) return;
    toolDialogRequested = true;
    notifyListeners();
  }
  void clearToolDialogRequest() { toolDialogRequested = false; }

  // ── Reaction FX ───────────────────────────────────────────────────────────
  void _triggerReaction(bool correct, {bool inRange = true}) {
    reactionActive  = true; reactionCorrect = correct;
    reactionPhase   = gamePhase; reactionInRange = inRange;
    reactionTimer   = 1.3;
    overlays.add('reactionFx');
  }

  // ── Camera follow with edge-scroll hints (mirrors NoisePollutionGame) ─────
  void _updateCamera(double dt) {
    final sw = size.x;
    final sh = size.y;
    final edgeW = sw * kEdgeFraction;
    final edgeH = sh * kEdgeFraction;

    // Drone position in screen coords relative to current camera
    final sx = dronePos.x - camX;
    final sy = dronePos.y - camY;

    double tx = _targetCamX;
    double ty = _targetCamY;

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

  // ── Update loop ────────────────────────────────────────────────────────────
  @override
  void update(double dt) {
    super.update(dt);

    // ── Global timers ──────────────────────────────────────────────────────
    if (bannerTimer > 0) {
      bannerTimer -= dt;
      if (bannerTimer <= 0) overlays.remove('banner');
    }
    if (reactionTimer > 0) {
      reactionTimer -= dt;
      if (reactionTimer <= 0) { reactionActive = false; overlays.remove('reactionFx'); }
    }
    if (scanActive) {
      scanRadius += dt * 230;
      if (scanRadius >= _scanMaxRadius) scanActive = false;
    }
    if (surgePulse > 0) {
      surgePulse = math.max(0, surgePulse - dt * 0.9);
      if (surgePulse == 0) surgePending = false;
    }
    // Eco-guide timer
    if (ecoGuideTimer > 0) { ecoGuideTimer -= dt; if (ecoGuideTimer <= 0) ecoGuideHint = ''; }
    if (_hintCooldown > 0) _hintCooldown -= dt;

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
      if (resupplyTimer <= 0) { resupplyActive = false; overlays.remove('resupply'); }
    }
    // Scan streak decay
    if (scanStreakTimer > 0) {
      scanStreakTimer -= dt;
      if (scanStreakTimer <= 0) scanStreak = 0;
    }

    if (!gameStarted || levelDone) { notifyListeners(); return; }

    // ── Drone movement with wind ─────────────────────────────────────────
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

    activeWindForce = Vector2.zero();
    windIntensity   = 0;
    for (final zone in windZones) {
      final d = (zone.center - dronePos).length;
      if (d < zone.radius) {
        final str = 1.0 - (d / zone.radius);
        activeWindForce += zone.force * str;
        windIntensity    = math.max(windIntensity, str * (zone.force.length / 90));
      }
    }
    dronePos.x = (dronePos.x + (vx * _droneSpeed + activeWindForce.x) * dt)
        .clamp(30, worldW - 30);
    dronePos.y = (dronePos.y + (vy * _droneSpeed + activeWindForce.y) * dt)
        .clamp(40, worldH * 0.97);

    // ── Camera follow with edge-scroll hints ──────────────────────────────
    _updateCamera(dt);

    // ── Patch refill timer ────────────────────────────────────────────────
    _refillTimer += dt;
    if (_refillTimer >= _refillInterval) {
      _refillTimer = 0;
      _tryRefillPatches();
    }

    // ── Wind direction rotation ──────────────────────────────────────────    _windChangeTimer += dt;
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

    // ── Phase 1: User-triggered scan lock (mirrors sonarPing timing logic) ───
    if (gamePhase == 1) {
      // Always update nearest target for UI feedback
      DegradedPatch? nearest; double nearestD = _scanRange;
      for (final p in patches) {
        if (p.isScanned) continue;
        final d = (p.patchPos - dronePos).length;
        if (d < nearestD) { nearestD = d; nearest = p; }
      }
      _nearestScanTarget = nearest;

      // Progress the lock-scan timer when active
      if (scanLockActive && activeScanPatch != null) {
        // Cancel lock if drone moves out of range
        final lockDist = (activeScanPatch!.patchPos - dronePos).length;
        if (lockDist > _scanRange * 1.15) {
          scanLockActive  = false;
          _scanLockTimer  = 0;
          activeScanPatch = null;
          reactionMsg = '📡 Scan cancelled — too far!';
          _triggerReaction(false, inRange: false);
        } else {
          final rate = inDustCloud ? 0.45 : 1.0;
          _scanLockTimer += dt * rate;
          scanHoldTime = _scanLockTimer; // keep backward-compat for render
          if (_scanLockTimer >= _scanDuration) {
            final p = activeScanPatch!;
            _completePatchScan(p);
          }
        }
      } else if (!scanLockActive) {
        activeScanPatch = null;
        scanHoldTime = 0;
      }
    }

    // ── Phase 2 timers ────────────────────────────────────────────────────
    if (gamePhase == 2) {
      if (comboCount > 0) {
        comboTimer -= dt;
        if (comboTimer <= 0) _breakCombo();
      }
      if (comboFlashTimer > 0) {
        comboFlashTimer -= dt;
        if (comboFlashTimer <= 0) showComboFlash = false;
      }

      // Rain
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

      // Critical alerts
      _criticalAlertTimer -= dt;
      if (_criticalAlertTimer <= 0 && criticalAlerts.length < 2) {
        _criticalAlertTimer = 42.0 + math.Random().nextDouble() * 20.0;
        _spawnCriticalAlert();
      }
      for (final alert in List<CriticalAlert>.from(criticalAlerts)) {
        if (!alert.handled) {
          alert.timeLeft -= dt;
          if (alert.timeLeft <= 0) _expireCriticalAlert(alert);
        }
      }

      // Gully expansion
      _gullyCheckTimer -= dt;
      if (_gullyCheckTimer <= 0) {
        _gullyCheckTimer = 1.0;
        _checkGullyExpansion();
      }

      // Wind strip
      _windStripTimer -= dt;
      if (_windStripTimer <= 0) {
        _windStripTimer = 20.0 + math.Random().nextDouble() * 12.0;
        _applyWindStrip();
      }

      // ── Tool-depletion end-game check ────────────────────────────────────
      // All 5 tools at 0 uses AND no resupply currently active → player can
      // no longer make any progress; end the level now.
      if (!levelDone && !resupplyActive &&
          toolUses.values.every((uses) => uses == 0)) {
        Future.delayed(const Duration(milliseconds: 600), _endLevel);
      }
    }

    notifyListeners();
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  ERODED LAND RENDERER  — richly layered 2D degraded terrain
// ══════════════════════════════════════════════════════════════════════════════
class ErodedLandRenderer extends Component {
  final LandDegradationGame game;
  double _t = 0;

  late final List<_GullyFeature>   _gullies;
  late final List<_RockFeature>    _rocks;
  late final List<_CrackNetwork>   _crackNets;
  late final List<_ErosionChannel> _channels;
  late final List<_HillRidge>      _hills;
  late final List<_SedimentFan>    _fans;
  // Animated dust motes
  late final List<_DustMote>       _motes;

  ErodedLandRenderer({required this.game});

  @override
  void onLoad() { _initTerrain(); }

  void _initTerrain() {
    final w   = game.worldW;
    final h   = game.worldH;
    final rng = math.Random(77);

    // Background hill ridges — silhouette depth
    _hills = [
      _HillRidge(points: [
        Offset(0, h * 0.22), Offset(w * 0.15, h * 0.16),
        Offset(w * 0.30, h * 0.20), Offset(w * 0.45, h * 0.14),
        Offset(w * 0.60, h * 0.19), Offset(w * 0.75, h * 0.12),
        Offset(w * 0.90, h * 0.17), Offset(w, h * 0.20),
        Offset(w, h * 0.28), Offset(0, h * 0.28),
      ], color: const Color(0xFF120A04)),
      _HillRidge(points: [
        Offset(0, h * 0.26), Offset(w * 0.20, h * 0.21),
        Offset(w * 0.38, h * 0.24), Offset(w * 0.55, h * 0.18),
        Offset(w * 0.72, h * 0.23), Offset(w * 0.88, h * 0.19),
        Offset(w, h * 0.24), Offset(w, h * 0.32), Offset(0, h * 0.32),
      ], color: const Color(0xFF1A0E06)),
    ];

    // Main erosion gullies with more branching
    _gullies = [
      _GullyFeature(start: Offset(w * 0.28, h * 0.10), end: Offset(w * 0.34, h * 0.70),
          width: 14.0, branches: 5, seed: 11),
      _GullyFeature(start: Offset(w * 0.62, h * 0.08), end: Offset(w * 0.68, h * 0.60),
          width: 11.0, branches: 4, seed: 29),
      _GullyFeature(start: Offset(w * 0.05, h * 0.35), end: Offset(w * 0.45, h * 0.40),
          width: 9.0, branches: 3, seed: 47),
      // New: dry riverbed gully
      _GullyFeature(start: Offset(w * 0.40, h * 0.68), end: Offset(w * 0.78, h * 0.82),
          width: 16.0, branches: 2, seed: 63, isDryRiver: true),
    ];

    // Rock outcrops
    _rocks = List.generate(22, (i) {
      return _RockFeature(
        x: rng.nextDouble() * w,
        y: h * 0.18 + rng.nextDouble() * h * 0.64,
        size: 8.0 + rng.nextDouble() * 24.0,
        seed: i * 13,
      );
    });

    // Crack networks
    _crackNets = List.generate(9, (i) {
      return _CrackNetwork(
        cx: w * (0.08 + rng.nextDouble() * 0.84),
        cy: h * (0.18 + rng.nextDouble() * 0.62),
        radius: 40.0 + rng.nextDouble() * 50.0,
        seed: i * 37 + 3,
      );
    });

    // Erosion channels
    _channels = List.generate(15, (i) {
      return _ErosionChannel(
        startX: rng.nextDouble() * w,
        startY: rng.nextDouble() * h * 0.3,
        length: 80.0 + rng.nextDouble() * 140.0,
        angle:  0.8 + rng.nextDouble() * 0.8,
        seed:   i * 7,
      );
    });

    // Sediment fans
    _fans = [
      _SedimentFan(x: w * 0.22, y: h * 0.68, r: 46.0),
      _SedimentFan(x: w * 0.48, y: h * 0.52, r: 38.0),
      _SedimentFan(x: w * 0.70, y: h * 0.74, r: 54.0),
      _SedimentFan(x: w * 0.85, y: h * 0.58, r: 30.0),
    ];

    // Animated dust motes
    _motes = List.generate(60, (i) {
      return _DustMote(
        x: rng.nextDouble() * w,
        y: h * 0.18 + rng.nextDouble() * h * 0.70,
        speed: 8.0 + rng.nextDouble() * 18.0,
        drift: rng.nextDouble() * 2 - 1,
        size:  1.0 + rng.nextDouble() * 2.5,
        seed:  i * 7 + 3,
      );
    });
  }

  @override
  void update(double dt) {
    _t += dt * 0.28;
    // Animate dust motes across the world
    for (final m in _motes) {
      m.x += m.drift * dt * 12;
      m.y -= m.speed * dt * 0.4;
      if (m.y < game.worldH * 0.14) m.y = game.worldH * 0.85;
      if (m.x < 0) m.x = game.worldW;
      if (m.x > game.worldW) m.x = 0;
    }
  }

  @override
  void render(Canvas canvas) {
    final w  = game.worldW;
    final h  = game.worldH;
    final sw = game.size.x;
    final sh = game.size.y;

    // Shift canvas into world space so all drawing uses world coordinates
    canvas.save();
    canvas.translate(-game.camX, -game.camY);

    _drawHazySky(canvas, w, h);
    _drawHillRidges(canvas, w, h);
    _drawBaseGround(canvas, w, h);
    _drawSlopeShading(canvas, w, h);
    _drawDryRiverbedTexture(canvas, w, h);
    _drawCrackNetworks(canvas, w, h);
    _drawErosionChannels(canvas, w, h);
    _drawGullies(canvas, w, h);
    _drawSedimentFans(canvas, w, h);
    _drawRockOutcrops(canvas, w, h);
    _drawBarrenTexture(canvas, w, h);
    _drawDustMotes(canvas, w, h);
    _drawFooterStrip(canvas, w, h);

    // Restoration progress greening
    final restoreRatio = game.patches.isEmpty ? 0.0
        : game.restoredCount / game.patches.length;
    if (restoreRatio > 0) {
      canvas.drawRect(Rect.fromLTWH(0, 0, w, h),
          Paint()
            ..color = const Color(0xFF1B5E20).withValues(alpha: restoreRatio * 0.08)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40));
    }

    // Erosion tint overlay
    final er = (game.erosionIndex / 92.0).clamp(0.0, 1.0);
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h),
        Paint()
          ..color = const Color(0xFFEF5350).withValues(alpha: er * 0.065)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30));

    // Surge flash
    if (game.surgePulse > 0) {
      canvas.drawRect(Rect.fromLTWH(0, 0, w, h),
          Paint()..color = const Color(0xFFFF6D00)
              .withValues(alpha: game.surgePulse * 0.20));
    }

    if (game.weatherIntensity > 0) _drawRain(canvas, w, h);

    canvas.restore();

    // ── Edge-scroll vignette hints (screen space — drawn after restore) ─────
    _drawEdgeHints(canvas, sw, sh);
  }

  void _drawEdgeHints(Canvas canvas, double sw, double sh) {
    const hintColor = Color(0xFF8BC34A); // green for land theme
    void drawVignette(double alpha, Alignment from, Alignment to) {
      if (alpha < 0.01) return;
      canvas.drawRect(
        Rect.fromLTWH(0, 0, sw, sh),
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(sw * (from.x + 1) / 2, sh * (from.y + 1) / 2),
            Offset(sw * (to.x + 1) / 2, sh * (to.y + 1) / 2),
            [
              hintColor.withValues(alpha: alpha * 0.35),
              Colors.transparent,
            ],
          ),
      );
    }
    drawVignette(game.edgeHintLeft,   Alignment.centerLeft,   Alignment.center);
    drawVignette(game.edgeHintRight,  Alignment.centerRight,  Alignment.center);
    drawVignette(game.edgeHintTop,    Alignment.topCenter,    Alignment.center);
    drawVignette(game.edgeHintBottom, Alignment.bottomCenter, Alignment.center);
  }

  void _drawHazySky(Canvas canvas, double w, double h) {
    // Layered hazy sky — ochre/brown degraded dryland atmosphere
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h * 0.20),
        Paint()..shader = ui.Gradient.linear(
          Offset.zero, Offset(0, h * 0.20),
          [const Color(0xFF3D1A04), const Color(0xFF1C0C04)],
          [0.0, 1.0],
        ));

    // Haze band at horizon (volumetric dust suspended in air)
    canvas.drawRect(Rect.fromLTWH(0, h * 0.12, w, h * 0.10),
        Paint()
          ..color = const Color(0xFFD4A05A).withValues(alpha: 0.06 + math.sin(_t * 0.5) * 0.02)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22));

    // Sun disc (hazy through dust)
    canvas.drawCircle(Offset(w * 0.75, h * 0.09), 18,
        Paint()
          ..color = const Color(0xFFFFCC80).withValues(alpha: 0.12)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12));
    canvas.drawCircle(Offset(w * 0.75, h * 0.09), 8,
        Paint()..color = const Color(0xFFFFE082).withValues(alpha: 0.18));
  }

  void _drawHillRidges(Canvas canvas, double w, double h) {
    for (final hill in _hills) {
      final path = Path();
      for (int i = 0; i < hill.points.length; i++) {
        i == 0 ? path.moveTo(hill.points[i].dx, hill.points[i].dy)
               : path.lineTo(hill.points[i].dx, hill.points[i].dy);
      }
      path.close();
      canvas.drawPath(path, Paint()..color = hill.color);
    }
  }

  void _drawBaseGround(Canvas canvas, double w, double h) {
    // Multi-layer degraded laterite soil bands — visible soil profile
    final layers = [
      (0.20, 0.38, const Color(0xFF1C0E06), const Color(0xFF2A1508)),
      (0.38, 0.56, const Color(0xFF2A1508), const Color(0xFF221005)),
      (0.56, 0.72, const Color(0xFF221005), const Color(0xFF1A0C04)),
      (0.72, 0.86, const Color(0xFF1A0C04), const Color(0xFF140A02)),
    ];
    for (final (from, to, c1, c2) in layers) {
      canvas.drawRect(
        Rect.fromLTWH(0, h * from, w, h * (to - from)),
        Paint()..shader = ui.Gradient.linear(
          Offset(0, h * from), Offset(0, h * to), [c1, c2],
        ),
      );
    }
  }

  void _drawDryRiverbedTexture(Canvas canvas, double w, double h) {
    // A prominent dry riverbed sweeping lower third
    final path = Path();
    path.moveTo(w * 0.38, h * 0.65);
    path.cubicTo(w * 0.48, h * 0.67, w * 0.62, h * 0.70, w * 0.80, h * 0.80);
    path.lineTo(w * 0.85, h * 0.80);
    path.cubicTo(w * 0.66, h * 0.70, w * 0.52, h * 0.67, w * 0.42, h * 0.65);
    path.close();
    canvas.drawPath(path,
        Paint()
          ..color = const Color(0xFF0A0502).withValues(alpha: 0.60)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));

    // Exposed dry riverbed gravel texture
    final rng = math.Random(301);
    for (int i = 0; i < 20; i++) {
      final rx = w * 0.38 + rng.nextDouble() * w * 0.47;
      final ry = h * 0.65 + rng.nextDouble() * h * 0.14;
      canvas.drawOval(
        Rect.fromCenter(center: Offset(rx, ry),
            width: 4.0 + rng.nextDouble() * 8.0,
            height: 2.5 + rng.nextDouble() * 4.0),
        Paint()..color = const Color(0xFF3A2010).withValues(alpha: 0.38),
      );
    }
  }

  void _drawSlopeShading(Canvas canvas, double w, double h) {
    final zones = [
      (0.0, 0.18, 0.28, 0.52), (0.55, 0.15, 0.45, 0.55), (0.0, 0.60, 0.50, 0.86),
    ];
    for (final (lx, ly, lw, lh) in zones) {
      canvas.drawRect(
        Rect.fromLTWH(w * lx, h * ly, w * lw, h * lh),
        Paint()..shader = ui.Gradient.radial(
          Offset(w * (lx + lw / 2), h * (ly + lh / 2)),
          math.max(w * lw, h * lh) * 0.6,
          [const Color(0xFF3A2010).withValues(alpha: 0.28), Colors.transparent],
        ),
      );
    }
  }

  void _drawCrackNetworks(Canvas canvas, double w, double h) {
    for (final net in _crackNets) {
      final rng   = math.Random(net.seed);
      final paint = Paint()
        ..color = const Color(0xFF3D2010).withValues(alpha: 0.58)
        ..strokeWidth = 0.9
        ..strokeCap = StrokeCap.round;

      final pts = List.generate(7, (i) {
        final angle = (i / 7) * math.pi * 2 + rng.nextDouble() * 0.7;
        final r = net.radius * (0.5 + rng.nextDouble() * 0.5);
        return Offset(net.cx + math.cos(angle) * r, net.cy + math.sin(angle) * r);
      });

      for (final pt in pts) {
        canvas.drawLine(Offset(net.cx, net.cy), pt, paint);
        for (int b = 0; b < 3; b++) {
          final mid = Offset(
            (net.cx + pt.dx) / 2 + rng.nextDouble() * 10 - 5,
            (net.cy + pt.dy) / 2 + rng.nextDouble() * 10 - 5,
          );
          canvas.drawLine(mid,
              Offset(mid.dx + rng.nextDouble() * 20 - 10, mid.dy + rng.nextDouble() * 20 - 10),
              paint..color = const Color(0xFF3D2010).withValues(alpha: 0.30));
        }
      }
      for (int i = 0; i < pts.length; i++) {
        canvas.drawLine(pts[i], pts[(i + 1) % pts.length],
            paint..color = const Color(0xFF3D2010).withValues(alpha: 0.40));
      }
    }
  }

  void _drawErosionChannels(Canvas canvas, double w, double h) {
    for (final ch in _channels) {
      final rng = math.Random(ch.seed);
      final path = Path();
      path.moveTo(ch.startX, ch.startY);
      double cx = ch.startX, cy = ch.startY;
      for (int s = 0; s < 10; s++) {
        final nx = cx + math.cos(ch.angle + math.sin(s * 1.3) * 0.45) * ch.length / 10;
        final ny = cy + math.sin(ch.angle + math.cos(s * 0.9) * 0.35) * ch.length / 10;
        path.lineTo(nx, ny);
        cx = nx; cy = ny;
      }
      canvas.drawPath(path,
          Paint()
            ..color = const Color(0xFF080402).withValues(alpha: 0.48)
            ..strokeWidth = 1.8 + rng.nextDouble() * 2.5
            ..strokeCap = StrokeCap.round
            ..style = PaintingStyle.stroke);
    }
  }

  void _drawGullies(Canvas canvas, double w, double h) {
    for (final gully in _gullies) {
      final rng = math.Random(gully.seed);
      final dx = gully.end.dx - gully.start.dx;
      final dy = gully.end.dy - gully.start.dy;
      final len = math.sqrt(dx * dx + dy * dy);
      final nx  = -dy / len; final ny = dx / len;

      final path = Path();
      path.moveTo(gully.start.dx + nx * gully.width * 0.4, gully.start.dy + ny * gully.width * 0.4);
      path.lineTo(gully.end.dx + nx * gully.width, gully.end.dy + ny * gully.width);
      path.lineTo(gully.end.dx - nx * gully.width, gully.end.dy - ny * gully.width);
      path.lineTo(gully.start.dx - nx * gully.width * 0.4, gully.start.dy - ny * gully.width * 0.4);
      path.close();

      canvas.drawPath(path,
          Paint()
            ..color = gully.isDryRiver
                ? const Color(0xFF080402).withValues(alpha: 0.65)
                : const Color(0xFF050302).withValues(alpha: 0.78)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));

      // Wall highlight
      canvas.drawLine(
        Offset(gully.start.dx + nx * gully.width * 0.4, gully.start.dy + ny * gully.width * 0.4),
        Offset(gully.end.dx + nx * gully.width, gully.end.dy + ny * gully.width),
        Paint()..color = const Color(0xFF6B3A1C).withValues(alpha: 0.38)..strokeWidth = 2.2,
      );

      // Side branches
      for (int b = 0; b < gully.branches; b++) {
        final t   = 0.15 + (b / gully.branches) * 0.75;
        final bx  = gully.start.dx + dx * t;
        final by  = gully.start.dy + dy * t;
        final ba  = math.atan2(dy, dx) + (rng.nextBool() ? 0.6 : -0.6) + rng.nextDouble() * 0.4;
        final bl  = 18.0 + rng.nextDouble() * 40.0;
        canvas.drawLine(
          Offset(bx, by),
          Offset(bx + math.cos(ba) * bl, by + math.sin(ba) * bl),
          Paint()..color = const Color(0xFF050302).withValues(alpha: 0.48)
            ..strokeWidth = 3.0 + rng.nextDouble() * 3.5
            ..strokeCap = StrokeCap.round,
        );
      }

      // Dry riverbed shimmer (animated)
      if (gully.isDryRiver) {
        final shimmerAlpha = 0.04 + math.sin(_t * 1.8) * 0.02;
        canvas.drawPath(path,
            Paint()..color = const Color(0xFF4A3010).withValues(alpha: shimmerAlpha));
      }
    }
  }

  void _drawSedimentFans(Canvas canvas, double w, double h) {
    for (final fan in _fans) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(fan.x, fan.y), width: fan.r * 2.2, height: fan.r * 0.8),
        Paint()
          ..color = const Color(0xFF5A3820).withValues(alpha: 0.24)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
      );
      final rng = math.Random(fan.x.toInt() + fan.y.toInt());
      for (int i = 0; i < 10; i++) {
        canvas.drawCircle(
          Offset(fan.x + rng.nextDouble() * fan.r * 1.6 - fan.r * 0.8,
                 fan.y + rng.nextDouble() * fan.r * 0.5 - fan.r * 0.25),
          1.5 + rng.nextDouble() * 3.0,
          Paint()..color = const Color(0xFF4A2810).withValues(alpha: 0.30),
        );
      }
    }
  }

  void _drawRockOutcrops(Canvas canvas, double w, double h) {
    for (final rock in _rocks) {
      final rng = math.Random(rock.seed);
      final cx = rock.x; final cy = rock.y; final s = rock.size;

      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx + s * 0.2, cy + s * 0.4), width: s * 1.9, height: s * 0.65),
        Paint()..color = Colors.black.withValues(alpha: 0.28)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );

      final path = Path();
      final sides = 5 + rng.nextInt(3);
      for (int i = 0; i < sides; i++) {
        final angle = (i / sides) * math.pi * 2 - math.pi / 2;
        final r = s * (0.7 + rng.nextDouble() * 0.38);
        final px = cx + math.cos(angle) * r;
        final py = cy + math.sin(angle) * r * 0.65;
        i == 0 ? path.moveTo(px, py) : path.lineTo(px, py);
      }
      path.close();

      final rockColor = Color.lerp(
          const Color(0xFF3A2515), const Color(0xFF4E3020), rng.nextDouble())!;
      canvas.drawPath(path, Paint()..color = rockColor);

      // Highlight face
      final hlPath = Path();
      hlPath.moveTo(cx, cy - s * 0.5);
      hlPath.lineTo(cx - s * 0.4, cy - s * 0.1);
      hlPath.lineTo(cx + s * 0.3, cy - s * 0.1);
      hlPath.close();
      canvas.drawPath(hlPath,
          Paint()..color = const Color(0xFF6B4828).withValues(alpha: 0.55));

      // Lichen patches on large rocks
      if (s > 16) {
        canvas.drawCircle(Offset(cx - s * 0.2, cy - s * 0.2), s * 0.22,
            Paint()..color = const Color(0xFF4A5520).withValues(alpha: 0.28));
      }

      // Crack
      canvas.drawLine(Offset(cx - s * 0.1, cy - s * 0.2), Offset(cx + s * 0.15, cy + s * 0.15),
          Paint()..color = Colors.black.withValues(alpha: 0.32)..strokeWidth = 1.2);
    }
  }

  void _drawBarrenTexture(Canvas canvas, double w, double h) {
    final rng   = math.Random(55);
    final paint = Paint()..strokeWidth = 1.2..strokeCap = StrokeCap.round;

    // Fine stippling
    for (int i = 0; i < 280; i++) {
      final x = rng.nextDouble() * w;
      final y = rng.nextDouble() * h * 0.84;
      final alpha = 0.05 + rng.nextDouble() * 0.13;
      paint.color = const Color(0xFF6B4020).withValues(alpha: alpha);
      canvas.drawCircle(Offset(x, y), 0.7 + rng.nextDouble() * 2.0, paint);
    }

    // Dead vegetation stubs — more varied
    for (int i = 0; i < 45; i++) {
      final x = rng.nextDouble() * w;
      final y = h * 0.20 + rng.nextDouble() * h * 0.62;
      final stemH = 3.0 + rng.nextDouble() * 10.0;
      final lean  = rng.nextDouble() * 4 - 2;
      canvas.drawLine(
        Offset(x, y), Offset(x + lean, y - stemH),
        Paint()..color = const Color(0xFF4A3010).withValues(alpha: 0.38)
          ..strokeWidth = 0.8 + rng.nextDouble() * 0.8..strokeCap = StrokeCap.round,
      );
      // Small branch
      if (stemH > 6) {
        canvas.drawLine(
          Offset(x + lean * 0.5, y - stemH * 0.55),
          Offset(x + lean * 0.5 + rng.nextDouble() * 5 - 2.5, y - stemH * 0.75),
          Paint()..color = const Color(0xFF4A3010).withValues(alpha: 0.25)
            ..strokeWidth = 0.6..strokeCap = StrokeCap.round,
        );
      }
    }
  }

  void _drawDustMotes(Canvas canvas, double w, double h) {
    final paint = Paint();
    for (final m in _motes) {
      final alpha = 0.04 + math.sin(_t * m.seed * 0.3 + m.x * 0.01) * 0.03;
      paint.color = const Color(0xFFBCAAA4).withValues(alpha: alpha.clamp(0.01, 0.08));
      canvas.drawCircle(Offset(m.x, m.y), m.size, paint);
    }
  }

  void _drawFooterStrip(Canvas canvas, double w, double h) {
    canvas.drawRect(Rect.fromLTWH(0, h * 0.86, w, h * 0.14),
        Paint()..color = const Color(0xFF070500));
    canvas.drawLine(Offset(0, h * 0.86), Offset(w, h * 0.86),
        Paint()..color = const Color(0xFF3A1E08).withValues(alpha: 0.52)..strokeWidth = 1.5);
  }

  void _drawRain(Canvas canvas, double w, double h) {
    final alpha = game.weatherIntensity * 0.58;
    final rng   = math.Random(11);
    final paint = Paint()
      ..color = const Color(0xFF90CAF9).withValues(alpha: alpha)
      ..strokeWidth = 1.0..strokeCap = StrokeCap.round;
    for (int i = 0; i < 100; i++) {
      final rx    = rng.nextDouble() * w;
      final ry    = rng.nextDouble() * h;
      final len   = 10.0 + rng.nextDouble() * 20.0;
      final phase = ((_t * 4.5 + rng.nextDouble() * 6.0) % 1.0);
      final y     = (ry + phase * h * 0.6) % h;
      canvas.drawLine(Offset(rx - len * 0.15, y), Offset(rx + len * 0.15, y + len), paint);
    }
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h),
        Paint()..color = const Color(0xFF1565C0).withValues(alpha: game.weatherIntensity * 0.08));
  }
}

// ── Data classes for terrain features ─────────────────────────────────────────
class _GullyFeature {
  final Offset start, end;
  final double width;
  final int    branches, seed;
  final bool   isDryRiver;
  const _GullyFeature({required this.start, required this.end, required this.width,
    required this.branches, required this.seed, this.isDryRiver = false});
}
class _RockFeature    { final double x, y, size; final int seed;
  const _RockFeature({required this.x, required this.y, required this.size, required this.seed}); }
class _CrackNetwork   { final double cx, cy, radius; final int seed;
  const _CrackNetwork({required this.cx, required this.cy, required this.radius, required this.seed}); }
class _ErosionChannel { final double startX, startY, length, angle; final int seed;
  const _ErosionChannel({required this.startX, required this.startY, required this.length,
    required this.angle, required this.seed}); }
class _HillRidge      { final List<Offset> points; final Color color;
  const _HillRidge({required this.points, required this.color}); }
class _SedimentFan    { final double x, y, r;
  const _SedimentFan({required this.x, required this.y, required this.r}); }
class _DustMote       { double x, y; final double speed, drift, size; final double seed;
  _DustMote({required this.x, required this.y, required this.speed,
    required this.drift, required this.size, required int seed}) : seed = seed.toDouble(); }

// ══════════════════════════════════════════════════════════════════════════════
//  DEAD VEGETATION LAYER  — pre-computed dead trees and dried shrubs
// ══════════════════════════════════════════════════════════════════════════════
class DeadVegetationLayer extends Component {
  final LandDegradationGame game;
  late final List<_DeadTree> _trees;
  double _t = 0;
  DeadVegetationLayer({required this.game});

  @override
  void onLoad() {
    final rng = math.Random(123);
    final w   = game.worldW;
    final h   = game.worldH;
    _trees    = List.generate(12, (i) {
      return _DeadTree(
        x:    rng.nextDouble() * w,
        y:    h * 0.22 + rng.nextDouble() * h * 0.55,
        h:    22.0 + rng.nextDouble() * 32.0,
        lean: rng.nextDouble() * 0.22 - 0.11,
        seed: i * 31 + 5,
      );
    });
  }

  @override
  void update(double dt) => _t += dt;

  @override
  void render(Canvas canvas) {
    canvas.save();
    canvas.translate(-game.camX, -game.camY);
    for (final tree in _trees) {
      _drawDeadTree(canvas, tree);
    }
    canvas.restore();
  }

  void _drawDeadTree(Canvas canvas, _DeadTree tree) {
    final rng   = math.Random(tree.seed);
    final paint = Paint()
      ..color = const Color(0xFF2A1808).withValues(alpha: 0.70)
      ..strokeWidth = 2.5 + rng.nextDouble() * 2.0
      ..strokeCap = StrokeCap.round;

    // Main trunk
    canvas.drawLine(
      Offset(tree.x, tree.y),
      Offset(tree.x + tree.lean * tree.h, tree.y - tree.h),
      paint,
    );

    // Branches
    for (int b = 0; b < 4 + rng.nextInt(3); b++) {
      final t   = 0.4 + b * 0.15 + rng.nextDouble() * 0.08;
      final bx  = tree.x + tree.lean * tree.h * t;
      final by  = tree.y - tree.h * t;
      final ba  = (rng.nextBool() ? 1 : -1) * (0.5 + rng.nextDouble() * 0.8);
      final bl  = tree.h * (0.15 + rng.nextDouble() * 0.25);
      canvas.drawLine(
        Offset(bx, by),
        Offset(bx + math.cos(ba) * bl, by + math.sin(ba) * bl),
        paint..strokeWidth = 1.0 + rng.nextDouble() * 1.2,
      );
    }
  }
}

class _DeadTree { final double x, y, h, lean; final int seed;
  const _DeadTree({required this.x, required this.y, required this.h,
    required this.lean, required this.seed}); }

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
    canvas.save();
    canvas.translate(-game.camX, -game.camY);
    _renderWorld(canvas);
    canvas.restore();
  }

  void _renderWorld(Canvas canvas) {
    final cx = game.dronePos.x;
    final cy = game.dronePos.y + math.sin(_t * 3.0) * 2.5;

    // Scan pulse ring
    if (game.scanActive) {
      final alpha = (1.0 - game.scanRadius / LandDegradationGame._scanMaxRadius) * 0.32;
      canvas.drawCircle(Offset(cx, cy), game.scanRadius,
          Paint()
            ..color = const Color(0xFFFFB300).withValues(alpha: alpha)
            ..style = PaintingStyle.stroke..strokeWidth = 2.8);
    }

    // Range indicator
    final rangeColor = game.gamePhase == 1
        ? const Color(0xFFFFB300) : const Color(0xFF69F0AE);
    final rangeR     = game.gamePhase == 1
        ? LandDegradationGame._scanRange : LandDegradationGame._applyRange;
    canvas.drawCircle(Offset(cx, cy), rangeR,
        Paint()
          ..color = rangeColor.withValues(alpha: 0.065)
          ..style = PaintingStyle.stroke..strokeWidth = 1.2);

    // Phase 1: dashed hover-range
    if (game.gamePhase == 1) {
      final dashPaint = Paint()
        ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.09)
        ..style = PaintingStyle.stroke..strokeWidth = 1.0..strokeCap = StrokeCap.round;
      const double r = LandDegradationGame._hoverRange;
      const int    segments = 28;
      const double dashFrac = 0.55;
      for (int seg = 0; seg < segments; seg++) {
        final startAngle = (seg / segments) * math.pi * 2 + _t * 0.65;
        final sweep      = (math.pi * 2 / segments) * dashFrac;
        canvas.drawArc(
          Rect.fromCenter(center: Offset(cx, cy), width: r * 2, height: r * 2),
          startAngle, sweep, false, dashPaint,
        );
      }
    }

    // Scan progress arc — drawn at active scan patch, not drone (but reflected on drone glow)
    if (game.gamePhase == 1 && game.activeScanPatch != null) {
      final prog  = game.scanHoldProgress;
      final glow  = 0.6 + prog * 0.35;
      canvas.drawCircle(Offset(cx, cy), 12 + prog * 8,
          Paint()
            ..color = const Color(0xFFFFB300).withValues(alpha: glow * prog * 0.3)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    }

    // Dust-cloud tint
    if (game.inDustCloud) {
      canvas.drawCircle(Offset(cx, cy), 42,
          Paint()..color = const Color(0xFFBCAAA4).withValues(alpha: 0.22)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20));
    }

    // Wind deflection arrow
    final wf = game.activeWindForce;
    if (wf.length > 10) {
      final ang      = math.atan2(wf.y, wf.x);
      final arrowLen = math.min(wf.length * 0.38, 30.0);
      final ex = cx + math.cos(ang) * arrowLen;
      final ey = cy + math.sin(ang) * arrowLen;
      canvas.drawLine(Offset(cx, cy), Offset(ex, ey),
          Paint()..color = const Color(0xFF80CBC4).withValues(alpha: 0.70)
            ..strokeWidth = 2.0..strokeCap = StrokeCap.round);
    }

    canvas.save();
    canvas.translate(cx, cy);

    // Shadow
    canvas.drawOval(Rect.fromCenter(center: const Offset(0, 15), width: 40, height: 10),
        Paint()..color = Colors.black.withValues(alpha: 0.30));

    // Arms
    final armP = Paint()..color = const Color(0xFF3A2810)..strokeWidth = 3.2..strokeCap = StrokeCap.round;
    for (final (dx, dy) in [(-1, -1), (1, -1), (-1, 1), (1, 1)]) {
      canvas.drawLine(Offset(dx * 8.0, dy * 8.0), Offset(dx * 23.0, dy * 23.0), armP);
    }

    // Propellers
    const propPositions = [(-23.0, -23.0), (23.0, -23.0), (-23.0, 23.0), (23.0, 23.0)];
    for (final (px, py) in propPositions) {
      canvas.save();
      canvas.translate(px, py);
      canvas.rotate(_t * 13);
      final propPaint = Paint()
        ..color = const Color(0xFFFFB300).withValues(alpha: 0.58)
        ..strokeWidth = 1.9..strokeCap = StrokeCap.round;
      canvas.drawLine(const Offset(-9, 0), const Offset(9, 0), propPaint);
      canvas.drawLine(const Offset(0, -9), const Offset(0, 9), propPaint);
      canvas.restore();
    }

    // Body
    canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(-14, -10, 28, 20), const Radius.circular(6)),
        Paint()..color = const Color(0xFF2A1C0A));

    // Sensor glow
    final glowColor  = game.gamePhase == 1 ? const Color(0xFFFFB300) : const Color(0xFF69F0AE);
    final glowBright = game.gamePhase == 1 && game.activeScanPatch != null
        ? 0.95 : 0.75 + math.sin(_t * 4) * 0.20;
    canvas.drawCircle(Offset.zero, 7.5,
        Paint()
          ..color = glowColor.withValues(alpha: glowBright)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7));
    canvas.drawCircle(Offset.zero, 3.8, Paint()..color = Colors.white.withValues(alpha: 0.95));

    // Phase icon
    final tp = TextPainter(
      text: TextSpan(text: game.gamePhase == 1 ? '🛰️' : '🪨', style: const TextStyle(fontSize: 8)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(-tp.width / 2, 13 - tp.height / 2));

    canvas.restore(); // restore the canvas.translate(cx,cy) save
  } // end _renderWorld
}

// ══════════════════════════════════════════════════════════════════════════════
//  DEGRADED PATCH COMPONENT  — richly drawn terrain issues with event states
// ══════════════════════════════════════════════════════════════════════════════
class DegradedPatch extends Component {
  final LandDegradationGame game;
  final DegradationType type;
  double hx, hy;
  final int  seed;
  final bool isChildPatch;   // spawned by gully expansion
  int        scanVariant = 0;

  bool            isScanned    = false;
  RestorationStep step         = RestorationStep.none;
  bool            isAtRisk     = false;
  double          riskTimer    = 0;
  bool            isCritical   = false;    // critical alert active
  bool            windStripped = false;    // just got wind-stripped
  bool            triggerSparkle = false; // one-shot sparkle on restore
  double          sparkleTimer = 0;
  double          _t           = 0;

  bool get isRestored   => step == RestorationStep.restored;
  bool get isStabilized => step == RestorationStep.stabilized;

  DegradedPatch({
    required this.game, required this.type,
    required double worldX, required double worldY,
    required this.seed, this.isChildPatch = false,
  }) : hx = worldX, hy = worldY;

  Vector2 get patchPos => Vector2(hx, hy);

  static const _specs = {
    DegradationType.steepSlope: ('⛰️', 'Steep\nSlope',   Color(0xFFEF5350), 'HIGH'),
    DegradationType.gully:      ('🕳️', 'Erosion\nGully', Color(0xFFFF6D00), 'SEVERE'),
    DegradationType.bareLand:   ('🌾', 'Bare\nLand',     Color(0xFFFFB300), 'MED'),
    DegradationType.drySoil:    ('🪨', 'Dry\nSoil',      Color(0xFFBCAAA4), 'LOW'),
  };

  @override
  void update(double dt) {
    _t += dt;
    if (windStripped) { windStripped = (dt * 3.0 + 1) < 4.0; } // auto-clear after 4s
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

    if (step == RestorationStep.restored) {
      _drawRestored(canvas); return;
    }

    _drawTerrainArt(canvas, color, pulse);

    // Sparkle burst on recent restoration attempt (wrong tool visual feedback)
    if (sparkleTimer > 0) _drawSparkle(canvas, const Color(0xFF69F0AE), sparkleTimer / 2.0);

    // Scan progress ring (phase 1, active hover)
    if (game.gamePhase == 1 && game.activeScanPatch == this) {
      _drawScanProgress(canvas, game.scanHoldProgress);
    }

    // Critical alert pulsing ring
    if (isCritical) {
      final urgency = math.sin(_t * 8).abs();
      final alert = game.criticalAlerts.firstWhere((a) => a.patch == this,
          orElse: () => CriticalAlert(patch: this, timeLeft: 0));
      canvas.drawCircle(Offset(hx, hy), 46 + urgency * 10,
          Paint()
            ..color = Colors.red.withValues(alpha: 0.22 + urgency * 0.15)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
      canvas.drawCircle(Offset(hx, hy), 34,
          Paint()
            ..color = Colors.red.withValues(alpha: 0.75)
            ..style = PaintingStyle.stroke..strokeWidth = 2.8);
      // Timer label
      final tp = TextPainter(
        text: TextSpan(text: '⚡ ${alert.timeLeft.ceil()}s',
            style: const TextStyle(color: Colors.red, fontSize: 10,
                fontWeight: FontWeight.w900)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(hx - tp.width / 2, hy - 68));
    }

    // Wind-stripped warning flash
    if (windStripped) {
      canvas.drawCircle(Offset(hx, hy), 38,
          Paint()..color = const Color(0xFF80CBC4).withValues(alpha: 0.22)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12));
    }

    // At-risk rain animation
    if (isAtRisk) {
      final urgency = math.sin(_t * 6).abs();
      canvas.drawCircle(Offset(hx, hy), 44 + urgency * 8,
          Paint()..color = const Color(0xFFFF9800).withValues(alpha: 0.18 + urgency * 0.12)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
    }

    // Time bonus indicator (subtle golden shimmer, visible only after scanning)
    if (isScanned) {
      final idx = game.patches.indexOf(this);
      if (idx == game.timeBonusPatchIndex && !game.timeBonusCollected) {
        canvas.drawCircle(Offset(hx + 22, hy - 22), 9,
            Paint()
              ..color = const Color(0xFFFFD700).withValues(alpha: 0.80)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
        final tp = TextPainter(
          text: const TextSpan(text: '⏱', style: TextStyle(fontSize: 10)),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(hx + 22 - tp.width / 2, hy - 22 - tp.height / 2));
      }

      // Eco-discovery hidden indicator (subtle sparkle before scan)
      if (game.ecoDiscoveryIndices.contains(idx) &&
          !game.discoveredEcoPatches.contains(idx)) {
        final shimmer = 0.3 + math.sin(_t * 3.5) * 0.25;
        canvas.drawCircle(Offset(hx - 22, hy - 22), 6,
            Paint()
              ..color = const Color(0xFFE040FB).withValues(alpha: shimmer)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
      }
    }

    if (isScanned) {
      // Outer glow
      canvas.drawCircle(Offset(hx, hy), 36 * pulse,
          Paint()..color = color.withValues(alpha: 0.09 + pulse * 0.05)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12));

      // Step ring
      final ringColor = step == RestorationStep.stabilized
          ? const Color(0xFF29B6F6) : color;
      canvas.drawCircle(Offset(hx, hy), 32,
          Paint()..color = ringColor.withValues(alpha: 0.12));
      canvas.drawCircle(Offset(hx, hy), 32,
          Paint()..color = ringColor.withValues(alpha: 0.72)
            ..style = PaintingStyle.stroke..strokeWidth = 2.2);

      // Step badge
      final badge = step == RestorationStep.stabilized ? 'STEP 2 ▶' : 'STEP 1 ▶';
      final badgeP = TextPainter(
        text: TextSpan(text: badge,
            style: TextStyle(color: ringColor, fontSize: 7.5,
                fontWeight: FontWeight.bold, letterSpacing: 0.6)),
        textDirection: TextDirection.ltr,
      )..layout();
      badgeP.paint(canvas, Offset(hx - badgeP.width / 2, hy + 20));

      // Type label above
      final labelP = TextPainter(
        text: TextSpan(text: spec.$2,
            style: TextStyle(color: color, fontSize: 8,
                fontWeight: FontWeight.w700, height: 1.2)),
        textDirection: TextDirection.ltr, textAlign: TextAlign.center,
      )..layout(maxWidth: 72);
      labelP.paint(canvas, Offset(hx - labelP.width / 2, hy - 52));

      // Child gully indicator
      if (isChildPatch) {
        final tp = TextPainter(
          text: const TextSpan(text: '⚠️ Expanded',
              style: TextStyle(color: Color(0xFFFF6D00), fontSize: 8,
                  fontWeight: FontWeight.bold)),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(hx - tp.width / 2, hy - 62));
      }

      // Risk countdown
      if (isAtRisk) {
        final tp = TextPainter(
          text: TextSpan(text: '⛈️ ${riskTimer.ceil()}s',
              style: const TextStyle(color: Color(0xFFFF9800), fontSize: 9,
                  fontWeight: FontWeight.bold)),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(hx - tp.width / 2, hy - 62));
      }
    } else {
      // Unknown — question mark with animated scan lines
      canvas.drawCircle(Offset(hx, hy), 30 * pulse,
          Paint()..color = const Color(0xFFBCAAA4).withValues(alpha: 0.07)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9));
      canvas.drawCircle(Offset(hx, hy), 24,
          Paint()..color = const Color(0xFFBCAAA4).withValues(alpha: 0.10));
      canvas.drawCircle(Offset(hx, hy), 24,
          Paint()..color = const Color(0xFFBCAAA4).withValues(alpha: 0.58)
            ..style = PaintingStyle.stroke..strokeWidth = 1.8);
      final scanAlpha = 0.14 + math.sin(_t * 3.8) * 0.10;
      for (int i = -2; i <= 2; i++) {
        canvas.drawLine(Offset(hx - 18, hy + i * 5.0), Offset(hx + 18, hy + i * 5.0),
            Paint()..color = const Color(0xFFBCAAA4).withValues(alpha: scanAlpha)
              ..strokeWidth = 0.8);
      }
      final qp = TextPainter(
        text: const TextSpan(text: '?',
            style: TextStyle(color: Color(0xFFBCAAA4), fontSize: 17, fontWeight: FontWeight.bold)),
        textDirection: TextDirection.ltr,
      )..layout();
      qp.paint(canvas, Offset(hx - qp.width / 2, hy - qp.height / 2));
    }
  } // end _renderWorld

  // ── Per-type terrain art ───────────────────────────────────────────────────
  void _drawTerrainArt(Canvas canvas, Color color, double pulse) {
    final rng = math.Random(seed);
    switch (type) {
      case DegradationType.steepSlope: _drawSteepSlopeArt(canvas, rng, color, pulse);
      case DegradationType.gully:      _drawGullyArt(canvas, rng, color, pulse);
      case DegradationType.bareLand:   _drawBareLandArt(canvas, rng, color, pulse);
      case DegradationType.drySoil:    _drawDrySoilArt(canvas, rng, color, pulse);
    }
  }

  void _drawSteepSlopeArt(Canvas canvas, math.Random rng, Color color, double pulse) {
    canvas.drawPath(
      Path()..moveTo(hx - 28, hy + 18)..lineTo(hx + 28, hy + 18)..lineTo(hx, hy - 20)..close(),
      Paint()..color = const Color(0xFF3A1408).withValues(alpha: 0.62),
    );
    for (int s = 0; s < 5; s++) {
      final sx = hx - 24 + s * 13.0;
      canvas.drawLine(Offset(sx, hy - 12), Offset(sx - 6, hy + 16),
          Paint()..color = const Color(0xFF5A2010).withValues(alpha: 0.52)
            ..strokeWidth = 2.2 + rng.nextDouble());
    }
    canvas.drawLine(Offset(hx - 28, hy + 18), Offset(hx, hy - 20),
        Paint()..color = color.withValues(alpha: 0.38)..strokeWidth = 2.0..strokeCap = StrokeCap.round);
    canvas.drawLine(Offset(hx + 28, hy + 18), Offset(hx, hy - 20),
        Paint()..color = const Color(0xFF2A0E04).withValues(alpha: 0.58)..strokeWidth = 2.0..strokeCap = StrokeCap.round);
    for (int r = 0; r < 5; r++) {
      canvas.drawCircle(
        Offset(hx + rng.nextDouble() * 32 - 16, hy + 4 + rng.nextDouble() * 12),
        1.5 + rng.nextDouble() * 2.8,
        Paint()..color = const Color(0xFF4A2010).withValues(alpha: 0.72),
      );
    }
  }

  void _drawGullyArt(Canvas canvas, math.Random rng, Color color, double pulse) {
    canvas.drawPath(
      Path()..moveTo(hx - 30, hy - 14)..lineTo(hx - 8, hy + 18)
           ..lineTo(hx + 8, hy + 18)..lineTo(hx + 30, hy - 14),
      Paint()..color = const Color(0xFF050302).withValues(alpha: 0.82),
    );
    canvas.drawLine(Offset(hx - 30, hy - 14), Offset(hx - 8, hy + 18),
        Paint()..color = const Color(0xFF6B3010).withValues(alpha: 0.58)..strokeWidth = 3.2);
    canvas.drawLine(Offset(hx + 30, hy - 14), Offset(hx + 8, hy + 18),
        Paint()..color = const Color(0xFF2A1408).withValues(alpha: 0.58)..strokeWidth = 2.8);
    canvas.drawOval(Rect.fromCenter(center: Offset(hx, hy + 18), width: 22, height: 7),
        Paint()..color = const Color(0xFF5A3020).withValues(alpha: 0.62));
    for (int b = 0; b < 4; b++) {
      final bx = hx - 24 + b * 17.0;
      canvas.drawLine(Offset(bx, hy - 14), Offset(bx + rng.nextDouble() * 16 - 8, hy - 30),
          Paint()..color = const Color(0xFF050302).withValues(alpha: 0.42)
            ..strokeWidth = 2.8..strokeCap = StrokeCap.round);
    }
    for (int s = 0; s < 4; s++) {
      final sx = hx - 14 + s * 10.0;
      canvas.drawLine(Offset(sx, hy - 10), Offset(sx + rng.nextDouble() * 4 - 2, hy + 14),
          Paint()..color = const Color(0xFF1A0A04).withValues(alpha: 0.38)..strokeWidth = 1.5);
    }
  }

  void _drawBareLandArt(Canvas canvas, math.Random rng, Color color, double pulse) {
    canvas.drawOval(Rect.fromCenter(center: Offset(hx, hy + 4), width: 62, height: 30),
        Paint()..color = const Color(0xFF2A1508).withValues(alpha: 0.58));
    for (int s = 0; s < 7; s++) {
      canvas.drawLine(Offset(hx - 24, hy - 9 + s * 5.5),
          Offset(hx + 24 + rng.nextDouble() * 9, hy - 9 + s * 5.5 + rng.nextDouble() * 3),
          Paint()..color = const Color(0xFF4A2810).withValues(alpha: 0.34)..strokeWidth = 0.9);
    }
    for (int i = 0; i < 7; i++) {
      final rx = hx + rng.nextDouble() * 46 - 23;
      final ry = hy + rng.nextDouble() * 20 - 4;
      canvas.drawLine(Offset(rx, ry + 8), Offset(rx + rng.nextDouble() * 6 - 3, ry),
          Paint()..color = const Color(0xFF3A2010).withValues(alpha: 0.58)
            ..strokeWidth = 1.5..strokeCap = StrokeCap.round);
    }
    for (int i = 0; i < 6; i++) {
      canvas.drawCircle(Offset(hx + rng.nextDouble() * 42 - 21, hy + rng.nextDouble() * 18 - 3),
          2.0 + rng.nextDouble() * 3.2,
          Paint()..color = const Color(0xFF3A2418).withValues(alpha: 0.62));
    }
  }

  void _drawDrySoilArt(Canvas canvas, math.Random rng, Color color, double pulse) {
    final poly = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (i / 6) * math.pi * 2 - math.pi / 2;
      final r = 22.0 + rng.nextDouble() * 9.0;
      final px = hx + math.cos(angle) * r;
      final py = hy + math.sin(angle) * r * 0.75;
      i == 0 ? poly.moveTo(px, py) : poly.lineTo(px, py);
    }
    poly.close();
    canvas.drawPath(poly, Paint()..color = const Color(0xFF2A1A0A).withValues(alpha: 0.58));
    for (int c = 0; c < 8; c++) {
      final angle = (c / 8) * math.pi * 2 + rng.nextDouble() * 0.3;
      final len   = 12.0 + rng.nextDouble() * 15.0;
      canvas.drawLine(Offset(hx, hy),
          Offset(hx + math.cos(angle) * len, hy + math.sin(angle) * len * 0.8),
          Paint()..color = const Color(0xFF4A2810).withValues(alpha: 0.68)
            ..strokeWidth = 1.4..strokeCap = StrokeCap.round);
    }
    for (int c = 0; c < 5; c++) {
      final angle = rng.nextDouble() * math.pi * 2;
      canvas.drawLine(
        Offset(hx + math.cos(angle) * 12, hy + math.sin(angle) * 9),
        Offset(hx + math.cos(angle + 0.5) * 22, hy + math.sin(angle + 0.5) * 16.5),
        Paint()..color = const Color(0xFF3A2010).withValues(alpha: 0.52)..strokeWidth = 1.1,
      );
    }
    canvas.drawCircle(Offset(hx, hy), 26,
        Paint()..color = const Color(0xFFBCAAA4).withValues(alpha: 0.10)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
  }

  void _drawScanProgress(Canvas canvas, double progress) {
    const startAngle = -math.pi / 2;
    const full       = math.pi * 2;

    // Sweeping radar beam effect
    final beamAngle = startAngle + full * progress;
    // Beam trail
    canvas.drawArc(
      Rect.fromCenter(center: Offset(hx, hy), width: 84, height: 84),
      beamAngle - 0.5, 0.5, false,
      Paint()..color = const Color(0xFFFFB300).withValues(alpha: 0.18)
        ..style = PaintingStyle.stroke..strokeWidth = 10.0,
    );
    // Leading edge
    canvas.drawLine(Offset(hx, hy),
        Offset(hx + math.cos(beamAngle) * 42, hy + math.sin(beamAngle) * 42),
        Paint()..color = const Color(0xFFFFB300).withValues(alpha: 0.32)..strokeWidth = 2.0);

    // Background ring
    canvas.drawCircle(Offset(hx, hy), 42,
        Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: 0.08)
          ..style = PaintingStyle.stroke..strokeWidth = 4.2);

    // Progress arc
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCenter(center: Offset(hx, hy), width: 84, height: 84),
        startAngle, full * progress, false,
        Paint()
          ..color = const Color(0xFFFFB300).withValues(alpha: 0.88)
          ..style = PaintingStyle.stroke..strokeWidth = 4.2
          ..strokeCap = StrokeCap.round,
      );
    }

    // Scan % label
    final pct = (progress * 100).toInt();
    final tp  = TextPainter(
      text: TextSpan(text: '$pct%',
          style: const TextStyle(color: Color(0xFFFFB300), fontSize: 9,
              fontWeight: FontWeight.bold)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(hx - tp.width / 2, hy - 62));

    // Status label
    final al = TextPainter(
      text: TextSpan(
          text: game.inDustCloud ? '🌫️ Slowed' : '📡 Scanning…',
          style: TextStyle(
              color: game.inDustCloud ? const Color(0xFFBCAAA4) : const Color(0xFFFFB300),
              fontSize: 8.5, fontWeight: FontWeight.w700)),
      textDirection: TextDirection.ltr,
    )..layout();
    al.paint(canvas, Offset(hx - al.width / 2, hy + 48));
  }

  void _drawSparkle(Canvas canvas, Color color, double progress) {
    final rng = math.Random(seed + 999);
    for (int i = 0; i < 12; i++) {
      final angle = (i / 12) * math.pi * 2;
      final r     = progress * 55.0;
      final alpha = progress * 0.85;
      canvas.drawCircle(
        Offset(hx + math.cos(angle) * r, hy + math.sin(angle) * r),
        2.5 + rng.nextDouble() * 3.0,
        Paint()..color = color.withValues(alpha: alpha.clamp(0, 1)),
      );
    }
  }

  void _drawRestored(Canvas canvas) {
    if (sparkleTimer > 0) _drawSparkle(canvas, const Color(0xFF69F0AE), sparkleTimer / 2.0);

    canvas.drawCircle(Offset(hx, hy), 32,
        Paint()..color = const Color(0xFF69F0AE).withValues(alpha: 0.16));
    canvas.drawCircle(Offset(hx, hy), 32,
        Paint()..color = const Color(0xFF69F0AE).withValues(alpha: 0.65)
          ..style = PaintingStyle.stroke..strokeWidth = 2.2);

    // Vegetation ring
    for (int i = 0; i < 7; i++) {
      final angle = (i / 7) * math.pi * 2;
      final rx = hx + math.cos(angle) * 14;
      final ry = hy + math.sin(angle) * 14;
      canvas.drawLine(Offset(rx, ry + 6), Offset(rx, ry - 4),
          Paint()..color = const Color(0xFF4CAF50).withValues(alpha: 0.70)
            ..strokeWidth = 2.0..strokeCap = StrokeCap.round);
    }

    final tp = TextPainter(
      text: const TextSpan(text: '🌿', style: TextStyle(fontSize: 15)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(hx - tp.width / 2, hy - tp.height / 2));
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  DUST CLOUD COMPONENT
// ══════════════════════════════════════════════════════════════════════════════
class DustCloudComponent extends Component {
  final LandDegradationGame game;
  Vector2 cloudPos;
  final double radius, speed;
  double _dx, _dy, _t = 0;

  DustCloudComponent({
    required this.game, required double startX, required double startY,
    required this.radius, required this.speed, required int seed,
  })  : cloudPos = Vector2(startX, startY),
        _dx      = math.cos(seed.toDouble()) * 1.0,
        _dy      = math.sin(seed.toDouble()) * 1.0;

  @override
  void update(double dt) {
    _t += dt;
    cloudPos.x += _dx * speed * dt;
    cloudPos.y += _dy * speed * dt;
    if (cloudPos.x < radius)                         { cloudPos.x = radius;              _dx = _dx.abs(); }
    if (cloudPos.x > game.worldW - radius)           { cloudPos.x = game.worldW - radius; _dx = -_dx.abs(); }
    if (cloudPos.y < radius)                         { cloudPos.y = radius;              _dy = _dy.abs(); }
    if (cloudPos.y > game.worldH * 0.85 - radius)   { cloudPos.y = game.worldH * 0.85 - radius; _dy = -_dy.abs(); }
    final angle = math.atan2(_dy, _dx) + math.sin(_t * 0.4) * 0.016;
    _dx = math.cos(angle); _dy = math.sin(angle);
  }

  @override
  void render(Canvas canvas) {
    canvas.save();
    canvas.translate(-game.camX, -game.camY);
    final inside = (cloudPos - game.dronePos).length < radius + 20;
    final alpha  = inside ? 0.40 : 0.23;
    for (final (r, a) in [
      (radius * 1.4, 0.08), (radius, 0.15), (radius * 0.65, 0.09)
    ]) {
      canvas.drawCircle(Offset(cloudPos.x, cloudPos.y), r,
          Paint()..color = const Color(0xFFBCAAA4).withValues(alpha: a + alpha * 0.3)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24));
    }
    if (inside && game.gamePhase == 1) {
      final tp = TextPainter(
        text: const TextSpan(text: '🌫️  Scan slowed',
            style: TextStyle(color: Color(0xFFBCAAA4), fontSize: 9.5, fontWeight: FontWeight.w700)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(cloudPos.x - tp.width / 2, cloudPos.y - 24));
    }
    canvas.restore();
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  WIND ZONE RENDERER
// ══════════════════════════════════════════════════════════════════════════════
class WindZoneRenderer extends Component {
  final WindZone            zone;
  final LandDegradationGame game;
  double _t = 0;
  WindZoneRenderer({required this.zone, required this.game});

  @override
  void update(double dt) => _t += dt;

  @override
  void render(Canvas canvas) {
    if (game.gamePhase != 1) return;
    canvas.save();
    canvas.translate(-game.camX, -game.camY);
    final cx = zone.center.x, cy = zone.center.y, r = zone.radius;
    final angle  = math.atan2(zone.force.y, zone.force.x);
    final inZone = (zone.center - game.dronePos).length < r;
    final alpha  = inZone ? 0.30 : 0.15;

    canvas.drawCircle(Offset(cx, cy), r,
        Paint()..color = const Color(0xFF80CBC4).withValues(alpha: alpha)
          ..style = PaintingStyle.stroke..strokeWidth = 1.5);

    for (int i = 0; i < 5; i++) {
      final a  = angle + (i / 5) * math.pi * 2 + _t * 1.3;
      final ox = cx + math.cos(a) * r * 0.52;
      final oy = cy + math.sin(a) * r * 0.52;
      final ex = ox + math.cos(angle) * 20;
      final ey = oy + math.sin(angle) * 20;
      canvas.drawLine(Offset(ox, oy), Offset(ex, ey),
          Paint()..color = const Color(0xFF80CBC4).withValues(alpha: alpha + 0.09)
            ..strokeWidth = 2.0..strokeCap = StrokeCap.round);
      for (final ha in [math.pi * 0.75, -math.pi * 0.75]) {
        canvas.drawLine(Offset(ex, ey),
            Offset(ex + math.cos(angle + ha) * 7, ey + math.sin(angle + ha) * 7),
            Paint()..color = const Color(0xFF80CBC4).withValues(alpha: alpha)
              ..strokeWidth = 1.5..strokeCap = StrokeCap.round);
      }
    }

    if (inZone) {
      final label = zone.force.length > 75 ? '💨 Strong Wind  →  Strips bare land!'
                                           : '💨 Wind';
      final tp = TextPainter(
        text: TextSpan(text: label,
            style: const TextStyle(color: Color(0xFF80CBC4), fontSize: 9.5, fontWeight: FontWeight.bold)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(cx - tp.width / 2, cy - r - 18));
    }
    canvas.restore();
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
            : game.erosionIndex < 50 ? const Color(0xFFFFB300) : const Color(0xFFEF5350);
        final totalPatches = game.patches.length;

        return SafeArea(child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch, children: [

            // Phase tag
            Align(alignment: Alignment.topCenter, child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
              decoration: BoxDecoration(
                color: game.gamePhase == 1
                    ? const Color(0xFFFFB300).withValues(alpha: 0.90)
                    : const Color(0xFF69F0AE).withValues(alpha: 0.90),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(
                    color: (game.gamePhase == 1
                        ? const Color(0xFFFFB300) : const Color(0xFF69F0AE))
                        .withValues(alpha: 0.38), blurRadius: 12)],
              ),
              child: Text(
                game.gamePhase == 1
                    ? '🛰️  PHASE 1 — TERRAIN SURVEY'
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
                  '${game.scannedCount}/$totalPatches',
                  'SCANNED',
                  const Color(0xFFFFB300)),
              const SizedBox(width: 5),
              _LHTile(Icons.restore_rounded,
                  '${game.restoredCount}/${LandDegradationGame.kMinPatchesRequired}',
                  'RESTORED',
                  game.restoredCount >= LandDegradationGame.kMinPatchesRequired
                      ? const Color(0xFF69F0AE)
                      : Colors.white70),
              const SizedBox(width: 5),
              _LHTile(Icons.terrain_rounded, '${game.erosionIndex.toStringAsFixed(0)}%',
                  'EROSION', erosionColor),
            ]),
            const SizedBox(height: 5),

            // Phase 1: scan progress bar (user-triggered lock scan)
            if (game.gamePhase == 1 && game.scanLockActive) ...[
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
                Text(game.inDustCloud ? '🌫️ Slowed' : 'Locking…',
                    style: TextStyle(
                        color: game.inDustCloud ? const Color(0xFFBCAAA4) : const Color(0xFFFFB300),
                        fontSize: 9, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 4),
            ],

            // Phase 1: nudge when a patch is nearby but not scanning
            if (game.gamePhase == 1 && !game.scanLockActive &&
                game._nearestScanTarget != null && !game.toolSelectorOpen && !game.scanResultActive) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFB300).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFFB300).withValues(alpha: 0.35)),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('📡', style: TextStyle(fontSize: 10)),
                  SizedBox(width: 5),
                  Text('Degraded zone nearby — tap SCAN!',
                      style: TextStyle(color: Color(0xFFFFB300),
                          fontSize: 9, fontWeight: FontWeight.w700)),
                ]),
              ),
            ],

            // Phase 1: scan streak indicator
            if (game.gamePhase == 1 && game.scanStreak >= 2)
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

            // Phase 2: erosion bar + combo
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
                      style: TextStyle(color: erosionColor, fontSize: 10, fontWeight: FontWeight.bold)),
                  const TextSpan(text: ' / 20%',
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
                      '${game.criticalAlerts.length} CRITICAL ZONE${game.criticalAlerts.length > 1 ? "S" : ""}!  Treat before they collapse!',
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
      Text(val, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
      Text(label, style: const TextStyle(color: Colors.white54, fontSize: 7, letterSpacing: 0.7)),
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

    if (k == LogicalKeyboardKey.keyW || k == LogicalKeyboardKey.arrowUp)    { if (pressed) up(true); if (released) up(false); }
    if (k == LogicalKeyboardKey.keyS || k == LogicalKeyboardKey.arrowDown)  { if (pressed) dn(true); if (released) dn(false); }
    if (k == LogicalKeyboardKey.keyA || k == LogicalKeyboardKey.arrowLeft)  { if (pressed) lt(true); if (released) lt(false); }
    if (k == LogicalKeyboardKey.keyD || k == LogicalKeyboardKey.arrowRight) { if (pressed) rt(true); if (released) rt(false); }
    if (k == LogicalKeyboardKey.space && pressed) {
      if (widget.game.gamePhase == 1) {
        widget.game.triggerScan();
      } else {
        widget.game.applyTool();   // SPACE applies the currently selected tool directly
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
        final actColor = phase == 1 ? const Color(0xFFFFB300) : const Color(0xFF69F0AE);

        // toolDialogRequested is no longer used for touch — panel handles selection.
        // Retained only as a no-op to avoid breaking any residual desktop path.
        if (widget.game.toolDialogRequested) {
          widget.game.clearToolDialogRequest();
        }

        return KeyboardListener(
          focusNode: _fk,
          onKeyEvent: _onKey,
          child: Stack(children: [

            // D-pad
            Align(alignment: Alignment.bottomLeft, child: SafeArea(child: Padding(
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
            ))),

            // ── Phase 2: right-side tool panel (always visible, replaces dialog) ──
            if (phase == 2)
              Align(
                alignment: Alignment.centerRight,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _ToolSidePanel(game: widget.game),
                  ),
                ),
              ),

            // ── Action button (bottom-right) ─────────────────────────────────
            Align(alignment: Alignment.bottomRight, child: SafeArea(child: Padding(
              padding: const EdgeInsets.only(bottom: 20, right: 14),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                if (phase == 1 && widget.game.activeScanPatch != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.70),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFFB300).withValues(alpha: 0.42)),
                    ),
                    child: Text(
                      widget.game.inDustCloud ? '🌫️ Dust slowing scan!' : '🔒 Scanning — stay in range!',
                      style: const TextStyle(color: Color(0xFFFFB300), fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ),
                if (phase == 1 && widget.game.toolSelectorOpen)
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF69F0AE).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF69F0AE).withValues(alpha: 0.42)),
                    ),
                    child: const Text(
                      '🔧 Select restoration tool!',
                      style: TextStyle(color: Color(0xFF69F0AE), fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ),
                GestureDetector(
                  onTap: () {
                    if (phase == 1) {
                      widget.game.triggerScan();
                    } else {
                      // Apply the currently selected tool directly — no dialog
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
                      phase == 1
                          ? (widget.game.scanLockActive ? '🔒\nLOCK\nING…' : '📡\nSCAN')
                          : '✅\nAPPLY',
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

// ══════════════════════════════════════════════════════════════════════════════
//  RIGHT-SIDE TOOL PANEL  —  Phase 2 persistent tool selector
// ══════════════════════════════════════════════════════════════════════════════
class _ToolSidePanel extends StatelessWidget {
  final LandDegradationGame game;
  const _ToolSidePanel({required this.game});

  static const _tools = [
    (RestorationTool.terrace,   '🏗️', 'Terrace',    'Steep Slope (Step 1)',     Color(0xFFEF5350)),
    (RestorationTool.checkDam,  '🧱', 'Check Dam',  'Erosion Gully (Step 1)',   Color(0xFFFF6D00)),
    (RestorationTool.coverCrop, '🌱', 'Cover Crop', 'Bare Land①  Slope②',      Color(0xFF69F0AE)),
    (RestorationTool.biochar,   '⬛', 'Biochar',    'Dry Soil①  Gully②',       Color(0xFFBCAAA4)),
    (RestorationTool.compost,   '🌿', 'Compost',    'Bare Land②  Dry Soil②',   Color(0xFF8BC34A)),
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: game,
      builder: (_, __) {
        final target  = game._nearestActionable;
        final step    = target?.step ?? RestorationStep.none;

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: _tools.map((spec) {
            final (tool, emoji, label, hint, color) = spec;
            final uses     = game.toolUses[tool] ?? 0;
            final isEmpty  = uses == 0;
            final selected = game.selectedTool == tool;
            final correct  = target != null && game._isCorrectTool(target.type, tool, step);

            // Border / bg logic: selected > correct > normal > empty
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
                margin: const EdgeInsets.only(bottom: 5),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                constraints: const BoxConstraints(minWidth: 120, maxWidth: 140),
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
                    // ── Emoji icon ────────────────────────────────────────────
                    Container(
                      width: 30, height: 30,
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
                        child: Text(emoji, style: const TextStyle(fontSize: 14)),
                      ),
                    ),
                    const SizedBox(width: 7),

                    // ── Label + hint ──────────────────────────────────────────
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
                              fontSize: 10.5,
                            ),
                          ),
                          Text(
                            hint,
                            style: TextStyle(
                              color: isEmpty
                                  ? Colors.white12
                                  : color.withValues(alpha: 0.68),
                              fontSize: 8,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 5),

                    // ── Uses badge / correct tick ────────────────────────────
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
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
                            isEmpty ? 'OUT' : '×$uses',
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

class _LDPad extends StatelessWidget {
  final String label;
  final bool   isActive;
  final Color  color;
  final VoidCallback onDown, onUp;
  const _LDPad(this.label, this.isActive, this.color, {required this.onDown, required this.onUp});

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
//  LAND TOOL SELECTOR OVERLAY
// ══════════════════════════════════════════════════════════════════════════════
class LandToolSelector extends StatelessWidget {
  final LandDegradationGame game;
  const LandToolSelector(this.game, {super.key});

  static const _tools = [
    (RestorationTool.terrace,   '🏗️', 'Terrace',    'Steep Slope — Step ① Structural',  Color(0xFFEF5350)),
    (RestorationTool.checkDam,  '🧱', 'Check Dam',  'Erosion Gully — Step ① Structural', Color(0xFFFF6D00)),
    (RestorationTool.coverCrop, '🌱', 'Cover Crop', 'Bare Land ①  •  Steep Slope ②',    Color(0xFF69F0AE)),
    (RestorationTool.biochar,   '⬛', 'Biochar',    'Dry Soil ①  •  Erosion Gully ②',   Color(0xFFBCAAA4)),
    (RestorationTool.compost,   '🌿', 'Compost',    'Bare Land ②  •  Dry Soil ②',       Color(0xFF8BC34A)),
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: game,
      builder: (_, __) {
        final target = game.pendingFixTarget;
        if (target == null) return const SizedBox.shrink();

        final step      = target.step;
        final typeName  = _patchTypeName(target.type);
        final isStep2   = step == RestorationStep.stabilized;
        final stepLabel = isStep2 ? '② Biological step — finish the restoration' : '① Structural step — stabilise the patch';
        final accent    = isStep2 ? const Color(0xFF69F0AE) : const Color(0xFFFF6D00);
        // Show correct-tool highlight & labels only when the game is "teaching" this step
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
                  // ── Header ────────────────────────────────────────────────
                  Row(children: [
                    Text(_patchTypeIcon(target.type), style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(typeName,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(stepLabel,
                          style: TextStyle(color: accent, fontSize: 10.5, fontWeight: FontWeight.w700)),
                    ])),
                    // Cancel: always shown but styled differently for step 2
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

                  // ── Step-2 mandatory reminder ──────────────────────────────
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
                        Text('🌿', style: TextStyle(fontSize: 12)),
                        const SizedBox(width: 6),
                        Text('Step ① applied — complete Step ② to fully restore this patch',
                            style: TextStyle(color: accent, fontSize: 9, fontWeight: FontWeight.w800)),
                      ]),
                    ),
                  ],

                  const SizedBox(height: 4),

                  // ── Issue reminder / "trust memory" banner ─────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: accent.withValues(alpha: 0.35)),
                    ),
                    child: showHints
                        ? Text(
                            'Issue: ${game.lastScanResult?.typeName ?? typeName}  •  ${game.lastScanResult?.severity ?? ""}',
                            style: TextStyle(color: accent, fontSize: 9.5, fontWeight: FontWeight.w700))
                        : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            const Text('🧠', style: TextStyle(fontSize: 11)),
                            const SizedBox(width: 5),
                            Text('Recall from memory — no hints this time!',
                                style: TextStyle(color: accent, fontSize: 9.5, fontWeight: FontWeight.w700)),
                          ]),
                  ),
                  const SizedBox(height: 10),
                  Text('Select the correct restoration tool:',
                      style: const TextStyle(color: Colors.white54, fontSize: 10.5)),
                  const SizedBox(height: 14),

                  // ── Tool grid ─────────────────────────────────────────────
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: _tools.map((spec) {
                      final (tool, emoji, label, hint, color) = spec;
                      final uses    = game.toolUses[tool] ?? 0;
                      final isEmpty = uses == 0;
                      // Only highlight correct tool when hints are active
                      final correct = showHints && game._isCorrectTool(target.type, tool, step);
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
                            // Issue label: shown when hints are active, hidden otherwise
                            if (showHints)
                              Text(hint,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: isEmpty ? Colors.white12 : color.withValues(alpha: 0.68),
                                    fontSize: 8,
                                  ))
                            else
                              Text('— apply from memory —',
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
                                isEmpty ? 'OUT' : '×$uses',
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

  String _patchTypeIcon(DegradationType t) {
    switch (t) {
      case DegradationType.steepSlope: return '⛰️';
      case DegradationType.gully:      return '🕳️';
      case DegradationType.bareLand:   return '🌾';
      case DegradationType.drySoil:    return '🪨';
    }
  }

  String _patchTypeName(DegradationType t) {
    switch (t) {
      case DegradationType.steepSlope: return 'Steep Erosion Slope';
      case DegradationType.gully:      return 'Erosion Gully';
      case DegradationType.bareLand:   return 'Bare Land';
      case DegradationType.drySoil:    return 'Dry Soil';
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  PHASE BANNER
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
            style: const TextStyle(color: Colors.white54, fontSize: 13, letterSpacing: 2.5)),
        const SizedBox(height: 4),
        Text(phase1 ? '🛰️  Terrain Survey' : '🪨  Terrain Restoration',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22)),
        const SizedBox(height: 6),
        Text(
          phase1
              ? 'Fly close to a degraded zone, then tap 📡 SCAN.\nA 1.5 s lock starts — stay in range to complete it.\nRead the identified issue, then tap FIX IT to restore!\nDust clouds slow scans · Wind zones push your drone.'
              : 'Apply the correct two-step treatment per patch.\nWatch for critical alerts, gully expansion & rain!',
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
class ScanResultOverlay extends StatefulWidget {
  final LandDegradationGame game;
  const ScanResultOverlay(this.game, {super.key});
  @override
  State<ScanResultOverlay> createState() => _ScanResultOverlayState();
}

class _ScanResultOverlayState extends State<ScanResultOverlay>
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
        // Use a longer display duration for progress arc
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

                // ── Header row ───────────────────────────────────────────────
                Row(children: [
                  SizedBox(
                    width: 22, height: 22,
                    child: CustomPaint(painter: _ArcCountdownPainter(progress, result.color)),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('TERRAIN SCAN COMPLETE',
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
                    child: Text('+$pts pts${pts >= 30 ? " 🌟" : ""}',
                        style: const TextStyle(color: Color(0xFFFFB300),
                            fontSize: 9, fontWeight: FontWeight.bold)),
                  ),
                ]),
                const SizedBox(height: 12),

                // ── IDENTIFIED ISSUE — most prominent section ────────────────
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

                // ── Treatment guide (first encounter) / Memory prompt (repeat) ──
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
                            'You\'ve treated this issue before.\nApply the two-step restoration from memory!',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white54, fontSize: 9.5, height: 1.4),
                          ),
                        ]),
                      ),
                const SizedBox(height: 14),

                // ── FIX IT button — player taps to open tool selector ────────
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
//  CRITICAL ALERT OVERLAY
// ══════════════════════════════════════════════════════════════════════════════
class CriticalAlertOverlay extends StatelessWidget {
  final LandDegradationGame game;
  const CriticalAlertOverlay(this.game, {super.key});

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
                const Text('CRITICAL ZONE — TREAT NOW!',
                    style: TextStyle(color: Colors.red, fontSize: 10,
                        fontWeight: FontWeight.w900, letterSpacing: 1.3)),
                const SizedBox(height: 2),
                const Text(
                  'A zone is on the verge of collapse.\nTreat it to save +15 pts — or lose -20!',
                  style: TextStyle(color: Colors.white60, fontSize: 9.5),
                ),
              ]),
              const SizedBox(width: 10),
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(shape: BoxShape.circle,
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
//  ECO-DISCOVERY OVERLAY  — cultural marker popup
// ══════════════════════════════════════════════════════════════════════════════
class EcoDiscoveryOverlay extends StatefulWidget {
  final LandDegradationGame game;
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
  final LandDegradationGame game;
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
            Text('Low-stock tool refilled with +3 uses.\nKeep restoring to earn more!',
                style: TextStyle(color: Colors.white60, fontSize: 10)),
          ]),
        ]),
      )),
    ));
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  TOOL SELECTION DIALOG
// ══════════════════════════════════════════════════════════════════════════════
class _ToolSelectionDialog extends StatefulWidget {
  final LandDegradationGame game;
  const _ToolSelectionDialog({required this.game});
  @override
  State<_ToolSelectionDialog> createState() => _ToolSelectionDialogState();
}

class _ToolSelectionDialogState extends State<_ToolSelectionDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _scale, _fade;
  RestorationTool? _applying;

  static const _tools = [
    (RestorationTool.terrace,   '🏗️', 'Terrace',    'Steep Slope — Step ① Structural',  Color(0xFFEF5350)),
    (RestorationTool.checkDam,  '🧱', 'Check Dam',  'Erosion Gully — Step ① Structural', Color(0xFFFF6D00)),
    (RestorationTool.coverCrop, '🌱', 'Cover Crop', 'Bare Land ①  •  Steep Slope ②',    Color(0xFF69F0AE)),
    (RestorationTool.biochar,   '⬛', 'Biochar',    'Dry Soil ①  •  Erosion Gully ②',   Color(0xFFBCAAA4)),
    (RestorationTool.compost,   '🌿', 'Compost',    'Bare Land ②  •  Dry Soil ②',       Color(0xFF8BC34A)),
  ];

  @override
  void initState() {
    super.initState();
    _ctrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 280))..forward();
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack);
    _fade  = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  void _pick(RestorationTool tool) {
    if (_applying != null) return;
    HapticFeedback.lightImpact();
    setState(() => _applying = tool);
    widget.game.selectTool(tool);
    Future.delayed(const Duration(milliseconds: 240), () {
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.game.applyTool();
    });
  }

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.of(context).size.width < 600;
    final target = widget.game._nearestActionable;
    final step   = target?.step ?? RestorationStep.none;
    final type   = target?.type;

    return AnimatedBuilder(
      animation: widget.game,
      builder: (_, __) => FadeTransition(
        opacity: _fade,
        child: ScaleTransition(
          scale: _scale,
          child: Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: EdgeInsets.symmetric(horizontal: mobile ? 14 : 80, vertical: 60),
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              decoration: BoxDecoration(
                color: const Color(0xFF0A0E06),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF69F0AE).withValues(alpha: 0.42), width: 1.5),
                boxShadow: [
                  BoxShadow(color: const Color(0xFF69F0AE).withValues(alpha: 0.12), blurRadius: 32, spreadRadius: 4),
                  const BoxShadow(color: Colors.black54, blurRadius: 20),
                ],
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [

                Row(children: [
                  const Text('🛠️', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('SELECT RESTORATION TOOL',
                      style: TextStyle(color: Colors.white70, fontSize: 10,
                          fontWeight: FontWeight.w900, letterSpacing: 1.6))),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Icon(Icons.close_rounded, color: Colors.white30, size: 18),
                  ),
                ]),
                const SizedBox(height: 4),

                if (target != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(8)),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(_typeIcon(type!), style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 6),
                      Text(
                        '${_typeName(type)}  •  ${step == RestorationStep.none
                            ? 'Needs Structural Fix (Step ①)'
                            : 'Needs Biological Treatment (Step ②)'}',
                        style: TextStyle(
                          color: step == RestorationStep.none
                              ? const Color(0xFFEF5350) : const Color(0xFF69F0AE),
                          fontSize: 9.5, fontWeight: FontWeight.w700,
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 10),
                ] else ...[
                  const Padding(padding: EdgeInsets.symmetric(vertical: 6),
                      child: Text('Move closer to a degraded patch first',
                          style: TextStyle(color: Colors.white38, fontSize: 10))),
                  const SizedBox(height: 8),
                ],

                ..._tools.map((spec) {
                  final (tool, emoji, label, hint, color) = spec;
                  final uses    = widget.game.toolUses[tool] ?? 0;
                  final out     = uses == 0;
                  final picking = _applying == tool;
                  final correct = target != null &&
                      widget.game._isCorrectTool(target.type, tool, step);

                  return GestureDetector(
                    onTap: out ? null : () => _pick(tool),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.only(bottom: 7),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                      decoration: BoxDecoration(
                        color: picking ? color.withValues(alpha: 0.28)
                            : out     ? Colors.white.withValues(alpha: 0.03)
                            : correct ? color.withValues(alpha: 0.10)
                            : Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: picking ? color.withValues(alpha: 0.92)
                              : out     ? Colors.white12
                              : correct ? color.withValues(alpha: 0.58)
                              : Colors.white.withValues(alpha: 0.10),
                          width: (picking || correct) ? 1.8 : 1.0,
                        ),
                        boxShadow: picking
                            ? [BoxShadow(color: color.withValues(alpha: 0.42), blurRadius: 14)]
                            : correct && !out
                                ? [BoxShadow(color: color.withValues(alpha: 0.18), blurRadius: 8)]
                                : [],
                      ),
                      child: Row(children: [
                        Container(width: 36, height: 36,
                          decoration: BoxDecoration(shape: BoxShape.circle,
                            color: out ? Colors.white.withValues(alpha: 0.04) : color.withValues(alpha: 0.15),
                            border: Border.all(color: out ? Colors.white12 : color.withValues(alpha: 0.42)),
                          ),
                          child: Center(child: Text(emoji, style: const TextStyle(fontSize: 17))),
                        ),
                        const SizedBox(width: 11),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(label, style: TextStyle(
                              color: out ? Colors.white24 : picking ? color : Colors.white,
                              fontWeight: FontWeight.w800, fontSize: 13)),
                          const SizedBox(height: 1),
                          Text(hint, style: TextStyle(
                              color: out ? Colors.white12 : color.withValues(alpha: 0.72),
                              fontSize: 9.5)),
                        ])),
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: out ? Colors.redAccent.withValues(alpha: 0.12) : color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: out ? Colors.redAccent.withValues(alpha: 0.40) : color.withValues(alpha: 0.32)),
                            ),
                            child: Text(out ? 'EMPTY' : '×$uses left',
                                style: TextStyle(color: out ? Colors.redAccent : color,
                                    fontSize: 8, fontWeight: FontWeight.bold)),
                          ),
                          if (correct && !out) ...[
                            const SizedBox(height: 3),
                            Text('✓ correct',
                                style: TextStyle(color: color.withValues(alpha: 0.80),
                                    fontSize: 8, fontWeight: FontWeight.bold)),
                          ],
                        ]),
                      ]),
                    ),
                  );
                }),

                const SizedBox(height: 3),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  _dot(const Color(0xFFEF5350), '① Structural'),
                  const SizedBox(width: 16),
                  _dot(const Color(0xFF69F0AE), '② Biological'),
                ]),
                const SizedBox(height: 5),
                const Text('Tap tool to apply  •  ✓ = correct for this patch',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white24, fontSize: 8.5)),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  String _typeIcon(DegradationType t) {
    switch (t) {
      case DegradationType.steepSlope: return '⛰️';
      case DegradationType.gully:      return '🕳️';
      case DegradationType.bareLand:   return '🌾';
      case DegradationType.drySoil:    return '🪨';
    }
  }

  String _typeName(DegradationType t) {
    switch (t) {
      case DegradationType.steepSlope: return 'Steep Slope';
      case DegradationType.gully:      return 'Erosion Gully';
      case DegradationType.bareLand:   return 'Bare Land';
      case DegradationType.drySoil:    return 'Dry Soil';
    }
  }

  Widget _dot(Color c, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 7, height: 7, decoration: BoxDecoration(shape: BoxShape.circle, color: c)),
    const SizedBox(width: 4),
    Text(label, style: TextStyle(color: c.withValues(alpha: 0.76), fontSize: 8, fontWeight: FontWeight.w600)),
  ]);
}

// ══════════════════════════════════════════════════════════════════════════════
//  WEATHER ALERT OVERLAY
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
        return IgnorePointer(child: Align(
          alignment: Alignment.topCenter,
          child: SafeArea(child: Container(
            margin: const EdgeInsets.only(top: 62),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1B2A).withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF29B6F6).withValues(alpha: 0.72), width: 1.5),
              boxShadow: [BoxShadow(color: const Color(0xFF29B6F6).withValues(alpha: 0.28), blurRadius: 22)],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Text('⛈️', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              const Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('RAIN EVENT INCOMING',
                    style: TextStyle(color: Color(0xFF29B6F6), fontSize: 11,
                        fontWeight: FontWeight.w900, letterSpacing: 1.4)),
                SizedBox(height: 2),
                Text(
                  'Step-1 stabilised patches are at risk of regression.\nApply Step 2 before rain hits!',
                  style: TextStyle(color: Colors.white60, fontSize: 10),
                ),
              ]),
              const SizedBox(width: 12),
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(shape: BoxShape.circle,
                    color: const Color(0xFF29B6F6).withValues(alpha: 0.12),
                    border: Border.all(color: const Color(0xFF29B6F6).withValues(alpha: 0.52))),
                child: Center(child: Text('${cd.ceil()}',
                    style: const TextStyle(color: Color(0xFF29B6F6),
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
        : (!inRange ? '🛰️  Out of Range — move closer'
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

      // Combo flash
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
//  COMPLETION BANNER  — auto-dismissing popup that shows BEFORE the results
//  screen.  Three distinct visual states map to LevelCompletionState.
// ══════════════════════════════════════════════════════════════════════════════
class LandCompletionBanner extends StatefulWidget {
  final LandDegradationGame game;
  const LandCompletionBanner(this.game, {super.key});

  @override
  State<LandCompletionBanner> createState() => _LandCompletionBannerState();
}

class _LandCompletionBannerState extends State<LandCompletionBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _scale;
  late final Animation<double>   _fade;

  @override
  void initState() {
    super.initState();
    _ctrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 380));
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack);
    _fade  = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _ctrl.forward();

    // After 5 s (380 ms scale-in + 4620 ms hold), dismiss and show results.
    Future.delayed(const Duration(milliseconds: 5000), () {
      if (!mounted) return;
      widget.game.overlays
        ..remove('completionBanner')
        ..add('results');
    });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final r     = LandDegradationResult.current!;
    final state = r.completionState;
    final total = widget.game.patches.length;

    // ── Per-state visuals ──────────────────────────────────────────────────
    final String topEmoji;
    final String title;
    final String subtitle;
    final List<Color> bgGrad;
    final Color glow;

    switch (state) {
      case LevelCompletionState.fullCompletion:
        topEmoji = '🏆';
        title    = 'FULL RESTORATION!';
        subtitle = 'All $total patches restored — outstanding fieldwork!';
        bgGrad   = [const Color(0xFF003D14), const Color(0xFF005A1E)];
        glow     = const Color(0xFF69F0AE);
        break;
      case LevelCompletionState.moderate:
        topEmoji = '✅';
        title    = 'MINIMUM ACHIEVED!';
        subtitle = '${r.patchesRestored}/$total patches restored\n'
            'Continuing to Soil Remediation…';
        bgGrad   = [const Color(0xFF3B2600), const Color(0xFF5A3800)];
        glow     = const Color(0xFFFFB300);
        break;
      case LevelCompletionState.failed:
        topEmoji = '⏰';
        title    = 'NOT ENOUGH RESTORED';
        subtitle = '${r.patchesRestored}/${r.minimumRequired} patches restored\n'
            'Replay to reach the minimum';
        bgGrad   = [const Color(0xFF3D0000), const Color(0xFF5A0000)];
        glow     = const Color(0xFFEF5350);
        break;
    }

    return Container(
      color: Colors.black.withValues(alpha: 0.75),
      child: Center(
        child: FadeTransition(
          opacity: _fade,
          child: ScaleTransition(
            scale: _scale,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 28),
              padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: bgGrad,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: glow.withValues(alpha: 0.55), width: 2.0),
                boxShadow: [
                  BoxShadow(color: glow.withValues(alpha: 0.35),
                      blurRadius: 36, spreadRadius: 3),
                ],
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                // Big emoji
                Text(topEmoji, style: const TextStyle(fontSize: 62)),
                const SizedBox(height: 12),
                // State title
                Text(title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: glow, fontSize: 22,
                      fontWeight: FontWeight.w900, letterSpacing: 1.4,
                    )),
                const SizedBox(height: 10),
                // Subtitle / reason
                Text(subtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 13.5, height: 1.55)),
                const SizedBox(height: 20),
                // Quick-stats pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
                  decoration: BoxDecoration(
                    color: glow.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: glow.withValues(alpha: 0.38)),
                  ),
                  child: Text(
                    '🌿 ${r.patchesRestored}/$total Restored  •  '
                    '⭐ ${r.ecoPoints} pts  •  🎯 ${r.accuracyPct}% acc',
                    style: TextStyle(
                        color: glow, fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 16),
                // Auto-dismiss hint
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  SizedBox(
                    width: 12, height: 12,
                    child: CircularProgressIndicator(
                        strokeWidth: 1.5, color: glow.withValues(alpha: 0.5)),
                  ),
                  const SizedBox(width: 8),
                  const Text('Loading results…',
                      style: TextStyle(color: Colors.white38, fontSize: 10.5)),
                ]),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  RESULTS OVERLAY  — fully dynamic, no constant values
// ══════════════════════════════════════════════════════════════════════════════
class LandResultsOverlay extends StatelessWidget {
  final LandDegradationGame game;
  const LandResultsOverlay(this.game, {super.key});

  @override
  Widget build(BuildContext context) {
    final r          = LandDegradationResult.current!;
    final stabilised = r.terrainStabilised;
    final meetsMin   = r.meetsMinimum;
    final totalPatches = game.patches.length;
    final restored   = r.patchesRestored;
    final stars      = restored >= totalPatches - 1 ? '★★★'
                     : restored >= (totalPatches * 0.6).ceil() ? '★★☆'
                     : '★☆☆';

    return Container(
      color: Colors.black.withValues(alpha: 0.94),
      child: SafeArea(child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(children: [

          // ── Header card ─────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: stabilised
                  ? [const Color(0xFF001A0A), const Color(0xFF003018)]
                  : [const Color(0xFF1A1000), const Color(0xFF2A1800)]),
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 16)],
            ),
            child: Column(children: [
              Text(stabilised ? '🌿' : '🏜️', style: const TextStyle(fontSize: 50)),
              const SizedBox(height: 6),
              Text(stabilised ? 'Terrain Stabilised!' : 'Phase Complete',
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              // Dynamic performance grade — varies per player
              Text(r.performanceGrade,
                  style: TextStyle(
                    color: stabilised ? const Color(0xFF69F0AE) : const Color(0xFFFFB300),
                    fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 1.0,
                  )),
              const SizedBox(height: 4),
              const Text('Phase 1 & 2 — Land Degradation Results',
                  style: TextStyle(color: Colors.white54, fontSize: 12)),
              const SizedBox(height: 8),
              // Stars based on dynamic total patch count
              Text(stars, style: const TextStyle(
                  color: Color(0xFFFFB300), fontSize: 28, letterSpacing: 6)),
              if (stabilised) ...[
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
                    Text('Terrain Stabiliser Badge Unlocked!',
                        style: TextStyle(color: Color(0xFF69F0AE),
                            fontWeight: FontWeight.w800, fontSize: 11.5)),
                  ]),
                ),
              ],
            ]),
          ),

          const SizedBox(height: 14),

          // ── Restoration progress (dynamic patch count) ────────────────────
          _LRCard(children: [
            _LRBig('🌿', '$restored/$totalPatches', 'Restored',  Colors.limeAccent),
            _LRBig('🏗️', '${r.patchesStabilized}/$totalPatches', 'Step 1',    const Color(0xFF29B6F6)),
            _LRBig('🛰️', '${r.scannedPatches}/$totalPatches',    'Scanned',   const Color(0xFFFFB300)),
          ]),

          const SizedBox(height: 8),

          // ── Tool accuracy (all dynamic) ────────────────────────────────────
          _LRCard(children: [
            _LRBig('✅', '${r.correctTools}',  'Correct',  const Color(0xFF69F0AE)),
            _LRBig('❌', '${r.wrongTools}',    'Wrong',    Colors.redAccent),
            _LRBig('🎯', '${r.accuracyPct}%',  'Accuracy', r.accuracyPct >= 70
                ? const Color(0xFF69F0AE)
                : r.accuracyPct >= 40 ? const Color(0xFFFFB300) : Colors.redAccent),
            _LRBig('🔥', '${r.maxCombo}×',     'Max Combo', const Color(0xFFFF6D00)),
          ]),

          const SizedBox(height: 8),

          // ── Erosion & points ───────────────────────────────────────────────
          _LRCard(children: [
            _LRBig('🏜️', '${r.erosionIndex.toStringAsFixed(0)}%', 'Erosion',
                stabilised ? const Color(0xFF69F0AE) : const Color(0xFFFFB300)),
            _LRBig('⭐', '${r.ecoPoints}', 'Eco-Points', Colors.amber),
            if (r.scanStreakBonus > 0)
              _LRBig('🎯', '+${r.scanStreakBonus}', 'Streak Pts', const Color(0xFFE040FB)),
          ]),

          const SizedBox(height: 8),

          // ── Dynamic bonus events row ───────────────────────────────────────
          _LRCard(children: [
            _LRBig('⚡', '${r.criticalSaves}', 'Crits Saved', Colors.redAccent),
            _LRBig('🌍', '${r.ecoDiscoveriesFound}/2', 'Discoveries', const Color(0xFFE040FB)),
            _LRBig('⏱️', r.timeBonusCollected ? 'YES' : 'NO', 'Time Bonus',
                r.timeBonusCollected ? const Color(0xFFFFD700) : Colors.white38),
            if (r.gulliesExpanded > 0)
              _LRBig('⚠️', '${r.gulliesExpanded}', 'Gullies\nExpanded', Colors.orange),
          ]),

          const SizedBox(height: 10),

          // ── Personalised performance summary (dynamic per player) ──────────
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

          // ── Why the level ended (clear feedback) ───────────────────────
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

          const SizedBox(height: 10),

          // ── Two-step reference guide ───────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: const Color(0xFF0A1A08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(children: [
              const Text('Two-Step Restoration Applied',
                  style: TextStyle(color: Colors.white70, fontSize: 12,
                      fontWeight: FontWeight.bold, letterSpacing: 1)),
              const SizedBox(height: 10),
              _LRRow('⛰️', 'Steep Slopes',    '① Terraces  →  ② Cover Crops'),
              _LRRow('🕳️', 'Erosion Gullies', '① Check Dams  →  ② Biochar'),
              _LRRow('🌾', 'Bare Land',        '① Cover Crops  →  ② Compost'),
              _LRRow('🪨', 'Dry Soil',         '① Biochar  →  ② Compost'),
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

          // ── Primary action: REPLAY if below minimum, CONTINUE if met ───────
          SizedBox(
            width: double.infinity,
            child: meetsMin
                ? ElevatedButton.icon(
                    onPressed: () {
                      game.resumeEngine();
                      game.onLevelComplete();
                    },
                    icon: const Icon(Icons.biotech_rounded),
                    label: const Text('Continue to Soil Remediation  →',
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
                    // Replay button (primary action when below minimum)
                    ElevatedButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.replay_rounded),
                      label: Text(
                        'Replay  — Restore ${r.minimumRequired - r.patchesRestored} More Patch(es)',
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
                    // Minimum requirement reminder
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFB300).withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFFB300).withValues(alpha: 0.35)),
                      ),
                      child: Text(
                        '💡 Tip: Fly near a degraded zone and tap SCAN.\n'
                        'Read the identified issue, tap FIX IT, then pick the right tool.\n'
                        'Minimum ${r.minimumRequired} fully restored patches needed to advance.',
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

class _LRCard extends StatelessWidget {
  final List<Widget> children;
  const _LRCard({required this.children});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
    decoration: BoxDecoration(color: const Color(0xFF0A1A08),
        borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white12)),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: children),
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
        const SizedBox(height: 3),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 17)),
        const SizedBox(height: 2),
        Text(label, textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white54, fontSize: 8.5)),
      ]);
}

class _LRRow extends StatelessWidget {
  final String emoji, label, action;
  const _LRRow(this.emoji, this.label, this.action);
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