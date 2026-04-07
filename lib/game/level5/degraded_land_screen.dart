import 'dart:async';
import 'dart:math' as math;
import 'package:ecoquest/game/level5/land_degradation_game_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  LAND & SOIL POLLUTION SCREEN  —  Level 5 Introduction
//  Pure Flutter. Zero Flame. Zero image assets.
//  Receives carry-over values from Level 4 and forwards them to
//  LandDegradationGameScreen via Level4CarryOver.
// ══════════════════════════════════════════════════════════════════════════════

/// Carry-over data from Level 4 (Air & Noise Pollution).
class Level4CarryOver {
  final int ecoPoints;
  final int airEcoPoints;
  final int noiseEcoPoints;
  final int pollutantsNeutralized;
  final int hotspotsFix;
  final int methanol;
  final int gypsum;
  final int urea;
  final int nitrates;
  final bool peacefulCityBadge;

  const Level4CarryOver({
    this.ecoPoints             = 0,
    this.airEcoPoints          = 0,
    this.noiseEcoPoints        = 0,
    this.pollutantsNeutralized = 0,
    this.hotspotsFix           = 0,
    this.methanol              = 0,
    this.gypsum                = 0,
    this.urea                  = 0,
    this.nitrates              = 0,
    this.peacefulCityBadge     = false,
  });
}

class DegradedLandScreen extends StatefulWidget {
  final Level4CarryOver carryOver;

  const DegradedLandScreen({
    super.key,
    this.carryOver = const Level4CarryOver(),
  });

  @override
  State<DegradedLandScreen> createState() => _DegradedLandScreenState();
}

class _DegradedLandScreenState extends State<DegradedLandScreen>
    with TickerProviderStateMixin {

  // ── Animation controllers ──────────────────────────────────────────────────
  late final AnimationController _bgCtrl;
  late final AnimationController _entryCtrl;
  late final AnimationController _staggerCtrl;
  late final AnimationController _pulseCtrl;
  late final AnimationController _shimmerCtrl;
  late final AnimationController _dustCtrl;
  late final AnimationController _landCtrl;

  late final Animation<double> _fadeAnim;
  late final Animation<Offset>  _titleSlide;
  late final Animation<double>  _titleScale;

  // ── Palette ────────────────────────────────────────────────────────────────
  static const Color _bgDeep       = Color(0xFF0A0804);
  static const Color _panel        = Color(0xFF120E08);
  static const Color _panelAlt     = Color(0xFF161008);
  static const Color _dustBrown    = Color(0xFFBCAAA4);
  static const Color _erosionRed   = Color(0xFFEF5350);
  static const Color _soilAmber    = Color(0xFFFFB300);
  static const Color _fertileGreen = Color(0xFF69F0AE);
  static const Color _earthOrange  = Color(0xFFFF6D00);
  static const Color _clayTan      = Color(0xFFD7CCC8);
  static const Color _waterBlue    = Color(0xFF29B6F6);

  @override
  void initState() {
    super.initState();

    _bgCtrl = AnimationController(vsync: this,
        duration: const Duration(seconds: 14))..repeat(reverse: true);
    _entryCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 900))..forward();
    _staggerCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 1400))..forward();
    _pulseCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 1600))..repeat(reverse: true);
    _shimmerCtrl = AnimationController(vsync: this,
        duration: const Duration(seconds: 2))..repeat(reverse: true);
    _dustCtrl = AnimationController(vsync: this,
        duration: const Duration(seconds: 9))..repeat();
    _landCtrl = AnimationController(vsync: this,
        duration: const Duration(seconds: 11))..repeat(reverse: true);

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
    _bgCtrl.dispose();
    _entryCtrl.dispose();
    _staggerCtrl.dispose();
    _pulseCtrl.dispose();
    _shimmerCtrl.dispose();
    _dustCtrl.dispose();
    _landCtrl.dispose();
    super.dispose();
  }

  void _openControls(BuildContext context) {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(PageRouteBuilder(
      pageBuilder: (_, anim, __) =>
          _ControlsScreen(carryOver: widget.carryOver),
      transitionsBuilder: (_, anim, __, child) => SlideTransition(
        position: Tween<Offset>(
                begin: const Offset(0, 1), end: Offset.zero)
            .animate(CurvedAnimation(parent: anim,
                curve: Curves.easeOutCubic)),
        child: child,
      ),
      transitionDuration: const Duration(milliseconds: 420),
    ));
  }

  void _startLevel(BuildContext context) {
    HapticFeedback.heavyImpact();
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, anim, __) =>
            LandDegradationGameScreen(carryOver: widget.carryOver),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeIn),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
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

          _AnimatedErodedBackground(
            bgCtrl:   _bgCtrl,
            landCtrl: _landCtrl,
            dustCtrl: _dustCtrl,
          ),

          _DustParticles(ctrl: _dustCtrl, size: size),

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
                      child: _TitleSection(
                        shimmer: _shimmerCtrl,
                        pulse:   _pulseCtrl,
                        mobile:  mobile,
                      ),
                    ),
                  ),

                  SizedBox(height: mobile ? 22 : 30),

                  _ThreatBanner(pulse: _pulseCtrl, mobile: mobile),

                  SizedBox(height: mobile ? 22 : 28),

                  _MissionPhases(stagger: _staggerCtrl, mobile: mobile),

                  SizedBox(height: mobile ? 22 : 28),

                  _CarryOverPanel(
                    stagger:   _staggerCtrl,
                    shimmer:   _shimmerCtrl,
                    carryOver: widget.carryOver,
                    mobile:    mobile,
                  ),

                  SizedBox(height: mobile ? 100 : 110),
                ]),
              ),
            ),
          ),

          Positioned(
            left: 0, right: 0, bottom: 0,
            child: _FloatingActionBar(
              pulse:      _pulseCtrl,
              shimmer:    _shimmerCtrl,
              mobile:     mobile,
              hPad:       hPad,
              onStart:    () => _startLevel(context),
              onControls: () => _openControls(context),
            ),
          ),
        ]),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  ANIMATED ERODED LAND BACKGROUND
