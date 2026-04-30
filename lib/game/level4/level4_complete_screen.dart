import 'dart:math' as math;
import 'package:ecoquest/game/level4/air_noise_city_screen.dart';
import 'package:ecoquest/game/level4/air_pollution_game_screen.dart';
import 'package:ecoquest/game/level4/noise_pollution_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  LEVEL 4 COMPLETE SCREEN  —  Air & Noise Pollution final summary
//  Pure Flutter. Zero Flame. Zero image assets.
//  Reads AirPollutionResult.current & NoiseResult.current (static holders).
//  Features: confetti burst, animated grade badge, stat grid, Level 5 CTA.
// ══════════════════════════════════════════════════════════════════════════════

class Level4CompleteScreen extends StatefulWidget {
  final Level3CarryOver carryOver;

  const Level4CompleteScreen({super.key, required this.carryOver});

  @override
  State<Level4CompleteScreen> createState() => _Level4CompleteScreenState();
}

class _Level4CompleteScreenState extends State<Level4CompleteScreen>
    with TickerProviderStateMixin {

  // ── Animation controllers ─────────────────────────────────────────────────
  late final AnimationController _entryCtrl;
  late final AnimationController _burstCtrl;
  late final AnimationController _badgePulse;
  late final AnimationController _shimmerCtrl;
  late final AnimationController _staggerCtrl;
  late final AnimationController _bgCtrl;

  late final Animation<double> _scaleAnim;
  late final Animation<Offset> _slideAnim;
  late final Animation<double> _fadeAnim;

  // ── Colour constants ──────────────────────────────────────────────────────
  static const Color bgDeep        = Color(0xFF060C16);
  static const Color bgMid         = Color(0xFF0C1828);
  static const Color panel         = Color(0xFF0A1422);
  static const Color toxicOrange   = Color(0xFFFF6D00);
  static const Color calmBlue      = Color(0xFF29B6F6);
  static const Color acidGreen     = Color(0xFF69F0AE);
  static const Color gold          = Color(0xFFFFD700);

  // ── Derived data ──────────────────────────────────────────────────────────
  AirPollutionResult get _air =>
      AirPollutionResult.current ??
      const AirPollutionResult(
        pollutantsNeutralized: 0, wrongArrows: 0, ecoPoints: 0,
        methanol: 0, gypsum: 0, urea: 0, nitrates: 0,
      );

  NoiseResult get _noise =>
      NoiseResult.current ??
      const NoiseResult(
        hotspotsFix: 0, wrongTools: 0, ecoPoints: 0,
        noiseMeterFinal: 96, peacefulCityBadge: false, windEvades: 0, scanComboMax: 0,
      );

  int get _totalScore => _air.ecoPoints + _noise.ecoPoints;

  String get _grade {
    if (_totalScore >= 500) return 'S';
    if (_totalScore >= 350) return 'A';
    if (_totalScore >= 200) return 'B';
    if (_totalScore >= 100) return 'C';
    return 'D';
  }

  Color get _gradeColor {
    switch (_grade) {
      case 'S': return gold;
      case 'A': return acidGreen;
      case 'B': return calmBlue;
      case 'C': return Colors.orange;
      default:  return Colors.redAccent;
    }
  }

  bool get _airPerfect =>
      _air.pollutantsNeutralized >= 20;

  bool get _peacefulCity => _noise.peacefulCityBadge;

  @override
  void initState() {
    super.initState();
    HapticFeedback.heavyImpact();

    _entryCtrl  = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 950))..forward();
    _burstCtrl  = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 2600))..forward();
    _badgePulse = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 1800))..repeat(reverse: true);
    _shimmerCtrl = AnimationController(vsync: this,
        duration: const Duration(seconds: 2))..repeat(reverse: true);
    _staggerCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 1500))..forward();
    _bgCtrl     = AnimationController(vsync: this,
        duration: const Duration(seconds: 10))..repeat(reverse: true);

    _scaleAnim = Tween<double>(begin: 0.72, end: 1.0).animate(
        CurvedAnimation(parent: _entryCtrl, curve: Curves.elasticOut));
    _slideAnim = Tween<Offset>(
            begin: const Offset(0, 0.1), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _entryCtrl, curve: Curves.easeOutCubic));
    _fadeAnim = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeIn);
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _burstCtrl.dispose();
    _badgePulse.dispose();
    _shimmerCtrl.dispose();
    _staggerCtrl.dispose();
    _bgCtrl.dispose();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final size   = MediaQuery.of(context).size;
    final mobile = size.width < 640;
    final hPad   = size.width > 1000
        ? size.width * 0.18
        : mobile ? 16.0 : 32.0;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: bgDeep,
        body: Stack(children: [

          // Animated dark gradient background
          AnimatedBuilder(
            animation: _bgCtrl,
            builder: (_, __) => Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color.lerp(bgDeep, const Color(0xFF0A1A2E), _bgCtrl.value)!,
                    Color.lerp(bgMid,  const Color(0xFF0C1E10), _bgCtrl.value * 0.5)!,
                    Color.lerp(bgDeep, const Color(0xFF08100A), _bgCtrl.value * 0.3)!,
                  ],
                  stops: const [0.0, 0.55, 1.0],
                ),
              ),
            ),
          ),

          // Starfield
          const _L4StarField(),

          // Confetti burst
          _L4ConfettiBurst(ctrl: _burstCtrl, screenSize: size),

          // Scrollable content
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: ScaleTransition(
                  scale: _scaleAnim,
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                        horizontal: hPad, vertical: 22),
                    child: Column(children: [

                      _L4TrophyHeader(
                        badgePulse:   _badgePulse,
                        shimmer:      _shimmerCtrl,
                        totalScore:   _totalScore,
                        peacefulCity: _peacefulCity,
                        airPerfect:   _airPerfect,
                        mobile:       mobile,
                      ),

                      SizedBox(height: mobile ? 22 : 30),

                      _L4ScoreBanner(
                        totalScore: _totalScore,
                        grade:      _grade,
                        gradeColor: _gradeColor,
                        shimmer:    _shimmerCtrl,
                        mobile:     mobile,
                      ),

                      SizedBox(height: mobile ? 18 : 26),

                      _L4StatGrid(
                        stagger:    _staggerCtrl,
                        air:        _air,
                        noise:      _noise,
                        mobile:     mobile,
                      ),

                      SizedBox(height: mobile ? 18 : 26),

                      // Badges row
                      _L4BadgesRow(
                        peacefulCity: _peacefulCity,
                        airPerfect:   _airPerfect,
                        pulse:        _badgePulse,
                        mobile:       mobile,
                      ),

                      SizedBox(height: mobile ? 18 : 26),

                      _L4BadgeCard(
                        grade:      _grade,
                        gradeColor: _gradeColor,
                        pulse:      _badgePulse,
                        mobile:     mobile,
                      ),

                      SizedBox(height: mobile ? 22 : 30),

                      _L4ActionButtons(mobile: mobile),

                      const SizedBox(height: 24),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  STAR FIELD
// ══════════════════════════════════════════════════════════════════════════════
class _L4StarField extends StatelessWidget {
  const _L4StarField();
  @override
  Widget build(BuildContext context) => Positioned.fill(
    child: IgnorePointer(child: CustomPaint(painter: _L4StarPainter())),
  );
}

class _L4StarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rng   = math.Random(99);
    final paint = Paint();
    for (int i = 0; i < 80; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final r = rng.nextDouble() * 1.2 + 0.3;
      paint.color = Colors.white.withValues(
          alpha: rng.nextDouble() * 0.22 + 0.04);
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }
  @override bool shouldRepaint(_) => false;
}

// ══════════════════════════════════════════════════════════════════════════════
//  CONFETTI BURST  — orange / cyan / green themed
// ══════════════════════════════════════════════════════════════════════════════
class _L4ConfettiBurst extends StatelessWidget {
  final AnimationController ctrl;
  final Size screenSize;
  const _L4ConfettiBurst({required this.ctrl, required this.screenSize});

  static const _colors = [
    Color(0xFFFF6D00), Color(0xFF29B6F6), Color(0xFF69F0AE),
    Color(0xFFFFB300), Color(0xFFCE93D8), Color(0xFFFFFFFF),
    Color(0xFF00E5FF), Color(0xFF76FF03), Color(0xFFFF4081),
  ];

  @override
  Widget build(BuildContext context) => Positioned.fill(
    child: IgnorePointer(
      child: AnimatedBuilder(
        animation: ctrl,
        builder: (_, __) => CustomPaint(
          painter: _L4ConfettiPainter(t: ctrl.value, colors: _colors),
        ),
      ),
    ),
  );
}

class _L4ConfettiPainter extends CustomPainter {
  final double t;
  final List<Color> colors;
  static const _count = 72;
  const _L4ConfettiPainter({required this.t, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0) return;
    final opacity = t < 0.25
        ? t / 0.25
        : t < 0.65 ? 1.0
        : (1.0 - (t - 0.65) / 0.35).clamp(0.0, 1.0);
    if (opacity <= 0) return;

    final cx = size.width  / 2;
    final cy = size.height * 0.22;

    for (int i = 0; i < _count; i++) {
      final delay  = (i / _count) * 0.28;
      final pt     = ((t - delay) / (1.0 - delay)).clamp(0.0, 1.0);
      if (pt <= 0) continue;

      final angle  = (i * 137.508 % 360) * math.pi / 180;
      final radius = size.width * 0.50 * pt * (0.28 + (i % 8) * 0.09);
      final gravY  = size.height * 0.28 * pt * pt;
      final px     = cx + math.cos(angle) * radius;
      final py     = cy + math.sin(angle) * radius * 0.55 + gravY;
      final r      = (2.5 + (i % 6) * 2.2) * (1 - pt * 0.35);
      final col    = colors[i % colors.length].withValues(alpha: opacity * 0.88);
      final paint  = Paint()..color = col;

      switch (i % 3) {
        case 0:
          canvas.drawCircle(Offset(px, py), r, paint);
          break;
        case 1:
          final rot = angle + pt * math.pi * 5;
          canvas.save();
          canvas.translate(px, py);
          canvas.rotate(rot);
          canvas.drawRect(
              Rect.fromCenter(center: Offset.zero,
                  width: r * 2.2, height: r * 0.8),
              paint);
          canvas.restore();
          break;
        case 2:
          canvas.drawLine(
            Offset(px - math.cos(angle) * r, py - math.sin(angle) * r),
            Offset(px + math.cos(angle) * r, py + math.sin(angle) * r),
            Paint()
              ..color       = col
              ..strokeWidth = r * 0.55
              ..strokeCap   = StrokeCap.round,
          );
          break;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _L4ConfettiPainter o) => o.t != t;
}

// ══════════════════════════════════════════════════════════════════════════════
//  TROPHY HEADER
// ══════════════════════════════════════════════════════════════════════════════
class _L4TrophyHeader extends StatelessWidget {
  final AnimationController badgePulse, shimmer;
  final int   totalScore;
  final bool  peacefulCity, airPerfect, mobile;

  const _L4TrophyHeader({
    required this.badgePulse, required this.shimmer,
    required this.totalScore, required this.peacefulCity,
    required this.airPerfect, required this.mobile,
  });

  @override
  Widget build(BuildContext context) {
    return Column(children: [

      // Glowing trophy circle
      AnimatedBuilder(
        animation: badgePulse,
        builder: (_, __) {
          final glow = badgePulse.value;
          return Container(
            width:  mobile ? 106 : 130,
            height: mobile ? 106 : 130,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(colors: [
                Color(0xFF1A2A0A), Color(0xFF0A100A),
              ]),
              border: Border.all(
                color: Color.lerp(
                    _Level4CompleteScreenState.calmBlue,
                    _Level4CompleteScreenState.acidGreen,
                    glow)!.withValues(alpha: 0.72),
                width: 2.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Color.lerp(
                          _Level4CompleteScreenState.calmBlue,
                          _Level4CompleteScreenState.acidGreen, glow)!
                      .withValues(alpha: 0.28 + glow * 0.28),
                  blurRadius: 28 + glow * 22,
                  spreadRadius: 4 + glow * 3,
                ),
              ],
            ),
            child: Center(
                child: Text('🏆',
                    style: TextStyle(fontSize: mobile ? 48 : 60))),
          );
        },
      ),

      const SizedBox(height: 18),

      // LEVEL 4 COMPLETE — gradient text
      ShaderMask(
        shaderCallback: (bounds) => const LinearGradient(
          colors: [
            Color(0xFFFF6D00),
            Color(0xFF29B6F6),
            Color(0xFF69F0AE),
          ],
        ).createShader(bounds),
        child: Text(
          'LEVEL 4 COMPLETE',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: mobile ? 26 : 36,
            fontWeight: FontWeight.w900,
            letterSpacing: mobile ? 1.8 : 3.0,
          ),
        ),
      ),

      const SizedBox(height: 6),

      Text(
        '🌿  Air Purified & City Silenced — Mission Accomplished!',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white54,
          fontSize: mobile ? 12 : 14,
          letterSpacing: 0.3,
        ),
      ),

      const SizedBox(height: 18),

      // Total score pill
      AnimatedBuilder(
        animation: shimmer,
        builder: (_, __) => Container(
          padding: EdgeInsets.symmetric(
              horizontal: mobile ? 18 : 26, vertical: 9),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              Color.lerp(const Color(0xFF001A2E),
                  const Color(0xFF003050), shimmer.value)!,
              const Color(0xFF001E2A),
            ]),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
                color: _Level4CompleteScreenState.calmBlue
                    .withValues(alpha: 0.45), width: 1.5),
            boxShadow: [
              BoxShadow(
                  color: _Level4CompleteScreenState.calmBlue
                      .withValues(alpha: 0.12 + shimmer.value * 0.18),
                  blurRadius: 18),
            ],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Text('⚡', style: TextStyle(fontSize: 17)),
            const SizedBox(width: 9),
            Text('+$totalScore Total Eco-Points earned',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: mobile ? 12 : 14,
                )),
          ]),
        ),
      ),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  SCORE BANNER
