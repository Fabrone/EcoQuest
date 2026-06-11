import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:ecoquest/game/level6/degraded_park_screen.dart';
import 'package:ecoquest/game/level6/level6_complete_screen.dart';
import 'package:flame/components.dart' hide Matrix4;
import 'package:flame/game.dart' hide Matrix4;
import 'package:flutter/material.dart' hide Matrix4;
import 'package:flutter/services.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  AWARENESS POSTER CRAFTING GAME  —  EcoQuest Level 6 Phase 4
//  Standalone Poster Design & Placement Game
//  
//  FLOW: WildlifeRescueScreen (Phase 3) → PosterCraftingGameScreen (Phase 4) → Level6CompleteScreen
//  
//  CRAFTING SYSTEM:
//    • Materials from Level 1: Natural Dyes (color selection)
//    • Materials from Level 3: Crafted items (recycled paper, cardboard frames)
//    • Materials from Level 4: Gypsum (chalk/white pigment), Urea (binder)
//    • Materials from Level 5: Compost (natural ink), Biochar (black pigment)
//    • Materials from Level 6: Collected litter (recycled materials for frames)
//  
//  GAMEPLAY:
//    1. Select a poster template (5 conservation themes)
//    2. Craft the poster using available materials (dye + chalk + recycled base)
//    3. Fly drone to poster board locations
//    4. Place crafted poster at matching-theme board for bonus points
//    5. 5 boards total — all must be filled to complete the level
//  
//  MECHANICS:
//    • First-hint / Memory-recall: First craft shows recipe hints
//    • Material scarcity: Limited dyes/chalk from earlier levels
//    • Theme matching: Correct theme at board = +10 bonus pts
//    • Combo system: Consecutive correct placements = multiplier
//    • Eco-Discovery: 2 boards have hidden cultural facts
// ══════════════════════════════════════════════════════════════════════════════

// ── Result class passed to Level6CompleteScreen ──────────────────────────────
class PosterCraftingResult {
  final int    postersPlaced;
  final int    correctThemeMatches;
  final int    ecoPoints;
  final int    materialsUsed;
  final int    maxCombo;
  final int    ecoDiscoveriesFound;
  final bool   allPostersCrafted;
  final bool   meetsMinimum;
  final int    minimumRequired;

  const PosterCraftingResult({
    required this.postersPlaced,
    required this.correctThemeMatches,
    required this.ecoPoints,
    required this.materialsUsed,
    this.maxCombo              = 1,
    this.ecoDiscoveriesFound   = 0,
    this.allPostersCrafted    = false,
    this.meetsMinimum          = false,
    this.minimumRequired       = 3,
  });

  String get performanceGrade {
    if (postersPlaced >= 5 && correctThemeMatches >= 4) return 'MASTER AWARENESS CAMPAIGNER';
    if (postersPlaced >= 4 && correctThemeMatches >= 2) return 'ECO EDUCATOR';
    if (postersPlaced >= 3) return 'PARK AMBASSADOR';
    return 'JUNIOR VOLUNTEER';
  }

  String get performanceSummary {
    final lines = <String>[];
    if (correctThemeMatches >= 4) lines.add('Matched $correctThemeMatches/5 themes perfectly — maximum awareness impact!');
    if (ecoDiscoveriesFound > 0) lines.add('Found $ecoDiscoveriesFound hidden cultural fact(s)');
    if (maxCombo >= 3) lines.add('$maxCombo-placement combo achieved — 2x point multiplier!');
    if (allPostersCrafted) lines.add('All 5 posters crafted and placed — full park coverage!');
    return lines.isEmpty
        ? 'Craft and place posters to spread conservation awareness.'
        : lines.join('\n');
  }

  static PosterCraftingResult? current;
}

// ── Carry-over data that flows into Phase 4 ─────────────────────────────────
// This is passed from WildlifeRescueScreen after Phase 3 completes
class Phase4CarryOver {
  final Level5CarryOver level5Data;
  final int animalsRescued;
  final int criticalSaves;
  final int ecoDiscoveriesFound;
  final int rescueEcoPoints;
  final double habitatHealth;

  const Phase4CarryOver({
    required this.level5Data,
    this.animalsRescued      = 0,
    this.criticalSaves       = 0,
    this.ecoDiscoveriesFound  = 0,
    this.rescueEcoPoints      = 0,
    this.habitatHealth        = 0,
  });
}

// ── Enums ───────────────────────────────────────────────────────────────────
enum PosterTheme {
  deforestation,      // Forest boards (near dead trees)
  waterPollution,   // Wetland boards (near ponds)
  soilHealth,       // Dry land boards (near degraded soil)
  wildlifeProtection, // Park centre (near animal paths)
  wasteManagement,    // Entry boards (near park entrance)
}

enum CraftMaterial {
  naturalDye,      // From Level 1 — color pigment
  chalkGypsum,     // From Level 4 — white pigment/text
  recycledPaper,   // From Level 3 — poster base
  compostInk,      // From Level 5 — natural ink/binder
  biocharBlack,    // From Level 5 — black pigment
  litterFrame,     // From Level 6 Phase 1 — recycled frame
}

// ── Crafting recipe for each theme ──────────────────────────────────────────
class PosterRecipe {
  final PosterTheme theme;
  final String title;
  final String description;
  final String icon;
  final Color accentColor;
  final Map<CraftMaterial, int> requiredMaterials;
  final String ecoFact;

  const PosterRecipe({
    required this.theme,
    required this.title,
    required this.description,
    required this.icon,
    required this.accentColor,
    required this.requiredMaterials,
    required this.ecoFact,
  });

  static const recipes = {
    PosterTheme.deforestation: PosterRecipe(
      theme: PosterTheme.deforestation,
      title: 'Save Our Forests',
      description: 'Plant trees, protect watersheds, fight deforestation',
      icon: '🌳',
      accentColor: Color(0xFF2E7D32),
      requiredMaterials: {
        CraftMaterial.recycledPaper: 1,
        CraftMaterial.naturalDye: 1,
        CraftMaterial.compostInk: 1,
      },
      ecoFact: 'Kenya forests cover only 6% of the land — down from 12% in 1960. Every poster plants a seed of awareness.',
    ),
    PosterTheme.waterPollution: PosterRecipe(
      theme: PosterTheme.waterPollution,
      title: 'Clean Water = Life',
      description: 'Protect wetlands, filter runoff, save our rivers',
      icon: '💧',
      accentColor: Color(0xFF0288D1),
      requiredMaterials: {
        CraftMaterial.recycledPaper: 1,
        CraftMaterial.chalkGypsum: 1,
        CraftMaterial.compostInk: 1,
      },
      ecoFact: 'The Ondiri Wetland filters water for 50,000 Kiambu residents. Protecting it protects the community.',
    ),
    PosterTheme.soilHealth: PosterRecipe(
      theme: PosterTheme.soilHealth,
      title: 'Healthy Soil, Healthy Future',
      description: 'Compost, avoid chemicals, prevent erosion',
      icon: '🌱',
      accentColor: Color(0xFF558B2F),
      requiredMaterials: {
        CraftMaterial.recycledPaper: 1,
        CraftMaterial.biocharBlack: 1,
        CraftMaterial.compostInk: 1,
      },
      ecoFact: 'One teaspoon of healthy soil contains more organisms than there are humans on Earth. Respect the soil.',
    ),
    PosterTheme.wildlifeProtection: PosterRecipe(
      theme: PosterTheme.wildlifeProtection,
      title: 'Protect Our Wildlife',
      description: 'Habitat corridors, anti-poaching, coexistence',
      icon: '🦓',
      accentColor: Color(0xFFEF5350),
      requiredMaterials: {
        CraftMaterial.recycledPaper: 1,
        CraftMaterial.naturalDye: 1,
        CraftMaterial.litterFrame: 1,
      },
      ecoFact: 'The zebra, crane, and colobus monkey of Ondiri are keystone species — their survival signals ecosystem health.',
    ),
    PosterTheme.wasteManagement: PosterRecipe(
      theme: PosterTheme.wasteManagement,
      title: 'Reduce, Reuse, Recycle',
      description: 'Sort waste, compost organic, repurpose materials',
      icon: '♻️',
      accentColor: Color(0xFF29B6F6),
      requiredMaterials: {
        CraftMaterial.recycledPaper: 1,
        CraftMaterial.litterFrame: 1,
        CraftMaterial.chalkGypsum: 1,
      },
      ecoFact: 'Karura Forest was saved by community action — the same spirit that sorts litter today protects parks forever.',
    ),
  };
}

