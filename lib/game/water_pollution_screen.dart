import 'dart:async' show Future, Timer;
import 'dart:math';
import 'package:ecoquest/game/water_pollution_game.dart';
import 'package:ecoquest/game/rowing_components.dart';
import 'package:flame/extensions.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
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
  int _sessionScore = 0;
  bool _netOnCooldown = false;
  double _netCooldownFraction = 0.0;
  Timer? _netCooldownTimer;
  String? _lastObstacleMessage;
  Timer? _obstacleMessageTimer;

  // Phase 1 — failure/retry state
  bool _phase1Failed = false;
  String _failReason = '';

  // Phase 1 — touch joystick tracking (screen-level pan feeds into boat)
  bool _joystickActive = false;
  Offset _joystickOrigin = Offset.zero;
  Offset _joystickCurrent = Offset.zero;
  
  // Phase 2 stats
  int sortingAccuracy = 0;
  int itemsSorted = 0;
  int sortedCorrectly = 0;   
  int sortedIncorrectly = 0;
  
  // Phase 3 stats
  int zonesTreated = 0;
  int totalZones = 6;
  double pollutionLevel = 100.0;
  
  // Phase 4 stats
  int farmsIrrigated = 0;
  int totalFarms = 3;
  int cropsMature = 0;
  
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

    // Timer tick — fires every frame from _updatePhase1Timer
    game.onTimerTick = (timeLeft) {
      safeSetState(() => _collectionTimeLeft = timeLeft);
    };

    // Collection update (score + health) — fires from collectFloatingWaste
    game.onCollectionUpdate = (score, health, collected) {
      safeSetState(() {
        _sessionScore = score;
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

    // Phase 1 failure (boat sunk or time up without all waste collected)
    game.onPhase1Failed = () {
      safeSetState(() {
        _phase1Failed = true;
        _failReason = game.timeUp
            ? 'Time ran out! ${game.wasteCollectedCount}/${game.totalSpawnedWaste} items collected.'
            : 'Your boat sank! ${game.wasteCollectedCount}/${game.totalSpawnedWaste} items collected.';
      });
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
                // Wrap in GestureDetector for Phase 1 touch joystick
                child: currentPhase == 1
                    ? GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onPanStart: (d) => _onJoystickStart(d.localPosition),
                        onPanUpdate: (d) => _onJoystickUpdate(d.localPosition),
                        onPanEnd: (_) => _onJoystickEnd(),
                        onPanCancel: () => _onJoystickEnd(),
                        child: GameWidget(game: game),
                      )
                    : GameWidget(game: game),
              ),
            
            // UI Overlays
            if (currentPhase == 0) _buildIntroScreen(),
            if (currentPhase == 1) _buildCollectionOverlay(),
            if (currentPhase == 2) _buildSortingInterface(),
            if (currentPhase == 3) _buildTreatmentOverlay(),
            if (currentPhase == 4) _buildAgricultureInterface(),
            if (currentPhase == 5) _buildCompletionScreen(),

            // Phase 1 failure overlay (boat sunk / time up)
            if (currentPhase == 1 && _phase1Failed) _buildPhase1FailedOverlay(),

            // Phase transition overlay
            if (_showPhaseTransition) _buildPhaseTransition(),
          ],
        ),
      ),
    );
  }

  // ── Touch joystick handlers — pan anywhere on screen to steer ────────────

  void _onJoystickStart(Offset pos) {
    setState(() {
      _joystickActive = true;
      _joystickOrigin = pos;
      _joystickCurrent = pos;
    });
    _feedJoystickToBoat(pos);
  }

  void _onJoystickUpdate(Offset pos) {
    setState(() => _joystickCurrent = pos);
    _feedJoystickToBoat(pos);
  }

  void _onJoystickEnd() {
    setState(() => _joystickActive = false);
    // Clear joystick on the boat
    game.rowingBoat?.joystickCenter = null;
    game.rowingBoat?.joystickCurrent = null;
  }

  void _feedJoystickToBoat(Offset screenPos) {
    final boat = game.rowingBoat;
    if (boat == null) return;
    // Convert screen Offset to Flame Vector2
    boat.joystickCenter = Vector2(_joystickOrigin.dx, _joystickOrigin.dy);
    boat.joystickCurrent = Vector2(screenPos.dx, screenPos.dy);
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

  // ── Phase 1 failure overlay ───────────────────────────────────────────────

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
                game.timeUp ? '⏰ TIME\'S UP!' : '🚤 BOAT SUNK!',
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
                'You must collect ALL waste items to clean the river.',
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
                        _sessionScore = 0;
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

  Widget _buildCollectionOverlay() {
    final double collectionProgress =
        (wasteCollected / (game.totalSpawnedWaste > 0 ? game.totalSpawnedWaste : totalWasteItems) * 100).clamp(0.0, 100.0);
    final bool isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;
    final bool isMobile = screenWidth < 600;
    final bool isTablet = screenWidth >= 600 && screenWidth < 1024;

    // Derive readable timer values from _collectionTimeLeft state field
    final int timeLeft = _collectionTimeLeft.toInt().clamp(0, 9999);
    final int timeMins = timeLeft ~/ 60;
    final int timeSecs = timeLeft % 60;
    final String timerLabel =
        '${timeMins.toString().padLeft(2, '0')}:${timeSecs.toString().padLeft(2, '0')}';
    final bool timerWarning = _collectionTimeLeft < 30;

    // Boat-health colour ramp
    final double healthFraction = (_boatHealth / 100.0).clamp(0.0, 1.0);
    final Color healthColor = healthFraction > 0.6
        ? Colors.green
        : healthFraction > 0.3
            ? Colors.orange
            : Colors.red;

    // Net state (reads from new RowingBoatComponent)
    final bool netDeployed = game.rowingBoat?.netDeployed ?? false;

    return Stack(
      children: [
        // ── TOP STATS PANEL ───────────────────────────────────────────────
        Positioned(
          top: 0,
          left: 0,
          right: isLandscape && !isMobile ? screenWidth * 0.3 : 0,
          child: SafeArea(
            child: Container(
              margin: EdgeInsets.all(isMobile ? 12 : isTablet ? 14 : 16),
              padding: EdgeInsets.all(isMobile ? 12 : isTablet ? 14 : 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withValues(alpha: 0.8),
                    Colors.black.withValues(alpha: 0.6),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.cyan, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.cyan.withValues(alpha: 0.3),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Row 1: title + waste count ─────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          'WASTE COLLECTION',
                          style: GoogleFonts.exo2(
                            fontSize: isMobile ? 14 : isTablet ? 16 : 18,
                            color: Colors.cyan,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isMobile ? 8 : 12,
                          vertical: isMobile ? 4 : 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.cyan.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.cyan, width: 1.5),
                        ),
                        child: Text(
                          '$wasteCollected / ${game.totalSpawnedWaste > 0 ? game.totalSpawnedWaste : totalWasteItems}',
                          style: GoogleFonts.exo2(
                            fontSize: isMobile ? 14 : isTablet ? 16 : 18,
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: isMobile ? 8 : 12),

                  // ── Waste progress bar ────────────────────────────────
                  Container(
                    height: isMobile ? 16 : 20,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade900,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.cyan.withValues(alpha: 0.5),
                        width: 1.5,
                      ),
                    ),
                    child: Stack(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: (screenWidth -
                                  (isMobile ? 48 : isTablet ? 56 : 64)) *
                              (collectionProgress / 100),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.cyan,
                                Colors.blue,
                                Colors.cyan.shade700,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(9),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.cyan.withValues(alpha: 0.5),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                        Center(
                          child: Text(
                            '${collectionProgress.toInt()}%',
                            style: GoogleFonts.exo2(
                              fontSize: isMobile ? 10 : 12,
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withValues(alpha: 0.8),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: isMobile ? 8 : 12),

                  // ── Row 2: Timer | Score | Boat HP ───────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Countdown timer (from _collectionTimeLeft state field)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: EdgeInsets.symmetric(
                          horizontal: isMobile ? 8 : 10,
                          vertical: isMobile ? 4 : 6,
                        ),
                        decoration: BoxDecoration(
                          color: timerWarning
                              ? Colors.red.withValues(alpha: 0.35)
                              : Colors.green.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: timerWarning ? Colors.red : Colors.green,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.timer,
                              size: isMobile ? 14 : 16,
                              color:
                                  timerWarning ? Colors.red : Colors.green,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              timerLabel,
                              style: GoogleFonts.exo2(
                                fontSize: isMobile ? 12 : 14,
                                color: timerWarning
                                    ? Colors.red
                                    : Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Session score (from _sessionScore state field)
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isMobile ? 8 : 10,
                          vertical: isMobile ? 4 : 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                          border:
                              Border.all(color: Colors.amber, width: 1.5),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star_rounded,
                                size: isMobile ? 14 : 16,
                                color: Colors.amber),
                            const SizedBox(width: 4),
                            Text(
                              '$_sessionScore',
                              style: GoogleFonts.exo2(
                                fontSize: isMobile ? 12 : 14,
                                color: Colors.amber,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Boat HP (from _boatHealth state field)
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isMobile ? 8 : 10,
                          vertical: isMobile ? 4 : 6,
                        ),
                        decoration: BoxDecoration(
                          color: healthColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: healthColor, width: 1.5),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.directions_boat_filled,
                                size: isMobile ? 14 : 16,
                                color: healthColor),
                            const SizedBox(width: 4),
                            SizedBox(
                              width: isMobile ? 50 : 70,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: healthFraction,
                                  backgroundColor:
                                      Colors.white.withValues(alpha: 0.2),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      healthColor),
                                  minHeight: isMobile ? 8 : 10,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: isMobile ? 8 : 12),

                  // ── Row 3: Net status indicator ───────────────────────
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 8 : 10,
                      vertical: isMobile ? 4 : 6,
                    ),
                    decoration: BoxDecoration(
                      color: netDeployed
                          ? Colors.amber.withValues(alpha: 0.3)
                          : _netOnCooldown
                              ? Colors.orange.withValues(alpha: 0.2)
                              : Colors.grey.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: netDeployed
                            ? Colors.amber
                            : _netOnCooldown
                                ? Colors.orange
                                : Colors.grey,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.catching_pokemon,
                          size: isMobile ? 14 : 16,
                          color: netDeployed
                              ? Colors.amber
                              : _netOnCooldown
                                  ? Colors.orange
                                  : Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          netDeployed
                              ? 'NET ACTIVE'
                              : _netOnCooldown
                                  ? 'RELOADING…'
                                  : 'NET READY',
                          style: GoogleFonts.exo2(
                            fontSize: isMobile ? 10 : 12,
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (_netOnCooldown) ...[
                          const SizedBox(width: 6),
                          SizedBox(
                            width: 40,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: 1.0 - _netCooldownFraction,
                                backgroundColor:
                                    Colors.white.withValues(alpha: 0.2),
                                valueColor:
                                    const AlwaysStoppedAnimation<Color>(
                                        Colors.orange),
                                minHeight: 5,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  SizedBox(height: isMobile ? 6 : 10),

                  // ── Controls hint ─────────────────────────────────────
                  Container(
                    padding: EdgeInsets.all(isMobile ? 8 : 10),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        if (!isMobile) ...[
                          Text(
                            '🎮 KEYBOARD: WASD / Arrows to row  |  SPACE to cast net',
                            style: GoogleFonts.exo2(
                              fontSize: isTablet ? 11 : 12,
                              color: Colors.white70,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '🐊 Avoid crocodiles  🌀 Steer clear of whirlpools  🪵 Watch for log jams',
                            style: GoogleFonts.exo2(
                              fontSize: isTablet ? 10 : 11,
                              color: Colors.white54,
                              fontWeight: FontWeight.w400,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ] else ...[
                          Text(
                            '👆 Drag left joystick to row  •  🎯 Cast Net button to collect',
                            style: GoogleFonts.exo2(
                              fontSize: 11,
                              color: Colors.white70,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '🐊 Avoid crocs  🌀 Escape whirlpools  🪵 Go around log jams',
                            style: GoogleFonts.exo2(
                              fontSize: 10,
                              color: Colors.white54,
                              fontWeight: FontWeight.w400,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // ── OBSTACLE DANGER BANNER (from _lastObstacleMessage) ───────────
        if (_lastObstacleMessage != null)
          Positioned(
            top: screenHeight * 0.16,
            left: 0,
            right: 0,
            child: Center(
              child: AnimatedOpacity(
                opacity: _lastObstacleMessage != null ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade900.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withValues(alpha: 0.5),
                        blurRadius: 20,
                        spreadRadius: 3,
                      ),
                    ],
                  ),
                  child: Text(
                    _lastObstacleMessage!,
                    style: GoogleFonts.exo2(
                      fontSize: isMobile ? 13 : 15,
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),

        // ── COLLECTION MILESTONE FEEDBACK ─────────────────────────────────
        if (wasteCollected > 0 && wasteCollected % 5 == 0)
          Positioned(
            top: screenHeight * 0.25,
            left: 0,
            right: 0,
            child: Center(
              child: TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 800),
                tween: Tween(begin: 0.0, end: 1.0),
                builder: (context, value, child) {
                  return Opacity(
                    opacity: 1.0 - value,
                    child: Transform.scale(
                      scale: 1.0 + (value * 0.5),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.green,
                              Colors.green.shade700,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.withValues(alpha: 0.5),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Text(
                          '+5 COLLECTED! 🎉',
                          style: GoogleFonts.exo2(
                            fontSize: 18,
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

        // ── "WAITING TO START" hint (shown until player first moves) ─────
        if (!game.playerHasStarted)
          Positioned(
            bottom: screenHeight * 0.12,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.cyan.withValues(alpha: 0.6), width: 1.5),
                ),
                child: Text(
                  isMobile
                      ? '👆 Drag anywhere to row  •  Timer starts on first move'
                      : '⬆ WASD / Arrow Keys to row  •  SPACE to cast net  •  Timer starts on first move',
                  style: GoogleFonts.exo2(
                    fontSize: isMobile ? 12 : 13,
                    color: Colors.cyan.shade200,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),

        // ── TOUCH JOYSTICK VISUAL (mobile only, shown while dragging) ────
        if (isMobile && _joystickActive)
          Positioned(
            left: _joystickOrigin.dx - 55,
            top: _joystickOrigin.dy - 55,
            child: IgnorePointer(
              child: CustomPaint(
                size: const Size(110, 110),
                painter: _JoystickPainter(
                  origin: const Offset(55, 55),
                  delta: Offset(
                    (_joystickCurrent.dx - _joystickOrigin.dx).clamp(-50, 50),
                    (_joystickCurrent.dy - _joystickOrigin.dy).clamp(-50, 50),
                  ),
                ),
              ),
            ),
          ),

        // ── NET CAST BUTTON (mobile bottom-right) ─────────────────────────
        if (isMobile)
          Positioned(
            right: 20,
            bottom: 80,
            child: GestureDetector(
              onTap: () => game.rowingBoat?.castNet(),
              child: CustomPaint(
                size: const Size(76, 76),
                painter: NetCastButtonPainter(
                  isActive: game.rowingBoat?.netDeployed ?? false,
                  cooldownFraction: _netCooldownFraction,
                ),
              ),
            ),
          ),

        // ── RIVER CLEANLINESS INDICATOR (bottom-right) ────────────────────
        Positioned(
          right: isMobile ? 12 : isTablet ? 16 : 20,
          bottom: isMobile ? 12 : isTablet ? 16 : 20,
          child: Container(
            padding: EdgeInsets.all(isMobile ? 10 : 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.blue.withValues(alpha: 0.8),
                  Colors.cyan.withValues(alpha: 0.8),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.water_drop,
                  color: collectionProgress > 70
                      ? Colors.green
                      : collectionProgress > 40
                          ? Colors.orange
                          : Colors.red,
                  size: isMobile ? 24 : 32,
                ),
                const SizedBox(height: 4),
                Text(
                  'RIVER',
                  style: GoogleFonts.exo2(
                    fontSize: isMobile ? 10 : 12,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  collectionProgress > 70
                      ? 'CLEAN'
                      : collectionProgress > 40
                          ? 'BETTER'
                          : 'DIRTY',
                  style: GoogleFonts.exo2(
                    fontSize: isMobile ? 8 : 10,
                    color: collectionProgress > 70
                        ? Colors.green
                        : collectionProgress > 40
                            ? Colors.orange
                            : Colors.red,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSortingInterface() {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;
    // SYNC GAME CANVAS SIZE WITH SCREEN SIZE
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (game.size.x != size.width || game.size.y != size.height) {
        game.onGameResize(size.toVector2());
      }
    });
    
    return Stack(
      children: [
        // Top header with stats - COMPACT VERSION
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Container(
              margin: EdgeInsets.all(isMobile ? 8 : 12),
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 12 : 16,
                vertical: isMobile ? 10 : 12,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withValues(alpha: 0.75),
                    Colors.black.withValues(alpha: 0.6),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green, width: 2),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'WASTE SORTING',
                    style: GoogleFonts.exo2(
                      fontSize: isMobile ? 14 : 16,
                      color: Colors.green,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                  SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildCompactStat(
                        'Accuracy',
                        '$sortingAccuracy%',
                        sortingAccuracy >= 70 ? Colors.green : Colors.orange,
                        isMobile,
                      ),
                      Container(width: 1, height: 30, color: Colors.white24),
                      _buildCompactStat(
                        'Progress',
                        '$itemsSorted/${game.collectedWaste.length + itemsSorted}',
                        Colors.cyan,
                        isMobile,
                      ),
                      Container(width: 1, height: 30, color: Colors.white24),
                      _buildCompactStat(
                        'Correct',
                        '$sortedCorrectly',
                        Colors.green,
                        isMobile,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        
        // Instructions - Floating hint (show on first few items)
        // Position relative to SCREEN for overlay consistency
        if (itemsSorted < 5)
          Positioned(
            top: size.height * 0.15,
            left: 16,
            right: 16,
            child: Center(
              child: Container(
                padding: EdgeInsets.all(isMobile ? 10 : 12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber, width: 2),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.touch_app,
                      color: Colors.amber,
                      size: isMobile ? 20 : 24,
                    ),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        isMobile 
                            ? 'TAP item → TAP bin\nOR DRAG to bin'
                            : 'TAP item then TAP bin | OR | DRAG item to bin',
                        style: GoogleFonts.exo2(
                          fontSize: isMobile ? 11 : 13,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
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

  Widget _buildCompactStat(String label, String value, Color color, bool isMobile) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: GoogleFonts.exo2(
            fontSize: isMobile ? 16 : 18,
            color: color,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.exo2(
            fontSize: isMobile ? 9 : 10,
            color: Colors.white70,
            fontWeight: FontWeight.w500,
          ),
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

  Widget _buildAgricultureInterface() {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;
    
    return Stack(
      children: [
        // ADD: Full-screen gesture detector that sits behind UI overlays
        // This ensures gestures reach the game canvas
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent, // CRITICAL: Allow gestures to pass through
            onPanStart: (details) {
              final localPosition = details.localPosition;
              game.onFarmTapDown(Vector2(localPosition.dx, localPosition.dy));
            },
            onPanUpdate: (details) {
              final localPosition = details.localPosition;
              final delta = details.delta;
              game.onFarmDragUpdate(
                Vector2(localPosition.dx, localPosition.dy),
                Vector2(delta.dx, delta.dy),
              );
            },
            onPanEnd: (details) {
              // Use last known position since onPanEnd doesn't provide localPosition
              if (game.lastFurrowPoint != null) {
                game.onFarmDragEnd(game.lastFurrowPoint!.clone());
              }
            },
            onLongPressStart: (details) {
              final tapPosition = Vector2(details.localPosition.dx, details.localPosition.dy);
              _checkForFurrowContinuation(tapPosition);
            },
          ),
        ),
        
        // Instructions overlay - with pointer events disabled so gestures pass through
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: IgnorePointer( // CRITICAL: Prevent this widget from blocking gestures
            child: SafeArea(
              child: Container(
                margin: EdgeInsets.all(isMobile ? 8 : 12),
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 12 : 16,
                  vertical: isMobile ? 10 : 12,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withValues(alpha: 0.75),
                      Colors.black.withValues(alpha: 0.6),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green, width: 2),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.agriculture,
                          color: Colors.green,
                          size: isMobile ? 20 : 24,
                        ),
                        SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'IRRIGATION SETUP',
                            style: GoogleFonts.exo2(
                              fontSize: isMobile ? 14 : 16,
                              color: Colors.green,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      isMobile
                          ? 'Drag to create furrows\nConnect to river for water flow'
                          : 'Drag across the farm to dig furrows • Connect to the river to enable water flow',
                      style: GoogleFonts.exo2(
                        fontSize: isMobile ? 11 : 13,
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        
        // Stats display - with pointer events disabled
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: IgnorePointer( // CRITICAL: Prevent this widget from blocking gestures
            child: SafeArea(
              child: Container(
                margin: EdgeInsets.all(isMobile ? 8 : 12),
                padding: EdgeInsets.all(isMobile ? 10 : 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.blue.withValues(alpha: 0.8),
                      Colors.cyan.withValues(alpha: 0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildAgricultureStat(
                      'Furrows',
                      '${game.completedFurrows.length}',
                      Icons.landscape,
                      isMobile,
                    ),
                    Container(width: 1, height: 30, color: Colors.white24),
                    _buildAgricultureStat(
                      'Connected',
                      '${game.completedFurrows.where((f) => f.isConnectedToRiver).length}',
                      Icons.water_drop,
                      isMobile,
                    ),
                    Container(width: 1, height: 30, color: Colors.white24),
                    _buildAgricultureStat(
                      'Irrigated',
                      '${game.completedFurrows.where((f) => f.hasWater).length}',
                      Icons.check_circle,
                      isMobile,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        
        // Display hint for continuing furrows - with pointer events disabled
        if (game.completedFurrows.isNotEmpty)
          Positioned(
            top: size.height * 0.15,
            left: 16,
            right: 16,
            child: IgnorePointer( // CRITICAL: Prevent this widget from blocking gestures
              child: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Long press on a furrow end to continue drawing',
                  style: GoogleFonts.exo2(
                    fontSize: isMobile ? 10 : 12,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAgricultureStat(String label, String value, IconData icon, bool isMobile) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: Colors.white,
          size: isMobile ? 18 : 22,
        ),
        SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.exo2(
          fontSize: isMobile ? 16 : 18,
          color: Colors.white,
          fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.exo2(
            fontSize: isMobile ? 9 : 10,
            color: Colors.white70,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  void _checkForFurrowContinuation(Vector2 tapPosition) {
    const threshold = 30.0; // Pixels
    
    for (var furrow in game.completedFurrows) {
      if (furrow.points.isEmpty) continue;
      
      // Check if tapping near the end of an existing furrow
      final endPoint = furrow.points.last;
      final distance = (endPoint - tapPosition).length;
      
      if (distance < threshold && !furrow.isConnectedToRiver) {
        // Continue drawing this furrow
        game.resumeFurrowDrawing(furrow);
        
        // Show feedback
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Continuing furrow...'),
            duration: Duration(seconds: 1),
            backgroundColor: Colors.green,
          ),
        );
        
        break;
      }
    }
  }

  Widget _buildCompletionScreen() {
    final totalPoints = game.calculateFinalScore();
    final purifiedWater = game.purifiedWaterAmount;
    final bacteriaMultiplied = game.bacteriaMultiplied;
    
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
            const Color(0xFF0F4C81),
            const Color(0xFF1E88E5),
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
                Icons.check_circle,
                size: isMobile ? 70 : isTablet ? 85 : 100,
                color: Colors.green,
              ),
              SizedBox(height: isMobile ? 16 : 24),
              
              Text(
                'RIVER RESTORED!',
                style: GoogleFonts.exo2(
                  fontSize: isMobile ? 28 : isTablet ? 32 : 36,
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
              
              SizedBox(height: isMobile ? 20 : 32),
              
              Container(
                padding: EdgeInsets.all(isMobile ? 16 : 24),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.cyan, width: 2),
                ),
                child: Column(
                  children: [
                    _buildCompletionStat(
                      'Total Points',
                      '$totalPoints',
                      Colors.amber,
                      isMobile,
                    ),
                    SizedBox(height: isMobile ? 12 : 16),
                    _buildCompletionStat(
                      'Purified Water',
                      '${purifiedWater}L',
                      Colors.cyan,
                      isMobile,
                    ),
                    SizedBox(height: isMobile ? 12 : 16),
                    _buildCompletionStat(
                      'Bacteria Cultures',
                      '$bacteriaMultiplied',
                      Colors.green,
                      isMobile,
                    ),
                    SizedBox(height: isMobile ? 12 : 16),
                    _buildCompletionStat(
                      'Recycled Materials',
                      '${game.recycledMaterials}kg',
                      Colors.purple,
                      isMobile,
                    ),
                  ],
                ),
              ),
              
              SizedBox(height: isMobile ? 20 : 32),
              
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context, {
                      'purifiedWater': purifiedWater,
                      'bacteria': bacteriaMultiplied,
                      'recycledMaterials': game.recycledMaterials,
                      'ecoPoints': totalPoints,
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: EdgeInsets.symmetric(
                      vertical: isMobile ? 12 : 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'CONTINUE',
                    style: GoogleFonts.exo2(
                      fontSize: isMobile ? 16 : 18,
                      fontWeight: FontWeight.w900,
                    ),
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

  Widget _buildCompletionStat(String label, String value, Color color, bool isMobile) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            label,
            style: GoogleFonts.exo2(
              fontSize: isMobile ? 14 : 16,
              color: Colors.white70,
            ),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.exo2(
            fontSize: isMobile ? 20 : 24,
            color: color,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
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

class Phase1CollectionOverlay extends StatefulWidget {
  final double timeLeft;
  final double boatHealth;
  final int score;
  final int wasteCollected;
  final int totalWaste;
  final String? obstacleMessage;
  final bool netOnCooldown;
  final double netCooldownFraction;
  final VoidCallback onNetCast;

  // Joystick state reported back to this widget from gesture layer
  final ValueChanged<Offset> onJoystickStart;
  final ValueChanged<Offset> onJoystickUpdate;
  final VoidCallback onJoystickEnd;

  const Phase1CollectionOverlay({
    super.key,
    required this.timeLeft,
    required this.boatHealth,
    required this.score,
    required this.wasteCollected,
    required this.totalWaste,
    this.obstacleMessage,
    required this.netOnCooldown,
    required this.netCooldownFraction,
    required this.onNetCast,
    required this.onJoystickStart,
    required this.onJoystickUpdate,
    required this.onJoystickEnd,
  });

  @override
  State<Phase1CollectionOverlay> createState() => _Phase1CollectionOverlayState();
}

class _Phase1CollectionOverlayState extends State<Phase1CollectionOverlay>
    with SingleTickerProviderStateMixin {
  Offset? _joystickCenter;
  Offset _joystickCurrent = Offset.zero;

  late AnimationController _dangerPulse;

  @override
  void initState() {
    super.initState();
    _dangerPulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _dangerPulse.dispose();
    super.dispose();
  }

  bool get _isLowHealth => widget.boatHealth < 30;
  bool get _isLowTime => widget.timeLeft < 30;

  String get _formattedTime {
    final mins = (widget.timeLeft ~/ 60).toString().padLeft(2, '0');
    final secs = (widget.timeLeft.toInt() % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 700;

    return Stack(
      children: [
        // ── Low health danger vignette ────────────────────────────────────
        if (_isLowHealth)
          AnimatedBuilder(
            animation: _dangerPulse,
            builder: (_, __) => IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      Colors.transparent,
                      Colors.red.withValues(
                          alpha: 0.25 + _dangerPulse.value * 0.25),
                    ],
                    radius: 0.9,
                  ),
                ),
              ),
            ),
          ),

        // ── TOP HUD ───────────────────────────────────────────────────────
        SafeArea(
          child: Padding(
            padding: EdgeInsets.all(isMobile ? 10 : 16),
            child: Column(
              children: [
                _buildTopHUD(isMobile),
                if (widget.obstacleMessage != null)
                  _buildObstacleAlert(widget.obstacleMessage!),
              ],
            ),
          ),
        ),

        // ── JOYSTICK (bottom-left) ────────────────────────────────────────
        Positioned(
          left: 24,
          bottom: isMobile ? 32 : 48,
          child: _buildJoystick(isMobile),
        ),

        // ── NET BUTTON (bottom-right) ─────────────────────────────────────
        Positioned(
          right: 32,
          bottom: isMobile ? 32 : 48,
          child: _buildNetButton(isMobile),
        ),

        // ── PROGRESS BAR (bottom centre) ─────────────────────────────────
        Positioned(
          left: 0,
          right: 0,
          bottom: isMobile ? 16 : 20,
          child: Center(child: _buildWasteProgress(isMobile)),
        ),

        // ── CONTROLS HINT (first 5 s handled by parent timer) ────────────
        // (kept minimal — main controls are joystick + net button)
      ],
    );
  }

  // ── Top HUD ───────────────────────────────────────────────────────────────

  Widget _buildTopHUD(bool isMobile) {
    return Row(
      children: [
        // Timer
        _hudCard(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.timer_outlined,
                  color: _isLowTime ? Colors.red : Colors.cyan,
                  size: isMobile ? 18 : 22),
              const SizedBox(width: 6),
              AnimatedBuilder(
                animation: _dangerPulse,
                builder: (_, __) => Text(
                  _formattedTime,
                  style: GoogleFonts.exo2(
                    fontSize: isMobile ? 20 : 26,
                    fontWeight: FontWeight.w900,
                    color: _isLowTime
                        ? Color.lerp(Colors.red, Colors.orange,
                            _dangerPulse.value)!
                        : Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(width: 10),

        // Score
        _hudCard(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
              const SizedBox(width: 4),
              Text(
                '${widget.score}',
                style: GoogleFonts.exo2(
                  fontSize: isMobile ? 18 : 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.amber,
                ),
              ),
            ],
          ),
        ),

        const Spacer(),

        // Health bar
        _buildHealthBar(isMobile),
      ],
    );
  }

  Widget _buildHealthBar(bool isMobile) {
    final hp = widget.boatHealth / 100.0;
    final hpColor = hp > 0.6
        ? Colors.green
        : hp > 0.3
            ? Colors.orange
            : Colors.red;

    return _hudCard(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.directions_boat_filled,
              color: hpColor, size: isMobile ? 18 : 22),
          const SizedBox(width: 8),
          SizedBox(
            width: isMobile ? 80 : 120,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Boat HP',
                    style: GoogleFonts.exo2(
                        fontSize: 11, color: Colors.white60)),
                const SizedBox(height: 3),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: hp.clamp(0, 1),
                    backgroundColor: Colors.white24,
                    valueColor: AlwaysStoppedAnimation(hpColor),
                    minHeight: isMobile ? 8 : 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildObstacleAlert(String message) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.red.shade900.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red, width: 1.5),
        boxShadow: [
          BoxShadow(
              color: Colors.red.withValues(alpha: 0.4),
              blurRadius: 16,
              spreadRadius: 2)
        ],
      ),
      child: Text(
        message,
        style: GoogleFonts.exo2(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Colors.white),
        textAlign: TextAlign.center,
      ),
    );
  }

  // ── Joystick ──────────────────────────────────────────────────────────────

  Widget _buildJoystick(bool isMobile) {
    const baseSize = 110.0;

    return GestureDetector(
      onPanStart: (d) {
        _joystickCenter = d.localPosition;
        _joystickCurrent = d.localPosition;
        widget.onJoystickStart(d.globalPosition);
        setState(() {});
      },
      onPanUpdate: (d) {
        _joystickCurrent = d.localPosition;
        widget.onJoystickUpdate(d.globalPosition);
        setState(() {});
      },
      onPanEnd: (_) {
        _joystickCenter = null;
        widget.onJoystickEnd();
        setState(() {});
      },
      child: SizedBox(
        width: baseSize,
        height: baseSize,
        child: CustomPaint(
          painter: _JoystickPainter(
            origin: Offset(baseSize / 2, baseSize / 2),
            delta: _joystickCenter == null
                ? Offset.zero
                : (_joystickCurrent - _joystickCenter!),
          ),
        ),
      ),
    );
  }

  // ── Net button ────────────────────────────────────────────────────────────

  Widget _buildNetButton(bool isMobile) {
    const btnSize = 76.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: widget.netOnCooldown ? null : widget.onNetCast,
          child: SizedBox(
            width: btnSize,
            height: btnSize,
            child: CustomPaint(
              painter: NetCastButtonPainter(
                isActive: !widget.netOnCooldown,
                cooldownFraction: widget.netCooldownFraction,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          widget.netOnCooldown ? 'Reloading…' : 'Cast Net',
          style: GoogleFonts.exo2(
            fontSize: 11,
            color: Colors.white70,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // ── Waste progress ────────────────────────────────────────────────────────

  Widget _buildWasteProgress(bool isMobile) {
    final fraction =
        (widget.wasteCollected / widget.totalWaste).clamp(0.0, 1.0);

    return Container(
      width: isMobile ? 220 : 300,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.cyan.withValues(alpha: 0.4)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '♻ Waste: ${widget.wasteCollected} / ${widget.totalWaste}',
            style: GoogleFonts.exo2(
                fontSize: 12,
                color: Colors.white,
                fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: fraction,
              backgroundColor: Colors.white24,
              valueColor: AlwaysStoppedAnimation(
                fraction > 0.8 ? Colors.green : Colors.cyan,
              ),
              minHeight: 10,
            ),
          ),
        ],
      ),
    );
  }

  // ── Helper ────────────────────────────────────────────────────────────────

  Widget _hudCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: child,
    );
  }
}

class _JoystickPainter extends CustomPainter {
  final Offset origin;  // centre of the base ring in local paint space
  final Offset delta;   // thumb offset from origin, clamped to ±50 px

  const _JoystickPainter({required this.origin, required this.delta});

  @override
  void paint(Canvas canvas, Size sz) {
    const baseRadius = 50.0;

    // Base ring — fill + stroke
    canvas.drawCircle(
        origin,
        baseRadius,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.15)
          ..style = PaintingStyle.fill);
    canvas.drawCircle(
        origin,
        baseRadius,
        Paint()
          ..color = Colors.cyan.withValues(alpha: 0.55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5);

    // Thumb knob — clamp so it never leaves the ring
    final dist = delta.distance.clamp(0.0, baseRadius - 20);
    final dir = delta.distance > 0 ? delta / delta.distance : Offset.zero;
    final knobPos = origin + dir * dist;

    canvas.drawCircle(
        knobPos,
        22,
        Paint()
          ..shader = RadialGradient(
            colors: [Colors.cyan.shade300, Colors.cyan.shade700],
          ).createShader(Rect.fromCircle(center: knobPos, radius: 22)));
    canvas.drawCircle(
        knobPos,
        22,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);

    // Direction arrow when thumb is displaced
    if (dist > 8) {
      final arrowEnd = knobPos + dir * 12;
      canvas.drawLine(
          knobPos,
          arrowEnd,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.7)
            ..strokeWidth = 2.5
            ..strokeCap = StrokeCap.round);
    }
  }

  @override
  bool shouldRepaint(_JoystickPainter old) =>
      old.origin != origin || old.delta != delta;
}
class VirtualJoystickPainter extends CustomPainter {
  final Vector2 center;
  final Vector2 position;
  
  VirtualJoystickPainter({
    required this.center,
    required this.position,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;
    
    // Draw outer circle (base)
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width / 2,
      paint,
    );
    
    // Draw outer circle border
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width / 2,
      paint
        ..color = Colors.cyan.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    
    // Calculate joystick position relative to center
    final direction = position - center;
    final distance = direction.length.clamp(0.0, size.width / 2 - 15);
    final normalized = distance > 0 ? direction.normalized() : Vector2.zero();
    final joystickPos = normalized * distance;
    
    // Draw inner circle (movable stick)
    final stickPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.cyan,
          Colors.cyan.shade700,
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(
            size.width / 2 + joystickPos.x,
            size.height / 2 + joystickPos.y,
          ),
          radius: 25,
        ),
      )
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(
      Offset(
        size.width / 2 + joystickPos.x,
        size.height / 2 + joystickPos.y,
      ),
      25,
      stickPaint,
    );
    
    // Draw direction indicator line
    if (distance > 5) {
      final linePaint = Paint()
        ..color = Colors.cyan.withValues(alpha: 0.5)
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round;
      
      canvas.drawLine(
        Offset(size.width / 2, size.height / 2),
        Offset(
          size.width / 2 + joystickPos.x,
          size.height / 2 + joystickPos.y,
        ),
        linePaint,
      );
    }
  }
  
  @override
  bool shouldRepaint(VirtualJoystickPainter oldDelegate) {
    return oldDelegate.position != position || oldDelegate.center != center;
  }
}