// ════════════════════════════════════════════════════════════════════════════
class _AnimatedErodedBackground extends StatelessWidget {
  final AnimationController bgCtrl;
  final AnimationController landCtrl;
  final AnimationController dustCtrl;

  const _AnimatedErodedBackground({
    required this.bgCtrl,
    required this.landCtrl,
    required this.dustCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([bgCtrl, landCtrl, dustCtrl]),
      builder: (_, __) => SizedBox.expand(
        child: CustomPaint(
          painter: _ErodedLandPainter(
            bgT:   bgCtrl.value,
            landT: landCtrl.value,
            dustT: dustCtrl.value,
          ),
        ),
      ),
    );
  }
}

class _ErodedLandPainter extends CustomPainter {
  final double bgT, landT, dustT;
  const _ErodedLandPainter({
    required this.bgT, required this.landT, required this.dustT,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Sky — dusty haze cycling between orange-brown and grey
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.lerp(const Color(0xFF120A04),
                  const Color(0xFF1A0E06), bgT * 0.4)!,
              Color.lerp(const Color(0xFF1E1008),
                  const Color(0xFF2A1404), bgT * 0.5)!,
              Color.lerp(const Color(0xFF160C04),
                  const Color(0xFF0A0604), bgT * 0.3)!,
            ],
            stops: const [0.0, 0.45, 1.0],
          ).createShader(Rect.fromLTWH(0, 0, w, h)));

    // Dust haze layer
    canvas.drawRect(Rect.fromLTWH(0, h * 0.15, w, h * 0.55),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              const Color(0xFFBCAAA4).withValues(alpha: 0.06 + bgT * 0.08),
              const Color(0xFFFFB300).withValues(alpha: 0.04 + bgT * 0.05),
              Colors.transparent,
            ],
            stops: const [0.0, 0.35, 0.60, 1.0],
          ).createShader(Rect.fromLTWH(0, h * 0.15, w, h * 0.55)));

    // Eroded hillside silhouettes (back)
    _drawErodedHills(canvas, w, h,
        baseY: h * 0.55, color: const Color(0xFF0E0804),
        count: 8, maxH: h * 0.22, seed: 31);

    // Gully-scarred foreground terrain
    _drawGullyTerrain(canvas, w, h);

    // Ground strip
    canvas.drawRect(Rect.fromLTWH(0, h * 0.80, w, h * 0.20),
        Paint()..color = const Color(0xFF0A0602));

    // Cracked soil texture on ground
    _drawCrackedSoil(canvas, w, h, t: landT);
  }

  void _drawErodedHills(Canvas canvas, double w, double h, {
    required double baseY, required Color color,
    required int count, required double maxH, required int seed,
  }) {
    final rng = math.Random(seed);
    double x = -w * 0.06;
    for (int i = 0; i < count; i++) {
      final bw = w * (0.10 + rng.nextDouble() * 0.14);
      final bh = maxH * (0.4 + rng.nextDouble() * 0.6);
      // Draw eroded hill shape (irregular top)
      final path = Path();
      path.moveTo(x, baseY);
      path.lineTo(x, baseY - bh * 0.6);
      path.quadraticBezierTo(
        x + bw * 0.3, baseY - bh * (0.7 + rng.nextDouble() * 0.3),
        x + bw * 0.5, baseY - bh,
      );
      path.quadraticBezierTo(
        x + bw * 0.7, baseY - bh * (0.6 + rng.nextDouble() * 0.3),
        x + bw, baseY - bh * 0.5,
      );
      path.lineTo(x + bw, baseY);
      path.close();
      canvas.drawPath(path, Paint()..color = color);
      x += bw + rng.nextDouble() * w * 0.03;
    }
  }

  void _drawGullyTerrain(Canvas canvas, double w, double h) {
    // Draw V-shaped gullies cutting into the terrain
    final rng = math.Random(55);
    final gullyPaint = Paint()
      ..color = const Color(0xFF080604)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 5; i++) {
      final gx = w * (0.08 + i * 0.19 + rng.nextDouble() * 0.04);
      final gy = h * 0.62;
      final gw = w * (0.03 + rng.nextDouble() * 0.03);
      final gd = h * (0.08 + rng.nextDouble() * 0.06);
      final path = Path();
      path.moveTo(gx - gw, gy);
      path.lineTo(gx, gy + gd);
      path.lineTo(gx + gw, gy);
      path.close();
      canvas.drawPath(path, gullyPaint);
    }

    // Barren plateau
    canvas.drawRect(Rect.fromLTWH(0, h * 0.62, w, h * 0.18),
        Paint()..color = const Color(0xFF120A04));
  }

  void _drawCrackedSoil(Canvas canvas, double w, double h, {required double t}) {
    final crackPaint = Paint()
      ..color = const Color(0xFF2A1804).withValues(alpha: 0.60)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    final rng = math.Random(77);
    for (int i = 0; i < 18; i++) {
      final cx = w * rng.nextDouble();
      final cy = h * (0.65 + rng.nextDouble() * 0.14);
      final len = 12 + rng.nextDouble() * 22;
      final angle = rng.nextDouble() * math.pi;
      canvas.drawLine(
        Offset(cx, cy),
        Offset(cx + math.cos(angle) * len, cy + math.sin(angle) * len),
        crackPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_ErodedLandPainter old) =>
      old.bgT != bgT || old.landT != landT || old.dustT != dustT;
}

// ════════════════════════════════════════════════════════════════════════════
//  DUST PARTICLES
// ════════════════════════════════════════════════════════════════════════════
class _DustParticles extends StatelessWidget {
  final AnimationController ctrl;
  final Size size;
  const _DustParticles({required this.ctrl, required this.size});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ctrl,
      builder: (_, __) => CustomPaint(
          size: size, painter: _DustParticlePainter(t: ctrl.value)),
    );
  }
}

