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

  const NoiseResult({
    required this.hotspotsFix,
    required this.wrongTools,
    required this.ecoPoints,
    required this.noiseMeterFinal,
    required this.peacefulCityBadge,
  });

  static NoiseResult? current;
}

// ══════════════════════════════════════════════════════════════════════════════
//  ENUMS
// ══════════════════════════════════════════════════════════════════════════════
enum NoiseType { traffic, construction, loudspeaker, vegetation }
enum NoiseTool { electricMuffler, silentMachinery, silentZone, treeBarrier }

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

  // ── State ─────────────────────────────────────────────────────────────────
  int    gamePhase   = 3;   // 3 = scan, 4 = fix
  bool   gameStarted = false;
  double timeLeft    = 120.0;
  bool   levelDone   = false;

  // ── Score ─────────────────────────────────────────────────────────────────
  int ecoPoints   = 0;
  int wrongTools  = 0;
  int fixedCount  = 0;
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

  // ── Tool selection ────────────────────────────────────────────────────────
  NoiseTool selectedTool = NoiseTool.electricMuffler;

  // ── Reaction FX ──────────────────────────────────────────────────────────
  bool   reactionActive  = false;
  bool   reactionCorrect = false;
  int    reactionPhase   = 3;
  bool   reactionInRange = true;
  double reactionTimer   = 0;

  // ── Banner ────────────────────────────────────────────────────────────────
  double bannerTimer = 3.5;

  // ── Scan animation ────────────────────────────────────────────────────────
  bool   scanActive    = false;
  double scanRadius    = 0;
  static const double _scanMaxRadius = 180.0;

  // ── Components ────────────────────────────────────────────────────────────
  late EcoDroneComponent drone;
  final List<NoiseHotspot> hotspots = [];

  @override
  Future<void> onLoad() async {
    super.onLoad();
    dronePos = Vector2(size.x * 0.50, size.y * 0.60);

    add(NoiseCityRenderer(game: this));
    drone = EcoDroneComponent(game: this);
    add(drone);

    _spawnHotspots();

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

  // ── Phase 3 — Scan ────────────────────────────────────────────────────────
  void scanHotspot() {
    if (!gameStarted || levelDone || gamePhase != 3) return;
    gameStarted = true;
    HapticFeedback.selectionClick();

    int newly = 0;
    for (final h in hotspots) {
      if (h.isScanned) continue;
      if ((h.hotspotPos - dronePos).length <= _scanRange) {
        h.reveal();
        scannedCount++;
        newly++;
      }
    }

    if (newly > 0) {
      ecoPoints += newly * 5;
      scanActive = true;
      scanRadius = 0;
      _triggerReaction(true);
      if (scannedCount >= hotspots.length) {
        Future.delayed(const Duration(milliseconds: 900), _advanceToPhase4);
      }
    } else {
      _triggerReaction(false, inRange: false);
    }
    notifyListeners();
  }

  void _advanceToPhase4() {
    if (levelDone) return;
    gamePhase   = 4;
    bannerTimer = 3.0;
    overlays
      ..add('banner')
      ..add('toolSelect');
    notifyListeners();
  }

  // ── Phase 4 — Fix ─────────────────────────────────────────────────────────
  void applyTool() {
    if (!gameStarted || levelDone || gamePhase != 4) return;
    final target = _nearestUnfixed;
    if (target == null) { _triggerReaction(false, inRange: false); return; }

    HapticFeedback.lightImpact();
    final correct = _isCorrectTool(target.type, selectedTool);
    if (correct) {
      target.fix();
      fixedCount++;
      noiseMeter = math.max(0, noiseMeter - _fixReduction);
      ecoPoints += 15;
      _triggerReaction(true);
    } else {
      wrongTools++;
      noiseMeter = math.min(120, noiseMeter + _wrongPenalty);
      ecoPoints  = math.max(0, ecoPoints - 10);
      _triggerReaction(false);
    }

    final allDone = hotspots.every((h) => h.isFixed);
    if (noiseMeter <= _targetNoise || allDone) {
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

    NoiseResult.current = NoiseResult(
      hotspotsFix:       fixedCount,
      wrongTools:        wrongTools,
      ecoPoints:         ecoPoints,
      noiseMeterFinal:   noiseMeter,
      peacefulCityBadge: noiseMeter < _targetNoise,
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
    if (isLeft)  vx -= 1;  if (isRight) vx += 1;
    if (isUp)    vy -= 1;  if (isDown)  vy += 1;
    dronePos.x = (dronePos.x + vx * _droneSpeed * dt).clamp(30, size.x - 30);
    dronePos.y = (dronePos.y + vy * _droneSpeed * dt).clamp(40, size.y * 0.88);

    notifyListeners();
  }
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
    final w = game.size.x;
    final h = game.size.y;

    canvas.drawRect(Rect.fromLTWH(0, 0, w, h),
        Paint()
          ..shader = ui.Gradient.linear(Offset(0, 0), Offset(0, h), [
            const Color(0xFF080E18),
            Color.lerp(const Color(0xFF0C1420), const Color(0xFF0A1E14),
                (math.sin(_t) * 0.5 + 0.5) * 0.4)!,
            const Color(0xFF080C10),
          ], [0.0, 0.5, 1.0]));

    final noiseRatio = (game.noiseMeter / 96.0).clamp(0.0, 1.0);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()
        ..color = const Color(0xFFEF5350).withValues(alpha: noiseRatio * 0.05)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30),
    );

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
    final blocks = [
      (0.02, 0.02, 0.20, 0.24), (0.26, 0.02, 0.22, 0.24), (0.52, 0.02, 0.22, 0.24),
      (0.78, 0.02, 0.20, 0.24), (0.02, 0.30, 0.20, 0.20), (0.26, 0.30, 0.22, 0.20),
      (0.52, 0.30, 0.22, 0.20), (0.78, 0.30, 0.20, 0.20), (0.02, 0.54, 0.20, 0.18),
    ];
    for (final (bx, by, bw, bh) in blocks) {
      final x = w * bx + 4; final y = h * by + 4;
      final width = w * bw - 8; final height = h * bh - 8;
      canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(x, y, width, height),
              const Radius.circular(3)),
          Paint()..color = const Color(0xFF090D14));
      _drawWindows(canvas, x, y, width, height, rng);
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
    final cx = game.dronePos.x;
    final cy = game.dronePos.y + math.sin(_t * 3.2) * 2.5;

    if (game.scanActive) {
      final alpha =
          (1.0 - game.scanRadius / NoisePollutionGame._scanMaxRadius) * 0.30;
      canvas.drawCircle(Offset(cx, cy), game.scanRadius,
          Paint()
            ..color = const Color(0xFF29B6F6).withValues(alpha: alpha)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5);
    }

    final rangeColor = game.gamePhase == 3
        ? const Color(0xFF29B6F6)
        : const Color(0xFF69F0AE);
    final rangeR = game.gamePhase == 3
        ? NoisePollutionGame._scanRange
        : NoisePollutionGame._applyRange;
    canvas.drawCircle(Offset(cx, cy), rangeR,
        Paint()
          ..color = rangeColor.withValues(alpha: 0.06)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2);

    canvas.save();
    canvas.translate(cx, cy);

    canvas.drawOval(Rect.fromCenter(center: const Offset(0, 14),
        width: 38, height: 9),
        Paint()..color = Colors.black.withValues(alpha: 0.28));

    final armPaint = Paint()
      ..color = const Color(0xFF1C3A5C)
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;
    for (final (dx, dy) in [(-1, -1), (1, -1), (-1, 1), (1, 1)]) {
      canvas.drawLine(
          Offset(dx * 8, dy * 8), Offset(dx * 22, dy * 22), armPaint);
    }

    final propPaint = Paint()
      ..color = const Color(0xFF90CAF9).withValues(alpha: 0.55)
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    for (final (px, py) in [(-22.0, -22.0), (22.0, -22.0),
          (-22.0, 22.0), (22.0, 22.0)]) {
      canvas.drawLine(Offset(px - 8, py), Offset(px + 8, py), propPaint);
      canvas.drawLine(Offset(px, py - 8), Offset(px, py + 8), propPaint);
    }

    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(-13, -10, 26, 20), const Radius.circular(6)),
        Paint()..color = const Color(0xFF1E3A5F));

    final glowColor = game.gamePhase == 3
        ? const Color(0xFF29B6F6)
        : const Color(0xFF69F0AE);
    canvas.drawCircle(Offset.zero, 7,
        Paint()
          ..color = glowColor.withValues(alpha: 0.75 + math.sin(_t * 4) * 0.20)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    canvas.drawCircle(Offset.zero, 3.5,
        Paint()..color = Colors.white.withValues(alpha: 0.95));

    final tp = TextPainter(
      text: TextSpan(
          text: game.gamePhase == 3 ? '📡' : '🔧',
          style: const TextStyle(fontSize: 8)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(-tp.width / 2, 13 - tp.height / 2));

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
  bool isFixed   = false;
  double _t = 0;

  NoiseHotspot({
    required this.game, required this.type,
    required double worldX, required double worldY,
    required this.seed,
  }) : hx = worldX, hy = worldY;

  Vector2 get hotspotPos => Vector2(hx, hy);

  void reveal() => isScanned = true;
  void fix()    { isFixed = true; isScanned = true; }

  static const _specs = {
    NoiseType.traffic:      ('🚗', 'Vehicle\nHonking',  Color(0xFFEF5350), '85 dB'),
    NoiseType.construction: ('🏗️', 'Construction\nSite', Color(0xFFFF6D00), '90 dB'),
    NoiseType.loudspeaker:  ('📢', 'Loud\nSpeaker',     Color(0xFFCE93D8), '78 dB'),
    NoiseType.vegetation:   ('🌿', 'Sparse\nVegetation', Color(0xFF78909C), '72 dB'),
  };

  @override
  void update(double dt) => _t += dt;

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
//  NOISE HUD
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
          ]),
        ));
      },
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
//  NOISE CONTROLS  (D-pad  +  SCAN / APPLY button)
// ════════════════════════════════════════════════════════════════════════════
class NoiseControls extends StatefulWidget {
  final NoisePollutionGame game;
  const NoiseControls(this.game, {super.key});
  @override
  State<NoiseControls> createState() => _NoiseControlsState();
}