// ══════════════════════════════════════════════════════════════════════════════
class _L4ScoreBanner extends StatelessWidget {
  final int   totalScore;
  final String grade;
  final Color  gradeColor;
  final AnimationController shimmer;
  final bool   mobile;

  const _L4ScoreBanner({
    required this.totalScore, required this.grade,
    required this.gradeColor, required this.shimmer,
    required this.mobile,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: shimmer,
      builder: (_, __) => Container(
        padding: EdgeInsets.symmetric(
            vertical: mobile ? 18 : 24, horizontal: mobile ? 20 : 32),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF0A1A2E),
              Color.lerp(const Color(0xFF0A1A2E),
                  const Color(0xFF0D2A14), shimmer.value)!,
              const Color(0xFF080E1A),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: _Level4CompleteScreenState.calmBlue
                  .withValues(alpha: 0.28), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: _Level4CompleteScreenState.calmBlue
                  .withValues(alpha: 0.07 + shimmer.value * 0.07),
              blurRadius: 22, spreadRadius: 1,
            ),
          ],
        ),
        child: Row(children: [
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('TOTAL LEVEL SCORE',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: mobile ? 10 : 11,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w600,
                  )),
              const SizedBox(height: 4),
              ShaderMask(
                shaderCallback: (b) => LinearGradient(
                    colors: [_Level4CompleteScreenState.toxicOrange,
                             _Level4CompleteScreenState.calmBlue])
                    .createShader(b),
                child: Text('$totalScore pts',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: mobile ? 34 : 46,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    )),
              ),
            ],
          )),

          Container(
            width:  mobile ? 58 : 72,
            height: mobile ? 58 : 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: gradeColor.withValues(alpha: 0.12),
              border: Border.all(
                  color: gradeColor.withValues(alpha: 0.6), width: 2.2),
              boxShadow: [
                BoxShadow(
                    color: gradeColor.withValues(alpha: 0.28),
                    blurRadius: 16, spreadRadius: 2),
              ],
            ),
            child: Center(child: Text(grade,
                style: TextStyle(
                  color: gradeColor,
                  fontSize: mobile ? 26 : 32,
                  fontWeight: FontWeight.w900,
                ))),
          ),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  STAT GRID  — 6 animated metric cards
