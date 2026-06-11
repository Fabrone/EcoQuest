import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:ecoquest/game/level6/degraded_park_screen.dart';
import 'package:ecoquest/game/level6/pond_cleaning_game_screen.dart';
import 'package:flame/components.dart' hide Matrix4;
import 'package:flame/game.dart' hide Matrix4;
import 'package:flutter/material.dart' hide Matrix4;
import 'package:flutter/services.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  HABITAT CLEANUP — Phase 1 only (Waste Collection)
//  10 litter types · 4-bin sort · First-hint / Memory-recall · Minimum gate
//  Completes → PondCleaningGameScreen
// ══════════════════════════════════════════════════════════════════════════════

class HabitatCleanupResult {
  final int    litterCollected;
  final int    correctSorts;
  final int    wrongSorts;        // ── NEW: Tracks failed sort attempts ──
  final int    ecoPoints;
  final int    maxCombo;
  final int    scanStreakBonus;
  final int    ecoDiscoveriesFound;
  final bool   timeBonusCollected;
  final bool   meetsMinimum;
  final int    minimumLitterRequired;
  final String endReason;
  final LevelCompletionState completionState;

  const HabitatCleanupResult({
    required this.litterCollected,
    required this.correctSorts,
    required this.wrongSorts,      // ── NEW: Required field ──
    required this.ecoPoints,
    this.maxCombo              = 1,
    this.scanStreakBonus        = 0,
    this.ecoDiscoveriesFound   = 0,
    this.timeBonusCollected    = false,
    this.meetsMinimum          = false,
    this.minimumLitterRequired = 9,
    this.endReason             = 'Level completed.',
    this.completionState       = LevelCompletionState.failed,
  });

  int get accuracyPct {
    final totalAttempts = correctSorts + wrongSorts;
    return totalAttempts == 0 ? 0 : ((correctSorts / totalAttempts) * 100).round();
  }

  String get performanceGrade {
    final totalAttempts = correctSorts + wrongSorts;
    final accuracy = totalAttempts == 0 ? 0 : (correctSorts / totalAttempts);

    if (correctSorts >= 14 && accuracy >= 0.85) return 'MASTER ECOLOGIST';
    if (correctSorts >= 10 && accuracy >= 0.75) return 'HABITAT GUARDIAN';
    if (correctSorts >= 6  && accuracy >= 0.60) return 'ECO FIELD AGENT';
    if (correctSorts >= 3)                      return 'ECO LEARNER';
    return 'JUNIOR RANGER';
  }

  String get performanceSummary {
    final lines = <String>[];
    if (ecoDiscoveriesFound > 0) lines.add('Found $ecoDiscoveriesFound hidden Eco-Discovery marker(s)');
    if (timeBonusCollected)      lines.add('Time Bonus item collected — earned +8 s');
    if (maxCombo >= 4)           lines.add('$maxCombo-action combo achieved — 3× point multiplier!');
    if (scanStreakBonus > 0)     lines.add('Scan streak bonus: +$scanStreakBonus pts');
    return lines.isEmpty
        ? 'Collect and sort all litter to maximise your score.'
        : lines.join('\n');
  }

  static HabitatCleanupResult? current;
}

enum LevelCompletionState { failed, moderate, fullCompletion }

// ── Scan result (litter only) ───────────────────────────────────────────────
class HabitatScanResult {
  final String typeName;
  final String ecoFact;
  final String correctAction;
  final String icon;
  final Color  color;
  final bool   hasEcoDiscovery;
  final String discoveryFact;

  const HabitatScanResult({
    required this.typeName,
    required this.ecoFact,
    required this.correctAction,
    required this.icon,
    required this.color,
    this.hasEcoDiscovery = false,
    this.discoveryFact   = '',
  });

  static const _litterFacts = {
    LitterType.plasticBottle: [
      'A plastic bottle takes 450 years to decompose. Every bottle collected today protects Karura\'s wildlife for centuries.',
      'Plastic bottles fragment into microplastics that enter the soil food chain, harming birds and small mammals.',
    ],
    LitterType.polythene: [
      'Polythene bags clog waterways and suffocate soil organisms. Kenya banned them in 2017, yet remnants persist in urban parks.',
      'When buried, polythene blocks root growth and can remain intact for over 1,000 years in forest soil.',
    ],
    LitterType.foodWrap: [
      'Plastic food wraps leach chemicals into soil and fragment into microplastics that earthworms and birds ingest.',
      'Used food wraps attract pests and spread bacteria when left in natural habitats like Karura Forest.',
    ],
    LitterType.glassBottle: [
      'A glass bottle can be washed and reused up to 50 times — far better than melting it down for recycling.',
      'Broken glass in Karura Forest injures birds and small mammals. Proper collection keeps habitats safe.',
    ],
    LitterType.metalCan: [
      'Recycling one metal can saves enough energy to power a television for 3 hours.',
      'Rusting metal cans leach zinc and iron into soil, acidifying it and poisoning ground-nesting birds.',
    ],
    LitterType.paper: [
      'Recycling one ton of paper saves 17 mature trees and 7,000 gallons of water.',
      'While paper biodegrades, landfill burial produces methane — a greenhouse gas 25× stronger than CO₂.',
    ],
    LitterType.fruitPeel: [
      'Fruit peels compost in 2–4 weeks, returning nutrients to the soil and feeding beneficial microbes.',
      'When trapped in plastic bags, organic waste like peels produces methane instead of enriching soil.',
    ],
    LitterType.clothes: [
      'Textile waste can take over 200 years to decompose. Repurposing old clothes cuts landfill volume dramatically.',
      'Synthetic fabrics release microfibres into waterways. Collection for reuse protects Karura\'s ponds.',
    ],
    LitterType.shoes: [
      'Torn shoes contain rubber and synthetic foam that last centuries in landfills. Donation or repurposing is key.',
      'Shoe rubber can be ground into playground surfaces or insulation — never truly "waste" if collected.',
    ],
    LitterType.eWaste: [
      'One discarded phone battery can contaminate 600,000 liters of groundwater with lead and mercury.',
      'E-waste contains precious metals like gold and copper. Proper harmful-waste disposal enables safe recovery.',
    ],
  };

  static const _discoveryFacts = {
    LitterType.plasticBottle:
      '🏺 Cultural Marker Found! Karura Forest was the site of Wangari Maathai\'s famous stand — local women planted trees here to protest litter and deforestation under the Green Belt Movement.',
    LitterType.polythene:
      '🌿 Cultural Marker Found! The Kikuyu held "Itwika" renewal ceremonies in sacred Karura groves — community clean-ups that maintained the forest\'s spiritual and ecological purity.',
    LitterType.foodWrap:
      '🌾 Cultural Marker Found! Karura\'s original Kikuyu custodians composted organic waste in communal "githiga" mounds to feed the forest floor — an ancestral form of park stewardship.',
    LitterType.glassBottle:
      '🪶 Cultural Marker Found! Maasai elders near Karura used crushed glass from trading caravans as a soil amendment — a tradition now echoed in modern glass-recycling composites.',
    LitterType.metalCan:
      '⚙️ Cultural Marker Found! Early Nairobi metalworkers traded scrap at Karura\'s edge, melting cans into tools — an early recycling economy that kept metal out of the forest.',
    LitterType.paper:
      '📜 Cultural Marker Found! Before paper, Kikuyu elders recorded wisdom on bark cloth. The shift to paper was called "kwandikira mbere" — writing the future while honouring the past.',
    LitterType.fruitPeel:
      '🍃 Cultural Marker Found! Kikuyu farmers buried fruit peels at the base of "mukinduri" trees as natural fertiliser — a practice that kept Karura\'s soil rich for generations.',
    LitterType.clothes:
      '👘 Cultural Marker Found! The "muthaka" tradition saw torn clothes woven into rugs and mats. Nothing was wasted — textiles lived many lives before returning to the soil.',
    LitterType.shoes:
      '👣 Cultural Marker Found! Elders repaired leather sandals with forest fibre. "Guturira nguo" — the art of repair — was a moral duty, not just practicality.',
    LitterType.eWaste:
      '🔌 Cultural Marker Found! Early telephone wires in Nairobi used copper from recycled metal. Karura\'s clean-up legacy teaches us that today\'s e-waste is tomorrow\'s resource.',
  };

  static HabitatScanResult forLitter(
    LitterType t, {bool withDiscovery = false, int variant = 0}) {
    final facts = _litterFacts[t]!;
    final fact  = facts[variant % facts.length];
    switch (t) {
      case LitterType.plasticBottle:
        return HabitatScanResult(
          typeName: 'Plastic Bottle', ecoFact: fact,
          correctAction: 'Sort into ♻️ Recyclable Bin',
          icon: '🥤', color: const Color(0xFF29B6F6),
          hasEcoDiscovery: withDiscovery,
          discoveryFact: withDiscovery ? (_discoveryFacts[t] ?? '') : '',
        );
      case LitterType.polythene:
        return HabitatScanResult(
          typeName: 'Polythene Bag', ecoFact: fact,
          correctAction: 'Sort into ♻️ Recyclable Bin',
          icon: '🛍️', color: const Color(0xFF42A5F5),
          hasEcoDiscovery: withDiscovery,
          discoveryFact: withDiscovery ? (_discoveryFacts[t] ?? '') : '',
        );
      case LitterType.foodWrap:
        return HabitatScanResult(
          typeName: 'Food Wrap', ecoFact: fact,
          correctAction: 'Sort into ♻️ Recyclable Bin',
          icon: '🥡', color: const Color(0xFF26C6DA),
          hasEcoDiscovery: withDiscovery,
          discoveryFact: withDiscovery ? (_discoveryFacts[t] ?? '') : '',
        );
      case LitterType.glassBottle:
        return HabitatScanResult(
          typeName: 'Glass Bottle', ecoFact: fact,
          correctAction: 'Sort into 🔄 Reusable Bin',
          icon: '🍾', color: const Color(0xFFAB47BC),
          hasEcoDiscovery: withDiscovery,
          discoveryFact: withDiscovery ? (_discoveryFacts[t] ?? '') : '',
        );
      case LitterType.metalCan:
        return HabitatScanResult(
          typeName: 'Metal Can', ecoFact: fact,
          correctAction: 'Sort into ♻️ Recyclable Bin',
          icon: '🥫', color: const Color(0xFF90A4AE),
          hasEcoDiscovery: withDiscovery,
          discoveryFact: withDiscovery ? (_discoveryFacts[t] ?? '') : '',
        );
      case LitterType.paper:
        return HabitatScanResult(
          typeName: 'Paper / Book', ecoFact: fact,
          correctAction: 'Sort into ♻️ Recyclable Bin',
          icon: '📄', color: const Color(0xFF8D6E63),
          hasEcoDiscovery: withDiscovery,
          discoveryFact: withDiscovery ? (_discoveryFacts[t] ?? '') : '',
        );
      case LitterType.fruitPeel:
        return HabitatScanResult(
          typeName: 'Fruit Peel', ecoFact: fact,
          correctAction: 'Sort into 🌿 Biodegradable Bin',
          icon: '🍌', color: const Color(0xFF558B2F),
          hasEcoDiscovery: withDiscovery,
          discoveryFact: withDiscovery ? (_discoveryFacts[t] ?? '') : '',
        );
      case LitterType.clothes:
        return HabitatScanResult(
          typeName: 'Old Clothes', ecoFact: fact,
          correctAction: 'Sort into 🔄 Reusable Bin',
          icon: '👕', color: const Color(0xFFEC407A),
          hasEcoDiscovery: withDiscovery,
          discoveryFact: withDiscovery ? (_discoveryFacts[t] ?? '') : '',
        );
      case LitterType.shoes:
        return HabitatScanResult(
          typeName: 'Torn Shoes', ecoFact: fact,
          correctAction: 'Sort into 🔄 Reusable Bin',
          icon: '👟', color: const Color(0xFF7E57C2),
          hasEcoDiscovery: withDiscovery,
          discoveryFact: withDiscovery ? (_discoveryFacts[t] ?? '') : '',
        );
      case LitterType.eWaste:
        return HabitatScanResult(
          typeName: 'E-Waste / Battery', ecoFact: fact,
          correctAction: 'Sort into ☠️ Harmful Bin',
          icon: '🔋', color: const Color(0xFFEF5350),
          hasEcoDiscovery: withDiscovery,
          discoveryFact: withDiscovery ? (_discoveryFacts[t] ?? '') : '',
        );
    }
  }
}