// ── Eco-Discovery facts for poster boards ───────────────────────────────────
class PosterEcoDiscovery {
  final String fact;
  final String bonus;

  const PosterEcoDiscovery({required this.fact, required this.bonus});

  static const discoveries = [
    PosterEcoDiscovery(
      fact: '🏺 Cultural Marker! The Kikuyu "Mũgumo" fig tree was sacred — posters near trees honour an ancestral covenant to protect forests.',
      bonus: '+15 Cultural Heritage Bonus',
    ),
    PosterEcoDiscovery(
      fact: '🌿 Cultural Marker! Ondiri elders used "githiga" compost mounds — the same organic wisdom now powers your compost ink posters.',
      bonus: '+15 Ancestral Wisdom Bonus',
    ),
  ];
}

// ══════════════════════════════════════════════════════════════════════════════
//  SCREEN WRAPPER
// ══════════════════════════════════════════════════════════════════════════════
class PosterCraftingGameScreen extends StatefulWidget {
  final Phase4CarryOver carryOver;
  const PosterCraftingGameScreen({super.key, required this.carryOver});

  @override
  State<PosterCraftingGameScreen> createState() => _PosterCraftingGameScreenState();
}

class _PosterCraftingGameScreenState extends State<PosterCraftingGameScreen> {
  late PosterCraftingGame _game;

  @override
  void initState() {
    super.initState();
    _game = PosterCraftingGame(
      carryOver:       widget.carryOver,
      onLevelComplete: _onDone,
    );
  }