// ══════════════════════════════════════════════════════════════════════════════
class _L4StatGrid extends StatelessWidget {
  final AnimationController stagger;
  final AirPollutionResult air;
  final NoiseResult noise;
  final bool mobile;

  const _L4StatGrid({
    required this.stagger, required this.air,
    required this.noise,   required this.mobile,
  });

  @override
  Widget build(BuildContext context) {
    final byProducts = air.methanol + air.gypsum + air.urea + air.nitrates;

    final stats = [
      _L4SD('🛩️', 'Air Purified',
          '${air.pollutantsNeutralized}/20',
          'Pollutant bubbles correctly\nneutralized in Phase 1 & 2',
          _Level4CompleteScreenState.toxicOrange),
      _L4SD('🔊', 'Noise Reduced',
          '${noise.noiseMeterFinal.toStringAsFixed(0)} dB',
          'Final city noise level\n(target: < 40 dB)',
          _Level4CompleteScreenState.calmBlue),
      _L4SD('✅', 'Hotspots Fixed',
          '${noise.hotspotsFix}/8',
          'Noise hotspots correctly\ntreated in Phase 3 & 4',
          _Level4CompleteScreenState.acidGreen),
      _L4SD('⚗️', 'By-Products',
          '$byProducts',
          'Chemical by-products collected\n(methanol, gypsum, urea, nitrates)',
          const Color(0xFFFFE082)),
      _L4SD('⭐', 'Air Eco-Pts',
          '${air.ecoPoints}',
          'Points from Phases 1 & 2\nair purification',
          _Level4CompleteScreenState.toxicOrange),
      _L4SD('🌿', 'Noise Eco-Pts',
          '${noise.ecoPoints}',
          'Points from Phases 3 & 4\nnoise reduction',
          _Level4CompleteScreenState.acidGreen),
    ];

    return LayoutBuilder(
      builder: (_, constraints) {
        final cols = constraints.maxWidth > 500 ? 3 : 2;
        return GridView.builder(
          shrinkWrap:  true,
          physics:     const NeverScrollableScrollPhysics(),
          itemCount:   stats.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount:   cols,
            crossAxisSpacing: 10,
            mainAxisSpacing:  10,
            childAspectRatio: mobile ? 1.25 : 1.45,
          ),
          itemBuilder: (_, i) => _L4StatCard(
            stat:    stats[i],
            idx:     i,
            stagger: stagger,
            mobile:  mobile,
          ),
        );
      },
    );
  }
}

