import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:ecoquest/game/level4/air_noise_city_screen.dart';
import 'package:ecoquest/game/level4/noise_pollution_screen.dart';
import 'package:flame/components.dart' hide Matrix4;
import 'package:flame/game.dart' hide Matrix4;
import 'package:flutter/material.dart' hide Matrix4;
import 'package:flutter/services.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  AIR POLLUTION RESULT  — passed to NoisePollutionScreen
// ══════════════════════════════════════════════════════════════════════════════
class AirPollutionResult {
  final int pollutantsNeutralized;
  final int wrongArrows;
  final int ecoPoints;
  final int methanol;   // by-product count
  final int gypsum;
  final int urea;
  final int nitrates;

  const AirPollutionResult({
    required this.pollutantsNeutralized,
    required this.wrongArrows,
    required this.ecoPoints,
    required this.methanol,
    required this.gypsum,
    required this.urea,
    required this.nitrates,
  });

  static AirPollutionResult? current;
}

// ══════════════════════════════════════════════════════════════════════════════
//  ENUMS
// ══════════════════════════════════════════════════════════════════════════════
enum PollutantType { co, co2, no, no2, so2, nh3, ch4 }
enum ArrowType     { h2, nh3, caco3 }

// ══════════════════════════════════════════════════════════════════════════════
//  SCREEN WRAPPER
// ══════════════════════════════════════════════════════════════════════════════
class AirPollutionGameScreen extends StatefulWidget {
  final Level3CarryOver carryOver;
  const AirPollutionGameScreen({super.key, required this.carryOver});

  @override
  State<AirPollutionGameScreen> createState() =>
      _AirPollutionGameScreenState();
}

class _AirPollutionGameScreenState extends State<AirPollutionGameScreen> {
  late AirPollutionGame _game;

  @override
  void initState() {
    super.initState();
    _game = AirPollutionGame(
      carryOver: widget.carryOver,
      onLevelComplete: _onDone,
    );
  }

