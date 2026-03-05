import 'dart:math' as math;
import 'package:ecoquest/game/level3/city_collection_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  CITY WASTE ITEM — mirrors WasteToken from city_collection_screen exactly.
//  Each item carries the same emoji/label from the street collection phase.
// ══════════════════════════════════════════════════════════════════════════════

class _CityWasteItem {
  final String   emoji;  // exact emoji from _WasteConfig, or 'BROKEN_BOTTLE'/'SHATTERED_GLASS'
  final String   label;  // e.g. 'Banana Peel', 'Old Phone'
  final WasteType type;  // city enum: plastic/organic/electronic/glass/metallic
  final String   id;
  bool isSorted = false;

  _CityWasteItem({
    required this.emoji,
    required this.label,
    required this.type,
  }) : id = '${type.name}_${DateTime.now().microsecondsSinceEpoch}_${math.Random().nextInt(9999)}';

  /// Bin key this item must go into.
  String get correctBin {
    switch (type) {
      case WasteType.plastic:    return 'plastic';
      case WasteType.organic:    return 'organic';
      case WasteType.electronic: return 'e_waste';
      case WasteType.glass:      return 'glass';
      case WasteType.metallic:   return 'metallic';
      default:                   return 'metallic'; // WasteType.general maps to metallic as fallback
    }
  }