class _L4SD {
  final String e, label, value, desc;
  final Color  color;
  const _L4SD(this.e, this.label, this.value, this.desc, this.color);
}

class _L4StatCard extends StatelessWidget {
  final _L4SD stat;
  final int  idx;
  final AnimationController stagger;
  final bool mobile;

  const _L4StatCard({
    required this.stat, required this.idx,
    required this.stagger, required this.mobile,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: stagger,
      builder: (_, child) {
        final delay = idx * 0.075;
        final raw   = ((stagger.value - delay) / (1.0 - delay)).clamp(0.0, 1.0);
        final t     = Curves.easeOutBack.transform(raw).clamp(0.0, 1.0);
        return Opacity(
            opacity: t,
            child: Transform.translate(
                offset: Offset(0, 22 * (1 - t)), child: child));
      },
      child: Container(
        padding: EdgeInsets.all(mobile ? 12 : 16),
        decoration: BoxDecoration(
          color: _Level4CompleteScreenState.panel,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: stat.color.withValues(alpha: 0.25), width: 1.2),
          boxShadow: [
            BoxShadow(
                color: stat.color.withValues(alpha: 0.08),
                blurRadius: 14, spreadRadius: 1),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(children: [
              Text(stat.e, style: TextStyle(fontSize: mobile ? 17 : 20)),
              const SizedBox(width: 6),
              Expanded(child: Text(stat.label,
                  style: TextStyle(
                    color: stat.color,
                    fontSize: mobile ? 9 : 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis)),
            ]),
            ShaderMask(
              shaderCallback: (b) =>
                  LinearGradient(colors: [stat.color, Colors.white])
                      .createShader(b),
              child: Text(stat.value,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: mobile ? 22 : 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  )),
            ),
            Text(stat.desc,
                style: TextStyle(
                  color: Colors.white30,
                  fontSize: mobile ? 9 : 10,
                  height: 1.4,
                )),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  BADGES ROW  — Peaceful City + Air Purifier unlocks
// ══════════════════════════════════════════════════════════════════════════════
class _L4BadgesRow extends StatelessWidget {
  final bool peacefulCity, airPerfect;
  final AnimationController pulse;
  final bool mobile;

  const _L4BadgesRow({
    required this.peacefulCity, required this.airPerfect,
    required this.pulse, required this.mobile,
  });

  @override
  Widget build(BuildContext context) {
    if (!peacefulCity && !airPerfect) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: pulse,
      builder: (_, __) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('BADGES UNLOCKED',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white38,
                fontSize: mobile ? 10 : 11,
                letterSpacing: 2,
                fontWeight: FontWeight.w600,
              )),
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (peacefulCity)
              _BadgePill('🕊️', 'Peaceful City',
                  _Level4CompleteScreenState.acidGreen, pulse.value, mobile),
            if (peacefulCity && airPerfect) const SizedBox(width: 10),
            if (airPerfect)
              _BadgePill('💨', 'Air Purifier',
                  _Level4CompleteScreenState.calmBlue, pulse.value, mobile),
          ]),
        ],
      ),
    );
  }
}

