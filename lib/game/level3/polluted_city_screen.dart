import 'dart:async';
import 'dart:math' as math;
import 'package:ecoquest/game/level3/city_collection_screen.dart';
import 'package:ecoquest/game/level3/sorting_facility_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  POLLUTED CITY SCREEN  —  Level 3 Introduction
//  Pure Flutter. Zero Flame. Zero image assets.
//  Receives carry-over values from Level 2 and forwards them to
//  CityCollectionScreen via WaterLevelCarryOver.
// ══════════════════════════════════════════════════════════════════════════════

class PollutedCityScreen extends StatefulWidget {
  final int recycledPlastic;
  final int recycledMetal;
  final int bacteriaCultures;
  final int ecoPoints;
  final int fishCount;
  final int cropYield;
  final String cropType;
  final int purifiedWater;
  final int recycledOrganic;

  const PollutedCityScreen({
    super.key,
    required this.recycledPlastic,
    required this.recycledMetal,
    required this.bacteriaCultures,
    required this.ecoPoints,
    required this.fishCount,
    required this.cropYield,
    required this.cropType,
    required this.purifiedWater,
    required this.recycledOrganic,
  });

  @override
  State<PollutedCityScreen> createState() => _PollutedCityScreenState();
}

class _PollutedCityScreenState extends State<PollutedCityScreen>
    with TickerProviderStateMixin {

  // ── Animation controllers ─────────────────────────────────────────────────
  late final AnimationController _bgCtrl;
  late final AnimationController _entryCtrl;
  late final AnimationController _staggerCtrl;
  late final AnimationController _pulseCtrl;
  late final AnimationController _shimmerCtrl;
  late final AnimationController _particleCtrl;
  late final AnimationController _cityCtrl;

  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _titleSlide;
  late final Animation<double> _titleScale;

  // ── Palette ───────────────────────────────────────────────────────────────
  static const Color _bgDeep   = Color(0xFF020A14);
  static const Color _panel    = Color(0xFF0C1525);
  static const Color _panelAlt = Color(0xFF0E1C2E);
  static const Color _amber    = Color(0xFFFFB300);
  static const Color _teal     = Color(0xFF00BCD4);
  static const Color _lime     = Color(0xFF76FF03);
  static const Color _orange   = Color(0xFFFF6D00);
  static const Color _blue     = Color(0xFF1E88E5);
  static const Color _red      = Color(0xFFE53935);

  // ── State ─────────────────────────────────────────────────────────────────
  void _openControls(BuildContext context) {
    HapticFeedback.selectionClick();
    final carryOver = WaterLevelCarryOver(
      plastic:       widget.recycledPlastic,
      metal:         widget.recycledMetal,
      organic:       widget.recycledOrganic,
      hazardous:     0,
      ecoPoints:     widget.ecoPoints,
      purifiedWater: widget.purifiedWater,
      fishCount:     widget.fishCount,
    );
    Navigator.of(context).push(PageRouteBuilder(
      pageBuilder: (_, anim, __) => _ControlsScreen(carryOver: carryOver),
      transitionsBuilder: (_, anim, __, child) => SlideTransition(
        position: Tween<Offset>(
                begin: const Offset(0, 1), end: Offset.zero)
            .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: child,
      ),
      transitionDuration: const Duration(milliseconds: 420),
    ));
  }

  @override
  void initState() {
    super.initState();

    _bgCtrl = AnimationController(vsync: this,
        duration: const Duration(seconds: 10))..repeat(reverse: true);

    _entryCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 900))..forward();

    _staggerCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 1400))..forward();

    _pulseCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 1600))..repeat(reverse: true);

    _shimmerCtrl = AnimationController(vsync: this,
        duration: const Duration(seconds: 2))..repeat(reverse: true);

    _particleCtrl = AnimationController(vsync: this,
        duration: const Duration(seconds: 6))..repeat();

    _cityCtrl = AnimationController(vsync: this,
        duration: const Duration(seconds: 8))..repeat(reverse: true);

    _fadeAnim = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeIn);

    _titleSlide = Tween<Offset>(
            begin: const Offset(0, -0.15), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));

    _titleScale = Tween<double>(begin: 0.88, end: 1.0)
        .animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.elasticOut));
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _entryCtrl.dispose();
    _staggerCtrl.dispose();
    _pulseCtrl.dispose();
    _shimmerCtrl.dispose();
    _particleCtrl.dispose();
    _cityCtrl.dispose();
    super.dispose();
  }

  void _startLevel(BuildContext context) {
    HapticFeedback.heavyImpact();
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, anim, __) => CityCollectionScreen(
          waterCarryOver: WaterLevelCarryOver(
            plastic:       widget.recycledPlastic,
            metal:         widget.recycledMetal,
            organic:       widget.recycledOrganic,
            hazardous:     0,
            ecoPoints:     widget.ecoPoints,
            purifiedWater: widget.purifiedWater,
            fishCount:     widget.fishCount,
          ),
        ),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeIn),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────
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

          // ── Animated deep-city background ─────────────────────────────
          _AnimatedCityBackground(
            bgCtrl:   _bgCtrl,
            cityCtrl: _cityCtrl,
          ),

          // ── Floating pollution particles ──────────────────────────────
          _PollutionParticles(ctrl: _particleCtrl, size: size),

          // ── Main content ──────────────────────────────────────────────
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                    horizontal: hPad, vertical: mobile ? 16 : 22),
                child: Column(children: [

                  // ── LEVEL BADGE + TITLE ──────────────────────────────
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

                  // ── CITY THREAT BANNER ───────────────────────────────
                  _ThreatBanner(pulse: _pulseCtrl, mobile: mobile),

                  SizedBox(height: mobile ? 22 : 28),

                  // ── MISSION PHASES (staggered) ───────────────────────
                  _MissionPhases(
                    stagger: _staggerCtrl,
                    mobile:  mobile,
                  ),

                  SizedBox(height: mobile ? 22 : 28),

                  // ── CARRY-OVER FROM LEVEL 2 ──────────────────────────
                  _CarryOverPanel(
                    stagger:          _staggerCtrl,
                    shimmer:          _shimmerCtrl,
                    ecoPoints:        widget.ecoPoints,
                    recycledPlastic:  widget.recycledPlastic,
                    recycledMetal:    widget.recycledMetal,
                    recycledOrganic:  widget.recycledOrganic,
                    purifiedWater:    widget.purifiedWater,
                    fishCount:        widget.fishCount,
                    cropYield:        widget.cropYield,
                    cropType:         widget.cropType,
                    mobile:           mobile,
                  ),

                  // Bottom padding so content clears the floating button bar
                  SizedBox(height: mobile ? 100 : 110),
                ]),
              ),
            ),
          ),
          // ── Floating action bar (pinned at bottom) ────────────────────
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: _FloatingActionBar(
              pulse:   _pulseCtrl,
              shimmer: _shimmerCtrl,
              mobile:  mobile,
              hPad:    hPad,
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
//  ANIMATED CITY BACKGROUND
// ════════════════════════════════════════════════════════════════════════════
class _AnimatedCityBackground extends StatelessWidget {
  final AnimationController bgCtrl;
  final AnimationController cityCtrl;
  const _AnimatedCityBackground({required this.bgCtrl, required this.cityCtrl});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([bgCtrl, cityCtrl]),
      builder: (_, __) {
        return SizedBox.expand(
          child: CustomPaint(
            painter: _CityPainter(
              bgT:   bgCtrl.value,
              cityT: cityCtrl.value,
            ),
          ),
        );
      },
    );
  }
}