  void _onDone() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => Level6CompleteScreen(carryOver: widget.carryOver.level5Data),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GameWidget(
        game: _game,
        overlayBuilderMap: {
          'hud':              (ctx, g) => PosterHud(g as PosterCraftingGame),
          'controls':         (ctx, g) => PosterControls(g as PosterCraftingGame),
          'banner':           (ctx, g) => PosterPhaseBanner(g as PosterCraftingGame),
          'craftingStation':  (ctx, g) => CraftingStationOverlay(g as PosterCraftingGame),
          'materialTray':     (ctx, g) => MaterialTrayOverlay(g as PosterCraftingGame),
          'reactionFx':       (ctx, g) => PosterReactionFx(g as PosterCraftingGame),
          'ecoDiscovery':     (ctx, g) => PosterEcoDiscoveryOverlay(g as PosterCraftingGame),
          'results':          (ctx, g) => PosterResultsOverlay(g as PosterCraftingGame),
        },
        initialActiveOverlays: const ['hud', 'controls', 'materialTray'],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  MAIN GAME CLASS
// ══════════════════════════════════════════════════════════════════════════════
class PosterCraftingGame extends FlameGame
    with HasCollisionDetection, ChangeNotifier {

  final Phase4CarryOver carryOver;
  final VoidCallback    onLevelComplete;

  PosterCraftingGame({required this.carryOver, required this.onLevelComplete});

  static const int kMinPostersRequired = 3;
  static const int totalPosters = 5;

  bool   gameStarted = false;
  double timeLeft    = 120.0;
  bool   levelDone   = false;

  int ecoPoints           = 0;
  int postersPlaced       = 0;
  int correctThemeMatches = 0;
  int materialsUsed       = 0;

  static const double _placeRange = 90.0;

  late Vector2 dronePos;
  bool isUp = false, isDown = false, isLeft = false, isRight = false;
  static const double _droneSpeed = 175.0;
  double _idleTimer = 0;

  Map<CraftMaterial, int> availableMaterials = {};
  Map<CraftMaterial, int> usedMaterials = {};

  PosterTheme? selectedTheme;
  bool craftingStationOpen = false;
  bool showCraftingHints = true;

  PosterRecipe? craftedPoster;
  bool hasCraftedPoster = false;

  int    comboCount      = 0;
  double comboTimer      = 0;
  int    maxCombo        = 1;
  bool   showComboFlash  = false;
  double comboFlashTimer = 0;
  static const double _comboWindow = 5.0;

  final Set<int> ecoDiscoveryIndices = {};
  final Set<int> discoveredEcoBoards = {};
  int             ecoDiscoveriesFound  = 0;
  String          lastDiscoveryFact    = '';
  double          discoveryDisplayTimer = 0;
  static const double _discoveryDisplay = 4.0;

  final Set<PosterTheme> _craftedThemes = {};

  String ecoGuideHint   = '';
  double ecoGuideTimer  = 0;
  double _hintCooldown  = 0;

  String reactionMsg = '';

  bool   reactionActive  = false;
  bool   reactionCorrect = false;
  bool   reactionInRange = true;
  double reactionTimer   = 0;

  double bannerTimer = 3.5;

  late PosterDroneComponent drone;
  final List<PosterBoard>    posterBoards = [];

  @override
  Future<void> onLoad() async {
    super.onLoad();
    dronePos = Vector2(size.x * 0.50, size.y * 0.52);

    _initMaterials();

    add(PosterParkRenderer(game: this));
    drone = PosterDroneComponent(game: this);
    add(drone);

    _spawnPosterBoards();
    _assignEcoDiscoveries();

    bannerTimer = 3.5;
    overlays.add('banner');
    add(TimerComponent(period: 1.0, repeat: true, onTick: _onSecond));
  }

  void _initMaterials() {
    availableMaterials = {
      CraftMaterial.naturalDye:   carryOver.level5Data.naturalDyes,
      CraftMaterial.chalkGypsum:  carryOver.level5Data.gypsum,
      CraftMaterial.recycledPaper: math.max(5, carryOver.level5Data.compost ~/ 2),
      CraftMaterial.compostInk:   carryOver.level5Data.compost,
      CraftMaterial.biocharBlack: carryOver.level5Data.biochar,
      CraftMaterial.litterFrame:  math.max(3, carryOver.level5Data.ecoPoints ~/ 50),
    };

    availableMaterials.updateAll((key, value) => math.max(value, 1));
    usedMaterials = {for (var k in CraftMaterial.values) k: 0};
  }

  void _spawnPosterBoards() {
    final locs = [
      (0.12, 0.25, PosterTheme.deforestation),
      (0.38, 0.18, PosterTheme.waterPollution),
      (0.62, 0.30, PosterTheme.wildlifeProtection),
      (0.80, 0.55, PosterTheme.soilHealth),
      (0.20, 0.70, PosterTheme.wasteManagement),
    ];
    for (int i = 0; i < locs.length; i++) {
      final (rx, ry, recommended) = locs[i];
      final b = PosterBoard(
        game: this,
        worldX: size.x * rx, worldY: size.y * ry,
        seed: i * 11,
        recommendedTheme: recommended,
        index: i,
      );
      add(b);
      posterBoards.add(b);
    }
  }

  void _assignEcoDiscoveries() {
    final rng = math.Random(DateTime.now().millisecondsSinceEpoch);
    final indices = List.generate(posterBoards.length, (i) => i)..shuffle(rng);
    ecoDiscoveryIndices.add(indices[0]);
    ecoDiscoveryIndices.add(indices[1]);
  }

  void _onSecond() {
    if (!gameStarted || levelDone) return;
    timeLeft -= 1;
    if (timeLeft <= 0) { timeLeft = 0; _endLevel(); }
    notifyListeners();
  }

  bool get _hasNearbyBoard {
    final board = _nearestBoard;
    if (board == null) return false;
    return (board.boardPos - dronePos).length <= _placeRange;
  }

  PosterBoard? get _nearestBoard {
    PosterBoard? target;
    double best = _placeRange;
    for (final b in posterBoards) {
      if (b.hasPosted) continue;
      final d = (b.boardPos - dronePos).length;
      if (d < best) { best = d; target = b; }
    }
    return target;
  }

  bool get _canCraftSelected {
    if (selectedTheme == null) return false;
    final recipe = PosterRecipe.recipes[selectedTheme]!;
    for (final entry in recipe.requiredMaterials.entries) {
      if ((availableMaterials[entry.key] ?? 0) < entry.value) return false;
    }
    return true;
  }

  void openCraftingStation() {
    if (!gameStarted || levelDone) return;
    gameStarted = true;
    HapticFeedback.selectionClick();

    if (hasCraftedPoster) {
      reactionMsg = '📋 Place your crafted poster first!';
      _triggerReaction(false, inRange: false);
      notifyListeners();
      return;
    }

    craftingStationOpen = true;
    overlays.add('craftingStation');
    notifyListeners();
  }

  void selectTheme(PosterTheme theme) {
    selectedTheme = theme;
    notifyListeners();
  }

  void craftPoster() {
    if (selectedTheme == null || !_canCraftSelected) return;

    HapticFeedback.heavyImpact();
    final recipe = PosterRecipe.recipes[selectedTheme]!;

    for (final entry in recipe.requiredMaterials.entries) {
      availableMaterials[entry.key] = (availableMaterials[entry.key] ?? 0) - entry.value;
      usedMaterials[entry.key] = (usedMaterials[entry.key] ?? 0) + entry.value;
      materialsUsed += entry.value;
    }

    craftedPoster = recipe;
    hasCraftedPoster = true;
    craftingStationOpen = false;
    overlays.remove('craftingStation');

    final firstTime = !_craftedThemes.contains(selectedTheme!);
    if (firstTime) _craftedThemes.add(selectedTheme!);
    showCraftingHints = firstTime;

    reactionMsg = '🎨 ${recipe.title} crafted!  Fly to a board and place it!';
    _triggerReaction(true);
    notifyListeners();
  }

  void cancelCrafting() {
    craftingStationOpen = false;
    selectedTheme = null;
    overlays.remove('craftingStation');
    notifyListeners();
  }

  void placePoster() {
    if (!gameStarted || levelDone) return;
    if (!hasCraftedPoster || craftedPoster == null) {
      reactionMsg = '🎨 Craft a poster first at the crafting station!';
      _triggerReaction(false, inRange: false);
      notifyListeners();
      return;
    }

    final target = _nearestBoard;
    if (target == null) {
      reactionMsg = '📌 No empty board in range — fly closer!';
      _triggerReaction(false, inRange: false);
      notifyListeners();
      return;
    }

    HapticFeedback.lightImpact();

    final isRecommended = craftedPoster!.theme == target.recommendedTheme;
    target.post(craftedPoster!.theme, isRecommended);
    postersPlaced++;

    if (isRecommended) correctThemeMatches++;

    final basePts = 20;
    final bonusPts = isRecommended ? 15 : 0;
    final comboMult = _comboMult();
    final totalPts = (basePts + bonusPts) * comboMult;

    ecoPoints += totalPts;
    _incCombo();

    final idx = posterBoards.indexOf(target);
    if (ecoDiscoveryIndices.contains(idx) && !discoveredEcoBoards.contains(idx)) {
      ecoDiscoveriesFound++;
      discoveredEcoBoards.add(idx);
      lastDiscoveryFact = PosterEcoDiscovery.discoveries[discoveredEcoBoards.length - 1].fact;
      discoveryDisplayTimer = _discoveryDisplay;
      overlays.add('ecoDiscovery');
      ecoPoints += 15;
    }

    if (isRecommended) {
      reactionMsg = '📋 Poster placed!  +$totalPts pts  ✓ Perfect theme match!';
    } else {
      reactionMsg = '📋 Poster placed!  +$totalPts pts';
    }
    _triggerReaction(true);

    craftedPoster = null;
    hasCraftedPoster = false;
    selectedTheme = null;

    if (posterBoards.every((b) => b.hasPosted)) {
      Future.delayed(const Duration(milliseconds: 800), _endLevel);
    }
    notifyListeners();
  }

  int _comboMult() {
    if (comboCount >= 3) return 2;
    return 1;
  }

  void _incCombo() {
    comboCount++;
    comboTimer = _comboWindow;
    if (comboCount > maxCombo) maxCombo = comboCount;
    showComboFlash = true;
    comboFlashTimer = 1.8;
    notifyListeners();
  }

  void _breakCombo() {
    comboCount = 0;
    comboTimer = 0;
  }

  void _checkHints() {
    if (_hintCooldown > 0 || ecoGuideTimer > 0) return;
    if (_idleTimer > 4.5) {
      if (!hasCraftedPoster) {
        ecoGuideHint = '🎨 Open the crafting station, select a theme, and craft a poster using your materials!';
      } else {
        ecoGuideHint = '📌 Fly to an empty board and tap PLACE to install your poster!';
      }
      ecoGuideTimer = 3.5;
      _hintCooldown = 12;
      _idleTimer = 0;
    }
    notifyListeners();
  }

  void setUpKey(bool v)    { isUp    = v; if (v) gameStarted = true; _idleTimer = 0; }
  void setDownKey(bool v)  { isDown  = v; if (v) gameStarted = true; _idleTimer = 0; }
  void setLeftKey(bool v)  { isLeft  = v; if (v) gameStarted = true; _idleTimer = 0; }
  void setRightKey(bool v) { isRight = v; if (v) gameStarted = true; _idleTimer = 0; }

  void _triggerReaction(bool correct, {bool inRange = true}) {
    reactionActive  = true;
    reactionCorrect = correct;
    reactionInRange = inRange;
    reactionTimer   = 1.3;
    overlays.add('reactionFx');
  }

  void _endLevel() {
    if (levelDone) return;
    levelDone = true;
    pauseEngine();

    final meetsMin = postersPlaced >= kMinPostersRequired;
    final allPlaced = posterBoards.every((b) => b.hasPosted);

    PosterCraftingResult.current = PosterCraftingResult(
      postersPlaced:       postersPlaced,
      correctThemeMatches: correctThemeMatches,
      ecoPoints:           ecoPoints,
      materialsUsed:       materialsUsed,
      maxCombo:            maxCombo,
      ecoDiscoveriesFound: ecoDiscoveriesFound,
      allPostersCrafted:   allPlaced,
      meetsMinimum:        meetsMin,
      minimumRequired:     kMinPostersRequired,
    );

    overlays
      ..remove('reactionFx')
      ..remove('craftingStation')
      ..remove('materialTray')
      ..remove('ecoDiscovery')
      ..add('results');
    notifyListeners();
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
      if (reactionTimer <= 0) {
        reactionActive = false;
        overlays.remove('reactionFx');
      }
    }
    if (ecoGuideTimer > 0)  { ecoGuideTimer -= dt; if (ecoGuideTimer <= 0) ecoGuideHint = ''; }
    if (_hintCooldown > 0)  _hintCooldown -= dt;
    if (discoveryDisplayTimer > 0) {
      discoveryDisplayTimer -= dt;
      if (discoveryDisplayTimer <= 0) overlays.remove('ecoDiscovery');
    }
    if (comboFlashTimer > 0) {
      comboFlashTimer -= dt;
      if (comboFlashTimer <= 0) showComboFlash = false;
    }

    if (!gameStarted || levelDone) { notifyListeners(); return; }

    double vx = 0, vy = 0;
    if (isLeft)  vx -= 1;
    if (isRight) vx += 1;
    if (isUp)    vy -= 1;
    if (isDown)  vy += 1;

    final moving = vx != 0 || vy != 0;
    if (!moving) {
      _idleTimer += dt;
    } else {
      _idleTimer = 0;
    }
    if (_idleTimer > 4.5) _checkHints();

    dronePos.x = (dronePos.x + vx * _droneSpeed * dt).clamp(30, size.x - 30);
    dronePos.y = (dronePos.y + vy * _droneSpeed * dt).clamp(40, size.y * 0.88);

    if (comboCount > 0) {
      comboTimer -= dt;
      if (comboTimer <= 0) _breakCombo();
    }

    notifyListeners();
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  RESTORED PARK RENDERER (Phase 4 — park is now recovering)
// ══════════════════════════════════════════════════════════════════════════════
class PosterParkRenderer extends Component {
  final PosterCraftingGame game;
  double _t = 0;
  PosterParkRenderer({required this.game});

  @override
  void update(double dt) => _t += dt * 0.2;

  @override
  void render(Canvas canvas) {
    final w = game.size.x, h = game.size.y;

    canvas.drawRect(Rect.fromLTWH(0, 0, w, h),
        Paint()..shader = ui.Gradient.linear(
            Offset.zero, Offset(0, h), [
          const Color(0xFF060E08),
          Color.lerp(const Color(0xFF0A1808), const Color(0xFF0E2010),
              (math.sin(_t) * 0.5 + 0.5) * 0.4)!,
          const Color(0xFF060A04),
        ], [0.0, 0.5, 1.0]));

    final hr = (game.postersPlaced / PosterCraftingGame.totalPosters).clamp(0.0, 1.0);
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h),
        Paint()
          ..color = const Color(0xFF69F0AE).withValues(alpha: hr * 0.08)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30));

    _drawField(canvas, w, h);
    canvas.drawRect(Rect.fromLTWH(0, h * 0.86, w, h * 0.14),
        Paint()..color = const Color(0xFF040806));
  }

