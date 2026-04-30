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
  final int    hotspotsFix;
  final int    wrongTools;
  final int    ecoPoints;
  final double noiseMeterFinal;
  final bool   peacefulCityBadge;
  final int    windEvades;
  final int    scanComboMax;

  const NoiseResult({
    required this.hotspotsFix,
    required this.wrongTools,
    required this.ecoPoints,
    required this.noiseMeterFinal,
    required this.peacefulCityBadge,
    required this.windEvades,
    required this.scanComboMax,
  });

  static NoiseResult? current;
}

// ══════════════════════════════════════════════════════════════════════════════
//  ENUMS
// ══════════════════════════════════════════════════════════════════════════════
enum NoiseType    { traffic, construction, loudspeaker, vegetation }
enum NoiseTool    { electricMuffler, silentMachinery, silentZone, treeBarrier }
enum WindIntensity { light, moderate, heavy }

enum ReactionKind {
  scanHit, scanMiss, windBlock, noCharge,
  windEvade, fixCorrect, fixWrong
}

// ══════════════════════════════════════════════════════════════════════════════
//  WIND ZONE  (Phase 3 hazard)
// ══════════════════════════════════════════════════════════════════════════════
class WindZone {
  double cx, cy;
  final double radius;
  double angle;           // travel direction (radians)
  final double speed;     // pixels / second
  final WindIntensity intensity;
  double lifetime;        // remaining seconds
  final double maxLifetime;
  bool isActive = true;
  double animT = 0;

  WindZone({
    required this.cx, required this.cy,
    required this.radius, required this.angle,
    required this.speed,  required this.intensity,
    required this.lifetime,
  })  : maxLifetime = lifetime;

  void update(double dt, double w, double h) {
    if (!isActive) return;
    animT  += dt;
    cx     += math.cos(angle) * speed * dt;
    cy     += math.sin(angle) * speed * dt;
    lifetime -= dt;
    if (lifetime <= 0) { isActive = false; return; }
    // Bounce off vertical bounds (keep within game area)
    if (cy < 90)         { cy = 90;         angle = _reflectV(angle); }
    if (cy > h * 0.83)   { cy = h * 0.83;   angle = _reflectV(angle); }
    // Wrap horizontally
    if (cx < -radius * 1.5) cx = w + radius;
    if (cx > w + radius * 1.5) cx = -radius;
  }

  double _reflectV(double a) => -a; // flip vertical component

  bool containsPoint(Vector2 p) =>
      (Vector2(cx, cy) - p).length < radius;

  /// 0.0 at edge, 1.0 at centre
  double intensityAt(Vector2 p) =>
      (1.0 - (Vector2(cx, cy) - p).length / radius).clamp(0.0, 1.0);

  Color get color {
    switch (intensity) {
      case WindIntensity.light:    return const Color(0xFF80DEEA);
      case WindIntensity.moderate: return const Color(0xFFFFB300);
      case WindIntensity.heavy:    return const Color(0xFFEF5350);
    }
  }

  double get strengthFactor {
    switch (intensity) {
      case WindIntensity.light:    return 0.35;
      case WindIntensity.moderate: return 0.65;
      case WindIntensity.heavy:    return 1.00;
    }
  }

  /// Does this intensity actually block a scan?
  bool blocksAt(Vector2 p, math.Random rng) {
    if (!containsPoint(p)) return false;
    switch (intensity) {
      case WindIntensity.light:    return false;
      case WindIntensity.moderate: return rng.nextDouble() < 0.72;
      case WindIntensity.heavy:    return true;
    }
  }