enum LitterType {
  plasticBottle,
  polythene,
  foodWrap,
  glassBottle,
  metalCan,
  paper,
  fruitPeel,
  clothes,
  shoes,
  eWaste,
}

enum WasteSort { recyclable, reusable, biodegradable, harmful }

// ══════════════════════════════════════════════════════════════════════════════
//  SCREEN WRAPPER
// ══════════════════════════════════════════════════════════════════════════════
class HabitatCleanupGameScreen extends StatefulWidget {
  final Level5CarryOver carryOver;
  const HabitatCleanupGameScreen({super.key, required this.carryOver});

  @override
  State<HabitatCleanupGameScreen> createState() =>
      _HabitatCleanupGameScreenState();
}

class _HabitatCleanupGameScreenState extends State<HabitatCleanupGameScreen> {
  late HabitatCleanupGame _game;

  @override
  void initState() {
    super.initState();
    _game = HabitatCleanupGame(
      carryOver:       widget.carryOver,
      onLevelComplete: _onDone,
    );
  }

  void _onDone() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => PondCleaningGameScreen(carryOver: widget.carryOver),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GameWidget(
        game: _game,
        overlayBuilderMap: {
          'hud':           (ctx, g) => CleanupHud(g as HabitatCleanupGame),
          'controls':      (ctx, g) => CleanupControls(g as HabitatCleanupGame),
          'banner':        (ctx, g) => CleanupPhaseBanner(g as HabitatCleanupGame),
          'scanResult':    (ctx, g) => HabitatScanResultOverlay(g as HabitatCleanupGame),
          'sortMini':      (ctx, g) => SortMiniGame(g as HabitatCleanupGame),
          'reactionFx':    (ctx, g) => CleanupReactionFx(g as HabitatCleanupGame),
          'ecoDiscovery':  (ctx, g) => CleanupEcoDiscoveryOverlay(g as HabitatCleanupGame),
          'results':       (ctx, g) => CleanupResultsOverlay(g as HabitatCleanupGame),
        },
        initialActiveOverlays: const ['hud', 'controls'],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  MAIN GAME CLASS  — Waste only
// ══════════════════════════════════════════════════════════════════════════════
class HabitatCleanupGame extends FlameGame
    with HasCollisionDetection, ChangeNotifier {

  final Level5CarryOver carryOver;
  final VoidCallback    onLevelComplete;
  HabitatCleanupGame({required this.carryOver, required this.onLevelComplete});

  static const int kMinLitterRequired = 9;

  static const double kWorldScale   = 3.0;
  static const double kEdgeFraction = 0.22;
  static const double kCameraEase   = 5.5;
  double worldW = 0, worldH = 0;
  double camX = 0, camY = 0;
  double _targetCamX = 0, _targetCamY = 0;
  double edgeHintLeft = 0, edgeHintRight = 0;
  double edgeHintTop  = 0, edgeHintBottom = 0;

  bool   gameStarted = false;
  double timeLeft    = 150.0;
  bool   levelDone   = false;

  int ecoPoints    = 0;
  int litterCount  = 0;
  int correctSorts = 0;
  int wrongSorts   = 0;   // ── NEW: Tracks failed sort attempts ──
  int maxCombo     = 1;

  static const double _scanRange     = 145.0;
  static const double _scanMaxRadius = 170.0;

  late Vector2 dronePos;
  bool isUp = false, isDown = false, isLeft = false, isRight = false;
  static const double _droneSpeed = 185.0;

  LitterItem?   pendingSortTarget;
  bool          sortSelectorOpen      = false;

  bool        scanLockActive   = false;
  double      _scanLockTimer   = 0;
  static const double _scanDuration = 1.5;
  LitterItem? activeScanLitter;
  LitterItem? _nearestScanLitter;
  bool        scanActive       = false;
  double      scanRadius       = 0;

  bool               scanResultActive = false;
  HabitatScanResult? lastScanResult;
  double             scanResultTimer  = 0;
  int                lastScanPoints   = 0;
  Vector2            scanCardPos      = Vector2.zero();

  int    scanStreak      = 0;
  double scanStreakTimer  = 0;
  int    totalScanStreak = 0;
  static const double _streakWindow = 6.0;

  final Set<int> ecoDiscoveryIndices  = {};
  final Set<int> discoveredEcoItems   = {};
  int?           timeBonusLitterIndex;
  bool           timeBonusCollected   = false;
  int            ecoDiscoveriesFound  = 0;
  String         lastDiscoveryFact    = '';
  double         discoveryDisplayTimer = 0;
  static const double _discoveryDisplay = 4.0;

  int    comboCount      = 0;
  double comboTimer      = 0;
  static const double _comboWindow = 4.5;
  bool   showComboFlash  = false;
  double comboFlashTimer = 0;

  final Set<LitterType> _seenLitterTypes = {};
  bool scanResultShowsHints  = true;
  bool sortShowsHints        = true;

  bool   reactionActive  = false;
  bool   reactionCorrect = false;
  bool   reactionInRange = true;
  double reactionTimer   = 0;
  String reactionMsg     = '';

  double bannerTimer = 3.5;

  String ecoGuideHint  = '';
  double ecoGuideTimer = 0;
  double _hintCooldown = 0;
  double _idleTimer    = 0;

  late EcoDroneCleanupComponent drone;
  final List<LitterItem>   litter = [];

  static const int totalLitter = 16;

  @override
  Future<void> onLoad() async {
    super.onLoad();
    worldW   = size.x * kWorldScale;
    worldH   = size.y * kWorldScale;
    dronePos = Vector2(worldW * 0.50, worldH * 0.50);
    _centerCamOn(dronePos);
    _targetCamX = camX; _targetCamY = camY;

    add(DegradedParkRenderer(game: this));
    drone = EcoDroneCleanupComponent(game: this);
    add(drone);

    _spawnLitter();
    _assignSpecialLitter();

    bannerTimer = 3.5;
    overlays.add('banner');
    add(TimerComponent(period: 1.0, repeat: true, onTick: _onSecond));
  }

  void _centerCamOn(Vector2 pos) {
    camX = (pos.x - size.x / 2).clamp(0.0, worldW - size.x);
    camY = (pos.y - size.y / 2).clamp(0.0, worldH - size.y);
  }

  Vector2 screenToWorld(Vector2 s) => Vector2(s.x + camX, s.y + camY);
  Vector2 worldToScreen(Vector2 w) => Vector2(w.x - camX, w.y - camY);
  Vector2 get droneScreen => worldToScreen(dronePos);

  void _spawnLitter() {
    const specs = [
      (LitterType.plasticBottle, 0.40, 0.42),
      (LitterType.polythene,     0.55, 0.38),
      (LitterType.foodWrap,      0.47, 0.53),
      (LitterType.glassBottle,   0.60, 0.46),
      (LitterType.metalCan, 0.12, 0.30),
      (LitterType.paper,    0.18, 0.58),
      (LitterType.fruitPeel, 0.08, 0.70),
      (LitterType.clothes,  0.22, 0.42),
      (LitterType.shoes,    0.82, 0.24),
      (LitterType.eWaste,   0.76, 0.54),
      (LitterType.plasticBottle, 0.88, 0.68),
      (LitterType.polythene,     0.70, 0.38),
      (LitterType.foodWrap,    0.44, 0.14),
      (LitterType.glassBottle, 0.62, 0.76),
      (LitterType.metalCan,    0.28, 0.80),
      (LitterType.paper,       0.55, 0.18),
    ];
    for (int i = 0; i < specs.length; i++) {
      final (type, rx, ry) = specs[i];
      final l = LitterItem(
        game: this, type: type,
        worldX: worldW * rx, worldY: worldH * ry,
        seed: i * 17,
      );
      add(l); litter.add(l);
    }
  }

  void _assignSpecialLitter() {
    final rng     = math.Random(DateTime.now().millisecondsSinceEpoch);
    final indices = List.generate(litter.length, (i) => i)..shuffle(rng);
    ecoDiscoveryIndices.add(indices[0]);
    ecoDiscoveryIndices.add(indices[1]);
    timeBonusLitterIndex = indices[2];
  }

  void _onSecond() {
    if (!gameStarted || levelDone) return;
    timeLeft -= 1;
    if (timeLeft <= 0) { timeLeft = 0; _endCleanup(); }
    notifyListeners();
  }

  double get scanHoldProgress =>
      scanLockActive ? (_scanLockTimer / _scanDuration).clamp(0.0, 1.0) : 0.0;

  bool get _hasNearbyUnscannedLitter =>
      litter.any((l) => !l.isScanned && !l.isCollected &&
          (l.litterPos - dronePos).length <= _scanRange);

  // ══════════════════════════════════════════════════════════════════════════
  //  LITTER SCAN
  // ══════════════════════════════════════════════════════════════════════════
  void triggerScan() {
    if (!gameStarted || levelDone) return;
    gameStarted = true;
    HapticFeedback.selectionClick();

    if (sortSelectorOpen) {
      reactionMsg = '🗑️ Sort the current item first!';
      _triggerReaction(false, inRange: false);
      notifyListeners(); return;
    }
    if (scanLockActive) {
      reactionMsg = '📡 Scanning in progress…';
      _triggerReaction(true, inRange: true);
      notifyListeners(); return;
    }

    LitterItem? nearest; double nearestD = _scanRange;
    for (final l in litter) {
      if (l.isScanned || l.isCollected) continue;
      final d = (l.litterPos - dronePos).length;
      if (d < nearestD) { nearestD = d; nearest = l; }
    }

    if (nearest == null) {
      scanActive = true; scanRadius = 0;
      reactionMsg = '🌿 No litter in range — fly closer';
      _triggerReaction(false, inRange: false);
      notifyListeners(); return;
    }

    activeScanLitter = nearest;
    scanLockActive   = true;
    _scanLockTimer   = 0;
    scanActive       = true; scanRadius = 0;
    reactionMsg      = '📡 Scanning litter — hold position!';
    _triggerReaction(true, inRange: true);
    HapticFeedback.lightImpact();
    notifyListeners();
  }

  void _completeLitterScan(LitterItem l) {
    if (l.isScanned) return;
    final idx          = litter.indexOf(l);
    final hasDiscovery = ecoDiscoveryIndices.contains(idx);
    l.isScanned        = true;
    l.scanVariant      = idx;

    final pts      = hasDiscovery ? 30 : 10;
    ecoPoints     += pts;
    lastScanPoints = pts;
    scanActive     = true; scanRadius = 0;
    scanCardPos    = dronePos.clone();

    final firstScan = !_seenLitterTypes.contains(l.type);
    if (firstScan) _seenLitterTypes.add(l.type);
    scanResultShowsHints = firstScan;
    sortShowsHints       = firstScan;

    lastScanResult   = HabitatScanResult.forLitter(
        l.type, withDiscovery: hasDiscovery, variant: idx);
    scanResultTimer  = hasDiscovery ? 5.0 : 3.8;
    scanResultActive = true;

    scanLockActive   = false; _scanLockTimer = 0; activeScanLitter = null;
    _handleScanStreak();
    HapticFeedback.heavyImpact();

    if (hasDiscovery) {
      ecoDiscoveriesFound++;
      discoveredEcoItems.add(idx);
      lastDiscoveryFact    = lastScanResult!.discoveryFact;
      discoveryDisplayTimer = _discoveryDisplay;
      overlays.add('ecoDiscovery');
    } else {
      overlays.add('scanResult');
    }

    pendingSortTarget = l;
    notifyListeners();
  }

  void openSortSelectorForPending() {
    if (pendingSortTarget == null || sortSelectorOpen) return;
    sortSelectorOpen = true;
    overlays.remove('scanResult');
    scanResultActive = false;
    overlays.add('sortMini');
    notifyListeners();
  }

  void dismissScanResult() {
    if (!scanResultActive) return;
    scanResultActive = false;
    overlays.remove('scanResult');
    if (pendingSortTarget != null && !sortSelectorOpen) {
      sortSelectorOpen = true;
      overlays.add('sortMini');
    }
    notifyListeners();
  }

  void sortLitter(WasteSort sort) {
    if (pendingSortTarget == null) return;
    HapticFeedback.selectionClick();

    final target  = pendingSortTarget!;
    final correct = _isCorrectSort(target.type, sort);

    if (correct) {
      target.collect();
      litterCount++;
      correctSorts++;
      ecoPoints += 20 * _comboMult();
      _incCombo();

      final idx = litter.indexOf(target);
      if (idx == timeBonusLitterIndex && !timeBonusCollected) {
        timeBonusCollected = true;
        timeLeft = math.min(timeLeft + 8, 150);
        reactionMsg = '⏱️ Time Bonus! +8 s  ♻️ Sorted!  +${20 * _comboMult()} pts';
        HapticFeedback.heavyImpact();
      } else {
        reactionMsg = '✅ Correctly Sorted!  +${20 * _comboMult()} pts';
      }
      _triggerReaction(true);

      sortSelectorOpen  = false;
      pendingSortTarget = null;
      overlays.remove('sortMini');

      if (litter.every((l) => l.isCollected)) {
        Future.delayed(const Duration(milliseconds: 600), _endCleanup);
      }
    } else {
      // ── FIXED: Track wrong sort attempts ──
      wrongSorts++;
      ecoPoints = math.max(0, ecoPoints - 5);
      _breakCombo();
      reactionMsg = '❌ Wrong bin — try another!  (Wrong sorts: $wrongSorts)';
      _triggerReaction(false);
    }
    notifyListeners();
  }

  bool _isCorrectSort(LitterType t, WasteSort s) {
    switch (t) {
      case LitterType.plasticBottle:
      case LitterType.polythene:
      case LitterType.foodWrap:
      case LitterType.metalCan:
      case LitterType.paper:
        return s == WasteSort.recyclable;
      case LitterType.glassBottle:
      case LitterType.clothes:
      case LitterType.shoes:
        return s == WasteSort.reusable;
      case LitterType.fruitPeel:
        return s == WasteSort.biodegradable;
      case LitterType.eWaste:
        return s == WasteSort.harmful;
    }
  }

  void cancelSortSelector() {
    sortSelectorOpen  = false;
    pendingSortTarget = null;
    overlays.remove('sortMini');
    notifyListeners();
  }

  void _handleScanStreak() {
    scanStreakTimer = _streakWindow;
    scanStreak++;
    if (scanStreak >= 3) {
      final bonus     = (scanStreak - 2) * 8;
      ecoPoints      += bonus;
      totalScanStreak += bonus;
      reactionMsg     = '🎯 Scan Streak x$scanStreak!  +$bonus bonus pts';
      _triggerReaction(true);
    }
  }

  int _comboMult() {
    if (comboCount >= 4) return 3;
    if (comboCount >= 2) return 2;
    return 1;
  }

  void _incCombo() {
    comboCount++; comboTimer = _comboWindow;
    if (comboCount > maxCombo) maxCombo = comboCount;
    showComboFlash = true; comboFlashTimer = 1.8;
    notifyListeners();
  }

  void _breakCombo() { comboCount = 0; comboTimer = 0; }

  void _checkHints() {
    if (_hintCooldown > 0 || ecoGuideTimer > 0) return;
    if (_idleTimer > 4.5) {
      ecoGuideHint  = '📡 Fly near litter and hold SCAN (1.5 s). Read the eco-fact, then tap SORT IT!';
      ecoGuideTimer = 3.5; _hintCooldown = 12; _idleTimer = 0;
    }
    notifyListeners();
  }

  void _endCleanup() {
    if (levelDone) return;
    levelDone = true;
    pauseEngine();

    final meetsMin    = correctSorts >= kMinLitterRequired;
    final allCollected = litter.every((l) => l.isCollected);

    final LevelCompletionState completionState;
    if (allCollected) {
      completionState = LevelCompletionState.fullCompletion;
    } else if (meetsMin) {
      completionState = LevelCompletionState.moderate;
    } else {
      completionState = LevelCompletionState.failed;
    }

    String endReason = '';
    if (timeLeft <= 0) {
      if (allCollected) {
        endReason = '🌍 All litter collected — and just in time!';
      } else if (meetsMin) {
        endReason = '⏰ Time expired — minimum $kMinLitterRequired sorts met. Well done!';
      } else {
        endReason = '⏰ Time ran out before sorting $kMinLitterRequired items. Keep practising!';
      }
    } else if (allCollected) {
      endReason = '🌍 All ${litter.length} litter items correctly sorted! Outstanding work!';
    } else {
      endReason = 'Level ended with $correctSorts/$kMinLitterRequired items correctly sorted.';
    }

    HabitatCleanupResult.current = HabitatCleanupResult(
      litterCollected:       litterCount,
      correctSorts:          correctSorts,
      wrongSorts:            wrongSorts,   // ── NEW: Pass wrong sorts to results ──
      ecoPoints:             ecoPoints,
      maxCombo:              maxCombo,
      scanStreakBonus:        totalScanStreak,
      ecoDiscoveriesFound:   ecoDiscoveriesFound,
      timeBonusCollected:    timeBonusCollected,
      meetsMinimum:          meetsMin,
      minimumLitterRequired: kMinLitterRequired,
      endReason:             endReason,
      completionState:       completionState,
    );

    overlays
      ..remove('reactionFx')
      ..remove('scanResult')
      ..remove('sortMini')
      ..remove('ecoDiscovery')
      ..add('results');
    notifyListeners();
  }

  void setUpKey(bool v)    { isUp    = v; if (v) { gameStarted = true; _idleTimer = 0; } }
  void setDownKey(bool v)  { isDown  = v; if (v) { gameStarted = true; _idleTimer = 0; } }
  void setLeftKey(bool v)  { isLeft  = v; if (v) { gameStarted = true; _idleTimer = 0; } }
  void setRightKey(bool v) { isRight = v; if (v) { gameStarted = true; _idleTimer = 0; } }

  void _triggerReaction(bool correct, {bool inRange = true}) {
    reactionActive  = true; reactionCorrect = correct;
    reactionInRange = inRange;
    reactionTimer   = 1.3;
    overlays.add('reactionFx');
  }

  void _updateCamera(double dt) {
    final sw = size.x; final sh = size.y;
    final edgeW = sw * kEdgeFraction;
    final edgeH = sh * kEdgeFraction;
    final sx = dronePos.x - camX;
    final sy = dronePos.y - camY;
    double tx = _targetCamX; double ty = _targetCamY;

    if (sx < edgeW) {
      tx = dronePos.x - edgeW;
    } else if (sx > sw-edgeW) {tx = dronePos.x - (sw - edgeW);}
    if (sy < edgeH) {
      ty = dronePos.y - edgeH;
    } else if (sy > sh-edgeH) {ty = dronePos.y - (sh - edgeH);}

    _targetCamX = tx.clamp(0.0, worldW - sw);
    _targetCamY = ty.clamp(0.0, worldH - sh);
    camX += (_targetCamX - camX) * kCameraEase * dt;
    camY += (_targetCamY - camY) * kCameraEase * dt;

    edgeHintLeft   = (sx < edgeW*1.5 && camX > 1)
        ? (1.0 - sx/(edgeW*1.5)).clamp(0, 1) : 0;
    edgeHintRight  = (sx > sw-edgeW*1.5 && camX < worldW-sw-1)
        ? ((sx-(sw-edgeW*1.5))/(edgeW*1.5)).clamp(0, 1) : 0;
    edgeHintTop    = (sy < edgeH*1.5 && camY > 1)
        ? (1.0 - sy/(edgeH*1.5)).clamp(0, 1) : 0;
    edgeHintBottom = (sy > sh-edgeH*1.5 && camY < worldH-sh-1)
        ? ((sy-(sh-edgeH*1.5))/(edgeH*1.5)).clamp(0, 1) : 0;
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (bannerTimer > 0) {
      bannerTimer -= dt;
      if (bannerTimer <= 0) overlays.remove('banner');
    }
    if (reactionTimer > 0) {
      reactionTimer -= dt;
      if (reactionTimer <= 0) { reactionActive = false; overlays.remove('reactionFx'); }
    }
    if (scanActive) {
      scanRadius += dt * 220;
      if (scanRadius >= _scanMaxRadius) scanActive = false;
    }
    if (ecoGuideTimer > 0) {
      ecoGuideTimer -= dt;
      if (ecoGuideTimer <= 0) ecoGuideHint = '';
    }
    if (_hintCooldown > 0) _hintCooldown -= dt;
    if (scanResultActive) {
      scanResultTimer -= dt;
      if (scanResultTimer <= 0) dismissScanResult();
    }
    if (discoveryDisplayTimer > 0) {
      discoveryDisplayTimer -= dt;
      if (discoveryDisplayTimer <= 0) overlays.remove('ecoDiscovery');
    }
    if (scanStreakTimer > 0) {
      scanStreakTimer -= dt;
      if (scanStreakTimer <= 0) scanStreak = 0;
    }

    if (!gameStarted || levelDone) { notifyListeners(); return; }

    double vx = 0, vy = 0;
    if (isLeft)  vx -= 1; if (isRight) vx += 1;
    if (isUp)    vy -= 1; if (isDown)  vy += 1;
    final moving = vx != 0 || vy != 0;
    if (!moving) {
      _idleTimer += dt;
    } else {
      _idleTimer = 0;
    }
    if (_idleTimer > 4.5) _checkHints();

    dronePos.x = (dronePos.x + vx * _droneSpeed * dt).clamp(30, worldW - 30);
    dronePos.y = (dronePos.y + vy * _droneSpeed * dt).clamp(40, worldH - 40);
    _updateCamera(dt);

    LitterItem? nl; double nlD = _scanRange;
    for (final l in litter) {
      if (l.isScanned || l.isCollected) continue;
      final d = (l.litterPos - dronePos).length;
      if (d < nlD) { nlD = d; nl = l; }
    }
    _nearestScanLitter = nl;

    if (scanLockActive && activeScanLitter != null) {
      final lockDist = (activeScanLitter!.litterPos - dronePos).length;
      if (lockDist > _scanRange * 1.15) {
        scanLockActive = false; _scanLockTimer = 0; activeScanLitter = null;
        reactionMsg = '📡 Scan cancelled — too far!';
        _triggerReaction(false, inRange: false);
      } else {
        _scanLockTimer += dt;
        if (_scanLockTimer >= _scanDuration) _completeLitterScan(activeScanLitter!);
      }
    }

    if (comboCount > 0) { comboTimer -= dt; if (comboTimer <= 0) _breakCombo(); }
    if (comboFlashTimer > 0) {
      comboFlashTimer -= dt;
      if (comboFlashTimer <= 0) showComboFlash = false;
    }

    notifyListeners();
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  PARK BACKGROUND RENDERER
// ══════════════════════════════════════════════════════════════════════════════
class DegradedParkRenderer extends Component {
  final HabitatCleanupGame game;
  double _t = 0;

  late final List<_ParkTree>   _trees;
  late final List<_LitterPile> _piles;
  late final List<_ParkPath>   _paths;
  late final List<_GrassBlock> _grass;
  late final List<_MudPatch>   _mud;

  DegradedParkRenderer({required this.game});

  @override
  void onLoad() { _initPark(); }

  void _initPark() {
    final w   = game.worldW; final h = game.worldH;
    final rng = math.Random(44);

    _paths = [
      _ParkPath(x: 0, y: h * 0.30, w: w, h: 14),
      _ParkPath(x: 0, y: h * 0.56, w: w, h: 14),
      _ParkPath(x: 0, y: h * 0.78, w: w, h: 14),
      _ParkPath(x: w * 0.24, y: 0, w: 14, h: h),
      _ParkPath(x: w * 0.52, y: 0, w: 14, h: h),
      _ParkPath(x: w * 0.78, y: 0, w: 14, h: h),
    ];

    _grass = List.generate(24, (i) => _GrassBlock(
      x: rng.nextDouble() * w,
      y: h * 0.05 + rng.nextDouble() * h * 0.85,
      w: 40 + rng.nextDouble() * 90,
      h: 30 + rng.nextDouble() * 60,
      seed: i,
    ));

    _mud = List.generate(10, (i) => _MudPatch(
      x: rng.nextDouble() * w,
      y: h * 0.10 + rng.nextDouble() * h * 0.75,
      r: 20 + rng.nextDouble() * 40, seed: i * 19,
    ));

    _trees = List.generate(18, (i) => _ParkTree(
      x: rng.nextDouble() * w,
      y: h * 0.10 + rng.nextDouble() * h * 0.76,
      h: 18 + rng.nextDouble() * 28,
      state: i % 5 == 0 ? 'dead' : 'sparse',
      seed: i * 11,
    ));

    _piles = List.generate(14, (i) => _LitterPile(
      x: rng.nextDouble() * w,
      y: h * 0.12 + rng.nextDouble() * h * 0.70,
      seed: i * 7,
    ));
  }

  @override
  void update(double dt) => _t += dt * 0.22;

  @override
  void render(Canvas canvas) {
    final w = game.worldW; final h = game.worldH;
    final sw = game.size.x; final sh = game.size.y;
    canvas.save();
    canvas.translate(-game.camX, -game.camY);

    _drawSky(canvas, w, h);
    _drawGrass(canvas, w, h);
    _drawPaths(canvas, w, h);
    _drawMudPatches(canvas, w, h);
    _drawTrees(canvas, w, h);
    _drawLitterPiles(canvas, w, h);
    _drawFooter(canvas, w, h);

    canvas.restore();
    _drawEdgeHints(canvas, sw, sh);
  }

  void _drawEdgeHints(Canvas canvas, double sw, double sh) {
    const hintColor = Color(0xFF00897B);
    void drawV(double alpha, Alignment from, Alignment to) {
      if (alpha < 0.01) return;
      canvas.drawRect(Rect.fromLTWH(0, 0, sw, sh), Paint()
        ..shader = ui.Gradient.linear(
          Offset(sw*(from.x+1)/2, sh*(from.y+1)/2),
          Offset(sw*(to.x+1)/2,   sh*(to.y+1)/2),
          [hintColor.withValues(alpha: alpha*0.38), Colors.transparent]));
    }
    drawV(game.edgeHintLeft,   Alignment.centerLeft,   Alignment.center);
    drawV(game.edgeHintRight,  Alignment.centerRight,  Alignment.center);
    drawV(game.edgeHintTop,    Alignment.topCenter,    Alignment.center);
    drawV(game.edgeHintBottom, Alignment.bottomCenter, Alignment.center);
  }

  void _drawSky(Canvas canvas, double w, double h) {
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h * 0.18),
        Paint()..shader = ui.Gradient.linear(Offset.zero, Offset(0, h*0.18),
            [const Color(0xFF060C06), const Color(0xFF0C1410)]));
  }

  void _drawGrass(Canvas canvas, double w, double h) {
    canvas.drawRect(Rect.fromLTWH(0, h * 0.18, w, h * 0.68),
        Paint()..color = const Color(0xFF060A04));
    for (final g in _grass) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(g.x, g.y, g.w, g.h), const Radius.circular(4)),
        Paint()..color = const Color(0xFF0A1208).withValues(alpha: 0.70),
      );
      final rng = math.Random(g.seed);
      for (int i = 0; i < 5; i++) {
        final gx = g.x + rng.nextDouble() * g.w;
        final gy = g.y + rng.nextDouble() * g.h;
        canvas.drawLine(Offset(gx, gy), Offset(gx + rng.nextDouble()*3-1.5, gy-6),
            Paint()..color = const Color(0xFF1A2E18).withValues(alpha: 0.45)
              ..strokeWidth = 1.0..strokeCap = StrokeCap.round);
      }
    }
  }

  void _drawPaths(Canvas canvas, double w, double h) {
    for (final p in _paths) {
      canvas.drawRect(Rect.fromLTWH(p.x, p.y, p.w, p.h),
          Paint()..color = const Color(0xFF0A100A));
    }
  }

  void _drawMudPatches(Canvas canvas, double w, double h) {
    for (final m in _mud) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(m.x, m.y), width: m.r*2, height: m.r*0.7),
        Paint()..color = const Color(0xFF1C2814).withValues(alpha: 0.50)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }
  }

  void _drawTrees(Canvas canvas, double w, double h) {
    for (final t in _trees) {
      final rng = math.Random(t.seed);
      canvas.drawLine(Offset(t.x, t.y), Offset(t.x + t.h*0.05, t.y - t.h),
          Paint()..color = const Color(0xFF1A2810).withValues(alpha: 0.65)
            ..strokeWidth = 3.0 + rng.nextDouble()*2.0..strokeCap = StrokeCap.round);
      final canopyColor = t.state == 'dead'
          ? const Color(0xFF101808) : const Color(0xFF142010);
      canvas.drawCircle(Offset(t.x, t.y - t.h * 0.75), t.h * 0.38,
          Paint()..color = canopyColor.withValues(alpha: 0.50)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
      for (int b = 0; b < 3; b++) {
        final angle = rng.nextDouble() * math.pi * 2;
        canvas.drawLine(
          Offset(t.x, t.y - t.h * 0.5),
          Offset(t.x + math.cos(angle)*t.h*0.28, t.y - t.h*0.5 + math.sin(angle)*t.h*0.22),
          Paint()..color = const Color(0xFF1A2810).withValues(alpha: 0.40)
            ..strokeWidth = 1.4..strokeCap = StrokeCap.round);
      }
    }
  }

  void _drawLitterPiles(Canvas canvas, double w, double h) {
    for (final p in _piles) {
      final rng = math.Random(p.seed);
      for (int i = 0; i < 3; i++) {
        canvas.drawOval(
          Rect.fromCenter(center: Offset(p.x + rng.nextDouble()*12-6, p.y + rng.nextDouble()*8-4),
              width: 8 + rng.nextDouble()*12, height: 4 + rng.nextDouble()*6),
          Paint()..color = const Color(0xFF253020).withValues(alpha: 0.35),
        );
      }
    }
  }

  void _drawFooter(Canvas canvas, double w, double h) {
    canvas.drawRect(Rect.fromLTWH(0, h*0.86, w, h*0.14),
        Paint()..color = const Color(0xFF040804));
    canvas.drawLine(Offset(0, h*0.86), Offset(w, h*0.86),
        Paint()..color = const Color(0xFF1A2E18).withValues(alpha: 0.50)..strokeWidth = 1.5);
  }
}

