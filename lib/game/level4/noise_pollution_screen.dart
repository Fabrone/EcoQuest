import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:ecoquest/game/level4/air_noise_city_screen.dart';
import 'package:ecoquest/game/level4/level4_complete_screen.dart';
import 'package:flame/components.dart' hide Matrix4;
import 'package:flame/game.dart' hide Matrix4;
import 'package:flutter/material.dart' hide Matrix4;
import 'package:flutter/services.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  NOISE RESULT  — passed to Level4CompleteScreen via static holder
// ══════════════════════════════════════════════════════════════════════════════
class NoiseResult {
  final int hotspotsFix;
  final int wrongTools;
  final int ecoPoints;
  final double noiseMeterFinal;
  final bool peacefulCityBadge;
  final int windEvades;
  final int scanComboMax;
  final bool meetsMinimum;
  final int minimumRequired;
  final int scannedCount;
  final int maxCombo;
  final String endReason;
  final LevelCompletionState completionState;

  const NoiseResult({
    required this.hotspotsFix,
    required this.wrongTools,
    required this.ecoPoints,
    required this.noiseMeterFinal,
    required this.peacefulCityBadge,
    required this.windEvades,
    required this.scanComboMax,
    required this.meetsMinimum,
    required this.minimumRequired,
    this.scannedCount = 0,
    this.maxCombo = 1,
    this.endReason = 'Level completed.',
    this.completionState = LevelCompletionState.failed,
  });

  static NoiseResult? current;
}

// ══════════════════════════════════════════════════════════════════════════════
//  ENUMS
// ══════════════════════════════════════════════════════════════════════════════
enum NoiseType { 
  traffic, 
  construction, 
  loudspeaker, 
  vegetation,
  industrial,
  aircraft,
  railway,
  nightclub,
}

enum NoiseTool { 
  electricMuffler, 
  silentMachinery, 
  silentZone, 
  treeBarrier,
  noiseBarrier,
  flightPath,
  trackDampener,
  soundInsulation,
}

enum WindIntensity { light, moderate, heavy }

enum LevelCompletionState { failed, moderate, fullCompletion }

enum ReactionKind {
  scanLocked,
  scanMiss,
  scanPartial,
  windSlow,
  noCharge,
  windEvade,
  fixCorrect,
  fixWrong,
}

// ══════════════════════════════════════════════════════════════════════════════
//  SCAN RESULT  — shows once, then memory only
// ══════════════════════════════════════════════════════════════════════════════
class NoiseScanResult {
  final String icon;
  final String typeName;
  final String dbLevel;
  final Color color;
  final String ecoFact;
  final String requiredTool;
  final String requiredToolEmoji;

  const NoiseScanResult({
    required this.icon,
    required this.typeName,
    required this.dbLevel,
    required this.color,
    required this.ecoFact,
    required this.requiredTool,
    required this.requiredToolEmoji,
  });