  // Fade-in / fade-out alpha multiplier
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
  ScanRing({required this.radius, required this.alpha, required this.disrupted});
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
      carryOver:       widget.carryOver,
      onLevelComplete: _onDone,
    );
  }

  void _onDone() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => Level4CompleteScreen(carryOver: widget.carryOver),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GameWidget(
        game: _game,
        overlayBuilderMap: {
          'hud':        (ctx, g) => NoiseHud(g as NoisePollutionGame),
          'controls':   (ctx, g) => NoiseControls(g as NoisePollutionGame),
          'banner':     (ctx, g) => NoisePhaseBanner(g as NoisePollutionGame),
          'toolSelect': (ctx, g) => NoiseToolSelector(g as NoisePollutionGame),
          'reactionFx': (ctx, g) => NoiseReactionFx(g as NoisePollutionGame),
          'results':    (ctx, g) => NoiseResultsOverlay(g as NoisePollutionGame),
        },
        initialActiveOverlays: const ['hud', 'controls'],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  MAIN GAME CLASS
// ══════════════════════════════════════════════════════════════════════════════
class NoisePollutionGame extends FlameGame
    with HasCollisionDetection, ChangeNotifier {

  final Level3CarryOver carryOver;
  final VoidCallback    onLevelComplete;

  NoisePollutionGame({required this.carryOver, required this.onLevelComplete});

  // ── Core state ────────────────────────────────────────────────────────────
  int    gamePhase   = 3;   // 3 = scan, 4 = fix
  bool   gameStarted = false;
  double timeLeft    = 120.0;
  bool   levelDone   = false;

  // ── Score ─────────────────────────────────────────────────────────────────
  int ecoPoints    = 0;
  int wrongTools   = 0;
  int fixedCount   = 0;
  int scannedCount = 0;

  // ── Noise meter ───────────────────────────────────────────────────────────
  double noiseMeter = 96.0;
  static const double _targetNoise  = 40.0;
  static const double _fixReduction = 8.0;
  static const double _wrongPenalty = 4.0;

  // ── Range constants ───────────────────────────────────────────────────────
  static const double _scanRange  = 150.0;
  static const double _applyRange = 100.0;

  // ── Drone physics ─────────────────────────────────────────────────────────
  late Vector2 dronePos;
  bool isUp = false, isDown = false, isLeft = false, isRight = false;
  static const double _droneSpeed = 180.0;

  // Wind buffet applied to drone visually (not actual pos)
  double droneWindTiltX = 0;
  double droneWindTiltY = 0;

  // ── Tool selection ────────────────────────────────────────────────────────
  NoiseTool selectedTool = NoiseTool.electricMuffler;

  // ── Phase 3 — Wind Interference System ───────────────────────────────────
  final List<WindZone> windZones = [];
  double _windSpawnTimer  = 0;
  double _windSpawnCooldown = 4.5; // grows harder over time
  final _rng = math.Random();

  // Whether drone is currently inside a disruptive wind zone
  bool get isInBlockingWind => gamePhase == 3 &&
      windZones.any((z) => z.isActive &&
          z.intensity != WindIntensity.light &&
          z.containsPoint(dronePos));

  bool get isInAnyWind => gamePhase == 3 &&
      windZones.any((z) => z.isActive && z.containsPoint(dronePos));

  WindZone? get dominantWindZone {
    WindZone? best;
    double bestI = 0;
    for (final z in windZones) {
      if (!z.isActive) continue;
      final i = z.intensityAt(dronePos);
      if (i > bestI) { bestI = i; best = z; }
    }
    return best;
  }

  // Wind evasion tracking
  bool   _wasInWind    = false;
  int    windEvades    = 0;
  double _evadeShowTimer = 0;

  // ── Phase 3 — Scan Charge ─────────────────────────────────────────────────
  double scanCharge = 1.0;               // 0.0 – 1.0
  static const double _scanChargeCost   = 0.32;
  static const double _scanRechargeRate = 0.16; // per second
  bool scanChargeReady = true;           // true when above threshold

  // ── Phase 3 — Combo System ────────────────────────────────────────────────
  int    scanCombo       = 0;
  int    scanComboMax    = 0;
  double _comboDecayTimer = 0;
  static const double _comboWindow = 9.0; // seconds

  // ── Reaction FX ──────────────────────────────────────────────────────────
  bool          reactionActive = false;
  bool          reactionCorrect = false;
  int           reactionPhase  = 3;
  bool          reactionInRange = true;
  double        reactionTimer   = 0;
  ReactionKind reactionKind    = ReactionKind.scanHit;
  int           reactionCombo   = 0;

  // ── Banner ────────────────────────────────────────────────────────────────
  double bannerTimer = 3.5;

  // ── Scan animation ────────────────────────────────────────────────────────
  bool   scanActive  = false;
  double scanRadius  = 0;
  static const double _scanMaxRadius = 180.0;

  final List<ScanRing> scanRings = [];

  // ── Components ────────────────────────────────────────────────────────────
  late EcoDroneComponent drone;
  final List<NoiseHotspot> hotspots = [];

  @override
  Future<void> onLoad() async {
    super.onLoad();
    dronePos = Vector2(size.x * 0.50, size.y * 0.60);

    add(NoiseCityRenderer(game: this));
    _spawnHotspots();
    add(WindZoneRenderer(game: this)); // above hotspots, below drone
    drone = EcoDroneComponent(game: this);
    add(drone);

    bannerTimer = 3.5;
    overlays.add('banner');
    add(TimerComponent(period: 1.0, repeat: true, onTick: _onSecond));
  }

  void _spawnHotspots() {
    final specs = [
      (NoiseType.traffic,      0.15, 0.32),
      (NoiseType.traffic,      0.78, 0.52),
      (NoiseType.construction, 0.32, 0.62),
      (NoiseType.construction, 0.62, 0.22),
      (NoiseType.loudspeaker,  0.48, 0.42),
      (NoiseType.loudspeaker,  0.88, 0.72),
      (NoiseType.vegetation,   0.18, 0.78),
      (NoiseType.vegetation,   0.65, 0.82),
    ];
    for (int i = 0; i < specs.length; i++) {
      final (type, rx, ry) = specs[i];
      final h = NoiseHotspot(
        game: this, type: type,
        worldX: size.x * rx, worldY: size.y * ry,
        seed: i * 19,
      );
      add(h);
      hotspots.add(h);
    }
  }

  void _onSecond() {
    if (!gameStarted || levelDone) return;
    timeLeft -= 1;
    if (timeLeft <= 0) { timeLeft = 0; _endLevel(); }
    notifyListeners();
  }

  // ── Wind zone spawning ────────────────────────────────────────────────────
  void _spawnWindZone() {
    // Determine entry edge
    final edge = _rng.nextInt(3); // 0=left 1=top 2=right
    double cx, cy, angle;

    switch (edge) {
      case 0:
        cx    = -70;
        cy    = size.y * (0.10 + _rng.nextDouble() * 0.68);
        angle = -0.45 + _rng.nextDouble() * 0.9;
        break;
      case 1:
        cx    = size.x * (0.10 + _rng.nextDouble() * 0.80);
        cy    = -70;
        angle = math.pi * 0.25 + _rng.nextDouble() * math.pi * 0.50;
        break;
      default:
        cx    = size.x + 70;
        cy    = size.y * (0.10 + _rng.nextDouble() * 0.68);
        angle = math.pi - 0.45 + _rng.nextDouble() * 0.9;
    }

    // Scale intensity with game progress
    final progress = scannedCount / hotspots.length.toDouble();
    WindIntensity intensity;
    if (progress < 0.30) {
      intensity = _rng.nextBool() ? WindIntensity.light : WindIntensity.moderate;
    } else if (progress < 0.65) {
      intensity = _rng.nextBool() ? WindIntensity.moderate : WindIntensity.heavy;
    } else {
      intensity = WindIntensity.heavy;
    }

    windZones.add(WindZone(
      cx:        cx,
      cy:        cy,
      radius:    85.0 + _rng.nextDouble() * 55.0,
      angle:     angle,
      speed:     38.0 + _rng.nextDouble() * 32.0,
      intensity: intensity,
      lifetime:  6.5 + _rng.nextDouble() * 6.0,
    ));

    // Tighten spawn interval as player progresses
    _windSpawnCooldown = math.max(2.2, 4.5 - progress * 3.0);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  bool get _hasNearbyUnscanned =>
      hotspots.any((h) => !h.isScanned &&
          (h.hotspotPos - dronePos).length <= _scanRange);

  bool get _hasNearbyUnfixed =>
      hotspots.any((h) => !h.isFixed &&
          (h.hotspotPos - dronePos).length <= _applyRange);

  NoiseHotspot? get _nearestUnfixed {
    NoiseHotspot? target;
    double best = _applyRange;
    for (final h in hotspots) {
      if (h.isFixed) continue;
      final d = (h.hotspotPos - dronePos).length;
      if (d < best) { best = d; target = h; }
    }
    return target;
  }

  // ── Phase 3 — Scan (with wind checks) ────────────────────────────────────
  void scanHotspot() {
    if (!gameStarted || levelDone || gamePhase != 3) return;
    gameStarted = true;
    HapticFeedback.selectionClick();

    // 1. Check scan charge
    if (scanCharge < 0.18) {
      _triggerReaction(ReactionKind.noCharge);
      return;
    }

    // 2. Check wind disruption
    for (final z in windZones) {
      if (!z.isActive) continue;
      if (z.blocksAt(dronePos, _rng)) {
        scanCharge = math.max(0, scanCharge - _scanChargeCost * 0.45);
        scanCombo  = 0; // break combo
        _comboDecayTimer = 0;
        HapticFeedback.vibrate();
        // Disrupted scan ring
        scanRings.add(ScanRing(radius: 0, alpha: 0.55, disrupted: true));
        _triggerReaction(ReactionKind.windBlock);
        notifyListeners();
        return;
      }
    }

    // 3. Normal scan
    int newly = 0;
    for (final h in hotspots) {
      if (h.isScanned) continue;
      if ((h.hotspotPos - dronePos).length <= _scanRange) {
        h.reveal(); scannedCount++; newly++;
      }
    }

    if (newly > 0) {
      scanCharge = math.max(0, scanCharge - _scanChargeCost);
      scanCombo++;
      if (scanCombo > scanComboMax) scanComboMax = scanCombo;
      _comboDecayTimer = _comboWindow;

      int pts = newly * 5 + (scanCombo >= 3 ? scanCombo * 3 : 0);
      ecoPoints += pts;

      scanActive = true;
      scanRadius = 0;
      scanRings.add(ScanRing(radius: 0, alpha: 0.75, disrupted: false));
      _triggerReaction(ReactionKind.scanHit, combo: scanCombo);

      if (scannedCount >= hotspots.length) {
        Future.delayed(const Duration(milliseconds: 900), _advanceToPhase4);
      }
    } else {
      _triggerReaction(ReactionKind.scanMiss);
    }
    notifyListeners();
  }

  void _advanceToPhase4() {
    if (levelDone) return;
    gamePhase   = 4;
    bannerTimer = 3.0;
    // Despawn all wind zones
    for (final z in windZones) {
      z.isActive = false;
    }
    overlays
      ..add('banner')
      ..add('toolSelect');
    notifyListeners();
  }

  // ── Phase 4 — Fix ─────────────────────────────────────────────────────────
  void applyTool() {
    if (!gameStarted || levelDone || gamePhase != 4) return;
    final target = _nearestUnfixed;
    if (target == null) {
      _triggerReaction(ReactionKind.scanMiss);
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
      ecoPoints  = math.max(0, ecoPoints - 10);
      _triggerReaction(ReactionKind.fixWrong);
    }

    if (noiseMeter <= _targetNoise || hotspots.every((h) => h.isFixed)) {
      Future.delayed(const Duration(milliseconds: 800), _endLevel);
    }
    notifyListeners();
  }

  bool _isCorrectTool(NoiseType t, NoiseTool tool) {
    switch (t) {
      case NoiseType.traffic:      return tool == NoiseTool.electricMuffler;
      case NoiseType.construction: return tool == NoiseTool.silentMachinery;
      case NoiseType.loudspeaker:  return tool == NoiseTool.silentZone;
      case NoiseType.vegetation:   return tool == NoiseTool.treeBarrier;
    }
  }

  void selectTool(NoiseTool t) { selectedTool = t; notifyListeners(); }

  // ── Input ─────────────────────────────────────────────────────────────────
  void setUpKey(bool v)    { isUp    = v; if (v) gameStarted = true; }
  void setDownKey(bool v)  { isDown  = v; if (v) gameStarted = true; }
  void setLeftKey(bool v)  { isLeft  = v; if (v) gameStarted = true; }
  void setRightKey(bool v) { isRight = v; if (v) gameStarted = true; }

  // ── Reaction ──────────────────────────────────────────────────────────────
  void _triggerReaction(ReactionKind kind, {int combo = 0}) {
    reactionKind    = kind;
    reactionCombo   = combo;
    reactionActive  = true;
    reactionCorrect = kind == ReactionKind.scanHit   ||
                      kind == ReactionKind.fixCorrect ||
                      kind == ReactionKind.windEvade;
    reactionPhase   = gamePhase;
    reactionInRange = kind != ReactionKind.scanMiss &&
                      kind != ReactionKind.noCharge;
    reactionTimer   = kind == ReactionKind.windEvade ? 0.8 : 1.2;
    overlays.add('reactionFx');
  }

  void _endLevel() {
    if (levelDone) return;
    levelDone = true;
    pauseEngine();

    NoiseResult.current = NoiseResult(
      hotspotsFix:       fixedCount,
      wrongTools:        wrongTools,
      ecoPoints:         ecoPoints,
      noiseMeterFinal:   noiseMeter,
      peacefulCityBadge: noiseMeter < _targetNoise,
      windEvades:        windEvades,
      scanComboMax:      scanComboMax,
    );

    overlays
      ..remove('reactionFx')
      ..remove('toolSelect')
      ..add('results');
    notifyListeners();
  }

  // ── Update ────────────────────────────────────────────────────────────────
  @override
  void update(double dt) {
    super.update(dt);

    // Banners / reaction timers
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

    // Scan animation ring
    if (scanActive) {
      scanRadius += dt * 220;
      if (scanRadius >= _scanMaxRadius) scanActive = false;
      notifyListeners();
    }

    // Scan ripple rings
    for (final ring in scanRings) {
      ring.radius += dt * 190;
      ring.alpha   = math.max(0, ring.alpha - dt * 0.72);
    }
    scanRings.removeWhere((r) => r.alpha <= 0);

    if (!gameStarted || levelDone) return;

    // ── Phase 3 wind system ──────────────────────────────────────────────
    if (gamePhase == 3) {
      // Spawn wind zones
      _windSpawnTimer += dt;
      if (_windSpawnTimer >= _windSpawnCooldown) {
        _windSpawnTimer = 0;
        _spawnWindZone();
      }

      // Update existing wind zones
      for (final z in windZones) {
        z.update(dt, size.x, size.y);
      }
      windZones.removeWhere((z) => !z.isActive);

      // Wind drift pushes drone gently
      final dom = dominantWindZone;
      if (dom != null) {
        final i = dom.intensityAt(dronePos);
        final driftX = math.cos(dom.angle) * i * 12 * dt;
        final driftY = math.sin(dom.angle) * i * 10 * dt;
        dronePos.x = (dronePos.x + driftX).clamp(30, size.x - 30);
        dronePos.y = (dronePos.y + driftY).clamp(40, size.y * 0.88);
        // Visual tilt
        droneWindTiltX += (math.cos(dom.angle) * i * 18 - droneWindTiltX) * dt * 4;
        droneWindTiltY += (math.sin(dom.angle) * i * 18 - droneWindTiltY) * dt * 4;
      } else {
        droneWindTiltX *= math.pow(0.85, dt * 60) as double;
        droneWindTiltY *= math.pow(0.85, dt * 60) as double;
      }

      // Wind evasion detection
      final nowInWind = isInAnyWind;
      if (_wasInWind && !nowInWind && gameStarted) {
        windEvades++;
        ecoPoints += 3;
        _evadeShowTimer = 1.0;
        _triggerReaction(ReactionKind.windEvade);
      }
      _wasInWind = nowInWind;
      if (_evadeShowTimer > 0) _evadeShowTimer -= dt;

      // Scan charge recharge (faster when out of wind)
      final rechargeBoost = isInAnyWind ? 0.5 : 1.0;
      if (scanCharge < 1.0) {
        scanCharge = math.min(1.0, scanCharge + _scanRechargeRate * dt * rechargeBoost);
        scanChargeReady = scanCharge >= 0.18;
      }

      // Combo decay timer
      if (_comboDecayTimer > 0) {
        _comboDecayTimer -= dt;
        if (_comboDecayTimer <= 0) scanCombo = 0;
      }
    }

    // ── Drone movement ───────────────────────────────────────────────────
    double vx = 0, vy = 0;
    if (isLeft)  vx -= 1;  if (isRight) vx += 1;
    if (isUp)    vy -= 1;  if (isDown)  vy += 1;
    dronePos.x = (dronePos.x + vx * _droneSpeed * dt).clamp(30, size.x - 30);
    dronePos.y = (dronePos.y + vy * _droneSpeed * dt).clamp(40, size.y * 0.88);

    notifyListeners();
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  NOISE CITY RENDERER  (unchanged)
// ════════════════════════════════════════════════════════════════════════════
class NoiseCityRenderer extends Component {
  final NoisePollutionGame game;
  double _t = 0;
  NoiseCityRenderer({required this.game});

  @override
  void update(double dt) => _t += dt * 0.3;

  @override
  void render(Canvas canvas) {
    final w = game.size.x;
    final h = game.size.y;

    canvas.drawRect(Rect.fromLTWH(0, 0, w, h),
        Paint()
          ..shader = ui.Gradient.linear(Offset.zero, Offset(0, h), [
            const Color(0xFF080E18),
            Color.lerp(const Color(0xFF0C1420), const Color(0xFF0A1E14),
                (math.sin(_t) * 0.5 + 0.5) * 0.4)!,
            const Color(0xFF080C10),
          ], [0.0, 0.5, 1.0]));

    final noiseRatio = (game.noiseMeter / 96.0).clamp(0.0, 1.0);
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h),
        Paint()
          ..color = const Color(0xFFEF5350).withValues(alpha: noiseRatio * 0.05)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30));

    _drawRoads(canvas, w, h);
    _drawBuildings(canvas, w, h);

    canvas.drawRect(Rect.fromLTWH(0, h * 0.86, w, h * 0.14),
        Paint()..color = const Color(0xFF050810));
  }

  void _drawRoads(Canvas canvas, double w, double h) {
    final roadPaint = Paint()..color = const Color(0xFF0B1018);
    final dashPaint = Paint()
      ..color = const Color(0xFF1A2820).withValues(alpha: 0.7)
      ..strokeWidth = 1.0;

    for (final ry in [0.28, 0.52, 0.74]) {
      canvas.drawRect(Rect.fromLTWH(0, h * ry - 14, w, 28), roadPaint);
      double x = 0;
      while (x < w) {
        canvas.drawLine(Offset(x, h * ry), Offset(x + 14, h * ry), dashPaint);
        x += 28;
      }
    }
    for (final rx in [0.24, 0.50, 0.76]) {
      canvas.drawRect(Rect.fromLTWH(w * rx - 14, 0, 28, h * 0.86), roadPaint);
      double y = 0;
      while (y < h * 0.86) {
        canvas.drawLine(Offset(w * rx, y), Offset(w * rx, y + 14), dashPaint);
        y += 28;
      }
    }
  }

  void _drawBuildings(Canvas canvas, double w, double h) {
    final rng = math.Random(66);
    const blocks = [
      (0.02, 0.02, 0.20, 0.24), (0.26, 0.02, 0.22, 0.24),
      (0.52, 0.02, 0.22, 0.24), (0.78, 0.02, 0.20, 0.24),
      (0.02, 0.30, 0.20, 0.20), (0.26, 0.30, 0.22, 0.20),
      (0.52, 0.30, 0.22, 0.20), (0.78, 0.30, 0.20, 0.20),
      (0.02, 0.54, 0.20, 0.18),
    ];
    for (final (bx, by, bw, bh) in blocks) {
      final x = w * bx + 4; final y = h * by + 4;
      final bww = w * bw - 8; final bhh = h * bh - 8;
      canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(x, y, bww, bhh),
              const Radius.circular(3)),
          Paint()..color = const Color(0xFF090D14));
      _drawWindows(canvas, x, y, bww, bhh, rng);
    }
  }

  void _drawWindows(Canvas canvas, double bx, double by,
      double bw, double bh, math.Random rng) {
    final cols = (bw / 13).floor().clamp(2, 6);
    final rows = (bh / 18).floor().clamp(2, 8);
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (rng.nextDouble() > 0.50) {
          final wx = bx + 5 + c * (bw - 10) / cols.clamp(1, 6);
          final wy = by + 7 + r * (bh - 10) / rows.clamp(1, 8);
          canvas.drawRect(Rect.fromLTWH(wx, wy, 5, 6),
              Paint()..color = const Color(0xFFFF8C00)
                  .withValues(alpha: 0.06 + rng.nextDouble() * 0.10));
        }
      }
    }
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  WIND ZONE RENDERER  (Phase 3 animated wind zones)
// ════════════════════════════════════════════════════════════════════════════
class WindZoneRenderer extends Component {
  final NoisePollutionGame game;
  double _t = 0;
  WindZoneRenderer({required this.game});