class _BadgePill extends StatelessWidget {
  final String emoji, label;
  final Color color;
  final double pulse;
  final bool mobile;
  const _BadgePill(this.emoji, this.label, this.color, this.pulse, this.mobile);

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(
        horizontal: mobile ? 14 : 20, vertical: 10),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.10 + pulse * 0.06),
      borderRadius: BorderRadius.circular(32),
      border: Border.all(
          color: color.withValues(alpha: 0.45 + pulse * 0.20), width: 1.5),
      boxShadow: [BoxShadow(
          color: color.withValues(alpha: 0.18 + pulse * 0.14),
          blurRadius: 14)],
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text(emoji, style: TextStyle(fontSize: mobile ? 18 : 22)),
      const SizedBox(width: 8),
      Text(label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w900,
            fontSize: mobile ? 12 : 14,
          )),
    ]),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
//  GRADE BADGE CARD
// ══════════════════════════════════════════════════════════════════════════════
class _L4BadgeCard extends StatelessWidget {
  final String grade;
  final Color  gradeColor;
  final AnimationController pulse;
  final bool   mobile;

  const _L4BadgeCard({
    required this.grade,   required this.gradeColor,
    required this.pulse,   required this.mobile,
  });

  String get _title {
    switch (grade) {
      case 'S': return 'Eco-Hero: City Saviour';
      case 'A': return 'Air & Sound Champion';
      case 'B': return 'Environmental Defender';
      case 'C': return 'City Cleaner';
      default:  return 'Pollution Fighter';
    }
  }

