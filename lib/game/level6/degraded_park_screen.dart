import 'dart:async';
import 'dart:math' as math;
import 'package:ecoquest/game/level6/habitat_cleanup_game_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  DEGRADED PARK SCREEN  —  Level 6 Introduction
//  Pure Flutter. Zero Flame. Zero image assets.
//  Receives carry-over from Level 5 and forwards to HabitatCleanupGameScreen.
// ══════════════════════════════════════════════════════════════════════════════

/// Carry-over data from Level 5 (Land Degradation & Soil Pollution).
class Level5CarryOver {
  final int ecoPoints;
  final int landEcoPoints;
  final int soilEcoPoints;
  final int patchesRestored;
  final int zonesRemediated;
  final double soilHealthFinal;
  final bool soilGuardianBadge;
  final bool terrainStabilised;
  // Resources from earlier levels carried forward
  final int biochar;
  final int compost;
  final int bacteriaCultures;
  final int gypsum;     // from Level 4 air phase
  final int naturalDyes; // from Level 1 deforestation phase

  const Level5CarryOver({
    this.ecoPoints          = 0,
    this.landEcoPoints      = 0,
    this.soilEcoPoints      = 0,
    this.patchesRestored    = 0,
    this.zonesRemediated    = 0,
    this.soilHealthFinal    = 0,
    this.soilGuardianBadge  = false,
    this.terrainStabilised  = false,
    this.biochar            = 0,
    this.compost            = 0,
    this.bacteriaCultures   = 0,
    this.gypsum             = 0,
    this.naturalDyes        = 0,
  });
}

class DegradedParkScreen extends StatefulWidget {
  final Level5CarryOver carryOver;

  const DegradedParkScreen({
    super.key,
    this.carryOver = const Level5CarryOver(),
  });

  @override
  State<DegradedParkScreen> createState() => _DegradedParkScreenState();
}

class _DegradedParkScreenState extends State<DegradedParkScreen>
    with TickerProviderStateMixin {

  // ── Animation controllers ──────────────────────────────────────────────────
  late final AnimationController _bgCtrl;
  late final AnimationController _entryCtrl;
  late final AnimationController _staggerCtrl;
  late final AnimationController _pulseCtrl;
  late final AnimationController _shimmerCtrl;
  late final AnimationController _driftCtrl;
  late final AnimationController _parkCtrl;

  late final Animation<double> _fadeAnim;
  late final Animation<Offset>  _titleSlide;
  late final Animation<double>  _titleScale;

  // ── Palette ────────────────────────────────────────────────────────────────
  static const Color _bgDeep       = Color(0xFF040A06);
  static const Color _panel        = Color(0xFF081008);
  static const Color _panelAlt     = Color(0xFF0A1208);
  static const Color _murkyGreen   = Color(0xFF558B2F);
  static const Color _pollutedBrown = Color(0xFF795548);
  static const Color _dangerRed    = Color(0xFFEF5350);
  static const Color _waterTeal    = Color(0xFF00897B);
  static const Color _wildlifeGold = Color(0xFFFFB300);
  static const Color _posterBlue   = Color(0xFF1E88E5);
  static const Color _healthGreen  = Color(0xFF69F0AE);

  @override
  void initState() {
    super.initState();

    _bgCtrl = AnimationController(vsync: this,
        duration: const Duration(seconds: 12))..repeat(reverse: true);
    _entryCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 900))..forward();
    _staggerCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 1400))..forward();
    _pulseCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 1600))..repeat(reverse: true);
    _shimmerCtrl = AnimationController(vsync: this,
        duration: const Duration(seconds: 2))..repeat(reverse: true);
    _driftCtrl = AnimationController(vsync: this,
        duration: const Duration(seconds: 10))..repeat();
    _parkCtrl = AnimationController(vsync: this,
        duration: const Duration(seconds: 13))..repeat(reverse: true);

    _fadeAnim = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeIn);
    _titleSlide = Tween<Offset>(
            begin: const Offset(0, -0.15), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entryCtrl,
            curve: Curves.easeOutCubic));
    _titleScale = Tween<double>(begin: 0.88, end: 1.0)
        .animate(CurvedAnimation(parent: _entryCtrl,
            curve: Curves.elasticOut));
  }

  @override
  void dispose() {
    _bgCtrl.dispose(); _entryCtrl.dispose(); _staggerCtrl.dispose();
    _pulseCtrl.dispose(); _shimmerCtrl.dispose();
    _driftCtrl.dispose(); _parkCtrl.dispose();
    super.dispose();
  }

  void _openControls(BuildContext context) {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(PageRouteBuilder(
      pageBuilder: (_, anim, __) =>
          _ControlsScreen(carryOver: widget.carryOver),
      transitionsBuilder: (_, anim, __, child) => SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
            .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: child,
      ),
      transitionDuration: const Duration(milliseconds: 420),
    ));
  }

  void _startLevel(BuildContext context) {
    HapticFeedback.heavyImpact();
    Navigator.push(context, PageRouteBuilder(
      pageBuilder: (_, anim, __) =>
          HabitatCleanupGameScreen(carryOver: widget.carryOver),
      transitionsBuilder: (_, anim, __, child) => FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: Curves.easeIn),
        child: child,
      ),
      transitionDuration: const Duration(milliseconds: 600),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final size   = MediaQuery.of(context).size;
    final mobile = size.width < 640;
    final hPad   = mobile ? 16.0 : size.width * 0.12;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _bgDeep,
        body: Stack(children: [

          _AnimatedParkBackground(
              bgCtrl: _bgCtrl, parkCtrl: _parkCtrl, driftCtrl: _driftCtrl),

          _LitterParticles(ctrl: _driftCtrl, size: size),

          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                    horizontal: hPad, vertical: mobile ? 16 : 22),
                child: Column(children: [

                  SlideTransition(
                    position: _titleSlide,
                    child: ScaleTransition(
                      scale: _titleScale,
                      child: _TitleSection(shimmer: _shimmerCtrl,
                          pulse: _pulseCtrl, mobile: mobile),
                    ),
                  ),

                  SizedBox(height: mobile ? 22 : 30),
                  _ThreatBanner(pulse: _pulseCtrl, mobile: mobile),
                  SizedBox(height: mobile ? 22 : 28),
                  _MissionPhases(stagger: _staggerCtrl, mobile: mobile),
                  SizedBox(height: mobile ? 22 : 28),
                  _CarryOverPanel(stagger: _staggerCtrl, shimmer: _shimmerCtrl,
                      carryOver: widget.carryOver, mobile: mobile),
                  SizedBox(height: mobile ? 100 : 110),
                ]),
              ),
            ),
          ),

          Positioned(
            left: 0, right: 0, bottom: 0,
            child: _FloatingActionBar(
              pulse: _pulseCtrl, shimmer: _shimmerCtrl,
              mobile: mobile, hPad: hPad,
              onStart: () => _startLevel(context),
              onControls: () => _openControls(context),
            ),
          ),
        ]),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  ANIMATED DEGRADED PARK BACKGROUND