  /// Type-colour — exact WasteToken._col from city_collection_screen.
  Color get typeColor {
    switch (type) {
      case WasteType.plastic:    return const Color(0xFF2196F3);
      case WasteType.organic:    return const Color(0xFF4CAF50);
      case WasteType.electronic: return const Color(0xFFF97316);
      case WasteType.glass:      return const Color(0xFF00BCD4);
      case WasteType.metallic:   return const Color(0xFFB0BEC5);
      default:                   return const Color(0xFF9E9E9E);
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  CARRY-OVER FROM LEVEL 2 (Water Cleaning sorting phase)
// ══════════════════════════════════════════════════════════════════════════════

class WaterLevelCarryOver {
  final int plastic;
  final int metal;
  final int organic;
  final int hazardous;
  final int ecoPoints;
  final int purifiedWater;
  final int fishCount;

  const WaterLevelCarryOver({
    this.plastic = 0,
    this.metal = 0,
    this.organic = 0,
    this.hazardous = 0,
    this.ecoPoints = 0,
    this.purifiedWater = 0,
    this.fishCount = 0,
  });

  int get totalItems => plastic + metal + organic + hazardous;
}

// ══════════════════════════════════════════════════════════════════════════════
//  SORTING FACILITY SCREEN
// ══════════════════════════════════════════════════════════════════════════════

class SortingFacilityScreen extends StatefulWidget {
  /// Carry-over data from Level 2. Defaults to empty.
  final WaterLevelCarryOver waterCarryOver;

  const SortingFacilityScreen({
    super.key,
    this.waterCarryOver = const WaterLevelCarryOver(),
  });

  @override
  State<SortingFacilityScreen> createState() => _SortingFacilityScreenState();
}

class _SortingFacilityScreenState extends State<SortingFacilityScreen>
    with TickerProviderStateMixin {

  // ── Design palette (city collection screen colours) ───────────────────────
  static const Color _bgDeep   = Color(0xFF0D1B2A);
  static const Color _panel    = Color(0xFF0D1B2A);
  static const Color _accent   = Color(0xFFFFD740);   // amber
  static const Color _correct  = Color(0xFF4CAF50);
  static const Color _wrong    = Color(0xFFE53935);

  // Bin / type colours — exact WasteToken._col
  static const Color _plasticC   = Color(0xFF2196F3);
  static const Color _organicC   = Color(0xFF4CAF50);
  static const Color _eWasteC    = Color(0xFFF97316);
  static const Color _glassC     = Color(0xFF00BCD4);
  static const Color _metallicC  = Color(0xFFB0BEC5);

  // ── Sorting timer ─────────────────────────────────────────────────────────
  static const int _timerMax = 120; // 2 min
  double _timeLeft    = _timerMax.toDouble();
  bool   _timerRunning = false;

  // ── Waste stack ───────────────────────────────────────────────────────────
  late List<_CityWasteItem> _stack;
  late List<_CityWasteItem> _allItems;
  _CityWasteItem? _selected;

  // Per-bin sorted tallies
  int _plasticSorted   = 0;
  int _organicSorted   = 0;
  int _eWasteSorted    = 0;
  int _glassSorted     = 0;
  int _metallicSorted  = 0;

  int _sortedCorrectly   = 0;
  int _sortedIncorrectly = 0;

  // ── UI flags ──────────────────────────────────────────────────────────────
  bool _gameOver    = false;
  bool _showResults = false;

  // Merged recycling totals (city + water level)
  int _mergedPlastic   = 0;
  int _mergedMetal     = 0;
  int _mergedOrganic   = 0;
  int _mergedGlass     = 0;
  int _mergedMetallic  = 0;
  int _mergedHazardous = 0;
  int _totalEcoPoints  = 0;

  // Bin flash
  String? _flashBin;
  bool    _flashCorrect = true;
  late AnimationController _flashCtrl;

  // Feedback banner
  String? _feedbackMsg;
  late AnimationController _feedbackCtrl;

  // Results slide-in
  late AnimationController _resultsCtrl;

  // Timer warning pulse
  late AnimationController _warningCtrl;

  // Item tap pop
  late AnimationController _popCtrl;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _buildStack();
    _initAnimations();
  }

  @override
  void dispose() {
    _flashCtrl.dispose();
    _feedbackCtrl.dispose();
    _resultsCtrl.dispose();
    _warningCtrl.dispose();
    _popCtrl.dispose();
    super.dispose();
  }

  // ── Stack construction — mirrors _spawnWaste() exactly ────────────────────

  void _buildStack() {
    final result = WasteCollectionResult.current;
    final rng    = math.Random();

    // All configs matching CityCollectionGame._spawnWaste()
    const allConfigs = [
      // plastic
      (WasteType.plastic,    '🧴', 'Plastic Bottle'),
      (WasteType.plastic,    '🛍️', 'Plastic Bag'),
      (WasteType.plastic,    '🥤', 'Drink Cup'),
      // organic
      (WasteType.organic,    '🍌', 'Banana Peel'),
      (WasteType.organic,    '👟', 'Old Shoe'),
      (WasteType.organic,    '👕', 'Torn Shirt'),
      (WasteType.organic,    '🧦', 'Torn Sock'),
      (WasteType.organic,    '🍎', 'Rotten Food'),
      // electronic
      (WasteType.electronic, '📱', 'Old Phone'),
      (WasteType.electronic, '🔋', 'Battery'),
      (WasteType.electronic, '💡', 'Light Bulb'),
      // glass
      (WasteType.glass,      '🍶', 'Glass Bottle'),
      (WasteType.glass,      '🪟', 'Broken Glass'),
      (WasteType.glass,      'BROKEN_BOTTLE',   'Broken Bottle'),
      (WasteType.glass,      'SHATTERED_GLASS', 'Shattered Glass'),
      // metallic
      (WasteType.metallic,   '🥫', 'Tin Can'),
      (WasteType.metallic,   '🔩', 'Metal Bolt'),
      (WasteType.metallic,   '⚙️', 'Old Gear'),
      (WasteType.metallic,   '🔧', 'Broken Wrench'),
      (WasteType.metallic,   '🪣', 'Metal Bucket'),
    ];

    // Pick n items of a specific WasteType at random from the pool
    List<_CityWasteItem> pick(WasteType t, int n) {
      final pool = allConfigs.where((c) => c.$1 == t).toList()..shuffle(rng);
      return List.generate(n, (i) {
        final cfg = pool[i % pool.length];
        return _CityWasteItem(emoji: cfg.$2, label: cfg.$3, type: cfg.$1);
      });
    }

    final items = <_CityWasteItem>[];

    if (result != null && result.total > 0) {
      // Real collected counts — capped so sorting remains playable
      if (result.plastic    > 0) items.addAll(pick(WasteType.plastic,    result.plastic.clamp(1, 8)));
      if (result.organic    > 0) items.addAll(pick(WasteType.organic,    result.organic.clamp(1, 8)));
      if (result.electronic > 0) items.addAll(pick(WasteType.electronic, result.electronic.clamp(1, 6)));
      if (result.glass      > 0) items.addAll(pick(WasteType.glass,      result.glass.clamp(1, 6)));
      if (result.metallic   > 0) items.addAll(pick(WasteType.metallic,   result.metallic.clamp(1, 8)));
    } else {
      // Fallback representative set
      items
        ..addAll(pick(WasteType.plastic,    3))
        ..addAll(pick(WasteType.organic,    3))
        ..addAll(pick(WasteType.electronic, 2))
        ..addAll(pick(WasteType.glass,      3))
        ..addAll(pick(WasteType.metallic,   3));
    }

    items.shuffle(rng);
    _stack    = items;
    _allItems = List.from(items);
  }

  void _initAnimations() {
    _flashCtrl   = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _feedbackCtrl= AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));
    _resultsCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 550));
    _warningCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))
      ..repeat(reverse: true);
    _popCtrl     = AnimationController(vsync: this, duration: const Duration(milliseconds: 220));
  }

  // ── Timer ─────────────────────────────────────────────────────────────────

  void _startTimer() {
    if (_timerRunning) return;
    _timerRunning = true;
    _tick();
  }

  void _tick() {
    if (!_timerRunning || !mounted) return;
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted || !_timerRunning) return;
      setState(() => _timeLeft = (_timeLeft - 1).clamp(0, _timerMax.toDouble()));
      _timeLeft <= 0 ? _endSorting(timeUp: true) : _tick();
    });
  }

  // ── Sorting logic ─────────────────────────────────────────────────────────

  void _selectItem(_CityWasteItem item) {
    if (_gameOver) return;
    _startTimer();
    HapticFeedback.selectionClick();
    _popCtrl.forward(from: 0);
    setState(() => _selected = (_selected == item) ? null : item);
  }

  void _dropIntoBin(String binKey) {
    final item = _selected;
    if (item == null || _gameOver) return;

    final ok = item.correctBin == binKey;
    HapticFeedback.mediumImpact();

    setState(() {
      _selected = null;
      _stack.remove(item);
      item.isSorted = true;

      if (ok) {
        _sortedCorrectly++;
        switch (binKey) {
          case 'plastic':  _plasticSorted++;  break;
          case 'organic':  _organicSorted++;  break;
          case 'e_waste':  _eWasteSorted++;   break;
          case 'glass':    _glassSorted++;    break;
          case 'metallic': _metallicSorted++; break;
        }
        _triggerFlash(binKey, true);
        _showFeedback('✅  ${item.label}  →  ${_binLabel(binKey)}', true);
      } else {
        _sortedIncorrectly++;
        _triggerFlash(binKey, false);
        _showFeedback(
            '❌  ${item.label}  goes to  ${_binLabel(item.correctBin)}', false);
      }
    });

    if (_stack.isEmpty) {
      Future.delayed(const Duration(milliseconds: 600), () => _endSorting(timeUp: false));
    }
  }

  void _triggerFlash(String key, bool ok) {
    _flashBin     = key;
    _flashCorrect = ok;
    _flashCtrl.forward(from: 0).then((_) {
      if (mounted) setState(() => _flashBin = null);
    });
  }

  void _showFeedback(String msg, bool ok) {
    setState(() => _feedbackMsg = msg);
    _feedbackCtrl.forward(from: 0).then((_) {
      if (mounted) setState(() => _feedbackMsg = null);
    });
  }

  void _endSorting({required bool timeUp}) {
    if (_gameOver) return;
    setState(() { _gameOver = true; _timerRunning = false; });

    final cityResult = WasteCollectionResult.current;
    final cityPts    = cityResult?.totalEcoPoints ?? 0;

    _mergedPlastic   = _plasticSorted  + widget.waterCarryOver.plastic;
    _mergedMetal     = _metallicSorted + widget.waterCarryOver.metal;
    _mergedOrganic   = _organicSorted  + widget.waterCarryOver.organic;
    _mergedGlass     = _glassSorted;
    _mergedMetallic  = _metallicSorted;
    _mergedHazardous = widget.waterCarryOver.hazardous;
    _totalEcoPoints  = cityPts + widget.waterCarryOver.ecoPoints + (_sortedCorrectly * 12);

    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(() => _showResults = true);
      _resultsCtrl.forward(from: 0);
    });
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  double get _accuracy => (_sortedCorrectly + _sortedIncorrectly) > 0
      ? _sortedCorrectly / (_sortedCorrectly + _sortedIncorrectly)
      : 0.0;

  double get _progress => _allItems.isNotEmpty
      ? (_allItems.length - _stack.length) / _allItems.length
      : 0.0;

  String get _timerLabel {
    final t = _timeLeft.toInt().clamp(0, 9999);
    return '${(t ~/ 60).toString().padLeft(2, '0')}:${(t % 60).toString().padLeft(2, '0')}';
  }

  String _binLabel(String k) {
    const m = {
      'plastic': 'Plastic', 'organic': 'Organic', 'e_waste': 'E-Waste',
      'glass': 'Glass', 'metallic': 'Metallic',
    };
    return m[k] ?? k;
  }

  Color _binColor(String k) {
    const m = {
      'plastic': _plasticC, 'organic': _organicC, 'e_waste': _eWasteC,
      'glass': _glassC, 'metallic': _metallicC,
    };
    return m[k] ?? Colors.grey;
  }

  String _binEmoji(String k) {
    const m = {
      'plastic': '🧴', 'organic': '🍌', 'e_waste': '📱',
      'glass': '🍶', 'metallic': '🔩',
    };
    return m[k] ?? '♻️';
  }

  int _binCount(String k) {
    switch (k) {
      case 'plastic':  return _plasticSorted;
      case 'organic':  return _organicSorted;
      case 'e_waste':  return _eWasteSorted;
      case 'glass':    return _glassSorted;
      case 'metallic': return _metallicSorted;
      default:         return 0;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final mq       = MediaQuery.of(context);
    final isMobile = mq.size.width < 600;

    return Scaffold(
      backgroundColor: _bgDeep,
      body: Stack(children: [
        // Night-city facility backdrop
        SizedBox.expand(
          child: CustomPaint(painter: _CityFacilityBgPainter()),
        ),

        SafeArea(
          child: Column(children: [
            _buildTopHUD(isMobile),
            if (!_showResults) ...[
              _buildProgressBar(),
              _buildInstructionHint(isMobile),
              Expanded(child: _buildWastePile(isMobile)),
              _buildBinsRow(isMobile),
              const SizedBox(height: 6),
            ],
          ]),
        ),

        if (_feedbackMsg != null) _buildFeedbackBanner(isMobile),

        if (_showResults) ...[
          Positioned.fill(
            child: IgnorePointer(
              child: Container(color: Colors.black.withValues(alpha: 0.62)),
            ),
          ),
          _buildResultsCard(isMobile),
        ],
      ]),
    );
  }

  // ── Top HUD ───────────────────────────────────────────────────────────────

  Widget _buildTopHUD(bool isMobile) {
    final warn        = _timeLeft < 20;
    final sortedCount = _allItems.length - _stack.length;
    final total       = _allItems.length;

    return Container(
      margin: EdgeInsets.fromLTRB(
          isMobile ? 8 : 12, isMobile ? 6 : 8, isMobile ? 8 : 12, 0),
      padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 10 : 14, vertical: isMobile ? 6 : 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1B2A).withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: Colors.limeAccent.withValues(alpha: 0.28), width: 1.5),
        boxShadow: [BoxShadow(
            color: Colors.limeAccent.withValues(alpha: 0.07),
            blurRadius: 12, spreadRadius: -2)],
      ),
      child: Row(children: [
        const Icon(Icons.delete_rounded, color: Color(0xFF4CAF50), size: 14),
        const SizedBox(width: 5),
        Text('SORTING FACILITY',
            style: GoogleFonts.exo2(
                fontSize: isMobile ? 10 : 11, color: Colors.limeAccent,
                fontWeight: FontWeight.w800, letterSpacing: 1.4)),

        const Spacer(),

        // sorted counter
        _hudChip(Icons.inventory_2_outlined,
            '$sortedCount/$total',
            sortedCount == total && total > 0 ? Colors.limeAccent : Colors.white,
            isMobile),
        const SizedBox(width: 8),

        // accuracy
        _hudChip(Icons.track_changes_rounded,
            '${(_accuracy * 100).toStringAsFixed(0)}%',
            _accuracy >= 0.8
                ? Colors.limeAccent
                : _accuracy >= 0.5 ? Colors.amber : _wrong,
            isMobile),
        const SizedBox(width: 8),

        // timer
        AnimatedBuilder(
          animation: _warningCtrl,
          builder: (_, __) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: warn
                  ? _wrong.withValues(alpha: 0.10 + _warningCtrl.value * 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: warn
                  ? Border.all(
                      color: _wrong.withValues(
                          alpha: 0.40 + _warningCtrl.value * 0.40),
                      width: 1)
                  : null,
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.timer_rounded, size: 13,
                  color: warn ? _wrong : Colors.white54),
              const SizedBox(width: 4),
              Text(_timerLabel,
                  style: GoogleFonts.exo2(
                      fontSize: isMobile ? 15 : 17,
                      fontWeight: FontWeight.w900,
                      color: warn ? _wrong : Colors.white)),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _hudChip(IconData icon, String lbl, Color col, bool isMobile) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: col.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: col.withValues(alpha: 0.30), width: 1),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 11, color: col),
          const SizedBox(width: 4),
          Text(lbl,
              style: GoogleFonts.exo2(
                  fontSize: isMobile ? 11 : 12,
                  fontWeight: FontWeight.w800, color: col)),
        ]),
      );

  // ── Progress bar ──────────────────────────────────────────────────────────

  Widget _buildProgressBar() => Padding(
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: _progress,
            minHeight: 5,
            backgroundColor: Colors.white.withValues(alpha: 0.07),
            valueColor: AlwaysStoppedAnimation(
                _progress >= 1.0 ? Colors.limeAccent : _accent),
          ),
        ),
      );

  // ── Instruction hint ──────────────────────────────────────────────────────

  Widget _buildInstructionHint(bool isMobile) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.touch_app_rounded, size: 13,
                  color: _selected != null ? _accent : Colors.white38),
              const SizedBox(width: 5),
              Text(
                _selected == null
                    ? 'TAP a waste item to select it'
                    : 'TAP the correct bin for  "${_selected!.label}"',
                style: GoogleFonts.exo2(
                    fontSize: isMobile ? 11 : 12,
                    color: _selected != null ? _accent : Colors.white54,
                    fontWeight: FontWeight.w600),
              ),
            ]),
          ),
        ),
      );

  // ── Waste pile ─────────────────────────────────────────────────────────────
  // Seeded random positions/rotations per item so the pile stays stable
  // across rebuilds but looks like a real chaotic heap.
  final Map<String, _PilePos> _pilePositions = {};

  _PilePos _posFor(_CityWasteItem item, double pileW, double pileH, double sz) {
    if (_pilePositions.containsKey(item.id)) return _pilePositions[item.id]!;
    final rng = math.Random(item.id.hashCode);
    final pad = sz * 0.4;
    final pos = _PilePos(
      dx:  pad + rng.nextDouble() * (pileW - sz - pad),
      dy:  pad * 0.5 + rng.nextDouble() * (pileH - sz - pad),
      rot: (rng.nextDouble() - 0.5) * 0.60, // ±~17°
    );
    _pilePositions[item.id] = pos;
    return pos;
  }

  Widget _buildWastePile(bool isMobile) {
    if (_stack.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('✅', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 8),
          Text('All items sorted!',
              style: GoogleFonts.exo2(
                  fontSize: 18, color: Colors.limeAccent,
                  fontWeight: FontWeight.w800)),
        ]),
      );
    }

    final itemSz = isMobile ? 62.0 : 76.0;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Status strip
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
        child: Row(children: [
          Text(
            '${_stack.length} item${_stack.length == 1 ? '' : 's'} in pile',
            style: GoogleFonts.exo2(
                fontSize: isMobile ? 9 : 10, color: Colors.white30,
                fontWeight: FontWeight.w600, letterSpacing: 0.8),
          ),
          const Spacer(),
          if (_selected != null)
            RichText(text: TextSpan(
              style: GoogleFonts.exo2(fontSize: isMobile ? 9 : 10),
              children: [
                const TextSpan(text: 'Selected: ', style: TextStyle(color: Colors.white30)),
                TextSpan(text: _selected!.label,
                    style: TextStyle(color: _selected!.typeColor, fontWeight: FontWeight.w800)),
              ],
            )),
        ]),
      ),

      // The pile — items strewn randomly inside a bounded canvas
      Expanded(
        child: LayoutBuilder(
          builder: (ctx, constraints) {
            final pileW = constraints.maxWidth;
            final pileH = constraints.maxHeight;
            return Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0C1825),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    // Centre glow
                    Positioned.fill(child: Container(
                      decoration: const BoxDecoration(
                        gradient: RadialGradient(
                          center: Alignment(0, 0.15),
                          radius: 0.65,
                          colors: [Color(0x0BFFFFFF), Colors.transparent],
                        ),
                      ),
                    )),
                    // Items — last in list renders on top
                    for (final item in _stack)
                      _buildPileItem(item, pileW, pileH, itemSz),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    ]);
  }

  Widget _buildPileItem(
      _CityWasteItem item, double pileW, double pileH, double itemSz) {
    final sel   = _selected == item;
    final color = item.typeColor;
    final pos   = _posFor(item, pileW, pileH, itemSz);

    return Positioned(
      left: pos.dx,
      top:  pos.dy,
      child: GestureDetector(
        onTap: () => _selectItem(item),
        child: AnimatedScale(
          scale:    sel ? 1.22 : 1.0,
          duration: const Duration(milliseconds: 200),
          curve:    Curves.easeOutBack,
          child: Transform.rotate(
            // snap upright when selected so player sees it clearly
            angle: sel ? 0.0 : pos.rot,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: itemSz, height: itemSz,
              decoration: BoxDecoration(
                color: sel
                    ? color.withValues(alpha: 0.22)
                    : const Color(0xFF1A2A3A).withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: sel ? color : color.withValues(alpha: 0.38),
                    width: sel ? 2.5 : 1.5),
                boxShadow: [BoxShadow(
                  color: sel
                      ? color.withValues(alpha: 0.55)
                      : Colors.black.withValues(alpha: 0.55),
                  blurRadius: sel ? 20 : 6,
                  spreadRadius: sel ? 3 : 0,
                  offset: sel ? Offset.zero : const Offset(2, 3),
                )],
              ),
              child: Stack(children: [
                // Glow fill
                Positioned.fill(child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(11),
                    gradient: RadialGradient(
                      colors: [
                        color.withValues(alpha: sel ? 0.22 : 0.06),
                        Colors.transparent,
                      ],
                      radius: 0.9,
                    ),
                  ),
                )),

                // Icon only — no label
                Center(child: _buildItemIcon(item, itemSz * 0.60)),

                // Type-colour dot (WasteToken corner dot)
                Positioned(
                  bottom: 4, left: 4,
                  child: Container(
                    width: 6, height: 6,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                ),

                // Selected check badge
                if (sel)
                  Positioned(
                    top: 3, right: 3,
                    child: Container(
                      width: 16, height: 16,
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                      child: const Icon(Icons.check_rounded,
                          color: Colors.white, size: 10),
                    ),
                  ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItemIcon(_CityWasteItem item, double iconSz) {
    if (item.emoji == 'BROKEN_BOTTLE') {
      return CustomPaint(
          size: Size(iconSz, iconSz),
          painter: _GlassIconPainter(shattered: false));
    }
    if (item.emoji == 'SHATTERED_GLASS') {
      return CustomPaint(
          size: Size(iconSz, iconSz),
          painter: _GlassIconPainter(shattered: true));
    }
    return Text(item.emoji, style: TextStyle(fontSize: iconSz * 0.72));
  }



  // ── Bins row ──────────────────────────────────────────────────────────────

  static const _binKeys = ['plastic', 'organic', 'e_waste', 'glass', 'metallic'];

  Widget _buildBinsRow(bool isMobile) => Container(
        padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 2 : 8, vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: _binKeys
              .map((k) => Expanded(child: _buildBin(k, isMobile)))
              .toList(),
        ),
      );

  Widget _buildBin(String key, bool isMobile) {
    final color     = _binColor(key);
    final isTarget  = _selected?.correctBin == key;
    final isFlashing = _flashBin == key;

    return GestureDetector(
      onTap: () => _dropIntoBin(key),
      child: AnimatedBuilder(
        animation: _flashCtrl,
        builder: (_, __) {
          final fa = isFlashing ? (1.0 - _flashCtrl.value) * 0.50 : 0.0;

          return AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: EdgeInsets.symmetric(horizontal: isMobile ? 1.5 : 3),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  color.withValues(alpha: isTarget ? 0.38 : 0.14),
                  color.withValues(alpha: isTarget ? 0.22 : 0.07),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: isTarget ? color : color.withValues(alpha: 0.40),
                  width: isTarget ? 2.5 : 1.5),
              boxShadow: [
                if (fa > 0)
                  BoxShadow(
                      color: (_flashCorrect ? _correct : _wrong)
                          .withValues(alpha: fa),
                      blurRadius: 18, spreadRadius: 2),
                if (isTarget)
                  BoxShadow(
                      color: color.withValues(alpha: 0.30), blurRadius: 12),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 3 : 6,
                  vertical: isMobile ? 6 : 8),
              child: Column(mainAxisSize: MainAxisSize.min, children: [

                // 3-D bin body
                _Bin3DWidget(
                  color: color,
                  height: isMobile ? 42.0 : 54.0,
                  flashColor: isFlashing
                      ? (_flashCorrect ? _correct : _wrong)
                          .withValues(alpha: fa)
                      : null,
                  isTarget: isTarget,
                ),

                const SizedBox(height: 4),

                // Exact emoji from bin config (same icon used on road)
                Text(_binEmoji(key),
                    style: TextStyle(fontSize: isMobile ? 16 : 20)),
                const SizedBox(height: 1),

                // Bin label
                Text(_binLabel(key),
                    style: GoogleFonts.exo2(
                        fontSize: isMobile ? 7.5 : 8.5, color: color,
                        fontWeight: FontWeight.w800, letterSpacing: 0.3),
                    textAlign: TextAlign.center),

                // Sorted count badge
                if (_binCount(key) > 0) ...[
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('${_binCount(key)} ✓',
                        style: GoogleFonts.exo2(
                            fontSize: isMobile ? 7 : 8,
                            color: Colors.white,
                            fontWeight: FontWeight.w700)),
                  ),
                ],

                // Drop-here arrow
                if (isTarget) ...[
                  const SizedBox(height: 2),
                  Icon(Icons.arrow_downward_rounded,
                      color: color, size: isMobile ? 11 : 13),
                ],
              ]),
            ),
          );
        },
      ),
    );
  }

  // ── Feedback banner ───────────────────────────────────────────────────────

  Widget _buildFeedbackBanner(bool isMobile) {
    final isOk = _feedbackMsg?.startsWith('✅') ?? false;
    return Positioned(
      top: isMobile ? 70 : 88,
      left: 16, right: 16,
      child: AnimatedBuilder(
        animation: _feedbackCtrl,
        builder: (_, __) {
          final fade = (1.0 - ((_feedbackCtrl.value - 0.60).clamp(0.0, 0.40) / 0.40));
          return Opacity(
            opacity: fade,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: (isOk ? _correct : _wrong).withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: isOk ? _correct : _wrong, width: 1.5),
                boxShadow: [BoxShadow(
                    color: (isOk ? _correct : _wrong).withValues(alpha: 0.28),
                    blurRadius: 12)],
              ),
              child: Text(_feedbackMsg ?? '',
                  style: GoogleFonts.exo2(
                      fontSize: isMobile ? 12 : 13,
                      color: isOk ? _correct : _wrong,
                      fontWeight: FontWeight.w800),
                  textAlign: TextAlign.center),
            ),
          );
        },
      ),
    );
  }

  // ── Results card ──────────────────────────────────────────────────────────

  Widget _buildResultsCard(bool isMobile) {
    final acc       = (_accuracy * 100).toStringAsFixed(0);
    final excellent = _accuracy >= 0.85;
    final good      = _accuracy >= 0.60;
    final heading   = excellent ? 'EXCELLENT SORTING!' : good ? 'GOOD JOB!' : 'SORTING COMPLETE';
    final hColor    = excellent ? Colors.limeAccent : good ? Colors.amber : _wrong;

    return Positioned.fill(
      child: Center(
        child: AnimatedBuilder(
          animation: _resultsCtrl,
          builder: (_, __) => Transform.scale(
            scale: Curves.elasticOut.transform(
                _resultsCtrl.value.clamp(0.0, 1.0)),
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 12 : 36, vertical: 16),
              child: Container(
                padding: EdgeInsets.all(isMobile ? 16 : 24),
                decoration: BoxDecoration(
                  color: _panel,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                      color: hColor.withValues(alpha: 0.45), width: 2),
                  boxShadow: [BoxShadow(
                      color: hColor.withValues(alpha: 0.18),
                      blurRadius: 28, spreadRadius: 2)],
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [

                  // Header
                  const Icon(Icons.emoji_events_rounded,
                      color: Colors.amber, size: 46),
                  const SizedBox(height: 6),
                  Text('🏙️  CITY SORTING COMPLETE!',
                      style: TextStyle(color: Colors.white, fontSize: isMobile ? 17 : 20,
                          fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                  const SizedBox(height: 2),
                  Text(heading,
                      style: GoogleFonts.exo2(
                          fontSize: isMobile ? 14 : 17,
                          fontWeight: FontWeight.w900,
                          color: hColor, letterSpacing: 1.0)),
                  const SizedBox(height: 14),

                  // Score chips
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    _statChip('$acc%',            'ACCURACY', hColor,   isMobile),
                    const SizedBox(width: 10),
                    _statChip('$_sortedCorrectly', 'CORRECT',  _correct, isMobile),
                    const SizedBox(width: 10),
                    _statChip('$_sortedIncorrectly','WRONG',   _wrong,   isMobile),
                  ]),

                  const SizedBox(height: 16),

                  // City sorted breakdown — exact _WasteRow style
                  _sectionLabel('Waste Collected by Category', Colors.amber, isMobile),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D1B2A),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Column(children: [
                      _WasteResultRow('🧴', 'Plastic',    _plasticSorted,  _plasticC,  isMobile),
                      _WasteResultRow('🍌', 'Organic',    _organicSorted,  _organicC,  isMobile),
                      _WasteResultRow('📱', 'E-Waste',    _eWasteSorted,   _eWasteC,   isMobile),
                      _WasteResultRow('🍶', 'Glass / Broken', _glassSorted, _glassC,   isMobile),
                      _WasteResultRow('🔩', 'Metallic',   _metallicSorted, _metallicC, isMobile),
                    ]),
                  ),

                  // Water level carry-over
                  if (widget.waterCarryOver.totalItems > 0) ...[
                    const SizedBox(height: 14),
                    _sectionLabel('💧  Water Level Carry-Over (Level 2)',
                        const Color(0xFF42A5F5), isMobile),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D1B2A),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: const Color(0xFF42A5F5).withValues(alpha: 0.30)),
                      ),
                      child: Column(children: [
                        _WasteResultRow('♻️', 'Plastic (L2)',   widget.waterCarryOver.plastic,   _plasticC,  isMobile),
                        _WasteResultRow('🔧', 'Metal (L2)',     widget.waterCarryOver.metal,     _metallicC, isMobile),
                        _WasteResultRow('🌿', 'Organic (L2)',   widget.waterCarryOver.organic,   _organicC,  isMobile),
                        _WasteResultRow('☣️', 'Hazardous (L2)', widget.waterCarryOver.hazardous, _eWasteC,   isMobile),
                      ]),
                    ),
                  ],

                  const SizedBox(height: 14),

                  // Grand total
                  Container(height: 1.5,
                    decoration: BoxDecoration(gradient: LinearGradient(colors: [
                      Colors.transparent, _accent.withValues(alpha: 0.5), Colors.transparent,
                    ]))),
                  const SizedBox(height: 12),
                  _sectionLabel('♻️  Ready for Recycling (Grand Total)',
                      Colors.limeAccent, isMobile),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.limeAccent.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: Colors.limeAccent.withValues(alpha: 0.22)),
                    ),
                    child: Column(children: [
                      if (_mergedPlastic   > 0) _WasteResultRow('🧴', 'Plastic',   _mergedPlastic,   _plasticC,  isMobile, highlight: true),
                      if (_mergedMetal     > 0) _WasteResultRow('🔧', 'Metal',     _mergedMetal,     _metallicC, isMobile, highlight: true),
                      if (_mergedOrganic   > 0) _WasteResultRow('🍌', 'Organic',   _mergedOrganic,   _organicC,  isMobile, highlight: true),
                      if (_mergedGlass     > 0) _WasteResultRow('🍶', 'Glass',     _mergedGlass,     _glassC,    isMobile, highlight: true),
                      if (_mergedMetallic  > 0) _WasteResultRow('🔩', 'Metallic',  _mergedMetallic,  _metallicC, isMobile, highlight: true),
                      if (_mergedHazardous > 0) _WasteResultRow('☣️', 'Hazardous', _mergedHazardous, _eWasteC,   isMobile, highlight: true),
                    ]),
                  ),

                  const SizedBox(height: 14),

                  // Eco-points — same gradient card as city collection
                  Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 14, horizontal: 20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)]),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: Colors.limeAccent.withValues(alpha: 0.5),
                          width: 1.5),
                    ),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                      const Icon(Icons.eco_rounded,
                          color: Colors.limeAccent, size: 32),
                      const SizedBox(width: 12),
                      Column(crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        const Text('TOTAL ECO-POINTS',
                            style: TextStyle(color: Colors.white60,
                                fontSize: 11, letterSpacing: 1.5)),
                        Text('$_totalEcoPoints pts',
                            style: const TextStyle(
                                color: Colors.limeAccent,
                                fontSize: 28, fontWeight: FontWeight.bold)),
                      ]),
                    ]),
                  ),

                  const SizedBox(height: 18),

                  // Proceed button — same style as city collection proceed
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context, {
                        'plastic':   _mergedPlastic,
                        'metal':     _mergedMetal,
                        'organic':   _mergedOrganic,
                        'glass':     _mergedGlass,
                        'metallic':  _mergedMetallic,
                        'hazardous': _mergedHazardous,
                        'ecoPoints': _totalEcoPoints,
                        'accuracy':  (_accuracy * 100).round(),
                      }),
                      icon: const Icon(Icons.arrow_forward_rounded),
                      label: Text('PROCEED TO SORTING FACILITY',
                          style: GoogleFonts.exo2(
                              fontSize: isMobile ? 13 : 15,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4CAF50),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 8,
                        shadowColor: const Color(0xFF4CAF50),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Result helpers ────────────────────────────────────────────────────────

  Widget _sectionLabel(String text, Color color, bool isMobile) =>
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 24, height: 1.5, color: color.withValues(alpha: 0.4)),
        const SizedBox(width: 8),
        Text(text,
            style: TextStyle(color: Colors.white70,
                fontSize: isMobile ? 11 : 12,
                fontWeight: FontWeight.bold, letterSpacing: 1)),
        const SizedBox(width: 8),
        Container(width: 24, height: 1.5, color: color.withValues(alpha: 0.4)),
      ]);

  Widget _statChip(String val, String lbl, Color color, bool isMobile) =>
      Container(
        padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 10 : 16,
            vertical: isMobile ? 7 : 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: color.withValues(alpha: 0.35), width: 1.5),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(val,
              style: GoogleFonts.exo2(
                  fontSize: isMobile ? 18 : 23,
                  fontWeight: FontWeight.w900, color: color)),
          Text(lbl,
              style: GoogleFonts.exo2(
                  fontSize: 8, color: color.withValues(alpha: 0.65),
                  fontWeight: FontWeight.w700, letterSpacing: 0.8)),
        ]),
      );
}

