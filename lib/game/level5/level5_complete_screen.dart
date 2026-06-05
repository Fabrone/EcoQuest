import 'dart:math' as math;
import 'package:ecoquest/game/level5/degraded_land_screen.dart';
import 'package:ecoquest/game/level5/land_degradation_game_screen.dart';
import 'package:ecoquest/game/level5/soil_pollution_models.dart';
import 'package:ecoquest/game/level6/degraded_park_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  LEVEL 5 COMPLETE SCREEN
// ══════════════════════════════════════════════════════════════════════════════

class Level5CompleteScreen extends StatefulWidget {
  final Level4CarryOver carryOver;
  const Level5CompleteScreen({super.key, required this.carryOver});

  @override
  State<Level5CompleteScreen> createState() => _Level5CompleteScreenState();
}

class _Level5CompleteScreenState extends State<Level5CompleteScreen>
    with TickerProviderStateMixin {

  late final AnimationController _entryCtrl;
  late final AnimationController _burstCtrl;
  late final AnimationController _badgePulse;
  late final AnimationController _shimmerCtrl;
  late final AnimationController _staggerCtrl;
  late final AnimationController _bgCtrl;

  late final Animation<double> _scaleAnim;
  late final Animation<Offset> _slideAnim;
  late final Animation<double> _fadeAnim;

  // ── Colours ───────────────────────────────────────────────────────────────
  static const Color bgDeep       = Color(0xFF060804);
  static const Color bgMid        = Color(0xFF0C1208);
  static const Color panel        = Color(0xFF0A1006);
  static const Color soilAmber    = Color(0xFFFFB300);
  static const Color fertileGreen = Color(0xFF69F0AE);
  static const Color earthOrange  = Color(0xFFFF6D00);
  static const Color gold         = Color(0xFFFFD700);

  // ── Derived ───────────────────────────────────────────────────────────────
  LandDegradationResult get _land =>
      LandDegradationResult.current ??
      const LandDegradationResult(
        patchesRestored:   0,
        patchesStabilized: 0,
        correctTools:      0,
        wrongTools:        0,
        ecoPoints:         0,
        erosionIndex:      92,
        terrainStabilised: false,
        scannedPatches:    0,
      );

  SoilPollutionResult get _soil =>
      SoilPollutionResult.current ??
      const SoilPollutionResult(
        zonesRemediated:   0,
        zonesPhysical:     0,
        correctTools:      0,
        wrongTools:        0,
        ecoPoints:         0,
        soilHealth:        0.0,
        soilGuardianBadge: false,
        scannedZones:      0,
      );

  int get _totalScore => (_land.ecoPoints + _soil.ecoPoints).round();

  String get _grade {
    if (_totalScore >= 600) return 'S';
    if (_totalScore >= 420) return 'A';
    if (_totalScore >= 250) return 'B';
    if (_totalScore >= 120) return 'C';
    return 'D';
  }

  Color get _gradeColor {
    switch (_grade) {
      case 'S': return gold;
      case 'A': return fertileGreen;
      case 'B': return soilAmber;
      case 'C': return Colors.orange;
      default:  return Colors.redAccent;
    }
  }

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

          // Animated gradient background
          AnimatedBuilder(
            animation: _bgCtrl,
            builder: (_, __) => Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color.lerp(bgDeep, const Color(0xFF0A1A04), _bgCtrl.value)!,
                    Color.lerp(bgMid,  const Color(0xFF0C1E08), _bgCtrl.value * 0.5)!,
                    Color.lerp(bgDeep, const Color(0xFF060A04), _bgCtrl.value * 0.3)!,
                  ],
                  stops: const [0.0, 0.55, 1.0],
                ),
              ),
            ),
          ),

          const _L5StarField(),

          _L5ConfettiBurst(ctrl: _burstCtrl, screenSize: size),

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

                      _L5TrophyHeader(
                        badgePulse:    _badgePulse,
                        shimmer:       _shimmerCtrl,
                        totalScore:    _totalScore,
                        soilGuardian:  _soil.soilGuardianBadge,
                        terrainStable: _land.terrainStabilised,
                        mobile:        mobile,
                      ),

                      SizedBox(height: mobile ? 22 : 30),

                      _L5ScoreBanner(
                        totalScore: _totalScore,
                        grade:      _grade,
                        gradeColor: _gradeColor,
                        shimmer:    _shimmerCtrl,
                        mobile:     mobile,
                      ),

                      SizedBox(height: mobile ? 18 : 26),

                      _L5StatGrid(
                        stagger: _staggerCtrl,
                        land:    _land,
                        soil:    _soil,
                        mobile:  mobile,
                      ),

                      SizedBox(height: mobile ? 18 : 26),

                      _L5BadgesRow(
                        soilGuardian:  _soil.soilGuardianBadge,
                        terrainStable: _land.terrainStabilised,
                        pulse:         _badgePulse,
                        mobile:        mobile,
                      ),

                      SizedBox(height: mobile ? 18 : 26),

                      _L5BadgeCard(
                        grade:      _grade,
                        gradeColor: _gradeColor,
                        pulse:      _badgePulse,
                        mobile:     mobile,
                      ),

                      SizedBox(height: mobile ? 22 : 30),

                      _L5ActionButtons(
                        mobile: mobile,
                        level4CarryOver: widget.carryOver,          // kept for Replay button
                        level5CarryOver: Level5CarryOver(
                          ecoPoints:        _totalScore,
                          landEcoPoints:    _land.ecoPoints,
                          soilEcoPoints:    _soil.ecoPoints,
                          patchesRestored:  _land.patchesRestored,
                          zonesRemediated:  _soil.zonesRemediated,
                          soilHealthFinal:  _soil.soilHealth,
                          soilGuardianBadge: _soil.soilGuardianBadge,
                          terrainStabilised: _land.terrainStabilised,
                        ),
                      ),

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
class _L5StarField extends StatelessWidget {
  const _L5StarField();
  @override
  Widget build(BuildContext context) => Positioned.fill(
    child: IgnorePointer(child: CustomPaint(painter: _L5StarPainter())),
  );
}