class _ParkPath   { final double x, y, w, h; const _ParkPath({required this.x, required this.y, required this.w, required this.h}); }
class _GrassBlock { final double x, y, w, h; final int seed; const _GrassBlock({required this.x, required this.y, required this.w, required this.h, required this.seed}); }
class _MudPatch   { final double x, y, r; final int seed; const _MudPatch({required this.x, required this.y, required this.r, required this.seed}); }
class _ParkTree   { final double x, y, h; final String state; final int seed; const _ParkTree({required this.x, required this.y, required this.h, required this.state, required this.seed}); }
class _LitterPile { final double x, y; final int seed; const _LitterPile({required this.x, required this.y, required this.seed}); }

// ══════════════════════════════════════════════════════════════════════════════
//  DRONE
// ══════════════════════════════════════════════════════════════════════════════
class EcoDroneCleanupComponent extends Component {
  final HabitatCleanupGame game;
  double _t = 0;
  EcoDroneCleanupComponent({required this.game});

  @override
  void update(double dt) => _t += dt;

  @override
  void render(Canvas canvas) {
    canvas.save();
    canvas.translate(-game.camX, -game.camY);
    _renderWorld(canvas);
    canvas.restore();
  }

  void _renderWorld(Canvas canvas) {
    final cx = game.dronePos.x;
    final cy = game.dronePos.y + math.sin(_t * 3.0) * 2.5;

    if (game.scanActive) {
      final alpha = (1.0 - game.scanRadius / HabitatCleanupGame._scanMaxRadius) * 0.30;
      canvas.drawCircle(Offset(cx, cy), game.scanRadius,
          Paint()..color = const Color(0xFFFFB300).withValues(alpha: alpha)
            ..style = PaintingStyle.stroke..strokeWidth = 2.5);
    }

    final rangeColor = const Color(0xFFFFB300);
    canvas.drawCircle(Offset(cx, cy), HabitatCleanupGame._scanRange,
        Paint()..color = rangeColor.withValues(alpha: 0.058)
          ..style = PaintingStyle.stroke..strokeWidth = 1.2);

    final progress = game.scanHoldProgress;
    if (progress > 0) {
      canvas.drawCircle(Offset(cx, cy), 14 + progress * 7,
          Paint()..color = const Color(0xFFFFB300).withValues(alpha: progress * 0.28)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    }

    canvas.save();
    canvas.translate(cx, cy);

    canvas.drawOval(Rect.fromCenter(center: const Offset(0, 14), width: 38, height: 9),
        Paint()..color = Colors.black.withValues(alpha: 0.28));

    final armP = Paint()..color = const Color(0xFF1A2E18)..strokeWidth = 3.0..strokeCap = StrokeCap.round;
    for (final (dx, dy) in [(-1,-1),(1,-1),(-1,1),(1,1)]) {
      canvas.drawLine(Offset(dx*8.0, dy*8.0), Offset(dx*22.0, dy*22.0), armP);
    }

    final propPaint = Paint()
      ..color = const Color(0xFFFFB300).withValues(alpha: 0.58)
      ..strokeWidth = 1.8..strokeCap = StrokeCap.round;
    for (final (px, py) in [(-22.0,-22.0),(22.0,-22.0),(-22.0,22.0),(22.0,22.0)]) {
      canvas.save(); canvas.translate(px, py); canvas.rotate(_t * 13);
      canvas.drawLine(const Offset(-8,0), const Offset(8,0), propPaint);
      canvas.drawLine(const Offset(0,-8), const Offset(0,8), propPaint);
      canvas.restore();
    }

    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(-13, -9, 26, 18), const Radius.circular(6)),
        Paint()..color = const Color(0xFF142810));