  @override
  void update(double dt) => _t += dt;

  @override
  void render(Canvas canvas) {
    if (game.gamePhase != 3) return;
    for (final zone in game.windZones) {
      if (!zone.isActive) continue;
      _drawZone(canvas, zone);
    }
  }

  void _drawZone(Canvas canvas, WindZone zone) {
    final cx   = zone.cx;
    final cy   = zone.cy;
    final r    = zone.radius;
    final col  = zone.color;
    final sf   = zone.strengthFactor * zone.fadeAlpha;
    final t    = _t + zone.angle; // unique phase per zone

    // ── 1. Soft haze fill ───────────────────────────────────────────────
    canvas.drawCircle(Offset(cx, cy), r,
        Paint()
          ..color = col.withValues(alpha: sf * 0.07)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22));

    // ── 2. Animated sine-wave stream lines ──────────────────────────────
    canvas.save();
    canvas.clipPath(Path()
        ..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r * 0.95)));

    final windDx = math.cos(zone.angle);
    final windDy = math.sin(zone.angle);
    final perpDx = -windDy;
    final perpDy =  windDx;

    const streamCount = 9;
    for (int i = 0; i < streamCount; i++) {
      final perpOff   = ((i / (streamCount - 1)) - 0.5) * 2.0 * r;
      final animPhase = (t * 0.65 + i * 0.111) % 1.0;
      final startAlong = -1.0 + animPhase * 2.0;

      final path = Path();
      const pts = 28;
      bool firstPt = true;
      for (int p = 0; p <= pts; p++) {
        final pct   = p / pts;
        final along = startAlong + pct * 2.2;
        final waveAmp = r * (0.07 + zone.strengthFactor * 0.06);
        final wave    = math.sin(pct * math.pi * 3.5 + t * 5.5 + i * 0.75) * waveAmp;

        final px = cx + along * r * windDx + perpOff * perpDx + wave * perpDx;
        final py = cy + along * r * windDy + perpOff * perpDy + wave * perpDy;

        if (firstPt) { path.moveTo(px, py); firstPt = false; }
        else {
          path.lineTo(px, py);
        }
      }

      final streamAlpha = sf * (0.20 + (i % 3 == 0 ? 0.10 : 0.0));
      canvas.drawPath(path, Paint()
        ..color      = col.withValues(alpha: streamAlpha)
        ..strokeWidth = 1.3 + (i % 2) * 0.5
        ..strokeCap  = StrokeCap.round
        ..style      = PaintingStyle.stroke);
    }

    // ── 3. Particle dots streaming in wind direction ─────────────────────
    const dotCount = 14;
    final dotPaint = Paint()..style = PaintingStyle.fill;
    for (int d = 0; d < dotCount; d++) {
      final phase   = (t * 0.9 + d * (1.0 / dotCount)) % 1.0;
      final perpOff = ((d / dotCount) - 0.5) * 1.8 * r;
      final along   = (phase * 2.0 - 1.0) * r;
      final px = cx + along * windDx + perpOff * perpDx;
      final py = cy + along * windDy + perpOff * perpDy;
      final dotAlpha = sf * (0.35 * (1.0 - math.pow(phase - 0.5, 2).abs() * 2));

      dotPaint.color = col.withValues(alpha: dotAlpha.clamp(0, 1));
      canvas.drawCircle(Offset(px, py), 2.0 + zone.strengthFactor * 1.5, dotPaint);
    }

    canvas.restore();

    // ── 4. Outer border ring ─────────────────────────────────────────────
    canvas.drawCircle(Offset(cx, cy), r, Paint()
      ..color       = col.withValues(alpha: sf * 0.38)
      ..style       = PaintingStyle.stroke
      ..strokeWidth = 1.8);

    // ── 5. Pulsing inner ring ────────────────────────────────────────────
    final pulse = 0.55 + math.sin(t * 3.2) * 0.30;
    canvas.drawCircle(Offset(cx, cy), r * 0.58 * pulse, Paint()
      ..color       = col.withValues(alpha: sf * 0.14 * pulse)
      ..style       = PaintingStyle.stroke
      ..strokeWidth = 1.0);

    // ── 6. Wind direction arrow ──────────────────────────────────────────
    final arX    = cx + windDx * r * 0.52;
    final arY    = cy + windDy * r * 0.52;
    const arLen  = 20.0;
    final arPaint = Paint()
      ..color       = col.withValues(alpha: sf * 0.75)
      ..strokeWidth = 2.2
      ..strokeCap   = StrokeCap.round;

    canvas.drawLine(
      Offset(arX - windDx * arLen * 0.5, arY - windDy * arLen * 0.5),
      Offset(arX + windDx * arLen * 0.5, arY + windDy * arLen * 0.5),
      arPaint,
    );
    const hLen = 7.0; const hAng = 0.55;
    final ex = arX + windDx * arLen * 0.5;
    final ey = arY + windDy * arLen * 0.5;
    canvas.drawLine(Offset(ex, ey), Offset(
      ex - hLen * math.cos(zone.angle + hAng),
      ey - hLen * math.sin(zone.angle + hAng),
    ), arPaint);
    canvas.drawLine(Offset(ex, ey), Offset(
      ex - hLen * math.cos(zone.angle - hAng),
      ey - hLen * math.sin(zone.angle - hAng),
    ), arPaint);

    // ── 7. Intensity label ──────────────────────────────────────────────
    final label = zone.intensity == WindIntensity.light
        ? '🌬️ LIGHT'
        : zone.intensity == WindIntensity.moderate
            ? '💨 WIND'
            : '🌪️ DANGER';
    final labelAlpha = sf * (0.65 + math.sin(t * 4) * 0.25);
    final tp = TextPainter(
      text: TextSpan(text: label, style: TextStyle(
        color: col.withValues(alpha: labelAlpha.clamp(0, 1)),
        fontSize: 9.5,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.0,
      )),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2 - r * 0.28));
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  ECO-DRONE COMPONENT  (enhanced: wind tilt, scan rings, charge arc)
// ════════════════════════════════════════════════════════════════════════════
class EcoDroneComponent extends Component {
  final NoisePollutionGame game;
  double _t = 0;
  EcoDroneComponent({required this.game});

