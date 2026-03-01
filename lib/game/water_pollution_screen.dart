import 'dart:async' show Future, Timer;
import 'dart:math';
import 'package:ecoquest/game/level3/polluted_city_screen.dart';
import 'package:ecoquest/game/water_pollution_game.dart';
import 'package:ecoquest/game/rowing_components.dart';
import 'package:flame/extensions.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class WaterPollutionScreen extends StatefulWidget {
  final int bacteriaCulturesAvailable; // From Deforestation level
  final Map<String, int> materialsFromPreviousLevel;
  
  const WaterPollutionScreen({
    super.key,
    required this.bacteriaCulturesAvailable,
    required this.materialsFromPreviousLevel,
  });

  @override
  State<WaterPollutionScreen> createState() => _WaterPollutionScreenState();
}

class _WaterPollutionScreenState extends State<WaterPollutionScreen> {
  late final WaterPollutionGame game;
  
  int currentPhase = 0; // 0=Intro, 1=Collection, 2=Sorting, 3=Treatment, 4=Agriculture, 5=Complete
  bool _showPhaseTransition = false;
  
  // Phase 1 stats
  int wasteCollected = 0;
  int totalWasteItems = 50;

  // Phase 1 — enhanced rowing HUD fields (all mutated via setState in callbacks)
  double _collectionTimeLeft = 180.0;
  double _boatHealth = 100.0;
  // _sessionScore intentionally omitted — score is displayed via wasteCollected count
  bool _netOnCooldown = false;
  double _netCooldownFraction = 0.0;
  Timer? _netCooldownTimer;
  String? _lastObstacleMessage;
  Timer? _obstacleMessageTimer;

  // Phase 1 — failure/retry state
  bool _phase1Failed = false;
  String _failReason = '';

  // Phase 1 — results panel (shown for BOTH success and time-up paths)
  bool _phase1CompleteShown = false;
  bool _phase1WasTimeUp = false; // true = time lapsed, false = all collected

  // Phase 2 stats
  int sortingAccuracy = 0;
  int itemsSorted = 0;
  int sortedCorrectly = 0;   
  int sortedIncorrectly = 0;
  double _sortingTimeLeft = 75.0;
  bool _sortingTimerActive = false;
  bool _sortingTimeUpShown = false;
  int _sortingUnsorted = 0;

  // Phase 2 — full-completion state (player sorted everything before timer)
  bool _sortingCompleteShown = false;
  int _sortingCompleteCorrect = 0;
  int _sortingCompleteWrong = 0;
  double _sortingCompleteTimeLeft = 0.0;
  
  // Phase 3 stats
  int zonesTreated = 0;
  int totalZones = 6;
  double pollutionLevel = 100.0;
  
  // Phase 4 stats
  int farmsIrrigated = 0;
  int totalFarms = 3;
  int cropsMature = 0;

  // Phase 4 — new crop & irrigation system state
  String? _selectedCrop;        // set by crop selection card
  String? _irrigationMethod;    // 'furrow' | 'pipe'
  bool    _cropSelected   = false;
  bool    _methodSelected = false;
  bool    _showHarvestResult = false;
  String  _harvestResult  = '';
  String  _educationalTip = '';
  double  _farmGreenProgress = 0.0;
  int     _connectedChannels = 0;
  double  _irrigationTimeLeft = 90.0;
  
