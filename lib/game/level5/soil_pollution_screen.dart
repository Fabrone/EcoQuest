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
  final int    zonesRemediated;
  final int    wrongTreatments;
  final int    ecoPoints;
  final double soilHealthFinal;
  final bool   soilGuardianBadge;

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
enum SoilPollutantType { oilSpill, acidicSoil, heavyMetals, pesticides, compactSoil }
enum RemediationAgent  { biocharBacteria, limeGypsum, phytoPlants, compostWorms, earthworms }

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
      carryOver:       widget.carryOver,
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
          'hud':         (ctx, g) => SoilHud(g as SoilPollutionGame),
          'controls':    (ctx, g) => SoilControls(g as SoilPollutionGame),
          'banner':      (ctx, g) => SoilPhaseBanner(g as SoilPollutionGame),
          'agentSelect': (ctx, g) => RemediationAgentSelector(g as SoilPollutionGame),
          'reactionFx':  (ctx, g) => SoilReactionFx(g as SoilPollutionGame),
          'results':     (ctx, g) => SoilResultsOverlay(g as SoilPollutionGame),
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
  final VoidCallback    onLevelComplete;

  SoilPollutionGame({required this.carryOver, required this.onLevelComplete});

  // ── State ─────────────────────────────────────────────────────────────────
  int    gamePhase   = 3;   // 3 = diagnose, 4 = remediate
  bool   gameStarted = false;
  double timeLeft    = 120.0;
  bool   levelDone   = false;

  // ── Score ─────────────────────────────────────────────────────────────────
  int ecoPoints         = 0;
  int wrongTreatments   = 0;
  int remediatedCount   = 0;
  int diagnosedCount    = 0;

  // ── Soil health ───────────────────────────────────────────────────────────
  double soilHealth = 12.0;   // starts low, must reach >= 80
  static const double _targetHealth  = 80.0;
  static const double _fixGain       = 9.0;
  static const double _wrongPenalty  = 5.0;

  // ── Range constants ───────────────────────────────────────────────────────
  static const double _scanRange  = 155.0;
  static const double _applyRange = 100.0;

  // ── Drone physics ─────────────────────────────────────────────────────────
  late Vector2 dronePos;
  bool isUp = false, isDown = false, isLeft = false, isRight = false;
  static const double _droneSpeed = 185.0;

  // ── Agent selection ───────────────────────────────────────────────────────
  RemediationAgent selectedAgent = RemediationAgent.biocharBacteria;

  // ── Reaction FX ──────────────────────────────────────────────────────────
  bool   reactionActive  = false;
  bool   reactionCorrect = false;
  int    reactionPhase   = 3;
  bool   reactionInRange = true;
  double reactionTimer   = 0;

  // ── Banner ────────────────────────────────────────────────────────────────
  double bannerTimer = 3.5;

  // ── Scan animation ────────────────────────────────────────────────────────
  bool   scanActive  = false;
  double scanRadius  = 0;
  static const double _scanMaxRadius = 180.0;

  // ── Components ────────────────────────────────────────────────────────────
  late SoilDroneComponent drone;
  final List<SoilZone> zones = [];

  @override
  Future<void> onLoad() async {
    super.onLoad();
    dronePos = Vector2(size.x * 0.50, size.y * 0.58);

    add(SoilLayerRenderer(game: this));
    drone = SoilDroneComponent(game: this);
    add(drone);

    _spawnZones();

    bannerTimer = 3.5;
    overlays.add('banner');
    add(TimerComponent(period: 1.0, repeat: true, onTick: _onSecond));
  }

  void _spawnZones() {
    final specs = [
      (SoilPollutantType.oilSpill,     0.15, 0.30),
      (SoilPollutantType.oilSpill,     0.74, 0.48),
      (SoilPollutantType.acidicSoil,   0.34, 0.58),
      (SoilPollutantType.acidicSoil,   0.58, 0.22),
      (SoilPollutantType.heavyMetals,  0.48, 0.40),
      (SoilPollutantType.pesticides,   0.88, 0.68),
      (SoilPollutantType.compactSoil,  0.20, 0.75),
      (SoilPollutantType.compactSoil,  0.65, 0.78),
      (SoilPollutantType.pesticides,   0.82, 0.28),
      (SoilPollutantType.heavyMetals,  0.10, 0.52),
    ];
    for (int i = 0; i < specs.length; i++) {
      final (type, rx, ry) = specs[i];
      final z = SoilZone(
        game: this, type: type,
        worldX: size.x * rx, worldY: size.y * ry,
        seed: i * 23,
      );
      add(z);
      zones.add(z);
    }
  }

  void _onSecond() {
    if (!gameStarted || levelDone) return;
    timeLeft -= 1;
    if (timeLeft <= 0) { timeLeft = 0; _endLevel(); }
    notifyListeners();
  }

  bool get _hasNearbyUndiagnosed =>
      zones.any((z) => !z.isDiagnosed &&
          (z.zonePos - dronePos).length <= _scanRange);

  bool get _hasNearbyUnremediated =>
      zones.any((z) => !z.isRemediated &&
          (z.zonePos - dronePos).length <= _applyRange);

  SoilZone? get _nearestUnremediated {
    SoilZone? target;
    double best = _applyRange;
    for (final z in zones) {
      if (z.isRemediated) continue;
      final d = (z.zonePos - dronePos).length;
      if (d < best) { best = d; target = z; }
    }
    return target;
  }

  // ── Phase 3 — Diagnose ────────────────────────────────────────────────────
  void diagnoseZone() {
    if (!gameStarted || levelDone || gamePhase != 3) return;
    gameStarted = true;
    HapticFeedback.selectionClick();

    int newly = 0;
    for (final z in zones) {
      if (z.isDiagnosed) continue;
      if ((z.zonePos - dronePos).length <= _scanRange) {
        z.reveal();
        diagnosedCount++;
        newly++;
      }
    }

    if (newly > 0) {
      ecoPoints += newly * 5;
      scanActive = true;
      scanRadius = 0;
      _triggerReaction(true);
      if (diagnosedCount >= zones.length) {
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
      ..add('agentSelect');
    notifyListeners();
  }

  // ── Phase 4 — Remediate ───────────────────────────────────────────────────
  void applyAgent() {
    if (!gameStarted || levelDone || gamePhase != 4) return;
    final target = _nearestUnremediated;
    if (target == null) { _triggerReaction(false, inRange: false); return; }

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
      ecoPoints  = math.max(0, ecoPoints - 10);
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
      case SoilPollutantType.oilSpill:    return agent == RemediationAgent.biocharBacteria;
      case SoilPollutantType.acidicSoil:  return agent == RemediationAgent.limeGypsum;
      case SoilPollutantType.heavyMetals: return agent == RemediationAgent.phytoPlants;
      case SoilPollutantType.pesticides:  return agent == RemediationAgent.compostWorms;
      case SoilPollutantType.compactSoil: return agent == RemediationAgent.earthworms;
    }
  }

  void selectAgent(RemediationAgent a) { selectedAgent = a; notifyListeners(); }

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

    SoilPollutionResult.current = SoilPollutionResult(
      zonesRemediated:  remediatedCount,
      wrongTreatments:  wrongTreatments,
      ecoPoints:        ecoPoints,
      soilHealthFinal:  soilHealth,
      soilGuardianBadge: soilHealth >= _targetHealth,
    );

    overlays
      ..remove('reactionFx')
      ..remove('agentSelect')
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
//  SOIL LAYER RENDERER  — cross-section soil profile
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

    // Sky — cleaner than land phase (land is stabilised)
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h),
        Paint()
          ..shader = ui.Gradient.linear(Offset(0, 0), Offset(0, h), [
            const Color(0xFF0E0A04),
            Color.lerp(const Color(0xFF181006), const Color(0xFF1A1208),
                (math.sin(_t) * 0.5 + 0.5) * 0.4)!,
            const Color(0xFF0C0804),
          ], [0.0, 0.5, 1.0]));

    // Health green overlay — increases as soil heals
    final healthRatio = (game.soilHealth / 100.0).clamp(0.0, 1.0);
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h),
        Paint()
          ..color = const Color(0xFF69F0AE).withValues(alpha: healthRatio * 0.04)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30));

    // Soil profile horizontal bands
    _drawSoilLayers(canvas, w, h);

    // Field grid
    _drawFieldGrid(canvas, w, h);

    // Ground strip
    canvas.drawRect(Rect.fromLTWH(0, h * 0.86, w, h * 0.14),
        Paint()..color = const Color(0xFF080402));
  }

  void _drawSoilLayers(Canvas canvas, double w, double h) {
    // Top layer — contaminated (grey-brown)
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h * 0.35),
        Paint()..color = const Color(0xFF120C06));
    // Mid layer — chemical residue (darker)
    canvas.drawRect(Rect.fromLTWH(0, h * 0.35, w, h * 0.28),
        Paint()..color = const Color(0xFF0E0A04));
    // Bottom layer — compact subsoil
    canvas.drawRect(Rect.fromLTWH(0, h * 0.63, w, h * 0.23),
        Paint()..color = const Color(0xFF0A0802));
  }

  void _drawFieldGrid(Canvas canvas, double w, double h) {
    final linePaint = Paint()
      ..color = const Color(0xFF1A1004).withValues(alpha: 0.7)
      ..strokeWidth = 8;
    for (final ry in [0.30, 0.54, 0.72]) {
      canvas.drawLine(Offset(0, h * ry), Offset(w, h * ry), linePaint);
    }
    for (final rx in [0.25, 0.52, 0.76]) {
      canvas.drawLine(Offset(w * rx, 0), Offset(w * rx, h * 0.86), linePaint);
    }
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  SOIL DRONE COMPONENT
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

    if (game.scanActive) {
      final alpha =
          (1.0 - game.scanRadius / SoilPollutionGame._scanMaxRadius) * 0.30;
      canvas.drawCircle(Offset(cx, cy), game.scanRadius,
          Paint()
            ..color = const Color(0xFFFFB300).withValues(alpha: alpha)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5);
    }

    final rangeColor = game.gamePhase == 3
        ? const Color(0xFFFFB300)
        : const Color(0xFF69F0AE);
    final rangeR = game.gamePhase == 3
        ? SoilPollutionGame._scanRange
        : SoilPollutionGame._applyRange;
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
      ..color = const Color(0xFF3A2810)
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;
    for (final (dx, dy) in [(-1, -1), (1, -1), (-1, 1), (1, 1)]) {
      canvas.drawLine(
          Offset(dx * 8, dy * 8), Offset(dx * 22, dy * 22), armPaint);
    }

    final propPaint = Paint()
      ..color = const Color(0xFFFFB300).withValues(alpha: 0.55)
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    for (final (px, py) in [(-22.0, -22.0), (22.0, -22.0),
          (-22.0, 22.0), (22.0, 22.0)]) {
      canvas.drawLine(Offset(px - 8, py), Offset(px + 8, py), propPaint);
      canvas.drawLine(Offset(px, py - 8), Offset(px, py + 8), propPaint);
    }

    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(-13, -10, 26, 20), const Radius.circular(6)),
        Paint()..color = const Color(0xFF2A1C0A));

    final glowColor = game.gamePhase == 3
        ? const Color(0xFFFFB300)
        : const Color(0xFF69F0AE);
    canvas.drawCircle(Offset.zero, 7,
        Paint()
          ..color = glowColor.withValues(alpha: 0.75 + math.sin(_t * 4) * 0.20)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    canvas.drawCircle(Offset.zero, 3.5,
        Paint()..color = Colors.white.withValues(alpha: 0.95));

    final tp = TextPainter(
      text: TextSpan(
          text: game.gamePhase == 3 ? '🔬' : '🌱',
          style: const TextStyle(fontSize: 8)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(-tp.width / 2, 13 - tp.height / 2));

    canvas.restore();
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  SOIL ZONE COMPONENT
// ════════════════════════════════════════════════════════════════════════════
class SoilZone extends Component {
  final SoilPollutionGame game;
  final SoilPollutantType type;
  double hx, hy;
  final int seed;
  bool isDiagnosed  = false;
  bool isRemediated = false;
  double _t = 0;

  SoilZone({
    required this.game, required this.type,
    required double worldX, required double worldY,
    required this.seed,
  }) : hx = worldX, hy = worldY;

  Vector2 get zonePos => Vector2(hx, hy);

  void reveal()    => isDiagnosed = true;
  void remediate() { isRemediated = true; isDiagnosed = true; }

  static const _specs = {
    SoilPollutantType.oilSpill:    ('🛢️', 'Oil\nSpill',      Color(0xFF212121), '85%'),
    SoilPollutantType.acidicSoil:  ('⚗️', 'Acidic\nSoil',   Color(0xFFCE93D8), '78%'),
    SoilPollutantType.heavyMetals: ('⚙️', 'Heavy\nMetals',  Color(0xFF7B1FA2), '90%'),
    SoilPollutantType.pesticides:  ('🧪', 'Pesticide\nZone', Color(0xFFFF6D00), '72%'),
    SoilPollutantType.compactSoil: ('🪨', 'Compact\nSoil',  Color(0xFFBCAAA4), '65%'),
  };

  @override
  void update(double dt) => _t += dt;

  @override
  void render(Canvas canvas) {
    if (isRemediated) { _drawRemediated(canvas); return; }

    final spec  = _specs[type]!;
    final color = spec.$3;
    final pulse = 0.65 + math.sin(_t * 2.8) * 0.22;

    if (isDiagnosed) {
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

  void _drawRemediated(Canvas canvas) {
    canvas.drawCircle(Offset(hx, hy), 22,
        Paint()..color = const Color(0xFF69F0AE).withValues(alpha: 0.14));
    canvas.drawCircle(Offset(hx, hy), 22,
        Paint()
          ..color = const Color(0xFF69F0AE).withValues(alpha: 0.60)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0);
    final tp = TextPainter(
      text: const TextSpan(text: '🌱', style: TextStyle(fontSize: 13)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(hx - tp.width / 2, hy - tp.height / 2));
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  SOIL HUD
// ════════════════════════════════════════════════════════════════════════════
class SoilHud extends StatelessWidget {
  final SoilPollutionGame game;
  const SoilHud(this.game, {super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: game,
      builder: (_, __) {
        final warn        = game.timeLeft < 20;
        final healthRatio  = (game.soilHealth / 100.0).clamp(0.0, 1.0);
        final healthColor  = game.soilHealth >= 80
            ? const Color(0xFF69F0AE)
            : game.soilHealth >= 50
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
                    ? const Color(0xFFFFB300).withValues(alpha: 0.88)
                    : const Color(0xFF69F0AE).withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(
                    color: (game.gamePhase == 3
                        ? const Color(0xFFFFB300)
                        : const Color(0xFF69F0AE)).withValues(alpha: 0.35),
                    blurRadius: 10)],
              ),
              child: Text(
                game.gamePhase == 3
                    ? '🔬  PHASE 3 — SOIL DIAGNOSIS'
                    : '🌱  PHASE 4 — BIOREMEDIATION',
                style: const TextStyle(color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 12, letterSpacing: 1.1),
              ),
            )),
            const SizedBox(height: 8),

            Row(children: [
              _SHTile(Icons.timer_rounded, '${game.timeLeft.toInt()}s', 'TIME',
                  warn ? Colors.red : Colors.white),
              const SizedBox(width: 6),
              _SHTile(Icons.biotech_rounded,
                  game.gamePhase == 3
                      ? '${game.diagnosedCount}/10'
                      : '${game.remediatedCount}/10',
                  game.gamePhase == 3 ? 'DIAGNOSED' : 'TREATED',
                  const Color(0xFFFFB300)),
              const SizedBox(width: 6),
              _SHTile(Icons.eco_rounded, '${game.ecoPoints}', 'ECO-PTS',
                  Colors.limeAccent),
              const SizedBox(width: 6),
              _SHTile(Icons.grass_rounded,
                  '${game.soilHealth.toStringAsFixed(0)}%', 'HEALTH',
                  healthColor),
            ]),
            const SizedBox(height: 5),

            Row(children: [
              const Text('🌱', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Expanded(child: ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: LinearProgressIndicator(
                  value: healthRatio,
                  backgroundColor: Colors.white12,
                  valueColor: AlwaysStoppedAnimation(healthColor),
                  minHeight: 8,
                ),
              )),
              const SizedBox(width: 6),
              RichText(text: TextSpan(children: [
                TextSpan(text: '${game.soilHealth.toStringAsFixed(0)}%',
                    style: TextStyle(color: healthColor, fontSize: 10,
                        fontWeight: FontWeight.bold)),
                const TextSpan(text: ' / 80%',
                    style: TextStyle(color: Color(0xFF69F0AE), fontSize: 8)),
              ])),
            ]),
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
//  SOIL CONTROLS
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
        widget.game.diagnoseZone();
      } else {
        widget.game.applyAgent();
      }
    }
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

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.game,
      builder: (_, __) {
        final phase    = widget.game.gamePhase;
        final canAct   = phase == 3
            ? widget.game._hasNearbyUndiagnosed
            : widget.game._hasNearbyUnremediated;
        final actColor = phase == 3
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
                  _SPad('⬆', _up, Colors.cyanAccent,
                      onDown: () { setState(() => _up = true);  widget.game.setUpKey(true); },
                      onUp:   () { setState(() => _up = false); widget.game.setUpKey(false); }),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    _SPad('◀', _lt, Colors.cyanAccent,
                        onDown: () { setState(() => _lt = true);  widget.game.setLeftKey(true); },
                        onUp:   () { setState(() => _lt = false); widget.game.setLeftKey(false); }),
                    const SizedBox(width: 4),
                    _SPad('⬇', _dn, Colors.cyanAccent,
                        onDown: () { setState(() => _dn = true);  widget.game.setDownKey(true); },
                        onUp:   () { setState(() => _dn = false); widget.game.setDownKey(false); }),
                    const SizedBox(width: 4),
                    _SPad('▶', _rt, Colors.cyanAccent,
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
                      widget.game.diagnoseZone();
                    } else {
                      widget.game.applyAgent();
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
                      phase == 3 ? '🔬\nSCAN' : '🌱\nAPPLY',
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

class _SPad extends StatelessWidget {
  final String label;
  final bool isActive;
  final Color color;
  final VoidCallback onDown, onUp;
  const _SPad(this.label, this.isActive, this.color,
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
class SoilPhaseBanner extends StatelessWidget {
  final SoilPollutionGame game;
  const SoilPhaseBanner(this.game, {super.key});

  @override
  Widget build(BuildContext context) {
    final phase3  = game.gamePhase == 3;
    final accent  = phase3 ? const Color(0xFFFFB300) : const Color(0xFF69F0AE);

    return IgnorePointer(child: Center(child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
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
            style: const TextStyle(color: Colors.white54,
                fontSize: 13, letterSpacing: 2.5)),
        const SizedBox(height: 4),
        Text(phase3 ? '🔬  Soil Diagnosis' : '🌱  Bioremediation',
            style: const TextStyle(color: Colors.white,
                fontSize: 26, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text(
          phase3
              ? 'Fly near contaminated zones then tap 🔬 SCAN\nto identify each pollutant type.'
              : 'Select the correct remedy and tap 🌱 APPLY\nwhen near each polluted zone.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
      ]),
    )));
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  REMEDIATION AGENT SELECTOR  (Phase 4 only)
// ════════════════════════════════════════════════════════════════════════════
class RemediationAgentSelector extends StatelessWidget {
  final SoilPollutionGame game;
  const RemediationAgentSelector(this.game, {super.key});

  static const _agents = [
    (RemediationAgent.biocharBacteria, '🛢️', 'Biochar+\nBacteria', Color(0xFF212121), 'Oil Spill'),
    (RemediationAgent.limeGypsum,      '🪨', 'Lime /\nGypsum',     Color(0xFFCE93D8), 'Acidic'),
    (RemediationAgent.phytoPlants,     '🌻', 'Phyto-\nPlants',     Color(0xFF7B1FA2), 'Heavy Metals'),
    (RemediationAgent.compostWorms,    '🌿', 'Compost+\nWorms',    Color(0xFFFF6D00), 'Pesticides'),
    (RemediationAgent.earthworms,      '🪱', 'Earth-\nworms',      Color(0xFFBCAAA4), 'Compact'),
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
            padding: const EdgeInsets.only(bottom: 80, left: 8, right: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.78),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('SELECT REMEDIATION AGENT',
                    style: TextStyle(
                        color: Colors.white54,
                        fontSize: mobile ? 7.5 : 9,
                        letterSpacing: 1.5, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Row(mainAxisAlignment: MainAxisAlignment.center,
                    children: _agents.map((a) {
                  final (agent, emoji, label, color, target) = a;
                  final sel = game.selectedAgent == agent;
                  return GestureDetector(
                    onTap: () => game.selectAgent(agent),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 140),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      padding: EdgeInsets.symmetric(
                          horizontal: mobile ? 7 : 10, vertical: 7),
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
                        Text(emoji,
                            style: TextStyle(fontSize: mobile ? 16 : 20)),
                        const SizedBox(height: 2),
                        Text(label, textAlign: TextAlign.center,
                            style: TextStyle(
                              color: sel ? color : Colors.white70,
                              fontWeight: FontWeight.w900,
                              fontSize: mobile ? 7 : 8, height: 1.2,
                            )),
                        const SizedBox(height: 1),
                        Text(target, style: TextStyle(
                          color: sel ? color.withValues(alpha: 0.75) : Colors.white38,
                          fontSize: 6.5,
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
//  SOIL REACTION FLASH
// ════════════════════════════════════════════════════════════════════════════
class SoilReactionFx extends StatelessWidget {
  final SoilPollutionGame game;
  const SoilReactionFx(this.game, {super.key});

  @override
  Widget build(BuildContext context) {
    final ok      = game.reactionCorrect;
    final phase3  = game.reactionPhase == 3;
    final inRange = game.reactionInRange;

    final String title;
    final String sub;
    if (!inRange) {
      title = '🔬  OUT OF RANGE!';
      sub   = 'Move closer to a contaminated zone first';
    } else if (phase3 && ok) {
      title = '🔬  POLLUTANT FOUND!';
      sub   = '+5 Eco-Points per zone diagnosed';
    } else if (!phase3 && ok) {
      title = '🌱  SOIL HEALING!';
      sub   = '+20 Eco-Points  •  Soil health rises';
    } else {
      title = '❌  WRONG TREATMENT!';
      sub   = '−10 Eco-Points  •  Soil health drops';
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
                ? const Color(0xFF0A2E10).withValues(alpha: 0.95)
                : const Color(0xFF2E0A0A).withValues(alpha: 0.95),
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
//  SOIL RESULTS OVERLAY
// ════════════════════════════════════════════════════════════════════════════
class SoilResultsOverlay extends StatelessWidget {
  final SoilPollutionGame game;
  const SoilResultsOverlay(this.game, {super.key});

  @override
  Widget build(BuildContext context) {
    final result  = SoilPollutionResult.current!;
    final guardian = result.soilGuardianBadge;
    final hFinal  = result.soilHealthFinal.toStringAsFixed(0);

    return Container(
      color: Colors.black.withValues(alpha: 0.94),
      child: SafeArea(child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Column(children: [

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: guardian
                  ? [const Color(0xFF001A0A), const Color(0xFF003018)]
                  : [const Color(0xFF1A1000), const Color(0xFF2A1800)]),
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 16)],
            ),
            child: Column(children: [
              Text(guardian ? '🌻' : '🌱',
                  style: const TextStyle(fontSize: 52)),
              const SizedBox(height: 8),
              Text(guardian ? 'Soil Fully Regenerated!' : 'Phase Complete',
                  style: const TextStyle(color: Colors.white, fontSize: 22,
                      fontWeight: FontWeight.bold, letterSpacing: 0.8)),
              const SizedBox(height: 4),
              const Text('Phase 3 & 4 — Soil Pollution Results',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
              if (guardian) ...[
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
                    Text('Soil Guardian Badge Unlocked!',
                        style: TextStyle(color: Color(0xFF69F0AE),
                            fontWeight: FontWeight.w800, fontSize: 12)),
                  ]),
                ),
              ],
            ]),
          ),

          const SizedBox(height: 16),

          _SRCard(children: [
            _SRBig('🌱', '$hFinal%', 'Soil Health',
                guardian ? const Color(0xFF69F0AE) : const Color(0xFFFFB300)),
            _SRBig('✅', '${result.zonesRemediated}', 'Treated',   Colors.limeAccent),
            _SRBig('❌', '${result.wrongTreatments}', 'Wrong',     Colors.redAccent),
            _SRBig('⭐', '${result.ecoPoints}',       'Eco-Pts',   Colors.amber),
          ]),

          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0A1A08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(children: [
              const Text('Bioremediation Applied',
                  style: TextStyle(color: Colors.white70, fontSize: 12,
                      fontWeight: FontWeight.bold, letterSpacing: 1)),
              const SizedBox(height: 12),
              _SRRow('🛢️', 'Oil Spills',    '🌑 Biochar + bacteria cultures'),
              _SRRow('⚗️', 'Acidic Soil',  '🪨 Lime / gypsum neutralised'),
              _SRRow('⚙️', 'Heavy Metals', '🌻 Phyto-plants absorbed metals'),
              _SRRow('🧪', 'Pesticides',   '🌿 Compost + worms decomposed'),
              _SRRow('🪨', 'Compact Soil', '🪱 Earthworms restored aeration'),
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
              label: const Text('Complete Level 5  →',
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
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: children),
  );
}

class _SRBig extends StatelessWidget {
  final String emoji, value, label;
  final Color color;
  const _SRBig(this.emoji, this.value, this.label, this.color);
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

class _SRRow extends StatelessWidget {
  final String emoji, label, action;
  const _SRRow(this.emoji, this.label, this.action);
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