class _CityPainter extends CustomPainter {
  final double bgT;
  final double cityT;
  const _CityPainter({required this.bgT, required this.cityT});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // ── Sky gradient (shifts between polluted orange-red and dark blue)
    final skyPaint = Paint();
    final skyGrad = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color.lerp(
            const Color(0xFF020A14), const Color(0xFF0D1A0D), bgT * 0.3)!,
        Color.lerp(
            const Color(0xFF070D1A), const Color(0xFF1A0D05), bgT * 0.4)!,
        Color.lerp(
            const Color(0xFF0C1525), const Color(0xFF200A00), bgT * 0.5)!,
      ],
      stops: const [0.0, 0.55, 1.0],
    );
    skyPaint.shader =
        skyGrad.createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), skyPaint);

    // ── Smog / haze layer near horizon
    final smogPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          Color(0xFFFF6D00).withValues(alpha: 0.04 + bgT * 0.06),
          Color(0xFFFF6D00).withValues(alpha: 0.08 + bgT * 0.08),
          Colors.transparent,
        ],
        stops: const [0.0, 0.45, 0.65, 1.0],
      ).createShader(Rect.fromLTWH(0, h * 0.3, w, h * 0.5));
    canvas.drawRect(
        Rect.fromLTWH(0, h * 0.3, w, h * 0.5), smogPaint);

    // ── City skyline (back layer — far buildings)
    _drawBuildings(canvas, w, h,
        baseY: h * 0.62,
        buildingColor: const Color(0xFF0A1822),
        windowColor: const Color(0xFFFFB300),
        count: 18,
        maxH: h * 0.30,
        minW: w * 0.04,
        maxW: w * 0.075,
        seed: 77,
        windowAlpha: 0.18 + bgT * 0.1);

    // ── City skyline (front layer — near buildings, darker)
    _drawBuildings(canvas, w, h,
        baseY: h * 0.75,
        buildingColor: const Color(0xFF050D14),
        windowColor: const Color(0xFFFFB300),
        count: 12,
        maxH: h * 0.28,
        minW: w * 0.055,
        maxW: w * 0.10,
        seed: 42,
        windowAlpha: 0.25 + bgT * 0.12);

    // ── Ground / road strip
    final groundPaint = Paint()
      ..color = const Color(0xFF060C12);
    canvas.drawRect(
        Rect.fromLTWH(0, h * 0.80, w, h * 0.20), groundPaint);

    // ── Road lane lines
    final lanePaint = Paint()
      ..color = const Color(0xFF1C2E45).withValues(alpha: 0.6)
      ..strokeWidth = 2;
    canvas.drawLine(Offset(0, h * 0.83), Offset(w, h * 0.83), lanePaint);
    canvas.drawLine(Offset(0, h * 0.90), Offset(w, h * 0.90), lanePaint);

    // ── Dashed centre line (animated)
    final dashPaint = Paint()
      ..color = const Color(0xFFFFB300).withValues(alpha: 0.22)
      ..strokeWidth = 1.5;
    final dashLen  = w * 0.06;
    final gap      = w * 0.04;
    final offset   = (cityT * (dashLen + gap)) % (dashLen + gap);
    double x = -offset;
    while (x < w) {
      canvas.drawLine(
          Offset(x, h * 0.865),
          Offset(x + dashLen, h * 0.865),
          dashPaint);
      x += dashLen + gap;
    }

    // ── Smog clouds near tops of buildings
    _drawSmogClouds(canvas, w, h, t: bgT);
  }

  void _drawBuildings(
    Canvas canvas, double w, double h, {
    required double baseY,
    required Color buildingColor,
    required Color windowColor,
    required int count,
    required double maxH,
    required double minW,
    required double maxW,
    required int seed,
    required double windowAlpha,
  }) {
    final rng  = math.Random(seed);
    double x   = -maxW * 0.5;
    for (int i = 0; i < count; i++) {
      final bw = minW + rng.nextDouble() * (maxW - minW);
      final bh = maxH * (0.3 + rng.nextDouble() * 0.7);
      final by = baseY - bh;

      final buildPaint = Paint()..color = buildingColor;
      canvas.drawRect(Rect.fromLTWH(x, by, bw, bh + 2), buildPaint);

      // Windows
      final wRows = (bh / 18).floor().clamp(2, 12);
      final wCols = (bw / 14).floor().clamp(1, 4);
      for (int r = 0; r < wRows; r++) {
        for (int c = 0; c < wCols; c++) {
          if (rng.nextDouble() > 0.45) {
            final wx = x + 5 + c * (bw - 10) / wCols.clamp(1, 4);
            final wy = by + 8 + r * (bh - 10) / wRows.clamp(1, 12);
            final winPaint = Paint()
              ..color = windowColor.withValues(alpha: windowAlpha * rng.nextDouble());
            canvas.drawRect(
                Rect.fromLTWH(wx, wy, 5, 5), winPaint);
          }
        }
      }

      x += bw + rng.nextDouble() * maxW * 0.3;
    }
  }

  void _drawSmogClouds(Canvas canvas, double w, double h, {required double t}) {
    final clouds = [
      (0.1, 0.38, 0.18), (0.35, 0.33, 0.20), (0.6, 0.36, 0.15),
      (0.8, 0.31, 0.22), (0.5, 0.28, 0.16),
    ];
    for (final (cx, cy, r) in clouds) {
      final paint = Paint()
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28)
        ..color = const Color(0xFFFF6D00)
            .withValues(alpha: 0.04 + t * 0.03);
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset(w * cx, h * cy),
              width:  w * r * 2.2,
              height: h * r * 0.5),
          paint);
    }
  }

  @override
  bool shouldRepaint(_CityPainter old) =>
      old.bgT != bgT || old.cityT != cityT;
}