class _DustParticlePainter extends CustomPainter {
  final double t;
  const _DustParticlePainter({required this.t});

  static final List<_DustP> _ps = List.generate(50, (i) {
    final r = math.Random(i * 29 + 3);
    return _DustP(
      x: r.nextDouble(), yStart: 0.40 + r.nextDouble() * 0.60,
      speed: 0.008 + r.nextDouble() * 0.022,
      radius: 1.2 + r.nextDouble() * 4.0,
      drift: (r.nextDouble() - 0.5) * 0.012,
      phase: r.nextDouble(),
      color: [
        const Color(0xFFBCAAA4),
        const Color(0xFFD7CCC8),
        const Color(0xFFFFB300),
        const Color(0xFFEF5350),
        const Color(0xFFA1887F),
      ][r.nextInt(5)],
    );
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in _ps) {
      final progress = ((t + p.phase) % 1.0);
      final y = size.height * (p.yStart - progress * p.speed * 16);
      if (y < -10) continue;
      final x = size.width * (p.x + math.sin(progress * math.pi * 2) * p.drift * 5);
      final alpha = (1.0 - progress * 1.3).clamp(0.0, 0.28);
      canvas.drawCircle(Offset(x, y), p.radius,
          Paint()..color = p.color.withValues(alpha: alpha));
    }
  }