// ══════════════════════════════════════════════════════════════════════════════
//  _WasteResultRow — same pattern as _WasteRow in city_collection_screen
// ══════════════════════════════════════════════════════════════════════════════

class _WasteResultRow extends StatelessWidget {
  final String emoji, label;
  final int    count;
  final Color  color;
  final bool   isMobile;
  final bool   highlight;

  const _WasteResultRow(
      this.emoji, this.label, this.count, this.color, this.isMobile,
      {this.highlight = false});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Text(emoji, style: TextStyle(fontSize: isMobile ? 14 : 16)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label,
                style: TextStyle(
                    color: Colors.white70,
                    fontSize: isMobile ? 12 : 13,
                    fontWeight:
                        highlight ? FontWeight.w700 : FontWeight.normal)),
          ),
          SizedBox(
            width: isMobile ? 70 : 100,
            child: LinearProgressIndicator(
              value: count > 0 ? (count / 10).clamp(0.0, 1.0) : 0,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 5,
            ),
          ),
          const SizedBox(width: 8),
          Text('$count',
              style: TextStyle(
                  color: highlight ? color : Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: isMobile ? 14 : 15)),
        ]),
      );
}

// ══════════════════════════════════════════════════════════════════════════════
//  3-D BIN WIDGET
// ══════════════════════════════════════════════════════════════════════════════

