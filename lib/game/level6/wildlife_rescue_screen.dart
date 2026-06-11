import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:ecoquest/game/level6/degraded_park_screen.dart';
import 'package:flame/components.dart' hide Matrix4;
import 'package:flame/game.dart' hide Matrix4;
import 'package:flutter/material.dart' hide Matrix4;
import 'package:flutter/services.dart';
import 'package:ecoquest/game/level6/poster_crafting_game_screen.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  WILDLIFE RESCUE GAME SCREEN  ·  EcoQuest Level 6  ·  
// ══════════════════════════════════════════════════════════════════════════════

// ── Result class passed forward ───────────────────────────────────────────────
class WildlifeRescueResult {
  final int    animalsRescued;
  final int    postersPlaced;
  final int    ecoPoints;
  final double habitatHealth;
  final bool   guardianOfNatureBadge;
  // Dynamic bonus fields
  final int    rescueStreakBonus;
  final int    ecoDiscoveriesFound;
  final int    criticalSaves;
  final int    maxCombo;
  // Minimum gate
  final bool   meetsMinimum;
  final int    minimumRequired;

  const WildlifeRescueResult({
    required this.animalsRescued,
    required this.postersPlaced,
    required this.ecoPoints,
    required this.habitatHealth,
    required this.guardianOfNatureBadge,
    this.rescueStreakBonus   = 0,
    this.ecoDiscoveriesFound = 0,
    this.criticalSaves       = 0,
    this.maxCombo            = 1,
    this.meetsMinimum        = false,
    this.minimumRequired     = 3,
  });

  String get performanceGrade {
    if (animalsRescued >= 5 && ecoPoints >= 200) return 'MASTER CONSERVATIONIST';
    if (animalsRescued >= 4 && ecoPoints >= 130) return 'SKILLED WILDLIFE RANGER';
    if (animalsRescued >= 3 && ecoPoints >= 80)  return 'FIELD MEDIC TRAINEE';
    return 'WILDLIFE VOLUNTEER';
  }

  String get performanceSummary {
    final lines = <String>[];
    if (criticalSaves > 0) {
      lines.add('Saved $criticalSaves critical animal(s) before condition worsened');
    }
    if (ecoDiscoveriesFound > 0) {
      lines.add('Found $ecoDiscoveriesFound hidden Eco-Discovery fact(s)');
    }
    if (maxCombo >= 4) {
      lines.add('$maxCombo-rescue combo achieved — 3× point multiplier!');
    } else if (maxCombo >= 2)
      {lines.add('$maxCombo-rescue combo achieved — 2× point multiplier!');}
    if (rescueStreakBonus > 0) {
      lines.add('Rescue streak bonus: +$rescueStreakBonus pts');
    }
    return lines.isEmpty
        ? 'Rescue more animals to maximise habitat health score.'
        : lines.join('\n');
  }

  static WildlifeRescueResult? current;
}

// ── Critical animal alert ─────────────────────────────────────────────────────
class CriticalAnimalAlert {
  final InjuredAnimal animal;
  double timeLeft;
  bool   handled;
  CriticalAnimalAlert({
    required this.animal,
    this.timeLeft = 12.0,
    this.handled  = false,
  });
}

// ── Animal assessment result (auto-detected, mirrors TerrainScanResult) ───────
class AnimalAssessmentResult {
  final AnimalType type;
  final String typeName, condition, ecoFact, correctAidLabel, icon;
  final Color  color;
  final bool   hasEcoDiscovery;
  final String discoveryFact;

  const AnimalAssessmentResult({
    required this.type,
    required this.typeName,
    required this.condition,
    required this.ecoFact,
    required this.correctAidLabel,
    required this.icon,
    required this.color,
    this.hasEcoDiscovery = false,
    this.discoveryFact   = '',
  });

  static AnimalAssessmentResult forType(
    AnimalType t, {
    bool withDiscovery = false,
    int variant = 0,
  }) {
    const zebraFacts = [
      'Zebras in Kenya\'s highlands can lose critical blood volume within hours from an open wound. Antiseptic cleaning prevents tick colonisation and deadly fly-strike.',
      'A zebra wound untreated in the savannah heat becomes infected within 48 hours. Proper bandaging and rest restores full mobility within two weeks.',
    ];
    const birdFacts = [
      'The Abdim\'s stork loses up to 30% body weight during drought. Supplemental seeds and electrolyte water restore migration energy within days.',
      'Migratory birds like the crowned crane rely on waterways free from pollution. Feeding malnourished birds jump-starts recovery and seasonal migration.',
    ];
    const monkeyFacts = [
      'Sykes\' monkeys of Ondiri Swamp use medicinal plants for minor wounds, but fractured limbs need human splinting to prevent troop abandonment.',
      'Vervet monkeys\' social bonds mean an injured member slows the whole troop. Splinting a limb prevents the troop from leaving a wounded individual behind.',
    ];
    const impalaFacts = [
      'An impala laceration left untreated in Ondiri heat can become fly-strike in 48 hours. Flushing and sealing the wound is critical for survival.',
      'Impala can leap 3 m high when fleeing predators. A wound compromises their escape reflex — clean wound care restores full defensive capability.',
    ];

    const discoveryFacts = {
      AnimalType.zebra:
        '🌿 Cultural Discovery! The Gikuyu people of Gikambura call zebras "Punda Milia" — a symbol of harmony between wild and cultivated land. Community rangers trained by elders have protected them for generations along the Ondiri wetlands.',
      AnimalType.bird:
        '🌿 Cultural Discovery! Ondiri elders used bird song patterns as ecological indicators — if hornbills fell silent, it signalled drought approaching weeks ahead. Their calls guided farmers to seasonal water sources.',
      AnimalType.monkey:
        '🌿 Cultural Discovery! The Kikuyu revered the Colobus monkey ("Mbega") as a sacred messenger of the forest gods — hunting them was forbidden under traditional Gikuyu law in the Kiambu highlands.',
      AnimalType.impala:
        '🌿 Cultural Discovery! Rwithigiti community scouts tracked impala herds to map seasonal waterways — their movements indicated water availability for both wildlife and communities for centuries.',
    };

    final idx = variant % 2;
    switch (t) {
      case AnimalType.zebra:
        return AnimalAssessmentResult(
          type: t,
          typeName: 'Injured Zebra',
          condition: 'CRITICAL  •  Open wound — active bleeding',
          ecoFact: zebraFacts[idx],
          correctAidLabel: 'Clean Wound  →  Antiseptic, bandage & rest area',
          icon: '🦓',
          color: const Color(0xFF90A4AE),
          hasEcoDiscovery: withDiscovery,
          discoveryFact: discoveryFacts[t]!,
        );
      case AnimalType.bird:
        return AnimalAssessmentResult(
          type: t,
          typeName: 'Malnourished Bird',
          condition: 'MODERATE  •  Severe hunger & dehydration',
          ecoFact: birdFacts[idx],
          correctAidLabel: 'Feed Animal  →  Seeds, water & electrolytes',
          icon: '🦜',
          color: const Color(0xFF558B2F),
          hasEcoDiscovery: withDiscovery,
          discoveryFact: discoveryFacts[t]!,
        );
      case AnimalType.monkey:
        return AnimalAssessmentResult(
          type: t,
          typeName: 'Injured Monkey',
          condition: 'HIGH  •  Fractured or strained limb',
          ecoFact: monkeyFacts[idx],
          correctAidLabel: 'Splint Limb  →  Immobilise & support the joint',
          icon: '🐒',
          color: const Color(0xFF795548),
          hasEcoDiscovery: withDiscovery,
          discoveryFact: discoveryFacts[t]!,
        );
      case AnimalType.impala:
        return AnimalAssessmentResult(
          type: t,
          typeName: 'Injured Impala',
          condition: 'CRITICAL  •  Laceration — infection risk HIGH',
          ecoFact: impalaFacts[idx],
          correctAidLabel: 'Clean Wound  →  Flush, disinfect & seal wound',
          icon: '🦌',
          color: const Color(0xFFFFB300),
          hasEcoDiscovery: withDiscovery,
          discoveryFact: discoveryFacts[t]!,
        );
    }
  }
}

// ── Enums ─────────────────────────────────────────────────────────────────────
enum AnimalType      { zebra, bird, monkey, impala }
enum FirstAidAction  { cleanWound, splintLimb, feedAnimal }
enum PosterTheme     { deforestation, waterPollution, soilHealth, wildlifeProtection, wasteManagement }

// ══════════════════════════════════════════════════════════════════════════════
//  SCREEN WRAPPER
// ══════════════════════════════════════════════════════════════════════════════
class WildlifeRescueScreen extends StatefulWidget {
  final Level5CarryOver carryOver;
  const WildlifeRescueScreen({super.key, required this.carryOver});

  @override
  State<WildlifeRescueScreen> createState() => _WildlifeRescueScreenState();
}

class _WildlifeRescueScreenState extends State<WildlifeRescueScreen> {
  late WildlifeRescueGame _game;

  @override
  void initState() {
    super.initState();
    _game = WildlifeRescueGame(
      carryOver:       widget.carryOver,
      onLevelComplete: _onDone,
    );
  }