  void _onDone() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => NoisePollutionScreen(
          carryOver: widget.carryOver,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GameWidget(
        game: _game,
        overlayBuilderMap: {
          'hud':         (ctx, g) => AirHud(g as AirPollutionGame),
          'controls':    (ctx, g) => AirControls(g as AirPollutionGame),
          'banner':      (ctx, g) => AirPhaseBanner(g as AirPollutionGame),
          'arrowSelect': (ctx, g) => ArrowSelector(g as AirPollutionGame),
          'reactionFx':  (ctx, g) => ReactionFlash(g as AirPollutionGame),
          'results':     (ctx, g) => AirResultsOverlay(g as AirPollutionGame),
        },
        initialActiveOverlays: const ['hud', 'controls', 'arrowSelect'],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  MAIN GAME CLASS
// ══════════════════════════════════════════════════════════════════════════════
class AirPollutionGame extends FlameGame
    with HasCollisionDetection, ChangeNotifier {

  final Level3CarryOver carryOver;
  final VoidCallback    onLevelComplete;

  AirPollutionGame({required this.carryOver, required this.onLevelComplete});

  // State
  bool   gameStarted = false;
  double timeLeft    = 120.0;
  bool   levelDone   = false;

  // Score / by-products
  int ecoPoints    = 0;
  int wrongArrows  = 0;
  int neutralized  = 0;
  int methanol     = 0;
  int gypsum       = 0;
  int urea         = 0;
  int nitrates     = 0;

  // Air purity 0.0 → 1.0
  double get airPurity => (neutralized / _totalBubbles.clamp(1, 999)).clamp(0, 1);
  static const int _totalBubbles = 20;

  // Glider physics
  late Vector2 gliderPos;
  double gliderVx = 0, gliderVy = 0;
  static const double _gliderSpeed = 200.0;
  bool isUp = false, isDown = false, isLeft = false, isRight = false;
  double tiltX = 0, tiltY = 0;

  // Arrow selection
  ArrowType selectedArrow = ArrowType.h2;

  // Reaction FX
  bool reactionActive  = false;
  bool reactionCorrect = false;
  double reactionTimer = 0;

  // Banner
  double bannerTimer = 0;

  // Child components
  late GliderComponent glider;
  final List<PollutantBubble> bubbles = [];
  final List<Arrow>           arrows  = [];

  final math.Random _rng = math.Random();

  @override
  Future<void> onLoad() async {
    super.onLoad();
    gliderPos = Vector2(size.x / 2, size.y * 0.65);

    add(AirWorldRenderer(game: this));

    glider = GliderComponent(game: this);
    add(glider);

    _spawnBubbles();

    bannerTimer = 3.5;
    overlays.add('banner');
    add(TimerComponent(period: 1.0, repeat: true, onTick: _onSecond));
  }

  void _spawnBubbles() {
    final configs = [
      (PollutantType.co,  6),
      (PollutantType.co2, 3),
      (PollutantType.no,  3),
      (PollutantType.no2, 2),
      (PollutantType.so2, 3),
      (PollutantType.nh3, 2),
      (PollutantType.ch4, 1),
    ];
    for (final (type, count) in configs) {
      for (int i = 0; i < count; i++) {
        final b = PollutantBubble(
          game:   this,
          type:   type,
          worldX: 60 + _rng.nextDouble() * (size.x - 120),
          worldY: 60 + _rng.nextDouble() * (size.y * 0.55),
          seed:   i + type.index * 10,
        );
        add(b);
        bubbles.add(b);
      }
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

  // ── Input ─────────────────────────────────────────────────────────────────
  void setUpKey(bool v)    { isUp    = v; if (v) gameStarted = true; }
  void setDownKey(bool v)  { isDown  = v; if (v) gameStarted = true; }
  void setLeftKey(bool v)  { isLeft  = v; if (v) gameStarted = true; }
  void setRightKey(bool v) { isRight = v; if (v) gameStarted = true; }
  void setTilt(double x, double y) { tiltX = x; tiltY = y; }
  void selectArrow(ArrowType t) {
    selectedArrow = t;
    notifyListeners();
  }

  void fireArrow() {
    if (!gameStarted || levelDone) return;
    gameStarted = true;
    HapticFeedback.lightImpact();

    // Find nearest bubble
    PollutantBubble? target;
    double bestDist = 200.0;
    for (final b in bubbles) {
      if (b.isNeutralized) continue;
      final d = (b.bubblePos - gliderPos).length;
      if (d < bestDist) { bestDist = d; target = b; }
    }
    if (target == null) return;

    final correct = _isCorrectArrow(target.type, selectedArrow);
    if (correct) {
      target.neutralize();
      neutralized++;
      ecoPoints += 10;
      _collectByProduct(target.type);
      _triggerReaction(true);
    } else {
      ecoPoints = math.max(0, ecoPoints - 5);
      wrongArrows++;
      _triggerReaction(false);
    }

    if (bubbles.where((b) => !b.isNeutralized).isEmpty) {
      Future.delayed(const Duration(milliseconds: 800), _endLevel);
    }
    notifyListeners();
  }

  bool _isCorrectArrow(PollutantType p, ArrowType a) {
    switch (p) {
      case PollutantType.co:
      case PollutantType.co2:
      case PollutantType.ch4:
        return a == ArrowType.h2;
      case PollutantType.no:
      case PollutantType.no2:
      case PollutantType.nh3:
        return a == ArrowType.nh3;
      case PollutantType.so2:
        return a == ArrowType.caco3;
    }
  }

  void _collectByProduct(PollutantType p) {
    switch (p) {
      case PollutantType.co:
      case PollutantType.co2:
      case PollutantType.ch4:
        methanol++;
        break;
      case PollutantType.so2:
        gypsum++;
        break;
      case PollutantType.nh3:
        urea++;
        break;
      case PollutantType.no:
      case PollutantType.no2:
        nitrates++;
        break;
    }
  }

  void _triggerReaction(bool correct) {
    reactionActive  = true;
    reactionCorrect = correct;
    reactionTimer   = 1.2;
    overlays.add('reactionFx');
  }

  void _endLevel() {
    if (levelDone) return;
    levelDone = true;
    pauseEngine();

    AirPollutionResult.current = AirPollutionResult(
      pollutantsNeutralized: neutralized,
      wrongArrows:           wrongArrows,
      ecoPoints:             ecoPoints,
      methanol:              methanol,
      gypsum:                gypsum,
      urea:                  urea,
      nitrates:              nitrates,
    );

    overlays
      ..remove('reactionFx')
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

    if (!gameStarted || levelDone) return;

    // Glider movement
    double vx = 0, vy = 0;
    if (isLeft)  vx -= 1; if (isRight) vx += 1;
    if (isUp)    vy -= 1; if (isDown)  vy += 1;
    if (tiltX.abs() > 0.08 && !isLeft && !isRight) vx = tiltX;
    if (tiltY.abs() > 0.08 && !isUp   && !isDown)  vy = -tiltY;

    gliderPos.x = (gliderPos.x + vx * _gliderSpeed * dt).clamp(30, size.x - 30);
    gliderPos.y = (gliderPos.y + vy * _gliderSpeed * dt).clamp(40, size.y * 0.80);

    notifyListeners();
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  AIR WORLD RENDERER — smoggy sky background
// ════════════════════════════════════════════════════════════════════════════
class AirWorldRenderer extends Component {
  final AirPollutionGame game;
  double _t = 0;
  AirWorldRenderer({required this.game});

  @override
  void update(double dt) => _t += dt * 0.4;

  @override
  void render(Canvas canvas) {
    final w = game.size.x;
    final h = game.size.y;

    // Sky gradient — smoggy industrial look
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h),
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(0, 0), Offset(0, h),
            [
              const Color(0xFF080C14),
              Color.lerp(const Color(0xFF0C1018), const Color(0xFF1A0C08),
                  (math.sin(_t * 0.5) * 0.5 + 0.5) * 0.5)!,
              const Color(0xFF100A04),
            ],
            [0.0, 0.5, 1.0],
          ));

    // Haze bands
    for (int i = 0; i < 4; i++) {
      final y  = h * 0.1 + i * h * 0.18 +
          math.sin(_t + i * 1.1) * h * 0.025;
      final a  = 0.04 + i * 0.015;
      canvas.drawRect(
          Rect.fromLTWH(0, y, w, h * 0.15),
          Paint()
            ..color = const Color(0xFF607D8B).withValues(alpha: a)
            ..maskFilter =
                const MaskFilter.blur(BlurStyle.normal, 18));
    }

    // Ground plane
    canvas.drawRect(Rect.fromLTWH(0, h * 0.80, w, h * 0.20),
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(0, h * 0.80), Offset(0, h),
            [const Color(0xFF0C0E14), const Color(0xFF080A10)],
          ));

    // City silhouette at bottom
    _drawSkyline(canvas, w, h);
  }

  void _drawSkyline(Canvas canvas, double w, double h) {
    final rng = math.Random(42);
    double x  = 0;
    while (x < w) {
      final bw = 24 + rng.nextDouble() * 48;
      final bh = 30 + rng.nextDouble() * h * 0.18;
      canvas.drawRect(
          Rect.fromLTWH(x, h * 0.80 - bh, bw, bh),
          Paint()..color = const Color(0xFF050810));
      x += bw + rng.nextDouble() * 12;
    }
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  GLIDER COMPONENT
// ════════════════════════════════════════════════════════════════════════════
class GliderComponent extends Component {
  final AirPollutionGame game;
  double _t = 0;
  GliderComponent({required this.game});

  @override
  void update(double dt) => _t += dt;

  @override
  void render(Canvas canvas) {
    final cx = game.gliderPos.x;
    final cy = game.gliderPos.y + math.sin(_t * 2.0) * 3;

    canvas.save();
    canvas.translate(cx, cy);

    // Drop shadow
    canvas.drawOval(
        Rect.fromCenter(center: const Offset(0, 14),
            width: 44, height: 10),
        Paint()..color = Colors.black.withValues(alpha: 0.35));

    // Wing (left) — swept back for glider look
    final wingPaint = Paint()..color = const Color(0xFF1E3A5F);
    canvas.drawPath(Path()
      ..moveTo(0, 0)
      ..lineTo(-46, 8)
      ..lineTo(-38, 14)
      ..lineTo(-4, 6)
      ..close(), wingPaint);

    // Wing (right)
    canvas.drawPath(Path()
      ..moveTo(0, 0)
      ..lineTo(46, 8)
      ..lineTo(38, 14)
      ..lineTo(4, 6)
      ..close(), wingPaint);

    // Fuselage
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(-5, -16, 10, 32),
            const Radius.circular(5)),
        Paint()..color = const Color(0xFF29B6F6));

    // Nose
    canvas.drawPath(Path()
      ..moveTo(-5, -16)
      ..lineTo(0, -26)
      ..lineTo(5, -16)
      ..close(),
        Paint()..color = const Color(0xFF0288D1));

    // Cockpit glass
    canvas.drawOval(
        Rect.fromLTWH(-4, -13, 8, 10),
        Paint()..color = const Color(0x8881D4FA));

    // Tail
    canvas.drawPath(Path()
      ..moveTo(-5, 12)
      ..lineTo(-12, 18)
      ..lineTo(-5, 18)
      ..close(),
        Paint()..color = const Color(0xFF1E3A5F));
    canvas.drawPath(Path()
      ..moveTo(5, 12)
      ..lineTo(12, 18)
      ..lineTo(5, 18)
      ..close(),
        Paint()..color = const Color(0xFF1E3A5F));

    // Engine glow (rear)
    canvas.drawCircle(const Offset(0, 16), 5,
        Paint()
          ..color = const Color(0xFF69F0AE).withValues(alpha: 0.7)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));

    canvas.restore();
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  POLLUTANT BUBBLE
// ════════════════════════════════════════════════════════════════════════════
class PollutantBubble extends Component {
  final AirPollutionGame game;
  final PollutantType    type;
  double bubbleX, bubbleY;
  final int seed;
  bool   isNeutralized = false;
  double _t = 0;

  PollutantBubble({
    required this.game,
    required this.type,
    required double worldX,
    required double worldY,
    required this.seed,
  })  : bubbleX = worldX,
        bubbleY  = worldY;

  Vector2 get bubblePos => Vector2(bubbleX, bubbleY);

  static const _labels = {
    PollutantType.co:  ('CO',   Color(0xFF78909C), Color(0xFFB0BEC5)),
    PollutantType.co2: ('CO₂',  Color(0xFF546E7A), Color(0xFF90A4AE)),
    PollutantType.no:  ('NO',   Color(0xFF7B1FA2), Color(0xFFCE93D8)),
    PollutantType.no2: ('NO₂',  Color(0xFFE65100), Color(0xFFFF8A65)),
    PollutantType.so2: ('SO₂',  Color(0xFFF9A825), Color(0xFFFFE082)),
    PollutantType.nh3: ('NH₃',  Color(0xFF2E7D32), Color(0xFF81C784)),
    PollutantType.ch4: ('CH₄',  Color(0xFF4E342E), Color(0xFFA1887F)),
  };

  @override
  void update(double dt) {
    if (isNeutralized) return;
    _t += dt;
    final rng = math.Random(seed);
    final driftX = math.sin(_t * (0.4 + rng.nextDouble() * 0.4)) *
        (20 + rng.nextDouble() * 20);
    final driftY = math.cos(_t * (0.3 + rng.nextDouble() * 0.3)) *
        (15 + rng.nextDouble() * 15);
    bubbleX = (game.size.x * (0.05 + (seed % 10) * 0.09)) + driftX;
    bubbleY = game.size.y * (0.08 + (seed % 7) * 0.085) + driftY;
  }

  void neutralize() => isNeutralized = true;

  @override
  void render(Canvas canvas) {
    if (isNeutralized) return;
    final spec = _labels[type]!;
    final label = spec.$1;
    final inner = spec.$2;
    final rim   = spec.$3;

    final pulse = 0.72 + math.sin(_t * 3.5) * 0.12;
    final radius = 28.0 * pulse;

    // Glow
    canvas.drawCircle(
        Offset(bubbleX, bubbleY), radius + 8,
        Paint()
          ..color = inner.withValues(alpha: 0.15 + math.sin(_t * 2) * 0.06)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));

    // Bubble fill
    canvas.drawCircle(Offset(bubbleX, bubbleY), radius,
        Paint()..color = inner.withValues(alpha: 0.35));

    // Rim
    canvas.drawCircle(Offset(bubbleX, bubbleY), radius,
        Paint()
          ..color = rim.withValues(alpha: 0.80)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2);

    // Chemical label
    final tp = TextPainter(
      text: TextSpan(text: label,
          style: TextStyle(
            color: Colors.white,
            fontSize: label.length > 2 ? 11 : 13,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.3,
          )),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas,
        Offset(bubbleX - tp.width / 2, bubbleY - tp.height / 2));
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  ARROW (fired projectile)  — purely visual, collision handled in game
// ════════════════════════════════════════════════════════════════════════════
class Arrow extends Component {
  final AirPollutionGame game;
  double x, y;
  final double dx, dy;
  final ArrowType type;
  bool done = false;

  Arrow({required this.game, required this.x, required this.y,
         required this.dx, required this.dy, required this.type});

  @override
  void update(double dt) {
    if (done) return;
    x += dx * dt * 500;
    y += dy * dt * 500;
    if (x < 0 || x > game.size.x || y < 0 || y > game.size.y) {
      done = true;
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    if (done) return;
    final color = _arrowColor();
    canvas.drawLine(
        Offset(x, y), Offset(x - dx * 20, y - dy * 20),
        Paint()
          ..color = color
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round);
    canvas.drawCircle(Offset(x, y), 5, Paint()..color = color);
  }

  Color _arrowColor() {
    switch (type) {
      case ArrowType.h2:    return const Color(0xFF29B6F6);
      case ArrowType.nh3:   return const Color(0xFF69F0AE);
      case ArrowType.caco3: return const Color(0xFFFFE082);
    }
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  HUD
// ════════════════════════════════════════════════════════════════════════════
class AirHud extends StatelessWidget {
  final AirPollutionGame game;
  const AirHud(this.game, {super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: game,
      builder: (_, __) {
        final warn = game.timeLeft < 20;
        final remaining = bubbles(game);
        return SafeArea(child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [

            // Phase pill
            Align(alignment: Alignment.topCenter, child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6D00).withValues(alpha: 0.90),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(
                    color: const Color(0xFFFF6D00).withValues(alpha: 0.35),
                    blurRadius: 10)],
              ),
              child: const Text('🛩️  PHASE 1 & 2 — AIR PURIFICATION',
                  style: TextStyle(color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 12, letterSpacing: 1.1)),
            )),
            const SizedBox(height: 8),

            // Stats row
            Row(children: [
              _Tile(Icons.timer_rounded, '${game.timeLeft.toInt()}s', 'TIME',
                  warn ? Colors.red : Colors.white),
              const SizedBox(width: 6),
              _Tile(Icons.bubble_chart_rounded, '$remaining', 'BUBBLES',
                  const Color(0xFFFF6D00)),
              const SizedBox(width: 6),
              _Tile(Icons.eco_rounded, '${game.ecoPoints}', 'ECO-PTS',
                  Colors.limeAccent),
              const SizedBox(width: 6),
              _Tile(Icons.air_rounded, '${(game.airPurity * 100).toInt()}%',
                  'PURITY', const Color(0xFF69F0AE)),
            ]),
            const SizedBox(height: 5),

            // Air purity bar
            Row(children: [
              const Text('💨', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Expanded(child: ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: LinearProgressIndicator(
                  value: game.airPurity,
                  backgroundColor: Colors.white12,
                  valueColor: AlwaysStoppedAnimation(
                      game.airPurity > 0.7
                          ? const Color(0xFF29B6F6)
                          : const Color(0xFFFF6D00)),
                  minHeight: 8,
                ),
              )),
              const SizedBox(width: 6),
              Text('${(game.airPurity * 100).toInt()}%',
                  style: const TextStyle(color: Colors.white70, fontSize: 10)),
            ]),

            // By-products row
            const SizedBox(height: 4),
            Row(children: [
              _ByProductChip('⚗️', 'Methanol', game.methanol),
              const SizedBox(width: 4),
              _ByProductChip('🪨', 'Gypsum',   game.gypsum),
              const SizedBox(width: 4),
              _ByProductChip('🌿', 'Urea',     game.urea),
              const SizedBox(width: 4),
              _ByProductChip('🧪', 'Nitrates', game.nitrates),
            ]),
          ]),
        ));
      },
    );
  }

  int bubbles(AirPollutionGame g) =>
      g.bubbles.where((b) => !b.isNeutralized).length;
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String val, label;
  final Color color;
  const _Tile(this.icon, this.val, this.label, this.color);
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

class _ByProductChip extends StatelessWidget {
  final String emoji, label;
  final int count;
  const _ByProductChip(this.emoji, this.label, this.count);
  @override
  Widget build(BuildContext context) => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(vertical: 3),
    decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: Colors.white12)),
    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(emoji, style: const TextStyle(fontSize: 9)),
      const SizedBox(width: 3),
      Text('$count', style: const TextStyle(
          color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
    ]),
  ));
}