  void _drawField(Canvas canvas, double w, double h) {
    final rng = math.Random(66);
    for (final (bx, by, bw, bh) in [
      (0.02, 0.02, 0.22, 0.26), (0.26, 0.02, 0.22, 0.26),
      (0.50, 0.02, 0.22, 0.26), (0.74, 0.02, 0.24, 0.26),
      (0.02, 0.32, 0.22, 0.22), (0.26, 0.32, 0.22, 0.22),
      (0.50, 0.32, 0.22, 0.22), (0.74, 0.32, 0.24, 0.22),
      (0.02, 0.58, 0.22, 0.20),
    ]) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(w * bx + 4, h * by + 4, w * bw - 8, h * bh - 8),
              const Radius.circular(3)),
          Paint()..color = const Color(0xFF0A1608));
      _drawVegetation(canvas, w * bx + 6, h * by + 6, w * bw - 12, h * bh - 12, rng);
    }
  }

  void _drawVegetation(Canvas canvas, double bx, double by,
      double bw, double bh, math.Random rng) {
    for (int i = 0; i < 7; i++) {
      final gx = bx + rng.nextDouble() * bw;
      final gy = by + rng.nextDouble() * bh;
      canvas.drawLine(Offset(gx, gy), Offset(gx, gy - 8),
          Paint()
            ..color = const Color(0xFF2E4A20).withValues(alpha: 0.55)
            ..strokeWidth = 1.2);
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  POSTER DRONE COMPONENT
// ══════════════════════════════════════════════════════════════════════════════
class PosterDroneComponent extends Component {
  final PosterCraftingGame game;
  double _t = 0;
  PosterDroneComponent({required this.game});

  @override
  void update(double dt) => _t += dt;

  @override
  void render(Canvas canvas) {
    final cx = game.dronePos.x;
    final cy = game.dronePos.y + math.sin(_t * 3.0) * 2.5;

    final rangeColor = const Color(0xFF1E88E5);
    final rangeR = PosterCraftingGame._placeRange;

    canvas.drawCircle(Offset(cx, cy), rangeR,
        Paint()
          ..color = rangeColor.withValues(alpha: 0.065)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2);

    if (game.hasCraftedPoster) {
      canvas.drawCircle(Offset(cx, cy), 18,
          Paint()
            ..color = const Color(0xFF69F0AE).withValues(alpha: 0.25)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
    }

    canvas.save();
    canvas.translate(cx, cy);

    canvas.drawOval(
        Rect.fromCenter(center: const Offset(0, 14), width: 38, height: 9),
        Paint()..color = Colors.black.withValues(alpha: 0.28));

    final armPaint = Paint()
      ..color = const Color(0xFF1A2E18)
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;
    for (final (dx, dy) in [(-1, -1), (1, -1), (-1, 1), (1, 1)]) {
      canvas.drawLine(Offset(dx * 8, dy * 8), Offset(dx * 22, dy * 22), armPaint);
    }

    const propPositions = [(-22.0, -22.0), (22.0, -22.0), (-22.0, 22.0), (22.0, 22.0)];
    for (final (px, py) in propPositions) {
      canvas.save();
      canvas.translate(px, py);
      canvas.rotate(_t * 13);
      final propPaint = Paint()
        ..color = const Color(0xFF1E88E5).withValues(alpha: 0.55)
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(const Offset(-8, 0), const Offset(8, 0), propPaint);
      canvas.drawLine(const Offset(0, -8), const Offset(0, 8), propPaint);
      canvas.restore();
    }

    canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(-13, -10, 26, 20), const Radius.circular(6)),
        Paint()..color = const Color(0xFF142810));

    final glowColor = game.hasCraftedPoster
        ? const Color(0xFF69F0AE)
        : const Color(0xFF1E88E5);
    canvas.drawCircle(Offset.zero, 7,
        Paint()
          ..color = glowColor.withValues(alpha: 0.75 + math.sin(_t * 4) * 0.20)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    canvas.drawCircle(Offset.zero, 3.5,
        Paint()..color = Colors.white.withValues(alpha: 0.95));

    final icon = game.hasCraftedPoster ? '📋' : '🎨';
    final tp = TextPainter(
      text: TextSpan(
          text: icon,
          style: const TextStyle(fontSize: 8)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(-tp.width / 2, 13 - tp.height / 2));

    canvas.restore();
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  POSTER BOARD COMPONENT
// ══════════════════════════════════════════════════════════════════════════════
class PosterBoard extends Component {
  final PosterCraftingGame game;
  double hx, hy;
  final int          seed;
  final PosterTheme  recommendedTheme;
  final int          index;
  bool          hasPosted = false;
  PosterTheme?  placedTheme;
  bool          isCorrectTheme = false;
  double        _t = 0;

  PosterBoard({
    required this.game,
    required double worldX, required double worldY,
    required this.seed,
    required this.recommendedTheme,
    required this.index,
  }) : hx = worldX, hy = worldY;

  Vector2 get boardPos => Vector2(hx, hy);

  void post(PosterTheme t, bool correct) {
    hasPosted      = true;
    placedTheme    = t;
    isCorrectTheme = correct;
  }

  @override
  void update(double dt) => _t += dt;

  @override
  void render(Canvas canvas) {
    final pulse = 0.70 + math.sin(_t * 2.2) * 0.18;

    if (hasPosted) {
      final borderColor = isCorrectTheme
          ? const Color(0xFF69F0AE)
          : const Color(0xFF1E88E5);

      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(hx, hy), width: 44, height: 56),
            const Radius.circular(4)),
        Paint()..color = const Color(0xFF0A1408).withValues(alpha: 0.90),
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(hx, hy), width: 44, height: 56),
            const Radius.circular(4)),
        Paint()
          ..color = borderColor.withValues(alpha: 0.70)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0,
      );

      final icon = PosterRecipe.recipes[placedTheme]!.icon;
      final tp = TextPainter(
        text: TextSpan(text: icon, style: const TextStyle(fontSize: 20)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(hx - tp.width / 2, hy - tp.height / 2 - 8));

      if (isCorrectTheme) {
        final sp = TextPainter(
          text: const TextSpan(text: '✓', style: TextStyle(color: Color(0xFF69F0AE), fontSize: 12, fontWeight: FontWeight.bold)),
          textDirection: TextDirection.ltr,
        )..layout();
        sp.paint(canvas, Offset(hx + 12, hy - 22));
      }

      if (game.ecoDiscoveryIndices.contains(index) && 
          !game.discoveredEcoBoards.contains(index)) {
        final shimmer = 0.30 + math.sin(_t * 3.5) * 0.22;
        canvas.drawCircle(Offset(hx + 18, hy - 22), 6,
            Paint()
              ..color = const Color(0xFFE040FB).withValues(alpha: shimmer)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
      }
    } else {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(hx, hy),
                width: 40 * pulse, height: 52 * pulse),
            const Radius.circular(4)),
        Paint()
          ..color = const Color(0xFF1E88E5).withValues(alpha: 0.40)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8,
      );

      final tp = TextPainter(
        text: const TextSpan(text: '📌', style: TextStyle(fontSize: 14)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(hx - tp.width / 2, hy - tp.height / 2));

      final hint = _themeEmoji(recommendedTheme);
      final hp = TextPainter(
        text: TextSpan(text: hint, style: const TextStyle(fontSize: 10)),
        textDirection: TextDirection.ltr,
      )..layout();
      canvas.drawCircle(Offset(hx + 16, hy - 20), 10,
          Paint()..color = const Color(0xFF1E88E5).withValues(alpha: 0.18));
      hp.paint(canvas, Offset(hx + 16 - hp.width / 2, hy - 20 - hp.height / 2));

      if (game.ecoDiscoveryIndices.contains(index) && 
          !game.discoveredEcoBoards.contains(index)) {
        final shimmer = 0.25 + math.sin(_t * 3.0) * 0.20;
        canvas.drawCircle(Offset(hx - 16, hy - 20), 5,
            Paint()
              ..color = const Color(0xFFE040FB).withValues(alpha: shimmer)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
      }
    }
  }

  String _themeEmoji(PosterTheme t) {
    switch (t) {
      case PosterTheme.deforestation:     return '🌳';
      case PosterTheme.waterPollution:    return '💧';
      case PosterTheme.soilHealth:        return '🌱';
      case PosterTheme.wildlifeProtection: return '🦓';
      case PosterTheme.wasteManagement:   return '♻️';
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  HUD
// ══════════════════════════════════════════════════════════════════════════════
class PosterHud extends StatelessWidget {
  final PosterCraftingGame game;
  const PosterHud(this.game, {super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: game,
      builder: (_, __) {
        final warn    = game.timeLeft < 20;
        final crafted = game.hasCraftedPoster;

        return SafeArea(child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch, children: [

            Align(alignment: Alignment.topCenter, child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
              decoration: BoxDecoration(
                color: crafted
                    ? const Color(0xFF69F0AE).withValues(alpha: 0.90)
                    : const Color(0xFF1E88E5).withValues(alpha: 0.90),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(
                    color: (crafted
                        ? const Color(0xFF69F0AE)
                        : const Color(0xFF1E88E5)).withValues(alpha: 0.38),
                    blurRadius: 12)],
              ),
              child: Text(
                crafted
                    ? '📋  PHASE 4 — PLACE POSTER'
                    : '🎨  PHASE 4 — CRAFT POSTERS',
                style: const TextStyle(color: Colors.white,
                    fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1.1),
              ),
            )),
            const SizedBox(height: 8),

            Row(children: [
              _PTile(Icons.timer_rounded,
                  '${game.timeLeft.toInt()}s', 'TIME',
                  warn ? Colors.red : Colors.white),
              const SizedBox(width: 5),
              _PTile(Icons.check_circle_rounded,
                  '${game.postersPlaced}/${PosterCraftingGame.totalPosters}',
                  'PLACED',
                  game.postersPlaced >= PosterCraftingGame.kMinPostersRequired
                      ? const Color(0xFF69F0AE) : Colors.white70),
              const SizedBox(width: 5),
              _PTile(Icons.eco_rounded, '${game.ecoPoints}', 'ECO-PTS',
                  Colors.limeAccent),
              const SizedBox(width: 5),
              _PTile(Icons.palette_rounded,
                  '${game.materialsUsed}', 'MATERIALS',
                  const Color(0xFF1E88E5)),
            ]),
            const SizedBox(height: 5),

            if (crafted) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF69F0AE).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF69F0AE).withValues(alpha: 0.45)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(PosterRecipe.recipes[game.craftedPoster!.theme]!.icon,
                      style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 5),
                  Text('${PosterRecipe.recipes[game.craftedPoster!.theme]!.title} ready!',
                      style: const TextStyle(color: Color(0xFF69F0AE),
                          fontSize: 9, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 5),
                  const Text('→ Fly to board and PLACE',
                      style: TextStyle(color: Colors.white54, fontSize: 8)),
                ]),
              ),
            ],

            if (!crafted && game._hasNearbyBoard) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E88E5).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF1E88E5).withValues(alpha: 0.35)),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('📌', style: TextStyle(fontSize: 10)),
                  SizedBox(width: 5),
                  Text('Board nearby — craft a poster first!',
                      style: TextStyle(color: Color(0xFF1E88E5),
                          fontSize: 9, fontWeight: FontWeight.w700)),
                ]),
              ),
            ],

            if (game.comboCount > 0)
              Align(
                alignment: Alignment.centerRight,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
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

class _PTile extends StatelessWidget {
  final IconData icon;
  final String val, label;
  final Color color;
  const _PTile(this.icon, this.val, this.label, this.color);
  @override
  Widget build(BuildContext context) => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
    decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12)),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: color, size: 14),
      Text(val, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
      Text(label, style: const TextStyle(color: Colors.white54, fontSize: 8, letterSpacing: 0.8)),
    ]),
  ));
}