  factory NoiseScanResult.forType(NoiseType type) {
    switch (type) {
      case NoiseType.traffic:
        return const NoiseScanResult(
          icon: '🚗',
          typeName: 'Vehicle Honking',
          dbLevel: '85 dB',
          color: Color(0xFFEF5350),
          ecoFact: 'Traffic noise above 80 dB causes chronic stress. Electric mufflers reduce engine noise by up to 70%.',
          requiredTool: 'Electric Muffler',
          requiredToolEmoji: '⚡',
        );
      case NoiseType.construction:
        return const NoiseScanResult(
          icon: '🏗️',
          typeName: 'Construction Site',
          dbLevel: '90 dB',
          color: Color(0xFFFF6D00),
          ecoFact: 'Construction noise peaks at 90+ dB. Silent machinery enclosures cut noise by 15–20 dB without slowing work.',
          requiredTool: 'Silent Machinery',
          requiredToolEmoji: '🔕',
        );
      case NoiseType.loudspeaker:
        return const NoiseScanResult(
          icon: '📢',
          typeName: 'Loud Speaker',
          dbLevel: '78 dB',
          color: Color(0xFFCE93D8),
          ecoFact: 'Unregulated loudspeakers disrupt wildlife communication. Silent zones restore acoustic ecology.',
          requiredTool: 'Silent Zone',
          requiredToolEmoji: '🚫',
        );
      case NoiseType.vegetation:
        return const NoiseScanResult(
          icon: '🌿',
          typeName: 'Sparse Vegetation',
          dbLevel: '72 dB',
          color: Color(0xFF78909C),
          ecoFact: 'Dense tree barriers absorb 6–10 dB of noise. Native species create natural sound corridors.',
          requiredTool: 'Tree Barrier',
          requiredToolEmoji: '🌲',
        );
      case NoiseType.industrial:
        return const NoiseScanResult(
          icon: '🏭',
          typeName: 'Industrial Plant',
          dbLevel: '95 dB',
          color: Color(0xFF8D6E63),
          ecoFact: 'Industrial noise from factories can reach 95 dB. Noise barriers absorb and deflect sound waves effectively.',
          requiredTool: 'Noise Barrier',
          requiredToolEmoji: '🧱',
        );
      case NoiseType.aircraft:
        return const NoiseScanResult(
          icon: '✈️',
          typeName: 'Aircraft Overflight',
          dbLevel: '88 dB',
          color: Color(0xFF5C6BC0),
          ecoFact: 'Aircraft noise at 88 dB disrupts sleep patterns. Optimized flight paths reduce community exposure.',
          requiredTool: 'Flight Path',
          requiredToolEmoji: '🛫',
        );
      case NoiseType.railway:
        return const NoiseScanResult(
          icon: '🚆',
          typeName: 'Railway Noise',
          dbLevel: '82 dB',
          color: Color(0xFF26A69A),
          ecoFact: 'Railway noise at 82 dB vibrates through foundations. Track dampeners reduce vibration transmission.',
          requiredTool: 'Track Dampener',
          requiredToolEmoji: '🛤️',
        );
      case NoiseType.nightclub:
        return const NoiseScanResult(
          icon: '🎵',
          typeName: 'Nightclub District',
          dbLevel: '92 dB',
          color: Color(0xFFAB47BC),
          ecoFact: 'Nightclub districts hit 92 dB at night. Sound insulation in buildings protects residents while allowing nightlife.',
          requiredTool: 'Sound Insulation',
          requiredToolEmoji: '🏠',
        );
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  WIND ZONE  (Phase hazard — now only slows scanning)
// ══════════════════════════════════════════════════════════════════════════════
class WindZone {
  double cx, cy;
  final double radius;
  double angle;
  final double speed;
  final WindIntensity intensity;
  double lifetime;
  final double maxLifetime;
  bool isActive = true;
  double animT = 0;

  WindZone({
    required this.cx,
    required this.cy,
    required this.radius,
    required this.angle,
    required this.speed,
    required this.intensity,
    required this.lifetime,
  }) : maxLifetime = lifetime;

  void update(double dt, double worldW, double worldH) {
    if (!isActive) return;
    animT += dt;
    cx += math.cos(angle) * speed * dt;
    cy += math.sin(angle) * speed * dt;
    lifetime -= dt;
    if (lifetime <= 0) {
      isActive = false;
      return;
    }
    if (cy < 90) {
      cy = 90;
      angle = _reflectV(angle);
    }
    if (cy > worldH * 0.9) {
      cy = worldH * 0.9;
      angle = _reflectV(angle);
    }
    if (cx < -radius * 1.5) cx = worldW + radius;
    if (cx > worldW + radius * 1.5) cx = -radius;
  }

  double _reflectV(double a) => -a;

  bool containsPoint(Vector2 p) => (Vector2(cx, cy) - p).length < radius;

  double intensityAt(Vector2 p) =>
      (1.0 - (Vector2(cx, cy) - p).length / radius).clamp(0.0, 1.0);

  Color get color {
    switch (intensity) {
      case WindIntensity.light:
        return const Color(0xFF80DEEA);
      case WindIntensity.moderate:
        return const Color(0xFFFFB300);
      case WindIntensity.heavy:
        return const Color(0xFFEF5350);
    }
  }

  double get strengthFactor {
    switch (intensity) {
      case WindIntensity.light:
        return 0.35;
      case WindIntensity.moderate:
        return 0.65;
      case WindIntensity.heavy:
        return 1.00;
    }
  }

  /// NEW: Wind only slows scan rate, never blocks
  double get scanSlowFactor {
    switch (intensity) {
      case WindIntensity.light:
        return 0.85;  // 15% slower
      case WindIntensity.moderate:
        return 0.60;  // 40% slower
      case WindIntensity.heavy:
        return 0.35;  // 65% slower
    }
  }

  double get fadeAlpha {
    final t = lifetime / maxLifetime;
    if (t < 0.12) return t / 0.12;
    if (t > 0.85) return (1 - t) / 0.15;
    return 1.0;
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  SCAN RING  (visual ripple)
// ══════════════════════════════════════════════════════════════════════════════
class ScanRing {
  double radius;
  double alpha;
  final bool disrupted;
  ScanRing({
    required this.radius,
    required this.alpha,
    required this.disrupted,
  });
}

// ══════════════════════════════════════════════════════════════════════════════
//  SCREEN WRAPPER
// ══════════════════════════════════════════════════════════════════════════════
class NoisePollutionScreen extends StatefulWidget {
  final Level3CarryOver carryOver;
  const NoisePollutionScreen({super.key, required this.carryOver});

  @override
  State<NoisePollutionScreen> createState() => _NoisePollutionScreenState();
}

class _NoisePollutionScreenState extends State<NoisePollutionScreen> {
  late NoisePollutionGame _game;

  @override
  void initState() {
    super.initState();
    _game = NoisePollutionGame(
      carryOver: widget.carryOver,
      onLevelComplete: _onDone,
    );
  }

  void _onDone() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => Level4CompleteScreen(carryOver: widget.carryOver),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GameWidget(
        game: _game,
        overlayBuilderMap: {
          'hud': (ctx, g) => NoiseHud(g as NoisePollutionGame),
          'controls': (ctx, g) => NoiseControls(g as NoisePollutionGame),
          'banner': (ctx, g) => NoisePhaseBanner(g as NoisePollutionGame),
          'scanResult': (ctx, g) => NoiseScanResultOverlay(g as NoisePollutionGame),
          'toolSelect': (ctx, g) => NoiseToolSelector(g as NoisePollutionGame),
          'reactionFx': (ctx, g) => NoiseReactionFx(g as NoisePollutionGame),
          'results': (ctx, g) => NoiseResultsOverlay(g as NoisePollutionGame),
          'completionBanner': (ctx, g) => NoiseCompletionBanner(g as NoisePollutionGame),
          'liveMetrics': (ctx, g) => NoiseLiveMetrics(g as NoisePollutionGame),
        },
        initialActiveOverlays: const ['hud', 'controls', 'liveMetrics'],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  WORLD CONSTANTS
// ══════════════════════════════════════════════════════════════════════════════
class _World {
  static const double kScale = 3.0;
  static const double kEdgeFraction = 0.22;
  static const double kCameraEase = 5.0;
}

// ══════════════════════════════════════════════════════════════════════════════
//  MAIN GAME CLASS
// ══════════════════════════════════════════════════════════════════════════════
class NoisePollutionGame extends FlameGame
    with HasCollisionDetection, ChangeNotifier {
  final Level3CarryOver carryOver;
  final VoidCallback onLevelComplete;

  NoisePollutionGame({required this.carryOver, required this.onLevelComplete});

  // ── Minimum hotspots required to proceed (like land degradation) ───────────
  static const int kMinSolutionsRequired = 8;

  // ── Core state ────────────────────────────────────────────────────────────
  bool gameStarted = false;
  double timeLeft = 180.0;
  bool levelDone = false;

  // ── Score ─────────────────────────────────────────────────────────────────
  int ecoPoints = 0;
  int wrongTools = 0;
  int fixedCount = 0;
  int scannedCount = 0;

  // ── Noise meter ───────────────────────────────────────────────────────────
  double noiseMeter = 96.0;
  static const double _targetNoise = 40.0;
  static const double _fixReduction = 8.0;
  static const double _wrongPenalty = 2.0;

  // ── World / camera ────────────────────────────────────────────────────────
  double worldW = 0;
  double worldH = 0;
  double camX = 0;
  double camY = 0;
  double _targetCamX = 0;
  double _targetCamY = 0;
  double edgeHintLeft = 0;
  double edgeHintRight = 0;
  double edgeHintTop = 0;
  double edgeHintBottom = 0;

  // ── Range constants (world units) ─────────────────────────────────────────
  static const double _scanRange = 155.0;
  static const double _applyRange = 130.0;
  static const double _scanMaxRadius = 180.0;

  // ── Drone physics (world coords) ──────────────────────────────────────────
  late Vector2 dronePos;
  bool isUp = false, isDown = false, isLeft = false, isRight = false;
  static const double _droneSpeed = 200.0;

  double droneWindTiltX = 0;
  double droneWindTiltY = 0;

  // ── Tool selection ─────────────────────────────────────────────────────────
  NoiseTool selectedTool = NoiseTool.electricMuffler;
  NoiseHotspot? pendingFixTarget;
  bool toolSelectorOpen = false;

  // ── Wind zones ────────────────────────────────────────────────────────────
  final List<WindZone> windZones = [];
  double _windSpawnTimer = 0;
  double _windSpawnCooldown = 8.0;
  final _rng = math.Random();

  /// NEW: Wind only slows scanning, never blocks
  double get currentWindSlowFactor {
    double factor = 1.0;
    for (final z in windZones) {
      if (!z.isActive || !z.containsPoint(dronePos)) continue;
      factor = math.min(factor, z.scanSlowFactor);
    }
    return factor;
  }

  bool get isInAnyWind =>
      windZones.any((z) => z.isActive && z.containsPoint(dronePos));

  WindZone? get dominantWindZone {
    WindZone? best;
    double bestI = 0;
    for (final z in windZones) {
      if (!z.isActive) continue;
      final i = z.intensityAt(dronePos);
      if (i > bestI) {
        bestI = i;
        best = z;
      }
    }
    return best;
  }

  bool _wasInWind = false;
  int windEvades = 0;
  double _evadeShowTimer = 0;

  // ── NEW: Scan lock system (like LandDegradation) ─────────────────────────
  NoiseHotspot? activeScanTarget;
  bool scanLockActive = false;
  double _scanLockTimer = 0;
  static const double _scanDuration = 1.5;
  bool scanActive = false;
  double scanRadius = 0;
  double scanHoldTime = 0;

  // ── Show-once hint system (like land) ──────────────────────────────────────
  final Set<NoiseType> _seenNoiseTypes = {};
  bool toolSelectorShowsHints = true;
  bool scanResultShowsHints = true;
  bool scanResultActive = false;
  NoiseScanResult? lastScanResult;
  double scanResultTimer = 0;
  static const double _scanResultDisplay = 4.0;
  NoiseHotspot? lastScannedHotspot;
  int lastScanPoints = 0;

  // ── Combo ─────────────────────────────────────────────────────────────────
  int scanCombo = 0;
  int scanComboMax = 1;
  double _comboDecayTimer = 0;
  static const double _comboWindow = 9.0;

  // ── Reaction FX ──────────────────────────────────────────────────────────
  bool reactionActive = false;
  bool reactionCorrect = false;
  int reactionPhase = 1;
  bool reactionInRange = true;
  double reactionTimer = 0;
  ReactionKind reactionKind = ReactionKind.scanLocked;
  int reactionCombo = 0;

  // ── Banner / intro ────────────────────────────────────────────────────────
  double bannerTimer = 4.0;

  // ── Scan ripples ──────────────────────────────────────────────────────────
  final List<ScanRing> scanRings = [];

  // ── Components ────────────────────────────────────────────────────────────
  late EcoDroneComponent drone;
  final List<NoiseHotspot> hotspots = [];
  double _refillTimer = 0;
  static const double _refillInterval = 18.0;

  // ── Nearest target for UI hint ────────────────────────────────────────────
  NoiseHotspot? _nearestScanTarget;

  // ── Mini-map explored fraction ────────────────────────────────────────────
  double get exploredFraction {
    if (hotspots.isEmpty) return 0.0;
    final fixed = hotspots.where((h) => h.isFixed).length;
    return fixed / hotspots.length;
  }

  // ── Hotspot helpers (world coords) ───────────────────────────────────────
  NoiseHotspot? get _nearestSonarTarget {
    NoiseHotspot? best;
    double bestD = _scanRange;
    for (final h in hotspots) {
      if (h.isScanned || h.isFixed) continue;
      final d = (h.hotspotPos - dronePos).length;
      if (d < bestD) {
        bestD = d;
        best = h;
      }
    }
    return best;
  }

  NoiseHotspot? get _nearestScannedUnfixed {
    NoiseHotspot? target;
    double best = _applyRange;
    for (final h in hotspots) {
      if (!h.isScanned || h.isFixed) continue;
      final d = (h.hotspotPos - dronePos).length;
      if (d < best) {
        best = d;
        target = h;
      }
    }
    return target;
  }

  Vector2 screenToWorld(Vector2 s) => Vector2(s.x + camX, s.y + camY);
  Vector2 worldToScreen(Vector2 w) => Vector2(w.x - camX, w.y - camY);
  Vector2 get droneScreen => worldToScreen(dronePos);

  @override
  Future<void> onLoad() async {
    super.onLoad();
    worldW = size.x * _World.kScale;
    worldH = size.y * _World.kScale;

    dronePos = Vector2(worldW * 0.50, worldH * 0.50);
    _centerCamOn(dronePos);
    _targetCamX = camX;
    _targetCamY = camY;

    add(NoiseCityRenderer(game: this));
    _seedInitialHotspots();
    add(WindZoneRenderer(game: this));
    drone = EcoDroneComponent(game: this);
    add(drone);

    bannerTimer = 4.0;
    overlays.add('banner');
    add(TimerComponent(period: 1.0, repeat: true, onTick: _onSecond));
  }

  void _centerCamOn(Vector2 pos) {
    camX = (pos.x - size.x / 2).clamp(0.0, worldW - size.x);
    camY = (pos.y - size.y / 2).clamp(0.0, worldH - size.y);
  }

  void _seedInitialHotspots() {
    _spawnHotspotBatch(
      dronePos,
      radius: worldW * 0.45,
      count: 16,
      batchSeed: 0,
    );
  }

  void _spawnHotspotBatch(
    Vector2 centre, {
    required double radius,
    required int count,
    required int batchSeed,
  }) {
    final rng = math.Random(batchSeed + hotspots.length * 7);
    int placed = 0;
    int attempts = 0;
    while (placed < count && attempts < count * 8) {
      attempts++;
      final angle = rng.nextDouble() * math.pi * 2;
      final dist = 120.0 + rng.nextDouble() * radius;
      final wx = (centre.x + math.cos(angle) * dist).clamp(80.0, worldW - 80.0);
      final wy = (centre.y + math.sin(angle) * dist).clamp(80.0, worldH - 80.0);
      final candidate = Vector2(wx, wy);

      final tooClose = hotspots.any(
        (h) => (h.hotspotPos - candidate).length < 110,
      );
      if (tooClose) continue;

      final type = NoiseType.values[rng.nextInt(NoiseType.values.length)];
      final h = NoiseHotspot(
        game: this,
        type: type,
        worldX: wx,
        worldY: wy,
        seed: batchSeed * 31 + placed * 19 + attempts,
      );
      add(h);
      hotspots.add(h);
      placed++;
    }
  }

  void _tryRefillHotspots() {
    final remaining = hotspots.where((h) => !h.isFixed).length;
    if (remaining < 4) {
      _spawnHotspotBatch(
        dronePos,
        radius: worldW * 0.30,
        count: 8,
        batchSeed: hotspots.length * 13 + DateTime.now().millisecond,
      );
    }
  }

  void _onSecond() {
    if (!gameStarted || levelDone) return;
    timeLeft -= 1;
    if (timeLeft <= 0) {
      timeLeft = 0;
      _endLevel();
    }
    notifyListeners();
  }

  void _spawnWindZone() {
    final edge = _rng.nextInt(3);
    double cx, cy, angle;
    switch (edge) {
      case 0:
        cx = camX - 70;
        cy = camY + size.y * (0.10 + _rng.nextDouble() * 0.68);
        angle = -0.45 + _rng.nextDouble() * 0.9;
        break;
      case 1:
        cx = camX + size.x * (0.10 + _rng.nextDouble() * 0.80);
        cy = camY - 70;
        angle = math.pi * 0.25 + _rng.nextDouble() * math.pi * 0.50;
        break;
      default:
        cx = camX + size.x + 70;
        cy = camY + size.y * (0.10 + _rng.nextDouble() * 0.68);
        angle = math.pi - 0.45 + _rng.nextDouble() * 0.9;
    }
    final progress = fixedCount / math.max(1, hotspots.length).toDouble();
    WindIntensity intensity;
    if (progress < 0.40) {
      intensity = _rng.nextDouble() < 0.70
          ? WindIntensity.light
          : WindIntensity.moderate;
    } else if (progress < 0.70) {
      intensity = _rng.nextDouble() < 0.45
          ? WindIntensity.light
          : _rng.nextDouble() < 0.70
          ? WindIntensity.moderate
          : WindIntensity.heavy;
    } else {
      intensity = _rng.nextBool() ? WindIntensity.moderate : WindIntensity.heavy;
    }
    windZones.add(
      WindZone(
        cx: cx,
        cy: cy,
        radius: 85.0 + _rng.nextDouble() * 55.0,
        angle: angle,
        speed: 38.0 + _rng.nextDouble() * 32.0,
        intensity: intensity,
        lifetime: 6.5 + _rng.nextDouble() * 6.0,
      ),
    );
    _windSpawnCooldown = math.max(4.0, 8.0 - progress * 4.5);
  }

  // ── NEW: User-triggered SCAN (like LandDegradation.triggerScan) ────────────
  void triggerScan() {
    if (!gameStarted || levelDone) return;
    gameStarted = true;
    HapticFeedback.selectionClick();

    // If tool selector is open, scanning should not dismiss it
    if (toolSelectorOpen) {
      _triggerReaction(ReactionKind.noCharge);
      notifyListeners();
      return;
    }

    // If scan lock already active, do nothing (let it complete)
    if (scanLockActive) {
      _triggerReaction(ReactionKind.scanPartial);
      notifyListeners();
      return;
    }

    // Find nearest unscanned hotspot in range
    NoiseHotspot? nearest;
    double nearestD = _scanRange;
    for (final h in hotspots) {
      if (h.isScanned || h.isFixed) continue;
      final d = (h.hotspotPos - dronePos).length;
      if (d < nearestD) {
        nearestD = d;
        nearest = h;
      }
    }

    if (nearest == null) {
      scanActive = true;
      scanRadius = 0;
      _triggerReaction(ReactionKind.scanMiss);
      notifyListeners();
      return;
    }

    // Begin 1.5s lock-scan on this hotspot
    activeScanTarget = nearest;
    scanLockActive = true;
    _scanLockTimer = 0;
    scanHoldTime = 0;
    scanActive = true;
    scanRadius = 0;
    _triggerReaction(ReactionKind.scanPartial);
    HapticFeedback.lightImpact();
    notifyListeners();
  }

  // ── NEW: Complete scan (like LandDegradation._completePatchScan) ─────────
  void _completeHotspotScan(NoiseHotspot h) {
    if (h.isScanned) return;

    h.isScanned = true;
    scannedCount++;

    final pts = 10;
    ecoPoints += pts;
    lastScanPoints = pts;
    scanActive = true;
    scanRadius = 0;
    lastScannedHotspot = h;
    lastScanResult = NoiseScanResult.forType(h.type);

    // Show-once hint logic
    final firstScan = !_seenNoiseTypes.contains(h.type);
    if (firstScan) _seenNoiseTypes.add(h.type);
    scanResultShowsHints = firstScan;
    toolSelectorShowsHints = firstScan;

    scanResultTimer = _scanResultDisplay;
    scanResultActive = true;

    // Handle combo
    scanCombo++;
    if (scanCombo > scanComboMax) scanComboMax = scanCombo;
    _comboDecayTimer = _comboWindow;
    if (scanCombo >= 3) {
      final bonus = (scanCombo - 2) * 5;
      ecoPoints += bonus;
    }

    HapticFeedback.heavyImpact();

    // Reset lock state
    scanLockActive = false;
    _scanLockTimer = 0;
    activeScanTarget = null;

    overlays.add('scanResult');
    pendingFixTarget = h;
    notifyListeners();
  }

  // ── Called when player taps "FIX IT" on scan result card ─────────────────
  void openToolSelectorForPending() {
    if (pendingFixTarget == null || toolSelectorOpen) return;
    toolSelectorOpen = true;
    overlays.remove('scanResult');
    scanResultActive = false;
    overlays.add('toolSelect');
    notifyListeners();
  }

  void dismissScanResult() {
    if (!scanResultActive) return;
    scanResultActive = false;
    overlays.remove('scanResult');

    if (pendingFixTarget != null && !toolSelectorOpen) {
      toolSelectorOpen = true;
      overlays.add('toolSelect');
    }
    notifyListeners();
  }

  // ── APPLY TOOL ────────────────────────────────────────────────────────────
  void applyTool() {
    if (!gameStarted || levelDone) return;

    final target = pendingFixTarget ?? _nearestScannedUnfixed;
    if (target == null) {
      _triggerReaction(ReactionKind.scanMiss);
      notifyListeners();
      return;
    }

    HapticFeedback.lightImpact();
    final correct = _isCorrectTool(target.type, selectedTool);
    if (correct) {
      target.fix();
      fixedCount++;
      noiseMeter = math.max(0, noiseMeter - _fixReduction);
      ecoPoints += 15;
      _triggerReaction(ReactionKind.fixCorrect);
    } else {
      wrongTools++;
      noiseMeter = math.min(120, noiseMeter + _wrongPenalty);
      ecoPoints = math.max(0, ecoPoints - 10);
      _triggerReaction(ReactionKind.fixWrong);
    }

    pendingFixTarget = null;
    toolSelectorOpen = false;
    overlays.remove('toolSelect');

    if (noiseMeter <= _targetNoise) {
      Future.delayed(const Duration(milliseconds: 800), _endLevel);
    }

    notifyListeners();
  }

  bool _isCorrectTool(NoiseType t, NoiseTool tool) {
    switch (t) {
      case NoiseType.traffic:
        return tool == NoiseTool.electricMuffler;
      case NoiseType.construction:
        return tool == NoiseTool.silentMachinery;
      case NoiseType.loudspeaker:
        return tool == NoiseTool.silentZone;
      case NoiseType.vegetation:
        return tool == NoiseTool.treeBarrier;
      case NoiseType.industrial:
        return tool == NoiseTool.noiseBarrier;
      case NoiseType.aircraft:
        return tool == NoiseTool.flightPath;
      case NoiseType.railway:
        return tool == NoiseTool.trackDampener;
      case NoiseType.nightclub:
        return tool == NoiseTool.soundInsulation;
    }
  }

  void selectTool(NoiseTool t) {
    selectedTool = t;
    notifyListeners();
    if (toolSelectorOpen) applyTool();
  }

  void cancelToolSelector() {
    toolSelectorOpen = false;
    pendingFixTarget = null;
    overlays.remove('toolSelect');
    notifyListeners();
  }

  // ── Input ─────────────────────────────────────────────────────────────────
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

  // ── Reaction FX ──────────────────────────────────────────────────────────
  void _triggerReaction(ReactionKind kind, {int combo = 0}) {
    reactionKind = kind;
    reactionCombo = combo;
    reactionActive = true;
    reactionCorrect =
        kind == ReactionKind.scanLocked ||
        kind == ReactionKind.scanPartial ||
        kind == ReactionKind.fixCorrect ||
        kind == ReactionKind.windEvade;
    reactionPhase = 1;
    reactionInRange = kind != ReactionKind.scanMiss;
    reactionTimer =
        kind == ReactionKind.windEvade || kind == ReactionKind.scanPartial || kind == ReactionKind.windSlow
        ? 0.7
        : 1.2;
    overlays.add('reactionFx');
  }

  // ── NEW: End level with completion states (like LandDegradation) ──────────
  void _endLevel() {
    if (levelDone) return;
    levelDone = true;
    pauseEngine();

    final meetsMin = fixedCount >= kMinSolutionsRequired;
    final allFixed = hotspots.every((h) => h.isFixed);

    final LevelCompletionState completionState;
    if (allFixed) {
      completionState = LevelCompletionState.fullCompletion;
    } else if (meetsMin) {
      completionState = LevelCompletionState.moderate;
    } else {
      completionState = LevelCompletionState.failed;
    }

    String endReason = '';
    if (timeLeft <= 0) {
      if (allFixed) {
        endReason = '🌍 All hotspots fixed — and just in time!';
      } else if (meetsMin) {
        endReason = '⏰ Time expired — minimum $kMinSolutionsRequired fixes met. Well done!';
      } else {
        endReason = '⏰ Time ran out before fixing $kMinSolutionsRequired hotspots. Keep practising!';
      }
    } else if (allFixed) {
      endReason = '🌍 All ${hotspots.length} noise hotspots fully resolved! Outstanding work!';
    } else {
      endReason = meetsMin
          ? '✅ Minimum $kMinSolutionsRequired fixes achieved — level complete!'
          : 'Level ended with $fixedCount/$kMinSolutionsRequired hotspots fixed.';
    }

    NoiseResult.current = NoiseResult(
      hotspotsFix: fixedCount,
      wrongTools: wrongTools,
      ecoPoints: ecoPoints,
      noiseMeterFinal: noiseMeter,
      peacefulCityBadge: noiseMeter < _targetNoise,
      windEvades: windEvades,
      scanComboMax: scanComboMax,
      meetsMinimum: meetsMin,
      minimumRequired: kMinSolutionsRequired,
      scannedCount: scannedCount,
      maxCombo: scanComboMax,
      endReason: endReason,
      completionState: completionState,
    );

    overlays
      ..remove('reactionFx')
      ..remove('toolSelect')
      ..remove('scanResult')
      ..remove('liveMetrics')
      ..add('completionBanner');
    notifyListeners();
  }

  void finishEarly() => _endLevel();

  // ── Update ────────────────────────────────────────────────────────────────
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

    // Scan result auto-dismiss
    if (scanResultActive) {
      scanResultTimer -= dt;
      if (scanResultTimer <= 0) {
        dismissScanResult();
      }
    }

    // Scan radius animation
    if (scanActive) {
      scanRadius += dt * 230;
      if (scanRadius >= _scanMaxRadius) scanActive = false;
    }

    for (final ring in scanRings) {
      ring.radius += dt * 190;
      ring.alpha = math.max(0, ring.alpha - dt * 0.72);
    }
    scanRings.removeWhere((r) => r.alpha <= 0);

    if (!gameStarted || levelDone) return;

    // ── Wind system ──────────────────────────────────────────────────────
    _windSpawnTimer += dt;
    if (_windSpawnTimer >= _windSpawnCooldown) {
      _windSpawnTimer = 0;
      _spawnWindZone();
    }
    for (final z in windZones) {
      z.update(dt, worldW, worldH);
    }
    windZones.removeWhere((z) => !z.isActive);

    final dom = dominantWindZone;
    if (dom != null) {
      final i = dom.intensityAt(dronePos);
      dronePos.x = (dronePos.x + math.cos(dom.angle) * i * 12 * dt).clamp(
        30,
        worldW - 30,
      );
      dronePos.y = (dronePos.y + math.sin(dom.angle) * i * 10 * dt).clamp(
        40,
        worldH * 0.97,
      );
      droneWindTiltX +=
          (math.cos(dom.angle) * i * 18 - droneWindTiltX) * dt * 4;
      droneWindTiltY +=
          (math.sin(dom.angle) * i * 18 - droneWindTiltY) * dt * 4;
    } else {
      droneWindTiltX *= math.pow(0.85, dt * 60) as double;
      droneWindTiltY *= math.pow(0.85, dt * 60) as double;
    }

    final nowInWind = isInAnyWind;
    if (_wasInWind && !nowInWind && gameStarted) {
      windEvades++;
      ecoPoints += 3;
      _evadeShowTimer = 1.0;
      _triggerReaction(ReactionKind.windEvade);
    }
    _wasInWind = nowInWind;
    if (_evadeShowTimer > 0) _evadeShowTimer -= dt;

    // ── NEW: Scan lock progress (like LandDegradation) ───────────────────
    {
      // Always update nearest target for UI feedback
      NoiseHotspot? nearest;
      double nearestD = _scanRange;
      for (final h in hotspots) {
        if (h.isScanned || h.isFixed) continue;
        final d = (h.hotspotPos - dronePos).length;
        if (d < nearestD) {
          nearestD = d;
          nearest = h;
        }
      }
      _nearestScanTarget = nearest;

      // Progress the lock-scan timer when active
      if (scanLockActive && activeScanTarget != null) {
        // Cancel lock if drone moves out of range
        final lockDist = (activeScanTarget!.hotspotPos - dronePos).length;
        if (lockDist > _scanRange * 1.15) {
          scanLockActive = false;
          _scanLockTimer = 0;
          activeScanTarget = null;
          _triggerReaction(ReactionKind.scanMiss);
        } else {
          // Wind only slows, never blocks
          final rate = currentWindSlowFactor;
          _scanLockTimer += dt * rate;
          scanHoldTime = _scanLockTimer;
          if (_scanLockTimer >= _scanDuration) {
            final h = activeScanTarget!;
            _completeHotspotScan(h);
          }
        }
      } else if (!scanLockActive) {
        activeScanTarget = null;
        scanHoldTime = 0;
      }
    }

    if (_comboDecayTimer > 0) {
      _comboDecayTimer -= dt;
      if (_comboDecayTimer <= 0) scanCombo = 0;
    }

    // ── Drone movement (world space) ──────────────────────────────────────
    double vx = 0, vy = 0;
    if (isLeft) vx -= 1;
    if (isRight) vx += 1;
    if (isUp) vy -= 1;
    if (isDown) vy += 1;
    dronePos.x = (dronePos.x + vx * _droneSpeed * dt).clamp(30, worldW - 30);
    dronePos.y = (dronePos.y + vy * _droneSpeed * dt).clamp(40, worldH * 0.97);

    _updateCamera(dt);

    _refillTimer += dt;
    if (_refillTimer >= _refillInterval) {
      _refillTimer = 0;
      _tryRefillHotspots();
    }

    notifyListeners();
  }

  void _updateCamera(double dt) {
    final sw = size.x;
    final sh = size.y;
    final edgeW = sw * _World.kEdgeFraction;
    final edgeH = sh * _World.kEdgeFraction;

    final sx = dronePos.x - camX;
    final sy = dronePos.y - camY;

    double tx = _targetCamX;
    double ty = _targetCamY;

    if (sx < edgeW) {
      tx = dronePos.x - edgeW;
    } else if (sx > sw - edgeW) {
      tx = dronePos.x - (sw - edgeW);
    }

    if (sy < edgeH) {
      ty = dronePos.y - edgeH;
    } else if (sy > sh - edgeH) {
      ty = dronePos.y - (sh - edgeH);
    }

    _targetCamX = tx.clamp(0.0, worldW - sw);
    _targetCamY = ty.clamp(0.0, worldH - sh);

    camX += (_targetCamX - camX) * _World.kCameraEase * dt;
    camY += (_targetCamY - camY) * _World.kCameraEase * dt;

    edgeHintLeft = (sx < edgeW * 1.5 && camX > 1)
        ? (1.0 - sx / (edgeW * 1.5)).clamp(0, 1)
        : 0;
    edgeHintRight = (sx > sw - edgeW * 1.5 && camX < worldW - sw - 1)
        ? ((sx - (sw - edgeW * 1.5)) / (edgeW * 1.5)).clamp(0, 1)
        : 0;
    edgeHintTop = (sy < edgeH * 1.5 && camY > 1)
        ? (1.0 - sy / (edgeH * 1.5)).clamp(0, 1)
        : 0;
    edgeHintBottom = (sy > sh - edgeH * 1.5 && camY < worldH - sh - 1)
        ? ((sy - (sh - edgeH * 1.5)) / (edgeH * 1.5)).clamp(0, 1)
        : 0;
  }

  double get scanHoldProgress =>
      scanLockActive ? (_scanLockTimer / _scanDuration).clamp(0.0, 1.0) : 0.0;
}

// ════════════════════════════════════════════════════════════════════════════
//  NOISE CITY RENDERER
// ════════════════════════════════════════════════════════════════════════════
class NoiseCityRenderer extends Component {
  final NoisePollutionGame game;
  double _t = 0;
  NoiseCityRenderer({required this.game});

  @override
  void update(double dt) => _t += dt * 0.3;

  @override
  void render(Canvas canvas) {
    final w = game.worldW;
    final h = game.worldH;
    final sw = game.size.x;
    final sh = game.size.y;

    canvas.save();
    canvas.translate(-game.camX, -game.camY);

    final noiseRatio = (game.noiseMeter / 96.0).clamp(0.0, 1.0);
    final skyColor = Color.lerp(
      const Color(0xFF0A1E14),
      const Color(0xFF180A08),
      noiseRatio,
    )!;

    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(0, h),
          [
            Color.lerp(const Color(0xFF080E18), skyColor, 0.7)!,
            skyColor,
            const Color(0xFF050810),
          ],
          [0.0, 0.5, 1.0],
        ),
    );

    if (noiseRatio > 0.2) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, w, h),
        Paint()
          ..color = const Color(0xFFEF5350).withValues(alpha: noiseRatio * 0.06)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 45),
      );
    }

    _drawRoads(canvas, w, h);
    _drawBuildings(canvas, w, h, noiseRatio);
    _drawStreetDetails(canvas, w, h);

    canvas.drawRect(
      Rect.fromLTWH(0, h * 0.96, w, h * 0.04),
      Paint()..color = const Color(0xFF050810),
    );

    canvas.restore();

    _drawEdgeHints(canvas, sw, sh);
  }

