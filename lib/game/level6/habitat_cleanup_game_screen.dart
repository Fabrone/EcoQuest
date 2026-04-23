import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:ecoquest/game/level6/degraded_park_screen.dart';
import 'package:ecoquest/game/level6/wildlife_rescue_screen.dart';
import 'package:flame/components.dart' hide Matrix4;
import 'package:flame/game.dart' hide Matrix4;
import 'package:flutter/material.dart' hide Matrix4;
import 'package:flutter/services.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  HABITAT CLEANUP RESULT  — passed to WildlifeRescueScreen
// ══════════════════════════════════════════════════════════════════════════════
class HabitatCleanupResult {
  final int    litterCollected;
  final int    correctSorts;
  final int    pondsClean;
  final int    ecoPoints;
  final double waterPurity;

  const HabitatCleanupResult({
    required this.litterCollected,
    required this.correctSorts,
    required this.pondsClean,
    required this.ecoPoints,
    required this.waterPurity,
  });

  static HabitatCleanupResult? current;
}

// ══════════════════════════════════════════════════════════════════════════════
//  ENUMS
// ══════════════════════════════════════════════════════════════════════════════
enum LitterType  { plastic, metal, organic, glass }
enum WasteSort   { recyclable, reusable, biodegradable }
enum PondType    { algaeBloom, organicWaste, chemicalPollution }
enum PondTreatment { hyacinths, bacteriaPellets, filtrationUnit }

// ══════════════════════════════════════════════════════════════════════════════
//  SCREEN WRAPPER
// ══════════════════════════════════════════════════════════════════════════════
class HabitatCleanupGameScreen extends StatefulWidget {
  final Level5CarryOver carryOver;
  const HabitatCleanupGameScreen({super.key, required this.carryOver});

  @override
  State<HabitatCleanupGameScreen> createState() =>
      _HabitatCleanupGameScreenState();
}