class _NoiseControlsState extends State<NoiseControls> {
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
      if (widget.game.gamePhase == 3) {
        widget.game.scanHotspot();
      } else {
        widget.game.applyTool();
      }
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
        final phase    = widget.game.gamePhase;
        final canAct   = phase == 3
            ? widget.game._hasNearbyUnscanned
            : widget.game._hasNearbyUnfixed;
        final actColor = phase == 3
            ? const Color(0xFF29B6F6)
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

            Align(
              alignment: Alignment.bottomRight,
              child: SafeArea(child: Padding(
                padding: const EdgeInsets.only(bottom: 20, right: 14),
                child: GestureDetector(
                  onTap: () {
                    if (phase == 3) {
                      widget.game.scanHotspot();
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
                      phase == 3 ? '🔍\nSCAN' : '🔧\nAPPLY',
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
//  PHASE BANNER
// ════════════════════════════════════════════════════════════════════════════
class NoisePhaseBanner extends StatelessWidget {
  final NoisePollutionGame game;
  const NoisePhaseBanner(this.game, {super.key});

  @override
  Widget build(BuildContext context) {
    final phase3  = game.gamePhase == 3;
    final accent  = phase3 ? const Color(0xFF29B6F6) : const Color(0xFF69F0AE);

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
              ? 'Drive near hotspots then tap 🔍 SCAN\nto identify each noise source.'
              : 'Select the correct tool and tap 🔧 APPLY\nwhen near each hotspot.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
      ]),
    )));
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  NOISE TOOL SELECTOR  (Phase 4 only)
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
                    style: TextStyle(
                        color: Colors.white54,
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
//  REACTION FLASH
// ════════════════════════════════════════════════════════════════════════════
class NoiseReactionFx extends StatelessWidget {
  final NoisePollutionGame game;
  const NoiseReactionFx(this.game, {super.key});

  @override
  Widget build(BuildContext context) {
    final ok      = game.reactionCorrect;
    final phase3  = game.reactionPhase == 3;
    final inRange = game.reactionInRange;

    final String title;
    final String sub;
    if (!inRange) {
      title = '📡  OUT OF RANGE!';
      sub   = 'Move closer to a hotspot first';
    } else if (phase3 && ok) {
      title = '📡  IDENTIFIED!';
      sub   = '+5 Eco-Points per source revealed';
    } else if (!phase3 && ok) {
      title = '✅  NOISE REDUCED!';
      sub   = '+15 Eco-Points  •  Decibels dropped';
    } else {
      title = '❌  WRONG TOOL!';
      sub   = '−10 Eco-Points  •  Noise spike';
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
              style: TextStyle(
                  color: accent, fontSize: 13,
                  fontWeight: FontWeight.w600)),
        ]),
      )),
    ]));
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  NOISE RESULTS OVERLAY
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

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: peaceful
                  ? [const Color(0xFF001A0A), const Color(0xFF003018)]
                  : [const Color(0xFF1A1000), const Color(0xFF2A1800)]),
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [BoxShadow(
                  color: Colors.black54, blurRadius: 16)],
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

          _NRCard(children: [
            _NRBig('🔊', '$dbFinal dB', 'Final Noise',
                peaceful
                    ? const Color(0xFF69F0AE)
                    : const Color(0xFFFFB300)),
            _NRBig('✅', '${result.hotspotsFix}', 'Fixed',   Colors.limeAccent),
            _NRBig('❌', '${result.wrongTools}',  'Wrong',   Colors.redAccent),
            _NRBig('⭐', '${result.ecoPoints}',   'Eco-Pts', Colors.amber),
          ]),

          const SizedBox(height: 12),

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