    final glowBright = progress > 0 ? 0.95 : 0.75 + math.sin(_t*4)*0.20;
    canvas.drawCircle(Offset.zero, 7,
        Paint()..color = const Color(0xFFFFB300).withValues(alpha: glowBright)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    canvas.drawCircle(Offset.zero, 3.5, Paint()..color = Colors.white.withValues(alpha: 0.95));

    final tp = TextPainter(
      text: const TextSpan(text: '🗑️', style: TextStyle(fontSize: 8)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(-tp.width/2, 12 - tp.height/2));

    canvas.restore();
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  LITTER ITEM
// ══════════════════════════════════════════════════════════════════════════════
class LitterItem extends Component {
  final HabitatCleanupGame game;
  final LitterType type;
  double lx, ly;
  final int seed;
  bool isScanned      = false;
  bool isCollected    = false;
  bool triggerSparkle = false;
  double sparkleTimer = 0;
  int    scanVariant  = 0;
  double _t = 0;

  LitterItem({required this.game, required this.type,
      required double worldX, required double worldY, required this.seed})
      : lx = worldX, ly = worldY;

  Vector2 get litterPos => Vector2(lx, ly);
  void collect() => isCollected = true;

  static const _specs = {
    LitterType.plasticBottle: ('🥤', Color(0xFF29B6F6)),
    LitterType.polythene:     ('🛍️', Color(0xFF42A5F5)),
    LitterType.foodWrap:      ('🥡', Color(0xFF26C6DA)),
    LitterType.glassBottle:   ('🍾', Color(0xFFAB47BC)),
    LitterType.metalCan:      ('🥫', Color(0xFF90A4AE)),
    LitterType.paper:         ('📄', Color(0xFF8D6E63)),
    LitterType.fruitPeel:     ('🍌', Color(0xFF558B2F)),
    LitterType.clothes:       ('👕', Color(0xFFEC407A)),
    LitterType.shoes:         ('👟', Color(0xFF7E57C2)),
    LitterType.eWaste:        ('🔋', Color(0xFFEF5350)),
  };

  @override
  void update(double dt) {
    if (!isCollected) _t += dt;
    if (triggerSparkle) { sparkleTimer = 1.5; triggerSparkle = false; }
    if (sparkleTimer > 0) sparkleTimer = math.max(0, sparkleTimer - dt);
  }

  @override
  void render(Canvas canvas) {
    if (isCollected) return;
    canvas.save();
    canvas.translate(-game.camX, -game.camY);
    _renderWorld(canvas);
    canvas.restore();
  }

  void _renderWorld(Canvas canvas) {
    final spec  = _specs[type]!;
    final color = spec.$2;
    final pulse = 0.75 + math.sin(_t * 2.5) * 0.15;

    if (!isScanned) {
      canvas.drawCircle(Offset(lx, ly), 22 * pulse,
          Paint()..color = const Color(0xFF557755).withValues(alpha: 0.07)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
      canvas.drawCircle(Offset(lx, ly), 17,
          Paint()..color = const Color(0xFF558B2F).withValues(alpha: 0.48)
            ..style = PaintingStyle.stroke..strokeWidth = 1.6);
      final qp = TextPainter(
        text: const TextSpan(text: '?',
            style: TextStyle(color: Color(0xFF69F0AE), fontSize: 14, fontWeight: FontWeight.bold)),
        textDirection: TextDirection.ltr,
      )..layout();
      qp.paint(canvas, Offset(lx - qp.width/2, ly - qp.height/2));

      if (game.activeScanLitter == this) {
        _drawScanProgress(canvas, game.scanHoldProgress);
      }
    } else {
      canvas.drawCircle(Offset(lx, ly), 20 * pulse,
          Paint()..color = color.withValues(alpha: 0.10)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
      canvas.drawCircle(Offset(lx, ly), 16,
          Paint()..color = color.withValues(alpha: 0.52)
            ..style = PaintingStyle.stroke..strokeWidth = 2.0);
      final tp = TextPainter(
        text: TextSpan(text: spec.$1, style: const TextStyle(fontSize: 13)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(lx - tp.width/2, ly - tp.height/2));

      final idx = game.litter.indexOf(this);
      if (idx == game.timeBonusLitterIndex && !game.timeBonusCollected) {
        canvas.drawCircle(Offset(lx+18, ly-18), 8,
            Paint()..color = const Color(0xFFFFD700).withValues(alpha: 0.80)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
        final tip = TextPainter(
          text: const TextSpan(text: '⏱', style: TextStyle(fontSize: 9)),
          textDirection: TextDirection.ltr,
        )..layout();
        tip.paint(canvas, Offset(lx+18 - tip.width/2, ly-18 - tip.height/2));
      }

      if (game.ecoDiscoveryIndices.contains(idx) && !game.discoveredEcoItems.contains(idx)) {
        final shimmer = 0.30 + math.sin(_t*3.5)*0.22;
        canvas.drawCircle(Offset(lx-18, ly-18), 6,
            Paint()..color = const Color(0xFFE040FB).withValues(alpha: shimmer)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
      }

      if (sparkleTimer > 0) {
        for (int i = 0; i < 10; i++) {
          final angle = (i/10)*math.pi*2;
          final r = sparkleTimer/1.5 * 45;
          canvas.drawCircle(
            Offset(lx + math.cos(angle)*r, ly + math.sin(angle)*r), 2.5,
            Paint()..color = color.withValues(alpha: (sparkleTimer/1.5).clamp(0,1)),
          );
        }
      }
    }
  }

  void _drawScanProgress(Canvas canvas, double progress) {
    const start = -math.pi / 2;
    const full  = math.pi * 2;
    final beam  = start + full * progress;
    canvas.drawArc(
      Rect.fromCenter(center: Offset(lx, ly), width: 76, height: 76),
      beam - 0.5, 0.5, false,
      Paint()..color = const Color(0xFFFFB300).withValues(alpha: 0.18)
        ..style = PaintingStyle.stroke..strokeWidth = 9.0);
    canvas.drawLine(Offset(lx, ly),
        Offset(lx + math.cos(beam)*38, ly + math.sin(beam)*38),
        Paint()..color = const Color(0xFFFFB300).withValues(alpha: 0.30)..strokeWidth = 1.8);
    canvas.drawCircle(Offset(lx, ly), 38,
        Paint()..color = Colors.white.withValues(alpha: 0.07)
          ..style = PaintingStyle.stroke..strokeWidth = 3.8);
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCenter(center: Offset(lx, ly), width: 76, height: 76),
        start, full * progress, false,
        Paint()..color = const Color(0xFFFFB300).withValues(alpha: 0.88)
          ..style = PaintingStyle.stroke..strokeWidth = 3.8..strokeCap = StrokeCap.round);
    }
    final pct = (progress * 100).toInt();
    final pctP = TextPainter(
      text: TextSpan(text: '$pct%',
          style: const TextStyle(color: Color(0xFFFFB300), fontSize: 9, fontWeight: FontWeight.bold)),
      textDirection: TextDirection.ltr,
    )..layout();
    pctP.paint(canvas, Offset(lx - pctP.width/2, ly - 52));
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  HUD
// ══════════════════════════════════════════════════════════════════════════════
class CleanupHud extends StatelessWidget {
  final HabitatCleanupGame game;
  const CleanupHud(this.game, {super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: game,
      builder: (_, __) {
        final warn = game.timeLeft < 20;

        return SafeArea(child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch, children: [

            Align(alignment: Alignment.topCenter, child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFFFB300).withValues(alpha: 0.90),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(
                    color: const Color(0xFFFFB300).withValues(alpha: 0.35), blurRadius: 10)],
              ),
              child: const Text(
                '🗑️  WASTE COLLECTION',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900,
                    fontSize: 12, letterSpacing: 1.1),
              ),
            )),
            const SizedBox(height: 8),

            Row(children: [
              _CHTile(Icons.timer_rounded, '${game.timeLeft.toInt()}s', 'TIME',
                  warn ? Colors.red : Colors.white),
              const SizedBox(width: 5),
              _CHTile(Icons.radar_rounded,
                  '${game.litter.where((l) => l.isScanned).length}/${HabitatCleanupGame.totalLitter}',
                  'SCANNED', const Color(0xFFFFB300)),
              const SizedBox(width: 5),
              _CHTile(Icons.check_circle_rounded,
                  '${game.correctSorts}/${HabitatCleanupGame.kMinLitterRequired}+',
                  'SORTED',
                  game.correctSorts >= HabitatCleanupGame.kMinLitterRequired
                      ? const Color(0xFF69F0AE) : Colors.white70),
              const SizedBox(width: 5),
              _CHTile(Icons.eco_rounded, '${game.ecoPoints}', 'ECO-PTS', Colors.limeAccent),
            ]),
            const SizedBox(height: 5),

            if (game.scanLockActive) ...[
              Row(children: [
                const Text('🔒', style: TextStyle(fontSize: 12)),
                const SizedBox(width: 5),
                Expanded(child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: game.scanHoldProgress,
                    backgroundColor: Colors.white12,
                    valueColor: const AlwaysStoppedAnimation(Color(0xFFFFB300)),
                    minHeight: 7,
                  ),
                )),
                const SizedBox(width: 6),
                const Text('Locking…', style: TextStyle(
                    color: Color(0xFFFFB300), fontSize: 9, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 4),
            ],

            if (!game.scanLockActive && game._nearestScanLitter != null &&
                !game.sortSelectorOpen && !game.scanResultActive) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFB300).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFFB300).withValues(alpha: 0.35)),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('📡', style: TextStyle(fontSize: 10)),
                  SizedBox(width: 5),
                  Text('Litter nearby — hold SCAN!',
                      style: TextStyle(color: Color(0xFFFFB300), fontSize: 9, fontWeight: FontWeight.w700)),
                ]),
              ),
            ],

            if (game.scanStreak >= 2)
              Align(alignment: Alignment.centerRight,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE040FB).withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE040FB).withValues(alpha: 0.55)),
                  ),
                  child: Text('🎯 Streak x${game.scanStreak}!',
                      style: const TextStyle(color: Color(0xFFE040FB),
                          fontSize: 9, fontWeight: FontWeight.w900)),
                ),
              ),

            if (game.comboCount > 0)
              Align(alignment: Alignment.centerRight,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6D00).withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFF6D00).withValues(alpha: 0.60)),
                  ),
                  child: Text(
                    '🔥 ${game.comboCount}× Combo  (${game.comboTimer.toStringAsFixed(1)}s)',
                    style: const TextStyle(color: Color(0xFFFF6D00),
                        fontSize: 9, fontWeight: FontWeight.w900),
                  ),
                ),
              ),

            if (game.ecoGuideHint.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 5),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(children: [
                  const Text('🌍', style: TextStyle(fontSize: 12)),
                  const SizedBox(width: 6),
                  Expanded(child: Text(game.ecoGuideHint,
                      style: const TextStyle(color: Colors.white70, fontSize: 9.5))),
                ]),
              ),
          ]),
        ));
      },
    );
  }
}