  @override
  void update(double dt) => _t += dt;

  @override
  void render(Canvas canvas) {
    final baseCx = game.dronePos.x;
    final baseCy = game.dronePos.y + math.sin(_t * 3.2) * 2.5;

    // Wind tilt offset for visual effect
    final cx = baseCx + game.droneWindTiltX * 0.35;
    final cy = baseCy + game.droneWindTiltY * 0.35;

    // ── Scan ripple rings ────────────────────────────────────────────────
    for (final ring in game.scanRings) {
      if (ring.disrupted) {
        // Disrupted: ragged / broken ring
        _drawDisruptedRing(canvas, cx, cy, ring);
      } else {
        canvas.drawCircle(Offset(cx, cy), ring.radius,
            Paint()
              ..color = const Color(0xFF29B6F6).withValues(alpha: ring.alpha * 0.55)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.0);
      }
    }

    // ── Main scan pulse ──────────────────────────────────────────────────
    if (game.scanActive) {
      final alpha = (1.0 - game.scanRadius / NoisePollutionGame._scanMaxRadius) * 0.30;
      canvas.drawCircle(Offset(cx, cy), game.scanRadius,
          Paint()
            ..color = const Color(0xFF29B6F6).withValues(alpha: alpha)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5);
    }

    // ── Range indicator ──────────────────────────────────────────────────
    final inWind    = game.isInAnyWind;
    final windColor = game.isInBlockingWind
        ? const Color(0xFFEF5350)
        : inWind
            ? const Color(0xFFFFB300)
            : null;
    final rangeColor = windColor ??
        (game.gamePhase == 3
            ? const Color(0xFF29B6F6)
            : const Color(0xFF69F0AE));
    final rangeR = game.gamePhase == 3
        ? NoisePollutionGame._scanRange
        : NoisePollutionGame._applyRange;

    // Pulsing when near hotspot
    final hasTarget = game.gamePhase == 3
        ? game._hasNearbyUnscanned
        : game._hasNearbyUnfixed;
    final rangePulse = hasTarget ? (0.06 + math.sin(_t * 6) * 0.025) : 0.05;

    canvas.drawCircle(Offset(cx, cy), rangeR,
        Paint()
          ..color = rangeColor.withValues(alpha: rangePulse)
          ..style = PaintingStyle.stroke
          ..strokeWidth = hasTarget ? 1.8 : 1.1);

    // Range dash hints when close
    if (hasTarget) {
      _drawRangeDashes(canvas, cx, cy, rangeR, rangeColor);
    }

    canvas.save();
    // Wind tilt transform
    final tiltAngle = game.droneWindTiltX * 0.018;
    canvas.translate(cx, cy);
    canvas.rotate(tiltAngle);

    // Shadow
    canvas.drawOval(Rect.fromCenter(center: const Offset(0, 14),
        width: 38, height: 9),
        Paint()..color = Colors.black.withValues(alpha: 0.28));

    // Arms
    final armPaint = Paint()
      ..color = const Color(0xFF1C3A5C)
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;
    for (final (dx, dy) in [(-1, -1), (1, -1), (-1, 1), (1, 1)]) {
      canvas.drawLine(Offset(dx * 8.0, dy * 8.0),
          Offset(dx * 22.0, dy * 22.0), armPaint);
    }

    // Propellers (spin faster in wind)
    final propSpeed = 1.0 + (game.dominantWindZone?.strengthFactor ?? 0) * 2.5;
    final propPaint = Paint()
      ..color = const Color(0xFF90CAF9).withValues(
          alpha: 0.45 + math.sin(_t * 18 * propSpeed) * 0.10)
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    for (final (px, py) in [(-22.0, -22.0), (22.0, -22.0),
          (-22.0, 22.0), (22.0, 22.0)]) {
      final a = _t * 18 * propSpeed;
      final s = math.sin(a) * 8;
      final c = math.cos(a) * 8;
      canvas.drawLine(Offset(px - c, py - s), Offset(px + c, py + s), propPaint);
      canvas.drawLine(Offset(px - s, py + c), Offset(px + s, py - c), propPaint);
    }

    // Body
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(-13, -10, 26, 20), const Radius.circular(6)),
        Paint()..color = const Color(0xFF1E3A5F));

    // Scan charge arc
    if (game.gamePhase == 3) {
      _drawScanChargeArc(canvas);
    }

    // Glow
    final glowColor = game.isInBlockingWind
        ? const Color(0xFFEF5350)
        : game.isInAnyWind
            ? const Color(0xFFFFB300)
            : game.gamePhase == 3
                ? const Color(0xFF29B6F6)
                : const Color(0xFF69F0AE);
    canvas.drawCircle(Offset.zero, 7,
        Paint()
          ..color = glowColor.withValues(
              alpha: 0.75 + math.sin(_t * 4) * 0.20)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    canvas.drawCircle(Offset.zero, 3.5,
        Paint()..color = Colors.white.withValues(alpha: 0.95));

    // Mode icon
    final tp = TextPainter(
      text: TextSpan(
          text: game.gamePhase == 3 ? '📡' : '🔧',
          style: const TextStyle(fontSize: 8)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(-tp.width / 2, 13 - tp.height / 2));

    // Combo badge
    if (game.gamePhase == 3 && game.scanCombo >= 2) {
      _drawComboBadge(canvas, game.scanCombo);
    }

    canvas.restore();
  }

  void _drawScanChargeArc(Canvas canvas) {
    const arcR = 18.0;
    final chargeFrac = game.scanCharge.clamp(0.0, 1.0);
    final chargeColor = chargeFrac < 0.25
        ? const Color(0xFFEF5350)
        : chargeFrac < 0.60
            ? const Color(0xFFFFB300)
            : const Color(0xFF29B6F6);

    // Background arc
    canvas.drawArc(
        Rect.fromCenter(center: Offset(0, 0), width: arcR * 2, height: arcR * 2),
        -math.pi / 2, math.pi * 2, false,
        Paint()
          ..color       = Colors.white.withValues(alpha: 0.08)
          ..style       = PaintingStyle.stroke
          ..strokeWidth = 3.0
          ..strokeCap   = StrokeCap.round);

    // Charge fill arc
    if (chargeFrac > 0) {
      canvas.drawArc(
          Rect.fromCenter(center: Offset(0, 0), width: arcR * 2, height: arcR * 2),
          -math.pi / 2, math.pi * 2 * chargeFrac, false,
          Paint()
            ..color       = chargeColor.withValues(alpha: 0.80)
            ..style       = PaintingStyle.stroke
            ..strokeWidth = 3.0
            ..strokeCap   = StrokeCap.round);
    }
  }

  void _drawComboBadge(Canvas canvas, int combo) {
    const bx = 16.0; const by = -22.0;
    final color = combo >= 5 ? const Color(0xFFFF6D00) : const Color(0xFF69F0AE);

    canvas.drawCircle(const Offset(bx, by), 8.5,
        Paint()..color = const Color(0xFF0A1428).withValues(alpha: 0.90));
    canvas.drawCircle(const Offset(bx, by), 8.5,
        Paint()
          ..color       = color.withValues(alpha: 0.85)
          ..style       = PaintingStyle.stroke
          ..strokeWidth = 1.5);

    final tp = TextPainter(
      text: TextSpan(text: '×$combo',
          style: TextStyle(color: color, fontSize: 7, fontWeight: FontWeight.bold)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(bx - tp.width / 2, by - tp.height / 2));
  }

  void _drawRangeDashes(Canvas canvas, double cx, double cy,
      double r, Color color) {
    const dashCount = 12;
    final dashPaint = Paint()
      ..color       = color.withValues(alpha: 0.22)
      ..strokeWidth = 1.2
      ..strokeCap   = StrokeCap.round;
    for (int i = 0; i < dashCount; i++) {
      final a0 = (i / dashCount) * math.pi * 2 + _t;
      final a1 = a0 + 0.18;
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        a0, a1 - a0, false, dashPaint,
      );
    }
  }

  void _drawDisruptedRing(Canvas canvas, double cx, double cy, ScanRing ring) {
    const segments = 8;
    final paint = Paint()
      ..color       = const Color(0xFFEF5350).withValues(alpha: ring.alpha * 0.60)
      ..style       = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap   = StrokeCap.round;
    for (int i = 0; i < segments; i++) {
      if (i % 2 == 0) continue; // skip alternating for broken look
      final a0 = (i / segments) * math.pi * 2;
      final a1 = a0 + math.pi * 2 / segments * 0.7;
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: ring.radius),
        a0, a1 - a0, false, paint,
      );
    }
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  NOISE HOTSPOT COMPONENT  (traffic hotspots drift slowly)
// ════════════════════════════════════════════════════════════════════════════
class NoiseHotspot extends Component {
  final NoisePollutionGame game;
  final NoiseType type;
  double hx, hy;
  final int seed;
  bool isScanned = false;
  bool isFixed   = false;
  double _t      = 0;