  String get _desc {
    switch (grade) {
      case 'S': return 'Outstanding! You neutralized every pollutant and '
          'silenced the city entirely. Kiambu breathes and rests in peace!';
      case 'A': return 'Excellent work! Strong chemistry knowledge and sharp '
          'noise interventions restored health to the city.';
      case 'B': return 'Good effort! You reduced both air and noise pollution '
          'and made the city noticeably cleaner and quieter.';
      case 'C': return 'Level 4 complete. Sharpen your arrow selection and '
          'intervention choices to earn a higher grade next time.';
      default:  return 'You finished Level 4. Study the chemical reactions and '
          'noise sources to improve your score on the next attempt.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (_, __) => Container(
        padding: EdgeInsets.all(mobile ? 16 : 22),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            gradeColor.withValues(alpha: 0.08 + pulse.value * 0.06),
            _Level4CompleteScreenState.panel,
          ], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: gradeColor
                  .withValues(alpha: 0.35 + pulse.value * 0.2), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: gradeColor.withValues(alpha: 0.10 + pulse.value * 0.10),
              blurRadius: 22, spreadRadius: 2,
            ),
          ],
        ),
        child: Row(children: [
          // Grade circle
          Container(
            width:  mobile ? 66 : 82,
            height: mobile ? 66 : 82,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: gradeColor.withValues(alpha: 0.12),
              border: Border.all(
                  color: gradeColor.withValues(alpha: 0.6), width: 2.2),
              boxShadow: [
                BoxShadow(
                    color: gradeColor.withValues(
                        alpha: 0.22 + pulse.value * 0.16),
                    blurRadius: 20, spreadRadius: 3),
              ],
            ),
            child: Center(child: Text(grade,
                style: TextStyle(
                  color: gradeColor,
                  fontSize: mobile ? 28 : 36,
                  fontWeight: FontWeight.w900,
                ))),
          ),

          const SizedBox(width: 16),

          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Text('🏅 ', style: TextStyle(fontSize: 15)),
                Expanded(child: Text(_title,
                    style: TextStyle(
                      color: gradeColor,
                      fontWeight: FontWeight.w800,
                      fontSize: mobile ? 14 : 16,
                    ))),
              ]),
              const SizedBox(height: 7),
              Text(_desc,
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: mobile ? 11 : 12,
                    height: 1.55,
                  )),
            ],
          )),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  ACTION BUTTONS