class _HabitatCleanupGameScreenState
    extends State<HabitatCleanupGameScreen> {
  late HabitatCleanupGame _game;

  @override
  void initState() {
    super.initState();
    _game = HabitatCleanupGame(
      carryOver:       widget.carryOver,
      onLevelComplete: _onDone,
    );
  }

  void _onDone() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => WildlifeRescueScreen(carryOver: widget.carryOver),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GameWidget(
        game: _game,
        overlayBuilderMap: {
          'hud':        (ctx, g) => CleanupHud(g as HabitatCleanupGame),
          'controls':   (ctx, g) => CleanupControls(g as HabitatCleanupGame),
          'banner':     (ctx, g) => CleanupPhaseBanner(g as HabitatCleanupGame),
          'sortMini':   (ctx, g) => SortMiniGame(g as HabitatCleanupGame),
          'pondSelect': (ctx, g) => PondTreatmentSelector(g as HabitatCleanupGame),
          'reactionFx': (ctx, g) => CleanupReactionFx(g as HabitatCleanupGame),
          'results':    (ctx, g) => CleanupResultsOverlay(g as HabitatCleanupGame),
        },
        initialActiveOverlays: const ['hud', 'controls'],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  MAIN GAME CLASS
// ══════════════════════════════════════════════════════════════════════════════
class HabitatCleanupGame extends FlameGame
    with HasCollisionDetection, ChangeNotifier {

  final Level5CarryOver carryOver;
  final VoidCallback    onLevelComplete;

  HabitatCleanupGame({required this.carryOver, required this.onLevelComplete});

  // ── State ─────────────────────────────────────────────────────────────────
  int    gamePhase   = 1;   // 1 = waste, 2 = water
  bool   gameStarted = false;
  double timeLeft    = 120.0;
  bool   levelDone   = false;

  // ── Score ─────────────────────────────────────────────────────────────────
  int ecoPoints     = 0;
  int litterCount   = 0;
  int correctSorts  = 0;
  int pondsFixed    = 0;

  // ── Water purity ──────────────────────────────────────────────────────────
  double waterPurity = 10.0;
  static const double _purityGain   = 18.0;
  static const double _wrongPenalty = 6.0;

  // ── Ranges ────────────────────────────────────────────────────────────────
  static const double _collectRange = 80.0;
  static const double _treatRange   = 100.0;

  // ── Drone physics ─────────────────────────────────────────────────────────
  late Vector2 dronePos;
  bool isUp = false, isDown = false, isLeft = false, isRight = false;
  static const double _droneSpeed = 180.0;

  // ── Sorting mini-game ─────────────────────────────────────────────────────
  bool          sortingActive   = false;
  LitterType?   currentLitter;
  int           sortingScore    = 0;

  // ── Pond treatment ────────────────────────────────────────────────────────
  PondTreatment selectedTreatment = PondTreatment.hyacinths;

  // ── Reaction FX ──────────────────────────────────────────────────────────
  bool   reactionActive  = false;
  bool   reactionCorrect = false;
  int    reactionPhase   = 1;
  bool   reactionInRange = true;
  double reactionTimer   = 0;

  // ── Banner ────────────────────────────────────────────────────────────────
  double bannerTimer = 3.5;

  // ── Components ────────────────────────────────────────────────────────────
  late EcoDroneCleanupComponent drone;
  final List<LitterItem>  litter = [];
  final List<PollutedPond> ponds = [];

  static const int totalLitter = 10;
  static const int _totalPonds  = 6;

  @override
  Future<void> onLoad() async {
    super.onLoad();
    dronePos = Vector2(size.x * 0.50, size.y * 0.55);

    add(DegradedParkRenderer(game: this));
    drone = EcoDroneCleanupComponent(game: this);
    add(drone);

    _spawnLitter();

    bannerTimer = 3.5;
    overlays.add('banner');
    add(TimerComponent(period: 1.0, repeat: true, onTick: _onSecond));
  }

  void _spawnLitter() {
    final rng = math.Random(88);
    final types = LitterType.values;
    for (int i = 0; i < totalLitter; i++) {
      final l = LitterItem(
        game: this,
        type: types[i % types.length],
        worldX: 60 + rng.nextDouble() * (size.x - 120),
        worldY: size.y * 0.45 + rng.nextDouble() * (size.y * 0.35),
        seed: i * 13,
      );
      add(l);
      litter.add(l);
    }
  }

  void _spawnPonds() {
    final pondSpecs = [
      (PondType.algaeBloom,        0.15, 0.35),
      (PondType.algaeBloom,        0.68, 0.55),
      (PondType.organicWaste,      0.38, 0.48),
      (PondType.organicWaste,      0.84, 0.30),
      (PondType.chemicalPollution, 0.52, 0.65),
      (PondType.chemicalPollution, 0.22, 0.70),
    ];
    for (int i = 0; i < pondSpecs.length; i++) {
      final (type, rx, ry) = pondSpecs[i];
      final p = PollutedPond(
        game: this, type: type,
        worldX: size.x * rx, worldY: size.y * ry,
        seed: i * 21,
      );
      add(p);
      ponds.add(p);
    }
  }

  void _onSecond() {
    if (!gameStarted || levelDone) return;
    timeLeft -= 1;
    if (timeLeft <= 0) { timeLeft = 0; _endCleanup(); }
    notifyListeners();
  }

  // ── Phase 1 helpers ───────────────────────────────────────────────────────
  bool get _hasNearbyLitter =>
      litter.any((l) => !l.isCollected &&
          (l.litterPos - dronePos).length <= _collectRange);

  LitterItem? get _nearestLitter {
    LitterItem? target;
    double best = _collectRange;
    for (final l in litter) {
      if (l.isCollected) continue;
      final d = (l.litterPos - dronePos).length;
      if (d < best) { best = d; target = l; }
    }
    return target;
  }

  // ── Phase 2 helpers ───────────────────────────────────────────────────────
  bool get _hasNearbyPond =>
      ponds.any((p) => !p.isClean &&
          (p.pondPos - dronePos).length <= _treatRange);

  PollutedPond? get _nearestPond {
    PollutedPond? target;
    double best = _treatRange;
    for (final p in ponds) {
      if (p.isClean) continue;
      final d = (p.pondPos - dronePos).length;
      if (d < best) { best = d; target = p; }
    }
    return target;
  }

  // ── Phase 1 — Collect ─────────────────────────────────────────────────────
  void collectLitter() {
    if (!gameStarted || levelDone || gamePhase != 1) return;
    gameStarted = true;
    HapticFeedback.lightImpact();

    final target = _nearestLitter;
    if (target == null) { _triggerReaction(false, inRange: false); return; }

    target.collect();
    litterCount++;
    currentLitter = target.type;
    sortingActive = true;
    overlays.add('sortMini');
    notifyListeners();
  }

  void sortLitter(WasteSort sort) {
    sortingActive = false;
    overlays.remove('sortMini');
    HapticFeedback.selectionClick();

    final correct = _isCorrectSort(currentLitter!, sort);
    if (correct) {
      correctSorts++;
      ecoPoints += 20;
      _triggerReaction(true);
    } else {
      ecoPoints = math.max(0, ecoPoints - 5);
      _triggerReaction(false);
    }

    final allCollected = litter.every((l) => l.isCollected);
    if (allCollected) {
      Future.delayed(const Duration(milliseconds: 600), _advanceToPhase2);
    }
    notifyListeners();
  }

  bool _isCorrectSort(LitterType t, WasteSort s) {
    switch (t) {
      case LitterType.plastic: return s == WasteSort.recyclable;
      case LitterType.metal:   return s == WasteSort.recyclable;
      case LitterType.organic: return s == WasteSort.biodegradable;
      case LitterType.glass:   return s == WasteSort.reusable;
    }
  }

  void _advanceToPhase2() {
    if (levelDone) return;
    gamePhase   = 2;
    bannerTimer = 3.0;
    _spawnPonds();
    overlays..add('banner')..add('pondSelect');
    notifyListeners();
  }

  // ── Phase 2 — Treat ───────────────────────────────────────────────────────
  void treatPond() {
    if (!gameStarted || levelDone || gamePhase != 2) return;
    final target = _nearestPond;
    if (target == null) { _triggerReaction(false, inRange: false); return; }

    HapticFeedback.lightImpact();
    final correct = _isCorrectTreatment(target.type, selectedTreatment);
    if (correct) {
      target.clean();
      pondsFixed++;
      waterPurity = math.min(100, waterPurity + _purityGain);
      ecoPoints  += 25;
      _triggerReaction(true);
    } else {
      waterPurity = math.max(0, waterPurity - _wrongPenalty);
      ecoPoints   = math.max(0, ecoPoints - 8);
      _triggerReaction(false);
    }

    if (ponds.every((p) => p.isClean)) {
      Future.delayed(const Duration(milliseconds: 800), _endCleanup);
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

  void selectTreatment(PondTreatment t) {
    selectedTreatment = t;
    notifyListeners();
  }

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

  void _endCleanup() {
    if (levelDone) return;
    levelDone = true;
    pauseEngine();

    HabitatCleanupResult.current = HabitatCleanupResult(
      litterCollected: litterCount,
      correctSorts:    correctSorts,
      pondsClean:      pondsFixed,
      ecoPoints:       ecoPoints,
      waterPurity:     waterPurity,
    );

    overlays
      ..remove('reactionFx')
      ..remove('pondSelect')
      ..remove('sortMini')
      ..add('results');
    notifyListeners();
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
      if (reactionTimer <= 0) {
        reactionActive = false;
        overlays.remove('reactionFx');
      }
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
//  DEGRADED PARK RENDERER
// ════════════════════════════════════════════════════════════════════════════
class DegradedParkRenderer extends Component {
  final HabitatCleanupGame game;
  double _t = 0;
  DegradedParkRenderer({required this.game});

  @override
  void update(double dt) => _t += dt * 0.2;

  @override
  void render(Canvas canvas) {
    final w = game.size.x, h = game.size.y;

    // Sky
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h),
        Paint()..shader = ui.Gradient.linear(Offset(0, 0), Offset(0, h), [
          const Color(0xFF060C06),
          Color.lerp(const Color(0xFF0C1410), const Color(0xFF0E160C),
              (math.sin(_t) * 0.5 + 0.5) * 0.3)!,
          const Color(0xFF060A04),
        ], [0.0, 0.5, 1.0]));

    // Health tint — gets greener as purity rises
    final purity = (game.waterPurity / 100.0).clamp(0.0, 1.0);
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h),
        Paint()
          ..color = const Color(0xFF69F0AE).withValues(alpha: purity * 0.035)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30));

    _drawPaths(canvas, w, h);
    _drawBlocks(canvas, w, h);
    _drawPond(canvas, w, h);

    canvas.drawRect(Rect.fromLTWH(0, h * 0.86, w, h * 0.14),
        Paint()..color = const Color(0xFF040804));
  }

  void _drawPaths(Canvas canvas, double w, double h) {
    final p = Paint()..color = const Color(0xFF0A1008);
    for (final ry in [0.30, 0.54, 0.75]) {
      canvas.drawRect(Rect.fromLTWH(0, h * ry - 7, w, 14), p);
    }
    for (final rx in [0.25, 0.52, 0.78]) {
      canvas.drawRect(Rect.fromLTWH(w * rx - 7, 0, 14, h * 0.86), p);
    }
  }

  void _drawBlocks(Canvas canvas, double w, double h) {
    final rng = math.Random(22);
    for (final (bx, by, bw, bh) in [
      (0.02, 0.02, 0.21, 0.26), (0.27, 0.02, 0.23, 0.26),
      (0.54, 0.02, 0.22, 0.26), (0.78, 0.02, 0.20, 0.26),
      (0.02, 0.32, 0.21, 0.20), (0.27, 0.32, 0.23, 0.20),
      (0.54, 0.32, 0.22, 0.20), (0.78, 0.32, 0.20, 0.20),
    ]) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(w * bx + 4, h * by + 4,
                  w * bw - 8, h * bh - 8),
              const Radius.circular(3)),
          Paint()..color = const Color(0xFF080E06));
      _drawGrass(canvas, w * bx + 6, h * by + 6,
          w * bw - 12, h * bh - 12, rng);
    }
  }

  void _drawGrass(Canvas canvas, double bx, double by,
      double bw, double bh, math.Random rng) {
    final p = Paint()
      ..color = const Color(0xFF1B2E16).withValues(alpha: 0.50)
      ..strokeWidth = 1.0;
    for (int i = 0; i < 6; i++) {
      final gx = bx + rng.nextDouble() * bw;
      final gy = by + rng.nextDouble() * bh;
      canvas.drawLine(Offset(gx, gy), Offset(gx, gy - 6), p);
    }
  }

  void _drawPond(Canvas canvas, double w, double h) {
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w * 0.35, h * 0.68),
          width: w * 0.22, height: h * 0.07),
      Paint()..color = const Color(0xFF1B3028).withValues(alpha: 0.55),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  ECO-DRONE (CLEANUP) COMPONENT