  @override
  bool shouldRepaint(_DustParticlePainter old) => old.t != t;
}

class _DustP {
  final double x, yStart, speed, radius, drift, phase;
  final Color color;
  const _DustP({
    required this.x, required this.yStart, required this.speed,
    required this.radius, required this.drift, required this.phase,
    required this.color,
  });
}

// ════════════════════════════════════════════════════════════════════════════
//  TITLE SECTION
// ════════════════════════════════════════════════════════════════════════════
class _TitleSection extends StatelessWidget {
  final AnimationController shimmer;
  final AnimationController pulse;
  final bool mobile;
  const _TitleSection({
    required this.shimmer, required this.pulse, required this.mobile});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([shimmer, pulse]),
      builder: (_, __) => Column(children: [

        // Level badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: _DegradedLandScreenState._soilAmber.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _DegradedLandScreenState._soilAmber
                  .withValues(alpha: 0.45 + shimmer.value * 0.20),
            ),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 7, height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _DegradedLandScreenState._soilAmber
                    .withValues(alpha: 0.7 + pulse.value * 0.3),
                boxShadow: [BoxShadow(
                  color: _DegradedLandScreenState._soilAmber
                      .withValues(alpha: 0.5),
                  blurRadius: 6,
                )],
              ),
            ),
            const SizedBox(width: 8),
            Text('LEVEL  5',
                style: TextStyle(
                  color: _DegradedLandScreenState._soilAmber,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 3.0,
                )),
          ]),
        ),

        const SizedBox(height: 14),

        // Main title with shimmer
        ShaderMask(
          shaderCallback: (bounds) => LinearGradient(colors: [
            const Color(0xFFFFFFFF),
            Color.lerp(Colors.white, _DegradedLandScreenState._dustBrown,
                shimmer.value * 0.30)!,
            const Color(0xFFFFFFFF),
          ], stops: const [0.0, 0.5, 1.0]).createShader(bounds),
          child: Text(
            'Land Degradation\n& Soil Pollution',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: mobile ? 32 : 42,
              fontWeight: FontWeight.w900,
              height: 1.15,
              letterSpacing: -0.5,
            ),
          ),
        ),

        const SizedBox(height: 12),

        Text(
          'The land is scarred and the soil is poisoned.\nRestore the earth through science and care.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.45),
            fontSize: mobile ? 12 : 13,
            height: 1.55,
            letterSpacing: 0.2,
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
          color: _DegradedLandScreenState._erosionRed.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: _DegradedLandScreenState._erosionRed
                  .withValues(alpha: 0.20 + pulse.value * 0.12)),
          boxShadow: [BoxShadow(
              color: _DegradedLandScreenState._erosionRed
                  .withValues(alpha: 0.06),
              blurRadius: 18, spreadRadius: 1)],
        ),
        child: Row(children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: _DegradedLandScreenState._erosionRed
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: _DegradedLandScreenState._erosionRed
                      .withValues(alpha: 0.30 + pulse.value * 0.20)),
              boxShadow: [BoxShadow(
                  color: _DegradedLandScreenState._erosionRed
                      .withValues(alpha: 0.15 + pulse.value * 0.15),
                  blurRadius: 12)],
            ),
            child: const Center(
                child: Text('⚠️', style: TextStyle(fontSize: 18))),
          ),
          const SizedBox(width: 13),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('CRITICAL EROSION LEVEL',
                  style: TextStyle(
                    color: _DegradedLandScreenState._erosionRed,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.8,
                  )),
              const SizedBox(height: 3),
              Text(
                'Deep gullies, toxic soil, and barren land. '
                'Crops fail, wildlife vanishes, communities suffer.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: mobile ? 11 : 12,
                  height: 1.4,
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
    _Phase('🛰️', 'Survey the Land',
        'Pilot your restoration drone to scan the terrain and identify critical erosion zones and gullies.',
        _DegradedLandScreenState._dustBrown,    '01'),
    _Phase('🪨', 'Restore Land Structure',
        'Build terraces, stone check dams, and contour lines. Plant grasses and cover crops on barren slopes.',
        _DegradedLandScreenState._earthOrange,  '02'),
    _Phase('🔬', 'Diagnose Soil Pollution',
        'Use the soil scanner to detect oil spills, heavy metals, pesticide residues and acidic zones.',
        _DegradedLandScreenState._erosionRed,   '03'),
    _Phase('🌱', 'Remediate the Soil',
        'Apply the correct bioremediation agent: biochar, bacteria, lime, compost, worms or phyto-plants.',
        _DegradedLandScreenState._fertileGreen, '04'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Row(children: [
        Container(width: 3, height: 16,
            color: _DegradedLandScreenState._soilAmber,
            margin: const EdgeInsets.only(right: 10)),
        Text('YOUR MISSION',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: mobile ? 13 : 14,
              letterSpacing: 1.2,
            )),
        const Spacer(),
        Text('4 phases', style: TextStyle(
            color: _DegradedLandScreenState._soilAmber,
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
        color: _DegradedLandScreenState._panelAlt,
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
                    color: phase.color,
                    fontWeight: FontWeight.w800,
                    fontSize: mobile ? 13 : 14,
                  ))),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 7, vertical: 2),
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
                  fontSize: mobile ? 10.5 : 11.5,
                  height: 1.45,
                )),
          ],
        )),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  CARRY-OVER PANEL  (Level 4 resources loaded into Level 5)
