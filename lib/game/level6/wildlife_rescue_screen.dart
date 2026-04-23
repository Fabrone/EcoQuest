import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:ecoquest/game/level6/degraded_park_screen.dart';
import 'package:ecoquest/game/level6/level6_complete_screen.dart';
import 'package:flame/components.dart' hide Matrix4;
import 'package:flame/game.dart' hide Matrix4;
import 'package:flutter/material.dart' hide Matrix4;
import 'package:flutter/services.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  WILDLIFE RESCUE RESULT
// ══════════════════════════════════════════════════════════════════════════════
class WildlifeRescueResult {
  final int    animalsRescued;
  final int    postersPlaced;
  final int    ecoPoints;
  final double habitatHealth;
  final bool   guardianOfNatureBadge;

  const WildlifeRescueResult({
    required this.animalsRescued,
    required this.postersPlaced,
    required this.ecoPoints,
    required this.habitatHealth,
    required this.guardianOfNatureBadge,
  });

  static WildlifeRescueResult? current;
}

// ══════════════════════════════════════════════════════════════════════════════
//  ENUMS
// ══════════════════════════════════════════════════════════════════════════════
enum AnimalType      { zebra, bird, monkey, impala }
enum FirstAidAction  { cleanWound, splintLimb, feedAnimal }
enum PosterMaterial  { naturalDyes, gypsum, recycledWood }
enum PosterTheme     { deforestation, waterPollution, soilHealth, wildlifeProtection, wasteManagement }

// ══════════════════════════════════════════════════════════════════════════════
//  SCREEN WRAPPER
// ══════════════════════════════════════════════════════════════════════════════
class WildlifeRescueScreen extends StatefulWidget {
  final Level5CarryOver carryOver;
  const WildlifeRescueScreen({super.key, required this.carryOver});

  @override
  State<WildlifeRescueScreen> createState() => _WildlifeRescueScreenState();
}

class _WildlifeRescueScreenState extends State<WildlifeRescueScreen> {
  late WildlifeRescueGame _game;

  @override
  void initState() {
    super.initState();
    _game = WildlifeRescueGame(
      carryOver:       widget.carryOver,
      onLevelComplete: _onDone,
    );
  }