// ══════════════════════════════════════════════════════════════════════════════
//  CONTROLS
// ══════════════════════════════════════════════════════════════════════════════
class PosterControls extends StatefulWidget {
  final PosterCraftingGame game;
  const PosterControls(this.game, {super.key});
  @override
  State<PosterControls> createState() => _PosterControlsState();
}

class _PosterControlsState extends State<PosterControls> {
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
      if (widget.game.hasCraftedPoster) {
        widget.game.placePoster();
      } else {
        widget.game.openCraftingStation();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.game,
      builder: (_, __) {
        final canPlace = widget.game.hasCraftedPoster && widget.game._hasNearbyBoard;
        final canCraft = !widget.game.hasCraftedPoster;
        final actColor = widget.game.hasCraftedPoster
            ? const Color(0xFF69F0AE)
            : const Color(0xFF1E88E5);

        return KeyboardListener(
          focusNode: _fk,
          onKeyEvent: _onKey,
          child: Stack(children: [

            Align(
              alignment: Alignment.bottomLeft,
              child: SafeArea(child: Padding(
                padding: const EdgeInsets.only(bottom: 16, left: 12),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  _PPad('⬆', _up, Colors.cyanAccent,
                      onDown: () { setState(() => _up = true);  widget.game.setUpKey(true); },
                      onUp:   () { setState(() => _up = false); widget.game.setUpKey(false); }),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    _PPad('◀', _lt, Colors.cyanAccent,
                        onDown: () { setState(() => _lt = true);  widget.game.setLeftKey(true); },
                        onUp:   () { setState(() => _lt = false); widget.game.setLeftKey(false); }),
                    const SizedBox(width: 4),
                    _PPad('⬇', _dn, Colors.cyanAccent,
                        onDown: () { setState(() => _dn = true);  widget.game.setDownKey(true); },
                        onUp:   () { setState(() => _dn = false); widget.game.setDownKey(false); }),
                    const SizedBox(width: 4),
                    _PPad('▶', _rt, Colors.cyanAccent,
                        onDown: () { setState(() => _rt = true);  widget.game.setRightKey(true); },
                        onUp:   () { setState(() => _rt = false); widget.game.setRightKey(false); }),
                  ]),
                ]),
              )),
            ),

            Align(alignment: Alignment.bottomRight, child: SafeArea(child: Padding(
              padding: const EdgeInsets.only(bottom: 20, right: 14),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                if (widget.game.hasCraftedPoster)
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF69F0AE).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: const Color(0xFF69F0AE).withValues(alpha: 0.42)),
                    ),
                    child: const Text('📋 Ready to place!',
                        style: TextStyle(
                            color: Color(0xFF69F0AE),
                            fontSize: 9, fontWeight: FontWeight.bold)),
                  ),
                GestureDetector(
                  onTap: () {
                    if (widget.game.hasCraftedPoster) {
                      widget.game.placePoster();
                    } else {
                      widget.game.openCraftingStation();
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    width: 70, height: 70,
                    decoration: BoxDecoration(
                      color: canPlace || canCraft
                          ? actColor.withValues(alpha: 0.22)
                          : Colors.black.withValues(alpha: 0.60),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: canPlace || canCraft ? actColor : Colors.white24,
                          width: canPlace || canCraft ? 2.5 : 1.5),
                      boxShadow: canPlace || canCraft
                          ? [BoxShadow(
                              color: actColor.withValues(alpha: 0.42),
                              blurRadius: 16)]
                          : [],
                    ),
                    child: Center(child: Text(
                      widget.game.hasCraftedPoster
                          ? '📋 PLACE'
                          : '🎨 CRAFT',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: canPlace || canCraft ? actColor : Colors.white30,
                          fontWeight: FontWeight.w900,
                          fontSize: 8, letterSpacing: 0.3, height: 1.3),
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

class _PPad extends StatelessWidget {
  final String label;
  final bool   isActive;
  final Color  color;
  final VoidCallback onDown, onUp;
  const _PPad(this.label, this.isActive, this.color,
      {required this.onDown, required this.onUp});
  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown:   (_) => onDown(),
    onPointerUp:     (_) => onUp(),
    onPointerCancel: (_) => onUp(),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 70),
      width: 52, height: 52, margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: isActive ? color.withValues(alpha: 0.30)
            : Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: isActive ? color : Colors.white24, width: 1.8),
        boxShadow: isActive ? [BoxShadow(
            color: color.withValues(alpha: 0.40), blurRadius: 10)] : [],
      ),
      child: Center(child: Text(label, style: TextStyle(
          color: isActive ? color : Colors.white60,
          fontSize: 16, fontWeight: FontWeight.bold))),
    ),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
//  CRAFTING STATION OVERLAY — RESPONSIVE & SCROLLABLE
// ══════════════════════════════════════════════════════════════════════════════
class CraftingStationOverlay extends StatelessWidget {
  final PosterCraftingGame game;
  const CraftingStationOverlay(this.game, {super.key});