// ════════════════════════════════════════════════════════════════════════════
//  POLLUTION PARTICLES
// ════════════════════════════════════════════════════════════════════════════
class _PollutionParticles extends StatelessWidget {
  final AnimationController ctrl;
  final Size size;
  const _PollutionParticles({required this.ctrl, required this.size});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ctrl,
      builder: (_, __) => CustomPaint(
        size: size,
        painter: _ParticlePainter(t: ctrl.value),
      ),
    );
  }
}

class _ParticlePainter extends CustomPainter {
  final double t;
  const _ParticlePainter({required this.t});

  static final List<_Particle> _particles = List.generate(32, (i) {
    final rng = math.Random(i * 17 + 3);
    return _Particle(
      x:     rng.nextDouble(),
      yStart: 0.6 + rng.nextDouble() * 0.4,
      speed:  0.015 + rng.nextDouble() * 0.04,
      radius: 1.5 + rng.nextDouble() * 3.5,
      drift:  (rng.nextDouble() - 0.5) * 0.008,
      phase:  rng.nextDouble(),
      color: [
        const Color(0xFFFF6D00),
        const Color(0xFFFFB300),
        const Color(0xFF4CAF50),
        const Color(0xFF78909C),
      ][rng.nextInt(4)],
    );
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in _particles) {
      final progress = ((t + p.phase) % 1.0);
      final y = size.height * (p.yStart - progress * p.speed * 20);
      if (y < -10) continue;
      final x = size.width * (p.x + math.sin(progress * math.pi * 2) * p.drift * 8);
      final alpha = (1.0 - progress * 1.2).clamp(0.0, 0.35);
      canvas.drawCircle(
        Offset(x, y),
        p.radius,
        Paint()..color = p.color.withValues(alpha: alpha),
      );
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => old.t != t;
}

class _Particle {
  final double x, yStart, speed, radius, drift, phase;
  final Color color;
  const _Particle({
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
  const _TitleSection({required this.shimmer, required this.pulse, required this.mobile});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([shimmer, pulse]),
      builder: (_, __) {
        return Column(children: [

          // ── Level badge ──────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: _PollutedCityScreenState._orange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _PollutedCityScreenState._orange
                    .withValues(alpha: 0.45 + shimmer.value * 0.2),
              ),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 7, height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _PollutedCityScreenState._orange
                      .withValues(alpha: 0.7 + pulse.value * 0.3),
                  boxShadow: [BoxShadow(
                    color: _PollutedCityScreenState._orange
                        .withValues(alpha: 0.5),
                    blurRadius: 6,
                  )],
                ),
              ),
              const SizedBox(width: 8),
              Text('LEVEL  3',
                  style: TextStyle(
                    color: _PollutedCityScreenState._orange,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 3.0,
                  )),
            ]),
          ),

          const SizedBox(height: 14),

          // ── Main title ───────────────────────────────────────────────
          ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: [
                const Color(0xFFFFFFFF),
                Color.lerp(Colors.white,
                    _PollutedCityScreenState._orange, shimmer.value * 0.25)!,
                const Color(0xFFFFFFFF),
              ],
              stops: [0.0, 0.5, 1.0],
            ).createShader(bounds),
            child: Text(
              'Solid Waste\nCrisis',
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

          // ── Subtitle ─────────────────────────────────────────────────
          Text(
            'The city is drowning in waste.\nYour eco-mission begins now.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: mobile ? 12 : 13,
              height: 1.55,
              letterSpacing: 0.2,
            ),
          ),
        ]);
      },
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
      builder: (_, __) {
        return Container(
          padding: EdgeInsets.symmetric(
              horizontal: mobile ? 14 : 18, vertical: 13),
          decoration: BoxDecoration(
            color: _PollutedCityScreenState._red.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: _PollutedCityScreenState._red
                    .withValues(alpha: 0.2 + pulse.value * 0.12)),
            boxShadow: [BoxShadow(
                color: _PollutedCityScreenState._red.withValues(alpha: 0.06),
                blurRadius: 18, spreadRadius: 1)],
          ),
          child: Row(children: [
            // Pulsing alert icon
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: _PollutedCityScreenState._red.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: _PollutedCityScreenState._red
                        .withValues(alpha: 0.3 + pulse.value * 0.2)),
                boxShadow: [BoxShadow(
                    color: _PollutedCityScreenState._red
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
                Text('CRITICAL THREAT LEVEL',
                    style: TextStyle(
                      color: _PollutedCityScreenState._red,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.8,
                    )),
                const SizedBox(height: 3),
                Text(
                  'Toxic waste is spreading across EcoCity. '
                  'Air quality is dangerously low. Pipes are failing.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: mobile ? 11 : 12,
                    height: 1.4,
                  ),
                ),
              ],
            )),
          ]),
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  MISSION PHASES
// ════════════════════════════════════════════════════════════════════════════
class _MissionPhases extends StatelessWidget {
  final AnimationController stagger;
  final bool mobile;
  const _MissionPhases({required this.stagger, required this.mobile});