// ════════════════════════════════════════════════════════════════════════════
//  ARROW SELECTOR  (bottom tray)
// ════════════════════════════════════════════════════════════════════════════
class ArrowSelector extends StatelessWidget {
  final AirPollutionGame game;
  const ArrowSelector(this.game, {super.key});

  static const _arrows = [
    (ArrowType.h2,    '💨', 'H₂',    Color(0xFF29B6F6), 'CO / CO₂ / CH₄'),
    (ArrowType.nh3,   '🌿', 'NH₃',   Color(0xFF69F0AE), 'NO / NO₂ / NH₃'),
    (ArrowType.caco3, '🪨', 'CaCO₃', Color(0xFFFFE082), 'SO₂'),
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: game,
      builder: (_, __) {
        final mobile = MediaQuery.of(context).size.width < 600;

        return Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(
                  bottom: 80, left: 12, right: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.78),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('SELECT ARROW TYPE',
                      style: TextStyle(
                          color: Colors.white54,
                          fontSize: mobile ? 8 : 9,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: _arrows.map((a) {
                      final (type, emoji, chem, color, target) = a;
                      final sel = game.selectedArrow == type;
                      return GestureDetector(
                        onTap: () => game.selectArrow(type),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 140),
                          margin: const EdgeInsets.symmetric(horizontal: 5),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: sel
                                ? color.withValues(alpha: 0.22)
                                : Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: sel ? color : Colors.white12,
                                width: sel ? 2.0 : 1.0),
                            boxShadow: sel ? [BoxShadow(
                                color: color.withValues(alpha: 0.35),
                                blurRadius: 10)] : [],
                          ),
                          child: Column(
                              mainAxisSize: MainAxisSize.min, children: [
                            Text(emoji,
                                style: TextStyle(
                                    fontSize: mobile ? 18 : 22)),
                            const SizedBox(height: 2),
                            Text(chem,
                                style: TextStyle(
                                  color: sel ? color : Colors.white70,
                                  fontWeight: FontWeight.w900,
                                  fontSize: mobile ? 10 : 11,
                                )),
                            const SizedBox(height: 1),
                            Text(target,
                                style: TextStyle(
                                  color: sel
                                      ? color.withValues(alpha: 0.75)
                                      : Colors.white38,
                                  fontSize: mobile ? 7 : 8,
                                )),
                          ]),
                        ),
                      );
                    }).toList(),
                  ),
                ]),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  CONTROLS OVERLAY  (directional pad + FIRE button)