  String _materialEmoji(CraftMaterial m) {
    switch (m) {
      case CraftMaterial.naturalDye:    return '🎨';
      case CraftMaterial.chalkGypsum:   return '🪨';
      case CraftMaterial.recycledPaper: return '📄';
      case CraftMaterial.compostInk:    return '🌿';
      case CraftMaterial.biocharBlack:  return '🌑';
      case CraftMaterial.litterFrame:   return '♻️';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: game,
      builder: (_, __) {
        if (!game.craftingStationOpen) return const SizedBox.shrink();

        final mobile = MediaQuery.of(context).size.width < 600;
        final screenHeight = MediaQuery.of(context).size.height;
        final selected = game.selectedTheme;

        return Container(
          color: Colors.black.withValues(alpha: 0.75),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: mobile ? double.infinity : 720,
                maxHeight: screenHeight * 0.92, // Leave 4% padding top and bottom
              ),
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: mobile ? 12 : 40, vertical: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF080E08).withValues(alpha: 0.98),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: const Color(0xFF1E88E5).withValues(alpha: 0.55), width: 1.5),
                  boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 24)],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header - Fixed height
                    Row(children: [
                      const Text('🎨', style: TextStyle(fontSize: 22)),
                      const SizedBox(width: 10),
                      const Expanded(child: Text('CRAFTING STATION',
                          style: TextStyle(color: Colors.white,
                              fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 1.2))),
                      GestureDetector(
                        onTap: game.cancelCrafting,
                        child: Container(
                          width: 30, height: 30,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.08),
                              border: Border.all(color: Colors.white24)),
                          child: const Center(child: Text('✕',
                              style: TextStyle(color: Colors.white60, fontSize: 14))),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 4),
                    Text('Select a theme, then craft using your materials',
                        style: TextStyle(
                            color: const Color(0xFF1E88E5).withValues(alpha: 0.85),
                            fontSize: 10)),
                    const SizedBox(height: 12),
                    
                    // Scrollable content area
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Theme cards grid
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              alignment: WrapAlignment.center,
                              children: PosterTheme.values.map((theme) {
                                final recipe = PosterRecipe.recipes[theme]!;
                                final isSelected = selected == theme;
                                final canCraft = game.availableMaterials.entries.every((e) =>
                                    (recipe.requiredMaterials[e.key] ?? 0) <= e.value);

                                return GestureDetector(
                                  onTap: canCraft ? () => game.selectTheme(theme) : null,
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 130),
                                    width: mobile ? 130 : 150,
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? recipe.accentColor.withValues(alpha: 0.22)
                                          : canCraft
                                              ? recipe.accentColor.withValues(alpha: 0.10)
                                              : Colors.black.withValues(alpha: 0.55),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isSelected
                                            ? recipe.accentColor
                                            : canCraft
                                                ? recipe.accentColor.withValues(alpha: 0.50)
                                                : Colors.white12,
                                        width: isSelected ? 2.0 : 1.2,
                                      ),
                                      boxShadow: isSelected
                                          ? [BoxShadow(
                                              color: recipe.accentColor.withValues(alpha: 0.35),
                                              blurRadius: 12)]
                                          : [],
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(recipe.icon, style: const TextStyle(fontSize: 24)),
                                        const SizedBox(height: 4),
                                        Text(recipe.title,
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                                color: isSelected ? recipe.accentColor : Colors.white,
                                                fontWeight: FontWeight.w800,
                                                fontSize: 10)),
                                        const SizedBox(height: 3),
                                        Text(recipe.description,
                                            textAlign: TextAlign.center,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                color: Colors.white54,
                                                fontSize: 8, height: 1.3)),
                                        const SizedBox(height: 6),
                                        ...recipe.requiredMaterials.entries.map((e) {
                                          final hasEnough = (game.availableMaterials[e.key] ?? 0) >= e.value;
                                          return Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(_materialEmoji(e.key),
                                                  style: TextStyle(
                                                      fontSize: 9,
                                                      color: hasEnough ? Colors.white70 : Colors.white24)),
                                              const SizedBox(width: 3),
                                              Text('×${e.value}',
                                                  style: TextStyle(
                                                      color: hasEnough
                                                          ? const Color(0xFF69F0AE)
                                                          : Colors.redAccent,
                                                      fontSize: 8,
                                                      fontWeight: FontWeight.bold)),
                                              const SizedBox(width: 6),
                                            ],
                                          );
                                        }),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 12),

                            // Craft button and hints
                            if (selected != null) ...[
                              GestureDetector(
                                onTap: game._canCraftSelected ? game.craftPoster : null,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 130),
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: game._canCraftSelected
                                        ? PosterRecipe.recipes[selected]!.accentColor.withValues(alpha: 0.22)
                                        : Colors.white.withValues(alpha: 0.04),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: game._canCraftSelected
                                          ? PosterRecipe.recipes[selected]!.accentColor
                                          : Colors.white12,
                                      width: 2.0,
                                    ),
                                    boxShadow: game._canCraftSelected
                                        ? [BoxShadow(
                                            color: PosterRecipe.recipes[selected]!.accentColor.withValues(alpha: 0.38),
                                            blurRadius: 14)]
                                        : [],
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(PosterRecipe.recipes[selected]!.icon,
                                          style: const TextStyle(fontSize: 16)),
                                      const SizedBox(width: 8),
                                      Text(
                                        game._canCraftSelected
                                            ? 'CRAFT POSTER'
                                            : 'INSUFFICIENT MATERIALS',
                                        style: TextStyle(
                                          color: game._canCraftSelected
                                              ? PosterRecipe.recipes[selected]!.accentColor
                                              : Colors.white24,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (game.showCraftingHints)
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF69F0AE).withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                        color: const Color(0xFF69F0AE).withValues(alpha: 0.30)),
                                  ),
                                  child: Text(PosterRecipe.recipes[selected]!.ecoFact,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                          color: Color(0xFF69F0AE), fontSize: 10, height: 1.5)),
                                ),
                            ],
                          ],
                        ),
                      ),
                    ),
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