  static const _phases = [
    _Phase('🚛', 'Collect Waste',
        'Drive your eco-truck through the city streets and collect all waste items before time runs out.',
        _PollutedCityScreenState._amber,   '01'),
    _Phase('🔧', 'Repair Pipes',
        'Find and fix broken, leaking and loose pipes throughout the city to stop toxic contamination.',
        _PollutedCityScreenState._teal,    '02'),
    _Phase('♻️', 'Sort Recyclables',
        'Bring the collected waste to the sorting facility and correctly classify every item by category.',
        _PollutedCityScreenState._lime,    '03'),
    _Phase('🔨', 'Craft & Upcycle',
        'Transform sorted materials into useful products in the crafting workshop and earn Eco-Creativity XP.',
        _PollutedCityScreenState._blue,    '04'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // ── Section header
      Row(children: [
        Container(width: 3, height: 16,
            color: _PollutedCityScreenState._amber,
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
            color: _PollutedCityScreenState._amber, fontSize: 11,
            fontWeight: FontWeight.w600)),
      ]),
      const SizedBox(height: 12),

      // ── Phase cards (staggered)
      AnimatedBuilder(
        animation: stagger,
        builder: (_, __) {
          return Column(
            children: _phases.asMap().entries.map((e) {
              final delay = e.key * 0.12;
              final raw = ((stagger.value - delay) / (1.0 - delay))
                  .clamp(0.0, 1.0);
              final t = Curves.easeOutBack.transform(raw).clamp(0.0, 1.0);
              return Opacity(
                opacity: t,
                child: Transform.translate(
                  offset: Offset(22 * (1 - t), 0),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: _PhaseCard(
                        phase: e.value, mobile: mobile),
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    ]);
  }
}

class _Phase {
  final String emoji, label, desc;
  final Color color;
  final String num;
  const _Phase(this.emoji, this.label, this.desc, this.color, this.num);
}

class _PhaseCard extends StatelessWidget {
  final _Phase phase;
  final bool mobile;
  const _PhaseCard({required this.phase, required this.mobile});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(mobile ? 12 : 14),
      decoration: BoxDecoration(
        color: _PollutedCityScreenState._panelAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: phase.color.withValues(alpha: 0.22)),
        boxShadow: [BoxShadow(
            color: phase.color.withValues(alpha: 0.05),
            blurRadius: 12, spreadRadius: 1)],
      ),
      child: Row(children: [

        // Phase number + emoji block
        Container(
          width: mobile ? 52 : 60,
          height: mobile ? 52 : 60,
          decoration: BoxDecoration(
            color: phase.color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: phase.color.withValues(alpha: 0.32)),
          ),
          child: Stack(children: [
            Center(child: Text(phase.emoji,
                style: TextStyle(fontSize: mobile ? 22 : 26))),
            Positioned(
              right: 4, bottom: 4,
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
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
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
//  CARRY-OVER PANEL
// ════════════════════════════════════════════════════════════════════════════
class _CarryOverPanel extends StatelessWidget {
  final AnimationController stagger;
  final AnimationController shimmer;
  final int ecoPoints, recycledPlastic, recycledMetal, recycledOrganic;
  final int purifiedWater, fishCount, cropYield;
  final String cropType;
  final bool mobile;

  const _CarryOverPanel({
    required this.stagger, required this.shimmer,
    required this.ecoPoints, required this.recycledPlastic,
    required this.recycledMetal, required this.recycledOrganic,
    required this.purifiedWater, required this.fishCount,
    required this.cropYield, required this.cropType,
    required this.mobile,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      _StatItem('⭐', 'Eco-Points',    '$ecoPoints',        _PollutedCityScreenState._amber),
      _StatItem('🧴', 'Plastic',       '+$recycledPlastic', _PollutedCityScreenState._blue),
      _StatItem('🔩', 'Metal',         '+$recycledMetal',   const Color(0xFF78909C)),
      _StatItem('🍃', 'Organic',       '+$recycledOrganic', _PollutedCityScreenState._lime),
      _StatItem('💧', 'Pure Water',    '${purifiedWater}L', _PollutedCityScreenState._teal),
      _StatItem('🐟', 'Fish Saved',    '$fishCount',        const Color(0xFF4FC3F7)),
    ];

    return AnimatedBuilder(
      animation: shimmer,
      builder: (_, __) {
        return Container(
          padding: EdgeInsets.all(mobile ? 14 : 18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF0C1525),
                Color.lerp(const Color(0xFF0C1525),
                    const Color(0xFF0E1F10), shimmer.value * 0.4)!,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: _PollutedCityScreenState._lime
                    .withValues(alpha: 0.18 + shimmer.value * 0.12)),
            boxShadow: [BoxShadow(
                color: _PollutedCityScreenState._lime.withValues(alpha: 0.05),
                blurRadius: 18, spreadRadius: 1)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // Header
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: _PollutedCityScreenState._lime.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(
                        color: _PollutedCityScreenState._lime
                            .withValues(alpha: 0.3)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('✅',
                        style: const TextStyle(fontSize: 11)),
                    const SizedBox(width: 5),
                    Text('LEVEL 2 CARRY-OVER',
                        style: TextStyle(
                          color: _PollutedCityScreenState._lime,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        )),
                  ]),
                ),
                const Spacer(),
                Text('Loaded into Level 3',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.3),
                      fontSize: 10,
                    )),
              ]),

              const SizedBox(height: 14),

              // Stats list — one row per category
              ...items.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _StatRow(stat: s),
              )),

              if (cropYield > 0) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 11, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
                  ),
                  child: Row(children: [
                    const Text('🌾', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 8),
                    Text('$cropType harvest: ',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 11,
                        )),
                    Text('$cropYield units',
                        style: TextStyle(
                          color: _PollutedCityScreenState._amber,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        )),
                  ]),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _StatItem {
  final String emoji, label, value;
  final Color color;
  const _StatItem(this.emoji, this.label, this.value, this.color);
}

// ════════════════════════════════════════════════════════════════════════════
//  CARRY-OVER STAT ROW  (list-style row for each category)
// ════════════════════════════════════════════════════════════════════════════
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
        // Emoji icon container
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: stat.color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: stat.color.withValues(alpha: 0.25)),
          ),
          child: Center(
            child: Text(stat.emoji, style: const TextStyle(fontSize: 15)),
          ),
        ),
        const SizedBox(width: 12),
        // Label
        Expanded(
          child: Text(stat.label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              )),
        ),
        // Value chip
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
//  START BUTTON
// ════════════════════════════════════════════════════════════════════════════
class _StartButton extends StatelessWidget {
  final AnimationController pulse;
  final AnimationController shimmer;
  final bool mobile;
  final VoidCallback onTap;