// ════════════════════════════════════════════════════════════════════════════
class EcoDroneCleanupComponent extends Component {
  final HabitatCleanupGame game;
  double _t = 0;
  EcoDroneCleanupComponent({required this.game});

  @override
  void update(double dt) => _t += dt;

  @override
  void render(Canvas canvas) {
    final cx = game.dronePos.x;
    final cy = game.dronePos.y + math.sin(_t * 3.0) * 2.5;

    // Range indicator
    final rangeColor = game.gamePhase == 1
        ? const Color(0xFFFFB300)
        : const Color(0xFF00897B);
    final rangeR = game.gamePhase == 1
        ? HabitatCleanupGame._collectRange
        : HabitatCleanupGame._treatRange;
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
      ..color = const Color(0xFF1A2E18)
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;
    for (final (dx, dy) in [(-1, -1), (1, -1), (-1, 1), (1, 1)]) {
      canvas.drawLine(
          Offset(dx * 8, dy * 8), Offset(dx * 22, dy * 22), armPaint);
    }

    // Propellers
    final propPaint = Paint()
      ..color = const Color(0xFF69F0AE).withValues(alpha: 0.55)
      ..strokeWidth = 1.8 ..strokeCap = StrokeCap.round;
    for (final (px, py) in [(-22.0,-22.0),(22.0,-22.0),(-22.0,22.0),(22.0,22.0)]) {
      canvas.drawLine(Offset(px-8,py), Offset(px+8,py), propPaint);
      canvas.drawLine(Offset(px,py-8), Offset(px,py+8), propPaint);
    }

    // Body
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(-13, -10, 26, 20), const Radius.circular(6)),
        Paint()..color = const Color(0xFF142810));

    // Glow
    final glowColor = game.gamePhase == 1
        ? const Color(0xFFFFB300) : const Color(0xFF00897B);
    canvas.drawCircle(Offset.zero, 7,
        Paint()
          ..color = glowColor.withValues(alpha: 0.75 + math.sin(_t * 4) * 0.20)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    canvas.drawCircle(Offset.zero, 3.5,
        Paint()..color = Colors.white.withValues(alpha: 0.95));

    final tp = TextPainter(
      text: TextSpan(text: game.gamePhase == 1 ? '🗑️' : '💧',
          style: const TextStyle(fontSize: 8)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(-tp.width / 2, 13 - tp.height / 2));

    canvas.restore();
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  LITTER ITEM COMPONENT
// ════════════════════════════════════════════════════════════════════════════
class LitterItem extends Component {
  final HabitatCleanupGame game;
  final LitterType type;
  double lx, ly;
  final int seed;
  bool isCollected = false;
  double _t = 0;

  LitterItem({required this.game, required this.type,
      required double worldX, required double worldY, required this.seed})
      : lx = worldX, ly = worldY;

  Vector2 get litterPos => Vector2(lx, ly);

  void collect() => isCollected = true;

  static const _specs = {
    LitterType.plastic: ('🧴', Color(0xFF29B6F6)),
    LitterType.metal:   ('🥫', Color(0xFF90A4AE)),
    LitterType.organic: ('🍌', Color(0xFF558B2F)),
    LitterType.glass:   ('🍶', Color(0xFF26C6DA)),
  };

  @override
  void update(double dt) { if (!isCollected) _t += dt; }

  @override
  void render(Canvas canvas) {
    if (isCollected) return;
    final spec  = _specs[type]!;
    final color = spec.$2;
    final pulse = 0.75 + math.sin(_t * 2.5) * 0.15;

    canvas.drawCircle(Offset(lx, ly), 18 * pulse,
        Paint()
          ..color = color.withValues(alpha: 0.10)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    canvas.drawCircle(Offset(lx, ly), 14,
        Paint()
          ..color = color.withValues(alpha: 0.50)
          ..style = PaintingStyle.stroke ..strokeWidth = 1.8);

    final tp = TextPainter(
      text: TextSpan(text: spec.$1, style: const TextStyle(fontSize: 12)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(lx - tp.width/2, ly - tp.height/2));
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  POLLUTED POND COMPONENT
// ════════════════════════════════════════════════════════════════════════════
class PollutedPond extends Component {
  final HabitatCleanupGame game;
  final PondType type;
  double hx, hy;
  final int seed;
  bool isClean = false;
  double _t = 0;

  PollutedPond({required this.game, required this.type,
      required double worldX, required double worldY, required this.seed})
      : hx = worldX, hy = worldY;

  Vector2 get pondPos => Vector2(hx, hy);

  void clean() => isClean = true;

  static const _specs = {
    PondType.algaeBloom:        ('🌿', 'Algae\nBloom',    Color(0xFF2E7D32), '💧Hyacinths'),
    PondType.organicWaste:      ('🦠', 'Organic\nWaste',  Color(0xFF795548), '🧫Bacteria'),
    PondType.chemicalPollution: ('☠️', 'Chemical\nWaste', Color(0xFF7B1FA2), '🔧Filter'),
  };

  @override
  void update(double dt) { _t += dt; }

  @override
  void render(Canvas canvas) {
    if (isClean) { _drawClean(canvas); return; }
    final spec  = _specs[type]!;
    final color = spec.$3;
    final pulse = 0.65 + math.sin(_t * 2.6) * 0.22;

    // Polluted pond body
    canvas.drawOval(
      Rect.fromCenter(center: Offset(hx, hy), width: 60, height: 26),
      Paint()..color = color.withValues(alpha: 0.15 + pulse * 0.05),
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(hx, hy), width: 60, height: 26),
      Paint()
        ..color = color.withValues(alpha: 0.60)
        ..style = PaintingStyle.stroke ..strokeWidth = 2.0,
    );

    final ep = TextPainter(
      text: TextSpan(text: spec.$1, style: const TextStyle(fontSize: 14)),
      textDirection: TextDirection.ltr,
    )..layout();
    ep.paint(canvas, Offset(hx - ep.width/2, hy - ep.height/2 - 5));

    final lp = TextPainter(
      text: TextSpan(text: spec.$4,
          style: TextStyle(color: color, fontSize: 7.5,
              fontWeight: FontWeight.bold)),
      textDirection: TextDirection.ltr,
    )..layout();
    lp.paint(canvas, Offset(hx - lp.width/2, hy + 12));
  }

  void _drawClean(Canvas canvas) {
    canvas.drawOval(
      Rect.fromCenter(center: Offset(hx, hy), width: 60, height: 26),
      Paint()..color = const Color(0xFF00897B).withValues(alpha: 0.22),
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(hx, hy), width: 60, height: 26),
      Paint()
        ..color = const Color(0xFF69F0AE).withValues(alpha: 0.60)
        ..style = PaintingStyle.stroke ..strokeWidth = 2.0,
    );
    final tp = TextPainter(
      text: const TextSpan(text: '💧', style: TextStyle(fontSize: 14)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(hx - tp.width/2, hy - tp.height/2));
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  HUD
// ════════════════════════════════════════════════════════════════════════════
class CleanupHud extends StatelessWidget {
  final HabitatCleanupGame game;
  const CleanupHud(this.game, {super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: game,
      builder: (_, __) {
        final warn       = game.timeLeft < 20;
        final purityRatio = (game.waterPurity / 100.0).clamp(0.0, 1.0);
        final purityColor = game.waterPurity >= 80
            ? const Color(0xFF69F0AE)
            : game.waterPurity >= 50
                ? const Color(0xFF00897B)
                : const Color(0xFFEF5350);

        return SafeArea(child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch, children: [

            Align(alignment: Alignment.topCenter, child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
              decoration: BoxDecoration(
                color: game.gamePhase == 1
                    ? const Color(0xFF795548).withValues(alpha: 0.88)
                    : const Color(0xFF00897B).withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(
                    color: (game.gamePhase == 1
                        ? const Color(0xFF795548)
                        : const Color(0xFF00897B)).withValues(alpha: 0.35),
                    blurRadius: 10)],
              ),
              child: Text(
                game.gamePhase == 1
                    ? '🗑️  PHASE 1 — WASTE COLLECTION'
                    : '💧  PHASE 2 — WATER PURIFICATION',
                style: const TextStyle(color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 12, letterSpacing: 1.1),
              ),
            )),
            const SizedBox(height: 8),

            Row(children: [
              _CHTile(Icons.timer_rounded,
                  '${game.timeLeft.toInt()}s', 'TIME',
                  warn ? Colors.red : Colors.white),
              const SizedBox(width: 6),
              _CHTile(Icons.delete_sweep_rounded,
                  game.gamePhase == 1
                      ? '${game.litterCount}/${HabitatCleanupGame.totalLitter}'
                      : '${game.pondsFixed}/${HabitatCleanupGame._totalPonds}',
                  game.gamePhase == 1 ? 'LITTER' : 'PONDS',
                  const Color(0xFFFFB300)),
              const SizedBox(width: 6),
              _CHTile(Icons.eco_rounded, '${game.ecoPoints}', 'ECO-PTS',
                  Colors.limeAccent),
              const SizedBox(width: 6),
              _CHTile(Icons.water_rounded,
                  '${game.waterPurity.toStringAsFixed(0)}%', 'PURITY',
                  purityColor),
            ]),
            const SizedBox(height: 5),

            Row(children: [
              const Text('💧', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Expanded(child: ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: LinearProgressIndicator(
                  value: purityRatio,
                  backgroundColor: Colors.white12,
                  valueColor: AlwaysStoppedAnimation(purityColor),
                  minHeight: 8,
                ),
              )),
              const SizedBox(width: 6),
              RichText(text: TextSpan(children: [
                TextSpan(text: '${game.waterPurity.toStringAsFixed(0)}%',
                    style: TextStyle(color: purityColor, fontSize: 10,
                        fontWeight: FontWeight.bold)),
                const TextSpan(text: ' / 100%',
                    style: TextStyle(color: Color(0xFF69F0AE), fontSize: 8)),
              ])),
            ]),
          ]),
        ));
      },
    );
  }
}

class _CHTile extends StatelessWidget {
  final IconData icon;
  final String val, label;
  final Color color;
  const _CHTile(this.icon, this.val, this.label, this.color);
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
class CleanupControls extends StatefulWidget {
  final HabitatCleanupGame game;
  const CleanupControls(this.game, {super.key});
  @override
  State<CleanupControls> createState() => _CleanupControlsState();
}

class _CleanupControlsState extends State<CleanupControls> {
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
        widget.game.collectLitter();
      } else {
        widget.game.treatPond();
      }
    }
    if (k == LogicalKeyboardKey.digit1 && pressed) {
      widget.game.selectTreatment(PondTreatment.hyacinths);
    }
    if (k == LogicalKeyboardKey.digit2 && pressed) {
      widget.game.selectTreatment(PondTreatment.bacteriaPellets);
    }
    if (k == LogicalKeyboardKey.digit3 && pressed) {
      widget.game.selectTreatment(PondTreatment.filtrationUnit);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.game,
      builder: (_, __) {
        final phase  = widget.game.gamePhase;
        final canAct = phase == 1
            ? widget.game._hasNearbyLitter
            : widget.game._hasNearbyPond;
        final actColor = phase == 1
            ? const Color(0xFFFFB300)
            : const Color(0xFF00897B);

        return KeyboardListener(
          focusNode: _fk,
          onKeyEvent: _onKey,
          child: Stack(children: [
            Align(
              alignment: Alignment.bottomLeft,
              child: SafeArea(child: Padding(
                padding: const EdgeInsets.only(bottom: 16, left: 12),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  _CDPad('⬆', _up, Colors.cyanAccent,
                      onDown: () { setState(() => _up=true);  widget.game.setUpKey(true); },
                      onUp:   () { setState(() => _up=false); widget.game.setUpKey(false); }),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    _CDPad('◀', _lt, Colors.cyanAccent,
                        onDown: () { setState(() => _lt=true);  widget.game.setLeftKey(true); },
                        onUp:   () { setState(() => _lt=false); widget.game.setLeftKey(false); }),
                    const SizedBox(width: 4),
                    _CDPad('⬇', _dn, Colors.cyanAccent,
                        onDown: () { setState(() => _dn=true);  widget.game.setDownKey(true); },
                        onUp:   () { setState(() => _dn=false); widget.game.setDownKey(false); }),
                    const SizedBox(width: 4),
                    _CDPad('▶', _rt, Colors.cyanAccent,
                        onDown: () { setState(() => _rt=true);  widget.game.setRightKey(true); },
                        onUp:   () { setState(() => _rt=false); widget.game.setRightKey(false); }),
                  ]),
                ]),
              )),
            ),
            Align(
              alignment: Alignment.bottomRight,
              child: SafeArea(child: Padding(
                padding: const EdgeInsets.only(bottom: 20, right: 14),
                child: GestureDetector(
                  onTap: () => phase == 1
                      ? widget.game.collectLitter()
                      : widget.game.treatPond(),
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
                      boxShadow: canAct ? [BoxShadow(
                          color: actColor.withValues(alpha: 0.40),
                          blurRadius: 14)] : [],
                    ),
                    child: Center(child: Text(
                      phase == 1 ? '🗑️\nCOLL' : '💧\nTREAT',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: canAct ? actColor : Colors.white30,
                          fontWeight: FontWeight.w900,
                          fontSize: 9, letterSpacing: 0.4, height: 1.4),
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

class _CDPad extends StatelessWidget {
  final String label;
  final bool isActive;
  final Color color;
  final VoidCallback onDown, onUp;
  const _CDPad(this.label, this.isActive, this.color,
      {required this.onDown, required this.onUp});
  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (_) => onDown(), onPointerUp: (_) => onUp(),
    onPointerCancel: (_) => onUp(),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 70),
      width: 52, height: 52, margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: isActive ? color.withValues(alpha: 0.30)
            : Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: isActive ? color : Colors.white24, width: 1.8),
        boxShadow: isActive ? [BoxShadow(
            color: color.withValues(alpha: 0.40), blurRadius: 10)] : [],
      ),
      child: Center(child: Text(label, style: TextStyle(
          color: isActive ? color : Colors.white60,
          fontSize: 16, fontWeight: FontWeight.bold))),
    ),
  );
}

// ════════════════════════════════════════════════════════════════════════════
//  SORT MINI GAME  — appears after each collection
// ════════════════════════════════════════════════════════════════════════════
class SortMiniGame extends StatelessWidget {
  final HabitatCleanupGame game;
  const SortMiniGame(this.game, {super.key});

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.of(context).size.width < 600;
    final litter = game.currentLitter;
    if (litter == null || !game.sortingActive) return const SizedBox.shrink();

    final litEmoji = {
      LitterType.plastic: '🧴', LitterType.metal: '🥫',
      LitterType.organic: '🍌', LitterType.glass: '🍶',
    }[litter] ?? '?';

    const bins = [
      (WasteSort.recyclable,    '♻️', 'Recyclable',    Color(0xFF29B6F6)),
      (WasteSort.reusable,      '🔄', 'Reusable',      Color(0xFF69F0AE)),
      (WasteSort.biodegradable, '🌿', 'Biodegradable', Color(0xFF558B2F)),
    ];

    return Center(child: Container(
      margin: EdgeInsets.symmetric(horizontal: mobile ? 20 : 60),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1008).withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFFB300).withValues(alpha: 0.50)),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 20)],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('SORT THIS ITEM', style: TextStyle(color: Colors.white54,
            fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(litEmoji, style: TextStyle(fontSize: mobile ? 44 : 54)),
        const SizedBox(height: 14),
        Row(mainAxisAlignment: MainAxisAlignment.center,
            children: bins.map((b) {
          final (sort, emoji, label, color) = b;
          return GestureDetector(
            onTap: () => game.sortLitter(sort),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 6),
              padding: EdgeInsets.symmetric(
                  horizontal: mobile ? 12 : 18, vertical: 12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: color.withValues(alpha: 0.50)),
                boxShadow: [BoxShadow(
                    color: color.withValues(alpha: 0.25), blurRadius: 8)],
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(emoji, style: TextStyle(fontSize: mobile ? 22 : 26)),
                const SizedBox(height: 4),
                Text(label, style: TextStyle(color: color,
                    fontWeight: FontWeight.w900,
                    fontSize: mobile ? 9 : 10)),
              ]),
            ),
          );
        }).toList()),
      ]),
    ));
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  POND TREATMENT SELECTOR
// ════════════════════════════════════════════════════════════════════════════
class PondTreatmentSelector extends StatelessWidget {
  final HabitatCleanupGame game;
  const PondTreatmentSelector(this.game, {super.key});