// ══════════════════════════════════════════════════════════════════════════════
//  MATERIAL TRAY OVERLAY (always visible at bottom)
// ══════════════════════════════════════════════════════════════════════════════
class MaterialTrayOverlay extends StatelessWidget {
  final PosterCraftingGame game;
  const MaterialTrayOverlay(this.game, {super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: game,
      builder: (_, __) {
        final mobile = MediaQuery.of(context).size.width < 600;

        return Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(child: Padding(
            padding: const EdgeInsets.only(bottom: 90, left: 8, right: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.78),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('MATERIALS FROM EARLIER LEVELS',
                    style: TextStyle(
                        color: Colors.white54,
                        fontSize: mobile ? 7 : 8.5,
                        letterSpacing: 1.2, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _MatChip('🎨 Dye', game.availableMaterials[CraftMaterial.naturalDye] ?? 0,
                        const Color(0xFFE040FB)),
                    const SizedBox(width: 6),
                    _MatChip('🪨 Gypsum', game.availableMaterials[CraftMaterial.chalkGypsum] ?? 0,
                        const Color(0xFF90A4AE)),
                    const SizedBox(width: 6),
                    _MatChip('📄 Paper', game.availableMaterials[CraftMaterial.recycledPaper] ?? 0,
                        const Color(0xFFBCAAA4)),
                    const SizedBox(width: 6),
                    _MatChip('🌿 Compost', game.availableMaterials[CraftMaterial.compostInk] ?? 0,
                        const Color(0xFF558B2F)),
                    const SizedBox(width: 6),
                    _MatChip('🌑 Biochar', game.availableMaterials[CraftMaterial.biocharBlack] ?? 0,
                        const Color(0xFF424242)),
                    const SizedBox(width: 6),
                    _MatChip('♻️ Frames', game.availableMaterials[CraftMaterial.litterFrame] ?? 0,
                        const Color(0xFF29B6F6)),
                  ],
                ),
              ]),
            ),
          )),
        );
      },
    );
  }
}

class _MatChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _MatChip(this.label, this.count, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withValues(alpha: 0.40)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text(label, style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w700)),
      const SizedBox(width: 3),
      Text('×$count', style: TextStyle(
          color: count > 0 ? Colors.white : Colors.white24,
          fontSize: 8, fontWeight: FontWeight.bold)),
    ]),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
//  PHASE BANNER
// ══════════════════════════════════════════════════════════════════════════════
class PosterPhaseBanner extends StatelessWidget {
  final PosterCraftingGame game;
  const PosterPhaseBanner(this.game, {super.key});

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF1E88E5);
    return IgnorePointer(child: Center(child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFF001020), Color(0xFF002040)]),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 24)],
        border: Border.all(color: accent.withValues(alpha: 0.55), width: 1.5),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('PHASE 4',
            style: TextStyle(color: Colors.white54,
                fontSize: 13, letterSpacing: 2.5)),
        const SizedBox(height: 4),
        const Text('🎨  Awareness Campaign',
            style: TextStyle(color: Colors.white,
                fontWeight: FontWeight.bold, fontSize: 22)),
        const SizedBox(height: 6),
        Text(
          'Open the CRAFTING STATION to design conservation posters.'
          'Use dyes from Level 1, gypsum from Level 4, compost from Level 5.'
          'Match the poster theme to the board location for bonus points!'
          'Craft and place ${PosterCraftingGame.kMinPostersRequired}+ posters to complete Level 6!',
          textAlign: TextAlign.center,
          style: TextStyle(color: accent.withValues(alpha: 0.85), fontSize: 11.5),
        ),
      ]),
    )));
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  REACTION FLASH
// ══════════════════════════════════════════════════════════════════════════════
class PosterReactionFx extends StatelessWidget {
  final PosterCraftingGame game;
  const PosterReactionFx(this.game, {super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: game,
      builder: (_, __) {
        final ok      = game.reactionCorrect;
        final inRange = game.reactionInRange;
        final msg     = game.reactionMsg.isNotEmpty
            ? game.reactionMsg
            : (!inRange ? '🚁 Out of Range — move closer'
                : ok ? '✅ Success!' : '❌ Wrong approach');
        final accent  = (ok && inRange)
            ? const Color(0xFF69F0AE)
            : const Color(0xFFEF5350);

        return IgnorePointer(child: Stack(children: [
          Container(decoration: BoxDecoration(
            border: Border.all(color: accent, width: 8),
            gradient: RadialGradient(
                colors: [Colors.transparent, accent.withValues(alpha: 0.12)],
                radius: 1.5),
          )),
          Center(child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 11),
            decoration: BoxDecoration(
                color: ok
                    ? const Color(0xFF0A2A10).withValues(alpha: 0.94)
                    : const Color(0xFF2A0A0A).withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [BoxShadow(
                    color: Colors.black54, blurRadius: 14, spreadRadius: 2)]),
            child: Text(msg, textAlign: TextAlign.center,
                style: TextStyle(color: accent, fontWeight: FontWeight.bold,
                    fontSize: 14, letterSpacing: 0.5)),
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
                  boxShadow: [BoxShadow(
                      color: const Color(0xFFFF6D00).withValues(alpha: 0.42),
                      blurRadius: 18)],
                ),
                child: Text(
                  game.comboCount >= 3
                      ? '🔥🔥🔥  ${game.comboCount}× PLACEMENT COMBO!  2× POINTS!'
                      : '🔥  ${game.comboCount}× PLACEMENT COMBO!  2× POINTS!',
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
class PosterEcoDiscoveryOverlay extends StatefulWidget {
  final PosterCraftingGame game;
  const PosterEcoDiscoveryOverlay(this.game, {super.key});
  @override
  State<PosterEcoDiscoveryOverlay> createState() => _PosterEcoDiscoveryState();
}

class _PosterEcoDiscoveryState extends State<PosterEcoDiscoveryOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _scale;

  @override
  void initState() {
    super.initState();
    _ctrl  = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 380))..forward();
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
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFF0A1A2E), Color(0xFF0A2E1A)]),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: const Color(0xFF69F0AE).withValues(alpha: 0.70), width: 2.0),
          boxShadow: [BoxShadow(
              color: const Color(0xFF69F0AE).withValues(alpha: 0.28), blurRadius: 30)],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('✨ ECO-DISCOVERY FOUND! ✨',
              style: TextStyle(color: Color(0xFF69F0AE), fontSize: 12,
                  fontWeight: FontWeight.w900, letterSpacing: 1.5)),
          const SizedBox(height: 10),
          Text(widget.game.lastDiscoveryFact,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 11.5, height: 1.6)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF69F0AE).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF69F0AE).withValues(alpha: 0.45)),
            ),
            child: const Text('+15 Eco-Points  •  Cultural Heritage Bonus!',
                style: TextStyle(color: Color(0xFF69F0AE),
                    fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ]),
      ),
    )));
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  RESULTS OVERLAY
// ══════════════════════════════════════════════════════════════════════════════
class PosterResultsOverlay extends StatelessWidget {
  final PosterCraftingGame game;
  const PosterResultsOverlay(this.game, {super.key});