  const _StartButton({
    required this.pulse, required this.shimmer,
    required this.mobile, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([pulse, shimmer]),
      builder: (_, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [GestureDetector(
          onTap: onTap,
          child: Container(
            padding: EdgeInsets.symmetric(
                vertical: mobile ? 14 : 16, horizontal: mobile ? 22 : 30),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color.lerp(const Color(0xFF1B5E20),
                      const Color(0xFF2E7D32), shimmer.value)!,
                  Color.lerp(const Color(0xFF2E7D32),
                      const Color(0xFF43A047), shimmer.value)!,
                  Color.lerp(const Color(0xFF388E3C),
                      const Color(0xFF1B5E20), shimmer.value)!,
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: _PollutedCityScreenState._lime
                      .withValues(alpha: 0.22 + pulse.value * 0.18),
                  width: 1.5),
              boxShadow: [
                BoxShadow(
                    color: _PollutedCityScreenState._lime
                        .withValues(alpha: 0.18 + pulse.value * 0.18),
                    blurRadius: 24, offset: const Offset(0, 4)),
                BoxShadow(
                    color: _PollutedCityScreenState._lime
                        .withValues(alpha: 0.08 + pulse.value * 0.06),
                    blurRadius: 40, spreadRadius: 2),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('🚛', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 12),
                Text('START LEVEL 3',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: mobile ? 16 : 18,
                      letterSpacing: 1.4,
                    )),
                const SizedBox(width: 12),
                Icon(Icons.arrow_forward_rounded,
                    color: Colors.white
                        .withValues(alpha: 0.7 + pulse.value * 0.3),
                    size: 22),
              ],
            ),
          ),
        )],);
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  FLOATING ACTION BAR  (pinned to screen bottom on main screen)
// ════════════════════════════════════════════════════════════════════════════
class _FloatingActionBar extends StatelessWidget {
  final AnimationController pulse;
  final AnimationController shimmer;
  final bool mobile;
  final double hPad;
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
      builder: (_, __) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                _PollutedCityScreenState._bgDeep.withValues(alpha: 0.0),
                _PollutedCityScreenState._bgDeep.withValues(alpha: 0.82),
                _PollutedCityScreenState._bgDeep,
              ],
              stops: const [0.0, 0.38, 1.0],
            ),
          ),
          padding: EdgeInsets.fromLTRB(
            hPad, 18, hPad,
            MediaQuery.of(context).padding.bottom + (mobile ? 18 : 22),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [

              // ── Start Level ──────────────────────────────────────────
              _StartButton(
                pulse:   pulse,
                shimmer: shimmer,
                mobile:  mobile,
                onTap:   onStart,
              ),

              SizedBox(width: mobile ? 10 : 14),

              // ── View Controls (conspicuous teal) ──────────────────────
              _SecondaryBtn(
                icon:    Icons.gamepad_rounded,
                label:   'View Controls',
                pulse:   pulse,
                onTap:   onControls,
                mobile:  mobile,
              ),
            ],
          ),
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  SECONDARY BUTTON  (Controls toggle — conspicuous teal)
// ════════════════════════════════════════════════════════════════════════════
class _SecondaryBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final AnimationController pulse;
  final bool mobile;

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
          horizontal: mobile ? 18 : 24,
        ),
        decoration: BoxDecoration(
          color: _PollutedCityScreenState._teal.withValues(alpha: 0.10 + p * 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _PollutedCityScreenState._teal
                .withValues(alpha: 0.50 + p * 0.25),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: _PollutedCityScreenState._teal
                  .withValues(alpha: 0.14 + p * 0.16),
              blurRadius: 18, offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: _PollutedCityScreenState._teal
                  .withValues(alpha: 0.06 + p * 0.08),
              blurRadius: 32, spreadRadius: 2,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                color: _PollutedCityScreenState._teal
                    .withValues(alpha: 0.85 + p * 0.15),
                size: mobile ? 17 : 18),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                  color: _PollutedCityScreenState._teal
                      .withValues(alpha: 0.90 + p * 0.10),
                  fontWeight: FontWeight.w700,
                  fontSize: mobile ? 13 : 14,
                  letterSpacing: 0.4,
                )),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  CONTROLS SCREEN — text-first with typewriter animation
//  Layout:
//    • Header bar (back + skip)
//    • Scrolling typewriter phase guide (fills available space)
//    • Bottom bar: [🎮 Live Demo] [🚛 Start Game]  — always visible
// ════════════════════════════════════════════════════════════════════════════
class _ControlsScreen extends StatefulWidget {
  final WaterLevelCarryOver carryOver;
  const _ControlsScreen({required this.carryOver});
  @override
  State<_ControlsScreen> createState() => _ControlsScreenState();
}

