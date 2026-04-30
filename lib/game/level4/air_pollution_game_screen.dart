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
  // ── Correct shot by-products (chemically accurate) ──────────────────────
  final int methanol;        // CH₃OH  — from CO/CO₂/CH₄ + H₂
  final int gypsum;          // CaSO₄·2H₂O — from SO₂ + CaCO₃ + H₂O
  final int urea;            // CO(NH₂)₂   — from NH₃ + CO₂
  final int nitrates;        // NO₃⁻ / HNO₃ — from NO/NO₂ + NH₃
  // ── Wrong-hit harmful by-products (chemically accurate) ─────────────────
  final int sulfuricAcid;    // H₂SO₄ — wrong arrow on SO₂
  final int nitrousOxide;    // N₂O   — wrong arrow on NO/NO₂
  final int carbonSuboxide;  // C₃O₂  — wrong arrow on CO/CO₂
  final int ammoniumNitrate; // NH₄NO₃ — wrong arrow on NH₃
  final int wrongHits;       // total wrong-hit events (caps at 10)

  const AirPollutionResult({
    required this.pollutantsNeutralized,
    required this.wrongArrows,
    required this.ecoPoints,
    required this.methanol,
    required this.gypsum,
    required this.urea,
    required this.nitrates,
    required this.sulfuricAcid,
    required this.nitrousOxide,
    required this.carbonSuboxide,
    required this.ammoniumNitrate,
    required this.wrongHits,
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
          'hud':          (ctx, g) => AirHud(g as AirPollutionGame),
          'controls':     (ctx, g) => AirControls(g as AirPollutionGame),
          'banner':       (ctx, g) => AirPhaseBanner(g as AirPollutionGame),
          'arrowSelect':  (ctx, g) => ArrowSelector(g as AirPollutionGame),
          'reactionFx':   (ctx, g) => ReactionFlash(g as AirPollutionGame),
          'results':      (ctx, g) => AirResultsOverlay(g as AirPollutionGame),
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

  // Score / correct by-products (chemically accurate)
  int ecoPoints      = 0;
  int wrongArrows    = 0;
  int neutralized    = 0;
  int methanol       = 0;   // CO/CO₂/CH₄ + H₂ → CH₃OH + H₂O
  int gypsum         = 0;   // SO₂ + CaCO₃ + ½O₂ + 2H₂O → CaSO₄·2H₂O + CO₂
  int urea           = 0;   // 2NH₃ + CO₂ → CO(NH₂)₂ + H₂O
  int nitrates       = 0;   // NO/NO₂ + NH₃ → NO₃⁻ salts

  // Wrong-hit harmful by-products (chemically accurate)
  int sulfuricAcid    = 0;  // SO₂ + H₂O → H₂SO₄ (wrong arrow)
  int nitrousOxide    = 0;  // 2NO + O₂ → N₂O₃ / N₂O (wrong arrow)
  int carbonSuboxide  = 0;  // 3CO → C₃O₂ + CO₂ (wrong arrow)
  int ammoniumNitrate = 0;  // NH₃ + HNO₃ → NH₄NO₃ (wrong arrow)

  // Wrong-hit cap: auto-complete at 10 wrong hits
  static const int kMaxWrongHits = 10;

  // Air purity 0.0 → 1.0 — degrades with wrong hits
  double _wrongPurityDrain = 0.0;
  double get airPurity {
    final base = (neutralized / _totalBubbles.clamp(1, 999));
    final drain = _wrongPurityDrain;
    return (base - drain).clamp(0.0, 1.0);
  }
  static const int _totalBubbles = 20;

  // Glider physics
  late Vector2 gliderPos;
  double gliderVx = 0, gliderVy = 0;
  static const double _gliderSpeed = 200.0;
  bool isUp = false, isDown = false, isLeft = false, isRight = false;
  double tiltX = 0, tiltY = 0;

  // Arrow selection
  ArrowType selectedArrow = ArrowType.h2;

  // Reaction FX — now stores the last reaction details for rich feedback
  bool   reactionActive    = false;
  bool   reactionCorrect   = false;
  String reactionProduct   = '';   // chemical product to display
  double reactionTimer     = 0;

  // Particle bursts
  final List<BurstParticle> burstParticles = [];

  // Banner
  double bannerTimer = 0;

  // City animation timer
  //double _cityT = 0;

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

    final target = _findTargetBubble();
    if (target == null) return;

    final arrowType = selectedArrow;

    final arrow = Arrow(
      game:   this,
      x:      gliderPos.x,
      y:      gliderPos.y - 20,
      type:   arrowType,
      target: target,
      onHit: (correct, hitX, hitY) {
        if (correct) {
          target.neutralize();
          neutralized++;
          ecoPoints += 10;
          final product = _collectByProduct(target.type);
          _spawnGreenBurst(hitX, hitY);
          _triggerReaction(true, product);
        } else {
          ecoPoints = math.max(0, ecoPoints - 5);
          wrongArrows++;
          _wrongPurityDrain = math.min(0.5,
              _wrongPurityDrain + 0.05);   // each wrong hit degrades purity
          final harmfulProduct = _collectHarmfulByProduct(target.type, arrowType);
          _spawnExplosionBurst(hitX, hitY);
          _triggerReaction(false, harmfulProduct);

          // Auto-complete at 10 wrong hits
          if (wrongArrows >= kMaxWrongHits) {
            Future.delayed(const Duration(milliseconds: 800), _endLevel);
          }
        }
        if (bubbles.where((b) => !b.isNeutralized).isEmpty) {
          Future.delayed(const Duration(milliseconds: 800), _endLevel);
        }
        notifyListeners();
      },
    );
    add(arrow);
    arrows.add(arrow);
    notifyListeners();
  }

  /// Returns the best bubble to target.
  PollutantBubble? _findTargetBubble() {
    PollutantBubble? target;

    double bestScore = double.infinity;
    for (final b in bubbles) {
      if (b.isNeutralized) continue;
      final dy = gliderPos.y - b.bubbleY;
      if (dy <= 0) continue;
      final dxAbs = (b.bubbleX - gliderPos.x).abs();
      final score = dxAbs * 3 + dy * 0.3;
      if (score < bestScore) { bestScore = score; target = b; }
    }
    if (target != null) return target;

    double bestDist = double.infinity;
    for (final b in bubbles) {
      if (b.isNeutralized) continue;
      final d = (b.bubblePos - gliderPos).length;
      if (d < bestDist) { bestDist = d; target = b; }
    }
    return target;
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

  /// Collect the actual chemically-formed by-product from correct neutralisation.
  /// Chemistry references:
  ///   CO + 2H₂ → CH₃OH (methanol synthesis)
  ///   CO₂ + 3H₂ → CH₃OH + H₂O (methanol from CO₂)
  ///   CH₄ + H₂O → CO + 3H₂ → CH₃OH (methane reforming → methanol)
  ///   SO₂ + CaCO₃ + ½O₂ + 2H₂O → CaSO₄·2H₂O + CO₂ (FGD gypsum)
  ///   2NH₃ + CO₂ → CO(NH₂)₂ + H₂O (urea synthesis)
  ///   4NH₃ + 4NO + O₂ → 4N₂ + 6H₂O (SCR reaction; trace NO₃⁻ deposited)
  ///   NO₂ + NH₃ → NH₄NO₂ / ultimately NO₃⁻ salts
  String _collectByProduct(PollutantType p) {
    switch (p) {
      case PollutantType.co:
      case PollutantType.co2:
      case PollutantType.ch4:
        methanol++;
        return 'CH₃OH\n(Methanol)';
      case PollutantType.so2:
        gypsum++;
        return 'CaSO₄·2H₂O\n(Gypsum)';
      case PollutantType.nh3:
        urea++;
        return 'CO(NH₂)₂\n(Urea)';
      case PollutantType.no:
      case PollutantType.no2:
        nitrates++;
        return 'NO₃⁻ Salts\n(Nitrates)';
    }
  }

  /// Collect the actual harmful compound created by a wrong-arrow hit.
  /// Chemistry references:
  ///   SO₂ + H₂O → H₂SO₃ → H₂SO₄ (sulfuric acid rain precursor)
  ///   2NO + O₂ → 2NO₂ → N₂O₃ / N₂O (nitrous / dinitrogen trioxide)
  ///   3CO → C₃O₂ (carbon suboxide — irritant, toxic)
  ///   NH₃ + HNO₃ → NH₄NO₃ (ammonium nitrate — explosive / hazardous)
  String _collectHarmfulByProduct(PollutantType target, ArrowType wrong) {
    // Determine which harmful compound forms based on pollutant type hit with wrong arrow
    switch (target) {
      case PollutantType.so2:
        sulfuricAcid++;
        return 'H₂SO₄\n(Sulfuric Acid!)';
      case PollutantType.no:
      case PollutantType.no2:
        nitrousOxide++;
        return 'N₂O₃\n(Dinitrogen Trioxide!)';
      case PollutantType.co:
      case PollutantType.co2:
      case PollutantType.ch4:
        carbonSuboxide++;
        return 'C₃O₂\n(Carbon Suboxide!)';
      case PollutantType.nh3:
        ammoniumNitrate++;
        return 'NH₄NO₃\n(Ammonium Nitrate!)';
    }
  }

  // ── Burst particle effects ────────────────────────────────────────────────
  void _spawnGreenBurst(double x, double y) {
    for (int i = 0; i < 18; i++) {
      final angle = (i / 18) * math.pi * 2 + _rng.nextDouble() * 0.3;
      final spd   = 60 + _rng.nextDouble() * 120;
      burstParticles.add(BurstParticle(
        x: x, y: y,
        vx: math.cos(angle) * spd,
        vy: math.sin(angle) * spd,
        color: Color.lerp(
          const Color(0xFF00E676),
          const Color(0xFF69F0AE),
          _rng.nextDouble(),
        )!,
        radius: 4 + _rng.nextDouble() * 5,
        life: 0.0,
        maxLife: 0.7 + _rng.nextDouble() * 0.4,
        isGreen: true,
      ));
    }
  }

  void _spawnExplosionBurst(double x, double y) {
    for (int i = 0; i < 22; i++) {
      final angle = (i / 22) * math.pi * 2 + _rng.nextDouble() * 0.4;
      final spd   = 80 + _rng.nextDouble() * 150;
      burstParticles.add(BurstParticle(
        x: x, y: y,
        vx: math.cos(angle) * spd,
        vy: math.sin(angle) * spd,
        color: [
          const Color(0xFFFF6D00),
          const Color(0xFFFF1744),
          const Color(0xFFFFD600),
          const Color(0xFFBF360C),
        ][_rng.nextInt(4)],
        radius: 5 + _rng.nextDouble() * 7,
        life: 0.0,
        maxLife: 0.6 + _rng.nextDouble() * 0.5,
        isGreen: false,
      ));
    }
  }

  void _triggerReaction(bool correct, String product) {
    reactionActive    = true;
    reactionCorrect   = correct;
    reactionProduct   = product;
    reactionTimer     = 1.6;
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
      sulfuricAcid:          sulfuricAcid,
      nitrousOxide:          nitrousOxide,
      carbonSuboxide:        carbonSuboxide,
      ammoniumNitrate:       ammoniumNitrate,
      wrongHits:             wrongArrows,
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

    // Update burst particles
    burstParticles.removeWhere((p) {
      p.life += dt;
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.vy += 60 * dt; // gravity
      return p.life >= p.maxLife;
    });

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

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    // Draw burst particles on top of everything
    for (final p in burstParticles) {
      final progress = p.life / p.maxLife;
      final alpha    = (1.0 - progress).clamp(0.0, 1.0);
      final r        = p.radius * (1.0 + progress * 0.5);
      if (p.isGreen) {
        // Green bubble: soft glowing circle
        canvas.drawCircle(
          Offset(p.x, p.y), r,
          Paint()
            ..color = p.color.withValues(alpha: alpha * 0.7)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
        );
        canvas.drawCircle(
          Offset(p.x, p.y), r * 0.5,
          Paint()..color = Colors.white.withValues(alpha: alpha * 0.8),
        );
      } else {
        // Explosion: fiery jagged blob
        canvas.drawCircle(
          Offset(p.x, p.y), r,
          Paint()
            ..color = p.color.withValues(alpha: alpha)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        );
        canvas.drawCircle(
          Offset(p.x, p.y), r * 0.4,
          Paint()..color = Colors.white.withValues(alpha: alpha * 0.9),
        );
      }
    }
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  BURST PARTICLE DATA
// ════════════════════════════════════════════════════════════════════════════
class BurstParticle {
  double x, y, vx, vy;
  final Color color;
  final double radius;
  double life;
  final double maxLife;
  final bool isGreen;

  BurstParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.color,
    required this.radius,
    required this.life,
    required this.maxLife,
    required this.isGreen,
  });
}

// ════════════════════════════════════════════════════════════════════════════
//  AIR WORLD RENDERER — realistic side-view city with traffic & pedestrians
// ════════════════════════════════════════════════════════════════════════════
class AirWorldRenderer extends Component {
  final AirPollutionGame game;
  double _t = 0;

  // City animation state
  late List<_SideBuilding> _buildings;
  late List<_SideCar>      _sideCars;
  late List<_SidePed>      _sidePeds;

  AirWorldRenderer({required this.game});

  @override
  Future<void> onLoad() async {
    _initCity();
  }

  void _initCity() {
    // Buildings along left & right sides
    _buildings = [];
    final rng = math.Random(7);
    double leftX  = 0;
    double rightX = game.size.x;

    // Generate a continuous set of building entries for left and right
    for (int i = 0; i < 18; i++) {
      final bw  = 36 + rng.nextDouble() * 70;
      final bh  = 55 + rng.nextDouble() * game.size.y * 0.20;
      final floors = (bh / 18).round().clamp(2, 14);
      final style  = rng.nextInt(5);
      final color  = _buildingColors[rng.nextInt(_buildingColors.length)];

      // Left side building
      _buildings.add(_SideBuilding(
        x: leftX, w: bw, h: bh, floors: floors, style: style,
        color: color, isLeft: true, seed: i * 3,
        startY: -rng.nextDouble() * 1000,
      ));
      leftX += bw + 4 + rng.nextDouble() * 10;

      // Right side building
      final bw2  = 40 + rng.nextDouble() * 65;
      final bh2  = 60 + rng.nextDouble() * game.size.y * 0.22;
      final fl2  = (bh2 / 18).round().clamp(2, 14);
      _buildings.add(_SideBuilding(
        x: game.size.x - bw2 - rightX + game.size.x, w: bw2, h: bh2,
        floors: fl2, style: rng.nextInt(5),
        color: _buildingColors[rng.nextInt(_buildingColors.length)],
        isLeft: false, seed: i * 3 + 1,
        startY: -rng.nextDouble() * 1000,
      ));
    }

    // Side-view traffic cars (on the street at the bottom)
    _sideCars = [];
    for (int i = 0; i < 12; i++) {
      _sideCars.add(_SideCar(
        x: rng.nextDouble() * game.size.x,
        speed: 30 + rng.nextDouble() * 80,
        color: _carColors[rng.nextInt(_carColors.length)],
        kind: rng.nextInt(4),
        seed: i,
        laneY: game.size.y * (0.83 + (i % 2) * 0.05),
      ));
    }

    // Pedestrians walking along the sidewalk
    _sidePeds = [];
    for (int i = 0; i < 10; i++) {
      _sidePeds.add(_SidePed(
        x: rng.nextDouble() * game.size.x,
        speed: 18 + rng.nextDouble() * 28,
        laneY: game.size.y * 0.80,
        seed: i,
        dir: rng.nextBool() ? 1 : -1,
      ));
    }
  }

  static const _buildingColors = [
    Color(0xFF1E3A5F), Color(0xFF3D2B1F), Color(0xFF2C3E50),
    Color(0xFF1A2744), Color(0xFF4A3728), Color(0xFF263238),
    Color(0xFF2E3440), Color(0xFF1B2838), Color(0xFF2D1B69),
    Color(0xFF1A3020),
  ];

  static const _carColors = [
    Color(0xFFCC2200), Color(0xFF1565C0), Color(0xFF33691E),
    Color(0xFF37474F), Color(0xFFF57F17), Color(0xFF880E4F),
    Color(0xFFFFFFFF), Color(0xFF212121),
  ];

  @override
  void update(double dt) {
    _t += dt * 0.4;

    // Scroll traffic cars
    for (final car in _sideCars) {
      car.x += car.speed * dt * car.dir;
      if (car.x > game.size.x + 80) car.x = -80;
      if (car.x < -80) car.x = game.size.x + 80;
      car.time += dt;
    }

    // Scroll pedestrians
    for (final ped in _sidePeds) {
      ped.x += ped.speed * dt * ped.dir;
      if (ped.x > game.size.x + 30) ped.x = -30;
      if (ped.x < -30) ped.x = game.size.x + 30;
      ped.time += dt;
    }
  }

  @override
  void render(Canvas canvas) {
    final w = game.size.x;
    final h = game.size.y;

    // ── Smoggy sky ───────────────────────────────────────────────────────
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h),
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(0, 0), Offset(0, h),
            [
              const Color(0xFF080C14),
              Color.lerp(const Color(0xFF0C1018), const Color(0xFF1A0C08),
                  (math.sin(_t * 0.5) * 0.5 + 0.5) * 0.4)!,
              const Color(0xFF100A04),
            ],
            [0.0, 0.5, 1.0],
          ));

    // ── Haze bands ───────────────────────────────────────────────────────
    for (int i = 0; i < 4; i++) {
      final y = h * 0.08 + i * h * 0.15 +
          math.sin(_t + i * 1.1) * h * 0.02;
      final a = 0.04 + i * 0.018;
      canvas.drawRect(
          Rect.fromLTWH(0, y, w, h * 0.14),
          Paint()
            ..color = const Color(0xFF607D8B).withValues(alpha: a)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18));
    }

    // ── Ground & road strip at bottom ───────────────────────────────────
    final groundY = h * 0.78;
    canvas.drawRect(Rect.fromLTWH(0, groundY, w, h - groundY),
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(0, groundY), Offset(0, h),
            [const Color(0xFF1A1E24), const Color(0xFF080A10)],
          ));

    // Road surface (asphalt strip)
    canvas.drawRect(Rect.fromLTWH(0, groundY + 2, w, (h - groundY) * 0.55),
        Paint()..color = const Color(0xFF1C1C22));

    // Road lane lines
    final lanePaint = Paint()
      ..color = const Color(0xFFFFCC00).withValues(alpha: 0.55)
      ..strokeWidth = 2;
    final roadMidY = groundY + (h - groundY) * 0.28;
    for (double x = 0; x < w; x += 32) {
      canvas.drawLine(
        Offset(x + ((_t * 60) % 32), roadMidY),
        Offset(x + 18 + ((_t * 60) % 32), roadMidY),
        lanePaint,
      );
    }

    // Sidewalk strip
    canvas.drawRect(Rect.fromLTWH(0, groundY - 4, w, 8),
        Paint()..color = const Color(0xFF555566));

    // ── Side-view realistic buildings ────────────────────────────────────
    _drawSideViewBuildings(canvas, w, h, groundY);

    // ── Traffic cars (side view) ─────────────────────────────────────────
    for (final car in _sideCars) {
      _drawSideViewCar(canvas, car);
    }

    // ── Pedestrians ──────────────────────────────────────────────────────
    for (final ped in _sidePeds) {
      _drawSideViewPed(canvas, ped);
    }

    // ── Street lamps ─────────────────────────────────────────────────────
    _drawStreetLamps(canvas, w, h, groundY);

    // ── Smog overlay at horizon ──────────────────────────────────────────
    canvas.drawRect(
      Rect.fromLTWH(0, groundY - 30, w, 40),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, groundY - 30), Offset(0, groundY + 10),
          [
            Colors.transparent,
            const Color(0x44556B7F),
            Colors.transparent,
          ],
          [0.0, 0.5, 1.0],
        )
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
  }

  void _drawSideViewBuildings(Canvas canvas, double w, double h,
      double groundY) {
    final rng = math.Random(42);
    // Draw left-side buildings as a skyline
    double x = 0;
    while (x < w) {
      final bw     = 30 + rng.nextDouble() * 65;
      final bh     = 50 + rng.nextDouble() * h * 0.25;
      final floors = (bh / 16).round().clamp(3, 14);
      final style  = rng.nextInt(5);
      final colIdx = rng.nextInt(_buildingColors.length);
      final col    = _buildingColors[colIdx];

      _drawOneSideBuilding(canvas, x, groundY - bh, bw, bh, floors, col,
          style, rng.nextInt(1000));
      x += bw + rng.nextDouble() * 6;
    }
  }

  void _drawOneSideBuilding(Canvas canvas, double bx, double by, double bw,
      double bh, int floors, Color color, int style, int seed) {
    final rect = Rect.fromLTWH(bx, by, bw, bh);

    // Shadow
    canvas.drawRect(rect.translate(4, 0),
        Paint()..color = Colors.black.withValues(alpha: 0.4));

    // Facade
    canvas.drawRect(rect, Paint()..color = color);

    // Lighter trim at top
    canvas.drawRect(Rect.fromLTWH(bx, by, bw, 6),
        Paint()..color = color.withValues(alpha: 0.5));

    // Windows
    final winCols = 2 + (bw / 22).floor().clamp(1, 5);
    const winPadX = 6.0, winPadY = 10.0;
    final winW = (bw - winPadX * (winCols + 1)) / winCols;
    final winH = 9.0;
    final visFloors = math.min(floors, (bh / 18).floor());

    for (int row = 0; row < visFloors; row++) {
      for (int col = 0; col < winCols; col++) {
        final wx = bx + winPadX + col * (winW + winPadX);
        final wy = by + winPadY + row * (winH + winPadY);
        if (wx + winW > bx + bw - 3) continue;
        if (wy + winH > by + bh - 3) continue;

        // Frame
        canvas.drawRect(Rect.fromLTWH(wx - 1, wy - 1, winW + 2, winH + 2),
            Paint()..color = Colors.black.withValues(alpha: 0.6));

        // Glass (lit or dark; nighttime city feel)
        final isLit = seed * 7 + row * 13 + col * 17 + (_t * 0.1).toInt() % 23 != 0;
        final winColor = isLit
            ? (row % 3 == 0
                ? const Color(0xBBFFEEAA)
                : const Color(0x99AADDFF))
            : const Color(0xFF0A0E14);
        canvas.drawRect(Rect.fromLTWH(wx, wy, winW, winH),
            Paint()..color = winColor);

        // Reflection gleam on lit windows
        if (isLit) {
          canvas.drawRect(Rect.fromLTWH(wx, wy, 2, winH),
              Paint()..color = Colors.white.withValues(alpha: 0.3));
        }
      }
    }

    // Rooftop details
    switch (style) {
      case 0: // Flat parapet
        canvas.drawRect(Rect.fromLTWH(bx - 2, by - 5, bw + 4, 6),
            Paint()..color = color.withValues(alpha: 0.8));
        // AC unit
        canvas.drawRect(Rect.fromLTWH(bx + bw * 0.6, by - 10, 14, 8),
            Paint()..color = const Color(0xFF4A5568));
        break;
      case 1: // Water tower
        final tx = bx + bw * 0.35;
        canvas.drawOval(Rect.fromLTWH(tx - 8, by - 16, 16, 12),
            Paint()..color = const Color(0xFF5C3317));
        final lp = Paint()
          ..color = const Color(0xFF3C2816)
          ..strokeWidth = 2;
        canvas.drawLine(Offset(tx - 4, by - 7), Offset(tx - 7, by), lp);
        canvas.drawLine(Offset(tx + 4, by - 7), Offset(tx + 7, by), lp);
        break;
      case 2: // Solar panels
        final sp = Paint()..color = const Color(0xFF1A3858);
        for (int s = 0; s < 4; s++) {
          canvas.drawRect(Rect.fromLTWH(bx + 4 + s * 12.0, by - 10, 10, 7), sp);
        }
        break;
      case 3: // Antenna
        canvas.drawLine(
          Offset(bx + bw * 0.5, by),
          Offset(bx + bw * 0.5, by - 18),
          Paint()..color = const Color(0xFF888888)..strokeWidth = 2,
        );
        // Blinking light on antenna
        final blinkOn = (_t * 2).toInt() % 2 == 0;
        canvas.drawCircle(Offset(bx + bw * 0.5, by - 20), 3,
            Paint()..color = blinkOn
                ? const Color(0xFFFF2222)
                : const Color(0xFF440000));
        break;
      case 4: // Billboard
        canvas.drawRect(Rect.fromLTWH(bx + bw * 0.1, by - 14, bw * 0.8, 12),
            Paint()..color = const Color(0xFF1565C0));
        canvas.drawRect(Rect.fromLTWH(bx + bw * 0.1, by - 14, bw * 0.8, 12),
            Paint()
              ..color = Colors.white.withValues(alpha: 0.15)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1);
        break;
    }

    // Ground floor – shopfront / darker base
    canvas.drawRect(Rect.fromLTWH(bx, by + bh - 18, bw, 18),
        Paint()..color = Colors.black.withValues(alpha: 0.3));

    // Door
    canvas.drawRect(
        Rect.fromLTWH(bx + bw * 0.38, by + bh - 16, bw * 0.24, 14),
        Paint()..color = const Color(0xFF1A1A2A));
    canvas.drawRect(
        Rect.fromLTWH(bx + bw * 0.38, by + bh - 16, bw * 0.24, 14),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.1)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1);

    // Outline
    canvas.drawRect(rect,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.08)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1);
  }

  void _drawSideViewCar(Canvas canvas, _SideCar car) {
    final x  = car.x;
    final y  = car.laneY;
    final w  = car.kind == 2 ? 52.0 : (car.kind == 3 ? 40.0 : 34.0);
    final h  = car.kind == 2 ? 18.0 : 14.0;
    final col = car.color;
    final dir = car.dir;

    canvas.save();
    if (dir < 0) {
      canvas.translate(x, y);
      canvas.scale(-1, 1);
      canvas.translate(-x, -y);
    }

    // Shadow
    canvas.drawOval(
        Rect.fromLTWH(x - w * 0.45, y + h * 0.5, w * 0.9, 5),
        Paint()..color = Colors.black.withValues(alpha: 0.35));

    // Car body
    final bodyRect = Rect.fromLTWH(x - w / 2, y - h / 2, w, h);
    canvas.drawRRect(
        RRect.fromRectAndCorners(
          bodyRect,
          topLeft: const Radius.circular(4),
          topRight: const Radius.circular(8),
          bottomLeft: const Radius.circular(3),
          bottomRight: const Radius.circular(3),
        ),
        Paint()..color = col);

    // Cabin (roof)
    if (car.kind != 3) {
      final cabinPath = Path()
        ..moveTo(x - w * 0.15, y - h / 2)
        ..lineTo(x - w * 0.35, y - h / 2 - h * 0.65)
        ..lineTo(x + w * 0.2, y - h / 2 - h * 0.65)
        ..lineTo(x + w * 0.38, y - h / 2)
        ..close();
      canvas.drawPath(cabinPath,
          Paint()..color = col.withValues(alpha: 0.85));

      // Windshield
      final wsPath = Path()
        ..moveTo(x - w * 0.10, y - h / 2 - 1)
        ..lineTo(x - w * 0.28, y - h / 2 - h * 0.6)
        ..lineTo(x + w * 0.15, y - h / 2 - h * 0.6)
        ..lineTo(x + w * 0.32, y - h / 2 - 1)
        ..close();
      canvas.drawPath(wsPath,
          Paint()..color = const Color(0x88B3E5FC));
    }

    // Wheels
    final wp = Paint()..color = const Color(0xFF111111);
    for (final wx2 in [x - w * 0.28, x + w * 0.28]) {
      canvas.drawCircle(Offset(wx2, y + h / 2 - 1), 5, wp);
      canvas.drawCircle(Offset(wx2, y + h / 2 - 1), 3,
          Paint()..color = const Color(0xFF444444));
    }

    // Headlight / tail-light
    canvas.drawRect(Rect.fromLTWH(x + w / 2 - 5, y - 2, 5, 4),
        Paint()
          ..color = const Color(0xFFFFDD88)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    canvas.drawRect(Rect.fromLTWH(x - w / 2, y - 2, 4, 4),
        Paint()..color = const Color(0xFFCC2222));

    // Motion exhaust
    if (car.speed > 50) {
      canvas.drawCircle(Offset(x - w / 2 - 6, y + h / 2 - 4), 4,
          Paint()
            ..color = Colors.grey.withValues(alpha: 0.3)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
    }

    canvas.restore();
  }

  void _drawSideViewPed(Canvas canvas, _SidePed ped) {
    final x   = ped.x;
    final y   = ped.laneY;
    final t   = ped.time;
    final dir = ped.dir.toDouble();

    // Walk cycle
    final legSwing = math.sin(t * 5.0) * 4.0;

    canvas.save();
    if (dir < 0) {
      canvas.translate(x, y);
      canvas.scale(-1, 1);
      canvas.translate(-x, -y);
    }

    // Shadow
    canvas.drawOval(Rect.fromLTWH(x - 5, y - 1, 10, 3),
        Paint()..color = Colors.black.withValues(alpha: 0.3));

    // Legs
    final legPaint = Paint()
      ..color = const Color(0xFF1A237E)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(x, y - 7),
        Offset(x - 3 + legSwing, y), legPaint);
    canvas.drawLine(Offset(x, y - 7),
        Offset(x + 3 - legSwing, y), legPaint);

    // Body
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(x - 4, y - 18, 8, 12),
            const Radius.circular(3)),
        Paint()..color = const Color(0xFF1565C0));

    // Arms swing
    final armSwing = math.sin(t * 5.0 + math.pi) * 5.0;
    final armPaint = Paint()
      ..color = const Color(0xFF1A237E)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(x - 4, y - 15),
        Offset(x - 7, y - 11 + armSwing), armPaint);
    canvas.drawLine(Offset(x + 4, y - 15),
        Offset(x + 7, y - 11 - armSwing), armPaint);

    // Head
    final skinColor = _skinTones[ped.seed % _skinTones.length];
    canvas.drawCircle(Offset(x, y - 22), 5,
        Paint()..color = skinColor);

    // Hair
    canvas.drawOval(Rect.fromLTWH(x - 5, y - 28, 10, 7),
        Paint()..color = _hairColors[ped.seed % _hairColors.length]);

    canvas.restore();
  }

  static const _skinTones = [
    Color(0xFFFFDBAC), Color(0xFFF1C27D), Color(0xFFE0AC69),
    Color(0xFFC68642), Color(0xFF8D5524), Color(0xFF4A2912),
  ];

  static const _hairColors = [
    Color(0xFF1C0A00), Color(0xFF5C3317), Color(0xFFFFD700),
    Color(0xFFA0522D), Color(0xFF2C1810),
  ];

  void _drawStreetLamps(Canvas canvas, double w, double h, double groundY) {
    final rng = math.Random(99);
    for (double x = 60; x < w; x += 80 + rng.nextDouble() * 40) {
      // Pole
      canvas.drawRect(Rect.fromLTWH(x - 1.5, groundY - 40, 3, 40),
          Paint()..color = const Color(0xFF555566));
      // Arm
      canvas.drawLine(Offset(x, groundY - 40), Offset(x + 12, groundY - 44),
          Paint()..color = const Color(0xFF666677)..strokeWidth = 2);
      // Lamp glow
      canvas.drawCircle(Offset(x + 12, groundY - 44), 6,
          Paint()
            ..color = const Color(0xFFFFAA44).withValues(alpha: 0.8)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
      canvas.drawCircle(Offset(x + 12, groundY - 44), 3,
          Paint()..color = const Color(0xFFFFEE99));
      // Light cone on road
      final coneRect = Rect.fromLTWH(x + 2, groundY - 38, 20, 40);
      canvas.drawRect(coneRect,
          Paint()
            ..shader = ui.Gradient.linear(
              Offset(x + 12, groundY - 38),
              Offset(x + 12, groundY + 2),
              [
                const Color(0x22FFCC55),
                Colors.transparent,
              ],
            ));
    }
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  SIDE-VIEW CITY DATA CLASSES
// ════════════════════════════════════════════════════════════════════════════
class _SideBuilding {
  final double x, w, h, startY;
  final int floors, style, seed;
  final Color color;
  final bool isLeft;
  _SideBuilding({
    required this.x, required this.w, required this.h,
    required this.floors, required this.style, required this.color,
    required this.isLeft, required this.seed, required this.startY,
  });
}

class _SideCar {
  double x, time = 0;
  final double speed, laneY;
  final Color color;
  final int kind, seed;
  final int dir;
  _SideCar({
    required this.x, required this.speed, required this.color,
    required this.kind, required this.seed, required this.laneY,
  }) : dir = seed % 2 == 0 ? 1 : -1;
}

class _SidePed {
  double x, time = 0;
  final double speed, laneY;
  final int seed, dir;
  _SidePed({
    required this.x, required this.speed, required this.laneY,
    required this.seed, required this.dir,
  });
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

    // Wing (left)
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

    // Wing highlight
    canvas.drawPath(Path()
      ..moveTo(0, 0)
      ..lineTo(-46, 8)
      ..lineTo(-4, 6)
      ..close(),
        Paint()..color = const Color(0xFF2A4F7F));
    canvas.drawPath(Path()
      ..moveTo(0, 0)
      ..lineTo(46, 8)
      ..lineTo(4, 6)
      ..close(),
        Paint()..color = const Color(0xFF2A4F7F));

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
    // Cockpit glare
    canvas.drawOval(
        Rect.fromLTWH(-3, -13, 3, 5),
        Paint()..color = Colors.white.withValues(alpha: 0.4));

    // Tail fins
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

    // Engine glow (rear) — pulsing
    final glowR = 5 + math.sin(_t * 8) * 1.5;
    canvas.drawCircle(const Offset(0, 16), glowR,
        Paint()
          ..color = const Color(0xFF69F0AE).withValues(alpha: 0.8)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    canvas.drawCircle(const Offset(0, 16), glowR * 0.4,
        Paint()..color = Colors.white.withValues(alpha: 0.9));

    // Chemical spray indicator (shows selected arrow type)
    final arrowColor = _arrowIndicatorColor(game.selectedArrow);
    canvas.drawCircle(const Offset(0, -28), 5,
        Paint()
          ..color = arrowColor.withValues(alpha: 0.8)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));

    canvas.restore();
  }

  Color _arrowIndicatorColor(ArrowType t) {
    switch (t) {
      case ArrowType.h2:    return const Color(0xFF29B6F6);
      case ArrowType.nh3:   return const Color(0xFF69F0AE);
      case ArrowType.caco3: return const Color(0xFFFFE082);
    }
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
    final spec  = _labels[type]!;
    final label = spec.$1;
    final inner = spec.$2;
    final rim   = spec.$3;

    final pulse  = 0.72 + math.sin(_t * 3.5) * 0.12;
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

    // Bubble sheen (top glare)
    canvas.drawOval(
        Rect.fromLTWH(
            bubbleX - radius * 0.4,
            bubbleY - radius * 0.6,
            radius * 0.55,
            radius * 0.3),
        Paint()..color = Colors.white.withValues(alpha: 0.25));

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
//  ARROW (fired projectile)
// ════════════════════════════════════════════════════════════════════════════
class Arrow extends Component {
  final AirPollutionGame             game;
  double                             x, y;
  final ArrowType                    type;
  final PollutantBubble              target;
  final void Function(bool ok,
      double hitX, double hitY)      onHit;
  bool                               done   = false;
  bool                               _fired = false;

  static const double _speed = 420.0;

  Arrow({
    required this.game,
    required this.x,
    required this.y,
    required this.type,
    required this.target,
    required this.onHit,
  });

  @override
  void update(double dt) {
    if (done) return;

    if (target.isNeutralized && !_fired) {
      done = true;
      removeFromParent();
      return;
    }

    final tx   = target.bubbleX;
    final ty   = target.bubbleY;
    final dx   = tx - x;
    final dy   = ty - y;
    final dist = math.sqrt(dx * dx + dy * dy);

    if (dist < 26) {
      if (!_fired) {
        _fired = true;
        final correct = game._isCorrectArrow(target.type, type);
        onHit(correct, tx, ty);
      }
      done = true;
      removeFromParent();
      return;
    }

    x += (dx / dist) * _speed * dt;
    y += (dy / dist) * _speed * dt;

    if (x < -40 || x > game.size.x + 40 ||
        y < -40 || y > game.size.y + 40) {
      done = true;
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    if (done) return;
    final color = _arrowColor();

    final tx  = target.bubbleX;
    final ty  = target.bubbleY;
    final dx  = tx - x;
    final dy  = ty - y;
    final len = math.sqrt(dx * dx + dy * dy);
    final ndx = len > 0 ? dx / len : 0.0;
    final ndy = len > 0 ? dy / len : -1.0;

    // Trail
    canvas.drawLine(
      Offset(x, y),
      Offset(x - ndx * 22, y - ndy * 22),
      Paint()
        ..color      = color.withValues(alpha: 0.4)
        ..strokeWidth = 6
        ..strokeCap  = StrokeCap.round,
    );

    // Shaft
    canvas.drawLine(
      Offset(x, y),
      Offset(x - ndx * 22, y - ndy * 22),
      Paint()
        ..color      = color
        ..strokeWidth = 3.2
        ..strokeCap  = StrokeCap.round,
    );

    // Tip glow
    canvas.drawCircle(
      Offset(x, y), 7,
      Paint()
        ..color      = color.withValues(alpha: 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawCircle(Offset(x, y), 4, Paint()..color = Colors.white);

    // Chemical label on arrow
    final label = _arrowLabel();
    final tp = TextPainter(
      text: TextSpan(text: label,
          style: TextStyle(
              color: color,
              fontSize: 8,
              fontWeight: FontWeight.w900)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(x - ndx * 11 - tp.width / 2,
        y - ndy * 11 - tp.height / 2));
  }

  Color _arrowColor() {
    switch (type) {
      case ArrowType.h2:    return const Color(0xFF29B6F6);
      case ArrowType.nh3:   return const Color(0xFF69F0AE);
      case ArrowType.caco3: return const Color(0xFFFFE082);
    }
  }

  String _arrowLabel() {
    switch (type) {
      case ArrowType.h2:    return 'H₂';
      case ArrowType.nh3:   return 'NH₃';
      case ArrowType.caco3: return 'CaCO₃';
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
        final warn      = game.timeLeft < 20;
        final remaining = _remainingBubbles(game);
        final wrongLeft = AirPollutionGame.kMaxWrongHits - game.wrongArrows;

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
              const SizedBox(width: 5),
              _Tile(Icons.bubble_chart_rounded, '$remaining', 'BUBBLES',
                  const Color(0xFFFF6D00)),
              const SizedBox(width: 5),
              _Tile(Icons.eco_rounded, '${game.ecoPoints}', 'ECO-PTS',
                  Colors.limeAccent),
              const SizedBox(width: 5),
              _Tile(Icons.air_rounded, '${(game.airPurity * 100).toInt()}%',
                  'PURITY', const Color(0xFF69F0AE)),
              const SizedBox(width: 5),
              // Wrong-hits counter with warning
              _Tile(Icons.warning_rounded, '$wrongLeft', 'MISS-LEFT',
                  wrongLeft <= 3 ? Colors.red : Colors.orange),
            ]),
            const SizedBox(height: 5),

            // Air purity bar
            Row(children: [
              const Text('💨', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Expanded(child: Stack(children: [
                ClipRRect(
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
                ),
                // Wrong-purity drain indicator (red zone)
                if (game._wrongPurityDrain > 0)
                  Positioned.fill(child: ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerRight,
                      widthFactor: game._wrongPurityDrain.clamp(0, 1),
                      child: Container(
                        color: Colors.red.withValues(alpha: 0.4),
                      ),
                    ),
                  )),
              ])),
              const SizedBox(width: 6),
              Text('${(game.airPurity * 100).toInt()}%',
                  style: const TextStyle(color: Colors.white70, fontSize: 10)),
            ]),

            // Correct by-products row
            const SizedBox(height: 4),
            Row(children: [
              _ByProductChip('⚗️', 'CH₃OH', game.methanol, true),
              const SizedBox(width: 4),
              _ByProductChip('🪨', 'CaSO₄', game.gypsum, true),
              const SizedBox(width: 4),
              _ByProductChip('🌿', 'CO(NH₂)₂', game.urea, true),
              const SizedBox(width: 4),
              _ByProductChip('🧪', 'NO₃⁻', game.nitrates, true),
            ]),

            // Harmful by-products row (shown if any wrong hits)
            if (game.wrongArrows > 0) ...[
              const SizedBox(height: 3),
              Row(children: [
                _ByProductChip('☠️', 'H₂SO₄', game.sulfuricAcid, false),
                const SizedBox(width: 4),
                _ByProductChip('💥', 'N₂O₃', game.nitrousOxide, false),
                const SizedBox(width: 4),
                _ByProductChip('⚠️', 'C₃O₂', game.carbonSuboxide, false),
                const SizedBox(width: 4),
                _ByProductChip('🔴', 'NH₄NO₃', game.ammoniumNitrate, false),
              ]),
            ],
          ]),
        ));
      },
    );
  }

  int _remainingBubbles(AirPollutionGame g) =>
      g.bubbles.where((b) => !b.isNeutralized).length;
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String val, label;
  final Color color;
  const _Tile(this.icon, this.val, this.label, this.color);
  @override
  Widget build(BuildContext context) => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
    decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12)),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: color, size: 13),
      Text(val, style: TextStyle(color: color,
          fontWeight: FontWeight.bold, fontSize: 12)),
      Text(label, style: const TextStyle(color: Colors.white54,
          fontSize: 7, letterSpacing: 0.8)),
    ]),
  ));
}

