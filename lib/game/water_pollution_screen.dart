import 'dart:async';
import 'dart:math';
import 'package:ecoquest/game/water_pollution_game.dart';
import 'package:flame/extensions.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ecoquest/main.dart';

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
    
    // Set up callbacks
    game.onWasteCollected = (count) {
      setState(() {
        wasteCollected = count;
      });
    };
            
    game.onPhaseComplete = (phase) {
      setState(() {
        _showPhaseTransition = true;
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              currentPhase = phase + 1;
              _showPhaseTransition = false;
              
              // FIX: Ensure proper phase start
              if (phase == 1) {
                game.startPhase2Sorting();
              } else if (phase == 2) {
                game.startPhase3Treatment();
              } else if (phase == 3) {
                // ADD: Explicitly start phase 4
                game.startPhase4Agriculture();
                // Force a rebuild after a short delay to ensure game is ready
                Future.delayed(const Duration(milliseconds: 100), () {
                  if (mounted) setState(() {});
                });
              }
            });
          }
        });
      });
    };
    
    game.onSortingUpdate = (accuracy, sorted) {
      setState(() {
        sortingAccuracy = accuracy;
        itemsSorted = sorted;
        sortedCorrectly = game.sortedCorrectly;
        sortedIncorrectly = game.sortedIncorrectly;
      });
    };
    
    game.onTreatmentUpdate = (zones, pollution) {
      setState(() {
        zonesTreated = zones;
        pollutionLevel = pollution;
      });
    };
    
    game.onAgricultureUpdate = (farms, crops) {
      setState(() {
        farmsIrrigated = farms;
        cropsMature = crops;
      });
    };
      game.onRiverTapped = (tapPosition) {
      _showIrrigationMethodDialog();
    };
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Stack(
          children: [
            // Main game view - NOW INCLUDE PHASE 4
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

  Widget _buildCollectionOverlay() {
    double collectionProgress = (wasteCollected / totalWasteItems * 100).clamp(0, 100);
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;
    
    return Stack(
      children: [
        // Top stats panel - adaptive positioning
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
                          '$wasteCollected / $totalWasteItems',
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
                  
                  // Animated progress bar with gradient
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
                          width: (screenWidth - (isMobile ? 48 : isTablet ? 56 : 64)) * 
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
                        // Progress percentage text
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
                  
                  // Timer and net status row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ValueListenableBuilder<int>(
                        valueListenable: levelTimeNotifier,
                        builder: (context, time, _) {
                          return Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: isMobile ? 8 : 10,
                              vertical: isMobile ? 4 : 6,
                            ),
                            decoration: BoxDecoration(
                              color: time < 60 
                                  ? Colors.red.withValues(alpha: 0.3)
                                  : Colors.green.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: time < 60 ? Colors.red : Colors.green,
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.timer,
                                  size: isMobile ? 14 : 16,
                                  color: time < 60 ? Colors.red : Colors.green,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  '${time}s',
                                  style: GoogleFonts.exo2(
                                    fontSize: isMobile ? 12 : 14,
                                    color: time < 60 ? Colors.red : Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      
                      // Net deployment indicator
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: EdgeInsets.symmetric(
                          horizontal: isMobile ? 8 : 10,
                          vertical: isMobile ? 4 : 6,
                        ),
                        decoration: BoxDecoration(
                          color: (game.speedboat?.netDeployed ?? false)
                              ? Colors.amber.withValues(alpha: 0.3)
                              : Colors.grey.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: (game.speedboat?.netDeployed ?? false)
                                ? Colors.amber
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
                              color: (game.speedboat?.netDeployed ?? false)
                                  ? Colors.amber
                                  : Colors.grey,
                            ),
                            SizedBox(width: 4),
                            Text(
                              (game.speedboat?.netDeployed ?? false) 
                                  ? 'NET ACTIVE'
                                  : 'NET READY',
                              style: GoogleFonts.exo2(
                                fontSize: isMobile ? 10 : 12,
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  SizedBox(height: isMobile ? 8 : 12),
                  
                  // Controls hint - adaptive for device type
                  Container(
                    padding: EdgeInsets.all(isMobile ? 8 : 10),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        if (!isMobile) ...[
                          // Desktop/Laptop controls
                          Text(
                            '🎮 KEYBOARD: WASD or Arrow Keys to move',
                            style: GoogleFonts.exo2(
                              fontSize: isTablet ? 11 : 12,
                              color: Colors.white70,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 4),
                          Text(
                            '🖱️ MOUSE: Click and drag to steer | SPACE to deploy net',
                            style: GoogleFonts.exo2(
                              fontSize: isTablet ? 11 : 12,
                              color: Colors.white70,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ] else ...[
                          // Mobile/Tablet touch controls
                          Text(
                            '👆 Touch and drag to steer the boat',
                            style: GoogleFonts.exo2(
                              fontSize: 11,
                              color: Colors.white70,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 4),
                          Text(
                            '🎯 Tap to deploy collection net',
                            style: GoogleFonts.exo2(
                              fontSize: 11,
                              color: Colors.white70,
                              fontWeight: FontWeight.w500,
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
        
        // Mobile virtual joystick overlay (bottom-left for portrait, adjusts for landscape)
        if (isMobile && game.speedboat?.showJoystick == true)
          Positioned(
            left: isLandscape ? 20 : 30,
            bottom: isLandscape ? 20 : 80,
            child: CustomPaint(
              size: Size(isMobile ? 100 : 120, isMobile ? 100 : 120),
              painter: VirtualJoystickPainter(
                center: game.speedboat!.joystickCenter!,
                position: game.speedboat!.joystickPosition!,
              ),
            ),
          ),
        
        // Collection feedback indicator (center-top)
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
                        padding: EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.green, Colors.green.shade700],
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
        
        // River cleanliness indicator (bottom-right)
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
                SizedBox(height: 4),
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
    final isTablet = size.width >= 600 && size.width < 1024;
    // final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    
    return Stack(
      children: [
        // Main game canvas with drawing overlay
        Positioned.fill(
          child: GestureDetector(
            onPanStart: (details) {
              if (game.selectedIrrigationMethod != null && !game.isDrawingPipe) {
                setState(() {
                  game.isDrawingPipe = true;
                  game.currentDrawnPath.clear();
                  game.addPointToPath(details.localPosition.toVector2());
                });
              }
            },
            onPanUpdate: (details) {
              if (game.isDrawingPipe && game.selectedIrrigationMethod != null) {
                setState(() {
                  game.addPointToPath(details.localPosition.toVector2());
                });
              }
            },
            onPanEnd: (details) {
              if (game.isDrawingPipe) {
                setState(() {
                  game.finishDrawingIrrigation();
                });
              }
            },
            child: Stack(
              children: [
                Container(color: Colors.transparent),
                // Draw the current path being drawn
                if (game.isDrawingPipe && game.currentDrawnPath.isNotEmpty)
                  CustomPaint(
                    size: size,
                    painter: PathDrawingPainter(
                      path: game.currentDrawnPath,
                      color: game.selectedIrrigationMethod == 'drip' 
                          ? Colors.blue 
                          : Colors.green,
                    ),
                  ),
              ],
            ),
          ),
        ),
        
        // Top header with stats
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Container(
              margin: EdgeInsets.all(isMobile ? 8 : 12),
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 12 : 16,
                vertical: isMobile ? 8 : 10,
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
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'SUSTAINABLE IRRIGATION',
                    style: GoogleFonts.exo2(
                      fontSize: isMobile ? 14 : isTablet ? 16 : 18,
                      color: Colors.green,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                    ),
                  ),
                  SizedBox(height: isMobile ? 6 : 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildCompactAgriStat(
                          'Pipeline',
                          game.pipelineConnected ? 'Connected' : 'Not Connected',
                          game.pipelineConnected ? Colors.green : Colors.red,
                          Icons.water,
                          isMobile,
                        ),
                        SizedBox(width: isMobile ? 8 : 12),
                        _buildCompactAgriStat(
                          'Farms',
                          '$farmsIrrigated/$totalFarms',
                          Colors.blue,
                          Icons.agriculture,
                          isMobile,
                        ),
                        SizedBox(width: isMobile ? 8 : 12),
                        _buildCompactAgriStat(
                          'Crops',
                          '$cropsMature',
                          Colors.amber,
                          Icons.grass,
                          isMobile,
                        ),
                        SizedBox(width: isMobile ? 8 : 12),
                        _buildCompactAgriStat(
                          'Efficiency',
                          '${game.waterEfficiency}%',
                          Colors.cyan,
                          Icons.eco,
                          isMobile,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        
        // Instruction overlay - First tap river
        if (!game.pipelineConnected && game.selectedIrrigationMethod == null)
          Positioned(
            top: size.height * 0.3,
            left: 16,
            right: 16,
            child: Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber, width: 2),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.touch_app, color: Colors.amber, size: 32),
                  SizedBox(height: 8),
                  Text(
                    'TAP RIVER to select irrigation method',
                    style: GoogleFonts.exo2(
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        
        // Drawing mode indicator
        if (game.selectedIrrigationMethod != null && !game.isDrawingPipe)
          Positioned(
            top: size.height * 0.15,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue, Colors.cyan],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withValues(alpha: 0.5),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      game.selectedIrrigationMethod == 'drip' 
                          ? Icons.water_drop 
                          : Icons.landscape,
                      color: Colors.white,
                      size: 24,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'DRAW ${game.selectedIrrigationMethod?.toUpperCase()} PATH FROM RIVER',
                      style: GoogleFonts.exo2(
                        fontSize: 14,
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        
        // Drawing active indicator
        if (game.isDrawingPipe)
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Drawing... Release to complete',
                  style: GoogleFonts.exo2(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCompactAgriStat(String label, String value, Color color, IconData icon, bool isMobile) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: isMobile ? 18 : 22),
        SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.exo2(
            fontSize: isMobile ? 14 : 16,
            color: color,
            fontWeight: FontWeight.w900,
          ),
          textAlign: TextAlign.center,
        ),
        Text(
          label,
          style: GoogleFonts.exo2(
            fontSize: isMobile ? 9 : 10,
            color: Colors.white70,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  void _showIrrigationMethodDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black.withValues(alpha: 0.9),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.green, width: 3),
        ),
        title: Row(
          children: [
            Icon(Icons.water_drop, color: Colors.cyan, size: 32),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'SELECT IRRIGATION METHOD',
                style: GoogleFonts.exo2(
                  fontSize: 18,
                  color: Colors.green,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildIrrigationMethodOption(
              'Drip Irrigation',
              'Efficient water use with direct delivery to roots',
              Icons.water_drop,
              'drip',
            ),
            SizedBox(height: 16),
            _buildIrrigationMethodOption(
              'Contour Farming',
              'Prevents soil erosion and water runoff',
              Icons.landscape,
              'contour',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'CANCEL',
              style: GoogleFonts.exo2(
                color: Colors.red,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIrrigationMethodOption(
    String title,
    String description,
    IconData icon,
    String methodId,
  ) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        setState(() {
          game.startDrawingIrrigation(methodId);
        });
        
        // Show drawing instruction
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Draw a path from the river to the farms',
              style: GoogleFonts.exo2(fontWeight: FontWeight.w600),
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      },
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.blue.withValues(alpha: 0.3),
              Colors.cyan.withValues(alpha: 0.3),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.cyan, width: 2),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.cyan.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.cyan, size: 32),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.exo2(
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    description,
                    style: GoogleFonts.exo2(
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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

class PathDrawingPainter extends CustomPainter {
  final List<Vector2> path;
  final Color color;
  
  PathDrawingPainter({
    required this.path,
    required this.color,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    if (path.length < 2) return;
    
    final paint = Paint()
      ..color = color.withValues(alpha: 0.8)
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    
    final pathToDraw = Path();
    pathToDraw.moveTo(path.first.x, path.first.y);
    
    for (int i = 1; i < path.length; i++) {
      pathToDraw.lineTo(path[i].x, path[i].y);
    }
    
    // Draw shadow
    canvas.drawPath(
      pathToDraw,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.3)
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4),
    );
    
    canvas.drawPath(pathToDraw, paint);
    
    // Draw nodes at each point
    for (var point in path) {
      canvas.drawCircle(
        Offset(point.x, point.y),
        6,
        Paint()..color = color,
      );
    }
  }
  
  @override
  bool shouldRepaint(PathDrawingPainter oldDelegate) {
    return oldDelegate.path.length != path.length;
  }
}