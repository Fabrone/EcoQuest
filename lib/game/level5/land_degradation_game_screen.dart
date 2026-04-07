import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:ecoquest/game/level5/degraded_land_screen.dart';
import 'package:ecoquest/game/level5/soil_pollution_screen.dart';
import 'package:flame/components.dart' hide Matrix4;
import 'package:flame/game.dart' hide Matrix4;
import 'package:flutter/material.dart' hide Matrix4;
import 'package:flutter/services.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  LAND DEGRADATION RESULT  — passed to SoilPollutionScreen
// ══════════════════════════════════════════════════════════════════════════════
class LandDegradationResult {
  final int patchesRestored;
  final int wrongTools;
  final int ecoPoints;
  final double erosionIndex;
  final bool terrainStabilised;

  const LandDegradationResult({
    required this.patchesRestored,
    required this.wrongTools,
    required this.ecoPoints,
    required this.erosionIndex,
    required this.terrainStabilised,
  });

  static LandDegradationResult? current;
}

// ══════════════════════════════════════════════════════════════════════════════
//  ENUMS
// ══════════════════════════════════════════════════════════════════════════════
enum DegradationType { steepSlope, gully, bareLand, drySoil }
enum RestorationTool { terrace, checkDam, coverCrop, biochar }

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
          'hud':         (ctx, g) => LandHud(g as LandDegradationGame),
          'controls':    (ctx, g) => LandControls(g as LandDegradationGame),
          'banner':      (ctx, g) => LandPhaseBanner(g as LandDegradationGame),
          'toolSelect':  (ctx, g) => RestorationToolSelector(g as LandDegradationGame),
          'reactionFx':  (ctx, g) => LandReactionFx(g as LandDegradationGame),
          'results':     (ctx, g) => LandResultsOverlay(g as LandDegradationGame),
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

  // ── State ─────────────────────────────────────────────────────────────────
  int    gamePhase   = 1;   // 1 = survey, 2 = restore
  bool   gameStarted = false;
  double timeLeft    = 120.0;
  bool   levelDone   = false;

  // ── Score ─────────────────────────────────────────────────────────────────
  int ecoPoints      = 0;
  int wrongTools     = 0;
  int restoredCount  = 0;
  int scannedCount   = 0;

  // ── Erosion meter ─────────────────────────────────────────────────────────
  double erosionIndex = 92.0;
  static const double _targetErosion  = 20.0;
  static const double _fixReduction   = 9.0;
  static const double _wrongPenalty   = 4.0;

  // ── Range constants ───────────────────────────────────────────────────────
  static const double _scanRange   = 155.0;
  static const double _applyRange  = 100.0;

  // ── Drone physics ─────────────────────────────────────────────────────────
  late Vector2 dronePos;
  bool isUp = false, isDown = false, isLeft = false, isRight = false;
  static const double _droneSpeed = 185.0;

  // ── Tool selection ────────────────────────────────────────────────────────
  RestorationTool selectedTool = RestorationTool.terrace;

  // ── Reaction FX ──────────────────────────────────────────────────────────
  bool   reactionActive  = false;
  bool   reactionCorrect = false;
  int    reactionPhase   = 1;
  bool   reactionInRange = true;
  double reactionTimer   = 0;

  // ── Banner ────────────────────────────────────────────────────────────────
  double bannerTimer = 3.5;

  // ── Scan animation ────────────────────────────────────────────────────────
  bool   scanActive  = false;
  double scanRadius  = 0;
  static const double _scanMaxRadius = 180.0;

  // ── Components ────────────────────────────────────────────────────────────
  late RestorationDroneComponent drone;
  final List<DegradedPatch> patches = [];

  @override
  Future<void> onLoad() async {
    super.onLoad();
    dronePos = Vector2(size.x * 0.50, size.y * 0.58);

    add(ErodedLandRenderer(game: this));
    drone = RestorationDroneComponent(game: this);
    add(drone);

    _spawnPatches();

    bannerTimer = 3.5;
    overlays.add('banner');
    add(TimerComponent(period: 1.0, repeat: true, onTick: _onSecond));
  }

  void _spawnPatches() {
    final specs = [
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

  bool get _hasNearbyUnscanned =>
      patches.any((p) => !p.isScanned &&
          (p.patchPos - dronePos).length <= _scanRange);

  bool get _hasNearbyUnrestored =>
      patches.any((p) => !p.isRestored &&
          (p.patchPos - dronePos).length <= _applyRange);

  DegradedPatch? get _nearestUnrestored {
    DegradedPatch? target;
    double best = _applyRange;
    for (final p in patches) {
      if (p.isRestored) continue;
      final d = (p.patchPos - dronePos).length;
      if (d < best) { best = d; target = p; }
    }
    return target;
  }

  // ── Phase 1 — Survey ──────────────────────────────────────────────────────
  void surveyPatch() {
    if (!gameStarted || levelDone || gamePhase != 1) return;
    gameStarted = true;
    HapticFeedback.selectionClick();

    int newly = 0;
    for (final p in patches) {
      if (p.isScanned) continue;
      if ((p.patchPos - dronePos).length <= _scanRange) {
        p.reveal();
        scannedCount++;
        newly++;
      }
    }

    if (newly > 0) {
      ecoPoints += newly * 5;
      scanActive = true;
      scanRadius = 0;
      _triggerReaction(true);
      if (scannedCount >= patches.length) {
        Future.delayed(const Duration(milliseconds: 900), _advanceToPhase2);
      }
    } else {
      _triggerReaction(false, inRange: false);
    }
    notifyListeners();
  }

  void _advanceToPhase2() {
    if (levelDone) return;
    gamePhase   = 2;
    bannerTimer = 3.0;
    overlays
      ..add('banner')
      ..add('toolSelect');
    notifyListeners();
  }

  // ── Phase 2 — Restore ─────────────────────────────────────────────────────
  void applyTool() {
    if (!gameStarted || levelDone || gamePhase != 2) return;
    final target = _nearestUnrestored;
    if (target == null) { _triggerReaction(false, inRange: false); return; }

    HapticFeedback.lightImpact();
    final correct = _isCorrectTool(target.type, selectedTool);
    if (correct) {
      target.restore();
      restoredCount++;
      erosionIndex = math.max(0, erosionIndex - _fixReduction);
      ecoPoints += 10;
      _triggerReaction(true);
    } else {
      wrongTools++;
      erosionIndex = math.min(100, erosionIndex + _wrongPenalty);
      ecoPoints    = math.max(0, ecoPoints - 5);
      _triggerReaction(false);
    }

    final allDone = patches.every((p) => p.isRestored);
    if (erosionIndex <= _targetErosion || allDone) {
      Future.delayed(const Duration(milliseconds: 800), _endLevel);
    }
    notifyListeners();
  }

  bool _isCorrectTool(DegradationType t, RestorationTool tool) {
    switch (t) {
      case DegradationType.steepSlope: return tool == RestorationTool.terrace;
      case DegradationType.gully:      return tool == RestorationTool.checkDam;
      case DegradationType.bareLand:   return tool == RestorationTool.coverCrop;
      case DegradationType.drySoil:    return tool == RestorationTool.biochar;
    }
  }

  void selectTool(RestorationTool t) { selectedTool = t; notifyListeners(); }

  // ── Input ─────────────────────────────────────────────────────────────────
  void setUpKey(bool v)    { isUp    = v; if (v) gameStarted = true; }
  void setDownKey(bool v)  { isDown  = v; if (v) gameStarted = true; }
  void setLeftKey(bool v)  { isLeft  = v; if (v) gameStarted = true; }
  void setRightKey(bool v) { isRight = v; if (v) gameStarted = true; }

  void _triggerReaction(bool correct, {bool inRange = true}) {
    reactionActive  = true;
    reactionCorrect = correct;
    reactionPhase   = gamePhase;
    reactionInRange = inRange;
    reactionTimer   = 1.2;
    overlays.add('reactionFx');
  }

  void _endLevel() {
    if (levelDone) return;
    levelDone = true;
    pauseEngine();

    LandDegradationResult.current = LandDegradationResult(
      patchesRestored:   restoredCount,
      wrongTools:        wrongTools,
      ecoPoints:         ecoPoints,
      erosionIndex:      erosionIndex,
      terrainStabilised: erosionIndex <= _targetErosion,
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

    if (!gameStarted || levelDone) return;

    double vx = 0, vy = 0;
    if (isLeft)  vx -= 1; if (isRight) vx += 1;
    if (isUp)    vy -= 1; if (isDown)  vy += 1;
    dronePos.x = (dronePos.x + vx * _droneSpeed * dt).clamp(30, size.x - 30);
    dronePos.y = (dronePos.y + vy * _droneSpeed * dt).clamp(40, size.y * 0.88);

    notifyListeners();
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  ERODED LAND RENDERER
// ════════════════════════════════════════════════════════════════════════════
class ErodedLandRenderer extends Component {
  final LandDegradationGame game;
  double _t = 0;
  ErodedLandRenderer({required this.game});

  @override
  void update(double dt) => _t += dt * 0.25;

  @override
  void render(Canvas canvas) {
    final w = game.size.x;
    final h = game.size.y;

    // Sky — dusty amber-brown haze
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h),
        Paint()
          ..shader = ui.Gradient.linear(Offset(0, 0), Offset(0, h), [
            const Color(0xFF120A04),
            Color.lerp(const Color(0xFF1E1008), const Color(0xFF2A1404),
                (math.sin(_t) * 0.5 + 0.5) * 0.4)!,
            const Color(0xFF0A0602),
          ], [0.0, 0.5, 1.0]));

    // Erosion tint — red when high, fades as land heals
    final erosionRatio = (game.erosionIndex / 92.0).clamp(0.0, 1.0);
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h),
        Paint()
          ..color = const Color(0xFFEF5350).withValues(alpha: erosionRatio * 0.04)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30));

    // Terrain grid roads / paths
    _drawTerrainPaths(canvas, w, h);

    // Barren land blocks
    _drawBarrenBlocks(canvas, w, h);

    // Ground strip
    canvas.drawRect(Rect.fromLTWH(0, h * 0.86, w, h * 0.14),
        Paint()..color = const Color(0xFF080602));
  }

  void _drawTerrainPaths(Canvas canvas, double w, double h) {
    final pathPaint = Paint()
      ..color = const Color(0xFF0E0904)
      ..strokeWidth = 10;
    // Dirt tracks across the terrain
    for (final ry in [0.30, 0.55, 0.76]) {
      canvas.drawLine(Offset(0, h * ry), Offset(w, h * ry), pathPaint);
    }
    for (final rx in [0.25, 0.52, 0.78]) {
      canvas.drawLine(Offset(w * rx, 0), Offset(w * rx, h * 0.86), pathPaint);
    }
  }

  void _drawBarrenBlocks(Canvas canvas, double w, double h) {
    final rng = math.Random(44);
    final blocks = [
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
      // Cracked soil texture
      _drawCracks(canvas, w * bx + 6, h * by + 6,
          w * bw - 12, h * bh - 12, rng);
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
      final len = 8 + rng.nextDouble() * 14;
      final angle = rng.nextDouble() * math.pi;
      canvas.drawLine(
        Offset(cx, cy),
        Offset(cx + math.cos(angle) * len, cy + math.sin(angle) * len), p,
      );
    }
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  RESTORATION DRONE COMPONENT
// ════════════════════════════════════════════════════════════════════════════
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

    if (game.scanActive) {
      final alpha =
          (1.0 - game.scanRadius / LandDegradationGame._scanMaxRadius) * 0.30;
      canvas.drawCircle(Offset(cx, cy), game.scanRadius,
          Paint()
            ..color = const Color(0xFFFFB300).withValues(alpha: alpha)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5);
    }

    final rangeColor = game.gamePhase == 1
        ? const Color(0xFFFFB300)
        : const Color(0xFF69F0AE);
    final rangeR = game.gamePhase == 1
        ? LandDegradationGame._scanRange
        : LandDegradationGame._applyRange;
    canvas.drawCircle(Offset(cx, cy), rangeR,
        Paint()
          ..color = rangeColor.withValues(alpha: 0.06)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2);

    canvas.save();
    canvas.translate(cx, cy);

    // Shadow
    canvas.drawOval(
        Rect.fromCenter(center: const Offset(0, 14), width: 38, height: 9),
        Paint()..color = Colors.black.withValues(alpha: 0.28));

    // Arms
    final armPaint = Paint()
      ..color = const Color(0xFF3A2810)
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;
    for (final (dx, dy) in [(-1, -1), (1, -1), (-1, 1), (1, 1)]) {
      canvas.drawLine(
          Offset(dx * 8, dy * 8), Offset(dx * 22, dy * 22), armPaint);
    }

    // Propellers
    final propPaint = Paint()
      ..color = const Color(0xFFFFB300).withValues(alpha: 0.55)
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    for (final (px, py) in [(-22.0, -22.0), (22.0, -22.0),
          (-22.0, 22.0), (22.0, 22.0)]) {
      canvas.drawLine(Offset(px - 8, py), Offset(px + 8, py), propPaint);
      canvas.drawLine(Offset(px, py - 8), Offset(px, py + 8), propPaint);
    }

    // Body
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(-13, -10, 26, 20), const Radius.circular(6)),
        Paint()..color = const Color(0xFF2A1C0A));

    // Sensor glow
    final glowColor = game.gamePhase == 1
        ? const Color(0xFFFFB300)
        : const Color(0xFF69F0AE);
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