// ════════════════════════════════════════════════════════════════════════════
class AirControls extends StatefulWidget {
  final AirPollutionGame game;
  const AirControls(this.game, {super.key});
  @override
  State<AirControls> createState() => _AirControlsState();
}

class _AirControlsState extends State<AirControls> {
  bool _up = false, _dn = false, _lt = false, _rt = false;
  late FocusNode _fk;

  @override
  void initState() {
    super.initState();
    _fk = FocusNode();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _fk.requestFocus());
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

    if (k == LogicalKeyboardKey.keyW || k == LogicalKeyboardKey.arrowUp) {
      if (pressed) up(true); if (released) up(false);
    }
    if (k == LogicalKeyboardKey.keyS || k == LogicalKeyboardKey.arrowDown) {
      if (pressed) dn(true); if (released) dn(false);
    }
    if (k == LogicalKeyboardKey.keyA || k == LogicalKeyboardKey.arrowLeft) {
      if (pressed) lt(true); if (released) lt(false);
    }
    if (k == LogicalKeyboardKey.keyD || k == LogicalKeyboardKey.arrowRight) {
      if (pressed) rt(true); if (released) rt(false);
    }
    if (k == LogicalKeyboardKey.space && pressed) widget.game.fireArrow();
    if (k == LogicalKeyboardKey.digit1 && pressed) {
      widget.game.selectArrow(ArrowType.h2);
    }
    if (k == LogicalKeyboardKey.digit2 && pressed) {
      widget.game.selectArrow(ArrowType.nh3);
    }
    if (k == LogicalKeyboardKey.digit3 && pressed) {
      widget.game.selectArrow(ArrowType.caco3);
    }
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _fk,
      onKeyEvent: _onKey,
      child: Stack(children: [
        // D-pad (bottom-left)
        Align(
          alignment: Alignment.bottomLeft,
          child: SafeArea(child: Padding(
            padding: const EdgeInsets.only(
                bottom: 16, left: 12),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _DPadBtn('⬆', _up, Colors.cyanAccent,
                  onDown: () { setState(() => _up = true);  widget.game.setUpKey(true);  },
                  onUp:   () { setState(() => _up = false); widget.game.setUpKey(false); }),
              Row(mainAxisSize: MainAxisSize.min, children: [
                _DPadBtn('◀', _lt, Colors.cyanAccent,
                    onDown: () { setState(() => _lt = true);  widget.game.setLeftKey(true);  },
                    onUp:   () { setState(() => _lt = false); widget.game.setLeftKey(false); }),
                const SizedBox(width: 4),
                _DPadBtn('⬇', _dn, Colors.cyanAccent,
                    onDown: () { setState(() => _dn = true);  widget.game.setDownKey(true);  },
                    onUp:   () { setState(() => _dn = false); widget.game.setDownKey(false); }),
                const SizedBox(width: 4),
                _DPadBtn('▶', _rt, Colors.cyanAccent,
                    onDown: () { setState(() => _rt = true);  widget.game.setRightKey(true);  },
                    onUp:   () { setState(() => _rt = false); widget.game.setRightKey(false); }),
              ]),
            ]),
          )),
        ),