class _CHTile extends StatelessWidget {
  final IconData icon;
  final String val, label;
  final Color color;
  const _CHTile(this.icon, this.val, this.label, this.color);

  @override
  Widget build(BuildContext context) => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
    decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white12)),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: color, size: 13),
      Text(val, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
      Text(label, style: const TextStyle(color: Colors.white54, fontSize: 7, letterSpacing: 0.7)),
    ]),
  ));
}

// ══════════════════════════════════════════════════════════════════════════════
//  CONTROLS
// ══════════════════════════════════════════════════════════════════════════════
class CleanupControls extends StatefulWidget {
  final HabitatCleanupGame game;
  const CleanupControls(this.game, {super.key});
  @override
  State<CleanupControls> createState() => _CleanupControlsState();
}

class _CleanupControlsState extends State<CleanupControls> {
  bool _up = false, _dn = false, _lt = false, _rt = false;
  late FocusNode _fk;

  @override
  void initState() {
    super.initState();
    _fk = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fk.requestFocus());
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

    if (k == LogicalKeyboardKey.keyW || k == LogicalKeyboardKey.arrowUp)
        { if (pressed) up(true); if (released) up(false); }
    if (k == LogicalKeyboardKey.keyS || k == LogicalKeyboardKey.arrowDown)
        { if (pressed) dn(true); if (released) dn(false); }
    if (k == LogicalKeyboardKey.keyA || k == LogicalKeyboardKey.arrowLeft)
        { if (pressed) lt(true); if (released) lt(false); }
    if (k == LogicalKeyboardKey.keyD || k == LogicalKeyboardKey.arrowRight)
        { if (pressed) rt(true); if (released) rt(false); }
    if (k == LogicalKeyboardKey.space && pressed) {
      widget.game.triggerScan();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.game,
      builder: (_, __) {
        final scanning = widget.game.scanLockActive;
        final canScan  = widget.game._hasNearbyUnscannedLitter;
        const actColor = Color(0xFFFFB300);

        return KeyboardListener(
          focusNode: _fk,
          onKeyEvent: _onKey,
          child: Stack(children: [
            Align(alignment: Alignment.bottomLeft, child: SafeArea(child: Padding(
              padding: const EdgeInsets.only(bottom: 16, left: 12),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                _CDPad('⬆', _up, Colors.cyanAccent,
                    onDown: () { setState(() => _up = true);  widget.game.setUpKey(true); },
                    onUp:   () { setState(() => _up = false); widget.game.setUpKey(false); }),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  _CDPad('◀', _lt, Colors.cyanAccent,
                      onDown: () { setState(() => _lt = true);  widget.game.setLeftKey(true); },
                      onUp:   () { setState(() => _lt = false); widget.game.setLeftKey(false); }),
                  const SizedBox(width: 4),
                  _CDPad('⬇', _dn, Colors.cyanAccent,
                      onDown: () { setState(() => _dn = true);  widget.game.setDownKey(true); },
                      onUp:   () { setState(() => _dn = false); widget.game.setDownKey(false); }),
                  const SizedBox(width: 4),
                  _CDPad('▶', _rt, Colors.cyanAccent,
                      onDown: () { setState(() => _rt = true);  widget.game.setRightKey(true); },
                      onUp:   () { setState(() => _rt = false); widget.game.setRightKey(false); }),
                ]),
              ]),
            ))),

            Align(alignment: Alignment.bottomRight, child: SafeArea(child: Padding(
              padding: const EdgeInsets.only(bottom: 20, right: 14),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                if (scanning)
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.70),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: actColor.withValues(alpha: 0.42)),
                    ),
                    child: const Text(
                      '🔒 Scanning litter — stay in range!',
                      style: TextStyle(color: Color(0xFFFFB300), fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ),
                GestureDetector(
                  onTap: () => widget.game.triggerScan(),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    width: 70, height: 70,
                    decoration: BoxDecoration(
                      color: canScan ? actColor.withValues(alpha: 0.22)
                                     : Colors.black.withValues(alpha: 0.60),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: canScan ? actColor : Colors.white24,
                          width: canScan ? 2.5 : 1.5),
                      boxShadow: canScan
                          ? [BoxShadow(color: actColor.withValues(alpha: 0.42), blurRadius: 16)]
                          : [],
                    ),
                    child: Center(child: Text(
                      scanning ? '🔒\nLOCK\nING…' : '📡\nSCAN',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: canScan ? actColor : Colors.white30,
                          fontWeight: FontWeight.w900, fontSize: 8, letterSpacing: 0.3, height: 1.3),
                    )),
                  ),
                ),
              ]),
            ))),
          ]),
        );
      },
    );
  }
}