  void _onDone() {
    if (!mounted) return;

    // Build Phase 4 carry-over from Phase 3 results
    final phase4CarryOver = Phase4CarryOver(
      level5Data:         widget.carryOver,
      animalsRescued:     _game.animalsRescued,
      criticalSaves:      _game.criticalSaves,
      ecoDiscoveriesFound: _game.ecoDiscoveriesFound,
      rescueEcoPoints:    _game.ecoPoints,
      habitatHealth:      _game.habitatHealth,
    );

    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => PosterCraftingGameScreen(carryOver: phase4CarryOver),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GameWidget(
        game: _game,
        overlayBuilderMap: {
          'hud':              (ctx, g) => RescueHud(g as WildlifeRescueGame),
          'controls':         (ctx, g) => RescueControls(g as WildlifeRescueGame),
          'banner':           (ctx, g) => RescuePhaseBanner(g as WildlifeRescueGame),
          'firstAid':         (ctx, g) => FirstAidMiniGame(g as WildlifeRescueGame),
          'posterTray':       (ctx, g) => PosterTray(g as WildlifeRescueGame),
          'reactionFx':       (ctx, g) => RescueReactionFx(g as WildlifeRescueGame),
          'results':          (ctx, g) => RescueResultsOverlay(g as WildlifeRescueGame),
          'assessmentResult': (ctx, g) => AnimalAssessmentOverlay(g as WildlifeRescueGame),
          'criticalAnimal':   (ctx, g) => CriticalAnimalOverlay(g as WildlifeRescueGame),
          'rescueDiscovery':  (ctx, g) => RescueDiscoveryOverlay(g as WildlifeRescueGame),
        },
        initialActiveOverlays: const ['hud', 'controls'],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  MAIN GAME CLASS
// ══════════════════════════════════════════════════════════════════════════════
class WildlifeRescueGame extends FlameGame
    with HasCollisionDetection, ChangeNotifier {

  final Level5CarryOver carryOver;
  final VoidCallback    onLevelComplete;

  WildlifeRescueGame({required this.carryOver, required this.onLevelComplete});

  // ── Minimum animals required to pass the level ─────────────────────────────
  static const int kMinAnimalsRequired = 3;

  // ── State ──────────────────────────────────────────────────────────────────
  int    gamePhase   = 3;
  bool   gameStarted = false;
  double timeLeft    = 120.0;
  bool   levelDone   = false;

  // ── Score ──────────────────────────────────────────────────────────────────
  int ecoPoints      = 0;
  int animalsRescued = 0;
  int postersPlaced  = 0;

  // ── Habitat health ─────────────────────────────────────────────────────────
  double habitatHealth  = 20.0;
  static const double _targetHealth   = 80.0;
  static const double _rescueGain     = 10.0;
  static const double _posterGain     = 6.0;
  static const double _missedPenalty  = 5.0;

  // ── Ranges ─────────────────────────────────────────────────────────────────
  static const double _assessRange = 120.0;
  static const double _posterRange = 85.0;

  // ── Drone ──────────────────────────────────────────────────────────────────
  late Vector2 dronePos;
  bool isUp = false, isDown = false, isLeft = false, isRight = false;
  static const double _droneSpeed = 175.0;
  double _idleTimer = 0;

  // ── Phase 3 · Assessment lock (mirrors scan lock) ──────────────────────────
  InjuredAnimal? activeAssessAnimal;
  bool           assessLockActive  = false;
  double         _assessLockTimer  = 0;
  static const double _assessDuration = 1.5;
  InjuredAnimal? _nearestAssessTarget;

  // ── Phase 3 · Assessment result card (mirrors ScanResultOverlay) ──────────
  bool                   assessmentResultActive = false;
  AnimalAssessmentResult? lastAssessmentResult;
  double                 assessmentResultTimer  = 0;
  static const double    _assessResultDisplay   = 4.0;
  int                    lastAssessmentPoints   = 0;

  // ── Phase 3 · Pending treat target (mirrors pendingFixTarget) ─────────────
  InjuredAnimal? pendingTreatTarget;
  bool           firstAidSelectorOpen = false;

  // ── Phase 3 · First-aid current animal ────────────────────────────────────
  bool            firstAidActive  = false;
  InjuredAnimal?  currentAnimal;
  FirstAidAction? requiredAction;

  // ── Phase 3 · Rescue streak (mirrors scan streak) ─────────────────────────
  int    rescueStreak      = 0;
  double rescueStreakTimer  = 0;
  int    totalRescueStreak = 0;
  static const double _streakWindow = 6.0;

  // ── Phase 3 · Combo (mirrors restoration combo) ───────────────────────────
  int    comboCount      = 0;
  double comboTimer      = 0;
  int    maxCombo        = 1;
  bool   showComboFlash  = false;
  double comboFlashTimer = 0;
  static const double _comboWindow = 4.5;

  // ── Phase 3 · Critical animal events (mirrors critical alerts) ────────────
  final List<CriticalAnimalAlert> criticalAlerts = [];
  double _criticalAlertTimer = 40.0;
  int    criticalSaves       = 0;

  // ── Phase 3 · Eco-discoveries (mirrors eco-discovery markers) ─────────────
  final Set<int>  ecoDiscoveryIndices  = {};
  final Set<int>  discoveredEcoAnimals = {};
  int             ecoDiscoveriesFound  = 0;
  String          lastDiscoveryFact    = '';
  double          discoveryDisplayTimer = 0;
  static const double _discoveryDisplay = 5.0;

  // ── Phase 3 · Show-once consciousness (mirrors _seenScanCardTypes) ─────────
  final Set<AnimalType> _seenAssessmentTypes = {};
  bool assessmentShowsHints = true;

  // ── Phase 3 · Eco-guide hint ───────────────────────────────────────────────
  String ecoGuideHint   = '';
  double ecoGuideTimer  = 0;
  double _hintCooldown  = 0;

  // ── Phase 3 · Reaction message ────────────────────────────────────────────
  String reactionMsg = '';

  // ── Phase 4 · Poster crafting ─────────────────────────────────────────────
  PosterTheme selectedTheme = PosterTheme.wildlifeProtection;

  // ── Phase 4 · Poster combo ────────────────────────────────────────────────
  int posterComboCount = 0;

  // ── Reaction FX ───────────────────────────────────────────────────────────
  bool   reactionActive  = false;
  bool   reactionCorrect = false;
  int    reactionPhase   = 3;
  bool   reactionInRange = true;
  double reactionTimer   = 0;

  // ── Banner ────────────────────────────────────────────────────────────────
  double bannerTimer = 3.5;

  // ── Components ────────────────────────────────────────────────────────────
  late RescueDroneComponent drone;
  final List<InjuredAnimal>  animals      = [];
  final List<PosterBoard>    posterBoards = [];

  static const int totalAnimals = 6;
  static const int totalPosters = 5;

  @override
  Future<void> onLoad() async {
    super.onLoad();
    dronePos = Vector2(size.x * 0.50, size.y * 0.52);

    add(RestoringParkRenderer(game: this));
    drone = RescueDroneComponent(game: this);
    add(drone);

    _spawnAnimals();
    _assignEcoDiscoveries();

    bannerTimer = 3.5;
    overlays.add('banner');
    add(TimerComponent(period: 1.0, repeat: true, onTick: _onSecond));
  }

  void _spawnAnimals() {
    final specs = [
      (AnimalType.zebra,  0.18, 0.32, FirstAidAction.cleanWound),
      (AnimalType.bird,   0.72, 0.28, FirstAidAction.feedAnimal),
      (AnimalType.monkey, 0.42, 0.50, FirstAidAction.splintLimb),
      (AnimalType.impala, 0.82, 0.60, FirstAidAction.cleanWound),
      (AnimalType.bird,   0.28, 0.68, FirstAidAction.feedAnimal),
      (AnimalType.zebra,  0.60, 0.72, FirstAidAction.splintLimb),
    ];
    for (int i = 0; i < specs.length; i++) {
      final (type, rx, ry, aid) = specs[i];
      final a = InjuredAnimal(
        game: this, type: type, requiredAid: aid,
        worldX: size.x * rx, worldY: size.y * ry,
        seed: i * 19,
      );
      add(a);
      animals.add(a);
    }
  }

  void _assignEcoDiscoveries() {
    final rng = math.Random(DateTime.now().millisecondsSinceEpoch);
    final indices = List.generate(animals.length, (i) => i)..shuffle(rng);
    ecoDiscoveryIndices.add(indices[0]);
    ecoDiscoveryIndices.add(indices[1]);
  }

  /*void _spawnPosterBoards() {
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
      );
      add(b);
      posterBoards.add(b);
    }
  }*/

  void _onSecond() {
    if (!gameStarted || levelDone) return;
    timeLeft -= 1;
    if (timeLeft <= 0) { timeLeft = 0; _endLevel(); }
    notifyListeners();
  }

  // ── Getters ────────────────────────────────────────────────────────────────
  double get assessHoldProgress =>
      assessLockActive ? (_assessLockTimer / _assessDuration).clamp(0.0, 1.0) : 0.0;

  bool get _hasNearbyAnimal =>
      animals.any((a) => !a.isRescued &&
          (a.animalPos - dronePos).length <= _assessRange);

  bool get _hasNearbyBoard =>
      posterBoards.any((b) => !b.hasPosted &&
          (b.boardPos - dronePos).length <= _posterRange);

  PosterBoard? get _nearestBoard {
    PosterBoard? target;
    double best = _posterRange;
    for (final b in posterBoards) {
      if (b.hasPosted) continue;
      final d = (b.boardPos - dronePos).length;
      if (d < best) { best = d; target = b; }
    }
    return target;
  }

  // ── Phase 3: User-triggered ASSESS (mirrors triggerScan) ──────────────────
  // Player taps ASSESS; if an animal is in range, starts a 1.5 s lock.
  // On completion the assessment card appears, then first-aid picker opens.
  void triggerAssessment() {
    if (!gameStarted || levelDone || gamePhase != 3) return;
    gameStarted = true;
    HapticFeedback.selectionClick();

    if (firstAidSelectorOpen) {
      reactionMsg = '🩹 Select a first-aid action from the panel first!';
      _triggerReaction(false, inRange: false);
      notifyListeners();
      return;
    }

    if (assessLockActive) {
      reactionMsg = '🔬 Assessment in progress…';
      _triggerReaction(true, inRange: true);
      notifyListeners();
      return;
    }

    InjuredAnimal? nearest;
    double nearestD = _assessRange;
    for (final a in animals) {
      if (a.isRescued) continue;
      final d = (a.animalPos - dronePos).length;
      if (d < nearestD) { nearestD = d; nearest = a; }
    }

    if (nearest == null) {
      reactionMsg = '🚁 No injured animal in range — fly closer';
      _triggerReaction(false, inRange: false);
      notifyListeners();
      return;
    }

    _nearestAssessTarget = nearest;
    activeAssessAnimal   = nearest;
    assessLockActive     = true;
    _assessLockTimer     = 0;
    reactionMsg = '🔬 Assessing animal — hold position!';
    _triggerReaction(true, inRange: true);
    HapticFeedback.lightImpact();
    notifyListeners();
  }

  // ── Phase 3: Assessment lock complete → show result card ──────────────────
  void _completeAnimalAssessment(InjuredAnimal a) {
    if (a.isRescued) return;
    final idx          = animals.indexOf(a);
    final hasDiscovery = ecoDiscoveryIndices.contains(idx);

    lastAssessmentResult = AnimalAssessmentResult.forType(
      a.type, withDiscovery: hasDiscovery, variant: idx,
    );

    final pts = hasDiscovery ? 20 : 8;
    ecoPoints           += pts;
    lastAssessmentPoints = pts;

    final firstTime = !_seenAssessmentTypes.contains(a.type);
    if (firstTime) _seenAssessmentTypes.add(a.type);
    assessmentShowsHints = firstTime;

    assessmentResultTimer  = hasDiscovery ? 5.5 : _assessResultDisplay;
    assessmentResultActive = true;

    assessLockActive     = false;
    _assessLockTimer     = 0;
    activeAssessAnimal   = null;
    _nearestAssessTarget = null;

    HapticFeedback.heavyImpact();

    if (hasDiscovery) {
      ecoDiscoveriesFound++;
      discoveredEcoAnimals.add(idx);
      lastDiscoveryFact    = lastAssessmentResult!.discoveryFact;
      discoveryDisplayTimer = _discoveryDisplay;
      overlays.add('rescueDiscovery');
    } else {
      overlays.add('assessmentResult');
    }

    // Store pending target — first-aid selector opens when player taps TREAT IT
    // (or auto-opens when card auto-dismisses). Player always sees the condition
    // before choosing a first-aid action.
    pendingTreatTarget = a;

    notifyListeners();
  }

  // ── Called when player taps "TREAT IT" on assessment card ─────────────────
  void openFirstAidForPending() {
    if (pendingTreatTarget == null || firstAidSelectorOpen) return;
    firstAidSelectorOpen = true;
    currentAnimal  = pendingTreatTarget;
    requiredAction = pendingTreatTarget!.requiredAid;
    firstAidActive = true;
    overlays.remove('assessmentResult');
    assessmentResultActive = false;
    overlays.add('firstAid');
    notifyListeners();
  }

  // ── Dismiss assessment card → open first-aid selector ─────────────────────
  void dismissAssessmentResult() {
    if (!assessmentResultActive) return;
    assessmentResultActive = false;
    overlays.remove('assessmentResult');
    if (pendingTreatTarget != null && !firstAidSelectorOpen) {
      openFirstAidForPending();
    }
    notifyListeners();
  }

  // ── Phase 3: Apply first-aid action (immediate, mirrors applyTool) ─────────
  void applyFirstAid(FirstAidAction action) {
    firstAidActive       = false;
    firstAidSelectorOpen = false;
    overlays.remove('firstAid');
    HapticFeedback.selectionClick();

    final target = pendingTreatTarget ?? currentAnimal;
    if (target == null) return;
    pendingTreatTarget = null;

    final correct = action == target.requiredAid;
    if (correct) {
      target.rescue();
      animalsRescued++;
      habitatHealth = math.min(100, habitatHealth + _rescueGain);
      final pts     = 30 * _comboMult();
      ecoPoints    += pts;
      _incCombo();
      _handleRescueStreak();
      _dismissCriticalAnimal(target, saved: true);
      reactionMsg = '🌿 ${_animalLabel(target.type)} healed!  +$pts pts  🎉';
      _triggerReaction(true);
      target.triggerHealSparkle = true;
    } else {
      ecoPoints     = math.max(0, ecoPoints - 10);
      habitatHealth = math.max(0, habitatHealth - _missedPenalty);
      _breakCombo();
      reactionMsg = '❌ Wrong first-aid — try the correct treatment!';
      _triggerReaction(false);
    }

    if (animals.every((a) => a.isRescued)) {
      Future.delayed(const Duration(milliseconds: 600), _advanceToPhase4);
    }
    notifyListeners();
  }

  void _advanceToPhase4() {
    if (levelDone) return;
    levelDone = true;
    pauseEngine();

    // Save Phase 3 results
    WildlifeRescueResult.current = WildlifeRescueResult(
      animalsRescued:      animalsRescued,
      postersPlaced:       0,  // Now in Phase 4
      ecoPoints:           ecoPoints,
      habitatHealth:       habitatHealth,
      guardianOfNatureBadge: habitatHealth >= _targetHealth,
      rescueStreakBonus:   totalRescueStreak,
      ecoDiscoveriesFound: ecoDiscoveriesFound,
      criticalSaves:       criticalSaves,
      maxCombo:            maxCombo,
      meetsMinimum:        animalsRescued >= kMinAnimalsRequired,
      minimumRequired:     kMinAnimalsRequired,
    );

    // Navigate to Phase 4 — Phase4CarryOver is built in the screen wrapper's _onDone()
    onLevelComplete();
  }

  // ── Phase 4: Place poster (immediate, mirrors applyTool) ──────────────────
  void placePost() {
    if (!gameStarted || levelDone || gamePhase != 4) return;
    final target = _nearestBoard;
    if (target == null) {
      reactionMsg = '📌 No poster board in range — fly closer';
      _triggerReaction(false, inRange: false);
      return;
    }

    HapticFeedback.lightImpact();
    final isRecommended = selectedTheme == target.recommendedTheme;
    target.post(selectedTheme);
    postersPlaced++;
    habitatHealth = math.min(100, habitatHealth + _posterGain);
    final bonusPts = isRecommended ? 10 : 0;
    ecoPoints += 15 + bonusPts;
    posterComboCount++;

    if (isRecommended) {
      reactionMsg = '📋 Poster placed!  +${15 + bonusPts} pts  ✓ Best theme for this location!';
      _triggerReaction(true);
    } else {
      reactionMsg = '📋 Poster placed!  +15 pts';
      _triggerReaction(true);
    }

    if (posterBoards.every((b) => b.hasPosted) || habitatHealth >= _targetHealth) {
      Future.delayed(const Duration(milliseconds: 800), _endLevel);
    }
    notifyListeners();
  }

  void selectTheme(PosterTheme t) {
    selectedTheme = t;
    notifyListeners();
    if (gamePhase == 4) placePost();   // instant application on selection
  }

  // ── Rescue streak (mirrors scan streak) ────────────────────────────────────
  void _handleRescueStreak() {
    rescueStreakTimer = _streakWindow;
    rescueStreak++;
    if (rescueStreak >= 3) {
      final bonus      = (rescueStreak - 2) * 8;
      ecoPoints       += bonus;
      totalRescueStreak += bonus;
      reactionMsg       = '🎯 Rescue Streak x$rescueStreak!  +$bonus bonus pts';
      _triggerReaction(true);
    }
  }

  // ── Combo system (mirrors _incCombo / _breakCombo) ─────────────────────────
  int _comboMult() {
    if (comboCount >= 4) return 3;
    if (comboCount >= 2) return 2;
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

  // ── Critical animal events (mirrors _spawnCriticalAlert) ──────────────────
  void _spawnCriticalAnimal() {
    final candidates = animals.where((a) =>
        !a.isRescued &&
        criticalAlerts.every((c) => c.animal != a)).toList();
    if (candidates.isEmpty) return;
    candidates.shuffle(math.Random());
    final a     = candidates.first;
    a.isCritical = true;
    final alert  = CriticalAnimalAlert(animal: a, timeLeft: 12.0);
    criticalAlerts.add(alert);
    overlays.add('criticalAnimal');
    HapticFeedback.heavyImpact();
    notifyListeners();
  }

  void _dismissCriticalAnimal(InjuredAnimal a, {bool saved = false}) {
    final alert = criticalAlerts.where((c) => c.animal == a).firstOrNull;
    if (alert == null) return;
    alert.handled  = true;
    a.isCritical   = false;
    if (saved) { criticalSaves++; ecoPoints += 15; }
    criticalAlerts.removeWhere((c) => c.handled);
    if (criticalAlerts.isEmpty) overlays.remove('criticalAnimal');
    notifyListeners();
  }

  void _expireCriticalAnimal(CriticalAnimalAlert alert) {
    alert.handled          = true;
    alert.animal.isCritical = false;
    habitatHealth = math.max(0, habitatHealth - 12.0);
    ecoPoints     = math.max(0, ecoPoints - 15);
    criticalAlerts.removeWhere((c) => c.handled);
    if (criticalAlerts.isEmpty) overlays.remove('criticalAnimal');
    reactionMsg = '⛔ Animal condition critical — condition worsened!  −15 pts';
    _triggerReaction(false);
    notifyListeners();
  }

  // ── Eco-guide hints ────────────────────────────────────────────────────────
  void _checkHints() {
    if (_hintCooldown > 0 || ecoGuideTimer > 0) return;
    if (gamePhase == 3 && _idleTimer > 4.5) {
      ecoGuideHint = '🔬 Fly close to an injured animal then tap ASSESS. Read the condition card, then tap TREAT IT!';
      ecoGuideTimer = 3.5;
      _hintCooldown = 12;
      _idleTimer    = 0;
    } else if (gamePhase == 3 && criticalAlerts.isNotEmpty && _idleTimer > 3.0) {
      ecoGuideHint = '⚡ Critical animal alert! Treat it fast to earn +15 bonus pts!';
      ecoGuideTimer = 3.5;
      _hintCooldown = 8;
    }
    notifyListeners();
  }

  // ── Input ──────────────────────────────────────────────────────────────────
  void setUpKey(bool v)    { isUp    = v; if (v) gameStarted = true; _idleTimer = 0; }
  void setDownKey(bool v)  { isDown  = v; if (v) gameStarted = true; _idleTimer = 0; }
  void setLeftKey(bool v)  { isLeft  = v; if (v) gameStarted = true; _idleTimer = 0; }
  void setRightKey(bool v) { isRight = v; if (v) gameStarted = true; _idleTimer = 0; }

  void _triggerReaction(bool correct, {bool inRange = true}) {
    reactionActive  = true;
    reactionCorrect = correct;
    reactionPhase   = gamePhase;
    reactionInRange = inRange;
    reactionTimer   = 1.3;
    overlays.add('reactionFx');
  }

  void _endLevel() {
    if (levelDone) return;
    levelDone = true;
    pauseEngine();

    WildlifeRescueResult.current = WildlifeRescueResult(
      animalsRescued:      animalsRescued,
      postersPlaced:       postersPlaced,
      ecoPoints:           ecoPoints,
      habitatHealth:       habitatHealth,
      guardianOfNatureBadge: habitatHealth >= _targetHealth,
      rescueStreakBonus:   totalRescueStreak,
      ecoDiscoveriesFound: ecoDiscoveriesFound,
      criticalSaves:       criticalSaves,
      maxCombo:            maxCombo,
      meetsMinimum:        animalsRescued >= kMinAnimalsRequired,
      minimumRequired:     kMinAnimalsRequired,
    );

    overlays
      ..remove('reactionFx')
      ..remove('posterTray')
      ..remove('firstAid')
      ..remove('assessmentResult')
      ..remove('criticalAnimal')
      ..remove('rescueDiscovery')
      ..add('results');
    notifyListeners();
  }

  String _animalLabel(AnimalType t) {
    switch (t) {
      case AnimalType.zebra:  return 'Zebra';
      case AnimalType.bird:   return 'Bird';
      case AnimalType.monkey: return 'Monkey';
      case AnimalType.impala: return 'Impala';
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    // ── Global timers ────────────────────────────────────────────────────────
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

    // Assessment result overlay countdown (non-blocking)
    if (assessmentResultActive) {
      assessmentResultTimer -= dt;
      if (assessmentResultTimer <= 0) dismissAssessmentResult();
    }
    if (discoveryDisplayTimer > 0) {
      discoveryDisplayTimer -= dt;
      if (discoveryDisplayTimer <= 0) overlays.remove('rescueDiscovery');
    }

    // Combo flash timer
    if (comboFlashTimer > 0) {
      comboFlashTimer -= dt;
      if (comboFlashTimer <= 0) showComboFlash = false;
    }

    // Rescue streak decay
    if (rescueStreakTimer > 0) {
      rescueStreakTimer -= dt;
      if (rescueStreakTimer <= 0) rescueStreak = 0;
    }

    if (!gameStarted || levelDone) { notifyListeners(); return; }

    // ── Drone movement ────────────────────────────────────────────────────────
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

    // ── Phase 3: Assessment lock timer ───────────────────────────────────────
    if (gamePhase == 3) {
      // Update nearest target for UI
      InjuredAnimal? nearest;
      double nearestD = _assessRange;
      for (final a in animals) {
        if (a.isRescued) continue;
        final d = (a.animalPos - dronePos).length;
        if (d < nearestD) { nearestD = d; nearest = a; }
      }
      _nearestAssessTarget = nearest;

      if (assessLockActive && activeAssessAnimal != null) {
        final dist = (activeAssessAnimal!.animalPos - dronePos).length;
        if (dist > _assessRange * 1.15) {
          // Drone moved out of range — cancel lock
          assessLockActive   = false;
          _assessLockTimer   = 0;
          activeAssessAnimal = null;
          reactionMsg = '🔬 Assessment cancelled — too far!';
          _triggerReaction(false, inRange: false);
        } else {
          _assessLockTimer += dt;
          if (_assessLockTimer >= _assessDuration) {
            final target = activeAssessAnimal!;
            _completeAnimalAssessment(target);
          }
        }
      } else if (!assessLockActive) {
        activeAssessAnimal = null;
      }

      // Combo timer
      if (comboCount > 0) {
        comboTimer -= dt;
        if (comboTimer <= 0) _breakCombo();
      }

      // Critical animal timer
      _criticalAlertTimer -= dt;
      if (_criticalAlertTimer <= 0 && criticalAlerts.length < 2) {
        _criticalAlertTimer = 35.0 + math.Random().nextDouble() * 20.0;
        _spawnCriticalAnimal();
      }
      for (final alert in List<CriticalAnimalAlert>.from(criticalAlerts)) {
        if (!alert.handled) {
          alert.timeLeft -= dt;
          if (alert.timeLeft <= 0) _expireCriticalAnimal(alert);
        }
      }
    }

    notifyListeners();
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  RESTORING PARK RENDERER
// ══════════════════════════════════════════════════════════════════════════════
class RestoringParkRenderer extends Component {
  final WildlifeRescueGame game;
  double _t = 0;
  RestoringParkRenderer({required this.game});

  @override
  void update(double dt) => _t += dt * 0.2;

  @override
  void render(Canvas canvas) {
    final w = game.size.x, h = game.size.y;

    canvas.drawRect(Rect.fromLTWH(0, 0, w, h),
        Paint()..shader = ui.Gradient.linear(
            Offset.zero, Offset(0, h), [
          const Color(0xFF060E06),
          Color.lerp(const Color(0xFF0A1808), const Color(0xFF0E2010),
              (math.sin(_t) * 0.5 + 0.5) * 0.4)!,
          const Color(0xFF060A04),
        ], [0.0, 0.5, 1.0]));

    final hr = (game.habitatHealth / 100.0).clamp(0.0, 1.0);
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h),
        Paint()
          ..color = const Color(0xFF69F0AE).withValues(alpha: hr * 0.06)
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
//  RESCUE DRONE COMPONENT
// ══════════════════════════════════════════════════════════════════════════════
class RescueDroneComponent extends Component {
  final WildlifeRescueGame game;
  double _t = 0;
  RescueDroneComponent({required this.game});

  @override
  void update(double dt) => _t += dt;

  @override
  void render(Canvas canvas) {
    final cx = game.dronePos.x;
    final cy = game.dronePos.y + math.sin(_t * 3.0) * 2.5;

    final rangeColor = game.gamePhase == 3
        ? const Color(0xFFFFB300)
        : const Color(0xFF1E88E5);
    final rangeR = game.gamePhase == 3
        ? WildlifeRescueGame._assessRange
        : WildlifeRescueGame._posterRange;

    // Range indicator
    canvas.drawCircle(Offset(cx, cy), rangeR,
        Paint()
          ..color = rangeColor.withValues(alpha: 0.065)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2);

    // Assessment lock progress glow
    if (game.gamePhase == 3 && game.activeAssessAnimal != null) {
      final prog  = game.assessHoldProgress;
      canvas.drawCircle(Offset(cx, cy), 14 + prog * 10,
          Paint()
            ..color = const Color(0xFFFFB300).withValues(alpha: prog * 0.30)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    }

    canvas.save();
    canvas.translate(cx, cy);

    // Shadow
    canvas.drawOval(
        Rect.fromCenter(center: const Offset(0, 14), width: 38, height: 9),
        Paint()..color = Colors.black.withValues(alpha: 0.28));

    // Arms
    final armPaint = Paint()
      ..color = const Color(0xFF1A2E18)
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;
    for (final (dx, dy) in [(-1, -1), (1, -1), (-1, 1), (1, 1)]) {
      canvas.drawLine(Offset(dx * 8, dy * 8), Offset(dx * 22, dy * 22), armPaint);
    }

    // Propellers
    const propPositions = [(-22.0, -22.0), (22.0, -22.0), (-22.0, 22.0), (22.0, 22.0)];
    for (final (px, py) in propPositions) {
      canvas.save();
      canvas.translate(px, py);
      canvas.rotate(_t * 13);
      final propPaint = Paint()
        ..color = const Color(0xFFFFB300).withValues(alpha: 0.55)
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(const Offset(-8, 0), const Offset(8, 0), propPaint);
      canvas.drawLine(const Offset(0, -8), const Offset(0, 8), propPaint);
      canvas.restore();
    }

    // Body
    canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(-13, -10, 26, 20), const Radius.circular(6)),
        Paint()..color = const Color(0xFF142810));

    // Sensor glow
    final glowColor = game.gamePhase == 3
        ? const Color(0xFFFFB300)
        : const Color(0xFF1E88E5);
    canvas.drawCircle(Offset.zero, 7,
        Paint()
          ..color = glowColor.withValues(alpha: 0.75 + math.sin(_t * 4) * 0.20)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    canvas.drawCircle(Offset.zero, 3.5,
        Paint()..color = Colors.white.withValues(alpha: 0.95));

    // Phase icon
    final tp = TextPainter(
      text: TextSpan(
          text: game.gamePhase == 3 ? '🦓' : '📋',
          style: const TextStyle(fontSize: 8)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(-tp.width / 2, 13 - tp.height / 2));

    canvas.restore();
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  INJURED ANIMAL COMPONENT
// ══════════════════════════════════════════════════════════════════════════════
class InjuredAnimal extends Component {
  final WildlifeRescueGame game;
  final AnimalType   type;
  final FirstAidAction requiredAid;
  double hx, hy;
  final int seed;

  bool   isRescued         = false;
  bool   isCritical        = false;
  bool   triggerHealSparkle = false;
  double sparkleTimer       = 0;
  double _t                = 0;

  InjuredAnimal({
    required this.game, required this.type, required this.requiredAid,
    required double worldX, required double worldY, required this.seed,
  }) : hx = worldX, hy = worldY;

  Vector2 get animalPos => Vector2(hx, hy);
  void rescue() => isRescued = true;

  static const _specs = {
    AnimalType.zebra:  ('🦓', Color(0xFF90A4AE)),
    AnimalType.bird:   ('🦜', Color(0xFF558B2F)),
    AnimalType.monkey: ('🐒', Color(0xFF795548)),
    AnimalType.impala: ('🦌', Color(0xFFFFB300)),
  };

  @override
  void update(double dt) {
    _t += dt;
    if (triggerHealSparkle) { sparkleTimer = 2.0; triggerHealSparkle = false; }
    if (sparkleTimer > 0) sparkleTimer = math.max(0, sparkleTimer - dt);
  }

  @override
  void render(Canvas canvas) {
    if (isRescued) { _drawRescued(canvas); return; }

    final spec  = _specs[type]!;
    //final color = spec.$2;
    final pulse = 0.7 + math.sin(_t * 2.4) * 0.20;

    // Sparkle on recent heal attempt (wrong action visual feedback)
    if (sparkleTimer > 0) _drawSparkle(canvas, const Color(0xFFEF5350), sparkleTimer / 2.0);

    // Critical pulsing ring
    if (isCritical) {
      final urgency = math.sin(_t * 8).abs();
      final alert = game.criticalAlerts.firstWhere(
          (a) => a.animal == this,
          orElse: () => CriticalAnimalAlert(animal: this, timeLeft: 0));
      canvas.drawCircle(Offset(hx, hy), 44 + urgency * 10,
          Paint()
            ..color = Colors.red.withValues(alpha: 0.22 + urgency * 0.14)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
      canvas.drawCircle(Offset(hx, hy), 34,
          Paint()
            ..color = Colors.red.withValues(alpha: 0.75)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.8);
      final ctp = TextPainter(
        text: TextSpan(
            text: '⚡ ${alert.timeLeft.ceil()}s',
            style: const TextStyle(
                color: Colors.red, fontSize: 10, fontWeight: FontWeight.w900)),
        textDirection: TextDirection.ltr,
      )..layout();
      ctp.paint(canvas, Offset(hx - ctp.width / 2, hy - 62));
    }

    // Eco-discovery shimmer
    if (!game.assessmentResultActive || game.pendingTreatTarget != this) {
      final idx = game.animals.indexOf(this);
      if (game.ecoDiscoveryIndices.contains(idx) &&
          !game.discoveredEcoAnimals.contains(idx)) {
        final shimmer = 0.28 + math.sin(_t * 3.5) * 0.22;
        canvas.drawCircle(Offset(hx - 22, hy - 22), 6,
            Paint()
              ..color = const Color(0xFFE040FB).withValues(alpha: shimmer)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
      }
    }

    // Assessment progress ring (active on this animal)
    if (game.activeAssessAnimal == this) {
      _drawAssessProgress(canvas, game.assessHoldProgress);
    } else {
      // Default distress ring
      canvas.drawCircle(Offset(hx, hy), 30 * pulse,
          Paint()
            ..color = const Color(0xFFEF5350).withValues(alpha: 0.10)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
      canvas.drawCircle(Offset(hx, hy), 24,
          Paint()
            ..color = const Color(0xFFEF5350).withValues(alpha: 0.55)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0);
    }

    // Animal emoji
    final ep = TextPainter(
      text: TextSpan(text: spec.$1, style: const TextStyle(fontSize: 18)),
      textDirection: TextDirection.ltr,
    )..layout();
    ep.paint(canvas, Offset(hx - ep.width / 2, hy - ep.height / 2 - 4));

    // Distress heart
    final hp = TextPainter(
      text: const TextSpan(text: '❤️', style: TextStyle(fontSize: 9)),
      textDirection: TextDirection.ltr,
    )..layout();
    hp.paint(canvas, Offset(hx - hp.width / 2, hy + 14));
  }

  void _drawAssessProgress(Canvas canvas, double progress) {
    const startAngle = -math.pi / 2;
    const full       = math.pi * 2;
    final beamAngle  = startAngle + full * progress;

    // Beam trail
    canvas.drawArc(
      Rect.fromCenter(center: Offset(hx, hy), width: 82, height: 82),
      beamAngle - 0.5, 0.5, false,
      Paint()
        ..color = const Color(0xFFFFB300).withValues(alpha: 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10.0,
    );
    // Leading edge
    canvas.drawLine(Offset(hx, hy),
        Offset(hx + math.cos(beamAngle) * 41, hy + math.sin(beamAngle) * 41),
        Paint()..color = const Color(0xFFFFB300).withValues(alpha: 0.32)..strokeWidth = 2.0);

    // Background ring
    canvas.drawCircle(Offset(hx, hy), 41,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.08)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4.0);

    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCenter(center: Offset(hx, hy), width: 82, height: 82),
        startAngle, full * progress, false,
        Paint()
          ..color = const Color(0xFFFFB300).withValues(alpha: 0.88)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4.0
          ..strokeCap = StrokeCap.round,
      );
    }

    final pct = (progress * 100).toInt();
    final tp  = TextPainter(
      text: TextSpan(
          text: '$pct%',
          style: const TextStyle(
              color: Color(0xFFFFB300), fontSize: 9, fontWeight: FontWeight.bold)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(hx - tp.width / 2, hy - 58));

    final al = TextPainter(
      text: const TextSpan(
          text: '🔬 Assessing…',
          style: TextStyle(
              color: Color(0xFFFFB300), fontSize: 8.5, fontWeight: FontWeight.w700)),
      textDirection: TextDirection.ltr,
    )..layout();
    al.paint(canvas, Offset(hx - al.width / 2, hy + 46));
  }

  void _drawSparkle(Canvas canvas, Color color, double progress) {
    final rng = math.Random(seed + 777);
    for (int i = 0; i < 10; i++) {
      final angle = (i / 10) * math.pi * 2;
      final r     = progress * 50.0;
      canvas.drawCircle(
        Offset(hx + math.cos(angle) * r, hy + math.sin(angle) * r),
        2.5 + rng.nextDouble() * 2.5,
        Paint()..color = color.withValues(alpha: (progress * 0.85).clamp(0, 1)),
      );
    }
  }

  void _drawRescued(Canvas canvas) {
    if (sparkleTimer > 0) _drawSparkle(canvas, const Color(0xFF69F0AE), sparkleTimer / 2.0);

    canvas.drawCircle(Offset(hx, hy), 22,
        Paint()..color = const Color(0xFF69F0AE).withValues(alpha: 0.14));
    canvas.drawCircle(Offset(hx, hy), 22,
        Paint()
          ..color = const Color(0xFF69F0AE).withValues(alpha: 0.60)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0);
    final tp = TextPainter(
      text: const TextSpan(text: '✅', style: TextStyle(fontSize: 13)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(hx - tp.width / 2, hy - tp.height / 2));
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  POSTER BOARD COMPONENT
// ══════════════════════════════════════════════════════════════════════════════
class PosterBoard extends Component {
  final WildlifeRescueGame game;
  double hx, hy;
  final int          seed;
  final PosterTheme  recommendedTheme;
  bool          hasPosted = false;
  PosterTheme?  theme;
  bool          isCorrectTheme = false;
  double        _t = 0;

  PosterBoard({
    required this.game,
    required double worldX, required double worldY,
    required this.seed,
    required this.recommendedTheme,
  }) : hx = worldX, hy = worldY;

  Vector2 get boardPos => Vector2(hx, hy);

  void post(PosterTheme t) {
    hasPosted      = true;
    theme          = t;
    isCorrectTheme = (t == recommendedTheme);
  }

  @override
  void update(double dt) => _t += dt;

  @override
  void render(Canvas canvas) {
    final pulse = 0.70 + math.sin(_t * 2.2) * 0.18;

    if (hasPosted) {
      // Posted board — green if correct theme, blue otherwise
      final borderColor = isCorrectTheme
          ? const Color(0xFF69F0AE)
          : const Color(0xFF1E88E5);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(hx, hy), width: 36, height: 28),
            const Radius.circular(4)),
        Paint()..color = borderColor.withValues(alpha: 0.22),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(hx, hy), width: 36, height: 28),
            const Radius.circular(4)),
        Paint()
          ..color = borderColor.withValues(alpha: 0.70)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8,
      );
      final tp = TextPainter(
        text: const TextSpan(text: '📋', style: TextStyle(fontSize: 14)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(hx - tp.width / 2, hy - tp.height / 2));
      if (isCorrectTheme) {
        final sp = TextPainter(
          text: const TextSpan(text: '✓', style: TextStyle(color: Color(0xFF69F0AE), fontSize: 9, fontWeight: FontWeight.bold)),
          textDirection: TextDirection.ltr,
        )..layout();
        sp.paint(canvas, Offset(hx + 10, hy - 18));
      }
    } else {
      // Unposted board — show recommended theme hint as subtle icon
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(hx, hy),
                width: 36 * pulse, height: 28 * pulse),
            const Radius.circular(4)),
        Paint()
          ..color = const Color(0xFF1E88E5).withValues(alpha: 0.40)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8,
      );
      final tp = TextPainter(
        text: const TextSpan(text: '📌', style: TextStyle(fontSize: 12)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(hx - tp.width / 2, hy - tp.height / 2));

      // Show recommended theme hint (subtle)
      final hint = _themeEmoji(recommendedTheme);
      final hp = TextPainter(
        text: TextSpan(text: hint, style: const TextStyle(fontSize: 8)),
        textDirection: TextDirection.ltr,
      )..layout();
      canvas.drawCircle(Offset(hx + 14, hy - 16), 8,
          Paint()..color = const Color(0xFF1E88E5).withValues(alpha: 0.18));
      hp.paint(canvas, Offset(hx + 14 - hp.width / 2, hy - 16 - hp.height / 2));
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
class RescueHud extends StatelessWidget {
  final WildlifeRescueGame game;
  const RescueHud(this.game, {super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: game,
      builder: (_, __) {
        final warn    = game.timeLeft < 20;
        final hr      = (game.habitatHealth / 100.0).clamp(0.0, 1.0);
        final hColor  = game.habitatHealth >= 80
            ? const Color(0xFF69F0AE)
            : game.habitatHealth >= 50
                ? const Color(0xFFFFB300)
                : const Color(0xFFEF5350);

        return SafeArea(child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch, children: [

            // Phase tag
            Align(alignment: Alignment.topCenter, child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
              decoration: BoxDecoration(
                color: game.gamePhase == 3
                    ? const Color(0xFFFFB300).withValues(alpha: 0.90)
                    : const Color(0xFF1E88E5).withValues(alpha: 0.90),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(
                    color: (game.gamePhase == 3
                        ? const Color(0xFFFFB300)
                        : const Color(0xFF1E88E5)).withValues(alpha: 0.38),
                    blurRadius: 12)],
              ),
              child: Text(
                game.gamePhase == 3
                    ? '🦓  PHASE 3 — WILDLIFE RESCUE'
                    : '📋  PHASE 4 — AWARENESS CAMPAIGN',
                style: const TextStyle(color: Colors.white,
                    fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1.1),
              ),
            )),
            const SizedBox(height: 8),

            // Stats row
            Row(children: [
              _RHTile(Icons.timer_rounded,
                  '${game.timeLeft.toInt()}s', 'TIME',
                  warn ? Colors.red : Colors.white),
              const SizedBox(width: 5),
              _RHTile(
                  game.gamePhase == 3 ? Icons.pets_rounded : Icons.campaign_rounded,
                  game.gamePhase == 3
                      ? '${game.animalsRescued}/${WildlifeRescueGame.kMinAnimalsRequired}+'
                      : '${game.postersPlaced}/${WildlifeRescueGame.totalPosters}',
                  game.gamePhase == 3 ? 'RESCUED' : 'POSTERS',
                  game.gamePhase == 3
                      ? (game.animalsRescued >= WildlifeRescueGame.kMinAnimalsRequired
                          ? const Color(0xFF69F0AE) : Colors.white70)
                      : const Color(0xFF1E88E5)),
              const SizedBox(width: 5),
              _RHTile(Icons.eco_rounded, '${game.ecoPoints}', 'ECO-PTS',
                  Colors.limeAccent),
              const SizedBox(width: 5),
              _RHTile(Icons.forest_rounded,
                  '${game.habitatHealth.toStringAsFixed(0)}%', 'HABITAT',
                  hColor),
            ]),
            const SizedBox(height: 5),

            // Habitat health bar
            Row(children: [
              const Text('🌿', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Expanded(child: ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: LinearProgressIndicator(
                  value: hr,
                  backgroundColor: Colors.white12,
                  valueColor: AlwaysStoppedAnimation(hColor),
                  minHeight: 8,
                ),
              )),
              const SizedBox(width: 6),
              RichText(text: TextSpan(children: [
                TextSpan(text: '${game.habitatHealth.toStringAsFixed(0)}%',
                    style: TextStyle(color: hColor, fontSize: 10,
                        fontWeight: FontWeight.bold)),
                const TextSpan(text: ' / 80%',
                    style: TextStyle(color: Color(0xFF69F0AE), fontSize: 8)),
              ])),
            ]),
            const SizedBox(height: 4),

            // Phase 3: assessment lock progress bar
            if (game.gamePhase == 3 && game.assessLockActive) ...[
              Row(children: [
                const Text('🔒', style: TextStyle(fontSize: 12)),
                const SizedBox(width: 5),
                Expanded(child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: game.assessHoldProgress,
                    backgroundColor: Colors.white12,
                    valueColor: const AlwaysStoppedAnimation(Color(0xFFFFB300)),
                    minHeight: 7,
                  ),
                )),
                const SizedBox(width: 6),
                const Text('Assessing…',
                    style: TextStyle(
                        color: Color(0xFFFFB300),
                        fontSize: 9, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 4),
            ],

            // Phase 3: nudge when animal nearby but not assessing
            if (game.gamePhase == 3 && !game.assessLockActive &&
                game._nearestAssessTarget != null &&
                !game.firstAidSelectorOpen && !game.assessmentResultActive) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFB300).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFFB300).withValues(alpha: 0.35)),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('🔬', style: TextStyle(fontSize: 10)),
                  SizedBox(width: 5),
                  Text('Injured animal nearby — tap ASSESS!',
                      style: TextStyle(color: Color(0xFFFFB300),
                          fontSize: 9, fontWeight: FontWeight.w700)),
                ]),
              ),
            ],

            // Phase 3: rescue streak indicator
            if (game.gamePhase == 3 && game.rescueStreak >= 2)
              Align(alignment: Alignment.centerRight,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE040FB).withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE040FB).withValues(alpha: 0.55)),
                  ),
                  child: Text('🎯 Rescue Streak x${game.rescueStreak}!',
                      style: const TextStyle(color: Color(0xFFE040FB),
                          fontSize: 9, fontWeight: FontWeight.w900)),
                ),
              ),

            // Phase 3: combo indicator
            if (game.gamePhase == 3 && game.comboCount > 0)
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

            // Phase 3: critical animal alert count
            if (game.gamePhase == 3 && game.criticalAlerts.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                margin: const EdgeInsets.only(top: 3),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.60)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Text('⚡', style: TextStyle(fontSize: 10)),
                  const SizedBox(width: 5),
                  Text(
                    '${game.criticalAlerts.length} CRITICAL ANIMAL${game.criticalAlerts.length > 1 ? "S" : ""}!  Treat before condition worsens!',
                    style: const TextStyle(
                        color: Colors.red, fontSize: 8.5, fontWeight: FontWeight.w900),
                  ),
                ]),
              ),

            // Eco-guide hint
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

class _RHTile extends StatelessWidget {
  final IconData icon;
  final String val, label;
  final Color color;
  const _RHTile(this.icon, this.val, this.label, this.color);
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
class RescueControls extends StatefulWidget {
  final WildlifeRescueGame game;
  const RescueControls(this.game, {super.key});
  @override
  State<RescueControls> createState() => _RescueControlsState();
}

class _RescueControlsState extends State<RescueControls> {
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
      if (widget.game.gamePhase == 3) {
        widget.game.triggerAssessment();
      } else {
        widget.game.placePost();
      }
    }
    if (pressed) {
      if (k == LogicalKeyboardKey.digit1) widget.game.selectTheme(PosterTheme.deforestation);
      if (k == LogicalKeyboardKey.digit2) widget.game.selectTheme(PosterTheme.waterPollution);
      if (k == LogicalKeyboardKey.digit3) widget.game.selectTheme(PosterTheme.soilHealth);
      if (k == LogicalKeyboardKey.digit4) widget.game.selectTheme(PosterTheme.wildlifeProtection);
      if (k == LogicalKeyboardKey.digit5) widget.game.selectTheme(PosterTheme.wasteManagement);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.game,
      builder: (_, __) {
        final phase    = widget.game.gamePhase;
        final canAct   = phase == 3
            ? widget.game._hasNearbyAnimal
            : widget.game._hasNearbyBoard;
        final actColor = phase == 3
            ? const Color(0xFFFFB300)
            : const Color(0xFF1E88E5);

        return KeyboardListener(
          focusNode: _fk,
          onKeyEvent: _onKey,
          child: Stack(children: [

            // D-pad
            Align(
              alignment: Alignment.bottomLeft,
              child: SafeArea(child: Padding(
                padding: const EdgeInsets.only(bottom: 16, left: 12),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  _RPad('⬆', _up, Colors.cyanAccent,
                      onDown: () { setState(() => _up = true);  widget.game.setUpKey(true); },
                      onUp:   () { setState(() => _up = false); widget.game.setUpKey(false); }),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    _RPad('◀', _lt, Colors.cyanAccent,
                        onDown: () { setState(() => _lt = true);  widget.game.setLeftKey(true); },
                        onUp:   () { setState(() => _lt = false); widget.game.setLeftKey(false); }),
                    const SizedBox(width: 4),
                    _RPad('⬇', _dn, Colors.cyanAccent,
                        onDown: () { setState(() => _dn = true);  widget.game.setDownKey(true); },
                        onUp:   () { setState(() => _dn = false); widget.game.setDownKey(false); }),
                    const SizedBox(width: 4),
                    _RPad('▶', _rt, Colors.cyanAccent,
                        onDown: () { setState(() => _rt = true);  widget.game.setRightKey(true); },
                        onUp:   () { setState(() => _rt = false); widget.game.setRightKey(false); }),
                  ]),
                ]),
              )),
            ),

            // Phase 4: right-side poster theme panel (mirrors _ToolSidePanel)
            if (phase == 4)
              Align(
                alignment: Alignment.centerRight,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _PosterThemePanel(game: widget.game),
                  ),
                ),
              ),

            // Action button (bottom-right)
            Align(alignment: Alignment.bottomRight, child: SafeArea(child: Padding(
              padding: const EdgeInsets.only(bottom: 20, right: 14),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                // Lock status hint
                if (phase == 3 && widget.game.activeAssessAnimal != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.70),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: const Color(0xFFFFB300).withValues(alpha: 0.42)),
                    ),
                    child: const Text('🔒 Assessing — stay in range!',
                        style: TextStyle(
                            color: Color(0xFFFFB300),
                            fontSize: 9, fontWeight: FontWeight.bold)),
                  ),
                if (phase == 3 && widget.game.firstAidSelectorOpen)
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF69F0AE).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: const Color(0xFF69F0AE).withValues(alpha: 0.42)),
                    ),
                    child: const Text('🩹 Select first-aid action!',
                        style: TextStyle(
                            color: Color(0xFF69F0AE),
                            fontSize: 9, fontWeight: FontWeight.bold)),
                  ),
                GestureDetector(
                  onTap: () {
                    if (phase == 3) {
                      widget.game.triggerAssessment();
                    } else {
                      widget.game.placePost();
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    width: 70, height: 70,
                    decoration: BoxDecoration(
                      color: canAct
                          ? actColor.withValues(alpha: 0.22)
                          : Colors.black.withValues(alpha: 0.60),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: canAct ? actColor : Colors.white24,
                          width: canAct ? 2.5 : 1.5),
                      boxShadow: canAct
                          ? [BoxShadow(
                              color: actColor.withValues(alpha: 0.42),
                              blurRadius: 16)]
                          : [],
                    ),
                    child: Center(child: Text(
                      phase == 3
                          ? (widget.game.assessLockActive
                              ? '🔒\nLOCK\nING…'
                              : '🔬\nASSESS')
                          : '📋\nPLACE',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: canAct ? actColor : Colors.white30,
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

// ══════════════════════════════════════════════════════════════════════════════
//  POSTER THEME SIDE PANEL  (Phase 4, mirrors _ToolSidePanel)
//  Tapping a theme selects it AND immediately places if a board is in range.
// ══════════════════════════════════════════════════════════════════════════════
class _PosterThemePanel extends StatelessWidget {
  final WildlifeRescueGame game;
  const _PosterThemePanel({required this.game});

  static const _themes = [
    (PosterTheme.deforestation,      '🌳', 'Deforestation',   'Forest boards',    Color(0xFF2E7D32)),
    (PosterTheme.waterPollution,     '💧', 'Water Pollution', 'Wetland boards',   Color(0xFF0288D1)),
    (PosterTheme.soilHealth,         '🌱', 'Soil Health',     'Dry land boards',  Color(0xFFFFB300)),
    (PosterTheme.wildlifeProtection, '🦓', 'Wildlife',        'Park centre',      Color(0xFFEF5350)),
    (PosterTheme.wasteManagement,    '♻️', 'Waste Mgmt',      'Entry boards',     Color(0xFF29B6F6)),
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: game,
      builder: (_, __) {
        final nearestBoard = game._nearestBoard;

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: _themes.map((spec) {
            final (theme, emoji, label, hint, color) = spec;
            final selected    = game.selectedTheme == theme;
            final isRecommend = nearestBoard != null &&
                nearestBoard.recommendedTheme == theme;

            final borderColor = selected
                ? color
                : isRecommend
                    ? color.withValues(alpha: 0.60)
                    : Colors.white.withValues(alpha: 0.12);
            final bgColor = selected
                ? color.withValues(alpha: 0.25)
                : isRecommend
                    ? color.withValues(alpha: 0.10)
                    : Colors.black.withValues(alpha: 0.62);

            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                game.selectTheme(theme);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                margin: const EdgeInsets.only(bottom: 5),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                constraints: const BoxConstraints(minWidth: 118, maxWidth: 138),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: borderColor,
                    width: (selected || isRecommend) ? 1.8 : 1.1,
                  ),
                  boxShadow: selected
                      ? [BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 10)]
                      : isRecommend
                          ? [BoxShadow(color: color.withValues(alpha: 0.20), blurRadius: 6)]
                          : [],
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 30, height: 30,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.withValues(alpha: 0.18),
                      border: Border.all(color: color.withValues(alpha: 0.45)),
                    ),
                    child: Center(child: Text(emoji, style: const TextStyle(fontSize: 14))),
                  ),
                  const SizedBox(width: 7),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(label,
                          style: TextStyle(
                              color: selected ? color : Colors.white,
                              fontWeight: FontWeight.w800, fontSize: 10.5)),
                      Text(hint,
                          style: TextStyle(
                              color: color.withValues(alpha: 0.68), fontSize: 8)),
                    ],
                  )),
                  if (isRecommend) ...[
                    const SizedBox(width: 4),
                    Text('★',
                        style: TextStyle(
                            color: color, fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ]),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _RPad extends StatelessWidget {
  final String label;
  final bool   isActive;
  final Color  color;
  final VoidCallback onDown, onUp;
  const _RPad(this.label, this.isActive, this.color,
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
//  ANIMAL ASSESSMENT OVERLAY  (mirrors ScanResultOverlay)
//  Non-blocking card shown after 1.5s assessment lock completes.
//  Shows identified condition + eco-fact + correct first-aid hint (first time).
//  Auto-dismisses in 4 s. Player can tap TREAT IT to open first-aid picker early.
// ══════════════════════════════════════════════════════════════════════════════
class AnimalAssessmentOverlay extends StatefulWidget {
  final WildlifeRescueGame game;
  const AnimalAssessmentOverlay(this.game, {super.key});
  @override
  State<AnimalAssessmentOverlay> createState() => _AnimalAssessmentOverlayState();
}

class _AnimalAssessmentOverlayState extends State<AnimalAssessmentOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _scale;

  @override
  void initState() {
    super.initState();
    _ctrl  = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 340))..forward();
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.game,
      builder: (_, __) {
        final result = widget.game.lastAssessmentResult;
        if (result == null) return const SizedBox.shrink();

        final rawTimer       = widget.game.assessmentResultTimer;
        final displayDuration = WildlifeRescueGame._assessResultDisplay;
        final progress       = (rawTimer / displayDuration).clamp(0.0, 1.0);
        final pts            = widget.game.lastAssessmentPoints;

        return Center(
          child: ScaleTransition(
            scale: _scale,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 18),
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
              constraints: const BoxConstraints(maxWidth: 340),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF0A0A14),
                    result.color.withValues(alpha: 0.12),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: result.color.withValues(alpha: 0.70), width: 2.0),
                boxShadow: [
                  BoxShadow(color: result.color.withValues(alpha: 0.28), blurRadius: 28),
                  const BoxShadow(color: Colors.black54, blurRadius: 18),
                ],
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [

                // Header row
                Row(children: [
                  SizedBox(
                    width: 22, height: 22,
                    child: CustomPaint(
                        painter: _ArcCountdownPainter(progress, result.color)),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('ANIMAL ASSESSMENT COMPLETE',
                        style: TextStyle(color: Colors.white54, fontSize: 9,
                            fontWeight: FontWeight.w900, letterSpacing: 1.8)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFB300).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: const Color(0xFFFFB300).withValues(alpha: 0.42)),
                    ),
                    child: Text('+$pts pts',
                        style: const TextStyle(
                            color: Color(0xFFFFB300),
                            fontSize: 9, fontWeight: FontWeight.bold)),
                  ),
                ]),
                const SizedBox(height: 12),

                // Identified condition — most prominent section
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: result.color.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: result.color.withValues(alpha: 0.55), width: 1.8),
                    boxShadow: [
                      BoxShadow(
                          color: result.color.withValues(alpha: 0.18), blurRadius: 10),
                    ],
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Text(result.icon, style: const TextStyle(fontSize: 28)),
                      const SizedBox(width: 10),
                      Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('CONDITION IDENTIFIED',
                            style: TextStyle(
                                color: result.color.withValues(alpha: 0.75),
                                fontSize: 8,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5)),
                        const SizedBox(height: 2),
                        Text(result.typeName,
                            style: TextStyle(
                                color: result.color,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5)),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: result.color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(result.condition,
                              style: TextStyle(
                                  color: result.color.withValues(alpha: 0.90),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5)),
                        ),
                      ])),
                    ]),
                    const SizedBox(height: 8),
                    Text(result.ecoFact,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 10, height: 1.5)),
                  ]),
                ),
                const SizedBox(height: 10),

                // First-aid guide (first encounter) / Memory prompt (repeat)
                widget.game.assessmentShowsHints
                    ? Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('REQUIRED FIRST AID',
                              style: TextStyle(color: Colors.white38, fontSize: 7.5,
                                  fontWeight: FontWeight.w900, letterSpacing: 1.3)),
                          const SizedBox(height: 6),
                          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Container(
                              width: 16, height: 16, alignment: Alignment.center,
                              decoration: BoxDecoration(
                                  color: result.color.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: result.color.withValues(alpha: 0.50))),
                              child: Text('✦',
                                  style: TextStyle(
                                      color: result.color,
                                      fontSize: 8, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 6),
                            Expanded(child: Text(result.correctAidLabel,
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 9, height: 1.3))),
                          ]),
                        ]),
                      )
                    : Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF69F0AE).withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: const Color(0xFF69F0AE).withValues(alpha: 0.35)),
                        ),
                        child: const Column(mainAxisSize: MainAxisSize.min, children: [
                          Text('🧠 YOU KNOW THIS ONE',
                              style: TextStyle(color: Color(0xFF69F0AE), fontSize: 9.5,
                                  fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                          SizedBox(height: 5),
                          Text(
                            'You\'ve treated this animal type before.\nApply the correct first-aid from memory!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Colors.white54, fontSize: 9.5, height: 1.4),
                          ),
                        ]),
                      ),
                const SizedBox(height: 14),

                // TREAT IT button
                GestureDetector(
                  onTap: () => widget.game.openFirstAidForPending(),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: result.color.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: result.color, width: 2.0),
                      boxShadow: [
                        BoxShadow(
                            color: result.color.withValues(alpha: 0.38), blurRadius: 14),
                      ],
                    ),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(result.icon, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      Text('TREAT IT  →  SELECT FIRST AID',
                          style: TextStyle(
                              color: result.color,
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8)),
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
    final cx = size.width / 2; final cy = size.height / 2;
    final r  = math.min(cx, cy) - 1.5;
    canvas.drawCircle(Offset(cx, cy), r,
        Paint()..color = Colors.white12..style = PaintingStyle.stroke..strokeWidth = 2.0);
    canvas.drawArc(
        Rect.fromCenter(center: Offset(cx, cy), width: r * 2, height: r * 2),
        -math.pi / 2, math.pi * 2 * progress, false,
        Paint()
          ..color = color.withValues(alpha: 0.80)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(_ArcCountdownPainter old) => old.progress != progress;
}

// ══════════════════════════════════════════════════════════════════════════════
//  FIRST AID MINI-GAME OVERLAY  (updated — opens from assessment card)
// ══════════════════════════════════════════════════════════════════════════════
class FirstAidMiniGame extends StatelessWidget {
  final WildlifeRescueGame game;
  const FirstAidMiniGame(this.game, {super.key});

  @override
  Widget build(BuildContext context) {
    if (!game.firstAidActive) return const SizedBox.shrink();
    final animal = game.currentAnimal;
    if (animal == null)      return const SizedBox.shrink();

    final mobile = MediaQuery.of(context).size.width < 600;

    const actions = [
      (FirstAidAction.cleanWound, '🧴', 'Clean\nWound',  Color(0xFF29B6F6)),
      (FirstAidAction.splintLimb, '🩹', 'Splint\nLimb',  Color(0xFFFFB300)),
      (FirstAidAction.feedAnimal, '🌾', 'Feed\nAnimal',  Color(0xFF558B2F)),
    ];

    const animalEmojis = {
      AnimalType.zebra:  '🦓',
      AnimalType.bird:   '🦜',
      AnimalType.monkey: '🐒',
      AnimalType.impala: '🦌',
    };

    // Show the correct-aid hint only on first encounter (mirrors toolSelectorShowsHints)
    final showHints = game.assessmentShowsHints;
    final accent    = const Color(0xFF69F0AE);

    return Center(child: Container(
      margin: EdgeInsets.symmetric(horizontal: mobile ? 16 : 50),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF081008).withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEF5350).withValues(alpha: 0.50)),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 20)],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [

        // Header
        Row(children: [
          Text(animalEmojis[animal.type] ?? '🐾',
              style: TextStyle(fontSize: mobile ? 28 : 32)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(game.lastAssessmentResult?.typeName ?? 'Injured Animal',
                style: const TextStyle(color: Colors.white,
                    fontWeight: FontWeight.bold, fontSize: 15)),
            Text(game.lastAssessmentResult?.condition ?? '',
                style: const TextStyle(color: Color(0xFFEF5350),
                    fontSize: 10, fontWeight: FontWeight.w700)),
          ])),
        ]),

        const SizedBox(height: 6),

        // Hint / memory-recall banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: accent.withValues(alpha: 0.30)),
          ),
          child: showHints
              ? Text(
                  game.lastAssessmentResult?.correctAidLabel ??
                      'Apply the correct first-aid action',
                  style: TextStyle(color: accent,
                      fontSize: 9.5, fontWeight: FontWeight.w700))
              : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('🧠', style: TextStyle(fontSize: 11)),
                  SizedBox(width: 5),
                  Text('Recall from memory — no hints this time!',
                      style: TextStyle(color: Color(0xFF69F0AE),
                          fontSize: 9.5, fontWeight: FontWeight.w700)),
                ]),
        ),
        const SizedBox(height: 14),
        const Text('SELECT THE CORRECT FIRST AID',
            style: TextStyle(color: Colors.white38,
                fontSize: 9.5, letterSpacing: 1.5, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),

        // Action buttons
        Row(mainAxisAlignment: MainAxisAlignment.center,
            children: actions.map((a) {
          final (action, emoji, label, color) = a;
          // Highlight correct only when hints are active
          final isCorrect = showHints && action == animal.requiredAid;
          return GestureDetector(
            onTap: () => game.applyFirstAid(action),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 130),
              margin: const EdgeInsets.symmetric(horizontal: 6),
              padding: EdgeInsets.symmetric(
                  horizontal: mobile ? 12 : 18, vertical: 12),
              decoration: BoxDecoration(
                color: isCorrect
                    ? color.withValues(alpha: 0.22)
                    : color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: color.withValues(alpha: isCorrect ? 0.80 : 0.50),
                    width: isCorrect ? 2.0 : 1.2),
                boxShadow: isCorrect
                    ? [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 10)]
                    : [BoxShadow(color: color.withValues(alpha: 0.20), blurRadius: 6)],
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(emoji, style: TextStyle(fontSize: mobile ? 22 : 26)),
                const SizedBox(height: 4),
                Text(label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: isCorrect ? color : color.withValues(alpha: 0.85),
                        fontWeight: FontWeight.w900,
                        fontSize: mobile ? 9 : 10, height: 1.2)),
                if (isCorrect) ...[
                  const SizedBox(height: 2),
                  Text('✓', style: TextStyle(
                      color: color, fontSize: 9, fontWeight: FontWeight.bold)),
                ],
              ]),
            ),
          );
        }).toList()),
        const SizedBox(height: 10),
        const Text('Tap the correct action to apply immediately',
            style: TextStyle(color: Colors.white24, fontSize: 8.5),
            textAlign: TextAlign.center),
      ]),
    ));
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  POSTER TRAY  (Phase 4 — updated)
// ══════════════════════════════════════════════════════════════════════════════
class PosterTray extends StatelessWidget {
  final WildlifeRescueGame game;
  const PosterTray(this.game, {super.key});