// ════════════════════════════════════════════════════════════════════════════
class _CarryOverPanel extends StatelessWidget {
  final AnimationController stagger;
  final AnimationController shimmer;
  final Level4CarryOver    carryOver;
  final bool               mobile;

  const _CarryOverPanel({
    required this.stagger, required this.shimmer,
    required this.carryOver, required this.mobile,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      _StatItem('⭐', 'Eco-Points',    '${carryOver.ecoPoints}',
          _DegradedLandScreenState._soilAmber),
      _StatItem('💨', 'Air Pts',       '${carryOver.airEcoPoints}',
          _DegradedLandScreenState._waterBlue),
      _StatItem('🌿', 'Noise Pts',     '${carryOver.noiseEcoPoints}',
          _DegradedLandScreenState._fertileGreen),
      _StatItem('⚗️', 'Methanol',      '${carryOver.methanol}',
          _DegradedLandScreenState._dustBrown),
      _StatItem('🪨', 'Gypsum',        '${carryOver.gypsum}',
          _DegradedLandScreenState._clayTan),
      _StatItem('🧪', 'Nitrates',      '${carryOver.nitrates}',
          _DegradedLandScreenState._earthOrange),
    ];

    return AnimatedBuilder(
      animation: shimmer,
      builder: (_, __) => Container(
        padding: EdgeInsets.all(mobile ? 14 : 18),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            const Color(0xFF120E08),
            Color.lerp(const Color(0xFF120E08),
                const Color(0xFF1A1204), shimmer.value * 0.4)!,
          ], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: _DegradedLandScreenState._fertileGreen
                  .withValues(alpha: 0.18 + shimmer.value * 0.12)),
          boxShadow: [BoxShadow(
              color: _DegradedLandScreenState._fertileGreen
                  .withValues(alpha: 0.05),
              blurRadius: 18, spreadRadius: 1)],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: _DegradedLandScreenState._fertileGreen
                    .withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: _DegradedLandScreenState._fertileGreen
                    .withValues(alpha: 0.30)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Text('✅', style: TextStyle(fontSize: 11)),
                const SizedBox(width: 5),
                Text('LEVEL 4 CARRY-OVER',
                    style: TextStyle(
                      color: _DegradedLandScreenState._fertileGreen,
                      fontSize: 10, fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    )),
              ]),
            ),
            const Spacer(),
            Text('Loaded into Level 5',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.30),
                  fontSize: 10,
                )),
          ]),

          const SizedBox(height: 14),

          ...items.map((s) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _StatRow(stat: s),
          )),
        ]),
      ),
    );
  }
}