class _L5StarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(55);
    final p   = Paint();
    for (int i = 0; i < 80; i++) {
      p.color = Colors.white.withValues(
          alpha: rng.nextDouble() * 0.20 + 0.04);
      canvas.drawCircle(
        Offset(rng.nextDouble() * size.width,
               rng.nextDouble() * size.height),
        rng.nextDouble() * 1.2 + 0.3, p,
      );
    }
  }
  @override bool shouldRepaint(_) => false;
}

// ══════════════════════════════════════════════════════════════════════════════
//  CONFETTI BURST  — earth tone themed
// ══════════════════════════════════════════════════════════════════════════════
class _L5ConfettiBurst extends StatelessWidget {
  final AnimationController ctrl;
  final Size screenSize;
  const _L5ConfettiBurst({required this.ctrl, required this.screenSize});

  static const _colors = [
    Color(0xFFFFB300), Color(0xFF69F0AE), Color(0xFFFF6D00),
    Color(0xFFBCAAA4), Color(0xFFFFD700), Color(0xFFFFFFFF),
    Color(0xFF76FF03), Color(0xFFA5D6A7), Color(0xFFFF8A65),
  ];

  @override
  Widget build(BuildContext context) => Positioned.fill(
    child: IgnorePointer(
      child: AnimatedBuilder(
        animation: ctrl,
        builder: (_, __) => CustomPaint(
          painter: _L5ConfettiPainter(t: ctrl.value, colors: _colors),
        ),
      ),
    ),
  );
}

class _L5ConfettiPainter extends CustomPainter {
  final double t;
  final List<Color> colors;
  static const _count = 68;
  const _L5ConfettiPainter({required this.t, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0) return;
    final opacity = t < 0.25 ? t / 0.25
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
          canvas.save();
          canvas.translate(px, py);
          canvas.rotate(angle + pt * math.pi * 5);
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
            Paint()..color = col..strokeWidth = r * 0.55..strokeCap = StrokeCap.round,
          );
          break;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _L5ConfettiPainter o) => o.t != t;
}

// ══════════════════════════════════════════════════════════════════════════════
//  TROPHY HEADER
// ══════════════════════════════════════════════════════════════════════════════
class _L5TrophyHeader extends StatelessWidget {
  final AnimationController badgePulse, shimmer;
  final int   totalScore;
  final bool  soilGuardian, terrainStable, mobile;

  const _L5TrophyHeader({
    required this.badgePulse, required this.shimmer,
    required this.totalScore, required this.soilGuardian,
    required this.terrainStable, required this.mobile,
  });