  static const _themes = [
    (PosterTheme.deforestation,     '🌳', 'Deforestation', Color(0xFF2E7D32)),
    (PosterTheme.waterPollution,    '💧', 'Water\nPollution', Color(0xFF0288D1)),
    (PosterTheme.soilHealth,        '🌱', 'Soil\nHealth', Color(0xFFFFB300)),
    (PosterTheme.wildlifeProtection,'🦓', 'Wildlife',     Color(0xFFEF5350)),
    (PosterTheme.wasteManagement,   '♻️', 'Waste\nMgmt', Color(0xFF29B6F6)),
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: game,
      builder: (_, __) {
        final mobile = MediaQuery.of(context).size.width < 600;
        return Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(child: Padding(
            padding: const EdgeInsets.only(bottom: 80, left: 8, right: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.78),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('SELECT POSTER THEME  •  TAP = SELECT & PLACE',
                    style: TextStyle(color: Colors.white54,
                        fontSize: mobile ? 7 : 8.5,
                        letterSpacing: 1.2, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Row(mainAxisAlignment: MainAxisAlignment.center,
                    children: _themes.map((t) {
                  final (theme, emoji, label, color) = t;
                  final sel = game.selectedTheme == theme;
                  return GestureDetector(
                    onTap: () => game.selectTheme(theme),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 140),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      padding: EdgeInsets.symmetric(
                          horizontal: mobile ? 7 : 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: sel ? color.withValues(alpha: 0.22)
                            : Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: sel ? color : Colors.white12,
                            width: sel ? 2.0 : 1.0),
                        boxShadow: sel ? [BoxShadow(
                            color: color.withValues(alpha: 0.35), blurRadius: 10)] : [],
                      ),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(emoji, style: TextStyle(fontSize: mobile ? 16 : 20)),
                        const SizedBox(height: 2),
                        Text(label, textAlign: TextAlign.center,
                            style: TextStyle(
                                color: sel ? color : Colors.white70,
                                fontWeight: FontWeight.w900,
                                fontSize: mobile ? 7 : 8, height: 1.2)),
                      ]),
                    ),
                  );
                }).toList()),
                const SizedBox(height: 4),
                const Text('★ = recommended theme for nearest board (bonus pts)',
                    style: TextStyle(color: Colors.white38, fontSize: 7.5),
                    textAlign: TextAlign.center),
              ]),
            ),
          )),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  PHASE BANNER
