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
  
  int currentPhase = 0; // 0=Intro, 1=Collection, 2=Sorting, 3=Treatment, 3.5=AppSelect(shown as bool), 4=Agriculture, 5=Urban, 6=Industrial, 7=Environmental, 8=Complete
  bool _showApplicationSelection = false; // shown after Phase 3 completes
  String? _selectedApplication; // 'agriculture' | 'urban' | 'industrial' | 'environmental'
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
  double _sortingTimeLeft = 90.0;
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

  // Urban water supply phase state
  double _urbanTimeLeft = 90.0;
  bool _showUrbanResult = false;
  String _urbanResult = '';
  bool _urbanTimerStarted = false;  // drives pre-start overlay
  int _urbanActiveBursts = 0;       // drives animated burst banner
  int _urbanTotalBursts = 0;        // for result display
  int _urbanBurstsFixed = 0;        // for result display

  // Industrial phase state
  int _industrialSystems = 0;
  double _industrialEfficiency = 0.0;
  double _industrialTimeLeft = 90.0;
  bool _showIndustrialResult = false;
  String _industrialResult = '';
  final List<bool> _systemsUpgraded = [false, false, false, false];

  // Environmental restoration phase state
  int _habitatsRestored = 0;
  double _ecosystemHealth = 0.0;
  double _environmentalTimeLeft = 90.0;
  bool _showEnvironmentalResult = false;
  String _environmentalResult = '';
  final List<bool> _habitatsRestoredList = [false, false, false, false, false];

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
          _showPhaseTransition = false;
          if (phase == 1) {
            currentPhase = 2;
            game.startPhase2Sorting();
          } else if (phase == 2) {
            currentPhase = 3;
            game.startPhase3Treatment();
          } else if (phase == 3) {
            // Show application selection instead of going directly to agriculture
            _showApplicationSelection = true;
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

    game.onUrbanUpdate = (households, progress) {
      safeSetState(() {
        // mirror live burst counts from game for the HUD
        _urbanActiveBursts = game.urbanActiveBursts;
        _urbanBurstsFixed  = game.urbanBurstsFixed;
        _urbanTotalBursts  = game.urbanTotalBursts;
      });
    };

    game.onUrbanTimerStart = () {
      safeSetState(() => _urbanTimerStarted = true);
    };

    game.onUrbanTick = (timeLeft) {
      safeSetState(() {
        _urbanTimeLeft     = timeLeft;
        _urbanActiveBursts = game.urbanActiveBursts;
        _urbanBurstsFixed  = game.urbanBurstsFixed;
        _urbanTotalBursts  = game.urbanTotalBursts;
      });
    };

    game.onUrbanComplete = (result) {
      safeSetState(() {
        _urbanResult       = result;
        _urbanActiveBursts = game.urbanActiveBursts;
        _urbanBurstsFixed  = game.urbanBurstsFixed;
        _urbanTotalBursts  = game.urbanTotalBursts;
        _showUrbanResult   = true;
      });
    };

    game.onIndustrialUpdate = (systems, efficiency) {
      safeSetState(() {
        _industrialSystems = systems;
        _industrialEfficiency = efficiency;
      });
    };

    game.onIndustrialTick = (timeLeft) {
      safeSetState(() => _industrialTimeLeft = timeLeft);
    };

    game.onIndustrialComplete = (result) {
      safeSetState(() {
        _industrialResult = result;
        _showIndustrialResult = true;
      });
    };

    game.onEnvironmentalUpdate = (habitats, health) {
      safeSetState(() {
        _habitatsRestored = habitats;
        _ecosystemHealth = health;
      });
    };

    game.onEnvironmentalTick = (timeLeft) {
      safeSetState(() => _environmentalTimeLeft = timeLeft);
    };

    game.onEnvironmentalComplete = (result) {
      safeSetState(() {
        _environmentalResult = result;
        _showEnvironmentalResult = true;
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
            if (currentPhase == 5) _buildUrbanInterface(),
            if (currentPhase == 6) _buildIndustrialInterface(),
            if (currentPhase == 7) _buildEnvironmentalInterface(),
            if (currentPhase == 8) _buildCompletionScreen(),

            // Application selection overlay (after phase 3)
            if (_showApplicationSelection) _buildApplicationSelectionScreen(),

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
                      currentPhase = 8; // Advance to mission complete screen
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

  // ─────────────────────────────────────────────────────────────────────────
  // APPLICATION SELECTION SCREEN — shown after Phase 3 completion
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildApplicationSelectionScreen() {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0A1628), Color(0xFF051020), Color(0xFF0A1628)],
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.all(isMobile ? 16 : 24),
          child: Column(
            children: [
              SizedBox(height: isMobile ? 12 : 24),
              // Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.cyan.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.cyan.withValues(alpha: 0.5)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 7, height: 7,
                    decoration: BoxDecoration(color: Colors.cyan, shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Colors.cyan, blurRadius: 5)])),
                  const SizedBox(width: 8),
                  Text('PHASE 4  ·  CLEAN WATER APPLICATION',
                    style: GoogleFonts.exo2(fontSize: isMobile ? 10 : 11,
                      color: Colors.cyan, fontWeight: FontWeight.w700, letterSpacing: 1.4)),
                ]),
              ),
              SizedBox(height: isMobile ? 16 : 24),
              // Header
              Text('💧 Water is Purified!', style: GoogleFonts.exo2(
                fontSize: isMobile ? 26 : 32, color: Colors.white, fontWeight: FontWeight.w900)),
              SizedBox(height: isMobile ? 8 : 12),
              Container(
                padding: EdgeInsets.all(isMobile ? 12 : 16),
                decoration: BoxDecoration(
                  color: Colors.cyan.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.cyan.withValues(alpha: 0.25)),
                ),
                child: Text(
                  'The river has been cleaned and ${game.purifiedWaterAmount}L of clean water is ready.\n'
                  'Choose how to apply this precious resource to help the community.',
                  style: GoogleFonts.exo2(fontSize: isMobile ? 12 : 13,
                    color: Colors.white60, fontWeight: FontWeight.w500),
                  textAlign: TextAlign.center),
              ),
              SizedBox(height: isMobile ? 20 : 28),
              Text('Choose Your Application', style: GoogleFonts.exo2(
                fontSize: isMobile ? 18 : 22, color: Colors.white70, fontWeight: FontWeight.w800)),
              SizedBox(height: isMobile ? 14 : 20),
              // Application cards
              _buildAppCard('agriculture', '🌾', 'Agricultural Irrigation',
                'Use clean water for sustainable crop farming. Irrigate fields and harvest food for the community.',
                'Design irrigation channels & grow crops', const Color(0xFF4CAF50), isMobile),
              _buildAppCard('urban', '🏙', 'Urban Water Supply',
                'Pipe clean water to homes and families in the city, improving public health.',
                'Connect households to the water network', const Color(0xFF29B6F6), isMobile),
              _buildAppCard('industrial', '🏭', 'Industrial Processes',
                'Supply industries with clean water for eco-friendly manufacturing, reducing pollution.',
                'Upgrade factory systems with clean water', const Color(0xFFFF8F00), isMobile),
              _buildAppCard('environmental', '🌿', 'Environmental Restoration',
                'Release clean water back into ecosystems to restore wetlands, fish habitats, and wildlife.',
                'Restore habitats and revive biodiversity', const Color(0xFF00BFA5), isMobile),
              SizedBox(height: isMobile ? 12 : 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppCard(String appKey, String emoji, String title, String desc,
      String actionHint, Color color, bool isMobile) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedApplication = appKey;
          _showApplicationSelection = false;
          game.selectedApplication = appKey;
        });
        _launchApplication(appKey);
      },
      child: Container(
        margin: EdgeInsets.only(bottom: isMobile ? 12 : 16),
        padding: EdgeInsets.all(isMobile ? 14 : 18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [color.withValues(alpha: 0.18), color.withValues(alpha: 0.07)],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.45), width: 1.5),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.12),
            blurRadius: 14, offset: const Offset(0, 4))],
        ),
        child: Row(children: [
          Container(
            width: isMobile ? 56 : 68, height: isMobile ? 56 : 68,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(14)),
            child: Center(child: Text(emoji, style: TextStyle(fontSize: isMobile ? 30 : 36))),
          ),
          SizedBox(width: isMobile ? 12 : 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: GoogleFonts.exo2(fontSize: isMobile ? 15 : 17,
              color: Colors.white, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(desc, style: GoogleFonts.exo2(fontSize: isMobile ? 10 : 11,
              color: Colors.white54, fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(6)),
              child: Text(actionHint, style: GoogleFonts.exo2(fontSize: isMobile ? 9 : 10,
                color: color, fontWeight: FontWeight.w700)),
            ),
          ])),
          Icon(Icons.arrow_forward_ios_rounded,
            color: color.withValues(alpha: 0.6), size: isMobile ? 16 : 18),
        ]),
      ),
    );
  }

  void _launchApplication(String appKey) {
    switch (appKey) {
      case 'agriculture':
        setState(() => currentPhase = 4);
        game.startPhase4Agriculture();
        break;
      case 'urban':
        setState(() => currentPhase = 5);
        game.startUrbanPhase();
        break;
      case 'industrial':
        setState(() => currentPhase = 6);
        game.startIndustrialPhase();
        break;
      case 'environmental':
        setState(() => currentPhase = 7);
        game.startEnvironmentalPhase();
        break;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // URBAN WATER SUPPLY PHASE (Phase 5)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildUrbanInterface() {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;
    if (_showUrbanResult) return _buildUrbanResultOverlay(isMobile);

    // The pipe-puzzle grid is a pure Flutter overlay — no Flame canvas needed.
    return _buildUrbanGameplay(size, isMobile);
  }

  Widget _buildUrbanGameplay(Size size, bool isMobile) {
    if (game.urbanGrid.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: Colors.cyan));
    }

    return Stack(
      children: [
        // ── Main gameplay ────────────────────────────────────────────────
        Container(
          padding: EdgeInsets.all(isMobile ? 14 : 22),
          color: const Color(0xFF051428),
          child: Column(
            children: [
              _buildUrbanHUD(isMobile),
              const SizedBox(height: 10),
              // ── Progress bar ───────────────────────────────────────────
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: game.urbanProgress,
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  valueColor: AlwaysStoppedAnimation(
                      game.urbanProgress == 1.0
                          ? Colors.greenAccent
                          : const Color(0xFF29B6F6)),
                  minHeight: 4,
                ),
              ),
              const SizedBox(height: 10),
              // ── Pipe-puzzle grid ───────────────────────────────────────
              Expanded(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 6,
                      crossAxisSpacing: 4,
                      mainAxisSpacing: 4,
                    ),
                    itemCount: 36,
                    itemBuilder: (context, index) {
                      final r = index ~/ 6;
                      final c = index % 6;
                      return _buildUrbanTile(r, c, isMobile);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _buildBurstBanner(isMobile),
              const SizedBox(height: 6),
              // ── Hint bar ───────────────────────────────────────────────
              Container(
                padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 12 : 16,
                    vertical: isMobile ? 6 : 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.07)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.touch_app_rounded,
                        color: Colors.cyan, size: 13),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Tap empty = place pipe  •  Tap pipe = rotate/change type  •  Tap 💥 = fix burst  •  🪨 = impassable',
                        style: GoogleFonts.exo2(
                            fontSize: isMobile ? 9 : 10,
                            color: Colors.white38,
                            fontWeight: FontWeight.w500),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // ── PRE-START overlay (disappears after player taps BEGIN) ───────────
        if (!_urbanTimerStarted)
          Positioned.fill(
            child: GestureDetector(
              // Tapping outside the card does nothing — grid is accessible via BEGIN
              behavior: HitTestBehavior.opaque,
              onTap: () {}, // absorb stray taps on the dimmed area only
              child: Container(
                color: Colors.black.withValues(alpha: 0.78),
                child: Center(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 24 : 60,
                        vertical: isMobile ? 16 : 24),
                    child: Container(
                      padding: EdgeInsets.all(isMobile ? 20 : 28),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFF0A2040).withValues(alpha: 0.97),
                            const Color(0xFF051428).withValues(alpha: 0.97),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: const Color(0xFF29B6F6)
                                .withValues(alpha: 0.60),
                            width: 2),
                        boxShadow: [
                          BoxShadow(
                              color: const Color(0xFF29B6F6)
                                  .withValues(alpha: 0.28),
                              blurRadius: 36,
                              spreadRadius: 4),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('🔧',
                              style: TextStyle(fontSize: 46)),
                          const SizedBox(height: 8),
                          Text('URBAN WATER SUPPLY\nAPPLICATION',
                              style: GoogleFonts.exo2(
                                  fontSize: isMobile ? 15 : 17,
                                  color: const Color(0xFF29B6F6),
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.1,
                                  height: 1.25),
                              textAlign: TextAlign.center),
                          const SizedBox(height: 10),
                          Text(
                            'Route pipes from the reservoir to all 5 households.\n'
                            '🪨 Rocky terrain blocks direct paths — think ahead.\n'
                            '🟡 Amber dot = pipe placed but not yet connected.\n'
                            'Burst pipes drop pressure — fix immediately!',
                            style: GoogleFonts.exo2(
                                fontSize: isMobile ? 11 : 12,
                                color: Colors.white60,
                                fontWeight: FontWeight.w500,
                                height: 1.5),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          // Pipe type reference
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('TAP TO CYCLE PIPE TYPE:',
                                    style: GoogleFonts.exo2(
                                        fontSize: isMobile ? 8 : 9,
                                        color: Colors.white38,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.8)),
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    _pipeTypeChip('—', 'Straight\n(H/V)', Colors.cyan, isMobile),
                                    _pipeTypeChip('⌐', 'Corner\n(×4 rotate)', Colors.cyan, isMobile),
                                    _pipeTypeChip('⊤', 'T-Junction\n(×4 rotate)', const Color(0xFF4FC3F7), isMobile),
                                    _pipeTypeChip('✕', 'Remove', Colors.white38, isMobile),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          // Rule chips
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            alignment: WrapAlignment.center,
                            children: [
                              _urbanRuleChip(
                                  '⏱ 90s limit',
                                  Colors.orangeAccent,
                                  isMobile),
                              _urbanRuleChip(
                                  '🏠 5 households',
                                  Colors.greenAccent,
                                  isMobile),
                              _urbanRuleChip(
                                  '💥 Bursts spawn',
                                  Colors.redAccent,
                                  isMobile),
                              _urbanRuleChip(
                                  '💧 Maintain pressure',
                                  const Color(0xFF29B6F6),
                                  isMobile),
                            ],
                          ),
                          const SizedBox(height: 20),
                          // BEGIN button — starts timer and dismisses overlay
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () {
                                game.activateUrbanTimer();
                                // _urbanTimerStarted will be set via onUrbanTimerStart callback
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    const Color(0xFF29B6F6),
                                padding: EdgeInsets.symmetric(
                                    vertical: isMobile ? 13 : 16),
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(12)),
                                elevation: 6,
                                shadowColor: const Color(0xFF29B6F6)
                                    .withValues(alpha: 0.45),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.play_arrow_rounded,
                                      color: Colors.black, size: 20),
                                  const SizedBox(width: 8),
                                  Text('BEGIN APPLICATION',
                                      style: GoogleFonts.exo2(
                                          fontSize:
                                              isMobile ? 14 : 16,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.black,
                                          letterSpacing: 0.8)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Timer starts the moment you press BEGIN',
                            style: GoogleFonts.exo2(
                                fontSize: isMobile ? 9 : 10,
                                color: Colors.white30,
                                fontWeight: FontWeight.w500),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _pipeTypeChip(String symbol, String label, Color color, bool isMobile) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: isMobile ? 26 : 30,
          height: isMobile ? 26 : 30,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Center(
            child: Text(symbol,
                style: TextStyle(
                    fontSize: isMobile ? 14 : 16, color: color)),
          ),
        ),
        const SizedBox(height: 3),
        Text(label,
            style: GoogleFonts.exo2(
                fontSize: isMobile ? 7 : 8,
                color: Colors.white38,
                fontWeight: FontWeight.w600),
            textAlign: TextAlign.center),
      ],
    );
  }

  Widget _urbanRuleChip(String label, Color color, bool isMobile) {
    return Container(
      padding:
          EdgeInsets.symmetric(horizontal: isMobile ? 8 : 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(label,
          style: GoogleFonts.exo2(
              fontSize: isMobile ? 9 : 10,
              color: color,
              fontWeight: FontWeight.w700)),
    );
  }

  Widget _buildUrbanTile(int r, int c, bool isMobile) {
    final tile = game.urbanGrid[r][c];
    final isObstacle = tile.type == 'obstacle';

    // Pressure-driven colour for active pipes
    final pressureFrac = (tile.pressure / 100.0).clamp(0.0, 1.0);
    final pipeColor = tile.isConnected
        ? Color.lerp(Colors.cyan.shade200, Colors.cyan, pressureFrac)!
        : Colors.white.withValues(alpha: 0.30);

    // Border / bg by state
    Color borderColor;
    Color bgColor;
    if (isObstacle) {
      borderColor = const Color(0xFF5D4037).withValues(alpha: 0.80);
      bgColor     = const Color(0xFF3E2723).withValues(alpha: 0.85);
    } else if (tile.isLeaking) {
      borderColor = Colors.red;
      bgColor     = Colors.red.withValues(alpha: 0.16);
    } else if (tile.isConnected) {
      borderColor = pipeColor.withValues(alpha: 0.55);
      bgColor     = Colors.cyan.withValues(alpha: 0.07);
    } else if (tile.type != 'empty') {
      // Pipe placed but NOT connected — highlight as mis-rotated
      borderColor = Colors.amber.withValues(alpha: 0.50);
      bgColor     = Colors.amber.withValues(alpha: 0.05);
    } else {
      borderColor = Colors.white.withValues(alpha: 0.09);
      bgColor     = Colors.white.withValues(alpha: 0.02);
    }

    return GestureDetector(
      onTap: isObstacle ? null : () => setState(() => game.handleUrbanTileTap(r, c)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        decoration: BoxDecoration(
          color: bgColor,
          border: Border.all(
              color: borderColor,
              width: tile.isLeaking ? 2.0 : 1.0),
          borderRadius: BorderRadius.circular(4),
          boxShadow: tile.isConnected && !tile.isLeaking && !isObstacle
              ? [BoxShadow(
                  color: Colors.cyan.withValues(alpha: 0.14 * pressureFrac),
                  blurRadius: 5)]
              : [],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // ── Tile content ─────────────────────────────────────────────
            if (isObstacle)
              Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Text('🪨', style: TextStyle(fontSize: 14)),
              ])
            else if (tile.type == 'reservoir')
              Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.water_damage,
                    color: Colors.cyan, size: isMobile ? 18 : 22),
                Text('SRC',
                    style: GoogleFonts.exo2(
                        fontSize: 6,
                        color: Colors.cyan,
                        fontWeight: FontWeight.w800)),
              ])
            else if (tile.type == 'house')
              Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(
                  tile.isConnected && tile.pressure > 30
                      ? Icons.home
                      : Icons.home_outlined,
                  color: tile.isConnected && tile.pressure > 30
                      ? Colors.greenAccent
                      : Colors.white30,
                  size: isMobile ? 17 : 21,
                ),
                Text(
                  tile.isConnected && tile.pressure > 30
                      ? '${tile.pressure.toInt()}%'
                      : 'OFF',
                  style: GoogleFonts.exo2(
                      fontSize: 6,
                      color: tile.isConnected && tile.pressure > 30
                          ? (tile.pressure >= 65
                              ? Colors.greenAccent
                              : Colors.orange)
                          : Colors.white24,
                      fontWeight: FontWeight.w800),
                ),
              ])
            else if (tile.type == 'straight')
              Transform.rotate(
                angle: tile.rotation * 1.5708,
                child: Icon(Icons.horizontal_rule_rounded,
                    color: pipeColor, size: isMobile ? 20 : 24),
              )
            else if (tile.type == 'corner')
              Transform.rotate(
                angle: tile.rotation * 1.5708,
                child: Icon(Icons.turn_right_rounded,
                    color: pipeColor, size: isMobile ? 20 : 24),
              )
            else if (tile.type == 't_junction')
              Transform.rotate(
                angle: tile.rotation * 1.5708,
                child: Icon(Icons.device_hub_rounded,
                    color: pipeColor, size: isMobile ? 20 : 24),
              )
            else
              Icon(Icons.add_rounded,
                  color: Colors.white.withValues(alpha: 0.07),
                  size: isMobile ? 12 : 15),

            // ── Mis-rotation hint: amber dot top-right ───────────────────
            if (!tile.isConnected &&
                !isObstacle &&
                tile.type != 'empty' &&
                tile.type != 'house' &&
                tile.type != 'reservoir')
              Positioned(
                top: 2, right: 2,
                child: Container(
                  width: 5, height: 5,
                  decoration: const BoxDecoration(
                    color: Colors.amber,
                    shape: BoxShape.circle,
                  ),
                ),
              ),

            // ── Burst overlay ────────────────────────────────────────────
            if (tile.isLeaking)
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.3, end: 1.0),
                    duration: const Duration(milliseconds: 500),
                    builder: (ctx, v, _) => Opacity(
                      opacity: v,
                      child: Container(
                        color: Colors.red.withValues(alpha: 0.20),
                        child: Center(
                          child: Text('💥',
                              style: TextStyle(
                                  fontSize: isMobile ? 15 : 18)),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // ── Pressure badge (connected pipes only) ────────────────────
            if (tile.isConnected &&
                tile.pressure > 0 &&
                tile.type != 'house' &&
                tile.type != 'reservoir' &&
                !tile.isLeaking)
              Positioned(
                bottom: 1, right: 2,
                child: Text('${tile.pressure.toInt()}',
                    style: GoogleFonts.exo2(
                        fontSize: 5,
                        color: pipeColor.withValues(alpha: 0.75),
                        fontWeight: FontWeight.w700)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildUrbanHUD(bool isMobile) {
    final timerWarn = _urbanTimeLeft < 20 && _urbanTimerStarted;

    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 10 : 14, vertical: isMobile ? 7 : 9),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.60),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: const Color(0xFF29B6F6).withValues(alpha: 0.35),
            width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Households
          _statItem('🏠 Connected',
              '${game.urbanHouseholdsConnected}/5', Colors.greenAccent, isMobile),
          // Vertical divider
          Container(width: 1, height: 28, color: Colors.white12),
          // Timer — shows "READY" before first tap
          _urbanTimerStarted
              ? _statItem(
                  '⏱ Time',
                  '${_urbanTimeLeft.toInt()}s',
                  timerWarn ? Colors.red : Colors.orangeAccent,
                  isMobile)
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('⏱ Time',
                        style: GoogleFonts.exo2(
                            fontSize: isMobile ? 9 : 10,
                            color: Colors.white38,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text('READY',
                        style: GoogleFonts.exo2(
                            fontSize: isMobile ? 12 : 14,
                            color: const Color(0xFF29B6F6),
                            fontWeight: FontWeight.w900)),
                  ],
                ),
          Container(width: 1, height: 28, color: Colors.white12),
          // Active bursts — red when any exist
          _statItem(
            '💥 Bursts',
            _urbanActiveBursts > 0 ? '$_urbanActiveBursts ACTIVE' : 'Clear',
            _urbanActiveBursts > 0 ? Colors.redAccent : Colors.white38,
            isMobile,
          ),
          Container(width: 1, height: 28, color: Colors.white12),
          // Pressure efficiency
          _statItem(
            '💧 Pressure',
            game.urbanAveragePressure > 0
                ? '${game.urbanAveragePressure.toInt()}%'
                : '—',
            game.urbanAveragePressure >= 65
                ? Colors.cyan
                : game.urbanAveragePressure >= 40
                    ? Colors.orangeAccent
                    : Colors.white38,
            isMobile,
          ),
        ],
      ),
    );
  }

  Widget _statItem(
      String label, String value, Color color, bool isMobile) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: GoogleFonts.exo2(
                fontSize: isMobile ? 9 : 10,
                color: Colors.white54,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(value,
            style: GoogleFonts.exo2(
                fontSize: isMobile ? 14 : 16,
                color: color,
                fontWeight: FontWeight.w900)),
      ],
    );
  }

  Widget _buildBurstBanner(bool isMobile) {
    final count = _urbanActiveBursts;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: count > 0
          ? TweenAnimationBuilder<double>(
              key: ValueKey(count),
              tween: Tween(begin: 0.6, end: 1.0),
              duration: const Duration(milliseconds: 500),
              builder: (ctx, v, _) => Opacity(
                opacity: v,
                child: Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 12 : 16,
                      vertical: isMobile ? 6 : 8),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: Colors.red.withValues(alpha: 0.55)),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.red.withValues(alpha: 0.25),
                          blurRadius: 10),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: Colors.redAccent, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        count == 1
                            ? '💥  1 PIPE BURST — TAP IT TO FIX!  PRESSURE DROPPING!'
                            : '💥  $count PIPE BURSTS — FIX THEM NOW!  PRESSURE DROPPING!',
                        style: GoogleFonts.exo2(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.w800,
                            fontSize: isMobile ? 10 : 12,
                            letterSpacing: 0.4),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : const SizedBox(height: 0),
    );
  }



  // _buildHouseholdCard removed — urban phase now uses the 5×5 pipe-puzzle grid
  // (see _buildUrbanGameplay / _buildUrbanTile above)

  Widget _buildUrbanResultOverlay(bool isMobile) {
    // ── Tier data ──────────────────────────────────────────────────────────
    const tiers = {
      'excellent': (
        emoji: '🌊', label: 'PERFECT SUPPLY!',
        color: Color(0xFF29B6F6),
        msg: 'Outstanding! All 5 households receive clean water at full '
            'pressure — zero burst damage. Your network is city-grade!'
      ),
      'good': (
        emoji: '💧', label: 'GOOD SUPPLY',
        color: Color(0xFF4FC3F7),
        msg: 'Well done! Most households are connected with healthy pressure. '
            'A couple of bursts reduced efficiency slightly.'
      ),
      'partial': (
        emoji: '🚰', label: 'PARTIAL SUPPLY',
        color: Color(0xFFFFA000),
        msg: 'Some households got water, but the network was incomplete. '
            'More pipe connections and faster burst repairs would help.'
      ),
      'poor': (
        emoji: '⚠️', label: 'POOR SUPPLY',
        color: Color(0xFFFF7043),
        msg: 'Very few households received water. Burst damage and missing '
            'pipes left most of the network without flow.'
      ),
      'failed': (
        emoji: '🔴', label: 'SUPPLY FAILED',
        color: Color(0xFFEF5350),
        msg: 'No households were connected in time. Practice routing pipes '
            'from the reservoir and patch bursts the moment they appear!'
      ),
    };

    final tier = tiers[_urbanResult] ?? tiers['failed']!;
    final timeUp = game.urbanTimeLeft <= 0;
    final timeTaken = game.urbanTimeTaken.toInt().clamp(0, 90);
    final score = game.urbanSupplyScore;

    // Score colour
    final Color scoreColor = score >= 85
        ? Colors.greenAccent
        : score >= 60
            ? Colors.amber
            : score >= 35
                ? Colors.orange
                : Colors.redAccent;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF051428),
            (tier.color).withValues(alpha: 0.10),
            const Color(0xFF051428),
          ],
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.all(isMobile ? 20 : 32),
          child: Column(
            children: [
              SizedBox(height: isMobile ? 16 : 28),

              // ── Heading ────────────────────────────────────────────────
              Text(tier.emoji, style: TextStyle(fontSize: isMobile ? 64 : 80)),
              SizedBox(height: isMobile ? 10 : 14),
              Text(tier.label,
                  style: GoogleFonts.exo2(
                      fontSize: isMobile ? 26 : 32,
                      color: tier.color,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2),
                  textAlign: TextAlign.center),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: (timeUp ? Colors.amber : tier.color)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: (timeUp ? Colors.amber : tier.color)
                          .withValues(alpha: 0.45)),
                ),
                child: Text(
                  timeUp
                      ? '⏰  Time expired after ${timeTaken}s'
                      : '✅  Completed in ${timeTaken}s',
                  style: GoogleFonts.exo2(
                      fontSize: isMobile ? 10 : 11,
                      color: timeUp ? Colors.amber : tier.color,
                      fontWeight: FontWeight.w700),
                ),
              ),

              SizedBox(height: isMobile ? 16 : 22),

              // ── Supply quality score ring ──────────────────────────────
              Container(
                padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 16 : 22,
                    vertical: isMobile ? 12 : 16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: scoreColor.withValues(alpha: 0.35), width: 1.5),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Big score
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('$score',
                            style: GoogleFonts.exo2(
                                fontSize: isMobile ? 52 : 64,
                                color: scoreColor,
                                fontWeight: FontWeight.w900,
                                height: 1.0)),
                        Text('SUPPLY QUALITY SCORE  /100',
                            style: GoogleFonts.exo2(
                                fontSize: isMobile ? 9 : 10,
                                color: Colors.white38,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.0)),
                      ],
                    ),
                    SizedBox(width: isMobile ? 20 : 28),
                    // Score breakdown bars
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _scoreBar('Coverage',
                              (game.urbanHouseholdsConnected / 5.0),
                              Colors.greenAccent, isMobile),
                          const SizedBox(height: 6),
                          _scoreBar('Avg Pressure',
                              (game.urbanAveragePressure / 100.0).clamp(0, 1),
                              Colors.cyan, isMobile),
                          const SizedBox(height: 6),
                          _scoreBar(
                              'Burst Control',
                              ((20 -
                                          (game.urbanActiveBursts * 4)
                                              .clamp(0, 20)) /
                                      20.0)
                                  .clamp(0, 1),
                              Colors.orangeAccent,
                              isMobile),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: isMobile ? 14 : 18),

              // ── Stats grid ─────────────────────────────────────────────
              Container(
                padding: EdgeInsets.all(isMobile ? 14 : 18),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Column(
                  children: [
                    _urbanResultRow(
                        '🏠 Households Supplied',
                        '${game.urbanHouseholdsConnected} / 5',
                        tier.color,
                        isMobile),
                    _urbanResultRow(
                        '💧 Average Pressure',
                        game.urbanAveragePressure > 0
                            ? '${game.urbanAveragePressure.toInt()} psi'
                            : '— psi',
                        game.urbanAveragePressure >= 65
                            ? Colors.cyan
                            : Colors.orange,
                        isMobile),
                    _urbanResultRow(
                        '💥 Pipe Bursts Total',
                        '$_urbanTotalBursts burst${_urbanTotalBursts == 1 ? '' : 's'}',
                        _urbanTotalBursts == 0 ? Colors.greenAccent : Colors.redAccent,
                        isMobile),
                    _urbanResultRow(
                        '🔧 Bursts Repaired',
                        '$_urbanBurstsFixed / $_urbanTotalBursts',
                        _urbanBurstsFixed == _urbanTotalBursts && _urbanTotalBursts > 0
                            ? Colors.greenAccent
                            : Colors.orangeAccent,
                        isMobile),
                    _urbanResultRow(
                        '🔴 Unresolved Bursts',
                        '${game.urbanActiveBursts}',
                        game.urbanActiveBursts == 0
                            ? Colors.greenAccent
                            : Colors.redAccent,
                        isMobile),
                    _urbanResultRow(
                        '⏱ Time Taken',
                        timeUp ? 'Time expired' : '${timeTaken}s / 90s',
                        timeUp ? Colors.amber : Colors.white70,
                        isMobile),
                  ],
                ),
              ),

              SizedBox(height: isMobile ? 14 : 18),

              // ── Result message / tip ───────────────────────────────────
              Container(
                padding: EdgeInsets.all(isMobile ? 14 : 18),
                decoration: BoxDecoration(
                  color: (tier.color).withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: (tier.color).withValues(alpha: 0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                            color: (tier.color).withValues(alpha: 0.15),
                            shape: BoxShape.circle),
                        child: Icon(Icons.lightbulb_rounded,
                            color: tier.color,
                            size: isMobile ? 15 : 17)),
                      const SizedBox(width: 8),
                      Text('NETWORK ASSESSMENT',
                          style: GoogleFonts.exo2(
                              fontSize: isMobile ? 10 : 11,
                              color: tier.color,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.1)),
                    ]),
                    const SizedBox(height: 10),
                    Text(tier.msg,
                        style: GoogleFonts.exo2(
                            fontSize: isMobile ? 12 : 13,
                            color: Colors.white.withValues(alpha: 0.82),
                            fontWeight: FontWeight.w500,
                            height: 1.55)),
                    const SizedBox(height: 8),
                    Text(
                      '💡 Real urban networks lose 30–40 % of water to burst mains. '
                      'Quick response to pipe bursts and correct routing keep pressure high for every household.',
                      style: GoogleFonts.exo2(
                          fontSize: isMobile ? 10 : 11,
                          color: Colors.white38,
                          fontWeight: FontWeight.w500,
                          height: 1.45),
                    ),
                  ],
                ),
              ),

              SizedBox(height: isMobile ? 24 : 32),

              // ── CTA ───────────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => setState(() {
                    _showUrbanResult = false;
                    currentPhase = 8;
                  }),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tier.color,
                    padding: EdgeInsets.symmetric(
                        vertical: isMobile ? 14 : 18),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('VIEW MISSION RESULTS',
                          style: GoogleFonts.exo2(
                              fontSize: isMobile ? 14 : 16,
                              fontWeight: FontWeight.w900,
                              color: Colors.black,
                              letterSpacing: 0.8)),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_rounded,
                          color: Colors.black, size: 18),
                    ],
                  ),
                ),
              ),

              SizedBox(height: isMobile ? 12 : 16),
            ],
          ),
        ),
      ),
    );
  }

  // ── Result overlay helpers ─────────────────────────────────────────────

  Widget _scoreBar(String label, double fraction, Color color, bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.exo2(
                fontSize: isMobile ? 8 : 9,
                color: Colors.white38,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: fraction.clamp(0.0, 1.0),
            backgroundColor: Colors.white.withValues(alpha: 0.08),
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: isMobile ? 5 : 6,
          ),
        ),
      ],
    );
  }

  Widget _urbanResultRow(
      String label, String value, Color color, bool isMobile) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: GoogleFonts.exo2(
                  fontSize: isMobile ? 11 : 12,
                  color: Colors.white60,
                  fontWeight: FontWeight.w500)),
          Text(value,
              style: GoogleFonts.exo2(
                  fontSize: isMobile ? 12 : 13,
                  color: color,
                  fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
  // ─────────────────────────────────────────────────────────────────────────
  // INDUSTRIAL PHASE (Phase 6)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildIndustrialInterface() {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;
    if (_showIndustrialResult) return _buildIndustrialResultOverlay(isMobile);
    return _buildIndustrialGameplay(size, isMobile);
  }

  static const List<Map<String, dynamic>> _industrialSystemsData = [
    {'emoji': '⚙️', 'name': 'Cooling System', 'desc': 'Replace toxic coolant with clean water', 'color': Color(0xFF78909C)},
    {'emoji': '🔧', 'name': 'Steam Generator', 'desc': 'Use purified water to generate steam power', 'color': Color(0xFFFF8F00)},
    {'emoji': '🧪', 'name': 'Chemical Process', 'desc': 'Switch to water-based eco-chemicals', 'color': Color(0xFF26A69A)},
    {'emoji': '💨', 'name': 'Air Scrubber', 'desc': 'Use water to filter factory emissions', 'color': Color(0xFF7E57C2)},
  ];

  Widget _buildIndustrialGameplay(Size size, bool isMobile) {
    final tl = _industrialTimeLeft.toInt().clamp(0, 999);
    final timerStr = '${(tl ~/ 60).toString().padLeft(2, '0')}:${(tl % 60).toString().padLeft(2, '0')}';
    final timerWarn = _industrialTimeLeft < 20;
    const accent = Color(0xFFFF8F00);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1A1200), Color(0xFF0D0A00)],
        ),
      ),
      child: SafeArea(
        child: Column(children: [
          // HUD
          Container(
            margin: EdgeInsets.all(isMobile ? 10 : 14),
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16, vertical: isMobile ? 10 : 12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: accent.withValues(alpha: 0.4), width: 1.5)),
            child: Row(children: [
              const Text('🏭', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text('PHASE 4  ·  INDUSTRIAL UPGRADE', style: GoogleFonts.exo2(
                fontSize: isMobile ? 10 : 11, color: accent,
                fontWeight: FontWeight.w700, letterSpacing: 1.2)),
              const Spacer(),
              _agHUDStat(icon: Icons.settings, value: '$_industrialSystems/${game.industrialTotalSystems}',
                label: 'UPGRADED', color: accent, isMobile: isMobile),
              SizedBox(width: isMobile ? 10 : 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: timerWarn ? Colors.red.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: timerWarn ? Colors.red : Colors.white24)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.timer, color: timerWarn ? Colors.red : Colors.white54, size: 13),
                  const SizedBox(width: 4),
                  Text(timerStr, style: GoogleFonts.exo2(
                    fontSize: isMobile ? 13 : 15, color: timerWarn ? Colors.red : Colors.white,
                    fontWeight: FontWeight.w900)),
                ]),
              ),
            ]),
          ),
          // Progress bar
          Padding(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 14 : 20),
            child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Factory Efficiency', style: GoogleFonts.exo2(
                  fontSize: isMobile ? 11 : 12, color: Colors.white60)),
                Text('${(_industrialEfficiency * 100).toInt()}%', style: GoogleFonts.exo2(
                  fontSize: isMobile ? 13 : 14, color: accent, fontWeight: FontWeight.w900)),
              ]),
              const SizedBox(height: 5),
              ClipRRect(borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(value: _industrialEfficiency,
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  valueColor: const AlwaysStoppedAnimation(accent), minHeight: 8)),
            ]),
          ),
          SizedBox(height: isMobile ? 8 : 14),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 14 : 20),
            child: Container(
              padding: EdgeInsets.all(isMobile ? 10 : 12),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: accent.withValues(alpha: 0.2))),
              child: Row(children: [
                const Icon(Icons.info_outline, color: Color(0xFFFF8F00), size: 16),
                const SizedBox(width: 8),
                Flexible(child: Text('Tap each system to upgrade it with clean water technology.',
                  style: GoogleFonts.exo2(fontSize: isMobile ? 10 : 11, color: Colors.white54))),
              ]),
            ),
          ),
          SizedBox(height: isMobile ? 12 : 18),
          // Systems grid
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 14 : 20),
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12,
                  childAspectRatio: 1.1),
                itemCount: 4,
                itemBuilder: (ctx, i) => _buildIndustrialSystemCard(i, isMobile),
              ),
            ),
          ),
          SizedBox(height: isMobile ? 10 : 16),
        ]),
      ),
    );
  }

  Widget _buildIndustrialSystemCard(int index, bool isMobile) {
    final sys = _industrialSystemsData[index];
    final upgraded = _systemsUpgraded[index];
    final color = sys['color'] as Color;
    return GestureDetector(
      onTap: upgraded ? null : () {
        setState(() => _systemsUpgraded[index] = true);
        game.upgradeIndustrialSystem(index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutBack,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: upgraded
                ? [color.withValues(alpha: 0.28), color.withValues(alpha: 0.12)]
                : [Colors.white.withValues(alpha: 0.06), Colors.white.withValues(alpha: 0.03)]),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: upgraded ? color : Colors.white24, width: 1.5),
          boxShadow: upgraded ? [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 14)] : []),
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 12 : 16),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(sys['emoji'] as String, style: TextStyle(fontSize: isMobile ? 30 : 36)),
            SizedBox(height: isMobile ? 6 : 8),
            Text(sys['name'] as String, style: GoogleFonts.exo2(
              fontSize: isMobile ? 11 : 12, color: Colors.white, fontWeight: FontWeight.w800),
              textAlign: TextAlign.center),
            SizedBox(height: isMobile ? 4 : 5),
            Text(sys['desc'] as String, style: GoogleFonts.exo2(
              fontSize: isMobile ? 8 : 9, color: Colors.white38, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center, maxLines: 2),
            SizedBox(height: isMobile ? 6 : 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: (upgraded ? color : Colors.white).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8)),
              child: Text(upgraded ? '✅ Upgraded' : 'Tap to upgrade',
                style: GoogleFonts.exo2(fontSize: isMobile ? 8 : 9,
                  color: upgraded ? color : Colors.white38, fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildIndustrialResultOverlay(bool isMobile) {
    final isOptimized = _industrialResult == 'optimized';
    final isImproved = _industrialResult == 'improved';
    final resultColor = isOptimized ? const Color(0xFF66BB6A)
        : isImproved ? const Color(0xFFFF8F00) : Colors.orange;
    final resultEmoji = isOptimized ? '🏆' : isImproved ? '⚙️' : '🔧';
    final resultLabel = isOptimized ? 'FACTORY OPTIMIZED!'
        : isImproved ? 'SYSTEMS IMPROVED' : 'PARTIAL UPGRADE';

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [const Color(0xFF0D0A00), resultColor.withValues(alpha: 0.10), const Color(0xFF0D0A00)]),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.all(isMobile ? 20 : 32),
          child: Column(children: [
            SizedBox(height: isMobile ? 24 : 40),
            Text(resultEmoji, style: TextStyle(fontSize: isMobile ? 72 : 90)),
            SizedBox(height: isMobile ? 12 : 16),
            Text(resultLabel, style: GoogleFonts.exo2(
              fontSize: isMobile ? 26 : 32, color: resultColor,
              fontWeight: FontWeight.w900, letterSpacing: 1.2), textAlign: TextAlign.center),
            SizedBox(height: isMobile ? 8 : 12),
            Text('$_industrialSystems of ${game.industrialTotalSystems} industrial systems upgraded with clean water technology.',
              style: GoogleFonts.exo2(fontSize: isMobile ? 13 : 14, color: Colors.white54),
              textAlign: TextAlign.center),
            SizedBox(height: isMobile ? 20 : 28),
            Container(
              padding: EdgeInsets.all(isMobile ? 16 : 20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: resultColor.withValues(alpha: 0.25))),
              child: Column(children: [
                _appResultRow('⚙️ Systems Upgraded', '$_industrialSystems / ${game.industrialTotalSystems}', resultColor, isMobile),
                _appResultRow('📈 Factory Efficiency', '${(_industrialEfficiency * 100).toInt()}%', const Color(0xFFFF8F00), isMobile),
                _appResultRow('🌍 Pollution Reduced', isOptimized ? 'Greatly' : isImproved ? 'Moderately' : 'Slightly', resultColor, isMobile),
              ]),
            ),
            SizedBox(height: isMobile ? 16 : 22),
            Container(
              padding: EdgeInsets.all(isMobile ? 14 : 18),
              decoration: BoxDecoration(
                color: const Color(0xFFFF8F00).withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFF8F00).withValues(alpha: 0.25))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(color: const Color(0xFFFF8F00).withValues(alpha: 0.15), shape: BoxShape.circle),
                    child: const Icon(Icons.lightbulb_rounded, color: Color(0xFFFF8F00), size: 16)),
                  const SizedBox(width: 8),
                  Text('WHAT YOU LEARNED', style: GoogleFonts.exo2(
                    fontSize: isMobile ? 10 : 11, color: const Color(0xFFFF8F00),
                    fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                ]),
                const SizedBox(height: 10),
                Text(
                  '🏭 Industries that switch to clean water processes reduce toxic discharge by up to 75%. '
                  'Closed-loop water systems in factories can be reused dozens of times, '
                  'drastically cutting water consumption while improving product quality and reducing environmental fines.',
                  style: GoogleFonts.exo2(fontSize: isMobile ? 12 : 13,
                    color: Colors.white.withValues(alpha: 0.82), fontWeight: FontWeight.w500, height: 1.5)),
              ]),
            ),
            SizedBox(height: isMobile ? 24 : 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => setState(() {
                  _showIndustrialResult = false;
                  currentPhase = 8;
                }),
                style: ElevatedButton.styleFrom(
                  backgroundColor: resultColor,
                  padding: EdgeInsets.symmetric(vertical: isMobile ? 14 : 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('VIEW MISSION RESULTS', style: GoogleFonts.exo2(
                    fontSize: isMobile ? 14 : 16, fontWeight: FontWeight.w900,
                    color: Colors.black, letterSpacing: 0.8)),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_rounded, color: Colors.black, size: 18),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ENVIRONMENTAL RESTORATION PHASE (Phase 7)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildEnvironmentalInterface() {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;
    if (_showEnvironmentalResult) return _buildEnvironmentalResultOverlay(isMobile);
    return _buildEnvironmentalGameplay(size, isMobile);
  }

  static const List<Map<String, dynamic>> _habitats = [
    {'emoji': '🐸', 'name': 'Wetland',      'desc': 'Restore frog & amphibian habitat', 'color': Color(0xFF2E7D32)},
    {'emoji': '🐟', 'name': 'Fish Spawning','desc': 'Clear gravel beds for fish eggs',   'color': Color(0xFF0288D1)},
    {'emoji': '🦅', 'name': 'Riparian Zone','desc': 'Plant trees along riverbanks',      'color': Color(0xFF558B2F)},
    {'emoji': '🦋', 'name': 'Meadow Pool',  'desc': 'Create shallow pools for insects',  'color': Color(0xFF6A1B9A)},
    {'emoji': '🐢', 'name': 'Turtle Beach', 'desc': 'Restore sandy riverbanks for turtles','color': Color(0xFF00695C)},
  ];

  Widget _buildEnvironmentalGameplay(Size size, bool isMobile) {
    final tl = _environmentalTimeLeft.toInt().clamp(0, 999);
    final timerStr = '${(tl ~/ 60).toString().padLeft(2, '0')}:${(tl % 60).toString().padLeft(2, '0')}';
    final timerWarn = _environmentalTimeLeft < 20;
    const accent = Color(0xFF00BFA5);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Color(0xFF0A1F0A), Color(0xFF051208)],
        ),
      ),
      child: SafeArea(
        child: Column(children: [
          // HUD
          Container(
            margin: EdgeInsets.all(isMobile ? 10 : 14),
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16, vertical: isMobile ? 10 : 12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: accent.withValues(alpha: 0.4), width: 1.5)),
            child: Row(children: [
              const Text('🌿', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Text('PHASE 4  ·  ECOSYSTEM RESTORATION', style: GoogleFonts.exo2(
                fontSize: isMobile ? 10 : 11, color: accent,
                fontWeight: FontWeight.w700, letterSpacing: 1.2)),
              const Spacer(),
              _agHUDStat(icon: Icons.eco_rounded, value: '$_habitatsRestored/${game.totalHabitats}',
                label: 'RESTORED', color: accent, isMobile: isMobile),
              SizedBox(width: isMobile ? 10 : 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: timerWarn ? Colors.red.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: timerWarn ? Colors.red : Colors.white24)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.timer, color: timerWarn ? Colors.red : Colors.white54, size: 13),
                  const SizedBox(width: 4),
                  Text(timerStr, style: GoogleFonts.exo2(
                    fontSize: isMobile ? 13 : 15, color: timerWarn ? Colors.red : Colors.white,
                    fontWeight: FontWeight.w900)),
                ]),
              ),
            ]),
          ),
          // Ecosystem health
          Padding(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 14 : 20),
            child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Ecosystem Health', style: GoogleFonts.exo2(
                  fontSize: isMobile ? 11 : 12, color: Colors.white60)),
                Text('${(_ecosystemHealth * 100).toInt()}%', style: GoogleFonts.exo2(
                  fontSize: isMobile ? 13 : 14, color: accent, fontWeight: FontWeight.w900)),
              ]),
              const SizedBox(height: 5),
              ClipRRect(borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(value: _ecosystemHealth,
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  valueColor: const AlwaysStoppedAnimation(accent), minHeight: 8)),
            ]),
          ),
          SizedBox(height: isMobile ? 8 : 12),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 14 : 20),
            child: Container(
              padding: EdgeInsets.all(isMobile ? 10 : 12),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: accent.withValues(alpha: 0.2))),
              child: Row(children: [
                const Icon(Icons.info_outline, color: Color(0xFF00BFA5), size: 16),
                const SizedBox(width: 8),
                Flexible(child: Text('Release clean water to restore each habitat. Tap to revive!',
                  style: GoogleFonts.exo2(fontSize: isMobile ? 10 : 11, color: Colors.white54))),
              ]),
            ),
          ),
          SizedBox(height: isMobile ? 12 : 18),
          // Habitats
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 14 : 20),
              itemCount: _habitats.length,
              itemBuilder: (ctx, i) => _buildHabitatCard(i, isMobile),
            ),
          ),
          SizedBox(height: isMobile ? 10 : 16),
        ]),
      ),
    );
  }

  Widget _buildHabitatCard(int index, bool isMobile) {
    final habitat = _habitats[index];
    final restored = _habitatsRestoredList[index];
    final color = habitat['color'] as Color;
    return GestureDetector(
      onTap: restored ? null : () {
        setState(() => _habitatsRestoredList[index] = true);
        game.restoreHabitat(index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutBack,
        margin: EdgeInsets.only(bottom: isMobile ? 10 : 14),
        padding: EdgeInsets.all(isMobile ? 14 : 18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: restored
                ? [color.withValues(alpha: 0.30), color.withValues(alpha: 0.12)]
                : [Colors.white.withValues(alpha: 0.04), Colors.transparent]),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: restored ? color : Colors.white.withValues(alpha: 0.12), width: 1.5),
          boxShadow: restored ? [BoxShadow(color: color.withValues(alpha: 0.30), blurRadius: 16)] : []),
        child: Row(children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            width: isMobile ? 52 : 64, height: isMobile ? 52 : 64,
            decoration: BoxDecoration(
              color: restored ? color.withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12)),
            child: Center(child: Text(habitat['emoji'] as String,
              style: TextStyle(fontSize: isMobile ? 26 : 32))),
          ),
          SizedBox(width: isMobile ? 12 : 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(habitat['name'] as String, style: GoogleFonts.exo2(
              fontSize: isMobile ? 14 : 16, color: Colors.white, fontWeight: FontWeight.w800)),
            const SizedBox(height: 3),
            Text(habitat['desc'] as String, style: GoogleFonts.exo2(
              fontSize: isMobile ? 10 : 11, color: Colors.white54)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: restored ? color.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8)),
              child: Text(restored ? '🌱 Habitat Restored!' : '💧 Tap to release water',
                style: GoogleFonts.exo2(fontSize: isMobile ? 9 : 10,
                  color: restored ? color : Colors.white38, fontWeight: FontWeight.w700)),
            ),
          ])),
          if (!restored) Icon(Icons.water_drop, color: const Color(0xFF00BFA5).withValues(alpha: 0.6),
            size: isMobile ? 20 : 24),
          if (restored) Icon(Icons.check_circle, color: color, size: isMobile ? 24 : 28),
        ]),
      ),
    );
  }

  Widget _buildEnvironmentalResultOverlay(bool isMobile) {
    final isThriving = _environmentalResult == 'thriving';
    final isRecovering = _environmentalResult == 'recovering';
    final resultColor = isThriving ? const Color(0xFF00BFA5)
        : isRecovering ? const Color(0xFF66BB6A) : Colors.amber;
    final resultEmoji = isThriving ? '🌍' : isRecovering ? '🌿' : '🌱';
    final resultLabel = isThriving ? 'ECOSYSTEM THRIVING!'
        : isRecovering ? 'ECOSYSTEM RECOVERING' : 'RESTORATION BEGUN';

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [const Color(0xFF051208), resultColor.withValues(alpha: 0.12), const Color(0xFF051208)]),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.all(isMobile ? 20 : 32),
          child: Column(children: [
            SizedBox(height: isMobile ? 24 : 40),
            Text(resultEmoji, style: TextStyle(fontSize: isMobile ? 72 : 90)),
            SizedBox(height: isMobile ? 12 : 16),
            Text(resultLabel, style: GoogleFonts.exo2(
              fontSize: isMobile ? 26 : 32, color: resultColor,
              fontWeight: FontWeight.w900, letterSpacing: 1.2), textAlign: TextAlign.center),
            SizedBox(height: isMobile ? 8 : 12),
            Text('$_habitatsRestored of ${game.totalHabitats} habitats restored with clean water.',
              style: GoogleFonts.exo2(fontSize: isMobile ? 13 : 14, color: Colors.white54),
              textAlign: TextAlign.center),
            SizedBox(height: isMobile ? 20 : 28),
            Container(
              padding: EdgeInsets.all(isMobile ? 16 : 20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: resultColor.withValues(alpha: 0.25))),
              child: Column(children: [
                _appResultRow('🌿 Habitats Restored', '$_habitatsRestored / ${game.totalHabitats}', resultColor, isMobile),
                _appResultRow('💚 Ecosystem Health', '${(_ecosystemHealth * 100).toInt()}%', const Color(0xFF66BB6A), isMobile),
                _appResultRow('🐟 Biodiversity', isThriving ? 'Flourishing' : isRecovering ? 'Recovering' : 'Fragile', resultColor, isMobile),
              ]),
            ),
            SizedBox(height: isMobile ? 16 : 22),
            Container(
              padding: EdgeInsets.all(isMobile ? 14 : 18),
              decoration: BoxDecoration(
                color: const Color(0xFF00BFA5).withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF00BFA5).withValues(alpha: 0.25))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(color: const Color(0xFF00BFA5).withValues(alpha: 0.15), shape: BoxShape.circle),
                    child: const Icon(Icons.lightbulb_rounded, color: Color(0xFF00BFA5), size: 16)),
                  const SizedBox(width: 8),
                  Text('WHAT YOU LEARNED', style: GoogleFonts.exo2(
                    fontSize: isMobile ? 10 : 11, color: const Color(0xFF00BFA5),
                    fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                ]),
                const SizedBox(height: 10),
                Text(
                  '🐸 Freshwater ecosystems support 10% of all known species despite covering less than 1% of Earth\'s surface. '
                  'When rivers are restored, fish populations rebound within 2–5 years, insects return first, '
                  'then amphibians, birds, and mammals — triggering a cascade of ecological recovery.',
                  style: GoogleFonts.exo2(fontSize: isMobile ? 12 : 13,
                    color: Colors.white.withValues(alpha: 0.82), fontWeight: FontWeight.w500, height: 1.5)),
              ]),
            ),
            SizedBox(height: isMobile ? 24 : 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => setState(() {
                  _showEnvironmentalResult = false;
                  currentPhase = 8;
                }),
                style: ElevatedButton.styleFrom(
                  backgroundColor: resultColor,
                  padding: EdgeInsets.symmetric(vertical: isMobile ? 14 : 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('VIEW MISSION RESULTS', style: GoogleFonts.exo2(
                    fontSize: isMobile ? 14 : 16, fontWeight: FontWeight.w900,
                    color: Colors.black, letterSpacing: 0.8)),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_rounded, color: Colors.black, size: 18),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _appResultRow(String label, String value, Color color, bool isMobile) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: GoogleFonts.exo2(fontSize: isMobile ? 12 : 13,
          color: Colors.white60, fontWeight: FontWeight.w500)),
        Text(value, style: GoogleFonts.exo2(fontSize: isMobile ? 13 : 14,
          color: color, fontWeight: FontWeight.w800)),
      ]),
    );
  }

  Widget _buildCompletionScreen() {
    final size       = MediaQuery.of(context).size;
    final isMobile   = size.width < 600;

    final totalPoints   = game.calculateFinalScore();
    final purifiedWater = game.purifiedWaterAmount;
    final bactMult      = game.bacteriaMultiplied;
    final plasticKg     = game.recycledPlastic;
    final metalKg       = game.recycledMetal;
    final organicKg     = game.recycledOrganic;
    final hazardousKg   = game.recycledHazardous;
    final fishCaught    = game.fishCount;
    final application   = _selectedApplication ?? 'agriculture';

    // Application-specific data
    String appEmoji = '🌾';
    String appTitle = 'Application Complete';
    Color appColor = const Color(0xFF4CAF50);
    List<Widget> appRows = [];

    switch (application) {
      case 'agriculture':
        final cropType = game.selectedCrop ?? '';
        final cropHarvest = game.harvestYield;
        final harvestLabel = game.harvestResult == 'bountiful' ? '🌟 Bountiful'
            : game.harvestResult == 'average' ? '🌿 Average' : '🥀 Poor';
        final cropEmoji = cropType == 'vegetables' ? '🥦' : cropType == 'maize' ? '🌽' : cropType == 'rice' ? '🌾' : '🌱';
        appEmoji = cropEmoji;
        appTitle = 'Agricultural Harvest';
        appColor = const Color(0xFF4CAF50);
        appRows = [
          if (cropType.isNotEmpty) _lootRow('Crop', cropType[0].toUpperCase() + cropType.substring(1), const Color(0xFF8BC34A), isMobile),
          _lootRow('Yield', '${cropHarvest}kg', const Color(0xFFAED581), isMobile),
          _lootRow('Result', harvestLabel, game.harvestResult == 'bountiful' ? Colors.amber : game.harvestResult == 'average' ? const Color(0xFFFFA000) : const Color(0xFFFF5252), isMobile),
        ];
        break;
      case 'urban':
        appEmoji = '🏙';
        appTitle = 'Urban Water Network';
        appColor = const Color(0xFF29B6F6);
        appRows = [
          _lootRow('🏠 Households Connected', '${game.urbanHouseholdsConnected} / ${game.urbanTotalHouseholds}', const Color(0xFF29B6F6), isMobile),
          _lootRow('📊 Coverage', game.urbanResult == 'excellent' ? 'Full Coverage' : game.urbanResult == 'good' ? 'Good Coverage' : 'Partial', const Color(0xFF29B6F6), isMobile),
          _lootRow('❤️ Health Impact', game.urbanResult == 'excellent' ? 'Transformative' : 'Significant', Colors.pinkAccent, isMobile),
        ];
        break;
      case 'industrial':
        appEmoji = '🏭';
        appTitle = 'Industrial Upgrade';
        appColor = const Color(0xFFFF8F00);
        appRows = [
          _lootRow('⚙️ Systems Upgraded', '${game.industrialSystemsUpgraded} / ${game.industrialTotalSystems}', const Color(0xFFFF8F00), isMobile),
          _lootRow('📈 Efficiency', '${(game.industrialEfficiency * 100).toInt()}%', const Color(0xFF66BB6A), isMobile),
          _lootRow('🌍 Pollution Reduced', game.industrialResult == 'optimized' ? 'Greatly' : 'Moderately', const Color(0xFFFF8F00), isMobile),
        ];
        break;
      case 'environmental':
        appEmoji = '🌿';
        appTitle = 'Ecosystem Restoration';
        appColor = const Color(0xFF00BFA5);
        appRows = [
          _lootRow('🌿 Habitats Restored', '${game.habitatsRestored} / ${game.totalHabitats}', const Color(0xFF00BFA5), isMobile),
          _lootRow('💚 Ecosystem Health', '${(game.ecosystemHealth * 100).toInt()}%', const Color(0xFF66BB6A), isMobile),
          _lootRow('🐟 Biodiversity', game.environmentalResult == 'thriving' ? 'Flourishing' : 'Recovering', const Color(0xFF00BFA5), isMobile),
        ];
        break;
    }

    final cropType = application == 'agriculture' ? (game.selectedCrop ?? '') : '';
    final cropHarvest = application == 'agriculture' ? game.harvestYield : 0;

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

              // ── APPLICATION RESULT ────────────────────────────────────
              _missionCard(
                title: '$appEmoji $appTitle',
                subtitle: 'Impact of your clean water application',
                color: appColor,
                isMobile: isMobile,
                children: appRows,
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
        phaseText = 'Water Purified!\n            Choose your application...';
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