  @override
  Widget build(BuildContext context) {
    return Column(children: [

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
                    _Level5CompleteScreenState.soilAmber,
                    _Level5CompleteScreenState.fertileGreen,
                    glow)!.withValues(alpha: 0.72),
                width: 2.5,
              ),
              boxShadow: [BoxShadow(
                color: Color.lerp(
                        _Level5CompleteScreenState.soilAmber,
                        _Level5CompleteScreenState.fertileGreen, glow)!
                    .withValues(alpha: 0.28 + glow * 0.28),
                blurRadius: 28 + glow * 22,
                spreadRadius: 4 + glow * 3,
              )],
            ),
            child: Center(child: Text('🏆',
                style: TextStyle(fontSize: mobile ? 48 : 60))),
          );
        },
      ),

      const SizedBox(height: 18),

      ShaderMask(
        shaderCallback: (bounds) => const LinearGradient(
          colors: [Color(0xFFFFB300), Color(0xFF69F0AE), Color(0xFFFF6D00)],
        ).createShader(bounds),
        child: Text(
          'LEVEL 5 COMPLETE',
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
        '🌿  Land Restored & Soil Healed — Mission Accomplished!',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white54,
          fontSize: mobile ? 12 : 14,
          letterSpacing: 0.3,
        ),
      ),

      const SizedBox(height: 18),

      AnimatedBuilder(
        animation: shimmer,
        builder: (_, __) => Container(
          padding: EdgeInsets.symmetric(
              horizontal: mobile ? 18 : 26, vertical: 9),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              Color.lerp(const Color(0xFF1A1000),
                  const Color(0xFF2E1C00), shimmer.value)!,
              const Color(0xFF1A1200),
            ]),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
                color: _Level5CompleteScreenState.soilAmber
                    .withValues(alpha: 0.45), width: 1.5),
            boxShadow: [BoxShadow(
                color: _Level5CompleteScreenState.soilAmber
                    .withValues(alpha: 0.12 + shimmer.value * 0.18),
                blurRadius: 18)],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Text('⭐', style: TextStyle(fontSize: 17)),
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
class _L5ScoreBanner extends StatelessWidget {
  final int   totalScore;
  final String grade;
  final Color  gradeColor;
  final AnimationController shimmer;
  final bool   mobile;