// ══════════════════════════════════════════════════════════════════════════════
class RescuePhaseBanner extends StatelessWidget {
  final WildlifeRescueGame game;
  const RescuePhaseBanner(this.game, {super.key});

  @override
  Widget build(BuildContext context) {
    final p3     = game.gamePhase == 3;
    final accent = p3 ? const Color(0xFFFFB300) : const Color(0xFF1E88E5);
    return IgnorePointer(child: Center(child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: p3
            ? [const Color(0xFF1A1000), const Color(0xFF2E1C00)]
            : [const Color(0xFF001020), const Color(0xFF002040)]),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 24)],
        border: Border.all(color: accent.withValues(alpha: 0.55), width: 1.5),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(p3 ? 'PHASE 3' : 'PHASE 4',
            style: const TextStyle(color: Colors.white54,
                fontSize: 13, letterSpacing: 2.5)),
        const SizedBox(height: 4),
        Text(p3 ? '🦓  Wildlife Rescue' : '📋  Awareness Campaign',
            style: const TextStyle(color: Colors.white,
                fontWeight: FontWeight.bold, fontSize: 22)),
        const SizedBox(height: 6),
        Text(
          p3
              ? 'Fly close to an injured animal then tap 🔬 ASSESS.\nA 1.5 s lock starts — stay in range to complete it.\nRead the condition card, then tap TREAT IT!\nRescue ${WildlifeRescueGame.kMinAnimalsRequired}+ animals to advance!'
              : 'Select a poster theme (★ = recommended for bonus pts).\nFly to a board, then tap 📋 PLACE to install it!\nOr tap a theme on the right panel to select & place instantly.',
          textAlign: TextAlign.center,
          style: TextStyle(color: accent.withValues(alpha: 0.85), fontSize: 11.5),
        ),
      ]),
    )));
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  CRITICAL ANIMAL OVERLAY  (mirrors CriticalAlertOverlay)
// ══════════════════════════════════════════════════════════════════════════════
class CriticalAnimalOverlay extends StatelessWidget {
  final WildlifeRescueGame game;
  const CriticalAnimalOverlay(this.game, {super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: game,
      builder: (_, __) {
        if (game.criticalAlerts.isEmpty) return const SizedBox.shrink();
        final alert = game.criticalAlerts.first;

        return IgnorePointer(child: Align(
          alignment: Alignment.topCenter,
          child: SafeArea(child: Container(
            margin: const EdgeInsets.only(top: 58),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1A0000).withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.withValues(alpha: 0.75), width: 1.5),
              boxShadow: [BoxShadow(
                  color: Colors.red.withValues(alpha: 0.25), blurRadius: 20)],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Text('⚡', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Column(mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('CRITICAL ANIMAL — TREAT NOW!',
                    style: TextStyle(color: Colors.red, fontSize: 10,
                        fontWeight: FontWeight.w900, letterSpacing: 1.3)),
                const SizedBox(height: 2),
                const Text(
                  'An animal\'s condition is rapidly worsening.\nTreat it to save +15 pts — or lose −15!',
                  style: TextStyle(color: Colors.white60, fontSize: 9.5),
                ),
              ]),
              const SizedBox(width: 10),
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.red.withValues(alpha: 0.14),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.55))),
                child: Center(child: Text('${alert.timeLeft.ceil()}',
                    style: const TextStyle(color: Colors.red,
                        fontWeight: FontWeight.bold, fontSize: 16))),
              ),
            ]),
          )),
        ));
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  ECO-DISCOVERY OVERLAY  (mirrors EcoDiscoveryOverlay)
// ══════════════════════════════════════════════════════════════════════════════
class RescueDiscoveryOverlay extends StatefulWidget {
  final WildlifeRescueGame game;
  const RescueDiscoveryOverlay(this.game, {super.key});
  @override
  State<RescueDiscoveryOverlay> createState() => _RescueDiscoveryOverlayState();
}