class _ByProductChip extends StatelessWidget {
  final String emoji, label;
  final int count;
  final bool isGood;
  const _ByProductChip(this.emoji, this.label, this.count, this.isGood);
  @override
  Widget build(BuildContext context) => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(vertical: 3),
    decoration: BoxDecoration(
        color: (isGood ? Colors.green : Colors.red)
            .withValues(alpha: count > 0 ? 0.15 : 0.04),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
            color: count > 0
                ? (isGood ? Colors.green : Colors.red).withValues(alpha: 0.5)
                : Colors.white12)),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text(emoji, style: const TextStyle(fontSize: 8)),
      Text(label, style: TextStyle(
          color: isGood ? Colors.greenAccent : Colors.redAccent,
          fontSize: 6.5, fontWeight: FontWeight.bold)),
      Text('$count', style: TextStyle(
          color: count > 0
              ? (isGood ? Colors.limeAccent : Colors.redAccent)
              : Colors.white38,
          fontWeight: FontWeight.bold, fontSize: 10)),
    ]),
  ));
}

// ════════════════════════════════════════════════════════════════════════════
//  ARROW SELECTOR  — with keyboard shortcut labels (1/2/3)
// ════════════════════════════════════════════════════════════════════════════
class ArrowSelector extends StatelessWidget {
  final AirPollutionGame game;
  const ArrowSelector(this.game, {super.key});