// ════════════════════════════════════════════════════════════════════════════
class _AnimatedParkBackground extends StatelessWidget {
  final AnimationController bgCtrl, parkCtrl, driftCtrl;
  const _AnimatedParkBackground(
      {required this.bgCtrl, required this.parkCtrl, required this.driftCtrl});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([bgCtrl, parkCtrl, driftCtrl]),
      builder: (_, __) => SizedBox.expand(
        child: CustomPaint(
          painter: _DegradedParkPainter(
              bgT: bgCtrl.value, parkT: parkCtrl.value, driftT: driftCtrl.value),
        ),
      ),
    );
  }
}

class _DegradedParkPainter extends CustomPainter {
  final double bgT, parkT, driftT;
  const _DegradedParkPainter(
      {required this.bgT, required this.parkT, required this.driftT});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;

    // Sky — overcast, dull
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [
              Color.lerp(const Color(0xFF060C06),
                  const Color(0xFF0A120A), bgT * 0.4)!,
              Color.lerp(const Color(0xFF0C1410),
                  const Color(0xFF0A1008), bgT * 0.5)!,
              const Color(0xFF060A04),
            ],
            stops: const [0.0, 0.5, 1.0],
          ).createShader(Rect.fromLTWH(0, 0, w, h)));

    // Murky water / wetland haze
    canvas.drawRect(Rect.fromLTWH(0, h * 0.50, w, h * 0.20),
        Paint()
          ..color = const Color(0xFF00897B)
              .withValues(alpha: 0.06 + bgT * 0.06)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20));

    // Background tree silhouettes — sparse dead trees
    _drawDeadTrees(canvas, w, h, baseY: h * 0.55, seed: 11);

    // Ground / grassland — dry brown
    canvas.drawRect(Rect.fromLTWH(0, h * 0.60, w, h * 0.40),
        Paint()..color = const Color(0xFF080C06));

    // Polluted pond in foreground
    _drawPollutedPond(canvas, w, h);

    // Scattered litter on ground
    _drawLitter(canvas, w, h, t: driftT);
  }

  void _drawDeadTrees(Canvas canvas, double w, double h,
      {required double baseY, required int seed}) {
    final rng = math.Random(seed);
    for (int i = 0; i < 10; i++) {
      final tx = w * (0.05 + i * 0.10 + rng.nextDouble() * 0.05);
      final th = h * (0.08 + rng.nextDouble() * 0.12);
      final tw = 3.0 + rng.nextDouble() * 4;
      canvas.drawRect(Rect.fromLTWH(tx - tw / 2, baseY - th, tw, th),
          Paint()..color = const Color(0xFF0A0E08));
      // Bare branches
      for (int b = 0; b < 3; b++) {
        final by = baseY - th * (0.4 + b * 0.2);
        final bl = h * (0.02 + rng.nextDouble() * 0.03);
        final angle = (rng.nextDouble() - 0.5) * math.pi * 0.7;
        canvas.drawLine(
          Offset(tx, by),
          Offset(tx + math.cos(angle) * bl, by + math.sin(angle) * bl),
          Paint()..color = const Color(0xFF0A0E08)..strokeWidth = 1.5,
        );
      }
    }
  }

  void _drawPollutedPond(Canvas canvas, double w, double h) {
    final pondPaint = Paint()
      ..color = const Color(0xFF1B4030).withValues(alpha: 0.60);
    final path = Path();
    path.addOval(Rect.fromCenter(
        center: Offset(w * 0.35, h * 0.70), width: w * 0.28, height: h * 0.07));
    canvas.drawPath(path, pondPaint);
    // Oil slick shimmer
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w * 0.35, h * 0.70),
          width: w * 0.14, height: h * 0.025),
      Paint()..color = const Color(0xFF37474F).withValues(alpha: 0.35),
    );
  }

  void _drawLitter(Canvas canvas, double w, double h, {required double t}) {
    final rng = math.Random(33);
    for (int i = 0; i < 14; i++) {
      final lx = w * rng.nextDouble();
      final ly = h * (0.62 + rng.nextDouble() * 0.20);
      final color = [
        const Color(0xFF546E7A), const Color(0xFFBCAAA4),
        const Color(0xFF4CAF50), const Color(0xFF1565C0),
      ][i % 4];
      canvas.drawRect(
        Rect.fromCenter(center: Offset(lx, ly), width: 5, height: 3),
        Paint()..color = color.withValues(alpha: 0.45),
      );
    }
  }

  @override
  bool shouldRepaint(_DegradedParkPainter old) =>
      old.bgT != bgT || old.parkT != parkT || old.driftT != driftT;
}