class _RescueDiscoveryOverlayState extends State<RescueDiscoveryOverlay>
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
            child: const Text('+20 Eco-Points  •  Cultural Heritage Bonus!',
                style: TextStyle(color: Color(0xFF69F0AE),
                    fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ]),
      ),
    )));
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  REACTION FLASH
// ══════════════════════════════════════════════════════════════════════════════
class RescueReactionFx extends StatelessWidget {
  final WildlifeRescueGame game;
  const RescueReactionFx(this.game, {super.key});

  @override
  Widget build(BuildContext context) {
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

      // Combo flash
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
              game.comboCount >= 4
                  ? '🔥🔥🔥  ${game.comboCount}× RESCUE COMBO!  3× POINTS!'
                  : game.comboCount == 3
                      ? '🔥🔥  ${game.comboCount}× RESCUE COMBO!  2× POINTS!'
                      : '🔥  ${game.comboCount}× RESCUE COMBO!  2× POINTS!',
              style: const TextStyle(color: Colors.white,
                  fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.6),
            ),
          )),
        ),
    ]));
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  RESULTS OVERLAY  — REPLAY if below minimum, CONTINUE if met
// ══════════════════════════════════════════════════════════════════════════════
class RescueResultsOverlay extends StatelessWidget {
  final WildlifeRescueGame game;
  const RescueResultsOverlay(this.game, {super.key});