class _ControlsScreenState extends State<_ControlsScreen>
    with SingleTickerProviderStateMixin {

  // ── Typewriter ───────────────────────────────────────────────────────────
  final ScrollController _scrollCtrl = ScrollController();
  late final AnimationController _pulseCtrl; // for bottom-bar glow

  static const List<String> _sections = [
    '🚛 PHASE 1 — WASTE COLLECTION',
    'Drive your eco-truck through the city streets collecting all waste items '
    'before the timer runs out. Steer left and right to stay in your lane and '
    'brake to avoid collisions with oncoming traffic.',
    '',
    '▶  Tap ⬆ GO to accelerate forward.',
    '▶  Tap ◀ / ▶ to steer left or right.',
    '▶  Tap ■ BRK to slow down or stop.',
    '▶  Tap ⬇ REV to reverse when needed.',
    '▶  Desktop: W/↑ A/← S/↓ D/→ or Arrow Keys. Space also brakes.',
    '▶  Hold W+A or W+D to lane-switch while moving.',
    '▶  Mobile: tilt the device — the tilt bar shows live steering direction.',
    '',
    '🔧 PHASE 2 — SEWER REPAIR',
    'After collection the truck enters sewer-repair mode. Drive close to broken '
    'or leaking pipes and a repair prompt appears automatically.',
    '',
    '▶  Tap 🧰 TOOLBOX to open your repair tools.',
    '▶  Select the correct tool for each leak type:',
    '   🔧 Wrench       → loose joints',
    '   📏 Plumbing Tape → joint leaks',
    '   🪛 Pliers        → cracked sections',
    '   🛡️ Sealant       → multiple leak types',
    '▶  Desktop: press T to open the toolbox.',
    '',
    '♻️ PHASE 3 — SORTING FACILITY',
    'Your collected waste arrives at the sorting facility. Drag each item to its '
    'matching category bin. Accuracy earns more eco-points.',
    '',
    '▶  A progress bar shows how many items remain.',
    '▶  Correct sorts award points; wrong bins deduct them.',
    '▶  Sort quickly — a 2-minute timer counts down.',
    '',
    '🔨 PHASE 4 — CRAFTING WORKSHOP',
    'Sorted materials unlock crafting recipes. Each recipe costs a set number of '
    'items from that category. Crafting awards Eco-Creativity XP on top of your '
    'Eco-Points total.',
    '',
    '▶  Check your bin count before crafting.',
    '▶  Tap CRAFT on any recipe you have enough materials for.',
    '▶  Tap FINISH SESSION to see your Level 3 results.',
    '',
    '⭐  Good luck, Eco-Hero! 🌍',
  ];

  String _displayedText = '';
  int _secIdx = 0, _charIdx = 0;
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
    _typeTimer = Timer.periodic(const Duration(milliseconds: 20), (t) {
      if (!mounted) { t.cancel(); return; }
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
          setState(() { _displayedText += '\n\n'; _secIdx++; _charIdx = 0; });
        }
      } else {
        setState(() => _typingDone = true);
        t.cancel();
      }
    });
  }

  void _startGame(BuildContext context) {
    HapticFeedback.heavyImpact();
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      pageBuilder: (_, anim, __) =>
          CityCollectionScreen(waterCarryOver: widget.carryOver),
      transitionsBuilder: (_, anim, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeIn),
          child: child),
      transitionDuration: const Duration(milliseconds: 500),
    ));
  }

  void _openLiveDemo(BuildContext context) {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(PageRouteBuilder(
      pageBuilder: (_, anim, __) =>
          _LiveDemoScreen(carryOver: widget.carryOver),
      transitionsBuilder: (_, anim, __, child) => SlideTransition(
        position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
            .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: child,
      ),
      transitionDuration: const Duration(milliseconds: 380),
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
      if (line.startsWith('🚛') || line.startsWith('🔧') ||
          line.startsWith('♻️') || line.startsWith('🔨') ||
          line.startsWith('⭐')) {
        spans.add(TextSpan(text: '$line\n', style: TextStyle(
          color: _PollutedCityScreenState._amber,
          fontSize: 13.5, fontWeight: FontWeight.w900,
          height: 2.0, letterSpacing: 0.4,
        )));
      } else if (line.startsWith('▶') || line.startsWith('   ')) {
        spans.add(TextSpan(text: '$line\n', style: TextStyle(
          color: _PollutedCityScreenState._teal,
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
        backgroundColor: _PollutedCityScreenState._bgDeep,
        body: SafeArea(
          child: Column(children: [

            // ── Header ──────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: _PollutedCityScreenState._panel,
                border: Border(bottom: BorderSide(
                    color: _PollutedCityScreenState._teal
                        .withValues(alpha: 0.16))),
              ),
              child: Row(children: [
                _IconBtn(
                  icon: Icons.arrow_back_rounded,
                  onTap: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text('🎮  Game Controls',
                    style: TextStyle(color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: mobile ? 15 : 16))),
              ]),
            ),

            // ── Scrolling typewriter area ────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
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
                              color: _PollutedCityScreenState._teal),
                        ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),

            // ── Bottom action bar ───────────────────────────────────────
            AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (_, __) => Container(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                decoration: BoxDecoration(
                  color: _PollutedCityScreenState._panel,
                  border: Border(top: BorderSide(
                      color: Colors.white.withValues(alpha: 0.07))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.max,
                  children: [

                  // Live Demo button
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: mobile ? 110 : 130,
                      maxWidth: MediaQuery.of(context).size.width * 0.42,
                    ),
                    child: GestureDetector(
                    onTap: () => _openLiveDemo(context),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: mobile ? 14 : 18,
                      ),
                      decoration: BoxDecoration(
                        color: _PollutedCityScreenState._teal
                            .withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: _PollutedCityScreenState._teal
                                .withValues(alpha: 0.28 +
                                    _pulseCtrl.value * 0.10)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.gamepad_outlined,
                              color: _PollutedCityScreenState._teal, size: 15),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text('Live Demo',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: _PollutedCityScreenState._teal,
                                  fontWeight: FontWeight.w700,
                                  fontSize: mobile ? 12 : 13,
                                )),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.arrow_forward_ios_rounded,
                              color: _PollutedCityScreenState._teal
                                  .withValues(alpha: 0.6),
                              size: 10),
                        ],
                      ),
                    ),
                  )),

                  const SizedBox(width: 10),

                  // Start Game button
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: mobile ? 110 : 130,
                      maxWidth: MediaQuery.of(context).size.width * 0.42,
                    ),
                    child: GestureDetector(
                    onTap: () => _startGame(context),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: mobile ? 14 : 18,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                          Color.lerp(const Color(0xFF1B5E20),
                              const Color(0xFF2E7D32), _pulseCtrl.value)!,
                          Color.lerp(const Color(0xFF2E7D32),
                              const Color(0xFF388E3C), _pulseCtrl.value)!,
                        ]),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: _PollutedCityScreenState._lime
                                .withValues(alpha: 0.22 +
                                    _pulseCtrl.value * 0.18)),
                        boxShadow: [BoxShadow(
                            color: _PollutedCityScreenState._lime
                                .withValues(alpha: 0.12 +
                                    _pulseCtrl.value * 0.10),
                            blurRadius: 14)],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('🚛', style: TextStyle(fontSize: 15)),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text('Start Game',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: mobile ? 12 : 13,
                                )),
                          ),
                        ],
                      ),
                    ),
                  )),

                ]),
              ),
            ),

          ]),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  LIVE DEMO SCREEN  — animated key visual + Start Game
//  Slides in from the right when tapped from _ControlsScreen
// ════════════════════════════════════════════════════════════════════════════
class _LiveDemoScreen extends StatefulWidget {
  final WaterLevelCarryOver carryOver;
  const _LiveDemoScreen({required this.carryOver});
  @override
  State<_LiveDemoScreen> createState() => _LiveDemoScreenState();
}