// ════════════════════════════════════════════════════════════════════════════
//  LITTER PARTICLES
// ════════════════════════════════════════════════════════════════════════════
class _LitterParticles extends StatelessWidget {
  final AnimationController ctrl;
  final Size size;
  const _LitterParticles({required this.ctrl, required this.size});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ctrl,
      builder: (_, __) => CustomPaint(
          size: size, painter: _LitterParticlePainter(t: ctrl.value)),
    );
  }
}

class _LitterParticlePainter extends CustomPainter {
  final double t;
  const _LitterParticlePainter({required this.t});

  static final List<_LP> _ps = List.generate(38, (i) {
    final r = math.Random(i * 37 + 5);
    return _LP(
      x: r.nextDouble(), yStart: 0.50 + r.nextDouble() * 0.50,
      speed: 0.006 + r.nextDouble() * 0.016,
      radius: 1.4 + r.nextDouble() * 3.5,
      drift: (r.nextDouble() - 0.5) * 0.008,
      phase: r.nextDouble(),
      color: [
        const Color(0xFF795548), const Color(0xFF546E7A),
        const Color(0xFF558B2F), const Color(0xFFFFB300),
        const Color(0xFF90A4AE),
      ][r.nextInt(5)],
    );
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in _ps) {
      final progress = ((t + p.phase) % 1.0);
      final y = size.height * (p.yStart - progress * p.speed * 14);
      if (y < -10) continue;
      final x = size.width *
          (p.x + math.sin(progress * math.pi * 2) * p.drift * 4);
      final alpha = (1.0 - progress * 1.3).clamp(0.0, 0.25);
      canvas.drawCircle(Offset(x, y), p.radius,
          Paint()..color = p.color.withValues(alpha: alpha));
    }
  }

  @override
  bool shouldRepaint(_LitterParticlePainter old) => old.t != t;
}

class _LP {
  final double x, yStart, speed, radius, drift, phase;
  final Color color;
  const _LP({
    required this.x, required this.yStart, required this.speed,
    required this.radius, required this.drift, required this.phase,
    required this.color,
  });
}