class _StatItem {
  final String emoji, label, value;
  final Color  color;
  const _StatItem(this.emoji, this.label, this.value, this.color);
}

class _StatRow extends StatelessWidget {
  final _StatItem stat;
  const _StatRow({required this.stat});

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
              style: TextStyle(
                color: stat.color,
                fontWeight: FontWeight.w800, fontSize: 13,
              )),
        ),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  FLOATING ACTION BAR
// ════════════════════════════════════════════════════════════════════════════
class _FloatingActionBar extends StatelessWidget {
  final AnimationController pulse;
  final AnimationController shimmer;
  final bool         mobile;
  final double       hPad;
  final VoidCallback onStart;
  final VoidCallback onControls;

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
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _DegradedLandScreenState._bgDeep.withValues(alpha: 0.0),
              _DegradedLandScreenState._bgDeep.withValues(alpha: 0.82),
              _DegradedLandScreenState._bgDeep,
            ],
            stops: const [0.0, 0.38, 1.0],
          ),
        ),
        padding: EdgeInsets.fromLTRB(
          hPad, 18, hPad,
          MediaQuery.of(context).padding.bottom + (mobile ? 18 : 22),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _StartButton(pulse: pulse, shimmer: shimmer,
              mobile: mobile, onTap: onStart),
          SizedBox(width: mobile ? 10 : 14),
          _SecondaryBtn(
            icon: Icons.gamepad_rounded, label: 'View Controls',
            pulse: pulse, onTap: onControls, mobile: mobile,
          ),
        ]),
      ),
    );
  }
}

class _StartButton extends StatelessWidget {
  final AnimationController pulse, shimmer;
  final bool         mobile;
  final VoidCallback onTap;

  const _StartButton({
    required this.pulse, required this.shimmer,
    required this.mobile, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([pulse, shimmer]),
      builder: (_, __) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(
              vertical: mobile ? 14 : 16,
              horizontal: mobile ? 22 : 30),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              Color.lerp(const Color(0xFF1A0E00),
                  const Color(0xFF2E1C00), shimmer.value)!,
              Color.lerp(const Color(0xFF2E1C00),
                  const Color(0xFF3D2600), shimmer.value)!,
              Color.lerp(const Color(0xFF2E1C00),
                  const Color(0xFF1A0E00), shimmer.value)!,
            ]),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: _DegradedLandScreenState._soilAmber
                    .withValues(alpha: 0.40 + pulse.value * 0.25),
                width: 1.5),
            boxShadow: [
              BoxShadow(
                  color: _DegradedLandScreenState._soilAmber
                      .withValues(alpha: 0.22 + pulse.value * 0.18),
                  blurRadius: 24, offset: const Offset(0, 4)),
              BoxShadow(
                  color: _DegradedLandScreenState._soilAmber
                      .withValues(alpha: 0.08 + pulse.value * 0.06),
                  blurRadius: 40, spreadRadius: 2),
            ],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Text('🛰️', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Text('START LEVEL 5',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: mobile ? 15 : 17,
                  letterSpacing: 1.2,
                )),
            const SizedBox(width: 10),
            Icon(Icons.arrow_forward_rounded,
                color: Colors.white.withValues(
                    alpha: 0.7 + pulse.value * 0.3),
                size: 20),
          ]),
        ),
      ),
    );
  }
}

class _SecondaryBtn extends StatelessWidget {
  final IconData        icon;
  final String          label;
  final VoidCallback    onTap;
  final AnimationController pulse;
  final bool            mobile;