class _CDPad extends StatelessWidget {
  final String label; final bool isActive; final Color color;
  final VoidCallback onDown, onUp;
  const _CDPad(this.label, this.isActive, this.color, {required this.onDown, required this.onUp});

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (_) => onDown(), onPointerUp: (_) => onUp(), onPointerCancel: (_) => onUp(),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 70),
      width: 52, height: 52, margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: isActive ? color.withValues(alpha: 0.30) : Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isActive ? color : Colors.white24, width: 1.8),
        boxShadow: isActive ? [BoxShadow(color: color.withValues(alpha: 0.40), blurRadius: 10)] : [],
      ),
      child: Center(child: Text(label, style: TextStyle(
          color: isActive ? color : Colors.white60, fontSize: 16, fontWeight: FontWeight.bold))),
    ),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
//  PHASE BANNER
// ══════════════════════════════════════════════════════════════════════════════
class CleanupPhaseBanner extends StatelessWidget {
  final HabitatCleanupGame game;
  const CleanupPhaseBanner(this.game, {super.key});

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFFFB300);
    return IgnorePointer(child: Center(child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF1A1000), Color(0xFF2E1800)]),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 24)],
        border: Border.all(color: accent.withValues(alpha: 0.55), width: 1.5),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('PHASE 1',
            style: TextStyle(color: Colors.white54, fontSize: 13, letterSpacing: 2.5)),
        const SizedBox(height: 4),
        const Text('🗑️  Waste Collection',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22)),
        const SizedBox(height: 6),
        Text(
          'Fly near litter then hold 📡 SCAN (1.5 s).\n'
          'Read the eco-fact, then tap SORT IT!\n'
          'Wrong bin keeps mini-game open — choose again.\n'
          '10 waste types to identify — learn them well!',
          textAlign: TextAlign.center,
          style: TextStyle(color: accent.withValues(alpha: 0.85), fontSize: 11.5),
        ),
      ]),
    )));
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  SCAN RESULT OVERLAY
// ══════════════════════════════════════════════════════════════════════════════
class HabitatScanResultOverlay extends StatefulWidget {
  final HabitatCleanupGame game;
  const HabitatScanResultOverlay(this.game, {super.key});
  @override
  State<HabitatScanResultOverlay> createState() => _HabitatScanResultOverlayState();
}