// ════════════════════════════════════════════════════════════════════════════
//  TITLE SECTION
// ════════════════════════════════════════════════════════════════════════════
class _TitleSection extends StatelessWidget {
  final AnimationController shimmer, pulse;
  final bool mobile;
  const _TitleSection(
      {required this.shimmer, required this.pulse, required this.mobile});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([shimmer, pulse]),
      builder: (_, __) => Column(children: [

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: _DegradedParkScreenState._wildlifeGold
                .withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _DegradedParkScreenState._wildlifeGold
                  .withValues(alpha: 0.45 + shimmer.value * 0.20),
            ),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 7, height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _DegradedParkScreenState._wildlifeGold
                    .withValues(alpha: 0.7 + pulse.value * 0.3),
                boxShadow: [BoxShadow(
                  color: _DegradedParkScreenState._wildlifeGold
                      .withValues(alpha: 0.5),
                  blurRadius: 6,
                )],
              ),
            ),
            const SizedBox(width: 8),
            Text('LEVEL  6',
                style: TextStyle(
                  color: _DegradedParkScreenState._wildlifeGold,
                  fontSize: 11, fontWeight: FontWeight.w800,
                  letterSpacing: 3.0,
                )),
          ]),
        ),

        const SizedBox(height: 14),

        ShaderMask(
          shaderCallback: (bounds) => LinearGradient(colors: [
            const Color(0xFFFFFFFF),
            Color.lerp(Colors.white,
                _DegradedParkScreenState._murkyGreen, shimmer.value * 0.30)!,
            const Color(0xFFFFFFFF),
          ], stops: const [0.0, 0.5, 1.0]).createShader(bounds),
          child: Text(
            'Habitat\nDestruction',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: mobile ? 34 : 44,
              fontWeight: FontWeight.w900,
              height: 1.15, letterSpacing: -0.5,
            ),
          ),
        ),

        const SizedBox(height: 12),

        Text(
          'The Ondiri Wetland is dying — waste, polluted water\n'
          'and injured wildlife cry out for your help.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.45),
            fontSize: mobile ? 12 : 13,
            height: 1.55, letterSpacing: 0.2,
          ),
        ),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  THREAT BANNER
// ════════════════════════════════════════════════════════════════════════════
class _ThreatBanner extends StatelessWidget {
  final AnimationController pulse;
  final bool mobile;
  const _ThreatBanner({required this.pulse, required this.mobile});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (_, __) => Container(
        padding: EdgeInsets.symmetric(
            horizontal: mobile ? 14 : 18, vertical: 13),
        decoration: BoxDecoration(
          color: _DegradedParkScreenState._dangerRed.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: _DegradedParkScreenState._dangerRed
                  .withValues(alpha: 0.20 + pulse.value * 0.12)),
          boxShadow: [BoxShadow(
              color: _DegradedParkScreenState._dangerRed
                  .withValues(alpha: 0.06),
              blurRadius: 18, spreadRadius: 1)],
        ),
        child: Row(children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: _DegradedParkScreenState._dangerRed
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: _DegradedParkScreenState._dangerRed
                      .withValues(alpha: 0.30 + pulse.value * 0.20)),
              boxShadow: [BoxShadow(
                  color: _DegradedParkScreenState._dangerRed
                      .withValues(alpha: 0.15 + pulse.value * 0.15),
                  blurRadius: 12)],
            ),
            child: const Center(child: Text('🦒', style: TextStyle(fontSize: 18))),
          ),
          const SizedBox(width: 13),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ECOSYSTEM COLLAPSE',
                  style: TextStyle(
                    color: _DegradedParkScreenState._dangerRed,
                    fontSize: 10, fontWeight: FontWeight.w900,
                    letterSpacing: 1.8,
                  )),
              const SizedBox(height: 3),
              Text(
                'Litter smothers the reserve. Ponds are toxic. '
                'Animals are injured and birds have fled. '
                'Restore Ondiri before it is lost forever.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: mobile ? 11 : 12, height: 1.4,
                ),
              ),
            ],
          )),
        ]),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  MISSION PHASES  — 4 staggered cards
// ════════════════════════════════════════════════════════════════════════════
class _MissionPhases extends StatelessWidget {
  final AnimationController stagger;
  final bool mobile;
  const _MissionPhases({required this.stagger, required this.mobile});