  const _SecondaryBtn({
    required this.icon, required this.label,
    required this.onTap, required this.pulse, required this.mobile,
  });

  @override
  Widget build(BuildContext context) {
    final p = pulse.value;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
            vertical: mobile ? 14 : 16,
            horizontal: mobile ? 18 : 24),
        decoration: BoxDecoration(
          color: _DegradedLandScreenState._waterBlue
              .withValues(alpha: 0.10 + p * 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _DegradedLandScreenState._waterBlue
                .withValues(alpha: 0.50 + p * 0.25),
            width: 1.5,
          ),
          boxShadow: [BoxShadow(
            color: _DegradedLandScreenState._waterBlue
                .withValues(alpha: 0.14 + p * 0.16),
            blurRadius: 18, offset: const Offset(0, 4),
          )],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon,
              color: _DegradedLandScreenState._waterBlue
                  .withValues(alpha: 0.85 + p * 0.15),
              size: mobile ? 17 : 18),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(
                color: _DegradedLandScreenState._waterBlue
                    .withValues(alpha: 0.90 + p * 0.10),
                fontWeight: FontWeight.w700,
                fontSize: mobile ? 13 : 14,
                letterSpacing: 0.4,
              )),
        ]),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  CONTROLS SCREEN  — typewriter explanation of all 4 phases
// ════════════════════════════════════════════════════════════════════════════
class _ControlsScreen extends StatefulWidget {
  final Level4CarryOver carryOver;
  const _ControlsScreen({required this.carryOver});
  @override
  State<_ControlsScreen> createState() => _ControlsScreenState();
}