  @override
  Widget build(BuildContext context) {
    final r        = WildlifeRescueResult.current!;
    final guardian = r.guardianOfNatureBadge;
    final meetsMin = r.meetsMinimum;
    final stars    = r.animalsRescued >= WildlifeRescueGame.totalAnimals ? '★★★'
                   : r.animalsRescued >= 4 ? '★★☆'
                   : '★☆☆';

    return Container(
      color: Colors.black.withValues(alpha: 0.94),
      child: SafeArea(child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(children: [

          // Header card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: guardian
                  ? [const Color(0xFF001A0A), const Color(0xFF003018)]
                  : [const Color(0xFF1A1000), const Color(0xFF2A1800)]),
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 16)],
            ),
            child: Column(children: [
              Text(guardian ? '🦓' : '🌿', style: const TextStyle(fontSize: 50)),
              const SizedBox(height: 6),
              Text(guardian ? 'Ondiri Restored!' : 'Phase Complete',
                  style: const TextStyle(color: Colors.white, fontSize: 22,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              // Dynamic performance grade
              Text(r.performanceGrade,
                  style: TextStyle(
                    color: guardian
                        ? const Color(0xFF69F0AE)
                        : const Color(0xFFFFB300),
                    fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 1.0,
                  )),
              const SizedBox(height: 4),
              const Text('Phase 3 & 4 — Wildlife & Awareness Results',
                  style: TextStyle(color: Colors.white54, fontSize: 12)),
              const SizedBox(height: 8),
              Text(stars, style: const TextStyle(
                  color: Color(0xFFFFB300), fontSize: 28, letterSpacing: 6)),
              if (guardian) ...[
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
                    Text('Guardian of Nature Badge Unlocked!',
                        style: TextStyle(color: Color(0xFF69F0AE),
                            fontWeight: FontWeight.w800, fontSize: 11.5)),
                  ]),
                ),
              ],
            ]),
          ),

          const SizedBox(height: 14),

          // Rescue & poster stats
          _RRCard(children: [
            _RRBig('🦓',
                '${r.animalsRescued}/${WildlifeRescueGame.kMinAnimalsRequired}+',
                'Rescued',
                r.animalsRescued >= WildlifeRescueGame.kMinAnimalsRequired
                    ? const Color(0xFF69F0AE) : Colors.white70),
            _RRBig('📋', '${r.postersPlaced}', 'Posters',
                const Color(0xFF1E88E5)),
            _RRBig('🌿',
                '${r.habitatHealth.toStringAsFixed(0)}%', 'Habitat',
                const Color(0xFF69F0AE)),
            _RRBig('⭐', '${r.ecoPoints}', 'Eco-Pts', Colors.amber),
          ]),

          const SizedBox(height: 8),

          // Bonus events row
          _RRCard(children: [
            _RRBig('⚡', '${r.criticalSaves}', 'Crits\nSaved', Colors.redAccent),
            _RRBig('🌍', '${r.ecoDiscoveriesFound}/2', 'Discoveries',
                const Color(0xFF69F0AE)),
            _RRBig('🔥', '${r.maxCombo}×', 'Max\nCombo',
                const Color(0xFFFF6D00)),
            if (r.rescueStreakBonus > 0)
              _RRBig('🎯', '+${r.rescueStreakBonus}', 'Streak\nBonus',
                  const Color(0xFFE040FB)),
          ]),

          const SizedBox(height: 10),

          // Personalised performance summary
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

          // Treatment reference guide
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: const Color(0xFF081008),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(children: [
              const Text('First-Aid Reference Applied',
                  style: TextStyle(color: Colors.white70, fontSize: 12,
                      fontWeight: FontWeight.bold, letterSpacing: 1)),
              const SizedBox(height: 10),
              _RRRow('🦓', 'Zebra / Impala wounds',  '🧴 Clean Wound — antiseptic + bandage'),
              _RRRow('🦜', 'Malnourished birds',      '🌾 Feed Animal — seeds + electrolytes'),
              _RRRow('🐒', 'Monkey limb injuries',    '🩹 Splint Limb — immobilise joint'),
              _RRRow('📋', 'Poster campaign',         '★ Match recommended theme for bonus'),
            ]),
          ),

          const SizedBox(height: 18),

          // Primary action: REPLAY if below minimum, CONTINUE if met
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
                        'Replay  — Rescue ${r.minimumRequired - r.animalsRescued} More Animal(s)',
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
                        '💡 Tip: Fly near an injured animal and tap ASSESS.\n'
                        'Read the condition card, then tap TREAT IT to open first-aid.\n'
                        'Pick the correct action — it applies immediately!\n'
                        'Minimum ${r.minimumRequired} rescued animals needed to advance.',
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

class _RRCard extends StatelessWidget {
  final List<Widget> children;
  const _RRCard({required this.children});
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

class _RRBig extends StatelessWidget {
  final String emoji, value, label;
  final Color  color;
  const _RRBig(this.emoji, this.value, this.label, this.color);
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

class _RRRow extends StatelessWidget {
  final String emoji, label, action;
  const _RRRow(this.emoji, this.label, this.action);
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