  void _drawEdgeHints(Canvas canvas, double sw, double sh) {
    const hintColor = Color(0xFF29B6F6);
    void drawVignette(double alpha, Alignment from, Alignment to) {
      if (alpha < 0.01) return;
      canvas.drawRect(
        Rect.fromLTWH(0, 0, sw, sh),
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(sw * (from.x + 1) / 2, sh * (from.y + 1) / 2),
            Offset(sw * (to.x + 1) / 2, sh * (to.y + 1) / 2),
            [hintColor.withValues(alpha: alpha * 0.22), Colors.transparent],
            [0.0, 1.0],
          )
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1),
      );
    }

    drawVignette(game.edgeHintLeft, Alignment.centerLeft, Alignment.center);
    drawVignette(game.edgeHintRight, Alignment.centerRight, Alignment.center);
    drawVignette(game.edgeHintTop, Alignment.topCenter, Alignment.center);
    drawVignette(game.edgeHintBottom, Alignment.bottomCenter, Alignment.center);

    final paint = Paint()
      ..color = hintColor.withValues(alpha: 0.70)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    if (game.edgeHintLeft > 0.15) {
      _drawChevron(
        canvas,
        const Offset(18, 0),
        -math.pi / 2 * 2,
        paint,
        game.edgeHintLeft,
      );
    }
    if (game.edgeHintRight > 0.15) {
      _drawChevron(canvas, Offset(sw - 18, 0), 0, paint, game.edgeHintRight);
    }
    if (game.edgeHintTop > 0.15) {
      _drawChevron(
        canvas,
        const Offset(0, 18),
        -math.pi / 2,
        paint,
        game.edgeHintTop,
      );
    }
    if (game.edgeHintBottom > 0.15) {
      _drawChevron(
        canvas,
        Offset(0, sh - 18),
        math.pi / 2,
        paint,
        game.edgeHintBottom,
      );
    }
  }

  void _drawChevron(
    Canvas canvas,
    Offset anchor,
    double angle,
    Paint paint,
    double alpha,
  ) {
    canvas.save();
    canvas.translate(
      anchor.dx == 0 ? game.size.x / 2 : anchor.dx,
      anchor.dy == 0 ? game.size.y / 2 : anchor.dy,
    );
    canvas.rotate(angle);
    final p = Path()
      ..moveTo(-10, -6)
      ..lineTo(0, 6)
      ..lineTo(10, -6);
    canvas.drawPath(
      p,
      paint..color = const Color(0xFF29B6F6).withValues(alpha: alpha * 0.85),
    );
    canvas.restore();
  }

  void _drawRoads(Canvas canvas, double w, double h) {
    final roadPaint = Paint()..color = const Color(0xFF0D1420);
    final dashPaint = Paint()
      ..color = const Color(0xFF1E3040).withValues(alpha: 0.7)
      ..strokeWidth = 1.5;

    for (final ry in [0.12, 0.24, 0.36, 0.48, 0.60, 0.72, 0.84]) {
      canvas.drawRect(Rect.fromLTWH(0, h * ry - 16, w, 32), roadPaint);
      double x = 0;
      while (x < w) {
        canvas.drawLine(Offset(x, h * ry), Offset(x + 18, h * ry), dashPaint);
        x += 36;
      }
      canvas.drawLine(
        Offset(0, h * ry - 16),
        Offset(w, h * ry - 16),
        Paint()
          ..color = const Color(0xFF1A2E40).withValues(alpha: 0.5)
          ..strokeWidth = 1.0,
      );
    }
    for (final rx in [0.12, 0.25, 0.38, 0.50, 0.62, 0.75, 0.88]) {
      canvas.drawRect(Rect.fromLTWH(w * rx - 16, 0, 32, h * 0.96), roadPaint);
      double y = 0;
      while (y < h * 0.96) {
        canvas.drawLine(Offset(w * rx, y), Offset(w * rx, y + 18), dashPaint);
        y += 36;
      }
    }
  }

  void _drawBuildings(Canvas canvas, double w, double h, double noiseRatio) {
    final rng = math.Random(66);
    const cols = 8;
    const rows = 8;
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final bx = w * (c / cols) + 4;
        final by = h * (r / rows) + 4;
        final bw = w / cols * 0.85 - 8;
        final bh = h / rows * 0.85 - 8;
        if (bw < 20 || bh < 20) continue;

        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(bx, by, bw, bh),
            const Radius.circular(4),
          ),
          Paint()..color = const Color(0xFF0A0F1A),
        );

        if (noiseRatio > 0.3) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(bx, by, bw, bh),
              const Radius.circular(4),
            ),
            Paint()
              ..color = const Color(
                0xFFFF5722,
              ).withValues(alpha: noiseRatio * 0.04)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
          );
        }

        _drawWindows(canvas, bx, by, bw, bh, rng, noiseRatio);
      }
    }
  }

  void _drawWindows(
    Canvas canvas,
    double bx,
    double by,
    double bw,
    double bh,
    math.Random rng,
    double noise,
  ) {
    final cols = (bw / 13).floor().clamp(2, 8);
    final rows = (bh / 18).floor().clamp(2, 10);
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (rng.nextDouble() > 0.55) {
          final wx = bx + 5 + c * (bw - 10) / cols.clamp(1, 8);
          final wy = by + 7 + r * (bh - 10) / rows.clamp(1, 10);
          final brightness = 0.04 + rng.nextDouble() * 0.10;
          final windowColor = Color.lerp(
            const Color(0xFF29B6F6),
            const Color(0xFFFF6D00),
            noise,
          )!.withValues(alpha: brightness);
          canvas.drawRect(
            Rect.fromLTWH(wx, wy, 5, 6),
            Paint()..color = windowColor,
          );
        }
      }
    }
  }

  void _drawStreetDetails(Canvas canvas, double w, double h) {
    final rng = math.Random(42);
    for (int i = 0; i < 24; i++) {
      final rx = rng.nextDouble() * w;
      final roadYs = [0.12, 0.24, 0.36, 0.48, 0.60, 0.72, 0.84];
      final roadY = h * roadYs[i % roadYs.length];
      canvas.drawRect(
        Rect.fromLTWH(rx, roadY - 5, 8, 4),
        Paint()..color = const Color(0xFFEF5350).withValues(alpha: 0.25),
      );
    }
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  WIND ZONE RENDERER
// ════════════════════════════════════════════════════════════════════════════
class WindZoneRenderer extends Component {
  final NoisePollutionGame game;
  double _t = 0;
  WindZoneRenderer({required this.game});

  @override
  void update(double dt) => _t += dt;

  @override
  void render(Canvas canvas) {
    canvas.save();
    canvas.translate(-game.camX, -game.camY);
    for (final zone in game.windZones) {
      if (!zone.isActive) continue;
      _drawZone(canvas, zone);
    }
    canvas.restore();
  }

  void _drawZone(Canvas canvas, WindZone zone) {
    final cx = zone.cx;
    final cy = zone.cy;
    final r = zone.radius;
    final col = zone.color;
    final sf = zone.strengthFactor * zone.fadeAlpha;
    final t = _t + zone.angle;

    canvas.drawCircle(
      Offset(cx, cy),
      r,
      Paint()
        ..color = col.withValues(alpha: sf * 0.07)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22),
    );

    canvas.save();
    canvas.clipPath(
      Path()
        ..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r * 0.95)),
    );

    final windDx = math.cos(zone.angle);
    final windDy = math.sin(zone.angle);
    final perpDx = -windDy;
    final perpDy = windDx;

    const streamCount = 9;
    for (int i = 0; i < streamCount; i++) {
      final perpOff = ((i / (streamCount - 1)) - 0.5) * 2.0 * r;
      final animPhase = (t * 0.65 + i * 0.111) % 1.0;
      final startAlong = -1.0 + animPhase * 2.0;
      final path = Path();
      const pts = 28;
      bool firstPt = true;
      for (int p = 0; p <= pts; p++) {
        final pct = p / pts;
        final along = startAlong + pct * 2.2;
        final wave =
            math.sin(pct * math.pi * 3.5 + t * 5.5 + i * 0.75) *
            r *
            (0.07 + zone.strengthFactor * 0.06);
        final px = cx + along * r * windDx + perpOff * perpDx + wave * perpDx;
        final py = cy + along * r * windDy + perpOff * perpDy + wave * perpDy;
        if (firstPt) {
          path.moveTo(px, py);
          firstPt = false;
        } else {
          path.lineTo(px, py);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = col.withValues(
            alpha: sf * (0.20 + (i % 3 == 0 ? 0.10 : 0.0)),
          )
          ..strokeWidth = 1.3 + (i % 2) * 0.5
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke,
      );
    }
    canvas.restore();
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  NOISE HOTSPOT COMPONENT
// ════════════════════════════════════════════════════════════════════════════
class NoiseHotspot extends Component {
  final NoisePollutionGame game;
  final NoiseType type;
  double hx, hy;
  final int seed;
  bool isScanned = false;
  bool isFixed = false;
  double _t = 0;

  double _driftDir = 0;
  final bool _drifts;

  NoiseHotspot({
    required this.game,
    required this.type,
    required double worldX,
    required double worldY,
    required this.seed,
  }) : hx = worldX,
       hy = worldY,
       _drifts = type == NoiseType.traffic || type == NoiseType.aircraft {
    final rng = math.Random(seed);
    _driftDir = rng.nextDouble() * math.pi * 2;
  }

  Vector2 get hotspotPos => Vector2(hx, hy);

  void reveal() => isScanned = true;
  void fix() {
    isFixed = true;
    isScanned = true;
  }

  static const _specs = {
    NoiseType.traffic: ('🚗', 'Vehicle Honking', Color(0xFFEF5350), '85 dB'),
    NoiseType.construction: (
      '🏗️',
      'Construction Site',
      Color(0xFFFF6D00),
      '90 dB',
    ),
    NoiseType.loudspeaker: ('📢', 'Loud Speaker', Color(0xFFCE93D8), '78 dB'),
    NoiseType.vegetation: (
      '🌿',
      'Sparse Vegetation',
      Color(0xFF78909C),
      '72 dB',
    ),
    NoiseType.industrial: ('🏭', 'Industrial Plant', Color(0xFF8D6E63), '95 dB'),
    NoiseType.aircraft: ('✈️', 'Aircraft Overflight', Color(0xFF5C6BC0), '88 dB'),
    NoiseType.railway: ('🚆', 'Railway Noise', Color(0xFF26A69A), '82 dB'),
    NoiseType.nightclub: ('🎵', 'Nightclub District', Color(0xFFAB47BC), '92 dB'),
  };

  @override
  void update(double dt) {
    _t += dt;
    if (_drifts && !isFixed) {
      hx = (hx + math.cos(_driftDir) * 12.0 * dt).clamp(30, game.worldW - 30);
      hy = (hy + math.sin(_driftDir) * 12.0 * 0.3 * dt).clamp(
        40,
        game.worldH * 0.94,
      );
      if (hx <= 32 || hx >= game.worldW - 32) _driftDir = math.pi - _driftDir;
    }
  }

  @override
  void render(Canvas canvas) {
    final sx = hx - game.camX;
    final sy = hy - game.camY;
    if (sx < -160 ||
        sx > game.size.x + 160 ||
        sy < -160 ||
        sy > game.size.y + 160) {
      return;
    }

    if (isFixed) {
      _drawFixed(canvas, sx, sy);
      return;
    }
    final spec = _specs[type]!;
    final color = spec.$3;

    if (isScanned) {
      _drawScanned(canvas, sx, sy, spec, color);
    } else {
      _drawUnscanned(canvas, sx, sy, spec, color);
    }
  }

  void _drawUnscanned(
    Canvas canvas,
    double sx,
    double sy,
    dynamic spec,
    Color color,
  ) {
    // NEW: Simple pulsing rings (like land degradation) instead of frequency-based
    final pulse = 0.60 + math.sin(_t * 2.8) * 0.25;

    for (int wave = 0; wave < 3; wave++) {
      final waveT = ((_t * 0.8 + wave / 3.0) % 1.0);
      final waveR = 18.0 + waveT * NoisePollutionGame._scanRange * 0.9;
      final waveAlpha = (1.0 - waveT) * 0.35;
      final droneD = (game.dronePos - hotspotPos).length;
      final visible = droneD < NoisePollutionGame._scanRange * 1.6;

      if (visible && waveAlpha > 0.02) {
        canvas.drawCircle(
          Offset(sx, sy),
          waveR,
          Paint()
            ..color = color.withValues(
              alpha:
                  waveAlpha *
                  (1 - droneD / (NoisePollutionGame._scanRange * 2))
                      .clamp(0, 1),
            )
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4,
        );
      }
    }

    canvas.drawCircle(
      Offset(sx, sy),
      26 * pulse,
      Paint()
        ..color = const Color(0xFF90A4AE).withValues(alpha: 0.07)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
    );
    canvas.drawCircle(
      Offset(sx, sy),
      20,
      Paint()..color = color.withValues(alpha: 0.12),
    );
    canvas.drawCircle(
      Offset(sx, sy),
      20,
      Paint()
        ..color = color.withValues(alpha: 0.50)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8,
    );

    // NEW: Scan progress arc when actively scanning this hotspot
    if (game.activeScanTarget == this && game.scanLockActive) {
      final prog = game.scanHoldProgress;
      canvas.drawArc(
        Rect.fromCircle(center: Offset(sx, sy), radius: 26),
        -math.pi / 2,
        math.pi * 2 * prog,
        false,
        Paint()
          ..color = color.withValues(alpha: 0.85)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0
          ..strokeCap = StrokeCap.round,
      );
      // Percentage label
      final pct = (prog * 100).toInt();
      final tp = TextPainter(
        text: TextSpan(
          text: '$pct%',
          style: TextStyle(
            color: color,
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(sx - tp.width / 2, sy - 62));
    }

    final droneD = (game.dronePos - hotspotPos).length;
    final inZone = droneD < NoisePollutionGame._scanRange;

    if (droneD < NoisePollutionGame._scanRange * 1.4 && game.activeScanTarget != this) {
      canvas.drawCircle(
        Offset(sx, sy),
        NoisePollutionGame._scanRange,
        Paint()
          ..color = color.withValues(alpha: inZone ? 0.18 : 0.07)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0
          ..maskFilter = inZone
              ? const MaskFilter.blur(BlurStyle.normal, 2)
              : null,
      );
    }

    if (_drifts) {
      final mp = TextPainter(
        text: const TextSpan(
          text: '›',
          style: TextStyle(
            color: Color(0xFFEF5350),
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      mp.paint(canvas, Offset(sx + 16, sy - mp.height / 2));
    }

    final iconText = inZone ? spec.$1 : '?';
    final iconStyle = TextStyle(
      color: inZone ? color : const Color(0xFF90A4AE),
      fontSize: 13,
      fontWeight: FontWeight.bold,
    );
    final qp = TextPainter(
      text: TextSpan(text: iconText, style: iconStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    qp.paint(canvas, Offset(sx - qp.width / 2, sy - qp.height / 2));
  }

  void _drawScanned(
    Canvas canvas,
    double sx,
    double sy,
    dynamic spec,
    Color color,
  ) {
    final pulse = 0.65 + math.sin(_t * 2.8) * 0.22;

    canvas.drawCircle(
      Offset(sx, sy),
      36 * pulse,
      Paint()
        ..color = color.withValues(alpha: 0.07 + pulse * 0.05)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
    canvas.drawCircle(
      Offset(sx, sy),
      28,
      Paint()..color = color.withValues(alpha: 0.15),
    );
    canvas.drawCircle(
      Offset(sx, sy),
      28,
      Paint()
        ..color = color.withValues(alpha: 0.70)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2,
    );

    for (int w = 1; w <= 3; w++) {
      final wR = 30.0 + w * 12 + math.sin(_t * 3 + w) * 5;
      canvas.drawCircle(
        Offset(sx, sy),
        wR,
        Paint()
          ..color = color.withValues(alpha: 0.08 * (1 - w * 0.28) * pulse)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );
    }

    final ep = TextPainter(
      text: TextSpan(text: spec.$1, style: const TextStyle(fontSize: 14)),
      textDirection: TextDirection.ltr,
    )..layout();
    ep.paint(canvas, Offset(sx - ep.width / 2, sy - ep.height / 2 - 6));

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
    dp.paint(canvas, Offset(sx - dp.width / 2, sy + 14));

    final ap = TextPainter(
      text: TextSpan(
        text: '→ SELECT TOOL',
        style: TextStyle(
          color: color.withValues(alpha: 0.90),
          fontSize: 7,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.8,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    ap.paint(canvas, Offset(sx - ap.width / 2, sy + 26));
  }

  void _drawFixed(Canvas canvas, double sx, double sy) {
    canvas.drawCircle(
      Offset(sx, sy),
      24,
      Paint()
        ..color = const Color(0xFF69F0AE).withValues(alpha: 0.12)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawCircle(
      Offset(sx, sy),
      22,
      Paint()..color = const Color(0xFF69F0AE).withValues(alpha: 0.15),
    );
    canvas.drawCircle(
      Offset(sx, sy),
      22,
      Paint()
        ..color = const Color(0xFF69F0AE).withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );
    final tp = TextPainter(
      text: const TextSpan(text: '✅', style: TextStyle(fontSize: 14)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(sx - tp.width / 2, sy - tp.height / 2));
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  ECO-DRONE COMPONENT
// ════════════════════════════════════════════════════════════════════════════
class EcoDroneComponent extends Component {
  final NoisePollutionGame game;
  double _t = 0;
  EcoDroneComponent({required this.game});

  @override
  void update(double dt) => _t += dt;

  @override
  void render(Canvas canvas) {
    final screen = game.droneScreen;
    final baseCx = screen.x;
    final baseCy = screen.y + math.sin(_t * 3.2) * 2.5;
    final cx = baseCx + game.droneWindTiltX * 0.35;
    final cy = baseCy + game.droneWindTiltY * 0.35;

    // Scan pulse ring
    if (game.scanActive) {
      final alpha = (1.0 - game.scanRadius / NoisePollutionGame._scanMaxRadius) * 0.32;
      canvas.drawCircle(Offset(cx, cy), game.scanRadius,
          Paint()
            ..color = const Color(0xFF29B6F6).withValues(alpha: alpha)
            ..style = PaintingStyle.stroke..strokeWidth = 2.8);
    }

    for (final ring in game.scanRings) {
      if (ring.disrupted) {
        _drawDisruptedRing(canvas, cx, cy, ring);
      } else {
        canvas.drawCircle(
          Offset(cx, cy),
          ring.radius,
          Paint()
            ..color = const Color(
              0xFF29B6F6,
            ).withValues(alpha: ring.alpha * 0.55)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0,
        );
      }
    }

    final target = game._nearestSonarTarget;
    if (target != null && !game.toolSelectorOpen) {
      final dist = (target.hotspotPos - game.dronePos).length;
      final inZone = dist < NoisePollutionGame._scanRange;
      final rangeColor = inZone
          ? const Color(0xFF29B6F6)
          : const Color(0xFF78909C);

      if (!inZone) {
        final worldDir = (target.hotspotPos - game.dronePos).normalized();
        final arrowX = cx + worldDir.x * 55;
        final arrowY = cy + worldDir.y * 55;
        canvas.drawCircle(
          Offset(arrowX, arrowY),
          4,
          Paint()
            ..color = rangeColor.withValues(
              alpha: 0.50 + math.sin(_t * 4) * 0.25,
            )
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
        );
      }
    }

    // Range indicator
    final rangeColor = const Color(0xFF29B6F6);
    canvas.drawCircle(Offset(cx, cy), NoisePollutionGame._scanRange,
        Paint()
          ..color = rangeColor.withValues(alpha: 0.065)
          ..style = PaintingStyle.stroke..strokeWidth = 1.2);

    // Dashed hover-range
    final dashPaint = Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.09)
      ..style = PaintingStyle.stroke..strokeWidth = 1.0..strokeCap = StrokeCap.round;
    const double r = 110.0; // hover range
    const int segments = 28;
    const double dashFrac = 0.55;
    for (int seg = 0; seg < segments; seg++) {
      final startAngle = (seg / segments) * math.pi * 2 + _t * 0.65;
      final sweep = (math.pi * 2 / segments) * dashFrac;
      canvas.drawArc(
        Rect.fromCenter(center: Offset(cx, cy), width: r * 2, height: r * 2),
        startAngle, sweep, false, dashPaint,
      );
    }

    // Scan progress glow when locking
    if (game.scanLockActive && game.activeScanTarget != null) {
      final prog = game.scanHoldProgress;
      final glow = 0.6 + prog * 0.35;
      canvas.drawCircle(Offset(cx, cy), 12 + prog * 8,
          Paint()
            ..color = const Color(0xFF29B6F6).withValues(alpha: glow * prog * 0.3)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    }

    // Wind deflection arrow
    final dom = game.dominantWindZone;
    if (dom != null) {
      final wf = Vector2(math.cos(dom.angle) * dom.strengthFactor, 
                        math.sin(dom.angle) * dom.strengthFactor);
      final ang = math.atan2(wf.y, wf.x);
      final arrowLen = math.min(wf.length * 50, 30.0);
      final ex = cx + math.cos(ang) * arrowLen;
      final ey = cy + math.sin(ang) * arrowLen;
      canvas.drawLine(Offset(cx, cy), Offset(ex, ey),
          Paint()..color = dom.color.withValues(alpha: 0.70)
            ..strokeWidth = 2.0..strokeCap = StrokeCap.round);
    }

    canvas.save();
    final tiltAngle = game.droneWindTiltX * 0.018;
    canvas.translate(cx, cy);
    canvas.rotate(tiltAngle);

    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, 14), width: 38, height: 9),
      Paint()..color = Colors.black.withValues(alpha: 0.28),
    );

    final armPaint = Paint()
      ..color = const Color(0xFF1C3A5C)
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;
    for (final (dx, dy) in [(-1, -1), (1, -1), (-1, 1), (1, 1)]) {
      canvas.drawLine(
        Offset(dx * 8.0, dy * 8.0),
        Offset(dx * 22.0, dy * 22.0),
        armPaint,
      );
    }

    final propSpeed = 1.0 + (game.dominantWindZone?.strengthFactor ?? 0) * 2.5;
    final propPaint = Paint()
      ..color = const Color(
        0xFF90CAF9,
      ).withValues(alpha: 0.45 + math.sin(_t * 18 * propSpeed) * 0.10)
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    for (final (px, py) in [
      (-22.0, -22.0),
      (22.0, -22.0),
      (-22.0, 22.0),
      (22.0, 22.0),
    ]) {
      final a = _t * 18 * propSpeed;
      canvas.drawLine(
        Offset(px - math.cos(a) * 8, py - math.sin(a) * 8),
        Offset(px + math.cos(a) * 8, py + math.sin(a) * 8),
        propPaint,
      );
      canvas.drawLine(
        Offset(px - math.sin(a) * 8, py + math.cos(a) * 8),
        Offset(px + math.sin(a) * 8, py - math.cos(a) * 8),
        propPaint,
      );
    }

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-13, -10, 26, 20),
        const Radius.circular(6),
      ),
      Paint()..color = const Color(0xFF1E3A5F),
    );

    // Scan lock progress arc on drone
    if (game.scanLockActive) {
      final prog = game.scanHoldProgress;
      const arcR = 18.0;
      canvas.drawArc(
        Rect.fromCenter(center: Offset.zero, width: arcR * 2, height: arcR * 2),
        -math.pi / 2,
        math.pi * 2,
        false,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.08)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0,
      );
      canvas.drawArc(
        Rect.fromCenter(center: Offset.zero, width: arcR * 2, height: arcR * 2),
        -math.pi / 2,
        math.pi * 2 * prog,
        false,
        Paint()
          ..color = const Color(0xFF29B6F6).withValues(alpha: 0.80)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0
          ..strokeCap = StrokeCap.round,
      );
    }

    final glowColor = game.isInAnyWind
        ? (game.currentWindSlowFactor < 0.5 ? const Color(0xFFEF5350) : const Color(0xFFFFB300))
        : game.toolSelectorOpen
        ? const Color(0xFF69F0AE)
        : game.scanLockActive
        ? const Color(0xFF29B6F6)
        : const Color(0xFF546E7A);
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

    final tp = TextPainter(
      text: TextSpan(
        text: game.toolSelectorOpen
            ? '🔧'
            : game.scanLockActive
            ? '🔒'
            : '📡',
        style: const TextStyle(fontSize: 8),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(-tp.width / 2, 13 - tp.height / 2));

    if (game.scanCombo >= 2) _drawComboBadge(canvas, game.scanCombo);

    canvas.restore();
  }

  void _drawComboBadge(Canvas canvas, int combo) {
    const bx = 16.0;
    const by = -22.0;
    final color = combo >= 5
        ? const Color(0xFFFF6D00)
        : const Color(0xFF69F0AE);
    canvas.drawCircle(
      const Offset(bx, by),
      8.5,
      Paint()..color = const Color(0xFF0A1428).withValues(alpha: 0.90),
    );
    canvas.drawCircle(
      const Offset(bx, by),
      8.5,
      Paint()
        ..color = color.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    final tp = TextPainter(
      text: TextSpan(
        text: '×$combo',
        style: TextStyle(
          color: color,
          fontSize: 7,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(bx - tp.width / 2, by - tp.height / 2));
  }

  void _drawDisruptedRing(Canvas canvas, double cx, double cy, ScanRing ring) {
    const segments = 8;
    final paint = Paint()
      ..color = const Color(0xFFEF5350).withValues(alpha: ring.alpha * 0.60)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < segments; i++) {
      if (i % 2 == 0) continue;
      final a0 = (i / segments) * math.pi * 2;
      final a1 = a0 + math.pi * 2 / segments * 0.7;
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: ring.radius),
        a0,
        a1 - a0,
        false,
        paint,
      );
    }
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  HUD
// ════════════════════════════════════════════════════════════════════════════
class NoiseHud extends StatelessWidget {
  final NoisePollutionGame game;
  const NoiseHud(this.game, {super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: game,
      builder: (_, __) {
        final noiseRatio = (game.noiseMeter / 96.0).clamp(0.0, 1.0);
        final noiseColor = Color.lerp(
          const Color(0xFF69F0AE),
          const Color(0xFFEF5350),
          noiseRatio,
        )!;
        final warn = game.timeLeft < 30;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF29B6F6).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF29B6F6).withValues(alpha: 0.40),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF29B6F6).withValues(alpha: 0.25),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: const Text(
                    '📡  NOISE INVESTIGATION — Scan & Fix Hotspots',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 10,
                      letterSpacing: 0.9,
                    ),
                  ),
                ),
                const SizedBox(height: 7),

                Row(
                  children: [
                    _HTile(
                      Icons.timer_rounded,
                      '${game.timeLeft.toInt()}s',
                      'TIME',
                      warn ? Colors.redAccent : Colors.white,
                    ),
                    const SizedBox(width: 5),
                    _HTile(
                      Icons.radar_rounded,
                      '${game.scannedCount}',
                      'SCANNED',
                      const Color(0xFF29B6F6),
                    ),
                    const SizedBox(width: 5),
                    _HTile(
                      Icons.check_circle_outline_rounded,
                      '${game.fixedCount}/${NoisePollutionGame.kMinSolutionsRequired}',
                      'FIXED MIN',
                      game.fixedCount >= NoisePollutionGame.kMinSolutionsRequired
                          ? const Color(0xFF69F0AE)
                          : const Color(0xFFFFB300),
                    ),
                    const SizedBox(width: 5),
                    _HTile(
                      Icons.eco_rounded,
                      '${game.ecoPoints}',
                      'ECO-PTS',
                      Colors.limeAccent,
                    ),
                    const SizedBox(width: 5),
                    _HTile(
                      Icons.volume_down_rounded,
                      '${game.noiseMeter.toStringAsFixed(0)} dB',
                      'NOISE',
                      noiseColor,
                    ),
                  ],
                ),
                const SizedBox(height: 5),

                // NEW: Scan progress bar (like land degradation)
                if (game.scanLockActive) ...[
                  Row(children: [
                    const Text('🔒', style: TextStyle(fontSize: 12)),
                    const SizedBox(width: 5),
                    Expanded(child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: game.scanHoldProgress,
                        backgroundColor: Colors.white12,
                        valueColor: const AlwaysStoppedAnimation(Color(0xFF29B6F6)),
                        minHeight: 7,
                      ),
                    )),
                    const SizedBox(width: 6),
                    Text(
                      game.currentWindSlowFactor < 1.0 ? '💨 Slowed' : 'Locking…',
                      style: TextStyle(
                        color: game.currentWindSlowFactor < 1.0
                            ? const Color(0xFFFFB300)
                            : const Color(0xFF29B6F6),
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ]),
                  const SizedBox(height: 4),
                ],

                // Nudge when hotspot nearby but not scanning
                if (!game.scanLockActive &&
                    game._nearestScanTarget != null &&
                    !game.toolSelectorOpen &&
                    !game.scanResultActive) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    margin: const EdgeInsets.only(bottom: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF29B6F6).withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF29B6F6).withValues(alpha: 0.35)),
                    ),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Text('📡', style: TextStyle(fontSize: 10)),
                      SizedBox(width: 5),
                      Text('Noise source nearby — tap SCAN!',
                          style: TextStyle(color: Color(0xFF29B6F6),
                              fontSize: 9, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ],

                Row(
                  children: [
                    const Text('🔊', style: TextStyle(fontSize: 13)),
                    const SizedBox(width: 5),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: LinearProgressIndicator(
                          value: 1.0 - noiseRatio,
                          backgroundColor: Colors.white12,
                          valueColor: AlwaysStoppedAnimation(noiseColor),
                          minHeight: 7,
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${game.noiseMeter.toStringAsFixed(0)} dB',
                      style: TextStyle(
                        color: noiseColor,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      ' / 40 target',
                      style: TextStyle(color: Color(0xFF69F0AE), fontSize: 8),
                    ),
                  ],
                ),

                const SizedBox(height: 5),
                Row(
                  children: [
                    _WindStatusPill(game: game),
                    const SizedBox(width: 7),
                    if (game.scanCombo >= 2) _ComboBadge(combo: game.scanCombo),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _WindStatusPill extends StatelessWidget {
  final NoisePollutionGame game;
  const _WindStatusPill({required this.game});

  @override
  Widget build(BuildContext context) {
    final inAny = game.isInAnyWind;
    final slowFactor = game.currentWindSlowFactor;
    final Color color;
    final String label;
    if (!inAny) {
      color = const Color(0xFF69F0AE);
      label = '🌬️ CLEAR';
    } else if (slowFactor >= 0.8) {
      color = const Color(0xFF80DEEA);
      label = '💨 LIGHT';
    } else if (slowFactor >= 0.5) {
      color = const Color(0xFFFFB300);
      label = '💨 MODERATE';
    } else {
      color = const Color(0xFFEF5350);
      label = '🌪️ HEAVY';
    }

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.50)),
          boxShadow: inAny && slowFactor < 0.5
              ? [BoxShadow(color: color.withValues(alpha: 0.25), blurRadius: 8)]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 9,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.6,
          ),
        ),
      ),
    );
  }
}

class _ComboBadge extends StatelessWidget {
  final int combo;
  const _ComboBadge({required this.combo});
  @override
  Widget build(BuildContext context) {
    final color = combo >= 5
        ? const Color(0xFFFF6D00)
        : const Color(0xFF69F0AE);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.50)),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.22), blurRadius: 8),
        ],
      ),
      child: Text(
        '🔥 ×$combo COMBO',
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _HTile extends StatelessWidget {
  final IconData icon;
  final String val, label;
  final Color color;
  const _HTile(this.icon, this.val, this.label, this.color);
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          Text(
            val,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 7,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    ),
  );
}

// ════════════════════════════════════════════════════════════════════════════
//  LIVE METRICS OVERLAY
// ════════════════════════════════════════════════════════════════════════════
class NoiseLiveMetrics extends StatelessWidget {
  final NoisePollutionGame game;
  const NoiseLiveMetrics(this.game, {super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: game,
      builder: (_, __) {
        final noiseRatio = (game.noiseMeter / 96.0).clamp(0.0, 1.0);
        final noiseColor = Color.lerp(
          const Color(0xFF69F0AE),
          const Color(0xFFEF5350),
          noiseRatio,
        )!;
        final totalHotspots = game.hotspots.length;
        final fixedFrac = totalHotspots > 0
            ? game.fixedCount / totalHotspots
            : 0.0;

        final camFracX = game.worldW > 0
            ? (game.camX / (game.worldW - game.size.x)).clamp(0.0, 1.0)
            : 0.0;
        final camFracY = game.worldH > 0
            ? (game.camY / (game.worldH - game.size.y)).clamp(0.0, 1.0)
            : 0.0;

        return Align(
          alignment: Alignment.centerRight,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(right: 8, top: 140),
              child: Container(
                width: 78,
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.80),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.10),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.50),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'LIVE',
                      style: const TextStyle(
                        color: Color(0xFF29B6F6),
                        fontSize: 7,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.0,
                      ),
                    ),
                    const SizedBox(height: 8),

                    _MetricArc(
                      value: 1.0 - noiseRatio,
                      color: noiseColor,
                      label: '${game.noiseMeter.toStringAsFixed(0)}dB',
                      sublabel: 'NOISE',
                    ),
                    const SizedBox(height: 8),

                    _MiniBar(
                      value: fixedFrac,
                      color: const Color(0xFF69F0AE),
                      label: '${game.fixedCount} FIXED',
                    ),
                    const SizedBox(height: 6),

                    _MetricPill(
                      icon: '⭐',
                      value: '${game.ecoPoints}',
                      label: 'ECO-PTS',
                      color: Colors.amber,
                    ),
                    const SizedBox(height: 6),

                    _MetricPill(
                      icon: '❌',
                      value: '${game.wrongTools}',
                      label: 'ERRORS',
                      color: const Color(0xFFEF5350),
                    ),
                    const SizedBox(height: 6),

                    _MetricPill(
                      icon: '💨',
                      value: '${game.windEvades}',
                      label: 'EVADES',
                      color: const Color(0xFF80DEEA),
                    ),
                    const SizedBox(height: 8),

                    _MiniWorldMap(
                      camFracX: camFracX,
                      camFracY: camFracY,
                      hotspots: game.hotspots,
                      worldW: game.worldW,
                      worldH: game.worldH,
                      viewportFracW: game.worldW > 0
                          ? game.size.x / game.worldW
                          : 0,
                      viewportFracH: game.worldH > 0
                          ? game.size.y / game.worldH
                          : 0,
                    ),
                    const SizedBox(height: 8),

                    GestureDetector(
                      onTap: () => game.finishEarly(),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF69F0AE,
                          ).withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(
                              0xFF69F0AE,
                            ).withValues(alpha: 0.40),
                          ),
                        ),
                        child: const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('🏁', style: TextStyle(fontSize: 12)),
                            Text(
                              'FINISH',
                              style: TextStyle(
                                color: Color(0xFF69F0AE),
                                fontSize: 7,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
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

class _MetricArc extends StatelessWidget {
  final double value;
  final Color color;
  final String label, sublabel;
  const _MetricArc({
    required this.value,
    required this.color,
    required this.label,
    required this.sublabel,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 60,
    height: 60,
    child: CustomPaint(
      painter: _ArcPainter(value: value, color: color),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              sublabel,
              style: const TextStyle(color: Colors.white38, fontSize: 6),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ArcPainter extends CustomPainter {
  final double value;
  final Color color;
  const _ArcPainter({required this.value, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = (math.min(cx, cy) - 4).clamp(4.0, 30.0);
    canvas.drawCircle(
      Offset(cx, cy),
      r,
      Paint()
        ..color = Colors.white10
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      -math.pi / 2,
      math.pi * 2 * value,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_ArcPainter old) =>
      old.value != value || old.color != color;
}

class _MiniBar extends StatelessWidget {
  final double value;
  final Color color;
  final String label;
  const _MiniBar({
    required this.value,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 7,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
      const SizedBox(height: 3),
      ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: LinearProgressIndicator(
          value: value,
          backgroundColor: Colors.white10,
          valueColor: AlwaysStoppedAnimation(color),
          minHeight: 5,
        ),
      ),
    ],
  );
}

class _MetricPill extends StatelessWidget {
  final String icon, value, label;
  final Color color;
  const _MetricPill({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withValues(alpha: 0.20)),
    ),
    child: Row(
      children: [
        Text(icon, style: const TextStyle(fontSize: 10)),
        const SizedBox(width: 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 6,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _MiniWorldMap extends StatelessWidget {
  final double camFracX, camFracY;
  final List<NoiseHotspot> hotspots;
  final double worldW, worldH;
  final double viewportFracW, viewportFracH;
  const _MiniWorldMap({
    required this.camFracX,
    required this.camFracY,
    required this.hotspots,
    required this.worldW,
    required this.worldH,
    required this.viewportFracW,
    required this.viewportFracH,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: 64,
    height: 48,
    decoration: BoxDecoration(
      color: const Color(0xFF080E18),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: Colors.white12),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: CustomPaint(
        painter: _MapPainter(
          camFracX: camFracX,
          camFracY: camFracY,
          hotspots: hotspots,
          worldW: worldW,
          worldH: worldH,
          viewportFracW: viewportFracW,
          viewportFracH: viewportFracH,
        ),
      ),
    ),
  );
}

class _MapPainter extends CustomPainter {
  final double camFracX, camFracY;
  final List<NoiseHotspot> hotspots;
  final double worldW, worldH;
  final double viewportFracW, viewportFracH;
  const _MapPainter({
    required this.camFracX,
    required this.camFracY,
    required this.hotspots,
    required this.worldW,
    required this.worldH,
    required this.viewportFracW,
    required this.viewportFracH,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final vpW = size.width * viewportFracW;
    final vpH = size.height * viewportFracH;
    final vpX = camFracX * (size.width - vpW);
    final vpY = camFracY * (size.height - vpH);

    canvas.drawRect(
      Rect.fromLTWH(vpX, vpY, vpW, vpH),
      Paint()
        ..color = const Color(0xFF29B6F6).withValues(alpha: 0.18)
        ..style = PaintingStyle.fill,
    );
    canvas.drawRect(
      Rect.fromLTWH(vpX, vpY, vpW, vpH),
      Paint()
        ..color = const Color(0xFF29B6F6).withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );

    if (worldW > 0 && worldH > 0) {
      for (final h in hotspots) {
        final dx = (h.hx / worldW) * size.width;
        final dy = (h.hy / worldH) * size.height;
        final color = h.isFixed
            ? const Color(0xFF69F0AE)
            : h.isScanned
            ? const Color(0xFFFFB300)
            : const Color(0xFFEF5350).withValues(alpha: 0.55);
        canvas.drawCircle(
          Offset(dx, dy),
          h.isFixed ? 1.8 : 1.4,
          Paint()..color = color,
        );
      }
    }

    final tp = TextPainter(
      text: const TextSpan(
        text: 'MAP',
        style: TextStyle(color: Colors.white24, fontSize: 5, letterSpacing: 1),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(2, size.height - tp.height - 2));
  }

  @override
  bool shouldRepaint(_MapPainter old) => true;
}

// ════════════════════════════════════════════════════════════════════════════
//  NOISE CONTROLS
// ════════════════════════════════════════════════════════════════════════════
class NoiseControls extends StatefulWidget {
  final NoisePollutionGame game;
  const NoiseControls(this.game, {super.key});
  @override
  State<NoiseControls> createState() => _NoiseControlsState();
}

class _NoiseControlsState extends State<NoiseControls>
    with SingleTickerProviderStateMixin {
  bool _up = false, _dn = false, _lt = false, _rt = false;
  late FocusNode _fk;
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _fk = FocusNode();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _fk.requestFocus());
  }

  @override
  void dispose() {
    _fk.dispose();
    _pulseCtrl.dispose();
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

    if (k == LogicalKeyboardKey.space && pressed) widget.game.triggerScan();

    // Tool hotkeys
    if (pressed) {
      if (k == LogicalKeyboardKey.digit1) widget.game.selectTool(NoiseTool.electricMuffler);
      if (k == LogicalKeyboardKey.digit2) widget.game.selectTool(NoiseTool.silentMachinery);
      if (k == LogicalKeyboardKey.digit3) widget.game.selectTool(NoiseTool.silentZone);
      if (k == LogicalKeyboardKey.digit4) widget.game.selectTool(NoiseTool.treeBarrier);
      if (k == LogicalKeyboardKey.digit5) widget.game.selectTool(NoiseTool.noiseBarrier);
      if (k == LogicalKeyboardKey.digit6) widget.game.selectTool(NoiseTool.flightPath);
      if (k == LogicalKeyboardKey.digit7) widget.game.selectTool(NoiseTool.trackDampener);
      if (k == LogicalKeyboardKey.digit8) widget.game.selectTool(NoiseTool.soundInsulation);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.game,
      builder: (_, __) {
        final toolOpen = widget.game.toolSelectorOpen;
        final inWind = widget.game.isInAnyWind;
        final hasLock = widget.game.scanLockActive;
        final canScan = widget.game._nearestSonarTarget != null;

        final String btnLabel;
        final Color btnColor;
        final bool btnEnabled;
        final bool btnPulse;

        if (toolOpen) {
          btnLabel = '🔧SELECT TOOL';
          btnColor = const Color(0xFF69F0AE);
          btnEnabled = false;
          btnPulse = true;
        } else if (inWind && widget.game.currentWindSlowFactor < 0.8) {
          btnLabel = '💨 SLOWED';
          btnColor = const Color(0xFFFFB300);
          btnEnabled = true;
          btnPulse = true;
        } else if (hasLock) {
          btnLabel = '🔒 LOCKING…';
          btnColor = const Color(0xFF29B6F6);
          btnEnabled = true;
          btnPulse = true;
        } else if (canScan) {
          btnLabel = '📡 SCAN';
          btnColor = const Color(0xFF29B6F6).withValues(alpha: 0.75);
          btnEnabled = true;
          btnPulse = false;
        } else {
          btnLabel = '📡 SEEK';
          btnColor = const Color(0xFF546E7A);
          btnEnabled = false;
          btnPulse = false;
        }

        return KeyboardListener(
          focusNode: _fk,
          onKeyEvent: _onKey,
          child: Stack(
            children: [
              Align(
                alignment: Alignment.bottomLeft,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 18, left: 14),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _DPad(
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
                            _DPad(
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
                            _DPad(
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
                            _DPad(
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

              Align(
                alignment: Alignment.bottomRight,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 22, right: 14),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.game.windEvades > 0)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF69F0AE,
                                ).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(
                                    0xFF69F0AE,
                                  ).withValues(alpha: 0.35),
                                ),
                              ),
                              child: Text(
                                '💨 ×${widget.game.windEvades}',
                                style: const TextStyle(
                                  color: Color(0xFF69F0AE),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),

                        if (widget.game.scanLockActive)
                          Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.70),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFF29B6F6).withValues(alpha: 0.42)),
                            ),
                            child: Text(
                              widget.game.currentWindSlowFactor < 1.0
                                  ? '💨 Wind slowing scan!'
                                  : '🔒 Scanning — stay in range!',
                              style: const TextStyle(color: Color(0xFF29B6F6), fontSize: 9, fontWeight: FontWeight.bold),
                            ),
                          ),

                        if (widget.game.toolSelectorOpen)
                          Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF69F0AE).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFF69F0AE).withValues(alpha: 0.42)),
                            ),
                            child: const Text(
                              '🔧 Select noise solution!',
                              style: TextStyle(color: Color(0xFF69F0AE), fontSize: 9, fontWeight: FontWeight.bold),
                            ),
                          ),

                        AnimatedBuilder(
                          animation: _pulseCtrl,
                          builder: (_, __) {
                            final pulse = btnPulse ? _pulseCtrl.value : 0.0;
                            return GestureDetector(
                              onTap: () => widget.game.triggerScan(),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  if (btnPulse)
                                    AnimatedContainer(
                                      duration: Duration.zero,
                                      width: 82 + pulse * 12,
                                      height: 82 + pulse * 12,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: btnColor.withValues(
                                            alpha: 0.18 + pulse * 0.22,
                                          ),
                                          width: 1.5,
                                        ),
                                      ),
                                    ),
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 120),
                                    width: 68,
                                    height: 68,
                                    decoration: BoxDecoration(
                                      color: btnEnabled
                                          ? btnColor.withValues(
                                              alpha: 0.22 + pulse * 0.10,
                                            )
                                          : Colors.black.withValues(
                                              alpha: 0.60,
                                            ),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: btnEnabled
                                            ? btnColor
                                            : Colors.white24,
                                        width: btnEnabled ? 2.5 : 1.5,
                                      ),
                                      boxShadow: btnEnabled
                                          ? [
                                              BoxShadow(
                                                color: btnColor.withValues(
                                                  alpha: 0.30 + pulse * 0.25,
                                                ),
                                                blurRadius: 16 + pulse * 8,
                                              ),
                                            ]
                                          : [],
                                    ),
                                    child: Center(
                                      child: Text(
                                        btnLabel,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: btnEnabled
                                              ? btnColor
                                              : Colors.white30,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 9,
                                          letterSpacing: 0.4,
                                          height: 1.4,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
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

class _DPad extends StatelessWidget {
  final String label;
  final bool isActive;
  final Color color;
  final VoidCallback onDown, onUp;
  const _DPad(
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
//  NOISE SCAN RESULT OVERLAY  (like LandDegradation ScanResultOverlay)
// ════════════════════════════════════════════════════════════════════════════
class NoiseScanResultOverlay extends StatefulWidget {
  final NoisePollutionGame game;
  const NoiseScanResultOverlay(this.game, {super.key});
  @override
  State<NoiseScanResultOverlay> createState() => _NoiseScanResultOverlayState();
}

class _NoiseScanResultOverlayState extends State<NoiseScanResultOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 340))..forward();
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
        const displayDuration = 4.0;
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header row
                  Row(children: [
                    SizedBox(
                      width: 22, height: 22,
                      child: CustomPaint(painter: _ArcCountdownPainter(progress, result.color)),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text('SONAR SCAN COMPLETE',
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

                  // Identified issue
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
                          Text('SOURCE IDENTIFIED',
                              style: TextStyle(color: result.color.withValues(alpha: 0.75),
                                  fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                          const SizedBox(height: 2),
                          Text(result.typeName,
                              style: TextStyle(color: result.color, fontSize: 16,
                                  fontWeight: FontWeight.w900)),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: result.color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(result.dbLevel,
                                style: TextStyle(color: result.color.withValues(alpha: 0.90),
                                    fontSize: 9, fontWeight: FontWeight.w700)),
                          ),
                        ])),
                      ]),
                      const SizedBox(height: 8),
                      Text(result.ecoFact,
                          style: const TextStyle(color: Colors.white70, fontSize: 10, height: 1.5)),
                    ]),
                  ),
                  const SizedBox(height: 10),

                  // Show-once hint / memory prompt
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
                            const Text('REQUIRED SOLUTION',
                                style: TextStyle(color: Colors.white38, fontSize: 7.5,
                                    fontWeight: FontWeight.w900, letterSpacing: 1.3)),
                            const SizedBox(height: 6),
                            Row(children: [
                              Container(width: 16, height: 16, alignment: Alignment.center,
                                decoration: BoxDecoration(color: result.color.withValues(alpha: 0.15), shape: BoxShape.circle,
                                    border: Border.all(color: result.color.withValues(alpha: 0.50))),
                                child: Text('①', style: TextStyle(color: result.color, fontSize: 8, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 6),
                              Text('${result.requiredToolEmoji} ${result.requiredTool}',
                                  style: const TextStyle(color: Colors.white70, fontSize: 9, height: 1.3)),
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
                            Text(
                              'You have identified this noise source before. Apply the correct solution from memory!',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white54, fontSize: 9.5, height: 1.4),
                            ),
                          ]),
                        ),
                  const SizedBox(height: 14),

                  // FIX IT button
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
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ArcCountdownPainter extends CustomPainter {
  final double progress;
  final Color color;
  const _ArcCountdownPainter(this.progress, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2; final cy = size.height / 2;
    final r = math.min(cx, cy) - 1.5;
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

// ════════════════════════════════════════════════════════════════════════════
//  NOISE TOOL SELECTOR  (like LandToolSelector)
// ════════════════════════════════════════════════════════════════════════════
class NoiseToolSelector extends StatelessWidget {
  final NoisePollutionGame game;
  const NoiseToolSelector(this.game, {super.key});

  static const _tools = [
    (NoiseTool.electricMuffler,  '⚡', 'Electric Muffler',   Color(0xFFEF5350), 'Traffic'),
    (NoiseTool.silentMachinery,  '🔕', 'Silent Machine',     Color(0xFFFF6D00), 'Construct.'),
    (NoiseTool.silentZone,       '🚫', 'Silent Zone',        Color(0xFFCE93D8), 'Loudspeaker'),
    (NoiseTool.treeBarrier,      '🌲', 'Tree Barrier',       Color(0xFF69F0AE), 'Vegetation'),
    (NoiseTool.noiseBarrier,     '🧱', 'Noise Barrier',      Color(0xFF8D6E63), 'Industrial'),
    (NoiseTool.flightPath,       '🛫', 'Flight Path',        Color(0xFF5C6BC0), 'Aircraft'),
    (NoiseTool.trackDampener,    '🛤️', 'Track Dampener',     Color(0xFF26A69A), 'Railway'),
    (NoiseTool.soundInsulation,  '🏠', 'Sound Insulation',   Color(0xFFAB47BC), 'Nightclub'),  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: game,
      builder: (_, __) {
        final target = game.pendingFixTarget;
        if (target == null) return const SizedBox.shrink();

        final typeName = _sourceLabel(target.type);
        final showHints = game.toolSelectorShowsHints;

        return Container(
          color: Colors.black.withValues(alpha: 0.62),
          child: Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF0A1A2E),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF29B6F6).withValues(alpha: 0.55), width: 1.5),
                boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 20)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Row(children: [
                    Text(_sourceIcon(target.type), style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(typeName,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('Select the correct noise solution',
                          style: TextStyle(color: const Color(0xFF29B6F6), fontSize: 10.5, fontWeight: FontWeight.w700)),
                    ])),
                    GestureDetector(
                      onTap: game.cancelToolSelector,
                      child: Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.08),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: const Center(child: Text('✕',
                            style: TextStyle(color: Colors.white60, fontSize: 14, fontWeight: FontWeight.bold))),
                      ),
                    ),
                  ]),

                  const SizedBox(height: 4),

                  // Issue reminder
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF29B6F6).withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF29B6F6).withValues(alpha: 0.35)),
                    ),
                    child: showHints
                        ? Text(
                            'Issue: $typeName  •  ${game.lastScanResult?.dbLevel ?? ""}',
                            style: TextStyle(color: const Color(0xFF29B6F6), fontSize: 9.5, fontWeight: FontWeight.w700))
                        : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            const Text('🧠', style: TextStyle(fontSize: 11)),
                            const SizedBox(width: 5),
                            Text('Recall from memory — no hints this time!',
                                style: TextStyle(color: const Color(0xFF29B6F6), fontSize: 9.5, fontWeight: FontWeight.w700)),
                          ]),
                  ),
                  const SizedBox(height: 10),
                  Text('Select the correct solution tool:',
                      style: const TextStyle(color: Colors.white54, fontSize: 10.5)),
                  const SizedBox(height: 14),

                  // Tool grid
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: _tools.map((spec) {
                      final (tool, emoji, label, color, targetHint) = spec;
                      // Only highlight correct tool when hints are active
                      final correct = showHints && game._isCorrectTool(target.type, tool);
                      //final selColor = correct ? color : Colors.white24;

                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          game.selectTool(tool);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 130),
                          width: 100,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
                          decoration: BoxDecoration(
                            color: correct
                                ? color.withValues(alpha: 0.20)
                                : Colors.black.withValues(alpha: 0.62),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: correct ? color.withValues(alpha: 0.80) : Colors.white.withValues(alpha: 0.22),
                              width: correct ? 2.0 : 1.2,
                            ),
                            boxShadow: correct
                                ? [BoxShadow(color: color.withValues(alpha: 0.30), blurRadius: 10)]
                                : [],
                          ),
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            Text(emoji, style: const TextStyle(fontSize: 20)),
                            const SizedBox(height: 4),
                            Text(label,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: correct ? color : Colors.white70,
                                  fontWeight: FontWeight.w800, fontSize: 9.5,
                                )),
                            // Issue label: shown when hints are active
                            if (showHints)
                              Text(targetHint,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: color.withValues(alpha: 0.68),
                                    fontSize: 7.5,
                                  ))
                            else
                              Text('— apply from memory —',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.white24, fontSize: 7)),
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

  String _sourceIcon(NoiseType t) {
    switch (t) {
      case NoiseType.traffic: return '🚗';
      case NoiseType.construction: return '🏗️';
      case NoiseType.loudspeaker: return '📢';
      case NoiseType.vegetation: return '🌿';
      case NoiseType.industrial: return '🏭';
      case NoiseType.aircraft: return '✈️';
      case NoiseType.railway: return '🚆';
      case NoiseType.nightclub: return '🎵';
    }
  }

  String _sourceLabel(NoiseType t) {
    switch (t) {
      case NoiseType.traffic: return 'Vehicle Honking';
      case NoiseType.construction: return 'Construction Site';
      case NoiseType.loudspeaker: return 'Loud Speaker';
      case NoiseType.vegetation: return 'Sparse Vegetation';
      case NoiseType.industrial: return 'Industrial Plant';
      case NoiseType.aircraft: return 'Aircraft Overflight';
      case NoiseType.railway: return 'Railway Noise';
      case NoiseType.nightclub: return 'Nightclub District';
    }
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  PHASE BANNER
// ════════════════════════════════════════════════════════════════════════════
class NoisePhaseBanner extends StatelessWidget {
  final NoisePollutionGame game;
  const NoisePhaseBanner(this.game, {super.key});

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF29B6F6);

    return IgnorePointer(
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF001A2E), Color(0xFF003050)],
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
              const Text(
                'NOISE INVESTIGATION',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  letterSpacing: 2.5,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                '📡  Scan & Fix the City',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Fly close to noise sources and tap 📡 SCAN.'
                'A 1.5 s lock starts — stay in range to complete it.'
                'Read the identified source, then tap FIX IT to resolve!'
                'Wind slows scans · First scan shows hints, next requires memory.'
                '💡 Fix at least ${NoisePollutionGame.kMinSolutionsRequired} hotspots to advance.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11.5,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 10),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _WindLegendDot(
                    color: Color(0xFF80DEEA),
                    label: 'Light wind — 15% slower',
                  ),
                  SizedBox(width: 12),
                  _WindLegendDot(
                    color: Color(0xFFFFB300),
                    label: 'Moderate — 40% slower',
                  ),
                  SizedBox(width: 12),
                  _WindLegendDot(
                    color: Color(0xFFEF5350),
                    label: 'Heavy — 65% slower',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WindLegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _WindLegendDot({required this.color, required this.label});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
      const SizedBox(width: 4),
      Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}