  static const _phases = [
    _Phase('🗑️', 'Collect the Waste',
        'Pilot your eco-drone to gather scattered plastics, cans, and litter. '
        'Sort each item into recyclable, reusable, or biodegradable bins.',
        _DegradedParkScreenState._pollutedBrown, '01'),
    _Phase('💧', 'Purify Animal Drinking Points',
        'Fly to each polluted pond and apply the correct treatment: '
        'water hyacinths, eco-bacteria pellets, or filtration units.',
        _DegradedParkScreenState._waterTeal, '02'),
    _Phase('🦓', 'Rescue Injured Wildlife',
        'Locate injured animals on the map and guide them to the wildlife '
        'clinic. Apply first aid in a quick mini-game to restore their health.',
        _DegradedParkScreenState._wildlifeGold, '03'),
    _Phase('📋', 'Design Awareness Posters',
        'Use natural dyes from Level 1, gypsum from Level 4, compost '
        'from Level 5 to craft conservation posters. Match themes to '
        'board locations for maximum awareness impact!',
        _DegradedParkScreenState._posterBlue, '04'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Row(children: [
        Container(width: 3, height: 16,
            color: _DegradedParkScreenState._wildlifeGold,
            margin: const EdgeInsets.only(right: 10)),
        Text('YOUR MISSION',
            style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.w800,
              fontSize: mobile ? 13 : 14, letterSpacing: 1.2,
            )),
        const Spacer(),
        Text('4 phases', style: TextStyle(
            color: _DegradedParkScreenState._wildlifeGold,
            fontSize: 11, fontWeight: FontWeight.w600)),
      ]),
      const SizedBox(height: 12),

      AnimatedBuilder(
        animation: stagger,
        builder: (_, __) => Column(
          children: _phases.asMap().entries.map((e) {
            final delay = e.key * 0.12;
            final raw   = ((stagger.value - delay) / (1.0 - delay))
                .clamp(0.0, 1.0);
            final t     = Curves.easeOutBack.transform(raw).clamp(0.0, 1.0);
            return Opacity(
              opacity: t,
              child: Transform.translate(
                offset: Offset(22 * (1 - t), 0),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: _PhaseCard(phase: e.value, mobile: mobile),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    ]);
  }
}

class _Phase {
  final String emoji, label, desc;
  final Color  color;
  final String num;
  const _Phase(this.emoji, this.label, this.desc, this.color, this.num);
}

class _PhaseCard extends StatelessWidget {
  final _Phase phase;
  final bool   mobile;
  const _PhaseCard({required this.phase, required this.mobile});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(mobile ? 12 : 14),
      decoration: BoxDecoration(
        color: _DegradedParkScreenState._panelAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: phase.color.withValues(alpha: 0.22)),
        boxShadow: [BoxShadow(
            color: phase.color.withValues(alpha: 0.05),
            blurRadius: 12, spreadRadius: 1)],
      ),
      child: Row(children: [
        Container(
          width: mobile ? 52 : 60, height: mobile ? 52 : 60,
          decoration: BoxDecoration(
            color: phase.color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: phase.color.withValues(alpha: 0.32)),
          ),
          child: Stack(children: [
            Center(child: Text(phase.emoji,
                style: TextStyle(fontSize: mobile ? 22 : 26))),
            Positioned(right: 4, bottom: 4,
              child: Text(phase.num,
                  style: TextStyle(
                    color: phase.color.withValues(alpha: 0.55),
                    fontSize: 8, fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  )),
            ),
          ]),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: Text(phase.label,
                  style: TextStyle(
                    color: phase.color, fontWeight: FontWeight.w800,
                    fontSize: mobile ? 13 : 14,
                  ))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: phase.color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('PHASE ${phase.num}',
                    style: TextStyle(
                      color: phase.color, fontSize: 8,
                      fontWeight: FontWeight.w900, letterSpacing: 0.8,
                    )),
              ),
            ]),
            const SizedBox(height: 4),
            Text(phase.desc,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: mobile ? 10.5 : 11.5, height: 1.45,
                )),
          ],
        )),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  CARRY-OVER PANEL  (Level 5 resources loaded into Level 6)
// ════════════════════════════════════════════════════════════════════════════
class _CarryOverPanel extends StatelessWidget {
  final AnimationController stagger, shimmer;
  final Level5CarryOver    carryOver;
  final bool               mobile;

  const _CarryOverPanel({
    required this.stagger, required this.shimmer,
    required this.carryOver, required this.mobile,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      _SI('⭐', 'Eco-Points',    '${carryOver.ecoPoints}',
          _DegradedParkScreenState._wildlifeGold),
      _SI('🌑', 'Biochar',       '${carryOver.biochar}',
          _DegradedParkScreenState._pollutedBrown),
      _SI('🌿', 'Compost',       '${carryOver.compost}',
          _DegradedParkScreenState._murkyGreen),
      _SI('🧫', 'Bacteria',      '${carryOver.bacteriaCultures}',
          _DegradedParkScreenState._waterTeal),
      _SI('🪨', 'Gypsum',        '${carryOver.gypsum}',
          _DegradedParkScreenState._healthGreen),
      _SI('🎨', 'Natural Dyes',  '${carryOver.naturalDyes}',
          _DegradedParkScreenState._posterBlue),
    ];

    return AnimatedBuilder(
      animation: shimmer,
      builder: (_, __) => Container(
        padding: EdgeInsets.all(mobile ? 14 : 18),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            const Color(0xFF081008),
            Color.lerp(const Color(0xFF081008),
                const Color(0xFF0E1A0A), shimmer.value * 0.4)!,
          ], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: _DegradedParkScreenState._healthGreen
                  .withValues(alpha: 0.18 + shimmer.value * 0.12)),
          boxShadow: [BoxShadow(
              color: _DegradedParkScreenState._healthGreen
                  .withValues(alpha: 0.05),
              blurRadius: 18, spreadRadius: 1)],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: _DegradedParkScreenState._healthGreen
                    .withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                    color: _DegradedParkScreenState._healthGreen
                        .withValues(alpha: 0.30)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Text('✅', style: TextStyle(fontSize: 11)),
                const SizedBox(width: 5),
                Text('LEVEL 5 CARRY-OVER',
                    style: TextStyle(
                      color: _DegradedParkScreenState._healthGreen,
                      fontSize: 10, fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    )),
              ]),
            ),
            const Spacer(),
            Text('Loaded into Level 6',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.30), fontSize: 10,
                )),
          ]),

          const SizedBox(height: 14),

          ...items.map((s) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _SRow(stat: s),
          )),
        ]),
      ),
    );
  }
}