class _ControlsScreenState extends State<_ControlsScreen>
    with SingleTickerProviderStateMixin {

  final ScrollController _scrollCtrl = ScrollController();
  late final AnimationController _pulseCtrl;

  static const List<String> _sections = [
    '🛰️ PHASE 1 — SURVEY THE LAND',
    'Pilot your restoration drone above the degraded terrain. '
    'Move in all directions to fly over barren zones, gullies, and eroded slopes.',
    '',
    '▶  Tap ⬆ UP / ⬇ DOWN / ◀ LEFT / ▶ RIGHT to steer the drone.',
    '▶  Desktop: W/↑ A/← S/↓ D/→ or Arrow keys.',
    '▶  Stay within the survey zone — highlighted tiles turn orange when detected.',
    '▶  Scan all critical zones to unlock the restoration tools.',
    '',
    '🪨 PHASE 2 — RESTORE LAND STRUCTURE',
    'The terrain has deep erosion gullies and bare slopes. '
    'Fly near each degraded patch and apply the correct restoration tool.',
    '',
    '▶  Select tool from the tray at the bottom.',
    '▶  Terrace Tool  → Place on steep slopes to prevent runoff.',
    '▶  Check Dam     → Block gullies with stone or log barriers.',
    '▶  Cover Crop    → Plant grasses on bare flat land.',
    '▶  Biochar/Compost → Apply on cracked dry soil zones.',
    '▶  Tap 🪨 RESTORE or press Space to apply.',
    '▶  Correct placement = +10 pts  |  Wrong tool = −5 pts.',
    '▶  Erosion Index Meter drops as land stabilizes.',
    '',
    '🔬 PHASE 3 — DIAGNOSE SOIL POLLUTION',
    'The soil is contaminated from oil spills, pesticides, heavy metals '
    'and acidic chemical waste. Use the soil scanner to reveal pollutant zones.',
    '',
    '▶  Tap 🔬 SCAN to activate the Soil Analyzer.',
    '▶  Coloured hotspots reveal the pollutant type and severity.',
    '▶  Red = Oil spill  |  Purple = Heavy metals  |  Orange = Pesticides  |  Grey = Acidic soil.',
    '▶  Tap a hotspot to read its pollutant type and Soil Health reading.',
    '',
    '🌱 PHASE 4 — REMEDIATE THE SOIL',
    'Navigate the drone to each polluted zone and apply the correct '
    'natural remedy. Match the treatment to the contaminant!',
    '',
    '▶  Oil-contaminated soil → Apply Biochar + Bacteria culture.',
    '▶  Acidic soil           → Sprinkle Lime or Gypsum.',
    '▶  Heavy metal zones     → Plant Sunflower or Vetiver grass.',
    '▶  Pesticide areas       → Add Compost + Earthworms.',
    '▶  Compact soil          → Introduce Earthworms for aeration.',
    '▶  Correct = +20 pts  |  Incorrect = −10 pts.',
    '▶  Reach 80% Soil Health to unlock the "Soil Guardian" badge!',
    '',
    '⭐  Restore the land, heal the soil — Good luck, Eco-Hero! 🌍',
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
              _scrollCtrl.animateTo(
                _scrollCtrl.position.maxScrollExtent,
                duration: const Duration(milliseconds: 80),
                curve: Curves.easeOut,
              );
            }
          });
        } else {
          setState(() {
            _displayedText += '\n\n';
            _secIdx++;
            _charIdx = 0;
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
          LandDegradationGameScreen(carryOver: widget.carryOver),
      transitionsBuilder: (_, anim, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeIn),
          child: child),
      transitionDuration: const Duration(milliseconds: 500),
    ));
  }

  @override
  void dispose() {
    _typeTimer?.cancel();
    _pulseCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  List<TextSpan> _buildStyledSpans(String text) {
    final spans = <TextSpan>[];
    for (final line in text.split('\n')) {
      if (line.startsWith('🛰️') || line.startsWith('🪨') ||
          line.startsWith('🔬') || line.startsWith('🌱') ||
          line.startsWith('⭐')) {
        spans.add(TextSpan(text: '$line\n', style: TextStyle(
          color: _DegradedLandScreenState._soilAmber,
          fontSize: 13.5, fontWeight: FontWeight.w900,
          height: 2.0, letterSpacing: 0.4,
        )));
      } else if (line.startsWith('▶') || line.startsWith('   ')) {
        spans.add(TextSpan(text: '$line\n', style: TextStyle(
          color: _DegradedLandScreenState._waterBlue,
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
        backgroundColor: _DegradedLandScreenState._bgDeep,
        body: SafeArea(child: Column(children: [

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: _DegradedLandScreenState._panel,
              border: Border(bottom: BorderSide(
                  color: _DegradedLandScreenState._waterBlue
                      .withValues(alpha: 0.16))),
            ),
            child: Row(children: [
              _IconBtn(icon: Icons.arrow_back_rounded,
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(text: TextSpan(
                    style: const TextStyle(
                        fontFamily: 'monospace', fontSize: 12, height: 1.75),
                    children: _buildStyledSpans(_displayedText),
                  )),
                  if (!_typingDone)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: _BlinkingCursor(
                          color: _DegradedLandScreenState._waterBlue),
                    ),
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
                color: _DegradedLandScreenState._panel,
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
                        Color.lerp(const Color(0xFF1A0E00),
                            const Color(0xFF2E1C00), _pulseCtrl.value)!,
                        Color.lerp(const Color(0xFF2E1C00),
                            const Color(0xFF3D2600), _pulseCtrl.value)!,
                      ]),
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(
                          color: _DegradedLandScreenState._soilAmber
                              .withValues(alpha: 0.35 + _pulseCtrl.value * 0.20)),
                      boxShadow: [BoxShadow(
                          color: _DegradedLandScreenState._soilAmber
                              .withValues(alpha: 0.15 + _pulseCtrl.value * 0.12),
                          blurRadius: 14)],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('🛰️', style: TextStyle(fontSize: 18)),
                        const SizedBox(width: 8),
                        Text('Start Level 5',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: mobile ? 14 : 15,
                            )),
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

// ════════════════════════════════════════════════════════════════════════════
//  SMALL SHARED WIDGETS
// ════════════════════════════════════════════════════════════════════════════
class _IconBtn extends StatelessWidget {
  final IconData     icon;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.onTap});
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

class _BlinkingCursor extends StatefulWidget {
  final Color color;
  const _BlinkingCursor({required this.color});
  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 530))..repeat(reverse: true);
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _ctrl,
    child: Container(
      width: 7, height: 14,
      decoration: BoxDecoration(
        color: widget.color,
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );
}