class _LiveDemoScreenState extends State<_LiveDemoScreen>
    with TickerProviderStateMixin {

  late final AnimationController _pulseCtrl;
  late final AnimationController _floatCtrl;
  late final AnimationController _demoCtrl;
  int _activeKey = 0;

  static const int _demoSteps = 6;
  static const List<Duration> _stepDur = [
    Duration(milliseconds: 700),
    Duration(milliseconds: 600),
    Duration(milliseconds: 600),
    Duration(milliseconds: 500),
    Duration(milliseconds: 600),
    Duration(milliseconds: 450),
  ];

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 1400))..repeat(reverse: true);
    _floatCtrl = AnimationController(vsync: this,
        duration: const Duration(seconds: 3))..repeat(reverse: true);
    _demoCtrl = AnimationController(vsync: this, duration: _stepDur[0])
      ..addStatusListener(_onDemoStep)
      ..forward();
  }

  void _onDemoStep(AnimationStatus s) {
    if (s == AnimationStatus.completed && mounted) {
      setState(() => _activeKey = (_activeKey + 1) % _demoSteps);
      _demoCtrl.duration = _stepDur[_activeKey];
      _demoCtrl.forward(from: 0);
    }
  }

  void _startGame(BuildContext context) {
    HapticFeedback.heavyImpact();
    // Pop both this and the controls screen, then push game
    Navigator.of(context).popUntil((route) => route.isFirst);
    Navigator.of(context).push(PageRouteBuilder(
      pageBuilder: (_, anim, __) =>
          CityCollectionScreen(waterCarryOver: widget.carryOver),
      transitionsBuilder: (_, anim, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeIn),
          child: child),
      transitionDuration: const Duration(milliseconds: 500),
    ));
  }

  @override
  void dispose() {
    _demoCtrl.dispose();
    _pulseCtrl.dispose();
    _floatCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.of(context).size.width < 640;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _PollutedCityScreenState._bgDeep,
        body: SafeArea(
          child: Column(children: [

            // ── Header ──────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: _PollutedCityScreenState._panel,
                border: Border(bottom: BorderSide(
                    color: _PollutedCityScreenState._teal
                        .withValues(alpha: 0.16))),
              ),
              child: Row(children: [
                _IconBtn(
                  icon: Icons.arrow_back_rounded,
                  onTap: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text('🕹️  Live Controls Demo',
                    style: TextStyle(color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: mobile ? 15 : 16))),
                // Animated badge
                AnimatedBuilder(
                  animation: _floatCtrl,
                  builder: (_, __) => Transform.translate(
                    offset: Offset(0, _floatCtrl.value * -2),
                    child: AnimatedBuilder(
                      animation: _pulseCtrl,
                      builder: (_, __) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _PollutedCityScreenState._amber
                              .withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(7),
                          border: Border.all(
                              color: _PollutedCityScreenState._amber
                                  .withValues(alpha: 0.25 +
                                      _pulseCtrl.value * 0.20)),
                        ),
                        child: Text('● LIVE',
                            style: TextStyle(
                              color: _PollutedCityScreenState._amber,
                              fontSize: 9, fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            )),
                      ),
                    ),
                  ),
                ),
              ]),
            ),

            // ── Animated demo (fills space) ──────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(14),
                child: AnimatedBuilder(
                  animation: Listenable.merge([_pulseCtrl, _floatCtrl]),
                  builder: (_, __) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      // ── MOBILE section ─────────────────────────────────
                      _DemoSectionCard(
                        title: '📱  Mobile Touch Controls',
                        titleColor: _PollutedCityScreenState._teal,
                        pulse: _pulseCtrl.value,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [

                                // LEFT: steer + reverse
                                Column(mainAxisSize: MainAxisSize.min, children: [
                                  Row(mainAxisSize: MainAxisSize.min, children: [
                                    _AnimKey(label: '◀', sub: 'Steer L',
                                        color: Colors.cyanAccent,
                                        lit: _activeKey == 1,
                                        pulse: _pulseCtrl.value),
                                    const SizedBox(width: 6),
                                    _AnimKey(label: '▶', sub: 'Steer R',
                                        color: Colors.cyanAccent,
                                        lit: _activeKey == 2,
                                        pulse: _pulseCtrl.value),
                                  ]),
                                  const SizedBox(height: 6),
                                  _AnimKey(label: '⬇ REV', sub: 'Reverse',
                                      color: Colors.purpleAccent,
                                      lit: _activeKey == 4,
                                      pulse: _pulseCtrl.value, wide: true),
                                ]),

                                // CENTRE: tilt + toolbox
                                Column(mainAxisSize: MainAxisSize.min, children: [
                                  Transform.translate(
                                    offset: Offset(0, _floatCtrl.value * -4),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 7),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.04),
                                        borderRadius: BorderRadius.circular(9),
                                        border: Border.all(
                                            color: Colors.white.withValues(alpha: 0.09)),
                                      ),
                                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                                        Text('📱 Tilt to steer',
                                            style: TextStyle(color: Colors.white
                                                .withValues(alpha: 0.45), fontSize: 9)),
                                        const SizedBox(height: 5),
                                        _TiltBarDemo(pulse: _pulseCtrl.value),
                                      ]),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 9, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withValues(
                                          alpha: _activeKey == 5 ? 0.18 : 0.07),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.orange.withValues(
                                          alpha: _activeKey == 5 ? 0.55 : 0.18)),
                                    ),
                                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                                      const Text('🧰', style: TextStyle(fontSize: 13)),
                                      const SizedBox(width: 4),
                                      Text('TOOLBOX',
                                          style: TextStyle(
                                            color: Colors.orange.withValues(
                                                alpha: _activeKey == 5 ? 1.0 : 0.55),
                                            fontSize: 9,
                                            fontWeight: FontWeight.w800,
                                          )),
                                    ]),
                                  ),
                                  Text('(sewer phase)',
                                      style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.22),
                                          fontSize: 8)),
                                ]),

                                // RIGHT: drive + brake
                                Column(mainAxisSize: MainAxisSize.min, children: [
                                  _AnimKey(label: '⬆ GO', sub: 'Drive',
                                      color: Colors.green,
                                      lit: _activeKey == 0,
                                      pulse: _pulseCtrl.value),
                                  const SizedBox(height: 6),
                                  _AnimKey(label: '■ BRK', sub: 'Brake',
                                      color: Colors.redAccent,
                                      lit: _activeKey == 3,
                                      pulse: _pulseCtrl.value),
                                ]),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // ── DESKTOP section ────────────────────────────────
                      _DemoSectionCard(
                        title: '⌨️  Desktop Keyboard Controls',
                        titleColor: _PollutedCityScreenState._amber,
                        pulse: _pulseCtrl.value,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(height: 12),
                            Center(child: _AnimKey(
                                label: 'W / ↑', sub: 'Drive',
                                color: Colors.green, lit: _activeKey == 0,
                                pulse: _pulseCtrl.value)),
                            const SizedBox(height: 4),
                            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                              _AnimKey(label: 'A / ←', sub: 'Left',
                                  color: Colors.cyanAccent, lit: _activeKey == 1,
                                  pulse: _pulseCtrl.value),
                              const SizedBox(width: 4),
                              _AnimKey(label: 'S / ↓', sub: 'Brake',
                                  color: Colors.redAccent, lit: _activeKey == 3,
                                  pulse: _pulseCtrl.value),
                              const SizedBox(width: 4),
                              _AnimKey(label: 'D / →', sub: 'Right',
                                  color: Colors.cyanAccent, lit: _activeKey == 2,
                                  pulse: _pulseCtrl.value),
                            ]),
                            const SizedBox(height: 4),
                            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                              _AnimKey(label: 'R', sub: 'Reverse',
                                  color: Colors.purpleAccent, lit: _activeKey == 4,
                                  pulse: _pulseCtrl.value),
                              const SizedBox(width: 4),
                              _AnimKey(label: 'Space', sub: 'Brake',
                                  color: Colors.redAccent, lit: _activeKey == 3,
                                  pulse: _pulseCtrl.value, wide: true),
                              const SizedBox(width: 4),
                              _AnimKey(label: 'T', sub: 'Toolbox',
                                  color: Colors.orange, lit: _activeKey == 5,
                                  pulse: _pulseCtrl.value),
                            ]),
                            const SizedBox(height: 10),
                            Text('Hold W+A or W+D for lane switching',
                                style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.25),
                                    fontSize: 9)),
                          ],
                        ),
                      ),

                      const SizedBox(height: 6),
                    ],
                  ),
                ),
              ),
            ),

            // ── Start Game footer ────────────────────────────────────────
            AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (_, __) => Container(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                decoration: BoxDecoration(
                  color: _PollutedCityScreenState._panel,
                  border: Border(top: BorderSide(
                      color: Colors.white.withValues(alpha: 0.07))),
                ),
                child: GestureDetector(
                  onTap: () => _startGame(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        Color.lerp(const Color(0xFF1B5E20),
                            const Color(0xFF2E7D32), _pulseCtrl.value)!,
                        Color.lerp(const Color(0xFF2E7D32),
                            const Color(0xFF388E3C), _pulseCtrl.value)!,
                      ]),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: _PollutedCityScreenState._lime
                              .withValues(alpha: 0.22 + _pulseCtrl.value * 0.18)),
                      boxShadow: [BoxShadow(
                          color: _PollutedCityScreenState._lime
                              .withValues(alpha: 0.14 + _pulseCtrl.value * 0.12),
                          blurRadius: 18, offset: const Offset(0, 3))],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('🚛', style: TextStyle(fontSize: 20)),
                        const SizedBox(width: 10),
                        Text('Start Game Now',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              letterSpacing: 0.5,
                            )),
                        const SizedBox(width: 10),
                        Icon(Icons.arrow_forward_rounded,
                            color: Colors.white
                                .withValues(alpha: 0.6 + _pulseCtrl.value * 0.4),
                            size: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          ]),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  DEMO SECTION CARD  (titled container used in _LiveDemoScreen)