  static const _treatments = [
    (PondTreatment.hyacinths,      '🌿', 'Water\nHyacinths', Color(0xFF2E7D32),  'Algae Bloom'),
    (PondTreatment.bacteriaPellets,'🧫', 'Bacteria\nPellets', Color(0xFF795548), 'Organic Waste'),
    (PondTreatment.filtrationUnit, '🔧', 'Filtration\nUnit',  Color(0xFF7B1FA2), 'Chemical'),
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
                Text('SELECT POND TREATMENT',
                    style: TextStyle(color: Colors.white54,
                        fontSize: mobile ? 7.5 : 9,
                        letterSpacing: 1.5, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Row(mainAxisAlignment: MainAxisAlignment.center,
                    children: _treatments.map((t) {
                  final (tr, emoji, label, color, target) = t;
                  final sel = game.selectedTreatment == tr;
                  return GestureDetector(
                    onTap: () => game.selectTreatment(tr),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 140),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: EdgeInsets.symmetric(
                          horizontal: mobile ? 9 : 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: sel ? color.withValues(alpha: 0.22)
                            : Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: sel ? color : Colors.white12,
                            width: sel ? 2.0 : 1.0),
                        boxShadow: sel ? [BoxShadow(
                            color: color.withValues(alpha: 0.35),
                            blurRadius: 10)] : [],
                      ),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(emoji, style: TextStyle(
                            fontSize: mobile ? 18 : 22)),
                        const SizedBox(height: 2),
                        Text(label, textAlign: TextAlign.center,
                            style: TextStyle(
                              color: sel ? color : Colors.white70,
                              fontWeight: FontWeight.w900,
                              fontSize: mobile ? 8 : 9, height: 1.2,
                            )),
                        const SizedBox(height: 1),
                        Text(target, style: TextStyle(
                          color: sel ? color.withValues(alpha: 0.75)
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
//  PHASE BANNER
// ════════════════════════════════════════════════════════════════════════════
class CleanupPhaseBanner extends StatelessWidget {
  final HabitatCleanupGame game;
  const CleanupPhaseBanner(this.game, {super.key});

  @override
  Widget build(BuildContext context) {
    final p1    = game.gamePhase == 1;
    final accent = p1 ? const Color(0xFFFFB300) : const Color(0xFF00897B);
    return IgnorePointer(child: Center(child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: p1
            ? [const Color(0xFF1A1000), const Color(0xFF2E1C00)]
            : [const Color(0xFF001A14), const Color(0xFF003028)]),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 24)],
        border: Border.all(color: accent.withValues(alpha: 0.55), width: 1.5),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(p1 ? 'PHASE 1' : 'PHASE 2',
            style: const TextStyle(color: Colors.white54,
                fontSize: 13, letterSpacing: 2.5)),
        const SizedBox(height: 4),
        Text(p1 ? '🗑️  Waste Collection' : '💧  Water Purification',
            style: const TextStyle(color: Colors.white,
                fontSize: 26, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text(
          p1
              ? 'Fly near litter then tap 🗑️ COLL to scoop it up.\nSort each item into the correct waste bin!'
              : 'Fly near a polluted pond then tap 💧 TREAT.\nSelect the right treatment for each water type!',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
      ]),
    )));
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  REACTION FLASH
// ════════════════════════════════════════════════════════════════════════════
class CleanupReactionFx extends StatelessWidget {
  final HabitatCleanupGame game;
  const CleanupReactionFx(this.game, {super.key});

  @override
  Widget build(BuildContext context) {
    final ok = game.reactionCorrect;
    final p1 = game.reactionPhase == 1;
    final inRange = game.reactionInRange;

    final String title;
    final String sub;
    if (!inRange) {
      title = '🚁  OUT OF RANGE!';
      sub   = 'Move closer first';
    } else if (p1 && ok) {
      title = '🗑️  COLLECTED!';
      sub   = '+20 pts — now sort it!';
    } else if (!p1 && ok) {
      title = '💧  POND CLEAN!';
      sub   = '+25 pts  •  Water purity rises';
    } else {
      title = '❌  WRONG CHOICE!';
      sub   = p1 ? '−5 pts — wrong sort bin' : '−8 pts — water gets worse';
    }

    final accent = (ok || !inRange)
        ? const Color(0xFF69F0AE)
        : const Color(0xFFEF5350);

    return IgnorePointer(child: Stack(children: [
      Container(decoration: BoxDecoration(
        border: Border.all(color: accent, width: 10),
        gradient: RadialGradient(colors: [
          Colors.transparent, accent.withValues(alpha: 0.13),
        ], radius: 1.5),
      )),
      Center(child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
        decoration: BoxDecoration(
            color: ok
                ? const Color(0xFF0A2E10).withValues(alpha: 0.95)
                : const Color(0xFF2E0A0A).withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [BoxShadow(
                color: Colors.black54, blurRadius: 14, spreadRadius: 2)]),
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
//  CLEANUP RESULTS OVERLAY
// ════════════════════════════════════════════════════════════════════════════
class CleanupResultsOverlay extends StatelessWidget {
  final HabitatCleanupGame game;
  const CleanupResultsOverlay(this.game, {super.key});

  @override
  Widget build(BuildContext context) {
    final result = HabitatCleanupResult.current!;
    final clean  = result.waterPurity >= 80;

    return Container(
      color: Colors.black.withValues(alpha: 0.94),
      child: SafeArea(child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Column(children: [

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: clean
                  ? [const Color(0xFF001A14), const Color(0xFF003028)]
                  : [const Color(0xFF1A1000), const Color(0xFF2A1800)]),
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 16)],
            ),
            child: Column(children: [
              Text(clean ? '💧' : '🌊',
                  style: const TextStyle(fontSize: 52)),
              const SizedBox(height: 8),
              Text(clean ? 'Ponds Restored!' : 'Phase Complete',
                  style: const TextStyle(color: Colors.white, fontSize: 22,
                      fontWeight: FontWeight.bold, letterSpacing: 0.8)),
              const SizedBox(height: 4),
              const Text('Phase 1 & 2 — Waste & Water Results',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
            ]),
          ),

          const SizedBox(height: 16),

          _CRCard(children: [
            _CRBig('🗑️', '${result.litterCollected}', 'Litter',
                const Color(0xFFFFB300)),
            _CRBig('♻️', '${result.correctSorts}', 'Sorted',
                Colors.limeAccent),
            _CRBig('💧', '${result.pondsClean}', 'Ponds',
                const Color(0xFF00897B)),
            _CRBig('⭐', '${result.ecoPoints}', 'Eco-Pts',
                Colors.amber),
          ]),

          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF081008),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(children: [
              const Text('Actions Applied',
                  style: TextStyle(color: Colors.white70, fontSize: 12,
                      fontWeight: FontWeight.bold, letterSpacing: 1)),
              const SizedBox(height: 12),
              _CRRow('🧴', 'Plastic / Metal', '♻️ Recyclable bin'),
              _CRRow('🍌', 'Organic waste',   '🌿 Biodegradable bin'),
              _CRRow('🍶', 'Glass items',     '🔄 Reusable bin'),
              _CRRow('🌿', 'Algae blooms',    '🌿 Water hyacinths deployed'),
              _CRRow('🦠', 'Organic ponds',   '🧫 Bacteria pellets applied'),
              _CRRow('☠️', 'Chemical ponds',  '🔧 Filtration units installed'),
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
              icon: const Icon(Icons.pets_rounded),
              label: const Text('Continue to Wildlife Rescue  →',
                  style: TextStyle(fontSize: 15,
                      fontWeight: FontWeight.bold, letterSpacing: 0.8)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFB300),
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

class _CRCard extends StatelessWidget {
  final List<Widget> children;
  const _CRCard({required this.children});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    decoration: BoxDecoration(
      color: const Color(0xFF081008),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white12),
    ),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: children),
  );
}

class _CRBig extends StatelessWidget {
  final String emoji, value, label;
  final Color color;
  const _CRBig(this.emoji, this.value, this.label, this.color);
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

class _CRRow extends StatelessWidget {
  final String emoji, label, action;
  const _CRRow(this.emoji, this.label, this.action);
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