  // Traffic hotspots drift along roads
  double _driftDir = 0;
  final bool _drifts;

  NoiseHotspot({
    required this.game, required this.type,
    required double worldX, required double worldY,
    required this.seed,
  })  : hx = worldX, hy = worldY,
        _drifts = type == NoiseType.traffic {
    final rng = math.Random(seed);
    _driftDir = rng.nextDouble() * math.pi * 2;
  }

  Vector2 get hotspotPos => Vector2(hx, hy);

  void reveal() => isScanned = true;
  void fix()    { isFixed = true; isScanned = true; }

  static const _specs = {
    NoiseType.traffic:      ('🚗', 'Vehicle\nHonking',    Color(0xFFEF5350), '85 dB'),
    NoiseType.construction: ('🏗️', 'Construction\nSite',  Color(0xFFFF6D00), '90 dB'),
    NoiseType.loudspeaker:  ('📢', 'Loud\nSpeaker',       Color(0xFFCE93D8), '78 dB'),
    NoiseType.vegetation:   ('🌿', 'Sparse\nVegetation',  Color(0xFF78909C), '72 dB'),
  };

  @override
  void update(double dt) {
    _t += dt;
    // Traffic hotspots move slowly on roads
    if (_drifts && !isFixed && game.gamePhase == 3) {
      final spd = 12.0;
      hx = (hx + math.cos(_driftDir) * spd * dt)
          .clamp(30, game.size.x - 30);
      hy = (hy + math.sin(_driftDir) * spd * dt * 0.3)
          .clamp(40, game.size.y * 0.84);
      // Bounce
      if (hx <= 32 || hx >= game.size.x - 32) _driftDir = math.pi - _driftDir;
    }
  }

  @override
  void render(Canvas canvas) {
    if (isFixed) { _drawFixed(canvas); return; }

    final spec  = _specs[type]!;
    final color = spec.$3;
    final pulse = 0.65 + math.sin(_t * 2.8) * 0.22;

    if (isScanned) {
      canvas.drawCircle(Offset(hx, hy), 36 * pulse,
          Paint()
            ..color = color.withValues(alpha: 0.07 + pulse * 0.05)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12));
      canvas.drawCircle(Offset(hx, hy), 28,
          Paint()..color = color.withValues(alpha: 0.15));
      canvas.drawCircle(Offset(hx, hy), 28,
          Paint()
            ..color = color.withValues(alpha: 0.70)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.2);

      // Sound wave rings emanating from hotspot
      for (int w = 1; w <= 3; w++) {
        final wR = 30.0 + w * 12 + math.sin(_t * 3 + w) * 5;
        canvas.drawCircle(Offset(hx, hy), wR,
            Paint()
              ..color = color.withValues(
                  alpha: 0.08 * (1 - w * 0.28) * pulse)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.0);
      }

      final ep = TextPainter(
        text: TextSpan(text: spec.$1, style: const TextStyle(fontSize: 14)),
        textDirection: TextDirection.ltr,
      )..layout();
      ep.paint(canvas, Offset(hx - ep.width / 2, hy - ep.height / 2 - 6));

      final dp = TextPainter(
        text: TextSpan(text: spec.$4,
            style: TextStyle(color: color, fontSize: 8.5,
                fontWeight: FontWeight.bold)),
        textDirection: TextDirection.ltr,
      )..layout();
      dp.paint(canvas, Offset(hx - dp.width / 2, hy + 14));

    } else {
      // Unscanned — show hidden signal
      canvas.drawCircle(Offset(hx, hy), 30 * pulse,
          Paint()
            ..color = const Color(0xFF90A4AE).withValues(alpha: 0.07)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9));
      canvas.drawCircle(Offset(hx, hy), 22,
          Paint()..color = const Color(0xFF90A4AE).withValues(alpha: 0.10));
      canvas.drawCircle(Offset(hx, hy), 22,
          Paint()
            ..color = const Color(0xFF90A4AE).withValues(alpha: 0.55)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.8);

      // Traffic drift indicator
      if (_drifts) {
        final mp = TextPainter(
          text: const TextSpan(text: '›',
              style: TextStyle(color: Color(0xFFEF5350),
                  fontSize: 12, fontWeight: FontWeight.bold)),
          textDirection: TextDirection.ltr,
        )..layout();
        mp.paint(canvas, Offset(hx + 14, hy - mp.height / 2));
      }