class _Bin3DWidget extends StatelessWidget {
  final Color  color;
  final double height;
  final Color? flashColor;
  final bool   isTarget;

  const _Bin3DWidget({
    required this.color,
    required this.height,
    this.flashColor,
    this.isTarget = false,
  });

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size(double.infinity, height),
        painter: _Bin3DPainter(
            color: color, flashColor: flashColor, isTarget: isTarget),
      );
}

class _Bin3DPainter extends CustomPainter {
  final Color  color;
  final Color? flashColor;
  final bool   isTarget;

  const _Bin3DPainter(
      {required this.color, this.flashColor, this.isTarget = false});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Drop shadow
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.06, h * 0.88, w * 0.88, 6),
          const Radius.circular(3)),
      Paint()..color = Colors.black.withValues(alpha: 0.40),
    );

    // Body
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.06, h * 0.25, w * 0.88, h * 0.63),
          const Radius.circular(7)),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, color.withValues(alpha: 0.50)],
        ).createShader(Rect.fromLTWH(0, h * 0.25, w, h * 0.63)),
    );

    // Lid
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(-w * 0.02, h * 0.14, w * 1.04, h * 0.16),
          const Radius.circular(5)),
      Paint()..color = color.withValues(alpha: 0.88),
    );

    // Lid-to-body shadow line
    canvas.drawRect(
      Rect.fromLTWH(w * 0.06, h * 0.295, w * 0.88, 3),
      Paint()..color = Colors.black.withValues(alpha: 0.22),
    );

    // Recycle symbol
    _drawRecycle(canvas, w / 2, h * 0.59, h * 0.12);

    // Flash
    if (flashColor != null) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.06, h * 0.25, w * 0.88, h * 0.63),
            const Radius.circular(7)),
        Paint()..color = flashColor!,
      );
    }

    // Target highlight
    if (isTarget) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.06, h * 0.25, w * 0.88, h * 0.63),
            const Radius.circular(7)),
        Paint()..color = Colors.white.withValues(alpha: 0.12),
      );
    }
  }

  void _drawRecycle(Canvas canvas, double cx, double cy, double r) {
    final p = Paint()
      ..color = Colors.white.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 3; i++) {
      final a  = (i / 3) * math.pi * 2 - math.pi / 2;
      final x1 = cx + math.cos(a) * r;
      final y1 = cy + math.sin(a) * r;
      final x2 = cx + math.cos(a + math.pi * 2 / 3) * r;
      final y2 = cy + math.sin(a + math.pi * 2 / 3) * r;
      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), p);
    }
  }

  @override
  bool shouldRepaint(covariant _Bin3DPainter old) =>
      old.flashColor != flashColor || old.isTarget != isTarget;
}