  static const _arrows = [
    (ArrowType.h2,    '💨', 'H₂',    Color(0xFF29B6F6),
        'CO / CO₂ / CH₄',
        'CO + 2H₂ → CH₃OH', '1'),
    (ArrowType.nh3,   '🌿', 'NH₃',   Color(0xFF69F0AE),
        'NO / NO₂ / NH₃',
        '4NH₃+4NO → 4N₂+6H₂O', '2'),
    (ArrowType.caco3, '🪨', 'CaCO₃', Color(0xFFFFE082),
        'SO₂',
        'SO₂+CaCO₃ → CaSO₄', '3'),
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: game,
      builder: (_, __) {
        return Align(
          alignment: Alignment.bottomRight,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 100, right: 6),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.82),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('REAGENT',
                        style: TextStyle(color: Colors.white38,
                            fontSize: 7, letterSpacing: 1.4,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    ..._arrows.map((a) {
                      final (type, emoji, chem, color, target, rxn, key) = a;
                      final sel = game.selectedArrow == type;
                      return GestureDetector(
                        onTap: () => game.selectArrow(type),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 140),
                          margin: const EdgeInsets.symmetric(vertical: 3),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            color: sel
                                ? color.withValues(alpha: 0.22)
                                : Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: sel ? color : Colors.white12,
                                width: sel ? 2.0 : 1.0),
                            boxShadow: sel
                                ? [BoxShadow(
                                    color: color.withValues(alpha: 0.40),
                                    blurRadius: 8)]
                                : [],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(emoji, style: const TextStyle(fontSize: 16)),
                                  const SizedBox(width: 3),
                                  // Keyboard shortcut badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: sel
                                          ? color.withValues(alpha: 0.3)
                                          : Colors.white.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                          color: sel
                                              ? color.withValues(alpha: 0.7)
                                              : Colors.white24),
                                    ),
                                    child: Text(key,
                                        style: TextStyle(
                                            color: sel ? color : Colors.white54,
                                            fontSize: 8,
                                            fontWeight: FontWeight.w900)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(chem,
                                  style: TextStyle(
                                    color: sel ? color : Colors.white70,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 9,
                                  )),
                              const SizedBox(height: 1),
                              Text(target,
                                  style: TextStyle(
                                    color: sel
                                        ? color.withValues(alpha: 0.70)
                                        : Colors.white30,
                                    fontSize: 6.5,
                                  )),
                              // Show reaction equation on selected
                              if (sel) ...[
                                const SizedBox(height: 2),
                                Text(rxn,
                                    style: TextStyle(
                                      color: color.withValues(alpha: 0.85),
                                      fontSize: 5.5,
                                      fontStyle: FontStyle.italic,
                                    )),
                              ],
                            ],
                          ),
                        ),
                      );
                    }),
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

    // Number keys 1/2/3 to select arrow type
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
            padding: const EdgeInsets.only(bottom: 16, left: 12),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Keyboard hint
              Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('W A S D / ← ↑ → ↓  ·  SPACE=fire  ·  1 2 3=reagent',
                    style: TextStyle(color: Colors.white30, fontSize: 7,
                        letterSpacing: 0.5)),
              ),
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
            padding: const EdgeInsets.only(bottom: 20, right: 14),
            child: GestureDetector(
              onTap: widget.game.fireArrow,
              child: AnimatedBuilder(
                animation: widget.game,
                builder: (_, __) {
                  final color = _selectedArrowColor(widget.game.selectedArrow);
                  return Container(
                    width: 68, height: 68,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                      border: Border.all(color: color, width: 2.5),
                      boxShadow: [BoxShadow(
                          color: color.withValues(alpha: 0.45),
                          blurRadius: 14)],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('🎯', style: TextStyle(fontSize: 22)),
                        Text('FIRE', style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w900,
                            fontSize: 9, letterSpacing: 1)),
                      ],
                    ),
                  );
                },
              ),
            ),
          )),
        ),
      ]),
    );
  }

  Color _selectedArrowColor(ArrowType t) {
    switch (t) {
      case ArrowType.h2:    return const Color(0xFF29B6F6);
      case ArrowType.nh3:   return const Color(0xFF69F0AE);
      case ArrowType.caco3: return const Color(0xFFFFE082);
    }
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
        Text(
            'Select reagent (1/2/3 or tap), fly close to\n'
            'gas bubbles then tap 🎯 FIRE!\n'
            '⚠️ Max 10 wrong hits before phase ends!',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 12)),
      ]),
    )));
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  REACTION FLASH  — Green bubble burst (correct) / Explosion (wrong)
// ════════════════════════════════════════════════════════════════════════════
class ReactionFlash extends StatelessWidget {
  final AirPollutionGame game;
  const ReactionFlash(this.game, {super.key});