  void _onDone() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => Level6CompleteScreen(carryOver: widget.carryOver),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GameWidget(
        game: _game,
        overlayBuilderMap: {
          'hud':         (ctx, g) => RescueHud(g as WildlifeRescueGame),
          'controls':    (ctx, g) => RescueControls(g as WildlifeRescueGame),
          'banner':      (ctx, g) => RescuePhaseBanner(g as WildlifeRescueGame),
          'firstAid':    (ctx, g) => FirstAidMiniGame(g as WildlifeRescueGame),
          'posterTray':  (ctx, g) => PosterTray(g as WildlifeRescueGame),
          'reactionFx':  (ctx, g) => RescueReactionFx(g as WildlifeRescueGame),
          'results':     (ctx, g) => RescueResultsOverlay(g as WildlifeRescueGame),
        },
        initialActiveOverlays: const ['hud', 'controls'],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  MAIN GAME CLASS
// ══════════════════════════════════════════════════════════════════════════════
class WildlifeRescueGame extends FlameGame
    with HasCollisionDetection, ChangeNotifier {

  final Level5CarryOver carryOver;
  final VoidCallback    onLevelComplete;

  WildlifeRescueGame({required this.carryOver, required this.onLevelComplete});

  // ── State ─────────────────────────────────────────────────────────────────
  int    gamePhase   = 3;   // 3 = rescue, 4 = posters
  bool   gameStarted = false;
  double timeLeft    = 120.0;
  bool   levelDone   = false;

  // ── Score ─────────────────────────────────────────────────────────────────
  int ecoPoints      = 0;
  int animalsRescued = 0;
  int postersPlaced  = 0;

  // ── Habitat health ────────────────────────────────────────────────────────
  double habitatHealth = 20.0;
  static const double _targetHealth  = 80.0;
  static const double _rescueGain    = 10.0;
  static const double _posterGain    = 6.0;
  static const double _missedPenalty = 5.0;

  // ── Ranges ────────────────────────────────────────────────────────────────
  static const double _rescueRange = 90.0;
  static const double _posterRange = 85.0;

  // ── Drone ─────────────────────────────────────────────────────────────────
  late Vector2 dronePos;
  bool isUp = false, isDown = false, isLeft = false, isRight = false;
  static const double _droneSpeed = 175.0;

  // ── First-aid mini-game ───────────────────────────────────────────────────
  bool            firstAidActive  = false;
  InjuredAnimal?  currentAnimal;
  FirstAidAction? requiredAction;

  // ── Poster crafting ───────────────────────────────────────────────────────
  PosterTheme selectedTheme = PosterTheme.wildlifeProtection;

  // ── Reaction FX ──────────────────────────────────────────────────────────
  bool   reactionActive  = false;
  bool   reactionCorrect = false;
  int    reactionPhase   = 3;
  bool   reactionInRange = true;
  double reactionTimer   = 0;

  // ── Banner ────────────────────────────────────────────────────────────────
  double bannerTimer = 3.5;

  // ── Components ────────────────────────────────────────────────────────────
  late RescueDroneComponent drone;
  final List<InjuredAnimal>  animals      = [];
  final List<PosterBoard>    posterBoards = [];

  static const int totalAnimals = 6;
  static const int totalPosters = 5;

  @override
  Future<void> onLoad() async {
    super.onLoad();
    dronePos = Vector2(size.x * 0.50, size.y * 0.52);

    add(RestoringParkRenderer(game: this));
    drone = RescueDroneComponent(game: this);
    add(drone);

    _spawnAnimals();

    bannerTimer = 3.5;
    overlays.add('banner');
    add(TimerComponent(period: 1.0, repeat: true, onTick: _onSecond));
  }

  void _spawnAnimals() {
    final specs = [
      (AnimalType.zebra,  0.18, 0.32, FirstAidAction.cleanWound),
      (AnimalType.bird,   0.72, 0.28, FirstAidAction.feedAnimal),
      (AnimalType.monkey, 0.42, 0.50, FirstAidAction.splintLimb),
      (AnimalType.impala, 0.82, 0.60, FirstAidAction.cleanWound),
      (AnimalType.bird,   0.28, 0.68, FirstAidAction.feedAnimal),
      (AnimalType.zebra,  0.60, 0.72, FirstAidAction.splintLimb),
    ];
    for (int i = 0; i < specs.length; i++) {
      final (type, rx, ry, aid) = specs[i];
      final a = InjuredAnimal(
        game: this, type: type, requiredAid: aid,
        worldX: size.x * rx, worldY: size.y * ry,
        seed: i * 19,
      );
      add(a);
      animals.add(a);
    }
  }

  void _spawnPosterBoards() {
    final locs = [
      (0.12, 0.25), (0.38, 0.18), (0.62, 0.30),
      (0.80, 0.55), (0.20, 0.70),
    ];
    for (int i = 0; i < locs.length; i++) {
      final (rx, ry) = locs[i];
      final b = PosterBoard(
        game: this,
        worldX: size.x * rx, worldY: size.y * ry,
        seed: i * 11,
      );
      add(b);
      posterBoards.add(b);
    }
  }

  void _onSecond() {
    if (!gameStarted || levelDone) return;
    timeLeft -= 1;
    if (timeLeft <= 0) { timeLeft = 0; _endLevel(); }
    notifyListeners();
  }

  // ── Phase 3 helpers ───────────────────────────────────────────────────────
  bool get _hasNearbyAnimal =>
      animals.any((a) => !a.isRescued &&
          (a.animalPos - dronePos).length <= _rescueRange);

  InjuredAnimal? get _nearestAnimal {
    InjuredAnimal? target;
    double best = _rescueRange;
    for (final a in animals) {
      if (a.isRescued) continue;
      final d = (a.animalPos - dronePos).length;
      if (d < best) { best = d; target = a; }
    }
    return target;
  }

  // ── Phase 4 helpers ───────────────────────────────────────────────────────
  bool get _hasNearbyBoard =>
      posterBoards.any((b) => !b.hasPosted &&
          (b.boardPos - dronePos).length <= _posterRange);

  PosterBoard? get _nearestBoard {
    PosterBoard? target;
    double best = _posterRange;
    for (final b in posterBoards) {
      if (b.hasPosted) continue;
      final d = (b.boardPos - dronePos).length;
      if (d < best) { best = d; target = b; }
    }
    return target;
  }

  // ── Phase 3 — Rescue ──────────────────────────────────────────────────────
  void rescueAnimal() {
    if (!gameStarted || levelDone || gamePhase != 3) return;
    gameStarted = true;
    HapticFeedback.lightImpact();

    final target = _nearestAnimal;
    if (target == null) { _triggerReaction(false, inRange: false); return; }

    currentAnimal  = target;
    requiredAction = target.requiredAid;
    firstAidActive = true;
    overlays.add('firstAid');
    notifyListeners();
  }

  void applyFirstAid(FirstAidAction action) {
    firstAidActive = false;
    overlays.remove('firstAid');
    HapticFeedback.selectionClick();

    final correct = action == requiredAction;
    if (correct) {
      currentAnimal!.rescue();
      animalsRescued++;
      habitatHealth = math.min(100, habitatHealth + _rescueGain);
      ecoPoints    += 30;
      _triggerReaction(true);
    } else {
      ecoPoints = math.max(0, ecoPoints - 10);
      habitatHealth = math.max(0, habitatHealth - _missedPenalty);
      _triggerReaction(false);
    }

    if (animals.every((a) => a.isRescued)) {
      Future.delayed(const Duration(milliseconds: 600), _advanceToPhase4);
    }
    notifyListeners();
  }

  void _advanceToPhase4() {
    if (levelDone) return;
    gamePhase   = 4;
    bannerTimer = 3.0;
    _spawnPosterBoards();
    overlays..add('banner')..add('posterTray');
    notifyListeners();
  }

  // ── Phase 4 — Posters ─────────────────────────────────────────────────────
  void placePost() {
    if (!gameStarted || levelDone || gamePhase != 4) return;
    final target = _nearestBoard;
    if (target == null) { _triggerReaction(false, inRange: false); return; }

    HapticFeedback.lightImpact();
    target.post(selectedTheme);
    postersPlaced++;
    habitatHealth = math.min(100, habitatHealth + _posterGain);
    ecoPoints    += 15;
    _triggerReaction(true);

    if (posterBoards.every((b) => b.hasPosted) ||
        habitatHealth >= _targetHealth) {
      Future.delayed(const Duration(milliseconds: 800), _endLevel);
    }
    notifyListeners();
  }

  void selectTheme(PosterTheme t) { selectedTheme = t; notifyListeners(); }

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

    WildlifeRescueResult.current = WildlifeRescueResult(
      animalsRescued:      animalsRescued,
      postersPlaced:       postersPlaced,
      ecoPoints:           ecoPoints,
      habitatHealth:       habitatHealth,
      guardianOfNatureBadge: habitatHealth >= _targetHealth,
    );

    overlays
      ..remove('reactionFx')
      ..remove('posterTray')
      ..remove('firstAid')
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
//  RESTORING PARK RENDERER  — greener than phase 1-2 background
// ════════════════════════════════════════════════════════════════════════════
class RestoringParkRenderer extends Component {
  final WildlifeRescueGame game;
  double _t = 0;
  RestoringParkRenderer({required this.game});

  @override
  void update(double dt) => _t += dt * 0.2;

  @override
  void render(Canvas canvas) {
    final w = game.size.x, h = game.size.y;

    canvas.drawRect(Rect.fromLTWH(0, 0, w, h),
        Paint()..shader = ui.Gradient.linear(
            Offset(0, 0), Offset(0, h), [
          const Color(0xFF060E06),
          Color.lerp(const Color(0xFF0A1808), const Color(0xFF0E2010),
              (math.sin(_t) * 0.5 + 0.5) * 0.4)!,
          const Color(0xFF060A04),
        ], [0.0, 0.5, 1.0]));

    // Habitat health tint
    final hr = (game.habitatHealth / 100.0).clamp(0.0, 1.0);
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h),
        Paint()
          ..color = const Color(0xFF69F0AE).withValues(alpha: hr * 0.06)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30));

    _drawField(canvas, w, h);
    canvas.drawRect(Rect.fromLTWH(0, h * 0.86, w, h * 0.14),
        Paint()..color = const Color(0xFF040806));
  }