class _HabitatScanResultOverlayState extends State<HabitatScanResultOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _scale;

  @override
  void initState() {
    super.initState();
    _ctrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 340))..forward();
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.game,
      builder: (_, __) {
        final result = widget.game.lastScanResult;
        if (result == null) return const SizedBox.shrink();

        final displayDuration = result.hasEcoDiscovery ? 5.0 : 3.8;
        final progress = (widget.game.scanResultTimer / displayDuration).clamp(0.0, 1.0);
        final pts      = widget.game.lastScanPoints;

        return Center(
          child: ScaleTransition(
            scale: _scale,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 18),
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
              constraints: const BoxConstraints(maxWidth: 340),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xFF0A0A14), result.color.withValues(alpha: 0.12)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: result.color.withValues(alpha: 0.70), width: 2.0),
                boxShadow: [
                  BoxShadow(color: result.color.withValues(alpha: 0.28), blurRadius: 28),
                  const BoxShadow(color: Colors.black54, blurRadius: 18),
                ],
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [

                Row(children: [
                  SizedBox(width: 22, height: 22,
                    child: CustomPaint(painter: _ArcCountdownPainter(progress, result.color)),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('LITTER IDENTIFIED',
                      style: TextStyle(color: Colors.white54, fontSize: 9,
                          fontWeight: FontWeight.w900, letterSpacing: 1.8))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFB300).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFFFB300).withValues(alpha: 0.42)),
                    ),
                    child: Text('+$pts pts${pts >= 30 ? " 🌟" : ""}',
                        style: const TextStyle(color: Color(0xFFFFB300),
                            fontSize: 9, fontWeight: FontWeight.bold)),
                  ),
                ]),
                const SizedBox(height: 12),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: result.color.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: result.color.withValues(alpha: 0.55), width: 1.8),
                    boxShadow: [BoxShadow(color: result.color.withValues(alpha: 0.18), blurRadius: 10)],
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Text(result.icon, style: const TextStyle(fontSize: 28)),
                      const SizedBox(width: 10),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('ITEM IDENTIFIED',
                            style: TextStyle(color: result.color.withValues(alpha: 0.75),
                                fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                        const SizedBox(height: 2),
                        Text(result.typeName,
                            style: TextStyle(color: result.color, fontSize: 16,
                                fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                      ])),
                    ]),
                    const SizedBox(height: 8),
                    Text(result.ecoFact,
                        style: const TextStyle(color: Colors.white70, fontSize: 10, height: 1.5)),
                  ]),
                ),
                const SizedBox(height: 10),

                widget.game.scanResultShowsHints
                    ? Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('RECOMMENDED ACTION',
                              style: TextStyle(color: Colors.white38, fontSize: 7.5,
                                  fontWeight: FontWeight.w900, letterSpacing: 1.3)),
                          const SizedBox(height: 6),
                          Row(children: [
                            Container(width: 16, height: 16, alignment: Alignment.center,
                              decoration: BoxDecoration(color: result.color.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: result.color.withValues(alpha: 0.50))),
                              child: Text('✓', style: TextStyle(color: result.color,
                                  fontSize: 8, fontWeight: FontWeight.bold))),
                            const SizedBox(width: 6),
                            Expanded(child: Text(result.correctAction,
                                style: const TextStyle(color: Colors.white70, fontSize: 9.5, height: 1.3))),
                          ]),
                        ]),
                      )
                    : Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF69F0AE).withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF69F0AE).withValues(alpha: 0.35)),
                        ),
                        child: const Column(mainAxisSize: MainAxisSize.min, children: [
                          Text('🧠 YOU KNOW THIS ONE',
                              style: TextStyle(color: Color(0xFF69F0AE), fontSize: 9.5,
                                  fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                          SizedBox(height: 5),
                          Text('You\'ve handled this type before.\nApply the correct action from memory!',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white54, fontSize: 9.5, height: 1.4)),
                        ]),
                      ),
                const SizedBox(height: 14),

                GestureDetector(
                  onTap: () => widget.game.openSortSelectorForPending(),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: result.color.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: result.color, width: 2.0),
                      boxShadow: [BoxShadow(color: result.color.withValues(alpha: 0.38), blurRadius: 14)],
                    ),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(result.icon, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      Text('SORT IT  →  SELECT BIN',
                          style: TextStyle(color: result.color, fontSize: 13,
                              fontWeight: FontWeight.w900, letterSpacing: 0.8)),
                    ]),
                  ),
                ),
                const SizedBox(height: 6),
                const Text('or wait — auto-opens in a moment',
                    style: TextStyle(color: Colors.white24, fontSize: 8),
                    textAlign: TextAlign.center),
              ]),
            ),
          ),
        );
      },
    );
  }
}

class _ArcCountdownPainter extends CustomPainter {
  final double progress;
  final Color  color;
  const _ArcCountdownPainter(this.progress, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width/2; final cy = size.height/2;
    final r  = math.min(cx, cy) - 1.5;
    canvas.drawCircle(Offset(cx, cy), r,
        Paint()..color = Colors.white12..style = PaintingStyle.stroke..strokeWidth = 2.0);
    canvas.drawArc(Rect.fromCenter(center: Offset(cx, cy), width: r*2, height: r*2),
        -math.pi/2, math.pi*2*progress, false,
        Paint()..color = color.withValues(alpha: 0.80)
          ..style = PaintingStyle.stroke..strokeWidth = 2.5..strokeCap = StrokeCap.round);
  }
  @override bool shouldRepaint(_ArcCountdownPainter old) => old.progress != progress;
}

// ══════════════════════════════════════════════════════════════════════════════
//  SORT MINI-GAME  — 4 bins, wrong sort stays open, hints only on first encounter
// ══════════════════════════════════════════════════════════════════════════════
class SortMiniGame extends StatelessWidget {
  final HabitatCleanupGame game;
  const SortMiniGame(this.game, {super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: game,
      builder: (_, __) {
        final litterType = game.pendingSortTarget?.type;
        if (litterType == null || !game.sortSelectorOpen) return const SizedBox.shrink();

        final litEmoji = {
          LitterType.plasticBottle: '🥤',
          LitterType.polythene:     '🛍️',
          LitterType.foodWrap:      '🥡',
          LitterType.glassBottle:   '🍾',
          LitterType.metalCan:      '🥫',
          LitterType.paper:         '📄',
          LitterType.fruitPeel:     '🍌',
          LitterType.clothes:       '👕',
          LitterType.shoes:         '👟',
          LitterType.eWaste:        '🔋',
        }[litterType] ?? '?';

        const bins = [
          (WasteSort.recyclable,    '♻️', 'Recyclable',    'Plastics · Paper · Metal', Color(0xFF29B6F6)),
          (WasteSort.reusable,      '🔄', 'Reusable',      'Glass · Clothes · Shoes',  Color(0xFF69F0AE)),
          (WasteSort.biodegradable, '🌿', 'Biodegradable', 'Food · Peels · Organic',   Color(0xFF558B2F)),
          (WasteSort.harmful,       '☠️', 'Harmful',       'E-Waste · Batteries',      Color(0xFFEF5350)),
        ];

        final showHints  = game.sortShowsHints;
        final correctBin = {
          LitterType.plasticBottle: WasteSort.recyclable,
          LitterType.polythene:     WasteSort.recyclable,
          LitterType.foodWrap:      WasteSort.recyclable,
          LitterType.metalCan:      WasteSort.recyclable,
          LitterType.paper:         WasteSort.recyclable,
          LitterType.glassBottle:   WasteSort.reusable,
          LitterType.clothes:       WasteSort.reusable,
          LitterType.shoes:         WasteSort.reusable,
          LitterType.fruitPeel:     WasteSort.biodegradable,
          LitterType.eWaste:        WasteSort.harmful,
        }[litterType];

        return Container(
          color: Colors.black.withValues(alpha: 0.62),
          child: Center(child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 22),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF0A1008).withValues(alpha: 0.98),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFFFB300).withValues(alpha: 0.50)),
              boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 20)],
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Text(litEmoji, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('SORT THIS ITEM',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                  Text(
                    showHints ? 'Select the correct waste bin:' : '🧠 Recall from memory — no hints!',
                    style: TextStyle(
                        color: showHints ? const Color(0xFFFFB300) : const Color(0xFF69F0AE),
                        fontSize: 10, fontWeight: FontWeight.w700),
                  ),
                ])),
                GestureDetector(
                  onTap: game.cancelSortSelector,
                  child: Container(
                    width: 30, height: 30,
                    decoration: BoxDecoration(shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.08),
                        border: Border.all(color: Colors.white24)),
                    child: const Center(child: Text('✕',
                        style: TextStyle(color: Colors.white60, fontSize: 13))),
                  ),
                ),
              ]),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: bins.map((b) {
                  final (sort, emoji, label, desc, color) = b;
                  final isCorrect = showHints && sort == correctBin;

                  return GestureDetector(
                    onTap: () => game.sortLitter(sort),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 130),
                      width: 140,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      decoration: BoxDecoration(
                        color: isCorrect ? color.withValues(alpha: 0.22) : color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: isCorrect ? color : color.withValues(alpha: 0.45),
                            width: isCorrect ? 2.0 : 1.2),
                        boxShadow: isCorrect
                            ? [BoxShadow(color: color.withValues(alpha: 0.28), blurRadius: 10)]
                            : [],
                      ),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(emoji, style: const TextStyle(fontSize: 28)),
                        const SizedBox(height: 6),
                        Text(label,
                            style: TextStyle(
                                color: isCorrect ? color : color.withValues(alpha: 0.85),
                                fontWeight: FontWeight.w900, fontSize: 11)),
                        const SizedBox(height: 3),
                        Text(desc,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: isCorrect ? color.withValues(alpha: 0.90) : Colors.white54,
                                fontSize: 8.5, height: 1.3)),
                        if (isCorrect) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: color.withValues(alpha: 0.50)),
                            ),
                            child: Text('✓ correct', style: TextStyle(
                                color: color, fontSize: 8, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ]),
                    ),
                  );
                }).toList(),
              ),
            ]),
          )),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  REACTION FLASH