// ══════════════════════════════════════════════════════════════════════════════
//  GLASS ICON PAINTER — direct port of WasteToken._drawBrokenBottleIcon /
//  _drawShatteredGlassIcon, scaled to the card size.
// ══════════════════════════════════════════════════════════════════════════════

class _GlassIconPainter extends CustomPainter {
  final bool shattered;
  const _GlassIconPainter({required this.shattered});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width  / 2;
    final cy = size.height / 2;
    // Scale factor: WasteToken used a 26-px circle; here the canvas is cx wide
    final s  = cx / 13.0;
    shattered ? _drawShattered(canvas, cx, cy, s) : _drawBrokenBottle(canvas, cx, cy, s);
  }

  void _drawBrokenBottle(Canvas canvas, double cx, double cy, double s) {
    final stroke = Paint()
      ..color = const Color(0xFF80DEEA)
      ..strokeWidth = 1.5 * s
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final fill = Paint()..color = const Color(0x5500BCD4);

    final body = Path()
      ..moveTo(cx - 4*s, cy - 8*s)
      ..lineTo(cx - 5*s, cy + 2*s)
      ..lineTo(cx - 2*s, cy + 8*s)
      ..lineTo(cx + 3*s, cy + 7*s)
      ..lineTo(cx + 5*s, cy + 1*s)
      ..lineTo(cx + 4*s, cy - 7*s)
      ..close();
    canvas.drawPath(body, fill);
    canvas.drawPath(body, stroke);

    canvas.drawLine(Offset(cx-2*s, cy-8*s), Offset(cx-1*s, cy-11*s), stroke);
    canvas.drawLine(Offset(cx+2*s, cy-7*s), Offset(cx+1*s, cy-11*s), stroke);

    final crack = Paint()
      ..color = const Color(0xBBE0F7FA)
      ..strokeWidth = s
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(cx,       cy-4*s), Offset(cx-3*s, cy+2*s), crack);
    canvas.drawLine(Offset(cx,       cy-4*s), Offset(cx+4*s, cy+3*s), crack);
    canvas.drawLine(Offset(cx+4*s,   cy+3*s), Offset(cx+2*s, cy+7*s), crack);

    final shard = Paint()..color = const Color(0xAA80DEEA);
    for (final off in [
      Offset(cx-7*s, cy+5*s), Offset(cx+7*s, cy+4*s), Offset(cx-5*s, cy-2*s),
    ]) {
      final sh = Path()
        ..moveTo(off.dx, off.dy - 3*s)
        ..lineTo(off.dx - 2.5*s, off.dy + 3*s)
        ..lineTo(off.dx + 2.5*s, off.dy + 2*s)
        ..close();
      canvas.drawPath(sh, shard);
      canvas.drawPath(sh,
        Paint()..color = const Color(0x8800BCD4)
            ..style = PaintingStyle.stroke..strokeWidth = 0.8*s);
    }
  }

  void _drawShattered(Canvas canvas, double cx, double cy, double s) {
    final glassBase = Paint()..color = const Color(0x3300E5FF);
    final glassEdge = Paint()
      ..color = const Color(0xFF80DEEA)
      ..strokeWidth = 1.2*s
      ..style = PaintingStyle.stroke;
    final crack = Paint()
      ..color = const Color(0xBBE0F7FA)
      ..strokeWidth = s
      ..strokeCap = StrokeCap.round;

    final pane = Path()
      ..moveTo(cx-9*s, cy-7*s)
      ..lineTo(cx+5*s, cy-9*s)
      ..lineTo(cx+9*s, cy-2*s)
      ..lineTo(cx+7*s, cy+8*s)
      ..lineTo(cx-4*s, cy+9*s)
      ..lineTo(cx-9*s, cy+3*s)
      ..close();
    canvas.drawPath(pane, glassBase);
    canvas.drawPath(pane, glassEdge);

    final impact = Offset(cx+s, cy);
    for (final r in [
      Offset(cx-8*s, cy-5*s), Offset(cx+4*s, cy-8*s),
      Offset(cx+8*s, cy+2*s), Offset(cx+5*s, cy+7*s),
      Offset(cx-3*s, cy+8*s), Offset(cx-8*s, cy+2*s),
    ]) { canvas.drawLine(impact, r, crack); }

    canvas.drawLine(Offset(cx-3*s, cy-3*s), Offset(cx-7*s, cy-s),   crack);
    canvas.drawLine(Offset(cx+4*s, cy-2*s), Offset(cx+7*s, cy-6*s), crack);
    canvas.drawLine(Offset(cx+2*s, cy+4*s), Offset(cx-2*s, cy+7*s), crack);

    final shardP = Paint()..color = const Color(0x8840C4FF);
    for (final off in [
      Offset(cx-11*s, cy-4*s), Offset(cx+10*s, cy+4*s),
    ]) {
      final sh = Path()
        ..moveTo(off.dx, off.dy - 2.5*s)
        ..lineTo(off.dx - 2*s, off.dy + 3*s)
        ..lineTo(off.dx + 3*s, off.dy + s)
        ..close();
      canvas.drawPath(sh, shardP);
    }
  }

  @override
  bool shouldRepaint(covariant _GlassIconPainter old) =>
      old.shattered != shattered;
}

