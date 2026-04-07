import 'dart:async';
import 'dart:math' as math;
import 'package:ecoquest/game/level4/air_pollution_game_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  AIR & NOISE POLLUTION SCREEN  —  Level 4 Introduction
//  Pure Flutter. Zero Flame. Zero image assets.
//  Receives carry-over values from Level 3 and forwards them to
//  AirPollutionGameScreen via Level3CarryOver.
// ══════════════════════════════════════════════════════════════════════════════

/// Carry-over data from Level 3 (Solid Waste Management).
class Level3CarryOver {
  final int ecoPoints;
  final int ecoCreativity;
  final int craftedCount;
  final int itemsSorted;
  final int categoriesUsed;

  const Level3CarryOver({
    this.ecoPoints     = 0,
    this.ecoCreativity = 0,
    this.craftedCount  = 0,
    this.itemsSorted   = 0,
    this.categoriesUsed = 0,
  });
}

class AirNoiseCityScreen extends StatefulWidget {
  final Level3CarryOver carryOver;

  const AirNoiseCityScreen({
    super.key,
    this.carryOver = const Level3CarryOver(),
  });

  @override
  State<AirNoiseCityScreen> createState() => _AirNoiseCityScreenState();
}

class _AirNoiseCityScreenState extends State<AirNoiseCityScreen>
    with TickerProviderStateMixin {

  // ── Animation controllers ──────────────────────────────────────────────────
  late final AnimationController _bgCtrl;
  late final AnimationController _entryCtrl;
  late final AnimationController _staggerCtrl;
  late final AnimationController _pulseCtrl;
  late final AnimationController _shimmerCtrl;
  late final AnimationController _smokeCtrl;
  late final AnimationController _cityCtrl;

  late final Animation<double> _fadeAnim;
  late final Animation<Offset>  _titleSlide;
  late final Animation<double>  _titleScale;

  // ── Palette ────────────────────────────────────────────────────────────────
  static const Color _bgDeep       = Color(0xFF080C14);
  static const Color _panel        = Color(0xFF0C1424);
  static const Color _panelAlt     = Color(0xFF0E1828);
  static const Color _smogGray     = Color(0xFF90A4AE);
  static const Color _toxicOrange  = Color(0xFFFF6D00);
  static const Color _acidGreen    = Color(0xFF69F0AE);
  static const Color _noiseRed     = Color(0xFFEF5350);
  static const Color _calmBlue     = Color(0xFF29B6F6);
  static const Color _sulfurPurple = Color(0xFFCE93D8);
  static const Color _amber        = Color(0xFFFFB300);

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

    _smokeCtrl = AnimationController(vsync: this,
        duration: const Duration(seconds: 8))..repeat();

    _cityCtrl = AnimationController(vsync: this,
        duration: const Duration(seconds: 10))..repeat(reverse: true);

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
    _smokeCtrl.dispose();
    _cityCtrl.dispose();
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
            AirPollutionGameScreen(carryOver: widget.carryOver),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeIn),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
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

          // Animated smog / industrial background
          _AnimatedSmogBackground(
            bgCtrl:    _bgCtrl,
            cityCtrl:  _cityCtrl,
            smokeCtrl: _smokeCtrl,
          ),

          // Floating smog particles
          _SmogParticles(ctrl: _smokeCtrl, size: size),

          // Main scrollable content
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                    horizontal: hPad,
                    vertical:   mobile ? 16 : 22),
                child: Column(children: [

                  // Level badge + title
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

                  // Threat banner
                  _ThreatBanner(pulse: _pulseCtrl, mobile: mobile),

                  SizedBox(height: mobile ? 22 : 28),

                  // Mission phases
                  _MissionPhases(stagger: _staggerCtrl, mobile: mobile),

                  SizedBox(height: mobile ? 22 : 28),

                  // Carry-over from Level 3
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

          // Floating action bar (pinned bottom)
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
//  ANIMATED SMOG / INDUSTRIAL BACKGROUND
// ════════════════════════════════════════════════════════════════════════════
class _AnimatedSmogBackground extends StatelessWidget {
  final AnimationController bgCtrl;
  final AnimationController cityCtrl;
  final AnimationController smokeCtrl;

  const _AnimatedSmogBackground({
    required this.bgCtrl,
    required this.cityCtrl,
    required this.smokeCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([bgCtrl, cityCtrl, smokeCtrl]),
      builder: (_, __) => SizedBox.expand(
        child: CustomPaint(
          painter: _SmogCityPainter(
            bgT:    bgCtrl.value,
            cityT:  cityCtrl.value,
            smokeT: smokeCtrl.value,
          ),
        ),
      ),
    );
  }
}

class _SmogCityPainter extends CustomPainter {
  final double bgT, cityT, smokeT;
  const _SmogCityPainter({
    required this.bgT,
    required this.cityT,
    required this.smokeT,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Sky gradient — heavy smog cycling between dark purple-grey and orange haze
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(const Color(0xFF080C14),
                const Color(0xFF100818), bgT * 0.4)!,
            Color.lerp(const Color(0xFF0C1018),
                const Color(0xFF1A0C08), bgT * 0.5)!,
            Color.lerp(const Color(0xFF0C1220),
                const Color(0xFF1E0E04), bgT * 0.6)!,
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    // Heavy smog / haze layer
    canvas.drawRect(
      Rect.fromLTWH(0, h * 0.20, w, h * 0.60),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            const Color(0xFF607D8B).withValues(alpha: 0.08 + bgT * 0.10),
            const Color(0xFFFF6D00).withValues(alpha: 0.06 + bgT * 0.08),
            Colors.transparent,
          ],
          stops: const [0.0, 0.35, 0.60, 1.0],
        ).createShader(Rect.fromLTWH(0, h * 0.20, w, h * 0.60)),
    );

    // Back skyline (factory silhouettes)
    _drawIndustrialSkyline(canvas, w, h,
        baseY: h * 0.60, color: const Color(0xFF080E18),
        count: 14, maxH: h * 0.28, seed: 42);

    // Front skyline with chimneys
    _drawIndustrialSkyline(canvas, w, h,
        baseY: h * 0.72, color: const Color(0xFF050B12),
        count: 10, maxH: h * 0.24, seed: 77, withChimneys: true);

    // Ground strip
    canvas.drawRect(Rect.fromLTWH(0, h * 0.78, w, h * 0.22),
        Paint()..color = const Color(0xFF060A10));

    // Smoke plumes from chimneys
    _drawSmokePlumes(canvas, w, h, t: smokeT);
  }

  void _drawIndustrialSkyline(Canvas canvas, double w, double h, {
    required double baseY, required Color color,
    required int count,    required double maxH,
    required int seed,     bool withChimneys = false,
  }) {
    final rng = math.Random(seed);
    double x = -w * 0.04;
    for (int i = 0; i < count; i++) {
      final bw = w * (0.04 + rng.nextDouble() * 0.08);
      final bh = maxH * (0.3 + rng.nextDouble() * 0.7);
      final by = baseY - bh;
      canvas.drawRect(Rect.fromLTWH(x, by, bw, bh + 2),
          Paint()..color = color);

      // Dim industrial windows
      final wRows = (bh / 14).floor().clamp(2, 8);
      final wCols = (bw / 12).floor().clamp(1, 3);
      for (int r = 0; r < wRows; r++) {
        for (int c = 0; c < wCols; c++) {
          if (rng.nextDouble() > 0.55) {
            final wx = x + 4 + c * (bw - 8) / wCols.clamp(1, 3);
            final wy = by + 6 + r * (bh - 8) / wRows.clamp(1, 8);
            canvas.drawRect(Rect.fromLTWH(wx, wy, 4, 4),
                Paint()..color = const Color(0xFFFF8C00)
                    .withValues(alpha: 0.10 + rng.nextDouble() * 0.12));
          }
        }
      }

      // Chimney stack
      if (withChimneys && rng.nextDouble() > 0.4) {
        final cx = x + bw * (0.2 + rng.nextDouble() * 0.6);
        canvas.drawRect(Rect.fromLTWH(cx - 5, by - 22, 10, 24),
            Paint()..color = const Color(0xFF0A0E14));
        canvas.drawRect(Rect.fromLTWH(cx - 7, by - 24, 14, 4),
            Paint()..color = const Color(0xFF0E1218));
      }

      x += bw + rng.nextDouble() * w * 0.02;
    }
  }

  void _drawSmokePlumes(Canvas canvas, double w, double h, {required double t}) {
    const stacks = [
      (0.11, 0.72), (0.27, 0.68), (0.50, 0.71),
      (0.68, 0.69), (0.87, 0.72),
    ];
    for (final (sx, sy) in stacks) {
      for (int i = 0; i < 5; i++) {
        final offset = (t + i * 0.20) % 1.0;
        final plumeY = h * sy - offset * h * 0.38;
        final alpha  = (0.22 * (1.0 - offset * 1.3)).clamp(0.0, 0.22);
        final radius = (10.0 + offset * 30) * (1 + i * 0.12);
        canvas.drawCircle(
          Offset(w * sx + math.sin(offset * math.pi * 2) * 7, plumeY),
          radius,
          Paint()
            ..color = const Color(0xFF607D8B).withValues(alpha: alpha)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_SmogCityPainter old) =>
      old.bgT != bgT || old.cityT != cityT || old.smokeT != smokeT;
}

// ════════════════════════════════════════════════════════════════════════════
//  SMOG / CHEMICAL PARTICLES
// ════════════════════════════════════════════════════════════════════════════
class _SmogParticles extends StatelessWidget {
  final AnimationController ctrl;
  final Size size;
  const _SmogParticles({required this.ctrl, required this.size});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ctrl,
      builder: (_, __) => CustomPaint(
          size: size, painter: _SmogParticlePainter(t: ctrl.value)),
    );
  }
}

class _SmogParticlePainter extends CustomPainter {
  final double t;
  const _SmogParticlePainter({required this.t});

  static final List<_SmokeP> _ps = List.generate(42, (i) {
    final r = math.Random(i * 31 + 7);
    return _SmokeP(
      x: r.nextDouble(), yStart: 0.45 + r.nextDouble() * 0.55,
      speed: 0.010 + r.nextDouble() * 0.028,
      radius: 1.8 + r.nextDouble() * 5.5,
      drift: (r.nextDouble() - 0.5) * 0.007,
      phase: r.nextDouble(),
      color: [
        const Color(0xFF607D8B),
        const Color(0xFF78909C),
        const Color(0xFFFF6D00),
        const Color(0xFFCE93D8),
        const Color(0xFFFFB300),
      ][r.nextInt(5)],
    );
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in _ps) {
      final progress = ((t + p.phase) % 1.0);
      final y = size.height * (p.yStart - progress * p.speed * 18);
      if (y < -10) continue;
      final x = size.width * (p.x + math.sin(progress * math.pi * 2) * p.drift * 6);
      final alpha = (1.0 - progress * 1.35).clamp(0.0, 0.30);
      canvas.drawCircle(Offset(x, y), p.radius,
          Paint()..color = p.color.withValues(alpha: alpha));
    }
  }

  @override
  bool shouldRepaint(_SmogParticlePainter old) => old.t != t;
}

class _SmokeP {
  final double x, yStart, speed, radius, drift, phase;
  final Color color;
  const _SmokeP({
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
            color: _AirNoiseCityScreenState._toxicOrange
                .withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _AirNoiseCityScreenState._toxicOrange
                  .withValues(alpha: 0.45 + shimmer.value * 0.20),
            ),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 7, height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _AirNoiseCityScreenState._toxicOrange
                    .withValues(alpha: 0.7 + pulse.value * 0.3),
                boxShadow: [BoxShadow(
                  color: _AirNoiseCityScreenState._toxicOrange
                      .withValues(alpha: 0.5),
                  blurRadius: 6,
                )],
              ),
            ),
            const SizedBox(width: 8),
            Text('LEVEL  4',
                style: TextStyle(
                  color: _AirNoiseCityScreenState._toxicOrange,
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
            Color.lerp(Colors.white, _AirNoiseCityScreenState._smogGray,
                shimmer.value * 0.30)!,
            const Color(0xFFFFFFFF),
          ], stops: const [0.0, 0.5, 1.0]).createShader(bounds),
          child: Text(
            'Air & Noise\nPollution',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: mobile ? 34 : 44,
              fontWeight: FontWeight.w900,
              height: 1.15,
              letterSpacing: -0.5,
            ),
          ),
        ),

        const SizedBox(height: 12),

        Text(
          'The city chokes under smog and deafening noise.\nRestore clean air and peaceful streets.',
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
          color: _AirNoiseCityScreenState._noiseRed.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: _AirNoiseCityScreenState._noiseRed
                  .withValues(alpha: 0.20 + pulse.value * 0.12)),
          boxShadow: [BoxShadow(
              color: _AirNoiseCityScreenState._noiseRed
                  .withValues(alpha: 0.06),
              blurRadius: 18, spreadRadius: 1)],
        ),
        child: Row(children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: _AirNoiseCityScreenState._noiseRed
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: _AirNoiseCityScreenState._noiseRed
                      .withValues(alpha: 0.30 + pulse.value * 0.20)),
              boxShadow: [BoxShadow(
                  color: _AirNoiseCityScreenState._noiseRed
                      .withValues(alpha: 0.15 + pulse.value * 0.15),
                  blurRadius: 12)],
            ),
            child: const Center(
                child: Text('☠️', style: TextStyle(fontSize: 18))),
          ),
          const SizedBox(width: 13),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('CRITICAL THREAT LEVEL',
                  style: TextStyle(
                    color: _AirNoiseCityScreenState._noiseRed,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.8,
                  )),
              const SizedBox(height: 3),
              Text(
                'Toxic gas clouds blanket the city. Noise levels are '
                'dangerously high. NPCs are struggling to breathe.',
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
    _Phase('🛩️', 'Navigate the Smog',
        'Pilot your eco-glider through the haze-filled atmosphere above the industrial city.',
        _AirNoiseCityScreenState._smogGray,    '01'),
    _Phase('🏹', 'Neutralize Pollutants',
        'Shoot catalytic arrows at labeled gas bubbles. Match your arrow type to each chemical formula.',
        _AirNoiseCityScreenState._toxicOrange, '02'),
    _Phase('🔊', 'Identify Noise Hotspots',
        'Use the sound analyzer to map noise sources — traffic, construction, loudspeakers, bare roads.',
        _AirNoiseCityScreenState._noiseRed,    '03'),
    _Phase('🌿', 'Restore Quiet',
        'Deploy the correct intervention at each hotspot to bring the city Noise Meter below 40 dB.',
        _AirNoiseCityScreenState._acidGreen,   '04'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Row(children: [
        Container(width: 3, height: 16,
            color: _AirNoiseCityScreenState._toxicOrange,
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
            color: _AirNoiseCityScreenState._toxicOrange,
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
        color: _AirNoiseCityScreenState._panelAlt,
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
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
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
                      color: phase.color,
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
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
//  CARRY-OVER PANEL  (Level 3 resources loaded into Level 4)
// ════════════════════════════════════════════════════════════════════════════
class _CarryOverPanel extends StatelessWidget {
  final AnimationController stagger;
  final AnimationController shimmer;
  final Level3CarryOver    carryOver;
  final bool               mobile;

  const _CarryOverPanel({
    required this.stagger, required this.shimmer,
    required this.carryOver, required this.mobile,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      _StatItem('⭐', 'Eco-Points',    '${carryOver.ecoPoints}',
          _AirNoiseCityScreenState._amber),
      _StatItem('⚡', 'Creativity XP', '${carryOver.ecoCreativity}',
          _AirNoiseCityScreenState._acidGreen),
      _StatItem('🔨', 'Items Crafted', '${carryOver.craftedCount}',
          _AirNoiseCityScreenState._calmBlue),
      _StatItem('🗑️', 'Waste Sorted', '${carryOver.itemsSorted}',
          _AirNoiseCityScreenState._smogGray),
      _StatItem('♻️', 'Categories',   '${carryOver.categoriesUsed}/5',
          _AirNoiseCityScreenState._sulfurPurple),
    ];

    return AnimatedBuilder(
      animation: shimmer,
      builder: (_, __) => Container(
        padding: EdgeInsets.all(mobile ? 14 : 18),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            const Color(0xFF0C1424),
            Color.lerp(const Color(0xFF0C1424),
                const Color(0xFF0E1A10), shimmer.value * 0.4)!,
          ], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: _AirNoiseCityScreenState._acidGreen
                  .withValues(alpha: 0.18 + shimmer.value * 0.12)),
          boxShadow: [BoxShadow(
              color: _AirNoiseCityScreenState._acidGreen
                  .withValues(alpha: 0.05),
              blurRadius: 18, spreadRadius: 1)],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // Header row
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: _AirNoiseCityScreenState._acidGreen
                    .withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: _AirNoiseCityScreenState._acidGreen
                    .withValues(alpha: 0.30)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Text('✅', style: TextStyle(fontSize: 11)),
                const SizedBox(width: 5),
                Text('LEVEL 3 CARRY-OVER',
                    style: TextStyle(
                      color: _AirNoiseCityScreenState._acidGreen,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    )),
              ]),
            ),
            const Spacer(),
            Text('Loaded into Level 4',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.30),
                  fontSize: 10,
                )),
          ]),

          const SizedBox(height: 14),

          // Stat rows
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
              fontSize: 12,
              fontWeight: FontWeight.w500,
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
                fontWeight: FontWeight.w800,
                fontSize: 13,
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
  final bool          mobile;
  final double        hPad;
  final VoidCallback  onStart;
  final VoidCallback  onControls;

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
              _AirNoiseCityScreenState._bgDeep.withValues(alpha: 0.0),
              _AirNoiseCityScreenState._bgDeep.withValues(alpha: 0.82),
              _AirNoiseCityScreenState._bgDeep,
            ],
            stops: const [0.0, 0.38, 1.0],
          ),
        ),
        padding: EdgeInsets.fromLTRB(
          hPad, 18, hPad,
          MediaQuery.of(context).padding.bottom + (mobile ? 18 : 22),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _StartButton(
            pulse: pulse, shimmer: shimmer,
            mobile: mobile, onTap: onStart,
          ),
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
  final AnimationController pulse;
  final AnimationController shimmer;
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
              Color.lerp(const Color(0xFF1A0A00),
                  const Color(0xFF2E1800), shimmer.value)!,
              Color.lerp(const Color(0xFF2E1800),
                  const Color(0xFF3D2200), shimmer.value)!,
              Color.lerp(const Color(0xFF2E1800),
                  const Color(0xFF1A0A00), shimmer.value)!,
            ]),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: _AirNoiseCityScreenState._toxicOrange
                    .withValues(alpha: 0.40 + pulse.value * 0.25),
                width: 1.5),
            boxShadow: [
              BoxShadow(
                  color: _AirNoiseCityScreenState._toxicOrange
                      .withValues(alpha: 0.22 + pulse.value * 0.18),
                  blurRadius: 24, offset: const Offset(0, 4)),
              BoxShadow(
                  color: _AirNoiseCityScreenState._toxicOrange
                      .withValues(alpha: 0.08 + pulse.value * 0.06),
                  blurRadius: 40, spreadRadius: 2),
            ],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Text('🛩️', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Text('START LEVEL 4',
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
    required this.onTap, required this.pulse,
    required this.mobile,
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
          color: _AirNoiseCityScreenState._calmBlue
              .withValues(alpha: 0.10 + p * 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _AirNoiseCityScreenState._calmBlue
                .withValues(alpha: 0.50 + p * 0.25),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: _AirNoiseCityScreenState._calmBlue
                  .withValues(alpha: 0.14 + p * 0.16),
              blurRadius: 18, offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon,
              color: _AirNoiseCityScreenState._calmBlue
                  .withValues(alpha: 0.85 + p * 0.15),
              size: mobile ? 17 : 18),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(
                color: _AirNoiseCityScreenState._calmBlue
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
  final Level3CarryOver carryOver;
  const _ControlsScreen({required this.carryOver});
  @override
  State<_ControlsScreen> createState() => _ControlsScreenState();
}

class _ControlsScreenState extends State<_ControlsScreen>
    with SingleTickerProviderStateMixin {

  final ScrollController _scrollCtrl = ScrollController();
  late final AnimationController _pulseCtrl;

  static const List<String> _sections = [
    '🛩️ PHASE 1 — NAVIGATE THE SMOG',
    'Pilot your eco-glider through smog-filled skies above the industrial city. '
    'Move in all four directions to position yourself near floating gas bubbles.',
    '',
    '▶  Tap ⬆ UP / ⬇ DOWN / ◀ LEFT / ▶ RIGHT to steer the glider.',
    '▶  Desktop: W/↑ A/← S/↓ D/→ or Arrow keys.',
    '▶  Mobile: Tilt device — tilt bar shows live direction.',
    '▶  Stay within the atmosphere zone — avoid the screen edges!',
    '',
    '🏹 PHASE 2 — NEUTRALIZE POLLUTANTS',
    'Gas bubbles float labeled with chemical formulas. '
    'Each needs the correct catalytic arrow to neutralize it and earn by-products.',
    '',
    '▶  Select arrow type from the weapon tray at the bottom.',
    '▶  H₂ Arrow   → Targets CO and CO₂ (grey / dark-grey bubbles).',
    '▶  NH₃ Arrow  → Targets NO and NO₂ (purple / orange bubbles).',
    '▶  CaCO₃ Arrow → Targets SO₂ (yellow bubbles).',
    '▶  Tap 🎯 FIRE or press Space to shoot.',
    '▶  Correct hit = +10 pts  |  Wrong arrow = −5 pts.',
    '▶  By-products stored: methanol · gypsum · urea · nitrates.',
    '',
    '🔊 PHASE 3 — IDENTIFY NOISE HOTSPOTS',
    'The air is clean but the city is deafeningly loud. Use the '
    'sound analyzer to locate noise sources on the city map.',
    '',
    '▶  Tap 🔍 SCAN to activate the Sound Analyzer.',
    '▶  Pulsing red rings mark active noise hotspots.',
    '▶  Tap a hotspot to read its noise type and dB reading.',
    '▶  Noise Level Meter (top) shows overall city noise in dB.',
    '',
    '🌿 PHASE 4 — RESTORE QUIET',
    'Navigate the eco-drone to each hotspot and apply the '
    'correct intervention. Match the tool to the noise type!',
    '',
    '▶  Vehicle Honking    → Upgrade to Electric / Install Mufflers.',
    '▶  Construction Sites → Silent Machinery / Restrict Hours.',
    '▶  Loudspeakers       → Silent Zone Marker / Awareness Campaign.',
    '▶  Sparse Vegetation  → Plant Tree Line / Green Barrier.',
    '▶  Correct = +15 pts  |  Incorrect or ignored = −10 pts.',
    '▶  Reach below 40 dB to unlock the "Peaceful City" badge!',
    '',
    '⭐  Breathe clean, live quiet — Good luck, Eco-Hero! 🌍',
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
          AirPollutionGameScreen(carryOver: widget.carryOver),
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
      if (line.startsWith('🛩️') || line.startsWith('🏹') ||
          line.startsWith('🔊') || line.startsWith('🌿') ||
          line.startsWith('⭐')) {
        spans.add(TextSpan(text: '$line\n', style: TextStyle(
          color: _AirNoiseCityScreenState._toxicOrange,
          fontSize: 13.5, fontWeight: FontWeight.w900,
          height: 2.0, letterSpacing: 0.4,
        )));
      } else if (line.startsWith('▶') || line.startsWith('   ')) {
        spans.add(TextSpan(text: '$line\n', style: TextStyle(
          color: _AirNoiseCityScreenState._calmBlue,
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
        backgroundColor: _AirNoiseCityScreenState._bgDeep,
        body: SafeArea(child: Column(children: [

          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: _AirNoiseCityScreenState._panel,
              border: Border(bottom: BorderSide(
                  color: _AirNoiseCityScreenState._calmBlue
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

          // Typewriter body
          Expanded(child: SingleChildScrollView(
            controller: _scrollCtrl,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.07)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(text: TextSpan(
                    style: const TextStyle(
                        fontFamily: 'monospace', fontSize: 12,
                        height: 1.75),
                    children: _buildStyledSpans(_displayedText),
                  )),
                  if (!_typingDone)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: _BlinkingCursor(
                          color: _AirNoiseCityScreenState._calmBlue),
                    ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          )),

          // Bottom action bar
          AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (_, __) => Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              decoration: BoxDecoration(
                color: _AirNoiseCityScreenState._panel,
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
                        Color.lerp(const Color(0xFF1A0A00),
                            const Color(0xFF2E1800), _pulseCtrl.value)!,
                        Color.lerp(const Color(0xFF2E1800),
                            const Color(0xFF3D2200), _pulseCtrl.value)!,
                      ]),
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(
                          color: _AirNoiseCityScreenState._toxicOrange
                              .withValues(alpha: 0.35 + _pulseCtrl.value * 0.20)),
                      boxShadow: [BoxShadow(
                          color: _AirNoiseCityScreenState._toxicOrange
                              .withValues(alpha: 0.15 + _pulseCtrl.value * 0.12),
                          blurRadius: 14)],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('🛩️', style: TextStyle(fontSize: 18)),
                        const SizedBox(width: 8),
                        Text('Start Level 4',
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