        // FIRE button (bottom-right)
        Align(
          alignment: Alignment.bottomRight,
          child: SafeArea(child: Padding(
            padding: const EdgeInsets.only(
                bottom: 20, right: 14),
            child: GestureDetector(
              onTap: widget.game.fireArrow,
              child: Container(
                width: 68, height: 68,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6D00).withValues(alpha: 0.20),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: const Color(0xFFFF6D00), width: 2.5),
                  boxShadow: [BoxShadow(
                      color: const Color(0xFFFF6D00).withValues(alpha: 0.40),
                      blurRadius: 14)],
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('🎯', style: TextStyle(fontSize: 22)),
                    Text('FIRE', style: TextStyle(
                        color: Color(0xFFFF6D00),
                        fontWeight: FontWeight.w900,
                        fontSize: 9, letterSpacing: 1)),
                  ],
                ),
              ),
            ),
          )),
        ),
      ]),
    );
  }
}

class _DPadBtn extends StatelessWidget {
  final String label;
  final bool isActive;
  final Color color;
  final VoidCallback onDown, onUp;
  const _DPadBtn(this.label, this.isActive, this.color,
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
        boxShadow: isActive ? [BoxShadow(
            color: color.withValues(alpha: 0.40),
            blurRadius: 10)] : [],
      ),
      child: Center(child: Text(label,
          style: TextStyle(
            color: isActive ? color : Colors.white60,
            fontSize: 16, fontWeight: FontWeight.bold,
          ))),
    ),
  );
}