  const _L5ScoreBanner({
    required this.totalScore, required this.grade,
    required this.gradeColor, required this.shimmer, required this.mobile,
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
              const Color(0xFF0E1006),
              Color.lerp(const Color(0xFF0E1006),
                  const Color(0xFF1A1A08), shimmer.value)!,
              const Color(0xFF0A0C04),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: _Level5CompleteScreenState.soilAmber
                  .withValues(alpha: 0.28), width: 1.5),
          boxShadow: [BoxShadow(
            color: _Level5CompleteScreenState.soilAmber
                .withValues(alpha: 0.07 + shimmer.value * 0.07),
            blurRadius: 22, spreadRadius: 1,
          )],
        ),
        child: Row(children: [
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('TOTAL LEVEL SCORE',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: mobile ? 10 : 11,
                    letterSpacing: 2, fontWeight: FontWeight.w600,
                  )),
              const SizedBox(height: 4),
              ShaderMask(
                shaderCallback: (b) => LinearGradient(
                    colors: [_Level5CompleteScreenState.soilAmber,
                             _Level5CompleteScreenState.fertileGreen])
                    .createShader(b),
                child: Text('$totalScore pts',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: mobile ? 34 : 46,
                      fontWeight: FontWeight.w900, letterSpacing: 1,
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
              boxShadow: [BoxShadow(
                  color: gradeColor.withValues(alpha: 0.28),
                  blurRadius: 16, spreadRadius: 2)],
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
//  STAT GRID
// ══════════════════════════════════════════════════════════════════════════════
class _L5StatGrid extends StatelessWidget {
  final AnimationController stagger;
  final LandDegradationResult land;
  final SoilPollutionResult   soil;
  final bool mobile;

  const _L5StatGrid({
    required this.stagger, required this.land,
    required this.soil,    required this.mobile,
  });

  @override
  Widget build(BuildContext context) {
    final stats = [
      _L5SD('🛰️', 'Land Restored',
          '${land.patchesRestored}/8',
          'Eroded patches correctly\nrestored in Phase 1 & 2',
          _Level5CompleteScreenState.soilAmber),
      _L5SD('🌱', 'Soil Health',
          '${soil.soilHealth.toStringAsFixed(0)}%',
          'Final soil health level\n(target: ≥ 75%)',
          _Level5CompleteScreenState.fertileGreen),
      _L5SD('✅', 'Zones Treated',
          '${soil.zonesRemediated}',
          'Polluted zones fully\nremediated in Phase 3 & 4',
          const Color(0xFF76FF03)),
      _L5SD('🏜️', 'Erosion Index',
          '${land.erosionIndex.toStringAsFixed(0)}%',
          'Final erosion level\n(target: < 20%)',
          _Level5CompleteScreenState.earthOrange),
      _L5SD('⭐', 'Land Eco-Pts',
          '${land.ecoPoints}',
          'Points from Phases 1 & 2\nterrain restoration',
          _Level5CompleteScreenState.soilAmber),
      _L5SD('🌿', 'Soil Eco-Pts',
          '${soil.ecoPoints}',
          'Points from Phases 3 & 4\nbioremediation',
          _Level5CompleteScreenState.fertileGreen),
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
          itemBuilder: (_, i) => _L5StatCard(
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

class _L5SD {
  final String e, label, value, desc;
  final Color  color;
  const _L5SD(this.e, this.label, this.value, this.desc, this.color);
}

class _L5StatCard extends StatelessWidget {
  final _L5SD stat;
  final int  idx;
  final AnimationController stagger;
  final bool mobile;
  const _L5StatCard({
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
        return Opacity(opacity: t,
            child: Transform.translate(
                offset: Offset(0, 22 * (1 - t)), child: child));
      },
      child: Container(
        padding: EdgeInsets.all(mobile ? 12 : 16),
        decoration: BoxDecoration(
          color: _Level5CompleteScreenState.panel,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: stat.color.withValues(alpha: 0.25), width: 1.2),
          boxShadow: [BoxShadow(
              color: stat.color.withValues(alpha: 0.08),
              blurRadius: 14, spreadRadius: 1)],
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
                    color: stat.color, fontSize: mobile ? 9 : 10,
                    fontWeight: FontWeight.w700, letterSpacing: 0.4,
                  ),
                  maxLines: 1, overflow: TextOverflow.ellipsis)),
            ]),
            ShaderMask(
              shaderCallback: (b) =>
                  LinearGradient(colors: [stat.color, Colors.white])
                      .createShader(b),
              child: Text(stat.value,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: mobile ? 22 : 28,
                    fontWeight: FontWeight.w900, letterSpacing: 0.5,
                  )),
            ),
            Text(stat.desc,
                style: TextStyle(
                  color: Colors.white30,
                  fontSize: mobile ? 9 : 10, height: 1.4,
                )),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  BADGES ROW
// ══════════════════════════════════════════════════════════════════════════════
class _L5BadgesRow extends StatelessWidget {
  final bool soilGuardian, terrainStable;
  final AnimationController pulse;
  final bool mobile;

  const _L5BadgesRow({
    required this.soilGuardian, required this.terrainStable,
    required this.pulse, required this.mobile,
  });

  @override
  Widget build(BuildContext context) {
    if (!soilGuardian && !terrainStable) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: pulse,
      builder: (_, __) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('BADGES UNLOCKED',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white38, fontSize: mobile ? 10 : 11,
                letterSpacing: 2, fontWeight: FontWeight.w600,
              )),
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (terrainStable)
              _L5BadgePill('🌾', 'Terrain Stabiliser',
                  _Level5CompleteScreenState.soilAmber, pulse.value, mobile),
            if (terrainStable && soilGuardian) const SizedBox(width: 10),
            if (soilGuardian)
              _L5BadgePill('🌱', 'Soil Guardian',
                  _Level5CompleteScreenState.fertileGreen, pulse.value, mobile),
          ]),
        ],
      ),
    );
  }
}

class _L5BadgePill extends StatelessWidget {
  final String emoji, label;
  final Color color;
  final double pulse;
  final bool mobile;
  const _L5BadgePill(this.emoji, this.label, this.color, this.pulse, this.mobile);

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
      Text(label, style: TextStyle(
          color: color, fontWeight: FontWeight.w900,
          fontSize: mobile ? 12 : 14)),
    ]),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
//  GRADE BADGE CARD
// ══════════════════════════════════════════════════════════════════════════════
class _L5BadgeCard extends StatelessWidget {
  final String grade;
  final Color  gradeColor;
  final AnimationController pulse;
  final bool   mobile;