      final qp = TextPainter(
        text: const TextSpan(text: '?',
            style: TextStyle(color: Color(0xFF90A4AE),
                fontSize: 14, fontWeight: FontWeight.bold)),
        textDirection: TextDirection.ltr,
      )..layout();
      qp.paint(canvas, Offset(hx - qp.width / 2, hy - qp.height / 2));
    }
  }

  void _drawFixed(Canvas canvas) {
    canvas.drawCircle(Offset(hx, hy), 22,
        Paint()..color = const Color(0xFF69F0AE).withValues(alpha: 0.12));
    canvas.drawCircle(Offset(hx, hy), 22,
        Paint()
          ..color = const Color(0xFF69F0AE).withValues(alpha: 0.55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0);
    final tp = TextPainter(
      text: const TextSpan(text: '✅', style: TextStyle(fontSize: 13)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(hx - tp.width / 2, hy - tp.height / 2));
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  NOISE HUD  (enhanced: scan charge, wind indicator, combo badge)
// ════════════════════════════════════════════════════════════════════════════
class NoiseHud extends StatelessWidget {
  final NoisePollutionGame game;
  const NoiseHud(this.game, {super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: game,
      builder: (_, __) {
        final warn      = game.timeLeft < 20;
        final noiseRatio = (game.noiseMeter / 120.0).clamp(0.0, 1.0);
        final noiseColor = game.noiseMeter < 40
            ? const Color(0xFF69F0AE)
            : game.noiseMeter < 65
                ? const Color(0xFFFFB300)
                : const Color(0xFFEF5350);

        return SafeArea(child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch, children: [

            // Phase badge
            Align(alignment: Alignment.topCenter, child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
              decoration: BoxDecoration(
                color: game.gamePhase == 3
                    ? const Color(0xFF29B6F6).withValues(alpha: 0.88)
                    : const Color(0xFF69F0AE).withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(
                    color: (game.gamePhase == 3
                        ? const Color(0xFF29B6F6)
                        : const Color(0xFF69F0AE)).withValues(alpha: 0.35),
                    blurRadius: 10)],
              ),
              child: Text(
                game.gamePhase == 3
                    ? '📡  PHASE 3 — SOUND ANALYSIS'
                    : '🌿  PHASE 4 — NOISE REDUCTION',
                style: const TextStyle(color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 12, letterSpacing: 1.1),
              ),
            )),
            const SizedBox(height: 8),

            // Stat tiles
            Row(children: [
              _HTile(Icons.timer_rounded, '${game.timeLeft.toInt()}s', 'TIME',
                  warn ? Colors.red : Colors.white),
              const SizedBox(width: 6),
              _HTile(Icons.radar_rounded,
                  game.gamePhase == 3
                      ? '${game.scannedCount}/8'
                      : '${game.fixedCount}/8',
                  game.gamePhase == 3 ? 'SCANNED' : 'FIXED',
                  const Color(0xFF29B6F6)),
              const SizedBox(width: 6),
              _HTile(Icons.eco_rounded, '${game.ecoPoints}', 'ECO-PTS',
                  Colors.limeAccent),
              const SizedBox(width: 6),
              _HTile(Icons.volume_down_rounded,
                  '${game.noiseMeter.toStringAsFixed(0)} dB', 'NOISE',
                  noiseColor),
            ]),
            const SizedBox(height: 5),

            // Noise meter bar
            Row(children: [
              const Text('🔊', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Expanded(child: ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: LinearProgressIndicator(
                  value: 1.0 - noiseRatio,
                  backgroundColor: Colors.white12,
                  valueColor: AlwaysStoppedAnimation(noiseColor),
                  minHeight: 8,
                ),
              )),
              const SizedBox(width: 6),
              RichText(text: TextSpan(children: [
                TextSpan(text: '${game.noiseMeter.toStringAsFixed(0)} dB',
                    style: TextStyle(color: noiseColor, fontSize: 10,
                        fontWeight: FontWeight.bold)),
                const TextSpan(text: ' / 40 dB',
                    style: TextStyle(color: Color(0xFF69F0AE), fontSize: 8)),
              ])),
            ]),

            // ── Phase 3 extra row: scan charge + wind status + combo ──────
            if (game.gamePhase == 3) ...[
              const SizedBox(height: 5),
              Row(children: [
                // Scan charge bar
                _ScanChargeBar(charge: game.scanCharge),
                const SizedBox(width: 8),
                // Wind status pill
                _WindStatusPill(game: game),
                const SizedBox(width: 8),
                // Combo badge
                if (game.scanCombo >= 2)
                  _ComboBadge(combo: game.scanCombo),
              ]),
            ],
          ]),
        ));
      },
    );
  }
}

// ── Scan charge bar ──────────────────────────────────────────────────────────
class _ScanChargeBar extends StatelessWidget {
  final double charge;
  const _ScanChargeBar({required this.charge});

  @override
  Widget build(BuildContext context) {
    final frac  = charge.clamp(0.0, 1.0);
    final color = frac < 0.25
        ? const Color(0xFFEF5350)
        : frac < 0.60
            ? const Color(0xFFFFB300)
            : const Color(0xFF29B6F6);
    final label = frac < 0.18
        ? '⚡ CHARGING…'
        : frac < 0.60
            ? '⚡ ${(frac * 100).toInt()}%'
            : '⚡ SCAN READY';

    return Expanded(child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.40)),
      ),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min, children: [
          Text(label, style: TextStyle(color: color,
              fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
          const SizedBox(height: 3),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: frac,
              backgroundColor: Colors.white10,
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 5,
            ),
          ),
        ])),
      ]),
    ));
  }
}

// ── Wind status pill ─────────────────────────────────────────────────────────
class _WindStatusPill extends StatelessWidget {
  final NoisePollutionGame game;
  const _WindStatusPill({required this.game});

  @override
  Widget build(BuildContext context) {
    final inBlocking = game.isInBlockingWind;
    final inAny      = game.isInAnyWind;

    final Color color;
    final String label;
    if (inBlocking) {
      color = const Color(0xFFEF5350);
      label = '🌪️ EVADE!';
    } else if (inAny) {
      color = const Color(0xFFFFB300);
      label = '💨 LIGHT';
    } else {
      color = const Color(0xFF69F0AE);
      label = '🌬️ CLEAR';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.50)),
        boxShadow: inBlocking
            ? [BoxShadow(color: color.withValues(alpha: 0.25), blurRadius: 8)]
            : [],
      ),
      child: Text(label,
          style: TextStyle(color: color, fontSize: 9,
              fontWeight: FontWeight.bold, letterSpacing: 0.6)),
    );
  }
}

// ── Combo badge ──────────────────────────────────────────────────────────────
class _ComboBadge extends StatelessWidget {
  final int combo;
  const _ComboBadge({required this.combo});

  @override
  Widget build(BuildContext context) {
    final color = combo >= 5 ? const Color(0xFFFF6D00) : const Color(0xFF69F0AE);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.50)),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.22), blurRadius: 8)],
      ),
      child: Text('🔥 ×$combo COMBO',
          style: TextStyle(color: color, fontSize: 9,
              fontWeight: FontWeight.bold, letterSpacing: 0.6)),
    );
  }
}

class _HTile extends StatelessWidget {
  final IconData icon;
  final String val, label;
  final Color color;
  const _HTile(this.icon, this.val, this.label, this.color);

  @override
  Widget build(BuildContext context) => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
    decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12)),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: color, size: 14),
      Text(val, style: TextStyle(color: color,
          fontWeight: FontWeight.bold, fontSize: 13)),
      Text(label, style: const TextStyle(color: Colors.white54,
          fontSize: 8, letterSpacing: 0.8)),
    ]),
  ));
}