// ════════════════════════════════════════════════════════════════════════════
//  PHASE BANNER
// ════════════════════════════════════════════════════════════════════════════
class AirPhaseBanner extends StatelessWidget {
  final AirPollutionGame game;
  const AirPhaseBanner(this.game, {super.key});
  @override
  Widget build(BuildContext context) {
    return IgnorePointer(child: Center(child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFF1A0A00), Color(0xFF3D1800)]),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(
            color: Colors.black54, blurRadius: 24)],
        border: Border.all(color: const Color(0xFFFF6D00)
            .withValues(alpha: 0.55), width: 1.5),
      ),
      child: const Column(mainAxisSize: MainAxisSize.min, children: [
        Text('PHASE 1 & 2',
            style: TextStyle(color: Colors.white54,
                fontSize: 13, letterSpacing: 2.5)),
        SizedBox(height: 4),
        Text('🛩️  Air Purification',
            style: TextStyle(color: Colors.white,
                fontSize: 26, fontWeight: FontWeight.bold)),
        SizedBox(height: 6),
        Text('Fly close to gas bubbles then select\n'
             'the correct arrow and tap 🎯 FIRE!',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 13)),
      ]),
    )));
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  REACTION FLASH  — correct (blue) or wrong (red)
// ════════════════════════════════════════════════════════════════════════════
class ReactionFlash extends StatelessWidget {
  final AirPollutionGame game;
  const ReactionFlash(this.game, {super.key});
  @override
  Widget build(BuildContext context) {
    final ok = game.reactionCorrect;
    return IgnorePointer(child: Stack(children: [
      Container(decoration: BoxDecoration(
        border: Border.all(
            color: ok ? const Color(0xFF29B6F6) : Colors.red,
            width: 12),
        gradient: RadialGradient(colors: [
          Colors.transparent,
          (ok ? const Color(0xFF29B6F6) : Colors.red)
              .withValues(alpha: 0.15),
        ], radius: 1.5),
      )),
      Center(child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 26, vertical: 12),
        decoration: BoxDecoration(
            color: (ok
                    ? const Color(0xFF0D2A3A)
                    : const Color(0xFF3A0D0D))
                .withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [BoxShadow(
                color: Colors.black54,
                blurRadius: 14, spreadRadius: 2)]),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(ok ? '✅  NEUTRALIZED!' : '❌  WRONG ARROW!',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20, letterSpacing: 0.8)),
          const SizedBox(height: 4),
          Text(ok ? '+10 Eco-Points  •  By-product stored' : '−5 Eco-Points',
              style: TextStyle(
                  color: ok
                      ? const Color(0xFF29B6F6)
                      : const Color(0xFFEF5350),
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
        ]),
      )),
    ]));
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  AIR RESULTS OVERLAY  — shown when phase ends
// ════════════════════════════════════════════════════════════════════════════
class AirResultsOverlay extends StatelessWidget {
  final AirPollutionGame game;
  const AirResultsOverlay(this.game, {super.key});