  @override
  Widget build(BuildContext context) {
    final ok      = game.reactionCorrect;
    final product = game.reactionProduct;

    return IgnorePointer(child: Stack(children: [
      // Screen edge flash
      Container(decoration: BoxDecoration(
        border: Border.all(
            color: ok ? const Color(0xFF29B6F6) : Colors.red,
            width: ok ? 8 : 14),
        gradient: RadialGradient(colors: [
          Colors.transparent,
          (ok ? const Color(0xFF29B6F6) : Colors.red)
              .withValues(alpha: ok ? 0.10 : 0.22),
        ], radius: 1.5),
      )),
      // Product announcement card
      Center(child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 22, vertical: 12),
        decoration: BoxDecoration(
            color: (ok
                    ? const Color(0xFF0D2A3A)
                    : const Color(0xFF3A0D0D))
                .withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [BoxShadow(
                color: Colors.black54,
                blurRadius: 14, spreadRadius: 2)]),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(ok ? '✅  NEUTRALIZED!' : '❌  WRONG ARROW!',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18, letterSpacing: 0.8)),
          const SizedBox(height: 6),
          // Product formed
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: (ok ? Colors.green : Colors.red)
                  .withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: (ok ? Colors.greenAccent : Colors.redAccent)
                      .withValues(alpha: 0.5)),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(
                ok ? '⚗️ By-product formed:' : '☠️ Harmful compound created:',
                style: TextStyle(
                    color: ok ? Colors.greenAccent : Colors.redAccent,
                    fontSize: 10, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(product,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: ok
                        ? const Color(0xFF69F0AE)
                        : const Color(0xFFFF5252),
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  )),
            ]),
          ),
          const SizedBox(height: 6),
          Text(
            ok
                ? '+10 Eco-Points  •  By-product stored'
                : '−5 Eco-Points  •  Air Purity ↓  •  ${AirPollutionGame.kMaxWrongHits - game.wrongArrows} misses left',
            style: TextStyle(
                color: ok
                    ? const Color(0xFF29B6F6)
                    : const Color(0xFFEF5350),
                fontSize: 11,
                fontWeight: FontWeight.w600),
          ),
        ]),
      )),
    ]));
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  AIR RESULTS OVERLAY  — shown when phase ends; results persist on screen
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
    final autoEnd = result.wrongHits >= AirPollutionGame.kMaxWrongHits;

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
                      : autoEnd
                          ? [const Color(0xFF3A0000),
                             const Color(0xFF7B0000)]
                          : [const Color(0xFF1A0A00),
                             const Color(0xFF3D1800)]),
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [BoxShadow(
                  color: Colors.black54, blurRadius: 16)],
            ),
            child: Column(children: [
              Text(perfect ? '✨' : autoEnd ? '⚠️' : '🌫️',
                  style: const TextStyle(fontSize: 48)),
              const SizedBox(height: 8),
              Text(
                perfect
                    ? 'Air Fully Purified!'
                    : autoEnd
                        ? 'Max Wrong Hits Reached!'
                        : 'Phase Complete',
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
            _Big('🎯', '$pct%',
                'Neutralized', const Color(0xFF29B6F6)),
            _Big('✅', '${result.pollutantsNeutralized}',
                'Correct',     Colors.limeAccent),
            _Big('❌', '${result.wrongArrows}',
                'Wrong',       Colors.redAccent),
            _Big('⭐', '${result.ecoPoints}',
                'Eco-Pts',     Colors.amber),
          ]),

          const SizedBox(height: 12),

          // Correct by-products panel
          _SectionHeader('✅ Chemical By-Products Collected',
              const Color(0xFF29B6F6)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1B2A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
            ),
            child: Column(children: [
              _BPRow('⚗️', 'Methanol (CH₃OH)',  result.methanol,
                  'CO/CO₂/CH₄ + H₂ → CH₃OH + H₂O',
                  'Fuel / building material', true),
              _BPRow('🪨', 'Gypsum (CaSO₄·2H₂O)', result.gypsum,
                  'SO₂ + CaCO₃ + H₂O → CaSO₄·2H₂O + CO₂',
                  'Construction / plasterboard', true),
              _BPRow('🌿', 'Urea (CO(NH₂)₂)',  result.urea,
                  '2NH₃ + CO₂ → CO(NH₂)₂ + H₂O',
                  'Fertilizer for farming phase', true),
              _BPRow('🧪', 'Nitrates (NO₃⁻)',  result.nitrates,
                  '4NH₃ + 4NO + O₂ → 4N₂ + 6H₂O + NO₃⁻',
                  'Crop nutrients / fertilizer', true),
            ]),
          ),

          // Harmful by-products panel (if any wrong hits)
          if (result.wrongArrows > 0) ...[
            const SizedBox(height: 12),
            _SectionHeader('☠️ Harmful By-Products Created (Wrong Shots)',
                Colors.redAccent),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF2A0A0A),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: Column(children: [
                _BPRow('☠️', 'Sulfuric Acid (H₂SO₄)', result.sulfuricAcid,
                    'SO₂ + H₂O → H₂SO₄ (acid rain precursor)',
                    'Corrodes lungs / infrastructure', false),
                _BPRow('💥', 'Dinitrogen Trioxide (N₂O₃)', result.nitrousOxide,
                    '2NO + O₂ → N₂O₃ (smog component)',
                    'Toxic oxidant, respiratory harm', false),
                _BPRow('⚠️', 'Carbon Suboxide (C₃O₂)', result.carbonSuboxide,
                    '3CO → C₃O₂ (toxic lachrymator)',
                    'Eye & lung irritant', false),
                _BPRow('🔴', 'Ammonium Nitrate (NH₄NO₃)', result.ammoniumNitrate,
                    'NH₃ + HNO₃ → NH₄NO₃',
                    'Explosive hazard / water pollutant', false),
                const SizedBox(height: 8),
                // Air purity impact note
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '⚡ ${result.wrongArrows} wrong hits drained air purity by '
                    '${(result.wrongArrows * 5).clamp(0, 50)}% and cost '
                    '${result.wrongArrows * 5} eco-points',
                    style: const TextStyle(
                        color: Colors.orangeAccent,
                        fontSize: 10,
                        fontStyle: FontStyle.italic),
                    textAlign: TextAlign.center,
                  ),
                ),
              ]),
            ),
          ],

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