  @override
  Widget build(BuildContext context) {
    final r        = PosterCraftingResult.current!;
    final meetsMin = r.meetsMinimum;
    final stars    = r.postersPlaced >= 5 && r.correctThemeMatches >= 4 ? '★★★'
                   : r.postersPlaced >= 4 ? '★★☆'
                   : '★☆☆';

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
              Text(meetsMin ? '🎨' : '📋', style: const TextStyle(fontSize: 50)),
              const SizedBox(height: 6),
              Text(meetsMin ? 'Awareness Campaign Complete!' : 'Phase Complete',
                  style: const TextStyle(color: Colors.white, fontSize: 22,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(r.performanceGrade,
                  style: TextStyle(
                    color: meetsMin
                        ? const Color(0xFF69F0AE)
                        : const Color(0xFFFFB300),
                    fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 1.0,
                  )),
              const SizedBox(height: 4),
              const Text('Phase 4 — Awareness Campaign Results',
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
                    border: Border.all(
                        color: const Color(0xFF69F0AE).withValues(alpha: 0.42)),
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('🏅', style: TextStyle(fontSize: 14)),
                    SizedBox(width: 6),
                    Text('Eco-Educator Badge Unlocked!',
                        style: TextStyle(color: Color(0xFF69F0AE),
                            fontWeight: FontWeight.w800, fontSize: 11.5)),
                  ]),
                ),
              ],
            ]),
          ),

          const SizedBox(height: 14),

          _PRCard(children: [
            _PRBig('📋', '${r.postersPlaced}/${PosterCraftingGame.totalPosters}',
                'Posters Placed', const Color(0xFF1E88E5)),
            _PRBig('✓', '${r.correctThemeMatches}',
                'Theme Matches', const Color(0xFF69F0AE)),
            _PRBig('⭐', '${r.ecoPoints}', 'Eco Points', Colors.amber),
            _PRBig('🔥', '${r.maxCombo}×', 'Max Combo', const Color(0xFFFF6D00)),
          ]),
          const SizedBox(height: 8),

          _PRCard(children: [
            _PRBig('🌍', '${r.ecoDiscoveriesFound}/2', 'Discoveries',
                const Color(0xFF69F0AE)),
            _PRBig('🧪', '${r.materialsUsed}', 'Materials Used',
                const ui.Color.fromRGBO(30, 136, 229, 1)),
          ]),

          const SizedBox(height: 10),

          if (r.performanceSummary.isNotEmpty)
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
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 11, height: 1.6)),
              ]),
            ),
          const SizedBox(height: 10),

          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: const Color(0xFF081008),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(children: [
              const Text('Poster Theme Guide',
                  style: TextStyle(color: Colors.white70, fontSize: 12,
                      fontWeight: FontWeight.bold, letterSpacing: 1)),
              const SizedBox(height: 10),
              _PRRow('🌳', 'Deforestation',      'Near dead trees'),
              _PRRow('💧', 'Water Pollution',     'Near ponds/wetlands'),
              _PRRow('🌱', 'Soil Health',         'Near dry land'),
              _PRRow('🦓', 'Wildlife Protection', 'Near park centre'),
              _PRRow('♻️', 'Waste Management',    'Near park entrance'),
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
                    icon: const Icon(Icons.emoji_events_rounded),
                    label: const Text('Complete Level 6  →',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold,
                            letterSpacing: 0.8)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF69F0AE),
                      foregroundColor: Colors.black87,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 8,
                    ),
                  )
                : Column(children: [
                    ElevatedButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.replay_rounded),
                      label: Text(
                        'Replay  — Place ${r.minimumRequired - r.postersPlaced} More Poster(s)',
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.bold,
                            letterSpacing: 0.5),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEF5350),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        minimumSize: const Size(double.infinity, 0),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 8,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFB300).withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: const Color(0xFFFFB300).withValues(alpha: 0.35)),
                      ),
                      child: Text(
                        '💡 Open the crafting station, select a theme, and craft a poster.'
                        'Match the poster theme to the board location for bonus points.'
                        'Minimum ${r.minimumRequired} posters needed to advance.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Color(0xFFFFB300), fontSize: 11, height: 1.5),
                      ),
                    ),
                  ]),
          ),
        ]),
      )),
    );
  }
}

class _PRCard extends StatelessWidget {
  final List<Widget> children;
  const _PRCard({required this.children});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
    decoration: BoxDecoration(
      color: const Color(0xFF081008),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white12),
    ),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: children),
  );
}

class _PRBig extends StatelessWidget {
  final String emoji, value, label;
  final Color  color;
  const _PRBig(this.emoji, this.value, this.label, this.color);
  @override
  Widget build(BuildContext context) =>
      Column(mainAxisSize: MainAxisSize.min, children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 3),
        Text(value, style: TextStyle(color: color,
            fontWeight: FontWeight.bold, fontSize: 17)),
        const SizedBox(height: 2),
        Text(label, textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white54, fontSize: 8.5)),
      ]);
}

class _PRRow extends StatelessWidget {
  final String emoji, label, action;
  const _PRRow(this.emoji, this.label, this.action);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4.5),
    child: Row(children: [
      Text(emoji, style: const TextStyle(fontSize: 14)),
      const SizedBox(width: 8),
      Expanded(child: Text(label,
          style: const TextStyle(color: Colors.white,
              fontSize: 11.5, fontWeight: FontWeight.w600))),
      Text(action, style: const TextStyle(
          color: Color(0xFF69F0AE), fontSize: 9.5)),
    ]),
  );
}