  @override
  Widget build(BuildContext context) {
    final result  = AirPollutionResult.current!;
    final total   = game.bubbles.length;
    final pct     = total > 0
        ? (result.pollutantsNeutralized / total * 100).toStringAsFixed(0)
        : '0';
    final perfect = result.pollutantsNeutralized == total;

    return Container(
      color: Colors.black.withValues(alpha: 0.94),
      child: SafeArea(child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
            horizontal: 18, vertical: 16),
        child: Column(children: [

          // Header
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: perfect
                      ? [const Color(0xFF003050),
                         const Color(0xFF0D47A1)]
                      : [const Color(0xFF1A0A00),
                         const Color(0xFF3D1800)]),
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [BoxShadow(
                  color: Colors.black54, blurRadius: 16)],
            ),
            child: Column(children: [
              Text(perfect ? '✨' : '🌫️',
                  style: const TextStyle(fontSize: 52)),
              const SizedBox(height: 8),
              Text(perfect ? 'Air Fully Purified!' : 'Phase Complete',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8)),
              const SizedBox(height: 4),
              const Text('Phase 1 & 2 — Air Purification Results',
                  style: TextStyle(
                      color: Colors.white70, fontSize: 13)),
            ]),
          ),

          const SizedBox(height: 16),

          // Score row
          _ResultCard(children: [
            _Big('🏹', '$pct%',
                'Neutralized', const Color(0xFF29B6F6)),
            _Big('✅', '${result.pollutantsNeutralized}',
                'Correct',     Colors.limeAccent),
            _Big('❌', '${result.wrongArrows}',
                'Wrong',       Colors.redAccent),
            _Big('⭐', '${result.ecoPoints}',
                'Eco-Pts',     Colors.amber),
          ]),