// ════════════════════════════════════════════════════════════════════════════
//  REACTION FX
// ════════════════════════════════════════════════════════════════════════════
class NoiseReactionFx extends StatelessWidget {
  final NoisePollutionGame game;
  const NoiseReactionFx(this.game, {super.key});

  @override
  Widget build(BuildContext context) {
    final String title;
    final String sub;
    final Color accent;

    switch (game.reactionKind) {
      case ReactionKind.windSlow:
        title = '💨  WIND SLOWING SCAN';
        sub = 'Scan progress reduced — hold position longer!';
        accent = const Color(0xFFFFB300);
        break;
      case ReactionKind.scanMiss:
        title = '📡  OUT OF RANGE!';
        sub = 'Fly closer to a noise source first';
        accent = const Color(0xFF78909C);
        break;
      case ReactionKind.noCharge:
        final toolOpen = game.toolSelectorOpen;
        title = toolOpen ? '🔧  SELECT A TOOL FIRST!' : '⚡  NOT READY';
        sub = toolOpen
            ? 'Pick the correct solution from the panel'
            : 'Navigate into a noise source zone';
        accent = const Color(0xFFFFB300);
        break;
      case ReactionKind.scanPartial:
        title = '🔊  SCANNING…';
        sub = 'Hold position — stay in range to complete!';
        accent = const Color(0xFFFFB300);
        break;
      case ReactionKind.scanLocked:
        final c = game.reactionCombo;
        title = c >= 3 ? '🔥  COMBO ×$c  —  SCAN COMPLETE!' : '🔒  SCAN COMPLETE!';
        sub = c >= 3
            ? '+${10 + c * 5} Eco-Points  •  Now pick your tool!'
            : '+10 Eco-Points  •  Select a solution now!';
        accent = const Color(0xFF29B6F6);
        break;
      case ReactionKind.windEvade:
        title = '💨  WIND EVADED!';
        sub = '+3 Eco-Points  •  Nimble Navigator!';
        accent = const Color(0xFF69F0AE);
        break;
      case ReactionKind.fixCorrect:
        title = '✅  NOISE REDUCED!';
        sub = '+15 Eco-Points  •  Decibels dropped — keep exploring!';
        accent = const Color(0xFF69F0AE);
        break;
      case ReactionKind.fixWrong:
        title = '❌  WRONG TOOL!';
        sub = '−10 Eco-Points  •  Try a different solution';
        accent = const Color(0xFFEF5350);
        break;
    }

    final isPositive = game.reactionCorrect;

    if (game.reactionKind == ReactionKind.windEvade ||
        game.reactionKind == ReactionKind.scanPartial ||
        game.reactionKind == ReactionKind.windSlow) {
      return IgnorePointer(
        child: Align(
          alignment: Alignment.topCenter,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(top: 80),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isPositive
                      ? const Color(0xFF0A2E1A).withValues(alpha: 0.92)
                      : const Color(0xFF2E1A00).withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: accent.withValues(alpha: 0.60)),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.25),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      sub,
                      style: TextStyle(
                        color: accent.withValues(alpha: 0.75),
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return IgnorePointer(
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: accent.withValues(alpha: 0.55),
                width: 8,
              ),
              gradient: RadialGradient(
                colors: [Colors.transparent, accent.withValues(alpha: 0.10)],
                radius: 1.5,
              ),
            ),
          ),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
              decoration: BoxDecoration(
                color: isPositive
                    ? const Color(0xFF0A2E1A).withValues(alpha: 0.95)
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
                      fontSize: 19,
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
//  COMPLETION BANNER  (like LandCompletionBanner)
// ════════════════════════════════════════════════════════════════════════════
class NoiseCompletionBanner extends StatefulWidget {
  final NoisePollutionGame game;
  const NoiseCompletionBanner(this.game, {super.key});

  @override
  State<NoiseCompletionBanner> createState() => _NoiseCompletionBannerState();
}

class _NoiseCompletionBannerState extends State<NoiseCompletionBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 380));
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack);
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _ctrl.forward();

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
    final r = NoiseResult.current!;
    final state = r.completionState;
    final total = widget.game.hotspots.length;

    final String topEmoji;
    final String title;
    final String subtitle;
    final List<Color> bgGrad;
    final Color glow;

    switch (state) {
      case LevelCompletionState.fullCompletion:
        topEmoji = '🏆';
        title = 'FULL RESTORATION!';
        subtitle = 'All $total hotspots resolved — outstanding fieldwork!';
        bgGrad = [const Color(0xFF003D14), const Color(0xFF005A1E)];
        glow = const Color(0xFF69F0AE);
        break;
      case LevelCompletionState.moderate:
        topEmoji = '✅';
        title = 'MINIMUM ACHIEVED!';
        subtitle = '${r.hotspotsFix}/$total hotspots fixed'
            'Continuing to Level Complete…';
        bgGrad = [const Color(0xFF3B2600), const Color(0xFF5A3800)];
        glow = const Color(0xFFFFB300);
        break;
      case LevelCompletionState.failed:
        topEmoji = '⏰';
        title = 'NOT ENOUGH FIXED';
        subtitle = '${r.hotspotsFix}/${r.minimumRequired} hotspots fixed'
            'Replay to reach the minimum';
        bgGrad = [const Color(0xFF3D0000), const Color(0xFF5A0000)];
        glow = const Color(0xFFEF5350);
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
                Text(topEmoji, style: const TextStyle(fontSize: 62)),
                const SizedBox(height: 12),
                Text(title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: glow, fontSize: 22,
                      fontWeight: FontWeight.w900, letterSpacing: 1.4,
                    )),
                const SizedBox(height: 10),
                Text(subtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 13.5, height: 1.55)),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
                  decoration: BoxDecoration(
                    color: glow.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: glow.withValues(alpha: 0.38)),
                  ),
                  child: Text(
                    '🔊 ${r.hotspotsFix}/$total Fixed  •  '
                    '⭐ ${r.ecoPoints} pts  •  🎯 ${r.scanComboMax}× combo',
                    style: TextStyle(
                        color: glow, fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 16),
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

// ════════════════════════════════════════════════════════════════════════════
//  NOISE RESULTS OVERLAY  (updated with retry mechanism like land)
// ════════════════════════════════════════════════════════════════════════════
class NoiseResultsOverlay extends StatelessWidget {
  final NoisePollutionGame game;
  const NoiseResultsOverlay(this.game, {super.key});

  @override
  Widget build(BuildContext context) {
    final result = NoiseResult.current!;
    final peaceful = result.peacefulCityBadge;
    final meetsMin = result.meetsMinimum;
    final dbFinal = result.noiseMeterFinal.toStringAsFixed(0);
    final totalHotspots = game.hotspots.length;

    return Container(
      color: Colors.black.withValues(alpha: 0.94),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: peaceful
                        ? [const Color(0xFF001A0A), const Color(0xFF003018)]
                        : meetsMin
                        ? [const Color(0xFF001A0A), const Color(0xFF003018)]
                        : [const Color(0xFF1A0800), const Color(0xFF2E1200)],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: const [
                    BoxShadow(color: Colors.black54, blurRadius: 16),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      peaceful ? '🕊️' : meetsMin ? '📡' : '🔊',
                      style: const TextStyle(fontSize: 52),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      peaceful
                          ? 'City Restored to Peace!'
                          : meetsMin
                          ? 'Investigation Complete'
                          : 'More Work Needed!',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      result.endReason,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: meetsMin ? Colors.white70 : const Color(0xFFFF8A65),
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                    if (!meetsMin) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF5350).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0xFFEF5350).withValues(alpha: 0.50),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('⚠️', style: TextStyle(fontSize: 16)),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'Fixed: ${result.hotspotsFix} / ${result.minimumRequired} required'
                                'Replay to fix ${result.minimumRequired - result.hotspotsFix} more hotspot(s)',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Color(0xFFFF8A65),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (peaceful) ...[
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
                              'Peaceful City Badge Unlocked!',
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

              _NRCard(
                children: [
                  _NRBig(
                    '🔊',
                    '$dbFinal dB',
                    'Final Noise',
                    peaceful
                        ? const Color(0xFF69F0AE)
                        : const Color(0xFFFFB300),
                  ),
                  _NRBig(
                    '✅',
                    '${result.hotspotsFix}/$totalHotspots',
                    'Fixed',
                    Colors.limeAccent,
                  ),
                  _NRBig(
                    '❌',
                    '${result.wrongTools}',
                    'Errors',
                    Colors.redAccent,
                  ),
                  _NRBig('⭐', '${result.ecoPoints}', 'Eco-Pts', Colors.amber),
                ],
              ),

              const SizedBox(height: 10),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A1828),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFF29B6F6).withValues(alpha: 0.22),
                  ),
                ),
                child: Column(
                  children: [
                    const Text(
                      'SONAR INVESTIGATION STATS',
                      style: TextStyle(
                        color: Color(0xFF29B6F6),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _NRBig(
                          '💨',
                          '${result.windEvades}',
                          'Wind Evaded',
                          const Color(0xFF80DEEA),
                        ),
                        _NRBig(
                          '🔥',
                          '×${result.scanComboMax}',
                          'Best Combo',
                          const Color(0xFFFF6D00),
                        ),
                        _NRBig(
                          '🛰️',
                          '${result.scannedCount}',
                          'Scanned',
                          const Color(0xFF29B6F6),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A1E10),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Interventions Applied',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _NRRow(
                      '🚗',
                      'Vehicle Honking',
                      '⚡ Electric upgrade / mufflers',
                    ),
                    _NRRow(
                      '🏗️',
                      'Construction Sites',
                      '🔕 Silent machinery deployed',
                    ),
                    _NRRow('📢', 'Loudspeakers', '🚫 Silent zones established'),
                    _NRRow(
                      '🌲',
                      'Vegetation Zones',
                      '🌿 Tree lines & barriers planted',
                    ),
                    _NRRow(
                      '🏭',
                      'Industrial Plants',
                      '🧱 Noise barriers installed',
                    ),
                    _NRRow(
                      '✈️',
                      'Aircraft Overflight',
                      '🛫 Optimized flight paths',
                    ),
                    _NRRow(
                      '🚆',
                      'Railway Noise',
                      '🛤️ Track dampeners deployed',
                    ),
                    _NRRow(
                      '🎵',
                      'Nightclub Districts',
                      '🏠 Sound insulation applied',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: meetsMin
                    ? ElevatedButton.icon(
                        onPressed: () {
                          game.resumeEngine();
                          game.onLevelComplete();
                        },
                        icon: const Icon(Icons.emoji_events_rounded),
                        label: const Text(
                          'Complete Level 4  →',
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
                      )
                    : Column(
                        children: [
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            icon: const Icon(Icons.replay_rounded),
                            label: Text(
                              'Replay  — Fix ${result.minimumRequired - result.hotspotsFix} More Hotspot(s)',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFEF5350),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              minimumSize: const Size(double.infinity, 0),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 8,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFB300).withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xFFFFB300).withValues(alpha: 0.35),
                              ),
                            ),
                            child: Text(
                              '💡 Tip: Fly close to noise sources and tap SCAN.'
                              'Hold position for 1.5s to complete the scan.'
                              'Minimum ${result.minimumRequired} fixes needed to advance.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFFFFB300),
                                fontSize: 11,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NRCard extends StatelessWidget {
  final List<Widget> children;
  const _NRCard({required this.children});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    decoration: BoxDecoration(
      color: const Color(0xFF0A1E12),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white12),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: children,
    ),
  );
}

class _NRBig extends StatelessWidget {
  final String emoji, value, label;
  final Color color;
  const _NRBig(this.emoji, this.value, this.label, this.color);
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

class _NRRow extends StatelessWidget {
  final String emoji, label, action;
  const _NRRow(this.emoji, this.label, this.action);
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