// ══════════════════════════════════════════════════════════════════════════════
class _L4ActionButtons extends StatelessWidget {
  final bool mobile;
  const _L4ActionButtons({required this.mobile});

  void _showComingSoon(BuildContext context) {
    HapticFeedback.lightImpact();
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: const Color(0xFF0A1422),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
              color: _Level4CompleteScreenState.calmBlue
                  .withValues(alpha: 0.35), width: 1.5),
        ),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('🚧', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            const Text('Level 5 Coming Soon!',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20)),
            const SizedBox(height: 10),
            const Text(
              'The next adventure is under construction.\n'
              'Your Level 4 progress has been saved — '
              'check back soon to continue your eco-journey!',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white54, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF003050),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('GOT IT',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, letterSpacing: 1)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [

      // PROCEED TO LEVEL 5
      SizedBox(
        width: double.infinity,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: () => _showComingSoon(context),
            borderRadius: BorderRadius.circular(16),
            child: Ink(
              padding: EdgeInsets.symmetric(
                  vertical: mobile ? 16 : 19, horizontal: 24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF001A2E),
                    Color(0xFF003050),
                    Color(0xFF004070),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                      color: _Level4CompleteScreenState.calmBlue
                          .withValues(alpha: 0.28),
                      blurRadius: 18,
                      offset: const Offset(0, 4)),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('🚀', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 10),
                  Text('PROCEED TO LEVEL 5',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: mobile ? 15 : 17,
                        letterSpacing: 1.2,
                      )),
                  const SizedBox(width: 10),
                  const Icon(Icons.arrow_forward_rounded,
                      color: Colors.white, size: 20),
                ],
              ),
            ),
          ),
        ),
      ),

      const SizedBox(height: 12),

      // REPLAY LEVEL 4
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () =>
              Navigator.of(context).popUntil((r) => r.isFirst),
          icon: const Icon(Icons.replay_rounded, size: 17),
          label: Text('REPLAY LEVEL 4',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: mobile ? 13 : 14,
                letterSpacing: 0.8,
              )),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white70,
            side: BorderSide(
                color: Colors.white.withValues(alpha: 0.18), width: 1.2),
            padding: EdgeInsets.symmetric(
                vertical: mobile ? 13 : 15),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
    ]);
  }
}