  void _drawField(Canvas canvas, double w, double h) {
    final rng = math.Random(66);
    for (final (bx, by, bw, bh) in [
      (0.02, 0.02, 0.22, 0.26), (0.26, 0.02, 0.22, 0.26),
      (0.50, 0.02, 0.22, 0.26), (0.74, 0.02, 0.24, 0.26),
      (0.02, 0.32, 0.22, 0.22), (0.26, 0.32, 0.22, 0.22),
      (0.50, 0.32, 0.22, 0.22), (0.74, 0.32, 0.24, 0.22),
      (0.02, 0.58, 0.22, 0.20),
    ]) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(w*bx+4, h*by+4, w*bw-8, h*bh-8),
              const Radius.circular(3)),
          Paint()..color = const Color(0xFF0A1608));
      _drawVegetation(canvas, w*bx+6, h*by+6, w*bw-12, h*bh-12, rng);
    }
  }

  void _drawVegetation(Canvas canvas, double bx, double by,
      double bw, double bh, math.Random rng) {
    for (int i = 0; i < 7; i++) {
      final gx = bx + rng.nextDouble() * bw;
      final gy = by + rng.nextDouble() * bh;
      canvas.drawLine(
        Offset(gx, gy), Offset(gx, gy - 8),
        Paint()
          ..color = const Color(0xFF2E4A20).withValues(alpha: 0.55)
          ..strokeWidth = 1.2,
      );
    }
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  RESCUE DRONE COMPONENT
// ════════════════════════════════════════════════════════════════════════════
class RescueDroneComponent extends Component {
  final WildlifeRescueGame game;
  double _t = 0;
  RescueDroneComponent({required this.game});

  @override
  void update(double dt) => _t += dt;

  @override
  void render(Canvas canvas) {
    final cx = game.dronePos.x;
    final cy = game.dronePos.y + math.sin(_t * 3.0) * 2.5;

    final rangeColor = game.gamePhase == 3
        ? const Color(0xFFFFB300)
        : const Color(0xFF1E88E5);
    final rangeR = game.gamePhase == 3
        ? WildlifeRescueGame._rescueRange
        : WildlifeRescueGame._posterRange;

    canvas.drawCircle(Offset(cx, cy), rangeR,
        Paint()
          ..color = rangeColor.withValues(alpha: 0.06)
          ..style = PaintingStyle.stroke ..strokeWidth = 1.2);

    canvas.save();
    canvas.translate(cx, cy);

    canvas.drawOval(
        Rect.fromCenter(center: const Offset(0, 14), width: 38, height: 9),
        Paint()..color = Colors.black.withValues(alpha: 0.28));

    final armPaint = Paint()
      ..color = const Color(0xFF1A2E18)
      ..strokeWidth = 3.0 ..strokeCap = StrokeCap.round;
    for (final (dx, dy) in [(-1,-1),(1,-1),(-1,1),(1,1)]) {
      canvas.drawLine(
          Offset(dx*8, dy*8), Offset(dx*22, dy*22), armPaint);
    }

    final propPaint = Paint()
      ..color = const Color(0xFFFFB300).withValues(alpha: 0.55)
      ..strokeWidth = 1.8 ..strokeCap = StrokeCap.round;
    for (final (px, py) in [(-22.0,-22.0),(22.0,-22.0),(-22.0,22.0),(22.0,22.0)]) {
      canvas.drawLine(Offset(px-8,py), Offset(px+8,py), propPaint);
      canvas.drawLine(Offset(px,py-8), Offset(px,py+8), propPaint);
    }

    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(-13,-10,26,20), const Radius.circular(6)),
        Paint()..color = const Color(0xFF142810));

    final glowColor = game.gamePhase == 3
        ? const Color(0xFFFFB300) : const Color(0xFF1E88E5);
    canvas.drawCircle(Offset.zero, 7,
        Paint()
          ..color = glowColor.withValues(alpha: 0.75 + math.sin(_t*4)*0.20)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    canvas.drawCircle(Offset.zero, 3.5,
        Paint()..color = Colors.white.withValues(alpha: 0.95));

    final tp = TextPainter(
      text: TextSpan(
          text: game.gamePhase == 3 ? '🦓' : '📋',
          style: const TextStyle(fontSize: 8)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(-tp.width/2, 13 - tp.height/2));

    canvas.restore();
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  INJURED ANIMAL COMPONENT
// ════════════════════════════════════════════════════════════════════════════
class InjuredAnimal extends Component {
  final WildlifeRescueGame game;
  final AnimalType type;
  final FirstAidAction requiredAid;
  double hx, hy;
  final int seed;
  bool isRescued = false;
  double _t = 0;

  InjuredAnimal({
    required this.game, required this.type, required this.requiredAid,
    required double worldX, required double worldY, required this.seed,
  }) : hx = worldX, hy = worldY;

  Vector2 get animalPos => Vector2(hx, hy);

  void rescue() => isRescued = true;

  static const _specs = {
    AnimalType.zebra:  ('🦓', Color(0xFF90A4AE)),
    AnimalType.bird:   ('🦜', Color(0xFF558B2F)),
    AnimalType.monkey: ('🐒', Color(0xFF795548)),
    AnimalType.impala: ('🦌', Color(0xFFFFB300)),
  };

  @override
  void update(double dt) { _t += dt; }

  @override
  void render(Canvas canvas) {
    if (isRescued) { _drawRescued(canvas); return; }
    final spec  = _specs[type]!;
    final pulse = 0.7 + math.sin(_t * 2.4) * 0.20;

    // Red distress ring
    canvas.drawCircle(Offset(hx, hy), 30 * pulse,
        Paint()
          ..color = const Color(0xFFEF5350).withValues(alpha: 0.10)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    canvas.drawCircle(Offset(hx, hy), 24,
        Paint()
          ..color = const Color(0xFFEF5350).withValues(alpha: 0.55)
          ..style = PaintingStyle.stroke ..strokeWidth = 2.0);

    final ep = TextPainter(
      text: TextSpan(text: spec.$1, style: const TextStyle(fontSize: 16)),
      textDirection: TextDirection.ltr,
    )..layout();
    ep.paint(canvas, Offset(hx - ep.width/2, hy - ep.height/2 - 4));

    // Distress heart
    final hp = TextPainter(
      text: const TextSpan(text: '❤️',
          style: TextStyle(fontSize: 9)),
      textDirection: TextDirection.ltr,
    )..layout();
    hp.paint(canvas, Offset(hx - hp.width/2, hy + 14));
  }

  void _drawRescued(Canvas canvas) {
    canvas.drawCircle(Offset(hx, hy), 22,
        Paint()..color = const Color(0xFF69F0AE).withValues(alpha: 0.14));
    canvas.drawCircle(Offset(hx, hy), 22,
        Paint()
          ..color = const Color(0xFF69F0AE).withValues(alpha: 0.60)
          ..style = PaintingStyle.stroke ..strokeWidth = 2.0);
    final tp = TextPainter(
      text: const TextSpan(text: '✅', style: TextStyle(fontSize: 13)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(hx - tp.width/2, hy - tp.height/2));
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  POSTER BOARD COMPONENT
// ════════════════════════════════════════════════════════════════════════════
class PosterBoard extends Component {
  final WildlifeRescueGame game;
  double hx, hy;
  final int seed;
  bool hasPosted = false;
  PosterTheme? theme;
  double _t = 0;

  PosterBoard({required this.game,
      required double worldX, required double worldY, required this.seed})
      : hx = worldX, hy = worldY;

  Vector2 get boardPos => Vector2(hx, hy);

  void post(PosterTheme t) { hasPosted = true; theme = t; }

  @override
  void update(double dt) { _t += dt; }

  @override
  void render(Canvas canvas) {
    final pulse = 0.70 + math.sin(_t * 2.2) * 0.18;

    if (hasPosted) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(hx, hy), width: 34, height: 26),
            const Radius.circular(4)),
        Paint()..color = const Color(0xFF1E88E5).withValues(alpha: 0.25),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(hx, hy), width: 34, height: 26),
            const Radius.circular(4)),
        Paint()
          ..color = const Color(0xFF69F0AE).withValues(alpha: 0.70)
          ..style = PaintingStyle.stroke ..strokeWidth = 1.8,
      );
      final tp = TextPainter(
        text: const TextSpan(text: '📋', style: TextStyle(fontSize: 14)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(hx - tp.width/2, hy - tp.height/2));
    } else {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(hx, hy),
                width: 34 * pulse, height: 26 * pulse),
            const Radius.circular(4)),
        Paint()
          ..color = const Color(0xFF1E88E5).withValues(alpha: 0.40)
          ..style = PaintingStyle.stroke ..strokeWidth = 1.8,
      );
      final tp = TextPainter(
        text: const TextSpan(text: '📌',
            style: TextStyle(fontSize: 12)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(hx - tp.width/2, hy - tp.height/2));
    }
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  HUD
// ════════════════════════════════════════════════════════════════════════════
class RescueHud extends StatelessWidget {
  final WildlifeRescueGame game;
  const RescueHud(this.game, {super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: game,
      builder: (_, __) {
        final warn     = game.timeLeft < 20;
        final hr        = (game.habitatHealth / 100.0).clamp(0.0, 1.0);
        final hColor    = game.habitatHealth >= 80
            ? const Color(0xFF69F0AE)
            : game.habitatHealth >= 50
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
                    : const Color(0xFF1E88E5).withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(
                    color: (game.gamePhase == 3
                        ? const Color(0xFFFFB300)
                        : const Color(0xFF1E88E5)).withValues(alpha: 0.35),
                    blurRadius: 10)],
              ),
              child: Text(
                game.gamePhase == 3
                    ? '🦓  PHASE 3 — WILDLIFE RESCUE'
                    : '📋  PHASE 4 — AWARENESS CAMPAIGN',
                style: const TextStyle(color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 12, letterSpacing: 1.1),
              ),
            )),
            const SizedBox(height: 8),

            Row(children: [
              _RHTile(Icons.timer_rounded,
                  '${game.timeLeft.toInt()}s', 'TIME',
                  warn ? Colors.red : Colors.white),
              const SizedBox(width: 6),
              _RHTile(game.gamePhase == 3
                      ? Icons.pets_rounded : Icons.campaign_rounded,
                  game.gamePhase == 3
                      ? '${game.animalsRescued}/${WildlifeRescueGame.totalAnimals}'
                      : '${game.postersPlaced}/${WildlifeRescueGame.totalPosters}',
                  game.gamePhase == 3 ? 'RESCUED' : 'POSTERS',
                  const Color(0xFFFFB300)),
              const SizedBox(width: 6),
              _RHTile(Icons.eco_rounded, '${game.ecoPoints}', 'ECO-PTS',
                  Colors.limeAccent),
              const SizedBox(width: 6),
              _RHTile(Icons.forest_rounded,
                  '${game.habitatHealth.toStringAsFixed(0)}%', 'HABITAT',
                  hColor),
            ]),
            const SizedBox(height: 5),

            Row(children: [
              const Text('🌿', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Expanded(child: ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: LinearProgressIndicator(
                  value: hr,
                  backgroundColor: Colors.white12,
                  valueColor: AlwaysStoppedAnimation(hColor),
                  minHeight: 8,
                ),
              )),
              const SizedBox(width: 6),
              RichText(text: TextSpan(children: [
                TextSpan(text: '${game.habitatHealth.toStringAsFixed(0)}%',
                    style: TextStyle(color: hColor, fontSize: 10,
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

class _RHTile extends StatelessWidget {
  final IconData icon;
  final String val, label;
  final Color color;
  const _RHTile(this.icon, this.val, this.label, this.color);
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
class RescueControls extends StatefulWidget {
  final WildlifeRescueGame game;
  const RescueControls(this.game, {super.key});
  @override
  State<RescueControls> createState() => _RescueControlsState();
}

class _RescueControlsState extends State<RescueControls> {
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
        widget.game.rescueAnimal();
      } else {
        widget.game.placePost();
      }
    }
    if (k == LogicalKeyboardKey.digit1 && pressed) {
      widget.game.selectTheme(PosterTheme.deforestation);
    }
    if (k == LogicalKeyboardKey.digit2 && pressed) {
      widget.game.selectTheme(PosterTheme.waterPollution);
    }
    if (k == LogicalKeyboardKey.digit3 && pressed) {
      widget.game.selectTheme(PosterTheme.soilHealth);
    }
    if (k == LogicalKeyboardKey.digit4 && pressed) {
      widget.game.selectTheme(PosterTheme.wildlifeProtection);
    }
    if (k == LogicalKeyboardKey.digit5 && pressed) {
      widget.game.selectTheme(PosterTheme.wasteManagement);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.game,
      builder: (_, __) {
        final phase  = widget.game.gamePhase;
        final canAct = phase == 3
            ? widget.game._hasNearbyAnimal
            : widget.game._hasNearbyBoard;
        final actColor = phase == 3
            ? const Color(0xFFFFB300)
            : const Color(0xFF1E88E5);

        return KeyboardListener(
          focusNode: _fk,
          onKeyEvent: _onKey,
          child: Stack(children: [

            Align(
              alignment: Alignment.bottomLeft,
              child: SafeArea(child: Padding(
                padding: const EdgeInsets.only(bottom: 16, left: 12),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  _RPad('⬆', _up, Colors.cyanAccent,
                      onDown: () { setState(() => _up=true);  widget.game.setUpKey(true); },
                      onUp:   () { setState(() => _up=false); widget.game.setUpKey(false); }),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    _RPad('◀', _lt, Colors.cyanAccent,
                        onDown: () { setState(() => _lt=true);  widget.game.setLeftKey(true); },
                        onUp:   () { setState(() => _lt=false); widget.game.setLeftKey(false); }),
                    const SizedBox(width: 4),
                    _RPad('⬇', _dn, Colors.cyanAccent,
                        onDown: () { setState(() => _dn=true);  widget.game.setDownKey(true); },
                        onUp:   () { setState(() => _dn=false); widget.game.setDownKey(false); }),
                    const SizedBox(width: 4),
                    _RPad('▶', _rt, Colors.cyanAccent,
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
                  onTap: () => phase == 3
                      ? widget.game.rescueAnimal()
                      : widget.game.placePost(),
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
                      phase == 3 ? '🦓\nGUIDE' : '📋\nPLACE',
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

class _RPad extends StatelessWidget {
  final String label;
  final bool isActive;
  final Color color;
  final VoidCallback onDown, onUp;
  const _RPad(this.label, this.isActive, this.color,
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
//  FIRST AID MINI-GAME OVERLAY
// ════════════════════════════════════════════════════════════════════════════
class FirstAidMiniGame extends StatelessWidget {
  final WildlifeRescueGame game;
  const FirstAidMiniGame(this.game, {super.key});

  @override
  Widget build(BuildContext context) {
    if (!game.firstAidActive) return const SizedBox.shrink();
    final animal = game.currentAnimal;
    if (animal == null) return const SizedBox.shrink();

    final mobile = MediaQuery.of(context).size.width < 600;

    const actions = [
      (FirstAidAction.cleanWound, '🧴', 'Clean\nWound',   Color(0xFF29B6F6)),
      (FirstAidAction.splintLimb, '🩹', 'Splint\nLimb',   Color(0xFFFFB300)),
      (FirstAidAction.feedAnimal, '🌾', 'Feed\nAnimal',   Color(0xFF558B2F)),
    ];

    const animalEmojis = {
      AnimalType.zebra:  '🦓',
      AnimalType.bird:   '🦜',
      AnimalType.monkey: '🐒',
      AnimalType.impala: '🦌',
    };

    return Center(child: Container(
      margin: EdgeInsets.symmetric(horizontal: mobile ? 20 : 60),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF081008).withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: const Color(0xFFEF5350).withValues(alpha: 0.50)),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 20)],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('APPLY FIRST AID',
            style: TextStyle(color: Colors.white54,
                fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(animalEmojis[animal.type] ?? '🐾',
            style: TextStyle(fontSize: mobile ? 44 : 54)),
        const SizedBox(height: 6),
        Text(
          'What does this animal need?',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.60),
              fontSize: mobile ? 11 : 12),
        ),
        const SizedBox(height: 14),
        Row(mainAxisAlignment: MainAxisAlignment.center,
            children: actions.map((a) {
          final (action, emoji, label, color) = a;
          return GestureDetector(
            onTap: () => game.applyFirstAid(action),
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
                Text(emoji, style: TextStyle(
                    fontSize: mobile ? 22 : 26)),
                const SizedBox(height: 4),
                Text(label, textAlign: TextAlign.center,
                    style: TextStyle(color: color,
                        fontWeight: FontWeight.w900,
                        fontSize: mobile ? 9 : 10, height: 1.2)),
              ]),
            ),
          );
        }).toList()),
      ]),
    ));
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  POSTER TRAY  (Phase 4)
// ════════════════════════════════════════════════════════════════════════════
class PosterTray extends StatelessWidget {
  final WildlifeRescueGame game;
  const PosterTray(this.game, {super.key});

  static const _themes = [
    (PosterTheme.deforestation,     '🌳', 'Deforestation', Color(0xFF2E7D32)),
    (PosterTheme.waterPollution,    '💧', 'Water\nPollution', Color(0xFF0288D1)),
    (PosterTheme.soilHealth,        '🌱', 'Soil\nHealth', Color(0xFFFFB300)),
    (PosterTheme.wildlifeProtection,'🦓', 'Wildlife',     Color(0xFFEF5350)),
    (PosterTheme.wasteManagement,   '♻️', 'Waste\nMgmt', Color(0xFF29B6F6)),
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
                Text('SELECT POSTER THEME',
                    style: TextStyle(color: Colors.white54,
                        fontSize: mobile ? 7.5 : 9,
                        letterSpacing: 1.5, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Row(mainAxisAlignment: MainAxisAlignment.center,
                    children: _themes.map((t) {
                  final (theme, emoji, label, color) = t;
                  final sel = game.selectedTheme == theme;
                  return GestureDetector(
                    onTap: () => game.selectTheme(theme),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 140),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      padding: EdgeInsets.symmetric(
                          horizontal: mobile ? 7 : 10, vertical: 7),
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
                            fontSize: mobile ? 16 : 20)),
                        const SizedBox(height: 2),
                        Text(label, textAlign: TextAlign.center,
                            style: TextStyle(
                                color: sel ? color : Colors.white70,
                                fontWeight: FontWeight.w900,
                                fontSize: mobile ? 7 : 8, height: 1.2)),
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
class RescuePhaseBanner extends StatelessWidget {
  final WildlifeRescueGame game;
  const RescuePhaseBanner(this.game, {super.key});

  @override
  Widget build(BuildContext context) {
    final p3    = game.gamePhase == 3;
    final accent = p3 ? const Color(0xFFFFB300) : const Color(0xFF1E88E5);
    return IgnorePointer(child: Center(child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: p3
            ? [const Color(0xFF1A1000), const Color(0xFF2E1C00)]
            : [const Color(0xFF001020), const Color(0xFF002040)]),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 24)],
        border: Border.all(color: accent.withValues(alpha: 0.55), width: 1.5),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(p3 ? 'PHASE 3' : 'PHASE 4',
            style: const TextStyle(color: Colors.white54,
                fontSize: 13, letterSpacing: 2.5)),
        const SizedBox(height: 4),
        Text(p3 ? '🦓  Wildlife Rescue' : '📋  Awareness Campaign',
            style: const TextStyle(color: Colors.white,
                fontSize: 26, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text(
          p3
              ? 'Fly near an injured animal then tap 🦓 GUIDE.\nApply the correct first aid to heal it!'
              : 'Select a poster theme, fly to a board,\nthen tap 📋 PLACE to install it!',
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
class RescueReactionFx extends StatelessWidget {
  final WildlifeRescueGame game;
  const RescueReactionFx(this.game, {super.key});

  @override
  Widget build(BuildContext context) {
    final ok      = game.reactionCorrect;
    final p3      = game.reactionPhase == 3;
    final inRange = game.reactionInRange;

    final String title;
    final String sub;
    if (!inRange) {
      title = '🚁  OUT OF RANGE!';
      sub   = 'Move closer first';
    } else if (p3 && ok) {
      title = '🦓  ANIMAL HEALED!';
      sub   = '+30 pts  •  Wildlife returns!';
    } else if (!p3 && ok) {
      title = '📋  POSTER PLACED!';
      sub   = '+15 pts  •  Eco-consciousness rises';
    } else {
      title = '❌  WRONG CHOICE!';
      sub   = p3 ? '−10 pts — wrong first-aid' : '−5 pts';
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
//  RESCUE RESULTS OVERLAY
// ════════════════════════════════════════════════════════════════════════════
class RescueResultsOverlay extends StatelessWidget {
  final WildlifeRescueGame game;
  const RescueResultsOverlay(this.game, {super.key});

  @override
  Widget build(BuildContext context) {
    final result  = WildlifeRescueResult.current!;
    final guardian = result.guardianOfNatureBadge;

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
              Text(guardian ? '🦓' : '🌿',
                  style: const TextStyle(fontSize: 52)),
              const SizedBox(height: 8),
              Text(guardian ? 'Ondiri Restored!' : 'Phase Complete',
                  style: const TextStyle(color: Colors.white, fontSize: 22,
                      fontWeight: FontWeight.bold, letterSpacing: 0.8)),
              const SizedBox(height: 4),
              const Text('Phase 3 & 4 — Wildlife & Awareness Results',
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
                    Text('Guardian of Nature Badge Unlocked!',
                        style: TextStyle(color: Color(0xFF69F0AE),
                            fontWeight: FontWeight.w800, fontSize: 12)),
                  ]),
                ),
              ],
            ]),
          ),

          const SizedBox(height: 16),

          _RRCard(children: [
            _RRBig('🦓', '${result.animalsRescued}', 'Rescued',
                const Color(0xFFFFB300)),
            _RRBig('📋', '${result.postersPlaced}', 'Posters',
                const Color(0xFF1E88E5)),
            _RRBig('🌿', '${result.habitatHealth.toStringAsFixed(0)}%',
                'Habitat', const Color(0xFF69F0AE)),
            _RRBig('⭐', '${result.ecoPoints}', 'Eco-Pts', Colors.amber),
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
              const Text('Restoration Actions',
                  style: TextStyle(color: Colors.white70, fontSize: 12,
                      fontWeight: FontWeight.bold, letterSpacing: 1)),
              const SizedBox(height: 12),
              _RRRow('🦓', 'Zebra wounds',     '🧴 Cleaned & bandaged'),
              _RRRow('🦜', 'Malnourished birds', '🌾 Fed and released'),
              _RRRow('🐒', 'Injured monkeys',  '🩹 Limbs splinted'),
              _RRRow('🦌', 'Impala injuries',  '🧴 Wound care applied'),
              _RRRow('📋', 'Posters placed',   '🎨 Dyes, chalk & wood used'),
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
              label: const Text('Complete Level 6  →',
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

class _RRCard extends StatelessWidget {
  final List<Widget> children;
  const _RRCard({required this.children});
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

class _RRBig extends StatelessWidget {
  final String emoji, value, label;
  final Color color;
  const _RRBig(this.emoji, this.value, this.label, this.color);
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

class _RRRow extends StatelessWidget {
  final String emoji, label, action;
  const _RRRow(this.emoji, this.label, this.action);
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