// ══════════════════════════════════════════════════════════════════════════════
class CleanupReactionFx extends StatelessWidget {
  final HabitatCleanupGame game;
  const CleanupReactionFx(this.game, {super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: game,
      builder: (_, __) {
        final ok      = game.reactionCorrect;
        final inRange = game.reactionInRange;
        final msg     = game.reactionMsg.isNotEmpty
            ? game.reactionMsg
            : (!inRange ? '🛰️  Out of range — fly closer'
                : ok ? '✅  Done!' : '❌  Wrong approach');
        final accent  = (ok && inRange)
            ? const Color(0xFF69F0AE) : const Color(0xFFEF5350);

        return IgnorePointer(child: Stack(children: [
          Container(decoration: BoxDecoration(
            border: Border.all(color: accent, width: 8),
            gradient: RadialGradient(
                colors: [Colors.transparent, accent.withValues(alpha: 0.12)], radius: 1.5),
          )),
          Center(child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 11),
            decoration: BoxDecoration(
              color: ok ? const Color(0xFF0A2A10).withValues(alpha: 0.94)
                        : const Color(0xFF2A0A0A).withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 14, spreadRadius: 2)],
            ),
            child: Text(msg, textAlign: TextAlign.center,
                style: TextStyle(color: accent, fontWeight: FontWeight.bold,
                    fontSize: 15, letterSpacing: 0.5)),
          )),
          if (game.showComboFlash && game.comboCount >= 2)
            Positioned(
              top: MediaQuery.of(context).size.height * 0.30,
              left: 0, right: 0,
              child: Center(child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6D00).withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: const Color(0xFFFF6D00).withValues(alpha: 0.42), blurRadius: 18)],
                ),
                child: Text(
                  game.comboCount >= 4 ? '🔥🔥🔥  ${game.comboCount}× COMBO!  3× POINTS!'
                      : game.comboCount == 3 ? '🔥🔥  ${game.comboCount}× COMBO!  2× POINTS!'
                      : '🔥  ${game.comboCount}× COMBO!  2× POINTS!',
                  style: const TextStyle(color: Colors.white,
                      fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.6),
                ),
              )),
            ),
        ]));
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  ECO-DISCOVERY OVERLAY
// ══════════════════════════════════════════════════════════════════════════════
class CleanupEcoDiscoveryOverlay extends StatefulWidget {
  final HabitatCleanupGame game;
  const CleanupEcoDiscoveryOverlay(this.game, {super.key});
  @override
  State<CleanupEcoDiscoveryOverlay> createState() => _CleanupEcoDiscoveryState();
}

class _CleanupEcoDiscoveryState extends State<CleanupEcoDiscoveryOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _scale;

  @override
  void initState() {
    super.initState();
    _ctrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 380))..forward();
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(child: Center(child: ScaleTransition(
      scale: _scale,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 28),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFF1A0A2E), Color(0xFF2A0A1A)],
              begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFE040FB).withValues(alpha: 0.72), width: 2.0),
          boxShadow: [BoxShadow(color: const Color(0xFFE040FB).withValues(alpha: 0.30), blurRadius: 32)],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('✨ ECO-DISCOVERY FOUND! ✨',
              style: TextStyle(color: Color(0xFFE040FB), fontSize: 13,
                  fontWeight: FontWeight.w900, letterSpacing: 1.5)),
          const SizedBox(height: 12),
          Text(widget.game.lastDiscoveryFact,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.65)),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFFE040FB).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE040FB).withValues(alpha: 0.45)),
            ),
            child: const Text('+30 Eco-Points  •  Cultural Heritage Bonus!',
                style: TextStyle(color: Color(0xFFE040FB), fontSize: 12, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 10),
          const Text('Sort the item next to complete collection',
              style: TextStyle(color: Colors.white38, fontSize: 10)),
        ]),
      ),
    )));
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  RESULTS OVERLAY
// ══════════════════════════════════════════════════════════════════════════════
class CleanupResultsOverlay extends StatelessWidget {
  final HabitatCleanupGame game;
  const CleanupResultsOverlay(this.game, {super.key});

  @override
  Widget build(BuildContext context) {
    final r        = HabitatCleanupResult.current!;
    final meetsMin = r.meetsMinimum;
    final stars    = r.correctSorts >= 14 ? '★★★'
                   : r.correctSorts >= 8  ? '★★☆'
                   : '★☆☆';
    final headerEmoji = meetsMin ? '🌿' : '🗑️';
    final headerText  = meetsMin ? 'Habitat Cleanup Complete!' : 'Mission Incomplete';
    final accent      = meetsMin ? const Color(0xFF69F0AE) : const Color(0xFFFFB300);

    return Container(
      color: Colors.black.withValues(alpha: 0.94),
      child: SafeArea(child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(children: [

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: meetsMin
                  ? [const Color(0xFF001A0A), const Color(0xFF003018)]
                  : [const Color(0xFF1A1000), const Color(0xFF2A1800)]),
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 16)],
            ),
            child: Column(children: [
              Text(headerEmoji, style: const TextStyle(fontSize: 50)),
              const SizedBox(height: 6),
              Text(headerText,
                  style: const TextStyle(color: Colors.white,
                      fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(r.performanceGrade,
                  style: TextStyle(color: accent, fontSize: 13,
                      fontWeight: FontWeight.w700, letterSpacing: 1.0)),
              const SizedBox(height: 4),
              const Text('Phase 1 — Waste Collection Results',
                  style: TextStyle(color: Colors.white54, fontSize: 12)),
              const SizedBox(height: 8),
              Text(stars, style: const TextStyle(
                  color: Color(0xFFFFB300), fontSize: 28, letterSpacing: 6)),
              if (meetsMin) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF69F0AE).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF69F0AE).withValues(alpha: 0.42)),
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('🏅', style: TextStyle(fontSize: 14)),
                    SizedBox(width: 6),
                    Text('Eco-Sorter Badge Unlocked!',
                        style: TextStyle(color: Color(0xFF69F0AE),
                            fontWeight: FontWeight.w800, fontSize: 11.5)),
                  ]),
                ),
              ],
            ]),
          ),
          const SizedBox(height: 14),

          _CRCard(children: [
            _CRBig('🗑️', '${r.correctSorts}/${r.litterCollected}', 'Sorted Correctly', Colors.limeAccent),
            _CRBig('❌', '${r.wrongSorts}', 'Wrong Sorts', r.wrongSorts > 0 ? Colors.redAccent : Colors.white38),
            _CRBig('🎯', '${r.accuracyPct}%', 'Sort Accuracy',
                r.accuracyPct >= 80 ? const Color(0xFF69F0AE)
                    : r.accuracyPct >= 50 ? const Color(0xFFFFB300) : Colors.redAccent),
            _CRBig('🔥', '${r.maxCombo}×', 'Max Combo', const Color(0xFFFF6D00)),
          ]),
          const SizedBox(height: 8),

          _CRCard(children: [
            _CRBig('⭐', '${r.ecoPoints}', 'Eco Points', Colors.amber),
            _CRBig('📊', '${r.correctSorts + r.wrongSorts}', 'Total Attempts', const Color(0xFF90A4AE)),
            if (r.scanStreakBonus > 0)
              _CRBig('🎯', '+${r.scanStreakBonus}', 'Streak Bonus', const Color(0xFFE040FB)),
            _CRBig('🌍', '${r.ecoDiscoveriesFound}/2', 'Eco Discovers', const Color(0xFFE040FB)),
            _CRBig('⏱️', r.timeBonusCollected ? 'YES' : 'NO', 'Time Bonus', r.timeBonusCollected ? const Color(0xFFFFD700) : Colors.white38),
          ]),
          const SizedBox(height: 10),

          if (r.performanceSummary.isNotEmpty && r.performanceSummary !=
              'Collect and sort all litter to maximise your score.')
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0A0A12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(children: [
                const Text('YOUR PERFORMANCE',
                    style: TextStyle(color: Colors.white54, fontSize: 10,
                        fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                const SizedBox(height: 8),
                Text(r.performanceSummary,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 11, height: 1.6)),
              ]),
            ),
          const SizedBox(height: 10),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0A1A08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white24),
            ),
            child: Column(children: [
              const Text('LEVEL SUMMARY',
                  style: TextStyle(color: Colors.white54, fontSize: 10,
                      fontWeight: FontWeight.w900, letterSpacing: 1.2)),
              const SizedBox(height: 8),
              Text(r.endReason,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 11.5, height: 1.5)),
            ]),
          ),
          const SizedBox(height: 10),

          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: const Color(0xFF0A1A08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(children: [
              const Text('Sorting Reference',
                  style: TextStyle(color: Colors.white70, fontSize: 12,
                      fontWeight: FontWeight.bold, letterSpacing: 1)),
              const SizedBox(height: 10),
              _CRRow('🥤🛍️📄🥫', 'Plastics · Paper · Metal', '♻️ Recyclable Bin'),
              _CRRow('🍾👕👟', 'Glass · Clothes · Shoes', '🔄 Reusable Bin'),
              _CRRow('🍌🥡', 'Fruit Peels · Organic', '🌿 Biodegradable Bin'),
              _CRRow('🔋', 'E-Waste · Batteries', '☠️ Harmful Bin'),
            ]),
          ),
          const SizedBox(height: 18),

          SizedBox(
            width: double.infinity,
            child: meetsMin
                ? ElevatedButton.icon(
                    onPressed: () {
                      game.resumeEngine();
                      game.onLevelComplete();
                    },
                    icon: const Icon(Icons.water_drop_rounded),
                    label: const Text('Continue to Pond Cleaning  →',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.7)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00897B),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 8,
                    ),
                  )
                : Column(children: [
                    ElevatedButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.replay_rounded),
                      label: Text(
                        'Replay  — Sort ${r.minimumLitterRequired - r.correctSorts} More Item(s)',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEF5350),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        minimumSize: const Size(double.infinity, 0),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 8,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFB300).withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFFB300).withValues(alpha: 0.35)),
                      ),
                      child: Text(
                        '💡 Fly near litter and hold SCAN (1.5 s).\n'
                        'Read the eco-fact, tap SORT IT and pick the correct bin.\n'
                        'Minimum ${r.minimumLitterRequired} correct sorts needed to advance.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xFFFFB300), fontSize: 11, height: 1.5),
                      ),
                    ),
                  ]),
          ),
        ]),
      )),
    );
  }
}

class _CRCard extends StatelessWidget {
  final List<Widget> children;
  const _CRCard({required this.children});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
    decoration: BoxDecoration(
        color: const Color(0xFF0A1A08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12)),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: children),
  );
}

class _CRBig extends StatelessWidget {
  final String emoji, value, label;
  final Color  color;
  const _CRBig(this.emoji, this.value, this.label, this.color);
  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
    Text(emoji, style: const TextStyle(fontSize: 20)),
    const SizedBox(height: 3),
    Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 17)),
    const SizedBox(height: 2),
    Text(label, textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white54, fontSize: 8.5)),
  ]);
}

class _CRRow extends StatelessWidget {
  final String emoji, label, action;
  const _CRRow(this.emoji, this.label, this.action);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4.5),
    child: Row(children: [
      Text(emoji, style: const TextStyle(fontSize: 14)),
      const SizedBox(width: 8),
      Expanded(child: Text(label,
          style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600))),
      Text(action, style: const TextStyle(color: Color(0xFF69F0AE), fontSize: 9.5)),
    ]),
  );
}