  @override
  void initState() {
    super.initState();
    game = WaterPollutionGame(
      bacteriaCultures: widget.bacteriaCulturesAvailable,
    );
    
    // ── Callback helper ───────────────────────────────────────────────────
    // All game callbacks fire from inside Flame's update() loop, which runs
    // during Flutter's build phase (inside GameWidget's LayoutBuilder).
    // Calling setState() synchronously from there throws:
    //   "setState() called during build"
    // Fix: every callback defers its setState via addPostFrameCallback so it
    // runs after the current frame is fully built and painted.
    void safeSetState(VoidCallback fn) {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(fn);
      });
    }

    // Set up callbacks
    game.onWasteCollected = (count) {
      safeSetState(() => wasteCollected = count);
    };

    game.onPhaseComplete = (phase) {
      if (phase == 4) {
        // Phase 4 completion is shown persistently — user must tap Continue
        // We just record the phase as done; the harvest overlay stays visible
        // Navigation to PollutedCityScreen happens from Continue button
        return;
      }
      safeSetState(() => _showPhaseTransition = true);
      Future.delayed(const Duration(seconds: 2), () {
        if (!mounted) return;
        safeSetState(() {
          currentPhase = phase + 1;
          _showPhaseTransition = false;
          if (phase == 1) {
            game.startPhase2Sorting();
          } else if (phase == 2) {
            game.startPhase3Treatment();
          } else if (phase == 3) {
            game.startPhase4Agriculture();
            Future.delayed(const Duration(milliseconds: 100), () {
              if (mounted) safeSetState(() {});
            });
          }
        });
      });
    };

    game.onSortingUpdate = (accuracy, sorted) {
      safeSetState(() {
        sortingAccuracy = accuracy;
        itemsSorted = sorted;
        sortedCorrectly = game.sortedCorrectly;
        sortedIncorrectly = game.sortedIncorrectly;
      });
    };

    game.onSortingTick = (timeLeft) {
      safeSetState(() {
        _sortingTimeLeft = timeLeft;
        _sortingTimerActive = true;
      });
    };

    game.onSortingTimeUp = (correct, wrong, unsorted) {
      safeSetState(() {
        _sortingTimeUpShown = true;
        _sortingUnsorted = unsorted;
        sortedCorrectly = correct;
        sortedIncorrectly = wrong;
      });
    };

    // Fires when player sorts every item before the timer runs out.
    // Shows a completion results panel — user must tap to proceed.
    game.onSortingComplete = (correct, wrong, timeRemaining) {
      safeSetState(() {
        _sortingCompleteShown = true;
        _sortingCompleteCorrect = correct;
        _sortingCompleteWrong = wrong;
        _sortingCompleteTimeLeft = timeRemaining;
        sortedCorrectly = correct;
        sortedIncorrectly = wrong;
      });
    };

    game.onTreatmentUpdate = (zones, pollution) {
      safeSetState(() {
        zonesTreated = zones;
        pollutionLevel = pollution;
      });
    };

    game.onAgricultureUpdate = (farms, crops) {
      safeSetState(() {
        farmsIrrigated = farms;
        cropsMature = crops;
      });
    };

    game.onFarmUpdate = (greenProgress, connected) {
      safeSetState(() {
        _farmGreenProgress = greenProgress;
        _connectedChannels = connected;
      });
    };

    game.onHarvestComplete = (result, tip) {
      safeSetState(() {
        _harvestResult  = result;
        _educationalTip = tip;
        _showHarvestResult = true;
      });
    };

    game.onIrrigationTick = (timeLeft) {
      safeSetState(() => _irrigationTimeLeft = timeLeft);
    };

    // Timer tick — fires every frame from _updatePhase1Timer
    game.onTimerTick = (timeLeft) {
      safeSetState(() => _collectionTimeLeft = timeLeft);
    };

    // Collection update (health + collected count) — fires from collectFloatingWaste
    game.onCollectionUpdate = (score, health, collected) {
      safeSetState(() {
        _boatHealth = health;
        wasteCollected = collected;
      });
    };

    // Obstacle hit — fires from _handleObstacleHit inside update loop
    game.onObstacleHit = (obstacle, damage) {
      safeSetState(() {
        _lastObstacleMessage = {
          'crocodile': '🐊 Crocodile! −${damage.round()} HP',
          'whirlpool': '🌀 Whirlpool! Steering impaired',
          'logjam': '🪵 Log Jam! −${damage.round()} HP',
        }[obstacle] ?? '⚠ Obstacle!';
      });
      // Auto-dismiss after 2 s using a plain dart:async Timer (no setState risk)
      _obstacleMessageTimer?.cancel();
      _obstacleMessageTimer = Timer(const Duration(seconds: 2), () {
        safeSetState(() => _lastObstacleMessage = null);
      });
    };

    // Net state — fires from RowingBoatComponent.castNet() / net retract
    game.onNetStateChanged = (isDeployed, cooldownFraction) {
      if (isDeployed) {
        safeSetState(() {
          _netOnCooldown = false;
          _netCooldownFraction = 0.0;
        });
        return;
      }
      // Net finished retracting — start cooldown ticker
      if (cooldownFraction >= 1.0) {
        safeSetState(() {
          _netOnCooldown = true;
          _netCooldownFraction = 1.0;
        });
        _netCooldownTimer?.cancel();
        const int cooldownMs = 2000;
        const int tickMs = 100;
        int elapsed = 0;
        _netCooldownTimer =
            Timer.periodic(const Duration(milliseconds: tickMs), (t) {
          elapsed += tickMs;
          final double frac =
              (1.0 - elapsed / cooldownMs).clamp(0.0, 1.0);
          safeSetState(() => _netCooldownFraction = frac);
          if (elapsed >= cooldownMs) {
            t.cancel();
            safeSetState(() => _netOnCooldown = false);
          }
        });
      }
    };

    // Phase 1 failure — boat sunk after 9 crocodile attacks (retry required, cannot proceed)
    game.onPhase1Failed = () {
      safeSetState(() {
        _phase1Failed = true;
        _failReason =
            '🐊 Your boat was sunk after ${game.crocodileAttackCount} crocodile attacks!\n'
            '${game.wasteCollectedCount}/${game.totalSpawnedWaste} items collected.';
      });
    };

    // Phase 1 time lapse — timer ran out before all waste collected.
    // Just flag it — the onPhase1Complete overlay will show the details.
    game.onPhase1TimeUp = (int collected, int total) {
      safeSetState(() => _phase1WasTimeUp = true);
    };

    // Phase 1 complete — fires for BOTH all-collected and time-lapsed paths.
    // Shows results panel; player must tap "Proceed to Sorting" to advance.
    game.onPhase1Complete = () {
      safeSetState(() => _phase1CompleteShown = true);
    };
  }

  @override
  void dispose() {
    _netCooldownTimer?.cancel();
    _obstacleMessageTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Stack(
          children: [
            // Main game view
            if (currentPhase == 1 || currentPhase == 2 || currentPhase == 3 || currentPhase == 4)
              SizedBox.expand(
                child: GameWidget(game: game),
              ),
            
            // UI Overlays
            if (currentPhase == 0) _buildIntroScreen(),
            if (currentPhase == 1) _buildCollectionOverlay(),
            if (currentPhase == 2) _buildSortingInterface(),
            if (currentPhase == 3) _buildTreatmentOverlay(),
            if (currentPhase == 4) _buildAgricultureInterface(),
            if (currentPhase == 5) _buildCompletionScreen(),

            // Phase 1 failure overlay (boat sunk after 9 croc attacks — retry required)
            if (currentPhase == 1 && _phase1Failed) _buildPhase1FailedOverlay(),

            // Phase 1 results panel (time-up OR success — user must tap to proceed)
            if (currentPhase == 1 && _phase1CompleteShown) _buildPhase1CompleteOverlay(),

            // Phase transition overlay
            if (_showPhaseTransition) _buildPhaseTransition(),
          ],
        ),
      ),
    );
  }


  Widget _buildIntroScreen() {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;
    final isTablet = size.width >= 600 && size.width < 1024;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF1E3A5F),
            const Color(0xFF0F2235),
          ],
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.all(isMobile ? 16 : isTablet ? 20 : 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(height: isLandscape && isMobile ? 10 : 20),
              
              Icon(
                Icons.water_drop,
                size: isMobile ? 60 : isTablet ? 70 : 80,
                color: Colors.cyan,
              ),
              SizedBox(height: isMobile ? 16 : 24),
              Text(
                'WATER POLLUTION CHALLENGE',
                style: GoogleFonts.exo2(
                  fontSize: isMobile ? 24 : isTablet ? 28 : 32,
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
                textAlign: TextAlign.center,
              ),
              
              SizedBox(height: isMobile ? 12 : 16),
              
              Container(
                padding: EdgeInsets.all(isMobile ? 16 : 20),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.cyan, width: 2),
                ),
                child: Column(
                  children: [
                    _buildMissionItem(
                      '🚤 Phase 1: Navigate speedboat and collect floating waste',
                      isMobile,
                    ),
                    _buildMissionItem(
                      '♻️ Phase 2: Sort waste into recycling bins',
                      isMobile,
                    ),
                    _buildMissionItem(
                      '🦠 Phase 3: Apply bacteria to purify water',
                      isMobile,
                    ),
                    _buildMissionItem(
                      '🌾 Phase 4: Use clean water for sustainable irrigation',
                      isMobile,
                    ),
                  ],
                ),
              ),
              
              SizedBox(height: isMobile ? 16 : 24),
              
              Container(
                padding: EdgeInsets.all(isMobile ? 12 : 16),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green, width: 2),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.science,
                      color: Colors.green,
                      size: isMobile ? 24 : 32,
                    ),
                    SizedBox(width: isMobile ? 8 : 12),
                    Expanded(
                      child: Text(
                        'Bacteria cultures available: ${widget.bacteriaCulturesAvailable}',
                        style: GoogleFonts.exo2(
                          fontSize: isMobile ? 14 : 16,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              SizedBox(height: isMobile ? 20 : 32),
              
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    currentPhase = 1;
                  });
                  game.startPhase1();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyan,
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 32 : 48,
                    vertical: isMobile ? 12 : 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'START MISSION',
                  style: GoogleFonts.exo2(
                    fontSize: isMobile ? 16 : 20,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                  ),
                ),
              ),
              
              SizedBox(height: isLandscape && isMobile ? 10 : 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMissionItem(String text, bool isMobile) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: isMobile ? 6 : 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.check_circle,
            color: Colors.cyan,
            size: isMobile ? 16 : 20,
          ),
          SizedBox(width: isMobile ? 8 : 12),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.exo2(
                fontSize: isMobile ? 12 : 14,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Phase 1 failure overlay — boat sunk after 9 croc attacks (retry only) ──

  Widget _buildPhase1FailedOverlay() {
    final isMobile = MediaQuery.of(context).size.width < 600;
    return Container(
      color: Colors.black.withValues(alpha: 0.78),
      child: Center(
        child: Container(
          margin: EdgeInsets.all(isMobile ? 24 : 48),
          padding: EdgeInsets.all(isMobile ? 24 : 36),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.red.shade900.withValues(alpha: 0.95),
                Colors.black.withValues(alpha: 0.95),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.red.shade400, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: Colors.red.withValues(alpha: 0.4),
                blurRadius: 30,
                spreadRadius: 6,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '🚤 BOAT SUNK!',
                style: GoogleFonts.exo2(
                  fontSize: isMobile ? 26 : 34,
                  fontWeight: FontWeight.w900,
                  color: Colors.red.shade300,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _failReason,
                style: GoogleFonts.exo2(
                  fontSize: isMobile ? 14 : 16,
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'A sunken boat cannot carry waste to the sorter.\nYou must retry the collection phase.',
                style: GoogleFonts.exo2(
                  fontSize: isMobile ? 12 : 14,
                  color: Colors.white54,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _phase1Failed = false;
                        _failReason = '';
                        wasteCollected = 0;
                        _boatHealth = 100.0;
                        _collectionTimeLeft = 180.0;
                      });
                      game.retryPhase1();
                    },
                    icon: const Icon(Icons.replay_rounded, color: Colors.black),
                    label: Text(
                      'TRY AGAIN',
                      style: GoogleFonts.exo2(
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                        fontSize: isMobile ? 14 : 16,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 20 : 28,
                        vertical: isMobile ? 12 : 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Phase 1 results panel — shown for BOTH success and time-up paths ─────
  // User MUST tap "PROCEED TO SORTING" — no auto-advance.

  Widget _buildPhase1CompleteOverlay() {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final bool wasTimeUp = _phase1WasTimeUp;

    // Compute waste breakdown from what's actually in collectedWaste list
    final breakdown = <String, int>{};
    for (final w in game.collectedWaste) {
      breakdown[w.type] = (breakdown[w.type] ?? 0) + 1;
    }
    const wasteDisplay = {
      'plastic_bottle': ('🔵', 'Plastic Bottles'),
      'bag':            ('🛍', 'Plastic Bags'),
      'can':            ('⚙',  'Metal Cans'),
      'metal_scrap':    ('🔩', 'Metal Scrap'),
      'oil_slick':      ('⚠',  'Oil Slicks'),
      'wood':           ('🌿', 'Organic Wood'),
    };

    final int collected  = game.wasteCollectedCount;
    final int total      = game.totalSpawnedWaste > 0
        ? game.totalSpawnedWaste : WaterPollutionGame.totalWasteToCollect;
    final int score      = game.sessionScore;
    final int timeLeft   = game.collectionTimeRemaining.toInt().clamp(0, 999);
    final int crocHits   = game.crocodileAttackCount;
    final double health  = (game.boatHealth / 150.0 * 100).clamp(0, 100);

    // Colours / heading differ by outcome
    final Color accentColor  = wasTimeUp ? Colors.amber        : const Color(0xFF00E5A0);
    final Color borderColor  = wasTimeUp ? Colors.amber.shade600: const Color(0xFF00E5A0);
    final String headingEmoji= wasTimeUp ? '⏰'               : '🎉';
    final String headingText = wasTimeUp ? 'TIME\'S UP!'       : 'RIVER CLEARED!';
    final String subText     = wasTimeUp
        ? 'You collected $collected of $total items before time ran out.\nYour haul heads to the sorting facility!'
        : 'You collected all $collected waste items with ${timeLeft}s to spare!\nFantastic river cleanup!';

    return Container(
      color: Colors.black.withValues(alpha: 0.88),
      child: Center(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.all(isMobile ? 16 : 28),
          child: Container(
            padding: EdgeInsets.all(isMobile ? 20 : 30),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF0D1F33).withValues(alpha: 0.98),
                  Colors.black.withValues(alpha: 0.98),
                ],
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: borderColor, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.30),
                  blurRadius: 32, spreadRadius: 4,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [

                // ── Heading ─────────────────────────────────────────────
                Text(
                  '$headingEmoji $headingText',
                  style: GoogleFonts.exo2(
                    fontSize: isMobile ? 24 : 30,
                    fontWeight: FontWeight.w900,
                    color: accentColor,
                    letterSpacing: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: isMobile ? 8 : 10),
                Text(
                  subText,
                  style: GoogleFonts.exo2(
                    fontSize: isMobile ? 12 : 13,
                    color: Colors.white60,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),

                SizedBox(height: isMobile ? 16 : 20),

                // ── Collection summary row ───────────────────────────────
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 12 : 16, vertical: isMobile ? 10 : 12),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: accentColor.withValues(alpha: 0.35), width: 1.5),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _phase1Stat('$collected/$total', 'COLLECTED',
                          accentColor, isMobile),
                      _phase1StatDivider(),
                      _phase1Stat('$score pts', 'SCORE',
                          Colors.amber, isMobile),
                      _phase1StatDivider(),
                      _phase1Stat('${health.toInt()}%', 'HULL',
                          health > 66 ? Colors.green
                          : health > 33 ? Colors.orange : Colors.red,
                          isMobile),
                      if (!wasTimeUp) ...[
                        _phase1StatDivider(),
                        _phase1Stat('${timeLeft}s', 'REMAINING',
                            Colors.cyan, isMobile),
                      ],
                      if (crocHits > 0) ...[
                        _phase1StatDivider(),
                        _phase1Stat('$crocHits/9', 'CROC HITS',
                            Colors.red.shade300, isMobile),
                      ],
                    ],
                  ),
                ),

                SizedBox(height: isMobile ? 14 : 18),

                // ── Waste breakdown by category ──────────────────────────
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '♻  HAUL BREAKDOWN',
                    style: GoogleFonts.exo2(
                      fontSize: isMobile ? 10 : 11,
                      color: Colors.white38,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.6,
                    ),
                  ),
                ),
                SizedBox(height: isMobile ? 8 : 10),

                if (breakdown.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'No waste items collected this run.',
                      style: GoogleFonts.exo2(
                          fontSize: isMobile ? 12 : 13,
                          color: Colors.white38),
                    ),
                  )
                else
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: Column(
                      children: breakdown.entries.map((entry) {
                        final display = wasteDisplay[entry.key];
                        final emoji  = display?.$1 ?? '📦';
                        final label  = display?.$2 ?? entry.key;
                        // Pick a colour per category
                        final Color catColor = _wasteTypeColor(entry.key);
                        return _breakdownRow(
                          emoji, label, entry.value, catColor, isMobile,
                          isLast: entry.key == breakdown.keys.last,
                        );
                      }).toList(),
                    ),
                  ),

                SizedBox(height: isMobile ? 22 : 28),

                // ── Proceed button ───────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _phase1CompleteShown = false;
                        _phase1WasTimeUp     = false;
                      });
                      game.proceedFromPhase1();
                    },
                    icon: const Icon(Icons.recycling_rounded,
                        color: Colors.black),
                    label: Text(
                      'PROCEED TO SORTING',
                      style: GoogleFonts.exo2(
                        fontSize: isMobile ? 14 : 16,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                        letterSpacing: 0.8,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      padding: EdgeInsets.symmetric(
                          vertical: isMobile ? 13 : 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                  ),
                ),

              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Phase 1 overlay helpers ───────────────────────────────────────────────

  Widget _phase1Stat(String value, String label, Color color, bool isMobile) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value,
            style: GoogleFonts.exo2(
              fontSize: isMobile ? 15 : 18,
              fontWeight: FontWeight.w900,
              color: color,
              height: 1.0,
            )),
        const SizedBox(height: 2),
        Text(label,
            style: GoogleFonts.exo2(
              fontSize: 8,
              color: color.withValues(alpha: 0.65),
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            )),
      ],
    );
  }

  Widget _phase1StatDivider() =>
      Container(width: 1, height: 28, color: Colors.white12);

  Widget _breakdownRow(String emoji, String label, int count,
      Color color, bool isMobile, {bool isLast = false}) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 12 : 16, vertical: isMobile ? 8 : 10),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        children: [
          Text(emoji, style: TextStyle(fontSize: isMobile ? 14 : 16)),
          SizedBox(width: isMobile ? 8 : 10),
          Expanded(
            child: Text(label,
                style: GoogleFonts.exo2(
                  fontSize: isMobile ? 12 : 13,
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
                )),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withValues(alpha: 0.35)),
            ),
            child: Text(
              '$count item${count == 1 ? "" : "s"}',
              style: GoogleFonts.exo2(
                fontSize: isMobile ? 11 : 12,
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _wasteTypeColor(String type) {
    switch (type) {
      case 'plastic_bottle':
      case 'bag':
        return const Color(0xFF4FC3F7); // blue
      case 'can':
      case 'metal_scrap':
        return const Color(0xFFB0BEC5); // grey-silver
      case 'oil_slick':
        return const Color(0xFFFF5252); // red
      case 'wood':
        return const Color(0xFF69F0AE); // green
      default:
        return Colors.white54;
    }
  }

  Widget _buildCollectionOverlay() {
    final bool isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 600;

    // Timer
    final int timeLeft = _collectionTimeLeft.toInt().clamp(0, 9999);
    final String timerLabel =
        '${(timeLeft ~/ 60).toString().padLeft(2, '0')}:${(timeLeft % 60).toString().padLeft(2, '0')}';
    final bool timerWarning = _collectionTimeLeft < 30;
    final double healthFraction = (_boatHealth / 100.0).clamp(0.0, 1.0);
    final Color healthColor = healthFraction > 0.6
        ? Colors.green
        : healthFraction > 0.3 ? Colors.orange : Colors.red;
    final bool netDeployed = game.rowingBoat?.netDeployed ?? false;

    return Stack(
      children: [
        // ── SLIM TOP HUD ──────────────────────────────────────────────────
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Container(
              margin: EdgeInsets.fromLTRB(
                isMobile ? 8 : 12, isMobile ? 6 : 8, isMobile ? 8 : 12, 0),
              padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 10 : 14, vertical: isMobile ? 5 : 7),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: Colors.cyan.withValues(alpha: 0.5), width: 1.5),
              ),
              child: Row(
                children: [
                  // Timer
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: timerWarning
                          ? Colors.red.withValues(alpha: 0.28)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.timer,
                          size: 14,
                          color: timerWarning ? Colors.red : Colors.cyan),
                      const SizedBox(width: 4),
                      Text(timerLabel,
                          style: GoogleFonts.exo2(
                            fontSize: isMobile ? 15 : 17,
                            fontWeight: FontWeight.w900,
                            color: timerWarning ? Colors.red : Colors.white,
                          )),
                    ]),
                  ),

                  const SizedBox(width: 8),

                  // Waste count
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    const Text('♻', style: TextStyle(fontSize: 13)),
                    const SizedBox(width: 3),
                    Text(
                      '$wasteCollected/${game.totalSpawnedWaste > 0 ? game.totalSpawnedWaste : totalWasteItems}',
                      style: GoogleFonts.exo2(
                          fontSize: isMobile ? 13 : 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white),
                    ),
                  ]),

                  const Spacer(),

                  // Boat health bar
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.directions_boat_filled,
                        color: healthColor, size: 14),
                    const SizedBox(width: 5),
                    SizedBox(
                      width: isMobile ? 56 : 90,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: healthFraction,
                          backgroundColor: Colors.white24,
                          valueColor: AlwaysStoppedAnimation(healthColor),
                          minHeight: isMobile ? 7 : 10,
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    // Crocodile attack counter — shows remaining lives (boat sinks at 9 attacks)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: game.crocodileAttackCount >= 7
                            ? Colors.red.withValues(alpha: 0.30)
                            : Colors.black38,
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                          color: game.crocodileAttackCount >= 7
                              ? Colors.red
                              : Colors.white30,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        '🐊 ${game.crocodileAttackCount}/9',
                        style: GoogleFonts.exo2(
                          fontSize: isMobile ? 9 : 10,
                          fontWeight: FontWeight.w700,
                          color: game.crocodileAttackCount >= 7
                              ? Colors.red.shade300
                              : Colors.white70,
                        ),
                      ),
                    ),
                  ]),

                  const SizedBox(width: 8),

                  // Net status pill
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: netDeployed
                          ? Colors.amber.withValues(alpha: 0.25)
                          : _netOnCooldown
                              ? Colors.orange.withValues(alpha: 0.2)
                              : Colors.grey.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: netDeployed
                            ? Colors.amber
                            : _netOnCooldown
                                ? Colors.orange
                                : Colors.grey,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      netDeployed
                          ? '🎣 ON'
                          : _netOnCooldown ? '⏳ …' : '🎣 RDY',
                      style: GoogleFonts.exo2(
                          fontSize: isMobile ? 9 : 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.white),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // ℹ️ Controls guide button
                  GestureDetector(
                    onTap: () => _showControlsGuide(context, isMobile),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Colors.cyan.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.cyan, width: 1.5),
                      ),
                      child: const Icon(Icons.info_outline,
                          color: Colors.cyan, size: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Obstacle danger banner
        if (_lastObstacleMessage != null)
          Positioned(
            top: isMobile ? 52 : 64,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.red.shade900.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.red.withValues(alpha: 0.45),
                        blurRadius: 16,
                        spreadRadius: 2),
                  ],
                ),
                child: Text(
                  _lastObstacleMessage!,
                  style: GoogleFonts.exo2(
                      fontSize: isMobile ? 12 : 14,
                      color: Colors.white,
                      fontWeight: FontWeight.w800),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),

        // "Timer starts on first move" hint
        if (!game.playerHasStarted)
          Positioned(
            bottom: isMobile
                ? (isLandscape ? 90 : 120)
                : 60,
            left: 0,
            right: 0,
            child: Center(
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: Colors.cyan.withValues(alpha: 0.5), width: 1.5),
                  ),
                  child: Text(
                    isMobile
                        ? 'Use D-pad to row • Tap Net to collect • Timer starts on first move'
                        : 'WASD / Arrows to row  •  SPACE to cast net  •  Timer starts on first move',
                    style: GoogleFonts.exo2(
                      fontSize: isMobile ? 11 : 13,
                      color: Colors.cyan.shade200,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),

        // D-PAD ARROW CONTROLS (mobile only, bottom-left)
        if (isMobile)
          Positioned(
            left: 14,
            bottom: isLandscape ? 10 : 18,
            child: _buildDpad(),
          ),

        // NET CAST BUTTON (mobile, bottom-right)
        if (isMobile)
          Positioned(
            right: 18,
            bottom: isLandscape ? 18 : 28,
            child: GestureDetector(
              onTap: () => game.rowingBoat?.castNet(),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                CustomPaint(
                  size: const Size(62, 62),
                  painter: NetCastButtonPainter(
                    isActive: !(game.rowingBoat?.netDeployed ?? false),
                    cooldownFraction: _netCooldownFraction,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _netOnCooldown ? 'Reload…' : 'Cast Net',
                  style: GoogleFonts.exo2(
                      fontSize: 10,
                      color: Colors.white70,
                      fontWeight: FontWeight.w600),
                ),
              ]),
            ),
          ),
      ],
    );
  }
  // ── D-Pad arrow buttons ───────────────────────────────────────────────────

  Widget _buildDpad() {
    const btnSize = 54.0;
    const gap = 4.0;

    return Column(mainAxisSize: MainAxisSize.min, children: [
      // Up (forward)
      _dpadBtn(Icons.keyboard_arrow_up_rounded, LogicalKeyboardKey.arrowUp,
          btnSize, 'FWD'),
      SizedBox(height: gap),
      Row(mainAxisSize: MainAxisSize.min, children: [
        // Left (turn left)
        _dpadBtn(Icons.keyboard_arrow_left_rounded,
            LogicalKeyboardKey.arrowLeft, btnSize, 'L'),
        SizedBox(width: gap),
        SizedBox(width: btnSize, height: btnSize), // centre gap
        SizedBox(width: gap),
        // Right (turn right)
        _dpadBtn(Icons.keyboard_arrow_right_rounded,
            LogicalKeyboardKey.arrowRight, btnSize, 'R'),
      ]),
      SizedBox(height: gap),
      // Down (reverse)
      _dpadBtn(Icons.keyboard_arrow_down_rounded,
          LogicalKeyboardKey.arrowDown, btnSize, 'REV'),
    ]);
  }

  Widget _dpadBtn(
      IconData icon, LogicalKeyboardKey key, double size, String label) {
    return GestureDetector(
      onTapDown: (_) => game.rowingBoat?.pressKey(key),
      onTapUp: (_) => game.rowingBoat?.releaseKey(key),
      onTapCancel: () => game.rowingBoat?.releaseKey(key),
      onLongPressStart: (_) => game.rowingBoat?.pressKey(key),
      onLongPressEnd: (_) => game.rowingBoat?.releaseKey(key),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.58),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: Colors.cyan.withValues(alpha: 0.65), width: 1.5),
          boxShadow: [
            BoxShadow(
                color: Colors.cyan.withValues(alpha: 0.18), blurRadius: 8),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.cyan, size: size * 0.52),
            Text(label,
                style: GoogleFonts.exo2(
                    fontSize: 8,
                    color: Colors.white60,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  // ── Controls guide dialog ─────────────────────────────────────────────────

  void _showControlsGuide(BuildContext ctx, bool isMobile) {
    showDialog<void>(
      context: ctx,
      builder: (_) => Dialog(
        backgroundColor: const Color(0xFF0D1F33),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.sports_esports,
                    color: Colors.cyan, size: 22),
                const SizedBox(width: 8),
                Text('Controls Guide',
                    style: GoogleFonts.exo2(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: Colors.cyan)),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: const Icon(Icons.close,
                      color: Colors.white54, size: 22),
                ),
              ]),
              const Divider(color: Colors.white12, height: 24),
              _guideSection('🚤 Rowing', [
                if (isMobile) ...[
                  '▲ Up arrow — row forward',
                  '▼ Down arrow — reverse',
                  '◀ Left arrow — turn left',
                  '▶ Right arrow — turn right',
                ] else ...[
                  'W / ↑  —  row forward',
                  'S / ↓  —  reverse',
                  'A / ←  —  turn left',
                  'D / →  —  turn right',
                ],
              ]),
              const SizedBox(height: 12),
              _guideSection('🎣 Net / Scare', [
                if (isMobile)
                  'Tap the Cast Net button (bottom-right)'
                else
                  'SPACE  —  cast net / scare crocodiles',
              ]),
              const SizedBox(height: 12),
              _guideSection('⚠️ Hazards', [
                '🐊 Crocodile — cast net nearby to scare away',
                '🌀 Whirlpool — steer away to avoid spin lock',
                '🪵 Log jam — dodge to avoid hull damage',
              ]),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyan,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text('Got it!',
                      style: GoogleFonts.exo2(
                          fontWeight: FontWeight.w900,
                          color: Colors.black,
                          fontSize: 14)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _guideSection(String title, List<String> items) {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: GoogleFonts.exo2(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Colors.white)),
          const SizedBox(height: 5),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(left: 10, bottom: 3),
                child: Text(item,
                    style: GoogleFonts.exo2(
                        fontSize: 12, color: Colors.white70)),
              )),
        ]);
  }

  // ── Sorting phase palette constants ─────────────────────────────────────
  static const Color _sortAccent  = Color(0xFF00E5A0); // neon mint
  static const Color _sortWarning = Color(0xFFFF6B35); // coral-orange
  static const Color _sortPanel   = Color(0xFF0D1F18); // deep eco-green dark

  Widget _buildSortingInterface() {
    final size    = MediaQuery.of(context).size;
    final isMobile = size.width < 600;

    // SYNC GAME CANVAS SIZE WITH SCREEN SIZE
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (game.size.x != size.width || game.size.y != size.height) {
        game.onGameResize(size.toVector2());
      }
    });

    final int total    = game.collectedWaste.length + itemsSorted;
    final double prog  = total > 0 ? (itemsSorted / total).clamp(0.0, 1.0) : 0.0;
    final int remaining = game.collectedWaste.length;
    final bool nearDone = remaining <= 3 && total > 0;

    // Accuracy colour ramp
    final Color accColor = sortingAccuracy >= 80
        ? _sortAccent
        : sortingAccuracy >= 60
            ? Colors.amber
            : _sortWarning;

    return Stack(
      children: [
        // ── TOP HUD PANEL ─────────────────────────────────────────────────
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                isMobile ? 10 : 14,
                isMobile ? 8  : 10,
                isMobile ? 10 : 14,
                0,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(isMobile ? 14 : 18),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        _sortPanel.withValues(alpha: 0.96),
                        const Color(0xFF0A1A24).withValues(alpha: 0.96),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(isMobile ? 14 : 18),
                    border: Border.all(
                      color: _sortAccent.withValues(alpha: 0.35),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _sortAccent.withValues(alpha: 0.12),
                        blurRadius: 20,
                        spreadRadius: -2,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 12 : 18,
                      vertical:   isMobile ? 10 : 13,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // ── Row 1: phase label | remaining pill ──────────
                        Row(
                          children: [
                            // Phase label with dot
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: _sortAccent,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: _sortAccent.withValues(alpha: 0.8),
                                    blurRadius: 6,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 7),
                            Text(
                              'PHASE 2  ·  WASTE SORTING',
                              style: GoogleFonts.exo2(
                                fontSize: isMobile ? 11 : 12,
                                color: _sortAccent,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.6,
                              ),
                            ),
                            const Spacer(),
                            // Remaining items pill
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              padding: EdgeInsets.symmetric(
                                horizontal: isMobile ? 8 : 10,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: nearDone
                                    ? _sortAccent.withValues(alpha: 0.22)
                                    : Colors.white.withValues(alpha: 0.07),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: nearDone
                                      ? _sortAccent.withValues(alpha: 0.7)
                                      : Colors.white24,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.inventory_2_outlined,
                                    size: isMobile ? 11 : 12,
                                    color: nearDone ? _sortAccent : Colors.white60,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$remaining left',
                                    style: GoogleFonts.exo2(
                                      fontSize: isMobile ? 10 : 11,
                                      color: nearDone ? _sortAccent : Colors.white60,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Sorting countdown timer (appears on first sort)
                            if (_sortingTimerActive) ...[
                              const SizedBox(width: 6),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: _sortingTimeLeft < 15
                                      ? Colors.red.withValues(alpha: 0.22)
                                      : Colors.white.withValues(alpha: 0.07),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: _sortingTimeLeft < 15
                                        ? Colors.red
                                        : Colors.white24,
                                  ),
                                ),
                                child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.timer,
                                        color: _sortingTimeLeft < 15
                                            ? Colors.red : Colors.white54,
                                        size: isMobile ? 11 : 12),
                                      const SizedBox(width: 3),
                                      Text('${_sortingTimeLeft.toInt()}s',
                                        style: GoogleFonts.exo2(
                                          fontSize: isMobile ? 10 : 11,
                                          color: _sortingTimeLeft < 15
                                              ? Colors.red : Colors.white,
                                          fontWeight: FontWeight.w900)),
                                    ]),
                              ),
                            ],
                          ],
                        ),

                        SizedBox(height: isMobile ? 9 : 11),

                        // ── Row 2: stat chips ─────────────────────────────
                        Row(
                          children: [
                            // Accuracy chip
                            _sortStatChip(
                              icon: Icons.track_changes_rounded,
                              label: 'ACCURACY',
                              value: '$sortingAccuracy%',
                              color: accColor,
                              isMobile: isMobile,
                            ),
                            SizedBox(width: isMobile ? 6 : 10),
                            // Correct chip
                            _sortStatChip(
                              icon: Icons.check_circle_outline_rounded,
                              label: 'CORRECT',
                              value: '$sortedCorrectly',
                              color: _sortAccent,
                              isMobile: isMobile,
                            ),
                            SizedBox(width: isMobile ? 6 : 10),
                            // Wrong chip (only appears after first mistake)
                            if (sortedIncorrectly > 0)
                              _sortStatChip(
                                icon: Icons.cancel_outlined,
                                label: 'WRONG',
                                value: '$sortedIncorrectly',
                                color: _sortWarning,
                                isMobile: isMobile,
                              ),
                            const Spacer(),
                            // Sorted / Total counter
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                RichText(
                                  text: TextSpan(
                                    children: [
                                      TextSpan(
                                        text: '$itemsSorted',
                                        style: GoogleFonts.exo2(
                                          fontSize: isMobile ? 20 : 24,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                        ),
                                      ),
                                      TextSpan(
                                        text: '/$total',
                                        style: GoogleFonts.exo2(
                                          fontSize: isMobile ? 13 : 15,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.white38,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  'SORTED',
                                  style: GoogleFonts.exo2(
                                    fontSize: 9,
                                    color: Colors.white38,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),

                        SizedBox(height: isMobile ? 8 : 10),

                        // ── Progress bar ──────────────────────────────────
                        Stack(
                          children: [
                            // Track
                            Container(
                              height: isMobile ? 5 : 6,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            // Fill
                            AnimatedFractionallySizedBox(
                              duration: const Duration(milliseconds: 400),
                              curve: Curves.easeOutCubic,
                              widthFactor: prog,
                              child: Container(
                                height: isMobile ? 5 : 6,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      _sortAccent,
                                      const Color(0xFF00BCD4),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _sortAccent.withValues(alpha: 0.55),
                                      blurRadius: 6,
                                      spreadRadius: -1,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        // ── SORTING TIME-UP BANNER ────────────────────────────────────────
        if (_sortingTimeUpShown)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.82),
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: isMobile ? 20 : 40),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('⏱ TIME\'S UP!', style: GoogleFonts.exo2(
                            fontSize: isMobile ? 28 : 36, color: Colors.amber,
                            fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                          SizedBox(height: isMobile ? 16 : 22),
                          Container(
                            padding: EdgeInsets.all(isMobile ? 16 : 20),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.07),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: Column(children: [
                              _timeUpRow('✅ Correctly Sorted', '$sortedCorrectly items', _sortAccent, isMobile),
                              SizedBox(height: isMobile ? 8 : 10),
                              _timeUpRow('❌ Incorrectly Sorted', '$sortedIncorrectly items', _sortWarning, isMobile),
                              SizedBox(height: isMobile ? 8 : 10),
                              _timeUpRow('📦 Unsorted (Carried)', '$_sortingUnsorted items', Colors.white54, isMobile),
                              SizedBox(height: isMobile ? 8 : 10),
                              _timeUpRow('🎯 Accuracy', '$sortingAccuracy%', Colors.amber, isMobile),
                            ]),
                          ),
                          SizedBox(height: isMobile ? 24 : 30),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                setState(() => _sortingTimeUpShown = false);
                                game.proceedFromSorting();
                              },
                              icon: const Icon(Icons.science_rounded, color: Colors.black),
                              label: Text(
                                'PROCEED TO TREATMENT',
                                style: GoogleFonts.exo2(
                                  fontSize: isMobile ? 14 : 16,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.black,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.amber,
                                padding: EdgeInsets.symmetric(vertical: isMobile ? 13 : 16),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

        // ── SORTING COMPLETE OVERLAY (all items sorted before timer) ─────
        if (_sortingCompleteShown)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.82),
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: isMobile ? 20 : 40),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('♻ SORTING COMPLETE!', style: GoogleFonts.exo2(
                            fontSize: isMobile ? 26 : 34, color: const Color(0xFF00E5A0),
                            fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                          SizedBox(height: isMobile ? 6 : 10),
                          Text(
                            'All waste sorted with ${_sortingCompleteTimeLeft.toInt()}s remaining',
                            style: GoogleFonts.exo2(
                              fontSize: isMobile ? 12 : 14,
                              color: Colors.white54,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: isMobile ? 16 : 22),
                          Container(
                            padding: EdgeInsets.all(isMobile ? 16 : 20),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.07),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: const Color(0xFF00E5A0).withValues(alpha: 0.35)),
                            ),
                            child: Column(children: [
                              _timeUpRow('✅ Correctly Sorted', '$_sortingCompleteCorrect items', _sortAccent, isMobile),
                              SizedBox(height: isMobile ? 8 : 10),
                              _timeUpRow('❌ Incorrectly Sorted', '$_sortingCompleteWrong items', _sortWarning, isMobile),
                              SizedBox(height: isMobile ? 8 : 10),
                              _timeUpRow('🎯 Accuracy', '$sortingAccuracy%', Colors.amber, isMobile),
                            ]),
                          ),
                          SizedBox(height: isMobile ? 24 : 30),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                setState(() => _sortingCompleteShown = false);
                                game.proceedFromSorting();
                              },
                              icon: const Icon(Icons.science_rounded, color: Colors.black),
                              label: Text(
                                'PROCEED TO TREATMENT',
                                style: GoogleFonts.exo2(
                                  fontSize: isMobile ? 14 : 16,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.black,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF00E5A0),
                                padding: EdgeInsets.symmetric(vertical: isMobile ? 13 : 16),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

        // ── CATEGORY LEGEND BAR (bottom of screen) ────────────────────────
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                isMobile ? 10 : 14,
                0,
                isMobile ? 10 : 14,
                isMobile ? 10 : 12,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(isMobile ? 12 : 14),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF060F14).withValues(alpha: 0.90),
                    borderRadius: BorderRadius.circular(isMobile ? 12 : 14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                      width: 1,
                    ),
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 10 : 16,
                    vertical: isMobile ? 8 : 10,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _sortCategoryChip('♻', 'PLASTIC',   const Color(0xFF4FC3F7), isMobile),
                      _sortCategoryChip('🔩', 'METAL',    const Color(0xFFB0BEC5), isMobile),
                      _sortCategoryChip('⚠', 'HAZARDOUS', const Color(0xFFFF5252), isMobile),
                      _sortCategoryChip('🌿', 'ORGANIC',  const Color(0xFF69F0AE), isMobile),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        // ── FIRST-SORT INSTRUCTION TOOLTIP (shown only before first item sorted) ─
        if (itemsSorted == 0)
              Positioned(
                top: isMobile ? size.height * 0.13 : size.height * 0.12,
                left: isMobile ? 16 : size.width * 0.15,
                right: isMobile ? 16 : size.width * 0.15,
                child: IgnorePointer(
                  child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 14 : 18,
                  vertical:   isMobile ? 10 : 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D2418).withValues(alpha: 0.93),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _sortAccent.withValues(alpha: 0.45),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.45),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: _sortAccent.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _sortAccent.withValues(alpha: 0.5),
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        Icons.touch_app_rounded,
                        color: _sortAccent,
                        size: isMobile ? 16 : 18,
                      ),
                    ),
                    SizedBox(width: isMobile ? 10 : 12),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isMobile ? 'TAP item  →  TAP bin' : 'TAP item  ·  then TAP the correct bin',
                            style: GoogleFonts.exo2(
                              fontSize: isMobile ? 12 : 13,
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Or drag the item directly into a bin',
                            style: GoogleFonts.exo2(
                              fontSize: isMobile ? 10 : 11,
                              color: Colors.white54,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ── Sorting HUD helpers ───────────────────────────────────────────────────

  Widget _sortStatChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required bool isMobile,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 8 : 11,
        vertical:   isMobile ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: isMobile ? 11 : 13),
          SizedBox(width: isMobile ? 4 : 5),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: GoogleFonts.exo2(
                  fontSize: isMobile ? 13 : 15,
                  color: color,
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                ),
              ),
              Text(
                label,
                style: GoogleFonts.exo2(
                  fontSize: 8,
                  color: color.withValues(alpha: 0.65),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sortCategoryChip(String emoji, String label, Color color, bool isMobile) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(emoji, style: TextStyle(fontSize: isMobile ? 13 : 15)),
        SizedBox(width: isMobile ? 4 : 5),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.exo2(
                fontSize: isMobile ? 9 : 10,
                color: color,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            Container(
              width: isMobile ? 28 : 36,
              height: 2,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ],
    );
  }



  // Update _buildTreatmentOverlay method
  Widget _buildTreatmentOverlay() {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;
    
    return Stack(
      children: [
        // REDUCED HEIGHT - Top stats panel (now more compact)
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Container(
              margin: EdgeInsets.all(isMobile ? 8 : 12), // Reduced margin
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 12 : 16,
                vertical: isMobile ? 8 : 10, // Reduced vertical padding
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withValues(alpha: 0.85),
                    Colors.black.withValues(alpha: 0.7),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withValues(alpha: 0.3),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Single row with all key info
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Title
                      Expanded(
                        flex: 3,
                        child: Text(
                          'BACTERIAL TREATMENT',
                          style: GoogleFonts.exo2(
                            fontSize: isMobile ? 12 : 14,
                            color: Colors.green,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                      
                      // Bacteria counter
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isMobile ? 8 : 10,
                          vertical: isMobile ? 4 : 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.green, width: 1.5),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.science,
                              size: isMobile ? 14 : 16,
                              color: Colors.green,
                            ),
                            SizedBox(width: 4),
                            Text(
                              '${game.bacteriaRemaining}',
                              style: GoogleFonts.exo2(
                                fontSize: isMobile ? 14 : 16,
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  SizedBox(height: 8),
                  
                  // Compact pollution meter only
                  Container(
                    height: isMobile ? 12 : 14, // Thinner progress bar
                    decoration: BoxDecoration(
                      color: Colors.grey.shade900,
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(
                        color: Colors.green.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                    ),
                    child: Stack(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.easeInOut,
                          width: (size.width - (isMobile ? 32 : 48)) *
                              (pollutionLevel / 100),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: pollutionLevel < 30
                                  ? [Colors.green, Colors.lightGreen]
                                  : pollutionLevel < 60
                                      ? [Colors.orange, Colors.amber]
                                      : [Colors.red, Colors.deepOrange],
                            ),
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: [
                              BoxShadow(
                                color: (pollutionLevel < 30
                                        ? Colors.green
                                        : pollutionLevel < 60
                                            ? Colors.orange
                                            : Colors.red)
                                    .withValues(alpha: 0.5),
                                blurRadius: 6,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                        
                        Center(
                          child: Text(
                            '${pollutionLevel.toInt()}% Polluted',
                            style: GoogleFonts.exo2(
                              fontSize: isMobile ? 9 : 10,
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withValues(alpha: 0.9),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  SizedBox(height: 6),
                  
                  // Compact instruction
                  Text(
                    'Tap polluted water to apply bacteria',
                    style: GoogleFonts.exo2(
                      fontSize: isMobile ? 9 : 10,
                      color: Colors.white60,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        
        // Treatment indicator (keep existing positioning)
        if (game.waterTiles.any((tile) => tile.isTreating))
          Positioned(
            top: size.height * 0.35,
            left: 0,
            right: 0,
            child: Center(
              child: TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 600),
                tween: Tween(begin: 0.0, end: 1.0),
                builder: (context, value, child) {
                        return Opacity(
                          opacity: (sin(value * pi * 2) + 1) / 2,
                          child: Container(
                          padding: EdgeInsets.symmetric(
                          horizontal: isMobile ? 16 : 20,
                          vertical: isMobile ? 8 : 10,
                        ),
                        decoration: BoxDecoration(
                        gradient: LinearGradient(
                        colors: [
                          Colors.green.withValues(alpha: 0.9),
                          Colors.lightGreen.withValues(alpha: 0.9),
                        ],
                      ),
                    borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                        color: Colors.green.withValues(alpha: 0.6),
                        blurRadius: 15,
                        spreadRadius: 3,
                      ),
                    ],
                  ),
                  child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                            width: isMobile ? 14 : 16,
                            height: isMobile ? 14 : 16,
                            child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        SizedBox(width: 10),
                        Text(
                            'TREATING...',
                            style: GoogleFonts.exo2(
                            fontSize: isMobile ? 12 : 14,
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  // ── Phase 4 palette ────────────────────────────────────────────────────
  static const Color _agAccent  = Color(0xFF4CAF50);
  static const Color _agAmber   = Color(0xFFFFA000);
  static const Color _agPanel   = Color(0xFF0D1F0D);

  Widget _buildAgricultureInterface() {
    final size     = MediaQuery.of(context).size;
    final isMobile = size.width < 600;

    // ── Show harvest result overlay ────────────────────────────────────────
    if (_showHarvestResult) return _buildHarvestResultOverlay(isMobile);

    // ── Step 1: Crop selection ─────────────────────────────────────────────
    if (!_cropSelected) return _buildCropSelectionScreen(size, isMobile);

    // ── Step 2: Method selection ───────────────────────────────────────────
    if (!_methodSelected) return _buildMethodSelectionScreen(size, isMobile);

    // ── Step 3: Active irrigation drawing ─────────────────────────────────
    return _buildActiveIrrigationOverlay(size, isMobile);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STEP 1 — Crop selection
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildCropSelectionScreen(Size size, bool isMobile) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0D2B0D), Color(0xFF062006)],
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.all(isMobile ? 16 : 24),
          child: Column(
            children: [
              SizedBox(height: isMobile ? 12 : 24),
              // Phase badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  color: _agAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _agAccent.withValues(alpha: 0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 6, height: 6,
                      decoration: BoxDecoration(color: _agAccent, shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: _agAccent, blurRadius: 4)])),
                    const SizedBox(width: 8),
                    Text('PHASE 4  ·  SUSTAINABLE FARMING',
                      style: GoogleFonts.exo2(fontSize: isMobile ? 10 : 11,
                        color: _agAccent, fontWeight: FontWeight.w700, letterSpacing: 1.4)),
                  ],
                ),
              ),
              SizedBox(height: isMobile ? 14 : 20),
              Text('Choose Your Crop',
                style: GoogleFonts.exo2(fontSize: isMobile ? 24 : 30,
                  color: Colors.white, fontWeight: FontWeight.w900)),
              SizedBox(height: isMobile ? 6 : 10),
              Text('The crop you select will determine the irrigation method needed for a bountiful harvest.',
                style: GoogleFonts.exo2(fontSize: isMobile ? 12 : 13,
                  color: Colors.white54, fontWeight: FontWeight.w500),
                textAlign: TextAlign.center),
              SizedBox(height: isMobile ? 20 : 28),
              // Crop cards
              ...['vegetables', 'maize', 'rice'].map((crop) =>
                  _buildCropCard(crop, isMobile)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCropCard(String crop, bool isMobile) {
    final data = _cropData[crop]!;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCrop   = crop;
          _cropSelected   = true;
        });
        game.selectedCrop = crop;
      },
      child: Container(
        margin: EdgeInsets.only(bottom: isMobile ? 12 : 16),
        padding: EdgeInsets.all(isMobile ? 14 : 18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              (data['color'] as Color).withValues(alpha: 0.18),
              (data['color'] as Color).withValues(alpha: 0.08),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: (data['color'] as Color).withValues(alpha: 0.4), width: 1.5),
          boxShadow: [BoxShadow(color: (data['color'] as Color).withValues(alpha: 0.12),
            blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            Container(
              width: isMobile ? 52 : 64, height: isMobile ? 52 : 64,
              decoration: BoxDecoration(
                color: (data['color'] as Color).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(child: Text(data['emoji'] as String,
                style: TextStyle(fontSize: isMobile ? 28 : 34))),
            ),
            SizedBox(width: isMobile ? 12 : 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(data['name'] as String,
                    style: GoogleFonts.exo2(fontSize: isMobile ? 16 : 18,
                      color: Colors.white, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(data['desc'] as String,
                    style: GoogleFonts.exo2(fontSize: isMobile ? 11 : 12,
                      color: Colors.white60, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: (data['color'] as Color).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('Ideal: ${data["ideal"] as String}',
                      style: GoogleFonts.exo2(fontSize: isMobile ? 10 : 11,
                        color: data['color'] as Color, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
              color: (data['color'] as Color).withValues(alpha: 0.6),
              size: isMobile ? 16 : 18),
          ],
        ),
      ),
    );
  }

  static const Map<String, Map<String, dynamic>> _cropData = {
    'vegetables': {
      'emoji': '🥦', 'name': 'Vegetables',
      'desc': 'Shallow-rooted crops needing precise, gentle watering.',
      'ideal': 'Drip Pipes',
      'color': Color(0xFF69F0AE),
    },
    'maize': {
      'emoji': '🌽', 'name': 'Maize',
      'desc': 'Deep-rooted row crop — tunnel furrows deliver water between rows.',
      'ideal': 'Furrow (2–4 tunnels)',
      'color': Color(0xFFFFD54F),
    },
    'rice': {
      'emoji': '🌾', 'name': 'Rice',
      'desc': 'Paddy crop — needs flooded fields with many furrows.',
      'ideal': 'Flood Furrows (5+)',
      'color': Color(0xFF4FC3F7),
    },
  };

  // ─────────────────────────────────────────────────────────────────────────
  // STEP 2 — Irrigation method selection
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildMethodSelectionScreen(Size size, bool isMobile) {
    final cropInfo = _cropData[_selectedCrop!]!;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0D2B0D), Color(0xFF062006)],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 16 : 24),
          child: Column(
            children: [
              SizedBox(height: isMobile ? 16 : 28),
              // Selected crop recap
              Container(
                padding: EdgeInsets.all(isMobile ? 12 : 16),
                decoration: BoxDecoration(
                  color: (cropInfo['color'] as Color).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: (cropInfo['color'] as Color).withValues(alpha: 0.35)),
                ),
                child: Row(
                  children: [
                    Text(cropInfo['emoji'] as String,
                      style: TextStyle(fontSize: isMobile ? 32 : 40)),
                    SizedBox(width: isMobile ? 12 : 16),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Growing: ${cropInfo["name"]}',
                          style: GoogleFonts.exo2(fontSize: isMobile ? 14 : 16,
                            color: Colors.white, fontWeight: FontWeight.w800)),
                        Text('Recommended: ${cropInfo["ideal"]}',
                          style: GoogleFonts.exo2(fontSize: isMobile ? 11 : 12,
                            color: cropInfo['color'] as Color,
                            fontWeight: FontWeight.w600)),
                      ],
                    )),
                  ],
                ),
              ),
              SizedBox(height: isMobile ? 20 : 32),
              Text('Choose Irrigation Method',
                style: GoogleFonts.exo2(fontSize: isMobile ? 20 : 26,
                  color: Colors.white, fontWeight: FontWeight.w900)),
              SizedBox(height: isMobile ? 8 : 12),
              Text('This is your choice — irrigation design affects the harvest!',
                style: GoogleFonts.exo2(fontSize: isMobile ? 11 : 13,
                  color: Colors.white54),
                textAlign: TextAlign.center),
              SizedBox(height: isMobile ? 20 : 28),
              // Method cards
              Expanded(
                child: Row(
                  children: [
                    Expanded(child: _buildMethodCard('furrow', '⛏', 'Furrow Digging',
                        'Dig channels across the farm\nfor tunnel or flood irrigation.',
                        const Color(0xFFCD853F), isMobile)),
                    SizedBox(width: isMobile ? 10 : 16),
                    Expanded(child: _buildMethodCard('pipe', '🔧', 'Pipe Network',
                        'Lay drip pipes for precise\nwater delivery to each plant.',
                        const Color(0xFF78909C), isMobile)),
                  ],
                ),
              ),
              SizedBox(height: isMobile ? 12 : 16),
              // Back button
              TextButton(
                onPressed: () => setState(() {
                  _cropSelected = false;
                  _selectedCrop = null;
                  game.selectedCrop = null;
                }),
                child: Text('← Change Crop',
                  style: GoogleFonts.exo2(color: Colors.white38,
                    fontSize: isMobile ? 12 : 13, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMethodCard(String method, String emoji, String title, String desc,
      Color color, bool isMobile) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _irrigationMethod = method;
          _methodSelected   = true;
        });
        game.irrigationMethod = method;
      },
      child: Container(
        padding: EdgeInsets.all(isMobile ? 14 : 18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [color.withValues(alpha: 0.20), color.withValues(alpha: 0.08)],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.45), width: 1.5),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.15),
            blurRadius: 16, offset: const Offset(0, 4))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: TextStyle(fontSize: isMobile ? 40 : 52)),
            SizedBox(height: isMobile ? 10 : 14),
            Text(title, style: GoogleFonts.exo2(fontSize: isMobile ? 14 : 16,
              color: Colors.white, fontWeight: FontWeight.w800),
              textAlign: TextAlign.center),
            SizedBox(height: isMobile ? 8 : 10),
            Text(desc, style: GoogleFonts.exo2(fontSize: isMobile ? 10 : 11,
              color: Colors.white60, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STEP 3 — Active irrigation drawing overlay
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildActiveIrrigationOverlay(Size size, bool isMobile) {
    final methodLabel  = _irrigationMethod == 'pipe' ? 'Laying pipes' : 'Digging furrows';
    final methodIcon   = _irrigationMethod == 'pipe' ? Icons.water : Icons.landscape;
    final methodColor  = _irrigationMethod == 'pipe'
        ? const Color(0xFF78909C) : const Color(0xFFCD853F);
    final cropInfo     = _cropData[_selectedCrop ?? 'maize']!;

    // Timer display
    final int tl = _irrigationTimeLeft.toInt().clamp(0, 999);
    final String timerStr =
        '${(tl ~/ 60).toString().padLeft(2, '0')}:${(tl % 60).toString().padLeft(2, '0')}';
    final bool timerWarn = _irrigationTimeLeft < 20;

    return Stack(
      children: [
        // ── Full-screen gesture detector for drawing ───────────────────────
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onPanStart: (d) => game.onFarmTapDown(
                Vector2(d.localPosition.dx, d.localPosition.dy)),
            onPanUpdate: (d) => game.onFarmDragUpdate(
                Vector2(d.localPosition.dx, d.localPosition.dy),
                Vector2(d.delta.dx, d.delta.dy)),
            onPanEnd: (d) {
              if (game.lastFurrowPoint != null) {
                game.onFarmDragEnd(game.lastFurrowPoint!.clone());
              }
            },
            onLongPressStart: (d) => _checkForFurrowContinuation(
                Vector2(d.localPosition.dx, d.localPosition.dy)),
          ),
        ),

        // ── TOP HUD ────────────────────────────────────────────────────────
        Positioned(
          top: 0, left: 0, right: 0,
          child: SafeArea(
            child: IgnorePointer(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  isMobile ? 10 : 14, isMobile ? 8 : 10, isMobile ? 10 : 14, 0),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 12 : 16, vertical: isMobile ? 9 : 11),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      _agPanel.withValues(alpha: 0.96),
                      const Color(0xFF0A1A0A).withValues(alpha: 0.96),
                    ]),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _agAccent.withValues(alpha: 0.30), width: 1.5),
                    boxShadow: [BoxShadow(
                      color: _agAccent.withValues(alpha: 0.10),
                      blurRadius: 16, offset: const Offset(0, 4))],
                  ),
                  child: Row(
                    children: [
                      // Crop badge
                      Text(cropInfo['emoji'] as String,
                        style: TextStyle(fontSize: isMobile ? 20 : 24)),
                      SizedBox(width: isMobile ? 7 : 10),
                      // Method indicator
                      Icon(methodIcon, color: methodColor, size: isMobile ? 14 : 16),
                      SizedBox(width: 4),
                      Text(methodLabel,
                        style: GoogleFonts.exo2(fontSize: isMobile ? 11 : 12,
                          color: methodColor, fontWeight: FontWeight.w700,
                          letterSpacing: 0.8)),
                      const Spacer(),
                      // Connected channels
                      _agHUDStat(
                        icon: Icons.water_drop_rounded,
                        value: '$_connectedChannels',
                        label: 'LINKED',
                        color: const Color(0xFF29B6F6),
                        isMobile: isMobile,
                      ),
                      SizedBox(width: isMobile ? 8 : 12),
                      // Farm green progress
                      _agHUDStat(
                        icon: Icons.eco_rounded,
                        value: '${(_farmGreenProgress * 100).toInt()}%',
                        label: 'GROWTH',
                        color: _agAccent,
                        isMobile: isMobile,
                      ),
                      SizedBox(width: isMobile ? 8 : 12),
                      // Timer
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: timerWarn
                              ? Colors.red.withValues(alpha: 0.22)
                              : Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: timerWarn ? Colors.red : Colors.white24, width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.timer,
                              color: timerWarn ? Colors.red : Colors.white54,
                              size: isMobile ? 12 : 13),
                            const SizedBox(width: 4),
                            Text(timerStr,
                              style: GoogleFonts.exo2(
                                fontSize: isMobile ? 13 : 15,
                                color: timerWarn ? Colors.red : Colors.white,
                                fontWeight: FontWeight.w900)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        // ── Progress bar across top ────────────────────────────────────────
        Positioned(
          top: isMobile ? 68 : 76, left: isMobile ? 10 : 14, right: isMobile ? 10 : 14,
          child: IgnorePointer(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _farmGreenProgress,
                backgroundColor: Colors.white.withValues(alpha: 0.08),
                valueColor: AlwaysStoppedAnimation(_agAccent),
                minHeight: 3,
              ),
            ),
          ),
        ),

        // ── BOTTOM hint bar ────────────────────────────────────────────────
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: SafeArea(
            child: IgnorePointer(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  isMobile ? 10 : 14, 0, isMobile ? 10 : 14, isMobile ? 10 : 12),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 12 : 16, vertical: isMobile ? 8 : 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF060F06).withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.07), width: 1),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _irrigationMethod == 'pipe'
                            ? Icons.touch_app_rounded : Icons.gesture_rounded,
                        color: methodColor, size: isMobile ? 14 : 16),
                      SizedBox(width: isMobile ? 7 : 9),
                      Flexible(child: Text(
                        _irrigationMethod == 'pipe'
                            ? 'Drag from the river across the farm to lay drip pipes'
                            : 'Drag from the river across the farm to dig furrows',
                        style: GoogleFonts.exo2(fontSize: isMobile ? 10 : 11,
                          color: Colors.white60, fontWeight: FontWeight.w500),
                        textAlign: TextAlign.center)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        // ── Water connection flash badge ───────────────────────────────────
        if (_connectedChannels > 0 && _farmGreenProgress < 0.15)
          Positioned(
            top: isMobile ? 90 : 100, left: 0, right: 0,
            child: IgnorePointer(
              child: Center(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(seconds: 2),
                  builder: (ctx, v, _) => Opacity(
                    opacity: (sin(v * pi * 4) + 1) / 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 7),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0288D1).withValues(alpha: 0.90),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(
                          color: Colors.blue.withValues(alpha: 0.4),
                          blurRadius: 12)],
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.water_drop, color: Colors.white, size: 14),
                        const SizedBox(width: 6),
                        Text('💧 Water flowing!',
                          style: GoogleFonts.exo2(fontSize: isMobile ? 12 : 13,
                            color: Colors.white, fontWeight: FontWeight.w800)),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _agHUDStat({required IconData icon, required String value,
      required String label, required Color color, required bool isMobile}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: isMobile ? 11 : 12),
          SizedBox(width: 3),
          Text(value, style: GoogleFonts.exo2(fontSize: isMobile ? 13 : 15,
            color: color, fontWeight: FontWeight.w900, height: 1.0)),
        ]),
        Text(label, style: GoogleFonts.exo2(fontSize: 8,
          color: color.withValues(alpha: 0.65), fontWeight: FontWeight.w600,
          letterSpacing: 0.8)),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Harvest result + educational tip overlay
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildHarvestResultOverlay(bool isMobile) {
    final isGood   = _harvestResult == 'bountiful';
    final isAvg    = _harvestResult == 'average';
    final resultColor = isGood ? const Color(0xFF4CAF50)
        : isAvg ? _agAmber : const Color(0xFFFF5252);
    final resultEmoji = isGood ? '🌟' : isAvg ? '🌿' : '🥀';
    final resultLabel = isGood ? 'BOUNTIFUL HARVEST!'
        : isAvg ? 'AVERAGE HARVEST' : 'POOR HARVEST';

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF0D2B0D),
            resultColor.withValues(alpha: 0.15),
            const Color(0xFF062006),
          ],
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.all(isMobile ? 20 : 32),
          child: Column(
            children: [
              SizedBox(height: isMobile ? 20 : 36),
              Text(resultEmoji, style: TextStyle(fontSize: isMobile ? 64 : 80)),
              SizedBox(height: isMobile ? 12 : 16),
              Text(resultLabel,
                style: GoogleFonts.exo2(fontSize: isMobile ? 26 : 32,
                  color: resultColor, fontWeight: FontWeight.w900,
                  letterSpacing: 1.2),
                textAlign: TextAlign.center),
              SizedBox(height: isMobile ? 8 : 12),
              // Stats row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _harvestStatChip(
                    '${(_farmGreenProgress * 100).toInt()}%',
                    'Farm Irrigated', resultColor, isMobile),
                  SizedBox(width: isMobile ? 8 : 12),
                  _harvestStatChip(
                    '$_connectedChannels',
                    'Channels', const Color(0xFF29B6F6), isMobile),
                ],
              ),
              SizedBox(height: isMobile ? 20 : 28),
              // Educational tip card
              Container(
                padding: EdgeInsets.all(isMobile ? 16 : 20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _agAccent.withValues(alpha: 0.30), width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: _agAccent.withValues(alpha: 0.15),
                          shape: BoxShape.circle),
                        child: Icon(Icons.lightbulb_rounded,
                          color: _agAccent, size: isMobile ? 16 : 18)),
                      SizedBox(width: isMobile ? 8 : 10),
                      Text('WHAT YOU LEARNED',
                        style: GoogleFonts.exo2(fontSize: isMobile ? 11 : 12,
                          color: _agAccent, fontWeight: FontWeight.w800,
                          letterSpacing: 1.2)),
                    ]),
                    SizedBox(height: isMobile ? 10 : 12),
                    Text(_educationalTip,
                      style: GoogleFonts.exo2(fontSize: isMobile ? 13 : 14,
                        color: Colors.white.withValues(alpha: 0.85),
                        fontWeight: FontWeight.w500, height: 1.5)),
                  ],
                ),
              ),
              SizedBox(height: isMobile ? 24 : 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _showHarvestResult = false;
                      currentPhase = 5; // Advance to mission complete screen
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: resultColor,
                    padding: EdgeInsets.symmetric(vertical: isMobile ? 13 : 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('VIEW MISSION RESULTS',
                        style: GoogleFonts.exo2(fontSize: isMobile ? 14 : 16,
                          fontWeight: FontWeight.w900,
                          color: isGood ? Colors.black : Colors.white)),
                      const SizedBox(width: 6),
                      Icon(Icons.arrow_forward_rounded,
                        color: isGood ? Colors.black : Colors.white, size: 16),
                    ],
                  ),
                ),
              ),
              SizedBox(height: isMobile ? 16 : 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _harvestStatChip(String value, String label, Color color, bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 14 : 18, vertical: isMobile ? 8 : 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1),
      ),
      child: Column(
        children: [
          Text(value, style: GoogleFonts.exo2(fontSize: isMobile ? 22 : 26,
            color: color, fontWeight: FontWeight.w900, height: 1.0)),
          Text(label, style: GoogleFonts.exo2(fontSize: isMobile ? 10 : 11,
            color: Colors.white54, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  void _checkForFurrowContinuation(Vector2 tapPosition) {
    const threshold = 30.0;
    for (var furrow in game.completedFurrows) {
      if (furrow.points.isEmpty) continue;
      final endPoint = furrow.points.last;
      final distance = (endPoint - tapPosition).length;
      if (distance < threshold && !furrow.isConnectedToRiver) {
        game.resumeFurrowDrawing(furrow);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Continuing furrow...'),
            duration: Duration(seconds: 1), backgroundColor: Colors.green));
        break;
      }
    }
  }

    Widget _timeUpRow(String label, String value, Color color, bool isMobile) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.exo2(fontSize: isMobile ? 12 : 13,
          color: Colors.white70, fontWeight: FontWeight.w500)),
        Text(value, style: GoogleFonts.exo2(fontSize: isMobile ? 14 : 15,
          color: color, fontWeight: FontWeight.w900)),
      ],
    );
  }

  Widget _buildCompletionScreen() {
    final size       = MediaQuery.of(context).size;
    final isMobile   = size.width < 600;

    // Gather all session loot
    final totalPoints   = game.calculateFinalScore();
    final purifiedWater = game.purifiedWaterAmount;
    final bactMult      = game.bacteriaMultiplied;
    final cropHarvest   = game.harvestYield;
    final cropType      = game.selectedCrop ?? '';
    final fishCaught    = game.fishCount;
    final plasticKg     = game.recycledPlastic;
    final metalKg       = game.recycledMetal;
    final organicKg     = game.recycledOrganic;
    final hazardousKg   = game.recycledHazardous;
    final harvestLabel  = game.harvestResult == 'bountiful' ? '🌟 Bountiful'
        : game.harvestResult == 'average' ? '🌿 Average' : '🥀 Poor';
    final cropEmoji     = cropType == 'vegetables' ? '🥦'
        : cropType == 'maize' ? '🌽' : cropType == 'rice' ? '🌾' : '🌱';

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF051A10), Color(0xFF0A2A18), Color(0xFF051A10)],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: SafeArea(
        bottom: true,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            isMobile ? 16 : 24, isMobile ? 20 : 32,
            isMobile ? 16 : 24, isMobile ? 24 : 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header ────────────────────────────────────────────────
              Center(
                child: Column(children: [
                  Text('🏆', style: TextStyle(fontSize: isMobile ? 56 : 72)),
                  SizedBox(height: isMobile ? 8 : 12),
                  Text('MISSION COMPLETE',
                    style: GoogleFonts.exo2(
                      fontSize: isMobile ? 26 : 32,
                      color: const Color(0xFF00E5A0),
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.0,
                    )),
                  SizedBox(height: isMobile ? 4 : 6),
                  Text('River ecosystem fully restored',
                    style: GoogleFonts.exo2(
                      fontSize: isMobile ? 12 : 14,
                      color: Colors.white54,
                      fontWeight: FontWeight.w500)),
                  SizedBox(height: isMobile ? 6 : 8),
                  // Score badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.amber.withValues(alpha: 0.5))),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                      const SizedBox(width: 6),
                      Text('$totalPoints ECO POINTS',
                        style: GoogleFonts.exo2(fontSize: isMobile ? 13 : 14,
                          color: Colors.amber, fontWeight: FontWeight.w800,
                          letterSpacing: 1.2)),
                    ]),
                  ),
                ]),
              ),

              SizedBox(height: isMobile ? 20 : 28),

              // ── RECYCLED MATERIALS ────────────────────────────────────
              _missionCard(
                title: '♻ Recycled Materials',
                subtitle: 'Ready for use in the polluted city',
                color: const Color(0xFF4FC3F7),
                isMobile: isMobile,
                children: [
                  _lootRow('🔵 Plastic', '$plasticKg items', const Color(0xFF4FC3F7), isMobile),
                  _lootRow('⚙ Metal', '$metalKg items', const Color(0xFFB0BEC5), isMobile),
                  _lootRow('🌿 Organic', '$organicKg items', const Color(0xFF69F0AE), isMobile),
                  _lootRow('⚠ Hazardous', '$hazardousKg items', const Color(0xFFFF5252), isMobile),
                ],
              ),

              SizedBox(height: isMobile ? 12 : 16),

              // ── WATER & BACTERIA ──────────────────────────────────────
              _missionCard(
                title: '💧 Purified Water',
                subtitle: 'Clean water secured for the community',
                color: const Color(0xFF00E5A0),
                isMobile: isMobile,
                children: [
                  _lootRow('Water Purified', '${purifiedWater}L',
                      const Color(0xFF00E5A0), isMobile),
                  _lootRow('Bacteria Cultures', '$bactMult',
                      const Color(0xFF69F0AE), isMobile),
                  if (fishCaught > 0)
                    _lootRow('🐟 Fish (aquatic life restored)',
                        '$fishCaught species', const Color(0xFF4FC3F7), isMobile),
                ],
              ),

              SizedBox(height: isMobile ? 12 : 16),

              // ── HARVEST ───────────────────────────────────────────────
              if (cropType.isNotEmpty)
                _missionCard(
                  title: '$cropEmoji Harvest',
                  subtitle: 'Crops for future levels',
                  color: const Color(0xFF8BC34A),
                  isMobile: isMobile,
                  children: [
                    _lootRow('Crop', cropType[0].toUpperCase() + cropType.substring(1),
                        const Color(0xFF8BC34A), isMobile),
                    _lootRow('Yield', '${cropHarvest}kg',
                        const Color(0xFFAED581), isMobile),
                    _lootRow('Result', harvestLabel,
                        game.harvestResult == 'bountiful' ? Colors.amber
                        : game.harvestResult == 'average' ? const Color(0xFFFFA000)
                        : const Color(0xFFFF5252), isMobile),
                  ],
                ),

              SizedBox(height: isMobile ? 24 : 32),

              // ── CTA ───────────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PollutedCityScreen(
                          recycledPlastic:   plasticKg,
                          recycledMetal:     metalKg,
                          recycledOrganic:   organicKg,
                          purifiedWater:     purifiedWater,
                          cropType:          cropType,
                          cropYield:         cropHarvest,
                          fishCount:         fishCaught,
                          ecoPoints:         totalPoints,
                          bacteriaCultures:  bactMult,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00E5A0),
                    padding: EdgeInsets.symmetric(vertical: isMobile ? 14 : 18),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('PROCEED TO POLLUTED CITY',
                        style: GoogleFonts.exo2(fontSize: isMobile ? 15 : 17,
                          fontWeight: FontWeight.w900, color: Colors.black,
                          letterSpacing: 1.0)),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_rounded,
                          color: Colors.black, size: 18),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _missionCard({
    required String title, required String subtitle, required Color color,
    required bool isMobile, required List<Widget> children,
  }) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 14 : 18),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.30), width: 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: GoogleFonts.exo2(fontSize: isMobile ? 14 : 16,
          color: color, fontWeight: FontWeight.w800)),
        SizedBox(height: 2),
        Text(subtitle, style: GoogleFonts.exo2(fontSize: isMobile ? 10 : 11,
          color: Colors.white38, fontWeight: FontWeight.w500)),
        Divider(color: color.withValues(alpha: 0.20), height: isMobile ? 14 : 16),
        ...children,
      ]),
    );
  }

  Widget _lootRow(String label, String value, Color color, bool isMobile) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: GoogleFonts.exo2(fontSize: isMobile ? 12 : 13,
          color: Colors.white60, fontWeight: FontWeight.w500)),
        Text(value, style: GoogleFonts.exo2(fontSize: isMobile ? 13 : 14,
          color: color, fontWeight: FontWeight.w800)),
      ]),
    );
  }

  /*Widget _buildCompletionStat(String label, String value, Color color, bool isMobile) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(child: Text(label, style: GoogleFonts.exo2(
          fontSize: isMobile ? 14 : 16, color: Colors.white70))),
        Text(value, style: GoogleFonts.exo2(fontSize: isMobile ? 20 : 24,
          color: color, fontWeight: FontWeight.w900)),
      ],
    );
  }*/

    Widget _buildPhaseTransition() {
    String phaseText = '';
    IconData phaseIcon = Icons.check;
    
    switch (currentPhase) {
      case 1:
        phaseText = 'Waste Collection Complete!\nProceeding to Sorting...';
        phaseIcon = Icons.recycling;
        break;
      case 2:
        phaseText = 'Sorting Complete!\nStarting Bacterial Treatment...';
        phaseIcon = Icons.science;
        break;
      case 3:
        phaseText = 'Water Purified!\nSetting up Irrigation...';
        phaseIcon = Icons.agriculture;
        break;
      case 4:
        phaseText = 'Farms Irrigated!\nEcosystem Restoring...';
        phaseIcon = Icons.nature;
        break;
    }
    
    return Container(
      color: Colors.black.withValues(alpha: 0.9),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(phaseIcon, size: 80, color: Colors.cyan),
            const SizedBox(height: 24),
            Text(
              phaseText,
              style: GoogleFonts.exo2(
                fontSize: 24,
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            CircularProgressIndicator(color: Colors.cyan),
          ],
        ),
      ),
    );
  }
}