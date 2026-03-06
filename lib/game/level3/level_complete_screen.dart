import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  LEVEL COMPLETE SCREEN  —  Level 3 final summary
//  Pure Flutter. Zero Flame. Zero image assets.
//  All metrics passed from CraftingWorkshopScreen via constructor.
//  Features: confetti burst, animated grade badge, stat grid, Level 4 CTA.
// ══════════════════════════════════════════════════════════════════════════════

class LevelCompleteScreen extends StatefulWidget {
  /// Eco-points accumulated across the entire Level 3 (sorting phase total).
  final int ecoPoints;

  /// Eco-Creativity XP earned in the crafting workshop.
  final int ecoCreativity;

  /// Number of products crafted in the workshop.
  final int craftedCount;

  /// Total waste categories shown in the workshop (always 5).
  final int totalCategories;

  /// Waste categories that contained at least 1 item.
  final int categoriesUsed;

  /// Total individual waste items the player sorted.
  final int totalItemsSorted;

  const LevelCompleteScreen({
    super.key,
    required this.ecoPoints,
    required this.ecoCreativity,
    required this.craftedCount,
    required this.totalCategories,
    required this.categoriesUsed,
    required this.totalItemsSorted,
  });

  @override
  State<LevelCompleteScreen> createState() => _LevelCompleteScreenState();
}

class _LevelCompleteScreenState extends State<LevelCompleteScreen>
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

  // ── Colour constants (accessible from inner widgets via class ref) ─────────
  static const Color bgDeep  = Color(0xFF020B18);
  static const Color bgMid   = Color(0xFF071428);
  static const Color panel   = Color(0xFF0A1628);
  static const Color gold    = Color(0xFFFFD700);
  static const Color lime    = Color(0xFF76FF03);
  static const Color teal    = Color(0xFF00E5FF);

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
        duration: const Duration(seconds: 9))..repeat(reverse: true);

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

  // ── Derived stats ─────────────────────────────────────────────────────────
  int get _totalScore => widget.ecoPoints + widget.ecoCreativity;

  String get _grade {
    if (_totalScore >= 1200) return 'S';
    if (_totalScore >= 900)  return 'A';
    if (_totalScore >= 600)  return 'B';
    if (_totalScore >= 300)  return 'C';
    return 'D';
  }

  Color get _gradeColor {
    switch (_grade) {
      case 'S': return gold;
      case 'A': return lime;
      case 'B': return teal;
      case 'C': return Colors.orange;
      default:  return Colors.redAccent;
    }
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

          // ── Animated gradient background ──────────────────────────────
          AnimatedBuilder(
            animation: _bgCtrl,
            builder: (_, __) => Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color.lerp(bgDeep, const Color(0xFF031A2E), _bgCtrl.value)!,
                    Color.lerp(bgMid,  const Color(0xFF0A2040), _bgCtrl.value)!,
                    Color.lerp(bgDeep, const Color(0xFF011020), _bgCtrl.value * 0.5)!,
                  ],
                  stops: const [0.0, 0.55, 1.0],
                ),
              ),
            ),
          ),

          // ── Subtle star-field dots ────────────────────────────────────
          const _StarField(),

          // ── Confetti burst (appears at entry, fades out) ──────────────
          _ConfettiBurst(ctrl: _burstCtrl, screenSize: size),

          // ── Main scrollable content ───────────────────────────────────
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

                      _TrophyHeader(
                        badgePulse:  _badgePulse,
                        shimmer:     _shimmerCtrl,
                        totalXP:     widget.ecoCreativity,
                        mobile:      mobile,
                      ),

                      SizedBox(height: mobile ? 22 : 30),

                      _ScoreBanner(
                        totalScore: _totalScore,
                        grade:      _grade,
                        gradeColor: _gradeColor,
                        shimmer:    _shimmerCtrl,
                        mobile:     mobile,
                      ),

                      SizedBox(height: mobile ? 18 : 26),

                      _StatGrid(
                        stagger:       _staggerCtrl,
                        ecoPoints:     widget.ecoPoints,
                        ecoCreativity: widget.ecoCreativity,
                        craftedCount:  widget.craftedCount,
                        itemsSorted:   widget.totalItemsSorted,
                        categoriesUsed: widget.categoriesUsed,
                        totalCats:     widget.totalCategories,
                        mobile:        mobile,
                      ),

                      SizedBox(height: mobile ? 18 : 26),

                      _BadgeCard(
                        grade:      _grade,
                        gradeColor: _gradeColor,
                        pulse:      _badgePulse,
                        mobile:     mobile,
                      ),

                      SizedBox(height: mobile ? 22 : 30),

                      _ActionButtons(mobile: mobile),

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
//  STAR FIELD  — static tiny dots for depth
// ══════════════════════════════════════════════════════════════════════════════
class _StarField extends StatelessWidget {
  const _StarField();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(painter: _StarPainter()),
      ),
    );
  }
}