          const SizedBox(height: 12),

          // By-products panel
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1B2A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(children: [
              const Text('Chemical By-Products Collected',
                  style: TextStyle(color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1)),
              const SizedBox(height: 12),
              _BPRow('⚗️', 'Methanol',  result.methanol,
                  'Fuel / building material'),
              _BPRow('🪨', 'Gypsum',    result.gypsum,
                  'Construction material / plaster'),
              _BPRow('🌿', 'Urea',      result.urea,
                  'Fertilizer for farming phase'),
              _BPRow('🧪', 'Nitrates',  result.nitrates,
                  'Crop nutrients / fertilizer'),
            ]),
          ),

          const SizedBox(height: 20),

          // Continue button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                game.resumeEngine();
                game.onLevelComplete();
              },
              icon: const Icon(Icons.volume_off_rounded),
              label: const Text('Continue to Noise Reduction  →',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6D00),
                foregroundColor: Colors.white,
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

class _ResultCard extends StatelessWidget {
  final List<Widget> children;
  const _ResultCard({required this.children});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
        horizontal: 12, vertical: 14),
    decoration: BoxDecoration(
      color: const Color(0xFF0D1B2A),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white12),
    ),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: children),
  );
}

class _Big extends StatelessWidget {
  final String emoji, value, label;
  final Color color;
  const _Big(this.emoji, this.value, this.label, this.color);
  @override
  Widget build(BuildContext context) =>
      Column(mainAxisSize: MainAxisSize.min, children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold,
                fontSize: 18)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(
                color: Colors.white54, fontSize: 9),
            textAlign: TextAlign.center),
      ]);
}

class _BPRow extends StatelessWidget {
  final String emoji, label;
  final int count;
  final String desc;
  const _BPRow(this.emoji, this.label, this.count, this.desc);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(children: [
      Text(emoji, style: const TextStyle(fontSize: 16)),
      const SizedBox(width: 8),
      Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(
                color: Colors.white, fontSize: 13,
                fontWeight: FontWeight.w600)),
        Text(desc,
            style: const TextStyle(
                color: Colors.white38, fontSize: 10)),
      ])),
      Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white12),
        ),
        child: Text('$count',
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14)),
      ),
    ]),
  );
}