// ════════════════════════════════════════════════════════════════════════════
//  DEGRADED PATCH COMPONENT
// ════════════════════════════════════════════════════════════════════════════
class DegradedPatch extends Component {
  final LandDegradationGame game;
  final DegradationType type;
  double hx, hy;
  final int seed;
  bool isScanned   = false;
  bool isRestored  = false;
  double _t = 0;

  DegradedPatch({
    required this.game, required this.type,
    required double worldX, required double worldY,
    required this.seed,
  }) : hx = worldX, hy = worldY;

  Vector2 get patchPos => Vector2(hx, hy);

  void reveal()  => isScanned = true;
  void restore() { isRestored = true; isScanned = true; }

  static const _specs = {
    DegradationType.steepSlope: ('🏔️', 'Steep\nSlope',  Color(0xFFEF5350), 'High'),
    DegradationType.gully:      ('🕳️', 'Erosion\nGully', Color(0xFFFF6D00), 'Severe'),
    DegradationType.bareLand:   ('🌾', 'Bare\nLand',    Color(0xFFFFB300), 'Med'),
    DegradationType.drySoil:    ('🪨', 'Dry\nSoil',     Color(0xFFBCAAA4), 'Low'),
  };

  @override
  void update(double dt) => _t += dt;

  @override
  void render(Canvas canvas) {
    if (isRestored) { _drawRestored(canvas); return; }

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
      // Unknown patch — amber pulsing ring
      canvas.drawCircle(Offset(hx, hy), 30 * pulse,
          Paint()
            ..color = const Color(0xFFBCAAA4).withValues(alpha: 0.07)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9));
      canvas.drawCircle(Offset(hx, hy), 22,
          Paint()..color = const Color(0xFFBCAAA4).withValues(alpha: 0.10));
      canvas.drawCircle(Offset(hx, hy), 22,
          Paint()
            ..color = const Color(0xFFBCAAA4).withValues(alpha: 0.55)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.8);
      final qp = TextPainter(
        text: const TextSpan(text: '?',
            style: TextStyle(color: Color(0xFFBCAAA4),
                fontSize: 14, fontWeight: FontWeight.bold)),
        textDirection: TextDirection.ltr,
      )..layout();
      qp.paint(canvas, Offset(hx - qp.width / 2, hy - qp.height / 2));
    }
  }

  void _drawRestored(Canvas canvas) {
    canvas.drawCircle(Offset(hx, hy), 22,
        Paint()..color = const Color(0xFF69F0AE).withValues(alpha: 0.14));
    canvas.drawCircle(Offset(hx, hy), 22,
        Paint()
          ..color = const Color(0xFF69F0AE).withValues(alpha: 0.60)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0);
    final tp = TextPainter(
      text: const TextSpan(text: '🌿', style: TextStyle(fontSize: 13)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(hx - tp.width / 2, hy - tp.height / 2));
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  HUD
// ════════════════════════════════════════════════════════════════════════════
class LandHud extends StatelessWidget {
  final LandDegradationGame game;
  const LandHud(this.game, {super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: game,
      builder: (_, __) {
        final warn        = game.timeLeft < 20;
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

            Align(alignment: Alignment.topCenter, child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
              decoration: BoxDecoration(
                color: game.gamePhase == 1
                    ? const Color(0xFFFFB300).withValues(alpha: 0.88)
                    : const Color(0xFF69F0AE).withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(
                    color: (game.gamePhase == 1
                        ? const Color(0xFFFFB300)
                        : const Color(0xFF69F0AE)).withValues(alpha: 0.35),
                    blurRadius: 10)],
              ),
              child: Text(
                game.gamePhase == 1
                    ? '🛰️  PHASE 1 — LAND SURVEY'
                    : '🪨  PHASE 2 — TERRAIN RESTORATION',
                style: const TextStyle(color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 12, letterSpacing: 1.1),
              ),
            )),
            const SizedBox(height: 8),

            Row(children: [
              _LHTile(Icons.timer_rounded, '${game.timeLeft.toInt()}s', 'TIME',
                  warn ? Colors.red : Colors.white),
              const SizedBox(width: 6),
              _LHTile(Icons.radar_rounded,
                  game.gamePhase == 1
                      ? '${game.scannedCount}/8'
                      : '${game.restoredCount}/8',
                  game.gamePhase == 1 ? 'SCANNED' : 'RESTORED',
                  const Color(0xFFFFB300)),
              const SizedBox(width: 6),
              _LHTile(Icons.eco_rounded, '${game.ecoPoints}', 'ECO-PTS',
                  Colors.limeAccent),
              const SizedBox(width: 6),
              _LHTile(Icons.terrain_rounded,
                  '${game.erosionIndex.toStringAsFixed(0)}%', 'EROSION',
                  erosionColor),
            ]),
            const SizedBox(height: 5),

            // Erosion index bar
            Row(children: [
              const Text('🏜️', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Expanded(child: ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: LinearProgressIndicator(
                  value: 1.0 - erosionRatio,
                  backgroundColor: Colors.white12,
                  valueColor: AlwaysStoppedAnimation(erosionColor),
                  minHeight: 8,
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
//  CONTROLS
// ════════════════════════════════════════════════════════════════════════════
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
        widget.game.surveyPatch();
      } else {
        widget.game.applyTool();
      }
    }
    if (k == LogicalKeyboardKey.digit1 && pressed) {
      widget.game.selectTool(RestorationTool.terrace);
    }
    if (k == LogicalKeyboardKey.digit2 && pressed) {
      widget.game.selectTool(RestorationTool.checkDam);
    }
    if (k == LogicalKeyboardKey.digit3 && pressed) {
      widget.game.selectTool(RestorationTool.coverCrop);
    }
    if (k == LogicalKeyboardKey.digit4 && pressed) {
      widget.game.selectTool(RestorationTool.biochar);
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
            ? const Color(0xFFFFB300)
            : const Color(0xFF69F0AE);

        return KeyboardListener(
          focusNode: _fk,
          onKeyEvent: _onKey,
          child: Stack(children: [

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

            Align(
              alignment: Alignment.bottomRight,
              child: SafeArea(child: Padding(
                padding: const EdgeInsets.only(bottom: 20, right: 14),
                child: GestureDetector(
                  onTap: () {
                    if (phase == 1) {
                      widget.game.surveyPatch();
                    } else {
                      widget.game.applyTool();
                    }
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
                      phase == 1 ? '🛰️\nSCAN' : '🪨\nAPPLY',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: canAct ? actColor : Colors.white30,
                          fontWeight: FontWeight.w900,
                          fontSize: 9, letterSpacing: 0.4,
                          height: 1.4),
                    )),
                  ),
                ),
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
//  PHASE BANNER
// ════════════════════════════════════════════════════════════════════════════
class LandPhaseBanner extends StatelessWidget {
  final LandDegradationGame game;
  const LandPhaseBanner(this.game, {super.key});

  @override
  Widget build(BuildContext context) {
    final phase1  = game.gamePhase == 1;
    final accent  = phase1 ? const Color(0xFFFFB300) : const Color(0xFF69F0AE);

    return IgnorePointer(child: Center(child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
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
                fontSize: 26, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text(
          phase1
              ? 'Fly near degraded zones then tap 🛰️ SCAN\nto identify each erosion patch.'
              : 'Select the correct tool and tap 🪨 APPLY\nwhen near each degraded patch.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
      ]),
    )));
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  RESTORATION TOOL SELECTOR  (Phase 2 only)
// ════════════════════════════════════════════════════════════════════════════
class RestorationToolSelector extends StatelessWidget {
  final LandDegradationGame game;
  const RestorationToolSelector(this.game, {super.key});

  static const _tools = [
    (RestorationTool.terrace,  '🏔️', 'Terrace\nTool',    Color(0xFFEF5350), 'Steep Slope'),
    (RestorationTool.checkDam, '🪨', 'Check\nDam',        Color(0xFFFF6D00), 'Gully'),
    (RestorationTool.coverCrop,'🌾', 'Cover\nCrop',       Color(0xFFFFB300), 'Bare Land'),
    (RestorationTool.biochar,  '🌑', 'Biochar/\nCompost', Color(0xFFBCAAA4), 'Dry Soil'),
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
                Text('SELECT RESTORATION TOOL',
                    style: TextStyle(
                        color: Colors.white54,
                        fontSize: mobile ? 7.5 : 9,
                        letterSpacing: 1.5, fontWeight: FontWeight.w700)),
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
                        Text(label, textAlign: TextAlign.center,
                            style: TextStyle(
                              color: sel ? color : Colors.white70,
                              fontWeight: FontWeight.w900,
                              fontSize: mobile ? 7.5 : 9, height: 1.2,
                            )),
                        const SizedBox(height: 1),
                        Text(target, style: TextStyle(
                          color: sel ? color.withValues(alpha: 0.75) : Colors.white38,
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
//  REACTION FLASH
// ════════════════════════════════════════════════════════════════════════════
class LandReactionFx extends StatelessWidget {
  final LandDegradationGame game;
  const LandReactionFx(this.game, {super.key});

  @override
  Widget build(BuildContext context) {
    final ok      = game.reactionCorrect;
    final phase1  = game.reactionPhase == 1;
    final inRange = game.reactionInRange;

    final String title;
    final String sub;
    if (!inRange) {
      title = '🛰️  OUT OF RANGE!';
      sub   = 'Move closer to a degraded patch first';
    } else if (phase1 && ok) {
      title = '🛰️  ZONE IDENTIFIED!';
      sub   = '+5 Eco-Points per patch surveyed';
    } else if (!phase1 && ok) {
      title = '🌿  LAND RESTORED!';
      sub   = '+10 Eco-Points  •  Erosion index drops';
    } else {
      title = '❌  WRONG TOOL!';
      sub   = '−5 Eco-Points  •  Erosion worsens';
    }

    final accent = (ok || !inRange)
        ? const Color(0xFF69F0AE)
        : const Color(0xFFEF5350);

    return IgnorePointer(child: Stack(children: [
      Container(decoration: BoxDecoration(
        border: Border.all(color: accent, width: 10),
        gradient: RadialGradient(colors: [
          Colors.transparent,
          accent.withValues(alpha: 0.13),
        ], radius: 1.5),
      )),
      Center(child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
        decoration: BoxDecoration(
            color: ok
                ? const Color(0xFF0A2A10).withValues(alpha: 0.95)
                : const Color(0xFF2A0A0A).withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [BoxShadow(color: Colors.black54,
                blurRadius: 14, spreadRadius: 2)]),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(title, style: const TextStyle(color: Colors.white,
              fontWeight: FontWeight.bold, fontSize: 20, letterSpacing: 0.8)),
          const SizedBox(height: 4),
          Text(sub, style: TextStyle(color: accent, fontSize: 13,
              fontWeight: FontWeight.w600)),
        ]),
      )),
    ]));
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  LAND RESULTS OVERLAY
// ════════════════════════════════════════════════════════════════════════════
class LandResultsOverlay extends StatelessWidget {
  final LandDegradationGame game;
  const LandResultsOverlay(this.game, {super.key});

  @override
  Widget build(BuildContext context) {
    final result    = LandDegradationResult.current!;
    final stabilised = result.terrainStabilised;
    final erosionFinal = result.erosionIndex.toStringAsFixed(0);

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
              boxShadow: const [BoxShadow(
                  color: Colors.black54, blurRadius: 16)],
            ),
            child: Column(children: [
              Text(stabilised ? '🌿' : '🏜️',
                  style: const TextStyle(fontSize: 52)),
              const SizedBox(height: 8),
              Text(stabilised ? 'Terrain Stabilised!' : 'Phase Complete',
                  style: const TextStyle(color: Colors.white, fontSize: 22,
                      fontWeight: FontWeight.bold, letterSpacing: 0.8)),
              const SizedBox(height: 4),
              const Text('Phase 1 & 2 — Land Degradation Results',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
              if (stabilised) ...[
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
                    Text('Terrain Stabiliser Badge Unlocked!',
                        style: TextStyle(color: Color(0xFF69F0AE),
                            fontWeight: FontWeight.w800, fontSize: 12)),
                  ]),
                ),
              ],
            ]),
          ),

          const SizedBox(height: 16),

          // Score row
          _LRCard(children: [
            _LRBig('🏜️', '$erosionFinal%', 'Erosion',
                stabilised ? const Color(0xFF69F0AE) : const Color(0xFFFFB300)),
            _LRBig('🌿', '${result.patchesRestored}', 'Restored', Colors.limeAccent),
            _LRBig('❌', '${result.wrongTools}',       'Wrong',    Colors.redAccent),
            _LRBig('⭐', '${result.ecoPoints}',        'Eco-Pts',  Colors.amber),
          ]),

          const SizedBox(height: 12),

          // Restoration summary
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0A1A08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(children: [
              const Text('Restoration Actions Applied',
                  style: TextStyle(color: Colors.white70, fontSize: 12,
                      fontWeight: FontWeight.bold, letterSpacing: 1)),
              const SizedBox(height: 12),
              _LRRow('🏔️', 'Steep Slopes',  '🏔️ Terraces constructed'),
              _LRRow('🕳️', 'Erosion Gullies', '🪨 Check dams installed'),
              _LRRow('🌾', 'Bare Land',     '🌾 Cover crops planted'),
              _LRRow('🪨', 'Dry Soil',      '🌑 Biochar & compost applied'),
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

class _LRCard extends StatelessWidget {
  final List<Widget> children;
  const _LRCard({required this.children});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    decoration: BoxDecoration(
      color: const Color(0xFF0A1A08),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white12),
    ),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: children),
  );
}

class _LRBig extends StatelessWidget {
  final String emoji, value, label;
  final Color color;
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