class _StarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rng   = math.Random(77);
    final paint = Paint()..color = Colors.white;
    for (int i = 0; i < 80; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final r = rng.nextDouble() * 1.2 + 0.3;
      paint.color = Colors.white.withValues(
          alpha: rng.nextDouble() * 0.25 + 0.05);
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }
  @override bool shouldRepaint(_) => false;
}

// ══════════════════════════════════════════════════════════════════════════════
//  CONFETTI BURST
// ══════════════════════════════════════════════════════════════════════════════
class _ConfettiBurst extends StatelessWidget {
  final AnimationController ctrl;
  final Size screenSize;
  const _ConfettiBurst({required this.ctrl, required this.screenSize});

  static const _colors = [
    Color(0xFFFFD700), Color(0xFF76FF03), Color(0xFF00E5FF),
    Color(0xFFFF4081), Color(0xFFFFAB40), Color(0xFFE040FB),
    Color(0xFF40C4FF), Color(0xFFB2FF59), Color(0xFFFF6E40),
  ];

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: ctrl,
          builder: (_, __) => CustomPaint(
            painter: _ConfettiPainter(t: ctrl.value, colors: _colors),
          ),
        ),
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final double t;
  final List<Color> colors;
  static const _count = 64;

  const _ConfettiPainter({required this.t, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0) return;
    // Opacity envelope: ramp up 0→0.25, hold 0.25→0.65, fade 0.65→1.0
    final opacity = t < 0.25
        ? t / 0.25
        : t < 0.65
            ? 1.0
            : (1.0 - (t - 0.65) / 0.35).clamp(0.0, 1.0);
    if (opacity <= 0) return;

    final cx = size.width  / 2;
    final cy = size.height * 0.22;

    for (int i = 0; i < _count; i++) {
      final delay = (i / _count) * 0.28;
      final pt    = ((t - delay) / (1.0 - delay)).clamp(0.0, 1.0);
      if (pt <= 0) continue;

      final angle  = (i * 137.508 % 360) * math.pi / 180;
      final radius = size.width * 0.52 * pt * (0.28 + (i % 8) * 0.09);
      final gravY  = size.height * 0.3 * pt * pt;
      final px     = cx + math.cos(angle) * radius;
      final py     = cy + math.sin(angle) * radius * 0.55 + gravY;
      final r      = (2.5 + (i % 6) * 2.2) * (1 - pt * 0.35);
      final col    = colors[i % colors.length].withValues(alpha: opacity * 0.88);
      final paint  = Paint()..color = col;

      switch (i % 3) {
        case 0: // circle
          canvas.drawCircle(Offset(px, py), r, paint);
          break;
        case 1: // rotated rectangle (confetti strip)
          final rot = angle + pt * math.pi * 5;
          canvas.save();
          canvas.translate(px, py);
          canvas.rotate(rot);
          canvas.drawRect(
              Rect.fromCenter(center: Offset.zero, width: r * 2.2, height: r * 0.8),
              paint);
          canvas.restore();
          break;
        case 2: // short line
          canvas.drawLine(
            Offset(px - math.cos(angle) * r, py - math.sin(angle) * r),
            Offset(px + math.cos(angle) * r, py + math.sin(angle) * r),
            Paint()
              ..color    = col
              ..strokeWidth = r * 0.55
              ..strokeCap   = StrokeCap.round,
          );
          break;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter o) => o.t != t;
}

// ══════════════════════════════════════════════════════════════════════════════
//  TROPHY HEADER
// ══════════════════════════════════════════════════════════════════════════════
class _TrophyHeader extends StatelessWidget {
  final AnimationController badgePulse, shimmer;
  final int   totalXP;
  final bool  mobile;

  const _TrophyHeader({
    required this.badgePulse, required this.shimmer,
    required this.totalXP,    required this.mobile,
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
                Color(0xFF1A3A1A), Color(0xFF0A1A0A),
              ]),
              border: Border.all(
                color: Color.lerp(_LevelCompleteScreenState.lime,
                    _LevelCompleteScreenState.gold, glow)!
                    .withValues(alpha: 0.72),
                width: 2.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Color.lerp(_LevelCompleteScreenState.lime,
                          _LevelCompleteScreenState.gold, glow)!
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

      // LEVEL 3 COMPLETE — gradient text
      ShaderMask(
        shaderCallback: (bounds) => const LinearGradient(
          colors: [Color(0xFFFFD700), Color(0xFF76FF03), Color(0xFF00E5FF)],
        ).createShader(bounds),
        child: Text(
          'LEVEL 3 COMPLETE',
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
        '♻️  City Waste Recycled — Mission Accomplished!',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white54,
          fontSize: mobile ? 12 : 14,
          letterSpacing: 0.3,
        ),
      ),

      const SizedBox(height: 18),

      // XP earned pill
      AnimatedBuilder(
        animation: shimmer,
        builder: (_, __) => Container(
          padding: EdgeInsets.symmetric(
              horizontal: mobile ? 18 : 26, vertical: 9),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              Color.lerp(const Color(0xFF1A4A1A),
                  const Color(0xFF2E7D32), shimmer.value)!,
              const Color(0xFF1B5E20),
            ]),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
                color: _LevelCompleteScreenState.lime.withValues(alpha: 0.45),
                width: 1.5),
            boxShadow: [
              BoxShadow(
                  color: _LevelCompleteScreenState.lime
                      .withValues(alpha: 0.12 + shimmer.value * 0.18),
                  blurRadius: 18),
            ],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Text('⚡', style: TextStyle(fontSize: 17)),
            const SizedBox(width: 9),
            Text('+$totalXP Eco-Creativity XP earned',
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
class _ScoreBanner extends StatelessWidget {
  final int   totalScore;
  final String grade;
  final Color  gradeColor;
  final AnimationController shimmer;
  final bool   mobile;

  const _ScoreBanner({
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
              const Color(0xFF0D2A14),
              Color.lerp(const Color(0xFF0D2A14),
                  const Color(0xFF163D20), shimmer.value)!,
              const Color(0xFF0A1E10),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: _LevelCompleteScreenState.lime.withValues(alpha: 0.28),
              width: 1.5),
          boxShadow: [
            BoxShadow(
              color: _LevelCompleteScreenState.lime
                  .withValues(alpha: 0.07 + shimmer.value * 0.07),
              blurRadius: 22, spreadRadius: 1,
            ),
          ],
        ),
        child: Row(children: [
          // Score + label
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
                    colors: [_LevelCompleteScreenState.lime,
                             _LevelCompleteScreenState.gold])
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

          // Grade badge
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
class _StatGrid extends StatelessWidget {
  final AnimationController stagger;
  final int ecoPoints, ecoCreativity, craftedCount;
  final int itemsSorted, categoriesUsed, totalCats;
  final bool mobile;

  const _StatGrid({
    required this.stagger,
    required this.ecoPoints,     required this.ecoCreativity,
    required this.craftedCount,  required this.itemsSorted,
    required this.categoriesUsed, required this.totalCats,
    required this.mobile,
  });

  @override
  Widget build(BuildContext context) {
    final impactPct =
        ((ecoPoints + ecoCreativity) / 14.0).clamp(0, 100).toStringAsFixed(0);

    final stats = [
      _SD('⭐', 'Eco-Points',      '$ecoPoints',
          'Earned from sorting\n& collection accuracy',
          const Color(0xFFFFD700)),
      _SD('⚡', 'Creativity XP',   '$ecoCreativity',
          'XP from crafting recycled\nproducts in the workshop',
          const Color(0xFF76FF03)),
      _SD('🔨', 'Items Crafted',   '$craftedCount',
          'Useful products made\nfrom sorted waste',
          const Color(0xFF00E5FF)),
      _SD('🗑️', 'Waste Sorted',   '$itemsSorted',
          'Individual waste items\ncorrectly binned',
          const Color(0xFFFF9800)),
      _SD('♻️', 'Categories',     '$categoriesUsed / $totalCats',
          'Waste types actively\nrecycled this level',
          const Color(0xFFE040FB)),
      _SD('🌱', 'Eco-Impact',     '$impactPct%',
          'Your positive environmental\nimpact rating',
          const Color(0xFF69F0AE)),
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
          itemBuilder: (_, i) => _StatCard(
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

class _SD {
  final String e, label, value, desc;
  final Color  color;
  const _SD(this.e, this.label, this.value, this.desc, this.color);
}

class _StatCard extends StatelessWidget {
  final _SD  stat;
  final int  idx;
  final AnimationController stagger;
  final bool mobile;

  const _StatCard({
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
          color: _LevelCompleteScreenState.panel,
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
            // Emoji + label
            Row(children: [
              Text(stat.e,
                  style: TextStyle(fontSize: mobile ? 17 : 20)),
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
            // Value
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
            // Description
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
//  BADGE CARD
// ══════════════════════════════════════════════════════════════════════════════
class _BadgeCard extends StatelessWidget {
  final String grade;
  final Color  gradeColor;
  final AnimationController pulse;
  final bool   mobile;

  const _BadgeCard({
    required this.grade,   required this.gradeColor,
    required this.pulse,   required this.mobile,
  });

  String get _title {
    switch (grade) {
      case 'S': return 'Master City Recycler';
      case 'A': return 'Expert Eco-Warrior';
      case 'B': return 'Skilled Waste Sorter';
      case 'C': return 'City Cleaner';
      default:  return 'Waste Collector';
    }
  }

  String get _desc {
    switch (grade) {
      case 'S': return 'Outstanding across all Level 3 phases. You sorted, '
          'crafted, and recycled with exceptional skill and knowledge!';
      case 'A': return 'Excellent work! Strong recycling knowledge and a '
          'solid range of products crafted from the workshop.';
      case 'B': return 'Good job! You successfully sorted and recycled city '
          'waste and created useful items from the workshop.';
      case 'C': return 'Level 3 complete. Improve your sorting accuracy and '
          'craft more items to earn a higher grade next time.';
      default:  return 'You finished Level 3. Sort waste more accurately and '
          'craft more workshop products to improve your grade.';
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
            _LevelCompleteScreenState.panel,
          ], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: gradeColor.withValues(alpha: 0.35 + pulse.value * 0.2),
              width: 1.5),
          boxShadow: [
            BoxShadow(
              color: gradeColor.withValues(alpha: 0.1 + pulse.value * 0.1),
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
class _ActionButtons extends StatelessWidget {
  final bool mobile;
  const _ActionButtons({required this.mobile});

  void _showComingSoon(BuildContext context) {
    HapticFeedback.lightImpact();
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: const Color(0xFF0A1628),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
              color: const Color(0xFF76FF03).withValues(alpha: 0.35),
              width: 1.5),
        ),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('🚧', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            const Text('Level 4 Coming Soon!',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20)),
            const SizedBox(height: 10),
            const Text(
              'The next adventure is under construction.\n'
              'Your Level 3 progress has been saved — '
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
                  backgroundColor: const Color(0xFF1B5E20),
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

      // ── PROCEED TO LEVEL 4 ─────────────────────────────────────────────
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
                    Color(0xFF1B5E20),
                    Color(0xFF2E7D32),
                    Color(0xFF388E3C),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                      color: _LevelCompleteScreenState.lime
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
                  Text('PROCEED TO LEVEL 4',
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

      // ── REPLAY LEVEL 3 ─────────────────────────────────────────────────
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () =>
              Navigator.of(context).popUntil((r) => r.isFirst),
          icon: const Icon(Icons.replay_rounded, size: 17),
          label: Text('REPLAY LEVEL 3',
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