class _SectionHeader extends StatelessWidget {
  final String text;
  final Color color;
  const _SectionHeader(this.text, this.color);
  @override
  Widget build(BuildContext context) => Row(children: [
    Expanded(child: Container(height: 1,
        color: color.withValues(alpha: 0.3))),
    const SizedBox(width: 8),
    Text(text, style: TextStyle(color: color,
        fontSize: 11, fontWeight: FontWeight.bold,
        letterSpacing: 0.8)),
    const SizedBox(width: 8),
    Expanded(child: Container(height: 1,
        color: color.withValues(alpha: 0.3))),
  ]);
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
  final String emoji, label, equation, desc;
  final int count;
  final bool isGood;
  const _BPRow(this.emoji, this.label, this.count,
      this.equation, this.desc, this.isGood);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(emoji, style: const TextStyle(fontSize: 16)),
      const SizedBox(width: 8),
      Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(
                color: Colors.white, fontSize: 12,
                fontWeight: FontWeight.w600)),
        Text(equation,
            style: TextStyle(
                color: isGood
                    ? Colors.greenAccent.withValues(alpha: 0.8)
                    : Colors.redAccent.withValues(alpha: 0.8),
                fontSize: 9,
                fontStyle: FontStyle.italic)),
        Text(desc,
            style: const TextStyle(
                color: Colors.white38, fontSize: 9)),
      ])),
      Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: (isGood ? Colors.green : Colors.red)
              .withValues(alpha: count > 0 ? 0.15 : 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: (isGood ? Colors.green : Colors.red)
                  .withValues(alpha: count > 0 ? 0.5 : 0.15)),
        ),
        child: Text('$count',
            style: TextStyle(
                color: count > 0
                    ? (isGood ? Colors.greenAccent : Colors.redAccent)
                    : Colors.white38,
                fontWeight: FontWeight.bold,
                fontSize: 14)),
      ),
    ]),
  );
}