class _SI {
  final String emoji, label, value;
  final Color  color;
  const _SI(this.emoji, this.label, this.value, this.color);
}

class _SRow extends StatelessWidget {
  final _SI stat;
  const _SRow({required this.stat});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: stat.color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: stat.color.withValues(alpha: 0.18)),
      ),
      child: Row(children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: stat.color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: stat.color.withValues(alpha: 0.25)),
          ),
          child: Center(child: Text(stat.emoji,
              style: const TextStyle(fontSize: 15))),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(stat.label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 12, fontWeight: FontWeight.w500,
            ))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: stat.color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: stat.color.withValues(alpha: 0.30)),
          ),
          child: Text(stat.value,
              style: TextStyle(color: stat.color,
                  fontWeight: FontWeight.w800, fontSize: 13)),
        ),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  FLOATING ACTION BAR
// ════════════════════════════════════════════════════════════════════════════
class _FloatingActionBar extends StatelessWidget {
  final AnimationController pulse, shimmer;
  final bool mobile;
  final double hPad;
  final VoidCallback onStart, onControls;

  const _FloatingActionBar({
    required this.pulse, required this.shimmer,
    required this.mobile, required this.hPad,
    required this.onStart, required this.onControls,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([pulse, shimmer]),
      builder: (_, __) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [
              _DegradedParkScreenState._bgDeep.withValues(alpha: 0.0),
              _DegradedParkScreenState._bgDeep.withValues(alpha: 0.82),
              _DegradedParkScreenState._bgDeep,
            ],
            stops: const [0.0, 0.38, 1.0],
          ),
        ),
        padding: EdgeInsets.fromLTRB(
          hPad, 18, hPad,
          MediaQuery.of(context).padding.bottom + (mobile ? 18 : 22),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _StartBtn(pulse: pulse, shimmer: shimmer,
              mobile: mobile, onTap: onStart),
          SizedBox(width: mobile ? 10 : 14),
          _SecBtn(icon: Icons.gamepad_rounded, label: 'View Controls',
              pulse: pulse, onTap: onControls, mobile: mobile),
        ]),
      ),
    );
  }
}

class _StartBtn extends StatelessWidget {
  final AnimationController pulse, shimmer;
  final bool mobile;
  final VoidCallback onTap;
  const _StartBtn({required this.pulse, required this.shimmer,
      required this.mobile, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([pulse, shimmer]),
      builder: (_, __) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(
              vertical: mobile ? 14 : 16, horizontal: mobile ? 22 : 30),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              Color.lerp(const Color(0xFF0A1800), const Color(0xFF142800),
                  shimmer.value)!,
              Color.lerp(const Color(0xFF142800), const Color(0xFF1C3400),
                  shimmer.value)!,
              Color.lerp(const Color(0xFF142800), const Color(0xFF0A1800),
                  shimmer.value)!,
            ]),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: _DegradedParkScreenState._wildlifeGold
                    .withValues(alpha: 0.40 + pulse.value * 0.25),
                width: 1.5),
            boxShadow: [
              BoxShadow(
                  color: _DegradedParkScreenState._wildlifeGold
                      .withValues(alpha: 0.22 + pulse.value * 0.18),
                  blurRadius: 24, offset: const Offset(0, 4)),
            ],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Text('🦒', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Text('START LEVEL 6',
                style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w900,
                  fontSize: mobile ? 15 : 17, letterSpacing: 1.2,
                )),
            const SizedBox(width: 10),
            Icon(Icons.arrow_forward_rounded,
                color: Colors.white.withValues(alpha: 0.7 + pulse.value * 0.3),
                size: 20),
          ]),
        ),
      ),
    );
  }
}

class _SecBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final AnimationController pulse;
  final bool mobile;
  const _SecBtn({required this.icon, required this.label, required this.onTap,
      required this.pulse, required this.mobile});

  @override
  Widget build(BuildContext context) {
    final p = pulse.value;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
            vertical: mobile ? 14 : 16, horizontal: mobile ? 18 : 24),
        decoration: BoxDecoration(
          color: _DegradedParkScreenState._waterTeal
              .withValues(alpha: 0.10 + p * 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _DegradedParkScreenState._waterTeal
                .withValues(alpha: 0.50 + p * 0.25),
            width: 1.5,
          ),
          boxShadow: [BoxShadow(
            color: _DegradedParkScreenState._waterTeal
                .withValues(alpha: 0.14 + p * 0.16),
            blurRadius: 18, offset: const Offset(0, 4),
          )],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon,
              color: _DegradedParkScreenState._waterTeal
                  .withValues(alpha: 0.85 + p * 0.15),
              size: mobile ? 17 : 18),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(
                color: _DegradedParkScreenState._waterTeal
                    .withValues(alpha: 0.90 + p * 0.10),
                fontWeight: FontWeight.w700,
                fontSize: mobile ? 13 : 14, letterSpacing: 0.4,
              )),
        ]),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  CONTROLS SCREEN  — typewriter walkthrough
