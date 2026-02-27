import 'dart:async' show Future, Timer;
import 'dart:math';
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
                child: GameWidget(game: game),
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

        // ── FIRST-SORT INSTRUCTION TOOLTIP (dismisses after 5 items) ─────
        if (itemsSorted < 5)
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