// ════════════════════════════════════════════════════════════════════════════
class _DemoSectionCard extends StatelessWidget {
  final String title;
  final Color  titleColor;
  final double pulse;
  final Widget child;
  const _DemoSectionCard({
    required this.title, required this.titleColor,
    required this.pulse, required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: _PollutedCityScreenState._panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: titleColor.withValues(alpha: 0.18 + pulse * 0.08)),
        boxShadow: [BoxShadow(
            color: titleColor.withValues(alpha: 0.05), blurRadius: 12)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            Container(width: 3, height: 14,
                color: titleColor, margin: const EdgeInsets.only(right: 8)),
            Text(title, style: TextStyle(
              color: titleColor,
              fontWeight: FontWeight.w800,
              fontSize: 12,
              letterSpacing: 0.3,
            )),
          ]),
          child,
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  SMALL REUSABLE WIDGETS
// ════════════════════════════════════════════════════════════════════════════

// Back / icon button used in both screen headers
class _IconBtn extends StatelessWidget {
  final IconData icon;
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

// ════════════════════════════════════════════════════════════════════════════
//  BLINKING CURSOR  (typewriter effect)
// ════════════════════════════════════════════════════════════════════════════
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

// ════════════════════════════════════════════════════════════════════════════
//  SHARED KEY WIDGETS
// ════════════════════════════════════════════════════════════════════════════
class _AnimKey extends StatelessWidget {
  final String label, sub;
  final Color  color;
  final bool   lit, wide;
  final double pulse;

  const _AnimKey({
    required this.label, required this.sub,
    required this.color, required this.lit,
    required this.pulse, this.wide = false,
  });

  @override
  Widget build(BuildContext context) {
    final glow = lit ? (0.18 + pulse * 0.22) : 0.0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: wide ? 88 : null,
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: lit
            ? color.withValues(alpha: 0.18 + pulse * 0.10)
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: lit ? color.withValues(alpha: 0.75) : Colors.white12,
            width: lit ? 1.4 : 1.0),
        boxShadow: lit ? [BoxShadow(
            color: color.withValues(alpha: glow),
            blurRadius: 12, spreadRadius: 1)] : [],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: lit ? color : Colors.white54,
              fontSize: 11, fontWeight: FontWeight.w800,
            )),
        const SizedBox(height: 2),
        Text(sub,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: lit
                  ? color.withValues(alpha: 0.7)
                  : Colors.white.withValues(alpha: 0.25),
              fontSize: 8,
            )),
      ]),
    );
  }
}

class _TiltBarDemo extends StatelessWidget {
  final double pulse;
  const _TiltBarDemo({required this.pulse});
  @override
  Widget build(BuildContext context) {
    const w = 70.0, h = 7.0;
    final tilt = math.sin(pulse * math.pi) * 0.55;
    final clamped = tilt.clamp(-1.0, 1.0);
    final fillW   = (clamped.abs() * (w / 2)).clamp(0.0, w / 2);
    final fillX   = clamped >= 0 ? w / 2 : w / 2 - fillW;
    final color   = tilt.abs() > 0.4 ? Colors.orangeAccent : Colors.cyanAccent;
    return SizedBox(width: w, height: h,
      child: Stack(children: [
        Container(width: w, height: h,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: Colors.white12),
            )),
        Positioned(left: w / 2 - 0.75, top: 0,
            child: Container(width: 1.5, height: h, color: Colors.white24)),
        Positioned(left: fillX, top: 1,
            child: Container(
              width: fillW, height: h - 2,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(2),
              ),
            )),
      ]),
    );
  }
}