// ════════════════════════════════════════════════════════════════════════════
//  NOISE CONTROLS  (enhanced scan button with charge arc + wind warnings)
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
    _pulseCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 900))..repeat(reverse: true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _fk.requestFocus());
  }

  @override
  void dispose() {
    _fk.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

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
      widget.game.gamePhase == 3
          ? widget.game.scanHotspot()
          : widget.game.applyTool();
    }
    if (k == LogicalKeyboardKey.digit1 && pressed) {
      widget.game.selectTool(NoiseTool.electricMuffler);
    }
    if (k == LogicalKeyboardKey.digit2 && pressed) {
      widget.game.selectTool(NoiseTool.silentMachinery);
    }
    if (k == LogicalKeyboardKey.digit3 && pressed) {
      widget.game.selectTool(NoiseTool.silentZone);
    }
    if (k == LogicalKeyboardKey.digit4 && pressed) {
      widget.game.selectTool(NoiseTool.treeBarrier);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.game,
      builder: (_, __) {
        final phase  = widget.game.gamePhase;
        final canAct = phase == 3
            ? widget.game._hasNearbyUnscanned
            : widget.game._hasNearbyUnfixed;

        final inBlockingWind = widget.game.isInBlockingWind;
        final chargeOk       = widget.game.scanCharge >= 0.18;

        // Determine button state
        final String btnLabel;
        final Color  btnColor;
        final bool   btnEnabled;

        if (phase == 4) {
          btnLabel   = '🔧\nAPPLY';
          btnColor   = const Color(0xFF69F0AE);
          btnEnabled = canAct;
        } else if (inBlockingWind) {
          btnLabel   = '🌪️\nEVADE!';
          btnColor   = const Color(0xFFEF5350);
          btnEnabled = false;
        } else if (!chargeOk) {
          btnLabel   = '⚡\nCHRG…';
          btnColor   = const Color(0xFFFFB300);
          btnEnabled = false;
        } else {
          btnLabel   = '🔍\nSCAN';
          btnColor   = canAct
              ? const Color(0xFF29B6F6)
              : const Color(0xFF29B6F6).withValues(alpha: 0.55);
          btnEnabled = canAct;
        }

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
                  _DPad('⬆', _up, Colors.cyanAccent,
                      onDown: () { setState(() => _up = true);  widget.game.setUpKey(true); },
                      onUp:   () { setState(() => _up = false); widget.game.setUpKey(false); }),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    _DPad('◀', _lt, Colors.cyanAccent,
                        onDown: () { setState(() => _lt = true);  widget.game.setLeftKey(true); },
                        onUp:   () { setState(() => _lt = false); widget.game.setLeftKey(false); }),
                    const SizedBox(width: 4),
                    _DPad('⬇', _dn, Colors.cyanAccent,
                        onDown: () { setState(() => _dn = true);  widget.game.setDownKey(true); },
                        onUp:   () { setState(() => _dn = false); widget.game.setDownKey(false); }),
                    const SizedBox(width: 4),
                    _DPad('▶', _rt, Colors.cyanAccent,
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

                  // Wind evade streak hint
                  if (phase == 3 && widget.game.windEvades > 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF69F0AE).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: const Color(0xFF69F0AE).withValues(alpha: 0.35)),
                        ),
                        child: Text(
                          '💨 ×${widget.game.windEvades}',
                          style: const TextStyle(
                              color: Color(0xFF69F0AE),
                              fontSize: 10,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),

                  // Main action button
                  AnimatedBuilder(
                    animation: _pulseCtrl,
                    builder: (_, __) {
                      return GestureDetector(
                        onTap: () {
                          if (phase == 3) {
                            widget.game.scanHotspot();
                          } else {
                            widget.game.applyTool();
                          }
                        },
                        child: Stack(alignment: Alignment.center, children: [
                          // Charge arc (Phase 3)
                          if (phase == 3)
                            CustomPaint(
                              size: const Size(82, 82),
                              painter: _ChargeArcPainter(
                                charge: widget.game.scanCharge,
                                color: btnColor,
                                pulseT: _pulseCtrl.value,
                                inWind: inBlockingWind,
                              ),
                            ),

                          AnimatedContainer(
                            duration: const Duration(milliseconds: 140),
                            width: 68, height: 68,
                            decoration: BoxDecoration(
                              color: btnEnabled
                                  ? btnColor.withValues(alpha: 0.22)
                                  : Colors.black.withValues(alpha: 0.60),
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: btnEnabled
                                      ? btnColor
                                      : Colors.white24,
                                  width: btnEnabled ? 2.5 : 1.5),
                              boxShadow: btnEnabled
                                  ? [BoxShadow(
                                      color: btnColor.withValues(
                                          alpha: 0.35 + _pulseCtrl.value * 0.20),
                                      blurRadius: 16)]
                                  : [],
                            ),
                            child: Center(child: Text(btnLabel,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: btnEnabled
                                        ? btnColor
                                        : Colors.white30,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 9,
                                    letterSpacing: 0.4,
                                    height: 1.4))),
                          ),
                        ]),
                      );
                    },
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

// ── Charge arc painter around the SCAN button ─────────────────────────────────
class _ChargeArcPainter extends CustomPainter {
  final double charge, pulseT;
  final Color  color;
  final bool   inWind;
  const _ChargeArcPainter({
    required this.charge, required this.color,
    required this.pulseT, required this.inWind,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    const r  = 39.0;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);

    // Background track
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2, false,
        Paint()
          ..color       = Colors.white.withValues(alpha: 0.07)
          ..style       = PaintingStyle.stroke
          ..strokeWidth = 3.5
          ..strokeCap   = StrokeCap.round);

    // Charge fill
    final frac = charge.clamp(0.0, 1.0);
    if (frac > 0) {
      canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * frac, false,
          Paint()
            ..color       = inWind
                ? color.withValues(alpha: 0.5 + pulseT * 0.35)
                : color.withValues(alpha: 0.75)
            ..style       = PaintingStyle.stroke
            ..strokeWidth = 3.5
            ..strokeCap   = StrokeCap.round);
    }
  }

  @override
  bool shouldRepaint(_ChargeArcPainter old) =>
      old.charge != charge || old.pulseT != pulseT || old.inWind != inWind;
}

class _DPad extends StatelessWidget {
  final String label;
  final bool isActive;
  final Color color;
  final VoidCallback onDown, onUp;
  const _DPad(this.label, this.isActive, this.color,
      {required this.onDown, required this.onUp});

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown:   (_) => onDown(),
    onPointerUp:     (_) => onUp(),
    onPointerCancel: (_) => onUp(),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 70),
      width: 52, height: 52,
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: isActive
            ? color.withValues(alpha: 0.30)
            : Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: isActive ? color : Colors.white24, width: 1.8),
        boxShadow: isActive
            ? [BoxShadow(color: color.withValues(alpha: 0.40), blurRadius: 10)]
            : [],
      ),
      child: Center(child: Text(label,
          style: TextStyle(
              color: isActive ? color : Colors.white60,
              fontSize: 16, fontWeight: FontWeight.bold))),
    ),
  );
}

// ════════════════════════════════════════════════════════════════════════════
//  PHASE BANNER  (updated Phase 3 description with wind mechanic hint)
// ════════════════════════════════════════════════════════════════════════════
class NoisePhaseBanner extends StatelessWidget {
  final NoisePollutionGame game;
  const NoisePhaseBanner(this.game, {super.key});

  @override
  Widget build(BuildContext context) {
    final phase3 = game.gamePhase == 3;
    final accent = phase3 ? const Color(0xFF29B6F6) : const Color(0xFF69F0AE);

    return IgnorePointer(child: Center(child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: phase3
            ? [const Color(0xFF001A2E), const Color(0xFF003050)]
            : [const Color(0xFF001A0A), const Color(0xFF003018)]),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 24)],
        border: Border.all(color: accent.withValues(alpha: 0.55), width: 1.5),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(phase3 ? 'PHASE 3' : 'PHASE 4',
            style: const TextStyle(color: Colors.white54,
                fontSize: 13, letterSpacing: 2.5)),
        const SizedBox(height: 4),
        Text(phase3 ? '📡  Sound Analysis' : '🌿  Noise Reduction',
            style: const TextStyle(color: Colors.white,
                fontSize: 26, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text(
          phase3
              ? 'Navigate near hotspots then tap 🔍 SCAN.\n'
                '💨 Wind zones BLOCK scanning — evade them first!\n'
                'Traffic hotspots MOVE. Build scan combos for bonus points.'
              : 'Select the correct tool and tap 🔧 APPLY\nwhen near each hotspot.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.5),
        ),
        if (phase3) ...[
          const SizedBox(height: 10),
          Row(mainAxisSize: MainAxisSize.min, children: const [
            _WindLegendDot(color: Color(0xFF80DEEA), label: 'Light — safe'),
            SizedBox(width: 14),
            _WindLegendDot(color: Color(0xFFFFB300), label: 'Moderate — risky'),
            SizedBox(width: 14),
            _WindLegendDot(color: Color(0xFFEF5350), label: 'Heavy — blocked'),
          ]),
        ],
      ]),
    )));
  }
}

class _WindLegendDot extends StatelessWidget {
  final Color  color;
  final String label;
  const _WindLegendDot({required this.color, required this.label});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min,
    children: [
      Container(width: 8, height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(color: color, fontSize: 9,
          fontWeight: FontWeight.w600)),
    ],
  );
}

// ════════════════════════════════════════════════════════════════════════════
//  NOISE TOOL SELECTOR  (Phase 4 — unchanged logic)
// ════════════════════════════════════════════════════════════════════════════
class NoiseToolSelector extends StatelessWidget {
  final NoisePollutionGame game;
  const NoiseToolSelector(this.game, {super.key});