// ══════════════════════════════════════════════════════════════════════════════
//  CITY FACILITY BACKGROUND PAINTER
//  Matches the dark city night aesthetic of CityWorldRenderer
// ══════════════════════════════════════════════════════════════════════════════

class _CityFacilityBgPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Sky — same gradient as CityWorldRenderer
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1A1A2E), Color(0xFF16213E), Color(0xFF1A2438)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    // Building silhouettes
    final bPaint = Paint()..color = const Color(0xFF0A1020);
    const buildings = [
      [0.00, 0.20, 0.09, 0.28], [0.08, 0.13, 0.07, 0.23],
      [0.16, 0.09, 0.08, 0.27], [0.25, 0.16, 0.07, 0.24],
      [0.33, 0.07, 0.07, 0.28], [0.41, 0.12, 0.09, 0.24],
      [0.51, 0.08, 0.08, 0.29], [0.60, 0.14, 0.07, 0.24],
      [0.68, 0.10, 0.08, 0.27], [0.77, 0.16, 0.06, 0.22],
      [0.84, 0.11, 0.08, 0.26], [0.93, 0.14, 0.07, 0.24],
    ];
    for (final b in buildings) {
      final x = b[0] * size.width;
      final y = b[1] * size.height;
      final w = b[2] * size.width;
      final h = b[3] * size.height;
      canvas.drawRect(Rect.fromLTWH(x, y, w, h), bPaint);
      final winP = Paint()
          ..color = const Color(0xFFFFAA44).withValues(alpha: 0.18);
      for (double wy = y + 5; wy < y + h - 4; wy += 9) {
        for (double wx = x + 4; wx < x + w - 4; wx += 8) {
          if (math.Random(wx.toInt() * 13 + wy.toInt()).nextDouble() > 0.50) {
            canvas.drawRect(Rect.fromLTWH(wx, wy, 5, 5), winP);
          }
        }
      }
    }

    // Facility floor
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.40, size.width, size.height * 0.60),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF111E2D), Color(0xFF0C1520)],
        ).createShader(Rect.fromLTWH(
            0, size.height * 0.40, size.width, size.height * 0.60)),
    );

    // Conveyor belt strip — same dark tones as road
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.41, size.width, 16),
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF242424), Color(0xFF303030), Color(0xFF242424)],
        ).createShader(
            Rect.fromLTWH(0, size.height * 0.41, size.width, 16)),
    );
    final div = Paint()..color = const Color(0xFF1A1A1A)..strokeWidth = 2;
    for (double bx = 0; bx < size.width; bx += 22) {
      canvas.drawLine(Offset(bx, size.height * 0.41),
          Offset(bx, size.height * 0.41 + 16), div);
    }

    // Floor grid
    final gP = Paint()
        ..color = Colors.white.withValues(alpha: 0.025)..strokeWidth = 1;
    for (double gx = 0; gx < size.width; gx += 40) {
      canvas.drawLine(Offset(gx, size.height * 0.40), Offset(gx, size.height), gP);
    }
    for (double gy = size.height * 0.40; gy < size.height; gy += 40) {
      canvas.drawLine(Offset(0, gy), Offset(size.width, gy), gP);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ══════════════════════════════════════════════════════════════════════════════
//  PILE POSITION — random offset + rotation for each item in the heap
// ══════════════════════════════════════════════════════════════════════════════

class _PilePos {
  final double dx, dy, rot;
  const _PilePos({required this.dx, required this.dy, required this.rot});
}