  const _L5BadgeCard({
    required this.grade, required this.gradeColor,
    required this.pulse, required this.mobile,
  });

  String get _title {
    switch (grade) {
      case 'S': return 'Master Earth Restorer';
      case 'A': return 'Land & Soil Champion';
      case 'B': return 'Environmental Rehabilitator';
      case 'C': return 'Terrain Cleaner';
      default:  return 'Soil Apprentice';
    }
  }

  String get _desc {
    switch (grade) {
      case 'S': return 'Outstanding! Every gully was healed, every pollutant '
          'neutralised. The land thrives and Kiambu\'s soils are reborn!';
      case 'A': return 'Excellent work! Strong knowledge of erosion control '
          'and bioremediation transformed the degraded landscape.';
      case 'B': return 'Good job! You stabilised the terrain and treated '
          'multiple polluted zones, restoring soil fertility.';
      case 'C': return 'Level 5 complete. Review erosion control tools and '
          'bioremediation agents to earn a higher grade next time.';
      default:  return 'You finished Level 5. Study the soil treatment table '
          'and restoration tools to improve your score.';
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
            _Level5CompleteScreenState.panel,
          ], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: gradeColor.withValues(alpha: 0.35 + pulse.value * 0.2),
              width: 1.5),
          boxShadow: [BoxShadow(
            color: gradeColor.withValues(alpha: 0.10 + pulse.value * 0.10),
            blurRadius: 22, spreadRadius: 2,
          )],
        ),
        child: Row(children: [
          Container(
            width:  mobile ? 66 : 82,
            height: mobile ? 66 : 82,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: gradeColor.withValues(alpha: 0.12),
              border: Border.all(
                  color: gradeColor.withValues(alpha: 0.6), width: 2.2),
              boxShadow: [BoxShadow(
                  color: gradeColor.withValues(
                      alpha: 0.22 + pulse.value * 0.16),
                  blurRadius: 20, spreadRadius: 3)],
            ),
            child: Center(child: Text(grade,
                style: TextStyle(
                  color: gradeColor, fontSize: mobile ? 28 : 36,
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
                      color: gradeColor, fontWeight: FontWeight.w800,
                      fontSize: mobile ? 14 : 16,
                    ))),
              ]),
              const SizedBox(height: 7),
              Text(_desc, style: TextStyle(
                color: Colors.white54,
                fontSize: mobile ? 11 : 12, height: 1.55,
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
class _L5ActionButtons extends StatelessWidget {
  final bool            mobile;
  final Level4CarryOver level4CarryOver;   // replay
  final Level5CarryOver level5CarryOver;   // proceed
  const _L5ActionButtons({
    required this.mobile,
    required this.level4CarryOver,
    required this.level5CarryOver,
  });

  void _proceedToLevel6(BuildContext context) {
    HapticFeedback.lightImpact();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => DegradedParkScreen(carryOver: level5CarryOver),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [

      SizedBox(
        width: double.infinity,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: () => _proceedToLevel6(context),
            borderRadius: BorderRadius.circular(16),
            child: Ink(
              padding: EdgeInsets.symmetric(
                  vertical: mobile ? 16 : 19, horizontal: 24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0A1E04), Color(0xFF14300A), Color(0xFF1A3E0E)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(
                    color: _Level5CompleteScreenState.fertileGreen
                        .withValues(alpha: 0.28),
                    blurRadius: 18, offset: const Offset(0, 4))],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('🚀', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 10),
                  Text('PROCEED TO LEVEL 6',
                      style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w900,
                        fontSize: mobile ? 15 : 17, letterSpacing: 1.2,
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

      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () {
            // Pop the Level5CompleteScreen and everything above the
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute<void>(
                builder: (_) =>
                    DegradedLandScreen(carryOver: level4CarryOver),
              ),
              (route) => route.isFirst,
            );
          },
          icon: const Icon(Icons.replay_rounded, size: 17),
          label: Text('REPLAY LEVEL 5',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: mobile ? 13 : 14, letterSpacing: 0.8,
              )),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white70,
            side: BorderSide(
                color: Colors.white.withValues(alpha: 0.18), width: 1.2),
            padding: EdgeInsets.symmetric(vertical: mobile ? 13 : 15),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
    ]);
  }
}