  static const _tools = [
    (NoiseTool.electricMuffler, '⚡', 'Electric\nMuffler', Color(0xFF29B6F6),  'Traffic'),
    (NoiseTool.silentMachinery, '🔕', 'Silent\nMachinery', Color(0xFFFF6D00),  'Construction'),
    (NoiseTool.silentZone,      '🚫', 'Silent\nZone',      Color(0xFFCE93D8),  'Loudspeaker'),
    (NoiseTool.treeBarrier,     '🌲', 'Tree\nBarrier',     Color(0xFF69F0AE),  'Vegetation'),
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
            padding: const EdgeInsets.only(bottom: 80, left: 12, right: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.78),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('SELECT INTERVENTION TOOL',
                    style: TextStyle(color: Colors.white54,
                        fontSize: mobile ? 7.5 : 9,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Row(mainAxisAlignment: MainAxisAlignment.center,
                    children: _tools.map((t) {
                  final (tool, emoji, label, color, target) = t;
                  final sel = game.selectedTool == tool;
                  return GestureDetector(
                    onTap: () => game.selectTool(tool),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 140),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: EdgeInsets.symmetric(
                          horizontal: mobile ? 9 : 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: sel
                            ? color.withValues(alpha: 0.22)
                            : Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: sel ? color : Colors.white12,
                            width: sel ? 2.0 : 1.0),
                        boxShadow: sel
                            ? [BoxShadow(color: color.withValues(alpha: 0.35),
                                blurRadius: 10)]
                            : [],
                      ),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(emoji, style: TextStyle(
                            fontSize: mobile ? 18 : 22)),
                        const SizedBox(height: 2),
                        Text(label,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: sel ? color : Colors.white70,
                              fontWeight: FontWeight.w900,
                              fontSize: mobile ? 7.5 : 9,
                              height: 1.2,
                            )),
                        const SizedBox(height: 1),
                        Text(target,
                            style: TextStyle(
                              color: sel
                                  ? color.withValues(alpha: 0.75)
                                  : Colors.white38,
                              fontSize: 7,
                            )),
                      ]),
                    ),
                  );
                }).toList()),
              ]),
            ),
          )),
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  REACTION FLASH  (redesigned with ReactionKind)
// ════════════════════════════════════════════════════════════════════════════
class NoiseReactionFx extends StatelessWidget {
  final NoisePollutionGame game;
  const NoiseReactionFx(this.game, {super.key});

  @override
  Widget build(BuildContext context) {
    final String title;
    final String sub;
    final Color  accent;

    switch (game.reactionKind) {
      case ReactionKind.windBlock:
        title  = '🌪️  SCAN DISRUPTED!';
        sub    = 'Escape the wind zone first — then scan';
        accent = const Color(0xFFEF5350);
        break;
      case ReactionKind.noCharge:
        title  = '⚡  SCANNER CHARGING…';
        sub    = 'Wait a moment for charge to refill';
        accent = const Color(0xFFFFB300);
        break;
      case ReactionKind.scanMiss:
        title  = '📡  OUT OF RANGE!';
        sub    = 'Move closer to a hotspot first';
        accent = const Color(0xFF78909C);
        break;
      case ReactionKind.scanHit:
        final c = game.reactionCombo;
        title  = c >= 3 ? '🔥  COMBO ×$c  —  SCAN HIT!' : '📡  IDENTIFIED!';
        sub    = c >= 3
            ? '+${5 + c * 3} Eco-Points  •  Combo Bonus!'
            : '+5 Eco-Points per source revealed';
        accent = const Color(0xFF29B6F6);
        break;
      case ReactionKind.windEvade:
        title  = '💨  WIND EVADED!';
        sub    = '+3 Eco-Points  •  Nimble Navigator!';
        accent = const Color(0xFF69F0AE);
        break;
      case ReactionKind.fixCorrect:
        title  = '✅  NOISE REDUCED!';
        sub    = '+15 Eco-Points  •  Decibels dropped';
        accent = const Color(0xFF69F0AE);
        break;
      case ReactionKind.fixWrong:
        title  = '❌  WRONG TOOL!';
        sub    = '−10 Eco-Points  •  Noise spike';
        accent = const Color(0xFFEF5350);
        break;
    }

    final isPositive = game.reactionCorrect;

    // Wind evade is a small non-intrusive toast at top
    if (game.reactionKind == ReactionKind.windEvade) {
      return IgnorePointer(child: Align(
        alignment: Alignment.topCenter,
        child: SafeArea(child: Padding(
          padding: const EdgeInsets.only(top: 80),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF0A2E1A).withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: accent.withValues(alpha: 0.60)),
              boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.25),
                  blurRadius: 12)],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(title, style: TextStyle(color: accent,
                  fontWeight: FontWeight.bold, fontSize: 13)),
            ]),
          ),
        )),
      ));
    }

    return IgnorePointer(child: Stack(children: [
      Container(decoration: BoxDecoration(
        border: Border.all(color: accent.withValues(alpha: 0.55), width: 8),
        gradient: RadialGradient(colors: [
          Colors.transparent,
          accent.withValues(alpha: 0.10),
        ], radius: 1.5),
      )),
      Center(child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
        decoration: BoxDecoration(
            color: isPositive
                ? const Color(0xFF0A2E1A).withValues(alpha: 0.95)
                : const Color(0xFF2E0A0A).withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [BoxShadow(color: Colors.black54,
                blurRadius: 14, spreadRadius: 2)]),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(title,
              style: const TextStyle(color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20, letterSpacing: 0.8)),
          const SizedBox(height: 4),
          Text(sub,
              style: TextStyle(color: accent, fontSize: 13,
                  fontWeight: FontWeight.w600)),
        ]),
      )),
    ]));
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  NOISE RESULTS OVERLAY  (+ wind evasion & combo max stats)
// ════════════════════════════════════════════════════════════════════════════
class NoiseResultsOverlay extends StatelessWidget {
  final NoisePollutionGame game;
  const NoiseResultsOverlay(this.game, {super.key});

  @override
  Widget build(BuildContext context) {
    final result   = NoiseResult.current!;
    final peaceful = result.peacefulCityBadge;
    final dbFinal  = result.noiseMeterFinal.toStringAsFixed(0);

    return Container(
      color: Colors.black.withValues(alpha: 0.94),
      child: SafeArea(child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Column(children: [

          // Title card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: peaceful
                  ? [const Color(0xFF001A0A), const Color(0xFF003018)]
                  : [const Color(0xFF1A1000), const Color(0xFF2A1800)]),
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 16)],
            ),
            child: Column(children: [
              Text(peaceful ? '🕊️' : '🔊',
                  style: const TextStyle(fontSize: 52)),
              const SizedBox(height: 8),
              Text(peaceful ? 'City Restored to Peace!' : 'Phase Complete',
                  style: const TextStyle(color: Colors.white, fontSize: 22,
                      fontWeight: FontWeight.bold, letterSpacing: 0.8)),
              const SizedBox(height: 4),
              const Text('Phase 3 & 4 — Noise Pollution Results',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
              if (peaceful) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF69F0AE).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF69F0AE)
                        .withValues(alpha: 0.40)),
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('🏅', style: TextStyle(fontSize: 14)),
                    SizedBox(width: 6),
                    Text('Peaceful City Badge Unlocked!',
                        style: TextStyle(color: Color(0xFF69F0AE),
                            fontWeight: FontWeight.w800, fontSize: 12)),
                  ]),
                ),
              ],
            ]),
          ),

          const SizedBox(height: 16),

          // Core stats
          _NRCard(children: [
            _NRBig('🔊', '$dbFinal dB', 'Final Noise',
                peaceful ? const Color(0xFF69F0AE) : const Color(0xFFFFB300)),
            _NRBig('✅', '${result.hotspotsFix}', 'Fixed',    Colors.limeAccent),
            _NRBig('❌', '${result.wrongTools}',  'Errors',   Colors.redAccent),
            _NRBig('⭐', '${result.ecoPoints}',   'Eco-Pts',  Colors.amber),
          ]),

          const SizedBox(height: 10),

          // Phase 3 wind challenge stats
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF0A1828),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF29B6F6).withValues(alpha: 0.22)),
            ),
            child: Column(children: [
              const Text('PHASE 3 — SOUND ANALYSIS',
                  style: TextStyle(color: Color(0xFF29B6F6), fontSize: 10,
                      fontWeight: FontWeight.bold, letterSpacing: 1.5)),
              const SizedBox(height: 10),
              Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                _NRBig('💨', '${result.windEvades}',   'Wind Evaded',  const Color(0xFF80DEEA)),
                _NRBig('🔥', '×${result.scanComboMax}','Best Combo',   const Color(0xFFFF6D00)),
                _NRBig('📡', '8/8', 'Scanned', const Color(0xFF29B6F6)),
              ]),
            ]),
          ),

          const SizedBox(height: 10),

          // Interventions applied
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0A1E10),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(children: [
              const Text('Interventions Applied',
                  style: TextStyle(color: Colors.white70, fontSize: 12,
                      fontWeight: FontWeight.bold, letterSpacing: 1)),
              const SizedBox(height: 12),
              _NRRow('🚗', 'Vehicle Honking',    '⚡ Electric upgrade / mufflers'),
              _NRRow('🏗️', 'Construction Sites', '🔕 Silent machinery deployed'),
              _NRRow('📢', 'Loudspeakers',       '🚫 Silent zones established'),
              _NRRow('🌲', 'Vegetation Zones',   '🌿 Tree lines & barriers planted'),
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
              icon: const Icon(Icons.emoji_events_rounded),
              label: const Text('Complete Level 4  →',
                  style: TextStyle(fontSize: 15,
                      fontWeight: FontWeight.bold, letterSpacing: 0.8)),
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
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: children),
  );
}

class _NRBig extends StatelessWidget {
  final String emoji, value, label;
  final Color color;
  const _NRBig(this.emoji, this.value, this.label, this.color);
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

class _NRRow extends StatelessWidget {
  final String emoji, label, action;
  const _NRRow(this.emoji, this.label, this.action);
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