// ════════════════════════════════════════════════════════════════════════════
class _ControlsScreen extends StatefulWidget {
  final Level5CarryOver carryOver;
  const _ControlsScreen({required this.carryOver});
  @override
  State<_ControlsScreen> createState() => _ControlsScreenState();
}

class _ControlsScreenState extends State<_ControlsScreen>
    with SingleTickerProviderStateMixin {

  final ScrollController _scrollCtrl = ScrollController();
  late final AnimationController _pulseCtrl;

  static const List<String> _sections = [
    '🗑️ PHASE 1 — COLLECT THE WASTE',
    'Pilot your eco-drone across the degraded park. Fly over scattered litter '
    'and press COLLECT to scoop it up. Each item lands in your waste bin.',
    '',
    '▶  Tap ⬆ UP / ⬇ DOWN / ◀ LEFT / ▶ RIGHT to steer the drone.',
    '▶  Desktop: W/↑ A/← S/↓ D/→ or Arrow keys.',
    '▶  Fly near litter then tap 🗑️ COLLECT or press Space.',
    '▶  After collection, the sorting mini-game appears.',
    '▶  Sort each item: Recyclable ♻️ | Reusable 🔄 | Biodegradable 🌿',
    '▶  Correct sort = +20 pts  |  Wrong sort = −5 pts.',
    '',
    '💧 PHASE 2 — PURIFY ANIMAL DRINKING POINTS',
    'Fly to each polluted pond (marked with a 💧 icon). Apply the correct '
    'treatment to clean the water and restore it for wildlife.',
    '',
    '▶  Water Hyacinths → Remove excess nutrients / algae blooms.',
    '▶  Eco-Bacteria Pellets → Break down organic waste and toxins.',
    '▶  Filtration Unit → Remove sediment and chemical pollutants.',
    '▶  Fly close to a pond then tap 💧 TREAT or press Space.',
    '▶  Correct treatment = +25 pts  |  Wrong treatment = −8 pts.',
    '▶  Water Purity Meter (top) rises as ponds are cleaned.',
    '',
    '🦓 PHASE 3 — RESCUE INJURED WILDLIFE',
    'Injured animals are marked on the map with a ❤️ icon. '
    'Guide each one to the wildlife clinic by flying alongside them.',
    '',
    '▶  Locate the nearest injured animal on your HUD.',
    '▶  Fly within range and tap 🦓 GUIDE or press Space to escort.',
    '▶  A quick first-aid mini-game appears — tap the correct treatment.',
    '▶  Clean Wound → antiseptic | Broken Limb → splint | Malnourished → feed.',
    '▶  Successful rescue = +30 pts.  |  Missed animal = −10 pts.',
    '',
    '📋 PHASE 4 — DESIGN AWARENESS POSTERS',
    'Use your carry-over resources to craft conservation posters. '
    'Place them at poster boards around the park.',
    '',
    '▶  Select a poster template from the tray.',
    '▶  Choose your materials: natural dyes 🎨 for colour, chalk/gypsum 🪨 for text.',
    '▶  Fly to a poster board location and tap 📋 PLACE or press Space.',
    '▶  Each correct poster = +15 pts  •  Raises Eco-Consciousness Meter.',
    '▶  Place all 5 posters to complete Level 6!',
    '',
    '⭐  Restore Ondiri — protect wildlife, clean water, spread awareness! 🌍',
  ];

  String _displayedText = '';
  int  _secIdx = 0, _charIdx = 0;
  bool _typingDone = false;
  Timer? _typeTimer;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 1400))..repeat(reverse: true);
    _startTyping();
  }

  void _startTyping() {
    _typeTimer = Timer.periodic(const Duration(milliseconds: 18), (timer) {
      if (!mounted) { timer.cancel(); return; }
      if (_secIdx < _sections.length) {
        final sec = _sections[_secIdx];
        if (_charIdx < sec.length) {
          setState(() { _displayedText += sec[_charIdx]; _charIdx++; });
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollCtrl.hasClients) {
              _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
                  duration: const Duration(milliseconds: 80),
                  curve: Curves.easeOut);
            }
          });
        } else {
          setState(() {
            _displayedText += '\n\n'; _secIdx++; _charIdx = 0;
          });
        }
      } else {
        setState(() => _typingDone = true);
        timer.cancel();
      }
    });
  }

  void _startGame(BuildContext ctx) {
    HapticFeedback.heavyImpact();
    Navigator.of(ctx).pushReplacement(PageRouteBuilder(
      pageBuilder: (_, anim, __) =>
          HabitatCleanupGameScreen(carryOver: widget.carryOver),
      transitionsBuilder: (_, anim, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeIn),
          child: child),
      transitionDuration: const Duration(milliseconds: 500),
    ));
  }

  @override
  void dispose() {
    _typeTimer?.cancel(); _pulseCtrl.dispose(); _scrollCtrl.dispose();
    super.dispose();
  }

  List<TextSpan> _buildStyledSpans(String text) {
    final spans = <TextSpan>[];
    for (final line in text.split('\n')) {
      if (line.startsWith('🗑️') || line.startsWith('💧') ||
          line.startsWith('🦓') || line.startsWith('📋') ||
          line.startsWith('⭐')) {
        spans.add(TextSpan(text: '$line\n', style: TextStyle(
          color: _DegradedParkScreenState._wildlifeGold,
          fontSize: 13.5, fontWeight: FontWeight.w900,
          height: 2.0, letterSpacing: 0.4,
        )));
      } else if (line.startsWith('▶')) {
        spans.add(TextSpan(text: '$line\n', style: TextStyle(
          color: _DegradedParkScreenState._waterTeal,
          fontSize: 12, height: 1.7, fontWeight: FontWeight.w500,
        )));
      } else if (line.trim().isEmpty) {
        spans.add(const TextSpan(text: '\n'));
      } else {
        spans.add(TextSpan(text: '$line\n', style: TextStyle(
          color: Colors.white.withValues(alpha: 0.60),
          fontSize: 12, height: 1.75,
        )));
      }
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.of(context).size.width < 640;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _DegradedParkScreenState._bgDeep,
        body: SafeArea(child: Column(children: [

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: _DegradedParkScreenState._panel,
              border: Border(bottom: BorderSide(
                  color: _DegradedParkScreenState._waterTeal
                      .withValues(alpha: 0.16))),
            ),
            child: Row(children: [
              _IBtn(icon: Icons.arrow_back_rounded,
                  onTap: () => Navigator.of(context).pop()),
              const SizedBox(width: 12),
              Expanded(child: Text('🎮  Game Controls',
                  style: TextStyle(color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: mobile ? 15 : 16))),
            ]),
          ),

          Expanded(child: SingleChildScrollView(
            controller: _scrollCtrl,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(text: TextSpan(
                    style: const TextStyle(
                        fontFamily: 'monospace', fontSize: 12, height: 1.75),
                    children: _buildStyledSpans(_displayedText),
                  )),
                  if (!_typingDone)
                    Padding(padding: const EdgeInsets.only(top: 2),
                        child: _BlinkCursor(
                            color: _DegradedParkScreenState._waterTeal)),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          )),

          AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (_, __) => Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              decoration: BoxDecoration(
                color: _DegradedParkScreenState._panel,
                border: Border(top: BorderSide(
                    color: Colors.white.withValues(alpha: 0.07))),
              ),
              child: SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  onTap: () => _startGame(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        Color.lerp(const Color(0xFF0A1800),
                            const Color(0xFF142800), _pulseCtrl.value)!,
                        Color.lerp(const Color(0xFF142800),
                            const Color(0xFF1C3400), _pulseCtrl.value)!,
                      ]),
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(
                          color: _DegradedParkScreenState._wildlifeGold
                              .withValues(alpha: 0.35 + _pulseCtrl.value * 0.20)),
                      boxShadow: [BoxShadow(
                          color: _DegradedParkScreenState._wildlifeGold
                              .withValues(alpha: 0.15 + _pulseCtrl.value * 0.12),
                          blurRadius: 14)],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('🦒', style: TextStyle(fontSize: 18)),
                        const SizedBox(width: 8),
                        Text('Start Level 6',
                            style: TextStyle(color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: mobile ? 14 : 15)),
                        const SizedBox(width: 8),
                        Icon(Icons.arrow_forward_rounded,
                            color: Colors.white.withValues(
                                alpha: 0.6 + _pulseCtrl.value * 0.4),
                            size: 18),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ])),
      ),
    );
  }
}

class _IBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IBtn({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: Colors.white12),
      ),
      child: Icon(icon, color: Colors.white70, size: 18),
    ),
  );
}

class _BlinkCursor extends StatefulWidget {
  final Color color;
  const _BlinkCursor({required this.color});
  @override
  State<_BlinkCursor> createState() => _BlinkCursorState();
}

class _BlinkCursorState extends State<_BlinkCursor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 530))..repeat(reverse: true);
  }
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _c,
    child: Container(
      width: 7, height: 14,
      decoration: BoxDecoration(
          color: widget.color, borderRadius: BorderRadius.circular(2)),
    ),
  );
}